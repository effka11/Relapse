-- TAB human classes. Display score = inventory weights + points earned in that class.
-- Weights follow role/tier, not shop price. T1 tools must beat a T1 backup gun so
-- the main class sits left of +. Second class only if it is at least 40% of the first
-- and at least a T1-sized presence.
--
-- Worth examples (StartingWorth 100):
--   hammer 40 + T1 gun 15          → builder 24 (hammer+nails) > shooter 10
--   T1 gun + knife                 → shooter 10 = melee 10, shooter first (tie)
--   crate 50 + T1 gun              → supplier 22 > shooter 10
--   remantler 50 + T1 gun          → mechanic 20 > shooter 10
--   wrench 20 + T1 gun             → mechanic 14 > shooter 10
--   90 medpower + T1 gun           → medic ~11 > shooter 10
--   T5 gun + knife                 → shooter 54, knife hidden (ratio)

GM.TabClassOrder = {
	"builder",
	"shooter",
	"medic",
	"mechanic",
	"supplier",
	"melee"
}

GM.TabClassIndex = {
	builder = 1,
	shooter = 2,
	medic = 3,
	mechanic = 4,
	supplier = 5,
	melee = 6
}

-- Lower wins a tie so a gun+knife kit reads as shooter first.
GM.TabClassTie = {
	shooter = 1,
	builder = 2,
	medic = 3,
	mechanic = 4,
	supplier = 5,
	melee = 6
}

GM.TabClassTierWeight = {
	[1] = 10,
	[2] = 18,
	[3] = 28,
	[4] = 40,
	[5] = 54
}

GM.TabClassSecondRatio = 0.40
GM.TabClassSecondMin = 8

GM.TabClassDefs = {
	builder = {
		Icon = "zombiesurvival/class_hm.png",
		Size = 24,
		PlusGap = 2,
		Lang = "tab_class_builder"
	},
	shooter = {
		Icon = "zombiesurvival/class_ar.png",
		Size = 29,
		PlusGap = 2,
		Lang = "tab_class_shooter"
	},
	medic = {
		Icon = "zombiesurvival/class_sf.png",
		Size = 24,
		PlusGap = 2,
		Lang = "tab_class_medic"
	},
	mechanic = {
		Icon = "zombiesurvival/class_ge.png",
		Size = 24,
		PlusGap = 2,
		Lang = "tab_class_mechanic"
	},
	supplier = {
		Icon = "zombiesurvival/class_li.png",
		Size = 24,
		PlusGap = 2,
		Lang = "tab_class_supplier"
	},
	melee = {
		Icon = "zombiesurvival/class_ml.png",
		Size = 24,
		PlusGap = 2,
		Lang = "tab_class_melee"
	}
}

