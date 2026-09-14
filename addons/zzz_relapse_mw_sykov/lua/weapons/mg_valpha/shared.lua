AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_ar_10")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_valpha", "zombiesurvival/killicons/weapon_zs_asval_side.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_asval_side.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_asval_side.png"
-- WM receiver has one model (default 0). Do not copy MP5 [0]=1.
-- Barrel, mag, and stock bone-merge onto tag_*_attach. DrawModel after SetupBones is +Z.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_valpha.mdl",
	"models/viper/mw/attachments/valpha/attachment_vm_ar_valpha_barrel.mdl",
	"models/viper/mw/attachments/valpha/attachment_vm_ar_valpha_mag.mdl",
	"models/viper/mw/attachments/valpha/attachment_vm_ar_valpha_stock.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewOffset = Vector(0, 0, -3)
SWEP.RelapsePreviewLift = 2.8
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_barheavy_offset", "grip_barlight_offset",
"grip_barshort_offset", "grip_magwell_offset"}

SWEP.PrintName = "АС «Вал»"
SWEP.TranslationName = "wep_asval"
SWEP.TranslationDescription = "wep_asval_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Assault Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_valpha.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_valpha.mdl")

SWEP.Slot = 3
SWEP.HoldType = "Rifle"
SWEP.Trigger = {
    PressedSound = Sound("mw19.valpha.fire.first"),
    ReleasedSound = Sound("mw19.valpha.disconnector"),
    Time = 0
}

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (AS VAL empty ~2.5 kg). Clip is the real 20-round mag.
-- 9x39 auto tax: above MP5 9x19 (16) per shot, well below SKS/SCAR, so ~885 RPM stays T4.
SWEP.Relapse = {
    Damage = 18,
    Delay = 0.068,
    Reload = 2.45,
    Kinetic = 0.30,
    Recoil = 0.90,
    Accuracy = 1.35,
    Weight = 2.50,
    Clip = 20,
    Automatic = true,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("mw19.valpha.fire")
SWEP.Primary.Ammo = "9x39"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize = R.Clip
SWEP.Primary.Automatic = true
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = math.floor(60 / R.Delay + 0.5)
SWEP.CanChamberRound = true
SWEP.CanDisableAimReload = false
SWEP.ReloadTime = R.Reload
SWEP.ConeMin = R.Accuracy * 0.5
SWEP.ConeMax = R.Accuracy * 1.5
SWEP.ConeRamp = 2
SWEP.DrawCrosshair = false

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_suppressor_0",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_AR_Sup.Outside"),
            Reflection = Sound("Reflection_ARSUP.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_AR_Sup.Inside"),
            Reflection = Sound("Reflection_ARSUP.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Full Auto",
        OnSet = function(self)
            self.Primary.Automatic = true
            return "Firemode_Auto"
        end
    },

    [2] = {
        Name = "Semi Auto",
        OnSet = function(self)
            self.Primary.Automatic = false
            return "Firemode_Semi"
        end
    },
}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_pistol_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 35,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
}

SWEP.Cone = {
    Hip = R.Accuracy / 36,
    TacStance = false,
    Ads = R.Accuracy / 36,
    Increase = 0.1 * (R.Accuracy / 1.8),
    TacStanceMultiplier = 0.7,
    AdsMultiplier = 0.15,
    Max = R.Accuracy * (1.3 / 1.8),
}

SWEP.Recoil = {
    Vertical = {1.0 * R.Recoil, 1.4 * R.Recoil},
    Horizontal = {-0.6 * R.Recoil, 1.1 * R.Recoil},
    Shake = 1.15 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 8778456
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 21,
    EffectiveRange = 48, --in meters, damage scales within this distance
    Range = 180, --in meters, after this distance the bullet stops existing
    Tracer = false,
    NumBullets = 1,
    PhysicsMultiplier = 1,
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.63,
        MaxCount = 2,
        Thickness = 5,
    }
}

SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 6.5
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 100, -90),
    Pos = Vector(4, -3, -3)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 0, 0)
    },
    TacStance = {
        Angles = Angle(-0.3, 0.05, -45),
        Pos = Vector(-2, 0, 0)
    },
    Idle = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 0, 0)
    },
    Inspection = {
        Bone = "tag_sling",
        X = {
            [0] = {Pos = Vector(0, 3, 3), Angles = Angle(40, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(4, 0, 1.5), Angles = Angle(10, -20, 0)}
        }
    },

    RecoilMultiplier = 1,
    KickMultiplier = 1,
    AimKickMultiplier = 0.5
}

SWEP.Shell = "mwb_shelleject_939"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "An integrally suppressed carbine. Twenty 9×39s: it stays quiet, the mag does not last."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
