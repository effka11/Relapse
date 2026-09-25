-- Relapse ladders: CONTENTS_LADDER is baked into the BSP. Open faces get a
-- thin SOLID_BBOX wall. Without E it is just a wall. E seats the player on
-- that wall; W/S climb the face centerline. The wall never opens.

local GM = GM or GAMEMODE

local LADDER_ENTS = {"func_ladder", "info_ladder", "func_useableladder"}
local PAD_NEAR = 48
local STAND_OFF = 24
local USE_RADIUS = 104
local HINT_FULL = 40
-- CLIP_BAND (40) is server-only, below the client return. Climb still has to
-- cross one skipped floor cell (~40u) on the same U-strip.
local CLIP_GAP = 48
local CLIP_STRIP_XY = 16
local CLIP_STRIP_XY_SQR = CLIP_STRIP_XY * CLIP_STRIP_XY
local CLIP_INWARD_DOT = 0.9
GM.RelapseLadderUseRadius = USE_RADIUS

-- Flat ladders get a long oval; square shafts stay near-round.
function GM.RelapseLadderOvalRadii(hx, hy)
	hx = math.abs(hx or 0)
	hy = math.abs(hy or 0)
	local short, long = math.min(hx, hy), math.max(hx, hy)
	if long < 4 then
		return 20, 20
	end
	if long < short * 1.2 then
		return hx + 20, hy + 20
	end
	local rs = short + 22
	local rl = math.max(rs + 16, long * 1.35 + 20)
	if hx >= hy then
		return rl, rs
	end
	return rs, rl
end
local TOP_PAD = 56
local BOT_PAD = 24
local COOLDOWN = 0.5
-- Hammer 1u = 1 in. A bit quicker than scale-matched real climb (~36).
-- Down is faster: gravity and skipping rungs.
-- Shift is not ground sprint (240/95). Sprint-up matches walk-down.
GM.HumanClimbSpeed = 52
GM.HumanClimbSpeedDown = 72
GM.HumanClimbSprintMul = GM.HumanClimbSpeedDown / GM.HumanClimbSpeed
local CLIMB_SPEED_UP = GM.HumanClimbSpeed
local CLIMB_SPEED_DOWN = GM.HumanClimbSpeedDown

function GM:GetHumanClimbSpeed(pl, down, sprint)
	local speed = down and (self.HumanClimbSpeedDown or 72) or (self.HumanClimbSpeed or 52)
	if IsValid(pl) and self.GetUpgradePercentMul then
		speed = speed * self:GetUpgradePercentMul(pl, "Climb")
	end
	if sprint then
		speed = speed * (self.HumanClimbSprintMul or (72 / 52))
	end
	return speed
end
-- Hybrid: horizon keeps W = up. Commit to view-follow only when looking
-- clearly down; stay there until the look returns near the horizon.
local CLIMB_PITCH_ENTER = 45
local CLIMB_PITCH_EXIT = 12
-- Jump-off: a short hop toward look, not a standing pop and not a leap.
local JUMP_OFF_XY = 140
local JUMP_OFF_Z = 0.75

local WALK = MOVETYPE_WALK
local LADDER = MOVETYPE_LADDER
local NOCLIP = MOVETYPE_NOCLIP
local FLY = MOVETYPE_FLY

local P_ExitLadder = FindMetaTable("Player").ExitLadder
local MASK_PLAYERSOLID = MASK_PLAYERSOLID
local MASK_SOLID_BRUSHONLY = MASK_SOLID_BRUSHONLY

local cache = {}
local cacheUntil = 0

