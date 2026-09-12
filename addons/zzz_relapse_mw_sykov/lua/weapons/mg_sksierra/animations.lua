AddCSLuaFile()

SWEP.Animations = {
    ["Idle"] = {--idle is a special animation index, movement animations are played when this is on
        Sequences = {"idle"},
        Fps = 30,
        Events = {
        {Time = 0, Callback = function(self) self:EnableGrip() end},
        {Time = 0, Callback = function(self) self:EnableGrip2() end},
    }
        --does not need NextSequence to loop, it's an exception to the rule
    },

    ["Draw"] = {
        Sequences = {"draw"},
        Length = 0.85,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.067, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_raise")) end},
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Holster"] = {
        Sequences = {"holster"},
        Length = 0.8,
        Fps = 30,
        Events = {
            {Time = 0.067, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_drop")) end},
        }
    },

    ["Equip"] = {
        Sequences = {"draw_First"},
        Length = 1.25,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.033, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_raise_first_01")) end},
            {Time = 0.867, Callback = function(self) self:EnableGrip2() end},
            {Time = 0, Callback = function(self) self:DisableGrip2() end},
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0.433, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_raise_first_02")) end},
            {Time = 0.8, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_raise_first_03")) end},
        }
    },

    ["Reload"] = {
        Sequences = {"reload"},
        Length = 2.66,
        MagLength = 1.6,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.633, Callback = function(self)  end},
            {Time = 1.633, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_04")) end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_01")) end},
            {Time = 0.567, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_02")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_03")) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 2.267, Callback = function(self) self:EnableGrip() end},
            {Time = 1.533, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_035")) end},
        
        }
    },

    ["Reload_Fast"] = {
        Sequences = {"reload_fast"},
        Length = 1.83,
        MagLength = 1.23,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.AK.Metal"), Vector(-10, 0, 40)) end},
            {Time = 1.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_03")) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 1.533, Callback = function(self) self:EnableGrip() end},
            {Time = 1.433, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_04")) end},
            {Time = 1.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_035")) end},
            {Time = 0.033, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_01")) end},
            {Time = 0.567, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_02")) end},
        
        }
    },

    ["Reload_Xmag"] = {
        Sequences = {"Reload_Xmag"},
        Length = 2.66,
        MagLength = 1.6,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.1, Callback = function(self)  end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 1.533, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_xmag_035")) end},
            {Time = 2.133, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_xmag_04")) end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_xmag_01")) end},
            {Time = 2.367, Callback = function(self) self:EnableGrip() end},
            {Time = 1.067, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_xmag_03")) end},
            {Time = 0.7, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_xmag_02")) end},
        
        }
    },

    ["Reload_Xmag_Fast"] = {
        Sequences = {"Reload_Xmag_Fast"},
        Length = 1.83,
        MagLength = 1.23,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.AK.Metal"), Vector(-10, 0, 40)) end},
            {Time = 1.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_xmag_035")) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 1.533, Callback = function(self) self:EnableGrip() end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_xmag_01")) end},
            {Time = 1.067, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_xmag_03")) end},
            {Time = 0.533, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_xmag_02")) end},
            {Time = 1.567, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_xmag_04")) end},
        
        }
    },

    ["Reload_Smag"] = {
        Sequences = {"Reload_Smag"},
        Length = 2.15,
        MagLength = 1.6,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.3, Callback = function(self) end},
            {Time = 0.3, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_smag_02")) end},
            {Time = 1.167, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_smag_03")) end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_smag_01")) end},
            {Time = 1.833, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_smag_04")) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 1.733, Callback = function(self) self:EnableGrip() end},
            {Time = 1.5, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_smag_035")) end},
        
        }
    },

    ["Reload_Smag_Fast"] = {
        Sequences = {"Reload_Smag_Fast"},
        Length = 1.55,
        MagLength = 1,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.25, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.SMG.Metal"), Vector(-10, 0, 40)) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 1.033, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_smag_035")) end},
            {Time = 1.333, Callback = function(self) self:EnableGrip() end},
            {Time = 0.433, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_smag_02")) end},
            {Time = 0.833, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_smag_03")) end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_smag_01")) end},
            {Time = 1.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_fast_smag_04")) end},
        
        }
    },

    ["Reload_Empty"] = {
        Sequences = {"Reload_Empty"},
        Length = 2.93,
        MagLength = 1.4,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.AK.Metal"), Vector(-10, 0, 40)) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_01")) end},
            {Time = 0.7, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_02")) end},
            {Time = 1.167, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_03")) end},
            {Time = 1.7, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_04")) end},
            {Time = 2.633, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_06")) end},
            {Time = 1.767, Callback = function(self) self:DisableGrip2() end},
            {Time = 1.667, Callback = function(self) self:EnableGrip() end},
            {Time = 1.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_035")) end},
            {Time = 2.5, Callback = function(self) self:EnableGrip2() end},
            {Time = 2.233, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_05")) end},
        }
    },

    ["Reload_Empty_Fast"] = {
        Sequences = {"Reload_Empty_Fast"},
        Length = 2.2,
        MagLength = 1.23,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.AK.Metal"), Vector(-10, 0, 40)) end},
            {Time = 0, Callback = function(self) end},
            {Time = 0, Callback = function(self) end},
            {Time = 1.367, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_04")) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 0.033, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_01")) end},
            {Time = 0.467, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_02")) end},
            {Time = 1.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_03")) end},
            {Time = 1.967, Callback = function(self) self:EnableGrip() end},
            {Time = 1.5, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_05")) end},
            {Time = 2.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_06")) end},
            {Time = 1.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_035")) end},
        }
    },

    ["Reload_Empty_Xmag"] = {
        Sequences = {"Reload_Empty_Xmag"},
        Length = 2.93,
        MagLength = 1.4,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.AK.Metal"), Vector(-10, 0, 40)) end},
            {Time = 1.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_xmag_035")) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 2.5, Callback = function(self) self:EnableGrip2() end},
            {Time = 1.6, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_xmag_04")) end},
            {Time = 1.767, Callback = function(self) self:DisableGrip2() end},
            {Time = 1.667, Callback = function(self) self:EnableGrip() end},
            {Time = 2.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_xmag_05")) end},
            {Time = 2.767, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_xmag_06")) end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_xmag_01")) end},
            {Time = 1.233, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_xmag_03")) end},
            {Time = 0.8, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_xmag_02")) end},
        }
    },

    ["Reload_Empty_Xmag_Fast"] = {
        Sequences = {"Reload_Empty_Xmag_Fast"},
        Length = 2.2,
        MagLength = 1.23,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.AK.Metal"), Vector(-10, 0, 40)) end},
            {Time = 0, Callback = function(self) end},
            {Time = 0, Callback = function(self) end},
            {Time = 0.1, Callback = function(self) self:DisableGrip() end},
            {Time = 1.933, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_xmag_06")) end},
            {Time = 2.033, Callback = function(self) self:EnableGrip() end},
            {Time = 1.633, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_xmag_05")) end},
            {Time = 1.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_xmag_04")) end},
            {Time = 0.033, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_xmag_01")) end},
            {Time = 0.967, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_xmag_03")) end},
            {Time = 0.467, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_xmag_02")) end},
            {Time = 1.167, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_xmag_035")) end},
        }
    },

    ["Reload_Empty_Smag"] = {
        Sequences = {"Reload_Empty_Smag"},
        Length = 2.93,
        MagLength = 1.4,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.SMG.Metal"), Vector(-10, 0, 40)) end},
            {Time = 0.0, Callback = function(self) self:DisableGrip() end},
            {Time = 2.5, Callback = function(self) self:EnableGrip2() end},
            {Time = 1.767, Callback = function(self) self:DisableGrip2() end},
            {Time = 0.7, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_smag_02")) end},
            {Time = 1.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_smag_03")) end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_smag_01")) end},
            {Time = 2.567, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_smag_06")) end},
            {Time = 1.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_smag_04")) end},
            {Time = 2.067, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_smag_05")) end},
            {Time = 1.667, Callback = function(self) self:EnableGrip() end},
            {Time = 1.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_smag_035")) end},
        }
    },

    ["Reload_Empty_Smag_Fast"] = {
        Sequences = {"Reload_Empty_Smag_Fast"},
        Length = 2.2,
        MagLength = 1.23,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSpatialSound(Sound("MW_MagazineDrop.SMG.Metal"), Vector(-10, 0, 40)) end},
            {Time = 0, Callback = function(self) end},
            {Time = 0, Callback = function(self) end},
            {Time = 0, Callback = function(self) end},
            {Time = 0.567, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_smag_02")) end},
            {Time = 0.0, Callback = function(self) self:DisableGrip() end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_smag_01")) end},
            {Time = 1.433, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_smag_04")) end},
            {Time = 1.833, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_smag_05")) end},
            {Time = 1.967, Callback = function(self) self:EnableGrip() end},
            {Time = 1.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_smag_035")) end},
            {Time = 1.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_reload_empty_fast_smag_03")) end},
        }
    },


    ["Fire"] = {
        Sequences = {"fire"},
        Fps = 60,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0, 
                Callback = function(self) 
                    self:DoParticle("MuzzleFlash", "muzzle")
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
        }
    },

    ["Fire_Last"] = {
        Sequences = {"fire_last"},
        Fps = 60,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0, 
                Callback = function(self) 
                    self:DoParticle("MuzzleFlash", "muzzle")
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.sksierra.fire.last")) end},
        }
    },

    ["Ads_In"] = {
        Sequences = {"ads_in"},
        Length = 0.25,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}, 
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.sksierra.ads.up")) end},
        }
    },

    ["Ads_Out"] = {
        Sequences = {"ads_out"},
        Length = 0.25,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}, 
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.sksierra.ads.down")) end},
        }
    },

    ["Sprint_In"] = {
        Sequences = {"sprint_in"},
        Fps = 30,
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
        }
        --NextSequence = "Sprint_Loop",
    },

    ["Sprint_Loop"] = {
        Sequences = {"sprint_loop"},
        Fps = 30,
        NextSequence = "Sprint_Loop", --make our state loop
        --while sprinting, the playback rate of the viewmodel is scaled with velocity (cod-like behaviour)
        Events = {
        {Time = 0, Callback = function(self) self:EnableGrip() end},
        {Time = 0, Callback = function(self) self:EnableGrip2() end},
        }
    },

    ["Sprint_Out"] = {
        Sequences = {"sprint_out"},
        Length = 0.3,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
        }
    },

    ["Inspect"] = {
        Sequences = {"inspect"},
        Length = 5,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.133, Callback = function(self) self:DisableGrip() end},
            {Time = 4.3, Callback = function(self) self:EnableGrip() end},
            {Time = 4.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_inspect_04")) end},
            {Time = 0.033, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_inspect_01")) end},
            {Time = 1.367, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_inspect_02")) end},
            {Time = 2.367, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sksierra_inspect_03")) end},
        }
    },

    ["Jog_Out"] = {
        Sequences = {"jog_out"},
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
        }
    },

    ["Jump"] = {
        Sequences = {"jump"},
        Fps = 15,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
        }
    },

    ["Land"] = {
        Sequences = {"jump_land"},
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
        }
    },

    ["HybridOn"] = {
        Sequences = {"hybrid_toggle_off"},
        Fps = 30,
        Length = 0.9,
        NextSequence = "Idle",
        Events = {
            {Time = 0.15, Callback = function(self) self:DoSound(Sound("Flipsight.Up")) end},	
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:DisableGrip2() end},
            {Time = 0.833, Callback = function(self) self:EnableGrip2() end},
        }
    },

    ["HybridOff"] = {
        Sequences = {"hybrid_toggle_on"},
        Fps = 30,
        Length = 0.9,
        NextSequence = "Idle",
        Events = {
            {Time = 0.1, Callback = function(self) self:DoSound(Sound("Flipsight.Down")) end},
            {Time = 0, Callback = function(self) self:DisableGrip() end},
            {Time = 0.767, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Melee"] = {
        Sequences = {"melee_miss_01", "melee_miss_02",},
        Length = 0.6, --if melee misses

        Size = 15,
        Range = 40,

        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:DisableGrip() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("MW_Melee.Miss_Medium")) end},
            {Time = 0.8, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Melee_Hit"] = {
        Sequences = {"melee_hit_01", "melee_hit_02"},
        Length = 0.3, --if melee hits

        Damage = 45,

        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:DisableGrip() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("MW_Melee.Flesh_Medium")) end},
            {Time = 0.8, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Melee_Nostock"] = {
        Sequences = {"melee_miss_01_nostock", "melee_miss_02_nostock",},
        Length = 0.6, --if melee misses

        Size = 15,
        Range = 40,

        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:DisableGrip() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("MW_Melee.Miss_Medium")) end},
            {Time = 0.8, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Melee_Hit_Nostock"] = {
        Sequences = {"melee_hit_01_nostock", "melee_hit_02_nostock"},
        Length = 0.3, --if melee hits

        Damage = 45,

        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:DisableGrip() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("MW_Melee.Flesh_Medium")) end},
            {Time = 0.8, Callback = function(self) self:EnableGrip() end},
        }
    },
        
    ["Super_Sprint_In"] = {
        Sequences = {"super_sprint_in"},
        Fps = 30,
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
        --NextSequence = "Sprint_Loop",
    },

    ["Super_Sprint_Loop"] = {
        Sequences = {"super_sprint_loop"},
        Fps = 30,
        NextSequence = "Sprint_Loop", --make our state loop
        --while sprinting, the playback rate of the viewmodel is scaled with velocity (cod-like behaviour)
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Super_Sprint_Out"] = {
        Sequences = {"super_sprint_out"},
        Length = 0.3,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },
}