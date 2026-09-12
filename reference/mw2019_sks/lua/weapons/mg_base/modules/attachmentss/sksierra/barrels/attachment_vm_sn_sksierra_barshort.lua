ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "16\" FSS Para"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_barshort.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_barshort.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Recoil.AdsMultiplier = weapon.Recoil.AdsMultiplier * 1.15
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.05
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.05
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 1.05
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 1.05
end