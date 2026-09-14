ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "26.9\" Extended Barrel"
ATTACHMENT.Model = Model("models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_barrel_long.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/pkilo/icon_attachment_lm_pkilo_barrel_long.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Cone.Hip = weapon.Cone.Hip * 0.85
    weapon.Cone.MinDecreaseEveryShot = weapon.Cone.MinDecreaseEveryShot * 0.9
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 1.09
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 1.09
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.92
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.92
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.86
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.86
end