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
	DefaultSize = 4.5, -- weapon_zs_zombie MeleeSize; the swing hull, not a reach bonus
	LeadTime = 0.08,
	ReactionTime = 0.15, -- after acquiring a target
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

function Melee:GetSwingSize()
	local wep = self.Player:GetActiveWeapon()
	if IsValid(wep) then
		return wep.MeleeSize or self.P.DefaultSize
	end
	return self.P.DefaultSize
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

-- Squared hull distance from the closer of eyes / torso, plus the point the
-- swing should look through. Slack used to be added on top of NearestPoint;
-- the real claw is MeleeReach along the aim (MeleeSize is only ~4.5).
local function Measure(self, target)
	local pl = self.Player
	local eye = pl:EyePos()
	local center = pl:WorldSpaceCenter()

	if target:IsPlayer() then
		local pe = target:NearestPoint(eye)
		local pc = target:NearestPoint(center)
		local de2, dc2 = eye:DistToSqr(pe), center:DistToSqr(pc)
		if de2 <= dc2 then
			return de2, pe, false
		end
		return dc2, pc + (eye - center), true
	end

	local pe = SurfacePoint(target, eye)
	local pc = SurfacePoint(target, center)
	local de2 = eye:DistToSqr(pe)
	local dc2 = center:DistToSqr(pc)
	if de2 <= dc2 then
		return de2, pe, false
	end
	return dc2, pc + (eye - center), true
end

local swingRes = {}
local swingMins = Vector(-4.5, -4.5, -4.5)
local swingMaxs = Vector(4.5, 4.5, 4.5)
local swingStart, swingEnd = Vector(), Vector()
local swingSelf
local function SwingFilter(ent)
	if ent == swingSelf or ent.IgnoreMelee then return false end
	if ent:IsPlayer() and ent:Team() == swingSelf:Team() then return false end
	return true
end
local swingTr = {
	mask = MASK_SOLID,
	output = swingRes,
	mins = swingMins,
	maxs = swingMaxs,
	filter = SwingFilter,
	start = swingStart,
	endpos = swingEnd,
}

-- Same shape as Player:MeleeTrace: line, then hull of MeleeSize. Eyes then torso,
-- matching CompensatedZombieMeleeTrace. No lag compensation (bots, 0 ping).
function Melee:SwingHits(target, dir)
	if not IsValid(target) or not dir then return false end
	local dist = self:GetReach()
	local size = self:GetSwingSize()
	local len = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
	if len < 0.001 then return false end
	local dx, dy, dz = dir.x / len, dir.y / len, dir.z / len

	swingMins.x, swingMins.y, swingMins.z = -size, -size, -size
	swingMaxs.x, swingMaxs.y, swingMaxs.z = size, size, size
	swingSelf = self.Player

	local function ray(ox, oy, oz)
		swingStart:SetUnpacked(ox, oy, oz)
		swingEnd:SetUnpacked(ox + dx * dist, oy + dy * dist, oz + dz * dist)
		util.TraceLine(swingTr)
		if swingRes.Hit then return swingRes.Entity end
		util.TraceHull(swingTr)
		if swingRes.Hit then return swingRes.Entity end
		return nil
	end

	local eye = self.Player:EyePos()
	if ray(eye.x, eye.y, eye.z) == target then return true end
	local mid = self.Player:WorldSpaceCenter()
	return ray(mid.x, mid.y, mid.z) == target
end

function Melee:LookDirTo(target)
	local eye = self.Player:EyePos()
	if target:IsPlayer() then
		local center = target:WorldSpaceCenter()
		local teye = target:EyePos()
		return center * 0.45 + teye * 0.55 - eye
	end
	return SurfacePoint(target, eye) - eye
end

-- Aim points on a human, in order of preference: the usual chest/eye blend,
-- the head (clears the sigil post a human stands inside of, or the crate lip
-- he crouches behind), the torso centre (a human ducked under a lintel). The
-- claw goes where the ray actually reaches him; the blend stays the aim while
-- nothing reaches. Returns hit, and leaves the choice in `out`.
local candidate = Vector(0, 0, 0)
local function PlayerAim(self, target, out)
	local eye = self.Player:EyePos()
	local center = target:WorldSpaceCenter()
	local teye = target:EyePos()
	local vel = target:GetVelocity()
	local lead = self.P.LeadTime
	local lx, ly, lz = vel.x * lead, vel.y * lead, vel.z * lead

	out.x = center.x * 0.5 + teye.x * 0.5 + lx
	out.y = center.y * 0.5 + teye.y * 0.5 + ly
	out.z = center.z * 0.5 + teye.z * 0.5 + lz
	if self:SwingHits(target, out - eye) then return true end

	candidate.x, candidate.y, candidate.z = teye.x + lx, teye.y + ly, teye.z - 3 + lz
	if self:SwingHits(target, candidate - eye) then
		out:Set(candidate)
		return true
	end

	candidate.x, candidate.y, candidate.z = center.x + lx, center.y + ly, center.z + lz
	if self:SwingHits(target, candidate - eye) then
		out:Set(candidate)
		return true
	end
	return false
end

-- Pure check used by brains before committing to a target.
local probeAim = Vector(0, 0, 0)
function Melee:IsInReachOf(target)
	if not IsValid(target) then return false end
	local d2 = Measure(self, target)
	local reach = self:GetReach()
	if d2 > reach * reach then return false end
	if target:IsPlayer() then
		if math.abs(target:GetPos().z - self.Player:GetPos().z) > reach then
			return false
		end
		return PlayerAim(self, target, probeAim)
	end
	return self:SwingHits(target, self:LookDirTo(target))
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
	local d2, lookPoint, torso = Measure(self, target)
	self.Dist = math.sqrt(d2)

	if target:IsPlayer() then
		local hit = false
		if d2 <= reach * reach then
			hit = PlayerAim(self, target, aim)
		else
			local center = target:WorldSpaceCenter()
			local teye = target:EyePos()
			local vel = target:GetVelocity()
			local lead = self.P.LeadTime
			aim.x = center.x * 0.5 + teye.x * 0.5 + vel.x * lead
			aim.y = center.y * 0.5 + teye.y * 0.5 + vel.y * lead
			aim.z = center.z * 0.5 + teye.z * 0.5 + vel.z * lead
		end
		self.InReach = hit and math.abs(target:GetPos().z - pl:GetPos().z) <= reach
	else
		aim:Set(lookPoint)
		self.InReach = d2 <= reach * reach and self:SwingHits(target, aim - pl:EyePos())
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

-- Per tick: only claw if this view's swing would hit. InReach is hull-distance
-- plus a desired-aim probe; the view lags, so the live forward is what matters.
function Melee:WantsAttack(viewAngles)
	local target = self.Target
	if not IsValid(target) then return false end
	if CurTime() - self.TargetSince < self.P.ReactionTime then return false end
	if self.Dist > self.Reach then return false end
	return self:SwingHits(target, viewAngles:Forward())
end
