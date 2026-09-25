local pCharacter

local function State()
	local gm = GAMEMODE
	return gm and gm.RelapseScarState or {Picks = 0, Offer = {}, Ranks = {}, Counts = {}, Meters = {}}
end

local function Phrase(key, fallback)
	return RelapseUI.T(key, fallback)
end

local function PhraseF(key, ...)
	return RelapseUI.TF(key, ...)
end

local CHAR_PAGE_GRID = 1
local CHAR_PAGE_SCARS = 2

---------------------------------------------------------------------------
-- Character stat tip
---------------------------------------------------------------------------

local GRID_CORE_STATS = {
	Health = true,
	Speed = true,
	RunSpeed = true,
	Jump = true,
	Climb = true,
	Blood = true,
	ArsenalMargin = true
}

local GRID_STAT_SKIP = {
	ArsenalRivalOthers = true,
	ArsenalRivalSelf = true,
	ArsenalBreakPoints = true,
	ArsenalMonopoly = true,
	SupplySell = true
}

local GRID_STAT_INFO = {
	Reload = { key = "reload", name = "char_stat_reload", fallback = "Reload speed", kind = "pct" },
	Recoil = { key = "recoil", name = "char_stat_recoil", fallback = "Recoil", kind = "pct" },
	Deploy = { key = "deploy", name = "char_stat_deploy", fallback = "Deploy speed", kind = "pct" },
	Repair = { key = "repair", name = "char_stat_repair", fallback = "Repair rate", kind = "pct" },
	RepairPerNail = { key = "repairpernail", name = "char_stat_repairpernail", fallback = "Repair per own nail", kind = "pct" },
	Phase = { key = "phase", name = "char_stat_phase", fallback = "Barricade phase speed", kind = "pct" },
	DeviceHealth = { key = "devicehealth", name = "char_stat_devicehealth", fallback = "Device durability", kind = "pct" },
	DeviceHandle = { key = "devicehandle", name = "char_stat_devicehandle", fallback = "Device setup speed", kind = "pct" },
	TurretFire = { key = "turretfire", name = "char_stat_turretfire", fallback = "Turret attack speed", kind = "pct" },
	GunFire = { key = "gunfire", name = "char_stat_gunfire", fallback = "Fire rate", kind = "pct" },
	RangedShop = { key = "rangedshop", name = "char_stat_rangedshop", fallback = "Ranged weapon discount", kind = "pct" },
	SupplyHandle = { key = "supplyhandle", name = "char_stat_supplyhandle", fallback = "Supply setup speed", kind = "pct" },
	ResupplyAmmo = { key = "crateammo", name = "char_stat_crateammo", fallback = "Crate ammo", kind = "pct" },
	ArsenalMargin = { key = "arsenalcut", name = "char_stat_arsenalcut", fallback = "Arsenal margin", kind = "pct" },
	ArsenalCrateCost = { key = "arsenalcratecost", name = "char_stat_arsenalcratecost", fallback = "Arsenal crate cost", kind = "pct" },
	HammerSwing = { key = "hammerswing", name = "char_stat_hammerswing", fallback = "Hammer attack speed", kind = "pct" },
	MeleeSwing = { key = "meleeattack", name = "char_stat_meleeattack", fallback = "Melee attack speed", kind = "pct" },
	MeleeWindup = { key = "meleewindup", name = "char_stat_meleewindup", fallback = "Swing speed", kind = "pct" },
	MeleeStamina = { key = "meleestamina", name = "char_stat_meleestamina", fallback = "Melee stamina cost", kind = "pct" },
	NailRange = { key = "nailrange", name = "char_stat_nailrange", fallback = "Nail range", kind = "pct" },
	MaxNails = { key = "maxnails", name = "char_stat_maxnails", fallback = "Nails per prop" },
	DoorDamage = { key = "doordamage", name = "char_stat_doordamage", fallback = "Door damage", kind = "pct" },
	Heal = { key = "heal", name = "char_stat_heal", fallback = "Healing received", kind = "pct" },
	MedicHeal = { key = "medicheal", name = "char_stat_medicheal", fallback = "Healing effectiveness", kind = "pct" },
	MedkitCharge = { key = "medkitcharge", name = "char_stat_medkitcharge", fallback = "Medkit recovery speed", kind = "pct" },
	MeleeDamage = { key = "melee", name = "char_stat_melee", fallback = "Melee damage", kind = "pct" },
	MeleeMiss = { key = "meleemiss", name = "char_stat_meleemiss", fallback = "Melee miss chance", kind = "pct" },
	HitSlow = { key = "hitslow", name = "char_stat_hitslow", fallback = "Slow from incoming melee", kind = "pct" },
	BloodFromMelee = { key = "bloodfrommelee", name = "char_stat_bloodfrommelee", fallback = "Blood armor from melee", kind = "pct" },
	BloodAbsorb = { key = "bloodabsorb", name = "char_stat_bloodabsorb", fallback = "Blood armor absorption", kind = "pct" },
	BloodGain = { key = "bloodgain", name = "char_stat_bloodgain", fallback = "Blood armor gain", kind = "pct" },
	FoodBlood = { key = "foodblood", name = "char_stat_foodblood", fallback = "Blood armor from food", kind = "pct" },
	BloodReturn = { key = "bloodreturn", name = "char_stat_bloodreturn", fallback = "Absorbed damage returned", kind = "pct" },
	MeleeViewPunch = { key = "meleepunch", name = "char_stat_meleepunch", fallback = "Incoming melee camera kick", kind = "pct" },
	AimShake = { key = "aimshake", name = "char_stat_aimshake", fallback = "Aim tremor", kind = "pct" },
	AimShakeFear = { key = "aimshakefear", name = "char_stat_aimshakefear", fallback = "Fear tremor", kind = "pct" },
	AimShakeHP = { key = "aimshakehp", name = "char_stat_aimshakehp", fallback = "Low-health tremor", kind = "pct" },
	AimShakeThreshold = { key = "aimshakethreshold", name = "char_stat_aimshakethreshold", fallback = "Tremor health threshold", kind = "pct" },
	ZombieHealth = { key = "zombiehealth", name = "char_stat_zombiehealth", fallback = "Zombie max health", kind = "pct" },
	BarricadeDamage = { key = "barricadedmg", name = "char_stat_barricadedmg", fallback = "Barricade damage", kind = "pct" },
	LoosePropDamage = { key = "looseprop", name = "char_stat_looseprop", fallback = "Unnailed prop damage", kind = "pct" },
	ZombieDoorDamage = { key = "zombiedoor", name = "char_stat_zombiedoor", fallback = "Zombie door damage", kind = "pct" },
	ZombieHumanDamage = { key = "zombiehuman", name = "char_stat_zombiehuman", fallback = "Damage to humans", kind = "pct" },
	Worth = { key = "worth", name = "char_stat_worth", fallback = "Starting worth" },
	Scrap = { key = "scrap", name = "char_stat_scrap", fallback = "Starting scrap" },
	FallResist = { key = "fallresist", name = "char_stat_fall", fallback = "Fall damage", kind = "pp" },
	StartAmmo = { key = "startammo", name = "char_stat_startammo", fallback = "Starting ammo", kind = "pp" },
	Points = { key = "gridpoints", name = "char_stat_pointmul", fallback = "Point gain", kind = "pp" },
	Bandage = { key = "bandage", name = "char_stat_bandage", fallback = "Bandage" },
	Blood = { key = "bloodadd", name = "char_stat_maxblood", fallback = "Max blood armor" }
}

local SKILL_STAT_SKIP = {
	[SKILLMOD_HEALTH] = true,
	[SKILLMOD_SPEED] = true,
	[SKILLMOD_JUMPPOWER_MUL] = true,
	[SKILLMOD_BLOODARMOR] = true,
	[SKILLMOD_BLOODARMOR_MUL] = true
}

local SKILL_STAT_INFO = {
	{ id = SKILLMOD_WORTH, key = "worth", name = "char_stat_worth", fallback = "Starting worth" },
	{ id = SKILLMOD_POINTS, key = "points", name = "char_stat_points", fallback = "Starting points" },
	{ id = SKILLMOD_POINT_MULTIPLIER, key = "pointmul", name = "char_stat_pointmul", fallback = "Point gain", kind = "pct" },
	{ id = SKILLMOD_SCRAP_START, key = "scrap", name = "char_stat_scrap", fallback = "Starting scrap" },
	{ id = SKILLMOD_RELOADSPEED_MUL, key = "reload", name = "char_stat_reload", fallback = "Reload speed", kind = "pct" },
	{ id = SKILLMOD_DEPLOYSPEED_MUL, key = "deploy", name = "char_stat_deploy", fallback = "Deploy speed", kind = "pct" },
	{ id = SKILLMOD_REPAIRRATE_MUL, key = "repair", name = "char_stat_repair", fallback = "Repair rate", kind = "pct" },
	{ id = SKILLMOD_HEALING_RECEIVED, key = "heal", name = "char_stat_heal", fallback = "Healing received", kind = "pct" },
	{ id = SKILLMOD_MEDKIT_EFFECTIVENESS_MUL, key = "medkit", name = "char_stat_medkit", fallback = "Medkit healing", kind = "pct" },
	{ id = SKILLMOD_FALLDAMAGE_DAMAGE_MUL, key = "fall", name = "char_stat_fall", fallback = "Fall damage", kind = "pct" },
	{ id = SKILLMOD_FALLDAMAGE_THRESHOLD_MUL, key = "fallthreshold", name = "char_stat_fallthreshold", fallback = "Fall threshold", kind = "pct" },
	{ id = SKILLMOD_FALLDAMAGE_SLOWDOWN_MUL, key = "fallslow", name = "char_stat_fallslow", fallback = "Fall slow", kind = "pct" },
	{ id = SKILLMOD_BLOODARMOR_DMG_REDUCTION, key = "bloodabsorb", name = "char_stat_bloodabsorb", fallback = "Blood armor absorption", kind = "pct" },
	{ id = SKILLMOD_BLOODARMOR_GAIN_MUL, key = "bloodgain", name = "char_stat_bloodgain", fallback = "Blood armor gain", kind = "pct" },
	{ id = SKILLMOD_BARRICADE_PHASE_SPEED_MUL, key = "phase", name = "char_stat_phase", fallback = "Barricade phase speed", kind = "pct" },
	{ id = SKILLMOD_MELEE_DAMAGE_MUL, key = "melee", name = "char_stat_melee", fallback = "Melee damage", kind = "pct" },
	{ id = SKILLMOD_AIMSPREAD_MUL, key = "spread", name = "char_stat_spread", fallback = "Aim spread", kind = "pct" },
	{ id = SKILLMOD_SELF_DAMAGE_MUL, key = "selfdmg", name = "char_stat_selfdmg", fallback = "Self damage", kind = "pct" },
	{ id = SKILLMOD_KNOCKDOWN_RECOVERY_MUL, key = "knockdown", name = "char_stat_knockdown", fallback = "Knockdown recovery", kind = "pct" },
	{ id = SKILLMOD_RESUPPLY_DELAY_MUL, key = "resupply", name = "char_stat_resupply", fallback = "Resupply delay", kind = "pct" },
	{ id = SKILLMOD_ARSENAL_DISCOUNT, key = "discount", name = "char_stat_discount", fallback = "Arsenal discount", kind = "pct" },
	{ id = SKILLMOD_ENDWAVE_POINTS, key = "endwave", name = "char_stat_endwave", fallback = "End-of-wave points" },
	{ id = SKILLMOD_FOODRECOVERY_MUL, key = "food", name = "char_stat_food", fallback = "Food recovery", kind = "pct" },
	{ id = SKILLMOD_FOODEATTIME_MUL, key = "foodeat", name = "char_stat_foodeat", fallback = "Eat time", kind = "pct" },
	{ id = SKILLMOD_HAMMER_SWING_DELAY_MUL, key = "hammer", name = "char_stat_hammer", fallback = "Hammer delay", kind = "pct" },
	{ id = SKILLMOD_MELEE_SWING_DELAY_MUL, key = "meleeswing", name = "char_stat_meleeswing", fallback = "Melee swing delay", kind = "pct" },
	{ id = SKILLMOD_WEAPON_WEIGHT_SLOW_MUL, key = "weightslow", name = "char_stat_weightslow", fallback = "Weapon weight slow", kind = "pct" },
	{ id = SKILLMOD_LOW_HEALTH_SLOW_MUL, key = "lowhp", name = "char_stat_lowhp", fallback = "Low health slow", kind = "pct" },
	{ id = SKILLMOD_PROP_CARRY_CAPACITY_MUL, key = "carry", name = "char_stat_carry", fallback = "Carry capacity", kind = "pct" },
	{ id = SKILLMOD_PROP_THROW_STRENGTH_MUL, key = "throw", name = "char_stat_throw", fallback = "Throw strength", kind = "pct" }
}

