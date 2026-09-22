AddCSLuaFile()

PrecacheParticleSystem("mwb_muzzle_ar_1")
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mw_fas2_muzzleflash_ar_smoke_barrel")
include("animations.lua")
include("customization.lua")

if CLIENT then
    killicon.Add("mg_mike4", "zombiesurvival/killicons/weapon_zs_m4a1_side4.png", Color(255, 255, 255))
    SWEP.WepSelectIcon = surface.GetTextureID("zombiesurvival/killicons/weapon_zs_m4a1_side4.png")
end

SWEP.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_m4a1_side4.png"
-- Default receiver is a real mdl (not AK's empty att_receiver). Barrel/mag/stock
-- bone-merge onto tag_*_attach. WM variant 0 — do not copy MP5 [0]=1.
-- DrawModel after SetupBones is +Z: hull + LocalAng 90 like AK/SCAR.
SWEP.RelapsePreviewBoneMerge = true
SWEP.RelapsePreviewHullBounds = true
SWEP.RelapsePreviewParts = {
	"models/viper/mw/weapons/w_mike4.mdl",
	"models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_receiver.mdl",
	"models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_barrel.mdl",
	"models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_mag.mdl",
	"models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_stock.mdl",
}
SWEP.RelapsePreviewAngle = Angle(0, 0, 0)
SWEP.RelapsePreviewLocalAng = Angle(0, 0, 90)
SWEP.RelapsePreviewOffset = Vector(0, 0, -3)
SWEP.RelapsePreviewLift = 2.8
SWEP.RelapsePreviewCamScale = 1.4

SWEP.Base = "mg_base"
SWEP.GripPoseParameters = {"grip_gripvert_offset", "grip_gripvertpro_offset", "grip_barshort_gripang_offset", "grip_barshort_gripvert_offset", "grip_gripang_offset", "grip_barlong_gripvert_offset", "grip_barlong_gripang_offset", "grip_m203_offset", "grip_m203_gripvert_offset", "grip_m203_gripang_offset"}

SWEP.PrintName = "M4A1"
SWEP.TranslationName = "wep_m4a1"
SWEP.TranslationDescription = "wep_m4a1_desc"
SWEP.Category = "Modern Warfare"
SWEP.SubCategory = "Assault Rifles"
SWEP.Spawnable = true
SWEP.VModel = Model("models/viper/mw/weapons/v_mike4.mdl")
SWEP.WorldModel = Model("models/viper/mw/weapons/w_mike4.mdl")
SWEP.Trigger = {
    PressedSound = Sound("mw19.mike4.fire.first"),
    ReleasedSound = Sound("mw19.mike4.fire.disconnector"),
    Time = 0
}

SWEP.Slot = 3
SWEP.HoldType = "Rifle"
SWEP.Tier = 3
SWEP.AlternateGrips = false

-- Relapse combat stats. Source of truth for MW gunplay, usefulness, and the shop UI.
-- Kinetic = fraction of close-range damage lost by EffectiveRange (0 = none, 1 = all).
-- Accuracy = spread cone (higher = wider). Recoil = kick. Shop stability uses both.
-- Weight is kilograms (M4A1 empty ~2.88 kg). Clip is the real 30-round STANAG.
-- 5.56 auto tax: below AK 7.62x39 (24) and FiNN box (23) per shot so 800 RPM stays T3.
SWEP.Relapse = {
    Damage = 20,
    Delay = 0.075,
    Reload = 2.2,
    Kinetic = 0.28,
    Recoil = 0.85,
    Accuracy = 1.10,
    Weight = 2.88,
    Clip = 30,
    Automatic = true,
}

local R = SWEP.Relapse
local farDamage = math.max(1, R.Damage * (1 - R.Kinetic))

SWEP.Primary = SWEP.Primary or {}
SWEP.Primary.Sound = Sound("mw19.mike4.fire")
SWEP.Primary.Ammo = "556x45"
SWEP.Primary.Damage = R.Damage
SWEP.Primary.Delay = R.Delay
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize = R.Clip
SWEP.Primary.Automatic = true
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = math.floor(60 / R.Delay + 0.5)
SWEP.CanChamberRound = true
SWEP.ReloadTime = R.Reload
SWEP.ConeMin = R.Accuracy * 0.5
SWEP.ConeMax = R.Accuracy * 1.5
SWEP.ConeRamp = 2
SWEP.DrawCrosshair = false

SWEP.ParticleEffects = {
    ["MuzzleFlash"] = "mwb_muzzle_ar_1",
    ["MuzzleFlash_Suppressed"] = "mwb_suppressor_0",
    ["Ejection"] = "mwb_shell_eject",
}

SWEP.Reverb = {
    RoomScale = 50000, --(cubic hu)

    Sounds = {
        Outside = {
            Layer = Sound("Atmo_AR2.Outside"),
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
        Name = "Full Auto",
        OnSet = function(self)
            self.Primary.Automatic = true
            return "Firemode_Auto"
        end
    },

    [2] = {
        Name = "Semi Auto",
        OnSet = function(self)
            self.Primary.Automatic = false
            return "Firemode_Semi"
        end
    },
}

SWEP.BarrelSmoke = {
    Particle = "mw_fas2_muzzleflash_ar_smoke_barrel",
    Attachment = "muzzle",
    ShotTemperatureIncrease = 35,
    TemperatureThreshold = 100, --temperature that triggers smoke
    TemperatureCooldown = 100 --degrees per second
}

SWEP.Cone = {
    Hip = R.Accuracy / 36,
    TacStance = false,
    Ads = R.Accuracy / 36,
    Increase = 0.1 * (R.Accuracy / 1.8),
    TacStanceMultiplier = 0.7,
    AdsMultiplier = 0.15,
    Max = R.Accuracy * (1.3 / 1.8),
}

SWEP.Recoil = {
    Vertical = {1.0 * R.Recoil, 1.25 * R.Recoil},
    Horizontal = {-0.8 * R.Recoil, 0.8 * R.Recoil},
    Shake = 1.5 * R.Recoil,
    AdsMultiplier = 0.5,
    Seed = 2548715
}

SWEP.Bullet = {
    Damage = {R.Damage, farDamage},
    DropOffStartRange = 18,
    EffectiveRange = 40, --in meters, damage scales within this distance
    Range = 180, --in meters, after this distance the bullet stops existing
    Tracer = false,
    NumBullets = 1,
    PhysicsMultiplier = 1,
    HeadshotMultiplier = 1, --this gets multiplied by 2
    Penetration = {
        DamageMultiplier = 0.8,
        MaxCount = 3,
        Thickness = 12,
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
    Angles = Angle(0, 95, -90),
    Pos = Vector(3, -5, -3.5)
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
    }
}

SWEP.Shell = "mwb_shelleject_556"

SWEP.WalkSpeed = SPEED_NORMAL or 95
SWEP.NoDeploySpeedChange = true
SWEP.RequiredClip = 1
SWEP.Description = "A duty carbine. Thirty 5.56×45s: lighter than the AK, the mag still ends."

function SWEP:GetWalkSpeed()
    return self.WalkSpeed or SPEED_NORMAL or 95
end

DEFINE_BASECLASS("mg_base")
SWEP.bEnableMagPoseParam = true

function SWEP:PostDrawViewModel(vm, weapon, ply)
    BaseClass.PostDrawViewModel(self, vm, weapon, ply)

    if (self.bEnableMagPoseParam) then
        self:UpdateMagPoseParam(1 - self:Clip1() / self:GetMaxClip1())
    end
end

function SWEP:AllowRuntimeMagPoseParam(allow)
    self.bEnableMagPoseParam = allow
end

function SWEP:UpdateMagPoseParam(val)
    local mag = self:GetAttachmentInUseForSlot(4).m_Model

    if (IsValid(mag) && mag != nil) then
        mag:SetPoseParameter("bullets_offset", val)
    end
end
