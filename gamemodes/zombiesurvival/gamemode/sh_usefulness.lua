-- Relapse usefulness (U). Cycle packs still spend in ticks of 10.
-- Item U is exact (no snap to 10). See sh_usefulness_model.lua.

GM.Usefulness = GM.Usefulness or {}

local U = GM.Usefulness

U.Tick = 10
U.Deviation = 10 -- pack may miss the level target by one tick
U.Carry = 20 -- spent vs target across the cycle must stay within ±2 ticks
U.MaxLevel = 30

-- Reaching this level spends this many U on a random pack. Level 1 spends nothing.
U.Level = {
	[1] = 0,
	[2] = 20, [3] = 20, [4] = 20, [5] = 20, [6] = 20, [7] = 20, [8] = 20, [9] = 20, [10] = 20,
	[11] = 20, [12] = 20, [13] = 20, [14] = 20, [15] = 20, [16] = 20, [17] = 20, [18] = 20, [19] = 20, [20] = 20,
	[21] = 20, [22] = 20, [23] = 20, [24] = 20, [25] = 20, [26] = 20, [27] = 20, [28] = 20, [29] = 20, [30] = 20,
}

U.CycleTotal = 580 -- sum of Level[2..30]

-- Caps are per cycle, on the resulting stat, not per roll.
U.Caps = {
	Health = 15,
	Worth = 40,
	PointsPct = 10,
	Scrap = 20,
	SpeedPct = 5,
	BloodArmor = 15,
	StartAmmoPct = 30,
	FallResistPct = 30,
}

-- Universal chips only. Role-specific buffs do not belong here.
U.Buffs = {
	{id = "hp_1", U = 10, stat = "Health", add = 1},
	{id = "worth_5", U = 10, stat = "Worth", add = 5},
	{id = "points_1", U = 10, stat = "PointsPct", add = 1},
	{id = "scrap_5", U = 10, stat = "Scrap", add = 5},
	{id = "fall_10", U = 10, stat = "FallResistPct", add = 10},
	{id = "speed_1", U = 20, stat = "SpeedPct", add = 1},
	{id = "blood_5", U = 20, stat = "BloodArmor", add = 5},
	{id = "ammo_15", U = 20, stat = "StartAmmoPct", add = 15},
	{id = "bandage", U = 30, stat = "Bandage", add = 1, unique = true},
}

function GM:GetLevelUsefulness(level)
	return U.Level[level] or 0
end

function GM:GetUsefulnessTarget(through_level)
	local total = 0
	local last = math.min(through_level or 0, U.MaxLevel)
	for i = 1, last do
		total = total + (U.Level[i] or 0)
	end
	return total
end

-- Inclusive window a pack for this level may land in.
function GM:GetUsefulnessPackRange(level)
	local target = self:GetLevelUsefulness(level)
	if target <= 0 then
		return 0, 0, 0
	end

	return target - U.Deviation, target, target + U.Deviation
end

-- Cycle packs only. Item U is not snapped.
function GM:SnapUsefulness(raw)
	local tick = U.Tick
	if not raw or raw <= 0 then
		return 0
	end

	return math.max(tick, math.floor(raw / tick + 0.5) * tick)
end
