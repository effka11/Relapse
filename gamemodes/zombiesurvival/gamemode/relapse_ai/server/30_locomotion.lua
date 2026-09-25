-- Relapse AI locomotion.
--
-- One job: turn "go there" into buttons. The brain sets a goal; Nav answers with
-- a path (Relapse mesh cell centres, Source PathFollower as fallback); this file
-- walks it. Everything here is deliberately small and layered so a change in one
-- layer cannot leak into another:
--
--   cursor      closest point on the polyline, in a window around the last cursor
--   lookahead   the furthest path point ahead a body hull can see (no corner cuts)
--   slide       wish is projected off any wall the body would push into
--   specials    DROP walks off the lip, CLIMB/GAP jump at the launch, LADDER is a
--               four-phase state machine over the Relapse ladder (E, W/S, E)
--
-- Think only calls these. A new condition belongs in the layer function, not
-- in a new branch of Think.
--   obstacles   breakables in the way: E on an unlocked door from outside the
--               swing, and they stay there until the leaf has stopped (walking
--               in while it still moves shoves the body off the hole); a locked
--               door is claws; a nailed prop is clawed at once; anything else
--               first asks the mesh for a detour (DetourWait), then claws
--   stuck       no progress for StuckTime -> escalate: hop, sidestep, mark, episode
--
-- Every decision that is not steering writes a Note. The recorder turns some of
-- them into bug files (see relapse-ai-rec rule). Note vocabulary is the contract:
--   jump:<over|low|sill|ledge|rail|prop:off>  duck:<why>
--   stuck:crowd stuck1:<ledge|obstacle|wall|snag> stuck2 stuck3:mark stuck4
--   stuck:climb stuck:gap             (four hops from one launch, cells marked)
--   path:fail detour break:<class> break:noway
--   door:use door:clear door:locked   obstacle:<class> prop:<class>
--   prop:around prop:past giveup:<class>
--   ladder:approach ladder:mount ladder:climb ladder:leave ladder:done
--   ladder:abort:<approach|mount|stall|fell|leave|unplanned>
--   suicide    hopeless, this floor has no living human and no living sigil
-- solid is a recorder bug, not a note: the hull started inside a solid a player
-- body does not pass. IgnoreTraces, passable groups and ShouldNotCollide(player)
-- are not that (the sigil prop blocker).

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
local bit_bor = bit.bor
local util_TraceHull = util.TraceHull
local util_TraceLine = util.TraceLine

local SEG_GROUND = 0
local SEG_DROP = 1
local SEG_CLIMB = 2
local SEG_GAP = 3
local SEG_LADDER_UP = 4
local SEG_LADDER_DOWN = 5

local WALKABLE_Z = 0.7 -- a surface normal above this is floor, not wall

local LEDGE_CLEAR = "clear"
local LEDGE_JUMP = "ledge"
local LEDGE_WALL = "wall"

-- Seated on a Relapse ladder (relapse_ladder.lua owns the flag).
local function Holding(pl)
	return pl.RelapseLadderHold or pl:GetNW2Bool("RelapseLadderHold", false)
end

