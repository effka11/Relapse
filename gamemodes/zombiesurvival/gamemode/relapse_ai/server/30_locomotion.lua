-- Relapse AI locomotion: follows a PathFollower with a moving cursor and a
-- speed-scaled lookahead, converts the wish direction into forward/side moves
-- relative to the current view yaw, handles jumps/ducks, stuck escalation,
-- obstacle probing (barricades) and crowd spreading.
--
-- Jumping is evidence-based: a jump needs a real ledge in front (higher than the
-- step, lower than the jump height, room above). Path segment types and nav
-- attributes only say where to look; stairs and ramps are walked.
--
-- A breakable in the way is attacked only as the last resort: first crawl under
-- it, then hop over it, then ask the mesh for a way around it (the barricade gets
-- a path penalty, so a detour up to that long wins), and only then swing.
--
-- Ladders are climbed the way a player does it: walk up to the rungs, face them,
-- press forward looking up (the engine attaches on contact), keep pressing over
-- the lip. The ladder state machine owns movement and the head until it is done.

local AI = RelapseAI
local Loco = {}
Loco.__index = Loco
AI.Loco = Loco

local CurTime = CurTime
local IsValid = IsValid
local ipairs = ipairs
local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_ceil = math.ceil
local math_cos = math.cos
local math_sin = math.sin
local math_rad = math.rad
local math_deg = math.deg
local math_atan2 = math.atan2
local math_AngleDifference = math.AngleDifference
local bit_bor = bit.bor
local util_TraceHull = util.TraceHull
local util_TraceLine = util.TraceLine
local navmesh_GetNavArea = navmesh.GetNavArea

local SEEK_ENTIRE_PATH = 0
local SEEK_AHEAD = 1

local SEG_GROUND = 0
local SEG_DROP = 1
local SEG_CLIMB = 2
local SEG_GAP = 3
local SEG_LADDER_UP = 4
local SEG_LADDER_DOWN = 5

local NAV_STAIRS = NAV_MESH_STAIRS or 4096
local NAV_NO_JUMP = NAV_MESH_NO_JUMP or 8
local WALKABLE_Z = 0.7 -- a surface normal above this is a slope we simply walk

-- ProbeLedge results.
local LEDGE_CLEAR = "clear" -- nothing above step height: keep walking
local LEDGE_JUMP = "ledge" -- between step and jump height with room above: jump
local LEDGE_WALL = "wall" -- too high or no room: not jumpable here

Loco.Defaults = {
	Tolerance = 32,
	LookAheadMin = 48,
	LookAheadMax = 110,
	LookAheadSpeedMul = 0.45,
	RepathMoving = 2.5, -- seconds, goal is an entity
	RepathStatic = 8,
	RepathMinInterval = 0.5,
	OffPathDist = 110,
	GoalMoveRepath = 64,
	DirectDist = 200,
	StuckTime = 0.9,
	ProgressDist = 20,
	StepHeight = 18,
	JumpHeight = 60, -- duck-jump ledge (185 jump power, 600 gravity)
	LedgeProbe = 20, -- ledge hull sweep (+8 of hull); short, so stairs stay below step height inside it
	ProbeDist = 56,
	ObstacleAccept = 40, -- a breakable further than this from our centre is not "in the way" yet
	DuckProbe = 96,
	ObstacleTimeout = 25,
	ObstacleIgnore = 8,
	DetourWait = 1.5, -- seconds to wait for a path around a barricade before swinging at it
	BarricadeMark = 40, -- seconds a barricade keeps its path penalty (refreshed while we hit it)
	ExhaustedGiveUp = 2, -- seconds standing at the end of a path that does not reach the goal
	LadderMount = 22, -- stand this far in front of the rungs before pressing into them
	LadderApproachTime = 6,
	LadderMountTime = 2.5,
	LadderStallTime = 2, -- on the rungs without gaining height
	LadderDismountTime = 4,
	LadderRetries = 2,
	LadderBan = 12, -- seconds paths avoid a ladder we failed on
	LadderPitchUp = -35, -- looking up the rungs while climbing (negative = up)
	LadderPitchDown = 65,
	LadderFaceTolerance = 20, -- degrees off the rungs before we press on them
}

function Loco.New(pl, bot)
	local self = setmetatable({}, Loco)
	self.Player = pl
	self.Bot = bot
	self.P = table.Copy(Loco.Defaults)

	self.Mode = "stop" -- stop | path | direct
	self.Hold = false
	self.Goal = nil
	self.GoalEnt = nil
	self.GoalTol = self.P.Tolerance
	self.SpeedFrac = 1

	self.Path = nil
	self.PathValid = false
	self.PathReached = false
	self.PathGoal = nil
	self.PathTime = 0
	self.PathLength = 0
	self.PathPending = false
	self.NeedRepath = false
	self.NextRepath = 0
	self.FailedPaths = 0
	self.Segments = nil
	self.SegIndex = 1
	self.Cursor = 0
	self.OffPath = false
	self.Exhausted = false
	self.ExhaustedSince = nil

	self.Ladder = nil -- ladder state machine while climbing, see BeginLadder
	self.LadderDone = nil -- {Ent, Until}: just left this ladder, do not remount it
	self.ViaLadder = nil -- CNavLadder we are walking to because the goal is on another floor
	self.ViaUp = nil
	self.ViaMount = nil

	self.SteerPos = nil
	self.LookPos = nil
	self.WishDir = Vector(0, 0, 0) -- actual movement direction (lane offset, sidesteps)
	self.PathDir = Vector(0, 0, 0) -- pure direction along the path, used for probing

	self.JumpUntil = 0
	self.NextJump = 0
	self.DuckFrom = 0
	self.DuckUntil = 0
	self.SideStep = 1
	self.SideStepUntil = 0

	self.ProgressPos = pl:GetPos()
	self.ProgressTime = CurTime()
	self.StuckLevel = 0
	self.LastEscalation = 0
	self.StuckEpisodes = 0

	self.Obstacle = nil
	self.ObstaclePos = nil
	self.ObstacleHit = nil
	self.ObstacleLoose = false
	self.ObstacleAreas = nil
	self.ObstacleSince = 0
	self.ObstacleSeen = 0
	self.NextMark = 0
	self.DetourUntil = 0
	self.Detours = 0
	self.IgnoredObstacles = {}
	self.ClearPath = false -- hunt/search/sigil: unnailed props on the way may be broken

	-- Spread a crowd: each bot steers to a slightly different lane.
	self.LaneOffset = (((pl:EntIndex() * 7919) % 7) - 3) * 6

	return self
end

function Loco:Destroy()
	AI.Nav.Cancel(self.Bot)
	self.Path = nil
	self.Segments = nil
end

---------------------------------------------------------------------------
-- Goals
---------------------------------------------------------------------------

-- target: Vector or Entity (followed). ignoreEnt: entity that may sit on the goal
-- (the thing we want to hit) and must not count as blocking the direct approach.
function Loco:SetGoal(target, tolerance, ignoreEnt)
	local pos, ent
	if isentity(target) then
		if not IsValid(target) then return end
		ent = target
		pos = target:GetPos()
	else
		pos = target
	end

	self.GoalTol = tolerance or self.P.Tolerance
	self.IgnoreEnt = ignoreEnt or ent

	local changed = self.Goal == nil or self.GoalEnt ~= ent or (ent == nil and self.Goal:DistToSqr(pos) > 576)
	self.GoalEnt = ent
	if self.Goal then
		self.Goal:Set(pos)
	else
		self.Goal = Vector(pos)
	end

	if self.Mode == "stop" then
		self.Mode = "path"
		self:ResetProgress()
	end

	if changed then
		self.NextRepath = 0
		self.Exhausted = false
		self.ExhaustedSince = nil
		self.StuckEpisodes = 0
	end
end

