-- Relapse mesh graph: 8-neighbor walk links, A*, path through cell centres.
-- Centres stay inside the paint; a taut string hugged cliff lips. Ladder shafts
-- are extra edges (bottom cell ↔ top cell) so two roofs at the same Z still
-- connect: down, walk, up. Source .nav is fallback until this graph is linked
-- (relapse_ai_mesh_path 0 to stay on .nav).

local AI = RelapseAI
local Mesh = AI.Mesh
if not Mesh then return end

local Nav = AI.Nav
local SysTime = SysTime
local CurTime = CurTime
local IsValid = IsValid

local cvUse = CreateConVar("relapse_ai_mesh_path", "1", FCVAR_NOTIFY, "1 = bots walk the Relapse skin, 0 = Source .nav.")
local cvBudget = CreateConVar("relapse_ai_mesh_link_ms", "4", FCVAR_NOTIFY, "Milliseconds per tick to link mesh cells.")

local SEG_GROUND = 0
local SEG_DROP = 1
local SEG_CLIMB = 2
local SEG_LADDER_UP = 4
local SEG_LADDER_DOWN = 5

local WALK_Z = 22
local JUMP_Z = 68 -- 64u crate + sample lift; loco duck-jump
local DROP_Z = 200
local MAX_EXPAND = 14000
Mesh.JumpZ = JUMP_Z

-- Linking is centre-to-centre. A fat hull + side-ground test (meant for string
-- pull) dropped almost every neighbour, A* failed, and IsReady still blocked
-- the .nav fallback — zombies stood still.
local LINK_HULL = 10
local linkRes, groundRes = {}, {}
local linkStart, linkEnd = Vector(), Vector()
local linkTr = {
	mask = MASK_PLAYERSOLID_BRUSHONLY,
	output = linkRes,
	mins = Vector(-LINK_HULL, -LINK_HULL, 0),
	maxs = Vector(LINK_HULL, LINK_HULL, 28),
	start = linkStart,
	endpos = linkEnd,
}
local groundTr = {
	mask = MASK_PLAYERSOLID_BRUSHONLY,
	output = groundRes,
	start = linkStart,
	endpos = linkEnd,
}

Mesh.Blocked = Mesh.Blocked or {}
Mesh.LinkCount = Mesh.LinkCount or 0
Mesh.Linked = Mesh.Linked or false

local function CellSize()
	return Mesh.CellSize or 40
end

function Mesh.IsReady()
	if cvUse:GetInt() <= 0 then return false end
	return Mesh.Linked == true and not Mesh.Building and not Mesh.Linking
		and Mesh.Cells and #Mesh.Cells > 0 and (Mesh.LinkCount or 0) > 0
end

local function GridGet(gx, gy)
	local col = Mesh.Grid and Mesh.Grid[gx]
	return col and col[gy]
end