local function FmtStatNumber(n)
	if math.abs(n - math.floor(n + 0.5)) < 0.05 then
		return tostring(math.floor(n + 0.5))
	end
	return string.format("%.1f", n)
end

local function FmtStatBonus(n, kind)
	local shown = n
	local suffix = ""
	if kind == "pct" then
		shown = n * 100
		suffix = "%"
	elseif kind == "pp" then
		suffix = "%"
	end
	local body = FmtStatNumber(shown)
	if shown > 0 then
		return "+" .. body .. suffix
	end
	return body .. suffix
end

local function CollectSkillModTotals(pl)
	local totals = {}
	local gm_modifiers = GAMEMODE.SkillModifiers
	if not IsValid(pl) or not gm_modifiers then
		return totals
	end

	local function add_skill(skillid)
		local modifiers = gm_modifiers[skillid]
		if not modifiers then return end
		for modid, amount in pairs(modifiers) do
			totals[modid] = (totals[modid] or 0) + amount
		end
	end

	if pl.GetDesiredActiveSkills then
		local skills = GAMEMODE.Skills
		for skillid in pairs(table.ToAssoc(pl:GetDesiredActiveSkills())) do
			local skill = skills and skills[skillid]
			if skill and skill.Trinket then
				add_skill(skillid)
			end
		end
	end

	local skills = GAMEMODE.Skills
	if skills and pl.HasTrinket then
		for skillid, skill in pairs(skills) do
			if skill.Trinket and pl:HasTrinket(skill.Trinket) then
				add_skill(skillid)
			end
		end
	end

	return totals
end

local function CharacterWalkRun(pl)
	local walk = SPEED_NORMAL or 95
	if IsValid(pl) then
		if isnumber(pl.SkillSpeedAdd) then
			walk = walk + pl.SkillSpeedAdd
		end
		if GAMEMODE.GetCycleGridStatAdd then
			walk = walk + GAMEMODE:GetCycleGridStatAdd(pl, "Speed")
		end
		if pl:Team() == TEAM_UNDEAD then
			return pl:GetWalkSpeed() or walk, pl:GetRunSpeed() or walk
		end
	end
	local mul = (GAMEMODE and GAMEMODE.HumanSprintMultiplier) or (240 / 95)
	local run = walk * mul
	if GAMEMODE and GAMEMODE.GetUpgradePercentMul then
		run = run * GAMEMODE:GetUpgradePercentMul(pl, "RunSpeed")
	end
	return walk, run
end

local function CharacterJump(pl)
	local jump = DEFAULT_JUMP_POWER or 185
	if IsValid(pl) and pl:Team() == TEAM_UNDEAD then
		return pl:GetJumpPower() or jump
	end
	if GAMEMODE and GAMEMODE.GetJumpPercentMul then
		jump = jump * GAMEMODE:GetJumpPercentMul(pl)
	elseif IsValid(pl) and isnumber(pl.JumpPowerMul) then
		jump = jump * pl.JumpPowerMul
	end
	return jump
end

local function CharacterClimb(pl, sprint)
	if GAMEMODE and GAMEMODE.GetHumanClimbSpeed then
		return GAMEMODE:GetHumanClimbSpeed(pl, false, sprint)
	end
	local climb = (GAMEMODE and GAMEMODE.HumanClimbSpeed) or 52
	if GAMEMODE and GAMEMODE.GetUpgradePercentMul then
		climb = climb * GAMEMODE:GetUpgradePercentMul(pl, "Climb")
	end
	if sprint then
		climb = climb * ((GAMEMODE and GAMEMODE.HumanClimbSprintMul) or (72 / 52))
	end
	return climb
end

local function CharacterArsenalMargin(pl)
	if GAMEMODE and GAMEMODE.GetArsenalMarginKeepRate then
		return GAMEMODE:GetArsenalMarginKeepRate(pl)
	end
	return (GAMEMODE and GAMEMODE.ArsenalCrateCommission) or 0.04
end

