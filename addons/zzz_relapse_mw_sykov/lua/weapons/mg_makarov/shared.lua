AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_pl_3")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_makarov", "zombiesurvival/killicons/weapon_zs_makarov.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_makarov.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_makarov.png"
-- MW stub WM/VM has no gun mesh. Default slide + mag + grip is the actual PM.
SWEP.RelapsePreviewParts = {
	"models/viper/mw/attachments/attachment_vm_pi_mike_barrel.mdl",
	"models/viper/mw/attachments/attachment_vm_pi_mike_grip.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 90, 0)
SWEP.RelapsePreviewLift = 0.5
SWEP.RelapsePreviewCamScale = 1.65

SWEP.Base = "mg_base"

SWEP.PrintName = "Пистолет Макарова"
SWEP.TranslationName = "wep_makarov"
SWEP.TranslationDescription = "wep_makarov_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Pistols"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_makarov.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_makarov.mdl")
SWEP.Trigger = {
    PressedSound = Sound("weap_mike_fire_first"),
    ReleasedSound = Sound("weap_mike_fire_disconnector"),
    Time = 0
}
SWEP.Slot = 1
SWEP.HoldType = "Pistol"

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (ПМ empty 730 g). Clip is the real 8-round single-stack mag.
-- 9x18: milder than 9x19 USP/Battleaxe (24 dmg), snappy on a 730 g frame.
SWEP.Relapse = {
    Damage = 20,
    Delay = 0.20,
    Reload = 1.66,
    Kinetic = 0.40,
    Recoil = 0.55,
    Accuracy = 1.50,
    Weight = 0.73,
    Clip = 8,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_pl_3",
    ["MuzzleFlash_Suppressor"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_mike_fire_plr")
SWEP.Primary.Ammo = "9x18"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize = R.Clip
SWEP.Primary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = math.floor(60 / R.Delay + 0.5)
SWEP.CanChamberRound = true
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
            Layer = Sound("Atmo_Pistol.Outside"),
            Reflection = Sound("Reflection_Pistol.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_Pistol.Inside"),
            Reflection = Sound("Reflection_Pistol.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Semi Auto",
        OnSet = function()
            return nil
        end
    }
}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_pistol_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 20,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 40 --degrees per second
}

SWEP.Cone = {
    Hip = R.Accuracy / 6,
    TacStance = false,
    Ads = R.Accuracy / 36,
    Increase = 0.1 * (R.Accuracy / 1.8),
    TacStanceMultiplier = 0.7,
    AdsMultiplier = 0.15,
    Max = R.Accuracy * (1.3 / 1.8),
}

SWEP.Recoil = {
    Vertical = {0, 0.05 * R.Recoil},
    Horizontal = {-0.5 * R.Recoil, 1 * R.Recoil},
    Shake = 1.6 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 6954
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 8,
    EffectiveRange = 25, --in meters, damage scales within this distance
    Range = 100, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.6, --how much damaged is multipled by when leaving a surface.
        MaxCount = 3, --how many times the bullet can penetrate.
        Thickness = 5, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.2,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 13
    } 
}
 
SWEP.WorldModelOffsets = { 
    Bone = "tag_pistol_offset",
    Angles = Angle(0, 90, -90),
    Pos = Vector(3, -3, -1.5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0.15, 0, 0)
    },
    TacStance = {
        Angles = Angle(-0.3, 0.05, -45),
        Pos = Vector(-2, 0, -1.25)
    },
    Idle = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 0, 0)
    },
    Inspection = {
        Bone = "tag_pistol_offset",
        X = {
            [0] = {Pos = Vector(-2, 2, 0), Angles = Angle(30, 0, -30)},
            [1] = {Pos = Vector(-1, 0, 0), Angles = Angle(0, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, -30, 0)},
            [1] = {Pos = Vector(0, 0, 1), Angles = Angle(0, 30, 0)}
        }
    }
}

SWEP.Shell = "mwb_shelleject_9mm"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A compact service sidearm. Issued to everyone and valued by no one\194\160\194\160–\194\160\194\160until there was nothing else left."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")