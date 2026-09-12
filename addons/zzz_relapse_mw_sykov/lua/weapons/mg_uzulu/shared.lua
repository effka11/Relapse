AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_smg_0")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_uzulu", "zombiesurvival/killicons/weapon_zs_uzi_side6.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_uzi_side6.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_uzi_side6.png"
-- w_uzulu default DrawModel is empty. Variant 1 is the gun. After SetupBones the
-- WM points +Z (yaw 90 stands it on end). Same framing as SKS: hull + LocalAng 90.
-- Offset 0: orbit the GetRenderBounds center, do not guess hull XY.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewBodygroups = { [0] = 1 }
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_uzulu.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewOffset = Vector(0, 0, 0)
SWEP.RelapsePreviewLift = 2.2
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}

SWEP.PrintName = "Пистолет-пулемёт Uzi"
SWEP.TranslationName = "wep_uzi"
SWEP.TranslationDescription = "wep_uzi_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Submachine Guns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_uzulu.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_uzulu.mdl")

SWEP.Slot = 2
SWEP.HoldType = "TinyGun"
SWEP.Trigger = {
    PressedSound = Sound("weap_uzulu_fire_first_plr"),
    ReleasedSound = Sound("weap_uzulu_disconnector_plr"),
    Time = 0
}

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (Uzi with stock ~3.50 kg). Clip is the real 32-round stick, not CoD 50.
-- 9x19 auto tax: below 9x18 PM (20) per shot so 600 RPM stays T1, not T3 DPS.
-- Open bolt, real cyclic rate. Same cartridge on the card, ZS HP budget.
SWEP.Relapse = {
    Damage = 16,
    Delay = 0.10,
    Reload = 2.50,
    Kinetic = 0.38,
    Recoil = 0.95,
    Accuracy = 3.10,
    Weight = 3.50,
    Clip = 32,
    Automatic = true,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_uzulu_fire_plr")
SWEP.Primary.Ammo = "9x19"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize = R.Clip
SWEP.Primary.Automatic = true
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = math.floor(60 / R.Delay + 0.5)
SWEP.CanChamberRound = false
SWEP.CanDisableAimReload = false
SWEP.ReloadTime = R.Reload
SWEP.ConeMin = R.Accuracy * 0.5
SWEP.ConeMax = R.Accuracy * 1.5
SWEP.ConeRamp = 2
SWEP.DrawCrosshair = false

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_smg_0",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_SMG.Outside"),
            Reflection = Sound("Reflection_Pistol.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_SMG.Inside"),
            Reflection = Sound("Reflection_Pistol.Inside")
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
    Vertical = {0.5 * R.Recoil, 0.75 * R.Recoil},
    Horizontal = {-0.15 * R.Recoil, 0.15 * R.Recoil},
    Shake = 0.95 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 66666
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 12,
    EffectiveRange = 35, --in meters, damage scales within this distance
    Range = 100, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this is multiplied by 2
    Penetration = {
        DamageMultiplier = 0.5, --how much damaged is multipled by when leaving a surface.
        MaxCount = 2, --how many times the bullet can penetrate.
        Thickness = 10, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.15,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 7.5
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 90, -90),
    Pos = Vector(6, -5.5, -6)
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
            [0] = {Pos = Vector(0, 4, 0), Angles = Angle(30, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(10, -20, 0)}
        }
    },

    RecoilMultiplier = 0.25,
    KickMultiplier = 1,
    AimKickMultiplier = 1.3
}

SWEP.Shell = "mwb_shelleject_9mm"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "An open-bolt spray. Thirty-two 9×19s: it does not aim, it empties."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