local function LadderBoxes()
	local now = CurTime()
	if cacheUntil > now then return cache end
	cacheUntil = now + 2
	cache = {}
	for i = 1, #LADDER_ENTS do
		local list = ents.FindByClass(LADDER_ENTS[i])
		for j = 1, #list do
			local ent = list[j]
			if IsValid(ent) then
				local mins, maxs = ent:WorldSpaceAABB()
				if mins and maxs then
					cache[#cache + 1] = {mins = mins, maxs = maxs}
				end
			end
		end
	end
	if SERVER then
		local AI = RelapseAI
		local vols = AI and AI.Nav and AI.Nav.LadderVolume
		if vols then
			for _, vol in pairs(vols) do
				if vol.mins and vol.maxs then
					cache[#cache + 1] = vol
				end
			end
		end
	end
	return cache
end

local function InBox(mins, maxs, x, y, z, pad)
	return x >= mins.x - pad and x <= maxs.x + pad
		and y >= mins.y - pad and y <= maxs.y + pad
		and z >= mins.z - pad and z <= maxs.z + pad
end

-- World brushes keep CONTENTS_LADDER in the BSP. The global can be 0 if a
-- load order misses it; the Source bit is always 0x20000000.
local LADDER_BITS = CONTENTS_LADDER
if not LADDER_BITS or LADDER_BITS == 0 then
	LADDER_BITS = 0x20000000
end

local function PointHasLadder(x, y, z)
	if bit.band(util.PointContents(Vector(x, y, z)), LADDER_BITS) ~= 0 then
		return true
	end
end

local function OverlappingLadder(pos)
	if PointHasLadder(pos.x, pos.y, pos.z)
		or PointHasLadder(pos.x, pos.y, pos.z + 8)
		or PointHasLadder(pos.x, pos.y, pos.z + 36)
		or PointHasLadder(pos.x, pos.y, pos.z + 56) then
		return true
	end
	local boxes = LadderBoxes()
	for i = 1, #boxes do
		local b = boxes[i]
		if InBox(b.mins, b.maxs, pos.x, pos.y, pos.z + 36, 4) then
			return true
		end
	end
	return false
end

local function NearLadder(pl)
	if not IsValid(pl) then return false end
	local pos = pl:GetPos()
	if OverlappingLadder(pos) then return true end
	local z = pos.z + 36
	for i = 0, 7 do
		local a = i * 0.78539816339745
		if PointHasLadder(pos.x + math.cos(a) * PAD_NEAR, pos.y + math.sin(a) * PAD_NEAR, z) then
			return true
		end
	end
	local boxes = LadderBoxes()
	for i = 1, #boxes do
		local b = boxes[i]
		if InBox(b.mins, b.maxs, pos.x, pos.y, z, PAD_NEAR) then
			return true
		end
	end
	return false
end

local function Holding(pl)
	return pl.RelapseLadderHold or pl:GetNW2Bool("RelapseLadderHold", false)
end

local function Outward(clip)
	local inward = clip.GetInward and clip:GetInward()
	if not inward or inward:LengthSqr() < 0.01 then
		return Vector(0, 0, 0)
	end
	return Vector(-inward.x, -inward.y, 0):GetNormalized()
end

-- Face normal points into the wall when the slab was built on the back of the
-- volume. The player pressed E from the open side: seat that way.
local function SideDir(clip, pl)
	local out = Outward(clip)
	if out:LengthSqr() < 0.01 or not IsValid(pl) then return out end
	local pos = clip:GetPos()
	local p = pl:GetPos()
	if (p.x - pos.x) * out.x + (p.y - pos.y) * out.y < 0 then
		return Vector(-out.x, -out.y, 0)
	end
	return out
end

local function ClipWorldBox(clip)
	local wm, wx = clip:WorldSpaceAABB()
	if wm and wx and (wx.z - wm.z) > 8 then
		return wm, wx
	end
	local pos = clip:GetPos()
	return pos + clip:GetBoxMins(), pos + clip:GetBoxMaxs()
end

-- Same U-column: NW inward is quantized, next column is ~20-40u away.
function GM.RelapseLadderSameStrip(a, b)
	if not IsValid(a) or not IsValid(b) then return false end
	if a == b then return true end
	local ia = a.GetInward and a:GetInward()
	local ib = b.GetInward and b:GetInward()
	if not ia or not ib then return false end
	if ia:LengthSqr() < 0.01 or ib:LengthSqr() < 0.01 then return false end
	ia = Vector(ia.x, ia.y, 0)
	ib = Vector(ib.x, ib.y, 0)
	ia:Normalize()
	ib:Normalize()
	if ia:Dot(ib) < CLIP_INWARD_DOT then return false end
	local pa, pb = a:GetPos(), b:GetPos()
	local dx, dy = pa.x - pb.x, pa.y - pb.y
	return dx * dx + dy * dy <= CLIP_STRIP_XY_SQR
end

local function ClipZRange(clip)
	local wmins, wmaxs = ClipWorldBox(clip)
	local zmin, zmax = wmins.z, wmaxs.z - 2
	if zmax < zmin then zmax = zmin end
	return zmin, zmax
end

local function SeatXY(clip, extra, pl)
	local pos = clip:GetPos()
	local out = SideDir(clip, pl)
	local off = STAND_OFF + (extra or 0)
	return pos.x + out.x * off, pos.y + out.y * off
end

local function SeatFromClip(clip, z, extra, pl)
	local x, y = SeatXY(clip, extra, pl)
	local zmin, zmax = ClipZRange(clip)
	return Vector(x, y, math.Clamp(z, zmin, zmax)), zmin, zmax
end

-- zmin/zmax of this strip, including floor-cell gaps of one CLIP_GAP.
local function ClimbZRange(clip)
	local zmin, zmax = ClipZRange(clip)
	local list = ents.FindByClass("relapse_ladder_clip")
	local seen = {[clip] = true}
	local added = true
	while added do
		added = false
		for i = 1, #list do
			local other = list[i]
			if IsValid(other) and not seen[other] and GM.RelapseLadderSameStrip(clip, other) then
				local oz0, oz1 = ClipZRange(other)
				local gap
				if oz1 < zmin then
					gap = zmin - oz1
				elseif oz0 > zmax then
					gap = oz0 - zmax
				else
					gap = 0
				end
				if gap <= CLIP_GAP then
					seen[other] = true
					if oz0 < zmin then zmin = oz0 end
					if oz1 > zmax then zmax = oz1 end
					added = true
				end
			end
		end
	end
	return zmin, zmax
end

local function ClipNearest(clip, pos)
	local mins, maxs = ClipWorldBox(clip)
	return Vector(
		math.Clamp(pos.x, mins.x, maxs.x),
		math.Clamp(pos.y, mins.y, maxs.y),
		math.Clamp(pos.z + 36, mins.z - BOT_PAD, maxs.z + TOP_PAD)
	)
end

-- World brushes only. The 4u climb slab is not a wall; nailed props are not.
local function WorldWallBlocks(pl, dest)
	if not IsValid(pl) then return true end
	local eye = pl.EyePos and pl:EyePos() or (pl:GetPos() + Vector(0, 0, 64))
	local dir = dest - eye
	local len = dir:Length()
	if len < 12 then return false end
	dir:Mul(1 / len)
	local tr = util.TraceLine({
		start = eye,
		endpos = dest - dir * 6,
		mask = MASK_SOLID_BRUSHONLY,
		filter = function(ent)
			return ent == pl or (IsValid(ent) and ent.RelapseLadderClip)
		end,
	})
	return tr.Hit and not tr.HitSky
end

local function HintAlpha(dist)
	if dist >= USE_RADIUS then return 0 end
	if dist <= HINT_FULL then return 1 end
	return 1 - (dist - HINT_FULL) / (USE_RADIUS - HINT_FULL)
end

-- Nearest climb face within radius, both sides, top landing included, not through world.
local function QueryClip(pl, radius)
	if not IsValid(pl) then return end
	local pos = pl:GetPos()
	local eye = pl.EyePos and pl:EyePos() or (pos + Vector(0, 0, 64))
	local rSqr = radius * radius
	local list = ents.FindByClass("relapse_ladder_clip")
	local best, bestD, bestNearest
	for i = 1, #list do
		local ent = list[i]
		if IsValid(ent) then
			local nearest = ClipNearest(ent, pos)
			local dSqr = math.min(pos:DistToSqr(nearest), eye:DistToSqr(nearest))
			if dSqr <= rSqr and (not bestD or dSqr < bestD) and not WorldWallBlocks(pl, nearest) then
				best, bestD, bestNearest = ent, dSqr, nearest
			end
		end
	end
	if not best then return end
	return best, math.sqrt(bestD), bestNearest
end

local function NearestClimbClip(pl, pos)
	return QueryClip(pl, USE_RADIUS)
end

local function SetClip(pl, clip)
	pl.RelapseLadderClipEnt = clip
	if SERVER then
		if IsValid(clip) then
			pl:SetNW2Entity("RelapseLadderClip", clip)
			if clip.CollisionRulesChanged then
				clip:CollisionRulesChanged()
			end
		else
			pl:SetNW2Entity("RelapseLadderClip", NULL)
		end
	end
end

local function GetClip(pl)
	local clip = pl.RelapseLadderClipEnt
	if IsValid(clip) then return clip end
	clip = pl.GetNW2Entity and pl:GetNW2Entity("RelapseLadderClip")
	if IsValid(clip) then
		pl.RelapseLadderClipEnt = clip
		return clip
	end
end

local function SetHold(pl, hold)
	hold = hold and true or false
	pl.RelapseLadderHold = hold
	if SERVER then
		if pl:GetNW2Bool("RelapseLadderHold", false) ~= hold then
			pl:SetNW2Bool("RelapseLadderHold", hold)
		end
		if pl.CollisionRulesChanged then
			pl:CollisionRulesChanged()
		end
	end
	if not hold then
		SetClip(pl, nil)
		if SERVER then
			pl.RelapseLadderCanStep = false
			pl:SetNW2Bool("RelapseLadderCanStep", false)
		end
	end
end

local function KickOff(pl)
	if P_ExitLadder then
		P_ExitLadder(pl)
	end
	local mt = pl:GetMoveType()
	if mt == LADDER then
		pl:SetMoveType(WALK)
	end
end

-- FLY still collides with world: embed depth = stronger unstick. Hold uses
-- NOCLIP so the engine does not depenetrate hatches. Admin RelapseNoclip
-- is left alone.
local function SetClimbing(pl, on)
	if not IsValid(pl) then return end
	if pl.RelapseNoclip then return end
	if on then
		if pl:GetMoveType() ~= NOCLIP then
			pl:SetMoveType(NOCLIP)
		end
		if pl.SetGroundEntity then
			pl:SetGroundEntity(NULL)
		end
		if pl.RemoveFlags then
			pl:RemoveFlags(FL_ONGROUND)
		end
	elseif pl:GetMoveType() == NOCLIP or pl:GetMoveType() == FLY or pl:GetMoveType() == LADDER then
		pl:SetMoveType(WALK)
	end
end

function GM:RelapseLadderIsNear(pl)
	if not IsValid(pl) then return false end
	if Holding(pl) then return true end
	return QueryClip(pl, USE_RADIUS) ~= nil
end

-- TryHumanPickup is 64u. Engine use / FindUseEntity is 90u. Ladder E must
-- not step off for a prop in that cone, or the teleport then picks it up.
local PICKUP_DIST = 64
local PICKUP_USE_DIST = 90

local function PickupTraceFilter(pl)
	return function(ent)
		if ent == pl then return false end
		if IsValid(ent) and (ent.RelapseLadderClip or ent.IgnoreTraces) then return false end
		return true
	end
end

local function PickupCandidate(pl, ent, maxDist)
	if not IsValid(pl) or not IsValid(ent) then return false end
	if ent.m_NoPickup or ent.RelapseLadderClip then return false end
	if ent.IsNailed and ent:IsNailed() then return false end
	if ent.GetHolder and IsValid(ent:GetHolder()) then return false end
	if pl.GetGroundEntity and pl:GetGroundEntity() == ent then return false end
	local cls = ent:GetClass() or ""
	local ok = string.sub(cls, 1, 12) == "prop_physics" or string.sub(cls, 1, 12) == "func_physbox"
	if not ok and ent.HumanHoldable then
		ok = ent:HumanHoldable(pl) and true or false
	end
	if not ok then return false end
	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
	local phys = ent:GetPhysicsObject()
	if not phys or not phys:IsValid() then return false end
	local massMul = pl.PropCarryCapacityMul or 1
	if phys:GetMass() > CARRY_MAXIMUM_MASS * massMul then return false end
	if ent:OBBMins():Length() + ent:OBBMaxs():Length() > CARRY_MAXIMUM_VOLUME * massMul then return false end
	maxDist = maxDist or PICKUP_DIST
	local shoot = pl:GetShootPos()
	if shoot:DistToSqr(ent:NearestPoint(shoot)) > maxDist * maxDist then return false end
	return true
end

-- Any holdable in use reach. No aim cone: a crate on the landing is beside
-- the view, and KeyPress uses an unfiltered 64u trace the cone would miss.
local function AimedPickup(pl)
	if not pl.TraceLine then return false end
	if PickupCandidate(pl, pl:TraceLine(PICKUP_DIST).Entity, PICKUP_DIST) then
		return true
	end
	local filter = PickupTraceFilter(pl)
	if PickupCandidate(pl, pl:TraceLine(PICKUP_USE_DIST, nil, filter).Entity, PICKUP_USE_DIST) then
		return true
	end
	if pl.GetUseEntity and PickupCandidate(pl, pl:GetUseEntity(), PICKUP_USE_DIST) then
		return true
	end
	local shoot = pl:GetShootPos()
	local list = ents.FindInSphere(shoot, PICKUP_USE_DIST)
	for i = 1, #list do
		if PickupCandidate(pl, list[i], PICKUP_USE_DIST) then
			return true
		end
	end
	return false
end

-- Holding a prop, or E would pick one up: ladder must not eat the press.
function GM:RelapseLadderUseBlocked(pl)
	if not IsValid(pl) then return false end
	if pl.IsBot and pl:IsBot() then return false end
	if pl:Team() ~= TEAM_HUMAN then return false end
	if pl.IsHolding and pl:IsHolding() then return true end
	if pl.NoObjectPickup then return false end
	if self.ZombieEscape then return false end
	if pl.GetInfo and pl:GetInfo("zs_nopickupprops") == "1" then return false end
	return AimedPickup(pl)
end

function GM:RelapseLadderTakesUse(pl)
	if not IsValid(pl) then return false end
	if (pl.RelapseLadderAteUse or 0) >= CurTime() then return true end
	if self:RelapseLadderUseBlocked(pl) then return false end
	return self:RelapseLadderIsNear(pl)
end

-- kind, unused pos, alpha 0-1, clip. Hidden while climbing.
function GM:RelapseLadderHintState(pl)
	if not IsValid(pl) then return end
	if Holding(pl) then return end
	if self:RelapseLadderUseBlocked(pl) then return end
	local clip, dist = QueryClip(pl, USE_RADIUS)
	if not clip then return end
	return "climb", nil, HintAlpha(dist), clip
end

-- Distance to the climb face while E would seat. Nil if out of range or blocked.
function GM:RelapseLadderUseDist(pl)
	if not IsValid(pl) or Holding(pl) then return end
	local _, dist = QueryClip(pl, USE_RADIUS)
	return dist
end

function GM:RelapseLadderRelease(pl)
	if not IsValid(pl) then return end
	SetHold(pl, false)
	pl.RelapseLadderWish = 0
	pl.RelapseLadderViewFlip = false
	pl.RelapseLadderSeatExtra = nil
	pl.RelapseLadderCooldown = CurTime() + COOLDOWN
	SetClimbing(pl, false)
	KickOff(pl)
	if SERVER then
		pl.RelapseLadderCanStep = false
		pl:SetNW2Bool("RelapseLadderCanStep", false)
	end
end

local function Release(pl)
	GAMEMODE:RelapseLadderRelease(pl)
end

local function ClimbFilter(pl)
	return function(ent)
		return ent == pl or (IsValid(ent) and ent.RelapseLadderClip)
	end
end

local function IsGhostableProp(ent)
	if not IsValid(ent) or ent.RelapseLadderClip then return false end
	if ent:IsPlayer() or ent:IsWeapon() then return false end
	if not ent:IsSolid() or ent:GetSolid() == SOLID_NONE then return false end
	if ent.IsBarricadeProp and ent:IsBarricadeProp() then return true end
	if ent:GetMoveType() == MOVETYPE_VPHYSICS then return true end
	local cls = ent:GetClass() or ""
	return string.sub(cls, 1, 12) == "prop_physics" or string.sub(cls, 1, 12) == "func_physbox"
end

local function LadderGhostOn(pl)
	return pl.RelapseLadderGhosting or (pl.GetNW2Bool and pl:GetNW2Bool("RelapseLadderGhosting", false))
end

local function EnableLadderGhost(pl)
	if not IsValid(pl) then return end
	pl.RelapseLadderGhosting = true
	pl.FirstGhostThink = false
	if SERVER then
		pl:SetNW2Bool("RelapseLadderGhosting", true)
	end
	if not pl.SetBarricadeGhosting then return end
	if not pl:GetBarricadeGhosting() then
		pl:SetBarricadeGhosting(true)
	elseif pl.CollisionRulesChanged then
		pl:CollisionRulesChanged()
	end
end

local function HullTouchesGhostable(pl, origin)
	local mins, maxs = pl:GetHull()
	local list = ents.FindInBox(origin + mins, origin + maxs)
	for i = 1, #list do
		local ent = list[i]
		if ent ~= pl and IsGhostableProp(ent) then return true end
	end
	return false
end

-- true = hit (same as GetDynamicTraceFilter). Skip self, the climb slab,
-- and ghostable props only while phasing.
local function ClimbMoveFilter(pl, throughProps)
	return function(ent)
		if ent == pl then return false end
		if IsValid(ent) and ent.RelapseLadderClip then return false end
		if (throughProps or LadderGhostOn(pl)) and IsGhostableProp(ent) then return false end
		return true
	end
end

local function HullTrace(pl, start, dest, throughProps, mins, maxs)
	if not mins or not maxs then
		mins, maxs = pl:GetHull()
	end
	return util.TraceHull({
		start = start,
		endpos = dest,
		mins = mins,
		maxs = maxs,
		filter = ClimbMoveFilter(pl, throughProps),
		mask = MASK_PLAYERSOLID,
	})
end

local function PlayerHulls(pl)
	local sm, sx = pl:GetHull()
	if pl.GetHullDuck then
		return sm, sx, pl:GetHullDuck()
	end
	return sm, sx, sm, sx
end

local function SweepTo(pl, from, dest, ghost, mins, maxs)
	local tr = HullTrace(pl, from, dest, ghost, mins, maxs)
	if not ghost and tr.StartSolid and IsGhostableProp(tr.Entity) then
		EnableLadderGhost(pl)
		ghost = true
		tr = HullTrace(pl, from, dest, true, mins, maxs)
	end
	return tr, ghost
end

local function DepenetrateOutward(pl, origin, clip, ghost, mins, maxs)
	local tr
	tr, ghost = SweepTo(pl, origin, origin, ghost, mins, maxs)
	if not tr.StartSolid then return origin, ghost end
	if not IsValid(clip) then return origin, ghost end
	local out = SideDir(clip, pl)
	if out:LengthSqr() < 0.01 then return origin, ghost end
	for d = 2, 16, 2 do
		local try = Vector(origin.x + out.x * d, origin.y + out.y * d, origin.z)
		local t
		t, ghost = SweepTo(pl, try, try, ghost, mins, maxs)
		if not t.StartSolid then return try, ghost end
	end
	return origin, ghost
end

-- Keep mount XY. Extra stays whatever TrySeat set. Closed floors stop in
-- ClimbWorldStop, not here.
local function ClimbSqueeze(pl, clip, origin, destZ, ghost)
	return Vector(origin.x, origin.y, destZ), ghost
end

local function BrushOnlyFilter(ent)
	return not (IsValid(ent) and ent.RelapseLadderClip)
end

-- A rung lip ends beside the wall. A real floor still exists a step further
-- out into the room.
local function ShelfContinues(hitPos, out)
	local ahead = Vector(hitPos.x + out.x * 28, hitPos.y + out.y * 28, hitPos.z + 12)
	local tr = util.TraceLine({
		start = ahead,
		endpos = Vector(ahead.x, ahead.y, hitPos.z - 16),
		mask = MASK_SOLID_BRUSHONLY,
		filter = BrushOnlyFilter,
	})
	if tr.StartSolid then return true end
	if not tr.Hit or tr.HitSky then return false end
	if math.abs(tr.HitNormal.z or 0) <= 0.5 then return false end
	return math.abs(tr.HitPos.z - hitPos.z) <= 12
end

-- NOCLIP hold ignores world. Stop Z only if a brush line from air hits a
-- floor/ceiling. A narrow lip on the wall is a step, not that floor.
-- Vertical rim and StartSolid in the slab do not stop.
local function ClimbWorldStop(origin, dest, hullZ, pl, clip)
	if not origin or not dest or dest.z == origin.z then return dest end
	local h = dest.z > origin.z and (hullZ or 72) or 0
	local tr = util.TraceLine({
		start = Vector(origin.x, origin.y, origin.z + h),
		endpos = Vector(dest.x, dest.y, dest.z + h),
		mask = MASK_SOLID_BRUSHONLY,
		filter = BrushOnlyFilter,
	})
	if tr.StartSolid then return dest end
	if not tr.Hit or tr.HitSky then return dest end
	local n = tr.HitNormal
	if not n or math.abs(n.z) <= 0.5 then return dest end
	-- The ladder model keeps going through the navmesh landing. That lip is
	-- not an exit. The floor under the column still stops a descent, or the
	-- hold walks into the ground.
	if IsValid(clip) then
		local zBot, zTop = ClipZRange(clip)
		if dest.z > origin.z then
			if tr.HitPos.z < zTop - 16 then return dest end
		elseif tr.HitPos.z > zBot + 16 then
			return dest
		end
	end
	local out = IsValid(clip) and SideDir(clip, pl) or nil
	if out and out:LengthSqr() > 0.01 and not ShelfContinues(tr.HitPos, out) then
		return dest
	end
	return Vector(dest.x, dest.y, origin.z)
end

local function UnstickForLeave(pl, origin, clip)
	if not origin then return origin end
	local sm, sx, dm, dx = PlayerHulls(pl)
	origin = DepenetrateOutward(pl, origin, clip, true, sm, sx)
	if not HullTrace(pl, origin, origin, true, sm, sx).StartSolid then return origin end
	origin = DepenetrateOutward(pl, origin, clip, true, dm, dx)
	if not HullTrace(pl, origin, origin, true, dm, dx).StartSolid then return origin end
	if not IsValid(clip) then return origin end
	for _, extra in ipairs({0, 8, 16}) do
		local x, y = SeatXY(clip, extra, pl)
		local try = Vector(x, y, origin.z)
		local tr = HullTrace(pl, try, try, true, sm, sx)
		if not tr.StartSolid then return try end
		tr = HullTrace(pl, try, try, true, dm, dx)
		if not tr.StartSolid then return try end
	end
	return origin
end

-- Frozen VPHYSICS is not a world wall: the controller sinks a few units.
-- Sweep and stop on the surface, then drop inbound speed.
local function ClipMoveAgainstProps(pl, mv)
	if LadderGhostOn(pl) then return end
	local origin = mv:GetOrigin()
	local mins, maxs = pl:GetHull()
	local vel = mv:GetVelocity()
	local dt = FrameTime()
	if dt <= 0 then dt = engine.TickInterval() end
	local filt = ClimbMoveFilter(pl, false)

	local stuck = util.TraceHull({
		start = origin,
		endpos = origin,
		mins = mins,
		maxs = maxs,
		filter = filt,
		mask = MASK_PLAYERSOLID,
	})
	if stuck.StartSolid then
		local ent = stuck.Entity
		local away
		if IsGhostableProp(ent) then
			away = origin - ent:WorldSpaceCenter()
		else
			away = Vector(-vel.x, -vel.y, 0)
		end
		away.z = 0
		if away:LengthSqr() < 1 then
			away = Vector(-vel.x, -vel.y, 0)
		end
		if away:LengthSqr() < 1 then return end
		away:Normalize()
		for d = 2, 72, 2 do
			local try = origin + away * d
			local tr = util.TraceHull({
				start = try,
				endpos = try,
				mins = mins,
				maxs = maxs,
				filter = filt,
				mask = MASK_PLAYERSOLID,
			})
			if not tr.StartSolid then
				mv:SetOrigin(try)
				local into = -away
				local vn = vel:Dot(into)
				if vn > 0 then
					mv:SetVelocity(vel - into * vn)
				end
				return
			end
		end
		return
	end

	local dest = origin + vel * dt
	if dest:DistToSqr(origin) < 0.0001 then return end
	local tr = util.TraceHull({
		start = origin,
		endpos = dest,
		mins = mins,
		maxs = maxs,
		filter = filt,
		mask = MASK_PLAYERSOLID,
	})
	if not tr.Hit or tr.StartSolid or not IsGhostableProp(tr.Entity) then return end
	mv:SetOrigin(tr.HitPos)
	local n = tr.HitNormal
	if n:LengthSqr() < 0.01 then
		n = Vector(-vel.x, -vel.y, 0)
		if n:LengthSqr() < 0.01 then return end
		n:Normalize()
	end
	local vn = vel:Dot(n)
	if vn < 0 then
		mv:SetVelocity(vel - n * vn)
	end
end

local function TrySeat(pl, clip, z)
	local sm, sx, dm, dx = PlayerHulls(pl)
	local clipPos = clip:GetPos()
	local dir = SideDir(clip, pl)
	local p = pl:GetPos()
	local along = (p.x - clipPos.x) * dir.x + (p.y - clipPos.y) * dir.y
	local function try(extra, mins, maxs)
		local seat = SeatFromClip(clip, z, extra, pl)
		if HullTrace(pl, seat, seat, true, mins, maxs).StartSolid then return end
		pl.RelapseLadderSeatExtra = extra ~= 0 and extra or nil
		return seat
	end
	-- 0/8/16 stay on the face. Further steps only toward the player, and only
	-- while the face point is still inside the wall. Never keep a solid seat.
	local maxExtra = 16
	if along > STAND_OFF + maxExtra then
		maxExtra = along - STAND_OFF
	end
	local extra = 0
	while extra <= maxExtra + 0.01 do
		local seat = try(extra, sm, sx) or try(extra, dm, dx)
		if seat then return seat end
		if extra >= maxExtra - 0.01 then break end
		local nextExtra = extra + 8
		if nextExtra > maxExtra then nextExtra = maxExtra end
		if nextExtra <= extra then break end
		extra = nextExtra
	end
	local stay = Vector(p.x, p.y, z)
	local zmin, zmax = ClipZRange(clip)
	stay.z = math.Clamp(stay.z, zmin, zmax)
	if not HullTrace(pl, stay, stay, true, sm, sx).StartSolid
		or not HullTrace(pl, stay, stay, true, dm, dx).StartSolid then
		pl.RelapseLadderSeatExtra = nil
		return stay
	end
end

-- Player is at/slightly above a landing: E steps onto it. Side first, then back.
local PLAT_BELOW = 48
local PLAT_ABOVE = 8
local STEP_MIN = 20

local function StandHull(pl, start, dest)
	local mins, maxs = pl:GetHull()
	return util.TraceHull({
		start = start,
		endpos = dest,
		mins = mins,
		maxs = maxs,
		filter = ClimbFilter(pl),
		mask = MASK_PLAYERSOLID,
	})
end

local PASSABLE_GROUP = {
	[COLLISION_GROUP_DEBRIS] = true,
	[COLLISION_GROUP_DEBRIS_TRIGGER] = true,
	[COLLISION_GROUP_PROJECTILE] = true,
	[COLLISION_GROUP_IN_VEHICLE] = true,
	[COLLISION_GROUP_WEAPON] = true,
}

local function BlocksLanding(ent, pl)
	if not IsValid(ent) or ent == pl then return false end
	if ent.RelapseLadderClip then return false end
	if ent:IsPlayer() or ent:IsWeapon() then return false end
	if ent.IsProjectile and ent:IsProjectile() then return false end
	if not ent:IsSolid() then return false end
	if ent:GetSolid() == SOLID_NONE then return false end
	local cg = ent:GetCollisionGroup()
	if cg and PASSABLE_GROUP[cg] then return false end
	return true
end

local function PropBlocks(pl, dest)
	local mins, maxs = pl:GetHull()
	local lo = dest + Vector(mins.x + 2, mins.y + 2, 4)
	local hi = dest + Vector(maxs.x - 2, maxs.y - 2, maxs.z - 4)
	local boxmin = Vector(math.min(lo.x, hi.x), math.min(lo.y, hi.y), math.min(lo.z, hi.z))
	local boxmax = Vector(math.max(lo.x, hi.x), math.max(lo.y, hi.y), math.max(lo.z, hi.z))
	local list = ents.FindInBox(boxmin, boxmax)
	for i = 1, #list do
		if BlocksLanding(list[i], pl) then return true end
	end
	local tr = StandHull(pl, dest + Vector(0, 0, 36), dest)
	if tr.StartSolid then return true end
	if tr.Hit and not tr.HitWorld and BlocksLanding(tr.Entity, pl) then return true end
	return false
end

-- Body corridor, not the full stand hull. Feet at z+0 catch an 8u lip and a
-- full-height trace asks for headroom the landing does not owe. Railings sit
-- in this band. Ladder slabs are not a wall.
local function StepPathClear(pl, from, dest, clip)
	local hm, hx = pl:GetHull()
	local mins = Vector(hm.x, hm.y, 8)
	local maxs = Vector(hx.x, hx.y, 48)
	local function sweep(start)
		return util.TraceHull({
			start = start,
			endpos = dest,
			mins = mins,
			maxs = maxs,
			filter = function(ent)
				if ent == pl then return false end
				if IsValid(ent) and ent.RelapseLadderClip then return false end
				return true
			end,
			mask = MASK_PLAYERSOLID,
		})
	end
	local tr = sweep(from)
	if tr.StartSolid and IsValid(clip) then
		local out = SideDir(clip, pl)
		if out:LengthSqr() > 0.01 then
			tr = sweep(from + out * 8)
		end
	end
	if tr.StartSolid then return false end
	if not tr.Hit then return true end
	return dest:DistToSqr(tr.HitPos) <= 64 and (tr.HitNormal.z or 0) >= 0.6
end

local function PlatformAt(pl, x, y, z)
	local tr = util.TraceHull({
		start = Vector(x, y, z + 16),
		endpos = Vector(x, y, z - PLAT_BELOW),
		mins = Vector(-12, -12, 0),
		maxs = Vector(12, 12, 8),
		filter = ClimbFilter(pl),
		mask = MASK_PLAYERSOLID,
	})
	if not tr.Hit or tr.HitSky or tr.StartSolid then return end
	if (tr.HitNormal.z or 0) < 0.6 then return end
	if IsValid(tr.Entity) and BlocksLanding(tr.Entity, pl) then return end
	local fz = tr.HitPos.z
	if fz > z + PLAT_ABOVE then return end
	if z - fz > PLAT_BELOW then return end
	local dest = Vector(x, y, fz + 2)
	if PropBlocks(pl, dest) then return end
	local stuck = StandHull(pl, dest, dest)
	if stuck.StartSolid then return end
	return dest
end

local function FindPlatformStep(pl, clip, pos)
	if not IsValid(clip) then return end
	local out = SideDir(clip, pl)
	if out:LengthSqr() < 0.01 then return end
	local side = Vector(-out.y, out.x, 0)
	local z = pos.z
	local maxDist = 72
	local maxSqr = maxDist * maxDist

	local best, bestRank, bestDist
	local function consider(x, y, rank)
		local dx, dy = x - pos.x, y - pos.y
		local d2 = dx * dx + dy * dy
		if d2 < STEP_MIN * STEP_MIN or d2 > maxSqr then return end
		local dest = PlatformAt(pl, x, y, z)
		if not dest or not StepPathClear(pl, pos, dest, clip) then return end
		local dist = dest:DistToSqr(pos)
		if dist > maxSqr then return end
		local near = 24 * 24
		if not best then
			best, bestRank, bestDist = dest, rank, dist
			return
		end
		if rank > bestRank then
			if dist < bestDist + near then
				best, bestRank, bestDist = dest, rank, dist
			end
			return
		end
		if rank == bestRank and dist < bestDist then
			best, bestRank, bestDist = dest, rank, dist
			return
		end
		if rank < bestRank and dist + near < bestDist then
			best, bestRank, bestDist = dest, rank, dist
		end
	end

	-- Nearby side first, then back. Distances are a step, not another landing.
	for _, dist in ipairs({40, 56}) do
		consider(pos.x + side.x * dist, pos.y + side.y * dist, 2)
		consider(pos.x - side.x * dist, pos.y - side.y * dist, 2)
	end
	for _, dist in ipairs({40, 56, 72}) do
		consider(pos.x + out.x * dist, pos.y + out.y * dist, 1)
	end
	return best
end

-- Landing dest if E would step off this climb. Nil if no nearby platform
-- or the body corridor to it is blocked.
function GM:RelapseLadderStepOff(pl, pos)
	if not IsValid(pl) or not Holding(pl) then return end
	pos = pos or pl:GetPos()
	return FindPlatformStep(pl, GetClip(pl) or NearestClimbClip(pl, pos), pos)
end

hook.Add("Initialize", "RelapseLadder", function()
	if SERVER then
		RunConsoleCommand("sv_ladder_useonly", "1")
	end
end)

hook.Add("PlayerSpawn", "RelapseLadder", function(pl)
	SetHold(pl, false)
	pl.RelapseLadderCooldown = 0
	pl.RelapseLadderUseDown = false
	pl.RelapseLadderJumpDown = false
	pl.RelapseLadderSeatExtra = nil
	if SERVER then
		pl.RelapseLadderCanStep = false
		pl:SetNW2Bool("RelapseLadderCanStep", false)
	end
end)

hook.Add("PlayerDeath", "RelapseLadder", function(pl)
	Release(pl)
end)

local function ViewFollowDown(pl, pitch)
	if pl.IsBot and pl:IsBot() then return false end
	local flip = pl.RelapseLadderViewFlip and true or false
	pitch = pitch or 0
	if flip then
		if pitch < CLIMB_PITCH_EXIT then flip = false end
	elseif pitch > CLIMB_PITCH_ENTER then
		flip = true
	end
	pl.RelapseLadderViewFlip = flip
	return flip
end

local function JumpOffVelocity(pl, cmd)
	local ang = (cmd and cmd.GetViewAngles and cmd:GetViewAngles()) or pl:EyeAngles()
	local fwd = ang:Forward()
	local hx, hy = fwd.x, fwd.y
	local hlen = math.sqrt(hx * hx + hy * hy)
	if hlen < 0.08 then
		local yaw = math.rad(ang.y)
		hx, hy = math.cos(yaw), math.sin(yaw)
	else
		hx, hy = hx / hlen, hy / hlen
	end
	local jp = DEFAULT_JUMP_POWER or 185
	local gm = GAMEMODE or GM
	if gm and gm.GetJumpPercentMul then
		jp = jp * gm:GetJumpPercentMul(pl)
	else
		jp = jp * (pl.JumpPowerMul or 1)
	end
	return Vector(hx * JUMP_OFF_XY, hy * JUMP_OFF_XY, jp * JUMP_OFF_Z)
end

local function ClimbWishFromInput(pl, buttons, analog, pitch, holding)
	local fwd = 0
	if bit.band(buttons or 0, IN_FORWARD) ~= 0 then
		fwd = 1
	elseif bit.band(buttons or 0, IN_BACK) ~= 0 then
		fwd = -1
	elseif analog then
		if analog > 1 then
			fwd = 1
		elseif analog < -1 then
			fwd = -1
		end
	end
	if fwd == 0 then return 0 end
	if holding and ViewFollowDown(pl, pitch) then
		return -fwd
	end
	return fwd
end

local function JumpOff(pl, mv, cmd)
	pl.RelapseLadderGhostHop = CurTime() + 0.45
	pl.RelapseLadderPropClipUntil = CurTime() + 1
	pl.FirstGhostThink = false
	local origin = UnstickForLeave(pl, mv:GetOrigin(), GetClip(pl))
	mv:SetOrigin(origin)
	if not (pl.IsBot and pl:IsBot()) then
		local vel = JumpOffVelocity(pl, cmd)
		Release(pl)
		mv:SetVelocity(vel)
		cmd:RemoveKey(IN_JUMP)
		mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
	else
		Release(pl)
	end
end

local function SwallowUse(pl, mv, cmd)
	cmd:RemoveKey(IN_USE)
	mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_USE)))
	-- SetupMove runs after KeyPress; PlayerUse is after Move. Flag the tick
	-- so a step-off cannot also TryHumanPickup from the new origin.
	pl.RelapseLadderAteUse = CurTime()
