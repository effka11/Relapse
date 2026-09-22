AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_sg_0")
PrecacheParticleSystem("mwb_muzzle_sg_3")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mwb_airflow_eject")

SWEP.BulletList = {[0] = "j_ammoshell1", [1] = "j_ammoshell2"}

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_aalpha12", "zombiesurvival/killicons/weapon_zs_jak12_side5.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_jak12_side5.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_jak12_side5.png"
-- WM receiver is bodygroup 0 (hull along +Z — opposite of 680's empty default).
-- Barrel and mag bone-merge onto tag_*_attach. Default stock/grip slots are att_stock / att_grip.
-- DrawModel after SetupBones is +Z. Do not copy 680 yaw 90. Do not copy Origin sidegrip/stock.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_aalpha12.mdl",
	"models/viper/mw/attachments/aalpha12/attachment_vm_sh_aalpha12_barrel.mdl",
	"models/viper/mw/attachments/aalpha12/attachment_vm_sh_aalpha12_mag.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewOffset = Vector(0, 0, -3)
SWEP.RelapsePreviewLift = 2.8
SWEP.RelapsePreviewCamScale = 1.0

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}

SWEP.PrintName = "JAK-12"
SWEP.TranslationName = "wep_jak12"
SWEP.TranslationDescription = "wep_jak12_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Shotguns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_aalpha12.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_aalpha12.mdl")
SWEP.Trigger = {
    PressedSound = Sound("mw19.aalpha12.fire.first"),
    ReleasedSound = Sound("mw19.aalpha12.disconnector"),
    Time = 0
}

SWEP.Slot = 3
SWEP.HoldType = "Rifle"
SWEP.Tier = 4

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (AA-12 empty ~4.76 kg). Clip is the real 8-round box, not the drum att.
-- 12ga auto tax: below Origin-12 (12x9) per shell so 300 RPM stays T4, four hits not three.
SWEP.Relapse = {
    Damage = 8,
    Pellets = 9,
    Delay = 0.20,
    Reload = 2.5,
    Kinetic = 0.62,
    Recoil = 1.50,
    Accuracy = 4.80,
    Weight = 4.76,
    Clip = 8,
    Automatic = true,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_sg_0",
    ["MuzzleFlash_DB"] = "mwb_muzzle_sg_3",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
    ["Overheating"] = "mwb_airflow_eject",
}

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("mw19.aalpha12.fire")
SWEP.Primary.Ammo = "12ga"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = R.Pellets
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

SWEP.Reverb = {
    RoomScale = 50000,

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_Sniper.Outside"),
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
        Name = "Automatic",
        OnSet = function(self)
            self.Primary.Automatic = true
            return "Firemode_Auto"
        end
    },
}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_minigun_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 75,
    TemperatureThreshold = 250,
    TemperatureCooldown = 100
}

SWEP.Cone = {
    Hip = R.Accuracy / 12,
    TacStance = false,
    Ads = R.Accuracy / 12,
    Increase = 0.12,
    TacStanceMultiplier = 0.8,
    AdsMultiplier = 0,
    Max = R.Accuracy * (2.3 / 4.8),
}

SWEP.Recoil = {
    Vertical = {2.0 * R.Recoil, 3.25 * R.Recoil},
    Horizontal = {-0.8 * R.Recoil, 1.8 * R.Recoil},
    Shake = 4 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 1158
}

SWEP.Bullet = {
    -- MW divides Damage by NumBullets. Relapse.Damage is per pellet.
    Damage = {R.Damage * R.Pellets, farDamage * R.Pellets},
    DropOffStartRange = 15,
    EffectiveRange = 20,
    Range = 40,
    Tracer = false,
    NumBullets = R.Pellets,
    PhysicsMultiplier = 1.7,
    HeadshotMultiplier = 1,
    Penetration = {
        DamageMultiplier = 0.86,
        MaxCount = 13,
        Thickness = 18,
    }
}

SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 15
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(-3, 90, -90),
    Pos = Vector(3.5, -6, -4)
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
}

SWEP.Shell = "mwb_shelleject_12g_black"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A full-auto 12 gauge. Eight shells: Origin's brass, a trigger that does not let go."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
