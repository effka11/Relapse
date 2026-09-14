ATTACHMENT.Base = "att_vm_angledgrip02"
ATTACHMENT.AttachmentBodygroups = {
    ["tag_grip_hide"] = 1
}

ATTACHMENT.BonemergeToCategory = {"Barrels"}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)

    if (weapon.AlternateGrips) then
        weapon:SetGripPoseParameter("grip_barshort_gripang_offset") 
    else
        weapon:SetGripPoseParameter("grip_gripang_offset")
    end
end