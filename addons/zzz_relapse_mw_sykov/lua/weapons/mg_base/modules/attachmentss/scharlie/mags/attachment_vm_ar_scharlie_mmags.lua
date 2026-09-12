ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "25 Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/attachment_vm_ar_scharlie_mmags.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/scharlie/icon_attachment_ar_scharlie_mmags.vmt")


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 25
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.95
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.95

    weapon.Animations.Reload = weapon.Animations.Reload_Xmag
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.9
    weapon.Animations.Reload_Fast.Fps = weapon.Animations.Reload_Fast.Fps * 0.9
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.9
    weapon.Animations.Reload_Empty_Fast.Fps = weapon.Animations.Reload_Empty_Fast.Fps * 0.9
end