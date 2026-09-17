ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "7 Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_mmags.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/alpha50/icon_attachment_sn_alpha50_mmags.vmt")


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Reload = weapon.Animations.reload_mmag
    weapon.Animations.Reload_Fast = weapon.Animations.reload_mmag_fast
    weapon.Animations.Reload_Empty = weapon.Animations.reload_empty_mmag
    weapon.Animations.Reload_Empty_Fast = weapon.Animations.reload_empty_mmag_fast
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.93
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.93
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.95
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.95
    weapon.Primary.ClipSize = 7
end