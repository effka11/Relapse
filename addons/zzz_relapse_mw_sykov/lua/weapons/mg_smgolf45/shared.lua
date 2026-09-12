AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_smg_0")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_smgolf45", "zombiesurvival/killicons/weapon_zs_ump45_side2.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_ump45_side2.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_ump45_side2.png"
-- WM is the receiver. Barrel, mag, stock, and receiver att bone-merge like MP5/SKS.
-- DrawModel after SetupBones is +Z: hull + LocalAng 90. Frame like MP5, not a rifle.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewBodygroups = { [0] = 1 }
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_smgolf45.mdl",
	"models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_receiver.mdl",
	"models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_barrel.mdl",
	"models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_mag.mdl",
	"models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_stock.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewOffset = Vector(0, 0, -2)
SWEP.RelapsePreviewLift = 2.2
SWEP.RelapsePreviewCamScale = 1.6

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_vertpro_offset", "grip_killtheclamp_offset"}

SWEP.PrintName = "Пистолет-пулемёт UMP-45"
SWEP.TranslationName = "wep_ump45"
SWEP.TranslationDescription = "wep_ump45_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Submachine Guns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_smgolf45.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_smgolf45.mdl")

SWEP.Slot = 2
SWEP.HoldType = "Rifle"
SWEP.Trigger = {
    PressedSound = Sound("weap_smgolf45_fire_first_plr"),
    ReleasedSound = Sound("weap_smgolf45_disconnector_plr"),
    Time = 0
}

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (UMP45 empty ~2.5 kg). Clip is the real 25-round mag, not CoD 30.
-- .45 auto tax: above MP5 9x19 (16) per shot, below 1911 28, so 600 RPM stays T2 next to MP5.
SWEP.Relapse = {
    Damage = 22,
    Delay = 0.10,
    Reload = 2.60,
    Kinetic = 0.35,
    Recoil = 1.00,
    Accuracy = 2.10,
    Weight = 2.50,
    Clip = 25,
    Automatic = true,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_smgolf45_fire_plr_lfe")
SWEP.Primary.Ammo = "45acp"
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
    ["MuzzleFlash"] = "mwb_muzzle_smg_0",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_SMG2.Outside"),
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
    Vertical = {0.5 * R.Recoil, 0.7 * R.Recoil},
    Horizontal = {-0.35 * R.Recoil, 0.35 * R.Recoil},
    Shake = 1.35 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 67586758
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 13,
    EffectiveRange = 38, --in meters, damage scales within this distance
    Range = 100, --in meters, after this distance the bullet stops existing
    Tracer = false,
    NumBullets = 1,
    PhysicsMultiplier = 1,
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.5,
        MaxCount = 3,
        Thickness = 15,
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
    Pos = Vector(3, -4.5, -3.5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 2, 0)
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
            [0] = {Pos = Vector(5, 0, 3), Angles = Angle(40, 0, 0)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-15, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(0, 0, 1.5), Angles = Angle(10, 0, 15)}
        }
    },

    RecoilMultiplier = 1,
    KickMultiplier = 1,
    AimKickMultiplier = 0.5
}

SWEP.Shell = "mwb_shelleject_45"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A duty .45 SMG. Twenty-five rounds: heavier than the nines, the mag is shorter."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