function Loco:Stop()
	if self.Mode ~= "stop" then
		self.Mode = "stop"
		self.WishDir:Zero()
	end
	self.Goal = nil
	self.GoalEnt = nil
	self.IgnoreEnt = nil
	self.PathValid = false
	self.Segments = nil
	self.SteerPos = nil
	self.LookPos = nil
	self.Hold = false
	self.PathPending = false
	self.NeedRepath = false
	self.ViaLadder = nil
	self.ViaUp = nil
	self.ClearPath = false
	-- Halfway up a ladder we finish the climb; anything else is dropped.
	if self.Ladder and self.Player:GetMoveType() ~= MOVETYPE_LADDER then
		self:EndLadder("stop")
	end
	AI.Nav.Cancel(self.Bot)
end

-- Keep the goal but stand still (attacking something in reach).
function Loco:SetHold(hold)
	self.Hold = hold and true or false
	if self.Hold then
		self.WishDir:Zero()
	end
end

function Loco:IsMoving()
	return self.Mode ~= "stop" and not self.Hold and self.Goal ~= nil
end

function Loco:IsGoalReached()
	local goal = self.Goal
	if not goal then return true end
	local pos = self.Player:GetPos()
	local dx, dy = goal.x - pos.x, goal.y - pos.y
	-- Same floor only: standing under someone on a ledge is not "there".
	return dx * dx + dy * dy <= self.GoalTol * self.GoalTol and math_abs(goal.z - pos.z) < 40
end

function Loco:DistanceToGoal()
	if not self.Goal then return 0 end
	return self.Player:GetPos():Distance(self.Goal)
end

-- Where the view should look while walking: well ahead on the path.
function Loco:GetLookPoint()
	return self.LookPos or self.SteerPos or self.Goal
end

-- The path exists but cannot reach the goal (we stood at its end for a while, or
-- got stuck on it), we are repeatedly stuck, or no path can be found at all.
function Loco:IsHopeless()
	if self.Ladder then return false end
	if AI.Nav.HasLadder(self.ViaLadder) then return false end
	-- Under a player on another floor is not failure: DestForGoal should send
	-- us to a ladder. Giving up here makes the brain walk off to a sigil.
	if self.Goal and math_abs(self.Goal.z - self.Player:GetPos().z) > 40 then
		return false
	end
	if self.Exhausted then
		if self.StuckEpisodes >= 1 then return true end
		if self.ExhaustedSince and CurTime() - self.ExhaustedSince > self.P.ExhaustedGiveUp then return true end
	end
	return self.StuckEpisodes >= 3 or self.FailedPaths >= 3
end

---------------------------------------------------------------------------
-- Path results
---------------------------------------------------------------------------

function Loco:OnPathResult(path, reached, goal)
	local oldLength = self.PathLength

	self.PathPending = false
	self.Path = path
	self.PathValid = path:IsValid()
	self.PathReached = reached
	self.PathTime = CurTime()
	self.Exhausted = false
	if reached then self.ExhaustedSince = nil end -- a partial path again keeps the clock running
	self.OffPath = false

	if self.PathGoal then
		self.PathGoal:Set(goal)
	else
		self.PathGoal = Vector(goal)
	end

	if self.PathValid then
		self.PathLength = path:GetLength()
		self.Segments = path:GetAllSegments()
		self.SegIndex = 1
		path:MoveCursorToStart()
		self.FailedPaths = 0
	else
		self.PathLength = 0
		self.Segments = nil
		self.FailedPaths = self.FailedPaths + 1
	end

	-- Asked for a way around a barricade: did we get one?
	if self.DetourUntil > 0 then
		self.DetourUntil = 0
		local obstacle = self.Obstacle
		if IsValid(obstacle) then
			local around = self.PathValid and not self:PathPassesNear(obstacle)
			if AI.cv.debug:GetInt() > 0 then
				AI.Log("%s: %s %s (%.0f -> %.0f u)", self.Player:Nick(),
					around and "detours around" or "no way around", obstacle:GetClass(), oldLength, self.PathLength)
			end
			if around then
				self.Detours = self.Detours + 1
				-- Keep the marks (it is still there for everyone) and do not re-detect it right away.
				self.IgnoredObstacles[obstacle] = CurTime() + 3
				self:ClearObstacle(false)
				self:Note("detour")
			else
				self:Note("break:noway")
			end
		end
	end
end

-- Does the current path run through/next to this entity? Sampled every 24 units,
-- skipping the first 48 (we are usually standing right in front of it).
function Loco:PathPassesNear(ent)
	local segs = self.Segments
	if not segs then return true end

	local mins, maxs = ent:WorldSpaceAABB()
	local pad = 24
	local x0, y0, z0 = mins.x - pad, mins.y - pad, mins.z - 80
	local x1, y1, z1 = maxs.x + pad, maxs.y + pad, maxs.z + pad

	local prev, prevDist
	for i = 1, #segs do
		local seg = segs[i]
		local p = seg.pos
		if prev then
			local ddx, ddy, ddz = p.x - prev.x, p.y - prev.y, p.z - prev.z
			local flat = math_sqrt(ddx * ddx + ddy * ddy)
			local steps = math_ceil(flat / 24)
			if steps < 1 then steps = 1 end
			for s = 1, steps do
				local t = s / steps
				if prevDist + flat * t >= 48 then
					local x, y, z = prev.x + ddx * t, prev.y + ddy * t, prev.z + ddz * t
					if x >= x0 and x <= x1 and y >= y0 and y <= y1 and z >= z0 and z <= z1 then
						return true
					end
				end
			end
		end
		prev = p
		prevDist = seg.distanceFromStart
	end
	return false
end

---------------------------------------------------------------------------
-- Jumping / ducking
---------------------------------------------------------------------------

-- Why we last jumped/ducked/shuffled; shown in the debug overlay next to the state.
function Loco:Note(reason)
	self.LastAction = reason
	self.LastActionTime = CurTime()
end

function Loco:GetNote(maxAge)
	local t = self.LastActionTime
	if t and CurTime() - t <= (maxAge or 2) then
		return self.LastAction
	end
	return nil
end

function Loco:Jump(reason)
	local now = CurTime()
	if now < self.NextJump or not self.Player:IsOnGround() then return false end
	self.NextJump = now + 0.9
	self.JumpUntil = now + 0.06
	-- Duck-jump: tuck the legs shortly after leaving the ground for extra ledge height.
	self.DuckFrom = now + 0.12
	self.DuckUntil = now + 0.65
	if reason then self:Note("jump:" .. reason) end
	return true
end

function Loco:Duck(duration, reason)
	local now = CurTime()
	self.DuckFrom = math_min(self.DuckFrom, now)
	self.DuckUntil = math_max(self.DuckUntil, now + (duration or 0.25))
	if reason then self:Note("duck:" .. reason) end
end

---------------------------------------------------------------------------
-- Traces
---------------------------------------------------------------------------

local probeSelf, probeIgnore
local function ProbeFilter(ent)
	return ent ~= probeSelf and ent ~= probeIgnore and not ent:IsPlayer()
end

-- Knee/chest/head bands: what is directly ahead. Knee 8..32, chest 34..58 (24 tall), head 60..72.
local probeTrace = {
	mask = MASK_PLAYERSOLID,
	mins = Vector(-10, -10, -6),
	maxs = Vector(10, 10, 18),
	filter = ProbeFilter,
}
local PROBE_BAND = 18
local PROBE_HEAD = 6
-- Narrow crouched hull, lifted by the step or jump height.
local ledgeTrace = {
	mask = MASK_PLAYERSOLID,
	mins = Vector(-8, -8, 0),
	maxs = Vector(8, 8, 36),
	filter = ProbeFilter,
}
-- Full crouched player hull.
local duckTrace = {
	mask = MASK_PLAYERSOLID,
	mins = Vector(-16, -16, 0),
	maxs = Vector(16, 16, 36),
	filter = ProbeFilter,
}
local landingTrace = {mask = MASK_PLAYERSOLID, filter = ProbeFilter}
-- Standing hull for the direct approach.
local directTrace = {
	mask = MASK_PLAYERSOLID,
	mins = Vector(-12, -12, 0),
	maxs = Vector(12, 12, 60),
	filter = ProbeFilter,
}
local groundTrace = {mask = MASK_PLAYERSOLID_BRUSHONLY}

