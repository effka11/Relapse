AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_dmr_0")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_sbeta", "zombiesurvival/killicons/weapon_zs_mk2_side3.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_mk2_side3.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_mk2_side3.png"
-- WM draws the receiver and default stock (att_stock has no mdl). Barrel
-- bone-merges onto tag_barrel_attach. Tube lives on the receiver — no mag att.
-- Default optic is att_sight (irons), not the MK2 scope. WM variant 0 — do not
-- copy MP5 [0]=1. DrawModel after SetupBones is +Z like SKS: hull + LocalAng 90.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_sbeta.mdl",
	"models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_barrel.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewOffset = Vector(0, 0, -5)
SWEP.RelapsePreviewLift = 3.5
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"

SWEP.PrintName = "MK2"
SWEP.TranslationName = "wep_mk2"
SWEP.TranslationDescription = "wep_mk2_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Marksman Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_sbeta.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_sbeta.mdl")
SWEP.Trigger = {
    PressedSound = Sound("mw19.sbeta.fire.first"),
    ReleasedSound = Sound(""),
    Time = 0
}

SWEP.Slot = 3
SWEP.HoldType = "BoltAction"
SWEP.Tier = 2

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (Winchester 1894 empty ~2.90 kg). Clip is the real 6-round tube.
-- Lever .30-30: above SKS 34 per shot. Delay is Rechamber Length, not pack RPM 300.
SWEP.Relapse = {
    Damage = 45,
    Delay = 0.50,
    Reload = 3.95,
    Kinetic = 0.18,
    Recoil = 1.25,
    Accuracy = 0.85,
    Weight = 2.90,
    Clip = 6,
    Automatic = false,
    Hitscan = true,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_dmr_0",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("mw19.sbeta.fire")
SWEP.Primary.Ammo = "3030win"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize = R.Clip
SWEP.Primary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = math.floor(60 / R.Delay + 0.5)
SWEP.CanChamberRound = true
SWEP.CanDisableAimReload = false
SWEP.EmptyReloadRechambers = false
SWEP.ReloadTime = R.Reload
SWEP.ConeMin = R.Accuracy * 0.5
SWEP.ConeMax = R.Accuracy * 1.5
SWEP.ConeRamp = 2
SWEP.DrawCrosshair = false
SWEP.Projectile = nil

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_Western.Outside"),
            Reflection = Sound("Reflection_Shotgun.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_Shotgun.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Lever-Action",
        OnSet = function(self)
            self.Primary.Automatic = false
            return "Firemode_Semi"
        end
    },
}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_minigun_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 75,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 65 --degrees per second
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
    Vertical = {3.20 * R.Recoil, 5.20 * R.Recoil},
    Horizontal = {-1.40 * R.Recoil, 2.20 * R.Recoil},
    Shake = 2.40 * R.Recoil,
    AdsMultiplier = 0.05,
    Seed = 3584
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 25,
    EffectiveRange = 55, --in meters, damage scales within this distance
    Range = 110, --in meters, after this distance the bullet stops existing
    Tracer = false,
    NumBullets = 1,
    PhysicsMultiplier = 1.25,
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.85,
        MaxCount = 5,
        Thickness = 14,
    }
}

SWEP.Zoom = {
    IdleSway = 0.15,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 10
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 100, -90),
    Pos = Vector(8.5, -1.5, -5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 3, 0)
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

    RecoilMultiplier = 1.75,
    KickMultiplier = 1.3,
    AimKickMultiplier = 0.45
}

SWEP.Shell = "mwb_shelleject_45"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A lever carbine. Six .30-30s: one shot, then the lever waits."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
