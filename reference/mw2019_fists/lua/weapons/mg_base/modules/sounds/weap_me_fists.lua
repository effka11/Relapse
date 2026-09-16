local p = "mw/weapons/melee/fist/"

sound.Add({
	name = "weap_fist_inspect_01",
	channel = CHAN_WPNFOLEY,
	level = 75,
	sound = p .. "wfoly_me_fists_inspect_01.ogg"
})
sound.Add({
	name = "weap_fist_inspect_02",
	channel = CHAN_WPNFOLEY + 1,
	level = 75,
	sound = p .. "wfoly_me_fists_inspect_02.ogg"
})
sound.Add({
	name = "weap_fist_inspect_03",
	channel = CHAN_WPNFOLEY + 2,
	level = 75,
	sound = p .. "wfoly_me_fists_inspect_03.ogg"
})
sound.Add({
	name = "weap_fist_inspect_04",
	channel = CHAN_WPNFOLEY + 3,
	level = 75,
	sound = p .. "wfoly_me_fists_inspect_04.ogg"
})

sound.Add({
	name = "MW_Melee.Attack_Fists",
	channel = CHAN_WEAPON,
	volume = .82, .83,
	pitch = {95, 105},
	sound = {
		p .. "attack/melee_attack_fist_plr_01.ogg",
		p .. "attack/melee_attack_fist_plr_02.ogg",
		p .. "attack/melee_attack_fist_plr_03.ogg",
		p .. "attack/melee_attack_fist_plr_04.ogg",
		p .. "attack/melee_attack_fist_plr_05.ogg",
		p .. "attack/melee_attack_fist_plr_06.ogg",
		p .. "attack/melee_attack_fist_plr_07.ogg",
		p .. "attack/melee_attack_fist_plr_08.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Flesh_Fists",
	channel = CHAN_WEAPON + 10,
	sound = {
		p .. "character/melee_character_fist_plr_01.ogg",
		p .. "character/melee_character_fist_plr_02.ogg",
		p .. "character/melee_character_fist_plr_03.ogg",
		p .. "character/melee_character_fist_plr_04.ogg",
		p .. "character/melee_character_fist_plr_05.ogg",
		p .. "character/melee_character_fist_plr_06.ogg",
		p .. "character/melee_character_fist_plr_07.ogg",
		p .. "character/melee_character_fist_plr_08.ogg",
		p .. "character/melee_character_fist_plr_09.ogg",
		p .. "character/melee_character_fist_plr_10.ogg",
		p .. "character/melee_character_fist_plr_11.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Cement_Fists",
	channel = CHAN_WEAPON + 10,
	volume = 1.0,
	sound = {
		p .. "world/melee_world_fist_cement_plr_01.ogg",
		p .. "world/melee_world_fist_cement_plr_02.ogg",
		p .. "world/melee_world_fist_cement_plr_03.ogg",
		p .. "world/melee_world_fist_cement_plr_04.ogg",
		p .. "world/melee_world_fist_cement_plr_05.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Metal_Fists",
	channel = CHAN_WEAPON + 10,
	volume = 1.0,
	sound = {
		p .. "world/melee_world_fist_metal_plr_01.ogg",
		p .. "world/melee_world_fist_metal_plr_02.ogg",
		p .. "world/melee_world_fist_metal_plr_03.ogg",
		p .. "world/melee_world_fist_metal_plr_04.ogg",
		p .. "world/melee_world_fist_metal_plr_05.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Soft_Fists",
	channel = CHAN_WEAPON + 10,
	volume = 1.0,
	sound = {
		p .. "world/melee_world_fist_soft_plr_01.ogg",
		p .. "world/melee_world_fist_soft_plr_02.ogg",
		p .. "world/melee_world_fist_soft_plr_03.ogg",
		p .. "world/melee_world_fist_soft_plr_04.ogg",
		p .. "world/melee_world_fist_soft_plr_05.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Wood_Fists",
	channel = CHAN_WEAPON + 10,
	volume = 1.0,
	sound = {
		p .. "world/melee_world_fist_wood_plr_01.ogg",
		p .. "world/melee_world_fist_wood_plr_02.ogg",
		p .. "world/melee_world_fist_wood_plr_03.ogg",
		p .. "world/melee_world_fist_wood_plr_04.ogg",
		p .. "world/melee_world_fist_wood_plr_05.ogg",
	}
})