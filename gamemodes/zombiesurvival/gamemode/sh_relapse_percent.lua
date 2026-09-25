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

function GM:CountOwnNails(pl, ent)
	if not IsValid(pl) or not IsValid(ent) or not ent.GetNails then
		return 0
	end
	local nails = ent:GetNails()
	if not nails then
		return 0
	end
	local n = 0
	for _, nail in pairs(nails) do
		if IsValid(nail) and nail.GetOwner and nail:GetOwner() == pl then
			n = n + 1
		end
	end
	return n
end

-- Flat repair plus +1% per rank for each of your nails in this prop. Same Σp.
function GM:GetPropRepairPercentMul(pl, ent)
	local skill = 0
	if IsValid(pl) and isnumber(pl.RepairRateMul) then
		skill = pl.RepairRateMul - 1
	end
	local perNail = self:GetUpgradePercent(pl, "RepairPerNail") * self:CountOwnNails(pl, ent)
	return self:StackPercentMul(self:GetUpgradePercent(pl, "Repair"), skill, perNail)
end

function GM:GetDeployPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.DeploySpeedMultiplier) then
		skill = pl.DeploySpeedMultiplier - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "Deploy"), skill)
end

function GM:GetHammerSwingPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.HammerSwingDelayMul) then
		skill = (1 / math.max(pl.HammerSwingDelayMul, 0.01)) - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "HammerSwing"), skill)
end

function GM:GetMeleeSwingPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.MeleeSwingDelayMul) then
		skill = (1 / math.max(pl.MeleeSwingDelayMul, 0.01)) - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "MeleeSwing"), skill)
end

-- Shorter delay = faster melee. Hammer stays on HammerSwing. Gun bash unchanged.
-- Low stamina stretches delay (status mul, not an upgrade percent).
function GM:GetMeleeAttackDelayMul(pl, wep)
	local arm = 1
	if IsValid(pl) and pl.GetMeleeSpeedMul then
		arm = pl:GetMeleeSpeedMul()
	end
	if not IsValid(wep) or not self:IsMeleeDamageInflictor(wep) then
		return 1
	end
	if wep.GetClass and wep:GetClass() == "weapon_zs_hammer" then
		return arm
	end
	local delay = arm / math.max(self:GetMeleeSwingPercentMul(pl), 0.01)
	if self.GetHumanStaminaMeleeDelayMul then
		delay = delay * self:GetHumanStaminaMeleeDelayMul(pl, wep)
	end
	return delay
end

function GM:GetBarricadeDamageMul(pl)
	if not IsValid(pl) or not pl:IsPlayer() or pl:Team() ~= TEAM_UNDEAD then
		return 1
	end
	return self:GetUpgradePercentMul(pl, "BarricadeDamage")
end

function GM:UndeadDamageDealer(attacker)
	if not IsValid(attacker) then return end
	if attacker.PBAttacker and IsValid(attacker.PBAttacker) then
		attacker = attacker.PBAttacker
	end
	if attacker:IsPlayer() and attacker:Team() == TEAM_UNDEAD then
		return attacker
	end
end

-- prop_physics / func_physbox with no nails. Doors and nailed barricades are other skills.
function GM:IsLooseProp(ent)
	if not IsValid(ent) or ent:IsPlayer() then return false end
	if ent.IsNailed and ent:IsNailed() then return false end
	local class = ent:GetClass()
	return string.sub(class, 1, 12) == "prop_physics" or string.sub(class, 1, 12) == "func_physbox"
end

function GM:ApplyUndeadOutgoingDamage(attacker, ent, dmginfo)
	local zombie = self:UndeadDamageDealer(attacker)
	if not zombie or not IsValid(ent) or not dmginfo or ent == zombie then return end
	local field
	if ent:IsPlayer() then
		if ent:Team() == TEAM_HUMAN then
			field = "ZombieHumanDamage"
		end
	elseif ent:GetClass() == "prop_door_rotating" or ent:GetClass() == "func_door_rotating" then
		field = "ZombieDoorDamage"
	elseif self:IsLooseProp(ent) then
		field = "LoosePropDamage"
	end
	if not field then return end
	local mul = self:GetUpgradePercentMul(zombie, field)
	if mul ~= 1 then
		dmginfo:ScaleDamage(mul)
	end
