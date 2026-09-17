local p = "mw/weapons/melee/cinderblock/"

sound.Add({
	name = "weap_raise_cinderblock_plr",
	channel = CHAN_WPNFOLEY,
	level = 75,
	-- volume = {.7358, .7558},
	pitch = {95, 106},
	sound = p .. "sh_vm_cinderblock_pickup.ogg"
})

local p = "mw/mp/executions/"

sound.Add({
	name = "exec_gear_mvmt_midlength_light",
	channel = CHAN_WPNFOLEY,
	level = 75,
	volume = {.85, .87},
	pitch = {95, 106},
	sound = {
		p .. "exec_gear_mvmt_midlength_light_01.ogg",
		p .. "exec_gear_mvmt_midlength_light_02.ogg",
		p .. "exec_gear_mvmt_midlength_light_03.ogg",
		p .. "exec_gear_mvmt_midlength_light_04.ogg",
		p .. "exec_gear_mvmt_midlength_light_05.ogg",
		p .. "exec_gear_mvmt_midlength_light_06.ogg",
		p .. "exec_gear_mvmt_midlength_light_07.ogg",
		p .. "exec_gear_mvmt_midlength_light_08.ogg",
		p .. "exec_gear_mvmt_midlength_light_09.ogg",
		p .. "exec_gear_mvmt_midlength_light_10.ogg",
		p .. "exec_gear_mvmt_midlength_light_11.ogg",
		p .. "exec_gear_mvmt_midlength_light_12.ogg",
		p .. "exec_gear_mvmt_midlength_light_13.ogg",
		p .. "exec_gear_mvmt_midlength_light_14.ogg",
		p .. "exec_gear_mvmt_midlength_light_15.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Attack_Cinderblock",
	channel = CHAN_WEAPON,
	volume = {.9, .92},
	pitch = {95, 106},
	sound = {
		p .. "exec_gear_mvmt_complex_heavy_01.ogg",
		p .. "exec_gear_mvmt_complex_heavy_02.ogg",
		p .. "exec_gear_mvmt_complex_heavy_03.ogg",
		p .. "exec_gear_mvmt_complex_heavy_04.ogg",
		p .. "exec_gear_mvmt_complex_heavy_05.ogg",
		p .. "exec_gear_mvmt_complex_heavy_06.ogg",
		p .. "exec_gear_mvmt_complex_heavy_07.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Hit_Cinderblock",
	channel = CHAN_WEAPON + 10,
	volume = {.89, .91},
	pitch = {95, 106},
	sound = {
		p .. "exec_cinder_hit_body_01.ogg",
		p .. "exec_cinder_hit_body_02.ogg",
		p .. "exec_cinder_hit_head_01.ogg",
		p .. "exec_cinder_hit_head_02.ogg",
	}
})
