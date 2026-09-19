-- Cycle grid skeleton.
-- Law: documents/cycle-grid.md
-- Nine bushes in outward lanes. Free angles, a turn every hop, no crossings.

GM.CycleGridSlots = 15
GM.CycleGridUnit = 20
GM.CycleGridTrees = {
	{ id = "vitality", nameKey = "grid_tree_vitality" },
	{ id = "supply", nameKey = "grid_tree_supply" },
	{ id = "mechanics", nameKey = "grid_tree_mechanics" },
	{ id = "medicine", nameKey = "grid_tree_medicine" },
	{ id = "ranged", nameKey = "grid_tree_ranged" },
	{ id = "shadow", nameKey = "grid_tree_shadow" },
	{ id = "build", nameKey = "grid_tree_build" },
	{ id = "melee", nameKey = "grid_tree_melee" },
	{ id = "agility", nameKey = "grid_tree_agility" }
}

local function MakeArms(n)
	local arms = {}
	for i = 0, n - 1 do
		local a = math.rad(90 - i * (360 / n))
		arms[i + 1] = { outX = math.cos(a), outY = math.sin(a) }
	end
	return arms
end

local MIN_TURN = 17
local MIN_SEP = 0.70
local CORE_R = 0.94

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

local function ArmAxes(arm)
	local ox, oy = arm.outX, arm.outY
	local len = math.sqrt(ox * ox + oy * oy)
	ox, oy = ox / len, oy / len
	return ox, oy, -oy, ox
end

local function ArmDot(x, y, arm)
	local ox, oy = ArmAxes(arm)
	return x * ox + y * oy
end

local function InBush(x, y, arm, pad, cone)
	local ox, oy, rx, ry = ArmAxes(arm)
	local par = x * ox + y * oy
	if par < 0.88 or par > 7.2 then
		return false
	end
	local perp = math.abs(x * rx + y * ry)
	return perp <= 0.58 + par * cone + (pad or 0)
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

