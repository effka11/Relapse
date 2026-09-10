AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_pl_2")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add( "mg_m1911", "VGUI/entities/mg_m1911", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_pi_mike_1911")
end

SWEP.Base = "mg_base"

SWEP.PrintName = "M1911"
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

SWEP.Primary.Sound = Sound("weap_mike1911_fire_plr")
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.ClipSize = 7
SWEP.Primary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 284  
SWEP.CanChamberRound = true  
  
SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_pl_2",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject", 
}

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
    Hip = 0.3, --accuracy while hip
    Ads = 0, --accuracy while aiming
    Increase = 0.1, --increase cone size by this amount every time we shoot
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 1.3, --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {0.5, 1.5}, --random value between the 2
    Horizontal = {-0.08, 0.12}, --random value between the 2
    Shake = 2.7, --camera shake
    AdsMultiplier = 0.5, --multiply the values by this amount while aiming
    Seed = 123456 --give this a random number until you like the current recoil pattern
}

SWEP.Bullet = {
    Damage = {51, 22}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    EffectiveRange = 23, --in meters, damage scales within this distance
    DropOffStartRange = 7,
    Range = 100, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.9, --how much damaged is multipled by when leaving a surface.
        MaxCount = 3, --how many times the bullet can penetrate.
        Thickness = 10, --in hu, how thick an obstacle has to be to stop the bullet.
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