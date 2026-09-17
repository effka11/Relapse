-- Relapse scars. Law: documents/scars.md
-- Only mercenary is in the lottery pool. Other names are locked teasers.

GM.RelapseScarCatalog = {
	mercenary = {
		Order = 1,
		InPool = true,
		Pace = 50,
		Feed = "last_hit",
		K1 = 12,
		KInf = 3,
		Stat = { Kind = "k", Dec = 1 },
		Icon = "zombiesurvival/killicons/weapon_zs_ak47_side.png"
	},
	headhunter = {
		Order = 2,
		InPool = false,
		Pace = 20,
		Feed = "last_hit",
		K1 = 8,
		KInf = 2,
		Stat = { Kind = "k", Dec = 1 },
		Icon = "zombiesurvival/killicons/zs_headshot"
	},
	carver = {
		Order = 3,
		InPool = false,
		Pace = 25,
		Feed = "last_hit",
		K1 = 6,
		KInf = 2,
		Stat = { Kind = "k", Dec = 1 },
		Icon = "zombiesurvival/killicons/weapon_zs_cwknife2.png"
	},
	surgeon = {
		Order = 4,
		InPool = false,
		Pace = 750,
		Feed = "heal",
		Stat = { Kind = "p", Inf = 6, Dec = 1 },
		Icon = "zombiesurvival/killicons/weapon_zs_medkit"
	},
	orderly = {
		Order = 5,
		InPool = false,
		Pace = 6,
		Feed = "heal",
		Stat = { Kind = "on" },
		Icon = "zombiesurvival/killicons/weapon_zs_medicgun2"
	},
	foreman = {
		Order = 6,
		InPool = false,
		Pace = 10000,
		Feed = "cade",
		K1 = 8,
		KInf = 2,
		Stat = { Kind = "kmul", Mul = 200, Dec = 0 },
		Icon = "zombiesurvival/killicons/weapon_zs_hammer2"
	},
	landlord = {
		Order = 7,
		InPool = false,
		Pace = 10000,
		Feed = "cade",
		K1 = 6,
		KInf = 2,
		Stat = { Kind = "kmul", Mul = 400, Dec = 0 },
		Icon = "zombiesurvival/killicons/weapon_zs_plank"
	},
	spark = {
		Order = 8,
		InPool = false,
		Pace = 15000,
		Feed = "deploy",
		Stat = { Kind = "p", Inf = 2, Dec = 1 },
		Icon = "zombiesurvival/killicons/weapon_zs_zapper"
	},
	quartermaster = {
		Order = 9,
		InPool = false,
		Pace = 15,
		Feed = "deploy",
		Stat = { Kind = "p", Inf = 20, Dec = 1 },
		Icon = "zombiesurvival/killicons/weapon_zs_resupplybox"
	},
	nailer = {
		Order = 10,
		InPool = false,
		Pace = 20,
		Feed = "cade",
		Stat = { Kind = "p", Inf = 20, Dec = 1 },
		Icon = "zombiesurvival/killicons/nail_ammo_icon_2"
	},
	rot = {
		Order = 11,
		InPool = false,
		Pace = 12000,
		Feed = "undead",
		Stat = { Kind = "p", Inf = 25, Dec = 1 },
		Icon = "zombiesurvival/killicons/zombie"
	},
	zero = {
		Order = 12,
		InPool = false,
		Pace = 2,
		Feed = "undead",
		Stat = { Kind = "p", Inf = 4, Dec = 1 },
		Icon = "zombiesurvival/killicons/fresh_dead"
	}
}

GM.RelapseScarOrder = {
	"mercenary",
	"headhunter",
	"carver",
	"surgeon",
	"orderly",
	"foreman",
	"landlord",
	"spark",
	"quartermaster",
	"nailer",
	"rot",
	"zero"
}

local ROMAN = {
	1000, "M", 900, "CM", 500, "D", 400, "CD",
	100, "C", 90, "XC", 50, "L", 40, "XL",
	10, "X", 9, "IX", 5, "V", 4, "IV", 1, "I"
}

function GM:GetRelapseScar(id)
	return id and self.RelapseScarCatalog[id] or nil
end

function GM:RelapseScarRoman(n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 then
		return "—"
	end
	if n > 3999 then
		return tostring(n)
	end

	local out = ""
	for i = 1, #ROMAN, 2 do
		local v, g = ROMAN[i], ROMAN[i + 1]
		while n >= v do
			out = out .. g
			n = n - v
		end
	end

	return out
end

function GM:RelapseScarK(n, k1, kInf)
	n = math.max(1, tonumber(n) or 1)
	k1 = k1 or 12
	kInf = kInf or 3
	return kInf + (k1 - kInf) / (1 + 0.18 * (n - 1))
end

function GM:RelapseScarP(n, pInf, p0)
	n = math.floor(tonumber(n) or 0)
	if n < 1 then
		return 0
	end
	return (p0 or 0) + (pInf or 0) * n / (n + 8)
end

function GM:RelapseScarStatValue(id, n)
	local scar = self:GetRelapseScar(id)
	if not scar then
		return 0
	end
	n = math.floor(tonumber(n) or 0)
	if n < 1 then
		return 0
	end
	local st = scar.Stat or {}
	local kind = st.Kind
	if kind == "k" then
		return self:RelapseScarK(n, scar.K1, scar.KInf)
	end
	if kind == "kmul" then
		return self:RelapseScarK(n, scar.K1, scar.KInf) * (st.Mul or 1)
	end
	if kind == "p" then
		return self:RelapseScarP(n, st.Inf, st.Floor)
	end
	if kind == "on" then
		return 1
	end
	return 0
end

function GM:RelapseScarStatText(id, n)
	local scar = self:GetRelapseScar(id)
	local st = scar and scar.Stat or {}
	local v = self:RelapseScarStatValue(id, n)
	local dec = st.Dec
	if dec == nil then
		if st.Kind == "k" or st.Kind == "kmul" or st.Kind == "p" then
			dec = 1
		else
			dec = 0
		end
	end
	if dec <= 0 then
		return tostring(math.floor(v + 0.5))
	end
	return string.format("%." .. tostring(dec) .. "f", v)
end

function GM:RelapseScarPool()
	local pool = {}
	for _, id in ipairs(self.RelapseScarOrder) do
		local scar = self.RelapseScarCatalog[id]
		if scar and scar.InPool then
			pool[#pool + 1] = id
		end
	end
	return pool
end

function GM:RelapseScarOfferHas(offer, id)
	if not offer or not id then
		return false
	end
	for i = 1, #offer do
		if offer[i] == id then
			return true
		end
	end
	return false
end

if CLIENT then
	GM.RelapseScarState = GM.RelapseScarState or {
		Picks = 0,
		Offer = {},
		Ranks = {},
		Counts = {},
		Meters = {}
	}

	function GM:GetRelapseScarRank(id)
		local state = self.RelapseScarState
		return (state and state.Ranks and state.Ranks[id]) or 0
	end
end
