-- Shared stride clock. Sounds, view bob, leg anims, and weapon mods should
-- read this instead of inventing their own step rate.
-- Procedural eye/VM overlay is off (ViewBob). MW locomotion stays on the
-- viewmodel camera bone. Sounds and legs still use this clock.
--
--   local st = GAMEMODE.Stride:Get(pl)
--   st.cycle      0-1 gait (two steps)
--   st.bobCycle   0-1 visual sway (full 2π; rate = gait * BobFreq)
--   st.foot       0 left, 1 right
--   st.interval   seconds per step
--   st.intensity  0-1
--   st.sprintBlend 0-1 (IN_SPEED run, for eye bob)
--   st.speed      2D u/s
--   st.sprinting
--   st.grounded
--
-- SWEP flags (client bob):
--   StrideSkipViewModel     skip our viewmodel overlay
--   StrideSkipCamera        skip our eye bob
--   StrideKeepEngineBob     keep HL2 BobScale
--   StrideKeepRelapseBob    force our overlay on an mg_base weapon
--   StrideBobScale          extra amplitude mul

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
Stride.ViewBob = false -- no fake camera/VM sway; MW keeps tag_camera
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
-- Walk: gun sway, camera still. Sprint: one bounce per foot, like sprint_loop.
Stride.VMWalkDip = 1.05
Stride.VMWalkSide = 0.62
Stride.VMWalkPitch = 0.75
Stride.VMWalkRoll = 1.05
Stride.CamSprintDip = 1.35
Stride.CamSprintSide = 0.45
Stride.CamSprintPitch = 1.05
Stride.CamSprintYaw = 0.28
Stride.CamSprintRoll = 2.1
Stride.VMSprintDip = 1.8
Stride.VMSprintSide = 0.9
Stride.VMSprintPitch = 1.35
Stride.VMSprintRoll = 2.4
Stride.CrouchBobMul = 0.7
Stride.AdsBobMul = 0.12

local function GetState(pl)
	local pt = E_GetTable(pl)
	local st = pt.StrideState
	if not st then
		st = {
			cycle = 0,
			bobCycle = 0,
			foot = 0,
			interval = 0.45,
			intensity = 0,
			sprintBlend = 0,
			speed = 0,
			sprinting = false,
			grounded = true,
			lastStepTime = -1
		}
		pt.StrideState = st
	else
		if st.bobCycle == nil then
			st.bobCycle = 0
		end
		if st.sprintBlend == nil then
			st.sprintBlend = 0
		end
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

	-- bobCycle is 0-1 for a full left/right (2π). Do not multiply gait cycle by
	-- BobFreq here: cycle wraps at 1, so freq 0.5 stopped at π and restarted
	-- the sway mid-motion (very obvious on fists).
	local tau = (st.bobCycle or 0) * math_pi * 2
	local vertical = -math_abs(math_cos(tau)) * a
	local lateral = math_sin(tau) * a

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
			pt.StrideState.sprintBlend = 0
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
	st.sprintBlend = math_Approach(st.sprintBlend or 0, (want > 0 and sprinting) and 1 or 0, dt * self.IntensityRate)

	if want > 0 then
		if CLIENT and not IsFirstTimePredicted() then
			return
		end

		st.interval = self:ComputeInterval(pl, speed, sprinting, P_Crouching(pl))
		local gaitDt = dt / (st.interval * 2)
		st.cycle = (st.cycle + gaitDt) % 1
		st.foot = (st.cycle >= 0.5) and 1 or 0
		st.bobCycle = ((st.bobCycle or 0) + gaitDt * (self.BobFreq or 0.5)) % 1
	end
end

hook_Add("FinishMove", "RelapseStride", function(pl, mv)
	Stride:FinishMove(pl, mv)
end)

if not CLIENT then return end

local Angle = Angle
local IsValid = IsValid
local weapons_IsBasedOn = weapons.IsBasedOn

function Stride:IsMWBaseWeapon(wep)
	if not IsValid(wep) then
		return false
	end

	local class = wep:GetClass()
	if not class then
		return false
	end

	return class == "mg_base" or weapons_IsBasedOn(class, "mg_base")
end

function Stride:ShouldSkipCamera(wep)
	if not IsValid(wep) then
		return false
	end
	if wep.StrideSkipCamera then
		return true
	end

	return self:IsMWBaseWeapon(wep) and not wep.StrideKeepRelapseBob
