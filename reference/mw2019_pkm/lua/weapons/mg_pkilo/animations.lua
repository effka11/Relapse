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
        Length = 1.4, --o7
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.akilo47.raise")) end}
        }
    },

    ["Holster"] = {
        Sequences = {"holster"},
        Length = 1,
        Fps = 30,
        Events = {
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.akilo47.drop")) end},
            {Time = 0, Callback = function(self) self:DisableGrip() end},
        }
    },

    ["Equip"] = {
        Sequences = {"draw_First"},
        Length = 2,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0.35, Callback = function(self) self:DoSound(Sound("mw19.akilo47.raise.first")) end},
            {Time = 0, Callback = function(self) self:EnableGrip() end}
        }
    },

    ["Reload"] = {
        Sequences = {"Reload"},
        Length = 8.65,
        Fps = 30,
        MagLength = 5.85,
        NextSequence = "Idle",
        Events = {
        }
    },

    ["Reload_fast"] = {
        Sequences = {"Reload_fast"},
        Length = 5.9,
        Fps = 30,
        MagLength = 3.9,
        NextSequence = "Idle",
        Events = {
        }
    },

    ["Reload_Empty"] = {
        Sequences = {"Reload_empty"},
        Length = 8.65,
        Fps = 30,
        MagLength = 5.85,
        NextSequence = "Idle",
        Events = {
        }
    },

    ["Reload_empty_fast"] = {
        Sequences = {"Reload_empty_fast"},
        Length = 5.9,
        Fps = 30,
        MagLength = 3.9,
        NextSequence = "Idle",
        Events = {
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
                    self:DoParticle("Ejection", "shell_eject")
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 0, Callback = function(self) self:EnableGrip() end},
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
                    self:DoParticle("Ejection", "shell_eject")
                    self:DoEjection("shell_eject")
                end
            },
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Ads_In"] = {
        Sequences = {"ads_in"},
        Length = 0.195,
        Fps = 12,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.akilo47.ads.up")) end}
        }
    },

    ["Ads_Out"] = {
        Sequences = {"ads_out"},
        Length = 0.3,
        Fps = 17,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.akilo47.ads.down")) end}
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
        Fps = 30,
        NextSequence = "Sprint_Loop", --make our state loop
        --while sprinting, the playback rate of the viewmodel is scaled with velocity (cod-like behaviour)
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Sprint_Out"] = {
        Sequences = {"sprint_out"},
        Length = 0.3,
        Fps = 17,
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
            {Time = 0, Callback = function(self) self:DoSound(Sound("mw19.akilo47.inspect.01")) end},
            {Time = 0.13, Callback = function(self) self:DisableGrip() end},
            {Time = 1.3, Callback = function(self) self:DoSound(Sound("mw19.akilo47.inspect.02")) end},
            {Time = 2.36, Callback = function(self) self:DoSound(Sound("mw19.akilo47.inspect.03")) end},
            {Time = 3.6, Callback = function(self) self:DoSound(Sound("mw19.akilo47.inspect.04")) end},
            {Time = 4.26, Callback = function(self) self:DoSound(Sound("mw19.akilo47.inspect.05")) end},
            {Time = 4.4, Callback = function(self) self:EnableGrip() end},
        }
    },

    ["Jog_Out"] = {
        Sequences = {"jog_out"},
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}
        }
    },

    ["Jump"] = {
        Sequences = {"jump"},
        Fps = 15,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}
        }
    },

    ["Land"] = {
        Sequences = {"jump_land"},
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() end}
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
            {Time = 0.8, Callback = function(self) self:EnableGrip() end}
            
        }
    },

    ["Melee_Hit"] = {
        Sequences = {"melee_hit_01", "melee_hit_02", "melee_hit_03"},
        Length = 0.5, --if melee hits

        Damage = 100,

        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:DisableGrip() end},
            {Time = 0, Callback = function(self) self:DoSound(Sound("MW_Melee.Flesh_Medium")) end},
            {Time = 0.8, Callback = function(self) self:EnableGrip() end}
        }
    },
                
    ["Super_Sprint_In"] = {
        Sequences = {"super_sprint_in"},
        Fps = 30,
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() self:AllowRuntimeMagPoseParam(true) end},
        }
        --NextSequence = "Sprint_Loop",
    },

    ["Super_Sprint_Loop"] = {
        Sequences = {"super_sprint_loop"},
        Fps = 30,
        NextSequence = "Sprint_Loop", --make our state loop
        --while sprinting, the playback rate of the viewmodel is scaled with velocity (cod-like behaviour)
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() self:AllowRuntimeMagPoseParam(true) end},
        }
    },

    ["Super_Sprint_Out"] = {
        Sequences = {"super_sprint_out"},
        Length = 0.3,
        Fps = 30,
        NextSequence = "Idle",
        Events = {
            {Time = 0, Callback = function(self) self:EnableGrip() self:AllowRuntimeMagPoseParam(true) end},
        }
    },
}