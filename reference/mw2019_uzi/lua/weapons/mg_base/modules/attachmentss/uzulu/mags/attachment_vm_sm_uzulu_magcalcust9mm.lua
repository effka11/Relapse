ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "9x19mm 32-Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/uzulu/attachment_vm_sm_uzulu_mag.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/uzulu/icon_attachment_sm_uzulu_mag.vmt")


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
        weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 0.8
        weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 0.8
        weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 0.85
        weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 0.85
        weapon.Primary.RPM = weapon.Primary.RPM*1.6
        weapon.Primary.ClipSize = 32
        weapon:doCalConversionStats()
end