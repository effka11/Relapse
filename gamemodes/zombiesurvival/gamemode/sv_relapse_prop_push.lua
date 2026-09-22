-- Relapse: unnailed physics props stay solid so the HL2 player-controller
-- cannot shove them. Other props and physboxes still move them; pickup, nails,
-- shade, throws and explosions thaw the pile.

local meta = FindMetaTable("Entity")

local SHADE_CONTROL = {
	env_shadecontrol = true,
	env_frostshadecontrol = true,
}

local SLOW_VEL_SQR = 48 * 48
local SLOW_ANG_SQR = 20 * 20
-- Resting phys objects sit on contact or a millimetre of penetration. Anything
-- larger is a hang (player crawled out, door opened, the crate underneath moved).
local SUPPORT_DROP = 8
local CONTACT_DIST_SQR = SUPPORT_DROP * SUPPORT_DROP
-- Same spot: a shuffled player or a door that turned is a new support check.
local SUPPORT_MOVE_SQR = 1
local SUPPORT_TURN = 1
local LIFT_TRACE = Vector(0, 0, 1)
-- Jump-land embed vs foot clip on a frozen lid. Not SUPPORT_DROP.
local STUCK_LIFT = 4

local BLAST_FORCE = bit.bor(
	DMG_BLAST,
	DMG_BLAST_SURFACE,
	DMG_BURN,
	DMG_SLOWBURN,
	DMG_ALWAYSGIB
)

---------------------------------------------------------------------------
-- Candidates
---------------------------------------------------------------------------

local function EachPhys(ent, fn)
	local count = ent:GetPhysicsObjectCount()
	if count <= 1 then
		local phys = ent:GetPhysicsObject()
		if phys:IsValid() then
			fn(phys)
		end
		return
	end

	for i = 0, count - 1 do
		local phys = ent:GetPhysicsObjectNum(i)
		if phys:IsValid() then
			fn(phys)
		end
	end
end

local function IsPhysicsProp(ent)
	return string.sub(ent:GetClass(), 1, 12) == "prop_physics"
end

local function IsFuncPhysbox(ent)
	return string.sub(ent:GetClass(), 1, 12) == "func_physbox"
end

-- Props and map physboxes may thaw a frozen crate. Manhacks / drones do not.
local function IsPhysActor(ent)
	if not ent:IsValid() or ent:IsWorld() or ent:IsPlayer() then return false end
	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
	return IsPhysicsProp(ent) or IsFuncPhysbox(ent)
end

local function IsShadeGrabbed(ent)
	for _, child in ipairs(ent:GetChildren()) do
		if child:IsValid() and SHADE_CONTROL[child:GetClass()] then
			return true
		end
	end
	return false
end

local function IsHeldByGameplay(ent)
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() and phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) then
		return true
	end
	return IsShadeGrabbed(ent)
end

-- True if the collision hull still meets world / another solid within SUPPORT_DROP.
-- Players and NPCs count: while they are underneath the prop stays put; once they
-- leave, the next settle tick unfreezes it so it can fall.
local supportStart = Vector()
local supportEnd = Vector()
local supportTr = {
	mask = MASK_SOLID,
	filter = nil,
	start = supportStart,
	endpos = supportEnd,
}

local function ProbeRestSupport(ent)
	local pos = ent:GetPos()
	supportStart:Set(pos)
	supportEnd:Set(pos)
	supportEnd.z = supportEnd.z - SUPPORT_DROP
	supportTr.filter = ent
	local tr = util.TraceEntity(supportTr, ent)
	return tr.Hit or tr.StartSolid, tr
end

local function ClearSupport(ent)
	ent.m_RelapseSupportWorld = nil
	ent.m_RelapseSupportEnt = nil
end

