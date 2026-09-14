ATTACHMENT.Base = "att_vm_laser03_cylinder"
ATTACHMENT.Bodygroups ={
    ["laser"] = 1
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.LaserAimAngles = Angle(-0.3, 0.05, -15)
    weapon.LaserAimPos = Vector(-1, 5, -2)
end 