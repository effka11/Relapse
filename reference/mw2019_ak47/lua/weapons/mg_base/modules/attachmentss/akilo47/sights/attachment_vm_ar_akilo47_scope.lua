ATTACHMENT.Base = "attachment_vm_sn_delta_scope"
ATTACHMENT.Name = "Dragunov Scope"
ATTACHMENT.AttachmentBodygroups ={
    ["tag_rail"] = 0
}
ATTACHMENT.Model = Model("models/viper/mw/attachments/delta/attachment_vm_sn_delta_scope.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/delta/icon_attachment_sn_delta_scope.vmt")

ATTACHMENT.Optic = {
    HideModel = Model("models/viper/mw/attachments/delta/attachment_vm_sn_delta_scope_hid.mdl"),
    LensHideMaterial = Material("viper/MW/weapons/delta/weapon_vm_sn_delta_scope_lens.vmt"),
    LensBodygroup = "lens",
    FOV = 7, 
    ParallaxSize = 700, --a value of zero means 1:1 size with the end of the optic
    Thermal = false
}

ATTACHMENT.VElement = {
    Bone = "tag_reflex",
    Position = Vector(0, 7, -0.7),
    Angles = Angle(),
    Offsets = {}
}
ATTACHMENT.Reticle = {
    Material = Material("viper/shared/reticles/po4x_crosshair_new.vmt"),
    Size = 1900,
    Color = Color(255, 255, 255, 255),
    Attachment = "reticle"
}