-- World, or a live entity still at the stored pose. A miss means the next
-- settle tick traces again. StartSolid with no hit entity is not remembered:
-- the body inside us may leave without moving a brush.
local function RememberSupport(ent, tr)
	if tr.StartSolid and not tr.Hit then
		ClearSupport(ent)
		return
	end
	local sup = tr.Entity
	if tr.HitWorld or not IsValid(sup) or sup:IsWorld() then
		ent.m_RelapseSupportEnt = nil
		ent.m_RelapseSupportPos = nil
		ent.m_RelapseSupportAng = nil
		ent.m_RelapseSupportWorld = true
		return
	end
	ent.m_RelapseSupportWorld = nil
	ent.m_RelapseSupportEnt = sup
	local pos = ent.m_RelapseSupportPos
	if not pos then
		ent.m_RelapseSupportPos = Vector(sup:GetPos())
		ent.m_RelapseSupportAng = Angle(sup:GetAngles())
	else
		pos:Set(sup:GetPos())
		ent.m_RelapseSupportAng:Set(sup:GetAngles())
	end
end

local function SupportUnmoved(ent)
	if ent.m_RelapseSupportWorld then return true end
	local sup = ent.m_RelapseSupportEnt
	if not IsValid(sup) then return false end
	local pos = ent.m_RelapseSupportPos
	if not pos or sup:GetPos():DistToSqr(pos) > SUPPORT_MOVE_SQR then return false end
	local ang = ent.m_RelapseSupportAng
	if not ang then return false end
	local now = sup:GetAngles()
	return math.abs(math.AngleDifference(ang.p, now.p)) <= SUPPORT_TURN
		and math.abs(math.AngleDifference(ang.y, now.y)) <= SUPPORT_TURN
		and math.abs(math.AngleDifference(ang.r, now.r)) <= SUPPORT_TURN
end

local function WakePhys(ent)
	EachPhys(ent, function(obj)
		obj:Wake()
	end)
end

-- Loose map/player props that would otherwise slide when walked into.
function meta:RelapseIsPushCandidate()
	if not self:IsValid() then return false end
	if not IsPhysicsProp(self) then return false end
	if self:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
	if self:IsNailed() or self:GetNailFrozen() then return false end
	if self:IsProjectile() then return false end
	return true
end

-- Pickup / nails / shade treat anti-push frozen props as still moveable.
function meta:IsRelapseMoveable()
	if self.m_RelapsePushFrozen then return true end
	local phys = self:GetPhysicsObject()
	return phys:IsValid() and phys:IsMoveable()
end

---------------------------------------------------------------------------
-- Contact
---------------------------------------------------------------------------

local function NearestDistSqr(a, b)
	local p1 = a:NearestPoint(b:WorldSpaceCenter())
	local p2 = b:NearestPoint(p1)
	return p1:DistToSqr(p2)
end

-- Held / shade, or a moving prop/physbox, close enough that freeze would
-- turn a live shove back into a wall.
local function TouchesLivePhys(ent)
	local rad = ent:BoundingRadius() + SUPPORT_DROP
	for _, other in ipairs(ents.FindInSphere(ent:WorldSpaceCenter(), rad)) do
		if other == ent then continue end
		if not IsHeldByGameplay(other) then
			if not IsPhysActor(other) or other.m_RelapsePushFrozen then continue end
			local ophys = other:GetPhysicsObject()
			if not ophys:IsValid() or not ophys:IsMoveable() then continue end
			if ophys:GetVelocity():LengthSqr() < SLOW_VEL_SQR then continue end
		end
		if NearestDistSqr(ent, other) < CONTACT_DIST_SQR then
			return true
		end
	end
	return false
end

-- Feet on the lid or in the upper half. Side walk stays at floor z.
local function PlayerOnPropTop(ply, ent)
	if ply:GetGroundEntity() == ent then return true end
	local mins, maxs = ent:WorldSpaceAABB()
	return ply:GetPos().z >= (mins.z + maxs.z) * 0.5
end

