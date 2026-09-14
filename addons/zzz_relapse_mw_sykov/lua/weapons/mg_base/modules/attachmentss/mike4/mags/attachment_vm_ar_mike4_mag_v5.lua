ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = ".458 SOCOM 10-Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_mag_v5.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/mike4/icon_attachment_ar_mike4_mag_v5.vmt")

--Current mag
ATTACHMENT.BulletList = {
    [1] = {"j_b_016"},
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 10
    weapon.Primary.RPM = 591
    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.5
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.5
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 1.15
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 1.15
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 2
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 2
    weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 1.5
    weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 1.5

    weapon:doSocomConversionStats()
end