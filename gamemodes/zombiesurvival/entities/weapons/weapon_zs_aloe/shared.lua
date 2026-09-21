SWEP.PrintName = "Фикус К-4"
SWEP.TranslationName = "wep_aloe"
SWEP.TranslationDescription = "wep_aloe_desc"
SWEP.TranslationDescriptionShop = "wep_aloe_desc_shop"
SWEP.Description = "The fourth culture by the best botanists still alive — a plant against wounds, disease, and toxins: through mixotrophic photosynthesis it turns Mycelida spores into healing compounds. This prototype was the first that succeeded. Russian troops found it in an abandoned SB RAS laboratory. The botanists themselves were never found."

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = Model("models/srp/prop_pbucket.mdl")

SWEP.AmmoIfHas = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Ammo = "aloe"
SWEP.Primary.Delay = 1
SWEP.Primary.Automatic = true

SWEP.Secondary.ClipSize = 1
SWEP.Secondary.DefaultClip = 1
SWEP.Secondary.Ammo = "dummy"

SWEP.WalkSpeed = SPEED_NORMAL
SWEP.FullWalkSpeed = SPEED_SLOWEST

SWEP.NoDeploySpeedChange = true

SWEP.RelapsePreviewModel = "models/srp/prop_pbucket.mdl"
SWEP.RelapsePreviewParts = {
	"models/srp/prop_cocaleaves.mdl",
}
SWEP.RelapsePreviewPartLocalPos = Vector(0, 0, 8)
SWEP.RelapsePreviewPartLocalAng = Angle(0, 180, 0)
SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_aloe_k4.png"
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 0)
SWEP.RelapsePreviewLift = 0.4
SWEP.RelapsePreviewCamScale = 1.5
SWEP.RelapsePreviewDistMax = 118

function SWEP:Initialize()
	self:SetWeaponHoldType("slam")
	self:SetDeploySpeed(10)
	self:HideViewAndWorldModel()
end

function SWEP:SetReplicatedAmmo(count)
	self:SetDTInt(0, count)
end

function SWEP:GetReplicatedAmmo()
	return self:GetDTInt(0)
end

function SWEP:GetWalkSpeed()
	if self:GetPrimaryAmmoCount() > 0 then
		return self.FullWalkSpeed
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:CanPrimaryAttack()
	if self:GetOwner():IsHolding() or self:GetOwner():GetBarricadeGhosting() then return false end

	if self:GetPrimaryAmmoCount() <= 0 then
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
		return false
	end

	return true
end

function SWEP:Holster()
	return true
end
