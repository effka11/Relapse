SWEP.Base = "weapon_zs_basemelee"

SWEP.PrintName = "Молоток"
SWEP.TranslationName = "wep_hammer"
SWEP.TranslationDescription = "wep_hammer_desc"
SWEP.Description = "A carpenter's hammer. It drives nails, pulls them, and mends the ones that hold. The board lasts as long as the nail."

SWEP.DamageType = DMG_CLUB

SWEP.ViewModel = "models/weapons/v_hammer/c_hammer.mdl"
SWEP.WorldModel = "models/weapons/w_hammer.mdl"
SWEP.UseHands = true

-- WM handle is +Z (same as 1911). Pitch 45 tips the top toward the camera
-- (+X); roll 45 leans the head to the right (same sign as gun LocalAng 90).
SWEP.RelapsePreviewParts = {
	"models/weapons/w_hammer.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(45, 0, 45)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.6
SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_hammer3.png"

if CLIENT then
	killicon.Add("weapon_zs_hammer", "zombiesurvival/killicons/weapon_zs_hammer3.png", Color(255, 255, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_hammer3.png")
end

SWEP.Primary.ClipSize = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "GaussEnergy"
SWEP.Primary.Delay = 1
SWEP.Primary.DefaultClip = 16
SWEP.RelapsePoolAmmo = true

SWEP.Secondary.ClipSize = 1
SWEP.Secondary.DefaultClip = 1
SWEP.Secondary.Ammo = "dummy"

--SWEP.MeleeDamage = 35 -- Reduced due to instant swing speed
SWEP.MeleeDamage = 15
SWEP.MeleeRange = 50
SWEP.MeleeSize = 0.875

SWEP.MaxStock = 5

SWEP.UseMelee1 = true

-- RMB nails instead of throwing the carried prop.
SWEP.NoPropThrowing = true

SWEP.HitGesture = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE
SWEP.MissGesture = SWEP.HitGesture

SWEP.HealStrength = 1

SWEP.NoGlassWeapons = true

SWEP.AllowQualityWeapons = true

GAMEMODE:SetPrimaryWeaponModifier(SWEP, WEAPON_MODIFIER_FIRE_DELAY, -0.04)
GAMEMODE:AttachWeaponModifier(SWEP, WEAPON_MODIFIER_MELEE_RANGE, 3, 1)

function SWEP:SetNextAttack()
	local owner = self:GetOwner()
	local armdelay = owner:GetMeleeSpeedMul()
	local swing = GAMEMODE:GetHammerSwingPercentMul(owner)
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay * armdelay / math.max(swing, 0.01))
end

function SWEP:PlayHitSound()
	self:EmitSound("weapons/melee/crowbar/crowbar_hit-"..math.random(4)..".ogg", 75, math.random(110, 115))
end

function SWEP:PlayRepairSound(hitent)
	hitent:EmitSound("npc/dog/dog_servo"..math.random(7, 8)..".wav", 70, math.random(100, 105))
end
