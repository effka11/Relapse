AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_smg_0")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add( "mg_smgolf45", "VGUI/entities/mg_smgolf45", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_sm_smgolf45")
end

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_vertpro_offset", "grip_killtheclamp_offset"}

SWEP.PrintName = "Striker 45"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Submachine Guns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_smgolf45.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_smgolf45.mdl")

SWEP.Slot = 2
SWEP.HoldType = "Rifle"
SWEP.Trigger = {
    PressedSound = Sound("weap_smgolf45_fire_first_plr"),
    ReleasedSound = Sound("weap_smgolf45_disconnector_plr"),
    Time = 0
}

SWEP.Primary.Sound = Sound("weap_smgolf45_fire_plr_lfe")
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.ClipSize = 30
SWEP.Primary.Automatic = true
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 605  
SWEP.CanChamberRound = true  
  
SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_smg_0",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject", 
}

SWEP.Reverb = { 
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_SMG2.Outside"),
            Reflection = Sound("Reflection_Pistol.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_SMG.Inside"),
            Reflection = Sound("Reflection_Pistol.Inside")
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
    Hip = 0.35, --accuracy while hip
    TacStance = 0.2, --accuracy in tac-stance
    Ads = 0, --accuracy while aiming
    Increase = 0.07, --increase cone size by this amount every time we shoot
    TacStanceMultiplier = 0.8, --multiply the increase value by this while in tac-stance
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 1.3 --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {0.5, 0.7}, --random value between the 2
    Horizontal = {-0.35, 0.35}, --random value between the 2
    Shake = 1.35, --camera shake
    AdsMultiplier = 0.5, --multiply the values by this amount while aiming
    Seed = 67586758 --give this a random number until you like the current recoil pattern
}

SWEP.Bullet = {
    Damage = {26, 13}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    EffectiveRange = 38, --in meters, damage scales within this distance
    DropOffStartRange = 13, --in meters, damage will start dropping off after this range
    Range = 100, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.5, --how much damaged is multipled by when leaving a surface.
        MaxCount = 3, --how many times the bullet can penetrate.
        Thickness = 15, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.15,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 7.5
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0,90,-90),
    Pos = Vector(3,-4.5,-3.5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 2, 0)
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
            [0] = {Pos = Vector(5, 0, 3), Angles = Angle(40, 0, 0)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-15, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(0, 0, 1.5), Angles = Angle(10, 0, 15)}
        }
    },

    RecoilMultiplier = 0.5,
    KickMultiplier = 0.4,
    AimKickMultiplier = 1.75
}

SWEP.Shell = "mwb_shelleject_45"


DEFINE_BASECLASS("mg_base")