end

hook.Add("SetupMove", "RelapseLadder", function(pl, mv, cmd)
	if not pl:Alive() then return end
	if pl:GetMoveType() == NOCLIP and not Holding(pl) then return end

	local now = CurTime()
	local pos = mv:GetOrigin() or pl:GetPos()
	local cd = pl.RelapseLadderCooldown or 0
	local hold = Holding(pl)

	local use = bit.band(cmd:GetButtons(), IN_USE) ~= 0
	local pressed = use and not pl.RelapseLadderUseDown
	pl.RelapseLadderUseDown = use

	local jump = bit.band(cmd:GetButtons(), IN_JUMP) ~= 0
	local jumped = jump and not pl.RelapseLadderJumpDown
	pl.RelapseLadderJumpDown = jump

	local wish = ClimbWishFromInput(pl, cmd:GetButtons(), cmd:GetForwardMove(), cmd:GetViewAngles().p, hold)
	pl.RelapseLadderWish = wish
	pl.RelapseLadderSprint = hold and bit.band(cmd:GetButtons(), IN_SPEED) ~= 0

	if hold then
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_MOVELEFT)
		cmd:RemoveKey(IN_MOVERIGHT)
		mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(bit.bor(IN_DUCK, IN_MOVELEFT, IN_MOVERIGHT))))
		mv:SetSideSpeed(0)
		SetClimbing(pl, true)
		if pl:GetMoveType() == LADDER then
			KickOff(pl)
			SetClimbing(pl, true)
		end
		-- Z: full noclip through props. Jump-off keeps hop speed.
		if pl:Team() == TEAM_HUMAN and bit.band(cmd:GetButtons(), IN_ZOOM) ~= 0 then
			EnableLadderGhost(pl)
		end
	end

	if now < cd then return end

	-- Humans: E is pickup on the server (TryHumanPickup is server-only).
	-- Predicting mount here yanks the holder every tick until
	-- status_human_holding replicates. Jump-off and step-off are predicted.
	if pressed and not hold and not (CLIENT and pl:Team() == TEAM_HUMAN) then
		local gm = GAMEMODE or GM
		local blocked = gm.RelapseLadderUseBlocked and gm:RelapseLadderUseBlocked(pl)
		if not blocked then
			local clip = NearestClimbClip(pl, pos)
			local seat = clip and TrySeat(pl, clip, pos.z)
			if seat then
				SetHold(pl, true)
				SetClip(pl, clip)
				pl.RelapseLadderMountedAt = now
				mv:SetOrigin(seat)
				mv:SetVelocity(vector_origin)
				SetClimbing(pl, true)
				if pl:Team() == TEAM_HUMAN and HullTouchesGhostable(pl, seat) then
					EnableLadderGhost(pl)
				end
				SwallowUse(pl, mv, cmd)
			end
		end
	end

	-- E steps onto a landing. No landing: stay on the ladder. Space hops off.
	if hold and now > (pl.RelapseLadderMountedAt or 0) + 0.15 then
		local gm = GAMEMODE or GM
		local blocked = gm.RelapseLadderUseBlocked and gm:RelapseLadderUseBlocked(pl)
		if pressed and not blocked then
			local dest = gm.RelapseLadderStepOff and gm:RelapseLadderStepOff(pl, pos)
			if dest then
				Release(pl)
				mv:SetOrigin(dest)
				mv:SetVelocity(vector_origin)
				SwallowUse(pl, mv, cmd)
				return
			end
		end
		if jumped then
			JumpOff(pl, mv, cmd)
		end
	end
