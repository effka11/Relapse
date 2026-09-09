ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "PP-Skelet"
ATTACHMENT.Model = Model("models/viper/mw/attachments/attachment_vm_pi_mike_stockl.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/mike/icon_attachment_pi_mike_stockl.vmt")


local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)

    weapon.Cone.TacStance = 0.2
    weapon.Zoom.IdleSway = weapon.Zoom.IdleSway * 0.8
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.9
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.9
    weapon.Animations.Sprint_Out.Fps = weapon.Animations.Sprint_Out.Fps * 0.9
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.85
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.85

    weapon.Animations.Equip = weapon.Animations.Equip_Stock
    weapon.ViewModelOffsets.Aim.Pos = weapon.ViewModelOffsets.Aim.Pos + Vector(-0.15, 0, 0)
    weapon.Zoom.Blur.EyeFocusDistance = 7
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
    weapon:SetViewModel("models/viper/mw/weapons/v_makarov_stock.mdl")
end