ATTACHMENT.Base = "att_perk"
ATTACHMENT.Name = "Slamfire"
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/perks/perk_icon_slamfire.vmt")

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    -- weapon.Animations.Rechamber = weapon.Animations.rechamber_slam
    -- weapon.Animations.Fire = weapon.Animations.fire_slam
    -- weapon.Animations.Fire_Last = weapon.Animations.fire_last_slam
    weapon.Primary.RPM = 450
    weapon.Animations.Rechamber.Length = 0.3
    weapon.Cone.Hip = weapon.Cone.Hip * 1.85
    weapon.Cone.Ads = weapon.Cone.Ads * 1.85
    weapon.Cone.TacStance = weapon.Cone.TacStance * 1.85

    weapon.Firemodes[1].OnSet = function(weapon)
        weapon.Primary.Automatic = true
        return "Firemode_Semi"
    end
end