AddCSLuaFile()

SWEP.Base = "mg_base"

include("mg_melee_shared.lua")
include("animations.lua")

if CLIENT then
	killicon.Add("mg_cinderblock", "zombiesurvival/killicons/weapon_zs_cinderblock.png", Color(255, 255, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_cinderblock.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_cinderblock.png"
-- WM already has the block mesh (long axis +Y, holes through Y). No default attachments.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_cinderblock.mdl",
}
-- Long +Y. Yaw 90 lays that axis on -X so the camera looks into the holes.
SWEP.RelapsePreviewAngle = Angle(0, 90, 0)
SWEP.RelapsePreviewOffset = Vector(0, 0, 0)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.6
SWEP.RelapseMeleeCameraScale = 0.10

SWEP.PrintName = "Шлакоблок"
SWEP.Description = "A concrete block. It drops the one in front of you, not the one in the doorway."
SWEP.TranslationName = "wep_cinderblock"
SWEP.TranslationDescription = "wep_cinderblock_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Melee"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_cinderblock.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_cinderblock.mdl")
SWEP.Purpose = "A concrete block. It drops the one in front of you, not the one in the doorway."

SWEP.Slot = 0
SWEP.HoldType = "Cinderblock"
SWEP.IsMelee = true

-- Relapse combat stats. Source of truth for melee usefulness and the shop UI.
-- Damage is per swing. Delay is time between swings. Swing is windup before the trace.
-- Stopping is knockback. Range is hull trace hu. Weight is kilograms (concrete block ~12 kg).
-- Nine hits on 225, not CoD 45. Shorter blunt than the cane: the one in front of you.
SWEP.Relapse = {
	Melee = true,
	Type = "blunt",
	Damage = 25,
	Delay = 1.00,
	Swing = 0.25,
	Stopping = 70,
	Range = 44,
	Weight = 12.00,
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
	Cinderblock = {
		Idle = {Crouching = "duel", Standing = "duel"},
		Aim = {Crouching = "fist", Standing = "fist"},
		Down = {Crouching = "normal", Standing = "normal"},
		Attack = ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST,
		Draw = ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST,
		Deploy = ACT_GMOD_GESTURE_ITEM_PLACE,
		Melee = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE
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
	Bone = "j_gun",
	Angles = Angle(0, -15, -170),
	Pos = Vector(0, -12, -2)
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
	Flesh = "MW_Melee.Hit_Cinderblock",
	Cement = "MW_Melee.Hit_Cinderblock",
	Metal = "MW_Melee.Hit_Cinderblock",
	Soft = "MW_Melee.Hit_Cinderblock",
	Wood = "MW_Melee.Hit_Cinderblock",
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
