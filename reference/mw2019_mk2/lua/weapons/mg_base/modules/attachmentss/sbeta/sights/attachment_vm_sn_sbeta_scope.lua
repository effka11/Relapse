ATTACHMENT.Base = "att_optic_10x"
ATTACHMENT.Name = "Sniper Scope"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_scope.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_scope.vmt")
ATTACHMENT.Bodygroups = {
        ["tag_sight"] = 1,
        ["sight"] = 1
}
ATTACHMENT.Optic = {
        LensHideMaterial = Material("viper/mw/weapons/sbeta/weapon_vm_sn_sbeta_scope_lens1.vmt"),
        HideModel = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_scope_hide.mdl"),
        LensBodygroup = "lens",
        FOV = 7, 
        ParallaxSize = 750, --a value of zero means 1:1 size with the end of the optic
        Thermal = false
}
ATTACHMENT.Reticle = {
        Material = Material("viper/mw/reticles/reticle_sniper_new.vmt"),
        Size = 2000,
        Color = Color(255, 255, 255, 255),
        Attachment = "reticle"
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Zoom.ViewModelFovMultiplier = weapon.Zoom.ViewModelFovMultiplier * 0.9
end