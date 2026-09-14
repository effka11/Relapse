ATTACHMENT.Base = "att_perk_soh"
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Animations.Reload = weapon.Animations.Reload_Fast
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_Fast
    weapon.Animations.reload_drum = weapon.Animations.reload_drum_fast
    weapon.Animations.reload_empty_drum = weapon.Animations.reload_drum_empty_fast
    weapon.Animations.reload_xdrum = weapon.Animations.reload_xdrum_fast
    weapon.Animations.reload_empty_xdrum = weapon.Animations.reload_xdrum_empty_fast
end