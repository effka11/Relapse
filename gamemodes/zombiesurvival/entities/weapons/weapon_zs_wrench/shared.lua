SWEP.PrintName = "Гаечный ключ"
SWEP.TranslationName = "wep_wrench"
SWEP.TranslationDescription = "wep_wrench_desc"
SWEP.Description = "A mechanic's wrench. It puts crates and machines back together, if they have not just been torn open."

SWEP.Base = "weapon_zs_basemelee"

SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/props_c17/tools_wrench01a.mdl"
SWEP.ModelScale = 1.5
SWEP.UseHands = true

-- Prop lies in XY (handle +Y). Same shop pose as the hammer: pitch 45
-- toward the camera, roll 45 to the right.
SWEP.RelapsePreviewParts = {
	"models/props_c17/tools_wrench01a.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(45, 0, 45)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.6
SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_wrench2.png"

if CLIENT then
	killicon.Add("weapon_zs_wrench", "zombiesurvival/killicons/weapon_zs_wrench2.png", Color(255, 255, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_wrench2.png")
end

SWEP.HoldType = "melee"

SWEP.DamageType = DMG_CLUB

SWEP.Primary.Delay = 0.8
SWEP.MeleeDamage = 28
SWEP.MeleeRange = 50
SWEP.MeleeSize = 0.875

SWEP.MaxStock = 5

SWEP.HitGesture = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE
SWEP.MissGesture = SWEP.HitGesture

SWEP.SwingTime = 0.19
SWEP.SwingRotation = Angle(30, -30, -30)
SWEP.SwingOffset = Vector(0, -30, 0)
SWEP.SwingHoldType = "grenade"

SWEP.HealStrength = 13

SWEP.AllowQualityWeapons = true

GAMEMODE:SetPrimaryWeaponModifier(SWEP, WEAPON_MODIFIER_FIRE_DELAY, -0.04)
GAMEMODE:AttachWeaponModifier(SWEP, WEAPON_MODIFIER_MELEE_RANGE, 3, 1)

function SWEP:PlayHitSound()
	self:EmitSound("weapons/melee/crowbar/crowbar_hit-"..math.random(4)..".ogg", 75, math.random(120, 125))
end
