ENT.Type = "anim"

ENT.NoNails = true
ENT.PhysgunDisabled = true

local MODEL = "models/ammo/fas2/cratehit.mdl"

function ENT:BuildHit()
	if self:GetModel() ~= MODEL then
		self:SetModel(MODEL)
	end

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetNoDraw(true)
	self:DrawShadow(false)

	local custom = 0
	if FSOLID_CUSTOMRAYTEST then custom = bit.bor(custom, FSOLID_CUSTOMRAYTEST) end
	if FSOLID_CUSTOMBOXTEST then custom = bit.bor(custom, FSOLID_CUSTOMBOXTEST) end
	if custom ~= 0 then
		self:RemoveSolidFlags(custom)
	end

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:EnableMotion(false)
	end

	self:SetUseType(SIMPLE_USE)
end
