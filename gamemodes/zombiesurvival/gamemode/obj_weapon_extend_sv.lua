local meta = FindMetaTable("Weapon")

local function AmmoName(ammo)
	return isstring(ammo) and string.lower(ammo) or "none"
end

function meta:EmptyAll(nodefaultclip)
	if self.Primary and AmmoName(self.Primary.Ammo) ~= "none" then
		local owner = self:GetOwner()
		if owner:IsValid() then
			if self:Clip1() >= 1 then
				owner:GiveAmmo(self:Clip1(), self.Primary.Ammo, true)
			end
			if not nodefaultclip then
				owner:RemoveAmmo(self.Primary.DefaultClip, self.Primary.Ammo)
			end
		end
		self:SetClip1(0)
	end
	if self.Secondary and AmmoName(self.Secondary.Ammo) ~= "none" then
		local owner = self:GetOwner()
		if owner:IsValid() then
			if self:Clip2() >= 1 then
				owner:GiveAmmo(self:Clip2(), self.Secondary.Ammo, true)
			end
			if not nodefaultclip then
				owner:RemoveAmmo(self.Secondary.DefaultClip, self.Secondary.Ammo)
			end
		end
		self:SetClip2(0)
	end
end

function meta:HideWorldModel()
	self:DrawShadow(false)
end

function meta:HideViewModel()
end
