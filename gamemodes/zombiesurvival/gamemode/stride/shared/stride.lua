-- Shared stride clock. Sounds, view bob, leg anims, and weapon mods should
-- read this instead of inventing their own step rate.
--
--   local st = GAMEMODE.Stride:Get(pl)
--   st.cycle      0-1 gait (two steps)
--   st.foot       0 left, 1 right
--   st.interval   seconds per step
--   st.intensity  0-1
--   st.speed      2D u/s
--   st.sprinting
--   st.grounded
--
-- SWEP flags (client bob):
--   StrideSkipViewModel   skip our viewmodel overlay
--   StrideKeepEngineBob   keep HL2 BobScale
--   StrideBobScale        extra amplitude mul

local TEAM_HUMAN = TEAM_HUMAN
local IN_SPEED = IN_SPEED
local STEPSOUNDTIME_WATER_FOOT = STEPSOUNDTIME_WATER_FOOT
local STEPSOUNDTIME_ON_LADDER = STEPSOUNDTIME_ON_LADDER
local STEPSOUNDTIME_WATER_KNEE = STEPSOUNDTIME_WATER_KNEE

local math_Clamp = math.Clamp
local math_Approach = math.Approach
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi
local Lerp = Lerp
local TickInterval = engine.TickInterval
local CurTime = CurTime
local hook_Add = hook.Add
local hook_Run = hook.Run

local M_Player = FindMetaTable("Player")
local M_Entity = FindMetaTable("Entity")
local M_CMoveData = FindMetaTable("CMoveData")
local P_Team = M_Player.Team
local P_Alive = M_Player.Alive
local P_Crouching = M_Player.Crouching
local P_KeyDown = M_Player.KeyDown
local P_GetWalkSpeed = M_Player.GetWalkSpeed
local P_GetRunSpeed = M_Player.GetRunSpeed
-- OnGround / GetVelocity live on Entity. Player.__index falls through, but
-- M_Player.OnGround is nil if cached from the Player metatable.
local P_OnGround = M_Entity.OnGround or M_Entity.IsOnGround
local P_GetVelocity = M_Entity.GetVelocity
local E_GetTable = M_Entity.GetTable
local M_GetVelocity = M_CMoveData.GetVelocity
local M_Vector = FindMetaTable("Vector")
local V_Length2D = M_Vector.Length2D

local Stride = {}
GM.Stride = Stride

Stride.Enabled = true
-- One step, Source units (1 unit = 1 inch). Walk ~0.75-1 m, run ~1.9 m.
Stride.WalkLength = 40
Stride.RunLength = 76
Stride.CrouchLengthMul = 0.65
Stride.MinSpeed = 20
Stride.IntensityRate = 8
Stride.MinPlaybackRate = 0.25
Stride.MaxPlaybackRate = 2
Stride.MinStepMs = 240
Stride.MaxStepMs = 720
Stride.BobFreq = 0.5

local function GetState(pl)
	local pt = E_GetTable(pl)
	local st = pt.StrideState
	if not st then
		st = {
			cycle = 0,
			foot = 0,
			interval = 0.45,
			intensity = 0,
			speed = 0,
			sprinting = false,
			grounded = true,
			lastStepTime = -1
		}
		pt.StrideState = st
	end

	return st
end

function Stride:UsesStride(pl)
	return self.Enabled and pl:IsValid() and P_Alive(pl) and P_Team(pl) == TEAM_HUMAN
end

function Stride:Get(pl)
	if not pl:IsValid() then return nil end

	return GetState(pl)
end

function Stride:GetCycle(pl)
	return GetState(pl).cycle
end

function Stride:GetStrideLength(pl, speed, sprinting, crouching)
	local walk = math_max(1, P_GetWalkSpeed(pl))
	local run = math_max(walk + 1, P_GetRunSpeed(pl))
	local t = math_Clamp((speed - walk) / (run - walk), 0, 1)
	if not sprinting then
		t = math_min(t, 0.12)
	end

	local len = Lerp(t, self.WalkLength, self.RunLength)
	if crouching then
		len = len * self.CrouchLengthMul
	end

	return len
end

function Stride:ComputeInterval(pl, speed, sprinting, crouching)
	speed = math_max(speed, self.MinSpeed)

	return self:GetStrideLength(pl, speed, sprinting, crouching) / speed
end

function Stride:GetStepSoundTime(pl, iType, bWalking)
	if iType == STEPSOUNDTIME_ON_LADDER then
		return 500
	end

	if iType == STEPSOUNDTIME_WATER_KNEE then
		return 650
	end

	local speed = V_Length2D(P_GetVelocity(pl))
	local sprinting = P_KeyDown(pl, IN_SPEED) and not P_Crouching(pl)
	local interval = self:ComputeInterval(pl, speed, sprinting, P_Crouching(pl))

	if iType == STEPSOUNDTIME_WATER_FOOT then
		interval = interval * 1.2
	end

	if bWalking then
		interval = interval * 1.15
	end

	return math.floor(math_Clamp(interval * 1000, self.MinStepMs, self.MaxStepMs))
end

