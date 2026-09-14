ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "TA ChainSAW"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sierrax/attachment_vm_lm_sierrax_stocksaw.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sierrax/icon_attachment_lm_sierrax_stocksaw.mdl")
ATTACHMENT.Bodygroups = {
    ["pgrip"] = 1
}
ATTACHMENT.ExcludedCategories = {
    "Sights",
    "Grips"
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)

    weapon.Recoil.DecreaseEveryShot = weapon.Recoil.DecreaseEveryShot * 2
    weapon.Cone.Hip = weapon.Cone.Hip * 0.75
    weapon.Cone.DecreaseEveryShot = weapon.Cone.DecreaseEveryShot * 2
    weapon.Animations.Draw.Fps = weapon.Animations.Draw.Fps * 0.8
    weapon.Animations.Holster.Fps = weapon.Animations.Holster.Fps * 0.8

    weapon.ViewModelOffsets.Idle.Angles = Angle(0, 0, -7)
    weapon.ViewModelOffsets.Idle.Pos = Vector(0, -3, -4)
    weapon.HoldType = "Saw"

    weapon.WorldModelOffsets.Pos = Vector(9,-2, 0)
    weapon.WorldModelOffsets.Angles = Angle(10, -20, -180)
end