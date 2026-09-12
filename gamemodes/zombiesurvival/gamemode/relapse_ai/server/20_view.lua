-- Relapse AI view controller.
-- The bot owns its view state (yaw, pitch, angular velocity) instead of snapping
-- cmd angles at a target every tick. The look point is low-pass filtered and the
-- angles follow it with rate and acceleration limits, so the head never jerks:
-- no overshoot, no snaps when path segments change, natural sweeps on target switch.

local AI = RelapseAI
local View = {}
View.__index = View
AI.View = View

local CurTime = CurTime
local IsValid = IsValid
local math_abs = math.abs
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_exp = math.exp
local math_Approach = math.Approach
local math_AngleDifference = math.AngleDifference
local math_NormalizeAngle = math.NormalizeAngle

View.Defaults = {
	YawRate = 380, -- deg/s
	YawAccel = 2200, -- deg/s^2
	PitchRate = 200,
	PitchAccel = 1400,
	Gain = 9, -- error (deg) -> desired velocity (deg/s)
	FilterTime = 0.10, -- look point low-pass time constant
	SwitchSlow = 0.30, -- seconds after a target switch with a slower filter (reaction)
	SwitchMul = 2.5,
	MaxPitch = 80,
	SwayYaw = 5,
	SwayPitch = 2.5,
	SwaySpeed = 0.35,
}

function View.New(pl, bot)
	local ang = pl:EyeAngles()
	local self = setmetatable({}, View)
	self.Player = pl
	self.Bot = bot
	self.Yaw = ang.y
	self.Pitch = ang.p
	self.VelYaw = 0
	self.VelPitch = 0
	self.Mode = "idle"
	self.TargetPos = nil
	self.TargetEnt = nil
	self.Filtered = nil
	self.SwitchTime = 0
	self.Seed = math.Rand(0, 1000)
	self.P = table.Copy(View.Defaults)
	self.Out = Angle(ang.p, ang.y, 0)
	return self
end

function View:SetParams(tbl)
	if not tbl then return end
	for k, v in pairs(tbl) do
		self.P[k] = v
	end
end

function View:Reset(ang)
	ang = ang or self.Player:EyeAngles()
	self.Yaw = ang.y
	self.Pitch = math.NormalizeAngle(ang.p)
	self.VelYaw = 0
	self.VelPitch = 0
	self.Filtered = nil
	self.TargetPos = nil
	self.TargetEnt = nil
	self.OverridePos = nil
	self.Mode = "idle"
	self.Out.p = self.Pitch
	self.Out.y = self.Yaw
	self.Out.r = 0
end

function View:GetAngles()
	return self.Out
end

-- Look at a world position. Modes: "path" (soft, with sway), "target", "look".
function View:LookAt(pos, mode)
	mode = mode or "look"
	if self.TargetEnt or self.Mode ~= mode then
		self.SwitchTime = CurTime()
	end
	self.TargetEnt = nil
	if self.TargetPos then
		self.TargetPos:Set(pos)
	else
		self.TargetPos = Vector(pos)
	end
	self.Mode = mode
end

function View:LookAtEntity(ent, mode)
	mode = mode or "target"
	if self.TargetEnt ~= ent then
		self.SwitchTime = CurTime()
	end
	self.TargetEnt = ent
	self.TargetPos = nil
	self.Mode = mode
end

function View:Idle()
	if self.Mode ~= "idle" then
		self.SwitchTime = CurTime()
	end
	self.Mode = "idle"
	self.TargetEnt = nil
	self.TargetPos = nil
end

-- Locomotion needs the head somewhere specific (facing a ladder) while the brain
-- keeps setting its own targets: this sits on top of them until cleared.
function View:SetOverride(pos)
	if self.OverridePos then
		self.OverridePos:Set(pos)
	else
		self.OverridePos = Vector(pos)
		self.SwitchTime = CurTime()
	end
end

function View:ClearOverride()
	if self.OverridePos then
		self.OverridePos = nil
		self.SwitchTime = CurTime()
	end
end

