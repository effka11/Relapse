ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "TA VC-8 Harrier"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sierrax/attachment_vm_lm_sierrax_barlight.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sierrax/icon_attachment_lm_sierrax_barlight.vmt")


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 0.95
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 0.95
    weapon.Cone.Hip = weapon.Cone.Hip * 1.2
    weapon.Cone.MinDecreaseEveryShot = weapon.Cone.MinDecreaseEveryShot * 2
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.08
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.08
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 1.11
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 1.11
end