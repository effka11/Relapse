-- Item usefulness models. Exact U, no snap to 10.
-- U = Scale * TypeMul * Π (factor_i ^ w_i)

local U = GM.Usefulness
U.Models = U.Models or {}

local function factor(stat, spec)
	local pad = spec.pad or 0
	if spec.min then
		stat = math.max(spec.min, stat)
	end
	if spec.max then
		stat = math.min(spec.max, stat)
	end

	if spec.better == "less" then
		return (spec.ref + pad) / (stat + pad)
	end

	return (stat + pad) / (spec.ref + pad)
end

-- Battleaxe is the ranged stick: Scale 400 U.
-- Ammo dollars sit outside Π (AmmoMul), like TypeMul. Stick cartridge 9×18 → 1.
U.Models.ranged = {
	Scale = 400,
	TypeMul = {
		pistol = 1.00,
		smg = 1.00,
		rifle = 1.00,
		shotgun = 1.00,
		sniper = 1.00,
		pulse = 1.00,
		default = 1.00,
	},
	Stats = {
		{id = "Damage", w = 0.35, better = "more", ref = 24, pad = 0, min = 1},
		{id = "FireRate", w = 0.15, better = "more", ref = 5, pad = 0, min = 0.5},
		{id = "Reload", w = 0.10, better = "more", ref = 1, pad = 0, min = 0.2},
		{id = "Mag", w = 0.10, better = "more", ref = 12, pad = 0, min = 1},
		{id = "Accuracy", w = 0.10, better = "less", ref = 1.625, pad = 0.25, min = 0.25},
		{id = "Recoil", w = 0.05, better = "less", ref = 1, pad = 1, min = 0},
		{id = "Kinetic", w = 0.10, better = "more", ref = 1, pad = 0.2, min = 0},
		{id = "Weight", w = 0.05, better = "less", ref = 1, pad = 0.1, min = 0.5},
	},
}

-- Crowbar is the melee stick: Scale 400 U.
-- Stamina / block / parry stay live=false until those systems exist (factor 1).
U.Models.melee = {
	Scale = 400,
	TypeMul = {
		slash = 1.00,
		blunt = 1.00,
		heavy = 1.10,
		pole = 1.05,
		unarmed = 0.80,
		default = 1.00,
	},
	Stats = {
		{id = "Damage", w = 0.35, better = "more", ref = 35, pad = 0, min = 1},
		{id = "StaminaHit", w = 0.10, better = "less", ref = 20, pad = 4, live = false},
		{id = "StaminaMiss", w = 0.05, better = "less", ref = 12, pad = 3, live = false},
		{id = "SwingDelay", w = 0.15, better = "less", ref = 0.4, pad = 0.2, min = 0.15, max = 2},
		{id = "Stopping", w = 0.10, better = "more", ref = 110, pad = 40, min = 0},
		{id = "AttackSpeed", w = 0.10, better = "more", ref = 1 / 0.7, pad = 0, min = 0.25},
		{id = "BlockStability", w = 0.10, better = "more", ref = 50, pad = 10, live = false},
		{id = "ParryWindow", w = 0.05, better = "more", ref = 0.15, pad = 0.05, live = false},
	},
}

function GM:ComputeUsefulnessRaw(kind, values)
	local model = U.Models[kind]
	if not model or not values then
		return 0
	end

	local raw = model.Scale * (model.TypeMul[values.Type or "default"] or 1)

	for _, spec in ipairs(model.Stats) do
		if spec.live ~= false then
			local stat = values[spec.id]
			if stat == nil then
				stat = spec.ref
			end
			raw = raw * factor(stat, spec) ^ spec.w
		end
	end

	return raw
end

function GM:ComputeUsefulness(kind, values)
	return self:ComputeUsefulnessRaw(kind, values)
end

local function rangedWeaponClass(swep, prim, shots)
	local class = "default"
	local hold = string.lower(swep.HoldType or "")
	if shots >= 4 then
		class = "shotgun"
	elseif prim.Ammo == "pulse" then
		class = "pulse"
	elseif hold == "ar2" then
		class = "rifle"
	elseif hold == "smg" then
		class = "smg"
	elseif hold == "pistol" then
		class = "pistol"
	end

	return class
end

function GM:ExtractRangedUsefulnessValues(swep)
	if not swep then return nil end

	local prim = swep.Primary or {}
	local r = swep.Relapse
	local shots = math.max((r and r.Pellets) or prim.NumShots or 1, 1)
	local class = rangedWeaponClass(swep, prim, shots)

	-- Relapse table is seconds / kg / falloff. Convert into the stick units the model already uses.
	if r then
		return {
			Type = class,
			Damage = (r.Damage or 0) * shots,
			FireRate = 1 / math.max(r.Delay or 0.2, 0.05),
			Reload = 2 / math.max(r.Reload or 2, 0.2),
			Mag = r.Clip or prim.ClipSize or 1,
			Accuracy = r.Accuracy or 1.625,
			Recoil = r.Recoil or 0,
			Kinetic = 1 - math.Clamp(r.Kinetic or 0, 0, 1),
			Weight = math.max(r.Weight or 1, 0.1),
		}
	end

	local delay = math.max(prim.Delay or 0.2, 0.05)
	local cone_max = swep.ConeMax or 1.5
	local cone_min = swep.ConeMin or cone_max
	local walk = swep.WalkSpeed or SPEED_NORMAL
	local recoil = swep.Recoil
	if type(recoil) == "table" then
		recoil = 1
	end

	return {
		Type = class,
		Damage = (prim.Damage or 0) * shots,
		FireRate = 1 / delay,
		Reload = swep.ReloadSpeed or 1,
		Mag = prim.ClipSize or 1,
		Accuracy = (cone_min + cone_max) / 2,
		Recoil = recoil or 0,
		Kinetic = prim.KnockbackScale or 1,
		Weight = SPEED_NORMAL / math.max(walk, 1),
	}