Loco.Defaults = {
	Tolerance = 32,
	LookAheadMin = 40,
	LookAheadMax = 160,
	LookAheadSpeedMul = 0.5,
	RepathMoving = 2.5, -- seconds, goal is an entity
	RepathStatic = 8,
	RepathMinInterval = 0.5,
	OffPathDist = 110,
	GoalMoveRepath = 64,
	DirectDist = 200,
	StuckTime = 0.9,
	ProgressDist = 20,
	StuckTaxRadius = 28, -- stuck3: mesh edges whose chord passes this close to the body get the Stuck price
	StuckTaxTime = 30, -- seconds that edge price lasts
	StepHeight = 18,
	JumpHeight = 68, -- 64u crate + duck-jump (185 jump power, 600 gravity)
	SlideProbe = 22, -- body sweep along the wish; a wall inside it bends the wish
	SlideHold = 0.8, -- seconds a head-on slide keeps its side before re-choosing
	ProbeDist = 56,
	ObstacleAccept = 40, -- a breakable further than this from our centre is not "in the way" yet
	ExhaustedAccept = 64, -- standing at a path end that fell short: a breakable this far toward the goal is the way
	DuckProbe = 96,
	ObstacleTimeout = 25, -- seconds hammering without a dent before we route around it
	ObstacleIgnore = 8,
	DetourWait = 1.5, -- seconds to wait for a path around a barricade before swinging at it
	BarricadeMark = 40, -- seconds a barricade keeps its path penalty (refreshed while we hit it)
	ExhaustedGiveUp = 2, -- seconds standing at the end of a path that does not reach the goal
	DoorUseInterval = 1.5,
	DoorUseDist = 84,
	LadderNear = 72, -- start the ladder SM this far (2D) from the foot cell
	LadderApproachTime = 6,
	LadderMountTries = 3,
	LadderStallTime = 2, -- on the rungs without gaining height
	LadderLeaveTime = 3,
	LadderBan = 12, -- seconds paths avoid a ladder we failed on
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
	self.IgnoreEnt = nil
	self.SpeedFrac = 1
	self.ClearPath = false -- hunt/search/sigil: unnailed props on the way may be broken

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
	self.CursorFloor = nil -- after a ladder: the cursor may not rewind below this
	self.OffPath = false
	self.Exhausted = false
	self.ExhaustedSince = nil
	self.LastPathEnd = nil
	self.IslandCut = false
	self.LookDist = self.P.LookAheadMin
	self.NextLook = 0

	self.Ladder = nil -- see BeginLadder

	self.SteerPos = nil
	self.LookPos = nil
	self.WalkDest = nil
	self.WishDir = Vector(0, 0, 0) -- what we actually press (after slide / sidestep)
	self.PathDir = Vector(0, 0, 0) -- pure direction to the steer target; probes look along it

	self.JumpUntil = 0
	self.NextJump = 0
	self.DuckFrom = 0
	self.DuckUntil = 0
	self.UseUntil = 0
	self.SideStep = 1
	self.SideStepUntil = 0
	self.SlideSide = 0 -- head-on slide: tangent side kept until SlideUntil
	self.SlideUntil = 0
	self.NextLedgeProbe = 0
	self.CrowdSide = (pl:EntIndex() % 2 == 0) and 1 or -1
	self.HopKey = nil -- distanceFromStart of the launch we keep hopping at
	self.HopTries = 0

	self.ProgressPos = pl:GetPos()
	self.ProgressTime = CurTime()
	self.StuckLevel = 0
	self.LastEscalation = 0
	self.StuckEpisodes = 0

	self.Obstacle = nil
	self.ObstaclePos = nil
	self.ObstacleHit = nil
	self.ObstacleLoose = false
	self.ObstacleSince = 0
	self.ObstacleSeen = 0
	self.ObstacleProgress = nil
	self.ObstacleHP = nil
	self.ObstacleMarked = nil
	self.NextMark = 0
	self.DetourUntil = 0
	self.NextDoorUse = 0
	self.IgnoredObstacles = {}
	self.NoteFocus = nil -- entity the next Note is about when it is not the obstacle

	return self
end

function Loco:Destroy()
	AI.Nav.Cancel(self.Bot)
	self.Path = nil
	self.Segments = nil
end

---------------------------------------------------------------------------
-- Notes
---------------------------------------------------------------------------

-- Why we last did something that was not plain steering. Debug overlay and
-- recorder read it; the recorder writes a bug file for some of them.
function Loco:Note(reason)
	self.LastAction = reason
	self.LastActionTime = CurTime()
	local Rec = AI.Rec
	if Rec and Rec.OnNote then
		local ok, err = pcall(Rec.OnNote, self, reason)
		if not ok and Rec.Warn then Rec.Warn(err) end
	end
end

function Loco:GetNote(maxAge)
	local t = self.LastActionTime
	if t and CurTime() - t <= (maxAge or 2) then
		return self.LastAction
	end
	return nil
end

---------------------------------------------------------------------------
-- Goals
---------------------------------------------------------------------------

-- target: Vector or Entity (followed). ignoreEnt: entity that may sit on the goal
-- (the thing we want to hit) and must not count as blocking.
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

	-- A new thing to go to, not the approach point sliding as we walk up to a sigil.
	local changed = self.Goal == nil or self.GoalEnt ~= ent or (ent == nil and self.Goal:DistToSqr(pos) > 128 * 128)
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
		self.LastPathEnd = nil
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
	self.Path = nil
	self.Segments = nil
	self.CursorFloor = nil
	self.SteerPos = nil
	self.LookPos = nil
	self.WalkDest = nil
	self.Hold = false
	self.PathPending = false
	self.NeedRepath = false
	self.ClearPath = false
	self.Exhausted = false
	self.ExhaustedSince = nil
	self.LastPathEnd = nil
	self.IslandCut = false
	if self.Bot then self.Bot.Path = nil end
	-- Seated on the rungs we finish the climb; the brain re-decides at the top.
	if self.Ladder and self.Ladder.Phase ~= "climb" and not Holding(self.Player) then
		self:EndLadder("stop", false)
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

-- Are our cell and the goal's cell on different mesh islands?
function Loco:GoalOnOtherIsland()
	local mesh = AI.Mesh
	if not (mesh and mesh.IsReady and mesh.IsReady() and mesh.Nearest and self.Goal) then return false end
	local mine = mesh.Nearest(self.Player:GetPos(), 120, 80)
	local theirs = mesh.Nearest(self.Goal, 240)
	if not mine or not theirs or not mine.comp or not theirs.comp then return false end
	return mine.comp ~= theirs.comp
end

-- The path ends short of the goal and we have stood at that end, we are stuck
-- again and again, or no path can be found. A target we can already claw is
-- never hopeless. A door we are opening or breaking is not hopeless either.
function Loco:IsHopeless()
	if self.Ladder then return false end
	if self.PathPending then return false end
	local combat = self.Bot and self.Bot.Combat
	if combat and combat.InReach then return false end
	if IsValid(self.Obstacle) then return false end

	if self.PathValid then
		-- The search stopped at a closed leaf and named it: that door is the
		-- plan, not a dead end. It stops being one through GiveUpObstacle (ban),
		-- after which the next path no longer carries it.
		local door = self.Path.GetDoor and self.Path:GetDoor()
		local doorPlan = IsValid(door) and not door.Broken
		if self.IslandCut and not doorPlan then
			local endp = self.Path:GetEnd()
			if not endp or self.Player:GetPos():DistToSqr(endp) <= 80 * 80 then
				return true
			end
		end
		if self.Exhausted and not doorPlan and self.ExhaustedSince and CurTime() - self.ExhaustedSince > self.P.ExhaustedGiveUp then
			return true
		end
		return self.StuckEpisodes >= 3
	end
	return self.FailedPaths >= 2 or self.StuckEpisodes >= 3
end

---------------------------------------------------------------------------
-- Path results
---------------------------------------------------------------------------

function Loco:OnPathResult(path, reached, goal)
	local oldLength = self.PathLength

	self.PathPending = false
	self.Path = path
	if self.Bot then self.Bot.Path = path end
	self.PathValid = path ~= nil and path.IsValid ~= nil and path:IsValid() == true
	self.PathReached = reached == true and self.PathValid
	self.PathTime = CurTime()
	self.Exhausted = false
	self.OffPath = false
	self.CursorFloor = nil

	-- No edge to that island. The walk to that end still happens; the grind
	-- starts only once they are standing on it.
	self.IslandCut = self.PathValid and not self.PathReached and self:GoalOnOtherIsland()

	-- The exhausted clock survives a repath that ends where the last one did.
	if self.PathReached then
		self.ExhaustedSince = nil
		self.LastPathEnd = nil
	elseif self.PathValid then
		local e = path:GetEnd()
		if not self.LastPathEnd or self.LastPathEnd:DistToSqr(e) > 64 * 64 then
			self.ExhaustedSince = nil
		end
		self.LastPathEnd = Vector(e)
	end

	if goal then
		if self.PathGoal then
			self.PathGoal:Set(goal)
		else
			self.PathGoal = Vector(goal)
		end
	end

	if self.PathValid then
		self.PathLength = path:GetLength()
		self.Segments = path:GetAllSegments()
		self.SegIndex = 1
		self.Cursor = 0
		self.NextLook = 0
		self.HopKey = nil
		self.HopTries = 0
		self.FailedPaths = 0
	else
		self.PathLength = 0
		self.Segments = nil
		self.FailedPaths = self.FailedPaths + 1
		if self.FailedPaths >= 2 then
			self:Note("path:fail")
		end
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
				self.IgnoredObstacles[obstacle] = CurTime() + 3
				self:ClearObstacle(false)
				self:Note("detour")
			else
				self:Note("break:noway")
			end
		end
	end

	local Rec = AI.Rec
	if Rec and Rec.OnPath then
		local ok, err = pcall(Rec.OnPath, self, path, reached, goal)
		if not ok and Rec.Warn then Rec.Warn(err) end
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
-- Polyline helpers (work on any segment list with pos / distanceFromStart / type)
---------------------------------------------------------------------------

-- Point at distance d along the path. hint: segment index to start scanning from.
local function PointAt(segs, d, hint)
	local n = #segs
	if n == 0 then return nil, 1 end
	local i = hint or 1
	if i < 1 then i = 1 elseif i > n then i = n end
	while i > 1 and segs[i].distanceFromStart > d do i = i - 1 end
	while i < n and segs[i + 1].distanceFromStart <= d do i = i + 1 end
	if i >= n then return segs[n].pos, n end
	local a, b = segs[i], segs[i + 1]
	local span = b.distanceFromStart - a.distanceFromStart
	if span < 0.001 then return a.pos, i end
	local t = (d - a.distanceFromStart) / span
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return Vector(
		a.pos.x + (b.pos.x - a.pos.x) * t,
		a.pos.y + (b.pos.y - a.pos.y) * t,
		a.pos.z + (b.pos.z - a.pos.z) * t
	), i
end

-- Closest point on segments i0..i1 to pos. Returns distanceFromStart, segment index, dist^2.
-- Ties go to the point further along: the path starts under our feet, and a
-- leg that comes back past us must not pull the cursor to its start.
local CURSOR_SLACK = 10 * 10
local function ClosestOnPath(segs, pos, i0, i1)
	local bestD, bestI, bestDist = 0, i0, math.huge
	local px, py, pz = pos.x, pos.y, pos.z
	for i = i0, i1 do
		local a, b = segs[i], segs[i + 1]
		local ax, ay, az = a.pos.x, a.pos.y, a.pos.z
		local d, dist
		if not b then
			local dx, dy, dz = px - ax, py - ay, pz - az
			dist = dx * dx + dy * dy + dz * dz
			d = a.distanceFromStart
		else
			local ex, ey, ez = b.pos.x - ax, b.pos.y - ay, b.pos.z - az
			local len2 = ex * ex + ey * ey + ez * ez
			local t = 0
			if len2 > 0.001 then
				t = ((px - ax) * ex + (py - ay) * ey + (pz - az) * ez) / len2
				if t < 0 then t = 0 elseif t > 1 then t = 1 end
			end
			local dx, dy, dz = px - (ax + ex * t), py - (ay + ey * t), pz - (az + ez * t)
			dist = dx * dx + dy * dy + dz * dz
			d = a.distanceFromStart + (b.distanceFromStart - a.distanceFromStart) * t
		end
		if dist < bestDist - CURSOR_SLACK or (dist <= bestDist + CURSOR_SLACK and d > bestD) then
			bestDist, bestD, bestI = dist, d, i
		end
	end
	return bestD, bestI, bestDist
end

local function IsLadderSeg(seg)
	return seg.ladder ~= nil or seg.type == SEG_LADDER_UP or seg.type == SEG_LADDER_DOWN
end

-- First waypoint at or after i whose leave edge is not a plain walk.
local function NextSpecial(segs, i)
	local n = #segs
	for j = i, n - 1 do
		local s = segs[j]
		if s.type ~= SEG_GROUND or s.ladder ~= nil then
			return j
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

function Loco:Jump(reason, noduck)
	local now = CurTime()
	if now < self.NextJump or not self.Player:IsOnGround() then return false end
	self.NextJump = now + 0.9
	self.JumpUntil = now + 0.06
	if not noduck then
		-- Duck-jump: tuck the legs shortly after leaving the ground for extra ledge height.
		self.DuckFrom = now + 0.12
		self.DuckUntil = now + 0.65
	end
	if reason then self:Note("jump:" .. reason) end
	return true
end

function Loco:Duck(duration, reason)
	local now = CurTime()
	local fresh = now >= self.DuckUntil
	self.DuckFrom = math_min(self.DuckFrom, now)
	self.DuckUntil = math_max(self.DuckUntil, now + (duration or 0.25))
	if reason and fresh then self:Note("duck:" .. reason) end
end

function Loco:PressUse()
	self.UseUntil = CurTime() + 0.08
end

function Loco:SideStepFor(duration, side)
	self.SideStep = side or (math.random(2) == 1 and 1 or -1)
	self.SideStepUntil = CurTime() + duration
end

---------------------------------------------------------------------------
-- Traces
---------------------------------------------------------------------------

-- Things a player body passes through are not in the way: the sigil post
-- (DEBRIS_TRIGGER), dropped weapons, prop_prop_blocker (IgnoreTraces).
local PASSABLE_GROUPS = {
	[COLLISION_GROUP_DEBRIS] = true,
	[COLLISION_GROUP_DEBRIS_TRIGGER] = true,
	[COLLISION_GROUP_WEAPON] = true,
	[COLLISION_GROUP_IN_VEHICLE] = true,
	[COLLISION_GROUP_PASSABLE_DOOR] = true,
	[COLLISION_GROUP_DOOR_BLOCKER] = true,
	[COLLISION_GROUP_DISSOLVING] = true,
}

local probeSelf, probeIgnore
local function ProbeFilter(ent)
	if ent == probeSelf or ent == probeIgnore or ent:IsPlayer() then return false end
	if ent.IgnoreTraces or PASSABLE_GROUPS[ent:GetCollisionGroup()] then return false end
	if ent.RelapseLadderClip then return false end
	return true
end

-- Same filter, but players count (the slide needs to know about a crowd).
local function BodyFilter(ent)
	if ent == probeSelf or ent == probeIgnore then return false end
	if ent.IgnoreTraces or PASSABLE_GROUPS[ent:GetCollisionGroup()] then return false end
	if ent.RelapseLadderClip then return false end
	return true
end

-- Knee/chest/head bands: what is directly ahead.
local probeTrace = {
	mask = MASK_PLAYERSOLID,
	collisiongroup = COLLISION_GROUP_PLAYER,
	mins = Vector(-10, -10, -6),
	maxs = Vector(10, 10, 18),
	filter = ProbeFilter,
}
local PROBE_BAND = 18
local PROBE_HEAD = 6
-- Narrow crouched hull, lifted by the step or jump height.
local ledgeTrace = {
	mask = MASK_PLAYERSOLID,
	collisiongroup = COLLISION_GROUP_PLAYER,
	mins = Vector(-8, -8, 0),
	maxs = Vector(8, 8, 36),
	filter = ProbeFilter,
}
-- Full crouched player hull.
local duckTrace = {
	mask = MASK_PLAYERSOLID,
	collisiongroup = COLLISION_GROUP_PLAYER,
	mins = Vector(-16, -16, 0),
	maxs = Vector(16, 16, 36),
	filter = ProbeFilter,
}
local landingTrace = {mask = MASK_PLAYERSOLID, collisiongroup = COLLISION_GROUP_PLAYER, filter = ProbeFilter}
-- Standing hull for the direct approach.
local directTrace = {
	mask = MASK_PLAYERSOLID,
	collisiongroup = COLLISION_GROUP_PLAYER,
	mins = Vector(-12, -12, 0),
	maxs = Vector(12, 12, 60),
	filter = ProbeFilter,
}
-- Slightly slimmer than the body, lifted by the step: can we walk straight to a path point?
local seeTrace = {
	mask = MASK_PLAYERSOLID,
	collisiongroup = COLLISION_GROUP_PLAYER,
	mins = Vector(-14, -14, 0),
	maxs = Vector(14, 14, 38),
	filter = ProbeFilter,
}
-- Real body width, lifted by the step: what would we push into this tick?
local slideTrace = {
	mask = MASK_PLAYERSOLID,
	collisiongroup = COLLISION_GROUP_PLAYER,
	mins = Vector(-16, -16, 0),
	maxs = Vector(16, 16, 42),
	filter = BodyFilter,
}
local groundTrace = {mask = MASK_PLAYERSOLID_BRUSHONLY}

-- The thing we intend to hit never counts as blocking - unless it is the obstacle itself.
local function SetProbeContext(self)
	probeSelf = self.Player
	local ignore = self.IgnoreEnt
	if ignore == self.Obstacle then ignore = nil end
	probeIgnore = ignore
end

local function IsDoor(ent)
	local class = ent:GetClass()
	return class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating"
end

local function IsPhysicsPropClass(class)
	return string.sub(class, 1, 12) == "prop_physics"
		or class == "func_physbox" or class == "func_physbox_multiplayer"
end

-- What is in front of us above step height, within dist along (dx, dy)?
-- maxDrop: how far below us the landing may be.
function Loco:ProbeLedge(pos, dx, dy, dist, maxHeight, maxDrop)
	local P = self.P
	dist = dist or 20
	maxHeight = maxHeight or P.JumpHeight
	maxDrop = maxDrop or (P.JumpHeight + 24)
	SetProbeContext(self)

	local ex, ey = pos.x + dx * dist, pos.y + dy * dist

	-- A hull lifted by the step height only hits what a step cannot take.
	local z = pos.z + P.StepHeight + 1
	ledgeTrace.start = Vector(pos.x, pos.y, z)
	ledgeTrace.endpos = Vector(ex, ey, z)
	local tr = util_TraceHull(ledgeTrace)
	if tr.StartSolid then
		-- Overlapping a crate we walked into: back up and try again.
		ledgeTrace.start = Vector(pos.x - dx * 16, pos.y - dy * 16, z)
		tr = util_TraceHull(ledgeTrace)
		if tr.StartSolid then
			-- Pressed into a curb: is there a standable top within jump height?
			landingTrace.start = Vector(pos.x + dx * 28, pos.y + dy * 28, pos.z + maxHeight + 1)
			landingTrace.endpos = Vector(pos.x + dx * 28, pos.y + dy * 28, pos.z + 2)
			local down = util_TraceLine(landingTrace)
			if down.Hit and (not down.HitNormal or down.HitNormal.z > WALKABLE_Z) then
				local h = down.HitPos.z - pos.z
				if h > P.StepHeight and h <= maxHeight then
					return LEDGE_JUMP
				end
			end
			return LEDGE_WALL
		end
	end
	if not tr.Hit or tr.HitNormal.z > WALKABLE_Z then return LEDGE_CLEAR end
	-- A dumpster, drum or door reads as a curb with a floor beyond it. Hopping
	-- that face is the loop against the prop. A brush lip is still a jump.
	if IsValid(tr.Entity) and not tr.Entity:IsWorld() then
		local class = tr.Entity:GetClass()
		if IsPhysicsPropClass(class) or IsDoor(tr.Entity) then
			return LEDGE_WALL
		end
	end

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
	if h < P.StepHeight then
		-- Stair riser: a short down-hit. Not a hop.
			return LEDGE_CLEAR
	end

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

-- Can a body walk in a straight line from `from` to `to`? Stairs and ramps are
-- under the lifted hull, so they count as clear.
function Loco:HullClear(from, to)
	SetProbeContext(self)
	local lift = self.P.StepHeight + 1
	seeTrace.start = Vector(from.x, from.y, from.z + lift)
	seeTrace.endpos = Vector(to.x, to.y, to.z + lift)
	local tr = util_TraceHull(seeTrace)
	if tr.StartSolid then return true end -- cannot tell from inside something: trust the path
	return not tr.Hit or tr.HitNormal.z > WALKABLE_Z
end

-- Straight walk to the goal with no path: clear hull and floor under the midpoint.
function Loco:IsDirectClear(pos, goal)
	probeSelf = self.Player
	probeIgnore = self.IgnoreEnt
	local lift = Vector(0, 0, 18)
	directTrace.start = pos + lift
	directTrace.endpos = goal + lift
	if util_TraceHull(directTrace).Hit then
		return false
	end
	local mid = (pos + goal) * 0.5
	groundTrace.start = mid + lift
	groundTrace.endpos = mid - Vector(0, 0, 80)
	return util_TraceLine(groundTrace).Hit
end

---------------------------------------------------------------------------
-- Breakables
---------------------------------------------------------------------------

-- Things a zombie should punch through instead of pathing around forever.
-- Returns breakable, loose. Loose = unnailed physics: only if it sits on the
-- way to a human or a sigil, never as random clutter.
function Loco.IsBreakable(ent)
	if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return false end
	if ent.NoRelapseAIBreak or ent.IsCreeperNest then return false end

	local class = ent:GetClass()
	-- Bodies walk through the sigil post; corrupting it is the brain's intent.
	if class == "prop_obj_sigil" then
		return false
	end
	if ent.IsNailed and ent:IsNailed() then
		return true, false
	end
	-- Deployables (crate, lamp, aegis). Unnailed map physics is not a barricade
	-- just because TemporaryBarricadeObject flipped IsBarricadeObject.
	if ent.IsBarricadeObject and not IsPhysicsPropClass(class) then
		return true, false
	end
	if class == "func_breakable" or class == "func_breakable_surf" then
		return true, false
	end
	if IsDoor(ent) then
		-- E opens an unlocked prop door; claws take a breakable one. Either is "in the way, passable".
		return Loco.DoorOpenable(ent) or Loco.DoorBreakable(ent), false
	end
	if IsPhysicsPropClass(class) then
		return ent:IsRelapseMoveable(), true
	end
	return false
end

-- A prop door +USE swings open (zombie classes without NoUse).
function Loco.DoorOpenable(ent)
	if ent.Broken or ent:GetClass() ~= "prop_door_rotating" then return false end
	return not (ent.IsDoorLocked and ent:IsDoorLocked())
end

-- A door the gamemode lets zombies gib. Locked doors with the "unbreakable
-- when locked" spawnflag and damagefilter invul doors are walls.
function Loco.DoorBreakable(ent)
	if ent.Broken then return false end
	if ent.RelapseAIInvul == nil then
		local kv = ent:GetKeyValues()
		ent.RelapseAIInvul = (kv and kv.damagefilter == "invul") and true or false
	end
	if ent.RelapseAIInvul then return false end
	if ent:GetClass() == "prop_door_rotating" and ent:HasSpawnFlags(2048) and ent.IsDoorLocked and ent:IsDoorLocked() then
		return false
	end
	return true
end

-- Health pool our hits drain. Doors keep it in ent.Heal (nil until the first
-- hit); nailed props in the barricade pool; anything else in Health().
local function ObstacleHealth(ent)
	if IsDoor(ent) then
		return ent.Heal or math.huge
	end
	if ent.GetBarricadeHealth and ent.IsBarricadeProp and ent:IsBarricadeProp() then
		return ent:GetBarricadeHealth()
	end
	if ent.PropHealth then
		return ent.PropHealth -- map prop made vulnerable: init.lua drains this, not Health()
	end
	return ent:Health()
end

-- Opening is not a clear hole. Passable flips the moment the leaf moves;
-- stepping in then meets the swing and the leaf shoves the body off the opening.
local function DoorStillMoving(door)
	local class = door:GetClass()
	if class == "prop_door_rotating" then
		local st = door.GetInternalVariable and door:GetInternalVariable("m_eDoorState")
		return st == 1
	end
	if class == "func_door" or class == "func_door_rotating" then
		local st = door.GetInternalVariable and door:GetInternalVariable("m_toggle_state")
		return st == 2
	end
	return false
end

-- Is the leaf still across the walk chord? State can say closed after the leaf
-- has swung; the chord is the truth. A leaf that is still moving blocks even
-- when the chord already misses the hole it left.
function Loco:DoorBlocks(door, pos)
	if DoorStillMoving(door) then return true end
	local Mesh = AI.Mesh
	if not (Mesh and Mesh.DoorwayOpen) then return true end
	local id = door:EntIndex()
	local function blocks(tx, ty)
		return not Mesh.DoorwayOpen(id, pos.x, pos.y, pos.z, tx, ty, pos.z)
	end
	local dir = self.PathDir
	if (dir.x == 0 and dir.y == 0) then dir = self.WishDir end
	if (dir.x ~= 0 or dir.y ~= 0) and blocks(pos.x + dir.x * 72, pos.y + dir.y * 72) then
		return true
	end
	local c = door:WorldSpaceCenter()
	local dx, dy = c.x - pos.x, c.y - pos.y
	local len = math_sqrt(dx * dx + dy * dy)
	if len < 8 then return true end
	return blocks(pos.x + dx / len * (len + 56), pos.y + dy / len * (len + 56))
end

-- The leaf left the hole: lift the price on the mouth and ask for a new path.
function Loco:DoorCleared(door)
	self.NoteFocus = door
	self:Note("door:clear")
	self.NoteFocus = nil
	if AI.Mesh and AI.Mesh.LiftDoorBlock then AI.Mesh.LiftDoorBlock(door) end
	if self.Obstacle == door then self:ClearObstacle(true) end
	self.PathValid = false
	self.NextRepath = 0
end

-- Outside a leaf's swing. A shut door is a thin box; open, it sweeps about its
-- own length. Claws close that gap and the moving leaf shoves the body off the hole.
local DOOR_STAND = 72

local function DoorStandPoint(self, door, pos)
	local c = door:WorldSpaceCenter()
	local sx, sy = self.DoorSideX, self.DoorSideY
	if not sx then
		local dx, dy = pos.x - c.x, pos.y - c.y
		local len = math_sqrt(dx * dx + dy * dy)
		if len < 1 then
			sx, sy = 1, 0
		else
			sx, sy = dx / len, dy / len
		end
	end
	return c.x + sx * DOOR_STAND, c.y + sy * DOOR_STAND
end

-- Unlocked prop door in our way: E opens it, once we are standing clear of the
-- swing and looking at the leaf.
function Loco:TryUseDoor(pos, now)
	local door = self.Obstacle
	if not IsValid(door) or door:GetClass() ~= "prop_door_rotating" then return end
	if door.IsDoorLocked and door:IsDoorLocked() then return end
	if not self:DoorBlocks(door, pos) then return end
	self.ObstacleSeen = now
	-- The hunt still looks at the player. Use traces the eyes, so the head
	-- has to be on the leaf or E hits whatever is behind it.
	local view = self.Bot and self.Bot.View
	local eye = self.Player:EyePos()
	local aim = door:NearestPoint(eye)
	if view then
		view:SetOverride(aim)
		if view:AngleTo(aim) > 25 then return end
	end
	local sx, sy = DoorStandPoint(self, door, pos)
	local dx, dy = sx - pos.x, sy - pos.y
	if dx * dx + dy * dy > 20 * 20 then return end
	if now < self.NextDoorUse then return end
	local classtab = self.Player.GetZombieClassTable and self.Player:GetZombieClassTable()
	if classtab and classtab.NoUse then return end
	local near = aim
	if near:DistToSqr(eye) > self.P.DoorUseDist * self.P.DoorUseDist then return end
	self.NextDoorUse = now + self.P.DoorUseInterval
	self:PressUse()
	self:Note("door:use")
end

-- Wish toward the stand point while an unlocked leaf still fills the hole.
-- Zero once there: the path chord runs through the leaf, and walking it means
-- the swing meets the body.
function Loco:OpenDoorWish(pos, wx, wy)
	local door = self.Obstacle
	if not IsValid(door) or not Loco.DoorOpenable(door) then return wx, wy end
	if not self:DoorBlocks(door, pos) then return wx, wy end
	local sx, sy = DoorStandPoint(self, door, pos)
	local dx, dy = sx - pos.x, sy - pos.y
	local len = math_sqrt(dx * dx + dy * dy)
	if len < 12 then return 0, 0 end
	return dx / len, dy / len
end

-- Pad just outside the footprint. A pad into a brush is skipped.
local exitTrace = {
	mask = MASK_SOLID_BRUSHONLY,
	mins = Vector(-12, -12, 2),
	maxs = Vector(12, 12, 36),
}
local function ExitClear(pl, pos, nx, ny)
	exitTrace.start = Vector(pos.x, pos.y, pos.z + 8)
	exitTrace.endpos = Vector(nx, ny, pos.z + 8)
	exitTrace.filter = pl
	local tr = util_TraceHull(exitTrace)
	if tr.StartSolid then return false end
	if tr.Hit and tr.Fraction < 0.85 and math_abs(tr.HitNormal.z) <= 0.5 then
		return false
	end
	return true
end

-- Nearest open point just outside the prop's footprint, on its bottom.
function Loco:LoosePropExit(ent)
	local pl = self.Player
	local pos = pl:GetPos()
	local mins, maxs = ent:WorldSpaceAABB()
	local pad = 36
	local best = math.huge
	local x, y
	local function consider(dist, nx, ny)
		if dist < best and ExitClear(pl, pos, nx, ny) then
			best, x, y = dist, nx, ny
		end
	end
	consider(pos.x - mins.x, mins.x - pad, pos.y)
	consider(maxs.x - pos.x, maxs.x + pad, pos.y)
	consider(pos.y - mins.y, pos.x, mins.y - pad)
	consider(maxs.y - pos.y, pos.x, maxs.y + pad)
	if not x then return nil end
	return Vector(x, y, mins.z)
end

-- Unnailed physics we are standing on: hop off, never punch the floor.
-- Frozen is a platform (a pallet laid as floor). Hopping lands on it again.
function Loco:OnLooseProp()
	local g = self.Player:GetGroundEntity()
	if not IsValid(g) or g:IsWorld() then return nil end
	if g.IsNailed and g:IsNailed() then return nil end
	local phys = g.GetPhysicsObject and g:GetPhysicsObject()
	if IsValid(phys) and not phys:IsMotionEnabled() then return nil end
	if IsPhysicsPropClass(g:GetClass()) and g:GetMoveType() == MOVETYPE_VPHYSICS then
		return g
	end
	return nil
end

-- Unnailed junk is worth a swing only when the route actually stops at it.
function Loco:LooseWorthBreaking(ent, hitPos)
	if self.PathReached then return false end
	if self.Obstacle == ent then return true end
	if not self.ClearPath then return false end
	if self.IslandCut then return false end
	local path = self.Path
	if path and path.GetEnd then
		local endp = path:GetEnd()
		if endp and hitPos:DistToSqr(endp) > 120 * 120 then return false end
	end
	local dest = self.PathGoal or self.Goal
	if not dest then return false end
	local pos = self.Player:GetPos()
	if math_abs(dest.z - pos.z) > 40 then return false end
	local gx, gy = dest.x - pos.x, dest.y - pos.y
	local g2 = gx * gx + gy * gy
	if g2 < 48 * 48 then return false end
	local glen = math_sqrt(g2)
	local hx, hy = hitPos.x - pos.x, hitPos.y - pos.y
	if (hx * gx + hy * gy) / glen < 10 then return false end
	return math_abs(hx * -gy + hy * gx) / glen <= 60
end

-- Path penalty on the mesh under and around the thing.
function Loco:MarkObstacle(ent, now, duration, penalty)
	local Nav = AI.Nav
	local c = ent:WorldSpaceCenter()
	Nav.MarkBlockedAt(self.Player:GetPos(), duration, penalty)
	Nav.MarkBlockedAt(c, duration, penalty)
	local Mesh = AI.Mesh
	if Mesh and Mesh.MarkBlockedAround and Mesh.IsReady and Mesh.IsReady() then
		local mins, maxs = ent:WorldSpaceAABB()
		local rad = math_max(maxs.x - mins.x, maxs.y - mins.y) * 0.5 + 24
		Mesh.MarkBlockedAround(Vector(c.x, c.y, mins.z), rad, duration, penalty)
	end
	self.ObstacleMarked = Vector(c)
	self.NextMark = now + 10
end

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
		self.ObstacleMarked = nil
		self.DetourUntil = 0
		self.NextDoorUse = 0
		if not (IsDoor(ent) and Loco.DoorOpenable(ent)) then
			self.DoorSideX, self.DoorSideY = nil, nil
			local view = self.Bot and self.Bot.View
			if view then view:ClearOverride() end
		end

	local Nav = AI.Nav
		local door = IsDoor(ent)
		if door then
			if Loco.DoorOpenable(ent) then
				-- Remember the side we walked in from. The swing meets that side.
				local c = ent:WorldSpaceCenter()
				local p = self.Player:GetPos()
				local dx, dy = p.x - c.x, p.y - c.y
				local len = math_sqrt(dx * dx + dy * dy)
				if len < 1 then
					self.DoorSideX, self.DoorSideY = 1, 0
				else
					self.DoorSideX, self.DoorSideY = dx / len, dy / len
				end
			else
				-- The graph already prices a shut leaf; a detour, if any, was taken.
				self:Note("break:" .. ent:GetClass())
			end
		else
			local penalty = loose and (Nav.Penalty.Prop or 450) or Nav.Penalty.Barricade
			local duration = loose and 15 or self.P.BarricadeMark
			local known = Nav.BlockedSince(self.ObstacleHit, penalty)
			self:MarkObstacle(ent, now, duration, penalty)
			local nailed = ent.IsNailed and ent:IsNailed()
			if nailed or self.Mode ~= "path" or self.Hold or (known and self.PathTime > known) then
				self:Note("break:" .. ent:GetClass())
			else
				-- See whether the penalty buys a way around before swinging.
				self.DetourUntil = now + self.P.DetourWait
				self.NeedRepath = true
				self:Note((loose and "prop:" or "obstacle:") .. ent:GetClass())
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
	if unmark and self.ObstacleMarked then
	local Mesh = AI.Mesh
		if Mesh and Mesh.UnblockAround then
			Mesh.UnblockAround(self.ObstacleMarked, 96)
		end
	end
	self.Obstacle = nil
	self.ObstacleMarked = nil
	self.ObstacleLoose = false
	self.DoorSideX, self.DoorSideY = nil, nil
	self.DetourUntil = 0
	local view = self.Bot and self.Bot.View
	if view then view:ClearOverride() end
end

-- What the brain should break right now, or nil. Also the place where an
-- obstacle stops being one: gone, moved, opened, hammered for too long.
function Loco:GetObstacle()
	local ent = self.Obstacle
	if not ent then return nil end

	local now = CurTime()
	if not IsValid(ent) then
		self:ClearObstacle(true)
		return nil
	end
	if not Loco.IsBreakable(ent) then
		if IsDoor(ent) and not ent.Broken then
			-- Became a wall (locked with the unbreakable flag): route around it for good.
			self:GiveUpObstacle(ent, now, "door:locked")
		else
			self:ClearObstacle(true)
		end
		return nil
	end
	if ent:GetPos():DistToSqr(self.ObstaclePos) > 48 * 48 then
		self:ClearObstacle(true) -- pushed or knocked away
		return nil
	end

	local mypos = self.Player:GetPos()
	if IsDoor(ent) and not self:DoorBlocks(ent, mypos) then
		self:DoorCleared(ent)
		return nil
	end
	if self.ObstacleLoose then
		local past = self.PathReached
		if not past and self.Path and self.Path.GetEnd then
		local endp = self.Path:GetEnd()
		local hit = self.ObstacleHit or ent:WorldSpaceCenter()
			past = endp and hit:DistToSqr(endp) > 120 * 120
		end
		if past then
			self.NoteFocus = ent
			self:Note("prop:past")
			self.NoteFocus = nil
			self:ClearObstacle(true)
			return nil
		end
		if not self.ClearPath then
		self:ClearObstacle(true)
		return nil
	end
	end
	if self.Player:GetGroundEntity() == ent then
		self:ClearObstacle(true)
		return nil
	end
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

	-- Hammered for too long without result (elevator, welded door): route around it.
	-- Loose furniture with no health never shows a dent; do not stand on it for the full timer.
	local limit = self.P.ObstacleTimeout
	if self.ObstacleLoose and (not hp or hp <= 0) then
		limit = 4
	end
	if now - math_max(self.ObstacleSince, self.ObstacleProgress or 0) > limit then
		self:GiveUpObstacle(ent, now, "giveup:" .. ent:GetClass())
		return nil
	end

	-- Still waiting to hear whether there is a way around it.
	if self.DetourUntil > now then return nil end

	-- Unlocked: E from outside the swing. Claws walk into the leaf and it pushes back.
	if IsDoor(ent) and Loco.DoorOpenable(ent) then
		local classtab = self.Player.GetZombieClassTable and self.Player:GetZombieClassTable()
		if not (classtab and classtab.NoUse) then return nil end
	end

	if self.ObstacleMarked and now >= self.NextMark then
		local Nav = AI.Nav
		if self.ObstacleLoose then
			self:MarkObstacle(ent, now, 15, Nav.Penalty.Prop or 450)
		else
			self:MarkObstacle(ent, now, self.P.BarricadeMark, Nav.Penalty.Barricade)
		end
	end
	return ent
end

function Loco:GiveUpObstacle(ent, now, why)
			local Nav = AI.Nav
	self.IgnoredObstacles[ent] = now + self.P.ObstacleIgnore
	self:MarkObstacle(ent, now, 45, Nav.Penalty.Unbreakable)
	if IsDoor(ent) and AI.Mesh and AI.Mesh.BanDoor then
		AI.Mesh.BanDoor(ent, 45)
	end
	self.NoteFocus = ent
	self:Note(why)
	self.NoteFocus = nil
	self:ClearObstacle(false)
	self.PathValid = false
	self.NextRepath = 0
end

local function ConsiderHit(self, tr, dist, accept)
	if not tr.Hit or tr.HitWorld then return nil end
	local ent = tr.Entity
	if not IsValid(ent) then return nil end
	if tr.Fraction * dist > (accept or self.P.ObstacleAccept) then return nil end

	local breakable, loose = Loco.IsBreakable(ent)
	if not breakable then
		if IsDoor(ent) and not ent.Broken and self.Mode == "path" then
			-- A wall with hinges. Price it so the next path goes elsewhere.
			self:GiveUpObstacle(ent, CurTime(), "door:locked")
		end
		return nil
	end
	if loose and not self:LooseWorthBreaking(ent, tr.HitPos) then return nil end
	if IsDoor(ent) and not self:DoorBlocks(ent, self.Player:GetPos()) then return nil end
	if self:SetObstacle(ent, loose, tr.HitPos) then
		return ent
	end
	return nil
end

-- Step around a loose prop when a lane beside it is open.
function Loco:TrySidestepAround(pos, dx, dy, ent)
	if CurTime() < self.SideStepUntil then return false end
	SetProbeContext(self)
	local rx, ry = -dy, dx
	local dist = 48
	for _, s in ipairs({1, -1}) do
		local sx, sy = pos.x + rx * s * 36, pos.y + ry * s * 36
		probeTrace.maxs.z = PROBE_BAND
		probeTrace.start = Vector(sx, sy, pos.z + 24)
		probeTrace.endpos = Vector(sx + dx * dist, sy + dy * dist, pos.z + 24)
		local tr = util_TraceHull(probeTrace)
		if not tr.Hit and not tr.StartSolid then
			groundTrace.start = Vector(sx, sy, pos.z + 24)
			groundTrace.endpos = Vector(sx, sy, pos.z - 64)
			local g = util_TraceLine(groundTrace)
			if g.Hit and math_abs(g.HitPos.z - pos.z) < 40 then
				self:SideStepFor(0.55, s)
				self.NoteFocus = ent
				self:Note("prop:around")
				self.NoteFocus = nil
				return true
			end
		end
	end
	return false
end

-- Look at what is in the way along the path. Crawl under it or hop over it when
-- possible; walk around a loose prop; only then, if it is breakable, make it the
-- obstacle and return it. Default look: along the path, ProbeDist, ObstacleAccept.
function Loco:ProbeObstacle(pos, dx, dy, dist, accept)
	if not dx then
		local dir = self.PathDir
		if dir.x == 0 and dir.y == 0 then dir = self.WishDir end
		dx, dy = dir.x, dir.y
	end
	if dx == 0 and dy == 0 then return nil end

	SetProbeContext(self)
	dist = dist or self.P.ProbeDist
	local ex, ey = pos.x + dx * dist, pos.y + dy * dist

	probeTrace.maxs.z = PROBE_BAND
	probeTrace.start = Vector(pos.x, pos.y, pos.z + 40)
	probeTrace.endpos = Vector(ex, ey, pos.z + 40)
	local chest = util_TraceHull(probeTrace)
	probeTrace.start = Vector(pos.x, pos.y, pos.z + 14)
	probeTrace.endpos = Vector(ex, ey, pos.z + 14)
	local knee = util_TraceHull(probeTrace)

	-- Still try to hop a loose crate we had started hitting.
	local cur = self.Obstacle
	if cur and (chest.Entity == cur or knee.Entity == cur) then
		if self.ObstacleLoose and self:ProbeLedge(pos, dx, dy, dist) == LEDGE_JUMP then
			self:ClearObstacle(true)
			self:Jump("over")
			return nil
		end
		self.ObstacleSeen = CurTime()
		return cur
	end

	if not chest.Hit and not knee.Hit then
		probeTrace.maxs.z = PROBE_HEAD
		probeTrace.start = Vector(pos.x, pos.y, pos.z + 66)
		probeTrace.endpos = Vector(ex, ey, pos.z + 66)
		if util_TraceHull(probeTrace).Hit and self:CanDuckThrough(pos, dx, dy) then
			self:Duck(0.5, "head")
		end
		return nil
	end

	if chest.Hit and not knee.Hit then
		if self:CanDuckThrough(pos, dx, dy) then
			self:Duck(0.5, "under")
			return nil
		end
		if self:ProbeLedge(pos, dx, dy, dist) == LEDGE_JUMP then
			self:Jump("over")
			return nil
		end
	elseif knee.Hit and not chest.Hit then
		local kind = self:ProbeLedge(pos, dx, dy, dist)
		if kind == LEDGE_CLEAR then
			return nil
		elseif kind == LEDGE_JUMP then
			self:Jump("low")
			return nil
		end
	else
		if self:ProbeLedge(pos, dx, dy, dist) == LEDGE_JUMP then
			self:Jump("sill")
			return nil
		end
	end

	local hitEnt = (chest.Hit and chest.Entity) or (knee.Hit and knee.Entity)
	local _, loose = Loco.IsBreakable(hitEnt)
	if loose and self:TrySidestepAround(pos, dx, dy, hitEnt) then
		return nil
	end

	return ConsiderHit(self, chest, dist, accept) or ConsiderHit(self, knee, dist, accept)
end

-- Standing at the end of a path that fell short of a goal on our own island:
-- the world holds something the graph does not know (a leaf, a nailed prop,
-- a crate in a doorway). Look toward the goal, a little further than usual.
function Loco:ProbeExhausted(pos)
	local goal = self.Goal
	if not goal then return nil end
	local dx, dy = goal.x - pos.x, goal.y - pos.y
	local l = math_sqrt(dx * dx + dy * dy)
	if l < 1 then return nil end
	local accept = self.P.ExhaustedAccept
	return self:ProbeObstacle(pos, dx / l, dy / l, accept + 16, accept)
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

-- Is a player the thing we are pressing against?
function Loco:IsBlockedByPlayer(pos)
	probeSelf = self.Player
	local dir = self.WishDir
	crowdTrace.start = pos + Vector(0, 0, 4)
	crowdTrace.endpos = Vector(pos.x + dir.x * 40, pos.y + dir.y * 40, pos.z + 4)
	local tr = util_TraceHull(crowdTrace)
	return tr.Hit and IsValid(tr.Entity) and tr.Entity:IsPlayer()
end

-- Does the body sweep along dir hit a brush?
function Loco:WishHitsWorld(pos, dir)
	if not dir or (dir.x == 0 and dir.y == 0) then return false end
	SetProbeContext(self)
	probeTrace.maxs.z = 36
	probeTrace.start = Vector(pos.x, pos.y, pos.z + 8)
	probeTrace.endpos = Vector(pos.x + dir.x * 28, pos.y + dir.y * 28, pos.z + 8)
	local tr = util_TraceHull(probeTrace)
	probeTrace.maxs.z = PROBE_BAND
	if not tr.Hit then return false end
	if tr.HitWorld then return true end
	return IsValid(tr.Entity) and (tr.Entity:IsWorld() or tr.Entity:GetSolid() == SOLID_BSP)
end

-- No progress for StuckTime. Each call is one level up; level 4 is an episode
-- (three episodes make the goal hopeless).
function Loco:Escalate(pos)
	local now = CurTime()
	self.LastEscalation = now
	self.StuckLevel = self.StuckLevel + 1
	local level = self.StuckLevel

	-- A crowd, not geometry: shuffle sideways, never hop, never blame the mesh.
	if self:IsBlockedByPlayer(pos) then
		self:SideStepFor(0.6, self.CrowdSide)
		self.CrowdSide = -self.CrowdSide
		self:Note("stuck:crowd")
		self.StuckLevel = 0
		return
	end

	local dir = self.PathDir
	if dir.x == 0 and dir.y == 0 then dir = self.WishDir end

	if level == 1 then
		local kind = self:ProbeLedge(pos, dir.x, dir.y)
		if kind == LEDGE_JUMP then
			self:Jump()
			self:Note("stuck1:ledge")
		elseif self:ProbeObstacle(pos) then
			self:Note("stuck1:obstacle")
		elseif kind == LEDGE_WALL or self:WishHitsWorld(pos, dir) then
			self:SideStepFor(0.7) -- nothing to jump onto: slide along it
			self:Note("stuck1:wall")
		else
			self:Jump()
			self:Note("stuck1:snag")
		end
	elseif level == 2 then
		self:ProbeObstacle(pos)
		self:SideStepFor(0.7, -self.SideStep)
		if not self:WishHitsWorld(pos, dir) then
			self:Jump()
		end
		self:Note("stuck2")
	elseif level == 3 then
		-- Price what we are stuck on. On the Relapse skin that is the edges
		-- through this spot (a bridge over skipped paint has no cell here); the
		-- cells are the fallback when no edge runs through.
		local Nav = AI.Nav
		local Mesh = AI.Mesh
		local ahead = Vector(pos.x + dir.x * 16, pos.y + dir.y * 16, pos.z)
		local taxed = 0
		if Mesh and Mesh.IsReady and Mesh.IsReady() and Mesh.TaxEdgesThrough then
			taxed = Mesh.TaxEdgesThrough(ahead, self.P.StuckTaxRadius, self.P.StuckTaxTime, Nav.Penalty.Stuck)
		end
		if taxed == 0 then
		Nav.MarkBlockedAt(pos, 20, Nav.Penalty.Stuck)
			Nav.MarkBlockedAt(Vector(pos.x + dir.x * 48, pos.y + dir.y * 48, pos.z), 20, Nav.Penalty.Stuck)
		end
		-- Ask for a way around; keep walking the old path until it arrives.
		self.NeedRepath = true
		self:SideStepFor(0.9, -self.SideStep)
		self:Note("stuck3:mark")
	else
		self.StuckLevel = 0
		self.StuckEpisodes = self.StuckEpisodes + 1
		self:SideStepFor(1.2)
		self:Jump()
		self:Note("stuck4")
	end
end

---------------------------------------------------------------------------
-- Ladders
--
-- The Relapse ladder is E to seat (within 104u of a climb face), W/S to move
-- along the face, E or the strip end to let go. Phases:
--   approach  walk to the foot cell, then into the shaft face
--   mount     E pressed, waiting for the hold flag
--   climb     W (up) or S (down) until the hold drops or the landing Z is reached
--   leave     walk to the landing cell on the far floor
---------------------------------------------------------------------------

function Loco:BeginLadder(segIndex)
	local segs = self.Segments
	local seg = segs and segs[segIndex]
	local nxt = segs and segs[segIndex + 1]
	if not seg or not nxt then return false end
	local ladder = seg.ladder
	local now = CurTime()
	local pos = self.Player:GetPos()
	local up = nxt.pos.z > seg.pos.z
	local cx, cy = seg.pos.x, seg.pos.y
	if AI.Nav.HasLadder(ladder) then
		cx, cy = AI.Nav.LadderCenter(ladder)
	end
	self.Ladder = {
		Ent = ladder,
		Up = up,
		Phase = "approach",
		Since = now,
		PhaseAt = now,
		Foot = Vector(seg.pos),
		Landing = Vector(nxt.pos),
		Shaft = Vector(cx, cy, seg.pos.z),
		Index = segIndex,
		Tries = 0,
		BestZ = pos.z,
		LastGain = now,
		MountAt = 0,
	}
	self:Note("ladder:approach")
	return true
end

function Loco:SetLadderPhase(phase, now)
	local L = self.Ladder
	if not L or L.Phase == phase then return end
	L.Phase = phase
	L.PhaseAt = now
	if phase == "climb" then
		L.BestZ = self.Player:GetPos().z
		L.LastGain = now
	end
	self:Note("ladder:" .. phase)
end

-- Done or given up. success: cursor jumps past the shaft so the walk resumes
-- from the landing; otherwise the ladder is banned and a new path asked for.
function Loco:EndLadder(reason, success)
	local L = self.Ladder
	if not L then return end
	self.Ladder = nil
	if success then
		local segs = self.Segments
		local land = segs and segs[L.Index + 1]
		if land then
			self.Cursor = land.distanceFromStart
			self.SegIndex = math_min(L.Index + 1, #segs)
			self.CursorFloor = land.distanceFromStart
		end
		self:ResetProgress()
		self.StuckLevel = 0
		self:Note("ladder:done")
	elseif reason ~= "stop" then
		self:Note("ladder:abort:" .. reason)
		self.PathValid = false
		self.NextRepath = 0
	end
end

function Loco:AbortLadder(reason)
	local L = self.Ladder
	if not L then return end
	if Holding(self.Player) then
		self:PressUse()
	end
	if AI.Nav.HasLadder(L.Ent) then
		AI.Nav.BanLadder(L.Ent, self.P.LadderBan)
	end
	self:EndLadder(reason, false)
end

function Loco:ThinkLadder(pos, now)
	local L = self.Ladder
	local P = self.P
	local pl = self.Player
	local hold = Holding(pl)
	local phase = L.Phase

	if phase == "approach" then
		if hold then
			self:SetLadderPhase("climb", now)
			return
		end
		if now - L.Since > P.LadderApproachTime then
			self:AbortLadder("approach")
		end
	elseif phase == "mount" then
		if hold then
			self:SetLadderPhase("climb", now)
			return
		end
		if now - L.MountAt > 0.8 then
			if L.Tries >= P.LadderMountTries then
				self:AbortLadder("mount")
				return
			end
			self:SetLadderPhase("approach", now)
		end
	elseif phase == "climb" then
		if not hold then
			-- Let go at the strip end (or knocked off): walk onto the landing.
			self:SetLadderPhase("leave", now)
			return
		end
		local gain = L.Up and (pos.z - L.BestZ) or (L.BestZ - pos.z)
		if gain > 2 then
			L.BestZ = pos.z
			L.LastGain = now
		end
		if now - L.LastGain > P.LadderStallTime then
			self:AbortLadder("stall")
			return
		end
		-- At the landing height and the strip has not let go yet: E releases.
		if now - L.PhaseAt > 0.3 then
			if (L.Up and pos.z >= L.Landing.z - 2) or (not L.Up and pos.z <= L.Landing.z + 2) then
				self:PressUse()
			end
		end
	elseif phase == "leave" then
		if hold then
			self:SetLadderPhase("climb", now)
			return
		end
		local dx, dy = L.Landing.x - pos.x, L.Landing.y - pos.y
		local onFloor = math_abs(L.Landing.z - pos.z) < 40
		local late = now - L.PhaseAt > P.LadderLeaveTime
		if onFloor and (dx * dx + dy * dy <= 32 * 32 or late) then
			-- On the far floor: the walk resumes from the landing cell.
			self:EndLadder("done", true)
			return
		end
		if pl:IsOnGround() and now - L.PhaseAt > 0.5 and math_abs(L.Landing.z - pos.z) >= 48 then
			self:AbortLadder("fell")
			return
		end
		if late then
			self:AbortLadder("leave")
		end
	end
end

-- Buttons while the ladder SM owns the body.
function Loco:StepLadder(cmd, viewYaw, buttons, now, pos)
	local L = self.Ladder
	local pl = self.Player
	local phase = L.Phase
	local hold = Holding(pl)
	local gm = GAMEMODE

	if phase == "climb" or hold then
		self.WishDir:Zero()
		self.PathDir:Zero()
		self.SteerPos = L.Landing
		self.LookPos = Vector(L.Shaft.x, L.Shaft.y, pos.z + 48)
		cmd:SetSideMove(0)
		if L.Up then
			cmd:SetForwardMove(400)
			buttons = bit_bor(buttons, IN_FORWARD)
		else
			cmd:SetForwardMove(-400)
			buttons = bit_bor(buttons, IN_BACK)
		end
		return buttons
	end

	local target
	if phase == "approach" then
		local fx, fy = L.Foot.x - pos.x, L.Foot.y - pos.y
		local atFoot = fx * fx + fy * fy <= 28 * 28 and math_abs(L.Foot.z - pos.z) < 40
		if atFoot or now - L.Since > 1.5 then
			-- Close enough: E seats if a climb face is within reach; else press into the shaft.
			if gm.RelapseLadderIsNear and gm:RelapseLadderIsNear(pl) then
				L.Tries = L.Tries + 1
				L.MountAt = now
				self:PressUse()
				self:SetLadderPhase("mount", now)
				self.WishDir:Zero()
				return buttons
			end
			target = L.Shaft
		else
			target = L.Foot
		end
		self.LookPos = Vector(L.Shaft.x, L.Shaft.y, pos.z + 48)
	elseif phase == "mount" then
		self.WishDir:Zero()
		return buttons
	else -- leave
		target = L.Landing
		self.LookPos = nil
	end

	self.SteerPos = target
	local wx, wy = target.x - pos.x, target.y - pos.y
	local len = math_sqrt(wx * wx + wy * wy)
	if len < 1 then
		self.WishDir:Zero()
		return buttons
	end
	wx, wy = wx / len, wy / len
	self.PathDir.x, self.PathDir.y = wx, wy
	if phase == "leave" then
		wx, wy = self:Slide(pos, wx, wy, target, now)
	end
	self.WishDir.x, self.WishDir.y = wx, wy
	return self:ApplyMove(cmd, buttons, wx, wy, viewYaw)
end

---------------------------------------------------------------------------
-- Steering
---------------------------------------------------------------------------

-- Furthest path point ahead that a body can walk straight to. Throttled: the
-- distance is kept and re-applied from the moving cursor between checks.
function Loco:UpdateLookDist(pos, segs, d, i, cap, now)
	if now < self.NextLook then
		return math_min(self.LookDist, cap)
	end
	self.NextLook = now + 0.1
	local P = self.P
	local speed = self.Player:GetVelocity():Length2D()
	local want = speed * P.LookAheadSpeedMul
	if want < P.LookAheadMin then want = P.LookAheadMin elseif want > P.LookAheadMax then want = P.LookAheadMax end
	if want > cap then want = cap end
	local floor = math_min(P.LookAheadMin * 0.5, cap)
	local look = want
	for _ = 1, 4 do
		local p = PointAt(segs, d + look, i)
		if not p or self:HullClear(pos, p) then break end
		look = look * 0.6
		if look <= floor then
			look = floor
			break
		end
	end
	self.LookDist = look
	return look
end

-- A hop the graph promised. The fourth try at the same launch without getting
-- past it is a paint error: price both cells and ask for another way.
function Loco:HopAt(reason, s, nxt)
	if not self:Jump(reason) then return end
	local key = s.distanceFromStart
	if self.HopKey == key then
		self.HopTries = self.HopTries + 1
	else
		self.HopKey = key
		self.HopTries = 1
	end
	if self.HopTries > 3 then
		local Nav = AI.Nav
		Nav.MarkBlockedAt(s.pos, 30, Nav.Penalty.Stuck)
		if nxt then Nav.MarkBlockedAt(nxt.pos, 30, Nav.Penalty.Stuck) end
		self.NeedRepath = true
		self.HopTries = 0
		self:Note("stuck:" .. reason)
	end
end

-- Jump / duck for the special waypoint we stand at or approach.
function Loco:SpecialAction(s, nxt, pos, ahead, now)
	local P = self.P
	local t = s.type
	if t == SEG_CLIMB and nxt then
		local rise = nxt.pos.z - pos.z
		if rise > P.StepHeight + 2 and rise <= P.JumpHeight + 12 and ahead <= 40 then
			local dx, dy = nxt.pos.x - pos.x, nxt.pos.y - pos.y
			local l = math_sqrt(dx * dx + dy * dy)
			if l > 1 and (ahead <= 24 or self:ProbeLedge(pos, dx / l, dy / l, 48) == LEDGE_JUMP) then
				self:HopAt("climb", s, nxt)
			end
		end
	elseif t == SEG_GAP then
		if ahead <= 12 and ahead >= -8 then
			self:HopAt("gap", s, nxt)
		end
	elseif t == SEG_DROP then
		-- A rail on the lip (graph flagged it): hop it, the fall does the rest.
		if s.hop and ahead <= 12 and ahead >= -28 then
			self:Jump("rail")
		end
	end
end

-- Steer target while following the path. Also owns the cursor and the
-- exhausted flag. Returns nil when the ladder SM took over.
function Loco:PathTarget(pos, now)
	local segs = self.Segments
	local n = #segs
	local P = self.P

	-- Cursor: closest point in a window around the last one; whole path only when far off.
	local i0 = math_max(1, self.SegIndex - 1)
	local i1 = math_min(n, self.SegIndex + 6)
	local d, i, dist2 = ClosestOnPath(segs, pos, i0, i1)
	local off2 = P.OffPathDist * P.OffPathDist
	if dist2 > off2 then
		d, i, dist2 = ClosestOnPath(segs, pos, 1, n)
		self.OffPath = dist2 > off2
	else
		self.OffPath = false
	end
	if self.CursorFloor and d < self.CursorFloor then
		d = self.CursorFloor
		local _, fi = PointAt(segs, d, i)
		i = fi
	end
	self.Cursor = d
	self.SegIndex = i
	local length = self.PathLength

	-- Crouch run here or just ahead: duck before the lintel.
	local here, nxtWp = segs[i], segs[i + 1]
	if (here and here.crouch) or (nxtWp and nxtWp.crouch and nxtWp.distanceFromStart - d <= 64) then
		self:Duck(0.35, "path")
	end

	local target
	local special = NextSpecial(segs, i)
	if special then
		local s = segs[special]
		local nxt = segs[special + 1]
		local sd = s.distanceFromStart
		local ahead = sd - d
		if IsLadderSeg(s) then
			-- Walk to the foot; the SM takes over when close and on that floor.
			local fx, fy = s.pos.x - pos.x, s.pos.y - pos.y
			if fx * fx + fy * fy <= P.LadderNear * P.LadderNear and math_abs(s.pos.z - pos.z) < 48 then
				if self:BeginLadder(special) then
					return nil
				end
			end
			if ahead > 8 then
				local look = self:UpdateLookDist(pos, segs, d, i, ahead, now)
				target = PointAt(segs, d + look, i)
			else
				target = s.pos
			end
		elseif ahead <= 6 then
			-- On the special waypoint: aim at the far side and act.
			target = nxt and nxt.pos or s.pos
			self:SpecialAction(s, nxt, pos, ahead, now)
		else
			local look = self:UpdateLookDist(pos, segs, d, i, ahead, now)
			target = PointAt(segs, d + look, i)
			if s.type == SEG_CLIMB then
				self:SpecialAction(s, nxt, pos, ahead, now)
			end
		end
	else
		local look = self:UpdateLookDist(pos, segs, d, i, length - d, now)
		if d + look >= length then
			target = segs[n].pos
		else
			target = PointAt(segs, d + look, i)
		end
	end

	-- Standing at the end of a path that stops short of the goal.
	if not self.PathReached and d >= length - 4 then
		local e = segs[n].pos
		local dx, dy = e.x - pos.x, e.y - pos.y
		if dx * dx + dy * dy < 40 * 40 and math_abs(e.z - pos.z) < 40 then
			self.Exhausted = true
		end
	end

	self.LookPos = PointAt(segs, math_min(d + self.LookDist + 140, length), i)
	return target
end

-- Bend the wish off a wall the body would push into. A breakable on the way
-- is pressed (the obstacle logic wants contact); a player ahead nudges us
-- sideways; a hoppable curb is jumped instead of slid along.
function Loco:Slide(pos, wx, wy, target, now)
	SetProbeContext(self)
	local lift = self.P.StepHeight + 1
	local reach = self.P.SlideProbe
	slideTrace.start = Vector(pos.x, pos.y, pos.z + lift)
	slideTrace.endpos = Vector(pos.x + wx * reach, pos.y + wy * reach, pos.z + lift)
	local tr = util_TraceHull(slideTrace)
	if not tr.Hit or tr.StartSolid then return wx, wy end

	local ent = tr.Entity
	if IsValid(ent) and ent:IsPlayer() then
		-- Crowd: lean to our side of the lane.
		local s = self.CrowdSide * 0.7
		local nx, ny = wx - wy * s, wy + wx * s
		local nl = math_sqrt(nx * nx + ny * ny)
		return nx / nl, ny / nl
	end

	local n = tr.HitNormal
	if n.z > WALKABLE_Z or n.z < -WALKABLE_Z then return wx, wy end -- floor or ceiling, not a wall

	if IsValid(ent) and not ent:IsWorld() then
		if ent == self.Obstacle then return wx, wy end
		local brk, loose = Loco.IsBreakable(ent)
		if brk and not loose then return wx, wy end
	end

	-- A curb we can hop is jumped, not slid along.
	if self.Player:IsOnGround() and now >= self.NextLedgeProbe then
		self.NextLedgeProbe = now + 0.3
		if self:ProbeLedge(pos, wx, wy, 32) == LEDGE_JUMP then
			self:Jump("ledge")
			return wx, wy
		end
	end

	local dot = wx * n.x + wy * n.y
	local sx, sy = wx - n.x * dot, wy - n.y * dot
	local sl = math_sqrt(sx * sx + sy * sy)
	if sl < 0.25 then
		-- Head-on: take the tangent that leads toward the target. With the
		-- target straight through the wall the sign flips with every wobble and
		-- the body vibrates in place; a side once chosen is kept for a moment.
		local tx, ty = -n.y, n.x
		local side = tx * (target.x - pos.x) + ty * (target.y - pos.y)
		if self.SlideSide ~= 0 and now < self.SlideUntil then
			side = self.SlideSide
		else
			side = side < 0 and -1 or 1
		end
		if side < 0 then
			tx, ty = -tx, -ty
		end
		self.SlideSide = side
		self.SlideUntil = now + self.P.SlideHold
		sx, sy, sl = tx, ty, 1
	else
		self.SlideSide = 0
	end
	sx, sy = sx / sl, sy / sl
	-- A little pressure into the wall keeps the engine's own slide working.
	local fx, fy = sx + wx * 0.15, sy + wy * 0.15
	local fl = math_sqrt(fx * fx + fy * fy)
	return fx / fl, fy / fl
end

-- World-space wish (wx, wy) -> forward/side relative to the view yaw -> cmd.
function Loco:ApplyMove(cmd, buttons, wx, wy, viewYaw)
	local yaw = math_rad(viewYaw)
	local fwd = wx * math_cos(yaw) + wy * math_sin(yaw)
	local side = wx * math_sin(yaw) - wy * math_cos(yaw)

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

---------------------------------------------------------------------------
-- Think (brain rate) / Step (every tick)
---------------------------------------------------------------------------

-- Close, level and clear: walk straight. Otherwise follow the path.
function Loco:ChooseMode(pos)
	local goal = self.Goal
	local P = self.P
	local dx, dy = goal.x - pos.x, goal.y - pos.y
	if dx * dx + dy * dy < P.DirectDist * P.DirectDist and math_abs(goal.z - pos.z) < 28 and self:IsDirectClear(pos, goal) then
		self.Mode = "direct"
	elseif self.Mode == "direct" then
		self.Mode = "path"
	end
end

-- A moving target asks for a new path but keeps walking the old one until it arrives.
function Loco:RequestPath(now)
	if self.Mode ~= "path" then return end
	local goal = self.Goal
	local P = self.P
	local need = false
	if not self.PathValid then
		need = true
	elseif self.PathGoal and self.PathGoal:DistToSqr(goal) > P.GoalMoveRepath * P.GoalMoveRepath then
		need = true
	elseif now - self.PathTime > (self.GoalEnt and P.RepathMoving or P.RepathStatic) then
		need = true
	elseif self.OffPath then
		need = true
	end
	if self.NeedRepath then
		self.NeedRepath = false
		need = true
		self.NextRepath = now
	end
	if need and not self.PathPending and now >= self.NextRepath then
		self.PathPending = true
		self.NextRepath = now + P.RepathMinInterval * (1 + math_min(self.FailedPaths, 6))
		AI.Nav.Request(self.Bot, goal, {Tolerance = self.GoalTol, Profile = self.Bot.Brain.NavProfile})
	end
end

-- Path ended on a closed door: it becomes the obstacle once we are close.
function Loco:ClaimPathDoor(pos)
	local path = self.Path
	local door = path and path.GetDoor and path:GetDoor()
	if door and not self.Obstacle and self.PathValid and pos:DistToSqr(path:GetEnd()) < 80 * 80 then
		if self:DoorBlocks(door, pos) then
			self:SetObstacle(door, false, door:WorldSpaceCenter())
		else
			self:DoorCleared(door)
		end
	end
end

-- Our own island, standing at an end that fell short: find what the graph missed.
function Loco:ClaimExhausted(pos)
	if self.Exhausted and not self.ExhaustedSince then
		self.ExhaustedSince = CurTime()
	end
	if self.Exhausted and not self.IslandCut and not IsValid(self.Obstacle) and self.Mode == "path" then
		self:ProbeExhausted(pos)
	end
end

-- Standing on loose physics: hop off toward an open pad.
function Loco:HopOffProp()
	local on = self:OnLooseProp()
	if not on then return end
	if self.Obstacle == on then self:ClearObstacle(true) end
	if self:LoosePropExit(on) then
		self:Jump("prop:off")
	end
end

-- Stuck detection only while we actually try to move.
function Loco:WatchStuck(pos, now)
	local P = self.P
	local wish = self.WishDir
	local moving = wish.x ~= 0 or wish.y ~= 0
	if self.Hold or self:IsGoalReached() or not moving then
		self:ResetProgress(pos)
		return
	end

	self:ProbeObstacle(pos)

	-- Standing out of an unlocked door's swing is the open, not a stuck.
	local waitDoor = self.Obstacle
	if IsValid(waitDoor) and Loco.DoorOpenable(waitDoor) and self:DoorBlocks(waitDoor, pos) then
		self.ProgressTime = now
		return
	end

	-- Horizontal progress only: hopping in place under a ledge is not progress.
	local px, py = pos.x - self.ProgressPos.x, pos.y - self.ProgressPos.y
	if px * px + py * py > P.ProgressDist * P.ProgressDist then
		self.ProgressPos = pos
		self.ProgressTime = now
		if self.StuckLevel > 0 and now - self.LastEscalation > 2.5 then
			self.StuckLevel = 0
		end
		return
	end

	local combat = self.Bot.Combat
	if combat and combat.InReach then
		self.ProgressTime = now
		return
	end
	-- Airborne (a drop, a hop): the clock runs, the verdict waits for the landing.
	if not self.Player:IsOnGround() then return end

	if now - self.ProgressTime > P.StuckTime then
		self.ProgressTime = now
		self:Escalate(pos)
	end
end

function Loco:Think(dt)
	local pl = self.Player
	local now = CurTime()
	local pos = pl:GetPos()

	if self.Ladder then
		self:ThinkLadder(pos, now)
		if self.Ladder then return end
	elseif Holding(pl) and now >= self.UseUntil + 0.6 then
		-- Seated with no ladder SM (a stray E, or Stop() mid-mount): let go.
		self:PressUse()
		self:Note("ladder:abort:unplanned")
		return
	end

	if self.Mode == "stop" or not self.Goal then
		self.StuckLevel = 0
		return
	end

	local goal = self.Goal
	if self.GoalEnt then
		if IsValid(self.GoalEnt) then
			goal:Set(self.GoalEnt:GetPos())
		else
			self:Stop()
			return
		end
	end
	self.WalkDest = goal

	self:ChooseMode(pos)
	self:RequestPath(now)
	self:ClaimPathDoor(pos)
	self:ClaimExhausted(pos)
	self:TryUseDoor(pos, now)
	self:HopOffProp()
	self:WatchStuck(pos, now)
end

function Loco:Step(cmd, viewYaw, dt)
	local now = CurTime()
	local buttons = 0
	local pl = self.Player
	local pos = pl:GetPos()

	if now < self.JumpUntil then
		buttons = bit_bor(buttons, IN_JUMP)
	end
	if now >= self.DuckFrom and now < self.DuckUntil then
		buttons = bit_bor(buttons, IN_DUCK)
	end
	if now < self.UseUntil then
		buttons = bit_bor(buttons, IN_USE)
	end

	if self.Ladder then
		return self:StepLadder(cmd, viewYaw, buttons, now, pos)
	end

	local goal = self.Goal
	if self.Mode == "stop" or not goal or self.Hold then
		self.WishDir:Zero()
		return buttons
	end

	local target
	if self.Mode == "direct" then
		target = self.WalkDest or goal
		self.LookPos = nil
	elseif self.PathValid and self.Segments then
		target = self:PathTarget(pos, now)
		if not target then
			-- The ladder SM started this tick.
			return self:StepLadder(cmd, viewYaw, buttons, now, pos)
		end
		else
			self.WishDir:Zero()
			return buttons
	end
	self.SteerPos = target

	-- Close enough: stand. Same floor only, or we freeze under a ledge.
	local gdx, gdy = goal.x - pos.x, goal.y - pos.y
	if gdx * gdx + gdy * gdy <= self.GoalTol * self.GoalTol and math_abs(goal.z - pos.z) < 40 then
		self.WishDir:Zero()
		return buttons
	end

	local wx, wy = target.x - pos.x, target.y - pos.y
	local len = math_sqrt(wx * wx + wy * wy)
	if len < 1 then
		wx, wy = 0, 0
	else
		wx, wy = wx / len, wy / len
	end
	self.PathDir.x, self.PathDir.y = wx, wy

	if now < self.SideStepUntil then
		local s = self.SideStep
		wx, wy = -wy * s, wx * s
	elseif pl:IsOnGround() and len >= 1 then
		wx, wy = self:Slide(pos, wx, wy, target, now)
	end
	-- Airborne: push the way the path goes. A hop over a curb needs the body
	-- to keep pressing into it; the engine does its own sliding up there.
	-- An unlocked door replaces this: stand clear of the swing, then E.
	wx, wy = self:OpenDoorWish(pos, wx, wy)

	self.WishDir.x, self.WishDir.y = wx, wy
	if now < self.JumpUntil then
		buttons = bit_bor(buttons, IN_JUMP)
	end
	return self:ApplyMove(cmd, buttons, wx, wy, viewYaw)
end
