
-- Mike4 --
sound.Add({
    name =           "mw19.mike4.fire",
    channel =        CHAN_WEAPON,
    level = 140,
    volume =         1,
    sound = "^viper/weapons/mike4/weap_mike4_fire_plr_01.wav"
})
sound.Add({
    name =           "mw19.mike4.fire.s",
    channel =        CHAN_WEAPON,
    level = 140,
    volume =         1,
    sound = "^viper/weapons/mike4/weap_mike4_sup_plr_01.wav"
})



sound.Add({
    name =           "mw19.mike4.fire.disconnector",
    channel =        CHAN_WPNFOLEY +2,
    volume =         1,
    sound = {"viper/weapons/mike4/weap_mike4_fire_plr_disconnector_01.ogg",
             "viper/weapons/mike4/weap_mike4_fire_plr_disconnector_02.ogg",
             "viper/weapons/mike4/weap_mike4_fire_plr_disconnector_03.ogg",
             "viper/weapons/mike4/weap_mike4_fire_plr_disconnector_04.ogg",
             "viper/weapons/mike4/weap_mike4_fire_plr_disconnector_05.ogg",
             "viper/weapons/mike4/weap_mike4_fire_plr_disconnector_06.ogg"
            }              
})
sound.Add({
    name =           "mw19.mike4.fire.first",
    channel =        CHAN_WPNFOLEY +2,
    volume =         1,
    sound = {"viper/weapons/mike4/weap_mike4_fire_dryfire_plr_01.ogg",
             "viper/weapons/mike4/weap_mike4_fire_dryfire_plr_02.ogg",
             "viper/weapons/mike4/weap_mike4_fire_dryfire_plr_03.ogg",
             "viper/weapons/mike4/weap_mike4_fire_dryfire_plr_04.ogg",
             "viper/weapons/mike4/weap_mike4_fire_dryfire_plr_05.ogg",
             "viper/weapons/mike4/weap_mike4_fire_dryfire_plr_06.ogg"
            }              
})



sound.Add({
    name =           "mw19.mike4.fire.last",
    channel =        CHAN_WPNFOLEY,
    volume =         1,
    sound = {"viper/weapons/mike4/weap_mike4_fire_last_plr_mech_01.ogg",
             "viper/weapons/mike4/weap_mike4_fire_last_plr_mech_02.ogg",
             "viper/weapons/mike4/weap_mike4_fire_last_plr_mech_03.ogg"
            }              
})



sound.Add({
    name =           "weap_ar_mike4_ads_up",
    channel =        CHAN_WPNFOLEY,
    volume =         1,
    sound = {"viper/weapons/mike4/wfoly_ar_mike4_ads_up.ogg"}              
})
sound.Add({
    name =           "weap_ar_mike4_ads_down",
    channel =        CHAN_WPNFOLEY,
    volume =         1,
    sound = {"viper/weapons/mike4/wfoly_ar_mike4_ads_down.ogg"}              
})



sound.Add({
    name =           "weap_ar_mike4_selector_off",
    channel =        CHAN_WPNFOLEY,
    volume =         1,
    sound = {"viper/weapons/mike4/weap_m4_selector_semi_on_01.ogg"}              
})
sound.Add({
    name =           "weap_ar_mike4_selector_on",
    channel =        CHAN_WPNFOLEY,
    volume =         1,
    sound = {"viper/weapons/mike4/weap_m4_selector_semi_on_03.ogg"}              
})



sound.Add({
    name =           "wfoly_ar_mike4_inspect_01",
    channel =        CHAN_WPNFOLEY +1,
    volume =         1,
    sound = {"viper/weapons/mike4/wfoly_ar_mike4_inspect_01.ogg"}              
})
sound.Add({
    name =           "wfoly_ar_mike4_inspect_02",
    channel =        CHAN_WPNFOLEY +2,
    volume =         1,
    sound = {"viper/weapons/mike4/wfoly_ar_mike4_inspect_02.ogg"}              
})
sound.Add({
    name =           "wfoly_ar_mike4_inspect_03",
    channel =        CHAN_WPNFOLEY +3,
    volume =         1,
    sound = {"viper/weapons/mike4/wfoly_ar_mike4_inspect_03.ogg"}              
})
sound.Add({
    name =           "wfoly_ar_mike4_inspect_04",
    channel =        CHAN_WPNFOLEY +4,
    volume =         1,
    sound = {"viper/weapons/mike4/wfoly_ar_mike4_inspect_04.ogg"}              
})
sound.Add({
    name =           "wfoly_ar_mike4_inspect_05",
    channel =        CHAN_WPNFOLEY +5,
    volume =         1,
    sound = {"viper/weapons/mike4/wfoly_ar_mike4_inspect_05.ogg"}              
})



