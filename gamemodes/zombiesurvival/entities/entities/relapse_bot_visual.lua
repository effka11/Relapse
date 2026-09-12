AddCSLuaFile()

-- Visual piece. Zombie clothes bone-merge onto the RE2 body, not the player.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.DisableDuplicator = true

function ENT:Initialize()
	self:SetSolid(SOLID_NONE)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	self:SetNotSolid(true)
	self:DrawShadow(false)
	self:SetTransmitWithParent(true)
end

function ENT:Think()
end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

if CLIENT then
	function ENT:Draw()
		local owner = self:GetOwner()
		if IsValid(owner) and owner:IsPlayer() and not owner:Alive() then
			return
		end

		self:DrawModel()
	end

	ENT.DrawTranslucent = ENT.Draw
end
