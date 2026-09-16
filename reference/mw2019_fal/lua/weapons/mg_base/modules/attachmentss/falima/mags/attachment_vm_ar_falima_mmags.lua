ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "24 Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/falima/attachment_vm_ar_falima_mmags.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/falima/icon_attachment_ar_falima_mmags.vmt")


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 24
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.95
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.95

    weapon.Animations.Reload = weapon.Animations.Reload_Xmag
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.9
    weapon.Animations.Reload_Fast.Fps = weapon.Animations.Reload_Fast.Fps * 0.9
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.9
    weapon.Animations.Reload_Empty_Fast.Fps = weapon.Animations.Reload_Empty_Fast.Fps * 0.9
end