-- class = inventory identity. damageclass = zombie damage (hammer hits are melee, not cade).
GM.TabClassWeapon = {
	weapon_zs_hammer = { class = "builder", weight = 18, damageclass = "melee" },
	weapon_zs_electrohammer = { class = "builder", weight = 24, damageclass = "melee" },
	weapon_zs_barricadekit = { class = "builder", weight = 14 },
	weapon_zs_boardpack = { class = "builder", weight = 12 },

	weapon_zs_wrench = { class = "mechanic", weight = 14, damageclass = "melee" },
	weapon_zs_gunturret = { class = "mechanic", weight = 20 },
	weapon_zs_gunturret_assault = { class = "mechanic", weight = 28 },
	weapon_zs_gunturret_buckshot = { class = "mechanic", weight = 24 },
	weapon_zs_gunturret_rocket = { class = "mechanic", weight = 32 },
	weapon_zs_zapper = { class = "mechanic", weight = 18 },
	weapon_zs_zapper_arc = { class = "mechanic", weight = 26 },
	weapon_zs_manhack = { class = "mechanic", weight = 14 },
	weapon_zs_manhack_saw = { class = "mechanic", weight = 18 },
	weapon_zs_drone = { class = "mechanic", weight = 16 },
	weapon_zs_drone_pulse = { class = "mechanic", weight = 22 },
	weapon_zs_drone_hauler = { class = "mechanic", weight = 12 },
	weapon_zs_rollermine = { class = "mechanic", weight = 16 },
	weapon_zs_ffemitter = { class = "mechanic", weight = 16 },
	weapon_zs_repairfield = { class = "mechanic", weight = 16 },
	weapon_zs_minelayer = { class = "mechanic", weight = 16 },

	weapon_zs_arsenalcrate = { class = "supplier", weight = 22 },
	weapon_zs_resupplybox = { class = "supplier", weight = 22 },
	weapon_zs_remantler = { class = "mechanic", weight = 20 },

	weapon_zs_medicalkit = { class = "medic", weight = 16 },
	weapon_zs_medicgun = { class = "medic", weight = 20 },
	weapon_zs_medicrifle = { class = "medic", weight = 24 },
	weapon_zs_healingray = { class = "medic", weight = 22 },
	weapon_zs_strengthshot = { class = "medic", weight = 18 },
	weapon_zs_antidoteshot = { class = "medic", weight = 16 },
	weapon_zs_mediccloudbomb = { class = "medic", weight = 14 },

	weapon_zs_fists = { skip = true },
	weapon_zs_hands = { skip = true },
	zs_hands = { skip = true },
	weapon_zs_gunturretcontrol = { skip = true },
	weapon_zs_dronecontrol = { skip = true },
	weapon_zs_cameracontrol = { skip = true },
	weapon_zs_manhackcontrol = { skip = true },
	weapon_zs_manhackcontrol_saw = { skip = true },
	weapon_zs_rollerminecontrol = { skip = true }
}

GM.TabClassDeployableWeapons = {
	prop_arsenalcrate = "weapon_zs_arsenalcrate",
	prop_resupplybox = "weapon_zs_resupplybox",
	prop_remantler = "weapon_zs_remantler",
	prop_gunturret = "weapon_zs_gunturret",
	prop_gunturret_assault = "weapon_zs_gunturret_assault",
	prop_gunturret_buckshot = "weapon_zs_gunturret_buckshot",
	prop_gunturret_rocket = "weapon_zs_gunturret_rocket",
	prop_zapper = "weapon_zs_zapper",
	prop_zapper_arc = "weapon_zs_zapper_arc",
	prop_manhack = "weapon_zs_manhack",
	prop_manhack_saw = "weapon_zs_manhack_saw",
	prop_drone = "weapon_zs_drone",
	prop_drone_pulse = "weapon_zs_drone_pulse",
	prop_drone_hauler = "weapon_zs_drone_hauler",
	prop_rollermine = "weapon_zs_rollermine",
	prop_ffemitter = "weapon_zs_ffemitter",
	prop_repairfield = "weapon_zs_repairfield",
	prop_aegisboard = "weapon_zs_barricadekit"
}

GM.TabClassDeviceEnt = {
	prop_gunturret = true,
	prop_gunturret_assault = true,
	prop_gunturret_buckshot = true,
	prop_gunturret_rocket = true,
	prop_zapper = true,
	prop_zapper_arc = true,
	prop_manhack = true,
	prop_manhack_saw = true,
	prop_drone = true,
	prop_drone_pulse = true,
	prop_drone_hauler = true,
	prop_rollermine = true,
	prop_ffemitter = true,
	prop_ffemitterfield = true,
	projectile_impactmine = true,
	projectile_impactmine_kin = true
}

GM.TabClassAmmo = {
	GaussEnergy = { class = "builder", per = 0.5, cap = 6 },
	Battery = { class = "medic", per = 0.12, cap = 12 },
	impactmine = { class = "mechanic", per = 1.2, cap = 10 }
}

function GM:PackTabClassDisplay(primary, secondary)
	local p = (primary and self.TabClassIndex[primary]) or 0
	local s = (secondary and self.TabClassIndex[secondary]) or 0
	return p + s * 8
end

