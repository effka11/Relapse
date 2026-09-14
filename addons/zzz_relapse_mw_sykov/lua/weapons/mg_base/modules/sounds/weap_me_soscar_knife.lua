local p = "mw/weapons/melee/knife/"

sound.Add({
	name = "weap_raise_knife_plr",
	channel = CHAN_WPNFOLEY,
	level = 75,
	-- volume = {.7358, .7558},
	pitch = {95, 106},
	sound = p .. "melee_knife_unsheath.ogg"
})

sound.Add({
	name = "weap_knife_inspect_01",
	channel = CHAN_WPNFOLEY,
	level = 75,
	sound = p .. "wfoly_me_knife_inspect_01.ogg"
})
sound.Add({
	name = "weap_knife_inspect_02",
	channel = CHAN_WPNFOLEY + 1,
	level = 75,
	sound = p .. "wfoly_me_knife_inspect_02.ogg"
})
sound.Add({
	name = "weap_knife_inspect_03",
	channel = CHAN_WPNFOLEY + 2,
	level = 75,
	sound = p .. "wfoly_me_knife_inspect_03.ogg"
})

sound.Add({
	name = "MW_Melee.Attack_Knife",
	channel = CHAN_WEAPON,
	volume = .82, .83,
	pitch = {95, 105},
	sound = {
		p .. "attack/melee_attack_knife_plr_01.ogg",
		p .. "attack/melee_attack_knife_plr_02.ogg",
		p .. "attack/melee_attack_knife_plr_03.ogg",
		p .. "attack/melee_attack_knife_plr_04.ogg",
		p .. "attack/melee_attack_knife_plr_05.ogg",
		p .. "attack/melee_attack_knife_plr_06.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Flesh_Knife",
	channel = CHAN_WEAPON + 10,
	sound = {
		p .. "character/melee_character_knife_plr_01.ogg",
		p .. "character/melee_character_knife_plr_02.ogg",
		p .. "character/melee_character_knife_plr_03.ogg",
		p .. "character/melee_character_knife_plr_04.ogg",
		p .. "character/melee_character_knife_plr_05.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Cement_Knife",
	channel = CHAN_WEAPON + 10,
	volume = 1.0,
	sound = {
		p .. "world/melee_world_knife_cement_plr_01.ogg",
		p .. "world/melee_world_knife_cement_plr_02.ogg",
		p .. "world/melee_world_knife_cement_plr_03.ogg",
		p .. "world/melee_world_knife_cement_plr_04.ogg",
		p .. "world/melee_world_knife_cement_plr_05.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Metal_Knife",
	channel = CHAN_WEAPON + 10,
	volume = 1.0,
	sound = {
		p .. "world/melee_world_knife_metal_plr_01.ogg",
		p .. "world/melee_world_knife_metal_plr_02.ogg",
		p .. "world/melee_world_knife_metal_plr_03.ogg",
		p .. "world/melee_world_knife_metal_plr_04.ogg",
		p .. "world/melee_world_knife_metal_plr_05.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Soft_Knife",
	channel = CHAN_WEAPON + 10,
	volume = 1.0,
	sound = {
		p .. "world/melee_world_knife_soft_plr_01.ogg",
		p .. "world/melee_world_knife_soft_plr_02.ogg",
		p .. "world/melee_world_knife_soft_plr_03.ogg",
		p .. "world/melee_world_knife_soft_plr_04.ogg",
		p .. "world/melee_world_knife_soft_plr_05.ogg",
	}
})

sound.Add({
	name = "MW_Melee.Wood_Knife",
	channel = CHAN_WEAPON + 10,
	volume = 1.0,
	sound = {
		p .. "world/melee_world_knife_wood_plr_01.ogg",
		p .. "world/melee_world_knife_wood_plr_02.ogg",
		p .. "world/melee_world_knife_wood_plr_03.ogg",
		p .. "world/melee_world_knife_wood_plr_04.ogg",
		p .. "world/melee_world_knife_wood_plr_05.ogg",
	}
})