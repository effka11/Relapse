ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = ".45 Hollow Point 12-R Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_smags.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/smgolf45/icon_attachment_sm_smgolf45_smags.vmt")

ATTACHMENT.BulletList = {
    [0] = {"j_bullet1"},
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    weapon.Firemodes[1] = {
        Name = "2rnd Burst",
        OnSet = function(weapon)
            weapon.Primary.Automatic = false
            weapon.Primary.BurstRounds = 2
            weapon.Primary.BurstDelay = 0.067
            weapon.Primary.RPM = 513
            return "Firemode_Auto"
        end
    }

    weapon.Primary.ClipSize = 12
    weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.4
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.4
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.1
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.1

    weapon.Animations.Reload = weapon.Animations.Reload_Smag
    weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_Smag
end