function Stride:GetPlaybackRate(pl, maxseqgroundspeed)
	local st = GetState(pl)
	if not st.grounded or st.intensity < 0.01 or st.speed < self.MinSpeed then
		return 1
	end

	local rate = st.speed / math_max(1, maxseqgroundspeed or 1)

	return math_Clamp(rate, self.MinPlaybackRate, self.MaxPlaybackRate)
end

function Stride:GetBob(pl)
	local st = GetState(pl)
	local a = st.intensity
	if a <= 0 then
		return 0, 0, 0, 0
	end

	-- BobFreq 0.5 = one sway / plant per two steps, not a shake on every footfall.
	local gait = st.cycle * math_pi * 2 * (self.BobFreq or 0.5)
	local vertical = -math_abs(math_cos(gait)) * a
	local lateral = math_sin(gait) * a

	return vertical, lateral, lateral, a
end

function Stride:OnFootstep(pl, iFoot)
	if not self:UsesStride(pl) then return end

	local st = GetState(pl)
	st.foot = iFoot or st.foot or 0

	hook_Run("RelapseStrideFootstep", pl, st.foot, st)
end

-- Engine + anim events both hit PlayerFootstep. Play the first, swallow extras.
function Stride:AllowFootstepSound(pl, iFoot)
	if not self:UsesStride(pl) then
		return true
	end

	local st = GetState(pl)
	local now = CurTime()
	local gap = math_max(0.2, (st.interval or 0.4) * 0.7)
	if st.lastStepTime >= 0 and now - st.lastStepTime < gap then
		return false
	end

	st.lastStepTime = now
	self:OnFootstep(pl, iFoot)

	return true
end

function Stride:FinishMove(pl, mv)
	if not self:UsesStride(pl) then
		local pt = E_GetTable(pl)
		if pt.StrideState then
			pt.StrideState.intensity = 0
		end

		return
	end

	local st = GetState(pl)
	local speed = V_Length2D(M_GetVelocity(mv))
	local grounded = pl:OnGround()
	local sprinting = P_KeyDown(pl, IN_SPEED) and not P_Crouching(pl)
	local dt = TickInterval()
	if dt <= 0 then
		dt = FrameTime()
	end

	st.speed = speed
	st.grounded = grounded
	st.sprinting = sprinting

	local want = (grounded and speed >= self.MinSpeed) and 1 or 0
	st.intensity = math_Approach(st.intensity, want, dt * self.IntensityRate)

	if want > 0 then
		if CLIENT and not IsFirstTimePredicted() then
			return
		end

		st.interval = self:ComputeInterval(pl, speed, sprinting, P_Crouching(pl))
		st.cycle = (st.cycle + dt / (st.interval * 2)) % 1
		st.foot = (st.cycle >= 0.5) and 1 or 0
	end
end

hook_Add("FinishMove", "RelapseStride", function(pl, mv)
	Stride:FinishMove(pl, mv)
end)

if not CLIENT then return end

local Angle = Angle
local IsValid = IsValid

function Stride:ZeroEngineBob(pl)
	if not self:UsesStride(pl) then return end

	local wep = pl:GetActiveWeapon()
	if IsValid(wep) and not wep.StrideKeepEngineBob then
		wep.BobScale = 0
	end
end

function Stride:ApplyCamera(pl, origin, angles)
	if not self:UsesStride(pl) then return origin, angles end

	local vertical, lateral, _, amp = self:GetBob(pl)
	if amp < 0.001 then return origin, angles end

	origin = origin + angles:Up() * (vertical * 0.16)
	angles = Angle(angles.p, angles.y, angles.r)
	angles.p = angles.p + vertical * 0.08
	angles.r = angles.r + lateral * 0.12

	return origin, angles
end

function Stride:ApplyViewModel(pl, wep, pos, ang)
	if not pos or not ang or wep.StrideSkipViewModel or not self:UsesStride(pl) then
		return pos, ang
	end

	local vertical, lateral, _, amp = self:GetBob(pl)
	if amp < 0.001 then return pos, ang end

	local mul = wep.StrideBobScale or 1
	if wep.GetIronsights and wep:GetIronsights() then
		mul = mul * 0.12
	end

	ang = Angle(ang.p, ang.y, ang.r)
	pos = pos + ang:Up() * (vertical * 0.32 * mul) + ang:Right() * (lateral * 0.18 * mul)
	ang:RotateAroundAxis(ang:Right(), vertical * 0.22 * mul)
	ang:RotateAroundAxis(ang:Forward(), lateral * 0.24 * mul)

	return pos, ang
end

function GM:CalcViewModelView(wep, vm, oldpos, oldang, pos, ang)
	local base = self.BaseClass
	if base and base.CalcViewModelView then
		local newpos, newang = base.CalcViewModelView(self, wep, vm, oldpos, oldang, pos, ang)
		pos = newpos or pos
		ang = newang or ang
	end

	if IsValid(wep) and pos and ang then
		local pl = wep:GetOwner()
		if IsValid(pl) then
			pos, ang = Stride:ApplyViewModel(pl, wep, pos, ang)
		end
	end

	return pos, ang
end