function GM:UnpackTabClassDisplay(packed)
	packed = math.floor(tonumber(packed) or 0)
	local p = packed % 8
	local s = math.floor(packed / 8) % 8
	return self.TabClassOrder[p], self.TabClassOrder[s]
end

function GM:GetPlayerTabClasses(pl)
	if not (pl and pl:IsValid()) then return nil, nil end
	return self:UnpackTabClassDisplay(pl:GetDTInt(DT_PLAYER_INT_TABCLASS) or 0)
end

function GM:GetTabClassWeaponInfo(class)
	if not class then return nil end

	local mapped = self.TabClassWeapon[class]
	if mapped then
		if mapped.skip then return nil end
		return mapped
	end

	local def = self.RelapseWeapons and self.RelapseWeapons[class]
	if def then
		local tier = def.Tier or 1
		local weight = self.TabClassTierWeight[tier] or self.TabClassTierWeight[1]
		if def.IsMelee or (def.Relapse and def.Relapse.Melee) then
			return { class = "melee", weight = weight }
		end
		if def.Relapse then
			return { class = "shooter", weight = weight }
		end
	end

	local stored = weapons.GetStored(class)
	if not stored then return nil end
	if stored.Unarmed or stored.IsFistWeapon or stored.FoodEatTime or stored.IsFood then return nil end

	if stored.Heal and stored.Primary and stored.Primary.Ammo == "Battery" then
		return { class = "medic", weight = 16 }
	end

	if stored.IsMelee then
		return { class = "melee", weight = 8 }
	end

	local ammo = stored.Primary and stored.Primary.Ammo
	if ammo and ammo ~= "" and ammo ~= "dummy" and ammo ~= "none" and ammo ~= "GaussEnergy" then
		local tier = stored.Tier or 1
		return { class = "shooter", weight = self.TabClassTierWeight[tier] or self.TabClassTierWeight[1] }
	end

	return nil
end

function GM:GetTabClassForWeaponClass(class)
	local info = self:GetTabClassWeaponInfo(class)
	return info and info.class or nil, info and info.weight or nil
end

function GM:GetTabClassForDamage(attacker, inflictor)
	local inf = inflictor
	if not IsValid(inf) or inf == attacker then
		if IsValid(attacker) and attacker:IsPlayer() then
			inf = attacker:GetActiveWeapon()
		end
	end
	if not IsValid(inf) then return nil end

	local cls = inf:GetClass()
	if self.TabClassDeviceEnt[cls] then
		return "mechanic"
	end

	if inf.GetObjectOwner and not inf:IsWeapon() and not inf:IsPlayer() then
		local wep = self.TabClassDeployableWeapons[cls]
		if wep then
			local info = self:GetTabClassWeaponInfo(wep)
			if info then
				return info.damageclass or info.class
			end
		end
		return "mechanic"
	end

	if inf:IsPlayer() then
		inf = inf:GetActiveWeapon()
		if not IsValid(inf) then return nil end
		cls = inf:GetClass()
	end

	local info = self:GetTabClassWeaponInfo(cls)
	if not info then return nil end
	return info.damageclass or info.class
end

function GM:GetTabClassForRepair(wep)
	if IsValid(wep) then
		local cls = wep:GetClass()
		if cls == "weapon_zs_wrench" then
			return "mechanic"
		end
	end
	return "builder"
end

if CLIENT then
	function GM:GetTabClassMaterial(name)
		local def = self.TabClassDefs[name]
		if not def then return nil end
		if not def.mat or def.mat:IsError() then
			def.mat = Material(def.Icon, "smooth")
		end
		if not def.mat or def.mat:IsError() then return nil end
		return def.mat
	end
end

if not SERVER then return end

function GM:CreditTabClass(pl, class, amount)
	if not (pl and pl:IsValid() and pl:IsPlayer()) then return end
	if not class or not self.TabClassIndex[class] then return end
	amount = tonumber(amount) or 0
	if amount <= 0 then return end

	pl.TabClassEarned = pl.TabClassEarned or {}
	pl.TabClassEarned[class] = (pl.TabClassEarned[class] or 0) + amount
	self:UpdateTabClassDisplay(pl)
