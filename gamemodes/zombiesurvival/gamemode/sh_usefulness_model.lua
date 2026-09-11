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

	local delay = math.max(swep.Primary and swep.Primary.Delay or 1, 0.1)
	local hold = swep.HoldType
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

function GM:ComputeWeaponUsefulness(swep)
	if not swep then return 0 end
	if swep.IsMelee then
		return self:ComputeUsefulness("melee", self:ExtractMeleeUsefulnessValues(swep))
	end

	return self:ComputeUsefulness("ranged", self:ExtractRangedUsefulnessValues(swep))
end

-- T1 price of the ranged stick. Same unit in worth and points: two wallets, one number.
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
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_makarov.png",
		PreviewParts = {
			"models/viper/mw/attachments/attachment_vm_pi_mike_barrel.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_mike_grip.mdl",
		},
		PreviewAngle = Angle(8, 90, 0),
		Ammo = "pistol",
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
	mg_m1911 = {
		PrintName = "Пистолет 1911",
		Description = "A service .45. Retired before its owners\194\160\194\160–\194\160\194\160the heavy bullet never left.",
		TranslationName = "wep_1911",
		TranslationDescription = "wep_1911_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_colt1911.png",
		PreviewBoneMerge = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_m1911.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_mike1911_v1_slide.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_mike1911_v1_mag.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		Ammo = "pistol",
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
	mg_357 = {
		PrintName = "Револьвер .357",
		Description = "A magnum revolver. Six in the cylinder\194\160\194\160–\194\160\194\160it never learned to hurry.",
		TranslationName = "wep_357",
		TranslationDescription = "wep_357_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_python357.png",
		PreviewBoneMerge = true,
		PreviewParts = {
			"models/viper/mw/weapons/w_357.mdl",
			"models/viper/mw/attachments/attachment_vm_pi_cpapa_barrel.mdl",
		},
		PreviewAngle = Angle(0, 0, 0),
		PreviewLocalAng = Angle(0, 0, 90),
		Ammo = "pistol",
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
		Description = "A pump 12-gauge. Nine pellets, then the forend\194\160\194\160–\194\160\194\160it only speaks up close.",
		TranslationName = "wep_680",
		TranslationDescription = "wep_680_desc",
		PreviewIcon = "zombiesurvival/killicons/weapon_zs_model680.png",
		PreviewParts = {
			"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_receiver.mdl",
			"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_barrel.mdl",
			"models/viper/mw/attachments/romeo870/attachment_vm_sh_romeo870_pump.mdl",
		},
		PreviewAngle = Angle(8, 90, 0),
		PreviewOffset = Vector(0, 0, -1.2),
		Ammo = "buckshot",
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
	}
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
		src.TranslationName = src.TranslationName or def.TranslationName
		src.TranslationDescription = src.TranslationDescription or def.TranslationDescription
		src.RelapsePreviewIcon = src.RelapsePreviewIcon or def.PreviewIcon
		src.RelapsePreviewParts = def.PreviewParts or src.RelapsePreviewParts
		src.RelapsePreviewBoneMerge = def.PreviewBoneMerge or src.RelapsePreviewBoneMerge
		src.RelapsePreviewAngle = def.PreviewAngle or src.RelapsePreviewAngle
		src.RelapsePreviewLocalAng = def.PreviewLocalAng or src.RelapsePreviewLocalAng
		src.RelapsePreviewOffset = def.PreviewOffset or src.RelapsePreviewOffset
		src.Primary = src.Primary or {}
		if def.Ammo then
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
	local spec = self.RelapseShopScoreSpec and self.RelapseShopScoreSpec[id]
	if not spec then return raw end
	return math.floor(self:RelapseShopCurve(raw, spec) + 0.5)
end

function GM:RelapseStatValue(sweptable, id)
	if not sweptable then return nil end
	local r = self:GetWeaponRelapse(sweptable)
	if not r then return nil end

	if id == "FireRate" then
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
	if id == "FireRate" then
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
