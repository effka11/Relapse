ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "10mm Auto 30-Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/mpapa5/attachment_vm_sm_mpapa5_mag_xmag2.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/mpapa5/icon_attachment_sm_mpapa5_mag_xmag2.vmt")


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon:doCalConversionStats()

    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.15
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.15
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 1.1
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 1.1
    weapon.Primary.RPM = weapon.Primary.RPM * 0.9
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 1.2
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 1.2
    weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 1.2
    weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 1.2
end