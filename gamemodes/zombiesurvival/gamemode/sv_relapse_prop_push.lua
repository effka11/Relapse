-- Relapse: unnailed props stay solid, but the HL2 player-controller cannot
-- shove them. Pickup, nailing, shade grab, throws and damage still move them.

local meta = FindMetaTable("Entity")

local SHADE_CONTROL = {
	env_shadecontrol = true,
	env_frostshadecontrol = true,
}

local SLOW_VEL_SQR = 48 * 48
local SLOW_ANG_SQR = 20 * 20

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
-- Freeze / unfreeze
---------------------------------------------------------------------------

function meta:RelapseFreezeAgainstPush()
	if self.m_RelapsePushFrozen then return true end
	if not self:RelapseIsPushCandidate() then return false end
	if IsHeldByGameplay(self) then return false end
	if self.m_RelapseNoPushUntil and CurTime() < self.m_RelapseNoPushUntil then return false end
	if self.LastHeld and CurTime() < self.LastHeld + 0.35 then return false end

	local phys = self:GetPhysicsObject()
	if not phys:IsValid() or not phys:IsMoveable() then return false end

	self.m_RelapsePushFrozen = true
	EachPhys(self, function(obj)
		obj:EnableMotion(false)
	end)
	return true
end

function meta:RelapseUnfreezeAgainstPush()
	self.m_RelapseNoPushUntil = CurTime() + 0.35
	if not self.m_RelapsePushFrozen then return false end
	self.m_RelapsePushFrozen = nil
	if self:GetNailFrozen() then return false end

	EachPhys(self, function(obj)
		obj:EnableMotion(true)
		obj:Wake()
	end)
	return true
end

local function TrySettle(ent)
	if not ent:RelapseIsPushCandidate() then return end
	if ent.m_RelapsePushFrozen then return end
	if IsHeldByGameplay(ent) then return end

	local phys = ent:GetPhysicsObject()
	if not phys:IsValid() or not phys:IsMoveable() then return end

	if phys:IsAsleep() then
		ent:RelapseFreezeAgainstPush()
		return
	end

	local velSqr = phys:GetVelocity():LengthSqr()
	local angSqr = phys:GetAngleVelocity():LengthSqr()
	if velSqr >= SLOW_VEL_SQR or angSqr >= SLOW_ANG_SQR then return end

	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() and ply:GetGroundEntity() == ent then
			ent:RelapseFreezeAgainstPush()
			return
		end
	end
end

local function HookPropCollide(ent)
	if ent.m_RelapseNoPushHooked then return end
	if not IsPhysicsProp(ent) then return end

	ent.m_RelapseNoPushHooked = true
	ent:AddCallback("PhysicsCollide", function(self, data)
		if self.m_RelapsePushFrozen or not self:RelapseIsPushCandidate() then return end
		if IsHeldByGameplay(self) then return end

		local other = data.HitEntity
		if not other:IsValid() or not other:IsPlayer() then return end
		if data.OurOldVelocity:LengthSqr() >= SLOW_VEL_SQR then return end

		self:RelapseFreezeAgainstPush()
	end)
end

local function ScanExisting()
	for _, ent in ipairs(ents.FindByClass("prop_physics*")) do
		HookPropCollide(ent)
		TrySettle(ent)
	end
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

hook.Add("OnEntityCreated", "RelapsePropPush", function(ent)
	timer.Simple(0, function()
		if not ent:IsValid() then return end
		HookPropCollide(ent)
		TrySettle(ent)
	end)
end)

hook.Add("InitPostEntityMap", "RelapsePropPush", function()
	timer.Simple(0.1, ScanExisting)
end)

hook.Add("EntityTakeDamage", "RelapsePropPush", function(ent, dmginfo)
	if not ent.m_RelapsePushFrozen then return end
	if dmginfo:GetDamage() <= 0 then return end
	ent:RelapseUnfreezeAgainstPush()
end)

timer.Create("RelapsePropPushSettle", 0.25, 0, function()
	for _, ent in ipairs(ents.FindByClass("prop_physics*")) do
		TrySettle(ent)
	end
end)
