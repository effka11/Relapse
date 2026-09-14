AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_dmr_2")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_sksierra", "zombiesurvival/killicons/weapon_zs_sks_side.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_sks_side.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_sks_side.png"
-- WM draws the receiver. Barrel, mag, and stock bone-merge onto WM bones
-- (tag_barrel_attach, tag_mag_attach, tag_stock_attach). j_gun is parent -1 — do not use it.
-- Default gun is the first att in each slot. Iron sight has no mdl.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_sksierra.mdl",
	"models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_barrel.mdl",
	"models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_mag.mdl",
	"models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_stock.mdl",
}
-- DrawModel after SetupBones is along +Z (1911), not bind-pose +X. Yaw 90 stands it on end.
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
-- Hull origin is the hand; stock hangs behind it. Lift is view-space (offset orbits with the gun).
SWEP.RelapsePreviewOffset = Vector(0, 0, -5)
SWEP.RelapsePreviewLift = 3.5
SWEP.RelapsePreviewCamScale = 1.4

SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_vertpro_offset"}
SWEP.GripPoseParameters2 = {"grip_stockhvy_offset"}

SWEP.Base = "mg_base"

SWEP.PrintName = "СКС"
SWEP.TranslationName = "wep_sks"
SWEP.TranslationDescription = "wep_sks_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Marksman Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_sksierra.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_sksierra.mdl")
SWEP.Trigger = {
    PressedSound = Sound("mw19.sksierra.fire.first"),
    ReleasedSound = Sound("mw19.sksierra.disconnector"),
    Time = 0
}

SWEP.Slot = 3
SWEP.HoldType = "Rifle"

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (SKS empty ~3.85 kg). Clip is the real 10-round magazine, not CoD 20.
-- 7.62x39: harder than .45 1911 (28), softer than .357 (42). Semi, not CoD 328 RPM.
SWEP.Relapse = {
    Damage = 34,
    Delay = 0.22,
    Reload = 2.70,
    Kinetic = 0.20,
    Recoil = 1.10,
    Accuracy = 0.95,
    Weight = 3.85,
    Clip = 10,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_dmr_2",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("mw19.sksierra.fire")
SWEP.Primary.Ammo = "762x39"
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

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_br1.Outside"),
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
        Name = "Semi-Automatic",
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
    Vertical = {3.64 * R.Recoil, 4.55 * R.Recoil},
    Horizontal = {-1.59 * R.Recoil, 2.50 * R.Recoil},
    Shake = 2.73 * R.Recoil,
    AdsMultiplier = 0.15,
    Seed = 3584
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 22,
    EffectiveRange = 45, --in meters, damage scales within this distance
    Range = 90, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1.25, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.85, --how much damaged is multipled by when leaving a surface.
        MaxCount = 6, --how many times the bullet can penetrate.
        Thickness = 12, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.2,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 10
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(-3, 100, -90),
    Pos = Vector(4, -1.5, -7)
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

SWEP.Shell = "mwb_shelleject_7625x"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A warehouse carbine. The army is gone, ten 7.62s remain: it reaches past the pistols, the mag does not hurry."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
