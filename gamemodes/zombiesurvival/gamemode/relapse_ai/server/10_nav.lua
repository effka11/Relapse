-- Relapse AI navigation: navmesh readiness, budgeted path computation,
-- per-team cost profiles, temporary "blocked area" memory, nav ladders rebuilt
-- from the BSP and navmesh generation.

local AI = RelapseAI
local Nav = {}
AI.Nav = Nav

local CurTime = CurTime
local SysTime = SysTime
local IsValid = IsValid
local ipairs = ipairs

Nav.BlockedAreas = Nav.BlockedAreas or {} -- [areaID] = {Expiry = time, Penalty = extra path cost in units}
Nav.BadLadders = Nav.BadLadders or {} -- [ladderID] = expiry; a bot failed on it, paths avoid it until then
Nav.LadderDirs = Nav.LadderDirs or {} -- [ladderID] = Vector; facing (away from the wall) of ladders we built
Nav.Ladders = {} -- CNavLadders created on this map load
-- Additive path costs, in distance units: a detour shorter than the penalty wins over the marked area.
Nav.Penalty = {
	Stuck = 500, -- snagged on geometry the mesh does not show
	Barricade = 1400, -- nailed prop in the way: walk up to this much further instead of breaking it
	Unbreakable = 3000, -- hammered for ObstacleTimeout without result (locked door, elevator)
}
Nav.Queue = {} -- pending requests, FIFO
Nav.Pending = {} -- [bot] = request
Nav.Stats = {Computes = 0, Window = 0, WindowStart = 0, ComputesPerSec = 0, LastMs = 0, AvgMs = 0}
Nav.UsePathHost = false -- switched on if the engine refuses a player as the path owner
Nav.Host = nil

---------------------------------------------------------------------------
-- Readiness
---------------------------------------------------------------------------

function Nav.IsReady()
	return navmesh.IsLoaded() and not navmesh.IsGenerating()
end

function Nav.Status()
	if navmesh.IsGenerating() then
		return "generating"
	end
	if not navmesh.IsLoaded() then
		return "missing (maps/" .. game.GetMap() .. ".nav)"
	end
	return string.format("loaded, %d areas", navmesh.GetNavAreaCount())
end

---------------------------------------------------------------------------
-- Cost profiles
---------------------------------------------------------------------------

Nav.Profiles = {
	zombie = {
		StepHeight = 18,
		JumpHeight = 60, -- duck-jump ledge (185 jump power, 600 gravity)
		JumpMul = 2.5,
		JumpCost = 60, -- flat cost per jump connection
		CrouchMul = 1.5,
		AvoidMul = 4,
		PenaltyMul = 1, -- scales Nav.Penalty
		Ladders = true,
		LadderMul = 1.5, -- per unit of ladder length (climbing is slower than running)
		LadderCost = 80, -- flat: lining up with the rungs
	},
	human = {
		StepHeight = 18,
		JumpHeight = 56,
		JumpMul = 3,
		JumpCost = 80,
		CrouchMul = 1.5,
		AvoidMul = 6,
		PenaltyMul = 3, -- humans do not break barricades
		Ladders = true,
		LadderMul = 2,
		LadderCost = 120,
	},
}

local costCache = {}

local function MakeCostFunction(profile)
	local stepHeight = profile.StepHeight
	local jumpHeight = profile.JumpHeight
	local jumpMul = profile.JumpMul
	local jumpCost = profile.JumpCost or 0
	local crouchMul = profile.CrouchMul
	local avoidMul = profile.AvoidMul
	local penaltyMul = profile.PenaltyMul or 1
	local ladders = profile.Ladders
	local ladderMul = profile.LadderMul or 2
	local ladderCost = profile.LadderCost or 0
	local blocked = Nav.BlockedAreas
	local badLadders = Nav.BadLadders
	local maxDropVar = AI.cv.max_drop
	local navBlocker = NAV_MESH_NAV_BLOCKER or 0

	return function(area, fromArea, ladder, elevator, length)
		if not IsValid(fromArea) then
			return 0 -- first area
		end

		if IsValid(ladder) then
			if not ladders then return -1 end
			local bad = badLadders[ladder:GetID()]
			if bad then
				if bad > CurTime() then return -1 end
				badLadders[ladder:GetID()] = nil
			end
			return ladder:GetLength() * ladderMul + ladderCost + fromArea:GetCostSoFar()
		end

		if navBlocker ~= 0 and area:HasAttributes(navBlocker) then
			return -1
		end

		local dist
		if length > 0 then
			dist = length
		else
			dist = area:GetCenter():Distance(fromArea:GetCenter())
		end

		local cost = dist

		local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange(area)
		if deltaZ >= stepHeight then
			if deltaZ > jumpHeight then
				return -1
			end
			-- Flat part: a hop is slow and breaks the run even for a small ledge, so a slightly longer flat route wins.
			cost = cost + dist * jumpMul + jumpCost
		elseif deltaZ < -maxDropVar:GetFloat() then
			return -1
		end

		if area:HasAttributes(NAV_MESH_AVOID) then
			cost = cost * avoidMul
		end
		if area:HasAttributes(NAV_MESH_CROUCH) then
			cost = cost * crouchMul
		end

		local entry = blocked[area:GetID()]
		if entry then
			if entry.Expiry > CurTime() then
				cost = cost + entry.Penalty * penaltyMul
			else
				blocked[area:GetID()] = nil
			end
		end

		return cost + fromArea:GetCostSoFar()
	end