end

function GM:ExtractMeleeUsefulnessValues(swep)
	if not swep then return nil end

	local r = swep.Relapse
	if r and r.Melee then
		return {
			Type = r.Type or "slash",
			Damage = r.Damage or 0,
			SwingDelay = r.Swing or 0,
			Stopping = r.Stopping or 0,
			AttackSpeed = 1 / math.max(r.Delay or 0.7, 0.1),
		}
	end

	local delay = math.max(swep.Primary and swep.Primary.Delay or 1, 0.1)
	local hold = string.lower(swep.HoldType or "")
	local class = "blunt"
	if swep.Unarmed or hold == "fist" then
		class = "unarmed"
	elseif hold == "knife" then
		class = "slash"
	elseif hold == "melee2" then
		class = "heavy"
	elseif (swep.MeleeRange or 0) >= 68 then
		class = "pole"
	elseif swep.DamageType == DMG_SLASH then
		class = "slash"
	end

	return {
		Type = class,
		Damage = swep.MeleeDamage or 0,
		SwingDelay = swep.SwingTime or 0,
		Stopping = swep.MeleeKnockBack or 0,
		AttackSpeed = 1 / delay,
	}
end

function GM:GetWeaponAmmoMul(swep)
	local ammo = self:GetRelapseAmmo(self:GetWeaponAmmoType(swep))
	if not ammo or not ammo.Dollars then
		return 1
	end

	local price = self.RelapseAmmoPrice
	if not price or ammo.Dollars <= 0 then
		return 1
	end

	return (price.StickDollars / ammo.Dollars) ^ (price.AmmoMulW or 0)
end

function GM:ComputeWeaponCombatUsefulness(swep)
	if not swep then return 0 end
	local r = swep.Relapse
	if swep.IsMelee or (r and r.Melee) then
		return self:ComputeUsefulness("melee", self:ExtractMeleeUsefulnessValues(swep))
	end

	return self:ComputeUsefulness("ranged", self:ExtractRangedUsefulnessValues(swep))
end

function GM:ComputeWeaponUsefulness(swep)
	local combat = self:ComputeWeaponCombatUsefulness(swep)
	if not swep or swep.IsMelee then
		return combat
	end

	return combat * self:GetWeaponAmmoMul(swep)
end

-- Fraction of recoup cost that is the gun. Higher = ammo eats less.
-- HP to earn U_combat back in damage points, then ammo U for those shots.
function GM:ComputeWeaponPayback(swep)
	if not swep or swep.IsMelee then
		return nil
	end

	local values = self:ExtractRangedUsefulnessValues(swep)
	if not values then
		return nil
	end

	local combat = self:ComputeUsefulness("ranged", values)
	local damage = values.Damage or 0
	if combat <= 0 or damage <= 0 then
		return nil
	end

	local uPoint = self:GetPointUsefulness()
	local uRound = self:GetAmmoRoundUsefulness(self:GetWeaponAmmoType(swep))
	local hp = (combat / uPoint) * 45
	local uAmmo = (hp / damage) * uRound
	return combat / (combat + uAmmo)
end

-- U per 1 point and per 1 worth. Shelf prices are separate: T1 shop and worth are 40.
U.ShopT1Price = 15
U.WorthT1Price = U.ShopT1Price

-- Battleaxe stats as the model scores them (recoil 0 is a real bump over Scale).
function GM:GetStickRangedUsefulness()
	return self:ComputeUsefulness("ranged", {
		Type = "pistol",
		Damage = 24,
		FireRate = 5,
		Reload = 1,
		Mag = 12,
		Accuracy = 1.625,
		Recoil = 0,
		Kinetic = 1,
		Weight = 1,
	})
end

-- Shop U per 1 point (and per 1 worth). Stick / T1 price. Not T5.
function GM:GetPointUsefulness()
	return self:GetStickRangedUsefulness() / U.ShopT1Price
end

function GM:GetWorthUsefulness()
	return self:GetStickRangedUsefulness() / U.WorthT1Price
end

-- Shop scores (1–99). Hill n=1.4: extremes approach 1 and 100, never cross.
-- ref is an independent mid-game gun (score 50), not T1.
-- Stability = spread + recoil in one cone-ish error. Recoil always counts (kick),
-- not only leftover between shots.
GM.RelapseRecoilToCone = 1.2
GM.RelapseShopHillN = 1.4
GM.RelapseShopScoreSpec = {
	Damage = {ref = 34, better = "more"}, -- ~T2/T3 body damage
	FireRate = {ref = 520, better = "more"}, -- RPM, slow SMG
	Stability = {ref = 2.80, better = "less"}, -- Accuracy + Recoil*k of a typical gun
	Reload = {ref = 1.85, better = "less"}, -- seconds, mixed rifle/SMG reload
	Clip = {ref = 24, better = "more"}, -- mid rifle mag
	Weight = {ref = 2.8, better = "less"}, -- kg of a typical carbine
	Stamina = {ref = 0.055, better = "less"}, -- tank fraction per swing, machete
}

