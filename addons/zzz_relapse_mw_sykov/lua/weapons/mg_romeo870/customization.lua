AddCSLuaFile()

function SWEP:doSuppressorStats()
    self.Primary.Sound = Sound("weap_romeo870_sup_plr_lfe")
    self.Reverb = {
        RoomScale = 50000,
        Sounds = {
            Outside = {
                Layer = Sound("Atmo_Shotgun2.Outside"),
                Reflection = Sound("Reflection_ARSUP.Outside")
            },
    
            Inside = { 
                Layer = Sound("Reflection_ARSUP.Inside"),
                Reflection = Sound("Reflection_ShotgunSUP.Inside")
            }
        }
    }
    self.ParticleEffects.MuzzleFlash = "mw_fas2_muzzleflash_suppressed"
end

function SWEP:doDBStats()
    self.Primary.TrailingSound = Sound("wpn_shotgun_fire_lyr")
    self.ParticleEffects.MuzzleFlash = "AC_muzzle_shotgun_db"
end

SWEP.Customization = {
    {"att_perk", "attachment_vm_sh_romeo870_perk_soh", "att_perk_hip", "attachment_vm_sh_romeo870_perk_slamfire"}, 

    {"attachment_vm_sh_romeo870_barrel", "attachment_vm_sh_romeo870_heatguard_mp", "attachment_vm_sh_romeo870_barrel_long",
    "attachment_vm_sh_romeo870_barrel_sawn"},

    {"attachment_vm_sh_romeo870_pump", "attachment_vm_sh_romeo870_pumpalt", "attachment_vm_sh_romeo870_pump_wood", "attachment_vm_sh_romeo870_pump_custom"},

    {"att_magazine", "attachment_vm_sh_romeo870_mag"},

    {"att_ammo_default", "att_ammo_db", "att_ammo_flechette",
    "att_ammo_he", "att_ammo_slugs"},

    {"att_stock", "attachment_vm_sh_romeo870_stock_wood", 
    "attachment_vm_sh_romeo870_stock_pistolgrip", "att_vm_romeo870_stock_heavy01", 
    "att_vm_romeo870_stock_heavy02", "att_vm_romeo870_stock_light01", "att_vm_romeo870_stock_medium01"},

    {"att_muzzle", "att_vm_compensator_shgn01", "att_vm_compensator_shgn02", "att_vm_flashhider01_shgn", "att_vm_muzzlebrake_shgn01", 
    "att_vm_breacher02_shgn", "attachment_vm_sh_romeo870_shtgnsilencer", "attachment_vm_sh_romeo870_silencer02", 
    "attachment_vm_sh_romeo870_silencer03"},

    {"att_sight", "att_vm_2x_west02_holo", "att_vm_2x_west02", "att_vm_reflex_02", "attachment_vm_sh_romeo870_no_rail", "att_vm_minireddot01_tall", "att_vm_minireddot02_tall", "att_vm_minireddot03_tall",
    "att_vm_holo_west01", "att_vm_holo_west02", "att_vm_holo_east01", "att_vm_reflex_east01",
    "att_vm_reflex_east02_tall", "att_vm_reflex_west02_tall", "att_vm_reflex_west03",
    "att_vm_thermal_east01", "att_vm_thermal_west01", "att_vm_reflex_west04", "att_vm_2x_west01",
    "att_vm_4x_east01_tall", "att_vm_4x_west01_tall", "att_vm_4x_west02_tall",
    "att_vm_scope_mike14", "att_vm_scope_vz"},
    
    {"attachment_vm_sh_romeo870_receiver"},

    {"att_laser", "attachment_vm_sh_romeo870_laser01", "attachment_vm_sh_romeo870_laser02", "attachment_vm_sh_romeo870_laser03"},
    
    {"att_grip", "attachment_vm_sh_romeo870_angledgrip01", "attachment_vm_sh_romeo870_angledgrip02", "attachment_vm_sh_romeo870_stubbygrip01", 
    "attachment_vm_sh_romeo870_stubbygrip02", "attachment_vm_sh_romeo870_vertgrip01", "attachment_vm_sh_romeo870_vertgrip02", 
    "attachment_vm_sh_romeo870_vertgrip03"},
}

--NECESSARY: it loads custom attachments from other authors
require("mw_utils")
mw_utils.LoadInjectors(SWEP)   