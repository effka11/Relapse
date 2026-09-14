AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_lmg_3")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject2")

include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add( "mg_sierrax", "VGUI/entities/mg_sierrax", Color(255, 0, 0, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/spawnicons/icon_cac_weapon_lm_sierrax")
end

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_ang_offset", "grip_vert_offset"}

SWEP.PrintName = "FiNN LMG"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Lightmachine Guns"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_sierrax.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_sierrax.mdl")

SWEP.Slot = 2
SWEP.HoldType = "Rifle"
SWEP.Trigger = {
    PressedSound = Sound("weap_sierrax_prefire_plr"),
    ReleasedSound = Sound(""),
    Time = 0.05
}

SWEP.Primary.Sound = Sound("weap_sierrax_fire_plr")
SWEP.Primary.Ammo = "Ar2"
SWEP.Primary.ClipSize = 75
SWEP.Primary.Automatic = true
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 630
SWEP.CanChamberRound = false  
SWEP.CanDisableAimReload = true
  
SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_lmg_3",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject2", 
}

SWEP.Reverb = { 
    RoomScale = 50000, --(cubic hu)
    --how big should an area be before it is categorized as 'outside'?

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_LMG.Outside"),
            Reflection = Sound("Reflection_AR.Outside")
        },

        Inside = { 
            Layer = Sound("Atmo_LMG.Inside"),
            Reflection = Sound("Reflection_Shotgun.Inside")
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

}

SWEP.BarrelSmoke = {
    Particle = "AC_muzzle_pistol_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 35,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
}

SWEP.Cone = {
    Hip = 0.6, --accuracy while hip
    TacStance = 0.3, --accuracy in tac-stance
    Ads = 0, --accuracy while aiming
    Increase = 0.05, --increase cone size by this amount every time we shoot
    AdsMultiplier = 0, --multiply the increase value by this amount while aiming
    Max = 2, --the cone size will not go beyond this size
    DecreaseEveryShot = 0.075,
    MinDecreaseEveryShot = 0.25
}

SWEP.Recoil = {
    Vertical = {0.5, 0.75}, --random value between the 2
    Horizontal = {-0.4, 0.4}, --random value between the 2
    Shake = 1.25, --camera shake
    AdsMultiplier = 0.5, --multiply the values by this amount while aiming
    Seed = 6767, --give this a random number until you like the current recoil pattern
    DecreaseEveryShot = 0.05,
    MinDecreaseEveryShot = 0.5
}

SWEP.Bullet = {
    Damage = {26, 20}, --first value is damage at 0 meters from impact, second value is damage at furthest point in effective range
    DropOffStartRange = 15, --in meters, damage will start dropping off after this range
    EffectiveRange = 40, --in meters, damage scales within this distance
    Range = 180, --in meters, after this distance the bullet stops existing
    Tracer = false, --show tracer
    NumBullets = 1, --the amount of bullets to fire
    PhysicsMultiplier = 1, --damage is multiplied by this amount when pushing objects
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.8, --how much damaged is multipled by when leaving a surface.
        MaxCount = 3, --how many times the bullet can penetrate.
        Thickness = 12, --in hu, how thick an obstacle has to be to stop the bullet.
    }
}
SWEP.Zoom = {
    IdleSway = 0.1,
    FovMultiplier = 0.95,
    ViewModelFovMultiplier = 1,
    Blur = {
        EyeFocusDistance = 8
    }
}

SWEP.WorldModelOffsets = {
    Bone = "tag_sling",
    Angles = Angle(0, 0, -180),
    Pos = Vector(9,-1,-4)
}

SWEP.ViewModelOffsets = {
    Aim = {
        Angles = Angle(0, 0, 0),
        Pos = Vector(0, 1, 0)
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
            [0] = {Pos = Vector(0, -4, 3), Angles = Angle(40, 0, -30)},
            [1] = {Pos = Vector(0, 0, 0), Angles = Angle(-10, 0, 0)}
        },
        Y = {
            [0] = {Pos = Vector(3, 0, -2), Angles = Angle(-10, 20, 0)},
            [1] = {Pos = Vector(4, 0, 3), Angles = Angle(10, -20, 0)}
        }
    },
}

SWEP.Shell = "mwb_shelleject_556"

DEFINE_BASECLASS(SWEP.Base)

function SWEP:PreAttachments()
    BaseClass.PreAttachments(self)

    if (self:HasAttachment("attachment_vm_lm_sierrax_stocksaw")) then
        for _, anim in pairs(self.Animations) do
            anim.Sequences[1] = anim.Sequences[1] .. "_saw"
        end
    end
end

function SWEP:CanAim()
    if (self:HasAttachment("attachment_vm_lm_sierrax_stocksaw")) then
        return false
    end

    return BaseClass.CanAim(self)
end