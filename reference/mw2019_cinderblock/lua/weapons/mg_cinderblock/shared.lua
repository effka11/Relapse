AddCSLuaFile()

SWEP.Base = "mg_base"

include("mg_melee_shared.lua")
include("animations.lua")

if CLIENT then
	killicon.Add( "mg_cinderblock", "VGUI/entities/mg_cinderblock", Color(255, 0, 0, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/mg_cinderblock")
end

SWEP.PrintName = "Cinderblock"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Melee"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_cinderblock.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_cinderblock.mdl")

SWEP.Slot = 0
SWEP.HoldType = "Cinderblock"
SWEP.Primary.RPM = 50

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
	Damage = {45, 45}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
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

	RecoilMultiplier = 1,
	KickMultiplier = 1
}

SWEP.Customization = {
	{"att_receiver"},
}

SWEP.MeleeDamageType = DMG_CLUB + DMG_ALWAYSGIB

SWEP.MeleeSounds = {
	Flesh = "MW_Melee.Hit_Cinderblock",
	Cement = "MW_Melee.Hit_Cinderblock",
	Metal = "MW_Melee.Hit_Cinderblock",
	Soft = "MW_Melee.Hit_Cinderblock",
	Wood = "MW_Melee.Hit_Cinderblock",
}