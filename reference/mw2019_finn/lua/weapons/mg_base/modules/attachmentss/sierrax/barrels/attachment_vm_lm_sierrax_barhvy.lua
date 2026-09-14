ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "TA Pro Twist"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sierrax/attachment_vm_lm_sierrax_barhvy.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sierrax/icon_attachment_lm_sierrax_barhvy.vmt")
ATTACHMENT.Bodygroups = {
    ["tag_barrel_hide"] = 1
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Recoil.DecreaseEveryShot = weapon.Recoil.DecreaseEveryShot * 1.22
    weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.85
    weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.85
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.91
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.91
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.89
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.89
end