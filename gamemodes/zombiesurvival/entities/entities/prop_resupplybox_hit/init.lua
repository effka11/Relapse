INC_SERVER()

function ENT:Initialize()
	self:BuildHit()
	self:SetUseType(SIMPLE_USE)
	if self.CollisionRulesChanged then
		self:CollisionRulesChanged()
	end
end

function ENT:Use(activator, caller)
	local crate = self.Crate
	if crate:IsValid() then
		crate:Use(activator, caller)
	end
end

function ENT:AltUse(activator, tr)
	local crate = self.Crate
	if crate:IsValid() then
		return crate:AltUse(activator, tr)
	end
end

function ENT:OnTakeDamage(dmginfo)
	if dmginfo:GetDamage() <= 0 then return end

	local crate = self.Crate
	if crate:IsValid() then
		crate:TakeDamageInfo(dmginfo)
	end
end
