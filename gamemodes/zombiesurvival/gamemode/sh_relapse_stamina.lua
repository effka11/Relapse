-- Relapse stamina. 0..1. Spend: ground run, ladder sprint, noclip sprint.
-- Swift run stays IN_SPEED / ground / not crouch / not ghost. ZE skips.

local IN_SPEED = IN_SPEED
local MOVETYPE_WALK = MOVETYPE_WALK
local MOVETYPE_NOCLIP = MOVETYPE_NOCLIP
local TEAM_HUMAN = TEAM_HUMAN

local M_Entity = FindMetaTable("Entity")
local M_Player = FindMetaTable("Player")
local E_GetDTFloat = M_Entity.GetDTFloat
local E_GetDTBool = M_Entity.GetDTBool
local E_GetMoveType = M_Entity.GetMoveType
local P_Team = M_Player.Team
local P_Alive = M_Player.Alive
local P_Crouching = M_Player.Crouching
local P_GetBarricadeGhosting = M_Player.GetBarricadeGhosting

function M_Player:GetStaminaExhausted()
	return E_GetDTBool(self, DT_PLAYER_BOOL_STAMINAEXHAUST) and true or false
end

function M_Player:SetStaminaExhausted(on)
	if not SERVER then return end
	self:SetDTBool(DT_PLAYER_BOOL_STAMINAEXHAUST, on and true or false)
end

function M_Player:GetStamina()
	local v = math.Clamp(E_GetDTFloat(self, DT_PLAYER_FLOAT_STAMINA) or 0, 0, 1)
	-- DT defaults to 0. Unset (not exhausted) reads as full so sprint is not gated on connect.
	if v <= 0 and not self:GetStaminaExhausted() then
		return 1
	end
	return v
end

function M_Player:SetStamina(frac)
	if not SERVER then return end
	self:SetDTFloat(DT_PLAYER_FLOAT_STAMINA, math.Clamp(frac or 0, 0, 1))
end

function GM:ResetRelapseStamina(pl)
	if not IsValid(pl) then return end
	pl:SetStamina(1)
	pl:SetStaminaExhausted(false)
	pl.RelapseStaminaRestAt = nil
	pl.RelapseStaminaDrainT = nil
	pl.RelapseStaminaCoast = nil
end

function GM:HumanCanSprint(pl)
	if self.ZombieEscape then return true end
	if not IsValid(pl) or not P_Alive(pl) then return false end
	if P_Team(pl) ~= TEAM_HUMAN then return false end
	if pl:GetStaminaExhausted() then
		return pl:GetStamina() >= (self.HumanStaminaSprintResume or 0.15)
	end
	return pl:GetStamina() > 0
end

-- Same ground-run test as scars.md Swift. Standing / air / wall / ghost / crouch do not spend.
function GM:IsHumanRunning(pl, move)
	if not IsValid(pl) or not P_Alive(pl) then return false end
	if P_Team(pl) ~= TEAM_HUMAN then return false end
	if self.ZombieEscape then return false end
	if P_GetBarricadeGhosting(pl) then return false end
	if P_Crouching(pl) then return false end
	if E_GetMoveType(pl) ~= MOVETYPE_WALK then return false end
	if not pl:OnGround() then return false end

	local sprinting
	if move then
		sprinting = move:KeyDown(IN_SPEED)
	else
		sprinting = pl:KeyDown(IN_SPEED)
	end
	if not sprinting then return false end

	local vel = move and move:GetVelocity() or pl:GetVelocity()
	local minSqr = self.HumanStaminaRunSpeedSqr or (64 * 64)
	return vel.x * vel.x + vel.y * vel.y > minSqr
end

function GM:IsHumanOnLadder(pl)
	if not IsValid(pl) then return false end
	if pl.RelapseNoclip then return false end
	return pl.RelapseLadderHold or (pl.GetNW2Bool and pl:GetNW2Bool("RelapseLadderHold", false)) or false
end

function GM:IsHumanClimbing(pl)
	if not self:IsHumanOnLadder(pl) then return false end
	return (pl.RelapseLadderWish or 0) ~= 0
end

