AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_pl_5")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_357", "zombiesurvival/killicons/weapon_zs_python357_3.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_python357_3.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_python357_3.png"
-- World frame already has the cylinder. VM mag has ShowOnWorldModel=false and
-- no WM bones — bone-merging it leaves a speedloader floating at origin.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_357.mdl",
	"models/viper/mw/attachments/attachment_vm_pi_cpapa_barrel.mdl",
}
-- WM barrel is along +Z at identity; roll 90 puts it along Y for a side view.
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.65

SWEP.Base = "mg_base"

SWEP.PrintName = "Револьвер .357"
SWEP.TranslationName = "wep_357"
SWEP.TranslationDescription = "wep_357_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Pistols"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_357.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_357.mdl")

SWEP.Slot = 1
SWEP.HoldType = "Revolver"

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (Colt Python 6" empty ~1.30 kg). Clip is the real 6-round cylinder.
-- .357 Magnum: hotter than .45 ACP 1911 (28) and 9x19 USP/Battleaxe (24). DA is slow.
SWEP.Relapse = {
    Damage = 42,
    Delay = 0.43,
    Reload = 3.00,
    Kinetic = 0.28,
    Recoil = 1.20,
    Accuracy = 1.05,
    Weight = 1.30,
    Clip = 6,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_pl_5",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
}

SWEP.Trigger = {
    PressedSound = Sound("wfoly_plr_pi_cpapa_charge_in_01"),
    PressedAnimation = "Charge",
    Time = 0.075
}

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_cpapa_fire_plr")
SWEP.Primary.Ammo = "357mag"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize = R.Clip
SWEP.Primary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = math.floor(60 / R.Delay + 0.5)
SWEP.CanChamberRound = false
SWEP.CanDisableAimReload = true
SWEP.ReloadTime = R.Reload
SWEP.ConeMin = R.Accuracy * 0.5
SWEP.ConeMax = R.Accuracy * 1.5
SWEP.ConeRamp = 2
SWEP.DrawCrosshair = false

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_Pistol_Mag.Outside"),
            Reflection = Sound("Reflection_Pistol.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_Shotgun.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Semi Auto",
        OnSet = function()
            return nil
        end
    },
}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_pistol_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 100,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
}

SWEP.Cone = {
    Hip = R.Accuracy / 36,
    TacStance = false,
    Ads = R.Accuracy / 36,
    Increase = 0.1 * (R.Accuracy / 1.8),
    TacStanceMultiplier = 0.9,
    AdsMultiplier = 0.15,
    Max = R.Accuracy * (1.3 / 1.8),
}

SWEP.Recoil = {
    Vertical = {0.08 * R.Recoil, 0.17 * R.Recoil},
    Horizontal = {-0.17 * R.Recoil, 0.17 * R.Recoil},
    Shake = 2.0 * R.Recoil,
    AdsMultiplier = 0.75,
    Seed = 610312
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 12,
    EffectiveRange = 35, --in meters, damage scales within this distance
    Range = 100, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 0.5, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.95, --how much damaged is multipled by when leaving a surface.
        MaxCount = 6, --how many times the bullet can penetrate.
        Thickness = 14, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.2,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 15
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_pistol_offset",
    Angles = Angle(0, 90, -90),
    Pos = Vector(4.5, -3, -2.5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, -4, 0)
    },
    TacStance = {
        Angles = Angle(-0.3, 0.05, -45),
        Pos = Vector(-1.5, 2, -1)
    },
    Idle = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 0, 0)
    },
    Inspection = {
        Bone = "tag_pistol_offset",
        X = {
            [0] = {Pos = Vector(0, 2, -2), Angles = Angle(30, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(0, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(2, 0, 0), Angles = Angle(-30, -30, 0)},
            [1] = {Pos = Vector(-4, 0, 0), Angles = Angle(0, 30, 0)}
        }
    }
}

SWEP.Shell = "mwb_shelleject_50bmg"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "They carried it if six shots were enough. The trigger does not hurry, the hit does. It's worth aiming."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
