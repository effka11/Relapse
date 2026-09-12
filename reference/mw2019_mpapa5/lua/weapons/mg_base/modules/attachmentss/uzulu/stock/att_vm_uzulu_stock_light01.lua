ATTACHMENT.Base = "att_vm_stock_light01"
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Equip = weapon.Animations.Equip_No_Stock
end