-- Hull still in this prop after a vertical lift. World StartSolid does not count.
local function PlayerHullInProp(ply, ent, liftZ)
	local mins, maxs = ply:GetHull()
	if ply:Crouching() then
		mins, maxs = ply:GetHullDuck()
	end
	local pos = ply:GetPos() + Vector(0, 0, liftZ)
	local tr = util.TraceHull({
		start = pos,
		endpos = pos,
		mins = mins,
		maxs = maxs,
		mask = MASK_PLAYERSOLID,
		filter = function(e) return e == ent end,
	})
	if not tr.StartSolid or tr.HitWorld then return false end
	return not tr.Entity:IsValid() or tr.Entity == ent
end

local function PlayerStuckOnTop(ent)
	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() then continue end
		if not PlayerOnPropTop(ply, ent) then continue end
		if PlayerHullInProp(ply, ent, STUCK_LIFT) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Two-body
--
-- Collision already resolved against infinite mass. Replace both linear
-- velocities with an inelastic (e=0) split of OurOld/TheirOld along HitNormal.
---------------------------------------------------------------------------

local twoBodyTick = 0
local twoBodyPairs = {} -- ["i j"] = true this tick

-- Same PhysicsCollide fires on both ents; mark only when we actually schedule.
local function PairRewritten(a, b)
	local t = CurTime()
	if t ~= twoBodyTick then
		twoBodyTick = t
		twoBodyPairs = {}
	end
	local i, j = a:EntIndex(), b:EntIndex()
	if i > j then
		i, j = j, i
	end
	local k = i .. " " .. j
	if twoBodyPairs[k] then return true end
	twoBodyPairs[k] = true
	return false
end

local function ScheduleTwoBody(ent, other, data)
	local n = data.HitNormal
	if not n or n:LengthSqr() < 1e-8 then return end
	n = Vector(n)
	local v1 = Vector(data.OurOldVelocity)
	local v2 = Vector(data.TheirOldVelocity)
	if (v1 - v2):Dot(n) > 0 then
		n:Mul(-1)
	end

	local phys = data.PhysObject
	local otherPhys = data.HitObject
	if not phys:IsValid() or not otherPhys:IsValid() then return end
	local m1 = phys:GetMass()
	local m2 = otherPhys:GetMass()
	if m1 <= 0 or m2 <= 0 then return end

	if PairRewritten(ent, other) then return end

	local v1n = v1:Dot(n)
	local v2n = v2:Dot(n)
	local vn = (m1 * v1n + m2 * v2n) / (m1 + m2)
	local new1 = v1 + n * (vn - v1n)
	local new2 = v2 + n * (vn - v2n)

	timer.Simple(0, function()
		if not ent:IsValid() or not other:IsValid() then return end
		if ent:GetNailFrozen() or other:GetNailFrozen() then return end
		if ent.m_RelapsePushFrozen or other.m_RelapsePushFrozen then return end
		if phys:IsValid() then
			phys:SetVelocityInstantaneous(new1)
		end
		if otherPhys:IsValid() then
			otherPhys:SetVelocityInstantaneous(new2)
		end
	end)
end

---------------------------------------------------------------------------
-- Freeze / unfreeze
---------------------------------------------------------------------------

local function UnfreezeStandingOn(base)
	if not base:IsValid() then return end

	local rad = base:BoundingRadius() + SUPPORT_DROP
	for _, ent in ipairs(ents.FindInSphere(base:WorldSpaceCenter(), rad)) do
		if ent == base then continue end
		if not ent.m_RelapsePushFrozen then continue end
		if not ent:RelapseIsPushCandidate() then continue end

		local pos = ent:GetPos()
		local tr = util.TraceEntity({
			start = pos + LIFT_TRACE,
			endpos = pos + Vector(0, 0, -SUPPORT_DROP),
			filter = ent,
			mask = MASK_SOLID,
		}, ent)
		if tr.Entity == base then
			ent:RelapseUnfreezeAgainstPush()
		end
	end
end