end)

function GM:RelapseLadderClimb(pl, mv)
	if not Holding(pl) then return false end
	if not pl:Alive() then return false end
	if pl.RelapseNoclip then return false end

	local clip = GetClip(pl)
	if not IsValid(clip) then
		clip = NearestClimbClip(pl, mv:GetOrigin() or pl:GetPos())
		if IsValid(clip) then
			SetClip(pl, clip)
		else
			Release(pl)
			return false
		end
	end

	SetClimbing(pl, true)

	local pos = mv:GetOrigin()
	if SERVER then
		local now = CurTime()
		if now >= (pl.RelapseLadderCanStepAt or 0) then
			pl.RelapseLadderCanStepAt = now + 0.1
			local can = FindPlatformStep(pl, clip, pos) ~= nil
			if pl.RelapseLadderCanStep ~= can then
				pl.RelapseLadderCanStep = can
				pl:SetNW2Bool("RelapseLadderCanStep", can)
			end
		end
	end
	local zmin, zmax = ClimbZRange(clip)
	local pitch = (mv.GetAngles and mv:GetAngles().p) or (pl.EyeAngles and pl:EyeAngles().p) or 0
	local wish = pl.RelapseLadderWish or 0
	if wish == 0 then
		wish = ClimbWishFromInput(pl, mv:GetButtons(), mv:GetForwardSpeed(), pitch, true)
	end

	local dt = FrameTime()
	if dt <= 0 then dt = engine.TickInterval() end
	local gm = GAMEMODE or GM
	local sprint = pl.RelapseLadderSprint
	if sprint == nil then
		sprint = bit.band(mv:GetButtons() or 0, IN_SPEED) ~= 0
	end
	local speed
	if gm.GetHumanClimbSpeed then
		speed = gm:GetHumanClimbSpeed(pl, wish < 0, sprint)
	else
		speed = wish < 0 and CLIMB_SPEED_DOWN or CLIMB_SPEED_UP
	end
	if sprint and gm.GetHumanStaminaSpeedMul then
		speed = speed * gm:GetHumanStaminaSpeedMul(pl, true)
	end
	local _, hx = pl:GetHull()
	local pad = math.max(CLIP_GAP, (hx and hx.z) or CLIP_GAP)
	local z = math.Clamp(pos.z + wish * speed * dt, zmin - pad, zmax + pad)
	local ghost = LadderGhostOn(pl)
	local dest = ClimbSqueeze(pl, clip, pos, z, ghost)
	dest = ClimbWorldStop(pos, dest, hx and hx.z, pl, clip)

	if CurTime() > (pl.RelapseLadderMountedAt or 0) + 0.15 then
		local onBottom = wish < 0 and dest.z == pos.z and pos.z <= zmin + 24
		local atEnd = (wish > 0 and dest.z >= zmax - 0.5) or (wish < 0 and dest.z <= zmin + 0.5) or onBottom
		if atEnd and not HullTrace(pl, dest, dest, ghost).StartSolid then
			Release(pl)
		end
	end

	mv:SetOrigin(dest)
	mv:SetVelocity(Vector(0, 0, wish * speed))
	mv:SetForwardSpeed(0)
	mv:SetSideSpeed(0)
	mv:SetUpSpeed(0)
	return true
