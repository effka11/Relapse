AddCSLuaFile()

SWEP.Base = "mg_base"

include("mg_melee_shared.lua")
include("animations.lua")

if CLIENT then
	killicon.Add("mg_me_t9etool", "zombiesurvival/killicons/weapon_zs_cwetool2.png", Color(255, 255, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_cwetool2.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_cwetool2.png"
-- WM already has the shovel mesh (shaft along +Z, blade +X). No default attachments.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/easy/cw/weapons/wm_me_t9etool.mdl",
}
-- Same family as the machete: handle +Z. 45 around the handle lays the shaft
-- on the card; the blade stays on the +X side.
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(45, 0, 45)
SWEP.RelapsePreviewOffset = Vector(0, 0, -1)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.0
SWEP.RelapseMeleeCameraScale = 0.10

SWEP.PrintName = "Лопата"
SWEP.Description = "A folding shovel. Steel, not a stick: it reaches the one in the doorway, not the one behind him."
SWEP.TranslationName = "wep_cwetool"
SWEP.TranslationDescription = "wep_cwetool_desc"
SWEP.Category = "Black Ops: Cold War"
SWEP.SubCategory = "Melees"
SWEP.Spawnable = true
SWEP.VModel = Model("models/easy/cw/weapons/vm_me_t9etool.mdl")
SWEP.WorldModel = Model("models/easy/cw/weapons/wm_me_t9etool.mdl")
SWEP.Purpose = "A folding shovel. Steel, not a stick: it reaches the one in the doorway, not the one behind him."
SWEP.Author = "easy4115"

SWEP.Slot = 0
SWEP.HoldType = "Knife"
SWEP.IsMelee = true

-- Relapse combat stats. Source of truth for melee usefulness and the shop UI.
-- Damage is per swing. Delay is time between swings. Swing is windup before the trace.
-- Stopping is knockback. Range is hull trace hu. Weight is kilograms (folding e-tool ~0.80 kg).
-- Seven hits on 225, not CoD 40. Steel shovel: the doorway, not as fast as the knife and not as long as the bat.
SWEP.Relapse = {
	Melee = true,
	Type = "blunt",
	Damage = 33,
	Delay = 0.62,
	Swing = 0.25,
	Stopping = 50,
	Range = 52,
	Weight = 0.80,
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
	Knife = {
		Idle = {Crouching = "fist", Standing = "fist"},
		Aim = {Crouching = "fist", Standing = "fist"},
		Down = {Crouching = "normal", Standing = "normal"},
		Attack = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE,
		Draw = ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE,
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
	Bone = "tag_knife_offset",
	Angles = Angle(0, -90, 180),
	Pos = Vector(3, -1, 6)
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
		Pos = Vector(0, 0, -4.5),
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
