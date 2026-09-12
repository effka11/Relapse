ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "10 Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_smag.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_smag.vmt")

ATTACHMENT.BulletList = {
    [1] = {"j_bullet01"},
    [2] = {"j_bullet02"},
    [3] = {"j_bullet03"},
}


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Reload = weapon.Animations.Reload_Smag
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_Smag
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.04
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.04
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 1.1
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 1.1
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 1.1
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 1.1
    weapon.Primary.ClipSize = 10
end