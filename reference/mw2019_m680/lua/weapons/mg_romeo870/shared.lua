AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_sg_0")
PrecacheParticleSystem("mwb_muzzle_sg_3")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mwb_airflow_eject")

SWEP.BulletList = {"j_shell_12ga_01", "j_shell_12ga_02"}

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add( "mg_romeo870", "VGUI/entities/mg_romeo870", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_sh_romeo870")
end

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_wood_offset"}
SWEP.GripPoseParameters2 = {"grip_stockh_offset"}

SWEP.PrintName = "Model 680"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Shotguns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_romeo870.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_romeo870.mdl")

SWEP.Trigger = {
    PressedSound = Sound("weap_oscar12_fire_plr_first"),
    ReleasedSound = Sound("weap_sh_charlie725_disconnector_plr"),
    Time = 0
}

SWEP.DisableCantedReload = false
SWEP.Slot = 3
SWEP.HoldType = "Rifle"

SWEP.Primary.Sound = Sound("weap_romeo870_fire_plr_lfe")
SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.ClipSize = 8
SWEP.Primary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 175  
SWEP.CanChamberRound = true  
SWEP.CanDisableAimReload = false
SWEP.EmptyReloadRechambers = false
  
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
            Layer = Sound("Atmo_Shotgun.Outside"),
            Reflection = Sound("Reflection_Shotgun.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_LMG.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
        }
    }
}

SWEP.Firemodes = {

    [1] = {
        Name = "Pump-Action",
        OnSet = function(self)
            self.Primary.Automatic = false
            return "Firemode_Semi"
        end
    },

}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_minigun_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 65,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 65 --degrees per second
}

SWEP.Cone = {
    Hip = 0.8, --accuracy while hip
    Ads = 0.4, --accuracy while aiming
    TacStance = 0.55, --accuracy in tac-stance
    Increase = 0.12, --increase cone size by this amount every time we shoot
    TacStanceMultiplier = 0.7, --multiply the increase value by this while in tac-stance
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 2.3, --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {4, 3.25}, --random value between the 2
    Horizontal = {-0.8, 1.8}, --random value between the 2
    Shake = 4, --camera shake
    AdsMultiplier = 0.5, --multiply the values by this amount while aiming
    Seed = 65947, --give this a random number until you like the current recoil pattern
}

SWEP.Bullet = {
    Damage = {103, 40}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    EffectiveRange = 20, --in meters, damage scales within this distance
    DropOffStartRange = 15,
    Range = 40, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 6, --the amount of bullets to fire
    PhysicsMultiplier = 1.7, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.86, --how much damaged is multipled by when leaving a surface.
        MaxCount = 13, --how many times the bullet can penetrate.
        Thickness = 18, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 10
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0,100,-90),
    Pos = Vector(10,-1,-5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0.03, 0, 0)
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
            [1] = {Pos = Vector(-3, -1, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(4, -2, 1.5), Angles = Angle(10, -10, 0)}
        }
    },
}

SWEP.Shell = "mwb_shelleject_12g"

DEFINE_BASECLASS("mg_base")