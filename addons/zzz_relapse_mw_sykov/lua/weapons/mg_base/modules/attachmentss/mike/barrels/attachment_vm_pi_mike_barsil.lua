ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "SSL 308mm"
ATTACHMENT.Model = Model("models/viper/mw/attachments/attachment_vm_pi_mike_barsil.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/mike/icon_attachment_pi_mike_barsil.vmt")
ATTACHMENT.ExcludedCategories = {"Muzzle Devices"}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 1.15
    weapon.Bullet.DropOffStartRange = weapon.Bullet.DropOffStartRange * 1.15
    weapon.Cone.Hip = weapon.Cone.Hip * 0.9
    if weapon.Cone.TacStance then
        weapon.Cone.TacStance = weapon.Cone.TacStance * 0.9
    end
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.9
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.9
    weapon:doSuppressorStats()
end