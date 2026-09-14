AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_lmg_4")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject2")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_pkilo", "zombiesurvival/killicons/weapon_zs_pkm_side.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_pkm_side.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_pkm_side.png"
-- WM receiver is bodygroup 0 (same as AK/SCAR — do not copy MP5 [0]=1).
-- Barrel, box mag, and stock bone-merge onto tag_*_attach. Default grip slot is att_grip.
-- Studio hull / DrawModel is along +X (muzzle +X), not +Z like SCAR. LocalAng 90
-- rolls around the barrel and lays the PKM on its side. Yaw 90 like 680.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_pkilo.mdl",
	"models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_barrel.mdl",
	"models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_mag.mdl",
	"models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_stock.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 90, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 0)
SWEP.RelapsePreviewOffset = Vector(-6, 0, -3) -- -X toward the stock; hull center sits on the muzzle half
SWEP.RelapsePreviewLift = 2.8
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}

SWEP.PrintName = "ПКМ"
SWEP.TranslationName = "wep_pkm"
SWEP.TranslationDescription = "wep_pkm_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Lightmachine Guns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_pkilo.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_pkilo.mdl")

SWEP.Slot = 3
SWEP.HoldType = "Rifle"
SWEP.Trigger = {
    PressedSound = Sound("weap_pkilo_prefire_plr"),
    ReleasedSound = Sound(""),
    Time = 0
}

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (PKM empty ~7.5 kg). Clip is the real 100-round box, not CoD.
-- 7.62x54R auto tax: below SCAR 7.62x51 (30) per shot so 650 RPM stays T5, not a dump.
SWEP.Relapse = {
    Damage = 26,
    Delay = 0.092,
    Reload = 8.65,
    Kinetic = 0.17,
    Recoil = 1.35,
    Accuracy = 1.20,
    Weight = 7.50,
    Clip = 100,
    Automatic = true,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_pkilo_fire_plr")
SWEP.Primary.Ammo = "762x54r"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize = R.Clip
SWEP.Primary.Automatic = true
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

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_lmg_4",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject2",
}

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_LMG.Outside"),
            Reflection = Sound("Reflection_AR.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_LMG.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
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
    Vertical = {1.0 * R.Recoil, 0.8 * R.Recoil},
    Horizontal = {-1.25 * R.Recoil, 1.4 * R.Recoil},
    Shake = 1.25 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 675846694
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 35,
    EffectiveRange = 65, --in meters, damage scales within this distance
    Range = 180, --in meters, after this distance the bullet stops existing
    Tracer = false,
    NumBullets = 1,
    PhysicsMultiplier = 1,
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.8,
        MaxCount = 3,
        Thickness = 12,
    }
}

SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 8
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 0, -180),
    Pos = Vector(12, -1, -4)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 4, 0)
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
            [0] = {Pos = Vector(0, -4, 3), Angles = Angle(40, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(3, 0, -2), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(4, 0, 3), Angles = Angle(10, -20, 0)}
        }
    },

    RecoilMultiplier = 1,
    KickMultiplier = 1,
    AimKickMultiplier = 0.5
}

SWEP.Shell = "mwb_shelleject_762"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A belt-fed GPMG. A hundred 7.62×54R: the belt lasts, the reload does not hurry."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")

function SWEP:PreAttachments()
    BaseClass.PreAttachments(self)

    if (not self:HasAttachment("att_sight")) then
        self.Animations.Reload.Sequences = {"Reload_scope"}
        self.Animations.Reload_Empty.Sequences = {"Reload_empty_scope"}
        self.Animations.Reload_fast.Sequences = {"Reload_fast_scope"}
        self.Animations.Reload_empty_fast.Sequences = {"Reload_empty_fast_scope"}
    end
end
