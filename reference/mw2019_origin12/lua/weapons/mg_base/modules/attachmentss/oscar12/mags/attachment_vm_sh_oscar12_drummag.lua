ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "26 Round Drum Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_drummag.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/oscar12/icon_attachment_sh_oscar12_drummag.vmt")
ATTACHMENT.ExcludedAttachments = {"attachment_vm_sh_oscar12_none"}

--Current mag
ATTACHMENT.BulletList = {
    [1] = {"j_shell1"},
    [2] = {"j_shell2"},
    [3] = {"j_shell3"},
    [4] = {"j_shell4"},
    [5] = {"j_drumshell5"},
    [6] = {"j_drumshell6"},
    [7] = {"j_drumshell7"},
    [8] = {"j_drumshell8"},
    [9] = {"j_drumshell9"},
    [10] = {"j_drumshell10"},
    [11] = {"j_drumshell11"},
    [12] = {"j_drumshell12"},
    [13] = {"j_drumshell13"},
    [14] = {"j_drumshell14"},
    [15] = {"j_drumshell15"},
    [16] = {"j_drumshell16"},
    [17] = {"j_drumshell17"},
    [18] = {"j_drumshell18"},
    [19] = {"j_drumshell19"},
    [20] = {"j_drumshell20"},
    [21] = {"j_drumshell21"},
    [22] = {"j_drumshell22"},
    [23] = {"j_drumshell23"},
    [24] = {"j_drumshell24"},
    [25] = {"j_drumshell25"},
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 26

    weapon.Animations.Reload = weapon.Animations.reload_drum
    weapon.Animations.Reload_Empty = weapon.Animations.reload_empty_drum
    weapon.Animations.Equip = weapon.Animations.Equip_Drum

    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.9
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.9
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 0.85
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 0.85
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
end 