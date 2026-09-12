ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "5.45x39mm 45-Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/attachment_vm_ar_anov94_xmags.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/icon_attachment_ar_anov94_xmags.vmt")

-- bullets arent rigged VIPER.

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon:doSmgStats()
    weapon.Primary.ClipSize = 45
    weapon.Primary.RPM = 690
    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 0.85
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 0.85
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 0.95
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 0.95
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.85
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.85
    weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.85
    weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.85
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.95
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.95
    weapon.PrintName = "AK-74"

    if weapon:HasAttachment("attachment_vm_ar_akilo47_smgstock_unfolded") || weapon:HasAttachment("attachment_vm_ar_akilo47_smgstock") then 
        weapon.PrintName = "AKS-74"
    end
    if weapon:HasAttachment("attachment_vm_ar_akilo47_smgbarrel") || weapon:HasAttachment("attachment_vm_ar_akilo47_smgbarcust") then 
        weapon.PrintName = "AKS-74U"
    end
    if weapon:HasAttachment("attachment_vm_ar_akilo47_custombarrel") then 
        weapon.PrintName = "AK-12"
    end

    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.9
    weapon.Animations.Reload_Fast.Fps = weapon.Animations.Reload_Fast.Fps * 0.9
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.9
    weapon.Animations.Reload_Empty_Fast.Fps = weapon.Animations.Reload_Empty_Fast.Fps * 0.9
end