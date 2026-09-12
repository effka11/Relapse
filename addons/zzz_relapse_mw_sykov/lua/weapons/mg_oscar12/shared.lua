AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_sg_2")
PrecacheParticleSystem("mwb_muzzle_sg_3")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mwb_airflow_eject")

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_oscar12", "zombiesurvival/killicons/weapon_zs_origin12_side.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_origin12_side.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_origin12_side.png"
-- WM receiver is bodygroup 0 (27k verts — opposite of 680's empty default).
-- Barrel, mag, stock, and the default sidegrip bone-merge onto tag_*_attach.
-- DrawModel after SetupBones is +Z. Do not copy 680 yaw 90 (that gun is -X atts).
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_oscar12.mdl",
	"models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_barrel.mdl",
	"models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_mag.mdl",
	"models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_stock.mdl",
	"models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_sidegrip.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewOffset = Vector(0, 0, -3)
SWEP.RelapsePreviewLift = 2.8
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_queer_offset"}

SWEP.PrintName = "Дробовик Origin-12"
SWEP.TranslationName = "wep_origin12"
SWEP.TranslationDescription = "wep_origin12_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Shotguns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_oscar12.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_oscar12.mdl")

SWEP.Trigger = {
    PressedSound = Sound("weap_oscar12_fire_plr_first"),
    ReleasedSound = Sound("weap_sh_charlie725_disconnector_plr"),
    Time = 0
}

SWEP.Slot = 3
SWEP.HoldType = "Rifle"

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (Origin-12 empty ~4.15 kg). Clip is the real 8-round box mag.
-- Semi mag-fed, not CoD 300 RPM. 12ga auto tax: 00 buck like 680 (16x9), weaker per
-- shell so a 3-shot TTK stays T3 next to the AK instead of dumping like a T5.
SWEP.Relapse = {
    Damage = 12,
    Pellets = 9,
    Delay = 0.32,
    Reload = 2.45,
    Kinetic = 0.62,
    Recoil = 1.45,
    Accuracy = 4.80,
    Weight = 4.15,
    Clip = 8,
    Automatic = false,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_sg_2",
    ["MuzzleFlash_DB"] = "mwb_muzzle_sg_3",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
    ["Overheating"] = "mwb_airflow_eject",
}

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_oscar12_fire_plr")
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
SWEP.ReloadTime = R.Reload
SWEP.ConeMin = R.Accuracy * 0.5
SWEP.ConeMax = R.Accuracy * 1.5
SWEP.ConeRamp = 2
SWEP.DrawCrosshair = false

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_Sniper.Outside"),
            Reflection = Sound("Reflection_Shotgun.Outside")
        },

        Inside = {
            Layer = Sound("Atmo_Shotgun.Inside"),
            Reflection = Sound("Reflection_Sniper.Inside")
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
    },
}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_minigun_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 75,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
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
    Vertical = {2.0 * R.Recoil, 3.25 * R.Recoil},
    Horizontal = {-0.8 * R.Recoil, 1.8 * R.Recoil},
    Shake = 4 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 6874
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 15,
    EffectiveRange = 20, --in meters, damage scales within this distance
    Range = 40, --in meters, after this distance the bullet stops existing
    Tracer = false,
    NumBullets = R.Pellets,
    PhysicsMultiplier = 1.7,
    HeadshotMultiplier = 1, --this gets multiplied by 2
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
    Angles = Angle(0, 100, -90),
    Pos = Vector(3, -5, -3)
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
    }
}

SWEP.Shell = "mwb_shelleject_12g"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A mag-fed 12 gauge. Eight shells: the pump's brass, a trigger that does not wait."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
SWEP.bEnableMagPoseParam = false

function SWEP:PostDrawViewModel(vm, weapon, ply)
    BaseClass.PostDrawViewModel(self, vm, weapon, ply)

    if (self.bEnableMagPoseParam) then
        self:UpdateMagPoseParam(self:GetMaxClip1() - self:Clip1())
    end
end

function SWEP:AllowRuntimeMagPoseParam(allow)
    self.bEnableMagPoseParam = allow
end
