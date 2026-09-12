-- Relapse AI navigation: Valve .nav is a temporary walk host until Relapse's own
-- graph exists. relapse_editmesh is that editor shell — not nav_edit, not maps/*.nav.
-- Readiness, budgeted path computation, blocked-area memory, BSP ladders.

local AI = RelapseAI
local Nav = {}
AI.Nav = Nav

local CurTime = CurTime
local SysTime = SysTime
local IsValid = IsValid
local ipairs = ipairs

Nav.BlockedAreas = Nav.BlockedAreas or {} -- [areaID] = {Expiry = time, Penalty = extra path cost in units}
Nav.BadLadders = Nav.BadLadders or {} -- [ladderID] = expiry; a bot failed on it, paths avoid it until then
Nav.LadderDirs = Nav.LadderDirs or {} -- [ladderID] = Vector; facing (away from the wall) of ladders we built
Nav.Ladders = {} -- CNavLadders created on this map load
Nav.Climbables = {} -- BSP shafts we can walk to and climb even if CreateNavLadder failed

-- CNavLadder:IsValid exists, but a climbable table is not an entity. Pathing
-- and the climb SM must accept both.
function Nav.HasLadder(l)
	if l == nil then return false end
	if istable(l) then return l.Bottom ~= nil and l.Top ~= nil end
	if l.IsValid then return l:IsValid() end
	return l.GetBottom ~= nil
end
-- Additive path costs, in distance units: a detour shorter than the penalty wins over the marked area.
Nav.Penalty = {
	Stuck = 500, -- snagged on geometry the mesh does not show
	Barricade = 1400, -- nailed prop in the way: walk up to this much further instead of breaking it
	Unbreakable = 3000, -- hammered for ObstacleTimeout without result (locked door, elevator)
}
Nav.Queue = {} -- pending requests, FIFO
Nav.Pending = {} -- [bot] = request
Nav.Stats = {Computes = 0, Window = 0, WindowStart = 0, ComputesPerSec = 0, LastMs = 0, AvgMs = 0}
Nav.UsePathHost = false -- switched on if the engine refuses a player as the path owner
Nav.Host = nil

-- GMod has no info_ladder class, so the map's ladder ents never spawn.
-- A stub lets them exist (AABB/keyvalues) on the next map load; the BSP
-- lump is still the source we build CNavLadders from.
do
	local stub = {
		Type = "point",
		Base = "base_point",
		Spawnable = false,
	}
	scripted_ents.Register(stub, "info_ladder")
end

---------------------------------------------------------------------------
-- Readiness
---------------------------------------------------------------------------

function Nav.IsReady()
	return navmesh.IsLoaded() and not navmesh.IsGenerating()
end

function Nav.Status()
	if navmesh.IsGenerating() then
		return "generating"
	end
	if not navmesh.IsLoaded() then
		return "missing (maps/" .. game.GetMap() .. ".nav)"
	end
	return string.format("loaded, %d areas", navmesh.GetNavAreaCount())
end

---------------------------------------------------------------------------
-- Cost profiles
---------------------------------------------------------------------------

Nav.Profiles = {
	zombie = {
		StepHeight = 18,
		JumpHeight = 60, -- duck-jump ledge (185 jump power, 600 gravity)
		JumpMul = 2.5,
		JumpCost = 60, -- flat cost per jump connection
		CrouchMul = 1.5,
		AvoidMul = 4,
		PenaltyMul = 1, -- scales Nav.Penalty
		Ladders = true,
		LadderMul = 1.5, -- per unit of ladder length (climbing is slower than running)
		LadderCost = 80, -- flat: lining up with the rungs
	},
	human = {
		StepHeight = 18,
		JumpHeight = 56,
		JumpMul = 3,
		JumpCost = 80,
		CrouchMul = 1.5,
		AvoidMul = 6,
		PenaltyMul = 3, -- humans do not break barricades
		Ladders = true,
		LadderMul = 2,
		LadderCost = 120,
	},
}

local costCache = {}

local function MakeCostFunction(profile)
	local stepHeight = profile.StepHeight
	local jumpHeight = profile.JumpHeight
	local jumpMul = profile.JumpMul
	local jumpCost = profile.JumpCost or 0
	local crouchMul = profile.CrouchMul
	local avoidMul = profile.AvoidMul
	local penaltyMul = profile.PenaltyMul or 1
	local ladders = profile.Ladders
	local ladderMul = profile.LadderMul or 2
	local ladderCost = profile.LadderCost or 0
	local blocked = Nav.BlockedAreas
	local badLadders = Nav.BadLadders
	local maxDropVar = AI.cv.max_drop
	local navBlocker = NAV_MESH_NAV_BLOCKER or 0

	return function(area, fromArea, ladder, elevator, length)
		if not IsValid(fromArea) then
			return 0 -- first area
		end

		if ladder ~= nil and (not ladder.IsValid or ladder:IsValid()) then
			if not ladders then return -1 end
			local bad = badLadders[ladder:GetID()]
			if bad then
				if bad > CurTime() then return -1 end
				badLadders[ladder:GetID()] = nil
			end
			return ladder:GetLength() * ladderMul + ladderCost + fromArea:GetCostSoFar()
		end

		if navBlocker ~= 0 and area:HasAttributes(navBlocker) then
			return -1
		end

		local dist
		if length > 0 then
			dist = length
		else
			dist = area:GetCenter():Distance(fromArea:GetCenter())
		end

		local cost = dist

		local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange(area)
		if deltaZ >= stepHeight then
			if deltaZ > jumpHeight then
				return -1
			end
			-- Flat part: a hop is slow and breaks the run even for a small ledge, so a slightly longer flat route wins.
			cost = cost + dist * jumpMul + jumpCost
		elseif deltaZ < -maxDropVar:GetFloat() then
			return -1
		end

		if area:HasAttributes(NAV_MESH_AVOID) then
			cost = cost * avoidMul
		end
		if area:HasAttributes(NAV_MESH_CROUCH) then
			cost = cost * crouchMul
		end

		local entry = blocked[area:GetID()]
		if entry then
			if entry.Expiry > CurTime() then
				cost = cost + entry.Penalty * penaltyMul
			else
				blocked[area:GetID()] = nil
			end
		end

		return cost + fromArea:GetCostSoFar()
	end
end

function Nav.GetCostFunction(name)
	local fn = costCache[name]
	if not fn then
		local profile = Nav.Profiles[name] or Nav.Profiles.zombie
		fn = MakeCostFunction(profile)
		costCache[name] = fn
	end
	return fn
end

---------------------------------------------------------------------------
-- Blocked areas (learned barricades)
---------------------------------------------------------------------------

-- Marks stack by taking the later expiry and the larger penalty.
function Nav.MarkBlockedArea(area, duration, penalty)
	if not IsValid(area) then return end
	local id = area:GetID()
	local expiry = CurTime() + (duration or 20)
	penalty = penalty or Nav.Penalty.Stuck

	local entry = Nav.BlockedAreas[id]
	if entry then
		if expiry > entry.Expiry then entry.Expiry = expiry end
		if penalty > entry.Penalty then entry.Penalty = penalty end
	else
		Nav.BlockedAreas[id] = {Expiry = expiry, Penalty = penalty, Since = CurTime()}
	end
	return area
end

function Nav.MarkBlockedAt(pos, duration, penalty)
	local area = navmesh.GetNearestNavArea(pos, false, 200, false, true)
	return Nav.MarkBlockedArea(area, duration, penalty)
end

-- When the area at pos first got a penalty of at least minPenalty (nil if none is active).
-- A path computed after that already paid for it, so there is no point asking for a detour again.
function Nav.BlockedSince(pos, minPenalty)
	local area = navmesh.GetNearestNavArea(pos, false, 200, false, true)
	if not IsValid(area) then return nil end
	local entry = Nav.BlockedAreas[area:GetID()]
	if entry and entry.Expiry > CurTime() and entry.Penalty >= (minPenalty or 0) then
		return entry.Since
	end
	return nil
end

function Nav.UnmarkArea(areaOrID)
	local id = areaOrID
	if not isnumber(id) then
		if not IsValid(id) then return end
		id = id:GetID()
	end
	Nav.BlockedAreas[id] = nil
end

function Nav.IsAreaBlocked(area)
	if not IsValid(area) then return false end
	local entry = Nav.BlockedAreas[area:GetID()]
	return entry ~= nil and entry.Expiry > CurTime()
end

function Nav.GetAreaAt(pos, beneath)
	return navmesh.GetNavArea(pos, beneath or 32)
end

-- Random reachable-ish point around pos for wandering.
function Nav.RandomPointNear(pos, radius)
	local areas = navmesh.Find(pos, radius or 600, 64, AI.cv.max_drop:GetFloat())
	if #areas == 0 then return nil end
	local area = areas[math.random(#areas)]
	if not IsValid(area) then return nil end
	return area:GetRandomPoint()
end

-- Snap a rough position to the navmesh so paths end on walkable ground.
function Nav.SnapToMesh(pos, maxDist)
	local area = navmesh.GetNearestNavArea(pos, true, maxDist or 400, false, true)
	if IsValid(area) then
		return area:GetClosestPointOnArea(pos)
	end
	return pos
end

---------------------------------------------------------------------------
-- Ladders
--
-- GMod's generator builds no ladders: VBSP turns every func_ladder into an
-- info_ladder entity in the BSP and GMod does not know that class, so the
-- generated mesh has no way up a shaft. Read the boxes back from the entity
-- lump and create nav ladders on every map load (not saved to the .nav).
-- A* will not climb UP onto a behind-only landing, so wall-ladder roofs are
-- promoted to top-forward after the engine connects them.
---------------------------------------------------------------------------

local function EntityKey(block, key)
	return tonumber(string.match(block, '"' .. key .. '" "([^"]+)"'))
end

local function EntityVec(block, key)
	local x, y, z = string.match(block, '"' .. key .. '" "([^%s"]+)%s+([^%s"]+)%s+([^%s"]+)"')
	if x then return tonumber(x), tonumber(y), tonumber(z) end
end

local function PushBox(boxes, x0, y0, z0, x1, y1, z1)
	if not (x0 and y0 and z0 and x1 and y1 and z1) then return end
	local mins = Vector(math.min(x0, x1), math.min(y0, y1), math.min(z0, z1))
	local maxs = Vector(math.max(x0, x1), math.max(y0, y1), math.max(z0, z1))
	if maxs.z - mins.z < 40 then return end
	boxes[#boxes + 1] = {mins = mins, maxs = maxs}
end

-- info_ladder mins/maxs are local to origin on some maps and already world-space
-- on others. If the box centre is far from origin, treat them as local.
local function PushLadderBox(boxes, ox, oy, oz, x0, y0, z0, x1, y1, z1)
	if not (x0 and y0 and z0 and x1 and y1 and z1) then return end
	if ox then
		local cx, cy, cz = (x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5
		local dx, dy, dz = cx - ox, cy - oy, cz - oz
		if dx * dx + dy * dy + dz * dz > 64 * 64 then
			x0, y0, z0 = x0 + ox, y0 + oy, z0 + oz
			x1, y1, z1 = x1 + ox, y1 + oy, z1 + oz
		end
	end
	PushBox(boxes, x0, y0, z0, x1, y1, z1)
end

local function ParseKeyVec(v)
	if isvector(v) then return v end
	if isstring(v) then
		local x, y, z = string.match(v, "([^%s]+)%s+([^%s]+)%s+([^%s]+)")
		if x then return Vector(tonumber(x), tonumber(y), tonumber(z)) end
	end
end

-- Boxes of the map's func_ladder / func_useableladder: {mins = Vector, maxs = Vector}.
function Nav.LoadMapLadders()
	local f = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME")
	if not f then return {} end

	-- Lump 0 (entities) header follows the 8-byte ident/version.
	f:Seek(8)
	local ofs = f:ReadLong()
	local len = f:ReadLong()
	local data
	if ofs and len and ofs > 0 and len > 0 and len < 64 * 1024 * 1024 then
		f:Seek(ofs)
		data = f:Read(len)
	end
	f:Close()
	if not data then return {} end

	local boxes = {}
	for block in string.gmatch(data, "{(.-)}") do
		if string.find(block, '"classname" "info_ladder"', 1, true)
		or string.find(block, '"classname" "func_ladder"', 1, true) then
			local ox, oy, oz = EntityVec(block, "origin")
			local x0, y0, z0 = EntityKey(block, "mins%.x"), EntityKey(block, "mins%.y"), EntityKey(block, "mins%.z")
			local x1, y1, z1 = EntityKey(block, "maxs%.x"), EntityKey(block, "maxs%.y"), EntityKey(block, "maxs%.z")
			if not x0 then x0, y0, z0 = EntityVec(block, "mins") end
			if not x1 then x1, y1, z1 = EntityVec(block, "maxs") end
			PushLadderBox(boxes, ox, oy, oz, x0, y0, z0, x1, y1, z1)
		elseif string.find(block, '"classname" "func_useableladder"', 1, true) then
			local x0, y0, z0 = EntityVec(block, "point0")
			local x1, y1, z1 = EntityVec(block, "point1")
			if x0 and x1 then
				PushBox(boxes, x0 - 16, y0 - 16, z0, x1 + 16, y1 + 16, z1)
			end
		end
	end
	return boxes
end

function Nav.CollectLiveLadderBoxes(boxes)
	boxes = boxes or {}
	for _, class in ipairs({"info_ladder", "func_ladder"}) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if IsValid(ent) then
				local mins, maxs = ent:WorldSpaceAABB()
				if mins then PushBox(boxes, mins.x, mins.y, mins.z, maxs.x, maxs.y, maxs.z) end
			end
		end
	end
	for _, ent in ipairs(ents.FindByClass("func_useableladder")) do
		if IsValid(ent) then
			local kv = ent.GetKeyValues and ent:GetKeyValues() or {}
			local p0 = ParseKeyVec(kv.point0 or kv.Point0)
			local p1 = ParseKeyVec(kv.point1 or kv.Point1)
			if p0 and p1 then
				PushBox(boxes, p0.x - 16, p0.y - 16, p0.z, p1.x + 16, p1.y + 16, p1.z)
			end
		end
	end
	return boxes
end

-- Ignore grate/ladder volume: a vertical line up the open side hits the roof
-- slab that the shaft goes into, and we used to skip those as "walled in".
local WALL_MASK = bit.bor(CONTENTS_SOLID, CONTENTS_PLAYERCLIP or 0, CONTENTS_MOVEABLE or 0, CONTENTS_WINDOW or 0)
local ladderTrace = {mask = WALL_MASK}

-- Horizontal poke at climb height (not the landing). True if this side is a wall.
local function SideHitsWall(cx, cy, z, dir, dist)
	ladderTrace.mask = WALL_MASK
	ladderTrace.start = Vector(cx, cy, z)
	ladderTrace.endpos = Vector(cx + dir.x * dist, cy + dir.y * dist, z)
	local tr = util.TraceLine(ladderTrace)
	return tr.Hit and not tr.StartSolid and tr.Fraction < 0.92
end

local function HasGroundNear(x, y, z, dir)
	return IsValid(navmesh.GetNearestNavArea(Vector(x + dir.x * 40, y + dir.y * 40, z + 8), false, 120, false, true))
end

-- Nav area beside a ladder end, on this side, and actually at this height.
local function AreaBeside(origin, dir, dist)
	local p = Vector(origin.x + dir.x * dist, origin.y + dir.y * dist, origin.z + 8)
	local area = navmesh.GetNearestNavArea(p, false, 140, false, true)
	if not IsValid(area) then return nil end
	local az = area:GetClosestPointOnArea(p).z
	if math.abs(az - origin.z) > 72 then return nil end
	return area
end

-- Height of the landing next to the ladder's upper part. Only look near the
-- brush top: a shaft that passes two floors must not steal the third.
local function FindTopZ(cx, cy, halfWidth, mins, maxs)
	local pad = halfWidth + 40
	local areas = navmesh.FindInBox(
		Vector(cx - pad, cy - pad, maxs.z - 80),
		Vector(cx + pad, cy + pad, maxs.z + 24)
	)
	local best
	local probe = Vector(cx, cy, maxs.z)
	for _, area in ipairs(areas) do
		if IsValid(area) then
			local z = area:GetClosestPointOnArea(probe).z
			if not best or z > best then best = z end
		end
	end
	return best
end

local function MakeClimbable(bottom, top, normal, width, nav, id)
	local n = Vector(normal.x, normal.y, 0)
	if n:LengthSqr() < 0.25 then n = Vector(1, 0, 0) else n:Normalize() end
	local c = {
		Bottom = Vector(bottom.x, bottom.y, bottom.z),
		Top = Vector(top.x, top.y, top.z),
		Normal = n,
		Width = width or 32,
		Nav = nav,
		ID = id or 0,
	}
	function c:GetBottom() return self.Bottom end
	function c:GetTop() return self.Top end
	function c:GetWidth() return self.Width end
	function c:GetNormal() return self.Normal end
	function c:GetID() return self.ID end
	function c:GetLength() return math.abs(self.Top.z - self.Bottom.z) end
	function c:IsValid() return true end
	return c
end

-- Facing (away from the wall) plus the rung line. Never drops a shaft because
-- a roof slab sits over the open side.
local function SpecFromBox(box)
	local mins, maxs = box.mins, box.maxs
	local sx, sy = maxs.x - mins.x, maxs.y - mins.y
	local height = maxs.z - mins.z
	if height < 40 or sx < 1 or sy < 1 then return nil, "too small" end

	local cx, cy = (mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5
	local width, thickness, dirs
	if sx >= sy then
		width, thickness = sx, sy
		dirs = {Vector(0, 1, 0), Vector(0, -1, 0)}
	else
		width, thickness = sy, sx
		dirs = {Vector(1, 0, 0), Vector(-1, 0, 0)}
	end
	if width < 32 then width = 32 end

	local dist = thickness * 0.5 + 18
	local zLow, zMid = mins.z + 20, mins.z + height * 0.35
	local open = {}
	for _, d in ipairs(dirs) do
		if not (SideHitsWall(cx, cy, zLow, d, dist) or SideHitsWall(cx, cy, zMid, d, dist)) then
			open[#open + 1] = d
		end
	end

	local dir
	if #open == 1 then
		dir = open[1]
	else
		local pool = #open > 0 and open or dirs
		for _, d in ipairs(pool) do
			if HasGroundNear(cx, cy, mins.z, d) then
				dir = d
				break
			end
		end
		dir = dir or pool[1]
	end

	local fx, fy = cx + dir.x * thickness * 0.5, cy + dir.y * thickness * 0.5
	local topZ = FindTopZ(cx, cy, width * 0.5, mins, maxs) or maxs.z
	if topZ < mins.z + 40 then topZ = maxs.z end
	local botZ = mins.z
	local ground = AreaBeside(Vector(fx, fy, mins.z), dir, 36)
	if IsValid(ground) then
		local gz = ground:GetClosestPointOnArea(Vector(fx, fy, mins.z)).z
		if math.abs(gz - mins.z) < 48 then botZ = gz end
	end

	return {
		cx = cx, cy = cy,
		bottom = Vector(fx, fy, botZ),
		top = Vector(fx, fy, topZ),
		dir = dir,
		width = width,
	}
end

local function ExistingAt(existing, cx, cy, z)
	for _, l in ipairs(existing) do
		local b = l:GetBottom()
		local dx, dy = b.x - cx, b.y - cy
		if dx * dx + dy * dy < 40 * 40 and math.abs(b.z - z) < 56 then
			return l
		end
	end
end

local function CreateLadderFromBox(box, existing)
	local spec, why = SpecFromBox(box)
	if not spec then return nil, nil, why end

	local found = ExistingAt(existing, spec.cx, spec.cy, spec.bottom.z)
	if found then
		return found, spec, "duplicate"
	end

	local ladder = navmesh.CreateNavLadder(spec.top, spec.bottom, spec.width, spec.dir, 120)
	if ladder == nil or (ladder.IsValid and not ladder:IsValid()) then
		return nil, spec, "engine refused"
	end

	Nav.LadderDirs[ladder:GetID()] = spec.dir
	return ladder, spec, nil
end

-- Facing of a ladder (away from the wall, toward the climber).
function Nav.LadderNormal(ladder)
	if istable(ladder) and ladder.Normal then
		return ladder.Normal
	end
	if not Nav.HasLadder(ladder) then return Vector(1, 0, 0) end
	local dir = Nav.LadderDirs[ladder:GetID()]
	if dir then return dir end
	local n = ladder:GetNormal()
	if n:LengthSqr() < 0.5 then return Vector(1, 0, 0) end
	n = Vector(n.x, n.y, 0)
	n:Normalize()
	return n
end

function Nav.BanLadder(ladder, duration)
	if not Nav.HasLadder(ladder) then return end
	Nav.BadLadders[ladder:GetID()] = CurTime() + (duration or 30)
end

function Nav.GetAllLadders()
	local now = CurTime()
	if Nav.LadderCache and Nav.LadderCacheTime and now - Nav.LadderCacheTime < 2 then
		return Nav.LadderCache
	end
	local list = {}
	for id = 1, 1024 do
		local l = navmesh.GetNavLadderByID(id)
		if l ~= nil and (not l.IsValid or l:IsValid()) then
			list[#list + 1] = l
		end
	end
	Nav.LadderCache = list
	Nav.LadderCacheTime = now
	return list
end

local function HasTopExit(ladder)
	return IsValid(ladder:GetTopForwardArea())
		or IsValid(ladder:GetTopLeftArea())
		or IsValid(ladder:GetTopRightArea())
end

local function LinkArea(ladder, area)
	if not IsValid(area) then return end
	ladder:ConnectTo(area)
	pcall(function() area:ConnectTo(ladder) end)
end

-- A* will not climb UP onto a behind-only landing (wall ladders onto a roof).
-- Put a real exit in forward/left/right and make both ends two-way.
function Nav.WireLadder(ladder)
	if ladder == nil or (ladder.IsValid and not ladder:IsValid()) then return nil end
	local n = Nav.LadderNormal(ladder)
	local bottom, top = ladder:GetBottom(), ladder:GetTop()
	local note

	local bottomArea = ladder:GetBottomArea()
	if not IsValid(bottomArea) then
		bottomArea = AreaBeside(bottom, n, 36) or AreaBeside(bottom, n, 64)
		if IsValid(bottomArea) then
			ladder:SetBottomArea(bottomArea)
			LinkArea(ladder, bottomArea)
			note = "bottom"
		end
	else
		LinkArea(ladder, bottomArea)
	end

	LinkArea(ladder, ladder:GetTopForwardArea())
	LinkArea(ladder, ladder:GetTopBehindArea())
	LinkArea(ladder, ladder:GetTopLeftArea())
	LinkArea(ladder, ladder:GetTopRightArea())

	if not HasTopExit(ladder) then
		local behind = ladder:GetTopBehindArea()
		local landing = behind
			or AreaBeside(top, Vector(-n.x, -n.y, 0), 40)
			or AreaBeside(top, n, 40)
			or AreaBeside(top, Vector(-n.y, n.x, 0), 40)
			or AreaBeside(top, Vector(n.y, -n.x, 0), 40)
		if IsValid(landing) then
			local promoted = landing == behind
			ladder:SetTopForwardArea(landing)
			LinkArea(ladder, landing)
			local tag = promoted and "promote" or "top"
			note = note and (note .. "+" .. tag) or tag
		end
	end

	return note
end

-- Best shaft that actually changes floor toward the goal. Uses BSP climbables
-- so a roof ladder still counts if CreateNavLadder failed or A* will not climb it.
function Nav.FindLadderForGoal(pos, goal, maxMountDist)
	if not pos or not goal then return nil end
	local dz = goal.z - pos.z
	local wantUp = dz > 36
	if not wantUp and dz > -36 then return nil end

	local list = Nav.Climbables
	if not list or #list == 0 then
		list = Nav.GetAllLadders()
	end

	local maxMountD2 = maxMountDist and (maxMountDist * maxMountDist) or nil
	local landMax = 1400 * 1400
	local best, bestScore, bestUp
	local now = CurTime()
	local bad = Nav.BadLadders

	for _, ladder in ipairs(list) do
		if Nav.HasLadder(ladder) then
			local banned = bad[ladder:GetID()]
			if not (banned and banned > now) then
				local b, t = ladder:GetBottom(), ladder:GetTop()
				local mount, land, usable, reaches
				if wantUp then
					usable = math.abs(b.z - pos.z) <= 160 and t.z >= pos.z + 24
					reaches = t.z >= goal.z - 140
					mount, land = b, t
				else
					usable = math.abs(t.z - pos.z) <= 160 and b.z <= pos.z - 24
					reaches = b.z <= goal.z + 140
					mount, land = t, b
				end
				if usable then
					local mdx, mdy = mount.x - pos.x, mount.y - pos.y
					local mountD2 = mdx * mdx + mdy * mdy
					if not maxMountD2 or mountD2 <= maxMountD2 then
						local ldx, ldy = land.x - goal.x, land.y - goal.y
						local landD2 = ldx * ldx + ldy * ldy
						if landD2 <= landMax then
							local score = math.sqrt(mountD2) + math.sqrt(landD2) * 1.2
							if not reaches then score = score + 2500 end
							if not best or score < bestScore then
								best, bestScore, bestUp = ladder, score, wantUp
							end
						end
					end
				end
			end
		end
	end

	if not best then return nil end
	return best, bestUp
end

function Nav.NearestUsefulLadder(pos, goal, maxDist)
	return Nav.FindLadderForGoal(pos, goal, maxDist or 90)
end

-- Returns climbables created, ladder brushes found.
function Nav.BuildLadders()
	if AI.IsSpawnOff and AI.IsSpawnOff() then return 0, 0 end
	if not navmesh.IsLoaded() then return 0, 0 end
	Nav.LadderCache = nil
	Nav.Climbables = {}
	local boxes = Nav.CollectLiveLadderBoxes(Nav.LoadMapLadders())

	local existing = Nav.GetAllLadders()
	local made, skipped, climbN = 0, {}, 0
	for i, box in ipairs(boxes) do
		local ladder, spec, why = CreateLadderFromBox(box, existing)
		if spec then
			local id
			if ladder then
				id = ladder:GetID()
				Nav.LadderDirs[id] = spec.dir
				if why ~= "duplicate" then
					made = made + 1
					existing[#existing + 1] = ladder
					Nav.Ladders[#Nav.Ladders + 1] = ladder
				end
			else
				id = 10000 + i
			end
			Nav.Climbables[#Nav.Climbables + 1] = MakeClimbable(spec.bottom, spec.top, spec.dir, spec.width, ladder, id)
			climbN = climbN + 1
		end
		if why then
			skipped[why] = (skipped[why] or 0) + 1
		end
	end

	Nav.LadderCache = nil
	local wired, promoted = 0, 0
	for _, ladder in ipairs(Nav.GetAllLadders()) do
		local note = Nav.WireLadder(ladder)
		if note then
			wired = wired + 1
			if string.find(note, "promote", 1, true) then promoted = promoted + 1 end
		end
	end

	local parts = {}
	for why, n in pairs(skipped) do parts[#parts + 1] = n .. " " .. why end
	if #boxes > 0 then
		AI.Log("nav ladders: mesh %d / climb %d of %d info_ladder brushes%s", made, climbN, #boxes,
			#parts > 0 and (" (notes: " .. table.concat(parts, ", ") .. ")") or "")
		local sample = Nav.Climbables[1]
		if sample then
			local b = sample:GetBottom()
			AI.Log("nav ladders: sample climb #%s bottom (%.0f %.0f %.0f)", tostring(sample:GetID()), b.x, b.y, b.z)
		end
	elseif #Nav.GetAllLadders() == 0 then
		AI.Log("nav ladders: none found in the BSP (info_ladder / func_useableladder)")
	end
	if wired > 0 then
		AI.Log("nav ladders: wired %d (promoted %d wall-ladder exits so A* will climb them)", wired, promoted)
	end
	return climbN, #boxes
end

---------------------------------------------------------------------------
-- Path host fallback (only used if Path:Compute rejects a player nextbot)
---------------------------------------------------------------------------

do
	local ENT = {}
	ENT.Type = "nextbot"
	ENT.Base = "base_nextbot"
	ENT.IsRelapseAIPathHost = true

	function ENT:Initialize()
		self:AddEFlags(bit.bor(EFL_SERVER_ONLY, EFL_FORCE_CHECK_TRANSMIT))
		if self.BaseClass and self.BaseClass.Initialize then
			self.BaseClass.Initialize(self)
		end
		self:DrawShadow(false)
		self:SetModel("models/player/zombie_classic.mdl")
		self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetNoDraw(true)
		self.loco:SetStepHeight(18)
		self.loco:SetJumpHeight(60)
		self.loco:SetDeathDropHeight(200)
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_NONE
	end

	function ENT:RunBehaviour()
	end

	scripted_ents.Register(ENT, "relapse_ai_pathhost")
end

function Nav.GetHost(pl)
	if not Nav.UsePathHost then
		return pl
	end

	local host = Nav.Host
	if not IsValid(host) then
		host = ents.Create("relapse_ai_pathhost")
		if not IsValid(host) then return pl end
		host:Spawn()
		Nav.Host = host
	end

	host:SetPos(pl:GetPos())
	return host
end

---------------------------------------------------------------------------
-- Path requests
---------------------------------------------------------------------------

function Nav.Request(bot, goal, opts)
	opts = opts or {}

	local req = Nav.Pending[bot]
	if req then
		req.Goal:Set(goal)
		req.Opts = opts
		return req
	end

	req = {Bot = bot, Goal = Vector(goal), Opts = opts, Time = CurTime()}
	Nav.Pending[bot] = req
	Nav.Queue[#Nav.Queue + 1] = req
	return req
end

function Nav.Cancel(bot)
	local req = Nav.Pending[bot]
	if req then
		req.Cancelled = true
		Nav.Pending[bot] = nil
	end
end

function Nav.ComputeNow(bot, goal, opts)
	local pl = bot.Player
	local path = bot.Path
	if not path then
		path = Path("Follow")
		bot.Path = path
	end

	path:SetMinLookAheadDistance(opts.LookAhead or 120)
	path:SetGoalTolerance(opts.Tolerance or 24)

	local costfn = Nav.GetCostFunction(opts.Profile or bot.Brain.NavProfile or "zombie")
	local host = Nav.GetHost(pl)

	local t0 = SysTime()
	local ok, reached = pcall(path.Compute, path, host, goal, costfn)
	if not ok and not Nav.UsePathHost then
		AI.Log("Path:Compute rejected the player (%s); using a helper nextbot as path host", tostring(reached))
		Nav.UsePathHost = true
		host = Nav.GetHost(pl)
		ok, reached = pcall(path.Compute, path, host, goal, costfn)
	end
	if not ok then
		AI.Warn("Path:Compute failed: %s", tostring(reached))
		reached = false
	end

	local ms = (SysTime() - t0) * 1000
	local stats = Nav.Stats
	stats.Computes = stats.Computes + 1
	stats.Window = stats.Window + 1
	stats.LastMs = ms
	stats.AvgMs = stats.AvgMs + (ms - stats.AvgMs) * 0.1

	bot.Loco:OnPathResult(path, ok and reached == true, goal)
end

-- Called every server tick by the manager.
function Nav.Process()
	local now = CurTime()
	local stats = Nav.Stats
	if now - stats.WindowStart >= 1 then
		stats.ComputesPerSec = stats.Window / math.max(0.001, now - stats.WindowStart)
		stats.Window = 0
		stats.WindowStart = now
	end

	local queue = Nav.Queue
	if #queue == 0 then return end
	if not Nav.IsReady() then
		-- Drop everything; callers retry on their own schedule.
		for _, req in ipairs(queue) do
			Nav.Pending[req.Bot] = nil
		end
		Nav.Queue = {}
		return
	end

	local budget = math.max(1, AI.cv.path_budget:GetInt())
	local done = 0
	while done < budget and #queue > 0 do
		local req = table.remove(queue, 1)
		if not req.Cancelled and Nav.Pending[req.Bot] == req then
			Nav.Pending[req.Bot] = nil
			local bot = req.Bot
			if IsValid(bot.Player) and bot.Player:Alive() then
				Nav.ComputeNow(bot, req.Goal, req.Opts)
				done = done + 1
			end
		end
	end
end

---------------------------------------------------------------------------
-- Generation
---------------------------------------------------------------------------

-- Doors and breakables hide rooms from the generator; barricades must not be baked in.
function Nav.PrepareMapForGeneration()
	for _, class in ipairs({"func_door*", "prop_door*"}) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			ent:Fire("unlock", "", 0)
			ent:Fire("open", "", 0)
			ent:Fire("kill", "", 1)
		end
	end

	for _, class in ipairs({"prop_physics*", "func_breakable", "func_breakable_surf", "func_physbox*", "prop_ragdoll"}) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			ent:Remove()
		end
	end

	navmesh.ClearWalkableSeeds()

	local up = Vector(0, 0, 1)
	local lift = Vector(0, 0, 2)
	local seeds = 0
	local function Seed(pos)
		navmesh.AddWalkableSeed(pos + lift, up)
		seeds = seeds + 1
	end

	for _, teamid in ipairs({TEAM_HUMAN, TEAM_UNDEAD}) do
		for _, ent in ipairs(team.GetValidSpawnPoint(teamid)) do
			Seed(ent:GetPos())
		end
	end

	for _, ent in ipairs(ents.FindByClass("info_sigilnode")) do
		Seed(ent:GetPos())
	end

	for _, node in ipairs(GAMEMODE.ProfilerNodes or {}) do
		if isvector(node) then
			Seed(node)
		end
	end

	return seeds
end

function Nav.Generate(reason)
	if navmesh.IsGenerating() then
		return false, "already generating"
	end
	if Nav.GenerationStarted and CurTime() - Nav.GenerationStarted < 10 then
		return false, "generation is starting"
	end

	local seeds = Nav.PrepareMapForGeneration()
	Nav.GenerationStarted = CurTime()
	AI.Log("navmesh generation for %s (%s), %d walkable seeds. The server is unplayable until the map reloads.", game.GetMap(), reason or "manual", seeds)

	timer.Simple(1.5, function()
		navmesh.BeginGeneration()
	end)

	return true
end

hook.Add("InitPostEntity", "RelapseAI.NavAutogen", function()
	timer.Simple(10, function()
		if AI.IsSpawnOff and AI.IsSpawnOff() then return end
		if not GAMEMODE or not AI.cv.nav_autogen:GetBool() then return end
		if game.SinglePlayer() then return end
		if navmesh.IsLoaded() or navmesh.IsGenerating() then return end

		if AI.HasRealPlayer() then
			AI.Log("no navmesh for %s and players are online; run relapse_ai_nav_generate when ready", game.GetMap())
			return
		end

		Nav.Generate("autogen: empty server, no .nav")
	end)
end)

-- Post-processing once a mesh is available: ladders from the BSP, bots out of trigger_hurt volumes.
hook.Add("InitPostEntity", "RelapseAI.NavPostProcess", function()
	timer.Simple(2, function()
		if AI.IsSpawnOff and AI.IsSpawnOff() then return end
		if not navmesh.IsLoaded() then return end

		local okLadders, err = pcall(Nav.BuildLadders)
		if not okLadders then
			AI.Warn("nav ladder build failed: %s", tostring(err))
		end

		local marked = 0
		for _, hurt in ipairs(ents.FindByClass("trigger_hurt")) do
			local mins, maxs = hurt:WorldSpaceAABB()
			if mins and maxs then
				local pad = Vector(24, 24, 48)
				for _, area in ipairs(navmesh.FindInBox(mins - pad, maxs + pad)) do
					if IsValid(area) and not area:HasAttributes(NAV_MESH_AVOID) then
						area:SetAttributes(bit.bor(area:GetAttributes(), NAV_MESH_AVOID))
						marked = marked + 1
					end
				end
			end
		end

		if marked > 0 then
			AI.Log("marked %d nav areas near trigger_hurt as AVOID", marked)
		end
	end)
end)

-- Lua refresh after the map is already up: wire ladders again without waiting for a changelevel.
if navmesh.IsLoaded() then
	timer.Simple(1, function()
		if AI.IsSpawnOff and AI.IsSpawnOff() then return end
		if Nav.IsReady() then
			local ok, err = pcall(Nav.BuildLadders)
			if not ok then AI.Warn("nav ladder rebuild failed: %s", tostring(err)) end
		end
	end)
end

---------------------------------------------------------------------------
-- Console
---------------------------------------------------------------------------

local function Reply(pl, msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
	end
	print(msg)
end

local function IsAllowed(pl)
	return not IsValid(pl) or pl:IsSuperAdmin()
end

concommand.Add("relapse_ai_nav_status", function(pl)
	Reply(pl, string.format("[Relapse AI] navmesh: %s | climbables: %d | mesh ladders: %d (%d built this load) | blocked areas: %d | path computes/s: %.1f (avg %.2f ms)",
		Nav.Status(), #(Nav.Climbables or {}), #Nav.GetAllLadders(), #Nav.Ladders, table.Count(Nav.BlockedAreas), Nav.Stats.ComputesPerSec, Nav.Stats.AvgMs))
end)

concommand.Add("relapse_ai_nav_ladders", function(pl)
	if not IsAllowed(pl) then return end
	local listed = Nav.Climbables
	if not listed or #listed == 0 then listed = Nav.GetAllLadders() end
	for _, ladder in ipairs(listed) do
		if Nav.HasLadder(ladder) then
			local b, t = ladder:GetBottom(), ladder:GetTop()
			local n = Nav.LadderNormal(ladder)
			local nav = (not istable(ladder) and ladder) or ladder.Nav
			Reply(pl, string.format("  #%s bottom (%.0f %.0f %.0f) top z %.0f len %.0f width %.0f facing (%.0f %.0f) bottomArea=%s topFwd=%s topBehind=%s%s",
				tostring(ladder:GetID()), b.x, b.y, b.z, t.z, t.z - b.z, ladder:GetWidth(), n.x, n.y,
				(nav and IsValid(nav:GetBottomArea())) and "ok" or "-",
				(nav and IsValid(nav:GetTopForwardArea())) and "ok" or "-",
				(nav and IsValid(nav:GetTopBehindArea())) and "ok" or "-",
				(Nav.BadLadders[ladder:GetID()] or 0) > CurTime() and " BANNED" or ""))
		end
	end
end)

concommand.Add("relapse_ai_nav_generate", function(pl)
	if not IsAllowed(pl) then return end

	local ok, err = Nav.Generate(IsValid(pl) and ("command by " .. pl:Nick()) or "server console")
	if ok then
		Reply(pl, "[Relapse AI] navmesh generation started; the map reloads when it is done.")
	else
		Reply(pl, "[Relapse AI] navmesh generation not started: " .. tostring(err))
	end
end)
