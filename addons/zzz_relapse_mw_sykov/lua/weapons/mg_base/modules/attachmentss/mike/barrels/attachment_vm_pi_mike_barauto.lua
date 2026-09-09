ATTACHMENT.Base = "att_barrel"
ATTACHMENT.Name = "Sorokin 140mm Auto"
ATTACHMENT.Model = Model("models/viper/mw/attachments/attachment_vm_pi_mike_barauto.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/mike/icon_attachment_pi_mike_barauto.vmt")
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)

    weapon.Primary.RPM = 882
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 2
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 2
    weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 2
    weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 2
    weapon.Cone.Hip = weapon.Cone.Hip * 1.2
    weapon.PrintName = "Sorokin"

    weapon.Firemodes[1] = {
        Name = "Full Auto",
        OnSet = function(weapon)
            weapon.Primary.Automatic = true
            return "Firemode_Semi"
        end
    }
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
    weapon.Cone.Increase = weapon.Cone.Increase * 0.6
end