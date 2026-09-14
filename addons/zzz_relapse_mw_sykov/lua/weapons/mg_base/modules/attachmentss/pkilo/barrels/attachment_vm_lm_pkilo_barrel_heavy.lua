ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "25.9\" Heavy Barrel"
ATTACHMENT.Model = Model("models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_barrel_heavy.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/pkilo/icon_attachment_lm_pkilo_barrel_heavy.vmt")
ATTACHMENT.Bodygroups = {
    ["tag_barrel_hide"] = 1
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.85
    weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.85
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.85
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.85
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.92
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.92
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.86
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.86
end