local function CollectCharacterStats(pl)
	local rows = {}
	if not IsValid(pl) then
		return rows
	end

	local hp = pl:GetMaxHealth() or 0
	if hp < 1 then
		hp = 100
		if GAMEMODE.GetCycleGridHealthAdd then
			hp = hp + GAMEMODE:GetCycleGridHealthAdd(pl)
		end
	end
	local walk, run = CharacterWalkRun(pl)
	rows[#rows + 1] = {
		name = Phrase("char_stat_maxhealth", "Max health"),
		value = FmtStatNumber(hp)
	}
	local blood = 15
	if GAMEMODE.GetHumanBloodArmorMax then
		blood = GAMEMODE:GetHumanBloodArmorMax(pl)
	elseif isnumber(pl.MaxBloodArmor) then
		blood = pl.MaxBloodArmor
	end
	rows[#rows + 1] = {
		name = Phrase("char_stat_maxblood", "Max blood armor"),
		value = FmtStatNumber(math.max(0, blood))
	}
	rows[#rows + 1] = {
		name = Phrase("char_stat_walk", "Walk speed"),
		value = FmtStatNumber(walk)
	}
	rows[#rows + 1] = {
		name = Phrase("char_stat_run", "Run speed"),
		value = FmtStatNumber(run)
	}
	rows[#rows + 1] = {
		name = Phrase("char_stat_jump", "Jump height"),
		value = FmtStatNumber(CharacterJump(pl))
	}
	rows[#rows + 1] = {
		name = Phrase("char_stat_climb", "Climb speed"),
		value = FmtStatNumber(CharacterClimb(pl))
	}
	rows[#rows + 1] = {
		name = Phrase("char_stat_climb_sprint", "Climb sprint"),
		value = FmtStatNumber(CharacterClimb(pl, true))
	}
	rows[#rows + 1] = {
		name = Phrase("char_stat_arsenalcut", "Arsenal margin"),
		value = FmtStatNumber(CharacterArsenalMargin(pl) * 100) .. "%"
	}

	local extras = {}
	local function add_extra(order, key, name, amount, kind)
		if not amount or amount == 0 then return end
		local row = extras[key]
		if row then
			row.amount = row.amount + amount
			return
		end
		extras[key] = {
			order = order,
			name = name,
			amount = amount,
			kind = kind
		}
	end

	local mods = CollectSkillModTotals(pl)
	for i, info in ipairs(SKILL_STAT_INFO) do
		local id = info.id
		if id and not SKILL_STAT_SKIP[id] then
			add_extra(10 + i, info.key, Phrase(info.name, info.fallback), mods[id] or 0, info.kind)
		end
	end

	local gridAdds = GAMEMODE.GetCycleGridStatAdds and GAMEMODE:GetCycleGridStatAdds(pl) or {}
	local gi = 0
	for field, amount in pairs(gridAdds) do
		if GRID_CORE_STATS[field] or GRID_STAT_SKIP[field] then continue end
		gi = gi + 1
		local info = GRID_STAT_INFO[field]
		if info then
			add_extra(80 + gi, info.key, Phrase(info.name, info.fallback), amount, info.kind)
		else
			add_extra(90 + gi, string.lower(field), field, amount)
		end
	end

	local sorted = {}
	for _, row in pairs(extras) do
		if row.amount ~= 0 then
			sorted[#sorted + 1] = row
		end
	end
	table.sort(sorted, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.name < b.name
	end)
	for _, row in ipairs(sorted) do
		rows[#rows + 1] = {
			name = row.name,
			value = FmtStatBonus(row.amount, row.kind),
			extra = true
		}
	end

	return rows
end

local function MeasureStatTip(rows)
	surface.SetFont("Relapse15")
	local _, lineH = surface.GetTextSize("Ay")
	lineH = math.max(1, lineH)
	local nameW, valW = 0, 0
	for _, row in ipairs(rows) do
		nameW = math.max(nameW, surface.GetTextSize(row.name or ""))
		valW = math.max(valW, surface.GetTextSize(row.value or ""))
	end
	local pad = RelapseUI.Grid15()
	local gap = RelapseUI.Grid15()
	local rowGap = RelapseUI.Grid5()
	local n = #rows
	return {
		w = pad + nameW + gap + valW + pad,
		h = pad + n * lineH + math.max(0, n - 1) * rowGap + pad,
		pad = pad,
		gap = gap,
		rowGap = rowGap,
		lineH = lineH,
		nameW = nameW,
		valW = valW
	}
end

local function MouseOverPanel(pnl)
	if not IsValid(pnl) then return false end
	local w, h = pnl:GetWide(), pnl:GetTall()
	if w < 8 or h < 8 then return false end
	local mx, my = input.GetCursorPos()
	local x, y = pnl:LocalToScreen(0, 0)
	return mx >= x and my >= y and mx <= x + w and my <= y + h
end

local function UpdateStatTip(frame)
	if not IsValid(frame) then return end
	if not frame:IsVisible() or frame._RelapseClosing then
		frame._StatTipDraw = nil
		return
	end
	local hit = frame.ModelWell
	if not IsValid(hit) then
		hit = frame.Model
	end
	if not MouseOverPanel(hit) then
		frame._StatTipDraw = nil
		return
	end

	local pl = MySelf
	if not IsValid(pl) then
		pl = LocalPlayer()
	end
	local rows = CollectCharacterStats(pl)
	if #rows == 0 then
		frame._StatTipDraw = nil
		return
	end

	local m = MeasureStatTip(rows)
	local mx, my = input.GetCursorPos()
	local gap = RelapseUI.Grid15(2)
	local x = mx - gap - m.w
	local y = my
	x = math.max(0, x)
	y = math.Clamp(y, 0, math.max(0, ScrH() - m.h))
	frame._StatTipDraw = {
		rows = rows,
		m = m,
		x = x,
		y = y
	}
end

local function DrawStatTip()
	local frame = pCharacter
	local st = IsValid(frame) and frame._StatTipDraw
	if not st or not st.rows or not st.m then return end

	local m = st.m
	local x, y = st.x, st.y
	RelapseUI.RoundFill(RelapseUI.RadPx("Card"), x, y, m.w, m.h, RelapseUI.Col.Bg)
	local c = RelapseUI.Col
	local ty = y + m.pad
	local valX = x + m.w - m.pad
	for _, row in ipairs(st.rows) do
		draw.SimpleText(row.name, "Relapse15", x + m.pad, ty, c.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(row.value, "Relapse15", valX, ty, row.extra and c.Accent or c.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		ty = ty + m.lineH + m.rowGap
	end
end

hook.Add("PostRenderVGUI", "RelapseCharStatTip", DrawStatTip)

local function BindStatTip(frame)
	if not IsValid(frame) or frame._StatTipThinkBound then return end
	frame._StatTipThinkBound = true
	local prev = frame.Think
	frame.Think = function(me)
		if prev then
			prev(me)
		end
		UpdateStatTip(me)
	end
end

local function ConfirmRelapse()
	Derma_Query(
		Phrase("char_relapse_confirm", ""),
		Phrase("char_relapse", "Relapse"),
		Phrase("shop_ok", "OK"),
		function()
			net.Start("zs_skills_remort")
			net.SendToServer()
		end,
		Phrase("menu_continue", "Cancel"),
		function() end
	)
end

local function CutChars(s, n)
	if n <= 0 then return "" end
	if utf8 and utf8.len and utf8.offset then
		local len = utf8.len(s)
		if not len or len <= n then return s end
		local pos = utf8.offset(s, n + 1)
		if not pos then return s end
		return string.sub(s, 1, pos - 1)
	end
	if #s <= n then return s end
	return string.sub(s, 1, n)
end

local function CommaNum(n)
	if string.Comma then
		return string.Comma(n)
	end
	return tostring(n)
end

local function Ellipsize(text, font, maxW)
	text = tostring(text or "")
	surface.SetFont(font)
	if surface.GetTextSize(text) <= maxW then
		return text
	end
	local ell = "…"
	local lo, hi = 1, (utf8 and utf8.len and utf8.len(text)) or #text
	local best = ell
	while lo <= hi do
		local mid = math.floor((lo + hi) * 0.5)
		local trial = CutChars(text, mid) .. ell
		if surface.GetTextSize(trial) <= maxW then
			best = trial
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	return best
end

local function DrawWrapped(text, font, x, y, maxW, col, maxLines)
	text = tostring(text or "")
	if text == "" then return y end
	local lines = RelapseUI.WrapLines(text, font, maxW)
	surface.SetFont(font)
	local _, lh = surface.GetTextSize("Ay")
	lh = math.max(1, lh)
	local n = #lines
	if maxLines then
		n = math.min(n, maxLines)
	end
	for i = 1, n do
		local line = lines[i]
		if i == n and maxLines and #lines > maxLines then
			line = Ellipsize(line, font, maxW)
		end
		draw.SimpleText(line, font, x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + lh
	end
	return y
end

local function RankOf(id)
	return GAMEMODE:GetRelapseScarRank(id)
end

local function ScarName(id)
	return Phrase("scar_" .. id, id)
end

local GAIN_FONT = "Relapse20"

local function DrawScarGain(id, rank, x, y)
	local gm = GAMEMODE
	local cur = (gm and gm.RelapseScarStatText) and gm:RelapseScarStatText(id, rank) or "0"
	local nxt = (gm and gm.RelapseScarStatText) and gm:RelapseScarStatText(id, rank + 1) or "0"
	local label = Phrase("scar_" .. id .. "_gain", "")
	local unit = Phrase("scar_" .. id .. "_unit", "")
	local c = RelapseUI.Col
	surface.SetFont(GAIN_FONT)
	local function ink(text, col)
		if text == "" then return end
		draw.SimpleText(text, GAIN_FONT, x, y, col)
		surface.SetFont(GAIN_FONT)
		x = x + surface.GetTextSize(text)
	end
	ink(label, c.Muted)
	ink(cur, c.Text)
	ink("  –  ", c.Muted)
	ink(nxt, c.Muted)
	if unit == "%" then
		ink("%", c.Text)
	elseif unit ~= "" then
		ink(" " .. unit, c.Text)
	end
end

local function PushRun(runs, text, white)
	if text == nil or text == "" then return end
	local last = runs[#runs]
	if last and last.white == white then
		last.text = last.text .. text
	else
		runs[#runs + 1] = { text = text, white = white and true or false }
	end
end

local function ScarEffectRuns(id, rank)
	local raw = Phrase("scar_" .. id .. "_effect", "")
	if raw == "" then
		raw = Phrase("scar_" .. id .. "_desc", "")
	end
	local stat = "0"
	if GAMEMODE.RelapseScarStatText then
		stat = GAMEMODE:RelapseScarStatText(id, math.max(1, rank))
	end
	local mark = "\1"
	local s = tostring(raw or "")
	s = string.gsub(s, "%%[%d%.]*[a-zA-Z]", mark)
	s = string.gsub(s, "k×%d+", mark)
	s = string.gsub(s, "%f[%w][kp]%f[%W]", mark)

	local runs = {}
	local i = 1
	while i <= #s do
		local a, b = string.find(s, mark, i, true)
		if not a then
			PushRun(runs, string.sub(s, i), false)
			break
		end
		PushRun(runs, string.sub(s, i, a - 1), false)
		PushRun(runs, stat, true)
		i = b + 1
	end
	if #runs == 0 then
		runs[1] = { text = "", white = false }
	end
	return runs
end

local function WrapEffectRuns(runs, font, maxW)
	surface.SetFont(font)
	local lines = {}
	local line = {}
	local lineW = 0
	local function push(text, white)
		if text == nil or text == "" then return end
		local last = line[#line]
		if last and last.white == white then
			last.text = last.text .. text
		else
			line[#line + 1] = { text = text, white = white and true or false }
		end
	end
	local function flush()
		if #line == 0 then return end
		lines[#lines + 1] = line
		line = {}
		lineW = 0
	end
	for _, run in ipairs(runs) do
		local text = run.text or ""
		local pos = 1
		while pos <= #text do
			local nl = string.find(text, "\n", pos, true)
			local chunk = nl and string.sub(text, pos, nl - 1) or string.sub(text, pos)
			local at = 1
			while at <= #chunk do
				local _, we, word, spaces = string.find(chunk, "(%S+)(%s*)", at)
				if not we then break end
				local wordW = surface.GetTextSize(word)
				if lineW > 0 and lineW + wordW > maxW then
					flush()
				end
				push(word, run.white)
				lineW = lineW + wordW
				if spaces ~= "" then
					local spW = surface.GetTextSize(spaces)
					if lineW + spW <= maxW then
						push(spaces, run.white)
						lineW = lineW + spW
					end
				end
				at = we + 1
			end
			if nl then
				flush()
				pos = nl + 1
			else
				break
			end
		end
	end
	flush()
	if #lines == 0 then
		lines[1] = { { text = "", white = false } }
	end
	return lines
end

local function EffectLineWide(line)
	local w = 0
	for i = 1, #line do
		w = w + (surface.GetTextSize(line[i].text) or 0)
	end
	return w
end

local function RankCaption(id, lottery)
	local rank = RankOf(id)
	if lottery then
		if rank > 0 then
			return PhraseF("char_upgrade", GAMEMODE:RelapseScarRoman(rank), GAMEMODE:RelapseScarRoman(rank + 1))
		end
		return GAMEMODE:RelapseScarRoman(1)
	end
	if rank > 0 then
		return GAMEMODE:RelapseScarRoman(rank)
	end
	return Phrase("char_locked", "—")
end

local function SyncPreview(pnl, pl)
	if not IsValid(pnl) or not IsValid(pl) then return end
	local mdl = pl:GetModel() or ""
	if mdl == "" then return end
	if pnl.RelapseLastMdl ~= mdl then
		RelapseUI.SetPlayerPreview(pnl, mdl)
		pnl.RelapseLastMdl = mdl
	end
	local ent = pnl.Entity
	if not IsValid(ent) then return end
	ent:SetSkin(pl:GetSkin() or 0)
	local n = pl.GetNumBodyGroups and pl:GetNumBodyGroups() or 0
	for i = 0, n - 1 do
		ent:SetBodygroup(i, pl:GetBodygroup(i))
	end
	if pl.GetPlayerColor then
		local col = pl:GetPlayerColor()
		ent.GetPlayerColor = function()
			return col
		end
	end
end

local function SelectScar(frame, id, lottery, silent)
	if not IsValid(frame) or not id then return end
	frame.SelectedId = id
	frame.SelectedLottery = lottery and true or false
	for _, btn in ipairs(frame.InvCards or {}) do
		if IsValid(btn) then
			btn.On = btn.ScarId == id and not lottery
		end
	end
	for _, btn in ipairs(frame.LotCards or {}) do
		if IsValid(btn) then
			btn.On = btn.ScarId == id and lottery
		end
	end
	if IsValid(frame.Desc) then
		frame.Desc:InvalidateLayout()
	end
	if GAMEMODE.LayoutCharacterFooter then
		GAMEMODE:LayoutCharacterFooter(frame)
	end
	if (frame.CharPage or CHAR_PAGE_GRID) == CHAR_PAGE_SCARS and RelapseUI.IconsDevSelect then
		RelapseUI.IconsDevSelect(id, "scar")
	end
	if not silent then
		surface.PlaySound("buttons/button14.wav")
	end
end

local CARD = {}

function CARD:Init()
	self:SetText("")
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self.NameLabel = EasyLabel(self, "", "Relapse20", RelapseUI.Col.Text)
	self.NameLabel:SetContentAlignment(5)
	self.RankLabel = EasyLabel(self, "", "Relapse15", RelapseUI.Col.Muted)
	self.RankLabel:SetContentAlignment(5)
	self.IconFrame = vgui.Create("DPanel", self)
	self.IconFrame:SetPaintBackground(false)
	self.IconFrame:SetMouseInputEnabled(false)
	self.IconFrame.Paint = function(_, w, h)
		return self:PaintIcon(w, h)
	end
end

function CARD:PaintIcon(w, h)
	local mat = self.ScarMat
	if not mat or mat:IsError() then
		return true
	end
	local tw, th = mat:Width(), mat:Height()
	if tw <= 0 or th <= 0 then
		tw, th = 256, 256
	end
	local iw, ih = RelapseUI.FitIconDims(tw, th, w, h)
	local id = self.ScarId
	local zoom = RelapseUI.ScarIconZoomValue(id)
	local ang = RelapseUI.ScarIconAngValue(id)
	local ox, oy = RelapseUI.ScarIconPosValue(id)
	local col = self.Locked and RelapseUI.Col.Muted or RelapseUI.Col.Text
	local a = self.Locked and 80 or 255
	surface.SetMaterial(mat)
	surface.SetDrawColor(col.r, col.g, col.b, a)
	surface.DrawTexturedRectRotated(w * 0.5 + ox, h * 0.5 + oy, iw * zoom, ih * zoom, ang)
	return true
end

function CARD:SetCardSize(w, h)
	self.CardW = w
	self.CardH = h
	self:SetSize(w, h)
end

function CARD:ApplySchemeSettings()
end

function CARD:PerformLayout(w, h)
	w = self.CardW or w or self:GetWide()
	h = self.CardH or h or self:GetTall()
	self:SetSize(w, h)
	local pad = RelapseUI.Grid5(2)
	local gap = RelapseUI.Grid5()
	local nameH = RelapseUI.Grid5(4)
	local rankH = RelapseUI.Grid5(3)
	local textH = nameH + gap + rankH
	local iconH = math.max(RelapseUI.Grid5(3), h - pad * 2 - textH - gap)
	if IsValid(self.IconFrame) then
		self.IconFrame:SetSize(w - pad * 2, iconH)
		self.IconFrame:SetPos(pad, pad)
		if IsValid(self.Icon) then
			RelapseUI.FitIcon(self.Icon, self.IconFrame:GetWide(), self.IconFrame:GetTall())
		end
	end
	if IsValid(self.NameLabel) then
		self.NameLabel:SetSize(w - pad * 2, nameH)
		self.NameLabel:SetPos(pad, h - pad - textH)
	end
	if IsValid(self.RankLabel) then
		self.RankLabel:SetSize(w - pad * 2, rankH)
		self.RankLabel:SetPos(pad, h - pad - rankH)
	end
end

function CARD:SetScar(id, lottery)
	self.ScarId = id
	self.Lottery = lottery and true or false
	local scar = GAMEMODE:GetRelapseScar(id)
	if not scar then return end

	local locked = RankOf(id) <= 0 and not lottery
	self.Locked = locked

	local font = "Relapse20"
	local textW = math.max(RelapseUI.Grid5(2), (self.CardW or self:GetWide()) - RelapseUI.Grid5(2) * 2)
	self.NameLabel:SetFont(font)
	self.NameLabel:SetText(Ellipsize(ScarName(id), font, textW))
	self.NameLabel:SizeToContents()
	self.NameLabel:SetTall(RelapseUI.Grid5(4))
	self.NameLabel:SetTextColor(locked and RelapseUI.Col.Muted or RelapseUI.Col.Text)

	self.RankLabel:SetFont("Relapse15")
	self.RankLabel:SetText(RankCaption(id, lottery))
	self.RankLabel:SizeToContents()
	self.RankLabel:SetTall(RelapseUI.Grid5(3))
	self.RankLabel:SetTextColor(locked and RelapseUI.Col.Muted or RelapseUI.Col.Accent)

	for _, ch in ipairs(self.IconFrame:GetChildren()) do
		if IsValid(ch) then
			ch:Remove()
		end
	end
	self.Icon = nil
	self.ScarMat = scar.Icon and RelapseUI.ScarIconMaterial(scar.Icon) or nil
	self:InvalidateLayout(true)
end

function CARD:Paint(w, h)
	RelapseUI.PaintCard(self, w, h, self.On, self.Locked, false)
	return true
end

function CARD:DoClick()
	if self.Lottery then
		if not self.ScarId then return end
		surface.PlaySound("buttons/button14.wav")
		net.Start("zs_scars_take")
			net.WriteString(self.ScarId)
		net.SendToServer()
		return
	end
	local frame = pCharacter
	if not IsValid(frame) then return end
	SelectScar(frame, self.ScarId, false)
end

vgui.Register("RelapseScarCard", CARD, "DButton")

local LayoutCharacter

local matGridBeamSrc = Material("effects/laser1")
local matGridGlow = Material("sprites/light_glow02_add")
local matGridBeam = CreateMaterial("RelapseCycleGridBeamAdd", "UnlitGeneric", {
	["$basetexture"] = "effects/laser1",
	["$additive"] = "1",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$ignorez"] = "1",
	["$nocull"] = "1",
	["$nolod"] = "1"
})
do
	local tex = matGridBeamSrc:GetTexture("$basetexture")
	if tex then
		matGridBeam:SetTexture("$basetexture", tex)
	end
end

local GRID_ZOOM_MIN = 560
local GRID_ZOOM_MAX = 1900
local GRID_ZOOM_START = 980
local GRID_RT_SIZE = 2048
local skillsDev = false

concommand.Add("relapse_skillsdev", function(_, _, args)
	if args[1] ~= nil and args[1] ~= "" then
		local a = string.lower(tostring(args[1]))
		skillsDev = a == "1" or a == "true" or a == "on"
	else
		skillsDev = not skillsDev
	end
	MsgN("relapse_skillsdev " .. (skillsDev and "1" or "0"))
end)

local gridRT
local gridRTMat
local matFadeMul = CreateMaterial("RelapseCycleGridFadeMul", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$translucent"] = "1",
	["$ignorez"] = "1",
	["$nocull"] = "1",
	["$nolod"] = "1"
})
local GRID_FADE_STEPS = 10

local function EnsureGridRT()
	if gridRT and gridRTMat then
		return gridRT, gridRTMat
	end
	gridRT = GetRenderTarget("RelapseCycleGridRT2048", GRID_RT_SIZE, GRID_RT_SIZE)
	gridRTMat = CreateMaterial("RelapseCycleGridRTMatAdd", "UnlitGeneric", {
		["$basetexture"] = "RelapseCycleGridRT2048",
		["$additive"] = "1",
		["$vertexcolor"] = "1",
		["$ignorez"] = "1",
		["$nolod"] = "1",
		["$nocull"] = "1"
	})
	gridRTMat:SetTexture("$basetexture", gridRT)
	return gridRT, gridRTMat
end

local GRID = {}

function GRID:Init()
	self:SetPaintBackground(false)
	self:SetMouseInputEnabled(true)
	self.CamY = 0
	self.CamZ = 0
	self.PanVY = 0
	self.PanVZ = 0
	self.Zoom = GRID_ZOOM_START
	self.DesiredZoom = GRID_ZOOM_START
	self.FOV = 6
	self.FarZ = 32000
	self.LastPaint = RealTime()
	self.HoverGlow = {}
	self.CaptionAlpha = 0
	self.CaptionNode = nil
end

function GRID:WorldPos(x, y)
	local u = (GAMEMODE and GAMEMODE.CycleGridUnit) or 20
	return Vector(0, x * u, y * u)
end

function GRID:DrawPos(x, y)
	return self:WorldPos(x, y) + Vector(-16, 0, 0)
end

function GRID:TreeWorldRadius()
	if self._TreeR then
		return self._TreeR
	end
	local gm = GAMEMODE
	if not gm or not gm.GetCycleGridLayout then
		return 120
	end
	local r2 = 0
	for _, n in ipairs(gm:GetCycleGridLayout().nodes) do
		local d = n.x * n.x + n.y * n.y
		if d > r2 then
			r2 = d
		end
	end
	self._TreeR = math.sqrt(r2) * ((gm.CycleGridUnit or 20))
	return self._TreeR
end

function GRID:PanLimit()
	local zoom = self.Zoom or GRID_ZOOM_MAX
	if zoom >= GRID_ZOOM_MAX - 8 then
		return 0
	end
	local t = math.Clamp((GRID_ZOOM_MAX - zoom) / (GRID_ZOOM_MAX - GRID_ZOOM_MIN), 0, 1)
	-- Enough to put an outer node near the panel center, not into empty space.
	return (self:TreeWorldRadius() + 28) * t
end

function GRID:StepPan(dt)
	local lim = self:PanLimit()
	if lim <= 0 then
		self.CamY = 0
		self.CamZ = 0
		self.PanVY = 0
		self.PanVZ = 0
		if self.Dragging then
			self.Dragging = false
			self:MouseCapture(false)
		end
		return
	end
	if self.Dragging then
		if not input.IsMouseDown(MOUSE_LEFT) and not input.IsMouseDown(MOUSE_MIDDLE) then
			self.Dragging = false
			self:MouseCapture(false)
		else
			local mx, my = gui.MousePos()
			local k = self.Zoom * 0.00016
			local ny = math.Clamp(self.DragY - (mx - self.DragMX) * k, -lim, lim)
			local nz = math.Clamp(self.DragZ + (my - self.DragMY) * k, -lim, lim)
			if dt > 0.0001 then
				self.PanVY = Lerp(0.4, self.PanVY or 0, (ny - self.CamY) / dt)
				self.PanVZ = Lerp(0.4, self.PanVZ or 0, (nz - self.CamZ) / dt)
			end
			self.CamY = ny
			self.CamZ = nz
			return
		end
	end
	local damp = math.exp(-dt * 8)
	self.PanVY = (self.PanVY or 0) * damp
	self.PanVZ = (self.PanVZ or 0) * damp
	if math.abs(self.PanVY) < 4 then
		self.PanVY = 0
	end
	if math.abs(self.PanVZ) < 4 then
		self.PanVZ = 0
	end
	self.CamY = math.Clamp(self.CamY + self.PanVY * dt, -lim, lim)
	self.CamZ = math.Clamp(self.CamZ + self.PanVZ * dt, -lim, lim)
	if self.CamY <= -lim or self.CamY >= lim then
		self.PanVY = 0
	end
	if self.CamZ <= -lim or self.CamZ >= lim then
		self.PanVZ = 0
	end
end

function GRID:NodeOwned(n)
	if not n then
		return false
	end
	if n.tree == nil then
		return true
	end
	local gm = GAMEMODE
	if gm and gm.CycleGridSlotTaken then
		return gm:CycleGridSlotTaken(MySelf, n.treeId, n.slot)
	end
	return false
end

function GRID:HoverAmt(n)
	local glow = self.HoverGlow
	local t = 0
	if glow and n then
		t = glow[n] or 0
	end
	-- Hub and taken skills share the rest size. Empty nests stay small until hover.
	if n and self:NodeOwned(n) then
		return 0.4 + 0.6 * t
	end
	return t
end

function GRID:StepHoverGlow(hoverNode, dt)
	local glow = self.HoverGlow
	if not glow then
		glow = {}
		self.HoverGlow = glow
	end
	for n, t in pairs(glow) do
		local want = 0
		if n == hoverNode then
			want = 1
		end
		local rate = 4.5
		if want > t then
			rate = 6
		end
		t = math.Approach(t, want, dt * rate)
		if want == 0 and t <= 0 then
			glow[n] = nil
		else
			glow[n] = t
		end
	end
	if hoverNode and glow[hoverNode] == nil then
		glow[hoverNode] = math.min(1, dt * 6)
	end
end

function GRID:CanHubRelapse()
	local pl = MySelf
	return IsValid(pl) and pl.CanSkillsRemort and pl:CanSkillsRemort()
end

function GRID:NodeMuted(n)
	local gm = GAMEMODE
	return gm and gm.CycleGridNodeMuted and gm:CycleGridNodeMuted(MySelf, n)
end

function GRID:GridGray(a)
	local c = RelapseUI.Col.Muted
	local k = 0.62
	return Color(
		math.floor(c.r * k + 0.5),
		math.floor(c.g * k + 0.5),
		math.floor(c.b * k + 0.5),
		a
	)
end

function GRID:GridWine(a)
	local c = RelapseUI.Col.Danger
	return Color(c.r, c.g, c.b, a)
end

function GRID:GridLit(a, bright)
	local c = RelapseUI.Col.Text
	local k = bright and 0.78 or 0.62
	return Color(
		math.floor(c.r * k + 0.5),
		math.floor(c.g * k + 0.5),
		math.floor(c.b * k + 0.5),
		a
	)
end

function GRID:NodeWine(n)
	return self:NodeMuted(n) and self:NodeOwned(n)
end

function GRID:GridNodeInk(n)
	if self:NodeWine(n) then
		return self:GridWine(160)
	end
	local remortHub = n and n.tree == nil and self:CanHubRelapse()
	local rest
	if remortHub then
		rest = self:GridGray(170)
	elseif self:NodeOwned(n) then
		rest = self:GridLit(140)
	else
		rest = self:GridGray(120)
	end
	local t = self:HoverAmt(n)
	if remortHub or t <= 0 then
		return rest
	end
	t = t * t * (3 - 2 * t)
	local lit = self:GridLit(165, true)
	return Color(
		Lerp(t, rest.r, lit.r),
		Lerp(t, rest.g, lit.g),
		Lerp(t, rest.b, lit.b),
		Lerp(t, rest.a or 255, lit.a or 255)
	)
end

function GRID:GridEdgeInk(e)
	local a, b = e[1], e[2]
	if self:NodeWine(a) and self:NodeWine(b) then
		return self:GridWine(110)
	end
	if self:NodeOwned(a) and self:NodeOwned(b) then
		return self:GridLit(105)
	end
	return self:GridGray(75)
end

local function DrawGridBeam(pa, pb, col, u0, u1)
	render.DrawBeam(pa, pb, 3, u0, u1, Color(col.r, col.g, col.b, math.min(col.a or 255, 105)))
	render.DrawBeam(pa, pb, 8, u0, u1, Color(col.r, col.g, col.b, math.min((col.a or 255) * 0.4, 42)))
end

local FADE_STEPS = 8

local function BeamFade(t, from, to)
	local u = math.Clamp((t - 0.25) / 0.5, 0, 1)
	u = u * u * (3 - 2 * u)
	return Color(
		Lerp(u, from.r, to.r),
		Lerp(u, from.g, to.g),
		Lerp(u, from.b, to.b),
		Lerp(u, from.a or 255, to.a or 255)
	)
end

local function DrawFadeBeam(pa, pb, from, to)
	local dx, dy, dz = pb.x - pa.x, pb.y - pa.y, pb.z - pa.z
	for pass = 1, 2 do
		local width = pass == 1 and 3 or 8
		render.StartBeam(FADE_STEPS + 1)
		for i = 0, FADE_STEPS do
			local t = i / FADE_STEPS
			local col = BeamFade(t, from, to)
			local a = pass == 1 and math.min(col.a, 105) or math.min(col.a * 0.4, 42)
			render.AddBeam(
				Vector(pa.x + dx * t, pa.y + dy * t, pa.z + dz * t),
				width, t, Color(col.r, col.g, col.b, a)
			)
		end
		render.EndBeam()
	end
end

function GRID:DrawWeb3D(campos, ang, to_camera, layout, hoverNode, realtime, vx, vy, vw, vh)
	cam.Start3D(campos, ang, self.FOV, vx, vy, vw, vh, 5, self.FarZ)
	cam.IgnoreZ(true)
	render.OverrideDepthEnable(true, false)
	render.OverrideAlphaWriteEnable(true, false)
	render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)

	render.SetMaterial(matGridBeam)
	local remort = self:CanHubRelapse()
	local dim = remort and self:GridGray(75)
	local litPulse = remort and self:GridLit(120, true)
	local lit = remort and Color(litPulse.r, litPulse.g, litPulse.b, 105)
	for _, e in ipairs(layout.edges) do
		local pa = self:DrawPos(e[1].x, e[1].y)
		local pb = self:DrawPos(e[2].x, e[2].y)
		if self:NodeWine(e[2]) and not self:NodeWine(e[1]) then
			DrawFadeBeam(pa, pb, self:GridLit(105), self:GridWine(105))
		elseif remort and e.hub and self:NodeOwned(e[2]) and not self:NodeMuted(e[2]) then
			DrawFadeBeam(pa, pb, dim, lit)
		else
			DrawGridBeam(pa, pb, self:GridEdgeInk(e), 0, 1)
		end
	end

	render.SetMaterial(matGridGlow)
	local function paintDot(n)
		local remortHub = n.tree == nil and self:CanHubRelapse()
		local t = self:HoverAmt(n)
		t = t * t * (3 - 2 * t)
		local col = self:GridNodeInk(n)
		local size = Lerp(t, 7, 9.5)
		local pos = self:DrawPos(n.x, n.y)
		local coreA = math.floor((col.a or 255) * 0.4)
		local core = Color(col.r, col.g, col.b, coreA)
		if remortHub then
			local g = Lerp(t, 1, 1.12)
			render.DrawQuadEasy(pos, to_camera, 26 * g, 26 * g, Color(col.r, col.g, col.b, 20), 0)
			render.DrawQuadEasy(pos, to_camera, 16 * g, 16 * g, Color(col.r, col.g, col.b, 46), 0)
			render.DrawQuadEasy(pos, to_camera, 9 * g, 9 * g, core, 0)
			return
		end
		if t > 0.01 then
			render.DrawQuadEasy(pos, to_camera, size * 1.45, size * 1.45, Color(col.r, col.g, col.b, math.floor(16 * t)), 0)
		end
		render.DrawQuadEasy(pos, to_camera, size, size, core, 0)
	end
	paintDot(layout.hub)
	for _, n in ipairs(layout.nodes) do
		paintDot(n)
	end

	render.OverrideBlend(false)
	render.OverrideAlphaWriteEnable(false)
	render.OverrideDepthEnable(false)
	cam.IgnoreZ(false)
	cam.End3D()
end

function GRID:FadeBand(w, h)
	return math.max(RelapseUI.sPx(52), math.floor(math.min(w, h) * 0.08))
end

-- Additive blit treats RGB 0 as gone. Linear vgui gradients never quite
-- reach 0, so white lasers stay a hairline after gray is already invisible.
local function GridEdgeKeep(t)
	t = math.Clamp(t, 0, 1)
	t = t * t * (3 - 2 * t)
	return t * t
end

local function PushFadeVert(x, y, keep)
	mesh.Color(0, 0, 0, math.floor((1 - keep) * 255 + 0.5))
	mesh.Position(Vector(x, y, 0))
	mesh.TexCoord(0, 0, 0)
	mesh.AdvanceVertex()
end

local function PushFadeQuad(x0, y0, x1, y1, ktl, ktr, kbr, kbl)
	PushFadeVert(x0, y0, ktl)
	PushFadeVert(x1, y0, ktr)
	PushFadeVert(x1, y1, kbr)
	PushFadeVert(x0, y1, kbl)
end

function GRID:MaskWebEdges(w, h)
	local band = self:FadeBand(w, h)
	local n = GRID_FADE_STEPS
	cam.Start2D()
	render.SetMaterial(matFadeMul)
	mesh.Begin(MATERIAL_QUADS, n * 4)
	for i = 0, n - 1 do
		local t0, t1 = i / n, (i + 1) / n
		local k0, k1 = GridEdgeKeep(t0), GridEdgeKeep(t1)
		local a0, a1 = band * t0, band * t1
		PushFadeQuad(0, a0, w, a1, k0, k0, k1, k1)
		PushFadeQuad(0, h - a1, w, h - a0, k1, k1, k0, k0)
		PushFadeQuad(a0, 0, a1, h, k0, k1, k1, k0)
		PushFadeQuad(w - a1, 0, w - a0, h, k1, k0, k0, k1)
	end
	mesh.End()
	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, w, 3)
	surface.DrawRect(0, h - 3, w, 3)
	surface.DrawRect(0, 0, 3, h)
	surface.DrawRect(w - 3, 0, 3, h)
	cam.End2D()
end

function GRID:BlitWeb(w, h, fade)
	if fade <= 0 then
		return
	end
	local _, mat = EnsureGridRT()
	mat:SetTexture("$basetexture", gridRT)
	-- Additive blit ignores parent SetAlpha (vertex A). Fade the add through
	-- vertex color, same window alpha as DModelPanelEx.
	surface.SetMaterial(mat)
	local a = math.floor(fade * 255 + 0.5)
	surface.SetDrawColor(a, a, a, 255)
	render.PushFilterMin(TEXFILTER.LINEAR)
	render.PushFilterMag(TEXFILTER.LINEAR)
	surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, w / GRID_RT_SIZE, h / GRID_RT_SIZE)
	render.PopFilterMag()
	render.PopFilterMin()
end

function GRID:NodeActs(n)
	if not n or n.tree == nil then
		return false
	end
	local gm = GAMEMODE
	if not gm or gm:CycleGridMutedByAncestor(MySelf, n) then
		return false
	end
	if gm:CycleGridIsMuteRoot(MySelf, n) then
		return true
	end
	local skill = gm:GetCycleGridSkill(n.treeId, n.slot)
	if skill and gm:HasCycleGridSkill(MySelf, skill.id) then
		return true
	end
	return gm:CycleGridIsOffered(MySelf, n.treeId, n.slot)
end

function GRID:OnMousePressed(mc)
	if mc ~= MOUSE_LEFT and mc ~= MOUSE_MIDDLE then return end
	local mx, my = gui.MousePos()
	self.PressMX, self.PressMY = mx, my
	self.PressHubRelapse = mc == MOUSE_LEFT and self:CanHubRelapse() and self.HoverNode and self.HoverNode.tree == nil
	self.PressNode = mc == MOUSE_LEFT and self.HoverNode and self.HoverNode.tree ~= nil and self.HoverNode or nil
	if self:PanLimit() <= 0 then
		if self.PressHubRelapse or self.PressNode then
			self:MouseCapture(true)
		end
		return
	end
	self.Dragging = true
	self.PanVY = 0
	self.PanVZ = 0
	self.DragMX, self.DragMY = mx, my
	self.DragY, self.DragZ = self.CamY, self.CamZ
	self:MouseCapture(true)
end

function GRID:OnMouseReleased()
	local wantRelapse = self.PressHubRelapse
	local pressed = self.PressNode
	local px, py = self.PressMX, self.PressMY
	self.PressHubRelapse = false
	self.PressNode = nil
	self.Dragging = false
	self:MouseCapture(false)
	if (not wantRelapse and not pressed) or not px then
		return
	end
	local mx, my = gui.MousePos()
	if math.abs(mx - px) + math.abs(my - py) > RelapseUI.sPx(8) then
		return
	end
	if wantRelapse and self.HoverNode and self.HoverNode.tree == nil and self:CanHubRelapse() then
		ConfirmRelapse()
		return
	end
	local n = self.HoverNode
	if not pressed or n ~= pressed or n.tree == nil then
		return
	end
	local gm = GAMEMODE
	if gm:CycleGridMutedByAncestor(MySelf, n) then
		return
	end
	if gm:CycleGridIsMuteRoot(MySelf, n) then
		net.Start("zs_cycle_grid_mute")
		net.WriteString(n.treeId)
		net.WriteUInt(n.slot, 5)
		net.SendToServer()
		return
	end
	local skill = gm:GetCycleGridSkill(n.treeId, n.slot)
	local owned = skill and gm:HasCycleGridSkill(MySelf, skill.id)
	if owned then
		net.Start("zs_cycle_grid_mute")
		net.WriteString(n.treeId)
		net.WriteUInt(n.slot, 5)
		net.SendToServer()
		return
	end
	if gm:CycleGridIsOffered(MySelf, n.treeId, n.slot) then
		net.Start("zs_cycle_grid_unlock")
		net.WriteString(n.treeId)
		net.WriteUInt(n.slot, 5)
		net.SendToServer()
		return
	end
	surface.PlaySound("buttons/button8.wav")
end

function GRID:OnMouseWheeled(delta)
	self.DesiredZoom = math.Clamp(self.DesiredZoom - delta * 500, GRID_ZOOM_MIN, GRID_ZOOM_MAX)
	return true
end

function GRID:OnCursorExited()
	if not self.Dragging then
		self.HoverNode = nil
	end
end

function GRID:Paint(w, h)
	local gm = GAMEMODE
	if not gm or not gm.GetCycleGridLayout then
		return true
	end
	local layout = gm:GetCycleGridLayout()
	local realtime = RealTime()
	local dt = math.Clamp(realtime - (self.LastPaint or realtime), 0, 0.1)
	self.LastPaint = realtime
	self.Zoom = Lerp(1 - math.exp(-dt * 6), self.Zoom, self.DesiredZoom)
	if math.abs(self.Zoom - self.DesiredZoom) < 2 then
		self.Zoom = self.DesiredZoom
	end
	self:StepPan(dt)

	local campos = Vector(self.Zoom, self.CamY, self.CamZ)
	local lookat = Vector(0, self.CamY, self.CamZ)
	local ang = (lookat - campos):Angle()
	local to_camera = ang:Forward() * -1
	local vx, vy = self:LocalToScreen(0, 0)
	local mx, my = gui.MousePos()
	local aim = util.AimVector(ang, self.FOV, mx - vx, my - vy, w, h)
	local hit = util.IntersectRayWithPlane(campos, aim, lookat, Vector(-1, 0, 0))

	local hoverNode
	local nearest = 64
	if hit then
		if self:WorldPos(layout.hub.x, layout.hub.y):DistToSqr(hit) <= 90 then
			hoverNode = layout.hub
		end
		for _, n in ipairs(layout.nodes) do
			local d = self:WorldPos(n.x, n.y):DistToSqr(hit)
			if d <= nearest then
				nearest = d
				hoverNode = n
			end
		end
	end
	self.HoverNode = hoverNode
	self:StepHoverGlow(hoverNode, dt)
	self:StepCaptionFade(hoverNode, layout, dt)
	if self.Dragging then
		self:SetCursor("arrow")
	elseif self:CanHubRelapse() and hoverNode and hoverNode.tree == nil then
		self:SetCursor("hand")
	elseif hoverNode and hoverNode.tree ~= nil and self:NodeActs(hoverNode) then
		self:SetCursor("hand")
	else
		self:SetCursor("arrow")
	end

	local fade = RelapseUI.PanelFadeAlpha(self)
	if fade <= 0 then
		return true
	end

	local rt = EnsureGridRT()
	local sw, sh = ScrW(), ScrH()
	render.PushRenderTarget(rt)
	render.SetViewPort(0, 0, w, h)
	render.Clear(0, 0, 0, 255, true, true)
	self:DrawWeb3D(campos, ang, to_camera, layout, hoverNode, realtime, 0, 0, w, h)
	self:MaskWebEdges(w, h)
	render.SetViewPort(0, 0, sw, sh)
	render.PopRenderTarget()

	-- PushRenderTarget can drop or double the VGUI multiplier. Pin it, then
	-- apply the window fade once on the 2D blit and caption.
	local prevMul = surface.GetAlphaMultiplier and surface.GetAlphaMultiplier() or 1
	if surface.SetAlphaMultiplier then
		surface.SetAlphaMultiplier(1)
	end
	self:BlitWeb(w, h, fade)
	self:DrawSkillCaption(w, h, layout, fade)
	if surface.SetAlphaMultiplier then
		surface.SetAlphaMultiplier(prevMul)
	end
	return true
end

function GRID:SkillCaption(n, layout)
	if n == layout.hub then
		return Phrase("grid_hub_name", "Rebirth"), Phrase("grid_hub_desc", "Wipes the grid and cycle level. Scars and the points bonus stay.")
	end
	if not n or not n.treeId then
		return
	end
	local skill = GAMEMODE.GetCycleGridSkill and GAMEMODE:GetCycleGridSkill(n.treeId, n.slot)
	if skill then
		return Phrase(skill.nameKey, skill.id), Phrase(skill.descKey, "")
	end
	if skillsDev then
		return n.treeId, ""
	end
end

function GRID:StepCaptionFade(hoverNode, layout, dt)
	local name = hoverNode and self:SkillCaption(hoverNode, layout)
	local want = 0
	if name then
		want = 1
		self.CaptionNode = hoverNode
	end
	local rate = 4.5
	if want > (self.CaptionAlpha or 0) then
		rate = 6
	end
	self.CaptionAlpha = math.Approach(self.CaptionAlpha or 0, want, dt * rate)
	if (self.CaptionAlpha or 0) <= 0 and want == 0 then
		self.CaptionNode = nil
	end
end

function GRID:DrawSkillCaption(w, h, layout, fade)
	local t = self.CaptionAlpha or 0
	if t <= 0.01 or fade <= 0 then
		return
	end
	local n = self.CaptionNode
	local name, desc = self:SkillCaption(n, layout)
	if not name and not (skillsDev and n) then
		return
	end
	t = t * t * (3 - 2 * t) * fade
	RelapseUI.CreateFonts()
	local function withA(col)
		return Color(col.r, col.g, col.b, math.floor((col.a or 255) * t + 0.5))
	end
	-- Relapse30 cell sits ~6px above caps. 45px from box top to the capital.
	local y = RelapseUI.sPx(45) - RelapseUI.sPx(6)
	if skillsDev and n then
		local tag = n.tree == nil and "hub" or tostring(n.slot)
		RelapseUI.HudText(tag, "Relapse30", w * 0.5, y, withA(RelapseUI.Col.Accent), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1)
		surface.SetFont("Relapse30")
		local _, tagH = surface.GetTextSize(tag)
		y = y + tagH + RelapseUI.sPx(15)
	end
	if not name then
		return
	end
	RelapseUI.HudText(name, "Relapse30", w * 0.5, y, withA(RelapseUI.Col.Text), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1)
	if not desc or desc == "" then
		return
	end
	surface.SetFont("Relapse30")
	local _, titleH = surface.GetTextSize(name)
	local font = "Relapse20"
	surface.SetFont(font)
	local _, lh = surface.GetTextSize("Ay")
	lh = math.max(1, lh)
	local lines = RelapseUI.WrapLines(desc, font, math.floor(w * 0.7))
	-- Relapse20 cell sits ~5px above caps. 30px from the title to the capital.
	local dy = y + titleH + RelapseUI.sPx(30) - RelapseUI.sPx(5)
	local col = withA(RelapseUI.Col.Muted)
	for i = 1, #lines do
		RelapseUI.HudText(lines[i], font, w * 0.5, dy, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1)
		dy = dy + lh
	end
end

vgui.Register("RelapseCycleGrid", GRID, "DPanel")

local function SyncScarIconsDev(frame)
	if not IsValid(frame) then return end
	if (frame.CharPage or CHAR_PAGE_GRID) == CHAR_PAGE_SCARS then
		if RelapseUI.IconsDevBindScar then
			RelapseUI.IconsDevBindScar(frame)
		end
		if frame.SelectedId and RelapseUI.IconsDevSelect then
			RelapseUI.IconsDevSelect(frame.SelectedId, "scar")
		end
		return
	end
	if RelapseUI.IconsDevUnbindScar then
		RelapseUI.IconsDevUnbindScar()
	end
end

local function ApplyCharPage(frame, idx)
	if not IsValid(frame) then return end
	idx = math.Clamp(tonumber(idx) or CHAR_PAGE_GRID, CHAR_PAGE_GRID, CHAR_PAGE_SCARS)
	frame.CharPage = idx
	if IsValid(frame.CharTabs) and frame.CharTabs.Tabs then
		local btn = frame.CharTabs.Tabs[idx]
		if IsValid(btn) then
			frame.CharTabs._Active = btn
		end
	end
	LayoutCharacter(frame)
	SyncScarIconsDev(frame)
end

local function ScarCardSize()
	return RelapseUI.Grid15(9)
end

local function DefaultSelection(frame)
	local id = frame.SelectedId
	if id and not frame.SelectedLottery then
		local scar = GAMEMODE:GetRelapseScar(id)
		if scar then
			return id, false
		end
	end
	for _, sid in ipairs(GAMEMODE.RelapseScarOrder or {}) do
		if RankOf(sid) > 0 then
			return sid, false
		end
	end
	for _, sid in ipairs(GAMEMODE.RelapseScarOrder or {}) do
		if GAMEMODE:GetRelapseScar(sid) then
			return sid, false
		end
	end
	return nil, false
end

local function LotteryBox(offerCount)
	local size = ScarCardSize()
	local gap = RelapseUI.Grid15(2)
	local pad = RelapseUI.Grid15(3)
	local titleY = RelapseUI.Grid15(2)
	surface.SetFont("Relapse30")
	local _, titleCell = surface.GetTextSize("Ay")
	titleCell = math.max(titleCell or 0, RelapseUI.sPx(30))
	local header = titleY + titleCell - RelapseUI.sPx(6) + RelapseUI.sPx(45)
	local n = math.Clamp(offerCount, 1, 3)
	local cardsW = n * size + math.max(0, n - 1) * gap
	local w = pad + cardsW + pad
	local h = header + size + pad
	return {
		size = size,
		gap = gap,
		pad = pad,
		titleY = titleY,
		header = header,
		n = n,
		cardsW = cardsW,
		w = w,
		h = h
	}
end

local function PlaceLottery(frame)
	local win = frame.LotteryWin
	if not IsValid(win) then return end
	local st = State()
	local offer = st.Offer or {}
	local onScars = (frame.CharPage or CHAR_PAGE_GRID) == CHAR_PAGE_SCARS
	local show = onScars and frame:IsVisible() and (st.Picks or 0) > 0 and #offer > 0
	local was = win:IsVisible()
	win:SetVisible(show)
	if show and not was then
		win:MoveToFront()
	end
	if not show then
		frame._ScarTipDraw = nil
		local nudge = frame._LotteryNudge or 0
		if nudge ~= 0 then
			local host = frame:GetParent()
			local sx, sy = frame:LocalToScreen(0, 0)
			sx = sx + nudge
			local x, y = sx, sy
			if IsValid(host) then
				x, y = host:ScreenToLocal(sx, sy)
			end
			frame:SetPos(x, y)
			frame._LotteryNudge = 0
		end
		return
	end
	local alpha = frame:GetAlpha() or 255
	win:SetAlpha(alpha)
	win:SetMouseInputEnabled(alpha > 10)
	local host = frame:GetParent()
	if IsValid(host) and win:GetParent() ~= host then
		win:SetParent(host)
	end
	local gap = RelapseUI.sPx(30)
	local margin = RelapseUI.Grid15(2)
	local prev = frame._LotteryNudge or 0
	local sx, sy = frame:LocalToScreen(0, 0)
	local natural = sx + prev
	local overflow = natural + frame:GetWide() + gap + win:GetWide() - (ScrW() - margin)
	local shift = 0
	if overflow > 0 then
		shift = math.min(overflow, math.max(0, natural - margin))
	end
	sx = natural - shift
	if shift ~= prev then
		local fx, fy = sx, sy
		if IsValid(host) then
			fx, fy = host:ScreenToLocal(sx, sy)
		end
		frame:SetPos(fx, fy)
		frame._LotteryNudge = shift
	end
	local x = sx + frame:GetWide() + gap
	local y = sy
	x = math.max(margin, math.min(x, ScrW() - margin - win:GetWide()))
	y = math.Clamp(y, margin, math.max(margin, ScrH() - margin - win:GetTall()))
	if IsValid(host) then
		x, y = host:ScreenToLocal(x, y)
	end
	win:SetPos(x, y)
end

local function EnsureLotteryWin(frame)
	if IsValid(frame.LotteryWin) then
		return frame.LotteryWin
	end
	local host = frame:GetParent()
	local win = vgui.Create("DFrame", IsValid(host) and host or nil)
	win:SetTitle("")
	win:SetDraggable(false)
	win:SetDeleteOnClose(false)
	win:SetKeyboardInputEnabled(false)
	win:DockPadding(0, 0, 0, 0)
	win.Paint = RelapseUI.PaintWindow
	RelapseUI.HideChrome(win)
	win:SetVisible(false)
	if IsValid(win.lblTitle) then
		win.lblTitle:SetVisible(false)
	end
	local title = EasyLabel(win, Phrase("char_choose_scar", "Выберите шрам"), "Relapse30", RelapseUI.Col.Text)
	title:SetContentAlignment(4)
	win.TitleLab = title
	local picks = EasyLabel(win, "", "Relapse20", RelapseUI.Col.Muted)
	picks:SetContentAlignment(4)
	win.PicksLab = picks
	frame.LotteryWin = win
	return win
end

local function UpdateScarTip(frame)
	if not IsValid(frame) or not frame:IsVisible() then
		if IsValid(frame) then
			frame._ScarTipDraw = nil
		end
		return
	end
	local win = frame.LotteryWin
	if not IsValid(win) or not win:IsVisible() or (win:GetAlpha() or 0) < 10 then
		frame._ScarTipDraw = nil
		return
	end
	local mx, my = input.GetCursorPos()
	local card
	for _, btn in ipairs(frame.LotCards or {}) do
		if IsValid(btn) and btn.ScarId then
			local bx, by = btn:LocalToScreen(0, 0)
			local bw, bh = btn:GetSize()
			if mx >= bx and my >= by and mx <= bx + bw and my <= by + bh then
				card = btn
				break
			end
		end
	end
	if not card then
		frame._ScarTipDraw = nil
		return
	end
	local id = card.ScarId
	local name = ScarName(id)
	local runs = ScarEffectRuns(id, RankOf(id) + 1)
	local nameFont = "Relapse20"
	local font = "Relapse15"
	local maxW = RelapseUI.sPx(280)
	local lines = WrapEffectRuns(runs, font, maxW)
	surface.SetFont(nameFont)
	local nameW, nameH = surface.GetTextSize(name)
	surface.SetFont(font)
	local _, lineH = surface.GetTextSize("Ay")
	lineH = math.max(1, lineH)
	local textW = nameW
	for i = 1, #lines do
		textW = math.max(textW, EffectLineWide(lines[i]))
	end
	local pad = RelapseUI.Grid15()
	local gap = RelapseUI.Grid5()
	local w = pad + textW + pad
	local h = pad + nameH + gap + #lines * lineH + pad
	local x = mx - RelapseUI.Grid15() - w
	local y = my
	x = math.max(0, x)
	y = math.Clamp(y, 0, math.max(0, ScrH() - h))
	frame._ScarTipDraw = {
		name = name,
		lines = lines,
		x = x,
		y = y,
		w = w,
		h = h,
		pad = pad,
		gap = gap,
		nameH = nameH,
		lineH = lineH
	}
end

local function DrawScarTip()
	local frame = pCharacter
	local st = IsValid(frame) and frame._ScarTipDraw
	if not st then return end
	RelapseUI.RoundFill(RelapseUI.RadPx("Card"), st.x, st.y, st.w, st.h, RelapseUI.Col.Bg)
	local c = RelapseUI.Col
	draw.SimpleText(st.name, "Relapse20", st.x + st.pad, st.y + st.pad, c.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local ty = st.y + st.pad + st.nameH + st.gap
	surface.SetFont("Relapse15")
	for i = 1, #st.lines do
		local x = st.x + st.pad
		for j = 1, #st.lines[i] do
			local run = st.lines[i][j]
			draw.SimpleText(run.text, "Relapse15", x, ty, run.white and c.Text or c.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			x = x + (surface.GetTextSize(run.text) or 0)
		end
		ty = ty + st.lineH
	end
end

hook.Add("PostRenderVGUI", "RelapseScarLotTip", DrawScarTip)

local function RebuildLottery(frame)
	EnsureLotteryWin(frame)
	local win = frame.LotteryWin
	for _, btn in ipairs(frame.LotCards or {}) do
		if IsValid(btn) then
			btn:Remove()
		end
	end
	frame.LotCards = {}
	if not IsValid(win) then return end

	local st = State()
	local picks = st.Picks or 0
	local offer = (picks > 0 and st.Offer) or {}
	local title = win.TitleLab
	if IsValid(title) then
		title:SetText(Phrase("char_choose_scar", "Выберите шрам"))
		title:SizeToContents()
	end
	local box = LotteryBox(#offer)
	if IsValid(title) then
		local extra = 0
		if IsValid(win.PicksLab) and picks > 1 then
			win.PicksLab:SetText(PhraseF("char_picks", picks))
			win.PicksLab:SizeToContents()
			extra = RelapseUI.Grid15() + win.PicksLab:GetWide()
		end
		box.w = math.max(box.w, box.pad + title:GetWide() + extra + box.pad)
	end
	win:SetSize(box.w, box.h)
	if IsValid(title) then
		title:SetPos(box.pad, box.titleY)
	end
	if IsValid(win.PicksLab) then
		win.PicksLab:SetVisible(picks > 1)
		if picks > 1 and IsValid(title) then
			local _, titleH = title:GetSize()
			local _, pickH = win.PicksLab:GetSize()
			win.PicksLab:SetPos(box.pad + title:GetWide() + RelapseUI.Grid15(), box.titleY + math.max(0, titleH - pickH))
		end
	end
	if #offer == 0 then
		PlaceLottery(frame)
		return
	end
	local x = math.floor((box.w - box.cardsW) * 0.5 + 0.5)
	for i = 1, math.min(3, #offer) do
		local btn = vgui.Create("RelapseScarCard", win)
		btn:SetCardSize(box.size, box.size)
		btn:SetScar(offer[i], true)
		btn:SetPos(x, box.header)
		frame.LotCards[#frame.LotCards + 1] = btn
		x = x + box.size + box.gap
	end
	PlaceLottery(frame)
end

local function RebuildInventory(frame)
	local layout = frame.InvLayout
	if not IsValid(layout) then return end
	for _, ch in ipairs(layout:GetChildren()) do
		if IsValid(ch) then
			ch:Remove()
		end
	end
	frame.InvCards = {}

	local gap = RelapseUI.Grid15(2)
	local size = ScarCardSize()
	layout:SetSpaceX(gap)
	layout:SetSpaceY(gap)

	for _, id in ipairs(GAMEMODE.RelapseScarOrder or {}) do
		local scar = GAMEMODE:GetRelapseScar(id)
		if scar then
			local btn = vgui.Create("RelapseScarCard", layout)
			btn:SetCardSize(size, size)
			btn:SetScar(id, false)
			frame.InvCards[#frame.InvCards + 1] = btn
		end
	end
end

function GM:LayoutCharacterFooter(frame)
	if not IsValid(frame) then return end
	local classBtn = frame.ClassBtn
	local pl = MySelf
	if IsValid(classBtn) then
		local undead = IsValid(pl) and pl:Team() == TEAM_UNDEAD
		local blocked = GAMEMODE.ShouldUseAlternateDynamicSpawn and GAMEMODE:ShouldUseAlternateDynamicSpawn()
		classBtn:SetVisible(undead and not blocked)
		if undead and not blocked then
			RelapseUI.AlignFooterLeft(classBtn)
			RelapseUI.AlignFooterBottom(classBtn)
		end
	end
end

-- Relapse30 optical bottom → Relapse20 capital: 30px (Grid15(2)).
-- Relapse30 sits ~6px under the baseline; Relapse20 ~5px above caps.
local function IdentityMetrics(frame)
	local nameH = RelapseUI.sPx(30)
	if IsValid(frame) and IsValid(frame.NameLab) then
		local h = frame.NameLab:GetTall()
		if h and h > 1 then
			nameH = h
		end
	end
	surface.SetFont("Relapse20")
	local _, rowH = surface.GetTextSize("Ay")
	rowH = math.max(1, rowH)
	local capNudge = RelapseUI.sPx(5)
	local air = RelapseUI.Grid15(2)
	local rowY = math.max(0, nameH - RelapseUI.sPx(6) + air - capNudge)
	local barh = RelapseUI.sPx(10)
	local barY = rowY + rowH - capNudge + air
	local remortY = barY + barh + air - capNudge
	return {
		rowH = rowH,
		rowY = rowY,
		barY = barY,
		barh = barh,
		remortY = remortY,
		h = remortY + rowH
	}
end

function LayoutCharacter(frame)
	if not IsValid(frame) or not IsValid(frame.Body) then return end
	local body = frame.Body
	local bw, bh = body:GetWide(), body:GetTall()
	local m = RelapseUI.M()
	local gap = RelapseUI.Grid15(2)
	local leftW = RelapseUI.ViewerW()
	local met = IdentityMetrics(frame)
	local identH = met.h
	local tabH = m.tabs
	local leftTop = tabH + m.tabGap
	local identY = frame:GetTall() - RelapseUI.sPx(90) - body:GetY() - identH
	identY = math.max(leftTop + RelapseUI.Grid15(14) + gap, identY)
	local modelH = math.max(RelapseUI.Grid15(14), identY - leftTop - gap)

	if IsValid(frame.CharTabs) then
		if frame.CharTabs.RelapseLayout then
			frame.CharTabs:RelapseLayout()
		end
		frame.CharTabs:SetPos(0, 0)
		frame.CharTabs:MoveToFront()
	end

	if IsValid(frame.ModelWell) then
		frame.ModelWell:SetPos(0, leftTop)
		frame.ModelWell:SetSize(leftW, modelH)
		frame.ModelWell:InvalidateLayout(true)
	end
	if IsValid(frame.Model) then
		RelapseUI.FramePlayerPreview(frame.Model)
	end

	if IsValid(frame.Identity) then
		frame.Identity:SetPos(0, identY)
		frame.Identity:SetSize(leftW, identH)
	end

	local rightX = leftW + RelapseUI.Grid15(4)
	local rightW = math.max(1, bw - rightX)
	local gridPage = (frame.CharPage or CHAR_PAGE_GRID) == CHAR_PAGE_GRID

	if IsValid(frame.GridPane) then
		frame.GridPane:SetVisible(gridPage)
		frame.GridPane:SetMouseInputEnabled(gridPage)
		if gridPage then
			frame.GridPane:SetPos(rightX, 0)
			frame.GridPane:SetSize(rightW, bh)
			frame.GridPane:MoveToFront()
		else
			frame.GridPane.Dragging = false
			frame.GridPane:MouseCapture(false)
		end
	end

	local function showScars(vis)
		if IsValid(frame.Desc) then
			frame.Desc:SetVisible(vis)
			frame.Desc:SetMouseInputEnabled(vis)
		end
		if IsValid(frame.InvScroll) then
			frame.InvScroll:SetVisible(vis)
			frame.InvScroll:SetMouseInputEnabled(vis)
		end
	end

	if gridPage then
		showScars(false)
		GAMEMODE:LayoutCharacterFooter(frame)
		return
	end

	showScars(true)

	-- Relapse30 cell sits ~6px above caps. 90px from the window top to the name ink.
	local descTop = RelapseUI.sPx(90) - RelapseUI.sPx(6) - body:GetY()
	surface.SetFont("Relapse30")
	local _, titleCell = surface.GetTextSize("Ay")
	titleCell = math.max(1, titleCell or RelapseUI.sPx(30))
	local minGainY = titleCell - RelapseUI.sPx(6) + RelapseUI.Grid15() - RelapseUI.sPx(5)
	surface.SetFont("Relapse20")
	local _, gainH = surface.GetTextSize("Ay")
	gainH = math.max(1, gainH)
	local sketchExtra = 0
	local scar = frame.SelectedId and GAMEMODE:GetRelapseScar(frame.SelectedId)
	if scar and not scar.InPool then
		surface.SetFont("Relapse15")
		local _, sketchH = surface.GetTextSize("Ay")
		sketchExtra = RelapseUI.Grid15() + math.max(1, sketchH or 0)
	end
	local card = ScarCardSize()
	local rowsH = card * 3 + gap * 2
	-- Relapse20 cell hangs sPx(5) under the ink. 45px from that ink to the cards.
	local cardsGap = RelapseUI.sPx(45) - RelapseUI.sPx(5)
	-- Lowest row sits 90px above the window bottom. Title stays on the top 90px line.
	local cardsBottom = math.min(bh, frame:GetTall() - RelapseUI.sPx(90) - body:GetY())
	local cardsY = cardsBottom - rowsH
	local gainY = cardsY - cardsGap - gainH - sketchExtra - descTop
	if gainY < minGainY then
		gainY = minGainY
		cardsY = descTop + gainY + gainH + sketchExtra + cardsGap
		if bh - cardsY < rowsH then
			cardsY = math.max(0, bh - rowsH)
		end
	end
	local descH = gainY + gainH + sketchExtra
	frame.ScarGainY = gainY
	if IsValid(frame.Desc) then
		frame.Desc:SetPos(rightX, descTop)
		frame.Desc:SetSize(rightW, math.max(0, descH))
	end
	if IsValid(frame.InvScroll) then
		frame.InvScroll:SetPos(rightX, cardsY)
		frame.InvScroll:SetSize(rightW, math.max(1, bh - cardsY))
	end
	if IsValid(frame.InvLayout) then
		frame.InvLayout:SetPos(0, 0)
		frame.InvLayout:SetWide(math.max(1, frame.InvScroll:GetWide()))
	end
	GAMEMODE:LayoutCharacterFooter(frame)
end

local function DropRemortLab(frame)
	if not IsValid(frame) then return end
	if IsValid(frame.RemortLab) then
		frame.RemortLab:Remove()
		frame.RemortLab = nil
	end
	local ident = frame.Identity
	if not IsValid(ident) then return end
	for _, ch in ipairs(ident:GetChildren()) do
		if IsValid(ch) and ch ~= frame.NameLab and ch ~= frame.CycleLab then
			ch:Remove()
		end
	end
end

local function Ink(text, font, x, y, col)
	text = tostring(text or "")
	draw.SimpleText(text, font, x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	surface.SetFont(font)
	return surface.GetTextSize(text) or 0
end

local function PaintIdentity(frame, w, h)
	DropRemortLab(frame)
	if IsValid(frame.NameLab) then
		frame.NameLab:SetPos(0, 0)
	end
	if IsValid(frame.CycleLab) then
		frame.CycleLab:SetVisible(false)
	end
	local met = IdentityMetrics(frame)
	local font = "Relapse20"
	local gap = RelapseUI.Grid5()
	local c = RelapseUI.Col
	local x = 0
	local rowY = met.rowY
	x = x + Ink(Phrase("char_level_lab", "Уровень") .. ":", font, x, rowY, c.Muted)
	x = x + gap
	x = x + Ink(frame.LevelNum or "1", font, x, rowY, c.Text)
	x = x + Ink("/" .. (frame.MaxLevelNum or "30"), font, x, rowY, c.Muted)
	local have = frame.XPHaveText or "0"
	local need = " / " .. (frame.XPNeedText or "0")
	surface.SetFont(font)
	local haveW = surface.GetTextSize(have) or 0
	local needW = surface.GetTextSize(need) or 0
	local xpX = w - RelapseUI.Grid15() - haveW - needW
	Ink(have, font, xpX, rowY, c.Text)
	Ink(need, font, xpX + haveW, rowY, c.Muted)
	local progress = frame.XPProgress or 0
	frame.LerpXP = Lerp(FrameTime() * 8, frame.LerpXP or progress, progress)
	RelapseUI.PaintHudHairBar(0, met.barY, w, met.barh, frame.LerpXP, RelapseUI.Col.Ok, nil, nil, RelapseUI.Shadow)
	x = 0
	x = x + Ink(Phrase("char_remort_lab", "Реморт") .. ":", font, x, met.remortY, c.Muted)
	x = x + gap
	Ink(frame.RemortNum or "0", font, x, met.remortY, c.Text)
	local points = 0
	if (frame.CharPage or CHAR_PAGE_GRID) == CHAR_PAGE_SCARS then
		points = (GAMEMODE.RelapseScarState and GAMEMODE.RelapseScarState.Picks) or 0
	elseif GAMEMODE.GetCycleGridSPRemaining and IsValid(MySelf) then
		points = GAMEMODE:GetCycleGridSPRemaining(MySelf) or 0
	end
	local lab = Phrase("char_sp_lab", "Очки") .. ":"
	local num = tostring(points)
	surface.SetFont(font)
	local labW = surface.GetTextSize(lab) or 0
	local numW = surface.GetTextSize(num) or 0
	local pointsX = w - RelapseUI.Grid15() - labW - gap - numW
	Ink(lab, font, pointsX, met.remortY, c.Muted)
	Ink(num, font, pointsX + labW + gap, met.remortY, c.Text)
	return true
end

local function BindIdentityPaint(frame)
	if not IsValid(frame) or not IsValid(frame.Identity) then return end
	frame.Identity.Paint = function(me, w, h)
		return PaintIdentity(frame, w, h)
	end
end

local function UpdateIdentity(frame)
	if not IsValid(frame) or not IsValid(MySelf) then return end
	local pl = MySelf
	local name = pl:Name() or ""
	if IsValid(frame.NameLab) then
		frame.NameLab:SetText(Ellipsize(name, "Relapse30", math.max(8, frame.Identity:GetWide())))
		frame.NameLab:SizeToContents()
	end
	local level = pl:GetZSLevel() or 1
	local maxLevel = GAMEMODE.MaxLevel or 30
	frame.LevelNum = tostring(level)
	frame.MaxLevelNum = tostring(maxLevel)
	if IsValid(frame.CycleLab) then
		frame.CycleLab:SetVisible(false)
	end
	frame.XPProgress = GAMEMODE:ProgressForXP(pl:GetZSXP() or 0)
	local cur = GAMEMODE:XPForLevel(level)
	local nxt = GAMEMODE:XPForLevel(math.min(level + 1, maxLevel))
	local have = math.max(0, (pl:GetZSXP() or 0) - cur)
	local need = math.max(1, nxt - cur)
	if level >= maxLevel then
		have = need
	end
	frame.XPHaveText = CommaNum(have)
	frame.XPNeedText = CommaNum(need)
	local remort = 0
	if pl.GetZSRemortLevel then
		remort = pl:GetZSRemortLevel() or 0
	end
	frame.RemortNum = tostring(remort)
	if IsValid(frame.Model) then
		SyncPreview(frame.Model, pl)
	end
end

function GM:RefreshCharacterSheet()
	local frame = pCharacter
	if not IsValid(frame) then return end
	DropRemortLab(frame)
	BindIdentityPaint(frame)
	LayoutCharacter(frame)
	RebuildLottery(frame)
	RebuildInventory(frame)
	UpdateIdentity(frame)
	local id, lottery = DefaultSelection(frame)
	if id then
		SelectScar(frame, id, lottery, true)
	end
	self:LayoutCharacterFooter(frame)
end

function GM:CharacterSheetOpen()
	return IsValid(pCharacter) and (pCharacter:IsVisible() or pCharacter._RelapseClosing)
end

function GM:CloseCharacterSheet(fromEsc, instant)
	if not (pCharacter and pCharacter:IsValid()) then
		return false
	end
	if RelapseUI.IconsDevUnbindScar then
		RelapseUI.IconsDevUnbindScar()
	end
	if pCharacter._StatTipDraw then
		pCharacter._StatTipDraw = nil
	end
	pCharacter._ScarTipDraw = nil
	if IsValid(pCharacter.LotteryWin) then
		pCharacter.LotteryWin:SetVisible(false)
	end
	if not (pCharacter:IsVisible() or pCharacter._RelapseClosing) then
		return false
	end
	if instant or not pCharacter._RelapseClosing then
		pCharacter:Close(instant)
	end
	if fromEsc then
		self.ShopOverlayBlockPause = true
		gui.HideGameUI()
	end
	return true
end

function GM:ToggleCharacterSheet()
	if self:CharacterSheetOpen() then
		self:CloseCharacterSheet()
		return
	end
	self:OpenCharacterSheet()
end

function GM:OpenCharacterSheet()
	if not IsValid(MySelf) then
		MySelf = LocalPlayer()
	end
	if not IsValid(MySelf) then return end

	if self.CloseOtherOverlays then
		self:CloseOtherOverlays("character")
	end

	PlayMenuOpenSound()
	net.Start("zs_scars_request")
	net.SendToServer()

	if IsValid(pCharacter) then
		DropRemortLab(pCharacter)
		BindIdentityPaint(pCharacter)
		if IsValid(pCharacter.GridPane) then
			pCharacter.GridPane.Zoom = GRID_ZOOM_START
			pCharacter.GridPane.DesiredZoom = GRID_ZOOM_START
			pCharacter.GridPane.CamY = 0
			pCharacter.GridPane.CamZ = 0
			pCharacter.GridPane.PanVY = 0
			pCharacter.GridPane.PanVZ = 0
		end
		RelapseUI.ShowShopFrame(pCharacter)
		self:RefreshCharacterSheet()
		BindStatTip(pCharacter)
		SyncScarIconsDev(pCharacter)
		return
	end
	RelapseUI.CreateFonts()

	local frame, L, topspace, bottomspace, propertysheet = RelapseUI.BuildShopFrame("char_title", {
		deleteOnClose = false
	})
	pCharacter = frame
	self.CharacterSheet = frame

	if IsValid(topspace) then
		topspace:SetVisible(false)
		topspace:SetMouseInputEnabled(false)
	end
	if IsValid(propertysheet) then
		propertysheet:SetVisible(false)
		propertysheet:SetMouseInputEnabled(false)
		propertysheet:SetSize(0, 0)
	end

	local body = vgui.Create("DPanel", frame)
	body:SetPaintBackground(false)
	body:SetPos(L.pad, L.headerh)
	body:SetSize(L.innerW, L.sheetH)
	frame.Body = body

	local modelWell = vgui.Create("DPanel", body)
	modelWell:SetPaintBackground(false)
	frame.ModelWell = modelWell

	local mdl = vgui.Create("DModelPanelEx", modelWell)
	mdl:SetPaintBackground(false)
	mdl:Dock(FILL)
	frame.Model = mdl

	local identity = vgui.Create("DPanel", body)
	identity:SetPaintBackground(false)
	frame.Identity = identity
	frame.NameLab = EasyLabel(identity, "", "Relapse30", RelapseUI.Col.Text)
	frame.CycleLab = EasyLabel(identity, "", "Relapse20", RelapseUI.Col.Muted)
	BindIdentityPaint(frame)

	frame.CharPage = CHAR_PAGE_GRID
	local grid = vgui.Create("RelapseCycleGrid", body)
	frame.GridPane = grid

	local desc = vgui.Create("DPanel", body)
	desc:SetPaintBackground(false)
	frame.Desc = desc
	desc.Paint = function(me, w, h)
		local id = frame.SelectedId
		if not id then
			draw.SimpleText(Phrase("char_empty_desc", ""), GAIN_FONT, 0, 0, RelapseUI.Col.Muted)
			return true
		end
		local scar = GAMEMODE:GetRelapseScar(id)
		local c = RelapseUI.Col
		draw.SimpleText(ScarName(id), "Relapse30", 0, 0, c.Text)
		local y = frame.ScarGainY
		if not y then
			surface.SetFont("Relapse30")
			local titleCell = select(2, surface.GetTextSize("Ay"))
			y = titleCell - RelapseUI.sPx(6) + RelapseUI.Grid15() - RelapseUI.sPx(5)
		end
		DrawScarGain(id, RankOf(id), 0, y)
		if scar and not scar.InPool then
			surface.SetFont(GAIN_FONT)
			local lineH = select(2, surface.GetTextSize("Ay"))
			DrawWrapped(Phrase("char_sketch", ""), "Relapse15", 0, y + lineH + RelapseUI.Grid15(), w, c.Muted)
		end
		return true
	end

	local invScroll = vgui.Create("DScrollPanel", body)
	invScroll.Paint = function() return true end
	RelapseUI.StyleScroll(invScroll)
	frame.InvScroll = invScroll
	local layout = vgui.Create("DIconLayout", invScroll)
	frame.InvLayout = layout

	local classBtn = vgui.Create("DButton", bottomspace)
	classBtn:SetFont("Relapse20")
	classBtn:SetText(Phrase("char_class", "Class"))
	classBtn:SetSize(RelapseUI.Cells(12), L.m.btnH)
	classBtn.Paint = RelapseUI.PaintPrimaryButton
	classBtn.DoClick = function()
		surface.PlaySound("buttons/button14.wav")
		if GAMEMODE.OpenClassSelect then
			GAMEMODE:OpenClassSelect()
		end
	end
	frame.ClassBtn = classBtn

	frame.Think = function(me)
		if not me:IsVisible() then
			if IsValid(me.LotteryWin) then
				me.LotteryWin:SetVisible(false)
			end
			me._ScarTipDraw = nil
			return
		end
		UpdateIdentity(me)
		PlaceLottery(me)
		UpdateScarTip(me)
	end

	frame.CharTabs = RelapseUI.CreateFilterStrip(body, {
		Phrase("char_tab_skills", "Skills"),
		Phrase("char_tab_scars", "Scars")
	}, CHAR_PAGE_GRID, function(index)
		ApplyCharPage(frame, index)
	end)
	if IsValid(frame.RelapseClose) then
		frame.RelapseClose:MoveToFront()
	end
	body.PerformLayout = function()
		LayoutCharacter(frame)
	end

	ApplyCharPage(frame, CHAR_PAGE_GRID)
	RelapseUI.FinishShopFrame(frame, propertysheet)
	self:RefreshCharacterSheet()
	BindStatTip(frame)
end

net.Receive("zs_scars_sync", function()
	local gm = GAMEMODE
	local st = gm.RelapseScarState
	if not st then
		st = {Picks = 0, Offer = {}, Ranks = {}, Counts = {}, Meters = {}}
		gm.RelapseScarState = st
	end
	st.Picks = net.ReadUInt(8)
	local nOffer = net.ReadUInt(3)
	st.Offer = {}
	for i = 1, nOffer do
		st.Offer[i] = net.ReadString()
	end
	local nRanks = net.ReadUInt(8)
	st.Ranks = {}
	for _ = 1, nRanks do
		local id = net.ReadString()
		st.Ranks[id] = net.ReadUInt(16)
	end
	local nMeters = net.ReadUInt(8)
	st.Counts = {}
	st.Meters = {}
	for _ = 1, nMeters do
		local id = net.ReadString()
		st.Counts[id] = net.ReadUInt(16)
		st.Meters[id] = net.ReadFloat()
	end
	if gm.RefreshCharacterSheet then
		gm:RefreshCharacterSheet()
	end
end)

net.Receive("zs_cycle_grid_sync", function()
	local gm = GAMEMODE
	local pl = MySelf
	if not IsValid(pl) then
		pl = LocalPlayer()
	end
	if not IsValid(pl) or not gm or not gm.InitCycleGrid then
		return
	end
	local had = pl.CycleGridTaken ~= nil
	local before = had and gm:CycleGridTakenCount(pl) or 0
	local muteBefore = ""
	if had and pl.CycleGridMute then
		local keys = {}
		for key in pairs(pl.CycleGridMute) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		muteBefore = table.concat(keys, ",")
	end
	gm:InitCycleGrid(pl, true)
	local n = net.ReadUInt(8)
	for _ = 1, n do
		local id = net.ReadString()
		if gm.CycleGridCatalog[id] then
			pl.CycleGridTaken[id] = true
		end
	end
	local nm = net.ReadUInt(8)
	local muteKeys = {}
	for _ = 1, nm do
		local treeId = net.ReadString()
		local slot = net.ReadUInt(5)
		if gm:GetCycleGridNode(treeId, slot) then
			local key = gm:CycleGridMuteKey(treeId, slot)
			pl.CycleGridMute[key] = true
			muteKeys[#muteKeys + 1] = key
		end
	end
	table.sort(muteKeys)
	local muteAfter = table.concat(muteKeys, ",")
	local nLive = net.ReadUInt(8)
	for _ = 1, nLive do
		local id = net.ReadString()
		if gm.CycleGridCatalog[id] then
			pl.CycleGridLive[id] = true
		end
	end
	local nLiveMute = net.ReadUInt(8)
	for _ = 1, nLiveMute do
		local treeId = net.ReadString()
		local slot = net.ReadUInt(5)
		if gm:GetCycleGridNode(treeId, slot) then
			pl.CycleGridLiveMute[gm:CycleGridMuteKey(treeId, slot)] = true
		end
	end
	if had and gm:CycleGridTakenCount(pl) > before then
		surface.PlaySound("buttons/button14.wav")
	elseif had and muteBefore ~= muteAfter then
		surface.PlaySound("buttons/button15.wav")
	end
	if gm.RefreshCharacterSheet then
		gm:RefreshCharacterSheet()
	end
end)