local function NewGrower(treeIndex, tree, arm, rnd, allNodes, segs, cone)
	local nSlots = GAMEMODE.CycleGridSlots
	local nodes = {}
	local childCount = {}
	local spine = {}
	local lean = (rnd() < 0.5) and 1 or -1
	local center = math.atan2(arm.outY, arm.outX)
	local pad = 0
	local sep = MIN_SEP
	local spineN = (rnd() < 0.5) and 5 or 6

	local function tooClose(x, y, skip)
		if Dist2(x, y, 0, 0) < CORE_R * CORE_R then
			return true
		end
		for _, n in ipairs(allNodes) do
			if n ~= skip and Dist2(x, y, n.x, n.y) < sep * sep then
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
		local lim = 0.28 * 0.28
		for _, n in ipairs(allNodes) do
			if n ~= skipNode and SegDist2(n.x, n.y, ax, ay, bx, by) < lim then
				return true
			end
		end
		return false
	end

	local function addNode(x, y, parent, ang, kind)
		local dx, dy = math.cos(ang), math.sin(ang)
		local node = {
			tree = treeIndex,
			treeId = tree.id,
			slot = #nodes,
			x = x,
			y = y,
			parent = parent,
			ang = ang,
			kind = kind,
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

	local function sample(parent, mode)
		local ox, oy, rx, ry = ArmAxes(arm)
		local radial = math.atan2(oy, ox)
		local pr = math.sqrt(parent.x * parent.x + parent.y * parent.y)
		local prevLen = pr
		if parent.parent then
			prevLen = math.sqrt(Dist2(parent.x, parent.y, parent.parent.x, parent.parent.y))
		end
		local tip = spine[#spine]
		local cands = {}
		for k = 1, 41 do
			local sign = lean
			if k % 2 == 0 then
				sign = -lean
			end
			if mode == "twig" then
				if k % 3 == 0 then
					sign = lean
				else
					sign = -lean
				end
			end
			if rnd() < 0.12 then
				sign = -sign
			end
			local turn, len, band = 0, 0, rnd()
			if mode == "spine" then
				turn = 18 + rnd() * 24
				if band < 0.34 then
					len = 0.74 + rnd() * 0.16
				elseif band < 0.70 then
					len = 0.98 + rnd() * 0.22
				else
					len = 1.24 + rnd() * 0.28
				end
			else
				turn = 26 + rnd() * 34
				if band < 0.40 then
					len = 0.72 + rnd() * 0.16
				elseif band < 0.74 then
					len = 0.92 + rnd() * 0.22
				else
					len = 1.18 + rnd() * 0.30
				end
			end
			local ang = radial + sign * math.rad(turn)
			if math.abs(AngleDiff(ang, parent.ang)) < MIN_TURN then
				ang = parent.ang + sign * math.rad(MIN_TURN + 7 + rnd() * 14)
			end
			local x = parent.x + math.cos(ang) * len
			local y = parent.y + math.sin(ang) * len
			local r = math.sqrt(x * x + y * y)
			local ok = true
			if mode == "spine" and r < pr + 0.12 then
				ok = false
			end
			if ok and InBush(x, y, arm, pad, cone) and not tooClose(x, y, parent) and not edgeBlocked(parent.x, parent.y, x, y, parent) then
				local par = x * ox + y * oy
				local perp = math.abs(x * rx + y * ry)
				local s = rnd() * 1.7 + math.abs(len - prevLen) * 1.8
				if mode == "spine" then
					s = s - perp * 0.8
					if r > pr then
						s = s + 1.1
					end
				else
					s = s + perp * 1.6 + (3.1 - math.abs(par - 2.8)) * 0.5
					if parent == tip then
						s = s - 2.2
					end
				end
				cands[#cands + 1] = { x = x, y = y, ang = ang, s = s }
			end
		end
		if #cands == 0 then
			return nil
		end
		table.sort(cands, function(a, b)
			return a.s > b.s
		end)
		local pick = cands[1]
		if #cands >= 2 and rnd() < 0.38 then
			pick = cands[1 + math.floor(rnd() * math.min(3, #cands))]
		end
		return pick
	end

	local function growFrom(parent, mode)
		local pick = sample(parent, mode)
		if not pick then
			return nil
		end
		local n = addNode(pick.x, pick.y, parent, pick.ang, mode)
		if mode == "spine" then
			spine[#spine + 1] = n
			if rnd() < 0.82 then
				lean = -lean
			end
		end
		return n
	end

	local grower = { nodes = nodes, treeIndex = treeIndex, arm = arm }

	function grower.PlaceGate()
		local jitter = (rnd() - 0.5) * 0.12
		local ang = center + jitter
		local rad = 0.98 + rnd() * 0.40
		local x, y = math.cos(ang) * rad, math.sin(ang) * rad
		if tooClose(x, y, nil) then
			ang = center
			rad = 1.18
			x, y = math.cos(ang) * rad, math.sin(ang) * rad
		end
		local n = addNode(x, y, nil, ang, "gate")
		spine[#spine + 1] = n
	end

	function grower.StepSpine()
		if #nodes >= nSlots or #spine >= spineN then
			return false
		end
		if growFrom(spine[#spine], "spine") then
			return true
		end
		for i = #spine, 1, -1 do
			if growFrom(spine[i], "spine") then
				return true
			end
		end
		return false
	end

	function grower.StepTwig()
		if #nodes >= nSlots then
			return false
		end
		local ranked = {}
		local tip = spine[#spine]
		for _, n in ipairs(nodes) do
			local cc = childCount[n] or 0
			local cap = (n.kind == "twig") and 1 or 2
			if cc < cap then
				local s = rnd() * 2.2 - cc * 3.5
				if n == tip then
					s = s - 2.8
				end
				if n.kind == "gate" then
					s = s - 0.8
				end
				ranked[#ranked + 1] = { s = s, n = n }
			end
		end
		table.sort(ranked, function(a, b)
			return a.s > b.s
		end)
		for _, row in ipairs(ranked) do
			if growFrom(row.n, "twig") then
				return true
			end
		end
		return false
	end

	function grower.Widen()
		pad = math.min(0.55, pad + 0.12)
		sep = math.max(0.60, sep - 0.03)
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
	local nTrees = #self.CycleGridTrees
	local arms = MakeArms(nTrees)
	local cone = math.tan(math.pi / nTrees * 0.85)

	for i, tree in ipairs(self.CycleGridTrees) do
		local rnd = SeedRand(9041 + i * 7919)
		growers[i] = NewGrower(i, tree, arms[i], rnd, allNodes, segs, cone)
		growers[i].PlaceGate()
	end

	local function GrowRound(kind, allowWiden)
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
			local ok = false
			if kind == "spine" then
				ok = g.StepSpine()
			else
				ok = g.StepTwig() or g.StepSpine()
			end
			if ok then
				moved = true
			elseif allowWiden and #g.nodes < self.CycleGridSlots then
				g.Widen()
				if kind == "spine" then
					ok = g.StepSpine()
				else
					ok = g.StepTwig() or g.StepSpine()
				end
				if ok then
					moved = true
				end
			end
		end
		return moved
	end

	local moved = true
	local guard = 0
	while moved and guard < 40 do
		moved = GrowRound("spine", false)
		guard = guard + 1
	end
	moved = true
	guard = 0
	while moved and guard < 80 do
		moved = GrowRound("twig", true)
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
		local ux, uy = ArmAxes(g.arm)
		labels[#labels + 1] = {
			tree = i,
			treeId = self.CycleGridTrees[i].id,
			nameKey = self.CycleGridTrees[i].nameKey,
			x = far.x + ux * 0.7,
			y = far.y + uy * 0.7
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

-- Catalog. Law: documents/cycle-grid.md
GM.CycleGridCatalog = {
	vitality_1 = {
		tree = "vitality",
		slot = 0,
		nameKey = "grid_skill_vitality_1",
		descKey = "grid_skill_vitality_1_desc",
		U = 20,
		Health = 3
	},
	agility_1 = {
		tree = "agility",
		slot = 0,
		nameKey = "grid_skill_agility_1",
		descKey = "grid_skill_agility_1_desc",
		U = 20,
		RunSpeed = 0.03
	},
	agility_2 = {
		tree = "agility",
		slot = 1,
		nameKey = "grid_skill_agility_2",
		descKey = "grid_skill_agility_2_desc",
		U = 20,
		Jump = 0.02,
		Climb = 0.02
	},
	agility_3 = {
		tree = "agility",
		slot = 2,
		nameKey = "grid_skill_agility_3",
		descKey = "grid_skill_agility_3_desc",
		U = 20,
		RunSpeed = 0.03
	},
	agility_4 = {
		tree = "agility",
		slot = 12,
		nameKey = "grid_skill_agility_4",
		descKey = "grid_skill_agility_4_desc",
		U = 20,
		RunSpeed = 0.02,
		Jump = 0.02,
		Health = -2
	},
	agility_5 = {
		tree = "agility",
		slot = 13,
		nameKey = "grid_skill_agility_5",
		descKey = "grid_skill_agility_5_desc",
		U = 20,
		need = "agility_4",
		RunSpeed = 0.02,
		Jump = 0.02,
		Health = -2
	},
	ranged_1 = {
		tree = "ranged",
		slot = 0,
		nameKey = "grid_skill_ranged_1",
		descKey = "grid_skill_ranged_1_desc",
		U = 20,
		Reload = 0.03
	},
	ranged_2 = {
		tree = "ranged",
		slot = 1,
		nameKey = "grid_skill_ranged_2",
		descKey = "grid_skill_ranged_2_desc",
		U = 20,
		Recoil = -0.03
	},
	build_1 = {
		tree = "build",
		slot = 0,
		nameKey = "grid_skill_build_1",
		descKey = "grid_skill_build_1_desc",
		U = 20,
		Repair = 0.04
	},
	build_2 = {
		tree = "build",
		slot = 1,
		nameKey = "grid_skill_build_2",
		descKey = "grid_skill_build_2_desc",
		U = 20,
		HammerSwing = 0.07
	},
	build_3 = {
		tree = "build",
		slot = 2,
		nameKey = "grid_skill_build_3",
		descKey = "grid_skill_build_3_desc",
		U = 20,
		NailRange = 0.15
	},
	build_4 = {
		tree = "build",
		slot = 9,
		nameKey = "grid_skill_build_4",
		descKey = "grid_skill_build_4_desc",
		U = 20,
		DoorDamage = 0.40
	},
	mechanics_1 = {
		tree = "mechanics",
		slot = 0,
		nameKey = "grid_skill_mechanics_1",
		descKey = "grid_skill_mechanics_1_desc",
		U = 20,
		DeviceHealth = 0.05
	},
	medicine_1 = {
		tree = "medicine",
		slot = 0,
		nameKey = "grid_skill_medicine_1",
		descKey = "grid_skill_medicine_1_desc",
		U = 20,
		MedicHeal = 0.03
	},
	melee_1 = {
		tree = "melee",
		slot = 0,
		nameKey = "grid_skill_melee_1",
		descKey = "grid_skill_melee_1_desc",
		U = 20,
		MeleeDamage = 0.03
	},
	melee_2 = {
		tree = "melee",
		slot = 12,
		nameKey = "grid_skill_melee_2",
		descKey = "grid_skill_melee_2_desc",
		U = 20,
		MeleeViewPunch = -0.15,
		AimShake = 0.15,
		AimShakeThreshold = 0.15
	},
	shadow_1 = {
		tree = "shadow",
		slot = 0,
		nameKey = "grid_skill_shadow_1",
		descKey = "grid_skill_shadow_1_desc",
		U = 20,
		ZombieHealth = 0.03
	},
	supply_1 = {
		tree = "supply",
		slot = 0,
		nameKey = "grid_skill_supply_1",
		descKey = "grid_skill_supply_1_desc",
		U = 20,
		ResupplyAmmo = 0.04
	},
	supply_2 = {
		tree = "supply",
		slot = 1,
		nameKey = "grid_skill_supply_2",
		descKey = "grid_skill_supply_2_desc",
		U = 20,
		ArsenalMargin = 0.02
	},
	supply_3 = {
		tree = "supply",
		slot = 2,
		nameKey = "grid_skill_supply_3",
		descKey = "grid_skill_supply_3_desc",
		U = 20,
		ResupplyAmmo = 0.04
	},
	supply_4 = {
		tree = "supply",
		slot = 3,
		nameKey = "grid_skill_supply_4",
		descKey = "grid_skill_supply_4_desc",
		U = 20,
		ArsenalMargin = 0.02
	},
	supply_5 = {
		tree = "supply",
		slot = 13,
		nameKey = "grid_skill_supply_5",
		descKey = "grid_skill_supply_5_desc",
		U = 20,
		ArsenalRivalOthers = 0.02,
		ArsenalRivalSelf = 0.01
	},
	supply_6 = {
		tree = "supply",
		slot = 14,
		nameKey = "grid_skill_supply_6",
		descKey = "grid_skill_supply_6_desc",
		U = 20,
		need = "supply_5",
		ArsenalRivalOthers = 0.02,
		ArsenalRivalSelf = 0.01
	},
	vitality_2 = {
		tree = "vitality",
		slot = 1,
		nameKey = "grid_skill_vitality_2",
		descKey = "grid_skill_vitality_2_desc",
		U = 20,
		Blood = 2
	},
	vitality_3 = {
		tree = "vitality",
		slot = 2,
		nameKey = "grid_skill_vitality_3",
		descKey = "grid_skill_vitality_3_desc",
		U = 20,
		Health = 3
	}
}

GM.CycleGridByTreeSlot = {}
for id, skill in pairs(GM.CycleGridCatalog) do
	skill.id = id
	GM.CycleGridByTreeSlot[skill.tree] = GM.CycleGridByTreeSlot[skill.tree] or {}
	GM.CycleGridByTreeSlot[skill.tree][skill.slot] = skill
end

function GM:GetCycleGridSkill(treeId, slot)
	local byTree = treeId and self.CycleGridByTreeSlot[treeId]
	if not byTree then
		return nil
	end
	return byTree[slot]
end

function GM:GetCycleGridSkillById(id)
	return id and self.CycleGridCatalog[id] or nil
end

function GM:GetCycleGridTreeIndex(treeId)
	if not treeId then
		return nil
	end
	for i, tree in ipairs(self.CycleGridTrees) do
		if tree.id == treeId then
			return i
		end
	end
end

function GM:GetCycleGridNode(treeId, slot)
	local idx = self:GetCycleGridTreeIndex(treeId)
	if not idx then
		return nil
	end
	local tnodes = self:GetCycleGridLayout().byTree[idx]
	if not tnodes then
		return nil
	end
	for _, n in ipairs(tnodes) do
		if n.slot == slot then
			return n
		end
	end
end

function GM:InitCycleGrid(pl, wipe)
	if not IsValid(pl) then
		return
	end
	if wipe or not pl.CycleGridTaken then
		pl.CycleGridTaken = {}
	end
end

function GM:HasCycleGridSkill(pl, id)
	return IsValid(pl) and id and pl.CycleGridTaken and pl.CycleGridTaken[id] == true
end

function GM:CycleGridSlotTaken(pl, treeId, slot)
	local skill = self:GetCycleGridSkill(treeId, slot)
	if not skill then
		return false
	end
	return self:HasCycleGridSkill(pl, skill.id)
end

function GM:CycleGridTakenCount(pl)
	if not IsValid(pl) or not pl.CycleGridTaken then
		return 0
	end
	local n = 0
	for id in pairs(pl.CycleGridTaken) do
		if self.CycleGridCatalog[id] then
			n = n + 1
		end
	end
	return n
end

function GM:GetCycleGridSPTotal(pl)
	if not IsValid(pl) then
		return 0
	end
	local level = pl.GetZSLevel and pl:GetZSLevel() or 1
	local remort = pl.GetZSRemortLevel and pl:GetZSRemortLevel() or 0
	return math.max(0, level - 1) + remort
end

function GM:GetCycleGridSPUsed(pl)
	return self:CycleGridTakenCount(pl)
end

function GM:GetCycleGridSPRemaining(pl)
	return math.max(0, self:GetCycleGridSPTotal(pl) - self:GetCycleGridSPUsed(pl))
end

function GM:HasCycleGridVault(pl)
	return self:CycleGridTakenCount(pl) > 0
end

function GM:CycleGridNeighborOk(pl, treeId, slot)
	if slot == 0 then
		return true
	end
	local skill = self:GetCycleGridSkill(treeId, slot)
	if skill and skill.need and not self:HasCycleGridSkill(pl, skill.need) then
		return false
	end
	local node = self:GetCycleGridNode(treeId, slot)
	if not node then
		return false
	end
	local p = node.parent
	while p do
		if self:GetCycleGridSkill(treeId, p.slot) then
			return self:CycleGridSlotTaken(pl, treeId, p.slot)
		end
		p = p.parent
	end
	return true
end

function GM:CycleGridIsOffered(pl, treeId, slot)
	if not IsValid(pl) then
		return false
	end
	local skill = self:GetCycleGridSkill(treeId, slot)
	if not skill then
		return false
	end
	if self:HasCycleGridSkill(pl, skill.id) then
		return false
	end
	return self:CycleGridNeighborOk(pl, treeId, slot)
end

function GM:CycleGridCanUnlock(pl, treeId, slot)
	return self:CycleGridIsOffered(pl, treeId, slot) and self:GetCycleGridSPRemaining(pl) >= 1
end

local GRID_SKILL_META = {
	tree = true,
	slot = true,
	nameKey = true,
	descKey = true,
	U = true,
	id = true,
	need = true
}

function GM:GetCycleGridStatAdd(pl, field)
	if not IsValid(pl) or not pl.CycleGridTaken or not field then
		return 0
	end
	local add = 0
	for id in pairs(pl.CycleGridTaken) do
		local skill = self.CycleGridCatalog[id]
		local v = skill and skill[field]
		if isnumber(v) then
			add = add + v
		end
	end
	return add
end

function GM:GetCycleGridHealthAdd(pl)
	return self:GetCycleGridStatAdd(pl, "Health")
end

function GM:GetCycleGridBloodAdd(pl)
	return self:GetCycleGridStatAdd(pl, "Blood")
end

function GM:GetHumanBloodArmorMax(pl)
	local base = (self.ZombieEscape and 0) or (self.HumanBloodArmor or 15)
	if IsValid(pl) and isnumber(pl.MaxBloodArmor) then
		base = pl.MaxBloodArmor
	end
	if CLIENT then
		base = base + self:GetCycleGridBloodAdd(pl)
	end
	return math.max(0, base)
end

function GM:GetCycleGridStatAdds(pl)
	local adds = {}
	if not IsValid(pl) or not pl.CycleGridTaken then
		return adds
	end
	for id in pairs(pl.CycleGridTaken) do
		local skill = self.CycleGridCatalog[id]
		if not skill then continue end
		for k, v in pairs(skill) do
			if not GRID_SKILL_META[k] and isnumber(v) and v ~= 0 then
				adds[k] = (adds[k] or 0) + v
			end
		end
	end
	return adds
end

function GM:ApplyCycleGridModifiers(pl)
	if not SERVER or not IsValid(pl) or pl:Team() ~= TEAM_HUMAN then
		return
	end
	local add = self:GetCycleGridHealthAdd(pl)
	if add ~= 0 then
		local current = math.max(1, pl:GetMaxHealth())
		local new = current + add
		pl:SetMaxHealth(new)
		pl:SetHealth(math.max(1, math.floor(pl:Health() / current * new + 0.5)))
	end
	local blood = self:GetCycleGridBloodAdd(pl)
	if blood ~= 0 then
		local current = math.max(1, pl.MaxBloodArmor or self.HumanBloodArmor or 15)
		local new = current + blood
		pl.MaxBloodArmor = new
		pl:SetBloodArmor(math.max(0, math.floor(pl:GetBloodArmor() / current * new + 0.5)))
	end
	pl:ResetSpeed()
	pl:ResetJumpPower()
	self:ApplyCycleGridDeviceHealth(pl)
end

local MECHANICS_HEALTH_REFRESH = {
	"prop_gunturret*",
	"prop_zapper*",
	"prop_repairfield",
	"prop_ffemitter",
	"prop_drone",
	"prop_drone_pulse",
	"prop_drone_hauler",
	"prop_manhack",
	"prop_manhack_saw",
	"prop_rollermine"
}

function GM:ApplyCycleGridDeviceHealth(pl)
	if not SERVER or not IsValid(pl) then
		return
	end
	for i = 1, #MECHANICS_HEALTH_REFRESH do
		local found = ents.FindByClass(MECHANICS_HEALTH_REFRESH[i])
		for j = 1, #found do
			local ent = found[j]
			if not (ent:IsValid() and ent.GetObjectOwner and ent:GetObjectOwner() == pl) then
				continue
			end
			if isfunction(ent.SetupPlayerSkills) then
				ent:SetupPlayerSkills()
			elseif isfunction(ent.SetupDeployableSkillHealth) then
				ent:SetupDeployableSkillHealth()
			end
		end
	end
end
