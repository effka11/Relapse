ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "Singuard Arms Marksman"
ATTACHMENT.Model = Model("models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_stockh.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/alpha50/icon_attachment_sn_alpha50_stockh.vmt")
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.8
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.8
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.9
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.9
    weapon.Recoil.Punch = weapon.Recoil.Punch * 0.5
    weapon.Recoil.AdsMultiplier = weapon.Recoil.AdsMultiplier * 0.5
    weapon.Recoil.AdsShakeMultiplier = weapon.Recoil.AdsShakeMultiplier * 0.5
end