AddCSLuaFile()

SWEP.Base = "mg_base"

include("mg_melee_shared.lua")
include("animations.lua")
include("nodraw.lua")

if CLIENT then
	killicon.Add("mg_fists", "zombiesurvival/killicons/weapon_zs_fists", Color(255, 255, 255))
	SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_fists")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_fists"
-- Rifle walk barely moves tag_camera. Fist VM bounces the same bone harder.
SWEP.RelapseMeleeCameraScale = 0.10
SWEP.RelapseWalkCameraScale = 0.15
SWEP.RelapseSprintCameraScale = 0.40
SWEP.RelapseSuperSprintCameraScale = 0.28

SWEP.PrintName = "Кулаки"
SWEP.Description = "Your hands. They reach the one in front of you, not the one in the doorway."
SWEP.TranslationName = "wep_fists"
SWEP.TranslationDescription = "wep_fists_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Melee"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_fists.mdl")
-- World mesh is a knife leftover from the pack; nodraw.lua hides it.
SWEP.WorldModel = Model("models/viper/mw/weapons/w_knife.mdl")
SWEP.Purpose = "Your hands. They reach the one in front of you, not the one in the doorway."

SWEP.Slot = 0
SWEP.SlotPos = 100
SWEP.HoldType = "Fists"
SWEP.WalkSpeed = SPEED_NORMAL
SWEP.IsMelee = true
SWEP.Unarmed = true
SWEP.IsFistWeapon = true
SWEP.Undroppable = true
SWEP.NoPickupNotification = true
SWEP.NoDismantle = true
SWEP.NoGlassWeapons = true

-- Same numbers as weapon_zs_fists. Overlay copies them onto GetStored if the
-- workshop SWEP file wins.
SWEP.Relapse = {
	Melee = true,
	Type = "unarmed",
	Damage = 15,
	Delay = 0.6,
	Swing = 0.25,
	Stopping = 0,
	Range = 40,
	Weight = 0,
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
	Fists = {
		Idle = {Crouching = "fist", Standing = "fist"},
		Aim = {Crouching = "fist", Standing = "fist"},
		Down = {Crouching = "normal", Standing = "normal"},
		Attack = ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST,
		Draw = ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST,
		Deploy = ACT_GMOD_GESTURE_ITEM_PLACE,
		Melee = ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST
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
	Angles = Angle(0, -90, 0),
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
	Sprint = {
		Angles = Angle(0, 0, 0),
		Pos = Vector(0, 4, -6.5),
	},

	RecoilMultiplier = 1,
	KickMultiplier = 0.10
}

SWEP.Customization = {
	{"att_receiver"},
}

require("mw_utils")
mw_utils.LoadInjectors(SWEP)

SWEP.MeleeDamageType = R.DamageType

SWEP.MeleeSounds = {
	Flesh = "MW_Melee.Flesh_Fists",
	Cement = "MW_Melee.Cement_Fists",
	Metal = "MW_Melee.Metal_Fists",
	Soft = "MW_Melee.Soft_Fists",
	Wood = "MW_Melee.Wood_Fists",
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
	hit.DamageType = R.DamageType
	hit.DamageForce = 0
end
