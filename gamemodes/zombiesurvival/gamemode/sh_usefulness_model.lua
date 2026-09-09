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
		{id = "Damage", w = 0.30, better = "more", ref = 24, pad = 0, min = 1},
		{id = "FireRate", w = 0.20, better = "more", ref = 5, pad = 0, min = 0.5},
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
		{id = "Damage", w = 0.30, better = "more", ref = 35, pad = 0, min = 1},
		{id = "StaminaHit", w = 0.10, better = "less", ref = 20, pad = 4, live = false},
		{id = "StaminaMiss", w = 0.05, better = "less", ref = 12, pad = 3, live = false},
		{id = "SwingDelay", w = 0.15, better = "less", ref = 0.4, pad = 0.2, min = 0.15, max = 2},
		{id = "Stopping", w = 0.10, better = "more", ref = 110, pad = 40, min = 0},
		{id = "AttackSpeed", w = 0.15, better = "more", ref = 1 / 0.7, pad = 0, min = 0.25},
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
	local shots = math.max(prim.NumShots or 1, 1)
	local class = rangedWeaponClass(swep, prim, shots)

	-- Relapse table is seconds / kg / falloff. Convert into the stick units the model already uses.
	local r = swep.Relapse
	if r then
		return {
			Type = class,
			Damage = (r.Damage or 0) * shots,
			FireRate = 1 / math.max(r.Delay or 0.2, 0.05),
			Reload = 2 / math.max(r.Reload or 2, 0.2),
			Mag = prim.ClipSize or 1,
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

-- T1 arsenal price of the ranged stick (Battleaxe). Worth is a different currency.
U.ShopT1Price = 15
U.WorthT1Price = 45

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

-- Shop U per 1 arsenal point, from stick / T1 price. Not worth, not T5.
function GM:GetPointUsefulness()
	return self:GetStickRangedUsefulness() / U.ShopT1Price
end

function GM:GetWorthUsefulness()
	return self:GetStickRangedUsefulness() / U.WorthT1Price
end