end

-- Run before GM:Move so a true return actually skips FullWalkMove.
hook.Add("Move", "RelapseLadder", function(pl, mv)
	local gm = GAMEMODE or GM
	if gm and gm.RelapseLadderClimb and gm:RelapseLadderClimb(pl, mv) then
		return true
	end
end)

-- Walls should stop the hull before LadderMove. If it still mounts, just let go.
hook.Add("FinishMove", "RelapseLadder", function(pl, mv)
	if not pl:Alive() then return end
	if pl:GetMoveType() == NOCLIP then return end
	if pl:GetMoveType() == LADDER then
		KickOff(pl)
	end
	if not Holding(pl) and (pl.RelapseLadderPropClipUntil or 0) > CurTime() then
		ClipMoveAgainstProps(pl, mv)
	end
end)

if not SERVER then return end

local CLIP_THICK = 4
-- Cell size on the climb face. Shaft holes (doorways / landings) skip cells
-- that do not have a world wall immediately behind them.
local CLIP_BAND = 40
local CLIP_BEHIND = 36
local WALL_DIRS = {
	Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0),
}

local function BrushLine(x0, y0, z0, x1, y1, z1)
	return util.TraceLine({
		start = Vector(x0, y0, z0),
		endpos = Vector(x1, y1, z1),
		mask = MASK_SOLID_BRUSHONLY,
	})
