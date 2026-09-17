AddCSLuaFile()

SWEP.Animations = {
    ["Idle"] = {--idle is a special animation index, movement animations are played when this is on
        Sequences = {"idle"},
        Fps = 30,
        Events = {
        {Time = 0, Callback = function(self) self:EnableGrip() end},
    }
        --does not need NextSequence to loop, it's an exception to the rule
    },

    ["Draw"] = {
        Sequences = {"draw"},
        Length = 0.85,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.033, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_raise_01")) end},
            {Time = 0.7, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_raise_02")) end},
        }
    },

    ["Holster"] = {
        Sequences = {"holster"},
        Length = 0.7,
        Fps = 30,
        Events = {
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_drop_01")) end},
            {Time = 0.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_drop_02")) end},
        }
    },

    ["Equip"] = {
        Sequences = {"draw_First"},
        Length = 1.25,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.9, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_raise_first_04")) end},
            {Time = 0.8, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_raise_first_03")) end},
            {Time = 0.467, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_raise_first_02")) end},
            {Time = 0.067, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_raise_first_01")) end},
        }
    },

    ["Reload_Start"] = {
        Sequences = {"reload_start"},
        Length = 0.7,
        Fps = 30,
        MagLength = 0.7,
        NextSequence = "Idle",
        Events = {
            {Time = 0.667, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_start_03")) end},
            {Time = 0.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_start_02")) end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_start_01")) end},
        
        }
    },

    ["Reload_Loop"] = {
        Sequences = {"reload_loop"},
        Length = 0.5,
        Fps = 30,
        MagLength = 0.35,
        NextSequence = "Idle",
        Events = {
            {Time = 0.467, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_loop_02")) end},
            {Time = 0.067, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_loop_01")) end},    
        }
    },

    ["Reload_End"] = {
        Sequences = {"reload_end"},
        Length = 0.55,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_end_01")) end},
            {Time = 0.267, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_end_02")) end},
        }
    },

    ["Reload_End_Empty"] = {
        Sequences = {"reload_end_empty"},
        Length = 0.75,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.35, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                    self:DoParticle("Ejection", "shell_eject")
                end
            },
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_end_01_empty")) end},
            {Time = 0.267, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_end_02_empty")) end},
            {Time = 0.633, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_reload_end_04_empty")) end},    
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
                end
            },
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Rechamber"] = {
        Sequences = {"rechamber"},
        Length = 0.5,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.1, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                    self:DoParticle("Ejection", "shell_eject")
                end
            },
            {Time = 0.033, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_rechamber_02")) end},
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
                end
            },
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Ads_In"] = {
        Sequences = {"ads_in"},
        Length = 0.25,
        Fps = 35,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}, 
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.sbeta.ads.up")) end},
        }
    },

    ["Ads_Out"] = {
        Sequences = {"ads_out"},
        Length = 0.25,
        Fps = 35,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}, 
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.sbeta.ads.down")) end},
        }
    },

    ["Sprint_In"] = {
        Sequences = {"sprint_in"},
        Fps = 30,
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
        --NextSequence = "Sprint_Loop",
    },

    ["Sprint_Loop"] = {
        Sequences = {"sprint_loop"},
        Fps = 34,
        NextSequence = "Sprint_Loop", --make our state loop
        --while sprinting, the playback rate of the viewmodel is scaled with velocity (cod-like behaviour)
        Events = {
        {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Sprint_Out"] = {
        Sequences = {"sprint_out"},
        Length = 0.3,
        Fps = 34,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Inspect"] = {
        Sequences = {"inspect"},
        Length = 5,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_inspect_02")) end},
            {Time = 0.0, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_inspect_01")) end},
            {Time = 4.2, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_inspect_04")) end},
            {Time = 2.4, Callback = function(self) self:DoSound(Sound("ps_wfoly_plr_sn_sbeta_inspect_03")) end},
        }
    },

    ["Jog_Out"] = {
        Sequences = {"jog_out"},
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Jump"] = {
        Sequences = {"jump"},
        Fps = 15,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Land"] = {
        Sequences = {"jump_land"},
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["HybridOn"] = {
        Sequences = {"hybrid_toggle_off"},
        Fps = 30,
        Length = 0.9,
        NextSequence = "Idle",
        Events = {
            {Time = 0.15, Callback = function(self) self:DoSound(Sound("Flipsight.Up")) end}
        }
    },

    ["HybridOff"] = {
        Sequences = {"hybrid_toggle_on"},
        Fps = 30,
        Length = 0.9,
        NextSequence = "Idle",
        Events = {
            {Time = 0.1, Callback = function(self) self:DoSound(Sound("Flipsight.Down")) end}
        }
    },

    ["Melee"] = {
        Sequences = {"melee_miss_01", "melee_miss_02", "melee_miss_03"},
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
        Sequences = {"melee_hit_01", "melee_hit_02", "melee_hit_03"},
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