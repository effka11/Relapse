ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "FSS 24.0 Factory"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_barlong.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_barlong.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.05
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.05
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.9
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.9
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.89
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.89
end