end

local function IsRampBox(mins, maxs)
	local sx, sy = maxs.x - mins.x, maxs.y - mins.y
	local height = maxs.z - mins.z
	if height < 40 then return true end
	local thick, span = math.min(sx, sy), math.max(sx, sy)
	return (thick <= 48 and span > height * 1.2) or (thick > 40 and span >= height * 0.85)
end

-- Climb wall only: open to the room, world wall right behind. Shaft holes
-- have no close backing wall, so they stay walk-through.
local function MakeSlab(mins, maxs, d, u0, u1, z0, z1)
	local cmin, cmax = Vector(mins), Vector(maxs)
	cmin.z, cmax.z = z0, z1
	if d.x ~= 0 then
		cmin.y, cmax.y = u0, u1
		if d.x > 0 then
			cmin.x, cmax.x = maxs.x, maxs.x + CLIP_THICK
		else
			cmin.x, cmax.x = mins.x - CLIP_THICK, mins.x
		end
	else
		cmin.x, cmax.x = u0, u1
		if d.y > 0 then
			cmin.y, cmax.y = maxs.y, maxs.y + CLIP_THICK
		else
			cmin.y, cmax.y = mins.y - CLIP_THICK, mins.y
		end
	end
	return {mins = cmin, maxs = cmax, inward = -d}
end

