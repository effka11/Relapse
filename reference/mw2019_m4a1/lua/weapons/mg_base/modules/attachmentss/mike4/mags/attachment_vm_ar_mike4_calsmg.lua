ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "9mm Para 32-Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_calsmg.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/mike4/icon_attachment_ar_mike4_calsmg.vmt")
ATTACHMENT.Bodygroups ={
    ["ejection_cover"] = 1,
    ["tag_mag_show"] = 1
}

--Current mag
ATTACHMENT.BulletList = {
    [1] = {"j_b_017"},
    [2] = {"j_b_016"},
    [3] = {"j_b_014"},
    [4] = {"j_b_015"},
}


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 32
    weapon.Primary.RPM = 993
    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 0.8
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 0.8
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 0.8
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 0.8
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.85
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.85
    weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.85
    weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.85
    weapon.PrintName = "Colt 9mm SMG"

    weapon.Animations.Reload = weapon.Animations.Reload_Calsmg
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_Calsmg
    weapon:doCalConversionStats()
end