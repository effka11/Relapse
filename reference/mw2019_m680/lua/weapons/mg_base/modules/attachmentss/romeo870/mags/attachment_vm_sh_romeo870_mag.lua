ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "6-R Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_mag.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/romeo870/icon_attachment_sh_romeo870_mag.vmt")
ATTACHMENT.ExcludedCategories = {"Barrels"}
ATTACHMENT.Bodygroups = {
    ["tag_mag_attach"] = 1
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 6

    weapon.Cone.Hip = weapon.Cone.Hip * 0.9
    weapon.Cone.Ads = weapon.Cone.Ads * 0.9
    weapon.Cone.TacStance = weapon.Cone.TacStance * 0.9
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.05
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.05

    weapon.DisableCantedReload = false
    weapon.EmptyReloadRechambers = true
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
    weapon.Animations.Reload_Start = nil
    weapon.Animations.Reload_Loop = nil
    weapon.Animations.Reload_End = nil
    weapon.Animations.Reload_EndEmpty = nil
end 