-- Relapse scars. Law: documents/scars.md
-- Thirteen regular names in the weight draw. Honor is rare and replaces the third card.

GM.RelapseScarCatalog = {
	mercenary = {
		Order = 1,
		InPool = true,
		Pace = 50,
		Feed = "last_hit",
		K1 = 12,
		KInf = 3,
		Stat = { Kind = "k", Dec = 1 },
		Icon = "zombiesurvival/killicons/scar_mercenary.png"
	},
	stakhanovite = {
		Order = 5,
		InPool = true,
		Pace = 10000,
		Feed = "repair",
		Stat = { Kind = "p", Floor = 3, Inf = 9, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_stakhanovite.png"
	},
	demiurge = {
		Order = 6,
		InPool = true,
		Pace = 300,
		Feed = "deploy",
		Stat = { Kind = "p", Floor = 5, Inf = 15, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_demiurge.png"
	},
	mechanic = {
		Order = 7,
		InPool = true,
		Pace = 400,
		Feed = "repair",
		Stat = { Kind = "p", Floor = 5, Inf = 15, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_mechanic.png"
	},
	turner = {
		Order = 8,
		InPool = true,
		Pace = 50,
		Feed = "craft",
		Stat = { Kind = "p", Inf = 20, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_turner.png"
	},
	leader = {
		Order = 12,
		InPool = true,
		Pace = 830,
		Feed = "lead",
		Stat = { Kind = "p", Inf = 8, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_leader.png"
	},
	quartermaster = {
		Order = 10,
		InPool = true,
		Pace = 15,
		Feed = "supply",
		Stat = { Kind = "p", Inf = 25, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_quartermaster.png"
	},
	swift = {
		Order = 4,
		InPool = true,
		Pace = 50000,
		Feed = "move",
		Stat = { Kind = "p", Floor = 3, Inf = 7, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_swift.png"
	},
	breaker = {
		Order = 2,
		InPool = true,
		Pace = 3000,
		Feed = "melee",
		Stat = { Kind = "p", Floor = 2, Inf = 10, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_breaker.png"
	},
	anchor = {
		Order = 3,
		InPool = true,
		Pace = 200,
		Feed = "sigil",
		Stat = { Kind = "p", Floor = 5, Inf = 15, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_anchor2.png"
	},
	engineer = {
		Order = 9,
		InPool = true,
		Pace = 400,
		Feed = "deploy",
		Stat = { Kind = "p", Floor = 5, Inf = 15, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_engineer_wire.png"
	},
	scavenger = {
		Order = 11,
		InPool = true,
		Pace = 80,
		Feed = "scrap",
		Stat = { Kind = "p", Floor = 0, Inf = 8, Dec = 2 },
		Icon = "zombiesurvival/killicons/scar_scavenger.png"
	},
	bole = {
		Order = 14,
		InPool = true,
		Pace = 250,
		Feed = "body",
		Stat = { Kind = "step", Dec = 0 },
		Icon = "zombiesurvival/killicons/scar_bole.png"
	},
	honor = {
		Order = 13,
		InPool = true,
		Rare = true,
		Pace = 1000,
		Feed = "xp",
		Stat = { Kind = "step", Dec = 0 },
		Icon = "zombiesurvival/killicons/scar_honor_book.png"
	}
}

GM.RelapseScarOrder = {
	"mercenary",
	"breaker",
	"anchor",
	"swift",
	"stakhanovite",
	"demiurge",
	"mechanic",
	"turner",
	"engineer",
	"quartermaster",
	"scavenger",
	"leader",
	"honor",
	"bole"
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

function GM:RelapseScarAdd(n)
	n = math.floor(tonumber(n) or 0)
	if n < 1 then
		return 0
	end
	if n <= 5 then
		local step = { 3, 3, 2, 2, 2 }
		local sum = 0
		for i = 1, n do
			sum = sum + step[i]
		end
		return sum
	end
	return 12 + math.floor(10 * (n - 5) / (n + 3) + 0.5)
end

function GM:RelapseScrapBonus(pl)
	if not (IsValid(pl) and pl:IsPlayer() and pl:Team() == TEAM_HUMAN) then
		return 0
	end
	if not (self.GetRelapseScarRank and self.RelapseScarP) then
		return 0
	end
	local n = self:GetRelapseScarRank("scavenger", pl)
	if n < 1 then
		return 0
	end
	return self:RelapseScarP(n, 0.08, 0)
end

function GM:RelapseScrapPaid(pl, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return 0
	end
	local p = self:RelapseScrapBonus(pl)
	if p <= 0 then
		return amount
	end
	return amount + math.ceil(amount * p)
end

function GM:RelapseTurnerCut(pl)
	if not (IsValid(pl) and pl:IsPlayer() and pl:Team() == TEAM_HUMAN) then
		return 0
	end
	if not (self.GetRelapseScarRank and self.RelapseScarP) then
		return 0
	end
	local n = self:GetRelapseScarRank("turner", pl)
	if n < 1 then
		return 0
	end
	return self:RelapseScarP(n, 0.20, 0)
end

function GM:RelapseTurnerPay(pl, cost)
	cost = math.max(0, math.floor(tonumber(cost) or 0))
	if cost <= 0 then
		return 0
	end
	local p = self:RelapseTurnerCut(pl)
	if p <= 0 then
		return cost
	end
	return math.max(1, math.ceil(cost * (1 - p)))
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
	if kind == "step" then
		return self:RelapseScarAdd(n)
	end
	if kind == "on" then
		return 1
	end
	return 0
end

local function ScarDecText(v, dec)
	local text = string.format("%." .. tostring(dec) .. "f", v)
	local dot = string.find(text, ".", 1, true) or string.find(text, ",", 1, true)
	if not dot then
		return text
	end
	local frac = string.gsub(string.sub(text, dot + 1), "0+$", "")
	if frac == "" then
		return string.sub(text, 1, dot - 1)
	end
	return string.sub(text, 1, dot) .. frac
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
	if id == "leader" then
		return ScarDecText(v, dec) .. " / " .. ScarDecText(v * 2 / 3, dec) .. " / " .. ScarDecText(v / 3, dec)
	end
	return ScarDecText(v, dec)
end

function GM:RelapseScarPool()
	local pool = {}
	for _, id in ipairs(self.RelapseScarOrder) do
		local scar = self.RelapseScarCatalog[id]
		if scar and scar.InPool and not scar.Rare then
			pool[#pool + 1] = id
		end
	end
	return pool
end

function GM:RelapseScarRarePool()
	local pool = {}
	for _, id in ipairs(self.RelapseScarOrder) do
		local scar = self.RelapseScarCatalog[id]
		if scar and scar.Rare then
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
end

function GM:GetRelapseScarRank(id, pl)
	if not id then
		return 0
	end
	if CLIENT and (not IsValid(pl) or pl == LocalPlayer() or pl == MySelf) then
		local state = self.RelapseScarState
		return (state and state.Ranks and state.Ranks[id]) or 0
	end
	if IsValid(pl) and pl.RelapseScarRanks then
		return math.max(0, math.floor(tonumber(pl.RelapseScarRanks[id]) or 0))
	end
	return 0
end