end

-- SwingTime only. Primary.Delay stays on GetMeleeAttackDelayMul.
-- MeleeWindup is swing speed: duration = SwingTime / (1+Σp).
function GM:GetMeleeWindupTimeMul(pl, wep)
	if not IsValid(wep) or not self.IsMeleeDamageInflictor or not self:IsMeleeDamageInflictor(wep) then
		return 1
	end
	if wep.GetClass and wep:GetClass() == "weapon_zs_hammer" then
		return 1
	end
	local speed = self:GetUpgradePercentMul(pl, "MeleeWindup")
	return 1 / math.max(speed, 0.01)
end

-- Chance, not 1+Σp. 0.03 = 3% of connecting melee swings miss.
function GM:GetMeleeMissChance(pl)
	return math.max(0, self:GetUpgradePercent(pl, "MeleeMiss"))
end

function GM:ShouldMeleeMiss(pl, wep)
	if not IsValid(pl) or pl:Team() ~= TEAM_HUMAN then
		return false
	end
	if IsValid(wep) then
		if wep.GetClass and wep:GetClass() == "weapon_zs_hammer" then
			return false
		end
		if not self:IsMeleeDamageInflictor(wep) then
			return false
		end
	end
	local chance = self:GetMeleeMissChance(pl)
	if chance <= 0 then
		return false
	end
	local seed = pl:EntIndex()
	local cmd = pl.GetCurrentCommand and pl:GetCurrentCommand()
	if cmd then
		seed = seed + cmd:CommandNumber() * 32
	end
	if IsValid(wep) then
		seed = seed + wep:EntIndex()
	end
	return util.SharedRandom("relapse_melee_miss", 0, 1, seed) < chance
end

function GM:GetZombieHitSlowMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.SlowEffTakenMul) then
		skill = pl.SlowEffTakenMul - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "HitSlow"), skill)
end

-- Medkit charge recovery speed. Time = base / (1+Σp). Old MedicCooldownMul is a time mul; fold it as 1/mul−1.
function GM:GetMedkitChargeSpeedMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.MedicCooldownMul) and pl.MedicCooldownMul > 0 then
		skill = (1 / pl.MedicCooldownMul) - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "MedkitCharge"), skill)
end

function GM:GetMedkitChargeDelay(pl, delay)
	delay = tonumber(delay) or 0
	if delay <= 0 or not IsValid(pl) then
		return delay
	end
	return delay / math.max(self:GetMedkitChargeSpeedMul(pl), 0.01)
end

function GM:GetMedicHealPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.MedicHealMul) then
		skill = pl.MedicHealMul - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "MedicHeal"), skill)
end

function GM:GetHealReceivedPercentMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.HealingReceived) then
		skill = pl.HealingReceived - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "Heal"), skill)
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

-- Share of a hit that blood armor eats. Base 0.5. Grid and old skills add onto it.
function GM:GetBloodArmorAbsorbRatio(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.BloodArmorDamageReductionAdd) then
		skill = pl.BloodArmorDamageReductionAdd
	end
	return 0.5 + skill + self:GetUpgradePercent(pl, "BloodAbsorb")
end

-- All blood armor gained. Old BloodarmorGainMul is the same sum, not a second mul.
function GM:GetBloodArmorGainMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.BloodarmorGainMul) then
		skill = pl.BloodarmorGainMul - 1
	end
	return self:StackPercentMul(self:GetUpgradePercent(pl, "BloodGain"), skill)
end

-- Meal converted to blood (Glutton). Metabolism joins BloodGain on this channel only.
function GM:GetFoodBloodArmorMul(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.BloodarmorGainMul) then
		skill = pl.BloodarmorGainMul - 1
	end
	return self:StackPercentMul(
		self:GetUpgradePercent(pl, "BloodGain"),
		self:GetUpgradePercent(pl, "FoodBlood"),
		skill
	)
end