end

function Nav.GetCostFunction(name)
	local fn = costCache[name]
	if not fn then
		local profile = Nav.Profiles[name] or Nav.Profiles.zombie
		fn = MakeCostFunction(profile)
		costCache[name] = fn
	end
	return fn
end

---------------------------------------------------------------------------
-- Blocked areas (learned barricades)
---------------------------------------------------------------------------

-- Marks stack by taking the later expiry and the larger penalty.
function Nav.MarkBlockedArea(area, duration, penalty)
	if not IsValid(area) then return end
	local id = area:GetID()
	local expiry = CurTime() + (duration or 20)
	penalty = penalty or Nav.Penalty.Stuck

	local entry = Nav.BlockedAreas[id]
	if entry then
		if expiry > entry.Expiry then entry.Expiry = expiry end
		if penalty > entry.Penalty then entry.Penalty = penalty end
	else
		Nav.BlockedAreas[id] = {Expiry = expiry, Penalty = penalty, Since = CurTime()}
	end
	return area
end

function Nav.MarkBlockedAt(pos, duration, penalty)
	local area = navmesh.GetNearestNavArea(pos, false, 200, false, true)
	return Nav.MarkBlockedArea(area, duration, penalty)
end

-- When the area at pos first got a penalty of at least minPenalty (nil if none is active).
-- A path computed after that already paid for it, so there is no point asking for a detour again.
function Nav.BlockedSince(pos, minPenalty)
	local area = navmesh.GetNearestNavArea(pos, false, 200, false, true)
	if not IsValid(area) then return nil end
	local entry = Nav.BlockedAreas[area:GetID()]
	if entry and entry.Expiry > CurTime() and entry.Penalty >= (minPenalty or 0) then
		return entry.Since
	end
	return nil
end

function Nav.UnmarkArea(areaOrID)
	local id = areaOrID
	if not isnumber(id) then
		if not IsValid(id) then return end
		id = id:GetID()
	end
	Nav.BlockedAreas[id] = nil
end

function Nav.IsAreaBlocked(area)
	if not IsValid(area) then return false end
	local entry = Nav.BlockedAreas[area:GetID()]
	return entry ~= nil and entry.Expiry > CurTime()
end

function Nav.GetAreaAt(pos, beneath)
	return navmesh.GetNavArea(pos, beneath or 32)
end