-- The thing we intend to hit never counts as blocking - unless it is the obstacle itself.
local function SetProbeContext(self)
	probeSelf = self.Player
	local ignore = self.IgnoreEnt
	if ignore == self.Obstacle then ignore = nil end
	probeIgnore = ignore
end

-- What is in front of us above step height, within dist (+8 of hull) along (dx, dy)?
-- maxDrop: how far below us the landing may be (blind probes keep it short so a
-- balcony railing is not "a ledge").
function Loco:ProbeLedge(pos, dx, dy, dist, maxHeight, maxDrop)
	local P = self.P
	dist = dist or P.LedgeProbe
	maxHeight = maxHeight or P.JumpHeight
	maxDrop = maxDrop or (P.JumpHeight + 24)
	SetProbeContext(self)

	local ex, ey = pos.x + dx * dist, pos.y + dy * dist

	-- Stairs (and no-jump areas) are walked, whatever the geometry looks like.
	local here = navmesh_GetNavArea(pos, 32)
	if IsValid(here) and (here:HasAttributes(NAV_STAIRS) or here:HasAttributes(NAV_NO_JUMP)) then
		return LEDGE_CLEAR
	end
	local there = navmesh_GetNavArea(Vector(ex, ey, pos.z + maxHeight), maxHeight + 32)
	if IsValid(there) and there:HasAttributes(NAV_STAIRS) then
		return LEDGE_CLEAR
	end

	-- A hull lifted by the step height only hits what a step cannot take.
	local z = pos.z + P.StepHeight + 1
	ledgeTrace.start = Vector(pos.x, pos.y, z)
	ledgeTrace.endpos = Vector(ex, ey, z)
	local tr = util_TraceHull(ledgeTrace)
	if tr.StartSolid then return LEDGE_WALL end
	if not tr.Hit or tr.HitNormal.z > WALKABLE_Z then return LEDGE_CLEAR end

	-- How high is it? Look down just inside its face, from the highest top we could take.
	local topZ = pos.z + maxHeight + 1
	local hp = tr.HitPos
	local fx, fy = hp.x + dx * 12, hp.y + dy * 12
	landingTrace.start = Vector(fx, fy, topZ)
	landingTrace.endpos = Vector(fx, fy, pos.z - 8)
	local down = util_TraceLine(landingTrace)
	if down.StartSolid then return LEDGE_WALL end -- taller than we can jump
	local h = down.Hit and (down.HitPos.z - pos.z) or 0
	if h > maxHeight then return LEDGE_WALL end
	if h < P.StepHeight then h = maxHeight end -- too thin to look down on (railing, wire): assume the worst

	-- Something to land on beyond it (not a railing over a pit).
	landingTrace.start = Vector(ex, ey, topZ)
	landingTrace.endpos = Vector(ex, ey, pos.z - maxDrop)
	down = util_TraceLine(landingTrace)
	if down.StartSolid or not down.Hit then return LEDGE_WALL end

	-- Room to get over it: a crouched hull just above its top must sweep across.
	z = pos.z + h + 1
	ledgeTrace.start = Vector(pos.x, pos.y, z)
	ledgeTrace.endpos = Vector(ex, ey, z)
	tr = util_TraceHull(ledgeTrace)
	if tr.StartSolid or (tr.Hit and tr.HitNormal.z <= WALKABLE_Z) then return LEDGE_WALL end

	return LEDGE_JUMP
end

-- Does a crouched hull get through whatever is ahead?
function Loco:CanDuckThrough(pos, dx, dy)
	SetProbeContext(self)
	local dist = self.P.DuckProbe
	duckTrace.start = Vector(pos.x, pos.y, pos.z + 1)
	duckTrace.endpos = Vector(pos.x + dx * dist, pos.y + dy * dist, pos.z + 1)
	local tr = util_TraceHull(duckTrace)
	if tr.StartSolid then return false end
	return not tr.Hit or tr.HitNormal.z > WALKABLE_Z
end

---------------------------------------------------------------------------
-- Obstacles
---------------------------------------------------------------------------

local function IsMoveablePhysics(ent)
	return ent:IsRelapseMoveable()
end

local function IsPhysicsPropClass(class)
	return string.sub(class, 1, 12) == "prop_physics"
end

-- Things a zombie should punch through instead of pathing around forever.
-- Returns breakable, loose. Loose = unnailed physics: only if it sits on the
-- way to a human or a sigil, never as random clutter.
function Loco.IsBreakable(ent)
	if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return false end
	if ent.NoRelapseAIBreak or ent.IsCreeperNest then return false end

	local class = ent:GetClass()
	if class == "prop_obj_sigil" then
		return not ent:GetSigilCorrupted(), false
	end
	if ent.IsNailed and ent:IsNailed() then
		return true, false
	end
	-- Deployables (crate, lamp, aegis). Unnailed map physics is not a barricade
	-- just because TemporaryBarricadeObject flipped IsBarricadeObject.
	if ent.IsBarricadeObject and not IsPhysicsPropClass(class) then
		return true, false
	end
	if class == "func_breakable" or class == "func_breakable_surf"
	or class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating" then
		return true, false
	end
	if IsPhysicsPropClass(class) or class == "func_physbox" or class == "func_physbox_multiplayer" then
		return IsMoveablePhysics(ent), true
	end
	return false
end

-- Walk destination for "is this prop in the way": the ladder mount when the
-- human is upstairs, otherwise the path end / goal.
function Loco:ClearDest()
	if AI.Nav.HasLadder(self.ViaLadder) then
		return self:LadderMountPos(self.ViaLadder, self.ViaUp)
	end
	if self.PathValid and self.PathGoal then
		return self.PathGoal
	end
	return self.Goal
end

-- Unnailed junk beside the path or under a ledge is not worth a swing.
function Loco:LooseWorthBreaking(ent, hitPos, generous)
	if self.Obstacle == ent then return true end
	if not self.ClearPath then return false end
	local dest = self:ClearDest()
	if not dest then return false end

	local pos = self.Player:GetPos()
	local gx, gy = dest.x - pos.x, dest.y - pos.y
	local g2 = gx * gx + gy * gy
	if g2 < 48 * 48 then return false end
	-- Courtyard clutter under a rooftop player is not the way up.
	if math_abs(dest.z - pos.z) > 40 and not AI.Nav.HasLadder(self.ViaLadder) then
		return false
	end

	local hx, hy = hitPos.x - pos.x, hitPos.y - pos.y
	local glen = math_sqrt(g2)
	local along = (hx * gx + hy * gy) / glen
	if along < 10 then return false end
	local side = math_abs(hx * -gy + hy * gx) / glen
	local sideMax = generous and 88 or 52
	if side > sideMax then return false end
	return true
end

-- Something fixed that closes a passage (worth a path penalty), as opposed to a
-- loose prop or the sigil we are heading for anyway.
local function IsBarricade(ent, loose)
	return not loose and ent:GetClass() ~= "prop_obj_sigil"
end

