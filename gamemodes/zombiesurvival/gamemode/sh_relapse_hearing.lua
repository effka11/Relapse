-- Relapse hearing: humans make noise, zombie players read it.
-- HearingPeaks is one row per file. The local bar plays the file that started:
-- a step uses that footstep wav, a shot uses that shot wav. Peaks stay on their
-- own time and release. A separate rise runs between peaks and is what the bar
-- follows. Overlapping sounds show the max. Zombies do not get that
-- release. Each track sends one peak, its loudest point, scaled by the shared
-- distance curve stretched over that track's radius. The glow then fades for a
-- few seconds. A shot's networked peak is still that one instant.
-- AI bots do not use this yet; their eyes stay in relapse_ai/server/40_perception.lua.

local math_max = math.max
local math_min = math.min
local math_Clamp = math.Clamp
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local CurTime = CurTime
local IsValid = IsValid
local TEAM_HUMAN = TEAM_HUMAN

local M_Entity = FindMetaTable("Entity")
local M_Player = FindMetaTable("Player")
local E_GetDTFloat = M_Entity.GetDTFloat
local P_Team = M_Player.Team
local P_Alive = M_Player.Alive

local METRE = 39.37 -- Source units in one metre

---------------------------------------------------------------------------
-- Config
--
-- Peaks are on the 0..100 scale. Radius: R(N) = Min + (Max - Min) * (N/100)^Pow.
--   walk 15  -> ~13 m      run 40 -> ~35 m      pistol 74 -> ~79 m
--   SCAR 94  -> ~110 m     suppressed 9x19 (78 - 35 = 43) -> ~38 m
---------------------------------------------------------------------------

GM.Hearing = {
	-- Release on the stamina bar, same shape as the zombie glow: half the peak
	-- is left after HalfLife seconds. Louder events use a shorter half-life,
	-- sqrt(level/100) of the way from Quiet to Loud, so the bar follows the
	-- sound and does not sit after it.
	--   walk 15: half at 0.36 s, a tenth left at 1.18 s
	--   run 40: half at 0.28 s
	--   pistol 74: half at 0.20 s
	--   SCAR 94: half at 0.17 s
	--   full 100: half at 0.16 s, a tenth left at 0.53 s
	HalfLifeQuiet = 0.48,
	HalfLifeLoud = 0.16,
	Attack = 0.07, -- rise into the next peak, on its own line. The peak time is not moved.
	Mask = 0.85, -- an event quieter than Mask * current level is swallowed by the tail
	RadiusMin = 6 * METRE,
	RadiusMax = 120 * METRE,
	RadiusPow = 1.5,
	WallMul = 0.6, -- one world hit between ear and source

	Footstep = {Still = 5, Walk = 15, Run = 40, CrouchMul = 0.6},
	Land = {Min = 12, Max = 30, SpeedMin = 64, SpeedMax = 500},
	Hurt = 25,
	HurtMinDamage = 5,
	Repair = 28, -- hammer / wrench hit on a barricade
	Nail = 30,
	Melee = 20, -- a swing, hit or not

	ShotDefault = 84,
	ShotMin = 30,
	Suppressed = -35,
	ShotByAmmo = { -- [ammo id] = peak
		["9x18"] = 74,
		["9x19"] = 78,
		["45acp"] = 80,
		["357mag"] = 90,
		["3030win"] = 90,
		["9x39"] = 82,
		["556x45"] = 88,
		["762x39"] = 90,
		["762x51"] = 94,
		["762x54r"] = 96,
		["12ga"] = 96,
		["50bmg"] = 100,
		-- legacy ZS ids
		pistol = 78,
		smg1 = 80,
		ar2 = 88,
		["357"] = 90,
		buckshot = 96,
		pulse = 84,
		gaussenergy = 45,
		battery = 30,
	},

	-- Zombie glow memory. Half of a received peak is still there after this many seconds.
	GlowHalfLife = 1.8,

	-- Floors: continuous, no event. Breath scales with stamina fatigue (0..1).
	Breath = 22,
	LastHuman = {Floor = 35, PerMinute = 10, Max = 70},
	Escape = 30,
}

---------------------------------------------------------------------------
-- Tracks
--
-- Peaks are instants of the wav, time in seconds and height 0..1 of that
-- file's own peak. The bar rises into the peak, then releases with GetNoiseHalfLife.
-- Radius is per track. The distance model that will set it is not in yet.
---------------------------------------------------------------------------

GM.HearingTracks = {
	step = {
		Radius = 12 * METRE,
		-- Filled from HearingPeaks["player/footsteps/concrete1.wav"] when that file loads.
		Peaks = {
			{0.000, 1.000},
			{0.312, 0.170},
		},
	},
}