-- Extra blood from a normal meal: meal × (FoodBlood + BloodGain). 0 without Metabolism.
function GM:GetNormalFoodBloodAmount(pl, meal)
	meal = tonumber(meal) or 0
	if meal <= 0 or not IsValid(pl) then
		return 0
	end
	local extra = self:GetUpgradePercent(pl, "FoodBlood")
	if extra <= 0 then
		return 0
	end
	local skill = 0
	if isnumber(pl.BloodarmorGainMul) then
		skill = pl.BloodarmorGainMul - 1
	end
	local amount = meal * (extra + self:GetUpgradePercent(pl, "BloodGain") + skill)
	if amount <= 0 then
		return 0
	end
	return math.floor(amount + 0.5)
end

-- Share of blood-armor absorb that comes back as HP. Rate, not 1+Σp.
function GM:GetBloodArmorReturnRate(pl)
	return math.max(0, self:GetUpgradePercent(pl, "BloodReturn"))
end

-- Conversion rate, not 1+Σp. 0.01 = 1% of melee damage to blood armor.
function GM:GetMeleeBloodArmorRate(pl)
	local skill = 0
	if IsValid(pl) and isnumber(pl.MeleeDamageToBloodArmorMul) then
		skill = pl.MeleeDamageToBloodArmorMul
	end
	return math.max(0, skill + self:GetUpgradePercent(pl, "BloodFromMelee"))
end

function GM:GetMeleeViewPunchMul(pl)
	if not IsValid(pl) or (pl.Team and pl:Team() ~= TEAM_HUMAN) then
		return 1
	end
	return self:GetUpgradePercentMul(pl, "MeleeViewPunch")
end

function GM:GetHumanPalsySkillShakeAdd(pl)
	if IsValid(pl) and isnumber(pl.AimShakeMul) then
		return pl.AimShakeMul - 1
	end
	return 0
end

function GM:GetHumanPalsyAimShakeMul(pl)
	return self:StackPercentMul(self:GetUpgradePercent(pl, "AimShake"), self:GetHumanPalsySkillShakeAdd(pl))
end

function GM:GetHumanPalsyHPShakeMul(pl)
	return self:StackPercentMul(
		self:GetUpgradePercent(pl, "AimShake"),
		self:GetUpgradePercent(pl, "AimShakeHP"),
		self:GetHumanPalsySkillShakeAdd(pl)
	)
end

function GM:GetHumanPalsyFearShakeMul(pl)
	return self:StackPercentMul(
		self:GetUpgradePercent(pl, "AimShake"),
		self:GetUpgradePercent(pl, "AimShakeFear"),
		self:GetHumanPalsySkillShakeAdd(pl)
	)
end

function GM:GetHumanPalsyHPFrac(pl)
	local frac = self.HumanPalsyHPFrac or 0.40
	if self.GetUpgradePercent then
		frac = frac + self:GetUpgradePercent(pl, "AimShakeThreshold")
	end
	return math.Clamp(frac, 0.05, 0.90)
end

function GM:GetHumanPalsyHPThreshold(pl, maxhealth)
	maxhealth = tonumber(maxhealth) or (IsValid(pl) and pl:GetMaxHealth()) or 100
	if IsValid(pl) and pl.HasPalsy then
		return maxhealth - 1
	end
	return maxhealth * self:GetHumanPalsyHPFrac(pl)
end

function GM:GetHumanPalsyFearPower()
	if not CLIENT then
		return 0
	end
	local v = self.CachedFearPower and self:CachedFearPower()
	return tonumber(v) or 0
end

function GM:GetHumanPalsyCurve(u)
	u = math.Clamp(tonumber(u) or 0, 0, 1)
	local inflect = self.HumanPalsyInflect or 0.50
	local steep = self.HumanPalsySteep or 7.5
	if self.RelapseLogistic01 then
		return self:RelapseLogistic01(u, inflect, steep)
	end
	return u
end

function GM:GetHumanPalsyHPShake(health, threshold)
	local rate = self.HumanPalsyHPRate or 4.5
	if not (health <= threshold and threshold > 0) then
		return 0
	end
	return self:GetHumanPalsyCurve(1 - health / threshold) * rate
end