local function EntityLookPoint(self, ent)
	if ent:IsPlayer() then
		-- Upper chest: between the eyes and the center of mass.
		local center = ent:WorldSpaceCenter()
		local eye = ent:EyePos()
		return center * 0.45 + eye * 0.55
	end

	local eye = self.Player:EyePos()
	local point = ent:NearestPoint(eye)
	if point == ent:GetPos() then
		return ent:WorldSpaceCenter()
	end
	return point
end

-- Angle (degrees) between where we look now and a world position.
function View:AngleTo(pos)
	local eye = self.Player:EyePos()
	local dir = pos - eye
	local len = dir:Length()
	if len < 1 then return 0 end
	local fwd = self.Out:Forward()
	local dot = fwd:Dot(dir) / len
	if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
	return math.deg(math.acos(dot))
end

local function Axis(cur, vel, target, rate, accel, gain, dt)
	local err = math_AngleDifference(target, cur)
	local want = err * gain

	-- Never faster than what we can still brake from without overshoot.
	local vmax = math_sqrt(2 * accel * math_abs(err))
	if want > vmax then want = vmax elseif want < -vmax then want = -vmax end
	if want > rate then want = rate elseif want < -rate then want = -rate end

	vel = math_Approach(vel, want, accel * dt)
	cur = math_NormalizeAngle(cur + vel * dt)
	return cur, vel
end

function View:Step(dt)
	local pl = self.Player
	local p = self.P
	local eye = pl:EyePos()

	local target
	local ent = self.TargetEnt
	if self.OverridePos then
		target = self.OverridePos
	elseif ent then
		if IsValid(ent) then
			target = EntityLookPoint(self, ent)
		else
			self.TargetEnt = nil
			self.Mode = "idle"
		end
	elseif self.TargetPos then
		target = self.TargetPos
	end

	local desiredYaw, desiredPitch
	if target then
		local f = self.Filtered
		if not f then
			-- Start the sweep from where we currently look, at the target's distance.
			local dist = target:Distance(eye)
			f = eye + self.Out:Forward() * dist
			self.Filtered = f
		else
			local tau = p.FilterTime
			if CurTime() - self.SwitchTime < p.SwitchSlow then
				tau = tau * p.SwitchMul
			end
			local a = 1 - math_exp(-dt / tau)
			f.x = f.x + (target.x - f.x) * a
			f.y = f.y + (target.y - f.y) * a
			f.z = f.z + (target.z - f.z) * a
		end

		local dx, dy, dz = f.x - eye.x, f.y - eye.y, f.z - eye.z
		local flat = math_sqrt(dx * dx + dy * dy)
		if flat < 1 and math_abs(dz) < 1 then
			desiredYaw, desiredPitch = self.Yaw, 0
		else
			desiredYaw = math.deg(math.atan2(dy, dx))
			desiredPitch = -math.deg(math.atan2(dz, flat))
		end
	else
		self.Filtered = nil
		desiredYaw, desiredPitch = self.Yaw, 0
	end

	local mode = self.OverridePos and "look" or self.Mode
	if mode == "idle" or mode == "path" then
		local t = CurTime() * p.SwaySpeed + self.Seed
		local mul = mode == "idle" and 1 or 0.4
		desiredYaw = desiredYaw + math_sin(t) * p.SwayYaw * mul
		desiredPitch = desiredPitch + math_sin(t * 1.7 + 1) * p.SwayPitch * mul
	end

	if desiredPitch > p.MaxPitch then desiredPitch = p.MaxPitch elseif desiredPitch < -p.MaxPitch then desiredPitch = -p.MaxPitch end

	self.Yaw, self.VelYaw = Axis(self.Yaw, self.VelYaw, desiredYaw, p.YawRate, p.YawAccel, p.Gain, dt)
	self.Pitch, self.VelPitch = Axis(self.Pitch, self.VelPitch, desiredPitch, p.PitchRate, p.PitchAccel, p.Gain, dt)
	if self.Pitch > 89 then self.Pitch = 89 elseif self.Pitch < -89 then self.Pitch = -89 end

	local out = self.Out
	out.p = self.Pitch
	out.y = self.Yaw
	out.r = 0
	return out
end
