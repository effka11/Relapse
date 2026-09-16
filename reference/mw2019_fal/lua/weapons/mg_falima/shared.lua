AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_ar_4")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mw_fas2_muzzleflash_ar_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add( "mg_falima", "VGUI/entities/mg_falima", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_ar_falima")
end

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}

SWEP.PrintName = "FAL"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Assault Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_falima.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_falima.mdl")

SWEP.Slot = 2
SWEP.HoldType = "Rifle"
SWEP.Trigger = {
    PressedSound = Sound("mw19.falima.fire.first"),
    ReleasedSound = Sound("mw19.falima.fire.disconnector"),
    Time = 0
}

SWEP.Primary.Sound = Sound("mw19.falima.fire")
SWEP.Primary.Ammo = "Ar2"
SWEP.Primary.ClipSize = 20
SWEP.Primary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 500  
SWEP.CanChamberRound = true  
  
SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_ar_4",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject", 
}

SWEP.Reverb = { 
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_br1.Outside"),
            Reflection = Sound("Reflection_AR.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_AR.Inside"),
            Reflection = Sound("Reflection_AR.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Semi Auto",
        OnSet = function(self)
            return "Firemode_Semi"
        end
    }
}

SWEP.BarrelSmoke = {
    Particle = "mw_fas2_muzzleflash_ar_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 35,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
}

SWEP.Cone = {
    Hip = 0.45, --accuracy while hip
    TacStance = 0.2, --accuracy in tac-stance
    Ads = 0, --accuracy while aiming
    Increase = 0.08, --increase cone size by this amount every time we shoot
    TacStanceMultiplier = 1, --multiply the increase value by this while in tac-stance
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 1.7, --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {0.5, 1.75}, --random value between the 2
    Horizontal = {-1, 1}, --random value between the 2
    Shake = 1, --camera shake
    AdsMultiplier = 0.5, --multiply the values by this amount while aiming
    Seed = 67498 --give this a random number until you like the current recoil pattern
}

SWEP.Bullet = {
    Damage = {50, 20}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    DropOffStartRange = 20, --in meters, damage will start dropping off after this range
    EffectiveRange = 65, --in meters, damage scales within this distance
    Range = 180, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.95, --how much damaged is multipled by when leaving a surface.
        MaxCount = 6, --how many times the bullet can penetrate.
        Thickness = 30, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 7
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 95, -90),
    Pos = Vector(3,-5,-3)
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
            [0] = {Pos = Vector(0, 0, 3), Angles = Angle(40, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(3, 0, 0), Angles = Angle(10, -20, 0)}
        }
    }
}

SWEP.Shell = "mwb_shelleject_7625x"

