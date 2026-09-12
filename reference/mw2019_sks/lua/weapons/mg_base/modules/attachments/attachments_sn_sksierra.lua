AddCSLuaFile()

MW_ATT_KEYS["attachment_vm_sn_sksierra_barrel"] = {
    Name = "Default",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_barrel.mdl"),
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_barlong"] = {
    Name = "FSS 24.0 Factory",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_barlong.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_barlong.vmt"),
    Stats = function(self)
        weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.3
        weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.3
        weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.9
        weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.9
        weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.9
        weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.9
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.9
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.9
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_barhvy"] = {
    Name = "FSS 20.0 Factory",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_barhvy.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_barhvy.vmt"),
    Stats = function(self)
        weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.15
        weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.15
        weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.96
        weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.96
        weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.96
        weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.96
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.94
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.94
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_barshort"] = {
    Name = "FSS 20.0 Factory",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_barshort.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_barshort.vmt"),
    Stats = function(self)
        weapon.Bullet.Damage[1] = weapon.Bullet.Damage[1] * 1.15
        weapon.Bullet.Damage[2] = weapon.Bullet.Damage[2] * 1.15
        weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.96
        weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.96
        weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.96
        weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.96
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.94
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.94
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_stock"] = {
    Name = "Default",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_stock.mdl"),
    Stats = function(self)
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_stockhvy"] = {
    Name = "MK2 Ultralight Hollow",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_stockhvy.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_stockhvy.vmt"),
    Stats = function(self)
        weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.92
        weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.92
        weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.92
        weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.92
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.1
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.1
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_stockhvy2"] = {
    Name = "FSS MK2 Sport Comb",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_stockhvy2.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_stockhvy2.vmt"),
    Stats = function(self)
        weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.85
        weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.85
        weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.85
        weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.85
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.94
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.94
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_stockno"] = {
    Name = "FSS MK2 Precision Comb",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_stockno.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_stockno.vmt"),
    Stats = function(self)
        weapon.Animations.Melee = weapon.Animations.Melee_Nostock
        weapon.Animations.Melee_Hit = weapon.Animations.Melee_Hit_Nostock
        weapon.Recoil.Vertical[1] = weapon.Recoil.Vertical[1] * 0.95
        weapon.Recoil.Vertical[2] = weapon.Recoil.Vertical[2] * 0.95
        weapon.Recoil.Horizontal[1] = weapon.Recoil.Horizontal[1] * 0.95
        weapon.Recoil.Horizontal[2] = weapon.Recoil.Horizontal[2] * 0.95
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.25
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.25
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_mag"] = {
    Name = "FSS MK2 Sport Comb",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_mag.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_stocks.vmt"),
    Stats = function(self)
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.94
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.94
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_smag"] = {
    Name = "FSS MK2 Precision Comb",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_smag.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_smag.vmt"),
    Stats = function(self)
        weapon.Animations.Reload = weapon.Animations.Reload_Smag
        weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_Smag
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.25
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.25
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_xmag"] = {
    Name = "FSS MK2 Precision Comb",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_xmag.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_xmag.vmt"),
    Stats = function(self)
        weapon.Animations.Reload = weapon.Animations.Reload_Xmag
        weapon.Animations.Reload_Empty = weapon.Animations.Reload_Empty_Xmag
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 1.25
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 1.25
    end
}

MW_ATT_KEYS["attachment_vm_sn_sksierra_scope"] = {
    Name = "PSU Scope",
    Model = Model("models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_scope.mdl"),
    Icon = Material("viper/mw/attachments/icons/sksierra/icon_attachment_sn_sksierra_scope.vmt"),
    Optic = {
        LensHideMaterial = Material("viper/mw/weapons/sksierra/weapon_vm_sn_sksierra_scopeglass.vmt"),
        LensBodygroup = "lens",
        FOV = 7, 
        ParallaxSize = 750, --a value of zero means 1:1 size with the end of the optic
        Thermal = false
    },
    Reticle = {
        Material = Material("viper/mw/reticles/reticle_16.vmt"),
        Size = 1000,
        Color = Color(255, 255, 255, 255),
        Attachment = "reticle"
    },
    Stats = function(self)
        weapon.Bullet.EffectiveRange = weapon.Bullet.EffectiveRange * 1.5
        weapon.Animations.Ads_In.Fps = weapon.Animations.Ads_In.Fps * 0.92
        weapon.Animations.Ads_Out.Fps = weapon.Animations.Ads_Out.Fps * 0.92
        weapon.Zoom.ViewModelFovMultiplier = 0.95
        weapon.Zoom.FovMultiplier = 0.8
    end
}