-- Relapse: MW breathing on the camera while hip, not only at full ADS.
-- Pack zeroes the wave by AimDelta, then GetBreathingSwayAngle cuts hip again.

local HIP_SWAY = 0.5

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
		local cv = GetConVar("mgbase_sv_breathing")
		if cv and not cv:GetBool() then
			return angle_zero
		end
		if not isfunction(self.GetBreathingAngle) then
			return angle_zero
		end

		local src = self:GetBreathingAngle()
		if not src then
			return angle_zero
		end

		local ads = math.Clamp(self:GetAimDelta() or 0, 0, 1)
		local idle = (self.Zoom and self.Zoom.IdleSway) or 0.1
		local ang = Angle(
			math.NormalizeAngle(src.p),
			math.NormalizeAngle(src.y),
			math.NormalizeAngle(src.r)
		)
		ang:Mul(idle * Lerp(ads, HIP_SWAY, 1))
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
