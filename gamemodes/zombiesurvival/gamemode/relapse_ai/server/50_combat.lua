-- Relapse AI combat adapters.
-- An adapter owns the "how do I hurt this" part: aim point, reach/standoff and the
-- fire decision. Brains only pick targets. Melee is implemented; a Gun adapter for
-- the human brain must expose the same interface:
--   New(bot), SetTarget(ent), GetTarget(), Think(dt), GetAimPos(),
--   GetApproachPos(frompos) -> Vector|Entity, GetStandoff(), WantsAttack(viewAngles),
--   InReach (field), Kind (field)

local AI = RelapseAI
local Combat = {}
AI.Combat = Combat

local CurTime = CurTime
local IsValid = IsValid

---------------------------------------------------------------------------
-- Melee
---------------------------------------------------------------------------

local Melee = {}
Melee.__index = Melee
Combat.Melee = Melee

Melee.Defaults = {
	DefaultReach = 48,
	PlayerSlack = 12, -- the hull is hit before the aim point
	PropSlack = 6,
	LeadTime = 0.08,
	ReactionTime = 0.15, -- after acquiring a target
	FacingDot = 0.96, -- ~16 degrees
}

function Melee.New(bot)
	local self = setmetatable({}, Melee)
	self.Bot = bot
	self.Player = bot.Player
	self.Kind = "melee"
	self.Target = nil
	self.TargetSince = 0
	self.AimPos = Vector(0, 0, 0)
	self.InReach = false
	self.Dist = 0
	self.Reach = Melee.Defaults.DefaultReach
	self.P = table.Copy(Melee.Defaults)
	return self
end

function Melee:SetTarget(ent)
	if self.Target ~= ent then
		self.Target = ent
		self.TargetSince = CurTime()
		self.InReach = false
	end
end

function Melee:GetTarget()
	return self.Target
end

function Melee:GetReach()
	local wep = self.Player:GetActiveWeapon()
	if IsValid(wep) then
		return wep.MeleeReach or wep.MeleeRange or self.P.DefaultReach
	end
	return self.P.DefaultReach
end

function Melee:IsSwinging()
	local wep = self.Player:GetActiveWeapon()
	return IsValid(wep) and wep.IsSwinging and wep:IsSwinging() or false
end

local function SurfacePoint(ent, from)
	local point = ent:NearestPoint(from)
	if point == ent:GetPos() then
		return ent:WorldSpaceCenter()
	end
	return point
end

-- The zombie swing traces from the eyes and from the torso along the same aim
-- direction (CompensatedZombieMeleeTrace). Returns the squared distance from the
-- closer origin, the reach (with slack) that applies, the point to look at so that
-- the chosen ray goes through the target, and whether the torso ray was chosen.
local function Measure(self, target, reach)
	local pl = self.Player
	local eye = pl:EyePos()

	if target:IsPlayer() then
		-- Reach is measured to the hull, not to the aim point.
		return eye:DistToSqr(target:NearestPoint(eye)), reach + self.P.PlayerSlack, nil, false
	end

	local center = pl:WorldSpaceCenter()
	local pe = SurfacePoint(target, eye)
	local pc = SurfacePoint(target, center)
	local de2 = eye:DistToSqr(pe)
	local dc2 = center:DistToSqr(pc)

	if de2 <= dc2 then
		return de2, reach + self.P.PropSlack, pe, false
	end

	-- Torso ray: look at the point shifted up by (eye - center) so the parallel
	-- ray from the torso passes through pc.
	return dc2, reach + self.P.PropSlack, pc + (eye - center), true
end

-- Pure check used by brains before committing to a target.
function Melee:IsInReachOf(target)
	if not IsValid(target) then return false end
	local d2, reach = Measure(self, target, self:GetReach())
	if d2 > reach * reach then return false end
	if target:IsPlayer() and math.abs(target:GetPos().z - self.Player:GetPos().z) > reach then
		return false
	end
	return true
end

function Melee:Think(dt)
	local target = self.Target
	if not IsValid(target) or (target:IsPlayer() and not target:Alive()) then
		self.Target = nil
		self.InReach = false
		self.WantDuck = false
		return
	end

	local pl = self.Player
	local reach = self:GetReach()
	self.Reach = reach
	self.WantDuck = false

	local aim = self.AimPos
	local d2, effective, lookPoint, torso = Measure(self, target, reach)

	if target:IsPlayer() then
		local center = target:WorldSpaceCenter()
		local teye = target:EyePos()
		local vel = target:GetVelocity()
		local lead = self.P.LeadTime
		aim.x = center.x * 0.5 + teye.x * 0.5 + vel.x * lead
		aim.y = center.y * 0.5 + teye.y * 0.5 + vel.y * lead
		aim.z = center.z * 0.5 + teye.z * 0.5 + vel.z * lead
	else
		aim:Set(lookPoint)
	end

	self.Dist = math.sqrt(d2)
	self.InReach = d2 <= effective * effective
	if self.InReach and target:IsPlayer() and math.abs(target:GetPos().z - pl:GetPos().z) > effective then
		self.InReach = false
	end

	-- Low prop right in front of us: crouch so the torso ray can reach it.
	if not self.InReach and torso then
		local mypos = pl:GetPos()
		local low = SurfacePoint(target, mypos)
		local dx, dy = low.x - mypos.x, low.y - mypos.y
		if low.z < pl:WorldSpaceCenter().z and dx * dx + dy * dy <= reach * reach then
			self.WantDuck = true
		end
	end
end

function Melee:GetAimPos()
	if not self.Target then return nil end
	return self.AimPos
end

-- Where locomotion should go to be able to hit the target.
function Melee:GetApproachPos(frompos)
	local target = self.Target
	if not IsValid(target) then return nil end
	if target:IsPlayer() then
		return target
	end
	return SurfacePoint(target, frompos)
end

function Melee:GetStandoff()
	local target = self.Target
	if IsValid(target) and target:IsPlayer() then
		return math.max(24, self.Reach * 0.7)
	end
	return math.max(24, self.Reach * 0.6)
end

-- Per tick: hold attack while the target is in reach and roughly in front.
function Melee:WantsAttack(viewAngles)
	if not self.InReach or not IsValid(self.Target) then return false end
	if CurTime() - self.TargetSince < self.P.ReactionTime then return false end

	local eye = self.Player:EyePos()
	local aim = self.AimPos
	local dx, dy, dz = aim.x - eye.x, aim.y - eye.y, aim.z - eye.z
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len < 1 then return true end

	local fwd = viewAngles:Forward()
	local dot = (fwd.x * dx + fwd.y * dy + fwd.z * dz) / len
	return dot >= self.P.FacingDot
end
