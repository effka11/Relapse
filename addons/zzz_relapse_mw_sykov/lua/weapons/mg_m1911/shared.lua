AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_pl_2")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_m1911", "zombiesurvival/killicons/weapon_zs_colt1911.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_colt1911.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_colt1911.png"
-- World receiver is the parent. Slide and mag bone-merge onto it (same as MW in-game).
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_m1911.mdl",
	"models/viper/mw/attachments/attachment_vm_pi_mike1911_v1_slide.mdl",
	"models/viper/mw/attachments/attachment_vm_pi_mike1911_v1_mag.mdl",
}
-- WM barrel is along +Z at identity; roll 90 puts it along Y for a side view.
-- Makarov yaw 90 / pitch 8 are for a gun along X — here they show the rear and lean the grip.
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
-- Union AABB sits in the empty corner under the barrel (L-shape: long slide + hanging mag).
-- Pull the orbit pivot back to the mag well / trigger, same idea as 680's stock offset.
SWEP.RelapsePreviewOffset = Vector(-0.8, 0, 0.5)
SWEP.RelapsePreviewLift = 0.7
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"

SWEP.PrintName = "Пистолет 1911"
SWEP.TranslationName = "wep_1911"
SWEP.TranslationDescription = "wep_1911_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Pistols"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_m1911.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_m1911.mdl")
SWEP.Trigger = {
    PressedSound = Sound("weap_mike1911_fire_first"),
    ReleasedSound = Sound("weap_mike1911_fire_disconnector"),
    Time = 0
}
SWEP.Slot = 1
SWEP.HoldType = "Pistol"

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (M1911 empty 1.10 kg). Clip is the real 7-round single-stack mag.
-- .45 ACP: heavier than 9x18 PM (20 dmg) and a bit above 9x19 USP/Battleaxe (24).
SWEP.Relapse = {
    Damage = 28,
    Delay = 0.21,
    Reload = 1.35,
    Kinetic = 0.45,
    Recoil = 0.80,
    Accuracy = 1.25,
    Weight = 1.10,
    Clip = 7,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_pl_2",
    ["MuzzleFlash_Suppressor"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("weap_mike1911_fire_plr")
SWEP.Primary.Ammo = "45acp"
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
    ShotTemperatureIncrease = 35,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
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
    Seed = 123456
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 7,
    EffectiveRange = 23, --in meters, damage scales within this distance
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
    Pos = Vector(3.5, -3, -2)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0.13, 0, 0)
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
            [0] = {Pos = Vector(-3, 0, 0), Angles = Angle(-10, -30, 0)},
            [1] = {Pos = Vector(-4, 0, 0), Angles = Angle(0, 30, 0)}
        }
    }
}

SWEP.Shell = "mwb_shelleject_45"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "An officer's Colt. Seven fat .45s: heavy in a room\194\160\194\160–\194\160\194\160just loud past it."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
