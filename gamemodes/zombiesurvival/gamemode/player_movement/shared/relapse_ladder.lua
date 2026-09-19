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

local function SeatXY(clip, extra)
	local pos = clip:GetPos()
	local out = Outward(clip)
	local off = STAND_OFF + (extra or 0)
	return pos.x + out.x * off, pos.y + out.y * off
end

local function SeatFromClip(clip, z, extra)
	local x, y = SeatXY(clip, extra)
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
	local out = Outward(clip)
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

-- NOCLIP hold ignores world. Stop Z only if a brush line from air hits a
-- floor/ceiling. Vertical rim and StartSolid in the slab do not stop.
local function ClimbWorldStop(origin, dest, hullZ)
	if not origin or not dest or dest.z == origin.z then return dest end
	local h = dest.z > origin.z and (hullZ or 72) or 0
	local tr = util.TraceLine({
		start = Vector(origin.x, origin.y, origin.z + h),
		endpos = Vector(dest.x, dest.y, dest.z + h),
		mask = MASK_SOLID_BRUSHONLY,
		filter = function(ent)
			return not (IsValid(ent) and ent.RelapseLadderClip)
		end,
	})
	if tr.StartSolid then return dest end
	if not tr.Hit or tr.HitSky then return dest end
	local n = tr.HitNormal
	if not n or math.abs(n.z) <= 0.5 then return dest end
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
		local x, y = SeatXY(clip, extra)
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
	local function try(extra, mins, maxs)
		local seat = SeatFromClip(clip, z, extra)
		local tr = HullTrace(pl, seat, seat, true, mins, maxs)
		if not tr.StartSolid then
			pl.RelapseLadderSeatExtra = extra ~= 0 and extra or nil
			return seat
		end
	end
	local extras = {0, 8, 16}
	for i = 1, #extras do
		local extra = extras[i]
		local seat = try(extra, sm, sx) or try(extra, dm, dx)
		if seat then return seat end
	end
	pl.RelapseLadderSeatExtra = 16
	return SeatFromClip(clip, z, 16)
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
	local out = Outward(clip)
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
		if not dest then return end
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

--[[ Landing dest if E would step off this climb. Nil if no nearby platform.
function GM:RelapseLadderStepOff(pl)
	if not IsValid(pl) or not Holding(pl) then return end
	local pos = pl:GetPos()
	return FindPlatformStep(pl, GetClip(pl) or NearestClimbClip(pl, pos), pos)
end
]]

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
	-- status_human_holding replicates. Jump-off (space and E) is predicted.
	if pressed and not (CLIENT and pl:Team() == TEAM_HUMAN) then
		local gm = GAMEMODE or GM
		local blocked = gm.RelapseLadderUseBlocked and gm:RelapseLadderUseBlocked(pl)
		if not blocked then
			if hold then
				--[[ E step-off onto a landing. Leave is jump toward the camera.
				local dest = FindPlatformStep(pl, GetClip(pl) or NearestClimbClip(pl, pos), pos)
				Release(pl)
				if dest then
					mv:SetOrigin(dest)
					mv:SetVelocity(vector_origin)
				end
				SwallowUse(pl, mv, cmd)
				return
				]]
			else
				local clip = NearestClimbClip(pl, pos)
				if clip then
					local seat = TrySeat(pl, clip, pos.z)
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
	end

	local leave = jumped
	if hold and pressed then
		local gm = GAMEMODE or GM
		if not (gm.RelapseLadderUseBlocked and gm:RelapseLadderUseBlocked(pl)) then
			leave = true
		end
	end
	if hold and leave and now > (pl.RelapseLadderMountedAt or 0) + 0.15 then
		JumpOff(pl, mv, cmd)
		if pressed then
			SwallowUse(pl, mv, cmd)
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
	--[[ Step-off hint: E onto a nearby landing.
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
	]]
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
	dest = ClimbWorldStop(pos, dest, hx and hx.z)

	if CurTime() > (pl.RelapseLadderMountedAt or 0) + 0.15 then
		local atEnd = (wish > 0 and dest.z >= zmax - 0.5) or (wish < 0 and dest.z <= zmin + 0.5)
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

local function SpawnClips()
	for _, ent in ipairs(ents.FindByClass("relapse_ladder_clip")) do
		if IsValid(ent) then ent:Remove() end
	end
	local boxes = CollectSpawnBoxes()
	for i = 1, #boxes do
		local b = boxes[i]
		if b.mins and b.maxs and not IsRampBox(b.mins, b.maxs) then
			local slabs = OpenFaceSlabs(b.mins, b.maxs)
			for j = 1, #slabs do
				local s = slabs[j]
				local center = (s.mins + s.maxs) * 0.5
				local ent = ents.Create("relapse_ladder_clip")
				if IsValid(ent) then
					ent:SetPos(center)
					ent:SetBoxMins(s.mins - center)
					ent:SetBoxMaxs(s.maxs - center)
					ent:SetInward(s.inward)
					local ax = (b.mins.x + b.maxs.x) * 0.5
					local ay = (b.mins.y + b.maxs.y) * 0.5
					local hx = (b.maxs.x - b.mins.x) * 0.5
					local hy = (b.maxs.y - b.mins.y) * 0.5
					ent:SetAxisCenter(Vector(ax, ay, (b.mins.z + b.maxs.z) * 0.5))
					ent:SetAxisRadii(Vector(hx, hy, 0))
					ent:SetAxisRadius(math.max(hx, hy) + 16)
					ent:Spawn()
					ent:InitClip()
				end
			end
		end
	end
end

hook.Add("InitPostEntity", "RelapseLadderClips", function()
	timer.Simple(0.2, SpawnClips)
end)

hook.Add("PostCleanupMap", "RelapseLadderClips", function()
	timer.Simple(0.2, SpawnClips)
end)
