AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_sr_0")
PrecacheParticleSystem("AC_muzzle_shotgun_db")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_minigun_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_alpha50", "zombiesurvival/killicons/weapon_zs_ax50_side3.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_ax50_side3.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_ax50_side3.png"
-- WM draws the receiver. Barrel/mag/stock bone-merge onto tag_*_attach.
-- Default optic is att_sight (irons), not the AX-50 scope. WM variant 0 — do not copy MP5 [0]=1.
-- Studio hull / DrawModel is along +X like PKM, not +Z like SKS. LocalAng 90
-- rolls around the barrel and lays the rifle on its side. Yaw 90 like 680/PKM.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_alpha50.mdl",
	"models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_barrel.mdl",
	"models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_mag.mdl",
	"models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_stock.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 90, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 0)
SWEP.RelapsePreviewOffset = Vector(-6, 0, -3)
SWEP.RelapsePreviewLift = 2.8
SWEP.RelapsePreviewCamScale = 1.4

SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}

SWEP.Base = "mg_base"

SWEP.PrintName = "AX-50"
SWEP.TranslationName = "wep_ax50"
SWEP.TranslationDescription = "wep_ax50_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Sniper Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/vm_sn_alpha50.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_alpha50.mdl")
SWEP.Trigger = {
    PressedSound = Sound("weap_delta_fire_first"),
    ReleasedSound = Sound("weap_delta_fire_disconnector"),
    Time = 0
}

SWEP.Slot = 3
SWEP.HoldType = "BoltAction"
SWEP.Tier = 5

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (AI AX50 empty ~12.5 kg). Clip is the real 5-round mag.
-- Bolt .50 BMG: above FAL 38 per shot. Delay is Rechamber Length, not pack RPM 297.
SWEP.Relapse = {
    Damage = 113,
    Delay = 1.30,
    Reload = 3.03,
    Kinetic = 0.10,
    Recoil = 2.20,
    Accuracy = 0.50,
    Weight = 12.50,
    Clip = 5,
    Automatic = false,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_alpha50_fire_plr")
SWEP.Primary.Ammo = "50bmg"
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
SWEP.ReloadRechambers = true
SWEP.ReloadTime = R.Reload
SWEP.ConeMin = R.Accuracy * 0.5
SWEP.ConeMax = R.Accuracy * 1.5
SWEP.ConeRamp = 2
SWEP.DrawCrosshair = false

SWEP.Projectile = {
    Class = "mg_sniper_bullet",
    Speed = 60000,
    Gravity = 8,
    Penetrate = true
}

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_sr_0",
    ["MuzzleFlash_DB"] = "mw_fas2_muzzleflash_slug",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
    ["Overheating"] = "AC_muzzle_pistol_smoke_barrel",
}

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_Sniper.Outside"),
            Reflection = Sound("Reflection_Sniper.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_Shotgun.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Bolt-Action",
        OnSet = function(self)
            self.Primary.Automatic = false
            return "Firemode_Semi"
        end
    }
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
    Vertical = {0.5 * R.Recoil, 1.75 * R.Recoil},
    Horizontal = {-1.0 * R.Recoil, 1.0 * R.Recoil},
    Shake = 1.0 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 3584
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 35,
    EffectiveRange = 80, --in meters, damage scales within this distance
    Range = 220, --in meters, after this distance the bullet stops existing
    Tracer = false,
    NumBullets = 1,
    PhysicsMultiplier = 1.25,
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.95,
        MaxCount = 6,
        Thickness = 32,
    }
}

SWEP.Zoom = {
    IdleSway = 0.2,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    BreathingMultiplier = 1,
    MovementMultiplier = 1,
    Blur = {
        EyeFocusDistance = 10
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(10, 5, 180),
    Pos = Vector(10, -2, -1.5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, -4, 0.55)
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
    KickMultiplier = 3.3,
    AimKickMultiplier = 0.45
}

SWEP.Shell = "mwb_shelleject_50bmg"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A bolt-action sniper. Five .50 BMG: one shot, then the bolt waits."

function SWEP:PrimaryAttack()
    local clip = self:Clip1()
    weapons.Get(self.Base).PrimaryAttack(self)
    if (clip != self:Clip1()) then
        self:MakeEnvironmentDust(210)
    end
end

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