function meta:RelapseFreezeAgainstPush()
	if self.m_RelapsePushFrozen then return true end
	if not self:RelapseIsPushCandidate() then return false end
	if IsHeldByGameplay(self) then return false end
	if self.m_RelapseNoPushUntil and CurTime() < self.m_RelapseNoPushUntil then return false end
	if self.LastHeld and CurTime() < self.LastHeld + 0.35 then return false end

	local phys = self:GetPhysicsObject()
	if not phys:IsValid() or not phys:IsMoveable() then return false end
	local supported, tr = ProbeRestSupport(self)
	if not supported then return false end
	if PlayerStuckOnTop(self) then return false end

	self.m_RelapsePushFrozen = true
	RememberSupport(self, tr)
	EachPhys(self, function(obj)
		obj:EnableMotion(false)
	end)
	return true
end

function meta:RelapseUnfreezeAgainstPush()
	self.m_RelapseNoPushUntil = CurTime() + 0.35
	ClearSupport(self)
	if not self.m_RelapsePushFrozen then return false end
	self.m_RelapsePushFrozen = nil
	if self:GetNailFrozen() then return false end

	EachPhys(self, function(obj)
		obj:EnableMotion(true)
		obj:Wake()
	end)
	UnfreezeStandingOn(self)
	return true
end

local function TrySettle(ent)
	if not ent:RelapseIsPushCandidate() then return end
	if IsHeldByGameplay(ent) then return end

	if ent.m_RelapsePushFrozen then
		local supported = SupportUnmoved(ent)
		if not supported then
			local ok, tr = ProbeRestSupport(ent)
			if ok then
				RememberSupport(ent, tr)
				supported = true
			end
		end
		if not supported or PlayerStuckOnTop(ent) then
			ent:RelapseUnfreezeAgainstPush()
		end
		return
	end

	local phys = ent:GetPhysicsObject()
	if not phys:IsValid() or not phys:IsMoveable() then return end

	local asleep = phys:IsAsleep()
	if not asleep then
		local velSqr = phys:GetVelocity():LengthSqr()
		local angSqr = phys:GetAngleVelocity():LengthSqr()
		if velSqr >= SLOW_VEL_SQR or angSqr >= SLOW_ANG_SQR then return end
	end

	-- Asleep / slow in mid-air: the thing it landed on walked away. Wake so
	-- gravity runs; do not freeze or it stays a static hanging hull.
	if not ProbeRestSupport(ent) then
		if asleep then
			WakePhys(ent)
		end
		return
	end

	if TouchesLivePhys(ent) then return end

	if asleep then
		ent:RelapseFreezeAgainstPush()
		return
	end

	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() and ply:GetGroundEntity() == ent then
			ent:RelapseFreezeAgainstPush()
			return
		end
	end
end

local function ImpactSpeedSqr(data)
	local speed = data.Speed or 0
	return math.max(
		data.OurOldVelocity:LengthSqr(),
		data.TheirOldVelocity:LengthSqr(),
		speed * speed
	)
end

local function HookPropCollide(ent)
	if ent.m_RelapseNoPushHooked then return end
	if not IsPhysicsProp(ent) and not IsFuncPhysbox(ent) then return end

	ent.m_RelapseNoPushHooked = true
	ent:AddCallback("PhysicsCollide", function(self, data)
		local other = data.HitEntity
		if not other:IsValid() then return end

		if IsPhysActor(other) and ImpactSpeedSqr(data) >= SLOW_VEL_SQR then
			local selfWasFrozen = self.m_RelapsePushFrozen
			local otherWasFrozen = other.m_RelapsePushFrozen
			if selfWasFrozen then
				self:RelapseUnfreezeAgainstPush()
			end
			if otherWasFrozen then
				other:RelapseUnfreezeAgainstPush()
			end
			if selfWasFrozen or otherWasFrozen then
				ScheduleTwoBody(self, other, data)
			end
		end

		if IsHeldByGameplay(self) then return end
		if not other:IsPlayer() then return end
		if PlayerOnPropTop(other, self) and PlayerHullInProp(other, self, STUCK_LIFT) then
			if self.m_RelapsePushFrozen then
				self:RelapseUnfreezeAgainstPush()
			end
			return
		end
		if self.m_RelapsePushFrozen or not self:RelapseIsPushCandidate() then return end
		if data.OurOldVelocity:LengthSqr() >= SLOW_VEL_SQR then return end

		self:RelapseFreezeAgainstPush()
	end)
