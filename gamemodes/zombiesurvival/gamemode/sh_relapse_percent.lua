-- Relapse percent upgrades. Fractions stack as 1 + a + b, never (1+a)*(1+b).
-- Collects cycle grid now; scars and later sources add into GetUpgradePercent.

function GM:StackPercentMul(...)
	local add = 0
	for i = 1, select("#", ...) do
		-- Parens: select(i, ...) otherwise leaks the rest into tonumber's base.
		local v = (select(i, ...))
		add = add + (tonumber(v) or 0)
	end
	return math.max(0, 1 + add)
end

function GM:GetUpgradePercent(pl, field)
	if not IsValid(pl) or not field then
		return 0
	end
	local add = 0
	if self.GetCycleGridStatAdd then
		add = add + self:GetCycleGridStatAdd(pl, field)
	end
	return add
end

function GM:GetUpgradePercentMul(pl, field)
	return self:StackPercentMul(self:GetUpgradePercent(pl, field))
end

function GM:GetJumpPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.JumpPowerMul) then
		skill = pl.JumpPowerMul - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "Jump"), skill)
end

function GM:GetReloadPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.ReloadSpeedMultiplier) then
		skill = pl.ReloadSpeedMultiplier - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "Reload"), skill)
end

function GM:GetRepairPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.RepairRateMul) then
		skill = pl.RepairRateMul - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "Repair"), skill)
end

function GM:GetHammerSwingPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.HammerSwingDelayMul) then
		skill = (1 / math.max(pl.HammerSwingDelayMul, 0.01)) - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "HammerSwing"), skill)
end

function GM:GetMedicHealPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.MedicHealMul) then
		skill = pl.MedicHealMul - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "MedicHeal"), skill)
end

function GM:GetMeleeDamagePercentMul(pl, victim)
	local skill = 0
	if IsValid(pl) and isnumber(pl.MeleeDamageMultiplier) then
		skill = pl.MeleeDamageMultiplier - 1
	end
	-- Bonebreaker p(n) only on undead. Same Σp as Strength, not a second mul.
	local scar = 0
	if IsValid(victim) and victim:IsPlayer() and victim:Team() == TEAM_UNDEAD
		and self.GetRelapseScarRank and self.RelapseScarP then
		local n = self:GetRelapseScarRank("breaker", pl)
		if n >= 1 then
			scar = self:RelapseScarP(n, 0.16, 0.04)
		end
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "MeleeDamage"), skill, scar)
end

function GM:IsMeleeDamageInflictor(inflictor)
	if not IsValid(inflictor) then
		return false
	end
	if inflictor.IsMelee or inflictor.Melee then
		return true
	end
	local R = inflictor.Relapse
	return istable(R) and R.Melee
end

-- Remantler, resupply, and arsenal keep their own HP. Mechanics is devices.
GM.MechanicsHealthSkip = {
	prop_arsenalcrate = true,
	prop_resupplybox = true,
	prop_remantler = true
}

function GM:IsMechanicsDeviceEnt(ent)
	if not IsValid(ent) then
		return false
	end
	return not self.MechanicsHealthSkip[ent:GetClass()]
end

function GM:GetMechanicsDeviceHealthMul(pl, ent, ...)
	local total = 1
	if IsValid(pl) then
		if select("#", ...) > 0 then
			total = pl:GetTotalAdditiveModifier(...)
		end
		if self:IsMechanicsDeviceEnt(ent) then
			total = total + self:GetUpgradePercent(pl, "DeviceHealth")
		end
	end
	return total
end

-- Bonus is on the crate owner's grid. Everyone who opens that box gets it.
function GM:GetResupplyBoxAmmoGive(amount, owner, obj)
	amount = math.max(0, tonumber(amount) or 0)
	if amount <= 0 then
		return 0
	end
	if not (IsValid(obj) and obj:GetClass() == "prop_resupplybox") then
		return amount
	end
	local add = self:GetUpgradePercent(owner, "ResupplyAmmo")
	if add <= 0 then
		return amount
	end
	return amount + math.ceil(amount * add)
end

-- Shop reach DistToSqr 10000 (100u). Two shop circles overlap at (2r)^2.
local ARSENAL_CRATE_RANGE_SQR = 10000
local ARSENAL_RIVAL_OVERLAP_SQR = ARSENAL_CRATE_RANGE_SQR * 4

local function ArsenalCrateList()
	local crates = ents.FindByClass("prop_arsenalcrate")
	table.Add(crates, ents.FindByClass("status_arsenalpack"))
	return crates
end

-- Unfair Competition: rival crate overlapping yours −Others; own crate −Self per such crate.
function GM:GetArsenalRivalCut(crate)
	if not IsValid(crate) then
		return 0
	end
	local owner = self:GetArsenalCrateOwner(crate)
	if not IsValid(owner) then
		return 0
	end
	local origin = crate:WorldSpaceCenter()
	local others = 0
	local cut = 0
	local crates = ArsenalCrateList()
	for i = 1, #crates do
		local other = crates[i]
		if other ~= crate and IsValid(other) then
			local rival = self:GetArsenalCrateOwner(other)
			if IsValid(rival) and rival ~= owner
				and origin:DistToSqr(other:WorldSpaceCenter()) <= ARSENAL_RIVAL_OVERLAP_SQR then
				others = others + 1
				cut = cut + self:GetUpgradePercent(rival, "ArsenalRivalOthers")
			end
		end
	end
	if others > 0 then
		cut = cut + others * self:GetUpgradePercent(owner, "ArsenalRivalSelf")
	end
	return cut
