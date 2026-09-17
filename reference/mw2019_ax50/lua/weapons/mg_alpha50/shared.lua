AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_sr_0")
PrecacheParticleSystem("AC_muzzle_shotgun_db")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("AC_muzzle_minigun_smoke_barrel")
include("animations.lua")
include("customization.lua") 

if CLIENT then
    killicon.Add( "mg_alpha50", "VGUI/entities/mg_alpha50", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_sn_alpha50")
end

SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}
-- SWEP.GripPoseParameters2 = {"grip_pistolgrip_offset"}

SWEP.Base = "mg_base" 

SWEP.PrintName = "AX-50"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Sniper Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/vm_sn_alpha50.mdl") 
SWEP.WorldModel = Model("models/viper/mw/weapons/w_alpha50.mdl") 
SWEP.Trigger = {
    PressedSound = Sound("weap_delta_fire_first"),
    ReleasedSound = Sound("weap_delta_fire_disconnector"),
    Time = 0
}

SWEP.Slot = 3 
SWEP.HoldType = "BoltAction"

SWEP.Primary.Sound = Sound("weap_alpha50_fire_plr")
SWEP.Primary.Ammo = "357"
SWEP.Primary.ClipSize = 5
SWEP.Primary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 297  
SWEP.CanChamberRound = true
SWEP.CanDisableAimReload = false
SWEP.ReloadRechambers = true
SWEP.Projectile = {
    Class = "mg_sniper_bullet", --bullet entity class
    Speed = 60000, 
    Gravity = 8,
    Penetrate = true
}

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_sr_0",
    ["MuzzleFlash_DB"] = "mw_fas2_muzzleflash_slug",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject", 
    ["Overheating"] = "AC_muzzle_pistol_smoke_barrel", 
}
SWEP.Reverb = { 
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_Sniper.Outside"),
            Reflection = Sound("Reflection_Sniper.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_Shotgun.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
        }
    }
}

SWEP.Firemodes = {

    [1] = {
        Name = "Bolt-Action",
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
    Hip = 2, --accuracy while hip
    Ads = 0, --accuracy while aiming
    Increase = 3, --increase cone size by this amount every time we shoot
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 5, --the cone size will not go beyond this size
}

SWEP.Recoil = {
    Vertical = {3, 4}, --random value between the 2
    Horizontal = {-1, 1}, --random value between the 2
    Shake = 5, --camera shake
    AdsMultiplier = 1, --multiply the values by this amount while aiming
    Seed = 3584, --give this a random number until you like the current recoil pattern
    Punch = 1, --recoil will offset the view by this amount (takes vertical, horizontal and adsmul into account)
    AdsShakeMultiplier = 2
}
SWEP.Bullet = {
    Damage = {190, 140}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    EffectiveRange = 300, --in meters, damage scales within this distance
    DropOffStartRange = 30,
    Range = 350, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1.25, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 2,
    Penetration = {
        DamageMultiplier = 1, --how much damaged is multipled by when leaving a surface.
        MaxCount = 6, --how many times the bullet can penetrate.
        Thickness = 32, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}

SWEP.Zoom = {
    IdleSway = 0.2,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    BreathingMultiplier = 1,
    MovementMultiplier = 1,
    Blur = {
        EyeFocusDistance = 10
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(10,5,180),
    Pos = Vector(10,-2, -1.5)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, -4, 0.55)
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
    
    RecoilMultiplier = 1.75,
    KickMultiplier = 3.3,
    AimKickMultiplier = 0.45
}

SWEP.Shell = "mwb_shelleject_50bmg"

function SWEP:PrimaryAttack()
    local clip = self:Clip1()
    weapons.Get(self.Base).PrimaryAttack(self)
    if (clip != self:Clip1()) then
        self:MakeEnvironmentDust(210)
    end
end