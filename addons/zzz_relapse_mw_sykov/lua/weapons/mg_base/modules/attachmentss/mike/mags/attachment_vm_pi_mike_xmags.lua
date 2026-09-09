ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "20 Round Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/attachment_vm_pi_mike_xmags.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/mike/icon_attachment_pi_mike_xmags.vmt")

--Current mag
ATTACHMENT.BulletList = {
    [0] = {"j_bullet1"},
    [1] = {"j_bullet2"},
    [2] = {"j_bullet3"},
    [3] = {"j_bullet4"},
    [4] = {"j_bullet5"},
    [5] = {"j_bullet6"},
    [6] = {"j_bullet7"},
    [7] = {"j_bullet8"},
    [8] = {"j_bullet9"},
    [9] = {"j_bullet10"},
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 20
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.95
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.95

    weapon.Animations.Reload = weapon.Animations.Reload_Xmag
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_Xmag
    weapon.Animations.Inspect = weapon.Animations.Inspect_Xmag
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.9
    weapon.Animations.Reload_Fast.Fps = weapon.Animations.Reload_Fast.Fps * 0.9
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.9
    weapon.Animations.Reload_Empty_Fast.Fps = weapon.Animations.Reload_Empty_Fast.Fps * 0.9
end