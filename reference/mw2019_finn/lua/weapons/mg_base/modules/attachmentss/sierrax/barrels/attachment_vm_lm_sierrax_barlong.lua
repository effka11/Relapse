ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "TA LongShot Advantage"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sierrax/attachment_vm_lm_sierrax_barlong.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sierrax/icon_attachment_lm_sierrax_barlong.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 1.15
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 1.15
    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.06
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.87
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.87
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.84
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.84
end
