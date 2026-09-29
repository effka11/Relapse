-- soundlevel is open air only. A sound behind a wall is heard from the
-- opening nearest to the ear on the way there: a doorway, a window, or a
-- shut door. Loudness is the open-air falloff along that whole path, plus
-- a cut for glass or a shut door. No such path: the through-wall cut, and
-- the sound stays where it is. Music does not come through this hook.

local NEAR_SQR = 80 * 80
local MAX_WALLS = 4
local STEP = 2
local MAX_THICK = 96
local MERGE = 8

-- One stud wall is about 32 dB. The next leak is already in the structure,
-- so each further wall adds less. A pane and a shut door leak more than a wall.
local DB_WALL = 32
local DB_WALL_NEXT = 16
local DB_WINDOW = 18
local DB_DOOR = 22
local DB_OPENING = 8
local DB_CAP = 58

-- Stock dsp_presets. 30 is a 3 kHz lowpass. 23 is a short dull room:
-- a 150 ms slap at 3 kHz and a reverb cut at 1.5 kHz. 31 is a 1 kHz lowpass
-- with no tail, for a second wall where almost nothing should bloom.
local DSP_WINDOW = 30
local DSP_WALL = 23
local DSP_DEEP = 31

local CONTENTS_BLOCK = bit.bor(CONTENTS_SOLID, CONTENTS_WINDOW, CONTENTS_MOVEABLE)

local traceOut = {}
local trace = { mask = MASK_SOLID_BRUSHONLY, output = traceOut }
local filter = {}
local doorOut = {}

local function ClearFilter(lp)
	for i = 1, #filter do
		filter[i] = nil
	end
	filter[1] = lp
end

local function IsWindow(tr)
	if tr.MatType == MAT_GLASS then return true end
	local ent = tr.Entity
	if IsValid(ent) and ent:GetClass() == "func_breakable_surf" then return true end
	return false
end

local function IsBrushDoor(ent)
	if not IsValid(ent) then return false end
	local class = ent:GetClass()
	return class == "func_door" or class == "func_door_rotating"
end

local function IsPropDoor(ent)
	return IsValid(ent) and ent:GetClass() == "prop_door_rotating"
end

local function BlockedContents(pos)
	return bit.band(util.PointContents(pos), CONTENTS_BLOCK) ~= 0
end

-- Step through the brush we just hit. Maps often skin one wall as two faces;
-- the caller merges a hit that starts within MERGE of this exit.
local function ExitSolid(hit, dir)
	local traveled = 1
	local pos = hit + dir * 1
	while traveled < MAX_THICK and BlockedContents(pos) do
		traveled = traveled + STEP
		pos = hit + dir * traveled
	end
	return pos + dir * 1
end

-- A door or a pane is thin. A stud wall is not: tunneling through it
-- would put the sound on the near face and call the wall an opening.
local function ThinExit(hit, dir)
	local traveled = 1
	local pos = hit + dir * 1
	while traveled < 16 and BlockedContents(pos) do
		traveled = traveled + STEP
		pos = hit + dir * traveled
	end
	if BlockedContents(pos) then return end
	return pos + dir * 4
end

