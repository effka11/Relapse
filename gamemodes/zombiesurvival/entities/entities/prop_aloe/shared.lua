ENT.Type = "anim"
ENT.PrintName = "Ficus K-4"
ENT.Spawnable = false

ENT.m_NoNailUnfreeze = true
ENT.NoNails = true

ENT.CanPackUp = true
ENT.IsBarricadeObject = true
ENT.AlwaysGhostable = true

ENT.SWEP = "weapon_zs_aloe"
ENT.EmptyModel = Model("models/srp/prop_pbucket.mdl")
ENT.LeavesModel = Model("models/srp/prop_cocaleaves.mdl")
ENT.LeavesLocalPos = Vector(0, 0, 8)
ENT.LeavesLocalAng = Angle(0, 180, 0)
ENT.MaxHealth = 50

function ENT:SetObjectHealth(health)
	self:SetDTFloat(0, health)
	if health <= 0 and not self.Destroyed then
		self.Destroyed = true
	end
end

function ENT:GetObjectHealth()
	return self:GetDTFloat(0)
end

function ENT:SetMaxObjectHealth(health)
	self:SetDTFloat(1, health)
end

function ENT:GetMaxObjectHealth()
	return self:GetDTFloat(1)
end

function ENT:SetObjectOwner(ent)
	self:SetDTEntity(0, ent)
end

function ENT:GetObjectOwner()
	return self:GetDTEntity(0)
end

function ENT:ClearObjectOwner()
	self:SetObjectOwner(NULL)
end

function ENT:SetGrowEnd(t)
	self:SetDTFloat(2, t or 0)
end

function ENT:GetGrowEnd()
	return self:GetDTFloat(2)
end

function ENT:SetGrown(on)
	self:SetDTBool(1, on and true or false)
end

function ENT:GetGrown()
	return self:GetDTBool(1)
end

function ENT:GetGrowRemaining()
	if self:GetGrown() then
		return 0
	end
	return math.max(0, self:GetGrowEnd() - CurTime())
end
