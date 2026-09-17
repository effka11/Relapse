ATTACHMENT.Base = "att_optic_20x"
ATTACHMENT.Name = "AX-50 Scope"

ATTACHMENT.Model = Model("models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_scope.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/alpha50/icon_attachment_sn_alpha50_scope_v4.vmt")
ATTACHMENT.Bodygroups = {
    ["tag_sight"] = 2
}

ATTACHMENT.Optic = {
    HideModel = Model("models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_scope_hide.mdl"),
    LensHideMaterial = Material("viper/MW/weapons/alpha50/weapon_vm_sn_alpha50_hipfire_scope_lens.vmt"),
    LensBodygroup = "lens",
    FOV = 7, 
    ParallaxSize = 700, --a value of zero means 1:1 size with the end of the optic
    Thermal = false
}

ATTACHMENT.Reticle = {
    Material = Material("viper/mw/reticles/reticle_sniper_new.vmt"),
    Size = 2000,
    Color = Color(255, 255, 255, 255),
    Attachment = "reticle"
}