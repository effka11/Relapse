AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_ar_4")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mw_fas2_muzzleflash_ar_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_falima", "zombiesurvival/killicons/weapon_zs_fal_side.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_fal_side.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_fal_side.png"
-- Default receiver is a real mdl (not SCAR's empty att_receiver). Forend too.
-- Barrel/mag/stock/forend bone-merge onto tag_*_attach. WM variant 0 — do not copy MP5 [0]=1.
-- DrawModel after SetupBones is +Z: hull + LocalAng 90 like AK/SCAR/M4.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_falima.mdl",
	"models/viper/mw/attachments/falima/attachment_vm_ar_falima_reciever.mdl",
	"models/viper/mw/attachments/falima/attachment_vm_ar_falima_barrel.mdl",
	"models/viper/mw/attachments/falima/attachment_vm_ar_falima_mag.mdl",
	"models/viper/mw/attachments/falima/attachment_vm_ar_falima_stock.mdl",
	"models/viper/mw/attachments/falima/attachment_vm_ar_falima_forend.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewOffset = Vector(0, 0, -3)
SWEP.RelapsePreviewLift = 2.8
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}

SWEP.PrintName = "FAL"
SWEP.TranslationName = "wep_fal"
SWEP.TranslationDescription = "wep_fal_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Assault Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_falima.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_falima.mdl")

SWEP.Slot = 3
SWEP.HoldType = "Rifle"
SWEP.Tier = 5
SWEP.Trigger = {
    PressedSound = Sound("mw19.falima.fire.first"),
    ReleasedSound = Sound("mw19.falima.fire.disconnector"),
    Time = 0
}

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (FN FAL 50.00 empty ~4.25 kg). Clip is the real 20-round mag.
-- Semi 7.62x51: above SKS 34 and SCAR 30 per shot. Do not copy pack RPM 500.
SWEP.Relapse = {
    Damage = 38,
    Delay = 0.16,
    Reload = 2.6,
    Kinetic = 0.16,
    Recoil = 1.45,
    Accuracy = 0.95,
    Weight = 4.25,
    Clip = 20,
    Automatic = false,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("mw19.falima.fire")
SWEP.Primary.Ammo = "762x51"
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
SWEP.ReloadTime = R.Reload
SWEP.ConeMin = R.Accuracy * 0.5
SWEP.ConeMax = R.Accuracy * 1.5
SWEP.ConeRamp = 2
SWEP.DrawCrosshair = false

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_ar_4",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_br1.Outside"),
            Reflection = Sound("Reflection_AR.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_AR.Inside"),
            Reflection = Sound("Reflection_AR.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Semi Auto",
        OnSet = function(self)
            self.Primary.Automatic = false
            return "Firemode_Semi"
        end
    }
}

SWEP.BarrelSmoke = {
    Particle = "mw_fas2_muzzleflash_ar_smoke_barrel",
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
    Vertical = {0.5 * R.Recoil, 1.75 * R.Recoil},
    Horizontal = {-1.0 * R.Recoil, 1.0 * R.Recoil},
    Shake = 1.0 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 67498
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 22,
    EffectiveRange = 55, --in meters, damage scales within this distance
    Range = 180, --in meters, after this distance the bullet stops existing
    Tracer = false,
    NumBullets = 1,
    PhysicsMultiplier = 1.25,
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.92,
        MaxCount = 5,
        Thickness = 24,
    }
}

SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 7
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 95, -90),
    Pos = Vector(3, -5, -3)
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
            [0] = {Pos = Vector(0, 0, 3), Angles = Angle(40, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(3, 0, 0), Angles = Angle(10, -20, 0)}
        }
    },

    RecoilMultiplier = 1,
    KickMultiplier = 1,
    AimKickMultiplier = 0.5
}

SWEP.Shell = "mwb_shelleject_7625x"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A battle rifle. Twenty 7.62×51: one shot, then the trigger waits."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
