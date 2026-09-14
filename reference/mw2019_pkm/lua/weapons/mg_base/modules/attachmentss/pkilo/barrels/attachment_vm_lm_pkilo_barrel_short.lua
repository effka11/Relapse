ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "18.2\" Compact Barrel"
ATTACHMENT.Model = Model("models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_barrel_short.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/pkilo/icon_attachment_lm_pkilo_barrel_short.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Cone.Hip = weapon.Cone.Hip * 1.18
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 0.94
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 0.94
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.08
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.08
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 1.12
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 1.12
end