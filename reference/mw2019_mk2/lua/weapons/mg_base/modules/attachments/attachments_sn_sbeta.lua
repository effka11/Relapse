AddCSLuaFile()

MW_ATT_KEYS["attachment_vm_sh_sbeta_barrel"] = {
    Name = "Default",
    Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_barrel.mdl"),
}

MW_ATT_KEYS["attachment_vm_sn_sbeta_barlong"] = {
    Name = "FSS 24.0 Factory",
    Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_barlong.mdl"),
    Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_barlong.vmt"),
    Stats = function(self)
        self.Bullet.Damage[1] = self.Bullet.Damage[1] * 1.28
        self.Bullet.Damage[2] = self.Bullet.Damage[2] * 1.28
        self.Recoil.Vertical[1] = self.Recoil.Vertical[1] * 0.92
        self.Recoil.Vertical[2] = self.Recoil.Vertical[2] * 0.92
        self.Recoil.Horizontal[1] = self.Recoil.Horizontal[1] * 0.92
        self.Recoil.Horizontal[2] = self.Recoil.Horizontal[2] * 0.92
        self.Animations.Ads_In.Fps = self.Animations.Ads_In.Fps * 0.92
        self.Animations.Ads_Out.Fps = self.Animations.Ads_Out.Fps * 0.95
    end
}

MW_ATT_KEYS["attachment_vm_sn_sbeta_barmid"] = {
    Name = "FSS 20.0 Factory",
    Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_barmid.mdl"),
    Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_barmid.vmt"),
    Stats = function(self)
        self.Bullet.Damage[1] = self.Bullet.Damage[1] * 1.17
        self.Bullet.Damage[2] = self.Bullet.Damage[2] * 1.17
        self.Recoil.Vertical[1] = self.Recoil.Vertical[1] * 0.95
        self.Recoil.Vertical[2] = self.Recoil.Vertical[2] * 0.95
        self.Recoil.Horizontal[1] = self.Recoil.Horizontal[1] * 0.95
        self.Recoil.Horizontal[2] = self.Recoil.Horizontal[2] * 0.95
        self.Animations.Ads_In.Fps = self.Animations.Ads_In.Fps * 0.94
        self.Animations.Ads_Out.Fps = self.Animations.Ads_Out.Fps * 0.94
    end
}

MW_ATT_KEYS["attachment_vm_sn_sbeta_barshort"] = {
    Name = "FSS 18.0 Factory",
    Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_barshort.mdl"),
    Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_barshort.vmt"),
    Stats = function(self)
        self.Bullet.Damage[1] = self.Bullet.Damage[1] * 1.11
        self.Bullet.Damage[2] = self.Bullet.Damage[2] * 1.11
        self.Recoil.Vertical[1] = self.Recoil.Vertical[1] * 0.97
        self.Recoil.Vertical[2] = self.Recoil.Vertical[2] * 0.97
        self.Recoil.Horizontal[1] = self.Recoil.Horizontal[1] * 0.97
        self.Recoil.Horizontal[2] = self.Recoil.Horizontal[2] * 0.97
        self.Animations.Ads_In.Fps = self.Animations.Ads_In.Fps * 0.96
        self.Animations.Ads_Out.Fps = self.Animations.Ads_Out.Fps * 0.96
    end
}

MW_ATT_KEYS["attachment_vm_sn_sbeta_rack"] = {
    Name = "Cartridge Sleeve",
    Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_rack.mdl"),
    Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_rack.vmt"),
    Stats = function(self)
        self.Recoil.Vertical[1] = self.Recoil.Vertical[1] * 0.95
        self.Recoil.Vertical[2] = self.Recoil.Vertical[2] * 0.95
        self.Recoil.Horizontal[1] = self.Recoil.Horizontal[1] * 0.95
        self.Recoil.Horizontal[2] = self.Recoil.Horizontal[2] * 0.95
    end
}

MW_ATT_KEYS["attachment_vm_sn_sbeta_stock_light"] = {
    Name = "MK2 Ultralight Hollow",
    Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_stock_light.mdl"),
    Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_stock_light.vmt"),
    Stats = function(self)
        self.Animations.Ads_In.Fps = self.Animations.Ads_In.Fps * 1.25
        self.Animations.Ads_Out.Fps = self.Animations.Ads_Out.Fps * 1.25
    end
}

MW_ATT_KEYS["attachment_vm_sn_sbeta_stock_stable"] = {
    Name = "FSS MK2 Sport Comb",
    Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_stock_stable.mdl"),
    Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_stock_stable.vmt"),
    Stats = function(self)
        self.Animations.Ads_In.Fps = self.Animations.Ads_In.Fps * 1.12
        self.Animations.Ads_Out.Fps = self.Animations.Ads_Out.Fps * 1.12
        self.Recoil.Vertical[1] = self.Recoil.Vertical[1] * 0.94
        self.Recoil.Vertical[2] = self.Recoil.Vertical[2] * 0.94
        self.Recoil.Horizontal[1] = self.Recoil.Horizontal[1] * 0.93
        self.Recoil.Horizontal[2] = self.Recoil.Horizontal[2] * 0.93
    end
}

MW_ATT_KEYS["attachment_vm_sn_sbeta_stock_tactical"] = {
    Name = "FSS MK2 Precision Comb",
    Model = Model("models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_stock_tactical.mdl"),
    Icon = Material("viper/mw/attachments/icons/sbeta/icon_attachment_sn_sbeta_stock_tactical.vmt"),
    Stats = function(self)
        self.Animations.Ads_In.Fps = self.Animations.Ads_In.Fps * 0.95
        self.Animations.Ads_Out.Fps = self.Animations.Ads_Out.Fps * 0.95
        self.Recoil.Vertical[1] = self.Recoil.Vertical[1] * 0.9
        self.Recoil.Vertical[2] = self.Recoil.Vertical[2] * 0.9
        self.Recoil.Horizontal[1] = self.Recoil.Horizontal[1] * 0.9
        self.Recoil.Horizontal[2] = self.Recoil.Horizontal[2] * 0.9
    end
}