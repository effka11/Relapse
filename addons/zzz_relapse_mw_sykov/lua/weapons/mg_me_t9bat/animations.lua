AddCSLuaFile()

SWEP.Animations = {
    ["Idle"] = {--idle is a special animation index, movement animations are played when this is on
        Sequences = {"idle"},
        Fps = 30
        --does not need NextSequence to loop, it's an exception to the rule
    },

    ["Draw"] = {
        Sequences = {"draw"},
        Length = 15/30,
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Holster"] = {
        Sequences = {"holster"},
        Length = 15/30,
        Fps = 30
    },

    ["Equip"] = {
        Sequences = {"draw_First"},
        Length = 85/30,
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Ads_In"] = {
        Sequences = {"idle"},
        Length = 0.000001,
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Ads_Out"] = {
        Sequences = {"idle"},
        Length = 0.000001,
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Reload"] = {
        Sequences = {"idle"},
        Length = 0.000001,
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Sprint_In"] = {
        Sequences = {"sprint_in"},
        Fps = 60
        --NextSequence = "Sprint_Loop",
    },

    ["Sprint_Loop"] = {
        Sequences = {"sprint_loop"},
        Fps = 26,
        NextSequence = "Sprint_Loop" --make our state loop
        --while sprinting, the playback rate of the viewmodel is scaled with velocity (cod-like behaviour)
    },

    ["Sprint_Out"] = {
        Sequences = {"sprint_out"},
        Length = 10/60,
        Fps = 60,
        NextSequence = "Idle",
    },

    ["Inspect"] = {
        Sequences = {"inspect"},
        Length = 80/30,
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Jog_Out"] = {
        Sequences = {"jog_out"},
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Jump"] = {
        Sequences = {"jump"},
        Fps = 15,
        NextSequence = "Idle"
    },

    ["Land"] = {
        Sequences = {"jump_land"},
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Melee"] = {
        Sequences = {"melee_miss_01", "melee_miss_02"},
        Length = 25/30, --if melee misses

        Size = 15,
        Range = 45,
        Delay = 11/30,

        Fps = 30,
        NextSequence = "Idle"
    },

    ["Melee_Hit"] = {
        Sequences = {"melee_miss_01", "melee_miss_02"},
        Length = 20/30, --if melee hits

        Damage = 50,
        DamageType = DMG_CLUB,

        Fps = 30,
        NextSequence = "Idle"
    },
}