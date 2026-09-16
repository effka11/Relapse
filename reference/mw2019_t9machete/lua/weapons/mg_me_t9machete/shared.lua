AddCSLuaFile()

SWEP.Base = "mg_base"

include("mg_melee_shared.lua")
include("animations.lua")

if CLIENT then
	killicon.Add( "mg_me_t9machete", "VGUI/entities/mg_me_t9machete", Color(255, 0, 0, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_me_t9machete")
end

SWEP.PrintName = "Machete"
SWEP.Category = "Black Ops: Cold War"
SWEP.SubCategory = "Melees"
SWEP.Spawnable = true
SWEP.VModel = Model("models/easy/cw/weapons/vm_me_t9machete.mdl")
SWEP.WorldModel = Model("models/easy/cw/weapons/wm_me_t9machete.mdl")
SWEP.Purpose = "Manufactured from a durable steel blade tempered to maximum toughness to resist chipping and breaking. Popular in many tropical countries as both a weapon and an agricultural tool."
SWEP.Author = "easy4115"

SWEP.Slot = 0
SWEP.HoldType = "Knife"
SWEP.Primary.RPM = 170

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
	Damage = {90, 90}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
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
	Angles = Angle(0, -0, 210),
	Pos = Vector(3, -1, -1.5)
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

SWEP.MeleeDamageType = DMG_SLASH + DMG_ALWAYSGIB

SWEP.MeleeSounds = {
	Flesh = "MW_Melee.Flesh_Knife",
	Cement = "MW_Melee.Cement_Knife",
	Metal = "MW_Melee.Metal_Knife",
	Soft = "MW_Melee.Soft_Knife",
	Wood = "MW_Melee.Wood_Knife",
}