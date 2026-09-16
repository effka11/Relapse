-- Cycle grid skeleton. Catalog of skills is empty; slots are places.
-- Law: documents/cycle-grid.md
-- Free angles, a turn every hop, no segment crossings. Eight trees grow together.

GM.CycleGridSlots = 15
GM.CycleGridUnit = 20
GM.CycleGridTrees = {
	{ id = "vitality", nameKey = "grid_tree_vitality" },
	{ id = "supply", nameKey = "grid_tree_supply" },
	{ id = "mechanics", nameKey = "grid_tree_mechanics" },
	{ id = "medicine", nameKey = "grid_tree_medicine" },
	{ id = "ranged", nameKey = "grid_tree_ranged" },
	{ id = "melee", nameKey = "grid_tree_melee" },
	{ id = "build", nameKey = "grid_tree_build" },
	{ id = "shadow", nameKey = "grid_tree_shadow" }
}

local ARMS = {
	{ outX = 0, outY = 1 },
	{ outX = 1, outY = 1 },
	{ outX = 1, outY = 0 },
	{ outX = 1, outY = -1 },
	{ outX = 0, outY = -1 },
	{ outX = -1, outY = -1 },
	{ outX = -1, outY = 0 },
	{ outX = -1, outY = 1 }
}

local MIN_TURN = 42
local MAX_TURN = 118
local MIN_SEP = 0.68
local CORE_R = 0.92
local HALF_DEG = 30

local function SeedRand(seed)
	local s = math.floor(seed % 2147483647)
	if s <= 0 then
		s = s + 2147483646
	end
	return function()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end

