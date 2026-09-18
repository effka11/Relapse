-- Relapse: one idle breath wave for every first-person SWEP.
-- MW: GetBreathingSwayAngle -> Camera.LerpBreathing (eye + VM).
-- Other weapons: GM:_CalcView adds the same angle once.
-- Pack ADS sway stays here. Hip pack scale is 0 so this wave is not stacked.

RelapseBreath = RelapseBreath or {}

local HIP_PITCH = 0.22
local HIP_YAW = 0.15
local HIP_ROLL = 0.05

function RelapseBreath.Enabled()
	local cv = GetConVar("mgbase_sv_breathing")
	if cv then
		return cv:GetBool()
	end
	return true
end

local function adsMul(wep)
	if not IsValid(wep) then
		return 1
	end
	if wep.GetAimDelta then
		return 1 - math.Clamp(wep:GetAimDelta() or 0, 0, 1)
	end
	if wep.GetIronsights and wep:GetIronsights() then
		local gm = GAMEMODE
		if not (gm and gm.NoIronsights) then
			return 0
		end
	end
	return 1
end

local function sprintMul(wep, ply)
	if IsValid(wep) then
		if wep.HasFlag and wep:HasFlag("Sprinting") then
			return 0
		end
		if wep.GetIsSprinting and wep:GetIsSprinting() then
			return 0
		end
	end
	if not IsValid(ply) then
		return 1
	end
	local stride = GAMEMODE and GAMEMODE.Stride
	if stride and stride.Get then
		local st = stride:Get(ply)
		if st then
			if st.sprinting then
				return 0
			end
			if st.sprintBlend then
				return 1 - math.Clamp(st.sprintBlend, 0, 1)
			end
		end
	end
	return 1
end

function RelapseBreath.IdleAngle(wep, ply)
	if not RelapseBreath.Enabled() then
		return Angle(0, 0, 0)
	end
	if IsValid(wep) then
		ply = ply or wep:GetOwner()
		if wep.HasFlag and wep:HasFlag("Customizing") then
			return Angle(0, 0, 0)
		end
	end
	local mul = adsMul(wep) * sprintMul(wep, ply)
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
	if not wep or wep.RelapseHipBreath then return end
	if not isfunction(wep.GetBreathingSwayAngle) and not isfunction(wep.BreathingModule) then
		return
	end
	wep.RelapseHipBreath = true

	if isfunction(wep.BreathingModule) then
		wep.BreathingModule = function(self)
			local mul = 1
			local owner = self:GetOwner()
			local aiming = self.HasFlag and self:HasFlag("Aiming")
			local sight = self.GetSight and self:GetSight()
			local hybrid = self.m_hybridSwitchThreshold or 0.4
			local modeDelta = self.GetAimModeDelta and self:GetAimModeDelta() or 0

			if aiming and sight and sight.Optic and modeDelta <= hybrid then
				if IsValid(owner) and owner:KeyDown(IN_SPEED) and not self:GetHasRunOutOfBreath() then
					mul = 0
					self:SetBreathingDelta(math.max(self:GetBreathingDelta() - FrameTime() * 0.3, 0))
					if self:GetBreathingDelta() <= 0 then
						self:SetHasRunOutOfBreath(true)
					end
				end
			else
				self:SetBreathingDelta(math.min(self:GetBreathingDelta() + FrameTime() * 0.2, 1))
			end

			if self:GetHasRunOutOfBreath() then
				mul = mul + (5 * (1 - self:GetBreathingDelta()))
				self:SetBreathingDelta(math.min(self:GetBreathingDelta() + FrameTime() * 0.2, 1))
				if self:GetBreathingDelta() >= 1 then
					self:SetHasRunOutOfBreath(false)
				end
			end

			local t = CurTime()
			local pitch = math.sin(t * 3) * math.cos(t * 1.5)
			local yaw = math.cos(t * 1.5) * math.sin(t * 0.75)
			self:SetBreathingAngle(Angle(pitch * mul, yaw * mul, 0))
		end
	end

	wep.GetBreathingSwayAngle = function(self)
		if not RelapseBreath.Enabled() then
			return Angle(0, 0, 0)
		end

		local ang = RelapseBreath.IdleAngle(self, self:GetOwner())
		local ads = 0
		if self.GetAimDelta then
			ads = math.Clamp(self:GetAimDelta() or 0, 0, 1)
		end
		if ads > 0.001 and isfunction(self.GetBreathingAngle) then
			local src = self:GetBreathingAngle()
			if src then
				local idle = (self.Zoom and self.Zoom.IdleSway) or 0.1
				local pack = Angle(
					math.NormalizeAngle(src.p),
					math.NormalizeAngle(src.y),
					math.NormalizeAngle(src.r)
				)
				pack:Mul(idle * ads)
				ang:Add(pack)
			end
		end
		return ang
	end
end

hook.Add("PreRegisterSWEP", "RelapseMWHipBreath", function(SWEP, class)
	if class == "mg_base" then
		patchBase(SWEP)
	end
end)

local function apply()
	patchBase(weapons.GetStored("mg_base"))
end

hook.Add("Initialize", "RelapseMWHipBreath", apply)
hook.Add("InitPostEntity", "RelapseMWHipBreath", apply)
hook.Add("OnReloaded", "RelapseMWHipBreath", apply)
