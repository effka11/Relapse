ENT.Type = "anim"
ENT.Base = "prop_baseoutlined"

ENT.NoNails = true

function ENT:HumanHoldable(pl)
	if pl:KeyDown(GAMEMODE.UtilityKey) then return true end
	if not pl:HasWeapon(self:GetWeaponType()) then return false end
	-- GetClip1 is server-only. Unknown clips are not an empty husk.
	if not self.GetClip1 then return false end
	return self:GetClip1() == 0 and self:GetClip2() == 0
end

function ENT:SetWeaponType(class)
	local weptab = weapons.Get(class)
	if string.sub(class, 1, 12) == "weapon_zs_t_" then -- Convertor
		if SERVER then
			self:MakeInvItemConvert(class)
		end
	elseif weptab then
		if weptab.WorldModel then
			self:SetModel(weptab.WorldModel)
		end

		if SERVER then
			self:SetupPhysics(weptab)
		end

		if weptab.ModelScale then
			self:SetModelScale(weptab.ModelScale, 0)
		end
	end

	self:SetDTString(0, class)
end

function ENT:GetWeaponType()
	return self:GetDTString(0)
end