end

-- Settle walks this list. FindByClass every tick rebuilt the whole prop table
-- after the pile had already frozen.
local pushCandidates = {}
local pushCandidateSet = {}

local function TrackPushCandidate(ent)
	if not IsPhysicsProp(ent) or pushCandidateSet[ent] then return end
	pushCandidateSet[ent] = true
	pushCandidates[#pushCandidates + 1] = ent
end

local function ScanExisting()
	for _, ent in ipairs(ents.FindByClass("prop_physics*")) do
		TrackPushCandidate(ent)
		HookPropCollide(ent)
		TrySettle(ent)
	end
	for _, ent in ipairs(ents.FindByClass("func_physbox*")) do
		HookPropCollide(ent)
	end
end

---------------------------------------------------------------------------
-- Damage
---------------------------------------------------------------------------

-- Mirror GM:EntityTakeDamage early-outs that zero the hit after this hook.
local function ShouldSkipDamageThaw(ent, dmginfo)
	local attacker = dmginfo:GetAttacker()
	local inflictor = dmginfo:GetInflictor()
	if attacker:IsValid() and attacker == inflictor and attacker:IsProjectile()
		and dmginfo:GetDamageType() == DMG_CRUSH then
		return true
	end
	if GAMEMODE:GetWave() <= 0 and IsPhysicsProp(ent)
		and inflictor:IsValid() and inflictor.NoPropDamageDuringWave0 then
		return true
	end
	return false
end

-- Motion was off when the engine applied force; push next tick if still still.
local function ScheduleBlastForce(ent, dmginfo)
	if bit.band(dmginfo:GetDamageType(), BLAST_FORCE) == 0 then return end
	local force = dmginfo:GetDamageForce()
	if force:LengthSqr() <= 0 then return end
	force = Vector(force)
	local pos = Vector(dmginfo:GetDamagePosition())

	timer.Simple(0, function()
		if not ent:IsValid() then return end
		if ent.m_RelapsePushFrozen or ent:GetNailFrozen() then return end
		local phys = ent:GetPhysicsObject()
		if not phys:IsValid() then return end
		if phys:GetVelocity():LengthSqr() >= SLOW_VEL_SQR then return end
		if pos:LengthSqr() > 0 then
			phys:ApplyForceOffset(force, pos)
		else
			phys:ApplyForceCenter(force)
		end
	end)
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

hook.Add("OnEntityCreated", "RelapsePropPush", function(ent)
	timer.Simple(0, function()
		if not ent:IsValid() then return end
		TrackPushCandidate(ent)
		HookPropCollide(ent)
		TrySettle(ent)
	end)
end)

hook.Add("InitPostEntityMap", "RelapsePropPush", function()
	timer.Simple(0.1, ScanExisting)
end)

hook.Add("EntityTakeDamage", "RelapsePropPush", function(ent, dmginfo)
	if not ent.m_RelapsePushFrozen then return end
	if ShouldSkipDamageThaw(ent, dmginfo) then return end
	if dmginfo:GetDamage() <= 0 and dmginfo:GetDamageForce():LengthSqr() <= 0 then
		return
	end

	ent:RelapseUnfreezeAgainstPush()
	-- Pure crush is two-body. BLAST|CRUSH still needs delayed force.
	-- Do not return a value: GM:EntityTakeDamage never runs if a hook does.
	ScheduleBlastForce(ent, dmginfo)
end)

timer.Create("RelapsePropPushSettle", 0.25, 0, function()
	local n = 1
	for i = 1, #pushCandidates do
		local ent = pushCandidates[i]
		if ent:IsValid() then
			pushCandidates[n] = ent
			n = n + 1
			TrySettle(ent)
		else
			pushCandidateSet[ent] = nil
		end
	end
	for i = n, #pushCandidates do
		pushCandidates[i] = nil
	end
end)

if GAMEMODE and GAMEMODE.DidInitPostEntity then
	ScanExisting()
end
