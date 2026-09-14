GM.ZombieEscapeWeaponsPrimary = {
	"weapon_zs_zeakbar",
	"weapon_zs_zesweeper",
	"weapon_zs_zesmg",
	"weapon_zs_zeinferno",
	"weapon_zs_zestubber",
	"weapon_zs_zebulletstorm",
	"weapon_zs_zesilencer",
	"weapon_zs_zequicksilver",
	"weapon_zs_zeamigo",
	"weapon_zs_zem4"
}

GM.ZombieEscapeWeaponsSecondary = {
	"weapon_zs_zedeagle",
	"weapon_zs_zebattleaxe",
	"weapon_zs_zeeraser",
	"weapon_zs_zeglock",
	"weapon_zs_zetempest"
}

-- Change this if you plan to alter the cost of items or you severely change how Worth works.
-- Having separate cart files allows people to have separate loadouts for different servers.
GM.CartFile = "zscarts.txt"
GM.SkillLoadoutsFile = "zsskloadouts.txt"

ITEMCAT_GUNS = 1
ITEMCAT_AMMO = 2
ITEMCAT_MELEE = 3
ITEMCAT_TOOLS = 4
ITEMCAT_DEPLOYABLES = 5
ITEMCAT_TRINKETS = 6
ITEMCAT_OTHER = 7

ITEMSUBCAT_TRINKETS_DEFENSIVE = 1
ITEMSUBCAT_TRINKETS_OFFENSIVE = 2
ITEMSUBCAT_TRINKETS_MELEE = 3
ITEMSUBCAT_TRINKETS_PERFORMANCE = 4
ITEMSUBCAT_TRINKETS_SUPPORT = 5
ITEMSUBCAT_TRINKETS_SPECIAL = 6

GM.ItemCategories = {
	[ITEMCAT_GUNS] = "Guns",
	[ITEMCAT_AMMO] = "Ammunition",
	[ITEMCAT_MELEE] = "Melee",
	[ITEMCAT_TOOLS] = "Tools",
	[ITEMCAT_DEPLOYABLES] = "Deployables",
	[ITEMCAT_TRINKETS] = "Trinkets",
	[ITEMCAT_OTHER] = "Other"
}

GM.ItemSubCategories = {
	[ITEMSUBCAT_TRINKETS_DEFENSIVE] = "Defensive",
	[ITEMSUBCAT_TRINKETS_OFFENSIVE] = "Offensive",
	[ITEMSUBCAT_TRINKETS_MELEE] = "Melee",
	[ITEMSUBCAT_TRINKETS_PERFORMANCE] = "Performance",
	[ITEMSUBCAT_TRINKETS_SUPPORT] = "Support",
	[ITEMSUBCAT_TRINKETS_SPECIAL] = "Special"
}