function GM:GetHumanPalsyFearShake(fear)
	fear = tonumber(fear) or 0
	local start = self.HumanPalsyFearStart or 0.12
	local rate = self.HumanPalsyFearRate or 6
	if fear <= start then
		return 0
	end
	local u = math.min(1, (fear - start) / math.max(0.001, 1 - start))
	return self:GetHumanPalsyCurve(u) * rate
end

function GM:HumanPalsyShouldShake(pl, health, threshold, frightened, gunsway)
	if self.ZombieEscape then
		return false
	end
	if health <= threshold or frightened or gunsway then
		return true
	end
	return self:GetHumanPalsyFearPower() > (self.HumanPalsyFearStart or 0.12)
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

-- Place and pack speed. Not crates, plants, lamps, or cade kits.
GM.MechanicsDeviceClasses = {
	prop_gunturret = true,
	prop_gunturret_assault = true,
	prop_gunturret_buckshot = true,
	prop_gunturret_rocket = true,
	prop_drone = true,
	prop_drone_pulse = true,
	prop_drone_hauler = true,
	prop_ffemitter = true,
	prop_repairfield = true,
	prop_manhack = true,
	prop_manhack_saw = true,
	prop_zapper = true,
	prop_zapper_arc = true,
	prop_rollermine = true
}

function GM:IsMechanicsDeviceEnt(ent)
	if not IsValid(ent) then
		return false
	end
	return not self.MechanicsHealthSkip[ent:GetClass()]
end

function GM:IsMechanicsDeviceClass(class)
	return class and self.MechanicsDeviceClasses and self.MechanicsDeviceClasses[class] == true
end

-- Speed. Time = base / (1+Σp). Old pack mul stays a time factor beside it.
function GM:GetDeviceHandleSpeedMul(pl)
	return self:GetUpgradePercentMul(pl, "DeviceHandle")
end

function GM:GetDevicePlaceDelay(pl, wep, delay)
	delay = tonumber(delay) or 0
	if delay <= 0 or not IsValid(wep) or not self:IsMechanicsDeviceClass(wep.DeployClass) then
		return delay
	end
	return delay / math.max(self:GetDeviceHandleSpeedMul(pl), 0.01)
end

function GM:GetTurretFireDelay(pl, delay)
	delay = tonumber(delay) or 0
	if delay <= 0 or not IsValid(pl) then
		return delay
	end
	return delay / math.max(self:GetUpgradePercentMul(pl, "TurretFire"), 0.01)
end

-- Forced mode. Heat is real seconds of continuous engagement.
-- Damage uses heat / durability. Durability is the same sum as max health:
-- 1 + DeviceHealth + old deployable and turret health mods.
-- +15% reliability stretches the whole curve by 1.15 (break ~93 s, not 81 s).
-- Silence sheds TurretForcedCool heat per second and does not restore health.
GM.TurretForcedGrace = 6
GM.TurretForcedWear = 0.00036
GM.TurretForcedCool = 0.35

function GM:GetTurretForcedDurability(pl, ent)
	local mul = 1
	if self.GetMechanicsDeviceHealthMul then
		mul = self:GetMechanicsDeviceHealthMul(pl, ent, "DeployableHealthMul", "TurretHealthMul")
	end
	return math.max(tonumber(mul) or 1, 0.01)
end

function GM:HasTurretForcedMode(pl)
	if not (IsValid(pl) and self.CycleGridLiveHas and self:CycleGridLiveHas(pl, "mechanics_10")) then
		return false
	end
	if self.CycleGridLiveSkillMuted and self:CycleGridLiveSkillMuted(pl, "mechanics_10") then
		return false
	end
	return true
end

function GM:ApplyTurretForcedWear(ent, owner, engaging)
	if not IsValid(ent) or ent.Destroyed then
		return
	end
	if not self:HasTurretForcedMode(owner) then
		ent.ForcedHeat = nil
		ent.ForcedHeatTick = nil
		return
	end

	local now = CurTime()
	local prev = ent.ForcedHeatTick or now
	ent.ForcedHeatTick = now
	local dt = math.Clamp(now - prev, 0, 0.25)
	if dt <= 0 then
		return
	end

	local heat = ent.ForcedHeat or 0
	local mul = self:GetTurretForcedDurability(owner, ent)
	if engaging then
		heat = heat + dt
		local over = heat / mul - self.TurretForcedGrace
		if over > 0 then
			local maxhp = ent:GetMaxObjectHealth()
			local hp = ent:GetObjectHealth()
			if maxhp > 0 and hp > 0 then
				ent:SetObjectHealth(hp - maxhp * self.TurretForcedWear * over * dt / mul)
			end
		end
	else
		heat = math.max(0, heat - dt * self.TurretForcedCool)
	end
	ent.ForcedHeat = heat
