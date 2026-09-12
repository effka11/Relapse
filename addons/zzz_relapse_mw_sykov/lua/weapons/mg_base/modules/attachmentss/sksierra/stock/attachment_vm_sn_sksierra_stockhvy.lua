ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "FTAC Hunter-Scout"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_stockhvy.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_stockhvy.vmt")
-- ATTACHMENT.Bodygroups = {
--     ["tag_stock"] = 1
-- }
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
        weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.92
        weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.92
        weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.92
        weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.92
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.1
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.1
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
    -- weapon:SetGripPoseParameter("grip_ang_offset")
end 