AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_sg_0")
PrecacheParticleSystem("mwb_muzzle_sg_3")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mwb_airflow_eject")

SWEP.BulletList = {[0] = "j_ammoshell1", [1] = "j_ammoshell2"}

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add( "mg_aalpha12", "VGUI/entities/mg_aalpha12", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_sh_aalpha12")
end

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}

SWEP.PrintName = "Jak-12"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Shotguns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_aalpha12.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_aalpha12.mdl")
SWEP.Trigger = {
    PressedSound = Sound("mw19.aalpha12.fire.first"),
    ReleasedSound = Sound("mw19.aalpha12.disconnector"),
    Time = 0
}

SWEP.Slot = 3
SWEP.HoldType = "Rifle"

SWEP.Primary.Sound = Sound("mw19.aalpha12.fire")
SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.ClipSize = 8
SWEP.Primary.Automatic = true
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 339  
SWEP.CanChamberRound = false  
SWEP.CanDisableAimReload = false
  
SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_sg_0",
    ["MuzzleFlash_DB"] = "mwb_muzzle_sg_3",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject", 
    ["Overheating"] = "mwb_airflow_eject",
}

SWEP.Reverb = { 
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_Sniper.Outside"),
            Reflection = Sound("Reflection_Shotgun.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_Shotgun.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
        }
    }
}

SWEP.Firemodes = {
    [1] = {
        Name = "Automatic",
        OnSet = function(self)
            self.Primary.Automatic = true
            return "Firemode_Auto"
        end
    },

}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_minigun_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 75,
    TemperatureThreshold = 250, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
}

SWEP.Cone = {
    Hip = 0.75, --accuracy while hip
    Ads = 0.35, --accuracy while aiming
    TacStance = 0.5, --accuracy in tac-stance
    Increase = 0.12, --increase cone size by this amount every time we shoot
    TacStanceMultiplier = 0.8, --multiply the increase value by this while in tac-stance
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 2.3, --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {0.5, 1}, --random value between the 2
    Horizontal = {-0.5, 0.5}, --random value between the 2
    Shake = 3, --camera shake
    AdsMultiplier = 0.5, --multiply the values by this amount while aiming
    Seed = 1158, --give this a random number until you like the current recoil pattern
}

SWEP.Bullet = {
    Damage = {60, 35}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    EffectiveRange = 10, --in meters, damage scales within this distance
    DropOffStartRange = 10,
    Range = 40, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 4, --the amount of bullets to fire
    PhysicsMultiplier = 1.7, --damage is multiplied by this amount when pushing objects
    Penetration = {
        DamageMultiplier = 0.94, --how much damaged is multipled by when leaving a surface.
        MaxCount = 10, --how many times the bullet can penetrate.
        Thickness = 12, --in hu, how thick an obstacle has to be to stop the bullet.
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
    Angles = Angle(-3,90,-90),
    Pos = Vector(3.5,-6,-4)
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
    },
}

SWEP.Shell = "mwb_shelleject_12g_black"

DEFINE_BASECLASS("mg_base")