end

-- Cut is 4% plus stacked pp (grid, later Merchant p(n)). Not 4% × 1.03.
-- Rival cut is spatial: pass the crate. No crate → ceiling without competition.
function GM:GetArsenalMarginRate(owner, crate)
	local rate = self.ArsenalCrateCommission or 0.04
	rate = rate + self:GetUpgradePercent(owner, "ArsenalMargin")
	if IsValid(crate) then
		rate = rate - self:GetArsenalRivalCut(crate)
	end
	return math.max(0, rate)
end

function GM:GetArsenalCrateOwner(ent)
	if not IsValid(ent) then
		return nil
	end
	local owner = ent.GetObjectOwner and ent:GetObjectOwner() or ent:GetOwner()
	if IsValid(owner) and owner:IsPlayer() then
		return owner
	end
end

-- Slider: keep share of the pool. Default 1 (full margin). Remainder is buyer discount.
function GM:GetArsenalMarginKeepShare(owner)
	if IsValid(owner) and owner.GetArsenalMarginKeepShare then
		return owner:GetArsenalMarginKeepShare()
	end
	return 1
end

function GM:GetArsenalMarginKeepRate(owner, crate)
	return self:GetArsenalMarginRate(owner, crate) * self:GetArsenalMarginKeepShare(owner)
end

function GM:GetArsenalMarginGiveRate(owner, crate)
	return self:GetArsenalMarginRate(owner, crate) * (1 - self:GetArsenalMarginKeepShare(owner))
end

-- Starting shop (wave 0 / map zone) is list price. After wave 1, F2/E pick
-- the in-range crate with the biggest buyer cut; same cut → closer.
-- No crate in range → sigil. No sigil → arsenal zone.

function GM:GetArsenalCrateDiscount(pl, ent)
	if not (IsValid(pl) and IsValid(ent)) then
		return 0
	end
	local owner = self:GetArsenalCrateOwner(ent)
	if not IsValid(owner) then
		return 0
	end
	-- Own buys: full ceiling. Slider only splits keep vs teammate cut.
	if owner == pl then
		return self:GetArsenalMarginRate(pl, ent)
	end
	if (self:GetWave() or 0) < 1 then
		return 0
	end
	return self:GetArsenalMarginGiveRate(owner, ent)
end

function GM:ArsenalSourceDistSqr(pl, ent, maxsqr, lookrange)
	if not (IsValid(pl) and IsValid(ent)) then
		return
	end
	local pos = pl:EyePos()
	local nearest = ent:NearestPoint(pos)
	local dist = pos:DistToSqr(nearest)
	if dist > (maxsqr or ARSENAL_CRATE_RANGE_SQR) then
		return
	end
	-- Own crate/pack: skip WorldVisible. Pack on the back fails that trace.
	if self:GetArsenalCrateOwner(ent) == pl then
		return dist
	end
	if not (WorldVisible(pos, nearest) or pl:TraceLine(lookrange or 100).Entity == ent) then
		return
	end
	return dist
end

function GM:PickArsenalShop(pl)
	if not IsValid(pl) then
		return
	end

	local crates = ArsenalCrateList()
	local best, bestOff, bestDist
	for i = 1, #crates do
		local ent = crates[i]
		local dist = self:ArsenalSourceDistSqr(pl, ent)
		if dist then
			local off = self:GetArsenalCrateDiscount(pl, ent)
			if not best or off > bestOff or (off == bestOff and dist < bestDist) then
				best, bestOff, bestDist = ent, off, dist
			end
		end
	end
	if best then
		return "crate", best
	end

	if self.GetUseSigils and self:GetUseSigils() and self.GetUncorruptedSigils then
		local sigils = self:GetUncorruptedSigils()
		local sigRange = self.SigilShopRangeSqr or (256 * 256)
		local look = self.SigilShopRange or 256
		local sig, sigDist
		if sigils then
			for i = 1, #sigils do
				local ent = sigils[i]
				local dist = self:ArsenalSourceDistSqr(pl, ent, sigRange, look)
				if dist and (not sig or dist < sigDist) then
					sig, sigDist = ent, dist
				end
			end
		end
		if sig then
			return "sigil", sig
		end
	end

	if IsValid(pl.ArsenalZone) then
		return "zone", pl.ArsenalZone
	end
end

function GM:GetArsenalPurchaseMul(pl)
	if not IsValid(pl) then
		return 1
	end
	local off = 0
	-- Starting zone/sigil: list price. Own crate still cuts by max margin.
	if (self:GetWave() or 0) >= 1 and isnumber(pl.ArsenalDiscount) then
		off = off + math.max(0, 1 - pl.ArsenalDiscount)
	end
	local kind, src = self:PickArsenalShop(pl)
	if kind == "crate" then
		off = off + self:GetArsenalCrateDiscount(pl, src)
	end
	return math.max(0, 1 - off)
end

function GM:GetArsenalShopCost(pl, price)
	price = tonumber(price) or 0
	local mul = 1
	if self.GetArsenalPurchaseMul then
		local ok, v = pcall(self.GetArsenalPurchaseMul, self, pl)
		if ok then
			mul = tonumber(v) or 1
		end
	end
	return math.max(0, math.floor(price * mul))
end