local function GridAdd(gx, gy, i)
	local grid = Mesh.Grid
	local col = grid[gx]
	if not col then
		col = {}
		grid[gx] = col
	end
	local bucket = col[gy]
	if not bucket then
		bucket = {}
		col[gy] = bucket
	end
	bucket[#bucket + 1] = i
end

local function BestInBucket(gx, gy, z, skip)
	local bucket = GridGet(gx, gy)
	if not bucket then return nil end
	local best, bestDz
	for i = 1, #bucket do
		local j = bucket[i]
		if j ~= skip then
			local dz = math.abs(Mesh.Cells[j].pos.z - z)
			if not best or dz < bestDz then
				best, bestDz = j, dz
			end
		end
	end
	return best, bestDz
end

local function Classify(a, b, cell)
	local dz = b.pos.z - a.pos.z
	local adz = math.abs(dz)
	-- Samples sit on flat treads, so n.z ≈ 1 even on a 35° stair. A 40u cell
	-- on that run rises ~28u — still a walk, not a crate hop.
	if adz <= math.max(WALK_Z, cell * 1.05) then
		return "walk", SEG_GROUND
	end
	if dz > WALK_Z and dz <= JUMP_Z then
		return "jump", SEG_CLIMB
	end
	if dz < -WALK_Z and adz <= DROP_Z then
		return "drop", SEG_DROP
	end
	return nil
end

local function GroundOK(x, y, z)
	linkStart:SetUnpacked(x, y, z + 24)
	linkEnd:SetUnpacked(x, y, z - 72)
	groundTr.start = linkStart
	groundTr.endpos = linkEnd
	util.TraceLine(groundTr)
	if not groundRes.Hit or groundRes.HitSky then
		return false
	end
	return math.abs(groundRes.HitPos.z - z) <= 36
end

-- Neighbour test: walk uses a centreline hull. Jump cannot — that hull hits the
-- face of the crate. Jump: headroom at takeoff, crouched sweep at lip height.
-- Always pass the lower cell as (ax,ay,az).
local function AdjacentOK(ax, ay, az, bx, by, bz, kind)
	if kind == "jump" then
		linkStart:SetUnpacked(ax, ay, az + 8)
		linkEnd:SetUnpacked(ax, ay, math.max(az + JUMP_Z + 4, bz + 8))
		linkTr.start = linkStart
		linkTr.endpos = linkEnd
		util.TraceHull(linkTr)
		if linkRes.StartSolid or linkRes.Hit then
			return false
		end
		local lip = bz + 4
		linkStart:SetUnpacked(ax, ay, lip)
		linkEnd:SetUnpacked(bx, by, lip)
		util.TraceHull(linkTr)
		if linkRes.StartSolid then
			return false
		end
		-- Clipping the pad top is fine; a wall or railing is not.
		if linkRes.Hit and (not linkRes.HitNormal or linkRes.HitNormal.z < 0.7) then
			return false
		end
		return GroundOK(bx, by, bz)
	end

	local lift = 24
	linkStart:SetUnpacked(ax, ay, az + lift)
	linkEnd:SetUnpacked(bx, by, bz + lift)
	linkTr.start = linkStart
	linkTr.endpos = linkEnd
	util.TraceHull(linkTr)
	if linkRes.StartSolid then
		linkStart.z = az + 32
		linkEnd.z = bz + 32
		util.TraceHull(linkTr)
	end
	if linkRes.StartSolid then
		return false
	end
	-- A ramp/stair chord sits in the slope. Hitting the walkable skin is fine.
	if linkRes.Hit and (not linkRes.HitNormal or linkRes.HitNormal.z < 0.7) then
		return false
	end
	if kind == "drop" then
		return true
	end
	return GroundOK((ax + bx) * 0.5, (ay + by) * 0.5, (az + bz) * 0.5)
end

local function AddEdge(i, j, cost, kind, segType)
	local a, b = Mesh.Cells[i], Mesh.Cells[j]
	if kind == "jump" then
		local lo, hi = i, j
		if b.pos.z < a.pos.z then
			lo, hi = j, i
		end
		local low, high = Mesh.Cells[lo], Mesh.Cells[hi]
		low.nbs[#low.nbs + 1] = {j = hi, cost = cost + 55, kind = "jump", seg = SEG_CLIMB}
		high.nbs[#high.nbs + 1] = {j = lo, cost = cost, kind = "drop", seg = SEG_DROP}
	else
		a.nbs[#a.nbs + 1] = {j = j, cost = cost, kind = kind, seg = segType}
		b.nbs[#b.nbs + 1] = {j = i, cost = cost, kind = kind, seg = segType}
	end
	Mesh.LinkCount = Mesh.LinkCount + 1
end

local function AddLadderEdge(lo, hi, ladder, rise)
	local low, high = Mesh.Cells[lo], Mesh.Cells[hi]
	if not low or not high or lo == hi then return false end
	local costUp = rise * 1.5 + 80
	local costDown = rise + 40
	low.nbs[#low.nbs + 1] = {j = hi, cost = costUp, kind = "ladder", seg = SEG_LADDER_UP, ladder = ladder}
	high.nbs[#high.nbs + 1] = {j = lo, cost = costDown, kind = "ladder", seg = SEG_LADDER_DOWN, ladder = ladder}
	Mesh.LinkCount = Mesh.LinkCount + 1
	return true
end

local function StripLadderNbs()
	local cells = Mesh.Cells
	for i = 1, #cells do
		local nbs = cells[i].nbs
		if nbs then
			local o = 1
			for n = 1, #nbs do
				if nbs[n].kind ~= "ladder" then
					nbs[o] = nbs[n]
					o = o + 1
				end
			end
			for n = #nbs, o, -1 do
				nbs[n] = nil
			end
		end
	end
end

-- Shafts become graph edges so A* can chain two ladders (down, street, up)
-- between same-Z roofs. Snap each end to a cell on that floor, not the ground
-- under the rungs.
function Mesh.LinkLadders()
	if not Nav or not Mesh.Cells or #Mesh.Cells == 0 or not Mesh.Grid then
		return 0
	end
	StripLadderNbs()
	local list = Nav.Climbables
	if not list or #list == 0 then
		list = Nav.GetAllLadders and Nav.GetAllLadders() or {}
	end
	local n = 0
	for i = 1, #list do
		local ladder = list[i]
		if Nav.HasLadder(ladder) and (not Nav.IsShaft or Nav.IsShaft(ladder)) then
			local b, t = ladder:GetBottom(), ladder:GetTop()
			if b and t then
				local rise = math.abs(t.z - b.z)
				local snapD, snapZ = 220, 56
				if rise > 120 then
					snapD, snapZ = 360, 96
				end
				local lo = Mesh.NearestOnFloor(b, snapD, snapZ) or Mesh.Nearest(b, snapD, snapZ) or Mesh.Nearest(b, snapD)
				local hi = Mesh.NearestOnFloor(t, snapD, snapZ) or Mesh.Nearest(t, snapD, snapZ) or Mesh.Nearest(t, snapD)
				if lo and hi and lo.i ~= hi.i then
					if lo.pos.z > hi.pos.z then
						lo, hi = hi, lo
					end
					if AddLadderEdge(lo.i, hi.i, ladder, math.abs(t.z - b.z)) then
						n = n + 1
					end
				end
			end
		end
	end
	Mesh.LadderCount = n
	AI.Log("mesh ladders %d shafts", n)
	return n
end

local function LinkCell(i)
	local cells = Mesh.Cells
	local a = cells[i]
	local cell = CellSize()
	local maxDz = math.max(JUMP_Z, DROP_Z)
	local offsets = {
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1}, {0, 0}, {0, 1},
		{1, -1}, {1, 0}, {1, 1},
	}
	for o = 1, #offsets do
		local bucket = GridGet(a.gx + offsets[o][1], a.gy + offsets[o][2])
		if bucket then
			for bi = 1, #bucket do
				local j = bucket[bi]
				if j > i then
					local b = cells[j]
					if math.abs(b.pos.z - a.pos.z) <= maxDz then
						local kind, segType = Classify(a, b, cell)
						if kind then
							local dx, dy, dz = b.pos.x - a.pos.x, b.pos.y - a.pos.y, b.pos.z - a.pos.z
							local flat = math.sqrt(dx * dx + dy * dy)
							local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
							local maxFlat = (kind == "walk") and (cell * 1.8) or (cell * 1.55)
							if dist > 1 and flat <= maxFlat then
								local ok
								if kind == "walk" then
									ok = AdjacentOK(a.pos.x, a.pos.y, a.pos.z, b.pos.x, b.pos.y, b.pos.z, "walk")
									-- A 32u curb is "walk" (flat treads / cell*1.05) but the hull
									-- hits the face. That is a hop, same as a crate.
									if not ok and math.abs(dz) > 18 and math.abs(dz) <= JUMP_Z then
										local lo, hi = a, b
										if a.pos.z > b.pos.z then
											lo, hi = b, a
										end
										ok = AdjacentOK(lo.pos.x, lo.pos.y, lo.pos.z, hi.pos.x, hi.pos.y, hi.pos.z, "jump")
										kind, segType = "jump", SEG_CLIMB
									end
								elseif math.abs(dz) <= JUMP_Z then
									-- Pair is a hop: test from the lower cell. j>i may be the upper
									-- one, and Classify then says "drop" — a centreline hull
									-- still hits the face and the edge never appears.
									local lo, hi = a, b
									if a.pos.z > b.pos.z then
										lo, hi = b, a
									end
									ok = AdjacentOK(lo.pos.x, lo.pos.y, lo.pos.z, hi.pos.x, hi.pos.y, hi.pos.z, "jump")
									kind, segType = "jump", SEG_CLIMB
								else
									ok = AdjacentOK(a.pos.x, a.pos.y, a.pos.z, b.pos.x, b.pos.y, b.pos.z, "drop")
								end
								if ok then
									AddEdge(i, j, dist, kind, segType)
								end
							end
						end
					end
				end
			end
		end
	end
end

function Mesh.StartLink()
	if Mesh.Building or #Mesh.Cells == 0 then return end

	Mesh.Linked = false
	Mesh.LinkCount = 0
	Mesh.Grid = {}
	Mesh.Blocked = {}
	local size = CellSize()
	local cells = Mesh.Cells
	for i = 1, #cells do
		local c = cells[i]
		c.i = i
		c.nbs = {}
		c.gx = math.floor(c.pos.x / size)
		c.gy = math.floor(c.pos.y / size)
		GridAdd(c.gx, c.gy, i)
	end
	Mesh.Linking = {i = 1, n = #cells, t0 = SysTime(), ping = 0}
	AI.Log("mesh linking %d cells...", #cells)
end

function Mesh.LinkStep()
	local job = Mesh.Linking
	if not job then return end
	local deadline = SysTime() + math.max(0.001, cvBudget:GetFloat() / 1000)
	local n = job.n
	while job.i <= n and SysTime() < deadline do
		LinkCell(job.i)
		job.i = job.i + 1
	end
	if job.i > n then
		local elapsed = SysTime() - job.t0
		for k = 1, n do
			local c = Mesh.Cells[k]
			local w = 0
			for _, e in ipairs(c.nbs) do
				if e.kind == "walk" then w = w + 1 end
			end
			-- Outer corners / lips: standable but a fat body snags. Prefer interior.
			if w <= 2 then
				c.tax = 90
			elseif w == 3 then
				c.tax = 28
			else
				c.tax = 0
			end
		end
		local jumps, ladders = 0, 0
		for k = 1, n do
			for _, e in ipairs(Mesh.Cells[k].nbs) do
				if e.kind == "jump" then
					jumps = jumps + 1
				elseif e.kind == "ladder" then
					ladders = ladders + 1
				end
			end
		end
		Mesh.LinkLadders()
		ladders = (Mesh.LadderCount or 0)
		Mesh.Linking = nil
		Mesh.Linked = true
		AI.Log("mesh linked %d cells, %d edges (%d jump, %d ladders) in %.1fs", n, Mesh.LinkCount, jumps, ladders, elapsed)
		return
	end
	if CurTime() >= job.ping then
		job.ping = CurTime() + 1
		AI.Log("mesh linking %d%%", math.floor((job.i - 1) / n * 100))
	end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Mesh.Nearest(pos, maxDist, maxDz)
	if not pos or not Mesh.Grid then return nil end
	local size = CellSize()
	local gx, gy = math.floor(pos.x / size), math.floor(pos.y / size)
	local maxd = maxDist or 240
	local maxd2 = maxd * maxd
	local reach = math.max(2, math.ceil(maxd / size) + 1)
	local best, bestD2
	for dx = -reach, reach do
		for dy = -reach, reach do
			local bucket = GridGet(gx + dx, gy + dy)
			if bucket then
				for i = 1, #bucket do
					local c = Mesh.Cells[bucket[i]]
					if not maxDz or math.abs(c.pos.z - pos.z) <= maxDz then
						local d2 = pos:DistToSqr(c.pos)
						if d2 <= maxd2 and (not best or d2 < bestD2) then
							best, bestD2 = c, d2
						end
					end
				end
			end
		end
	end
	return best
end

-- Closest cell on this Z band, by XY. 3D Nearest prefers the walkway under a
-- high pad (dz 50, small XY) over the pad the entity actually stands on.
function Mesh.NearestOnFloor(pos, maxDist, maxDz)
	if not pos or not Mesh.Grid then return nil end
	local size = CellSize()
	local gx, gy = math.floor(pos.x / size), math.floor(pos.y / size)
	local maxd = maxDist or 240
	local maxd2 = maxd * maxd
	maxDz = maxDz or 48
	local reach = math.max(2, math.ceil(maxd / size) + 1)
	local best, bestXY
	for dx = -reach, reach do
		for dy = -reach, reach do
			local bucket = GridGet(gx + dx, gy + dy)
			if bucket then
				for i = 1, #bucket do
					local c = Mesh.Cells[bucket[i]]
					if math.abs(c.pos.z - pos.z) <= maxDz then
						local xyd = (c.pos.x - pos.x) * (c.pos.x - pos.x)
							+ (c.pos.y - pos.y) * (c.pos.y - pos.y)
						if xyd <= maxd2 and (not best or xyd < bestXY) then
							best, bestXY = c, xyd
						end
					end
				end
			end
		end
	end
	return best
end

function Mesh.Snap(pos, maxDist)
	local c = Mesh.NearestOnFloor(pos, maxDist or 400, 56)
		or Mesh.Nearest(pos, maxDist or 400, 56)
		or Mesh.Nearest(pos, maxDist or 400)
	return c and Vector(c.pos.x, c.pos.y, c.pos.z) or pos
end

function Mesh.RandomPointNear(pos, radius)
	local size = CellSize()
	local gx, gy = math.floor(pos.x / size), math.floor(pos.y / size)
	local reach = math.max(1, math.ceil((radius or 600) / size))
	local pool = {}
	local r2 = (radius or 600) * (radius or 600)
	for dx = -reach, reach do
		for dy = -reach, reach do
			local bucket = GridGet(gx + dx, gy + dy)
			if bucket then
				for i = 1, #bucket do
					local c = Mesh.Cells[bucket[i]]
					if pos:DistToSqr(c.pos) <= r2 then
						pool[#pool + 1] = c
					end
				end
			end
		end
	end
	if #pool == 0 then return nil end
	local c = pool[math.random(#pool)]
	return Vector(c.pos.x, c.pos.y, c.pos.z)
end

function Mesh.MarkBlockedAt(pos, duration, penalty)
	local c = Mesh.Nearest(pos, 120)
	if not c then return nil end
	local expiry = CurTime() + (duration or 20)
	penalty = penalty or (Nav and Nav.Penalty and Nav.Penalty.Stuck) or 500
	local entry = Mesh.Blocked[c.i]
	if entry then
		if expiry > entry.Expiry then entry.Expiry = expiry end
		if penalty > entry.Penalty then entry.Penalty = penalty end
	else
		Mesh.Blocked[c.i] = {Expiry = expiry, Penalty = penalty, Since = CurTime()}
	end
	return c
end

function Mesh.BlockedSince(pos, minPenalty)
	local c = Mesh.Nearest(pos, 80)
	if not c then return nil end
	local entry = Mesh.Blocked[c.i]
	if entry and entry.Expiry > CurTime() and entry.Penalty >= (minPenalty or 0) then
		return entry.Since
	end
	return nil
end

local function BlockPenalty(i)
	local entry = Mesh.Blocked[i]
	if entry and entry.Expiry > CurTime() then
		return entry.Penalty
	end
	return 0
end

---------------------------------------------------------------------------
-- Heap (lazy decrease-key: push duplicates, skip stale)
---------------------------------------------------------------------------

local function HeapPush(h, node, f)
	local n = h.n + 1
	h.n = n
	h.node[n] = node
	h.f[n] = f
	while n > 1 do
		local p = math.floor(n * 0.5)
		if h.f[p] <= h.f[n] then break end
		h.node[n], h.node[p] = h.node[p], h.node[n]
		h.f[n], h.f[p] = h.f[p], h.f[n]
		n = p
	end
end

local function HeapPop(h)
	local n = h.n
	if n == 0 then return nil end
	local node = h.node[1]
	h.node[1] = h.node[n]
	h.f[1] = h.f[n]
	h.node[n] = nil
	h.f[n] = nil
	h.n = n - 1
	n = h.n
	local i = 1
	while true do
		local l = i * 2
		if l > n then break end
		local r = l + 1
		local m = (r <= n and h.f[r] < h.f[l]) and r or l
		if h.f[i] <= h.f[m] then break end
		h.node[i], h.node[m] = h.node[m], h.node[i]
		h.f[i], h.f[m] = h.f[m], h.f[i]
		i = m
	end
	return node
end

---------------------------------------------------------------------------
-- A* + string pull
---------------------------------------------------------------------------

local function Heuristic(a, b)
	local dx, dy, dz = a.pos.x - b.pos.x, a.pos.y - b.pos.y, a.pos.z - b.pos.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function AStar(startI, goalI)
	if startI == goalI then
		return {startI}, {}, {}, {}
	end

	local cells = Mesh.Cells
	local g = {}
	local came = {}
	local cameKind = {}
	local cameSeg = {}
	local cameLadder = {}
	local closed = {}
	local h = {n = 0, node = {}, f = {}}
	g[startI] = 0
	HeapPush(h, startI, Heuristic(cells[startI], cells[goalI]))

	local expanded = 0
	local expandCap = MAX_EXPAND
	if math.abs(cells[startI].pos.z - cells[goalI].pos.z) > 48 then
		-- Wrong-floor plateau is closer in 3D; A* must drain it before the
		-- down-then-up chain. Give that search more room.
		expandCap = MAX_EXPAND * 2
	end
	local bad = Nav and Nav.BadLadders
	local now = CurTime()
	while h.n > 0 do
		local i = HeapPop(h)
		if not closed[i] then
			if i == goalI then
				local chain, kindChain, segChain, ladChain = {}, {}, {}, {}
				local cur = i
				while cur do
					chain[#chain + 1] = cur
					if came[cur] then
						kindChain[#kindChain + 1] = cameKind[cur]
						segChain[#segChain + 1] = cameSeg[cur]
						ladChain[#ladChain + 1] = cameLadder[cur]
					end
					cur = came[cur]
				end
				local ids, kinds, segs, ladders = {}, {}, {}, {}
				for k = #chain, 1, -1 do
					ids[#ids + 1] = chain[k]
				end
				for k = #kindChain, 1, -1 do
					kinds[#kinds + 1] = kindChain[k]
					segs[#segs + 1] = segChain[k]
					ladders[#ladders + 1] = ladChain[k]
				end
				return ids, kinds, segs, ladders
			end
			closed[i] = true
			expanded = expanded + 1
			if expanded > expandCap then
				return nil
			end
			local gi = g[i]
			local nbs = cells[i].nbs
			for n = 1, #nbs do
				local e = nbs[n]
				local j = e.j
				if not closed[j] then
					if e.ladder and bad then
						local untilT = bad[e.ladder.GetID and e.ladder:GetID() or 0]
						if untilT and untilT > now then
							j = nil
						end
					end
					if j then
						local ng = gi + e.cost + BlockPenalty(j) + (cells[j].tax or 0)
						if not g[j] or ng < g[j] then
							g[j] = ng
							came[j] = i
							cameKind[j] = e.kind
							cameSeg[j] = e.seg
							cameLadder[j] = e.ladder
							HeapPush(h, j, ng + Heuristic(cells[j], cells[goalI]))
						end
					end
				end
			end
		end
	end
	return nil
end

-- Stay on cell centres. A taut string hugs the paint boundary (cliff lips,
-- outer corners). Lookahead on the centre polyline is the smoothing.
-- Only drop a centre that already sits on the line between its neighbours.
-- Waypoints: {pos, freeze, seg, ladder}.
local function CollapseWaypoints(pts)
	if #pts <= 2 then return pts end
	local out = {pts[1]}
	for i = 2, #pts - 1 do
		if pts[i].freeze then
			out[#out + 1] = pts[i]
		else
			local a, b, c = out[#out].pos, pts[i].pos, pts[i + 1].pos
			local abx, aby = b.x - a.x, b.y - a.y
			local bcx, bcy = c.x - b.x, c.y - b.y
			local cross = abx * bcy - aby * bcx
			local dot = abx * bcx + aby * bcy
			if math.abs(cross) > 80 or dot <= 0 then
				out[#out + 1] = pts[i]
			end
		end
	end
	out[#out + 1] = pts[#pts]
	return out
end

local Path = {}
Path.__index = Path

local function NewPath()
	return setmetatable({
		_valid = false,
		_length = 0,
		_segs = {},
		_cursor = 0,
		_end = Vector(),
		_cursorData = {pos = Vector()},
	}, Path)
end

function Path:IsValid()
	return self._valid
end

function Path:GetLength()
	return self._length
end

function Path:GetAllSegments()
	return self._segs
end

function Path:MoveCursorToStart()
	self._cursor = 0
end

function Path:GetCursorPosition()
	return self._cursor
end

function Path:GetEnd()
	return self._end
end

function Path:GetPositionOnPath(d)
	local segs = self._segs
	local n = #segs
	if n == 0 then
		return self._end
	end
	if d <= 0 then
		return segs[1].pos
	end
	if d >= self._length then
		return segs[n].pos
	end
	local i = 1
	while i < n and segs[i + 1].distanceFromStart < d do
		i = i + 1
	end
	local a, b = segs[i], segs[math.min(i + 1, n)]
	local span = b.distanceFromStart - a.distanceFromStart
	if span < 0.001 then
		return a.pos
	end
	local t = (d - a.distanceFromStart) / span
	return Vector(
		a.pos.x + (b.pos.x - a.pos.x) * t,
		a.pos.y + (b.pos.y - a.pos.y) * t,
		a.pos.z + (b.pos.z - a.pos.z) * t
	)
end

function Path:GetCursorData()
	self._cursorData.pos = self:GetPositionOnPath(self._cursor)
	return self._cursorData
end

function Path:MoveCursorToClosestPosition(worldPos, seek)
	local segs = self._segs
	local n = #segs
	if n == 0 then
		self._cursor = 0
		return
	end
	if n == 1 then
		self._cursor = 0
		return
	end
	local minD = 0
	if seek == 1 then
		minD = math.max(0, self._cursor - 64)
	end
	local bestD, bestDist = minD, math.huge
	local wx, wy, wz = worldPos.x, worldPos.y, worldPos.z
	for i = 1, n - 1 do
		local a, b = segs[i], segs[i + 1]
		if b.distanceFromStart >= minD then
			local span = b.distanceFromStart - a.distanceFromStart
			local steps = math.max(1, math.ceil(span / 24))
			for s = 0, steps do
				local t = s / steps
				local d = a.distanceFromStart + span * t
				if d >= minD then
					local px = a.pos.x + (b.pos.x - a.pos.x) * t
					local py = a.pos.y + (b.pos.y - a.pos.y) * t
					local pz = a.pos.z + (b.pos.z - a.pos.z) * t
					local dx, dy, dz = wx - px, wy - py, wz - pz
					local dist = dx * dx + dy * dy + dz * dz
					if dist < bestDist then
						bestDist = dist
						bestD = d
					end
				end
			end
		end
	end
	self._cursor = bestD
end

local function BuildPath(from, goal, ids, kinds, segsType, ladders)
	local cells = Mesh.Cells
	ladders = ladders or {}
	local pts = {{pos = Vector(from.x, from.y, from.z), freeze = false, seg = SEG_GROUND}}
	for k = 1, #ids do
		local p = cells[ids[k]].pos
		local kind = kinds[k - 1]
		pts[#pts + 1] = {
			pos = Vector(p.x, p.y, p.z),
			freeze = kind == "jump" or kind == "drop" or kind == "ladder",
			seg = segsType[k - 1] or SEG_GROUND,
			ladder = ladders[k - 1],
		}
	end
	local lastCell = cells[ids[#ids]].pos
	local onFloor = math.abs(goal.z - lastCell.z) < 48 and goal:DistToSqr(lastCell) <= 96 * 96
	if onFloor then
		pts[#pts + 1] = {pos = Vector(goal.x, goal.y, goal.z), freeze = false, seg = SEG_GROUND}
	end

	local pulled = CollapseWaypoints(pts)
	local path = NewPath()
	local dist = 0
	local prev
	local walkRise = math.max(WALK_Z, (Mesh.CellSize or 40) * 1.05) + 2
	for i = 1, #pulled do
		local wp = pulled[i]
		local p = wp.pos
		if prev then
			dist = dist + prev:Distance(p)
		end
		local segType = wp.seg or SEG_GROUND
		if segType == SEG_GROUND and prev then
			if (p.z - prev.z) > walkRise then
				segType = SEG_CLIMB
			elseif (prev.z - p.z) > walkRise then
				segType = SEG_DROP
			end
		end
		path._segs[i] = {
			pos = p,
			distanceFromStart = dist,
			type = segType,
			how = segType,
			length = prev and prev:Distance(p) or 0,
			area = nil,
			ladder = wp.ladder,
		}
		prev = p
	end
	path._valid = #path._segs >= 1
	path._length = dist
	path._end = pulled[#pulled] and pulled[#pulled].pos or Vector(goal)
	path._cursor = 0
	return path
end

-- Walk to a drop / ladder / jump that leaves this floor toward goal.
-- Spawn roofs often cannot A* to a human below (goal cell missing or islands);
-- without this they stand still and HandleHopeless resets the fail counter.
function Mesh.FindLeaveFloor(from, goal)
	local startC = Mesh.NearestOnFloor(from, 240, 56) or Mesh.Nearest(from, 240, 72) or Mesh.Nearest(from, 240)
	if not startC or not goal then
		return nil, false, startC
	end
	local cells = Mesh.Cells
	local startZ = startC.pos.z
	local closed = {[startC.i] = true}
	local came, cameKind, cameSeg, cameLad = {}, {}, {}, {}
	local q = {startC.i}
	local bestI, bestJ, bestE, bestScore
	local head = 1
	local nq = 1
	while head <= nq do
		local i = q[head]
		head = head + 1
		local nbs = cells[i].nbs
		if nbs then
			for n = 1, #nbs do
				local e = nbs[n]
				local j = e.j
				local kind = e.kind
				local jz = cells[j].pos.z
				local leaves = kind == "ladder"
					or (kind == "drop" and jz < startZ - 40)
					or (kind == "jump" and jz > startZ + 40 and goal.z > from.z + 24)
				if leaves then
					local land = cells[j].pos
					local dx, dy, dz = land.x - goal.x, land.y - goal.y, land.z - goal.z
					local score = dx * dx + dy * dy + dz * dz * 0.2
					if kind == "ladder" then
						score = score * 0.45
					end
					if not bestJ or score < bestScore then
						bestI, bestJ, bestE, bestScore = i, j, e, score
					end
				end
				if not closed[j] then
					closed[j] = true
					came[j] = i
					cameKind[j] = kind
					cameSeg[j] = e.seg
					cameLad[j] = e.ladder
					nq = nq + 1
					q[nq] = j
					if nq > MAX_EXPAND then
						break
					end
				end
			end
		end
		if nq > MAX_EXPAND then
			break
		end
	end
	if not bestJ then
		return nil, false, startC
	end

	local chain, kindChain, segChain, ladChain = {}, {}, {}, {}
	local cur = bestI
	while cur do
		chain[#chain + 1] = cur
		if came[cur] then
			kindChain[#kindChain + 1] = cameKind[cur]
			segChain[#segChain + 1] = cameSeg[cur]
			ladChain[#ladChain + 1] = cameLad[cur]
		end
		cur = came[cur]
	end
	local ids, kinds, segsType, ladders = {}, {}, {}, {}
	for k = #chain, 1, -1 do
		ids[#ids + 1] = chain[k]
	end
	for k = #kindChain, 1, -1 do
		kinds[#kinds + 1] = kindChain[k]
		segsType[#segsType + 1] = segChain[k]
		ladders[#ladders + 1] = ladChain[k]
	end
	ids[#ids + 1] = bestJ
	kinds[#kinds + 1] = bestE.kind
	segsType[#segsType + 1] = bestE.seg
	ladders[#ladders + 1] = bestE.ladder
	local land = cells[bestJ].pos
	return BuildPath(from, land, ids, kinds, segsType, ladders), false, startC
end

local function PathLeavesFloor(path)
	if not path or not path.GetAllSegments then return false end
	local segs = path:GetAllSegments()
	for i = 1, #segs do
		local t = segs[i].type
		if t == SEG_DROP or t == SEG_LADDER_UP or t == SEG_LADDER_DOWN then
			return true
		end
	end
	return false
end

function Mesh.FindPath(from, goal, loose)
	local startC = Mesh.NearestOnFloor(from, 240, 56) or Mesh.Nearest(from, 240, 72) or Mesh.Nearest(from, 240)
	local cross = math.abs(goal.z - from.z) > 40
	local goalC = Mesh.NearestOnFloor(goal, 200, 48)
		or Mesh.NearestOnFloor(goal, 360, 56)
		or Mesh.NearestOnFloor(goal, 520, 72)
	if not cross then
		goalC = goalC or Mesh.Nearest(goal, 240, 48)
	else
		-- Other floor: snap on THAT Z band. Unconstrained Nearest is the cliff
		-- on our roof under the target.
		goalC = goalC
			or Mesh.NearestOnFloor(goal, 800, 96)
			or Mesh.NearestOnFloor(goal, 1400, 140)
	end
	if not startC then
		return nil, false, nil
	end
	if not goalC then
		return nil, false, startC
	end
	-- Same Z as the sigil but 200u away is the cliff on OUR roof, not the pad.
	-- loose: ladder mount / same-floor dest — A* to the nearest cell anyway.
	local gxy = (goal.x - goalC.pos.x) * (goal.x - goalC.pos.x)
		+ (goal.y - goalC.pos.y) * (goal.y - goalC.pos.y)
	if gxy > 160 * 160 and not loose then
		return nil, false, startC
	end
	local ids, kinds, segsType, ladders = AStar(startC.i, goalC.i)
	if not ids then
		return nil, false, startC
	end
	local path = BuildPath(from, goal, ids, kinds, segsType, ladders)
	local last = Mesh.Cells[ids[#ids]].pos
	local reached = math.abs(goal.z - last.z) < 48
		and (goal.x - last.x) * (goal.x - last.x) + (goal.y - last.y) * (goal.y - last.y) <= 180 * 180
	return path, reached, startC
end

function Mesh.ComputeNow(bot, goal, opts)
	opts = opts or {}
	local pl = bot.Player
	local from = pl:GetPos()
	local loco = bot.Loco
	local t0 = SysTime()

	local function stamp()
		local ms = (SysTime() - t0) * 1000
		if Nav and Nav.Stats then
			local stats = Nav.Stats
			stats.Computes = stats.Computes + 1
			stats.Window = stats.Window + 1
			stats.LastMs = ms
			stats.AvgMs = stats.AvgMs + (ms - stats.AvgMs) * 0.1
		end
	end

	local function accept(path, reached, dest)
		stamp()
		if path and path:IsValid() then
			bot.Path = path
			if loco then loco:OnPathResult(path, reached == true, dest) end
			return true
		end
		if loco then
			loco:OnPathResult(nil, false, dest)
		end
		-- On the paint: do not mix Source .nav (walks off lips / spawn has no area).
		return true
	end

	local hunt = loco and loco.Goal
	local toHunt = hunt and goal:DistToSqr(hunt) < 80 * 80
	local path, reached, startC = Mesh.FindPath(from, goal, not toHunt)

	if not startC then
		stamp()
		return false
	end

	if path and reached then
		return accept(path, true, goal)
	end
	if path and path:IsValid() and PathLeavesFloor(path) then
		return accept(path, reached, goal)
	end

	-- Hunt on another island: a partial path is the cliff under the sigil.
	-- Same tick: walk the paint to a shaft or a drop instead of standing.
	local toward = hunt or goal
	if toHunt and loco then
		local dx = toward.x - from.x
		local dy = toward.y - from.y
		local close = dx * dx + dy * dy < 100 * 100 and math.abs(toward.z - from.z) < 40
		if not close then
			loco.NeedLadder = true
			loco.NextRepath = 0
			local ladder, up = Nav.FindLadderForGoal(from, toward)
			if Nav.HasLadder(ladder) then
				loco.ViaLadder = ladder
				loco.ViaUp = up
				local mount = loco.LadderMountPos and loco:LadderMountPos(ladder, up)
				if mount then
					local snap = (Nav.SnapToMesh and Nav.SnapToMesh(mount, 160)) or mount
					local mpath, mreached = Mesh.FindPath(from, snap, true)
					if mpath and mpath:IsValid() then
						return accept(mpath, mreached, snap)
					end
				end
			end
		end
	elseif path and path:IsValid() then
		return accept(path, reached, goal)
	end

	local leave = Mesh.FindLeaveFloor(from, toward)
	if leave and leave:IsValid() then
		if loco then
			loco.NeedLadder = true
			loco.NextRepath = 0
		end
		return accept(leave, false, leave:GetEnd())
	end

	return accept(nil, false, goal)
end

---------------------------------------------------------------------------
-- Wire into Nav.* (once; lua_refresh keeps the originals)
---------------------------------------------------------------------------

if Nav then
	if not Nav.RelapseMeshWrapped then
		Nav.RelapseMeshWrapped = true
		Nav.ComputeSource = Nav.ComputeNow
		Nav.SourceIsReady = Nav.IsReady
		Nav.SourceStatus = Nav.Status
		Nav.SourceSnap = Nav.SnapToMesh
		Nav.SourceRand = Nav.RandomPointNear
		Nav.SourceMark = Nav.MarkBlockedAt
		Nav.SourceSince = Nav.BlockedSince
	end

	function Nav.ComputeNow(bot, goal, opts)
		if Mesh.IsReady() then
			local ok, handled = pcall(Mesh.ComputeNow, bot, goal, opts)
			if not ok then
				AI.Warn("Mesh.ComputeNow: %s", tostring(handled))
				if bot.Loco then bot.Loco:OnPathResult(nil, false, goal) end
				return
			end
			if handled then return end
		end
		if Nav.ComputeSource then
			return Nav.ComputeSource(bot, goal, opts)
		end
		if bot.Loco then bot.Loco:OnPathResult(nil, false, goal) end
	end

	function Nav.IsReady()
		if Mesh.IsReady() then return true end
		return Nav.SourceIsReady()
	end

	function Nav.Status()
		if Mesh.IsReady() then
			return string.format("relapse mesh %d cells / %d links", #Mesh.Cells, Mesh.LinkCount or 0)
		end
		if Mesh.Linking then
			local job = Mesh.Linking
			return string.format("relapse mesh linking %d%%", math.floor((job.i - 1) / math.max(1, job.n) * 100))
		end
		if Mesh.Cells and #Mesh.Cells > 0 then
			return string.format("relapse mesh %d cells (not linked)", #Mesh.Cells)
		end
		return Nav.SourceStatus()
	end

	function Nav.SnapToMesh(pos, maxDist)
		if Mesh.IsReady() then
			return Mesh.Snap(pos, maxDist)
		end
		return Nav.SourceSnap(pos, maxDist)
	end

	function Nav.RandomPointNear(pos, radius)
		if Mesh.IsReady() then
			return Mesh.RandomPointNear(pos, radius) or Nav.SourceRand(pos, radius)
		end
		return Nav.SourceRand(pos, radius)
	end

	function Nav.MarkBlockedAt(pos, duration, penalty)
		if Mesh.IsReady() then
			Mesh.MarkBlockedAt(pos, duration, penalty)
		end
		return Nav.SourceMark(pos, duration, penalty)
	end

	function Nav.BlockedSince(pos, minPenalty)
		if Mesh.IsReady() then
			local t = Mesh.BlockedSince(pos, minPenalty)
			if t then return t end
		end
		return Nav.SourceSince(pos, minPenalty)
	end
end

hook.Add("Think", "RelapseAI.MeshLink", function()
	if Mesh.Linking then
		Mesh.LinkStep()
	end
end)

if #Mesh.Cells > 0 and not Mesh.Building then
	Mesh.StartLink()
end
