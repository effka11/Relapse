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
