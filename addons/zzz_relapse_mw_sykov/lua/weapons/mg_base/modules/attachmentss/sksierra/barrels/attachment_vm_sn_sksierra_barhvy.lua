ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "22\" FSS M59/66"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_barhvy.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_barhvy.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 1.08
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 1.08
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.9
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.9
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.89
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.89
end