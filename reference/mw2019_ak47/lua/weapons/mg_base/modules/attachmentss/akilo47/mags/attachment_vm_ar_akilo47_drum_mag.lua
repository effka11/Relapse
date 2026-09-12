ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "75 Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/akilo47/attachment_vm_ar_akilo47_drum_mag.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/akilo47/icon_attachment_drums_akilo47.vmt")

ATTACHMENT.BulletList = {
    [1] = {"j_drumbullet1"},
    [2] = {"j_drumbullet2"},
    [3] = {"j_drumbullet3"}
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 75
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.9
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.9
    
    weapon.Animations.Reload = weapon.Animations.Reload_XmagLrg
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_XmagLrg
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.95
    weapon.Animations.Reload_Fast.Fps = weapon.Animations.Reload_Fast.Fps * 0.95
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.95
    weapon.Animations.Reload_Empty_Fast.Fps = weapon.Animations.Reload_Empty_Fast.Fps * 0.95
end