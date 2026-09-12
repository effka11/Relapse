ATTACHMENT.Base = "att_grip"
ATTACHMENT.Name = "Kill The Clamp"
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
    weapon:SetGripPoseParameter("grip_killtheclamp_offset")

end 