local function ProbeBrushes(eye, dest, dir)
	local walls, windows, doors = 0, 0, 0
	local pos = eye
	local lastExit
	ClearFilter(LocalPlayer())
	trace.filter = filter

	for _ = 1, MAX_WALLS + 2 do
		trace.start = pos
		trace.endpos = dest
		util.TraceLine(trace)
		if traceOut.StartSolid then return walls, windows, doors, true end
		if not traceOut.Hit or traceOut.HitSky or traceOut.Fraction >= 0.999 then break end

		local hit = traceOut.HitPos
		if hit:DistToSqr(dest) <= MERGE * MERGE then break end
		if lastExit and hit:DistToSqr(lastExit) <= MERGE * MERGE then
			pos = ExitSolid(hit, dir)
			lastExit = pos
			if IsValid(traceOut.Entity) and not traceOut.HitWorld then
				filter[#filter + 1] = traceOut.Entity
			end
			continue
		end

		if traceOut.MatType == MAT_GRATE then
			pos = ExitSolid(hit, dir)
			lastExit = pos
			if IsValid(traceOut.Entity) then
				filter[#filter + 1] = traceOut.Entity
			end
			continue
		end

		if IsWindow(traceOut) then
			windows = windows + 1
		elseif IsBrushDoor(traceOut.Entity) then
			doors = doors + 1
		else
			walls = walls + 1
		end

		if IsValid(traceOut.Entity) and not traceOut.HitWorld then
			filter[#filter + 1] = traceOut.Entity
		end
		pos = ExitSolid(hit, dir)
		lastExit = pos
		if walls + windows + doors >= MAX_WALLS then break end
		if pos:DistToSqr(dest) <= MERGE * MERGE then break end
	end

	return walls, windows, doors, false
end

local function PropDoorOnLine(eye, dest)
	local tr = util.TraceLine({
		start = eye,
		endpos = dest,
		mask = MASK_SOLID,
		filter = function(ent)
			if not IsValid(ent) then return false end
			if IsPropDoor(ent) then return false end
			return true
		end,
		output = doorOut,
	})
	return tr.Hit and IsPropDoor(tr.Entity)
end

local function SideOpen(eye, dest, dir)
	local right = dir:Cross(vector_up)
	if right:LengthSqr() < 0.01 then
		right = dir:Cross(Vector(1, 0, 0))
	end
	right:Normalize()
	right:Mul(40)

	for sign = -1, 1, 2 do
		local start = eye + right * sign
		if BlockedContents(start) then continue end
		trace.start = start
		trace.endpos = dest
		trace.filter = LocalPlayer()
		util.TraceLine(trace)
		if traceOut.StartSolid or traceOut.Hit then continue end
		if not PropDoorOnLine(start, dest) then return true end
	end
	return false
end

local function Decide(eye, dest, raw)
	local delta = dest - eye
	local lenSqr = delta:LengthSqr()
	local info = {
		walls = 0,
		windows = 0,
		doors = 0,
		opening = false,
		near = lenSqr < NEAR_SQR,
	}
	if info.near then return info end

	local len = math.sqrt(lenSqr)
	local dir = delta * (1 / len)
	local walls, windows, doors, stuck = ProbeBrushes(eye, dest, dir)
	info.walls, info.windows, info.doors = walls, windows, doors
	if stuck then
		info.stuck = true
		info.walls = MAX_WALLS
		info.db = DB_CAP
		info.dsp = DSP_DEEP
		return info
	end
	if PropDoorOnLine(eye, dest) then
		info.doors = info.doors + 1
	end
	if info.walls < 1 and info.windows < 1 and info.doors < 1 then return info end

	-- A clear step to the side is a doorway or a corner, not a sealed wall.
	-- The path beyond an opening does not use this: a side gap there is not
	-- a clear run to the sound.
	if not raw and (info.walls > 0 or info.doors > 0) and SideOpen(eye, dest, dir) then
		info.opening = true
		info.db = DB_OPENING
		info.dsp = DSP_WINDOW
		return info
	end

	local db = 0
	if info.walls > 0 then
		db = DB_WALL + (info.walls - 1) * DB_WALL_NEXT
	end
	db = db + info.windows * DB_WINDOW + info.doors * DB_DOOR
	if db > DB_CAP then
		info.capped = true
		db = DB_CAP
	end
	if db < 1 then return info end

	info.db = db
	info.dsp = DSP_WINDOW
	if info.walls >= 2 then
		info.dsp = DSP_DEEP
	elseif info.walls >= 1 or info.doors > 0 then
		info.dsp = DSP_WALL
	end
	return info
end

local FAN_LEN = 700
local FAN_HORIZ = 18
local FAN_DIRS = {}
do
	for i = 0, FAN_HORIZ - 1 do
		FAN_DIRS[#FAN_DIRS + 1] = Angle(0, i * (360 / FAN_HORIZ), 0):Forward()
	end
	for i = 0, 7 do
		FAN_DIRS[#FAN_DIRS + 1] = Angle(26, i * 45, 0):Forward()
	end
end

local function AirGain(dist, level)
	if not level or level <= 50 then return 1 end
	if dist < 36 then dist = 36 end
	local silence = 50 * (level - 50)
	if dist >= silence then return 0 end
	return 1 - dist / silence
end

local function BrushTrace(start, endpos)
	ClearFilter(LocalPlayer())
	trace.start = start
	trace.endpos = endpos
	trace.filter = filter
	util.TraceLine(trace)
	local hitPos = traceOut.HitPos
	local hitNormal = traceOut.HitNormal
	return {
		StartSolid = traceOut.StartSolid,
		Hit = traceOut.Hit and not traceOut.HitSky and (traceOut.Fraction or 1) < 0.999,
		Fraction = traceOut.Fraction or 1,
		HitPos = hitPos and Vector(hitPos.x, hitPos.y, hitPos.z) or start,
		HitNormal = hitNormal and Vector(hitNormal.x, hitNormal.y, hitNormal.z) or vector_up,
		Entity = traceOut.Entity,
		MatType = traceOut.MatType,
	}
end

local function PropDoorHit(eye, dest)
	local tr = util.TraceLine({
		start = eye,
		endpos = dest,
		mask = MASK_SOLID,
		filter = function(ent)
			if not IsValid(ent) then return false end
			if IsPropDoor(ent) then return false end
			return true
		end,
		output = doorOut,
	})
	if tr.Hit and IsPropDoor(tr.Entity) then
		local hitPos = tr.HitPos
		local hitNormal = tr.HitNormal
		return Vector(hitPos.x, hitPos.y, hitPos.z), tr.Entity, Vector(hitNormal.x, hitNormal.y, hitNormal.z)
	end
end

-- Fully open leaf is a hole. Anything else still fills the doorway.
local function LeafOpen(ent)
	if not IsValid(ent) or ent:GetClass() ~= "prop_door_rotating" then return false end
	local st = ent.GetInternalVariable and ent:GetInternalVariable("m_eDoorState")
	return st == 2
end

local function PushPortal(list, pos, far, kind, db)
	db = db or 0
	for i = 1, #list do
		local old = list[i]
		if old.pos:DistToSqr(pos) <= 72 * 72 then
			if db < (old.db or 0) then
				list[i] = { pos = pos, far = far, kind = kind, db = db }
			end
			return
		end
	end
	list[#list + 1] = { pos = pos, far = far, kind = kind, db = db }
end

local function AddHitPortal(list, tr, dir)
	if not tr.Hit then return end
	if IsWindow(tr) then
		local far = ThinExit(tr.HitPos, dir)
		if not far then return end
		PushPortal(list, tr.HitPos + tr.HitNormal * 8, far, "окно", DB_WINDOW)
		return
	end
	local ent = tr.Entity
	if not IsBrushDoor(ent) and not IsPropDoor(ent) then return end
	if LeafOpen(ent) then return end
	local far = tr.HitPos - tr.HitNormal * 28
	if BlockedContents(far) then
		far = ThinExit(tr.HitPos, dir)
	end
	if not far or BlockedContents(far) then return end
	PushPortal(list, tr.HitPos + tr.HitNormal * 8, far, "дверь", DB_DOOR)
end

local function CommitGap(list, hitPos, normal, tangent, z, sign, runStart, runEnd)
	local width = runEnd - runStart
	if width < 24 then return end
	local mid = width > 160 and (runStart + 40) or (runStart + runEnd) * 0.5
	local plane = hitPos + tangent * (mid * sign) + z
	local pos = plane + normal * 12
	local far = plane - normal * 16
	if BlockedContents(far) or BlockedContents(pos) then return end
	local doorPos, doorEnt, doorNormal = PropDoorHit(pos, far)
	if doorPos and not LeafOpen(doorEnt) then
		local doorFar = doorPos - doorNormal * 24
		if BlockedContents(doorFar) then doorFar = far end
		if not BlockedContents(doorFar) then
			PushPortal(list, doorPos + doorNormal * 8, doorFar, "дверь", DB_DOOR)
		end
		return
	end
	PushPortal(list, pos, far, "проём", 0)
end

local function WallGaps(list, hitPos, normal)
	local tangent = normal:Cross(vector_up)
	if tangent:LengthSqr() < 0.01 then
		tangent = normal:Cross(Vector(1, 0, 0))
	end
	tangent:Normalize()
	local lifts = { 0, 48, 88 }
	for lift = 1, 3 do
		local z = Vector(0, 0, lifts[lift])
		for sign = -1, 1, 2 do
			local runStart
			for dist = 16, 720, 20 do
				local into = hitPos + tangent * (dist * sign) + z - normal * 4
				local open = not BlockedContents(into)
				if open and not runStart then
					runStart = dist
				elseif not open and runStart then
					CommitGap(list, hitPos, normal, tangent, z, sign, runStart, dist)
					runStart = nil
				end
			end
			if runStart and runStart > 16 then
				CommitGap(list, hitPos, normal, tangent, z, sign, runStart, runStart + 80)
			end
		end
	end
end

local function FanPortals(list, origin)
	local horiz = {}
	for i = 1, #FAN_DIRS do
		local dir = FAN_DIRS[i]
		local tr = BrushTrace(origin, origin + dir * FAN_LEN)
		local dist = FAN_LEN
		if tr.StartSolid then
			dist = 0
		elseif tr.Hit then
			dist = tr.Fraction * FAN_LEN
			AddHitPortal(list, tr, dir)
		end
		if i <= FAN_HORIZ then
			horiz[i] = { dist = dist, dir = dir }
		end
	end

	for i = 1, FAN_HORIZ do
		local row = horiz[i]
		local d = row.dist
		local left = horiz[(i - 2) % FAN_HORIZ + 1].dist
		local right = horiz[i % FAN_HORIZ + 1].dist
		if d <= 96 or d <= left + 56 or d <= right + 56 then continue end
		local frame = math.max(left, right)
		if frame < 24 then frame = 24 end
		local through = math.min(frame + 28, d - 8)
		if through <= 40 then continue end
		local dir = row.dir
		local pos = origin + dir * through
		if BlockedContents(pos) then continue end
		local far = origin + dir * math.min(through + 36, d - 8)
		if BlockedContents(far) then far = pos end
		local hitPos, hitEnt, hitNormal = PropDoorHit(origin, far)
		if hitPos and not LeafOpen(hitEnt) then
			local doorFar = hitPos - hitNormal * 24
			if BlockedContents(doorFar) then doorFar = far end
			if not BlockedContents(doorFar) then
				PushPortal(list, hitPos + hitNormal * 8, doorFar, "дверь", DB_DOOR)
			end
		else
			PushPortal(list, pos, far, "проём", 0)
		end
	end
end

local portalEnts
local portalEntsAt = 0

local function EntityPortals(list, origin, dest)
	local now = RealTime()
	if not portalEnts or now >= portalEntsAt then
		portalEnts = {}
		local classes = {
			"prop_door_rotating",
			"func_door",
			"func_door_rotating",
			"func_breakable_surf",
		}
		for c = 1, #classes do
			local found = ents.FindByClass(classes[c])
			for i = 1, #found do
				portalEnts[#portalEnts + 1] = found[i]
			end
		end
		portalEntsAt = now + 1.5
	end

	local picked = {}
	for i = 1, #portalEnts do
		local ent = portalEnts[i]
		if not IsValid(ent) or LeafOpen(ent) then continue end
		local center = ent:WorldSpaceCenter()
		local len = center:Distance(origin)
		if len < 28 or len > 700 then continue end
		if center.z > origin.z + 96 and center.z > dest.z + 96 then continue end
		picked[#picked + 1] = { ent = ent, center = center, len = len }
	end
	table.sort(picked, function(a, b)
		return a.len < b.len
	end)

	local n = math.min(16, #picked)
	for i = 1, n do
		local ent = picked[i].ent
		local center = picked[i].center
		local dir = origin - center
		dir:Normalize()
		local near = center + dir * 22
		local far = center - dir * 30
		if BlockedContents(near) then
			near = ThinExit(center, dir)
		end
		if not near or BlockedContents(near) then continue end
		if BlockedContents(far) then
			far = ThinExit(center, -dir)
		end
		if not far or BlockedContents(far) then continue end
		local class = ent:GetClass()
		if class == "func_breakable_surf" then
			local tr = BrushTrace(near, far)
			if tr.Hit and IsWindow(tr) then
				PushPortal(list, near, far, "окно", DB_WINDOW)
			else
				PushPortal(list, near, far, "проём", 0)
			end
		else
			PushPortal(list, near, far, "дверь", DB_DOOR)
		end
	end
end

local function CollectPortals(origin, dest)
	local list = {}
	local delta = dest - origin
	local len = delta:Length()
	if len < 1 then return list end
	local dir = delta * (1 / len)
	local direct = BrushTrace(origin, dest)
	if direct.Hit then
		AddHitPortal(list, direct, dir)
		WallGaps(list, direct.HitPos, direct.HitNormal)
	end
	local hitPos, ent, hitNormal = PropDoorHit(origin, dest)
	if hitPos and not LeafOpen(ent) then
		local far = hitPos - hitNormal * 28
		if BlockedContents(far) then
			far = ThinExit(hitPos, dir)
		end
		if far and not BlockedContents(far) then
			PushPortal(list, hitPos + hitNormal * 8, far, "дверь", DB_DOOR)
		end
	end
	FanPortals(list, origin)
	EntityPortals(list, origin, dest)
	return list
end

local function ClearBrush(a, b)
	if a:DistToSqr(b) < 4 then return true end
	local tr = BrushTrace(a, b)
	if tr.StartSolid then return false end
	return not tr.Hit
end

local function ClearPath(a, b)
	if not ClearBrush(a, b) then return false end
	local _, ent = PropDoorHit(a, b)
	if IsValid(ent) and not LeafOpen(ent) then return false end
	return true
end

-- The opening itself may sit on a door leaf. A hit in the last steps still counts.
local function CanSee(eye, point)
	if eye:DistToSqr(point) < 24 * 24 then return true end
	local tr = BrushTrace(eye, point)
	if tr.StartSolid then return false end
	if tr.Hit and tr.HitPos:DistToSqr(point) > 48 * 48 then return false end
	local hitPos, ent = PropDoorHit(eye, point)
	if hitPos and not LeafOpen(ent) and hitPos:DistToSqr(point) > 48 * 48 then return false end
	return true
end

local function Blockers(info)
	if info.stuck then return 99 end
	return (info.walls or 0) + (info.windows or 0) + (info.doors or 0)
end

-- Far side of a door or a pane. A stud wall does not yield: ThinExit stops at 16.
-- Do not step onward through the next brush: that turns a point in this room
-- into a fake exit and the rest of the house sounds open.
local function PastOpening(far, dest)
	local dir = dest - far
	if dir:LengthSqr() < 1 then return far end
	dir:Normalize()
	local p = far
	if BlockedContents(p) then
		p = ThinExit(p, dir)
		if not p then return end
	end
	return p
end

-- A gap in the wall the straight trace hit sits next to that hit.
-- It still counts when its far side is through the plane. A point that
-- stays on the near face is the wall itself.
local function ThroughWall(far, impact, normal)
	return (far - impact):Dot(normal) < -8
end

-- Nearest opening the ear can see that actually leads toward the sound.
-- A nearby gap that only shaves a metre off the straight line is not that
-- path: the walls behind it still count, and the sound stays on the source.
local function SearchPortals(origin, dest, directN)
	local list = CollectPortals(origin, dest)
	local best
	local straight = origin:Distance(dest)
	local impact, wallNormal
	local direct = BrushTrace(origin, dest)
	if direct.Hit then
		impact = direct.HitPos
		wallNormal = direct.HitNormal
	end
	local miss = { see = 0, past = 0, progress = 0, face = 0 }
	for i = 1, #list do
		local c = list[i]
		if not CanSee(origin, c.pos) then
			miss.see = miss.see + 1
			continue
		end
		local far = c.far
		if not far then
			miss.past = miss.past + 1
			continue
		end
		local past = PastOpening(far, dest)
		if not past then
			miss.past = miss.past + 1
			continue
		end
		local along = origin:Distance(c.pos)
		local progress = straight - past:Distance(dest)
		if progress < 64 or progress < along * 0.55 then
			miss.progress = miss.progress + 1
			continue
		end
		local beyond = Decide(past, dest, true)
		local nBeyond = Blockers(beyond)
		local reached = nBeyond < directN
		local through = impact and ThroughWall(far, impact, wallNormal) and nBeyond <= directN
		local hatch = (c.kind == "дверь" or c.kind == "окно") and nBeyond <= directN
		if not reached and nBeyond > 0 and not through and not hatch then
			miss.face = miss.face + 1
			continue
		end
		local row = {
			portal = c.pos,
			far = past,
			pathLen = origin:Distance(c.pos) + c.pos:Distance(past) + past:Distance(dest),
			kind = c.kind,
			db = c.db or 0,
			beyond = beyond,
			along = along,
			strict = true,
			hops = 1,
		}
		if not best or along < best.along then best = row end
	end
	return best, #list, miss
end

local function PickDsp(kind, db, hops)
	if db >= DB_WALL + DB_WALL_NEXT then return DSP_DEEP end
	if kind == "дверь" or db >= DB_DOOR then return DSP_WALL end
	if kind == "окно" or db >= DB_WINDOW or hops >= 2 then return DSP_WINDOW end
end

local heardCache = {}
local heardCacheN = 0

local function HearFrom(eye, dest, level)
	local key = string.format("%d:%d:%d:%d:%d:%d:%.0f",
		math.floor(eye.x / 64), math.floor(eye.y / 64), math.floor(eye.z / 48),
		math.floor(dest.x / 64), math.floor(dest.y / 64), math.floor(dest.z / 48),
		level or 0)
	local now = RealTime()
	local cached = heardCache[key]
	if cached and cached.untilT > now then return cached end

	local info = Decide(eye, dest)
	local result
	if info.near or not info.db then
		result = { info = info }
	else
		local route, count, miss = SearchPortals(eye, dest, Blockers(info))
		if route then
			local db = route.db or 0
			local beyond = route.beyond
			if beyond and beyond.db and not beyond.opening then
				db = math.min(DB_CAP, db + beyond.db)
			end
			local portal = route.portal
			if BlockedContents(portal) then
				local nudge = eye - portal
				if nudge:LengthSqr() > 1 then
					nudge:Normalize()
					portal = portal + nudge * 16
				end
			end
			local gApp = AirGain(eye:Distance(portal), level)
			local gPath = AirGain(route.pathLen, level)
			local transmit = 10 ^ (-db / 20)
			local scale = 0
			if gApp > 0.02 then
				scale = math.Clamp((gPath / gApp) * transmit, 0, 1)
			end
			result = {
				portal = portal,
				scale = scale,
				kind = route.kind,
				db = db > 0 and db or nil,
				dsp = PickDsp(route.kind, db, route.hops or 1),
				pathLen = route.pathLen,
				hops = route.hops,
				info = info,
				candidates = count,
			}
		end
		if not result then
			result = { db = info.db, dsp = info.dsp, info = info, candidates = count, miss = miss }
		end
	end

	result.untilT = now + 0.3
	if not heardCache[key] then
		heardCacheN = heardCacheN + 1
		if heardCacheN > 48 then
			heardCache = {}
			heardCacheN = 1
		end
	end
	heardCache[key] = result
	return result
end

local routing
local replay = {}

hook.Add("Think", "RelapseOcclusionReplay", function()
	if routing or #replay == 0 then return end
	local item = table.remove(replay, 1)
	routing = item
	sound.Play(item.name, item.pos, item.level, item.pitch, item.vol)
	routing = nil
end)

hook.Add("EntityEmitSound", "RelapseOcclusion", function(data)
	-- A sound started inside EmitSound keeps its original origin. The copy
	-- is played next frame, already at the opening. This one is silenced.
	if routing then
		if routing.dsp and (data.DSP or 0) == 0 then
			data.DSP = routing.dsp
		end
		return
	end

	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	local level = data.SoundLevel or 75
	if level <= 0 then return end

	local pos = data.Pos
	if not isvector(pos) then
		if not IsValid(data.Entity) then return end
		pos = data.Entity:WorldSpaceCenter()
	end

	local heard = HearFrom(EyePos(), pos, level)
	local vol = data.Volume
	if not vol or vol <= 0 then vol = 1 end
	if heard.portal then
		local name = data.SoundName
		if isstring(name) and name ~= "" then
			replay[#replay + 1] = {
				name = name,
				pos = Vector(heard.portal),
				level = level,
				pitch = data.Pitch or 100,
				vol = math.Clamp(vol * (heard.scale or 1), 0, 1),
				dsp = heard.dsp,
			}
		end
		data.Volume = 0
		return true
	end
	if not heard.db then return end

	data.Volume = math.Clamp(vol * 10 ^ (-heard.db / 20), 0, 1)
	if heard.dsp and (data.DSP or 0) == 0 then
		data.DSP = heard.dsp
	end
end)

-- relapse_sound_imitation arms a tour. P plays the next spot. U records
-- at once: with no chain yet it plays the next spot and then starts the
-- log. I shows and hides the debug overlay; it stays hidden until then.
local IMITATE = {
	glass = function(pos)
		sound.Play("Glass.Break", pos, 90, 100)
	end,
}

local HINT_NAME = {
	glass = "стекло",
}

local SOUND = {
	glass = { script = "Glass.Break", level = 90 },
}

local DSP_TEXT = {
	[DSP_WINDOW] = "срез 3 кГц",
	[DSP_WALL] = "короткая глухая комната",
	[DSP_DEEP] = "срез 1 кГц",
}

surface.CreateFont("RelapseSoundImitation", {
	font = "Manrope",
	size = 22,
	weight = 500,
	antialias = true,
	extended = true,
})

local armed
local showUi = false
local rec
local LineBlock
local Primary
local LiveCount

local function HintLines()
	local name = HINT_NAME[armed.kind] or armed.kind
	local n = #armed.points
	if not RelapseSoundMesh.Ready() then
		local phase, frac = RelapseSoundMesh.Phase()
		local status = string.format("Комнаты звука: %s %d%%", phase, math.floor(frac * 100 + 0.5))
		if RelapseSoundMesh.Failed() then
			status = "Комнаты звука: " .. phase
		end
		return {
			string.format("Имитация: %s, %d точек", name, n),
			status,
		}
	end
	if not armed.last then
		local stats = RelapseSoundRooms.Stats()
		return {
			string.format("Имитация: %s, %d точек", name, n),
			stats and string.format("комнат %d, порталов %d (%s)", stats.rooms, stats.portals, stats.from) or "комнат нет",
			"U — запись, P — проиграть, I — скрыть",
		}
	end
	local last = armed.last
	local where = last.note or "без стены"
	local nextLine = last.i < n and "P — следующая точка" or "P — снова с первой"
	local count = ""
	if last.arrivals then
		nextLine = nextLine .. (rec and ", U — в файл" or ", U — запись хода") .. ", I — скрыть"
		count = string.format(", приходов %d", LiveCount(last))
	end
	return {
		string.format("%s %d/%d, %d м, %s%s", name, last.i, n, last.metres, where, count),
		nextLine,
	}
end

local function PointColor(i)
	if armed.last and armed.last.i == i then
		return Color(255, 196, 64)
	end
	if (armed.index % #armed.points) + 1 == i then
		return Color(140, 220, 160)
	end
	return Color(170, 205, 225)
end

hook.Add("HUDPaint", "RelapseSoundImitation", function()
	if not armed or not showUi then return end

	local font = "RelapseSoundImitation"
	local marks = {}
	local last = armed.last
	if last and last.arrivals then
		for _, a in ipairs(last.arrivals) do
			if not a.dying and a.held then marks[#marks + 1] = a.held end
		end
	elseif last and last.heard then
		marks[1] = last.heard
	end
	for _, mark in ipairs(marks) do
		local scr = mark:ToScreen()
		if scr.visible then
			draw.SimpleText("слух", font, scr.x + 1, scr.y - 17, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("слух", font, scr.x, scr.y - 18, Color(255, 90, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	for i = 1, #armed.points do
		local scr = armed.points[i]:ToScreen()
		if scr.visible then
			local col = PointColor(i)
			local label = tostring(i)
			draw.SimpleText(label, font, scr.x + 1, scr.y + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label, font, scr.x, scr.y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local lines = HintLines()
	local lineH = draw.GetFontHeight(font)
	local y = ScrH() - 96 - (#lines - 1) * lineH
	for i = 1, #lines do
		local ly = y + (i - 1) * lineH
		draw.SimpleText(lines[i], font, ScrW() * 0.5 + 1, ly + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(lines[i], font, ScrW() * 0.5, ly, Color(236, 236, 236), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "RelapseSoundImitation", function(depth, sky)
	if depth or sky or not armed or not showUi then return end

	render.SetColorMaterial()
	local eye = EyePos()
	local last = armed.last
	RelapseSoundRooms.DrawCells(eye, 480, last and last.earRoom or RelapseSoundRooms.RoomAt(eye))
	cam.IgnoreZ(true)
	for i = 1, #armed.points do
		local pos = armed.points[i]
		local col = PointColor(i)
		local active = armed.last and armed.last.i == i
		render.DrawLine(pos - Vector(0, 0, 8), pos + Vector(0, 0, 72), col, false)
		render.DrawWireframeSphere(pos, active and 12 or 7, 10, 10, col, false)
	end
	-- DrawPortals takes one chain: the shortest arrival draws its line and point,
	-- every arrival's portals are yellow, the rest are drawn here.
	local overlay
	local prim = Primary(last)
	if last and last.arrivals then
		local chain = {}
		for _, a in ipairs(last.arrivals) do
			for i = 1, #a.chain do
				chain[#chain + 1] = a.chain[i]
			end
		end
		overlay = { chain = chain, pts = prim and prim.pts, point = prim and prim.held }
	end
	RelapseSoundRooms.DrawPortals(eye, 1200, overlay)
	if last and last.arrivals then
		for _, a in ipairs(last.arrivals) do
			if a ~= prim and a.pts and a.held then
				local lineCol = a.dying and Color(150, 110, 140) or Color(255, 130, 220)
				local pointCol = a.dying and Color(150, 110, 140) or Color(255, 90, 210)
				for i = 2, #a.pts - 1 do
					render.DrawLine(a.pts[i - 1], a.pts[i], lineCol, false)
				end
				render.DrawLine(a.held - Vector(0, 0, 8), a.held + Vector(0, 0, 72), pointCol, false)
				render.DrawWireframeSphere(a.held, 11, 12, 12, pointCol, false)
			end
		end
	end
	if last and not last.arrivals and last.heard and last.pos then
		local col = Color(255, 90, 210)
		render.DrawLine(last.heard, last.pos, col, false)
		render.DrawLine(last.heard - Vector(0, 0, 8), last.heard + Vector(0, 0, 72), col, false)
		render.DrawWireframeSphere(last.heard, 11, 12, 12, col, false)
	end
	cam.IgnoreZ(false)
end)

local function BetweenText(info)
	local direct = string.format("стен %d, окон %d, дверей %d", info.walls, info.windows, info.doors)
	if info.near then return "рядом, ближе 2 м" end
	if info.opening then return "проём (на прямой " .. direct .. ")" end
	if not info.db then return "без стены" end
	return direct
end

local function GainText(info)
	if not info.db then
		return "громкость 1, реверб карты"
	end
	local mul = 10 ^ (-info.db / 20)
	local text = string.format("−%d дБ, громкость %.3f, DSP %d (%s)", info.db, mul, info.dsp, DSP_TEXT[info.dsp] or "?")
	if info.capped then
		text = text .. ", потолок −" .. DB_CAP .. " дБ"
	end
	return text
end

local function RouteText(heard)
	local p = heard.portal
	local info = heard.info
	local cut = (heard.db and heard.db > 0) and string.format(", −%d дБ", heard.db) or ""
	local hops = (heard.hops and heard.hops > 1) and string.format(", проёмов %d", heard.hops) or ""
	local tail
	if heard.dsp then
		tail = string.format("множитель %.3f, DSP %d (%s)", heard.scale or 0, heard.dsp, DSP_TEXT[heard.dsp] or "?")
	else
		tail = string.format("множитель %.3f, реверб карты", heard.scale or 0)
	end
	return string.format(
		"слышно из %s (%d, %d, %d), путь %d м%s%s  |  на прямой: %s  |  %s",
		heard.kind,
		math.floor(p.x + 0.5),
		math.floor(p.y + 0.5),
		math.floor(p.z + 0.5),
		math.floor((heard.pathLen or 0) / 39.37 + 0.5),
		cut,
		hops,
		info and BetweenText(info) or "—",
		tail
	)
end

local function LogPlay(pos, heard, metres)
	local soundInfo = SOUND[armed.kind] or {}
	local name = HINT_NAME[armed.kind] or armed.kind
	local how
	if heard.portal then
		how = RouteText(heard)
	else
		local info = heard.info or { walls = 0, windows = 0, doors = 0 }
		local found = ""
		if info.db then
			local miss = heard.miss
			if miss then
				found = string.format(", кандидатов %d (видимость %d, косяк %d, не по пути %d, не ведёт %d)",
					heard.candidates or 0, miss.see or 0, miss.past or 0, miss.progress or 0, miss.face or 0)
			else
				found = string.format(", кандидатов %d", heard.candidates or 0)
			end
		end
		how = string.format("слышно с места%s  |  %s  |  %s", found, BetweenText(info), GainText(info))
	end
	print(string.format(
		"[Relapse] %s %d/%d  %s  level %d  точка (%d, %d, %d)  %d м  |  %s",
		name,
		armed.index,
		#armed.points,
		soundInfo.script or "?",
		soundInfo.level or 0,
		math.floor(pos.x + 0.5),
		math.floor(pos.y + 0.5),
		math.floor(pos.z + 0.5),
		metres,
		how
	))
end

local playToken = 0
local sounding = {}
local SHEETS = {
	"sound/relapse/glass_sheet1.ogg",
	"sound/relapse/glass_sheet2.ogg",
	"sound/relapse/glass_sheet3.ogg",
	"sound/relapse/glass_sheet4.ogg",
}

-- An arrival is one way the sound reaches the ear: keyed by the last portal
-- of its chain, or "src" when the ear is in the source room. Each has its
-- own looping channel. A channel only pans. Loudness is the falloff of its
-- whole path, so the engine fade is pushed past any map.
local BASS_NEAR = 60000
local BASS_FAR = 120000
local EAR_STEP_SQR = 8 * 8
local HOLD_R = 32
local SOUND_SPEED = 13504
local ENV_T = 0.15
local LS_TAU = 0.15
local SWITCH_HOLD = 0.3
local SWITCH_FRAC = 0.1
local SWITCH_CAP = 64
local MAX_ARRIVALS = 4

local function IVec(v)
	if not v then return "—" end
	return string.format("(%d, %d, %d)", math.floor(v.x + 0.5), math.floor(v.y + 0.5), math.floor(v.z + 0.5))
end

local function IdText(id)
	return id == "src" and "звук" or tostring(id)
end

local function ArrivalId(chain)
	return chain[#chain] or "src"
end

local function StopArrival(a)
	a.gone = true
	sounding[a] = nil
	if a.chan then
		a.chan:Stop()
		a.chan = nil
	end
end

local function StopChannel()
	playToken = playToken + 1
	for a in pairs(sounding) do
		StopArrival(a)
	end
end

-- Every arrival of one source plays the same file on the source clock t0,
-- dt behind it. dt is fixed at birth. A portal hand-off copies it onto the
-- new channel so the pair stays on the same sample.
local function StartArrival(last, a)
	local token = playToken
	sounding[a] = true
	sound.PlayFile(last.file, "3d noplay", function(ch, errID, errName)
		if token ~= playToken or a.gone then
			if ch and ch.Stop then ch:Stop() end
			return
		end
		if not ch or not ch.Play then
			print("[Relapse] звук прихода не открылся: " .. tostring(errName or errID))
			return
		end
		a.chan = ch
		ch:Set3DFadeDistance(BASS_NEAR, BASS_FAR)
		ch:EnableLooping(true)
		local len = ch:GetLength()
		if len and len > 0 then
			ch:SetTime((CurTime() - last.t0 - a.dt) % len)
		end
		ch:SetPos(a.held or a.point)
		ch:SetVolume(a.vol or 0)
		ch:Play()
	end)
end

local function Borders(pid, room)
	local p = RelapseSoundRooms.Portal(pid)
	return p ~= nil and (p.a == room or p.b == room)
end

-- A chain still reaches the ear while its last portal borders the ear room.
local function Reaches(last, chain)
	if #chain == 0 then
		return not last.earRoom or last.earRoom == last.srcRoom
	end
	return last.earRoom ~= nil and Borders(chain[#chain], last.earRoom)
end

local function LiveArrival(last, id)
	for _, a in ipairs(last.arrivals) do
		if not a.dying and a.id == id then return a end
	end
end

local function HoldsId(last, id)
	for _, a in ipairs(last.arrivals) do
		if a.id == id then return true end
	end
end

function LiveCount(last)
	local n = 0
	for _, a in ipairs(last.arrivals) do
		if not a.dying then n = n + 1 end
	end
	return n
end

function Primary(last)
	if not last or not last.arrivals then return end
	local best
	for _, a in ipairs(last.arrivals) do
		if not a.dying and (not best or a.L < best.L) then best = a end
	end
	return best
end

local function Fade(a)
	a.dying = true
	a.envTo = 0
end

local function Birth(last, c, env, born)
	local id = ArrivalId(c.chain)
	local a = {
		id = id,
		chain = c.chain,
		key = c.key,
		point = c.point,
		held = Vector(c.point),
		L = c.L,
		pts = c.pts,
		Ls = c.L,
		env = env,
		envTo = 1,
		e = 0,
		dt = c.dt ~= nil and c.dt or math.max(0, (c.L - last.L0) / SOUND_SPEED),
		vol = 0,
	}
	last.arrivals[#last.arrivals + 1] = a
	born[#born + 1] = a
	return a
end

-- Same channel, new chain. The heard point is the new opening on this frame.
local function Follow(a, chain, src, eye)
	a.chain = chain
	a.key = table.concat(chain, ">")
	a.id = ArrivalId(chain)
	a.point, a.L, a.pts = RelapseSoundRooms.Aperture(chain, src, eye)
end

-- Heard point is the ear projected onto the last portal plane and clamped
-- into the frame (P0). At 32 or farther, that point is held. Closer, it
-- stays on that plane inside the frame and turns toward N0, the last portal
-- point Aperture returned (a.point). Between 8 and 32 the weight is
-- (32 - d) / 24. At 8 or nearer, at d = 0, or once the ear has crossed the
-- plane, the point is N0. Crossing is the sign of the ear axis against the
-- polyline vertex stored just before that portal (pts.portalIndex - 1).
-- An empty chain returns the source. No stored portal vertex stays on P0.
local function HoldPoint(a, eye)
	if #a.chain == 0 then return Vector(a.point) end
	local p = RelapseSoundRooms.Portal(a.chain[#a.chain])
	if not p then return Vector(a.point) end
	local k = p.axis
	local lo = { p.mins.x, p.mins.y, p.mins.z }
	local hi = { p.maxs.x, p.maxs.y, p.maxs.z }
	local P = { eye.x, eye.y, eye.z }
	P[k] = p.plane
	for j = 1, 3 do
		if j ~= k then
			P[j] = math.Clamp(P[j], lo[j], hi[j])
		end
	end
	local P0 = Vector(P[1], P[2], P[3])
	local d = P0:Distance(eye)
	if d >= HOLD_R then return P0 end
	local pts = a.pts
	local idx = pts and pts.portalIndex
	local prev = idx and pts[idx - 1]
	if not prev then return P0 end
	local N0 = a.point
	local eyeK = k == 1 and eye.x or (k == 2 and eye.y or eye.z)
	local prevK = k == 1 and prev.x or (k == 2 and prev.y or prev.z)
	local past = (eyeK - p.plane) * (prevK - p.plane) > 0
	local earStep = math.sqrt(EAR_STEP_SQR)
	if d <= earStep or past then return Vector(N0) end
	local w = (HOLD_R - d) / (HOLD_R - earStep)
	return P0 * (1 - w) + N0 * w
end

local function CommonPortal(old, new, eye)
	local rm = RelapseSoundRooms.Room(old)
	if not rm or not new then return end
	local best, bestD
	for _, pid in ipairs(rm.portals) do
		local p = RelapseSoundRooms.Portal(pid)
		if p and (p.a == new or p.b == new) then
			local d = p.center:DistToSqr(eye)
			if not best or d < bestD then
				best, bestD = pid, d
			end
		end
	end
	return best
end

-- The ear walked through P. The arrival that came in through P is cut back
-- to the portal before it, same channel. Any other arrival grows by P only
-- when that chain is then the shortest way in, same channel. A chain that
-- does not stay fades where it stands.
local function Rekey(last, P, oldRoom, list, eye, ev)
	local src = last.pos
	local cut
	local grow = {}
	for _, a in ipairs(last.arrivals) do
		if not a.dying then
			if a.chain[#a.chain] == P then
				cut = a
			else
				grow[#grow + 1] = a
			end
		end
	end

	local parts = {}
	local minL = math.huge
	if cut then
		local was = IdText(cut.id)
		local chain = {}
		for i = 1, #cut.chain - 1 do
			chain[i] = cut.chain[i]
		end
		if Reaches(last, chain) then
			Follow(cut, chain, src, eye)
			minL = cut.L
			parts[#parts + 1] = string.format("обрезан %s→%s", was, IdText(cut.id))
		else
			Fade(cut)
			parts[#parts + 1] = "гаснет " .. was
		end
	end
	for _, c in ipairs(list) do
		if c.L < minL then minL = c.L end
	end

	local grown = {}
	local keep
	if last.earRoom ~= last.srcRoom then
		for _, a in ipairs(grow) do
			if not table.HasValue(a.chain, P) then
				local chain = {}
				for i = 1, #a.chain do
					chain[i] = a.chain[i]
				end
				chain[#chain + 1] = P
				local point, L, pts = RelapseSoundRooms.Aperture(chain, src, eye)
				grown[a] = { chain = chain, point = point, L = L, pts = pts }
				if L <= minL + 1 and (not keep or L < grown[keep].L) then
					keep = a
				end
			end
		end
	end
	for _, a in ipairs(grow) do
		local was = IdText(a.id)
		if a == keep then
			local g = grown[a]
			a.chain = g.chain
			a.key = table.concat(g.chain, ">")
			a.id = P
			a.point, a.L, a.pts = g.point, g.L, g.pts
			parts[#parts + 1] = string.format("дописан %s→%d", was, P)
		else
			Fade(a)
			parts[#parts + 1] = "гаснет " .. was
		end
	end
	ev[#ev + 1] = string.format("комната уха %s→%s через %d: %s",
		tostring(oldRoom), tostring(last.earRoom), P, #parts > 0 and table.concat(parts, ", ") or "приходов не было")
end

-- Evaluate candidates by last portal. A new last portal is born and ramps in.
-- An id still in the list, including one fading out, is not born again.
-- The same live last portal moves to a chain shorter by min(L * 0.1, 64) held
-- for 0.3 s; its channel, dt and eased L stay. Past four, a newcomer shorter
-- than the longest by the same margin replaces it. A birth's delay is
-- max(0, (L - L0) / speed). A birth that already carries dt keeps it.
local function Merge(last, list, born, ev)
	local now = CurTime()
	local seen = {}
	local capWant = false
	for _, c in ipairs(list) do
		local id = ArrivalId(c.chain)
		if seen[id] then continue end
		seen[id] = true
		local a = LiveArrival(last, id)
		if a then
			if c.key ~= a.key and a.L - c.L >= math.min(a.L * SWITCH_FRAC, SWITCH_CAP) then
				if a.holdKey ~= c.key then
					a.holdKey = c.key
					a.holdT = now
				end
				if now - a.holdT >= SWITCH_HOLD then
					ev[#ev + 1] = string.format("короче %s: [%s]→[%s]", IdText(id), a.key, c.key)
					a.chain, a.key = c.chain, c.key
					a.point, a.L, a.pts = c.point, c.L, c.pts
					a.holdKey = nil
				end
			else
				a.holdKey = nil
			end
		elseif not HoldsId(last, id) and RelapseSoundMesh.Falloff(c.L) > 0 then
			local n, worst = 0, nil
			for _, b in ipairs(last.arrivals) do
				if not b.dying then
					n = n + 1
					if not worst or b.L > worst.L then worst = b end
				end
			end
			if n < MAX_ARRIVALS then
				Birth(last, c, 0, born)
				ev[#ev + 1] = "родился " .. IdText(id)
			elseif worst.L - c.L >= math.min(worst.L * SWITCH_FRAC, SWITCH_CAP) then
				capWant = true
				if last.capKey ~= c.key then
					last.capKey = c.key
					last.capT = now
				end
				if now - last.capT >= SWITCH_HOLD then
					Fade(worst)
					Birth(last, c, 0, born)
					ev[#ev + 1] = string.format("гаснет %s (пятый %s короче), родился %s", IdText(worst.id), IdText(id), IdText(id))
					last.capKey = nil
				end
			end
		end
	end
	if not capWant then last.capKey = nil end
	for _, a in ipairs(last.arrivals) do
		if not a.dying and not seen[a.id] then a.holdKey = nil end
	end
end

-- Ear room is re-read after a step of 8; outside the cells the last room is
-- kept. Walking into a neighbour through a shared portal rekeys the set, a
-- jump with no shared portal fades it all and the set is built again.
-- L is smoothed over 0.15 s, births and deaths ramp over 0.15 s. When the
-- last portal changes, the heard point is the new opening on that frame.
-- A fading chain stays where it is. Closer than 8 to the ear, a settled
-- channel keeps the last point that was at least 8 away, until the portal
-- id changes. g = M / Σ shares the frame. e frees the loudest over that
-- same 0.15 s, so its volume is its own falloff and another arrival does
-- not pull it down.
local function Track(last, dt, born)
	born = born or {}
	local eye = EyePos()
	local src = last.pos
	local ev = last.events
	local oldRoom
	local changed = false
	if not last.eyeAt or eye:DistToSqr(last.eyeAt) >= EAR_STEP_SQR then
		last.eyeAt = Vector(eye)
		local room = RelapseSoundRooms.RoomAt(eye)
		if not last.routes then
			last.earRoom = room
			last.routes = RelapseSoundRooms.Routes(room, last.srcRoom)
		elseif room and room ~= last.earRoom then
			oldRoom = last.earRoom
			changed = true
			last.earRoom = room
			last.routes = RelapseSoundRooms.Routes(room, last.srcRoom)
		end
	end

	local list = RelapseSoundRooms.Evaluate(last.routes or {}, src, eye, nil)
	if changed then
		local P = oldRoom and CommonPortal(oldRoom, last.earRoom, eye)
		if P then
			Rekey(last, P, oldRoom, list, eye, ev)
		else
			for _, a in ipairs(last.arrivals) do
				if not a.dying then Fade(a) end
			end
			ev[#ev + 1] = string.format("комната уха %s→%s без общего проёма: все гаснут", tostring(oldRoom), tostring(last.earRoom))
		end
	end

	for _, a in ipairs(last.arrivals) do
		if not a.dying then
			if Reaches(last, a.chain) then
				a.point, a.L, a.pts = RelapseSoundRooms.Aperture(a.chain, src, eye)
			else
				Fade(a)
				ev[#ev + 1] = string.format("гаснет %s: не граничит с комнатой уха", IdText(a.id))
			end
		end
	end

	Merge(last, list, born, ev)

	local k = dt > 0 and (1 - math.exp(-dt / LS_TAU)) or 1
	local step = dt > 0 and dt / ENV_T or 0
	for _, a in ipairs(last.arrivals) do
		if not a.dying then
			local goal = HoldPoint(a, eye)
			if a.holdId ~= a.id then
				a.holdId = a.id
				a.stable = nil
			end
			local d2 = goal:DistToSqr(eye)
			if d2 < EAR_STEP_SQR and a.stable and a.stable:DistToSqr(eye) >= EAR_STEP_SQR then
				a.held = Vector(a.stable)
			else
				a.held = goal
				if d2 >= EAR_STEP_SQR then
					a.stable = Vector(goal)
				end
			end
			a.Ls = a.Ls + (a.L - a.Ls) * k
		end
		if a.env < a.envTo then
			a.env = math.min(a.envTo, a.env + step)
		elseif a.env > a.envTo then
			a.env = math.max(a.envTo, a.env - step)
		end
	end

	local inPair = {}
	local pairs = {}
	for _, a in ipairs(last.arrivals) do
		local old = a.pair
		if old and old.pair == a and old.dying and not a.dying and not inPair[a] then
			local u = a.env
			old.env = 1 - u
			local pairF = RelapseSoundMesh.Falloff(old.Ls) * (1 - u) + RelapseSoundMesh.Falloff(a.Ls) * u
			pairs[#pairs + 1] = { new = a, old = old, u = u, pairF = pairF }
			inPair[a] = true
			inPair[old] = true
		end
	end

	local fall = {}
	local sum, M = 0, 0
	for i, a in ipairs(last.arrivals) do
		if not inPair[a] then
			local f = RelapseSoundMesh.Falloff(a.Ls) * a.env
			fall[i] = f
			sum = sum + f
			if f > M then M = f end
		end
	end
	for _, p in ipairs(pairs) do
		sum = sum + p.pairF
		if p.pairF > M then M = p.pairF end
	end
	local g = (M > 0 and sum > M) and M / sum or 1
	for i, a in ipairs(last.arrivals) do
		if not inPair[a] then
			local f = fall[i]
			local eTo = (M > 0 and f == M) and 1 or 0
			local e = a.e or 0
			if e < eTo then
				e = math.min(eTo, e + step)
			elseif e > eTo then
				e = math.max(eTo, e - step)
			end
			a.e = e
			a.vol = f * (g + (1 - g) * e)
		end
	end
	for _, p in ipairs(pairs) do
		local scale = M > p.pairF and g or 1
		p.old.vol = p.pairF * (1 - p.u) * scale
		p.new.vol = p.pairF * p.u * scale
		p.new.e = scale == 1 and 1 or 0
	end
	last.sum, last.g, last.M = sum, g, M

	for _, a in ipairs(born) do
		StartArrival(last, a)
	end
end

local function ApplyChannel(last)
	local ev = last.events
	for i = #last.arrivals, 1, -1 do
		local a = last.arrivals[i]
		local silent = RelapseSoundMesh.Falloff(a.Ls) <= 0
		if (a.dying and a.env <= 0) or silent then
			if a.pair then
				if a.pair.pair == a then a.pair.pair = nil end
				a.pair = nil
			end
			StopArrival(a)
			table.remove(last.arrivals, i)
			ev[#ev + 1] = "снят " .. IdText(a.id) .. (silent and " (L за спадом)" or "")
		else
			local ch = a.chan
			if ch and ch.GetState and ch:GetState() == GMOD_CHANNEL_PLAYING then
				ch:SetPos(a.held)
				ch:SetVolume(a.vol)
			end
		end
	end
end

local function PlayCut(pos, reason)
	local play = IMITATE[armed.kind]
	if not play then return end
	play(pos)
	local eye = EyePos()
	local metres = math.floor(eye:Distance(pos) / 39.37 + 0.5)
	local level = (SOUND[armed.kind] or {}).level or 75
	local heard = HearFrom(eye, pos, level)
	local note
	if heard.portal then
		note = string.format("из %s, путь %d м", heard.kind, math.floor((heard.pathLen or 0) / 39.37 + 0.5))
	else
		local info = heard.info or { walls = 0, windows = 0, doors = 0 }
		note = BetweenText(info)
		if info.db then
			note = string.format("%s, −%d дБ", note, info.db)
		end
	end
	armed.last = {
		i = armed.index,
		metres = metres,
		db = heard.db,
		pos = pos,
		note = (reason or "нет пути по комнатам") .. ", " .. note,
		heard = heard.portal and Vector(heard.portal) or nil,
	}
	LogPlay(pos, heard, metres)
end

local function ProbePoint(pos, eye)
	local srcRoom = RelapseSoundRooms.RoomAt(pos)
	if not srcRoom then return end
	local earRoom = RelapseSoundRooms.RoomAt(eye)
	local routes = RelapseSoundRooms.Routes(earRoom, srcRoom)
	local list = RelapseSoundRooms.Evaluate(routes, pos, eye, nil)
	if #list == 0 or RelapseSoundMesh.Falloff(list[1].L) <= 0 then return end
	return srcRoom, earRoom, routes, list
end

local function PlayNext()
	if not armed then return end
	if not IMITATE[armed.kind] then return end
	if not RelapseSoundMesh.Ready() then
		local phase, frac = RelapseSoundMesh.Phase()
		print(string.format("[Relapse] комнаты звука: %s %d%%", phase, math.floor(frac * 100 + 0.5)))
		return
	end

	local eye = EyePos()
	local n = #armed.points
	local pick
	for i = 1, n do
		local index = (armed.index + i - 1) % n + 1
		local pos = armed.points[index]
		local srcRoom, earRoom, routes, list = ProbePoint(pos, eye)
		if list then
			pick = {
				index = index,
				pos = pos,
				srcRoom = srcRoom,
				earRoom = earRoom,
				routes = routes,
				list = list,
			}
			break
		end
	end
	if not pick then
		print("[Relapse] точки за спадом")
		return
	end

	armed.index = pick.index
	local pos = pick.pos
	local metres = math.floor(eye:Distance(pos) / 39.37 + 0.5)
	local srcRoom, earRoom, routes, list = pick.srcRoom, pick.earRoom, pick.routes, pick.list

	StopChannel()

	local last = {
		i = armed.index,
		metres = metres,
		pos = pos,
		srcRoom = srcRoom,
		earRoom = earRoom,
		routes = routes,
		eyeAt = Vector(eye),
		t0 = CurTime(),
		L0 = list[1].L,
		file = SHEETS[math.random(#SHEETS)],
		arrivals = {},
		events = {},
	}
	armed.last = last
	local born = {}
	local seen = {}
	for _, c in ipairs(list) do
		local id = ArrivalId(c.chain)
		if not seen[id] and #born < MAX_ARRIVALS and RelapseSoundMesh.Falloff(c.L) > 0 then
			seen[id] = true
			Birth(last, c, 1, born)
		end
	end
	Track(last, 0, born)
	last.events = {}

	local prim = Primary(last)
	local pathM = math.max(1, math.floor(list[1].L / 39.37 + 0.5))
	if not prim then
		last.note = string.format("путь %d м, за спадом", pathM)
	elseif #prim.chain == 0 then
		last.note = string.format("одна комната, %d м", pathM)
	else
		last.note = string.format("путь %d м, порталов %d", pathM, #prim.chain)
	end
	if rec then
		rec.rows[#rec.rows + 1] = "--- P, новый звук ---"
		rec.rows[#rec.rows + 1] = LineBlock(last)
		rec.lastEye = nil
		rec.lastSig = nil
	end

	local soundInfo = SOUND[armed.kind] or {}
	print(string.format(
		"[Relapse] %s %d/%d  %s  level %d  точка %s  %d м  |  комната звука %d, уха %s, приходов %d, кратчайший [%s], L %d м, слышно из %s, громкость %.3f, Σ %.3f",
		HINT_NAME[armed.kind] or armed.kind,
		armed.index,
		#armed.points,
		soundInfo.script or "?",
		soundInfo.level or 0,
		IVec(pos),
		metres,
		srcRoom,
		tostring(last.earRoom or "вне клеток"),
		#last.arrivals,
		prim and prim.key or "—",
		pathM,
		IVec(prim and prim.held),
		prim and prim.vol or 0,
		last.sum or 0
	))
end

local function PortalLine(pid, order)
	local p = RelapseSoundRooms.Portal(pid)
	if not p then return string.format("  портал %d  нет", pid) end
	local size = p.maxs - p.mins
	local ents = RelapseSoundRooms.PortalEnts(p)
	return string.format(
		"  %d. портал %d  комнаты %d↔%d  %s  центр %s  рамка %.0f×%.0f×%.0f  ось %s  пропуск %d  рёбер %d%s",
		order,
		pid,
		p.a,
		p.b,
		RelapseSoundRooms.PortalKind(p),
		IVec(p.center),
		size.x, size.y, size.z,
		p.axis == 3 and "z" or (p.axis == 1 and "x" or "y"),
		p.cap or 0,
		p.width or 0,
		ents ~= "" and ("  " .. ents) or ""
	)
end

function LineBlock(last)
	local eye = EyePos()
	local lines = {
		string.format(
			"звук %s комната %d  ухо %s комната %s  приходов %d  L0 %.0f  файл %s  Σ %.3f  M %.3f  g %.3f",
			IVec(last.pos),
			last.srcRoom or -1,
			IVec(eye),
			tostring(last.earRoom or "вне клеток"),
			#last.arrivals,
			last.L0 or -1,
			last.file or "?",
			last.sum or 0,
			last.M or 0,
			last.g or 1
		),
	}
	if #last.arrivals == 0 then
		lines[#lines + 1] = "  приходов нет"
	end
	for _, a in ipairs(last.arrivals) do
		lines[#lines + 1] = string.format(
			"приход %s  ключ [%s]  L %.0f (сглаж. %.0f)  громкость %.3f  env %.2f  dt %.3f  проём %s  слух %s  d %.0f",
			IdText(a.id),
			a.key,
			a.L,
			a.Ls,
			a.vol or 0,
			a.env,
			a.dt,
			IVec(a.point),
			IVec(a.held),
			a.held and a.held:Distance(eye) or -1
		)
		if #a.chain == 0 then
			lines[#lines + 1] = "  порталов нет: ухо в комнате звука или вне клеток"
		end
		for i = 1, #a.chain do
			lines[#lines + 1] = PortalLine(a.chain[i], i)
		end
		local pts = a.pts
		if pts then
			local along = 0
			local portal = pts.portal
			local missAt = {}
			if pts.miss then
				for m = 1, #pts.miss do
					local miss = pts.miss[m]
					missAt[miss.at] = miss
				end
			end
			for i = 1, #pts do
				if i > 1 then along = along + pts[i]:Distance(pts[i - 1]) end
				local label
				if i == 1 then
					label = "звук"
				elseif i == #pts then
					label = "ухо"
				elseif portal and portal[i] then
					label = "P" .. portal[i]
				else
					label = "угол"
				end
				local miss = missAt[i]
				local extra = miss and string.format("  вне %d,%d", miss.ix, miss.iy) or ""
				lines[#lines + 1] = string.format("  %s  %s  вдоль %.0f%s", label, IVec(pts[i]), along, extra)
			end
		end
	end
	return table.concat(lines, "\n")
end

local function ArrivalSig(last)
	local out = {}
	for _, a in ipairs(last.arrivals) do
		out[#out + 1] = IdText(a.id) .. (a.dying and "~" or "") .. "[" .. a.key .. "]"
	end
	return table.concat(out, " ")
end

-- Turn is the angle between (heard point - ear) now and at this arrival's
-- previous row.
local function RecRow()
	local last = armed and armed.last
	if not last or not last.arrivals then return end
	local eye = EyePos()
	local sig = ArrivalSig(last)
	local write = not rec.lastEye or eye:DistToSqr(rec.lastEye) >= 8 * 8 or sig ~= rec.lastSig or #last.events > 0
	if not write then
		for _, a in ipairs(last.arrivals) do
			if a.held and (not a.recHeld or a.held:DistToSqr(a.recHeld) >= 4 * 4) then write = true break end
			if math.abs(a.Ls - (a.recLs or a.Ls)) >= 8 then write = true break end
		end
	end
	if not write then
		rec.same = rec.same + 1
		return
	end
	if rec.same > 0 then
		rec.rows[#rec.rows + 1] = string.format("  (same x%d)", rec.same)
		rec.same = 0
	end

	local step = rec.lastEye and (eye - rec.lastEye) or vector_origin
	local dmin
	for _, a in ipairs(last.arrivals) do
		if a.id ~= "src" and a.held then
			local d = a.held:Distance(eye)
			if not dmin or d < dmin then dmin = d end
		end
	end
	rec.rows[#rec.rows + 1] = string.format(
		"t=%.2f  ухо %s комната %s  шаг (%.0f, %.0f, %.0f) |%.0f|  звук комната %d  приходов %d  dmin %s  Σ %.3f  M %.3f  g %.3f  Σ·g %.3f%s",
		CurTime() - rec.t0,
		IVec(eye),
		tostring(last.earRoom or "вне клеток"),
		step.x, step.y, step.z,
		step:Length(),
		last.srcRoom or -1,
		#last.arrivals,
		dmin and string.format("%.0f", dmin) or "—",
		last.sum or 0,
		last.M or 0,
		last.g or 1,
		(last.sum or 0) * (last.g or 1),
		#last.events > 0 and ("  смена: " .. table.concat(last.events, "; ")) or ""
	)
	for _, a in ipairs(last.arrivals) do
		local held = a.held or a.point
		local to = held - eye
		local len = to:Length()
		local dirNow = len > 0.001 and to * (1 / len) or nil
		local turn = "новый"
		if a.recDir and dirNow then
			turn = string.format("%.1f°", math.deg(math.acos(math.Clamp(a.recDir:Dot(dirNow), -1, 1))))
		elseif a.recDir then
			turn = "—"
		end
		rec.rows[#rec.rows + 1] = string.format(
			"    %s  ключ [%s]  точка %s  d %.0f  L %.0f сглаж. %.0f  спад %.3f  vol %.3f  env %.2f  dt %.3f  поворот %s%s",
			IdText(a.id),
			a.key,
			IVec(held),
			len,
			a.L,
			a.Ls,
			RelapseSoundMesh.Falloff(a.Ls),
			a.vol or 0,
			a.env,
			a.dt,
			turn,
			a.dying and "  гаснет" or ""
		)
		if a.recKey ~= a.key then
			for i = 1, #a.chain do
				rec.rows[#rec.rows + 1] = "  " .. PortalLine(a.chain[i], i)
			end
		end
		a.recHeld = Vector(held)
		a.recLs = a.Ls
		a.recKey = a.key
		if dirNow then a.recDir = dirNow end
	end
	rec.lastEye = Vector(eye)
	rec.lastSig = sig
	rec.n = rec.n + 1
end

local function FlushRec(reason)
	if not rec then return end
	if rec.same > 0 then
		rec.rows[#rec.rows + 1] = string.format("  (same x%d)", rec.same)
		rec.same = 0
	end
	local tail = string.format("[Relapse] стоп (%s), кадров хода %d, секунд %.1f", reason, rec.n, CurTime() - rec.t0)
	local text = rec.head .. "\n" .. table.concat(rec.rows, "\n") .. "\n" .. tail
	rec = nil
	print(tail)
	local chunk = 24000
	local parts = math.max(1, math.ceil(#text / chunk))
	for i = 1, parts do
		net.Start("relapse_sound_log")
		net.WriteUInt(i, 8)
		net.WriteUInt(parts, 8)
		net.WriteString(string.sub(text, (i - 1) * chunk + 1, i * chunk))
		net.SendToServer()
	end
end

local function StartRec()
	if not (armed and armed.last and armed.last.arrivals) then
		PlayNext()
	end
	local last = armed and armed.last
	if not last or not last.arrivals then
		if RelapseSoundMesh.Ready() then
			print("[Relapse] запись: нет прихода")
		end
		return
	end
	for _, a in ipairs(last.arrivals) do
		a.recHeld, a.recLs, a.recKey, a.recDir = nil, nil, nil, nil
	end
	last.events = {}
	local stats = RelapseSoundRooms.Stats() or {}
	rec = {
		t0 = CurTime(),
		rows = {},
		same = 0,
		n = 0,
		head = string.format("[Relapse] запись хода  карта %s  комнат %d  порталов %d (%s)\n%s",
			game.GetMap(), stats.rooms or 0, stats.portals or 0, stats.from or "?", LineBlock(last)),
	}
	RecRow()
	print("[Relapse] запись хода. Иди к проёму и дальше, потом U — файл")
end

hook.Add("Think", "RelapseSoundImitationPan", function()
	local last = armed and armed.last
	if last and last.arrivals then
		Track(last, FrameTime())
		ApplyChannel(last)
	end
	if not rec then
		if last and last.arrivals then last.events = {} end
		return
	end
	if not last or not last.arrivals then
		FlushRec("цепочка пропала")
		return
	end
	local ok, err = pcall(RecRow)
	last.events = {}
	if not ok then
		rec.rows[#rec.rows + 1] = "ошибка кадра: " .. tostring(err)
		FlushRec("ошибка")
		return
	end
	if rec.n >= 280 or CurTime() - rec.t0 >= 90 then
		FlushRec(rec.n >= 280 and "лимит кадров" or "90 с")
	end
end)

hook.Add("PlayerButtonDown", "RelapseSoundImitation", function(pl, button)
	if pl ~= LocalPlayer() then return end
	if not IsFirstTimePredicted() then return end
	if not armed then return end
	if gui.IsConsoleVisible() or gui.IsGameUIVisible() or vgui.CursorVisible() then return end
	if button == KEY_I then
		showUi = not showUi
		print(showUi and "[Relapse] оверлей вкл" or "[Relapse] оверлей выкл")
	elseif button == KEY_P then
		PlayNext()
	elseif button == KEY_U then
		if rec then
			FlushRec("U")
		else
			StartRec()
		end
	end
end)

net.Receive("relapse_sound_imitation", function()
	local kind = net.ReadString()
	local count = net.ReadUInt(8)
	local points = {}
	for i = 1, count do
		points[i] = net.ReadVector()
	end
	StopChannel()
	if rec then FlushRec("имитация выключена") end
	if kind == "" or count < 1 or not IMITATE[kind] then
		RelapseSoundMesh.Reset()
		armed = nil
		showUi = false
		return
	end
	showUi = false
	armed = {
		kind = kind,
		points = points,
		index = 0,
	}
	RelapseSoundMesh.Ensure(points)
end)
