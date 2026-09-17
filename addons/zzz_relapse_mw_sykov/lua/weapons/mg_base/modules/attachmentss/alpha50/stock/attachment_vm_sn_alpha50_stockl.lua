ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "Singuard Arms Evader"
ATTACHMENT.Model = Model("models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_stockl.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/alpha50/icon_attachment_sn_alpha50_stockl.vmt")
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.1
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.1
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 1.12
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 1.12
    weapon.Recoil.AdsMultiplier = weapon.Recoil.AdsMultiplier * 1.2
    weapon.Zoom.MovementMultiplier = weapon.Zoom.MovementMultiplier * 1.5
end