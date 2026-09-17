AddCSLuaFile()

function SWEP:doSuppressorStats()
    self.Primary.Sound = Sound("weap_alpha50_fire_plr_sup")
    self.Reverb = {
        RoomScale = 50000,
        Sounds = {
            Outside = {
                Layer = Sound("Atmo_Sniper_Sup.Outside"),
                Reflection = Sound("Reflection_Sniper.Outside")
            },
    
            Inside = { 
                Layer = Sound("Atmo_DMR_Sup.Inside"),
                Reflection = Sound("Reflection_ARSUP.Inside")
            }
        }
    }
    self.ParticleEffects.MuzzleFlash = "mwb_suppressor_0"
end

SWEP.Customization = {
    {"att_perk", "attachment_vm_sn_alpha50_perk_soh", 
    "att_perk_steadywalk", "att_perk_nodrop", "att_perk_scopesway"}, 

    {"attachment_vm_sn_alpha50_stock", "attachment_vm_sn_alpha50_stockh", 
    "attachment_vm_sn_alpha50_stockl", "attachment_vm_sn_alpha50_stocks"},

    {"attachment_vm_sn_alpha50_mag",  "attachment_vm_sn_alpha50_xmags", "attachment_vm_sn_alpha50_mmags"},
   
    {"attachment_vm_sn_alpha50_barrel", "attachment_vm_sn_alpha50_barshort", 
    "attachment_vm_sn_alpha50_barmid", "attachment_vm_sn_alpha50_barlong"},

    {"att_muzzle", "att_vm_alpha50_compensator01", "att_vm_alpha50_flashhider01", "att_vm_alpha50_muzzlebrake01", 
    "att_vm_alpha50_muzzlebrake02", "att_vm_alpha50_silencer01", "att_vm_alpha50_silencer02", "att_vm_alpha50_silencer03"}, 

    {"att_sight", "att_vm_2x_west02_holo", "att_vm_2x_west02", "att_vm_reflex_02", "att_vm_2x_west02_holo", "att_vm_2x_west02", "att_vm_reflex_02", "attachment_vm_sn_alpha50_scope",
    "att_vm_minireddot01_tall", "att_vm_minireddot02_tall", "att_vm_minireddot03_tall",
    "att_vm_holo_west01", "att_vm_holo_west02", "att_vm_holo_east01", "att_vm_reflex_east01",
    "att_vm_reflex_east02_tall", "att_vm_reflex_west02_tall", "att_vm_reflex_west03",
    "att_vm_thermal_east01", "att_vm_thermal_west01", "att_vm_4x_east01_tall", "att_vm_2x_west01", "att_vm_scope_vz"},

    {"att_laser", "attachment_vm_sn_alpha50_laser01", "attachment_vm_sn_alpha50_laser02", 
    "attachment_vm_sn_alpha50_laser03"},
}

--NECESSARY: it loads custom attachments from other authors
require("mw_utils")
mw_utils.LoadInjectors(SWEP)   