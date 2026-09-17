ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "Cartridge Sleeve"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_rack.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_rack.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.94
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.94
    weapon.Animations.Reload_Start.Fps = weapon.Animations.Reload_Start.Fps * 1.5
end