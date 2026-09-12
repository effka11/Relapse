AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_ar_10")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add( "mg_valpha", "VGUI/entities/mg_valpha", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_ar_valpha")
end

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_barheavy_offset", "grip_barlight_offset",
"grip_barshort_offset", "grip_magwell_offset"}

SWEP.PrintName = "AS-VAL"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Assault Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_valpha.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_valpha.mdl")
SWEP.Trigger = {
    PressedSound = Sound("mw19.valpha.fire.first"),
    ReleasedSound = Sound("mw19.valpha.disconnector"),
    Time = 0
}

SWEP.Slot = 2
SWEP.HoldType = "Rifle"

SWEP.Primary.Sound = Sound("mw19.valpha.fire")
SWEP.Primary.Ammo = "Ar2"
SWEP.Primary.ClipSize = 20
SWEP.Primary.Automatic = true
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 885  
SWEP.CanChamberRound = true  
  
SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_suppressor_0",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject", 
}

SWEP.Reverb = { 
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_AR_Sup.Outside"),
            Reflection = Sound("Reflection_ARSUP.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_AR_Sup.Inside"),
            Reflection = Sound("Reflection_ARSUP.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Full Auto",
        OnSet = function()
            return "Firemode_Auto"
        end
    },

    [2] = {
        Name = "Semi Auto",
        OnSet = function(self)
            self.Primary.Automatic = false
            --self.Primary.RPM = 450

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
    Hip = 0.45, --accuracy while hip
    TacStance = 0.2, --accuracy in tac-stance
    Ads = 0, --accuracy while aiming
    Increase = 0.06, --increase cone size by this amount every time we shoot
    TacStanceMultiplier = 0.7, --multiply the increase value by this while in tac-stance
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 1.7, --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {1, 1.4}, --random value between the 2
    Horizontal = {-0.6, 1.1}, --random value between the 2
    Shake = 1.15, --camera shake
    AdsMultiplier = 0.5, --multiply the values by this amount while aiming
    Seed = 8778456, --give this a random number until you like the current recoil pattern
}
SWEP.Bullet = {
    Damage = {35, 15}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    DropOffStartRange = 21, --in meters, damage will start dropping off after this range
    EffectiveRange = 48, --in meters, damage scales within this distance
    Range = 180, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.63, --how much damaged is multipled by when leaving a surface.
        MaxCount = 2, --how many times the bullet can penetrate.
        Thickness = 5, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 6.5
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 100, -90),
    Pos = Vector(4,-3,-3)
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
            [0] = {Pos = Vector(0, 3, 3), Angles = Angle(40, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(4, 0, 1.5), Angles = Angle(10, -20, 0)}
        }
    },
    
    RecoilMultiplier = 0.5,
    KickMultiplier = 0.25,
    AimKickMultiplier = 0.95
}

SWEP.Shell = "mwb_shelleject_939"

DEFINE_BASECLASS("mg_base")