local function Dist2(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return dx * dx + dy * dy
end

local function AngleDiff(a, b)
	return math.AngleDifference(math.deg(a), math.deg(b))
end

local function InSector(x, y, arm, halfDeg)
	if x == 0 and y == 0 then
		return false
	end
	local ang = math.atan2(y, x)
	local center = math.atan2(arm.outY, arm.outX)
	return math.abs(AngleDiff(ang, center)) <= halfDeg
end

local function ArmDot(x, y, arm)
	local ox, oy = arm.outX, arm.outY
	local len = math.sqrt(ox * ox + oy * oy)
	return (x * ox + y * oy) / len
end

local function Near(ax, ay, bx, by)
	return Dist2(ax, ay, bx, by) < 1e-8
end

local function Orient(ax, ay, bx, by, cx, cy)
	return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
end

local function SegsCross(ax, ay, bx, by, cx, cy, dx, dy)
	if Near(ax, ay, cx, cy) or Near(ax, ay, dx, dy) or Near(bx, by, cx, cy) or Near(bx, by, dx, dy) then
		return false
	end
	local o1 = Orient(ax, ay, bx, by, cx, cy)
	local o2 = Orient(ax, ay, bx, by, dx, dy)
	local o3 = Orient(cx, cy, dx, dy, ax, ay)
	local o4 = Orient(cx, cy, dx, dy, bx, by)
	return ((o1 > 0 and o2 < 0) or (o1 < 0 and o2 > 0)) and ((o3 > 0 and o4 < 0) or (o3 < 0 and o4 > 0))
end

local function SegDist2(px, py, ax, ay, bx, by)
	local vx, vy = bx - ax, by - ay
	local len2 = vx * vx + vy * vy
	if len2 < 1e-8 then
		return Dist2(px, py, ax, ay)
	end
	local t = math.Clamp(((px - ax) * vx + (py - ay) * vy) / len2, 0, 1)
	local qx, qy = ax + vx * t, ay + vy * t
	return Dist2(px, py, qx, qy)
end

local function NewGrower(treeIndex, tree, arm, rnd, allNodes, segs)
	local nSlots = GAMEMODE.CycleGridSlots
	local nodes = {}
	local childCount = {}
	local lean = (rnd() < 0.5) and 1 or -1
	local center = math.atan2(arm.outY, arm.outX)
	local halfDeg = HALF_DEG

	local function tooClose(x, y, skip)
		if Dist2(x, y, 0, 0) < CORE_R * CORE_R then
			return true
		end
		for _, n in ipairs(allNodes) do
			if n ~= skip and Dist2(x, y, n.x, n.y) < MIN_SEP * MIN_SEP then
				return true
			end
		end
		return false
	end

	local function edgeBlocked(ax, ay, bx, by, skipNode)
		for _, e in ipairs(segs) do
			if SegsCross(ax, ay, bx, by, e[1], e[2], e[3], e[4]) then
				return true
			end
		end
		local lim = 0.32 * 0.32
		for _, n in ipairs(allNodes) do
			if n ~= skipNode and SegDist2(n.x, n.y, ax, ay, bx, by) < lim then
				return true
			end
		end
		return false
	end

	local function addNode(x, y, parent, ang)
		local dx, dy = math.cos(ang), math.sin(ang)
		local node = {
			tree = treeIndex,
			treeId = tree.id,
			slot = #nodes,
			x = x,
			y = y,
			parent = parent,
			ang = ang,
			inx = dx,
			iny = dy
		}
		nodes[#nodes + 1] = node
		allNodes[#allNodes + 1] = node
		if parent then
			childCount[parent] = (childCount[parent] or 0) + 1
			segs[#segs + 1] = { parent.x, parent.y, x, y }
		else
			segs[#segs + 1] = { 0, 0, x, y }
		end
		return node
	end

	local function score(parent, x, y, ang)
		local out = ArmDot(x, y, arm)
		local pout = ArmDot(parent.x, parent.y, arm)
		local s = rnd() * 3.2
		if out > pout then
			s = s + 4.5
		else
			s = s - 4
		end
		local turn = math.abs(AngleDiff(ang, parent.ang))
		if turn < 50 then
			s = s - 1.5
		elseif turn > 95 then
			s = s + 0.8
		end
		s = s - math.abs(AngleDiff(math.atan2(y, x), center)) * 0.04
		return s
	end

	local function tryFrom(parent, ignoreCap)
		if not ignoreCap and (childCount[parent] or 0) >= 3 then
			return nil
		end
		local cands = {}
		for k = 1, 22 do
			local sign = lean
			if k % 2 == 0 then
				sign = -lean
			end
			if rnd() < 0.22 then
				sign = -sign
			end
			local turn = math.rad(MIN_TURN + rnd() * (MAX_TURN - MIN_TURN))
			local ang = parent.ang + sign * turn
			local len = 0.92 + rnd() * 0.62
			local x = parent.x + math.cos(ang) * len
			local y = parent.y + math.sin(ang) * len
			if InSector(x, y, arm, halfDeg) and not tooClose(x, y, parent) and not edgeBlocked(parent.x, parent.y, x, y, parent) then
				cands[#cands + 1] = { x = x, y = y, ang = ang, s = score(parent, x, y, ang) }
			end
		end
		if #cands == 0 then
			return nil
		end
		table.sort(cands, function(a, b)
			return a.s > b.s
		end)
		local pick = cands[1]
		if #cands >= 2 and rnd() < 0.6 then
			pick = cands[1 + math.floor(rnd() * math.min(4, #cands))]
		end
		return addNode(pick.x, pick.y, parent, pick.ang)
	end

	local function pickParent()
		local roll = rnd()
		if roll < 0.38 then
			return nodes[#nodes]
		end
		if roll < 0.76 then
			return nodes[1 + math.floor(rnd() * #nodes)]
		end
		local best, bestN
		for _, n in ipairs(nodes) do
			local c = childCount[n] or 0
			if c < 3 and (not bestN or c < bestN) then
				best, bestN = n, c
			end
		end
		return best or nodes[#nodes]
	end

	local grower = { nodes = nodes, treeIndex = treeIndex, arm = arm }

	function grower.PlaceGate()
		local jitter = (rnd() - 0.5) * 0.16
		local ang = center + jitter
		local rad = 1.12 + rnd() * 0.22
		local x, y = math.cos(ang) * rad, math.sin(ang) * rad
		if tooClose(x, y, nil) then
			x, y = math.cos(center) * 1.2, math.sin(center) * 1.2
		end
		addNode(x, y, nil, ang)
	end

	function grower.Step(ignoreCap)
		if #nodes >= nSlots then
			return false
		end
		if tryFrom(pickParent(), ignoreCap) then
			return true
		end
		for i = #nodes, 1, -1 do
			if tryFrom(nodes[i], ignoreCap) then
				return true
			end
		end
		return false
	end

	function grower.Widen()
		halfDeg = math.min(40, halfDeg + 5)
	end

	return grower
end

GM.CycleGridLayout = nil

function GM:GetCycleGridLayout()
	if self.CycleGridLayout then
		return self.CycleGridLayout
	end

	local allNodes = {}
	local segs = {}
	local growers = {}

	for i, tree in ipairs(self.CycleGridTrees) do
		local rnd = SeedRand(41117 + i * 13063)
		growers[i] = NewGrower(i, tree, ARMS[i], rnd, allNodes, segs)
		growers[i].PlaceGate()
	end

	local function GrowRound(ignoreCap)
		local order = {}
		for i, g in ipairs(growers) do
			order[i] = g
		end
		table.sort(order, function(a, b)
			if #a.nodes ~= #b.nodes then
				return #a.nodes < #b.nodes
			end
			return a.treeIndex < b.treeIndex
		end)
		local moved = false
		for _, g in ipairs(order) do
			if g.Step(ignoreCap) then
				moved = true
			elseif #g.nodes < self.CycleGridSlots then
				g.Widen()
				if g.Step(ignoreCap) then
					moved = true
				end
			end
		end
		return moved
	end

	local moved = true
	local guard = 0
	while moved and guard < 80 do
		moved = GrowRound(false)
		guard = guard + 1
	end
	moved = true
	guard = 0
	while moved and guard < 80 do
		moved = GrowRound(true)
		guard = guard + 1
	end

	local nodes = {}
	local edges = {}
	local labels = {}
	local hub = { x = 0, y = 0 }
	local byTree = {}

	for i, g in ipairs(growers) do
		local tnodes = g.nodes
		byTree[i] = tnodes
		local far = tnodes[1]
		local farD = -1
		for _, n in ipairs(tnodes) do
			nodes[#nodes + 1] = n
			if n.slot == 0 then
				edges[#edges + 1] = { hub, n, hub = true }
			elseif n.parent then
				edges[#edges + 1] = { n.parent, n }
			end
			local d = ArmDot(n.x, n.y, g.arm)
			if d > farD then
				far, farD = n, d
			end
		end
		labels[#labels + 1] = {
			tree = i,
			treeId = self.CycleGridTrees[i].id,
			nameKey = self.CycleGridTrees[i].nameKey,
			x = far.x,
			y = far.y
		}
	end

	self.CycleGridLayout = {
		hub = hub,
		nodes = nodes,
		edges = edges,
		labels = labels,
		byTree = byTree
	}
	return self.CycleGridLayout
end
