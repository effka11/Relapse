AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_pl_5")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

require("mw_utils")
mw_utils.LoadInjectors(SWEP)  

if CLIENT then
    killicon.Add( "mg_357", "VGUI/entities/mg_357", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_pi_cpapa")
end

SWEP.Base = "mg_base"
 
SWEP.PrintName = ".357"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Pistols"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_357.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_357.mdl")


SWEP.Slot = 1
SWEP.HoldType = "Revolver"

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_pl_5",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
}

SWEP.Trigger = {
    PressedSound = Sound("wfoly_plr_pi_cpapa_charge_in_01"),
    PressedAnimation = "Charge",
    Time = 0.075
}

SWEP.Primary.Sound = Sound("weap_cpapa_fire_plr")
SWEP.Primary.Ammo = "357"
SWEP.Primary.ClipSize = 6
SWEP.Primary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 139
SWEP.CanChamberRound = false
SWEP.CanDisableAimReload = true

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)    
    --how big should an area be before it is categorized as 'outside'?
 
    Sounds = {  
        Outside = {  
            Layer = Sound("Atmo_Pistol_Mag.Outside"),
            Reflection = Sound("Reflection_Pistol.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_Shotgun.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
        }
    }
}
SWEP.Firemodes = {
    [1] = {
        Name = "Semi Auto",
        OnSet = function()
            return nil
        end
    },
}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_pistol_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 100,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
}
  
SWEP.Cone = {
    Hip = 0.3, --accuracy while hip
    TacStance = false, --accuracy in tac-stance
    Ads = 0, --accuracy while aiming
    Increase = 0.1, --increase cone size by this amount every time we shoot
    TacStanceMultiplier = 0.9, --multiply the increase value by this while in tac-stance
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 1.3, --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {0.1, 0.2}, --random value between the 2
    Horizontal = {-0.2, 0.2}, --random value between the 2
    Shake = 2.4, --camera shake
    AdsMultiplier = 0.75, --multiply the values by this amount while aiming
    Seed = 610312 --give this a random number until you like the current recoil pattern
}

SWEP.Bullet = {
    Damage = {100, 28}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    EffectiveRange = 35, --in meters, damage scales within this distance
    DropOffStartRange = 12, --in meters, damage scales within this distance
    Range = 100, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 0.5, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.95, --how much damaged is multipled by when leaving a surface.
        MaxCount = 6, --how many times the bullet can penetrate.
        Thickness = 14, --in hu, how thick an obstacle has to be to stop the bullet.
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
    Pos = Vector(4.5, -3, -2.5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, -4, 0)
    },
    TacStance = {
        Angles = Angle(-0.3, 0.05, -45),
        Pos = Vector(-1.5, 2, -1)
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
            [0] = {Pos = Vector(2, 0, 0), Angles = Angle(-30, -30, 0)},
            [1] = {Pos = Vector(-4, 0, 0), Angles = Angle(0, 30, 0)}
        }
    }
}

SWEP.Shell = "mwb_shelleject_50bmg"