-- Shift climb, actually moving on the strip. Gated by HumanCanSprint via StartCommand.
function GM:IsHumanClimbSprinting(pl, move)
	if not self:IsHumanClimbing(pl) then return false end
	if not self:HumanCanSprint(pl) then return false end
	local sprint = pl.RelapseLadderSprint
	if sprint == nil then
		if move then
			sprint = move:KeyDown(IN_SPEED)
		else
			sprint = pl:KeyDown(IN_SPEED)
		end
	end
	return sprint and true or false
end

function GM:IsHumanNoclipMove(pl)
	if not IsValid(pl) then return false end
	if pl.RelapseNoclip then return true end
	if self:IsHumanOnLadder(pl) then return false end
	return E_GetMoveType(pl) == MOVETYPE_NOCLIP
end

function GM:IsHumanNoclipSprinting(pl, move)
	if not self:IsHumanNoclipMove(pl) then return false end
	if not self:HumanCanSprint(pl) then return false end
	local sprinting
	if move then
		sprinting = move:KeyDown(IN_SPEED)
	else
		sprinting = pl:KeyDown(IN_SPEED)
	end
	if not sprinting then return false end
	local vel = move and move:GetVelocity() or pl:GetVelocity()
	local minSqr = self.HumanStaminaRunSpeedSqr or (64 * 64)
	return vel:LengthSqr() > minSqr
end

function GM:IsHumanStanding(pl, move)
	if not IsValid(pl) or not P_Alive(pl) then return false end
	if not pl:OnGround() then return false end
	if E_GetMoveType(pl) ~= MOVETYPE_WALK then return false end

	local vel = move and move:GetVelocity() or pl:GetVelocity()
	local minSqr = self.HumanStaminaStandSpeedSqr or (28 * 28)
	return vel.x * vel.x + vel.y * vel.y <= minSqr
end

-- Inverse of sprint load: speed is body/(body+kg), drain is (body+kg)/body.
function GM:GetHumanStaminaDrainMul(pl)
	if not IsValid(pl) or not pl.GetCarrySpeedMul then
		return 1
	end
	return 1 / math.max(pl:GetCarrySpeedMul(1), 0.4)
end

function GM:GetHumanStaminaRegenTime(pl, move)
	if self:IsHumanOnLadder(pl) then
		if self:IsHumanClimbing(pl) then
			return self.HumanStaminaRegenTimeClimb or 110
		end
		return self.HumanStaminaRegenTimeHang or 50
	end
	if self:IsHumanNoclipMove(pl) then
		local vel = move and move:GetVelocity() or (IsValid(pl) and pl:GetVelocity())
		local minSqr = self.HumanStaminaStandSpeedSqr or (28 * 28)
		if vel and vel:LengthSqr() > minSqr then
			return self.HumanStaminaRegenTimeNoclip or 42
		end
		return self.HumanStaminaRegenTimeStand or 30
	end
	if IsValid(pl) and P_GetBarricadeGhosting(pl) then
		return self.HumanStaminaRegenTimeGhost or 85
	end
	if self:IsHumanStanding(pl, move) then
		return self.HumanStaminaRegenTimeStand or 30
	end
	return self.HumanStaminaRegenTimeWalk or 38
end

local function RelapseLogistic(z)
	if z >= 20 then return 1 end
	if z <= -20 then return 0 end
	return 1 / (1 + math.exp(-z))
end

-- Remapped logistic, ends pinned to 0 and 1. Breath and palsy share this S.
function GM:RelapseLogistic01(u, inflect, steep)
	u = math.Clamp(u or 0, 0, 1)
	inflect = inflect or 0.5
	steep = steep or 6
	local a = RelapseLogistic(steep * (0 - inflect))
	local b = RelapseLogistic(steep * (1 - inflect))
	local denom = b - a
	if denom <= 1e-6 then return u end
	return math.Clamp((RelapseLogistic(steep * (u - inflect)) - a) / denom, 0, 1)
end

-- Hermite S. Zero slope at 0 and 1 so join of spend→regen stays smooth.
local function RelapseSmoother01(u)
	u = math.Clamp(u or 0, 0, 1)
	return u * u * u * (u * (u * 6 - 15) + 10)
