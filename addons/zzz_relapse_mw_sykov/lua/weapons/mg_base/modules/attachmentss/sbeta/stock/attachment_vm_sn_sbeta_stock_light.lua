ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "MK2 Ultralight Hollow"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_stock_light.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_stock_light.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Recoil.AdsMultiplier = weapon.Recoil.AdsMultiplier * 1.15
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.03
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.03
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 1.1
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 1.1
end