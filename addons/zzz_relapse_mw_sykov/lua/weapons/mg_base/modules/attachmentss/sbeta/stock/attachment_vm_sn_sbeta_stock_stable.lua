ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "FSS MK2 Sport Comb"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_stock_stable.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_stock_stable.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Recoil.AdsMultiplier = weapon.Recoil.AdsMultiplier * 1.2
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.08
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.08
end