end

-- 1..0. Elapsed since sprint stopped. Faster stop, rounded ends.
function GM:GetHumanStaminaDrainCoastMul(elapsed)
	local coast = self.HumanStaminaDrainCoast or 0.35
	elapsed = elapsed or 0
	if coast <= 0 then
		return 0
	end
	if elapsed <= 0 then
		return 1
	end
	return 1 - RelapseSmoother01(elapsed / coast)
end

-- 0..1. Starts only after spend has reached 0.
function GM:GetHumanStaminaRegenRateMul(elapsed)
	local coast = self.HumanStaminaDrainCoast or 0.35
	local delay = math.max(self.HumanStaminaRegenDelay or 0.35, coast)
	local ease = self.HumanStaminaRegenEase or 1.25
	elapsed = elapsed or 0
	if elapsed < delay then
		return 0
	end
	if ease <= 0 then
		return 1
	end
	return RelapseSmoother01((elapsed - delay) / ease)
end

-- Tank fraction for one Relapse melee swing. Guns' bash is 0. Not from Damage.
function GM:GetHumanStaminaMeleeCost(wep, heavy)
	if self.ZombieEscape then return 0 end
	if not IsValid(wep) then return 0 end
	local R = wep.Relapse
	if not (istable(R) and R.Melee) then return 0 end
	local cost = tonumber(R.Stamina) or 0
	if cost <= 0 then return 0 end
	if heavy then
		cost = tonumber(R.StaminaHeavy) or (cost * (self.HumanStaminaMeleeHeavyMul or 1.7))
	end
	return math.max(0, cost)
end

function GM:CanHumanStaminaMelee(pl, wep, heavy)
	local cost = self:GetHumanStaminaMeleeCost(wep, heavy)
	if cost <= 0 then return true end
	if not IsValid(pl) or not pl.GetStamina then return true end
	if P_Team(pl) ~= TEAM_HUMAN then return true end
	return pl:GetStamina() > 0
end

-- Server spends. Client only checks DT so predicted VM can start.
function GM:ConsumeHumanStaminaMelee(pl, wep, heavy)
	if not self:CanHumanStaminaMelee(pl, wep, heavy) then
		return false
	end
	local cost = self:GetHumanStaminaMeleeCost(wep, heavy)
	if cost <= 0 or not SERVER then
		return true
	end
	local stam = pl:GetStamina()
	pl:SetStamina(math.max(0, stam - cost))
	pl.RelapseStaminaRestAt = CurTime()
	pl.RelapseStaminaCoast = false
	return true
end

-- Quadratic fade below the start fraction. Status mul, not an upgrade percent.
function GM:GetHumanStaminaSpeedMul(pl, sprint)
	if self.ZombieEscape then return 1 end
	if not IsValid(pl) or not pl.GetStamina then return 1 end

	local start, maxSlow
	if sprint then
		start = self.HumanStaminaRunSlowStart or 0.40
		maxSlow = self.HumanStaminaRunSlowMax or 0.26
	else
		start = self.HumanStaminaWalkSlowStart or 0.18
		maxSlow = self.HumanStaminaWalkSlowMax or 0.12
	end
	if start <= 0 or maxSlow <= 0 then return 1 end

	local stam = pl:GetStamina()
	if stam >= start then return 1 end
	local t = 1 - stam / start
	return 1 - maxSlow * (t * t)
end

-- 0..1 fatigue from stamina. Remapped logistic, ends pinned to 0 and 1.
function GM:GetHumanStaminaBreathFatigue(stam)
	local start = self.HumanStaminaBreathStart or 0.90
	if start <= 0 then return 0 end
	stam = math.Clamp(stam or 1, 0, 1)
	if stam >= start then return 0 end

	local u = 1 - stam / start
	return self:RelapseLogistic01(u, self.HumanStaminaBreathInflect or 0.50, self.HumanStaminaBreathSteep or 7.5)
end

