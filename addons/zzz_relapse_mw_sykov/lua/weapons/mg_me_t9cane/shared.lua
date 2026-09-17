AddCSLuaFile()

SWEP.Base = "mg_base"

include("mg_melee_shared.lua")
include("animations.lua")

if CLIENT then
	killicon.Add("mg_me_t9cane", "zombiesurvival/killicons/weapon_zs_cwcane2.png", Color(255, 255, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_cwcane2.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_cwcane2.png"
-- WM already has the cane mesh (shaft along +Z, crook +X). No default attachments.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/easy/cw/weapons/wm_me_t9cane.mdl",
}
-- Same family as the machete: shaft +Z. 45 around the handle lays the stick
-- on the card; the crook stays on the +X end.
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(45, 0, 45)
SWEP.RelapsePreviewOffset = Vector(0, 0, -1)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.4
SWEP.RelapseMeleeCameraScale = 0.10

SWEP.PrintName = "Трость"
SWEP.Description = "A walking cane. Wood, not an edge: it reaches the one in the doorway, if you have the time."
SWEP.TranslationName = "wep_cwcane"
SWEP.TranslationDescription = "wep_cwcane_desc"
SWEP.Category = "Black Ops: Cold War"
SWEP.SubCategory = "Melees"
SWEP.Spawnable = true
SWEP.VModel = Model("models/easy/cw/weapons/vm_me_t9cane.mdl")
SWEP.WorldModel = Model("models/easy/cw/weapons/wm_me_t9cane.mdl")
SWEP.Purpose = "A walking cane. Wood, not an edge: it reaches the one in the doorway, if you have the time."
SWEP.Author = "easy4115"

SWEP.Slot = 0
SWEP.HoldType = "Melee2"
SWEP.IsMelee = true

-- Relapse combat stats. Source of truth for melee usefulness and the shop UI.
-- Damage is per swing. Delay is time between swings. Swing is windup before the trace.
-- Stopping is knockback. Range is hull trace hu. Weight is kilograms (wooden cane ~0.50 kg).
-- Nine hits on 225, not CoD 65. Longer blunt than the kit knife: the doorway, if you wait.
SWEP.Relapse = {
	Melee = true,
	Type = "blunt",
	Damage = 25,
	Delay = 0.75,
	Swing = 0.40,
	Stopping = 55,
	Range = 54,
	Weight = 0.50,
	DamageType = DMG_CLUB,
}

local R = SWEP.Relapse

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.RPM = math.floor(60 / R.Delay + 0.5)
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.ClipSize = -1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = true
SWEP.MeleeDamage = R.Damage
SWEP.MeleeRange = R.Range
SWEP.MeleeKnockBack = R.Stopping
SWEP.SwingTime = R.Swing

SWEP.HoldTypes = {
	Melee2 = {
		Idle = {Crouching = "melee2", Standing = "melee2"},
		Aim = {Crouching = "melee2", Standing = "melee2"},
		Down = {Crouching = "normal", Standing = "normal"},
		Attack = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE,
		Draw = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE,
		Deploy = ACT_GMOD_GESTURE_ITEM_PLACE,
		Melee = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE2
	}
}

SWEP.Bullet = {
	Damage = {R.Damage, R.Damage},
	DropOffStartRange = 0.8,
	EffectiveRange = 0.8,
	Range = 0.8,
	Tracer = false,
	NumBullets = 1,
	PhysicsMultiplier = 1,
	HeadshotMultiplier = 1,
	Penetration = {
		DamageMultiplier = 0.75,
		MaxCount = 3,
		Thickness = 7,
	}
}

SWEP.WorldModelOffsets = {
	Bone = "tag_knife_offset",
	Angles = Angle(0, 90, 180),
	Pos = Vector(3, -1, 4)
}

SWEP.ViewModelOffsets = {
	Aim = {
		Angles = Angle(0, 0, 0),
		Pos = Vector(0.15, 0, 0)
	},
	Idle = {
		Angles = Angle(0, 0, 0),
		Pos = Vector(0, 0, 0)
	},
	Inspection = {
		Bone = "tag_knife_offset",
		X = {
			[0] = {Pos = Vector(0, 2, -2), Angles = Angle(30, 0, -30)},
			[1] = {Pos = Vector(0, 0, 0), Angles = Angle(0, 0, 0)}
		},
		Y = {
			[0] = {Pos = Vector(-1, 0, 0), Angles = Angle(-10, -30, 0)},
			[1] = {Pos = Vector(-4, 0, 0), Angles = Angle(0, 30, 0)}
		}
	},
	Sprint = {
		Angles = Angle(0, 0, 0),
		Pos = Vector(0, 0, 0),
	},

	RecoilMultiplier = 1,
	KickMultiplier = 0.10
}

SWEP.Customization = {
	{"att_receiver"},
}

require("mw_utils")
mw_utils.LoadInjectors(SWEP)

SWEP.MeleeDamageType = DMG_CLUB

SWEP.MeleeSounds = {
	Flesh = "MW_Melee.Flesh_Small",
	Cement = "MW_Melee.Flesh_Small",
	Metal = "MW_Melee.Flesh_Small",
	Soft = "MW_Melee.Flesh_Small",
	Wood = "MW_Melee.Flesh_Small",
}

local melee = SWEP.Animations and SWEP.Animations.Melee
if melee then
	melee.Range = R.Range
	melee.Delay = R.Swing
	melee.Length = R.Delay
end

local hit = SWEP.Animations and SWEP.Animations.Melee_Hit
if hit then
	hit.Damage = R.Damage
	hit.Length = R.Delay * (11 / 15)
	hit.DamageType = DMG_CLUB
	hit.DamageForce = R.Stopping * 20
end