sound.Add({
    name =           "weap_mike4_raise_plr",
    channel =        CHAN_WPNFOLEY,
    volume =         1,
    sound = {"viper/weapons/mike4/wpfoly_mike4_raise_v2.ogg"}              
})
sound.Add({
    name =           "weap_mike4_drop_plr",
    channel =        CHAN_WPNFOLEY,
    volume =         1,
    sound = {"viper/weapons/mike4/wpfoly_mike4_drop_v2.ogg"}              
})



sound.Add({
    name =           "weap_mike4_raise_first_01",
    channel =        CHAN_WPNFOLEY +1,
    volume =         1,
    sound = {"viper/weapons/mike4/wpfoly_mike4_raise_first_01.ogg"}              
})
sound.Add({
    name =           "weap_mike4_raise_first_02",
    channel =        CHAN_WPNFOLEY +2,
    volume =         1,
    sound = {"viper/weapons/mike4/wpfoly_mike4_raise_first_02.ogg"}              
})
sound.Add({
    name =           "weap_mike4_raise_first_03",
    channel =        CHAN_WPNFOLEY +3,
    volume =         1,
    sound = {"viper/weapons/mike4/wpfoly_mike4_raise_first_03.ogg"}              
})




-- Sound: 38
sound.Add({
	name = "weap_mike4_reload_empty_chamber_plr",
	channel = CHAN_WPNFOLEY + 9,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_chamber_v2.ogg",
		}
})
-- Sound: 39
sound.Add({
	name = "weap_mike4_reload_empty_end_plr",
	channel = CHAN_WPNFOLEY + 10,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_end_v2.ogg",
		}
})
-- Sound: 40
sound.Add({
	name = "weap_mike4_reload_empty_fast_chamber_plr",
	channel = CHAN_WPNFOLEY + 1,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_fast_chamber_v2.ogg",
		}
})
-- Sound: 41
sound.Add({
	name = "weap_mike4_reload_empty_fast_end_plr",
	channel = CHAN_WPNFOLEY + 2,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_fast_end_v2.ogg",
		}
})
-- Sound: 42
sound.Add({
	name = "weap_mike4_reload_empty_fast_lift_plr",
	channel = CHAN_WPNFOLEY + 3,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_fast_lift_v2.ogg",
		}
})
-- Sound: 43
sound.Add({
	name = "weap_mike4_reload_empty_fast_magin_plr",
	channel = CHAN_WPNFOLEY + 4,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_fast_magin_v2.ogg",
		}
})
-- Sound: 44
sound.Add({
	name = "weap_mike4_reload_empty_fast_magout_plr",
	channel = CHAN_WPNFOLEY + 5,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_fast_magout_v2.ogg",
		}
})
-- Sound: 45
sound.Add({
	name = "weap_mike4_reload_empty_lift_plr",
	channel = CHAN_WPNFOLEY + 6,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_lift_v2.ogg",
		}
})
-- Sound: 46
sound.Add({
	name = "weap_mike4_reload_empty_magin_plr",
	channel = CHAN_WPNFOLEY + 7,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_magin_v2_01.ogg",
		}
})
-- Sound: 47
sound.Add({
	name = "weap_mike4_reload_empty_magin_plr_02",
	channel = CHAN_WPNFOLEY + 8,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_magin_v2_02.ogg",
		}
})
-- Sound: 48
sound.Add({
	name = "weap_mike4_reload_empty_magout_plr",
	channel = CHAN_WPNFOLEY + 9,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_empty_magout_v2.ogg",
		}
})
-- Sound: 49
sound.Add({
	name = "weap_mike4_reload_end_plr",
	channel = CHAN_WPNFOLEY + 10,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_end_v2.ogg",
		}
})
-- Sound: 50
sound.Add({
	name = "weap_mike4_reload_fast_end_plr",
	channel = CHAN_WPNFOLEY + 1,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_fast_end_v2.ogg",
		}
})
-- Sound: 51
sound.Add({
	name = "weap_mike4_reload_fast_lift_plr",
	channel = CHAN_WPNFOLEY + 2,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_fast_lift_v2.ogg",
		}
})
-- Sound: 52
sound.Add({
	name = "weap_mike4_reload_fast_magin_plr",
	channel = CHAN_WPNFOLEY + 3,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_fast_magin_v2_01.ogg",
		}
})
-- Sound: 53
sound.Add({
	name = "weap_mike4_reload_fast_magin_plr_02",
	channel = CHAN_WPNFOLEY + 4,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_fast_magin_v2_02.ogg",
		}
})
-- Sound: 54
sound.Add({
	name = "weap_mike4_reload_fast_magout_plr",
	channel = CHAN_WPNFOLEY + 5,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_fast_magout_v2.ogg",
		}
})
-- Sound: 55
sound.Add({
	name = "weap_mike4_reload_lift_plr",
	channel = CHAN_WPNFOLEY + 6,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_lift_v2.ogg",
		}
})
-- Sound: 56
sound.Add({
	name = "weap_mike4_reload_magin_plr",
	channel = CHAN_WPNFOLEY + 7,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_magin_v2_01.ogg",
		}
})
-- Sound: 57
sound.Add({
	name = "weap_mike4_reload_magin_plr_02",
	channel = CHAN_WPNFOLEY + 8,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_magin_v2_02.ogg",
		}
})
-- Sound: 58
sound.Add({
	name = "weap_mike4_reload_magout_plr",
	channel = CHAN_WPNFOLEY + 9,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_magout_v2.ogg",
		}
})
-- Sound: 59
sound.Add({
	name = "wfoly_ar_mike4_gl_drop",
	channel = CHAN_WPNFOLEY + 10,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_drop.ogg",
		}
})
-- Sound: 60
sound.Add({
	name = "wfoly_ar_mike4_gl_fromgrenade",
	channel = CHAN_WPNFOLEY + 1,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_fromgrenade.ogg",
		}
})
-- Sound: 61
sound.Add({
	name = "wfoly_ar_mike4_gl_raise",
	channel = CHAN_WPNFOLEY + 2,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_raise.ogg",
		}
})
-- Sound: 62
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_01",
	channel = CHAN_WPNFOLEY + 3,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_raise.ogg",
		}
})
-- Sound: 63
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_02",
	channel = CHAN_WPNFOLEY + 4,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_open_01.ogg",
		}
})
-- Sound: 64
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_03",
	channel = CHAN_WPNFOLEY + 5,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_shellout_01.ogg",
		}
})
-- Sound: 65
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_04",
	channel = CHAN_WPNFOLEY + 6,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_shellin_01.ogg",
		}
})
-- Sound: 66
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_05",
	channel = CHAN_WPNFOLEY + 7,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_close_01.ogg",
		}
})
-- Sound: 67
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_06",
	channel = CHAN_WPNFOLEY + 8,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_end.ogg",
		}
})
-- Sound: 68
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_fast_01",
	channel = CHAN_WPNFOLEY + 9,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_fast_raise.ogg",
		}
})
-- Sound: 69
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_fast_02",
	channel = CHAN_WPNFOLEY + 10,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_fast_open_01.ogg",
		}
})
-- Sound: 70
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_fast_03",
	channel = CHAN_WPNFOLEY + 1,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_fast_shellout_01.ogg",
		}
})
-- Sound: 71
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_fast_04",
	channel = CHAN_WPNFOLEY + 2,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_fast_shellin_01.ogg",
		}
})
-- Sound: 72
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_fast_05",
	channel = CHAN_WPNFOLEY + 3,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_fast_close_01.ogg",
		}
})
-- Sound: 73
sound.Add({
	name = "wfoly_ar_mike4_gl_reload_fast_06",
	channel = CHAN_WPNFOLEY + 4,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_reload_fast_end.ogg",
		}
})
-- Sound: 74
sound.Add({
	name = "wfoly_ar_mike4_gl_togrenade",
	channel = CHAN_WPNFOLEY + 5,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_gl_togrenade.ogg",
		}
})
-- Sound: 75
sound.Add({
	name = "wfoly_ar_mike4_inspect_01",
	channel = CHAN_WPNFOLEY + 6,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_inspect_01.ogg",
		}
})
-- Sound: 76
sound.Add({
	name = "wfoly_ar_mike4_inspect_02",
	channel = CHAN_WPNFOLEY + 7,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_inspect_02.ogg",
		}
})
-- Sound: 77
sound.Add({
	name = "wfoly_ar_mike4_inspect_03",
	channel = CHAN_WPNFOLEY + 8,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_inspect_03.ogg",
		}
})
-- Sound: 78
sound.Add({
	name = "wfoly_ar_mike4_inspect_04",
	channel = CHAN_WPNFOLEY + 9,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_inspect_04.ogg",
		}
})
-- Sound: 79
sound.Add({
	name = "wfoly_ar_mike4_inspect_05",
	channel = CHAN_WPNFOLEY + 10,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_inspect_05.ogg",
		}
})
-- Sound: 80
sound.Add({
	name = "wfoly_ar_mike4_reload_empty_xmag_in",
	channel = CHAN_WPNFOLEY + 1,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_reload_empty_xmag_magin_01.ogg",
		}
})
-- Sound: 81
sound.Add({
	name = "wfoly_ar_mike4_reload_empty_xmag_out",
	channel = CHAN_WPNFOLEY + 2,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_reload_empty_xmag_magout_01.ogg",
		}
})
-- Sound: 82
sound.Add({
	name = "wfoly_ar_mike4_reload_xmag_in",
	channel = CHAN_WPNFOLEY + 3,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wfoly_ar_mike4_reload_magin_01.ogg",
		}
})
-- Sound: 83
sound.Add({
	name = "wfoly_ar_mike4_reload_xmag_out",
	channel = CHAN_WPNFOLEY + 4,
	level = 140,
	volume = 1,
	pitch = {100,100},
	sound = {
		"viper/weapons/mike4/wpfoly_mike4_reload_magout_v2.ogg",
		}
})