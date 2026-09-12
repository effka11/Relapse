ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "SPP 10-R Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/valpha/attachment_vm_ar_valpha_smags.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/valpha/icon_attachment_ar_valpha_smags.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.ClipSize = 10
    weapon.Primary.RPM = 451

    weapon.Firemodes[1].Name = "Semi Auto"
    weapon.Firemodes[1].OnSet = function(weapon)
        weapon.Primary.Automatic = false
        return "Firemode_Semi"
    end

    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.3
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.3
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.1
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.1

    weapon.Animations.Reload = weapon.Animations.reload_smag
    weapon.Animations.Reload_Empty = weapon.Animations.reload_empty_smag
    weapon.Animations.Inspect = weapon.Animations.inspect_smag
    weapon.Animations.Reload.Fps = weapon.Animations.Reload.Fps * 1.15
    weapon.Animations.Reload_Fast.Fps = weapon.Animations.Reload_Fast.Fps * 1.15
    weapon.Animations.Reload_Empty.Fps = weapon.Animations.Reload_Empty.Fps * 1.15
    weapon.Animations.Reload_Empty_Fast.Fps = weapon.Animations.Reload_Empty_Fast.Fps * 1.15
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
    weapon.Firemodes[2] = nil
    weapon:SetGripPoseParameter("grip_magwell_offset")
end