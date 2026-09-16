AddCSLuaFile()

SWEP.Animations = {
    ["Idle"] = {--idle is a special animation index, movement animations are played when this is on
        Sequences = {"idle"},
        Fps = 30
        --does not need NextSequence to loop, it's an exception to the rule
    },

    ["Draw"] = {
        Sequences = {"draw"},
        Length = 0.8,
        Fps = 30,
        NextSequence = "Idle"
    },

    ["Holster"] = {
        Sequences = {"holster"},
        Length = 0.3,
        Fps = 30
    },

    ["Equip"] = {
        Sequences = {"draw_first"},
        Length = 0.933333,
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
        Fps = 30
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
        Length = 0.33,
        Fps = 24,
        NextSequence = "Idle",
    },

    ["Super_Sprint_In"] = {
        Sequences = {"super_sprint_in"},
        Fps = 30
        --NextSequence = "Sprint_Loop",
    },

    ["Super_Sprint_Loop"] = {
        Sequences = {"super_sprint_loop"},
        Fps = 26,
        NextSequence = "Sprint_Loop" --make our state loop
        --while sprinting, the playback rate of the viewmodel is scaled with velocity (cod-like behaviour)
    },

    ["Super_Sprint_Out"] = {
        Sequences = {"super_sprint_out"},
        Length = 0.3,
        Fps = 24,
        NextSequence = "Idle",
    },

    ["Inspect"] = {
        Sequences = {"inspect"},
        Length = 5.2,
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
        Sequences = {"melee_miss_01", "melee_miss_02", "melee_miss_03", "melee_miss_04", "melee_miss_05", "melee_miss_06", "melee_miss_07", "melee_miss_08"},
        Length = 0.35, --if melee misses

        Size = 15,
        Range = 40,
        Delay = 0.25,

        Fps = 30,
        NextSequence = "Idle"
    },

    ["Melee_Hit"] = {
        Sequences = {"melee_hit_01", "melee_hit_02", "melee_hit_03", "melee_hit_04", "melee_hit_05", "melee_hit_06", "melee_hit_07", "melee_hit_08"},
        Length = 0.35, --if melee hits

        Damage = 32.5,
        DamageType = DMG_CLUB,

        Fps = 30,
        NextSequence = "Idle"
    },
}