end

function Stride:ShouldSkipViewModel(wep)
	if not IsValid(wep) or wep.StrideSkipViewModel then
		return true
	end

	return self:IsMWBaseWeapon(wep) and not wep.StrideKeepRelapseBob
end

function Stride:GetHoldMul(pl, wep)
	local mul = 1
	if P_Crouching(pl) then
		mul = mul * (self.CrouchBobMul or 1)
	end
	if IsValid(wep) then
		mul = mul * (wep.StrideBobScale or 1)
		if wep.GetIronsights and wep:GetIronsights() then
			mul = mul * (self.AdsBobMul or 0.12)
		end
	end

	return mul
end

-- One bounce per foot, sway over the two-step gait. Same clock as footsteps.
function Stride:GetSprintShape(st)
	local c = st.cycle or 0
	local bounce = 0.5 - 0.5 * math_cos(c * math_pi * 4)
	local sway = math_sin(c * math_pi * 2)
	local kick = math_sin(c * math_pi * 4)

	return bounce, sway, kick
end

function Stride:ZeroEngineBob(pl)
	if not self.ViewBob or not self:UsesStride(pl) then return end

	local wep = pl:GetActiveWeapon()
	if IsValid(wep) and not wep.StrideKeepEngineBob then
		wep.BobScale = 0
	end
end

function Stride:ApplyCamera(pl, origin, angles)
	if not self.ViewBob or not self:UsesStride(pl) then return origin, angles end

	local wep = pl:GetActiveWeapon()
	if self:ShouldSkipCamera(wep) then return origin, angles end

	local st = GetState(pl)
	local blend = (st.sprintBlend or 0) * (st.intensity or 0) * self:GetHoldMul(pl, wep)
	if blend < 0.001 then return origin, angles end

	local bounce, sway, kick = self:GetSprintShape(st)
	local dip = bounce + kick * 0.12
	origin = origin + angles:Up() * (-dip * self.CamSprintDip * blend) + angles:Right() * (sway * self.CamSprintSide * blend)
	angles = Angle(angles.p, angles.y, angles.r)
	angles.p = angles.p + (-dip * self.CamSprintPitch) * blend
	angles.y = angles.y + sway * self.CamSprintYaw * blend
	angles.r = angles.r + sway * self.CamSprintRoll * blend

	return origin, angles
end

function Stride:ApplyViewModel(pl, wep, pos, ang)
	if not self.ViewBob or not pos or not ang or self:ShouldSkipViewModel(wep) or not self:UsesStride(pl) then
		return pos, ang
	end

	local st = GetState(pl)
	local hold = self:GetHoldMul(pl, wep)
	local intensity = st.intensity or 0
	local sprintBlend = st.sprintBlend or 0
	local walkMul = intensity * (1 - sprintBlend) * hold
	local sprintMul = intensity * sprintBlend * hold
	if walkMul < 0.001 and sprintMul < 0.001 then
		return pos, ang
	end

	ang = Angle(ang.p, ang.y, ang.r)

	if walkMul >= 0.001 then
		local vertical, lateral = self:GetBob(pl)
		-- GetBob already includes intensity; peel it so walkMul owns the fade.
		if intensity > 0.001 then
			vertical = vertical / intensity
			lateral = lateral / intensity
		end
		pos = pos + ang:Up() * (vertical * self.VMWalkDip * walkMul) + ang:Right() * (lateral * self.VMWalkSide * walkMul)
		ang:RotateAroundAxis(ang:Right(), vertical * self.VMWalkPitch * walkMul)
		ang:RotateAroundAxis(ang:Forward(), lateral * self.VMWalkRoll * walkMul)
	end

	if sprintMul >= 0.001 then
		local bounce, sway, kick = self:GetSprintShape(st)
		local dip = bounce + kick * 0.12
		pos = pos + ang:Up() * (-dip * self.VMSprintDip * sprintMul) + ang:Right() * (sway * self.VMSprintSide * sprintMul)
		ang:RotateAroundAxis(ang:Right(), -dip * self.VMSprintPitch * sprintMul)
		ang:RotateAroundAxis(ang:Forward(), sway * self.VMSprintRoll * sprintMul)
	end

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

