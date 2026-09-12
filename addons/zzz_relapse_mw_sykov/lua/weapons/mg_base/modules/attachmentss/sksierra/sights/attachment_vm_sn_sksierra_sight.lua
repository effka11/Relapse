ATTACHMENT.Base = "att_sight"

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.ViewModelOffsets.Aim.Pos.y = 8
end