end

function GM:GetGunFireDelay(pl, delay)
	delay = tonumber(delay) or 0
	if delay <= 0 or not IsValid(pl) then
		return delay
	end
	return delay / math.max(self:GetUpgradePercentMul(pl, "GunFire"), 0.01)
end

-- Arsenal and resupply. Remantler stays out of the supply tree.
GM.SupplyDeployClasses = {
	prop_arsenalcrate = true,
	prop_resupplybox = true
}

function GM:IsSupplyDeployClass(class)
	return class and self.SupplyDeployClasses and self.SupplyDeployClasses[class] == true
end

function GM:GetSupplyHandleSpeedMul(pl)
	return self:GetUpgradePercentMul(pl, "SupplyHandle")
end

function GM:GetSupplyPlaceDelay(pl, delay)
	delay = tonumber(delay) or 0
	if delay <= 0 then
		return delay
	end
	return delay / math.max(self:GetSupplyHandleSpeedMul(pl), 0.01)
end

function GM:GetSupplySellRate(pl)
	return math.max(0, self:GetUpgradePercent(pl, "SupplySell"))
end

function GM:GetSupplyDeployPointPrice(class)
	local info = self.DeployableInfo and self.DeployableInfo[class]
	local wep = info and info.WepClass
	if not wep or not self.Items then
		return 0
	end
	for _, item in pairs(self.Items) do
		if istable(item) and item.PointShop and item.SWEP == wep then
			return tonumber(item.Price) or 0
		end
	end
	return 0
end

function GM:GetSupplySellPoints(pl, class)
	if not self:IsSupplyDeployClass(class) then
		return 0
	end
	local rate = self:GetSupplySellRate(pl)
	if rate <= 0 then
		return 0
	end
	return math.max(0, math.floor(self:GetSupplyDeployPointPrice(class) * rate + 0.5))
end

function GM:GetSupplySellHint(pl, class)
	local pts = self:GetSupplySellPoints(pl, class)
	if pts <= 0 or not translate or not translate.Format then
		return
	end
	return translate.Format("supply_sell_hint", pts)
end

function GM:BeginSupplySell(pl, ent)
	if not IsValid(pl) or not IsValid(ent) or not ent.PackUp then
		return false
	end
	if pl:Team() ~= TEAM_HUMAN or not pl:Alive() then
		return false
	end
	local class = ent:GetClass()
	if not self:IsSupplyDeployClass(class) then
		return false
	end
	if self:GetSupplySellPoints(pl, class) <= 0 then
		return false
	end
	local owner = ent.GetObjectOwner and ent:GetObjectOwner()
	if owner ~= pl then
		return false
	end
	ent:PackUp(pl, true)
	return true
end

function GM:CompleteSupplySell(pl, ent)
	if not IsValid(pl) or not IsValid(ent) then
		return false
	end
	if pl:Team() ~= TEAM_HUMAN or not pl:Alive() then
		return false
	end
	local class = ent:GetClass()
	local pts = self:GetSupplySellPoints(pl, class)
	if pts <= 0 then
		return false
	end
	local owner = ent.GetObjectOwner and ent:GetObjectOwner()
	if owner ~= pl then
		return false
	end
	ent:Remove()
	pl:AddPoints(pts, nil, nil, true)
	if translate and translate.ClientFormat then
		pl:CenterNotify(COLOR_GREEN, translate.ClientFormat(pl, "supply_sold", pts))
	end
	return true
end

