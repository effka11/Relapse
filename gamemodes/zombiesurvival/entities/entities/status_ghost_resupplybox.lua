AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "status_ghost_base"

ENT.GhostModel = Model("models/ammo/fas2/ammocrate.mdl")
ENT.GhostScale = 0.75
ENT.GhostRotation = Angle(270, 0, 0)
ENT.GhostHitNormalOffset = 0

function ENT:Initialize()
	self.BaseClass.Initialize(self)

	local seq = self:LookupSequence("Open")
	if seq and seq >= 0 then
		self:ResetSequence(seq)
		self:SetCycle(1)
		self:SetPlaybackRate(0)
	end
end

function ENT:Think()
	local seq = self:LookupSequence("Open")
	if seq and seq >= 0 and (self:GetSequence() ~= seq or self:GetCycle() < 0.99) then
		self:ResetSequence(seq)
		self:SetCycle(1)
		self:SetPlaybackRate(0)
	end

	return self.BaseClass.Think(self)
end
ENT.GhostEntity = "prop_resupplybox"
ENT.GhostWeapon = "weapon_zs_resupplybox"
ENT.GhostDistance = 256
ENT.GhostLimitedNormal = 0.75
