ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "Singuard Arms Pro"
ATTACHMENT.Model = Model("models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_barmid.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/alpha50/icon_attachment_sn_alpha50_barmid.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.9
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.9
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.93
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.93
    --weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.1
    weapon.Projectile.Speed = weapon.Projectile.Speed * 1.15
    weapon.Cone.Hip = weapon.Cone.Hip * 0.9
end