-- u = distance / radius. Peak scale is (1 - u)^2: whole at the body, 0 at the rim.
-- The radius only stretches this shape. Past the rim the peak is not sent.
GM.HearingFalloff = {
	Knots = {
		{0.00, 1.00},
		{0.50, 0.25},
		{1.00, 0.00},
	},
	Controls = {
		{0.25, 0.50},
		{0.75, 0.00},
	},
}

-- Quadratic Bezier. u is solved from the handle's time, so the handle is the tangent.
function GM:EvalHearingCurve(curve, t)
	local knots = curve.Knots
	local n = #knots
	local y
	if t <= knots[1][1] then
		y = knots[1][2]
	elseif t >= knots[n][1] then
		y = knots[n][2]
	else
		local controls = curve.Controls
		for i = 1, n - 1 do
			local a = knots[i]
			local b = knots[i + 1]
			if t <= b[1] then
				local x0, y0 = a[1], a[2]
				local x1, y1 = b[1], b[2]
				local cx, cy = controls[i][1], controls[i][2]
				local A = x0 - 2 * cx + x1
				local B = 2 * (cx - x0)
				local C = x0 - t
				local u
				if math.abs(A) < 1e-8 then
					u = 0
					if B ~= 0 then u = -C / B end
				else
					local disc = B * B - 4 * A * C
					if disc < 0 then disc = 0 end
					local r = math.sqrt(disc)
					local u1 = (-B + r) / (2 * A)
					local u2 = (-B - r) / (2 * A)
					if u1 >= -1e-4 and u1 <= 1 + 1e-4 then
						u = u1
					else
						u = u2
					end
				end
				if u < 0 then u = 0 elseif u > 1 then u = 1 end
				local ou = 1 - u
				y = ou * ou * y0 + 2 * ou * u * cy + u * u * y1
				break
			end
		end
	end
	if not y or y < 0 then return 0 end
	if y > 1 then return 1 end
	return y
end

-- S-curve between peaks. Flat at both ends, so it meets the peak on that peak's time.
local function HearingAttackY(s)
	if s <= 0 then return 0 end
	if s >= 1 then return 1 end
	return s * s * (3 - 2 * s)
end

-- Height of the peaks themselves, 0..1 of the file. A peak is reached at its
-- own time, then releases. amp is the event on the 0..100 scale: a louder peak
-- releases faster. Nothing here moves or rounds the peak.
function GM:EvalHearingPeaks(peaks, t, amp)
	if not peaks then return 0 end
	local best = 0
	for i = 1, #peaks do
		local p = peaks[i]
		local age = t - p[1]
		if age >= 0 then
			local height = p[2]
			local level = (amp or 0) * height
			local y = height
			if level > 0 then
				y = y * 0.5 ^ (age / self:GetNoiseHalfLife(level))
			end
			if y > best then best = y end
		end
	end
	if best > 1 then return 1 end
	if best < 0 then return 0 end
	return best
end

-- The bar follows this, not the peaks. Between any two peaks the line rises
-- into the next one and meets it at its own time.
function GM:EvalHearingRise(peaks, t, amp)
	local raw = self:EvalHearingPeaks(peaks, t, amp)
	if not peaks then return raw end
	local attack = self.Hearing.Attack or 0.07
	if attack < 0.001 then attack = 0.001 end
	local best = raw
	for i = 1, #peaks do
		local P = peaks[i][1]
		local prev = 0
		for j = 1, #peaks do
			local tj = peaks[j][1]
			if tj < P and tj > prev then prev = tj end
		end
		local origin = P - attack
		local clip = prev
		if clip < 0 then clip = 0 end
		if t >= origin and t >= clip and t <= P then
			local y0 = self:EvalHearingPeaks(peaks, origin, amp)
			local y1 = self:EvalHearingPeaks(peaks, P, amp)
			if y1 > y0 then
				local y = y0 + (y1 - y0) * HearingAttackY((t - origin) / attack)
				if y > best then best = y end
			end
		end
	end
	if best > 1 then return 1 end
	return best
end

---------------------------------------------------------------------------
-- Model
---------------------------------------------------------------------------

function GM:GetNoiseRadius(noise)
	local H = self.Hearing
	local t = math_Clamp((noise or 0) / 100, 0, 1)
	return H.RadiusMin + (H.RadiusMax - H.RadiusMin) * t ^ H.RadiusPow
end

-- Louder peak, shorter release. See HalfLifeQuiet / HalfLifeLoud.
function GM:GetNoiseHalfLife(peak)
	local H = self.Hearing
	local t = math_Clamp((peak or 0) / 100, 0, 1) ^ 0.5
	local quiet = H.HalfLifeQuiet or 0.55
	local loud = H.HalfLifeLoud or quiet
	return quiet + (loud - quiet) * t
