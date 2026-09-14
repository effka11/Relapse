AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_pl_4")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_p320", "zombiesurvival/killicons/weapon_zs_m19_side.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_m19_side.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_m19_side.png"
-- World receiver is the parent (same as 1911). Slide and mag bone-merge onto it.
-- WM barrel is along +Z at identity; roll 90 puts it along Y for a side view.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_p320.mdl",
	"models/viper/mw/attachments/attachment_vm_pi_papa320_slide.mdl",
	"models/viper/mw/attachments/attachment_vm_pi_papa320_mag.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
-- Union AABB sits in the empty corner under the barrel (long slide + hanging mag).
-- Pull the orbit pivot back to the mag well / trigger, same as 1911.
SWEP.RelapsePreviewOffset = Vector(-0.8, 0, 0.5)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"

SWEP.PrintName = "M19"
SWEP.TranslationName = "wep_m19"
SWEP.TranslationDescription = "wep_m19_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Pistols"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_p320.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_p320.mdl")
SWEP.Trigger = {
    PressedSound = Sound("weap_papa320_fire_first"),
    ReleasedSound = Sound("weap_papa320_fire_disconnector"),
    Time = 0
}

SWEP.Slot = 1
SWEP.HoldType = "Pistol"
SWEP.Tier = 2

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (P320 Full Size empty ~0.83 kg). Clip is the real 17-round mag.
-- 9x19 semi: above PM 20, below 1911 28. No auto tax — UMP 22 is the queued .45.
SWEP.Relapse = {
    Damage = 23,
    Delay = 0.15,
    Reload = 1.5,
    Kinetic = 0.36,
    Recoil = 0.65,
    Accuracy = 1.30,
    Weight = 0.83,
    Clip = 17,
    Automatic = false,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_pl_4",
    ["MuzzleFlash_Suppressor"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_papa320_fire_plr")
SWEP.Primary.Ammo = "9x19"
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
    Hip = R.Accuracy / 36,
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
    Seed = 610312
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
        EyeFocusDistance = 15
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_pistol_offset",
    Angles = Angle(0, 90, -90),
    Pos = Vector(4, -3, -3)
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
            [0] = {Pos = Vector(0, 2, -2), Angles = Angle(30, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(0, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(-1, 0, 0), Angles = Angle(-10, -30, 0)},
            [1] = {Pos = Vector(-4, 0, 0), Angles = Angle(0, 30, 0)}
        }
    }
}

SWEP.Shell = "mwb_shelleject_9mm"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A duty pistol. Seventeen 9×19s: the mag lasts, the trigger does not wait."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
