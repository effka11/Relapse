ATTACHMENT.Base = "att_perk_soh"
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Reload = weapon.Animations.Reload_fast
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_empty_fast                
    weapon.Animations.Reload_saw = weapon.Animations.Reload_fast_saw
    weapon.Animations.Reload_Empty_saw = weapon.Animations.Reload_empty_fast_saw
end