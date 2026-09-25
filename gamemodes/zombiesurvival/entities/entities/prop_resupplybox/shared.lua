ENT.Type = "anim"

ENT.m_NoNailUnfreeze = true
ENT.NoNails = true

ENT.CanPackUp = true

ENT.IsBarricadeObject = true
ENT.AlwaysGhostable = true

local CRATE_MODEL = "models/ammo/fas2/ammocrate.mdl"

ENT.CrateScale = 0.75

-- Same faces as the hit box. Pack-up uses NearestPoint: a zero box is the floor origin,
-- farther than 64 from the eyes, so the fold drops and plays the deny sound.
local PACK_MIN = Vector(-13.4775, -28.9425, 0)
local PACK_MAX = Vector(19.0125, 30.1125, 27.0675)

-- The ammo model is only drawn. The solid is a frozen box prop, same path as the arsenal crate.
function ENT:KillModelCollision()
	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		self:PhysicsDestroy()
	end

	if self:GetMoveType() ~= MOVETYPE_NONE then
		self:SetMoveType(MOVETYPE_NONE)
	end
	if self:GetSolid() ~= SOLID_NONE then
		self:SetSolid(SOLID_NONE)
	end
	self:SetNotSolid(true)
	-- Open sequence hull is wider than the body on the front and back. If it comes back solid,
	-- debris still does not stop a player, so that hull cannot hold them short of the box.
	if self:GetCollisionGroup() ~= COLLISION_GROUP_DEBRIS then
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	end
	self:SetCollisionBounds(PACK_MIN, PACK_MAX)

	local custom = 0
	if FSOLID_CUSTOMRAYTEST then custom = bit.bor(custom, FSOLID_CUSTOMRAYTEST) end
	if FSOLID_CUSTOMBOXTEST then custom = bit.bor(custom, FSOLID_CUSTOMBOXTEST) end
	if custom ~= 0 and bit.band(self:GetSolidFlags(), custom) ~= 0 then
		self:RemoveSolidFlags(custom)
	end

	if not self.CrateNoCollide then
		self.CrateNoCollide = true
		self:SetCustomCollisionCheck(true)
		if self.CollisionRulesChanged then
			self:CollisionRulesChanged()
		end
	end
end

function ENT:ShouldNotCollide()
	return true
end

function ENT:ApplyOpenCrate()
	if self:GetModel() ~= CRATE_MODEL then return end

	local seq = self:LookupSequence("Open")
	if not seq or seq < 0 then return end

	if self:GetSequence() ~= seq then
		self:ResetSequence(seq)
	end

	self:SetPlaybackRate(0)
	self:SetCycle(1)
end

function ENT:SetObjectHealth(health)
	self:SetDTFloat(0, health)
	if health <= 0 and not self.Destroyed then
		self.Destroyed = true
		self:FakePropBreak()
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
