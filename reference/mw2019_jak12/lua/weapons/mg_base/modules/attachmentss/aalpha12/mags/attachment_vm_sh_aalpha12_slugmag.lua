ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "12g Mags"
ATTACHMENT.Model = Model("models/viper/mw/attachments/aalpha12/attachment_vm_sh_aalpha12_slugmag.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/aalpha12/icon_attachment_sh_aalpha12_slugmag.vmt")
--Current mag
ATTACHMENT.BulletList = {
    [0] = {"j_ammoshell1"},
    [1] = {"j_ammoshell2"},
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    
    weapon.Shell = "mwb_shelleject_12g_green"
    
    if weapon:HasAttachment("att_ammo_flechette") then return end

    weapon.Bullet.NumBullets = 12
    weapon.Cone.Hip = weapon.Cone.Hip * 1.1
    weapon.Cone.Ads = weapon.Cone.Ads * 1.1
    weapon.Cone.TacStance = weapon.Cone.TacStance * 1.1
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
end 