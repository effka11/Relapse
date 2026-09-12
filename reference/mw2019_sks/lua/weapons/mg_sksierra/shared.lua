AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_dmr_2")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add( "mg_sksierra", "VGUI/entities/mg_sksierra", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_sn_sksierra")
end

SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset", "grip_vertpro_offset"}
SWEP.GripPoseParameters2 = {"grip_stockhvy_offset"}

SWEP.Base = "mg_base" 

SWEP.PrintName = "SKS"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Marksman Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_sksierra.mdl") 
SWEP.WorldModel = Model("models/viper/mw/weapons/w_sksierra.mdl") 
SWEP.Trigger = {
    PressedSound = Sound("mw19.sksierra.fire.first"),
    ReleasedSound = Sound("mw19.sksierra.disconnector"),
    Time = 0
}

SWEP.Slot = 3 
SWEP.HoldType = "Rifle"

SWEP.Primary.Sound = Sound("mw19.sksierra.fire")
SWEP.Primary.Ammo = "357"
SWEP.Primary.ClipSize = 20
SWEP.Primary.Automatic = true
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 328  
SWEP.CanChamberRound = true
SWEP.CanDisableAimReload = false

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_dmr_2",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject", 
}


SWEP.Reverb = { 
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_br1.Outside"),
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
        Name = "Semi-Automatic",
        OnSet = function(self)
            self.Primary.Automatic = false
            return "Firemode_Semi"
        end
    },

}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_minigun_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 75,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 65 --degrees per second
}

SWEP.Cone = {
    Hip = 1, --accuracy while hip
    TacStance = 0.2, --accuracy in tac-stance
    Ads = 0, --accuracy while aiming
    Increase = 0.08, --increase cone size by this amount every time we shoot
    TacStanceMultiplier = 1, --multiply the increase value by this while in tac-stance
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 2.5, --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {4, 5}, --random value between the 2
    Horizontal = {-1.75, 2.75}, --random value between the 2
    Shake = 3, --camera shake
    AdsMultiplier = 0.15, --multiply the values by this amount while aiming
    Seed = 3584, --give this a random number until you like the current recoil pattern
}
SWEP.Bullet = {
    Damage = {65, 23}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    EffectiveRange = 110, --in meters, damage scales within this distance
    DropOffStartRange = 30,
    Range = 250, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1.25, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 2,
    Penetration = {
        DamageMultiplier = 0.85, --how much damaged is multipled by when leaving a surface.
        MaxCount = 12, --how many times the bullet can penetrate.
        Thickness = 25, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.2,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 10
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(-3,100,-90),
    Pos = Vector(4,-1.5,-7)
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
    
    RecoilMultiplier = 1,
    KickMultiplier = 1,
    AimKickMultiplier = 0.5
}

SWEP.Shell = "mwb_shelleject_7625x"