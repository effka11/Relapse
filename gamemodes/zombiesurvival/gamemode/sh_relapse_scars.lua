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
		Icon = "zombiesurvival/killicons/weapon_zs_ak47_side.png"
	},
	headhunter = {
		Order = 2,
		InPool = false,
		Pace = 20,
		Feed = "last_hit",
		Icon = "zombiesurvival/killicons/zs_headshot"
	},
	carver = {
		Order = 3,
		InPool = false,
		Pace = 25,
		Feed = "last_hit",
		Icon = "zombiesurvival/killicons/weapon_zs_cwknife2.png"
	},
	surgeon = {
		Order = 4,
		InPool = false,
		Pace = 750,
		Feed = "heal",
		Icon = "zombiesurvival/killicons/weapon_zs_medkit"
	},
	orderly = {
		Order = 5,
		InPool = false,
		Pace = 6,
		Feed = "heal",
		Icon = "zombiesurvival/killicons/weapon_zs_medicgun2"
	},
	foreman = {
		Order = 6,
		InPool = false,
		Pace = 10000,
		Feed = "cade",
		Icon = "zombiesurvival/killicons/weapon_zs_hammer2"
	},
	landlord = {
		Order = 7,
		InPool = false,
		Pace = 10000,
		Feed = "cade",
		Icon = "zombiesurvival/killicons/weapon_zs_plank"
	},
	spark = {
		Order = 8,
		InPool = false,
		Pace = 15000,
		Feed = "deploy",
		Icon = "zombiesurvival/killicons/weapon_zs_zapper"
	},
	quartermaster = {
		Order = 9,
		InPool = false,
		Pace = 15,
		Feed = "deploy",
		Icon = "zombiesurvival/killicons/weapon_zs_resupplybox"
	},
	nailer = {
		Order = 10,
		InPool = false,
		Pace = 20,
		Feed = "cade",
		Icon = "zombiesurvival/killicons/nail_ammo_icon_2"
	},
	rot = {
		Order = 11,
		InPool = false,
		Pace = 12000,
		Feed = "undead",
		Icon = "zombiesurvival/killicons/zombie"
	},
	zero = {
		Order = 12,
		InPool = false,
		Pace = 2,
		Feed = "undead",
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