local function OpenFaceSlabs(mins, maxs)
	local sx, sy = maxs.x - mins.x, maxs.y - mins.y
	local reach = math.max(sx, sy) * 0.5 + 24
	local cells = {}

	for i = 1, #WALL_DIRS do
		local d = WALL_DIRS[i]
		local u0, u1
		if d.x ~= 0 then
			u0, u1 = mins.y, maxs.y
		else
			u0, u1 = mins.x, maxs.x
		end
		local u = u0
		while u < u1 - 1 do
			local uTop = math.min(u + CLIP_BAND, u1)
			local um = (u + uTop) * 0.5
			local z = mins.z
			local runZ0
			while z < maxs.z - 1 do
				local zTop = math.min(z + CLIP_BAND, maxs.z)
				local zm = (z + zTop) * 0.5
				local fx, fy
				if d.x > 0 then
					fx, fy = maxs.x, um
				elseif d.x < 0 then
					fx, fy = mins.x, um
				elseif d.y > 0 then
					fx, fy = um, maxs.y
				else
					fx, fy = um, mins.y
				end
				local out = BrushLine(fx - d.x * 4, fy - d.y * 4, zm, fx + d.x * reach, fy + d.y * reach, zm)
				local open = not out.Hit or out.HitSky or out.Fraction > 0.4
				local mounted = false
				if open then
					local inn = BrushLine(
						fx - d.x * 2, fy - d.y * 2, zm,
						fx - d.x * (2 + CLIP_BEHIND), fy - d.y * (2 + CLIP_BEHIND), zm
					)
					mounted = inn.Hit and not inn.HitSky and inn.Fraction < 0.95
				end
				if mounted then
					if not runZ0 then runZ0 = z end
				elseif runZ0 then
					cells[#cells + 1] = MakeSlab(mins, maxs, d, u, uTop, runZ0, z)
					runZ0 = nil
				end
				z = zTop
			end
			if runZ0 then
				cells[#cells + 1] = MakeSlab(mins, maxs, d, u, uTop, runZ0, maxs.z)
			end
			u = uTop
		end
	end

	if #cells > 0 then return cells end

	-- Free-standing: no backing wall. Keep one thin-axis face so E still seats.
	local d = (sx <= sy) and Vector(-1, 0, 0) or Vector(0, -1, 0)
	local fu0 = (d.x ~= 0) and mins.y or mins.x
	local fu1 = (d.x ~= 0) and maxs.y or maxs.x
	return {MakeSlab(mins, maxs, d, fu0, fu1, mins.z, maxs.z)}
end

-- Props too: rungs are often a model, not a brush. World still blocks BrushLine.
local function SolidLine(x0, y0, z0, x1, y1, z1)
	return util.TraceLine({
		start = Vector(x0, y0, z0),
		endpos = Vector(x1, y1, z1),
		mask = MASK_SOLID,
		filter = function(ent)
			if not IsValid(ent) then return true end
			if ent.RelapseLadderClip or ent:IsPlayer() then return false end
			return true
		end,
	})
end

-- Thin thing in front of a deeper wall: rail or rung, not the flat wall.
local function RungAt(x, y, z, ix, iy)
	local ox, oy = -ix, -iy
	local sx, sy = x + ox * 36, y + oy * 36
	local tr = SolidLine(sx, sy, z, sx + ix * 96, sy + iy * 96, z)
	if not tr.Hit or tr.HitSky or tr.StartSolid then return false end
	if math.abs(tr.HitNormal.z or 0) > 0.45 then return false end
	local hx, hy, hz = tr.HitPos.x, tr.HitPos.y, tr.HitPos.z
	for _, dist in ipairs({6, 12, 18}) do
		local x0, y0 = hx + ix * dist, hy + iy * dist
		local tr2 = SolidLine(x0, y0, hz, x0 + ix * 40, y0 + iy * 40, hz)
		if not tr2.StartSolid and tr2.Hit and not tr2.HitSky and math.abs(tr2.HitNormal.z or 0) <= 0.45 then
			local dx, dy = tr2.HitPos.x - hx, tr2.HitPos.y - hy
			local gap = math.sqrt(dx * dx + dy * dy)
			if gap >= 4 and gap <= 32 then return true end
		end
	end
	return false
end

local function BandHasRung(x, y, z0, z1, ix, iy)
	local sx, sy = -iy, ix
	local zs = {z0 + 8, (z0 + z1) * 0.5, z1 - 8}
	for i = 1, #zs do
		local z = zs[i]
		if z > z0 and z < z1 then
			for _, side in ipairs({0, 14, -14}) do
				if RungAt(x + sx * side, y + sy * side, z, ix, iy) then return true end
			end
		end
	end
	return false
end

-- "wall" behind the face, "solid" inside a lip, "open" if the shaft has no wall.
local function BehindFace(x, y, z, ix, iy)
	local tr = BrushLine(x - ix * 4, y - iy * 4, z, x + ix * (CLIP_BEHIND + 8), y + iy * (CLIP_BEHIND + 8), z)
	if tr.StartSolid then return "solid" end
	if tr.Hit and not tr.HitSky and math.abs(tr.HitNormal.z or 0) <= 0.5 and tr.Fraction < 0.95 then
		return "wall"
	end
	return "open"
end

local function SameClimbFace(a, b)
	local dot = a.inward.x * b.inward.x + a.inward.y * b.inward.y
	if dot < 0.9 then return false end
	if a.maxs.x < b.mins.x - 8 or b.maxs.x < a.mins.x - 8 then return false end
	if a.maxs.y < b.mins.y - 8 or b.maxs.y < a.mins.y - 8 then return false end
	return true
end

-- Top of a face keeps going while rails or rungs sit in front of the wall.
-- One or two empty bands stay in the column so a lip does not cut it into steps.
-- No wall: stop. That hole stays walk-through.
local function ExtendTopSlabs(slabs)
	for i = 1, #slabs do
		local slab = slabs[i]
		local topped = false
		for j = 1, #slabs do
			local other = slabs[j]
			if other ~= slab and SameClimbFace(slab, other) and other.maxs.z > slab.maxs.z + 8 then
				topped = true
				break
			end
		end
		if not topped then
			local ix, iy = slab.inward.x, slab.inward.y
			local len = math.sqrt(ix * ix + iy * iy)
			if len > 0.01 then
				ix, iy = ix / len, iy / len
				local x = (slab.mins.x + slab.maxs.x) * 0.5
				local y = (slab.mins.y + slab.maxs.y) * 0.5
				local z = slab.maxs.z
				local limit = z + 640
				local pending = 0
				while z < limit - 1 do
					local z1 = math.min(z + CLIP_BAND, limit)
					local kind = BehindFace(x, y, (z + z1) * 0.5, ix, iy)
					if kind == "open" then break end
					if kind == "wall" and BandHasRung(x, y, z, z1, ix, iy) then
						slab.maxs.z = z1
						pending = 0
					else
						pending = pending + 1
						if pending > 2 then break end
					end
					z = z1
				end
			end
		end
	end
end

local WELD_XY = 96
local WELD_GAP = 192

local function SlabCenter(slab)
	return (slab.mins + slab.maxs) * 0.5
end

local function FaceOut(inward)
	local o = Vector(-inward.x, -inward.y, 0)
	if o:LengthSqr() < 0.01 then return o end
	return o:GetNormalized()
end

-- Stepped rungs sit on one wall but their slabs are shifted outward, so the
-- face test cuts a column into separate climbs. Weld a stack into one sheet
-- on the outermost plane. A gap with no wall behind stays a hole.
local function WeldColumns(slabs)
	local n = #slabs
	if n == 0 then return slabs end
	local parent = {}
	for i = 1, n do parent[i] = i end
	local function find(i)
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	local function join(a, b)
		a, b = find(a), find(b)
		if a ~= b then parent[b] = a end
	end
	for i = 1, n do
		local a = slabs[i]
		local ca = SlabCenter(a)
		for j = i + 1, n do
			local b = slabs[j]
			local dot = a.inward.x * b.inward.x + a.inward.y * b.inward.y
			if dot >= 0.9 then
				local cb = SlabCenter(b)
				local dx, dy = ca.x - cb.x, ca.y - cb.y
				local zGap = 0
				if a.maxs.z < b.mins.z then
					zGap = b.mins.z - a.maxs.z
				elseif b.maxs.z < a.mins.z then
					zGap = a.mins.z - b.maxs.z
				end
				if dx * dx + dy * dy <= WELD_XY * WELD_XY and zGap <= WELD_GAP then
					join(i, j)
				end
			end
		end
	end
	local groups = {}
	for i = 1, n do
		local r = find(i)
		local g = groups[r]
		if not g then
			g = {}
			groups[r] = g
		end
		g[#g + 1] = slabs[i]
	end
	local out = {}
	for _, group in pairs(groups) do
		table.sort(group, function(a, b) return a.mins.z < b.mins.z end)
		local run = {group[1]}
		local function flush()
			local inward = run[1].inward
			local face = FaceOut(inward)
			local front = run[1]
			local best = SlabCenter(front).x * face.x + SlabCenter(front).y * face.y
			local z0, z1 = front.mins.z, front.maxs.z
			local mins = Vector(front.mins)
			local maxs = Vector(front.maxs)
			for i = 1, #run do
				local s = run[i]
				local c = SlabCenter(s)
				local along = c.x * face.x + c.y * face.y
				if along > best then
					best = along
					front = s
				end
				if s.mins.z < z0 then z0 = s.mins.z end
				if s.maxs.z > z1 then z1 = s.maxs.z end
				if math.abs(face.x) > 0.5 then
					if s.mins.y < mins.y then mins.y = s.mins.y end
					if s.maxs.y > maxs.y then maxs.y = s.maxs.y end
				else
					if s.mins.x < mins.x then mins.x = s.mins.x end
					if s.maxs.x > maxs.x then maxs.x = s.maxs.x end
				end
			end
			if math.abs(face.x) > 0.5 then
				mins.x, maxs.x = front.mins.x, front.maxs.x
			else
				mins.y, maxs.y = front.mins.y, front.maxs.y
			end
			mins.z, maxs.z = z0, z1
			out[#out + 1] = {mins = mins, maxs = maxs, inward = inward}
		end
		for i = 2, #group do
			local prev = run[#run]
			local nxt = group[i]
			local gap = nxt.mins.z - prev.maxs.z
			local open = false
			if gap > 4 then
				local c = SlabCenter(prev)
				local ix, iy = prev.inward.x, prev.inward.y
				local len = math.sqrt(ix * ix + iy * iy)
				if len > 0.01 then
					ix, iy = ix / len, iy / len
					-- 36 misses a recessed step and leaves the column in pieces.
					-- A real opening still has no wall within this reach.
					local tr = BrushLine(
						c.x - ix * 4, c.y - iy * 4, prev.maxs.z + gap * 0.5,
						c.x + ix * 100, c.y + iy * 100, prev.maxs.z + gap * 0.5
					)
					local recessed = tr.StartSolid or (tr.Hit and not tr.HitSky and math.abs(tr.HitNormal.z or 0) <= 0.5)
					open = not recessed
				end
			end
			if gap > WELD_GAP or open then
				flush()
				run = {nxt}
			else
				run[#run + 1] = nxt
			end
		end
		flush()
	end
	return out
end

-- prop_static never becomes an entity, so FindInBox cannot see the rungs.
-- Segments of one column (same XY, small Z gap) are one climb.
local PROP_BYTES = {
	[4] = 56, [5] = 60, [6] = 64, [7] = 68, [8] = 72, [9] = 72, [10] = 76, [11] = 80,
}
local COLUMN_XY = 48
local COLUMN_GAP = 32

local function DecodeFloat(data, pos)
	local b1, b2, b3, b4 = string.byte(data, pos, pos + 3)
	if not b4 then return 0 end
	local sign = b4 >= 128 and -1 or 1
	local expo = (b4 % 128) * 2 + math.floor(b3 / 128)
	local mant = ((b3 % 128) * 256 + b2) * 256 + b1
	if expo == 0 or expo == 255 then return 0 end
	return sign * math.ldexp(mant / 8388608 + 1, expo - 127)
end

local function CString(data, pos, len)
	local last = pos + len - 1
	for i = pos, last do
		if string.byte(data, i) == 0 then
			if i == pos then return "" end
			return string.sub(data, pos, i - 1)
		end
	end
	return string.sub(data, pos, last)
end

-- Dedicated server has no util.GetModelBounds. The studio hull is at byte 104.
local function ModelBounds(mdl)
	local f = file.Open(mdl, "rb", "GAME")
	if f then
		local id = f:Read(4)
		if id == "IDST" then
			f:Seek(104)
			local function r()
				return f:ReadFloat() or 0
			end
			local mins = Vector(r(), r(), r())
			local maxs = Vector(r(), r(), r())
			f:Close()
			if maxs.z - mins.z >= 32 then return mins, maxs end
		else
			f:Close()
		end
	end
	local ent = ents.Create("prop_dynamic")
	if not IsValid(ent) then return end
	ent:SetModel(mdl)
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	ent:Remove()
	if not mins or not maxs or maxs.z - mins.z < 32 then return end
	return mins, maxs
end

local function ModelWorldBox(mdl, origin, ang)
	local mins, maxs = ModelBounds(mdl)
	if not mins then return end
	local xs = {mins.x, maxs.x}
	local ys = {mins.y, maxs.y}
	local zs = {mins.z, maxs.z}
	local wmins = Vector(math.huge, math.huge, math.huge)
	local wmaxs = Vector(-math.huge, -math.huge, -math.huge)
	for ix = 1, 2 do
		for iy = 1, 2 do
			for iz = 1, 2 do
				local w = LocalToWorld(Vector(xs[ix], ys[iy], zs[iz]), angle_zero, origin, ang)
				if w.x < wmins.x then wmins.x = w.x end
				if w.y < wmins.y then wmins.y = w.y end
				if w.z < wmins.z then wmins.z = w.z end
				if w.x > wmaxs.x then wmaxs.x = w.x end
				if w.y > wmaxs.y then wmaxs.y = w.y end
				if w.z > wmaxs.z then wmaxs.z = w.z end
			end
		end
	end
	return wmins, wmaxs
end

local function ReadStaticLadders()
	local f = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME")
	if not f then return {} end
	f:Seek(8 + 35 * 16)
	local lumpOfs = f:ReadLong()
	local lumpLen = f:ReadLong()
	if not lumpOfs or not lumpLen or lumpOfs <= 0 or lumpLen < 4 then
		f:Close()
		return {}
	end
	f:Seek(lumpOfs)
	local count = f:ReadLong()
	local sprpOfs, sprpLen, sprpVer
	for _ = 1, count or 0 do
		local id = f:Read(4)
		if not id or #id < 4 then break end
		f:ReadByte()
		f:ReadByte()
		local ver = f:ReadByte() + f:ReadByte() * 256
		local fileofs = f:ReadLong()
		local filelen = f:ReadLong()
		if id == "prps" then
			sprpOfs, sprpLen, sprpVer = fileofs, filelen, ver
		end
	end
	if not sprpOfs or not sprpLen or sprpLen < 8 then
		f:Close()
		return {}
	end
	f:Seek(sprpOfs)
	local blob = f:Read(sprpLen)
	f:Close()
	if not blob or #blob < 8 then return {} end

	local pos = 1
	local nnames = string.byte(blob, pos) + string.byte(blob, pos + 1) * 256
		+ string.byte(blob, pos + 2) * 65536 + string.byte(blob, pos + 3) * 16777216
	pos = pos + 4
	if nnames < 0 or nnames > 4096 then return {} end
	local names = {}
	for i = 1, nnames do
		names[i] = CString(blob, pos, 128)
		pos = pos + 128
	end
	if pos + 4 > #blob then return {} end
	local nleaf = string.byte(blob, pos) + string.byte(blob, pos + 1) * 256
		+ string.byte(blob, pos + 2) * 65536 + string.byte(blob, pos + 3) * 16777216
	pos = pos + 4 + math.max(nleaf, 0) * 2
	if pos + 4 > #blob then return {} end
	local nprop = string.byte(blob, pos) + string.byte(blob, pos + 1) * 256
		+ string.byte(blob, pos + 2) * 65536 + string.byte(blob, pos + 3) * 16777216
	pos = pos + 4
	if nprop <= 0 or nprop > 65536 then return {} end
	local size = PROP_BYTES[sprpVer]
	local remain = #blob - pos + 1
	if not size or nprop * size > remain then
		size = nil
		for _, candidate in ipairs({56, 60, 64, 68, 72, 76, 80}) do
			if nprop * candidate <= remain and (remain - nprop * candidate) < 16 then
				size = candidate
				break
			end
		end
	end
	if not size then return {} end

	local props = {}
	local waiting = false
	for i = 0, nprop - 1 do
		local base = pos + i * size
		if base + 26 > #blob then break end
		local ptype = string.byte(blob, base + 24) + string.byte(blob, base + 25) * 256
		local mdl = names[ptype + 1]
		if mdl and string.find(string.lower(mdl), "ladder", 1, true) then
			local origin = Vector(
				DecodeFloat(blob, base),
				DecodeFloat(blob, base + 4),
				DecodeFloat(blob, base + 8)
			)
			local ang = Angle(
				DecodeFloat(blob, base + 12),
				DecodeFloat(blob, base + 16),
				DecodeFloat(blob, base + 20)
			)
			local wmins, wmaxs = ModelWorldBox(mdl, origin, ang)
			if wmins then
				props[#props + 1] = {mins = wmins, maxs = wmaxs}
			else
				waiting = true
			end
		end
	end
	return props, waiting
end

local function StackColumns(props)
	local n = #props
	local parent = {}
	for i = 1, n do parent[i] = i end
	local function find(i)
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	for i = 1, n do
		local a = props[i]
		local ac = (a.mins + a.maxs) * 0.5
		for j = i + 1, n do
			local b = props[j]
			local bc = (b.mins + b.maxs) * 0.5
			local dx, dy = ac.x - bc.x, ac.y - bc.y
			if dx * dx + dy * dy <= COLUMN_XY * COLUMN_XY then
				local gap = 0
				if a.maxs.z < b.mins.z then
					gap = b.mins.z - a.maxs.z
				elseif b.maxs.z < a.mins.z then
					gap = a.mins.z - b.maxs.z
				end
				if gap <= COLUMN_GAP then
					parent[find(j)] = find(i)
				end
			end
		end
	end
	local groups = {}
	for i = 1, n do
		local r = find(i)
		local g = groups[r]
		if not g then
			g = {mins = Vector(props[i].mins), maxs = Vector(props[i].maxs)}
			groups[r] = g
		else
			local p = props[i]
			if p.mins.x < g.mins.x then g.mins.x = p.mins.x end
			if p.mins.y < g.mins.y then g.mins.y = p.mins.y end
			if p.mins.z < g.mins.z then g.mins.z = p.mins.z end
			if p.maxs.x > g.maxs.x then g.maxs.x = p.maxs.x end
			if p.maxs.y > g.maxs.y then g.maxs.y = p.maxs.y end
			if p.maxs.z > g.maxs.z then g.maxs.z = p.maxs.z end
		end
	end
	local cols = {}
	for _, g in pairs(groups) do
		cols[#cols + 1] = g
	end
	return cols
end

function GM:RelapseLadderModelColumns()
	if self.RelapseLadderModelColumnCache then
		return self.RelapseLadderModelColumnCache
	end
	local ok, props, waiting = pcall(ReadStaticLadders)
	if not ok then
		print("[Relapse] ladder models failed: " .. tostring(props))
		return {}
	end
	if waiting and #props == 0 then return {} end
	local cols = StackColumns(props)
	if #cols == 0 and waiting then return {} end
	self.RelapseLadderModelColumnCache = cols
	return cols
end

local function ColumnHitsBox(col, box)
	local pad = 64
	if col.maxs.x < box.mins.x - pad or col.mins.x > box.maxs.x + pad then return false end
	if col.maxs.y < box.mins.y - pad or col.mins.y > box.maxs.y + pad then return false end
	if col.maxs.z < box.mins.z - COLUMN_GAP or col.mins.z > box.maxs.z + COLUMN_GAP then return false end
	return true
end

-- A func_useableladder line often stops on the first landing while the model
-- keeps going. Raise that volume to the top of the stacked models. A model
-- stack with no volume of its own becomes its own column.
local function AbsorbModelColumns(boxes)
	local cols = GAMEMODE:RelapseLadderModelColumns()
	for i = 1, #cols do
		local col = cols[i]
		local hit = false
		for j = 1, #boxes do
			local box = boxes[j]
			if box.mins and ColumnHitsBox(col, box) then
				if col.mins.z < box.mins.z then box.mins.z = col.mins.z end
				if col.maxs.z > box.maxs.z then box.maxs.z = col.maxs.z end
				hit = true
			end
		end
		if not hit then
			boxes[#boxes + 1] = {mins = Vector(col.mins), maxs = Vector(col.maxs)}
		end
	end
	return #cols
end

local function CollectSpawnBoxes()
	local boxes = {}
	local Nav = RelapseAI and RelapseAI.Nav
	if Nav and Nav.LoadMapLadders then
		boxes = Nav.LoadMapLadders()
		if Nav.CollectLiveLadderBoxes then
			Nav.CollectLiveLadderBoxes(boxes)
		end
	else
		for i = 1, #LADDER_ENTS do
			local list = ents.FindByClass(LADDER_ENTS[i])
			for j = 1, #list do
				local ent = list[j]
				if IsValid(ent) then
					local mins, maxs = ent:WorldSpaceAABB()
					if mins then
						boxes[#boxes + 1] = {mins = mins, maxs = maxs}
					end
				end
			end
		end
	end
	return boxes
end

-- Parsed brush often stops at the first landing. Rungs above it are a model
-- (or more CONTENTS_LADDER the entity box missed). Raise the top before the
-- face test; OpenFaceSlabs still skips cells with no wall behind.
local function LadderColumnTop(mins, maxs)
	local top = maxs.z
	local cx = (mins.x + maxs.x) * 0.5
	local cy = (mins.y + maxs.y) * 0.5
	local z = maxs.z
	for _ = 1, 80 do
		local nz = z + 16
		if not PointHasLadder(cx, cy, nz) then break end
		z = nz
		top = nz
	end
	local pad = 48
	local list = ents.FindInBox(
		Vector(mins.x - pad, mins.y - pad, mins.z),
		Vector(maxs.x + pad, maxs.y + pad, maxs.z + 2048)
	)
	for i = 1, #list do
		local ent = list[i]
		if IsValid(ent) and not ent.RelapseLadderClip and ent.GetModel then
			local mdl = ent:GetModel()
			if mdl and string.find(string.lower(mdl), "ladder", 1, true) then
				local emins, emaxs = ent:WorldSpaceAABB()
				if emins and emaxs and emaxs.z > top
					and emaxs.x >= mins.x - pad and emins.x <= maxs.x + pad
					and emaxs.y >= mins.y - pad and emins.y <= maxs.y + pad
					and emins.z <= maxs.z + 96 then
					top = emaxs.z
				end
			end
		end
	end
	return top
end

local function SpawnClips()
	for _, ent in ipairs(ents.FindByClass("relapse_ladder_clip")) do
		if IsValid(ent) then ent:Remove() end
	end
	local boxes = CollectSpawnBoxes()
	local ok, columns = pcall(AbsorbModelColumns, boxes)
	if not ok then
		print("[Relapse] ladder columns failed: " .. tostring(columns))
		columns = 0
	end
	print(string.format("[Relapse] ladder volumes %d, model columns %d", #boxes, columns))
	local all = {}
	for i = 1, #boxes do
		local b = boxes[i]
		if b.mins and b.maxs and not IsRampBox(b.mins, b.maxs) then
			local maxs = b.maxs
			local top = LadderColumnTop(b.mins, b.maxs)
			if top > maxs.z + 1 then
				maxs = Vector(maxs.x, maxs.y, top)
			end
			local slabs = OpenFaceSlabs(b.mins, maxs)
			for j = 1, #slabs do
				all[#all + 1] = slabs[j]
			end
		end
	end
	all = WeldColumns(all)
	ExtendTopSlabs(all)
	for j = 1, #all do
		local s = all[j]
		local center = (s.mins + s.maxs) * 0.5
		local ent = ents.Create("relapse_ladder_clip")
		if IsValid(ent) then
			ent:SetPos(center)
			ent:SetBoxMins(s.mins - center)
			ent:SetBoxMaxs(s.maxs - center)
			ent:SetInward(s.inward)
			local ax = (s.mins.x + s.maxs.x) * 0.5
			local ay = (s.mins.y + s.maxs.y) * 0.5
			local hx = (s.maxs.x - s.mins.x) * 0.5
			local hy = (s.maxs.y - s.mins.y) * 0.5
			ent:SetAxisCenter(Vector(ax, ay, (s.mins.z + s.maxs.z) * 0.5))
			ent:SetAxisRadii(Vector(hx, hy, 0))
			ent:SetAxisRadius(math.max(hx, hy) + 16)
			ent:Spawn()
			ent:InitClip()
		end
	end
end

hook.Add("InitPostEntity", "RelapseLadderClips", function()
	timer.Simple(0.2, SpawnClips)
end)

hook.Add("PostCleanupMap", "RelapseLadderClips", function()
	timer.Simple(0.2, SpawnClips)
end)