--[[
Humans select what weapons (or other things) they want to start with and can even save favorites. Each object has a number of 'Worth' points.
Signature is a unique signature to give in case the item is renamed or reordered. Don't use a number or a string number!
A human can only use 100 points (default) when they join. Redeeming or joining late starts you out with a random loadout from above.
SWEP is a swep given when the player spawns with that perk chosen.
Callback is a function called. Model is a display model. If model isn't defined then the SWEP model will try to be used.
swep, callback, and model can all be nil or empty
]]
GM.Items = {}
function GM:AddItem(signature, category, price, swep, name, desc, model, callback)
	local tab = {Signature = signature, Name = name or "?", Description = desc, Category = category, Price = price or 0, SWEP = swep, Callback = callback, Model = model}

	tab.Worth = tab.Price -- compat

	self.Items[#self.Items + 1] = tab
	self.Items[signature] = tab

	return tab
end

function GM:AddStartingItem(signature, category, price, swep, name, desc, model, callback)
	local item = self:AddItem(signature, category, price, swep, name, desc, model, callback)
	item.WorthShop = true

	return item
end

function GM:AddPointShopItem(signature, category, price, swep, name, desc, model, callback)
	local item = self:AddItem("ps_"..signature, category, price, swep, name, desc, model, callback)
	item.PointShop = true

	return item
end

-- How much ammo is considered one 'clip' of ammo? For use with setting up weapon defaults. Works directly with zs_survivalclips
GM.AmmoCache = {}
GM.AmmoCache["ar2"]							= 32		-- Assault rifles.
GM.AmmoCache["alyxgun"]						= 24		-- Not used.
GM.AmmoCache["pistol"]						= 14		-- Pistols.
GM.AmmoCache["smg1"]						= 36		-- SMG's and some rifles.
GM.AmmoCache["357"]							= 8			-- Rifles, especially of the sniper variety.
GM.AmmoCache["xbowbolt"]					= 8			-- Crossbows
GM.AmmoCache["buckshot"]					= 12		-- Shotguns
GM.AmmoCache["ar2altfire"]					= 1			-- Not used.
GM.AmmoCache["slam"]						= 1			-- Force Field Emitters.
GM.AmmoCache["rpg_round"]					= 1			-- Not used. Rockets?
GM.AmmoCache["smg1_grenade"]				= 1			-- Not used.
GM.AmmoCache["sniperround"]					= 1			-- Barricade Kit
GM.AmmoCache["sniperpenetratedround"]		= 1			-- Remote Det pack.
GM.AmmoCache["grenade"]						= 1			-- Grenades.
GM.AmmoCache["thumper"]						= 1			-- Gun turret.
GM.AmmoCache["gravity"]						= 1			-- Unused.
GM.AmmoCache["battery"]						= 23		-- Used with the Medical Kit.
GM.AmmoCache["gaussenergy"]					= 2			-- Nails used with the Carpenter's Hammer.
GM.AmmoCache["combinecannon"]				= 1			-- Not used.
GM.AmmoCache["airboatgun"]					= 1			-- Arsenal crates.
GM.AmmoCache["striderminigun"]				= 1			-- Message beacons.
GM.AmmoCache["helicoptergun"]				= 1			-- Resupply boxes.
GM.AmmoCache["spotlamp"]					= 1
GM.AmmoCache["manhack"]						= 1
GM.AmmoCache["repairfield"]					= 1
GM.AmmoCache["zapper"]						= 1
GM.AmmoCache["pulse"]						= 30
GM.AmmoCache["impactmine"]					= 3
GM.AmmoCache["chemical"]					= 20
GM.AmmoCache["flashbomb"]					= 1
GM.AmmoCache["turret_buckshot"]				= 1
GM.AmmoCache["turret_assault"]				= 1
GM.AmmoCache["scrap"]						= 3

GM.AmmoResupply = table.ToAssoc({"ar2", "pistol", "smg1", "357", "xbowbolt", "buckshot", "battery", "pulse", "impactmine", "chemical", "gaussenergy", "scrap"})
GM:BindRelapseAmmoTables()

-----------
-- Worth --
-----------

GM:AddStartingItem("makarov",			ITEMCAT_GUNS,			15,				"mg_makarov")
GM:AddStartingItem("m1911",				ITEMCAT_GUNS,			15,				"mg_m1911")
GM:AddStartingItem("revolver357",		ITEMCAT_GUNS,			15,				"mg_357")
GM:AddStartingItem("uzi",				ITEMCAT_GUNS,			15,				"mg_uzulu")
GM:AddStartingItem("m680",				ITEMCAT_GUNS,			15,				"mg_romeo870")
GM:AddStartingItem("sks",				ITEMCAT_GUNS,			15,				"mg_sksierra")
GM:AddStartingItem("cwknife",			ITEMCAT_MELEE,			15,				"mg_me_t9loadout")

GM:RegisterRelapseAmmoShopItems()

GM:AddStartingItem("2smgcp",			ITEMCAT_AMMO,			15,				nil,			"72 SMG ammo",					nil,		"ammo_smg",				function(pl) pl:GiveAmmo(72, "smg1", true) end)
GM:AddStartingItem("3smgcp",			ITEMCAT_AMMO,			20,				nil,			"108 SMG ammo",					nil,		"ammo_smg",				function(pl) pl:GiveAmmo(108, "smg1", true) end)
GM:AddStartingItem("2arcp",				ITEMCAT_AMMO,			15,				nil,			"64 assault rifle ammo",		nil,		"ammo_assault",			function(pl) pl:GiveAmmo(64, "ar2", true) end)
GM:AddStartingItem("3arcp",				ITEMCAT_AMMO,			20,				nil,			"96 assault rifle ammo",		nil,		"ammo_assault",			function(pl) pl:GiveAmmo(96, "ar2", true) end)
GM:AddStartingItem("2pls",				ITEMCAT_AMMO,			15,				nil,			"60 pulse ammo",				nil,		"ammo_pulse",			function(pl) pl:GiveAmmo(60, "pulse", true) end)
GM:AddStartingItem("3pls",				ITEMCAT_AMMO,			20,				nil,			"90 pulse ammo",				nil,		"ammo_pulse",			function(pl) pl:GiveAmmo(90, "pulse", true) end)
GM:AddStartingItem("xbow1",				ITEMCAT_AMMO,			15,				nil,			"16 crossbow bolts",			nil,		"ammo_bolts",			function(pl) pl:GiveAmmo(16, "XBowBolt", true) end)
GM:AddStartingItem("xbow2",				ITEMCAT_AMMO,			20,				nil,			"24 crossbow bolts",			nil,		"ammo_bolts",			function(pl) pl:GiveAmmo(24, "XBowBolt", true) end)
GM:AddStartingItem("4mines",			ITEMCAT_AMMO,			15,				nil,			"6 explosives",					nil,		"ammo_explosive",		function(pl) pl:GiveAmmo(6, "impactmine", true) end)
GM:AddStartingItem("6mines",			ITEMCAT_AMMO,			20,				nil,			"9 explosives",					nil,		"ammo_explosive",		function(pl) pl:GiveAmmo(9, "impactmine", true) end)
GM:AddStartingItem("8nails",			ITEMCAT_AMMO,			15,				nil,			"8 nails",						nil, 		"ammo_nail", 			function(pl) pl:GiveAmmo(8, "GaussEnergy", true) end)
GM:AddStartingItem("12nails",			ITEMCAT_AMMO,			20,				nil,			"12 nails",						nil, 		"ammo_nail", 			function(pl) pl:GiveAmmo(12, "GaussEnergy", true) end)
GM:AddStartingItem("60mkit",			ITEMCAT_AMMO,			15,				nil,			"60 medical power",				nil,		"ammo_medpower",		function(pl) pl:GiveAmmo(60, "Battery", true) end)
GM:AddStartingItem("90mkit",			ITEMCAT_AMMO,			25,				nil,			"90 medical power",				nil,		"ammo_medpower",		function(pl) pl:GiveAmmo(90, "Battery", true) end)

local item
GM:AddStartingItem("arscrate",			ITEMCAT_DEPLOYABLES,			50,				"weapon_zs_arsenalcrate")
.Countables = "prop_arsenalcrate"
GM:AddStartingItem("resupplybox",		ITEMCAT_DEPLOYABLES,			50,				"weapon_zs_resupplybox")
.Countables = "prop_resupplybox"
GM:AddStartingItem("remantler",			ITEMCAT_DEPLOYABLES,			50,				"weapon_zs_remantler")
.Countables = "prop_remantler"

GM:AddStartingItem("wrench",			ITEMCAT_TOOLS,			20,				"weapon_zs_wrench").NoClassicMode = true
GM:AddStartingItem("crphmr",			ITEMCAT_TOOLS,			40,				"weapon_zs_hammer").NoClassicMode = true

------------
-- Points --
------------

-- Tier 1
GM:AddPointShopItem("makarov",			ITEMCAT_GUNS,			15,				"mg_makarov", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_makarov") end)
GM:AddPointShopItem("m1911",			ITEMCAT_GUNS,			15,				"mg_m1911", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_m1911") end)
GM:AddPointShopItem("revolver357",		ITEMCAT_GUNS,			15,				"mg_357", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_357") end)
GM:AddPointShopItem("uzi",				ITEMCAT_GUNS,			15,				"mg_uzulu", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_uzulu") end)
GM:AddPointShopItem("m680",				ITEMCAT_GUNS,			15,				"mg_romeo870", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_romeo870") end)
GM:AddPointShopItem("sks",				ITEMCAT_GUNS,			15,				"mg_sksierra", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_sksierra") end)
GM:AddPointShopItem("cwknife",			ITEMCAT_MELEE,			15,				"mg_me_t9loadout", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_me_t9loadout") end)
-- Tier 2
item =
GM:AddPointShopItem("mp5",				ITEMCAT_GUNS,			30,				"mg_mpapa5", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_mpapa5") end)
item.Tier = 2
item =
GM:AddPointShopItem("ump45",			ITEMCAT_GUNS,			30,				"mg_smgolf45", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_smgolf45") end)
item.Tier = 2
item =
GM:AddPointShopItem("m19",				ITEMCAT_GUNS,			30,				"mg_p320", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_p320") end)
item.Tier = 2
-- Tier 3
item =
GM:AddPointShopItem("ak47",				ITEMCAT_GUNS,			45,				"mg_akilo47", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_akilo47") end)
item.Tier = 3
item =
GM:AddPointShopItem("origin12",			ITEMCAT_GUNS,			45,				"mg_oscar12", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_oscar12") end)
item.Tier = 3
item =
GM:AddPointShopItem("m4a1",				ITEMCAT_GUNS,			45,				"mg_mike4", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_mike4") end)
item.Tier = 3
-- Tier 4
item =
GM:AddPointShopItem("asval",			ITEMCAT_GUNS,			55,				"mg_valpha", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_valpha") end)
item.Tier = 4
item =
GM:AddPointShopItem("finn",				ITEMCAT_GUNS,			55,				"mg_sierrax", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_sierrax") end)
item.Tier = 4
item =
GM:AddPointShopItem("jak12",			ITEMCAT_GUNS,			55,				"mg_aalpha12", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_aalpha12") end)
item.Tier = 4
-- Tier 5
item =
GM:AddPointShopItem("scar",				ITEMCAT_GUNS,			70,				"mg_scharlie", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_scharlie") end)
item.Tier = 5
item =
GM:AddPointShopItem("pkm",				ITEMCAT_GUNS,			70,				"mg_pkilo", nil, nil, nil, function(pl) pl:GiveEmptyWeapon("mg_pkilo") end)
item.Tier = 5

GM:AddPointShopItem("smgammo",			ITEMCAT_AMMO,			9,				nil,							"36 SMG ammo",					nil,									"ammo_smg",							function(pl) pl:GiveAmmo(36, "smg1", true) end)
GM:AddPointShopItem("crossbowammo",		ITEMCAT_AMMO,			9,				nil,							"8 crossbow bolts",				nil,									"ammo_bolts",						function(pl) pl:GiveAmmo(8,	"XBowBolt",	true) end)
GM:AddPointShopItem("assaultrifleammo",	ITEMCAT_AMMO,			9,				nil,							"32 assault rifle ammo",		nil,									"ammo_assault",						function(pl) pl:GiveAmmo(32, "ar2", true) end)
GM:AddPointShopItem("pulseammo",		ITEMCAT_AMMO,			9,				nil,							"30 pulse ammo",				nil,									"ammo_pulse",						function(pl) pl:GiveAmmo(30, "pulse", true) end)
GM:AddPointShopItem("impactmine",		ITEMCAT_AMMO,			9,				nil,							"3 explosives",					nil,									"ammo_explosive",					function(pl) pl:GiveAmmo(3, "impactmine", true) end)
GM:AddPointShopItem("chemical",			ITEMCAT_AMMO,			9,				nil,							"20 chemical vials",			nil,									"ammo_chemical",					function(pl) pl:GiveAmmo(20, "chemical", true) end)
item =
GM:AddPointShopItem("25mkit",			ITEMCAT_AMMO,			15,				nil,							"25 Medical Kit power",			"25 extra power for the Medical Kit.",	"ammo_medpower",					function(pl) pl:GiveAmmo(25, "Battery", true) end)
item.CanMakeFromScrap = true
item =
GM:AddPointShopItem("nail",				ITEMCAT_AMMO,			4,				nil,							"Nail",							"It's just one nail.",					"ammo_nail",						function(pl) pl:GiveAmmo(1, "GaussEnergy", true) end)
item.NoClassicMode = true
item.CanMakeFromScrap = true

GM:AddPointShopItem("crphmr",			ITEMCAT_TOOLS,			25,				"weapon_zs_hammer",			nil,							nil,									nil,											function(pl) pl:GiveEmptyWeapon("weapon_zs_hammer") pl:GiveAmmo(5, "GaussEnergy") end)
GM:AddPointShopItem("wrench",			ITEMCAT_TOOLS,			20,				"weapon_zs_wrench").NoClassicMode = true
GM:AddPointShopItem("arsenalcrate",		ITEMCAT_DEPLOYABLES,			40,				"weapon_zs_arsenalcrate").Countables = "prop_arsenalcrate"
GM:AddPointShopItem("resupplybox",		ITEMCAT_DEPLOYABLES,			40,				"weapon_zs_resupplybox").Countables = "prop_resupplybox"
GM:AddPointShopItem("remantler",		ITEMCAT_DEPLOYABLES,			40,				"weapon_zs_remantler").Countables = "prop_remantler"

-- These are the honorable mentions that come at the end of the round.

local function genericcallback(pl, magnitude) return pl:Name(), magnitude end
GM.HonorableMentions = {}
GM.HonorableMentions[HM_MOSTZOMBIESKILLED] = {Name = "Most zombies killed", String = "by %s, with %d killed zombies.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_MOSTDAMAGETOUNDEAD] = {Name = "Most damage to undead", String = "goes to %s, with a total of %d damage dealt to the undead.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_MOSTHEADSHOTS] = {Name = "Most headshot kills", String = "goes to %s, with a total of %s headshot kills.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_PACIFIST] = {Name = "Pacifist", String = "goes to %s for not killing a single zombie and still surviving!", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_MOSTHELPFUL] = {Name = "Most helpful", String = "goes to %s for assisting in the disposal of %d zombies.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_LASTHUMAN] = {Name = "Last Human", String = "goes to %s for being the last person alive.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_OUTLANDER] = {Name = "Outlander", String = "goes to %s for getting killed %d feet away from a zombie spawn.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_GOODDOCTOR] = {Name = "Good Doctor", String = "goes to %s for healing their team for %d points of health.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_HANDYMAN] = {Name = "Handy Man", String = "goes to %s for getting %d barricade assistance points.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_SCARECROW] = {Name = "Scarecrow", String = "goes to %s for killing %d poor crows.", Callback = genericcallback, Color = COLOR_WHITE}
GM.HonorableMentions[HM_MOSTBRAINSEATEN] = {Name = "Most brains eaten", String = "by %s, with %d brains eaten.", Callback = genericcallback, Color = COLOR_LIMEGREEN}
GM.HonorableMentions[HM_MOSTDAMAGETOHUMANS] = {Name = "Most damage to humans", String = "goes to %s, with a total of %d damage given to living players.", Callback = genericcallback, Color = COLOR_LIMEGREEN}
GM.HonorableMentions[HM_LASTBITE] = {Name = "Last Bite", String = "goes to %s for ending the round.", Callback = genericcallback, Color = COLOR_LIMEGREEN}
GM.HonorableMentions[HM_USEFULTOOPPOSITE] = {Name = "Most useful to opposite team", String = "goes to %s for giving up a whopping %d kills!", Callback = genericcallback, Color = COLOR_RED}
GM.HonorableMentions[HM_STUPID] = {Name = "Stupid", String = "is what %s is for getting killed %d feet away from a zombie spawn.", Callback = genericcallback, Color = COLOR_RED}
GM.HonorableMentions[HM_SALESMAN] = {Name = "Salesman", String = "is what %s is for having %d points worth of items taken from their arsenal crate.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_WAREHOUSE] = {Name = "Warehouse", String = "describes %s well since they had their resupply boxes used %d times.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_DEFENCEDMG] = {Name = "Defender", String = "goes to %s for protecting humans from %d damage with defence boosts.", Callback = genericcallback, Color = COLOR_WHITE}
GM.HonorableMentions[HM_STRENGTHDMG] = {Name = "Alchemist", String = "is what %s is for boosting players with an additional %d damage.", Callback = genericcallback, Color = COLOR_CYAN}
GM.HonorableMentions[HM_BARRICADEDESTROYER] = {Name = "Barricade Destroyer", String = "goes to %s for doing %d damage to barricades.", Callback = genericcallback, Color = COLOR_LIMEGREEN}
GM.HonorableMentions[HM_NESTDESTROYER] = {Name = "Nest Destroyer", String = "goes to %s for destroying %d nests.", Callback = genericcallback, Color = COLOR_LIMEGREEN}
GM.HonorableMentions[HM_NESTMASTER] = {Name = "Nest Master", String = "goes to %s for having %d zombies spawn through their nest.", Callback = genericcallback, Color = COLOR_LIMEGREEN}

-- Don't let humans use these models because they look like undead models. Must be lower case.
GM.RestrictedModels = {
	"models/player/zombie_classic.mdl",
	"models/player/zombie_classic_hbfix.mdl",
	"models/player/zombine.mdl",
	"models/player/zombie_soldier.mdl",
	"models/player/zombie_fast.mdl",
	"models/player/corpse1.mdl",
	"models/player/charple.mdl",
	"models/player/skeleton.mdl",
	"models/player/combine_soldier_prisonguard.mdl",
	"models/player/soldier_stripped.mdl",
	"models/player/zelpa/stalker.mdl",
	"models/player/fatty/fatty.mdl",
	"models/player/zombie_lacerator2.mdl"
}

-- If a person has no player model then use one of these (auto-generated).
GM.RandomPlayerModels = {}
for name, mdl in pairs(player_manager.AllValidModels()) do
	if not table.HasValue(GM.RestrictedModels, string.lower(mdl)) then
		table.insert(GM.RandomPlayerModels, name)
	end
end

GM.DeployableInfo = {}
function GM:AddDeployableInfo(class, name, wepclass)
	local tab = {Class = class, Name = name or "?", WepClass = wepclass}

	self.DeployableInfo[#self.DeployableInfo + 1] = tab
	self.DeployableInfo[class] = tab

	return tab
end
GM:AddDeployableInfo("prop_arsenalcrate", 		"Arsenal Crate", 		"weapon_zs_arsenalcrate")
GM:AddDeployableInfo("prop_resupplybox", 		"Resupply Box", 		"weapon_zs_resupplybox")
GM:AddDeployableInfo("prop_remantler", 			"Weapon Remantler", 	"weapon_zs_remantler")
GM:AddDeployableInfo("prop_messagebeacon", 		"Message Beacon", 		"weapon_zs_messagebeacon")
GM:AddDeployableInfo("prop_camera", 			"Camera",	 			"weapon_zs_camera")
GM:AddDeployableInfo("prop_gunturret", 			"Gun Turret",	 		"weapon_zs_gunturret")
GM:AddDeployableInfo("prop_gunturret_assault", 	"Assault Turret",	 	"weapon_zs_gunturret_assault")
GM:AddDeployableInfo("prop_gunturret_buckshot",	"Blast Turret",	 		"weapon_zs_gunturret_buckshot")
GM:AddDeployableInfo("prop_gunturret_rocket",	"Rocket Turret",	 	"weapon_zs_gunturret_rocket")
GM:AddDeployableInfo("prop_repairfield",		"Repair Field Emitter",	"weapon_zs_repairfield")
GM:AddDeployableInfo("prop_zapper",				"Zapper",				"weapon_zs_zapper")
GM:AddDeployableInfo("prop_zapper_arc",			"Arc Zapper",			"weapon_zs_zapper_arc")
GM:AddDeployableInfo("prop_ffemitter",			"Force Field Emitter",	"weapon_zs_ffemitter")
GM:AddDeployableInfo("prop_manhack",			"Manhack",				"weapon_zs_manhack")
GM:AddDeployableInfo("prop_manhack_saw",		"Sawblade Manhack",		"weapon_zs_manhack_saw")
GM:AddDeployableInfo("prop_drone",				"Drone",				"weapon_zs_drone")
GM:AddDeployableInfo("prop_drone_pulse",		"Pulse Drone",			"weapon_zs_drone_pulse")
GM:AddDeployableInfo("prop_drone_hauler",		"Hauler Drone",			"weapon_zs_drone_hauler")
GM:AddDeployableInfo("prop_rollermine",			"Rollermine",			"weapon_zs_rollermine")
GM:AddDeployableInfo("prop_tv",                   	 "TV",                    	"weapon_zs_tv")

GM.MaxSigils = 3

GM.DefaultRedeem = CreateConVar("zs_redeem", "4", FCVAR_REPLICATED + FCVAR_ARCHIVE + FCVAR_NOTIFY, "The amount of kills a zombie needs to do in order to redeem. Set to 0 to disable."):GetInt()
cvars.AddChangeCallback("zs_redeem", function(cvar, oldvalue, newvalue)
	GAMEMODE.DefaultRedeem = math.max(0, tonumber(newvalue) or 0)
end)

-- Relapse does not auto-convert living humans at wave start (no volunteer list).
GM.WaveOneZombies = 0

-- Game feeling too easy? Just change these values!
GM.ZombieSpeedMultiplier = math.Round(CreateConVar("zs_zombiespeedmultiplier", "1", FCVAR_REPLICATED + FCVAR_ARCHIVE + FCVAR_NOTIFY, "Zombie running speed will be scaled by this value."):GetFloat(), 2)
cvars.AddChangeCallback("zs_zombiespeedmultiplier", function(cvar, oldvalue, newvalue)
	GAMEMODE.ZombieSpeedMultiplier = math.ceil(100 * (tonumber(newvalue) or 1)) * 0.01
end)

-- This is a resistance, not for claw damage. 0.5 will make zombies take half damage, 0.25 makes them take 1/4, etc.
GM.ZombieDamageMultiplier = math.Round(CreateConVar("zs_zombiedamagemultiplier", "1", FCVAR_REPLICATED + FCVAR_ARCHIVE + FCVAR_NOTIFY, "Scales the amount of damage that zombies take. Use higher values for easy zombies, lower for harder."):GetFloat(), 2)
cvars.AddChangeCallback("zs_zombiedamagemultiplier", function(cvar, oldvalue, newvalue)
	GAMEMODE.ZombieDamageMultiplier = math.ceil(100 * (tonumber(newvalue) or 1)) * 0.01
end)

GM.TimeLimit = CreateConVar("zs_timelimit", "15", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Time in minutes before the game will change maps. It will not change maps if a round is currently in progress but after the current round ends. -1 means never switch maps. 0 means always switch maps."):GetInt() * 60
cvars.AddChangeCallback("zs_timelimit", function(cvar, oldvalue, newvalue)
	GAMEMODE.TimeLimit = tonumber(newvalue) or 15
	if GAMEMODE.TimeLimit ~= -1 then
		GAMEMODE.TimeLimit = GAMEMODE.TimeLimit * 60
	end
end)

GM.RoundLimit = CreateConVar("zs_roundlimit", "3", FCVAR_ARCHIVE + FCVAR_NOTIFY, "How many times the game can be played on the same map. -1 means infinite or only use time limit. 0 means once."):GetInt()
cvars.AddChangeCallback("zs_roundlimit", function(cvar, oldvalue, newvalue)
	GAMEMODE.RoundLimit = tonumber(newvalue) or 3
end)

-- Static values that don't need convars...

-- Initial length for wave 1.
GM.WaveOneLength = 220

-- Add this many seconds for each additional wave.
GM.TimeAddedPerWave = 15

-- New players are put on the zombie team if the current wave is this or higher. Do not put it lower than 1 or you'll break the game.
GM.NoNewHumansWave = 2

-- Humans can not commit suicide if the current wave is this or lower.
GM.NoSuicideWave = 1

-- How long 'wave 0' should last in seconds. This is the time you should give for new players to join and get ready.
GM.WaveZeroLength = 150

-- Time humans have between waves to do stuff without NEW zombies spawning. Any dead zombies will be in spectator (crow) view and any living ones will still be living.
GM.WaveIntermissionLength = 60

-- Time in seconds between end round and next map.
GM.EndGameTime = 45

-- How many clips of ammo guns from the Worth menu start with. Some guns such as shotguns and sniper rifles have multipliers on this.
GM.SurvivalClips = 4 --2

-- How long do humans have to wait before being able to get more ammo from a resupply box?
GM.ResupplyBoxCooldown = 60

-- Put your unoriginal, 5MB Rob Zombie and Metallica music here.
GM.LastHumanSound = Sound("zombiesurvival/lasthuman.ogg")

-- Sound played when humans all die.
GM.AllLoseSound = Sound("zombiesurvival/music_lose.ogg")

-- Sound played when humans survive.
GM.HumanWinSound = Sound("zombiesurvival/music_win.ogg")

-- Sound played to a person when they die as a human.
GM.DeathSound = Sound("zombiesurvival/human_death_stinger.ogg")

-- Fetch map profiles and node profiles from noxiousnet database?
GM.UseOnlineProfiles = true

-- This multiplier of points will save over to the next round. 1 is full saving. 0 is disabled.
-- Setting this to 0 will not delete saved points and saved points do not "decay" if this is less than 1.
GM.PointSaving = 0

-- Lock item purchases to waves. Tier 2 items can only be purchased on wave 2, tier 3 on wave 3, etc.
-- HIGHLY suggested that this is on if you enable point saving. Always false if objective map, zombie escape, classic mode, or wave number is changed by the map.
GM.LockItemTiers = false

-- Don't save more than this amount of points. 0 for infinite.
GM.PointSavingLimit = 0

-- For Classic Mode
GM.WaveIntermissionLengthClassic = 20
GM.WaveOneLengthClassic = 120
GM.TimeAddedPerWaveClassic = 10

-- Max amount of damage left to tick on these. Any more pending damage is ignored.
GM.MaxPoisonDamage = 50
GM.MaxBleedDamage = 50

-- Give humans this many points when the wave ends.
GM.EndWavePointsBonus = 5

-- Also give humans this many points when the wave ends, multiplied by (wave - 1)
GM.EndWavePointsBonusPerWave = 1
