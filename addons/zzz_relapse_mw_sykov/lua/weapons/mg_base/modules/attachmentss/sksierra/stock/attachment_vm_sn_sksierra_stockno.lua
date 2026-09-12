ATTACHMENT.Base = "att_vm_stock_no"
ATTACHMENT.Name = "Sawed-off Stock"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_stockno.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_stockno.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
    weapon:SetGripPoseParameter2("grip_stockhvy_offset")
end 