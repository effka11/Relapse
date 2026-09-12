ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "FORGE TAC Wideshot"
ATTACHMENT.Model = Model("models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_barrelmid.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/oscar12/icon_attachment_sh_oscar12_barrelmid.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.85
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.85
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.85
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.85
    weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 1.1
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
end 