function GM:GetDevicePackTimeMul(pl, ent)
	local old = 1
	if IsValid(pl) and isnumber(pl.DeployablePackTimeMul) and not (IsValid(ent) and ent.IgnorePackTimeMul) then
		old = pl.DeployablePackTimeMul
	end
	if not IsValid(ent) then
		return old
	end
	local class = ent:GetClass()
	local speed = 1
	if self:IsMechanicsDeviceClass(class) then
		speed = self:GetDeviceHandleSpeedMul(pl)
	elseif self:IsSupplyDeployClass(class) then
		speed = self:GetSupplyHandleSpeedMul(pl)
	else
		return old
	end
	return old / math.max(speed, 0.01)
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
function GM:HasArsenalRivalOverlap(crate)
	if not IsValid(crate) then
		return false
	end
	local owner = self:GetArsenalCrateOwner(crate)
	if not IsValid(owner) then
		return false
	end
	local origin = crate:WorldSpaceCenter()
	local crates = ArsenalCrateList()
	for i = 1, #crates do
		local other = crates[i]
		if other ~= crate and IsValid(other) then
			local rival = self:GetArsenalCrateOwner(other)
			if IsValid(rival) and rival ~= owner
				and origin:DistToSqr(other:WorldSpaceCenter()) <= ARSENAL_RIVAL_OVERLAP_SQR then
				return true
			end
		end
	end
	return false
end

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

-- Monopoly: +pp on your crate while no rival shop circle overlaps. Same 100u as Competition.
function GM:GetArsenalMonopolyBonus(crate)
	if not IsValid(crate) then
		return 0
	end
	local owner = self:GetArsenalCrateOwner(crate)
	if not IsValid(owner) then
		return 0
	end
	local add = self:GetUpgradePercent(owner, "ArsenalMonopoly")
	if add <= 0 or self:HasArsenalRivalOverlap(crate) then
		return 0
	end
	return add
end

-- Cut is 4% plus stacked pp (grid, later Merchant p(n)). Not 4% × 1.03.
-- Rival cut is spatial: pass the crate. No crate → ceiling without competition.
function GM:GetArsenalMarginRate(owner, crate)
	local rate = self.ArsenalCrateCommission or 0.04
	rate = rate + self:GetUpgradePercent(owner, "ArsenalMargin")
	if IsValid(crate) then
		rate = rate - self:GetArsenalRivalCut(crate)
		rate = rate + self:GetArsenalMonopolyBonus(crate)
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

function GM:IsArsenalCrateShopItem(item)
	if not item then
		return false
	end
	local sig = item.Signature
	if sig == "arsenalcrate" or sig == "arscrate" then
		return true
	end
	return item.SWEP == "weapon_zs_arsenalcrate"
end

function GM:GetArsenalCrateCostMul(pl)
	return self:GetUpgradePercentMul(pl, "ArsenalCrateCost")
end

function GM:GetWorthShopCost(pl, item)
	local price = tonumber(item and item.Price) or 0
	if self:IsArsenalCrateShopItem(item) then
		price = math.max(0, math.floor(price * self:GetArsenalCrateCostMul(pl)))
	end
	return price
end

-- Ranged guns, and a future component row that sets RangedComponent.
-- Crate margin and ArsenalDiscount stay on melee, ammo, tools, and deploys.
function GM:IsRangedGearShopItem(item)
	if not item then
		return false
	end
	if item.Category == ITEMCAT_GUNS then
		return true
	end
	return item.RangedComponent == true
end

function GM:GetRangedGearShopMul(pl)
	local off = 0
	if self.GetUpgradePercent then
		off = self:GetUpgradePercent(pl, "RangedShop")
	end
	return math.max(0, 1 - off)
end

function GM:GetArsenalShopCost(pl, price, item)
	price = tonumber(price) or 0
	local mul = 1
	if self:IsRangedGearShopItem(item) then
		mul = self:GetRangedGearShopMul(pl)
	elseif self.GetArsenalPurchaseMul then
		local ok, v = pcall(self.GetArsenalPurchaseMul, self, pl)
		if ok then
			mul = tonumber(v) or 1
		end
	end
	local cost = math.max(0, math.floor(price * mul))
	if self:IsArsenalCrateShopItem(item) then
		cost = math.max(0, math.floor(cost * self:GetArsenalCrateCostMul(pl)))
	end
	return cost
end
