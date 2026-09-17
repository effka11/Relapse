AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_sg_0")
PrecacheParticleSystem("mwb_muzzle_sg_3")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mwb_airflow_eject")

SWEP.BulletList = {"j_shell_12ga_01", "j_shell_12ga_02"}

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_romeo870", "zombiesurvival/killicons/weapon_zs_model680.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_model680.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_model680.png"
-- WM is a bone rig: VVD has every bodygroup, default DrawModel is empty, no j_gun.
-- Default gun is the first att in each slot. Stock is a receiver bodygroup, not an att.
-- Barrel/pump live near j_gun (~1 hu), so one origin like Makarov — not bone merge onto WM.
SWEP.RelapsePreviewParts = {
	"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_receiver.mdl",
	"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_barrel.mdl",
	"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_pump.mdl",
}
-- Att meshes along +X (muzzle +X). Yaw 90 is a side view. Pitch 8 plus the
-- elevated camera points a long gun downhill; SKS box uses pitch 0.
SWEP.RelapsePreviewAngle = Angle(0, 90, 0)
SWEP.RelapsePreviewOffset = Vector(0, 0, -1.2)
SWEP.RelapsePreviewLift = 2.2
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_wood_offset"}
SWEP.GripPoseParameters2 = {"grip_stockh_offset"}

SWEP.PrintName = "Дробовик 680"
SWEP.TranslationName = "wep_680"
SWEP.TranslationDescription = "wep_680_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Shotguns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_romeo870.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_romeo870.mdl")

SWEP.Trigger = {
    PressedSound = Sound("weap_oscar12_fire_plr_first"),
    ReleasedSound = Sound("weap_sh_charlie725_disconnector_plr"),
    Time = 0
}

SWEP.DisableCantedReload = false
SWEP.Slot = 3
SWEP.HoldType = "Rifle"

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (Remington 870 Express empty ~3.40 kg). Clip is a 6-round riot tube.
-- Damage is per pellet. Pellets = 9 (standard 2.75" 00 buck). Pump cycle, not CoD 175 RPM.
SWEP.Relapse = {
    Damage = 16,
    Pellets = 9,
    Delay = 0.70,
    Reload = 5.00,
    Kinetic = 0.62,
    Recoil = 1.55,
    Accuracy = 4.80,
    Weight = 3.40,
    Clip = 6,
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
SWEP.Primary.Sound = Sound("weap_romeo870_fire_plr_lfe")
SWEP.Primary.Ammo = "12ga"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = R.Pellets
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

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_Shotgun.Outside"),
            Reflection = Sound("Reflection_Shotgun.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_LMG.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Pump-Action",
        OnSet = function(self)
            self.Primary.Automatic = false
            return "Firemode_Semi"
        end
    },
}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_minigun_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 65,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 65 --degrees per second
}

SWEP.Cone = {
    Hip = R.Accuracy / 12,
    TacStance = false,
    Ads = R.Accuracy / 12,
    Increase = 0.12,
    TacStanceMultiplier = 0.7,
    AdsMultiplier = 0,
    Max = R.Accuracy * (2.3 / 4.8),
}

SWEP.Recoil = {
    Vertical = {2.6 * R.Recoil, 2.1 * R.Recoil},
    Horizontal = {-0.52 * R.Recoil, 1.16 * R.Recoil},
    Shake = 2.6 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 65947
}

SWEP.Bullet = {
    -- MW divides Damage by NumBullets. Relapse.Damage is per pellet.
    Damage = {R.Damage * R.Pellets, farDamage * R.Pellets},
    DropOffStartRange = 15,
    EffectiveRange = 20, --in meters, damage scales within this distance
    Range = 40, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = R.Pellets, --the amount of bullets to fire
    PhysicsMultiplier = 1.7, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.86, --how much damaged is multipled by when leaving a surface.
        MaxCount = 13, --how many times the bullet can penetrate.
        Thickness = 18, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 10
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 100, -90),
    Pos = Vector(10, -1, -5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0.03, 0, 0)
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
            [1] = {Pos = Vector(-3, -1, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(4, -2, 1.5), Angles = Angle(10, -10, 0)}
        }
    }
}

SWEP.Shell = "mwb_shelleject_12g"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A patrol pump. For a hallway, not a field: it drops them at the door, then the shot wanders. Then the forend."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
