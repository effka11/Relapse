ATTACHMENT.Base = "att_stock"
ATTACHMENT.Name = "FSS Raider Stock"
ATTACHMENT.Model = Model("models/viper/mw/attachments/attachment_vm_pi_cpapa_stockl.mdl")
ATTACHMENT.Icon = Material("viper/mw/attachments/icons/cpapa/icon_attachment_pi_cpapa_stockl.vmt")
ATTACHMENT.Bodygroups = {
    ["pgrip"] = 1
}
ATTACHMENT.AttachmentBodygroups = {
    ["pgrip"] = 1
}
local BaseClass = GetAttachmentBaseClass(ATTACHMENT.Base)
function ATTACHMENT:Stats(weapon)
    BaseClass.Stats(self, weapon)

    weapon.Cone.TacStance = 0.2
    weapon.Zoom.IdleSway = weapon.Zoom.IdleSway * 0.75
    weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.85
    weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.85
    weapon.Animations.Sprint_Out.Fps = weapon.Animations.Sprint_Out.Fps * 0.85
    weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.8
    weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.8
    
    weapon.ViewModelOffsets.Aim.Pos = weapon.ViewModelOffsets.Aim.Pos + Vector(0.15, 0, 0)
end

function ATTACHMENT:PostProcess(weapon)
    BaseClass.PostProcess(self, weapon)
        
    weapon:SetViewModel("models/viper/mw/weapons/v_357_stock.mdl")
end