end

function GM:ResetTabClassState(pl)
	if not (pl and pl:IsValid()) then return end
	pl.TabClassEarned = {}
	pl:SetDTInt(DT_PLAYER_INT_TABCLASS, 0)
end

local function AddScore(scores, class, amount)
	if not class or not amount or amount <= 0 then return end
	scores[class] = (scores[class] or 0) + amount
end

function GM:GetTabClassDeployableOwnerScores()
	local frame = FrameNumber()
	if self._TabClassDepFrame == frame and self._TabClassDepScores then
		return self._TabClassDepScores
	end

	local bypl = {}
	for entclass, wepclass in pairs(self.TabClassDeployableWeapons) do
		local info = self:GetTabClassWeaponInfo(wepclass)
		if info and info.weight then
			for _, ent in ipairs(ents.FindByClass(entclass)) do
				if ent:IsValid() and ent.GetObjectOwner then
					local owner = ent:GetObjectOwner()
					if owner:IsValid() and owner:IsPlayer() then
						local scores = bypl[owner]
						if not scores then
							scores = {}
							bypl[owner] = scores
						end
						AddScore(scores, info.class, info.weight)
					end
				end
			end
		end
	end

	self._TabClassDepFrame = frame
	self._TabClassDepScores = bypl
	return bypl
end

function GM:ComputeTabClassItemScores(pl)
	local scores = {}
	if not (pl and pl:IsValid()) then return scores end

	for _, wep in ipairs(pl:GetWeapons()) do
		if wep:IsValid() then
			local info = self:GetTabClassWeaponInfo(wep:GetClass())
			if info and info.weight then
				AddScore(scores, info.class, info.weight)
			end
		end
	end

	for ammoType, ammo in pairs(self.TabClassAmmo) do
		local n = pl:GetAmmoCount(ammoType) or 0
		if n > 0 then
			AddScore(scores, ammo.class, math.min(ammo.cap, n * ammo.per))
		end
	end

	local owned = self:GetTabClassDeployableOwnerScores()[pl]
	if owned then
		for class, amount in pairs(owned) do
			AddScore(scores, class, amount)
		end
	end

	return scores
end

function GM:PickTabClasses(pl)
	local earned = pl.TabClassEarned or {}
	local items = self:ComputeTabClassItemScores(pl)
	local ranked = {}

	for _, name in ipairs(self.TabClassOrder) do
		local score = (earned[name] or 0) + (items[name] or 0)
		if score > 0 then
			ranked[#ranked + 1] = { name = name, score = score }
		end
	end

	if #ranked == 0 then return nil, nil end

	table.sort(ranked, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		local ta = GAMEMODE.TabClassTie[a.name] or 99
		local tb = GAMEMODE.TabClassTie[b.name] or 99
		if ta ~= tb then
			return ta < tb
		end
		return a.name < b.name
	end)

	local primary = ranked[1].name
	local secondary
	if ranked[2] then
		local a, b = ranked[1].score, ranked[2].score
		if b >= self.TabClassSecondMin and b >= a * self.TabClassSecondRatio then
			secondary = ranked[2].name
		end
	end

	return primary, secondary
end

function GM:UpdateTabClassDisplay(pl)
	if not (pl and pl:IsValid()) then return end
	if pl:Team() ~= TEAM_HUMAN then
		if (pl:GetDTInt(DT_PLAYER_INT_TABCLASS) or 0) ~= 0 then
			pl:SetDTInt(DT_PLAYER_INT_TABCLASS, 0)
		end
		return
	end

	local packed = self:PackTabClassDisplay(self:PickTabClasses(pl))
	if (pl:GetDTInt(DT_PLAYER_INT_TABCLASS) or 0) ~= packed then
		pl:SetDTInt(DT_PLAYER_INT_TABCLASS, packed)
	end
end
