AddCSLuaFile()

SWEP.Base = "mg_base"

include("mg_melee_shared.lua")
include("animations.lua")

if CLIENT then
	killicon.Add( "mg_me_t9sledgehammer", "VGUI/entities/mg_me_t9sledgehammer", Color(255, 0, 0, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_me_t9sledgehanmmer")
end

SWEP.PrintName = "Sledgehammer" 
SWEP.Category = "Black Ops: Cold War"
SWEP.SubCategory = "Melees"
SWEP.Spawnable = true
SWEP.VModel = Model("models/easy/cw/weapons/vm_me_t9sledgehammer.mdl")
SWEP.WorldModel = Model("models/easy/cw/weapons/wm_me_t9sledgehammer.mdl")
SWEP.Purpose = "Derived from the word ''slægan,'' meaning ''to strike violently.'' Distributes a large amount of force over a small area and repurposed to demolish your enemies instead of dry wall."
SWEP.Author = "easy4115"
SWEP.FreezeInspectDelta = 0.4
SWEP.Slot = 0
SWEP.HoldType = "Melee2"
SWEP.Primary.RPM = 170

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
	Damage = {105, 105}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
	DropOffStartRange = 0.8,
	EffectiveRange = 0.8, --in meters, damage scales within this distance
	Range = 0.8, --in meters, after this distance the bullet stops existing
	Tracer = false, --show tracer
	NumBullets = 1, --the amount of bullets to fire
	PhysicsMultiplier = 1, --damage is multiplied by this amount when pushing objects
	HeadshotMultiplier = 1,
	Penetration = {
		DamageMultiplier = 0.75, --how much damaged is multipled by when leaving a surface.
		MaxCount = 3, --how many times the bullet can penetrate.
		Thickness = 7, --in hu, how thick an obstacle has to be to stop the bullet.
	}
}

SWEP.WorldModelOffsets = {
	Bone = "tag_knife_offset",
	Angles = Angle(0, -90, 180),
	Pos = Vector(3, -1, -2)
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
	Sprint = { -- I would prefer sprint_offset to work properly instead
		Angles = Angle(0, 0, 0),
		Pos = Vector(0, 0, -0),
	},

	RecoilMultiplier = 1,
	KickMultiplier = 1
}

SWEP.Customization = {
	{"att_receiver"},
}

require("mw_utils")
mw_utils.LoadInjectors(SWEP)

SWEP.MeleeDamageType = DMG_CLUB + DMG_ALWAYSGIB

SWEP.MeleeSounds = {
	Flesh = "MW_Melee.Flesh_Large",
	Cement = "MW_Melee.Flesh_Large",
	Metal = "MW_Melee.Flesh_Large",
	Soft = "MW_Melee.Flesh_Large",
	Wood = "MW_Melee.Flesh_Large",
}