-- Amp, rate from the S-curve. Rest stays 1, 1 (old idle wave).
function GM:GetHumanStaminaBreathMul(pl)
	if self.ZombieEscape then return 1, 1 end
	if not IsValid(pl) or not pl.GetStamina then return 1, 1 end

	local t = self:GetHumanStaminaBreathFatigue(pl:GetStamina())
	local ampMax = self.HumanStaminaBreathAmpMax or 1.60
	local rateMax = self.HumanStaminaBreathRateMax or 2.55
	return 1 + ampMax * t, 1 + rateMax * t
end

function GM:RelapseStaminaFinishMove(pl, move)
	if not SERVER then return end
	if self.ZombieEscape then return end
	if not IsValid(pl) or not P_Alive(pl) then return end
	if P_Team(pl) ~= TEAM_HUMAN then return end
	if pl.IsRelapseAIBot then return end

	local dt = FrameTime()
	if dt <= 0 then return end

	local drainT = self.HumanStaminaDrainTime or 24
	local resume = self.HumanStaminaSprintResume or 0.15

	local stamina = pl:GetStamina()
	local exhausted = pl:GetStaminaExhausted()
	local nextStamina = stamina
	local nextExhausted = exhausted

	if self:IsHumanClimbSprinting(pl, move) then
		local drainT = self.HumanStaminaClimbDrainTime or 20
		local drainMul = self:GetHumanStaminaDrainMul(pl)
		nextStamina = math.max(0, stamina - dt * drainMul / math.max(drainT, 0.01))
		pl.RelapseStaminaRestAt = nil
		pl.RelapseStaminaDrainT = drainT
		pl.RelapseStaminaCoast = true
		if nextStamina <= 0 then
			nextStamina = 0
			nextExhausted = true
		end
	elseif self:IsHumanRunning(pl, move) then
		local drainMul = self:GetHumanStaminaDrainMul(pl)
		nextStamina = math.max(0, stamina - dt * drainMul / math.max(drainT, 0.01))
		pl.RelapseStaminaRestAt = nil
		pl.RelapseStaminaDrainT = drainT
		pl.RelapseStaminaCoast = true
		if nextStamina <= 0 then
			nextStamina = 0
			nextExhausted = true
		end
	elseif self:IsHumanNoclipSprinting(pl, move) then
		local nDrainT = self.HumanStaminaNoclipDrainTime or 24
		local drainMul = self:GetHumanStaminaDrainMul(pl)
		nextStamina = math.max(0, stamina - dt * drainMul / math.max(nDrainT, 0.01))
		pl.RelapseStaminaRestAt = nil
		pl.RelapseStaminaDrainT = nDrainT
		pl.RelapseStaminaCoast = true
		if nextStamina <= 0 then
			nextStamina = 0
			nextExhausted = true
		end
	elseif stamina < 1 then
		if not pl.RelapseStaminaRestAt then
			pl.RelapseStaminaRestAt = CurTime()
		end
		local elapsed = CurTime() - pl.RelapseStaminaRestAt
		local spendMul = 0
		if pl.RelapseStaminaCoast ~= false then
			spendMul = self:GetHumanStaminaDrainCoastMul(elapsed)
		end
		local regenMul = self:GetHumanStaminaRegenRateMul(elapsed)
		local drainMul = self:GetHumanStaminaDrainMul(pl)
		local regenT = self:GetHumanStaminaRegenTime(pl, move)
		local coastT = pl.RelapseStaminaDrainT or drainT
		local flow = regenMul / math.max(regenT, 0.01) - spendMul * drainMul / math.max(coastT, 0.01)
		nextStamina = math.Clamp(stamina + dt * flow, 0, 1)
		if nextStamina <= 0 then
			nextStamina = 0
			nextExhausted = true
		elseif nextStamina >= resume then
			nextExhausted = false
		end
		if nextStamina >= 1 then
			pl.RelapseStaminaRestAt = nil
			pl.RelapseStaminaDrainT = nil
			pl.RelapseStaminaCoast = nil
		end
	else
		nextStamina = 1
		nextExhausted = false
		pl.RelapseStaminaRestAt = nil
	end

	if nextExhausted ~= exhausted then
		pl:SetStaminaExhausted(nextExhausted)
	end
	if nextStamina ~= stamina then
		pl:SetStamina(nextStamina)
	end
end
