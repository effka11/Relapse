ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Model = Model("models/viper/mw/attachments/aalpha12/attachment_vm_sh_aalpha12_mag.mdl")

--Current mag
ATTACHMENT.BulletList = {
    [0] = {"j_ammoshell1"},
    [1] = {"j_ammoshell2"},
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)
    
    if weapon:HasAttachment("att_ammo_he") then
        weapon.Primary.RPM = 290
    end
end