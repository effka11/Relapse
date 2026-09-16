ATTACHMENT.Base = "att_perk"
ATTACHMENT.Name = "Full Auto"
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/perks/perk_icon_hipaim.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Primary.RPM = 650
    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 0.65
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 0.65

    weapon.Firemodes[1] = {
        Name = "Automatic",
        OnSet = function(weapon)
            weapon.Primary.Automatic = true
            return "Firemode_Auto"
        end
    }
end