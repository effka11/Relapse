ATTACHMENT.Base = "att_optic_4x"
ATTACHMENT.Name = "PU Scope"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_scope.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_scope.vmt")
ATTACHMENT.Optic = {
        HideModel = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_scope_hide.mdl"),
        LensHideMaterial = Material("viper/mw/weapons/sksierra/weapon_vm_sn_sksierra_scopelens.vmt"),
        LensBodygroup = "lens",
        FOV = 7, 
        ParallaxSize = 750, --a value of zero means 1:1 size with the end of the optic
        Thermal = false
}
ATTACHMENT.Reticle = {
        Material = Material("viper/mw/reticles/reticle_16.vmt"),
        Size = 600,
        Color = Color(255, 255, 255, 255),
        Attachment = "reticle"
}