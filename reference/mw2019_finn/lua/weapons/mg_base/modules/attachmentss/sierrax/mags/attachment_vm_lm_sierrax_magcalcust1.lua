ATTACHMENT.Base = "att_magazine"
ATTACHMENT.Name = "5.56 CT 75-Round Belts"
ATTACHMENT.Model = Model("models/viper/mw/attachments/sierrax/attachment_vm_lm_sierrax_magcalcust1.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/sierrax/icon_attachment_lm_sierrax_magcalcust1.vmt")

--round, bone name
--im aware its the other way around but the reloads switch mags


--Current mag
ATTACHMENT.BulletList = {
    [10] = {"j_bullet011"},
    [9] = {"j_bullet010"},
    [8] = {"j_bullet09"},
    [7] = {"j_bullet08"},
    [6] = {"j_bullet07"},
    [5] = {"j_bullet06"},
    [4] = {"j_bullet05"},
    [3] = {"j_bullet04"},
    [2] = {"j_bullet03"},
    [1] = {"j_bullet02"},
    [0] = {"j_bullet01"},
}

local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)

function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)

    weapon.Primary.RPM = 995
    weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 0.75
end