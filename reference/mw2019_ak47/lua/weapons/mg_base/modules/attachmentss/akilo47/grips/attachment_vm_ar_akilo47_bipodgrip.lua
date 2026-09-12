ATTACHMENT.Base = "att_vm_bipodgrip"
ATTACHMENT.BonemergeToCategory = {"Barrels"}
ATTACHMENT.AttachmentBodygroups ={
    ["handguard"] = 1
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
    weapon:SetGripPoseParameter("grip_vert_offset")
end