-- Random reachable-ish point around pos for wandering.
function Nav.RandomPointNear(pos, radius)
	local areas = navmesh.Find(pos, radius or 600, 64, AI.cv.max_drop:GetFloat())
	if #areas == 0 then return nil end
	local area = areas[math.random(#areas)]
	if not IsValid(area) then return nil end
	return area:GetRandomPoint()
end

-- Snap a rough position to the navmesh so paths end on walkable ground.
function Nav.SnapToMesh(pos, maxDist)
	local area = navmesh.GetNearestNavArea(pos, true, maxDist or 400, false, true)
	if IsValid(area) then
		return area:GetClosestPointOnArea(pos)
	end
	return pos
end

---------------------------------------------------------------------------
-- Ladders
--
-- GMod's generator builds no ladders: VBSP turns every func_ladder into an
-- info_ladder entity in the BSP and GMod does not know that class, so the
-- generated mesh has no way up a shaft. Read the boxes back from the entity
-- lump and create nav ladders on every map load (not saved to the .nav).
---------------------------------------------------------------------------

local function EntityKey(block, key)
	return tonumber(string.match(block, '"' .. key .. '" "([^"]+)"'))
end

-- Boxes of the map's func_ladder brushes: {mins = Vector, maxs = Vector}.
function Nav.LoadMapLadders()
	local f = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME")
	if not f then return {} end

	-- Lump 0 (entities) header follows the 8-byte ident/version.
	f:Seek(8)
	local ofs = f:ReadLong()
	local len = f:ReadLong()
	local data
	if ofs and len and ofs > 0 and len > 0 and len < 64 * 1024 * 1024 then
		f:Seek(ofs)
		data = f:Read(len)
	end
	f:Close()
	if not data then return {} end

	local boxes = {}
	for block in string.gmatch(data, "{(.-)}") do
		if string.find(block, '"classname" "info_ladder"', 1, true) then
			local x0, y0, z0 = EntityKey(block, "mins%.x"), EntityKey(block, "mins%.y"), EntityKey(block, "mins%.z")
			local x1, y1, z1 = EntityKey(block, "maxs%.x"), EntityKey(block, "maxs%.y"), EntityKey(block, "maxs%.z")
			if x0 and y0 and z0 and x1 and y1 and z1 then
				boxes[#boxes + 1] = {
					mins = Vector(math.min(x0, x1), math.min(y0, y1), math.min(z0, z1)),
					maxs = Vector(math.max(x0, x1), math.max(y0, y1), math.max(z0, z1)),
				}
			end
		end
	end
	return boxes
end

local ladderTrace = {mask = MASK_PLAYERSOLID_BRUSHONLY}

-- Is there a wall along the whole height on this side of the ladder?
local function SideBlocked(cx, cy, z0, z1, dir, off)
	ladderTrace.start = Vector(cx + dir.x * off, cy + dir.y * off, z0)
	ladderTrace.endpos = Vector(cx + dir.x * off, cy + dir.y * off, z1)
	local tr = util.TraceLine(ladderTrace)
	return tr.StartSolid or tr.Fraction < 1
end

local function HasGroundNear(x, y, z, dir)
	return IsValid(navmesh.GetNearestNavArea(Vector(x + dir.x * 40, y + dir.y * 40, z + 8), false, 120, false, true))
end

-- Height of the highest nav area next to the ladder's upper part: where climbers get off.
local function FindTopZ(cx, cy, halfWidth, mins, maxs)
	local pad = halfWidth + 40
	local areas = navmesh.FindInBox(Vector(cx - pad, cy - pad, mins.z + 48), Vector(cx + pad, cy + pad, maxs.z + 24))
	local best
	local probe = Vector(cx, cy, maxs.z)
	for _, area in ipairs(areas) do
		if IsValid(area) then
			local z = area:GetClosestPointOnArea(probe).z
			if not best or z > best then best = z end
		end
	end
	return best
end

local function CreateLadderFromBox(box, existing)
	local mins, maxs = box.mins, box.maxs
	local sx, sy = maxs.x - mins.x, maxs.y - mins.y
	local height = maxs.z - mins.z
	if height < 40 or sx < 1 or sy < 1 then return nil, "too small" end

	local cx, cy = (mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5
	local width, thickness, dirs
	if sx >= sy then
		width, thickness = sx, sy
		dirs = {Vector(0, 1, 0), Vector(0, -1, 0)}
	else
		width, thickness = sy, sx
		dirs = {Vector(1, 0, 0), Vector(-1, 0, 0)}
	end

	-- Same ladder already in the mesh (hand-built, or a split brush).
	for _, l in ipairs(existing) do
		local b = l:GetBottom()
		local dx, dy = b.x - cx, b.y - cy
		if dx * dx + dy * dy < 40 * 40 and math.abs(b.z - mins.z) < 96 then
			return nil, "duplicate"
		end
	end

	-- The open side is where the climber stands; the other has the wall.
	local off = thickness * 0.5 + 12
	local z0, z1 = mins.z + 12, maxs.z - 12
	local open = {}
	for _, d in ipairs(dirs) do
		if not SideBlocked(cx, cy, z0, z1, d, off) then
			open[#open + 1] = d
		end
	end
	local dir
	if #open == 1 then
		dir = open[1]
	elseif #open == 2 then
		for _, d in ipairs(open) do
			if HasGroundNear(cx, cy, mins.z, d) then
				dir = d
				break
			end
		end
		dir = dir or open[1]
	else
		return nil, "walled in"
	end

	-- Ladder line on the front face; top at the exit ledge, not the brush top.
	local fx, fy = cx + dir.x * thickness * 0.5, cy + dir.y * thickness * 0.5
	local topZ = FindTopZ(cx, cy, width * 0.5, mins, maxs) or maxs.z
	if topZ < mins.z + 40 then topZ = maxs.z end
	local top = Vector(fx, fy, topZ)
	local bottom = Vector(fx, fy, mins.z)

	local ladder = navmesh.CreateNavLadder(top, bottom, width, dir, 64)
	if not IsValid(ladder) then return nil, "engine refused" end

	Nav.LadderDirs[ladder:GetID()] = dir
	return ladder
end

-- Facing of a ladder (away from the wall, toward the climber).
function Nav.LadderNormal(ladder)
	local dir = Nav.LadderDirs[ladder:GetID()]
	if dir then return dir end
	local n = ladder:GetNormal()
	if n:LengthSqr() < 0.5 then return Vector(1, 0, 0) end
	n = Vector(n.x, n.y, 0)
	n:Normalize()
	return n
end

function Nav.BanLadder(ladder, duration)
	if not IsValid(ladder) then return end
	Nav.BadLadders[ladder:GetID()] = CurTime() + (duration or 30)
end

function Nav.GetAllLadders()
	local list = {}
	for id = 1, 1024 do
		local l = navmesh.GetNavLadderByID(id)
		if IsValid(l) then list[#list + 1] = l end
	end
	return list
end

-- Returns ladders created, ladder brushes found.
function Nav.BuildLadders()
	if not navmesh.IsLoaded() then return 0, 0 end
	local boxes = Nav.LoadMapLadders()
	if #boxes == 0 then return 0, 0 end

	local existing = Nav.GetAllLadders()
	local made, skipped = 0, {}
	for _, box in ipairs(boxes) do
		local ladder, why = CreateLadderFromBox(box, existing)
		if ladder then
			made = made + 1
			existing[#existing + 1] = ladder
			Nav.Ladders[#Nav.Ladders + 1] = ladder
		else
			skipped[why] = (skipped[why] or 0) + 1
		end
	end

	local parts = {}
	for why, n in pairs(skipped) do parts[#parts + 1] = n .. " " .. why end
	AI.Log("nav ladders: built %d of %d info_ladder brushes%s", made, #boxes,
		#parts > 0 and (" (skipped: " .. table.concat(parts, ", ") .. ")") or "")
	return made, #boxes
end

---------------------------------------------------------------------------
-- Path host fallback (only used if Path:Compute rejects a player nextbot)
---------------------------------------------------------------------------

do
	local ENT = {}
	ENT.Type = "nextbot"
	ENT.Base = "base_nextbot"
	ENT.IsRelapseAIPathHost = true

	function ENT:Initialize()
		self:AddEFlags(bit.bor(EFL_SERVER_ONLY, EFL_FORCE_CHECK_TRANSMIT))
		if self.BaseClass and self.BaseClass.Initialize then
			self.BaseClass.Initialize(self)
		end
		self:DrawShadow(false)
		self:SetModel("models/player/zombie_classic.mdl")
		self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetNoDraw(true)
		self.loco:SetStepHeight(18)
		self.loco:SetJumpHeight(60)
		self.loco:SetDeathDropHeight(200)
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_NONE
	end

	function ENT:RunBehaviour()
	end

	scripted_ents.Register(ENT, "relapse_ai_pathhost")
end

function Nav.GetHost(pl)
	if not Nav.UsePathHost then
		return pl
	end

	local host = Nav.Host
	if not IsValid(host) then
		host = ents.Create("relapse_ai_pathhost")
		if not IsValid(host) then return pl end
		host:Spawn()
		Nav.Host = host
	end

	host:SetPos(pl:GetPos())
	return host
end

---------------------------------------------------------------------------
-- Path requests
---------------------------------------------------------------------------

function Nav.Request(bot, goal, opts)
	opts = opts or {}

	local req = Nav.Pending[bot]
	if req then
		req.Goal:Set(goal)
		req.Opts = opts
		return req
	end

	req = {Bot = bot, Goal = Vector(goal), Opts = opts, Time = CurTime()}
	Nav.Pending[bot] = req
	Nav.Queue[#Nav.Queue + 1] = req
	return req
end

function Nav.Cancel(bot)
	local req = Nav.Pending[bot]
	if req then
		req.Cancelled = true
		Nav.Pending[bot] = nil
	end
end

function Nav.ComputeNow(bot, goal, opts)
	local pl = bot.Player
	local path = bot.Path
	if not path then
		path = Path("Follow")
		bot.Path = path
	end

	path:SetMinLookAheadDistance(opts.LookAhead or 120)
	path:SetGoalTolerance(opts.Tolerance or 24)

	local costfn = Nav.GetCostFunction(opts.Profile or bot.Brain.NavProfile or "zombie")
	local host = Nav.GetHost(pl)

	local t0 = SysTime()
	local ok, reached = pcall(path.Compute, path, host, goal, costfn)
	if not ok and not Nav.UsePathHost then
		AI.Log("Path:Compute rejected the player (%s); using a helper nextbot as path host", tostring(reached))
		Nav.UsePathHost = true
		host = Nav.GetHost(pl)
		ok, reached = pcall(path.Compute, path, host, goal, costfn)
	end
	if not ok then
		AI.Warn("Path:Compute failed: %s", tostring(reached))
		reached = false
	end

	local ms = (SysTime() - t0) * 1000
	local stats = Nav.Stats
	stats.Computes = stats.Computes + 1
	stats.Window = stats.Window + 1
	stats.LastMs = ms
	stats.AvgMs = stats.AvgMs + (ms - stats.AvgMs) * 0.1

	bot.Loco:OnPathResult(path, ok and reached == true, goal)
end

-- Called every server tick by the manager.
function Nav.Process()
	local now = CurTime()
	local stats = Nav.Stats
	if now - stats.WindowStart >= 1 then
		stats.ComputesPerSec = stats.Window / math.max(0.001, now - stats.WindowStart)
		stats.Window = 0
		stats.WindowStart = now
	end

	local queue = Nav.Queue
	if #queue == 0 then return end
	if not Nav.IsReady() then
		-- Drop everything; callers retry on their own schedule.
		for _, req in ipairs(queue) do
			Nav.Pending[req.Bot] = nil
		end
		Nav.Queue = {}
		return
	end

	local budget = math.max(1, AI.cv.path_budget:GetInt())
	local done = 0
	while done < budget and #queue > 0 do
		local req = table.remove(queue, 1)
		if not req.Cancelled and Nav.Pending[req.Bot] == req then
			Nav.Pending[req.Bot] = nil
			local bot = req.Bot
			if IsValid(bot.Player) and bot.Player:Alive() then
				Nav.ComputeNow(bot, req.Goal, req.Opts)
				done = done + 1
			end
		end
	end
end

---------------------------------------------------------------------------
-- Generation
---------------------------------------------------------------------------

-- Doors and breakables hide rooms from the generator; barricades must not be baked in.
function Nav.PrepareMapForGeneration()
	for _, class in ipairs({"func_door*", "prop_door*"}) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			ent:Fire("unlock", "", 0)
			ent:Fire("open", "", 0)
			ent:Fire("kill", "", 1)
		end
	end

	for _, class in ipairs({"prop_physics*", "func_breakable", "func_breakable_surf", "func_physbox*", "prop_ragdoll"}) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			ent:Remove()
		end
	end

	navmesh.ClearWalkableSeeds()

	local up = Vector(0, 0, 1)
	local lift = Vector(0, 0, 2)
	local seeds = 0
	local function Seed(pos)
		navmesh.AddWalkableSeed(pos + lift, up)
		seeds = seeds + 1
	end

	for _, teamid in ipairs({TEAM_HUMAN, TEAM_UNDEAD}) do
		for _, ent in ipairs(team.GetValidSpawnPoint(teamid)) do
			Seed(ent:GetPos())
		end
	end

	for _, ent in ipairs(ents.FindByClass("info_sigilnode")) do
		Seed(ent:GetPos())
	end

	for _, node in ipairs(GAMEMODE.ProfilerNodes or {}) do
		if isvector(node) then
			Seed(node)
		end
	end

	return seeds
end

function Nav.Generate(reason)
	if navmesh.IsGenerating() then
		return false, "already generating"
	end
	if Nav.GenerationStarted and CurTime() - Nav.GenerationStarted < 10 then
		return false, "generation is starting"
	end

	local seeds = Nav.PrepareMapForGeneration()
	Nav.GenerationStarted = CurTime()
	AI.Log("navmesh generation for %s (%s), %d walkable seeds. The server is unplayable until the map reloads.", game.GetMap(), reason or "manual", seeds)

	timer.Simple(1.5, function()
		navmesh.BeginGeneration()
	end)

	return true
end

hook.Add("InitPostEntity", "RelapseAI.NavAutogen", function()
	timer.Simple(10, function()
		if not GAMEMODE or not AI.cv.nav_autogen:GetBool() then return end
		if game.SinglePlayer() then return end
		if navmesh.IsLoaded() or navmesh.IsGenerating() then return end

		if AI.HasRealPlayer() then
			AI.Log("no navmesh for %s and players are online; run relapse_ai_nav_generate when ready", game.GetMap())
			return
		end

		Nav.Generate("autogen: empty server, no .nav")
	end)
end)

-- Post-processing once a mesh is available: ladders from the BSP, bots out of trigger_hurt volumes.
hook.Add("InitPostEntity", "RelapseAI.NavPostProcess", function()
	timer.Simple(2, function()
		if not navmesh.IsLoaded() then return end

		local okLadders, err = pcall(Nav.BuildLadders)
		if not okLadders then
			AI.Warn("nav ladder build failed: %s", tostring(err))
		end

		local marked = 0
		for _, hurt in ipairs(ents.FindByClass("trigger_hurt")) do
			local mins, maxs = hurt:WorldSpaceAABB()
			if mins and maxs then
				local pad = Vector(24, 24, 48)
				for _, area in ipairs(navmesh.FindInBox(mins - pad, maxs + pad)) do
					if IsValid(area) and not area:HasAttributes(NAV_MESH_AVOID) then
						area:SetAttributes(bit.bor(area:GetAttributes(), NAV_MESH_AVOID))
						marked = marked + 1
					end
				end
			end
		end

		if marked > 0 then
			AI.Log("marked %d nav areas near trigger_hurt as AVOID", marked)
		end
	end)
end)

---------------------------------------------------------------------------
-- Console
---------------------------------------------------------------------------

local function Reply(pl, msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
	end
	print(msg)
end

local function IsAllowed(pl)
	return not IsValid(pl) or pl:IsSuperAdmin()
end

concommand.Add("relapse_ai_nav_status", function(pl)
	Reply(pl, string.format("[Relapse AI] navmesh: %s | ladders: %d (%d built from the BSP) | blocked areas: %d | path computes/s: %.1f (avg %.2f ms)",
		Nav.Status(), #Nav.GetAllLadders(), #Nav.Ladders, table.Count(Nav.BlockedAreas), Nav.Stats.ComputesPerSec, Nav.Stats.AvgMs))
end)

concommand.Add("relapse_ai_nav_ladders", function(pl)
	if not IsAllowed(pl) then return end
	for _, ladder in ipairs(Nav.GetAllLadders()) do
		local b, t = ladder:GetBottom(), ladder:GetTop()
		local n = Nav.LadderNormal(ladder)
		Reply(pl, string.format("  #%d bottom (%.0f %.0f %.0f) top z %.0f len %.0f width %.0f facing (%d %d) bottomArea=%s topFwd=%s topBehind=%s topL=%s topR=%s%s",
			ladder:GetID(), b.x, b.y, b.z, t.z, ladder:GetLength(), ladder:GetWidth(), n.x, n.y,
			IsValid(ladder:GetBottomArea()) and "ok" or "-", IsValid(ladder:GetTopForwardArea()) and "ok" or "-",
			IsValid(ladder:GetTopBehindArea()) and "ok" or "-", IsValid(ladder:GetTopLeftArea()) and "ok" or "-",
			IsValid(ladder:GetTopRightArea()) and "ok" or "-",
			(Nav.BadLadders[ladder:GetID()] or 0) > CurTime() and " BANNED" or ""))
	end
end)

concommand.Add("relapse_ai_nav_generate", function(pl)
	if not IsAllowed(pl) then return end

	local ok, err = Nav.Generate(IsValid(pl) and ("command by " .. pl:Nick()) or "server console")
	if ok then
		Reply(pl, "[Relapse AI] navmesh generation started; the map reloads when it is done.")
	else
		Reply(pl, "[Relapse AI] navmesh generation not started: " .. tostring(err))
	end
end)
