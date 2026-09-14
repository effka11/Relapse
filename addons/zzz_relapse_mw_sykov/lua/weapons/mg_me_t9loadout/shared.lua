AddCSLuaFile()

SWEP.Base = "mg_base"

include("mg_melee_shared.lua")
include("animations.lua")

if CLIENT then
	killicon.Add("mg_me_t9loadout", "zombiesurvival/killicons/weapon_zs_cwknife2.png", Color(255, 255, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_cwknife2.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_cwknife2.png"
-- WM already has the knife mesh (hull along +Z). No default attachments.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/easy/cw/weapons/wm_me_t9loadout.mdl",
}
-- Tip is -Z. Edge faces +X (it was up at -135/0/45). 180 around the handle
-- (+Z) flips the edge down; the tip stays on the same end.
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(45, 0, 135)
SWEP.RelapsePreviewOffset = Vector(0, 0, -1)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.0

SWEP.PrintName = "Нож"
SWEP.Description = "A service knife. Issued with the kit: it reaches the one in the doorway, not the one behind him."
SWEP.TranslationName = "wep_cwknife"
SWEP.TranslationDescription = "wep_cwknife_desc"
SWEP.Category = "Black Ops: Cold War"
SWEP.SubCategory = "Melees"
SWEP.Spawnable = true
SWEP.VModel = Model("models/easy/cw/weapons/vm_me_t9loadout.mdl")
SWEP.WorldModel = Model("models/easy/cw/weapons/wm_me_t9loadout.mdl")
SWEP.Purpose = "A service knife. Issued with the kit: it reaches the one in the doorway, not the one behind him."
SWEP.Author = "easy4115"

SWEP.Slot = 0
SWEP.HoldType = "Knife"
SWEP.IsMelee = true

-- Relapse combat stats. Source of truth for melee usefulness and the shop UI.
-- Damage is per swing. Delay is time between swings. Swing is windup before the trace.
-- Stopping is knockback. Range is hull trace hu. Weight is kilograms (Ka-Bar ~0.32 kg).
-- Below crowbar 35: short slash, not CoD 45.
SWEP.Relapse = {
	Melee = true,
	Type = "slash",
	Damage = 24,
	Delay = 0.55,
	Swing = 0.20,
	Stopping = 40,
	Range = 48,
	Weight = 0.32,
}

local R = SWEP.Relapse

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.RPM = math.floor(60 / R.Delay + 0.5)
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.ClipSize = -1
SWEP.Primary.Ammo = "none"
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
	Pos = Vector(3, -1, 2)
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
		Pos = Vector(0, 4, -6.5),
	},

	RecoilMultiplier = 1,
	KickMultiplier = 1
}

SWEP.Customization = {
	{"att_receiver"},
}

require("mw_utils")
mw_utils.LoadInjectors(SWEP)

SWEP.MeleeDamageType = DMG_SLASH

SWEP.MeleeSounds = {
	Flesh = "MW_Melee.Flesh_Knife",
	Cement = "MW_Melee.Cement_Knife",
	Metal = "MW_Melee.Metal_Knife",
	Soft = "MW_Melee.Soft_Knife",
	Wood = "MW_Melee.Wood_Knife",
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
	hit.DamageType = DMG_SLASH
	hit.DamageForce = R.Stopping * 20
end
