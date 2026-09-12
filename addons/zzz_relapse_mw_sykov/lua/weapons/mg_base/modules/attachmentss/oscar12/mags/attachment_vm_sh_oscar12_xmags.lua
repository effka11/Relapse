ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "12 Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_xmags.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/oscar12/icon_attachment_sh_oscar12_xmags.vmt")
ATTACHMENT.BulletList = {
    [1] = {"j_shell01"},
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 12

    weapon.Animations.Reload = weapon.Animations.Reload_Xmag
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_Xmag
    weapon.Animations.Equip = weapon.Animations.Equip_Drum

    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.95
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.95
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.9
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.9
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
end 