-- Put a price on the barricade's area(s) so paths prefer a way around it.
function Loco:MarkObstacle(ent, now)
	local Nav = AI.Nav
	local P = self.P
	local penalty = Nav.Penalty.Barricade
	local ids = {}

	local a = Nav.MarkBlockedAt(self.ObstacleHit or ent:WorldSpaceCenter(), P.BarricadeMark, penalty)
	if a then ids[#ids + 1] = a:GetID() end
	local b = Nav.MarkBlockedAt(ent:WorldSpaceCenter(), P.BarricadeMark, penalty)
	if b and b ~= a then ids[#ids + 1] = b:GetID() end

	self.ObstacleAreas = ids
	self.NextMark = now + 10
end

-- Health pool our hits drain, if any (barricade pool for nailed props, entity health otherwise).
local function ObstacleHealth(ent)
	if ent.GetBarricadeHealth and ent.IsBarricadeProp and ent:IsBarricadeProp() then
		return ent:GetBarricadeHealth()
	end
	return ent:Health()
end

local function IsDoor(ent)
	local class = ent:GetClass()
	return class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating"
end

function Loco:GetObstacle()
	local ent = self.Obstacle
	if not ent then return nil end

	local now = CurTime()
	if not IsValid(ent) or not Loco.IsBreakable(ent) then
		self:ClearObstacle(true) -- gone: the way is open again
		return nil
	end

	if ent:GetPos():DistToSqr(self.ObstaclePos) > 48 * 48 then
		self:ClearObstacle(true) -- pushed or knocked away
		return nil
	end

	-- Wander / no chase: drop a loose prop we had started hitting.
	if self.ObstacleLoose and not self.ClearPath then
		self:ClearObstacle(true)
		return nil
	end

	-- Lost contact with it (detoured, pushed back, door swung open) or it is too far.
	local mypos = self.Player:GetPos()
	if now - self.ObstacleSeen > 1.5 or ent:NearestPoint(mypos):DistToSqr(mypos) > 160 * 160 then
		self:ClearObstacle(IsDoor(ent)) -- a barricade is still there for the mesh; a door may just be open
		return nil
	end

	-- Our hits are making a dent: the timeout counts from the last bit of progress.
	local hp = ObstacleHealth(ent)
	if hp and self.ObstacleHP and hp < self.ObstacleHP - 0.5 then
		self.ObstacleProgress = now
	end
	self.ObstacleHP = hp

	-- Hammered it for too long without result (locked door, elevator...): route around it for a while.
	if now - math_max(self.ObstacleSince, self.ObstacleProgress or 0) > self.P.ObstacleTimeout then
		local Nav = AI.Nav
		self.IgnoredObstacles[ent] = now + self.P.ObstacleIgnore
		Nav.MarkBlockedAt(mypos, 45, Nav.Penalty.Unbreakable)
		Nav.MarkBlockedAt(ent:WorldSpaceCenter(), 45, Nav.Penalty.Unbreakable)
		self:ClearObstacle(false)
		self.PathValid = false
		self.NextRepath = 0
		self:Note("giveup:" .. ent:GetClass())
		return nil
	end

	-- Still waiting to hear whether there is a way around it.
	if self.DetourUntil > now then return nil end

	if self.ObstacleAreas and now >= self.NextMark then
		self:MarkObstacle(ent, now)
	end
	return ent
end

-- hitPos: where our probe touched it (the face we would have to open).
function Loco:SetObstacle(ent, loose, hitPos)
	local now = CurTime()
	local ignore = self.IgnoredObstacles[ent]
	if ignore then
		if ignore > now then return false end
		self.IgnoredObstacles[ent] = nil
	end

	if self.Obstacle ~= ent then
		self.Obstacle = ent
		self.ObstaclePos = ent:GetPos()
		self.ObstacleHit = hitPos or ent:WorldSpaceCenter()
		self.ObstacleSince = now
		self.ObstacleProgress = nil
		self.ObstacleHP = nil
		self.ObstacleLoose = loose and true or false
		self.ObstacleAreas = nil
		self.DetourUntil = 0

		if IsBarricade(ent, loose) then
			local Nav = AI.Nav
			local known = Nav.BlockedSince(self.ObstacleHit, Nav.Penalty.Barricade)
			self:MarkObstacle(ent, now)
			-- Following a path that does not already pay for this barricade: see whether
			-- the penalty buys us a way around before swinging.
			if self.Mode == "path" and not self.Hold and not (known and self.PathTime > known) then
				self.DetourUntil = now + self.P.DetourWait
				self.NeedRepath = true
				self:Note("obstacle:" .. ent:GetClass())
			else
				self:Note("break:" .. ent:GetClass())
			end
		end
	end
	self.ObstacleSeen = now
	return true
end

-- The brain confirms the obstacle is still in our way (we are hitting it).
function Loco:TouchObstacle()
	self.ObstacleSeen = CurTime()
end

-- unmark: the passage is open again (destroyed/moved), lift the path penalty.
function Loco:ClearObstacle(unmark)
	if unmark and self.ObstacleAreas then
		for _, id in ipairs(self.ObstacleAreas) do
			AI.Nav.UnmarkArea(id)
		end
	end
	self.Obstacle = nil
	self.ObstacleAreas = nil
	self.ObstacleLoose = false
	self.DetourUntil = 0
end

local function ConsiderHit(self, tr, includeLoose, dist)
	if not tr.Hit or tr.HitWorld then return nil end
	local ent = tr.Entity
	if not IsValid(ent) then return nil end
	if tr.Fraction * dist > self.P.ObstacleAccept then return nil end

	local breakable, loose = Loco.IsBreakable(ent)
	if not breakable then return nil end
	if loose and not self:LooseWorthBreaking(ent, tr.HitPos, includeLoose) then return nil end
	if self:SetObstacle(ent, loose, tr.HitPos) then
		return ent
	end
	return nil
end

-- Look at what is in the way along the path. Crawl under it or hop over it when
-- possible; otherwise, if it is breakable, make it the obstacle and return it.
-- includeLoose: stuck — accept a slightly wider corridor for unnailed props.
function Loco:ProbeObstacle(pos, includeLoose)
	local dir = self.PathDir
	if dir.x == 0 and dir.y == 0 then dir = self.WishDir end
	local dx, dy = dir.x, dir.y
	if dx == 0 and dy == 0 then return nil end

	SetProbeContext(self)
	local dist = self.P.ProbeDist
	local ex, ey = pos.x + dx * dist, pos.y + dy * dist

	probeTrace.maxs.z = PROBE_BAND
	probeTrace.start = Vector(pos.x, pos.y, pos.z + 40)
	probeTrace.endpos = Vector(ex, ey, pos.z + 40)
	local chest = util_TraceHull(probeTrace)
	probeTrace.start = Vector(pos.x, pos.y, pos.z + 14)
	probeTrace.endpos = Vector(ex, ey, pos.z + 14)
	local knee = util_TraceHull(probeTrace)

	-- The thing we already decided to break: no second thoughts.
	local cur = self.Obstacle
	if cur and (chest.Entity == cur or knee.Entity == cur) then
		self.ObstacleSeen = CurTime()
		return cur
	end

	if not chest.Hit and not knee.Hit then
		-- Only the head would hit (low doorway, board across the top): crawl under.
		probeTrace.maxs.z = PROBE_HEAD
		probeTrace.start = Vector(pos.x, pos.y, pos.z + 66)
		probeTrace.endpos = Vector(ex, ey, pos.z + 66)
		if util_TraceHull(probeTrace).Hit and self:CanDuckThrough(pos, dx, dy) then
			self:Duck(0.5, "head")
		end
		return nil
	end

	if chest.Hit and not knee.Hit then
		-- Gap underneath: crawl through, whatever it is. Otherwise maybe over it (railing, crate).
		if self:CanDuckThrough(pos, dx, dy) then
			self:Duck(0.5, "under")
			return nil
		end
		if self:ProbeLedge(pos, dx, dy) == LEDGE_JUMP then
			self:Jump("over")
			return nil
		end
	elseif knee.Hit and not chest.Hit then
		-- Low thing: a step takes it, or a hop does, or it is a real obstacle.
		local kind = self:ProbeLedge(pos, dx, dy)
		if kind == LEDGE_CLEAR then
			return nil
		elseif kind == LEDGE_JUMP then
			self:Jump("low")
			return nil
		end
	else
		-- Both bands: a window sill, a waist-high wall or a low barricade in the open is still a hop.
		if self:ProbeLedge(pos, dx, dy) == LEDGE_JUMP then
			self:Jump("sill")
			return nil
		end
	end

	-- Neither under nor over: break it if we can.
	return ConsiderHit(self, chest, includeLoose, dist) or ConsiderHit(self, knee, includeLoose, dist)
end

---------------------------------------------------------------------------
-- Direct movement (short, clear hops without a path)
---------------------------------------------------------------------------

function Loco:IsDirectClear(pos, goal)
	probeSelf = self.Player
	probeIgnore = self.IgnoreEnt
	local lift = Vector(0, 0, 18)
	directTrace.start = pos + lift
	directTrace.endpos = goal + lift
	if util_TraceHull(directTrace).Hit then
		return false
	end

	-- Don't walk off a ledge on the way.
	local mid = (pos + goal) * 0.5
	groundTrace.start = mid + lift
	groundTrace.endpos = mid - Vector(0, 0, 80)
	return util_TraceLine(groundTrace).Hit
end

---------------------------------------------------------------------------
-- Stuck handling
---------------------------------------------------------------------------

function Loco:ResetProgress(pos)
	self.ProgressPos = pos or self.Player:GetPos()
	self.ProgressTime = CurTime()
end

local crowdTrace = {
	mask = MASK_PLAYERSOLID,
	mins = Vector(-14, -14, 0),
	maxs = Vector(14, 14, 60),
	filter = function(ent)
		return ent ~= probeSelf
	end,
}

-- Is a teammate (or any player) the thing we are pressing against?
function Loco:IsBlockedByPlayer(pos)
	probeSelf = self.Player
	local dir = self.WishDir
	crowdTrace.start = pos + Vector(0, 0, 4)
	crowdTrace.endpos = Vector(pos.x + dir.x * 40, pos.y + dir.y * 40, pos.z + 4)
	local tr = util_TraceHull(crowdTrace)
	return tr.Hit and IsValid(tr.Entity) and tr.Entity:IsPlayer()
end

function Loco:SideStepFor(duration, side)
	self.SideStep = side or (math.random(2) == 1 and 1 or -1)
	self.SideStepUntil = CurTime() + duration
end

function Loco:Escalate(pos)
	local now = CurTime()
	self.LastEscalation = now
	self.StuckLevel = self.StuckLevel + 1
	local level = self.StuckLevel

	-- A crowd, not geometry: shuffle sideways, never hop, never blame the mesh.
	if self:IsBlockedByPlayer(pos) then
		self:SideStepFor(0.6)
		self:Note("stuck:crowd")
		self.StuckLevel = 0
		return
	end

	local dir = self.PathDir
	if dir.x == 0 and dir.y == 0 then dir = self.WishDir end

	if level == 1 then
		local kind = self:ProbeLedge(pos, dir.x, dir.y)
		if kind == LEDGE_JUMP then
			self:Jump("stuck1:ledge")
		elseif self:ProbeObstacle(pos, true) then
			self:Note("stuck1:obstacle")
		elseif kind == LEDGE_WALL then
			self:SideStepFor(0.7) -- nothing to jump onto: slide along it
			self:Note("stuck1:wall")
		else
			self:Jump("stuck1:snag") -- snagged on something small
		end
	elseif level == 2 then
		self:ProbeObstacle(pos, true)
		self:SideStepFor(0.7)
		self:Jump("stuck2")
		self:Note("stuck2")
	elseif level == 3 then
		local Nav = AI.Nav
		Nav.MarkBlockedAt(pos, 20, Nav.Penalty.Stuck)
		Nav.MarkBlockedAt(pos + dir * 48, 20, Nav.Penalty.Stuck)
		self.PathValid = false
		self.NextRepath = 0
		self:SideStepFor(0.9, -self.SideStep)
		self:Note("stuck3:mark")
	else
		self.StuckLevel = 0
		self.StuckEpisodes = self.StuckEpisodes + 1
		self:SideStepFor(1.2)
		self:Jump("stuck4")
		self:Note("stuck4")
	end
end

---------------------------------------------------------------------------
-- Ladders
--
-- Phases: approach (walk to the mount point) -> mount (press into the rungs
-- until the engine attaches us) -> climb (forward with the head tilted does
-- the rest; the engine climbs on IN_FORWARD, not on the move value) ->
-- dismount (keep pushing over the lip at the top, step back off at the bottom).
-- Down: walk off the ledge facing the drop, reach back for the rungs while
-- falling, turn to face them, descend.
---------------------------------------------------------------------------

local function YawOf(x, y)
	return math_deg(math_atan2(y, x))
end

-- GMod leaves PathSegment.type 4/5 unused. A ladder shows up as seg.ladder
-- and/or how = GO_LADDER_UP/DOWN (same numbers as the segment types).
local function IsLadderSeg(seg)
	if not seg then return false end
	if AI.Nav.HasLadder(seg.ladder) then return true end
	local t, h = seg.type, seg.how
	return t == SEG_LADDER_UP or t == SEG_LADDER_DOWN or h == SEG_LADDER_UP or h == SEG_LADDER_DOWN
end

function Loco:LadderSegIsUp(seg, ladder)
	if seg.type == SEG_LADDER_UP or seg.how == SEG_LADDER_UP then return true end
	if seg.type == SEG_LADDER_DOWN or seg.how == SEG_LADDER_DOWN then return false end
	local goal = self.Goal
	local b, t = ladder:GetBottom(), ladder:GetTop()
	if goal then
		return math_abs(goal.z - t.z) < math_abs(goal.z - b.z)
	end
	return self.Player:GetPos().z < (b.z + t.z) * 0.5
end

function Loco:LadderMountPos(ladder, up)
	local n = AI.Nav.LadderNormal(ladder)
	local P = self.P
	local v = self.ViaMount
	if not v then
		v = Vector(0, 0, 0)
		self.ViaMount = v
	end
	if up then
		local b = ladder:GetBottom()
		v.x = b.x + n.x * P.LadderMount
		v.y = b.y + n.y * P.LadderMount
		v.z = b.z
	else
		local t = ladder:GetTop()
		v.x = t.x - n.x * 20
		v.y = t.y - n.y * 20
		v.z = t.z
	end
	return v
end

-- Goal on another floor: walk to the ladder that leads there, not to the
-- unreachable XY under the player (A* 's closest area).
function Loco:DestForGoal(pos, goal)
	if math_abs(goal.z - pos.z) < 40 then
		self.ViaLadder = nil
		self.ViaUp = nil
		return goal
	end
	local ladder, up = AI.Nav.FindLadderForGoal(pos, goal)
	if not AI.Nav.HasLadder(ladder) then
		self.ViaLadder = nil
		self.ViaUp = nil
		return goal
	end
	self.ViaLadder = ladder
	self.ViaUp = up
	local mount = self:LadderMountPos(ladder, up)
	local snap = AI.Nav.SnapToMesh(mount, 80)
	if snap then
		local sx, sy = snap.x - mount.x, snap.y - mount.y
		if sx * sx + sy * sy <= 72 * 72 then
			-- A snap under the player (closer to goal XY than the rungs) is the bug.
			local gx, gy = snap.x - goal.x, snap.y - goal.y
			local mx, my = mount.x - goal.x, mount.y - goal.y
			if gx * gx + gy * gy + 80 * 80 >= mx * mx + my * my then
				return snap
			end
		end
	end
	return mount
end

function Loco:BeginLadder(seg, up)
	if self.Ladder then return false end
	local ladder = seg.ladder
	if not AI.Nav.HasLadder(ladder) then return false end
	local now = CurTime()
	local done = self.LadderDone
	if done and done.Ent == ladder and done.Until > now
	and self.Player:GetMoveType() ~= MOVETYPE_LADDER then
		return false
	end

	if up == nil then
		up = self:LadderSegIsUp(seg, ladder)
	end
	local n = AI.Nav.LadderNormal(ladder)
	local bottom, top = ladder:GetBottom(), ladder:GetTop()
	local P = self.P

	local mount
	if up then
		mount = Vector(bottom.x + n.x * P.LadderMount, bottom.y + n.y * P.LadderMount, bottom.z)
	else
		-- On the ledge just behind the top edge, facing the drop.
		mount = Vector(top.x - n.x * 20, top.y - n.y * 20, top.z)
	end

	self.Ladder = {
		Ent = ladder,
		Up = up,
		Normal = n,
		Bottom = bottom,
		Top = top,
		HalfWidth = ladder:GetWidth() * 0.5,
		Mount = mount,
		Phase = "approach",
		Since = now,
		PhaseSince = now,
		Retries = 0,
		Hopped = false,
		BestZ = nil,
		BestZTime = now,
	}
	self.SideStepUntil = 0
	self.WishDir:Zero()
	self:Note(up and "ladder:up" or "ladder:down")
	return true
end

function Loco:SetLadderPhase(phase)
	local L = self.Ladder
	L.Phase = phase
	L.PhaseSince = CurTime()
	L.BestZ = nil
	self:Note("ladder:" .. phase)
end

function Loco:EndLadder(reason)
	local L = self.Ladder
	if not L then return end
	self.Ladder = nil
	self.LadderDone = {Ent = L.Ent, Until = CurTime() + 3}
	self.Bot.View:ClearOverride()
	self:ResetProgress()
	self.StuckLevel = 0
	self:Note("ladder:" .. reason)
end

-- Could not use it: let go, keep paths off it for a while and find another way.
function Loco:AbortLadder(reason)
	local L = self.Ladder
	if not L then return end
	AI.Nav.BanLadder(L.Ent, self.P.LadderBan)
	if self.Player:GetMoveType() == MOVETYPE_LADDER then
		self.JumpUntil = CurTime() + 0.06 -- IN_JUMP lets go of the rungs
	end
	self:EndLadder("abort:" .. reason)
	self.PathValid = false
	self.NextRepath = 0
end

-- Point the head along (fx, fy) tilted by pitch degrees (negative = up).
local ladderLook = Vector(0, 0, 0)
function Loco:LadderLook(fx, fy, pitch)
	local eye = self.Player:EyePos()
	local r = math_rad(pitch)
	local flat = 100 * math_cos(r)
	ladderLook.x = eye.x + fx * flat
	ladderLook.y = eye.y + fy * flat
	ladderLook.z = eye.z - 100 * math_sin(r)
	self.Bot.View:SetOverride(ladderLook)
end

-- Are we standing in front of the rungs, close enough to press into them?
local function AtLadderBase(L, pos)
	local base = L.Up and L.Bottom or L.Top
	local n = L.Normal
	local rx, ry = pos.x - base.x, pos.y - base.y
	local front = rx * n.x + ry * n.y
	local side = math_abs(rx * -n.y + ry * n.x)
	if L.Up then
		return front >= -6 and front <= 30 and side <= L.HalfWidth + 8
	end
	return front >= -28 and front <= 8 and side <= L.HalfWidth + 8 and math_abs(pos.z - L.Top.z) < 40
end

-- Height bookkeeping for stall detection: when did we last gain in the right direction.
local function LadderProgress(L, z, now)
	if not L.BestZ or (L.Up and z > L.BestZ + 1) or (not L.Up and z < L.BestZ - 1) then
		L.BestZ = z
		L.BestZTime = now
	end
end

-- Brain-rate part: the head and the timeouts. StepLadder does the moves.
function Loco:ThinkLadder(now)
	local L = self.Ladder
	if not AI.Nav.HasLadder(L.Ent) then
		self:EndLadder("gone")
		return
	end

	local P = self.P
	local pl = self.Player
	local n = L.Normal
	local phase = L.Phase
	local onLadder = pl:GetMoveType() == MOVETYPE_LADDER
	local pos = pl:GetPos()

	if phase == "approach" and pos:DistToSqr(L.Mount) > 96 * 96 then
		self.Bot.View:ClearOverride() -- far away: the brain's own look is fine
	elseif not L.Up and not onLadder and phase ~= "dismount" then
		self:LadderLook(n.x, n.y, P.LadderPitchDown * 0.8) -- facing the drop we are about to step into
	elseif L.Up and phase == "dismount" then
		self:LadderLook(-n.x, -n.y, -10)
	else
		self:LadderLook(-n.x, -n.y, L.Up and P.LadderPitchUp or P.LadderPitchDown)
	end

	local inPhase = now - L.PhaseSince
	if phase == "approach" then
		if inPhase > P.LadderApproachTime then self:AbortLadder("approach") end
	elseif phase == "mount" then
		if inPhase > P.LadderMountTime then
			if L.Retries < P.LadderRetries then
				L.Retries = L.Retries + 1
				-- A lip at the foot of the rungs: a hop while pressing on sometimes catches them.
				if L.Up and not L.Hopped then
					L.Hopped = true
					self:Jump("ladder:hop")
				end
				self:SetLadderPhase("approach")
			else
				self:AbortLadder("mount")
			end
		end
	elseif phase == "climb" then
		if onLadder and L.BestZ and now - L.BestZTime > P.LadderStallTime then
			if not L.Up and pos.z < L.Bottom.z + 60 then
				self:SetLadderPhase("dismount") -- the floor is higher than the rungs end
			else
				self:AbortLadder("stall")
			end
		end
	elseif phase == "dismount" then
		if inPhase > P.LadderDismountTime then self:AbortLadder("dismount") end
	end
end

-- Every tick while a ladder is in progress. Returns the buttons.
function Loco:StepLadder(cmd, viewYaw, buttons, now)
	local L = self.Ladder
	local pl = self.Player
	local P = self.P
	local pos = pl:GetPos()
	local n = L.Normal
	local onLadder = pl:GetMoveType() == MOVETYPE_LADDER
	local onGround = pl:IsOnGround()
	local phase = L.Phase

	local wx, wy = 0, 0
	local rungs = false -- pressing while attached: only with the yaw lined up

	if phase == "approach" then
		if onLadder then
			self:SetLadderPhase("climb")
		elseif AtLadderBase(L, pos) then
			self:SetLadderPhase("mount")
		else
			local dx, dy = L.Mount.x - pos.x, L.Mount.y - pos.y
			local d = math_sqrt(dx * dx + dy * dy)
			if d > 1 then wx, wy = dx / d, dy / d end
		end
	elseif phase == "mount" then
		if onLadder then
			self:SetLadderPhase("climb")
		elseif L.Up then
			wx, wy = -n.x, -n.y
		elseif onGround and pos.z > L.Top.z - 30 then
			wx, wy = n.x, n.y -- walk off the ledge
		elseif onGround then
			self:EndLadder("fell") -- landed below without catching the rungs; the path goes on from here
		else
			wx, wy = -n.x, -n.y -- falling past the rungs: reach back for them
		end
	elseif phase == "climb" then
		if onLadder then
			rungs = true
			wx, wy = -n.x, -n.y
			LadderProgress(L, pos.z, now)
			if L.Up then
				if pos.z >= L.Top.z - 2 then self:SetLadderPhase("dismount") end
			elseif pos.z <= L.Bottom.z + 4 then
				self:SetLadderPhase("dismount")
			end
		elseif L.Up then
			if pos.z >= L.Top.z - 24 then
				self:SetLadderPhase("dismount")
			elseif onGround then
				-- Slid off near the foot: line up again.
				if L.Retries < P.LadderRetries then
					L.Retries = L.Retries + 1
					self:SetLadderPhase("approach")
				else
					self:AbortLadder("fell")
				end
			end
		elseif onGround then
			self:EndLadder("bottom")
		end
	elseif phase == "dismount" then
		if L.Up then
			-- Over the lip: while attached this climbs on, once free it walks onto the ledge.
			wx, wy = -n.x, -n.y
			rungs = onLadder
			if not onLadder and onGround and pos.z >= L.Top.z - 24 then
				self:EndLadder("top")
			end
		else
			-- Step back off the rungs onto the floor; a hop if they will not let go.
			wx, wy = n.x, n.y
			rungs = onLadder
			if not onLadder then
				self:EndLadder("bottom")
			elseif now - L.PhaseSince > 1 then
				self.JumpUntil = now + 0.06
				self:EndLadder("bottom:hop")
			end
		end
	end

	if rungs and (wx ~= 0 or wy ~= 0) then
		local faceYaw = YawOf(-n.x, -n.y)
		if math_abs(math_AngleDifference(viewYaw, faceYaw)) > P.LadderFaceTolerance then
			wx, wy = 0, 0 -- hang on until the head is on the rungs
		end
	end

	local wish = self.WishDir
	wish.x, wish.y = wx, wy
	if wx == 0 and wy == 0 then
		return buttons
	end

	local yaw = math_rad(viewYaw)
	local fwd = wx * math_cos(yaw) + wy * math_sin(yaw)
	local side = wx * math_sin(yaw) - wy * math_cos(yaw)
	if onLadder then side = 0 end -- a sideways press slides us off the rungs
	return self:ApplyMove(cmd, buttons, fwd, side)
end

-- Caught on a ladder we did not mean to climb (brushed past its foot).
-- If the path wants it, or the climb closes the Z gap to the goal, take it;
-- otherwise let go. Never jump off a useful ladder just because A* picked another.
function Loco:HandleUnplannedLadder(pos, now)
	local segs = self.Segments
	if segs then
		for j = self.SegIndex, math_min(self.SegIndex + 6, #segs) do
			local seg = segs[j]
			if IsLadderSeg(seg) and AI.Nav.HasLadder(seg.ladder) then
				local b = seg.ladder:GetBottom()
				local dx, dy = b.x - pos.x, b.y - pos.y
				if dx * dx + dy * dy < 96 * 96 and self:BeginLadder(seg) then
					self:SetLadderPhase("climb")
					return
				end
			end
		end
	end

	local goal = self.Goal
	if goal then
		local helps = math_abs(goal.z - pos.z) > 24
		if helps then
			local ladder, up = AI.Nav.NearestUsefulLadder(pos, goal, 96)
			if not ladder then
				-- Already on the rungs: ignore the ban and take whatever we are on.
				for _, l in ipairs((AI.Nav.Climbables and #AI.Nav.Climbables > 0) and AI.Nav.Climbables or AI.Nav.GetAllLadders()) do
					if AI.Nav.HasLadder(l) then
						local b = l:GetBottom()
						local dx, dy = b.x - pos.x, b.y - pos.y
						if dx * dx + dy * dy < 96 * 96 then
							ladder = l
							up = goal.z > (l:GetBottom().z + l:GetTop().z) * 0.5
							break
						end
					end
				end
			end
			if ladder then
				local fakeType = up and SEG_LADDER_UP or SEG_LADDER_DOWN
				if self:BeginLadder({ladder = ladder, type = fakeType, how = fakeType}, up) then
					self:SetLadderPhase("climb")
					return
				end
			end
		end
	end

	self.JumpUntil = now + 0.06
	self:Note("ladder:off")
end

-- Goal is on another floor: climb if we are at the rungs, otherwise DestForGoal
-- is already sending us to the mount.
function Loco:ConsiderNearbyLadder(pos)
	if self.Ladder or not self.Goal then return end
	if math_abs(self.Goal.z - pos.z) < 40 then return end
	local ladder, up = self.ViaLadder, self.ViaUp
	if not AI.Nav.HasLadder(ladder) then
		ladder, up = AI.Nav.FindLadderForGoal(pos, self.Goal)
	end
	if not AI.Nav.HasLadder(ladder) then return end
	local mount = self:LadderMountPos(ladder, up)
	local dx, dy = mount.x - pos.x, mount.y - pos.y
	local reach = 160
	if self.PathReached and self.ViaLadder == ladder then reach = 220 end
	if dx * dx + dy * dy > reach * reach or math_abs(pos.z - mount.z) >= 96 then return end
	local fakeType = up and SEG_LADDER_UP or SEG_LADDER_DOWN
	self:BeginLadder({ladder = ladder, type = fakeType, how = fakeType}, up)
end

---------------------------------------------------------------------------
-- Think (brain rate) and Step (every tick)
---------------------------------------------------------------------------

-- Move values plus the matching buttons: ladders climb on IN_FORWARD, not on the value.
function Loco:ApplyMove(cmd, buttons, fwd, side)
	local pl = self.Player
	local speed
	if self.SpeedFrac >= 0.999 then
		speed = 10000
	else
		speed = pl:GetMaxSpeed() * self.SpeedFrac
		if speed <= 0 then speed = 10000 end
	end

	cmd:SetForwardMove(fwd * speed)
	cmd:SetSideMove(side * speed)

	if fwd > 0.05 then
		buttons = bit_bor(buttons, IN_FORWARD)
	elseif fwd < -0.05 then
		buttons = bit_bor(buttons, IN_BACK)
	end
	if side > 0.05 then
		buttons = bit_bor(buttons, IN_MOVERIGHT)
	elseif side < -0.05 then
		buttons = bit_bor(buttons, IN_MOVELEFT)
	end
	return buttons
end

-- Path segments that need a jump or a ladder: only when the geometry agrees.
function Loco:CheckSegments(pos)
	local segs = self.Segments
	if not segs then return end

	local cursor = self.Cursor
	local i = self.SegIndex
	local n = #segs
	while i < n and segs[i + 1].distanceFromStart <= cursor do
		i = i + 1
	end
	self.SegIndex = i

	local P = self.P
	for j = i, math_min(i + 5, n) do
		local seg = segs[j]
		local ahead = seg.distanceFromStart - cursor
		if IsLadderSeg(seg) then
			local ladder = seg.ladder
			if AI.Nav.HasLadder(ladder) then
				local up = self:LadderSegIsUp(seg, ladder)
				local mount = up and ladder:GetBottom() or ladder:GetTop()
				local dx, dy = mount.x - pos.x, mount.y - pos.y
				-- Segment pos is often the FAR end of the climb, so "ahead" is the
				-- ladder's length. Start when we are at the rungs, not when the
				-- cursor has already travelled that length.
				local flat = dx * dx + dy * dy
				local near = flat <= 88 * 88 and math_abs(pos.z - mount.z) < 72
				if near or (ahead <= 72 and flat <= 160 * 160) then
					local belowTop = pos.z < ladder:GetTop().z - 40
					if (up and belowTop) or (not up and not belowTop) then
						self:BeginLadder(seg, up)
					end
				end
			end
			return
		elseif seg.type == SEG_CLIMB then
			if ahead > 28 then return end
			-- seg.pos is the launch point at the bottom, the next segment sits on top.
			local top = segs[j + 1]
			local landing = top and top.pos or seg.pos
			local rise = landing.z - pos.z
			if ahead >= -(seg.length + 8) and rise > P.StepHeight + 2 and rise <= P.JumpHeight + 12
			and not (top and IsValid(top.area) and top.area:HasAttributes(NAV_STAIRS)) then
				-- The path vouches for a ledge here, so look a little further than the blind probes do
				-- and accept whatever drop the path accepted.
				local dx, dy = landing.x - pos.x, landing.y - pos.y
				local l = math_sqrt(dx * dx + dy * dy)
				if l > 1 and self:ProbeLedge(pos, dx / l, dy / l, 32, nil, AI.cv.max_drop:GetFloat()) == LEDGE_JUMP then
					self:Jump("climb")
				end
				return
			end
		elseif seg.type == SEG_GAP then
			if ahead <= 12 and ahead >= -8 then
				self:Jump("gap")
				return
			end
		end
	end
end

function Loco:Think(dt)
	local pl = self.Player
	local now = CurTime()
	local P = self.P

	if self.Ladder then
		self:ThinkLadder(now)
		if self.Ladder then return end
	end
	if pl:GetMoveType() == MOVETYPE_LADDER then
		self:HandleUnplannedLadder(pl:GetPos(), now)
		return
	end

	if self.Mode == "stop" or not self.Goal then
		self.StuckLevel = 0
		return
	end

	local pos = pl:GetPos()
	local goal = self.Goal

	if self.GoalEnt then
		if IsValid(self.GoalEnt) then
			goal:Set(self.GoalEnt:GetPos())
		else
			self:Stop()
			return
		end
	end

	local dest = self:DestForGoal(pos, goal)

	-- Direct hop when the goal is close, on this floor, and the way is clear.
	-- A ladder shaft looks "clear" vertically, so Z must stay a same-floor check.
	local dx, dy = goal.x - pos.x, goal.y - pos.y
	local flat2 = dx * dx + dy * dy
	if not self.ViaLadder and flat2 < P.DirectDist * P.DirectDist and math_abs(goal.z - pos.z) < 28 and self:IsDirectClear(pos, goal) then
		self.Mode = "direct"
	elseif self.Mode == "direct" then
		self.Mode = "path"
		self.NextRepath = 0
	end

	-- Keep the path fresh.
	if self.Mode == "path" then
		local need = false
		if not self.PathValid then
			need = true
		elseif self.PathGoal:DistToSqr(dest) > P.GoalMoveRepath * P.GoalMoveRepath then
			need = true
			self.PathValid = false -- drop a stale path that ended under the player
		elseif now - self.PathTime > (self.GoalEnt and P.RepathMoving or P.RepathStatic) then
			need = true
		elseif self.OffPath then
			need = true
		end

		if self.NeedRepath then
			-- Explicit request (detour check): no interval gating. A pending compute already sees the new marks.
			self.NeedRepath = false
			need = true
			self.NextRepath = now
		end

		if need and not self.PathPending and now >= self.NextRepath then
			self.PathPending = true
			self.NextRepath = now + P.RepathMinInterval * (1 + math_min(self.FailedPaths, 6))
			AI.Nav.Request(self.Bot, dest, {Tolerance = self.GoalTol, Profile = self.Bot.Brain.NavProfile})
			if self.ViaLadder then self:Note("ladder:via") end
		end
	end

	-- Standing at the end of a path that stops short of the goal: IsHopeless counts from here.
	if self.Exhausted and not self.ExhaustedSince then
		self.ExhaustedSince = now
	end

	-- Nav attributes: crouch here and ahead, jump only where a ledge really is.
	local wish = self.WishDir
	local moving = wish.x ~= 0 or wish.y ~= 0
	local area = navmesh_GetNavArea(pos, 32)
	if IsValid(area) then
		if area:HasAttributes(NAV_MESH_CROUCH) then
			self:Duck(0.3, "navattr")
		end
		if moving and area:HasAttributes(NAV_MESH_JUMP) and self:ProbeLedge(pos, wish.x, wish.y) == LEDGE_JUMP then
			self:Jump("navattr")
		end
	end
	if moving then
		-- Duck before the low passage, not after bumping the head on it.
		local ahead = navmesh_GetNavArea(Vector(pos.x + wish.x * 40, pos.y + wish.y * 40, pos.z + 18), 64)
		if IsValid(ahead) and ahead ~= area and ahead:HasAttributes(NAV_MESH_CROUCH) then
			self:Duck(0.3, "navahead")
		end
	end

	self:ConsiderNearbyLadder(pos)
	if self.Ladder then return end
	if self.Mode == "path" then
		self:CheckSegments(pos)
		if self.Ladder then return end
	end

	-- Stuck detection only while we actually try to move.
	if (self.Hold and not AI.Nav.HasLadder(self.ViaLadder)) or self:IsGoalReached() or not moving then
		self:ResetProgress(pos)
		return
	end

	-- Deal with what is in the way before we bump into it.
	self:ProbeObstacle(pos)

	if pos:DistToSqr(self.ProgressPos) > P.ProgressDist * P.ProgressDist then
		self.ProgressPos = pos
		self.ProgressTime = now
		if self.StuckLevel > 0 and now - self.LastEscalation > 2.5 then
			self.StuckLevel = 0
		end
		return
	end

	local inReach = self.Bot.Combat and self.Bot.Combat.InReach
	if inReach then
		self.ProgressTime = now
		return
	end

	if now - self.ProgressTime > P.StuckTime then
		self.ProgressTime = now
		self:Escalate(pos)
	end
end

function Loco:Step(cmd, viewYaw, dt)
	local now = CurTime()
	local buttons = 0

	if now < self.JumpUntil then
		buttons = bit_bor(buttons, IN_JUMP)
	end
	if now >= self.DuckFrom and now < self.DuckUntil then
		buttons = bit_bor(buttons, IN_DUCK)
	end

	if self.Ladder then
		return self:StepLadder(cmd, viewYaw, buttons, now)
	end

	local pl = self.Player
	local goal = self.Goal
	if self.Mode == "stop" or not goal then
		self.WishDir:Zero()
		return buttons
	end
	if self.Hold and not AI.Nav.HasLadder(self.ViaLadder) then
		self.WishDir:Zero()
		return buttons
	end

	local pos = pl:GetPos()
	local target

	if self.Mode == "direct" then
		target = goal
		self.SteerPos = goal
		self.LookPos = nil
	elseif self.PathValid and self.Path then
		local path = self.Path
		local P = self.P

		path:MoveCursorToClosestPosition(pos, SEEK_AHEAD)
		local cursor = path:GetCursorPosition()
		local cpos = path:GetCursorData().pos
		if cpos:DistToSqr(pos) > P.OffPathDist * P.OffPathDist then
			path:MoveCursorToClosestPosition(pos, SEEK_ENTIRE_PATH)
			cursor = path:GetCursorPosition()
			cpos = path:GetCursorData().pos
			self.OffPath = cpos:DistToSqr(pos) > P.OffPathDist * P.OffPathDist
		else
			self.OffPath = false
		end
		self.Cursor = cursor

		local speed = pl:GetVelocity():Length2D()
		local look = speed * P.LookAheadSpeedMul
		if look < P.LookAheadMin then look = P.LookAheadMin elseif look > P.LookAheadMax then look = P.LookAheadMax end

		local length = self.PathLength
		if cursor + look >= length then
			target = path:GetEnd()
			if cursor >= length - 4 and target:DistToSqr(pos) < 1600 and not self.PathReached then
				self.Exhausted = true
			end
		else
			target = path:GetPositionOnPath(cursor + look)
		end

		self.LookPos = path:GetPositionOnPath(math_min(cursor + look + 140, length))
	else
		-- No path yet.
		self.WishDir:Zero()
		return buttons
	end

	-- Pure path direction (before lane offset and sidesteps): what the probes look along.
	local pdx, pdy = target.x - pos.x, target.y - pos.y
	local plen = math_sqrt(pdx * pdx + pdy * pdy)
	if plen > 1 then
		self.PathDir.x, self.PathDir.y = pdx / plen, pdy / plen
	end

	-- Lane offset perpendicular to the direction of travel.
	local lane = self.LaneOffset
	if lane ~= 0 and self.Mode ~= "direct" and plen > 1 then
		local k = lane * math_min(1, plen / 64) / plen
		target = Vector(target.x - pdy * k, target.y + pdx * k, target.z)
	end
	self.SteerPos = target

	-- Close enough: stand. Same-floor only, or we freeze under a ledge.
	local gdx, gdy = goal.x - pos.x, goal.y - pos.y
	if gdx * gdx + gdy * gdy <= self.GoalTol * self.GoalTol and math_abs(goal.z - pos.z) < 40 then
		self.WishDir:Zero()
		return buttons
	end

	local wx, wy = target.x - pos.x, target.y - pos.y
	local len = math_sqrt(wx * wx + wy * wy)
	if len < 8 and math_abs(target.z - pos.z) > 24 then
		-- Path continues above/below us. Keep pressing the last path direction
		-- into the rungs until Think starts the climb.
		local dir = self.PathDir
		if dir.x ~= 0 or dir.y ~= 0 then
			wx, wy, len = dir.x, dir.y, 1
		end
	end
	if len < 1 then
		self.WishDir:Zero()
		return buttons
	end
	wx, wy = wx / len, wy / len

	if now < self.SideStepUntil then
		local s = self.SideStep
		wx, wy = -wy * s, wx * s
	end

	local wish = self.WishDir
	wish.x, wish.y = wx, wy

	local yaw = math_rad(viewYaw)
	local fwd = wx * math_cos(yaw) + wy * math_sin(yaw)
	local side = wx * math_sin(yaw) - wy * math_cos(yaw)
	return self:ApplyMove(cmd, buttons, fwd, side)
end
