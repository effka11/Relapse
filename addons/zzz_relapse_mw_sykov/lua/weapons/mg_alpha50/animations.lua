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
        Length = 0.7,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.067, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_raise_01")) end},
        }
    },

    ["Holster"] = {
        Sequences = {"holster"},
        Length = 1,
        Fps = 30,
        Events = {
            {Time = 0.067, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_drop_01")) end},
        }
    },

    ["Equip"] = {
        Sequences = {"draw_First"},
        Length = 1.25,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.567, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_raise_first_02")) end},
            {Time = 0.2, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_raise_first_01")) end},
        }
    },

    ["reload_xmag"] = {
        Sequences = {"reload_xmag"},
        Length = 3.03,
        MagLength = 2.3,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_02")) end},
            {Time = 2.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_06")) end},
            {Time = 2.233, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_055")) end},
            {Time = 1.8, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_04")) end},
            {Time = 2.1, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_05")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_03")) end},
            {Time = 0.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_01")) end},
        
        }
    },

    ["reload_xmag_fast"] = {
        Sequences = {"reload_xmag_fast"},
        Length = 2.06,
        MagLength = 1.26,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.5, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_035")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_04")) end},
            {Time = 0.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_02")) end},
            {Time = 1.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_03")) end},
            {Time = 0.133, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_01")) end},
        
        }
    },

    ["reload_mmag"] = {
        Sequences = {"reload_mmag"},
        Length = 3.03,
        MagLength = 2.3,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_02")) end},
            {Time = 2.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_06")) end},
            {Time = 2.233, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_055")) end},
            {Time = 1.8, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_04")) end},
            {Time = 2.1, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_05")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_03")) end},
            {Time = 0.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_01")) end},
        
        }
    },

    ["reload_mmag_fast"] = {
        Sequences = {"reload_mmag_fast"},
        Length = 2.06,
        MagLength = 1.26,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.5, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_035")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_04")) end},
            {Time = 0.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_02")) end},
            {Time = 1.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_03")) end},
            {Time = 0.133, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_01")) end},
        
        }
    },

    ["Reload"] = {
        Sequences = {"reload"},
        Length = 3.03,
        MagLength = 2.3,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_02")) end},
            {Time = 2.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_06")) end},
            {Time = 2.233, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_055")) end},
            {Time = 1.8, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_04")) end},
            {Time = 2.1, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_05")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_03")) end},
            {Time = 0.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_01")) end},
        
        }
    },

    ["Reload_Fast"] = {
        Sequences = {"reload_fast"},
        Length = 2.06,
        MagLength = 1.26,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 1.5, Callback = function(self) end},
            {Time = 1.5, Callback = function(self) end},
            {Time = 1.5, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_035")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_04")) end},
            {Time = 0.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_02")) end},
            {Time = 1.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_03")) end},
            {Time = 0.133, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_fast_01")) end},
        
        }
    },

    ["reload_empty_xmag"] = {
        Sequences = {"reload_empty_xmag"},
        Length = 4.5,
        MagLength = 2.83,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.5, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 2.8, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_055")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_03")) end},
            {Time = 3.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_08")) end},
            {Time = 3.1, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_06")) end},
            {Time = 3.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_07")) end},
            {Time = 1.533, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_04")) end},
            {Time = 2.5, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_05")) end},
            {Time = 0.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_02")) end},
            {Time = 0.2, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_rechamber_01")) end},
        }
    },

    ["reload_empty_xmag_fast"] = {
        Sequences = {"reload_empty_xmag_fast"},
        Length = 2.9,
        MagLength = 1.73,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.25, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 2.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_06")) end},
            {Time = 2.667, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_07")) end},
            {Time = 1.6, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_05")) end},
            {Time = 0.233, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_02")) end},
            {Time = 1.867, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_055")) end},
            {Time = 0.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_rechamber_01")) end},
            {Time = 0.767, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_03")) end},
            {Time = 1.0, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_04")) end},
        }
    },

    ["reload_empty_mmag"] = {
        Sequences = {"reload_empty_mmag"},
        Length = 4.5,
        MagLength = 2.83,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.5, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 2.8, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_055")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_03")) end},
            {Time = 3.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_08")) end},
            {Time = 3.1, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_06")) end},
            {Time = 3.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_07")) end},
            {Time = 1.533, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_04")) end},
            {Time = 2.5, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_05")) end},
            {Time = 0.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_02")) end},
            {Time = 0.2, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_rechamber_01")) end},
        }
    },

    ["reload_empty_mmag_fast"] = {
        Sequences = {"reload_empty_mmag_fast"},
        Length = 2.9,
        MagLength = 1.73,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.25, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 2.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_06")) end},
            {Time = 2.667, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_07")) end},
            {Time = 1.6, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_05")) end},
            {Time = 0.233, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_02")) end},
            {Time = 1.867, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_055")) end},
            {Time = 0.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_rechamber_01")) end},
            {Time = 0.767, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_03")) end},
            {Time = 1.0, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_04")) end},
        }
    },

    ["Reload_Empty"] = {
        Sequences = {"reload_empty"},
        Length = 4.5,
        MagLength = 2.83,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.5, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 2.8, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_055")) end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_03")) end},
            {Time = 3.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_08")) end},
            {Time = 3.1, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_06")) end},
            {Time = 3.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_07")) end},
            {Time = 1.533, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_04")) end},
            {Time = 2.5, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_05")) end},
            {Time = 0.367, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_02")) end},
            {Time = 0.2, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_rechamber_01")) end},
        }
    },

    ["Reload_Empty_Fast"] = {
        Sequences = {"reload_empty_fast"},
        Length = 2.9,
        MagLength = 1.73,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.25, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 2.3, Callback = function(self) end},
            {Time = 2.3, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_06")) end},
            {Time = 2.667, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_07")) end},
            {Time = 1.6, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_05")) end},
            {Time = 0.233, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_02")) end},
            {Time = 1.867, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_055")) end},
            {Time = 0.167, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_rechamber_01")) end},
            {Time = 0.767, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_03")) end},
            {Time = 1.0, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_reload_empty_fast_04")) end},
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
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
        }
    },

    ["Rechamber"] = {
        Sequences = {"rechamber"},
        Fps = 30,
        Length = 1.3,
        NextSequence = "Idle",
        Events = {
            {
                Time = 0.5, 
                Callback = function(self) 
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 0.2, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_rechamber_01")) end},
            {Time = 0.733, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_rechamber_02")) end},
        }
    },

    ["Fire_Last"] = {
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

    ["Ads_In"] = {
        Sequences = {"ads_in"},
        Length = 0.25,
        Fps = 25,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}, 
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("weap_sn_alpha50_ads_up")) end},
        }
    },

    ["Ads_Out"] = {
        Sequences = {"ads_out"},
        Length = 0.25,
        Fps = 25,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}, 
            {Time = 0, Callback = function(self) self:EnableGrip2() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("weap_sn_alpha50_ads_down")) end},
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
            {Time = 1.7, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_inspect_02")) end},
            {Time = 0.033, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_inspect_01")) end},
            {Time = 3.867, Callback = function(self) self:DoSound(Sound("wfoly_plr_sn_alpha50_inspect_03")) end},
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