-- Relapse tables live here so the shop still scores a gun if workshop SWEP won.
-- Shop icons: 256x256 RGBA PNG, white RGB, alpha silhouette, path WITH .png, no VMT.
-- A .vmt/.vtf next to the PNG makes the card a cyan rectangle. Do not use CAC spawnicons.
GM.RelapseWeapons = {
	mg_makarov = {
		PrintName = "Пистолет Макарова",
		Description = "A compact service sidearm. Issued to everyone and valued by no one\194\160\194\160–\194\160\194\160until there was nothing else left.",
		TranslationName = "wep_makarov",
		TranslationDescription = "wep_makarov_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_makarov3.png",
		PreviewParts = {
			"models/viper/mw/attachments/attachment_vm_pi_mike_barrel.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_mike_grip.mdl",
		},
		PreviewAngle = Angle(0, 90, 0),
		PreviewLift = 0.5,
		PreviewCamScale = 1.65,
		Ammo = "9x18",
		Relapse = {
			Damage = 20,
			Delay = 0.20,
			Reload = 1.66,
			Kinetic = 0.40,
			Recoil = 0.55,
			Accuracy = 1.50,
			Weight = 0.73,
			Clip = 8,
		}
	},
	mg_fists = {
		PrintName = "Кулаки",
		Description = "Your hands. They reach the one in front of you, not the one in the doorway.",
		TranslationName = "wep_fists",
		TranslationDescription = "wep_fists_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_fists",
		IsMelee = true,
		Unarmed = true,
		IsFistWeapon = true,
		Undroppable = true,
		NoDismantle = true,
		NoPickupNotification = true,
		NoGlassWeapons = true,
		Relapse = {
			Melee = true,
			Type = "unarmed",
			Damage = 15,
			Delay = 0.6,
			Swing = 0.25,
			Stopping = 0,
			Range = 40,
			Weight = 0,
			Stamina = 0.024,
			DamageType = DMG_CLUB,
		}
	},
	mg_me_t9loadout = {
		PrintName = "Нож",
		Description = "A service knife. It reaches the one in the doorway, not the one behind him.",
		TranslationName = "wep_cwknife",
		TranslationDescription = "wep_cwknife_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cwknife2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/easy/cw/weapons/wm_me_t9loadout.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 135),
		PreviewOffset = Vector(0, 0, -1),
		PreviewLift = 0.7,
		PreviewCamScale = 1.0,
		IsMelee = true,
		Tier = 2,
		Relapse = {
			Melee = true,
			Type = "slash",
			Damage = 33,
			Delay = 0.55,
			Swing = 0.20,
			Stopping = 40,
			Range = 48,
			Weight = 0.32,
			Stamina = 0.028,
		}
	},
	mg_me_t9bat = {
		PrintName = "Бита",
		Description = "A baseball bat. Wood, not an edge: it reaches the one in the doorway, not the one behind him.",
		TranslationName = "wep_cwbat",
		TranslationDescription = "wep_cwbat_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cwbat2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/easy/cw/weapons/wm_me_t9bat.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 45),
		PreviewOffset = Vector(0, 0, -1),
		PreviewLift = 0.7,
		PreviewCamScale = 1.4,
		IsMelee = true,
		Tier = 2,
		Relapse = {
			Melee = true,
			Type = "blunt",
			Damage = 33,
			Delay = 0.70,
			Swing = 0.35,
			Stopping = 65,
			Range = 56,
			Weight = 0.90,
			Stamina = 0.058,
			DamageType = DMG_CLUB,
		}
	},
	mg_me_t9etool = {
		PrintName = "Лопата",
		Description = "A folding shovel. Steel, not a stick: it reaches the one in the doorway, not the one behind him.",
		TranslationName = "wep_cwetool",
		TranslationDescription = "wep_cwetool_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cwetool2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/easy/cw/weapons/wm_me_t9etool.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 45),
		PreviewOffset = Vector(0, 0, -1),
		PreviewLift = 0.7,
		PreviewCamScale = 1.0,
		IsMelee = true,
		Tier = 2,
		Relapse = {
			Melee = true,
			Type = "blunt",
			Damage = 33,
			Delay = 0.62,
			Swing = 0.25,
			Stopping = 50,
			Range = 52,
			Weight = 0.80,
			Stamina = 0.050,
			DamageType = DMG_CLUB,
		}
	},
	mg_me_t9cane = {
		PrintName = "Трость",
		Description = "A walking cane. Wood, not an edge: it reaches the one in the doorway, if you have the time.",
		TranslationName = "wep_cwcane",
		TranslationDescription = "wep_cwcane_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cwcane2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/easy/cw/weapons/wm_me_t9cane.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 45),
		PreviewOffset = Vector(0, 0, -1),
		PreviewLift = 0.7,
		PreviewCamScale = 1.4,
		IsMelee = true,
		Relapse = {
			Melee = true,
			Type = "blunt",
			Damage = 25,
			Delay = 0.75,
			Swing = 0.40,
			Stopping = 55,
			Range = 54,
			Weight = 0.50,
			Stamina = 0.042,
			DamageType = DMG_CLUB,
		}
	},
	mg_cinderblock = {
		PrintName = "Шлакоблок",
		Description = "A concrete block. It drops the one in front of you, not the one in the doorway.",
		TranslationName = "wep_cinderblock",
		TranslationDescription = "wep_cinderblock_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cinderblock.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_cinderblock.mdl",
		},
		PreviewAngle = Angle(0, 90, 0),
		PreviewOffset = Vector(0, 0, 0),
		PreviewLift = 0.7,
		PreviewCamScale = 1.6,
		IsMelee = true,
		Relapse = {
			Melee = true,
			Type = "blunt",
			Damage = 25,
			Delay = 1.00,
			Swing = 0.25,
			Stopping = 70,
			Range = 44,
			Weight = 12.00,
			Stamina = 0.160,
			DamageType = DMG_CLUB,
		}
	},
	mg_me_t9machete = {
		PrintName = "Мачете",
		Description = "A long blade. It reaches the one behind the doorway, not the one in the next room.",
		TranslationName = "wep_cwmachete",
		TranslationDescription = "wep_cwmachete_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cwmachete2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/easy/cw/weapons/wm_me_t9machete.mdl",
		},
		PreviewClipZ = -4.12,
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 45),
		PreviewOffset = Vector(0, 0, -1),
		PreviewLift = 0.7,
		PreviewCamScale = 1.0,
		IsMelee = true,
		Tier = 3,
		Relapse = {
			Melee = true,
			Type = "slash",
			Damage = 45,
			Delay = 0.70,
			Swing = 0.28,
			Stopping = 75,
			Range = 58,
			Weight = 0.65,
			Stamina = 0.055,
		}
	},
	mg_me_t9wakizashi = {
		PrintName = "Вакидзаси",
		Description = "A short sword. Light steel: it cuts the one behind the doorway, not the one in the next room.",
		TranslationName = "wep_cwwakizashi",
		TranslationDescription = "wep_cwwakizashi_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cwwakizashi.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = false,
		PreviewParts = {
			"models/easy/cw/weapons/wm_me_t9wakizashi.mdl",
		},
		PreviewAngle = Angle(0, 90, 0),
		PreviewLocalAng = Angle(0, 0, 45),
		PreviewOffset = Vector(0, 0, 0),
		PreviewLift = 0.7,
		PreviewCamScale = 1.0,
		IsMelee = true,
		Tier = 4,
		Relapse = {
			Melee = true,
			Type = "slash",
			Damage = 57,
			Delay = 0.62,
			Swing = 0.24,
			Stopping = 80,
			Range = 62,
			Weight = 0.55,
			Stamina = 0.046,
		}
	},
	mg_me_t9scythe = {
		PrintName = "Коса",
		Description = "A two-handed scythe. It reaches the one in the next room, not the one across the street.",
		TranslationName = "wep_cwscythe",
		TranslationDescription = "wep_cwscythe_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cwscythe2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/easy/cw/weapons/wm_me_t9scythe.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 45),
		PreviewOffset = Vector(0, 0, -2),
		PreviewLift = 0.7,
		PreviewCamScale = 1.4,
		IsMelee = true,
		Tier = 5,
		Relapse = {
			Melee = true,
			Type = "pole",
			Damage = 75,
			Delay = 1.00,
			Swing = 0.40,
			Stopping = 95,
			Range = 75,
			Weight = 2.00,
			Stamina = 0.090,
		}
	},
	mg_me_t9sledgehammer = {
		PrintName = "Кувалда",
		Description = "A sledgehammer. Steel, not an edge: it drops the one behind the doorway, not the one in the next room.",
		TranslationName = "wep_cwsledge",
		TranslationDescription = "wep_cwsledge_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_cwsledge2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/easy/cw/weapons/wm_me_t9sledgehammer.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 45),
		PreviewOffset = Vector(0, 0, -1),
		PreviewLift = 0.7,
		PreviewCamScale = 1.4,
		IsMelee = true,
		Tier = 5,
		Relapse = {
			Melee = true,
			Type = "heavy",
			Damage = 75,
			Delay = 1.20,
			Swing = 0.50,
			Stopping = 120,
			Range = 60,
			Weight = 8.00,
			Stamina = 0.145,
			DamageType = DMG_CLUB,
		}
	},
	mg_m1911 = {
		PrintName = "Кольт 1911",
		Description = "An officer's Colt. Seven fat .45s: heavy in a room\194\160\194\160–\194\160\194\160just loud past it.",
		TranslationName = "wep_1911",
		TranslationDescription = "wep_1911_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_colt1911_3.png",
		PreviewBoneMerge = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_m1911.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_mike1911_v1_slide.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_mike1911_v1_mag.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(-0.8, 0, 0.5),
		PreviewLift = 0.7,
		PreviewCamScale = 1.4,
		Ammo = "45acp",
		Relapse = {
			Damage = 28,
			Delay = 0.21,
			Reload = 1.35,
			Kinetic = 0.45,
			Recoil = 0.80,
			Accuracy = 1.25,
			Weight = 1.10,
			Clip = 7,
		}
	},
	mg_p320 = {
		PrintName = "M19",
		Description = "A duty pistol. Seventeen 9×19s: the mag lasts, the trigger does not wait.",
		TranslationName = "wep_m19",
		TranslationDescription = "wep_m19_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_m19_side2.png",
		PreviewBoneMerge = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_p320.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_papa320_slide.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_papa320_mag.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(-0.8, 0, 0.5),
		PreviewLift = 0.7,
		PreviewCamScale = 1.4,
		Ammo = "9x19",
		Tier = 2,
		Relapse = {
			Damage = 23,
			Delay = 0.15,
			Reload = 1.5,
			Kinetic = 0.36,
			Recoil = 0.65,
			Accuracy = 1.30,
			Weight = 0.83,
			Clip = 17,
			Automatic = false,
		}
	},
	mg_sbeta = {
		PrintName = "MK2",
		Description = "A lever carbine. Six .30-30s: one shot, then the lever waits.",
		TranslationName = "wep_mk2",
		TranslationDescription = "wep_mk2_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_mk2_side3.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_sbeta.mdl",
			"models/viper/mw/attachments/sbeta/attachment_vm_sn_sbeta_barrel.mdl",
		},
		-- Default stock is att_stock (already on WM). Default optic is irons.
		-- DrawModel after SetupBones is +Z like SKS. WM variant 0 — do not copy MP5 [0]=1.
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -5),
		PreviewLift = 3.5,
		PreviewCamScale = 1.4,
		Ammo = "3030win",
		Tier = 2,
		Relapse = {
			Damage = 45,
			Delay = 0.50,
			Reload = 3.95,
			Kinetic = 0.18,
			Recoil = 1.25,
			Accuracy = 0.85,
			Weight = 2.90,
			Clip = 6,
			Automatic = false,
			Hitscan = true,
		}
	},
	mg_357 = {
		PrintName = "Револьвер .357",
		Description = "They carried it if six shots were enough. The trigger does not hurry, the hit does. It's worth aiming.",
		TranslationName = "wep_357",
		TranslationDescription = "wep_357_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_python357_3.png",
		PreviewBoneMerge = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_357.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_cpapa_barrel.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewLift = 0.7,
		PreviewCamScale = 1.65,
		Ammo = "357mag",
		Relapse = {
			Damage = 42,
			Delay = 0.43,
			Reload = 3.00,
			Kinetic = 0.28,
			Recoil = 1.20,
			Accuracy = 1.05,
			Weight = 1.30,
			Clip = 6,
		}
	},
	mg_romeo870 = {
		PrintName = "Дробовик 680",
		Description = "A patrol pump. For a hallway, not a field: it drops them at the door, then the shot wanders. Then the forend.",
		TranslationName = "wep_680",
		TranslationDescription = "wep_680_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_model680_3.png",
		PreviewParts = {
			"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_receiver.mdl",
			"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_barrel.mdl",
			"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_pump.mdl",
		},
		PreviewAngle = Angle(0, 90, 0),
		PreviewOffset = Vector(0, 0, -1.2),
		PreviewLift = 2.2,
		PreviewCamScale = 1.4,
		Ammo = "12ga",
		Relapse = {
			Damage = 16,
			Pellets = 9,
			Delay = 0.70,
			Reload = 5.00,
			Kinetic = 0.62,
			Recoil = 1.55,
			Accuracy = 4.80,
			Weight = 3.40,
			Clip = 6,
		}
	},
	mg_sksierra = {
		PrintName = "СКС",
		Description = "A warehouse carbine. The army is gone, ten 7.62s remain: it reaches past the pistols, the mag does not hurry.",
		TranslationName = "wep_sks",
		TranslationDescription = "wep_sks_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_sks_side4.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_sksierra.mdl",
			"models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_barrel.mdl",
			"models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_mag.mdl",
			"models/viper/mw/attachments/sksierra/attachment_vm_sn_sksierra_stock.mdl",
		},
		-- DrawModel after SetupBones is along +Z (WM hull), like 1911. Bind-pose VVD is +X —
		-- Makarov yaw 90 stands the rifle on end. Dummy AABB must be GetRenderBounds, not
		-- GetModelMeshes, or extras in posed space mix with a +X box and the orbit looks down on the rail.
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -5),
		PreviewLift = 3.5,
		PreviewCamScale = 1.4,
		Ammo = "762x39",
		Relapse = {
			Damage = 34,
			Delay = 0.22,
			Reload = 2.70,
			Kinetic = 0.20,
			Recoil = 1.10,
			Accuracy = 0.95,
			Weight = 3.85,
			Clip = 10,
		}
	},
	mg_akilo47 = {
		PrintName = "АК-47",
		Description = "A warehouse automatic. Thirty 7.62×39s: the SKS's brass, a mag that empties.",
		TranslationName = "wep_ak47",
		TranslationDescription = "wep_ak47_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_ak47_side3.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_akilo47.mdl",
			"models/viper/mw/attachments/akilo47/attachment_vm_ar_akilo47_barrel.mdl",
			"models/viper/mw/attachments/akilo47/attachment_vm_ar_akilo47_mag.mdl",
			"models/viper/mw/attachments/akilo47/attachment_vm_ar_akilo47_stock.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "762x39",
		Tier = 3,
		Relapse = {
			Damage = 24,
			Delay = 0.10,
			Reload = 2.45,
			Kinetic = 0.22,
			Recoil = 1.25,
			Accuracy = 1.20,
			Weight = 3.47,
			Clip = 30,
			Automatic = true,
		}
	},
	mg_mike4 = {
		PrintName = "M4A1",
		Description = "A duty carbine. Thirty 5.56×45s: lighter than the AK, the mag still ends.",
		TranslationName = "wep_m4a1",
		TranslationDescription = "wep_m4a1_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_m4a1_side4.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_mike4.mdl",
			"models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_receiver.mdl",
			"models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_barrel.mdl",
			"models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_mag.mdl",
			"models/viper/mw/attachments/mike4/attachment_vm_ar_mike4_stock.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "556x45",
		Tier = 3,
		Relapse = {
			Damage = 20,
			Delay = 0.075,
			Reload = 2.2,
			Kinetic = 0.28,
			Recoil = 0.85,
			Accuracy = 1.10,
			Weight = 2.88,
			Clip = 30,
			Automatic = true,
		}
	},
	mg_oscar12 = {
		PrintName = "Origin-12",
		Description = "A mag-fed 12 gauge. Eight shells: the pump's brass, a trigger that does not wait.",
		TranslationName = "wep_origin12",
		TranslationDescription = "wep_origin12_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_origin12_side4.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_oscar12.mdl",
			"models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_barrel.mdl",
			"models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_mag.mdl",
			"models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_stock.mdl",
			"models/viper/mw/attachments/oscar12/attachment_vm_sh_oscar12_sidegrip.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "12ga",
		Tier = 3,
		Relapse = {
			Damage = 12,
			Pellets = 9,
			Delay = 0.32,
			Reload = 2.45,
			Kinetic = 0.62,
			Recoil = 1.45,
			Accuracy = 4.80,
			Weight = 4.15,
			Clip = 8,
			Automatic = false,
		}
	},
	mg_valpha = {
		PrintName = "АС «Вал»",
		Description = "An integrally suppressed carbine. Twenty 9×39s: it stays quiet, the mag does not last.",
		TranslationName = "wep_asval",
		TranslationDescription = "wep_asval_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_asval_side2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_valpha.mdl",
			"models/viper/mw/attachments/valpha/attachment_vm_ar_valpha_barrel.mdl",
			"models/viper/mw/attachments/valpha/attachment_vm_ar_valpha_mag.mdl",
			"models/viper/mw/attachments/valpha/attachment_vm_ar_valpha_stock.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "9x39",
		Tier = 4,
		Relapse = {
			Damage = 18,
			Delay = 0.068,
			Reload = 2.45,
			Kinetic = 0.30,
			Recoil = 0.90,
			Accuracy = 1.35,
			Weight = 2.50,
			Clip = 20,
			Automatic = true,
		}
	},
	mg_sierrax = {
		PrintName = "FiNN LMG",
		Description = "A box-fed LMG. Seventy-five 5.56×45: the box lasts, the recoil stays flat.",
		TranslationName = "wep_finn",
		TranslationDescription = "wep_finn_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_finn_side3.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_sierrax.mdl",
			"models/viper/mw/attachments/sierrax/attachment_vm_lm_sierrax_barrel.mdl",
			"models/viper/mw/attachments/sierrax/attachment_vm_lm_sierrax_mag.mdl",
			"models/viper/mw/attachments/sierrax/attachment_vm_lm_sierrax_stock.mdl",
		},
		PreviewAngle = Angle(0, 90, 0),
		PreviewLocalAng = Angle(0, 0, 0),
		PreviewOffset = Vector(-6, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "556x45",
		Tier = 4,
		Relapse = {
			Damage = 23,
			Delay = 0.095,
			Reload = 5.5,
			Kinetic = 0.22,
			Recoil = 0.90,
			Accuracy = 1.15,
			Weight = 5.10,
			Clip = 75,
			Automatic = true,
		}
	},
	mg_aalpha12 = {
		PrintName = "JAK-12",
		Description = "A full-auto 12 gauge. Eight shells: Origin's brass, a trigger that does not let go.",
		TranslationName = "wep_jak12",
		TranslationDescription = "wep_jak12_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_jak12_side5.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_aalpha12.mdl",
			"models/viper/mw/attachments/aalpha12/attachment_vm_sh_aalpha12_barrel.mdl",
			"models/viper/mw/attachments/aalpha12/attachment_vm_sh_aalpha12_mag.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.0,
		Ammo = "12ga",
		Tier = 4,
		Relapse = {
			Damage = 8,
			Pellets = 9,
			Delay = 0.20,
			Reload = 2.5,
			Kinetic = 0.62,
			Recoil = 1.50,
			Accuracy = 4.80,
			Weight = 4.76,
			Clip = 8,
			Automatic = true,
		}
	},
	mg_scharlie = {
		PrintName = "SCAR-H",
		Description = "A battle rifle. Twenty 7.62×51: it reaches past the carbines, the mag still ends.",
		TranslationName = "wep_scar",
		TranslationDescription = "wep_scar_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_scar_side2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_scharlie.mdl",
			"models/viper/mw/attachments/attachment_vm_ar_scharlie_barrel.mdl",
			"models/viper/mw/attachments/attachment_vm_ar_scharlie_mag.mdl",
			"models/viper/mw/attachments/attachment_vm_ar_scharlie_stock.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "762x51",
		Tier = 5,
		Relapse = {
			Damage = 30,
			Delay = 0.105,
			Reload = 2.40,
			Kinetic = 0.18,
			Recoil = 1.40,
			Accuracy = 1.05,
			Weight = 3.58,
			Clip = 20,
			Automatic = true,
		}
	},
	mg_pkilo = {
		PrintName = "ПКМ",
		Description = "A belt-fed GPMG. A hundred 7.62×54R: the belt lasts, the reload does not hurry.",
		TranslationName = "wep_pkm",
		TranslationDescription = "wep_pkm_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_pkm_side2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_pkilo.mdl",
			"models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_barrel.mdl",
			"models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_mag.mdl",
			"models/viper/mw/attachments/pkilo/attachment_vm_lm_pkilo_stock.mdl",
		},
		PreviewAngle = Angle(0, 90, 0),
		PreviewLocalAng = Angle(0, 0, 0),
		PreviewOffset = Vector(-6, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "762x54r",
		Tier = 5,
		Relapse = {
			Damage = 26,
			Delay = 0.092,
			Reload = 8.65,
			Kinetic = 0.17,
			Recoil = 1.35,
			Accuracy = 1.20,
			Weight = 7.50,
			Clip = 100,
			Automatic = true,
		}
	},
	mg_falima = {
		PrintName = "FAL",
		Description = "A battle rifle. Twenty 7.62×51: one shot, then the trigger waits.",
		TranslationName = "wep_fal",
		TranslationDescription = "wep_fal_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_fal_side2.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_falima.mdl",
			"models/viper/mw/attachments/falima/attachment_vm_ar_falima_reciever.mdl",
			"models/viper/mw/attachments/falima/attachment_vm_ar_falima_barrel.mdl",
			"models/viper/mw/attachments/falima/attachment_vm_ar_falima_mag.mdl",
			"models/viper/mw/attachments/falima/attachment_vm_ar_falima_stock.mdl",
			"models/viper/mw/attachments/falima/attachment_vm_ar_falima_forend.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "762x51",
		Tier = 5,
		Relapse = {
			Damage = 38,
			Delay = 0.16,
			Reload = 2.6,
			Kinetic = 0.16,
			Recoil = 1.45,
			Accuracy = 0.95,
			Weight = 4.25,
			Clip = 20,
			Automatic = false,
		}
	},
	mg_alpha50 = {
		PrintName = "AX-50",
		Description = "A bolt-action sniper. Five .50 BMG: one shot, then the bolt waits.",
		TranslationName = "wep_ax50",
		TranslationDescription = "wep_ax50_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_ax50_side3.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_alpha50.mdl",
			"models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_barrel.mdl",
			"models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_mag.mdl",
			"models/viper/mw/attachments/alpha50/attachment_vm_sn_alpha50_stock.mdl",
		},
		PreviewAngle = Angle(0, 90, 0),
		PreviewLocalAng = Angle(0, 0, 0),
		PreviewOffset = Vector(-6, 0, -3),
		PreviewLift = 2.8,
		PreviewCamScale = 1.4,
		Ammo = "50bmg",
		Tier = 5,
		Relapse = {
			Damage = 113,
			Delay = 1.30,
			Reload = 3.03,
			Kinetic = 0.10,
			Recoil = 2.20,
			Accuracy = 0.50,
			Weight = 12.50,
			Clip = 5,
			Automatic = false,
		}
	},
	mg_smgolf45 = {
		PrintName = "UMP-45",
		Description = "A duty .45 SMG. Twenty-five rounds: heavier than the nines, the mag is shorter.",
		TranslationName = "wep_ump45",
		TranslationDescription = "wep_ump45_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_ump45_side3.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewBodygroups = { [0] = 1 },
		PreviewParts = {
			"models/viper/mw/weapons/w_smgolf45.mdl",
			"models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_receiver.mdl",
			"models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_barrel.mdl",
			"models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_mag.mdl",
			"models/viper/mw/attachments/smgolf45/attachment_vm_sm_smgolf45_stock.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -2),
		PreviewLift = 2.2,
		PreviewCamScale = 1.6,
		Ammo = "45acp",
		Tier = 2,
		Relapse = {
			Damage = 22,
			Delay = 0.10,
			Reload = 2.60,
			Kinetic = 0.35,
			Recoil = 1.00,
			Accuracy = 2.10,
			Weight = 2.50,
			Clip = 25,
			Automatic = true,
		}
	},
	mg_mpapa5 = {
		PrintName = "MP5",
		Description = "A duty SMG. Thirty 9×19s, closed bolt: it hits where you point, then the mag is empty.",
		TranslationName = "wep_mp5",
		TranslationDescription = "wep_mp5_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_mp5_side7.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewBodygroups = { [0] = 1 },
		PreviewParts = {
			"models/viper/mw/weapons/w_mpapa5.mdl",
			"models/viper/mw/attachments/mpapa5/attachment_vm_sm_mpapa5_barrel.mdl",
			"models/viper/mw/attachments/mpapa5/attachment_vm_sm_mpapa5_mag.mdl",
			"models/viper/mw/attachments/mpapa5/attachment_vm_sm_mpapa5_stock.mdl",
		},
		-- WM variant 1 is the receiver only. Mag/stock/barrel on tag_*_attach like SKS.
		-- DrawModel along +Z: hull + LocalAng 90. Frame like Uzi (not SKS Lift 3.5).
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, -2),
		PreviewLift = 2.2,
		PreviewCamScale = 1.4,
		Ammo = "9x19",
		Tier = 2,
		Relapse = {
			Damage = 16,
			Delay = 0.075,
			Reload = 2.20,
			Kinetic = 0.32,
			Recoil = 0.70,
			Accuracy = 2.20,
			Weight = 3.10,
			Clip = 30,
			Automatic = true,
		}
	},
	mg_uzulu = {
		PrintName = "Uzi",
		Description = "An open-bolt spray. Thirty-two 9×19s: it does not aim, it empties.",
		TranslationName = "wep_uzi",
		TranslationDescription = "wep_uzi_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_uzi_side8.png",
		PreviewBoneMerge = true,
		PreviewHullBounds = true,
		PreviewBodygroups = { [0] = 1 },
		PreviewParts = {
			"models/viper/mw/weapons/w_uzulu.mdl",
		},
		-- DrawModel after SetupBones is +Z (yaw 90 stands the SMG up). Frame the hull
		-- like SKS; mesh AABB is bind +X and would look down the barrel.
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		PreviewOffset = Vector(0, 0, 0),
		PreviewLift = 2.2,
		PreviewCamScale = 1.4,
		Ammo = "9x19",
		Relapse = {
			Damage = 16,
			Delay = 0.10,
			Reload = 2.50,
			Kinetic = 0.38,
			Recoil = 0.95,
			Accuracy = 3.10,
			Weight = 3.50,
			Clip = 32,
			Automatic = true,
		}
	},
	weapon_zs_hammer = {
		PreviewParts = {
			"models/weapons/w_hammer.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 45),
		PreviewLift = 0.7,
		PreviewCamScale = 1.6,
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_hammer3.png",
	},
	weapon_zs_wrench = {
		PreviewParts = {
			"models/props_c17/tools_wrench01a.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(45, 0, 45),
		PreviewLift = 0.7,
		PreviewCamScale = 1.6,
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_wrench2.png",
	},
}

function GM:GetWeaponRelapse(src)
	if not src then return nil end

	if istable(src) and src.Relapse then
		return src.Relapse
	end

	local class = isstring(src) and src or src.ClassName or src.Class or src.SWEP
	if not class then return nil end

	local stored = weapons.GetStored(class)
	if stored and stored.Relapse then
		return stored.Relapse
	end

	local def = self.RelapseWeapons and self.RelapseWeapons[class]
	return def and def.Relapse or nil
end

function GM:BindRelapseWeapon(src)
	if not istable(src) then return src end

	local class = src.ClassName or src.Class or src.SWEP
	local def = class and self.RelapseWeapons and self.RelapseWeapons[class]
	if def then
		src.Relapse = src.Relapse or def.Relapse
		src.Tier = src.Tier or def.Tier
		src.TranslationName = src.TranslationName or def.TranslationName
		src.TranslationDescription = src.TranslationDescription or def.TranslationDescription
		src.RelapsePreviewIcon = def.PreviewIcon or src.RelapsePreviewIcon
		src.RelapsePreviewParts = def.PreviewParts or src.RelapsePreviewParts
		if def.PreviewBoneMerge ~= nil then
			src.RelapsePreviewBoneMerge = def.PreviewBoneMerge
		end
		if def.PreviewHullBounds ~= nil then
			src.RelapsePreviewHullBounds = def.PreviewHullBounds
		end
		src.RelapsePreviewBodygroups = def.PreviewBodygroups
		src.RelapsePreviewClipZ = def.PreviewClipZ or src.RelapsePreviewClipZ
		src.RelapsePreviewAngle = def.PreviewAngle or src.RelapsePreviewAngle
		src.RelapsePreviewLocalAng = def.PreviewLocalAng or src.RelapsePreviewLocalAng
		src.RelapsePreviewOffset = def.PreviewOffset or src.RelapsePreviewOffset
		src.RelapsePreviewLift = def.PreviewLift or src.RelapsePreviewLift
		src.RelapsePreviewCamScale = def.PreviewCamScale or src.RelapsePreviewCamScale
		if def.IsMelee then
			src.IsMelee = true
		end
		src.Primary = src.Primary or {}
		local melee = (src.Relapse and src.Relapse.Melee) or def.IsMelee
		if melee then
			src.Primary.Ammo = "none"
		elseif def.Ammo then
			src.Primary.Ammo = def.Ammo
		elseif isstring(src.Primary.Ammo) then
			src.Primary.Ammo = string.lower(src.Primary.Ammo)
		end
	end

	return src
end

function GM:GetWeaponAmmoType(src)
	if not istable(src) then return nil end

	local ammo = src.Primary and src.Primary.Ammo
	if isstring(ammo) and ammo ~= "" and string.lower(ammo) ~= "none" then
		return string.lower(ammo)
	end

	local class = src.ClassName or src.Class or src.SWEP
	local def = class and self.RelapseWeapons and self.RelapseWeapons[class]
	if def and isstring(def.Ammo) and def.Ammo ~= "" then
		return string.lower(def.Ammo)
	end

	return nil
end

function GM:RelapseStabilityError(r)
	if not r then return 0 end
	local spread = math.max(0, tonumber(r.Accuracy) or 0)
	local recoil = math.max(0, tonumber(r.Recoil) or 0)
	return spread + recoil * (self.RelapseRecoilToCone or 1.2)
end

function GM:RelapseShopCurve(x, spec)
	spec = spec or {}
	local n = spec.n or self.RelapseShopHillN or 1.4
	local ref = math.max(1e-6, spec.ref or 1)
	x = math.max(0, tonumber(x) or 0)
	local xn = x > 0 and (x ^ n) or 0
	local kn = ref ^ n
	local u = spec.better == "less" and (kn / (xn + kn)) or (xn / (xn + kn))
	return 1 + 98 * u
end

function GM:RelapseShopScore(id, raw)
	if id == "SwingRate" then
		id = "FireRate"
	end
	local spec = self.RelapseShopScoreSpec and self.RelapseShopScoreSpec[id]
	if not spec then return raw end
	return math.floor(self:RelapseShopCurve(raw, spec) + 0.5)
end

function GM:RelapseStatValue(sweptable, id)
	if not sweptable then return nil end
	local r = self:GetWeaponRelapse(sweptable)
	if not r then return nil end

	if r.Melee and (id == "Stability" or id == "Payback" or id == "Clip" or id == "Reload" or id == "Kinetic") then
		return nil
	end
	if id == "Stamina" and not r.Melee then
		return nil
	end

	if id == "Payback" then
		return self:ComputeWeaponPayback(sweptable)
	end
	if id == "FireRate" or id == "SwingRate" then
		return tonumber(r.Delay)
	end
	if id == "Stability" then
		return self:RelapseStabilityError(r)
	end
	if id == "Clip" then
		return tonumber(r.Clip) or (sweptable.Primary and sweptable.Primary.ClipSize) or nil
	end

	local raw = tonumber(r[id])
	if raw ~= nil then return raw end
	return r[id]
end

-- Units the hill curve expects. FireRate is RPM even though the shop prints Delay.
-- Damage fill uses pellet total so a 12-gauge is not scored as a single 16.
function GM:RelapseShopBarInput(sweptable, id)
	if id == "FireRate" or id == "SwingRate" then
		local r = self:GetWeaponRelapse(sweptable)
		local delay = r and tonumber(r.Delay) or 0
		if delay <= 0 then return nil end
		return 60 / delay
	end
	if id == "Damage" then
		local r = self:GetWeaponRelapse(sweptable)
		if not r then return nil end
		local dmg = tonumber(r.Damage)
		if dmg == nil then return nil end
		return dmg * math.max(1, tonumber(r.Pellets) or 1)
	end

	return self:RelapseStatValue(sweptable, id)
end

function GM:RelapseShopBarFill(sweptable, id)
	local raw = self:RelapseShopBarInput(sweptable, id)
	if raw == nil then return nil end
	return self:RelapseShopScore(id, raw)
end
