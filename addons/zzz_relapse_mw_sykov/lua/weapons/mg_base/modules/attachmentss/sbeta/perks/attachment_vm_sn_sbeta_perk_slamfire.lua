ATTACHMENT.Base = "att_perk"
ATTACHMENT.Name = "Slamfire"
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/perks/perk_icon_slamfire.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    -- weapon.Animations.Rechamber = weapon.Animations.rechamber_slam
    -- weapon.Animations.Fire = weapon.Animations.fire_slam
    -- weapon.Animations.Fire_Last = weapon.Animations.fire_last_slam
    weapon.Primary.RPM = 750
    weapon.Animations.Rechamber.Length = 0.13
    weapon.Cone.Hip = 1.5 
    weapon.Cone.Max = 7.5 
    weapon.Primary.Automatic = true 
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1]*1.5 
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2]*1.5 
    weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1]*1.5 
    weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2]*1.5 
end