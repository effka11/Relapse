ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "32 Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/attachment_vm_pi_papa320_mag_ext2.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/icon_attachment_pi_papa320_mag_ext2.vmt")


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 32
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.9
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.9
    
    weapon.Animations.Reload = weapon.Animations.Reload_XmagLrg
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_XmagLrg
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.85
    weapon.Animations.Reload_Fast.Fps = weapon.Animations.Reload_Fast.Fps * 0.85
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.85
    weapon.Animations.Reload_Empty_Fast.Fps = weapon.Animations.Reload_Empty_Fast.Fps * 0.85
end