end

-- Event level right now: the networked peak after its decay.
function GM:GetHumanNoisePeak(pl)
	local n0 = E_GetDTFloat(pl, DT_PLAYER_FLOAT_NOISE) or 0
	if n0 <= 0 then return 0 end

	local dt = CurTime() - (E_GetDTFloat(pl, DT_PLAYER_FLOAT_NOISETIME) or 0)
	if dt <= 0 then return n0 end

	return n0 * 0.5 ^ (dt / self:GetNoiseHalfLife(n0))
end

function GM:GetHumanNoiseFloor(pl)
	local H = self.Hearing
	local floor = 0

	if pl.GetStamina and self.GetHumanStaminaBreathFatigue and not self.ZombieEscape then
		floor = H.Breath * self:GetHumanStaminaBreathFatigue(pl:GetStamina())
	end

	if self.TheLastHuman == pl then
		local since = CurTime() - (self.HearingLastHumanAt or CurTime())
		floor = math_max(floor, math_min(H.LastHuman.Max, H.LastHuman.Floor + H.LastHuman.PerMinute * since / 60))
	end

	if self.GetEscapeSequence and self:GetEscapeSequence() then
		floor = math_max(floor, H.Escape)
	end

	return floor
end

function GM:GetHumanNoise(pl)
	if not (IsValid(pl) and pl:IsPlayer() and P_Team(pl) == TEAM_HUMAN and P_Alive(pl)) then return 0 end

	-- Loudest peak still releasing. A new step does not add to the one before it.
	local n = self:GetHumanNoisePeak(pl)
	if CLIENT and pl == LocalPlayer() and self.GetLocalHearingLevel then
		n = math_max(n, self:GetLocalHearingLevel())
	end
	return math_Clamp(n, 0, 100)
end

function M_Player:GetNoise()
	return GAMEMODE:GetHumanNoise(self)
end

function M_Player:GetNoiseRadius()
	return GAMEMODE:GetNoiseRadius(GAMEMODE:GetHumanNoise(self))
end

-- Speed against the player's own walk / run: a slow creep is quieter than a walk.
function GM:GetFootstepNoise(pl, speed, crouching)
	local F = self.Hearing.Footstep
	local walk = math_max(1, pl:GetWalkSpeed())
	local run = math_max(walk + 1, pl:GetRunSpeed())

	local n
	if speed <= walk then
		n = Lerp(math_Clamp(speed / walk, 0, 1), F.Still, F.Walk)
	else
		n = Lerp(math_Clamp((speed - walk) / (run - walk), 0, 1), F.Walk, F.Run)
	end

	if crouching then
		n = n * F.CrouchMul
	end

	return n
end

-- MW customization swaps Primary.Sound for the suppressed cue; legacy ZS silencers
-- shorten GetAuraRange. Either reads as a can on the barrel.
local function WeaponSuppressed(wep)
	if wep.GetNoiseSuppressed then
		return wep:GetNoiseSuppressed() and true or false
	end

	local s = wep.Primary and wep.Primary.Sound
	if isstring(s) and s ~= "" then
		s = string_lower(s)
		if string_find(s, "sup", 1, true) or string_find(s, "silenc", 1, true)
		or string_sub(s, -2) == ".s" or string_sub(s, -2) == "_s" then
			return true
		end
	end

	if wep.GetAuraRange and wep:GetAuraRange() < 2048 then
		return true
	end

	return false
end

-- Peak of one shot. Relapse.Noise on the weapon wins, then the calibre, then class default.
function GM:GetWeaponNoise(wep)
	local H = self.Hearing
	if not (IsValid(wep) and wep:IsWeapon()) then return H.ShotDefault end

	local R = wep.Relapse
	if wep.IsMelee or wep.Melee or (istable(R) and R.Melee) then
		return H.Melee
	end

	local n
	if istable(R) and isnumber(R.Noise) then
		n = R.Noise
	elseif isnumber(wep.NoiseLevel) then
		n = wep.NoiseLevel
	else
		local ammo = wep.Primary and wep.Primary.Ammo
		n = ammo and H.ShotByAmmo[string_lower(tostring(ammo))] or H.ShotDefault
	end

	if WeaponSuppressed(wep) then
		n = n + H.Suppressed
	end

	return math_Clamp(n, H.ShotMin, 100)
end

-- Server repeats LastHuman every infliction tick; the heart starts on the first call only.
hook.Add("LastHuman", "RelapseHearing", function(pl)
	if not LASTHUMAN then
		GAMEMODE.HearingLastHumanAt = CurTime()
	end
end)
