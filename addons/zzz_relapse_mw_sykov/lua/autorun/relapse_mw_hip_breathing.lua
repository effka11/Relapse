-- Relapse: MW camera breathing while hip, not only ADS.
-- Pack GetBreathingSwayAngle fades m_swayLerp to 0 off-ADS.

local HIP_PITCH = 0.22
local HIP_YAW = 0.15
local HIP_ROLL = 0.05

local function isMelee(wep)
	return wep.IsMelee or (istable(wep.Relapse) and wep.Relapse.Melee)
end

local function sprintMul(self)
	if self.HasFlag and self:HasFlag("Sprinting") then
		return 0
	end
	if self.GetIsSprinting and self:GetIsSprinting() then
		return 0
	end
	return 1
end

local function hipBreathAngle(self)
	if isMelee(self) then
		return Angle(0, 0, 0)
	end

	local ads = 0
	if self.GetAimDelta then
		ads = math.Clamp(self:GetAimDelta() or 0, 0, 1)
	end
	local mul = (1 - ads) * sprintMul(self)
	if mul <= 0.001 then
		return Angle(0, 0, 0)
	end

	local t = CurTime()
	return Angle(
		math.sin(t * 1.35) * math.cos(t * 0.62) * HIP_PITCH * mul,
		math.cos(t * 1.05) * math.sin(t * 0.47) * HIP_YAW * mul,
		math.sin(t * 0.8) * HIP_ROLL * mul
	)
end

local function patchBase(wep)
	if not wep or wep.RelapseHipBreathing then return end

	if isfunction(wep.GetBreathingSwayAngle) then
		wep.RelapseHipBreathing = true
		local old = wep.GetBreathingSwayAngle
		wep.GetBreathingSwayAngle = function(self)
			local ang = old(self)
			if ang == nil then
				ang = Angle(0, 0, 0)
			else
				ang = Angle(ang.p, ang.y, ang.r)
			end
			ang:Add(hipBreathAngle(self))
			return ang
		end
		return
	end

	if not isfunction(wep.CalcView) then return end

	wep.RelapseHipBreathing = true
	local oldView = wep.CalcView
	wep.CalcView = function(self, ply, pos, ang, fov)
		local p, a, f = oldView(self, ply, pos, ang, fov)
		if not isangle(a) then
			a = ang
		end
		a:Add(hipBreathAngle(self))
		return p, a, f
	end
end

hook.Add("PreRegisterSWEP", "RelapseMWHipBreathing", function(SWEP, class)
	if class == "mg_base" then
		patchBase(SWEP)
	end
end)

local function apply()
	patchBase(weapons.GetStored("mg_base"))
end

hook.Add("Initialize", "RelapseMWHipBreathing", apply)
hook.Add("InitPostEntity", "RelapseMWHipBreathing", apply)
hook.Add("OnReloaded", "RelapseMWHipBreathing", apply)
