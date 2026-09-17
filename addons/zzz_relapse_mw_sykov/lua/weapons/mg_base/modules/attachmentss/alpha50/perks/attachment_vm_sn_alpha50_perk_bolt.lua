ATTACHMENT.Base = "att_perk_bolt"

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Rechamber.Fps = weapon.Animations.Rechamber.Fps * 1.1
end