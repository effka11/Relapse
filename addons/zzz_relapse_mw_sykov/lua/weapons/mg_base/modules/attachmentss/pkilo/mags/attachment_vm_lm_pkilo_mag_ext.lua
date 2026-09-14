ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "150 Round Belt"
ATTACHMENT.Model = Model("models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_mag_ext.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/pkilo/icon_attachment_lm_pkilo_mag.vmt")

--Current mag
ATTACHMENT.BulletList = {
    [0] = {"j_b_08"},
    [1] = {"j_b_07"},
    [2] = {"j_b_06"},
    [3] = {"j_b_05"},
    [4] = {"j_b_04"},
    [5] = {"j_b_03"},
    [6] = {"j_b_02"},
    [7] = {"j_b_01"},
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 150
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.92
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.92
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.9
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.9
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.9
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.9
end