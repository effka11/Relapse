-- Cycle grid skeleton.
-- Law: documents/cycle-grid.md
-- Nine bushes traced from the hand-drawn web. Slot 0 is the gate. Graph follows the drawing.

GM.CycleGridSlots = 19
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

-- Positions are layout x,y (y up), hub at origin. Parent is a slot on the same tree.
local BUSH_PARENT = {
	{ -- vitality
		[1] = 0, [2] = 0, [3] = 1, [4] = 1, [5] = 2, [6] = 3, [7] = 3, [8] = 4, [9] = 6, [10] = 7, [11] = 7, [12] = 8, [13] = 8, [14] = 9, [15] = 9
	},
	{ -- supply
		[1] = 0, [2] = 0, [3] = 1, [4] = 2, [5] = 4, [6] = 4, [7] = 5, [8] = 5, [9] = 6, [10] = 7, [11] = 9, [12] = 9, [13] = 11, [14] = 11
	},
	{ -- mechanics
		[1] = 0, [2] = 0, [3] = 1, [4] = 1, [5] = 1, [6] = 2, [7] = 3, [8] = 4, [9] = 5, [10] = 8, [11] = 8, [12] = 9, [13] = 9, [14] = 10, [15] = 10, [16] = 12, [17] = 13
	},
	{ -- medicine
		[1] = 0, [2] = 0, [3] = 1, [4] = 2, [5] = 3, [6] = 3, [7] = 4, [8] = 6, [9] = 6, [10] = 8, [11] = 8, [12] = 9, [13] = 9
	},
	{ -- ranged
		[1] = 0, [2] = 0, [3] = 1, [4] = 2, [5] = 2, [6] = 3, [7] = 3, [8] = 5, [9] = 5, [10] = 6, [11] = 7, [12] = 8, [13] = 8, [14] = 9, [15] = 11, [16] = 12
	},
	{ -- shadow
		[1] = 0, [2] = 0, [4] = 1, [5] = 1, [6] = 4, [7] = 4, [8] = 5, [9] = 5, [10] = 6, [11] = 6, [12] = 8, [13] = 12
	},
	{ -- build
		[1] = 0, [2] = 0, [3] = 1, [4] = 1, [5] = 2, [6] = 3, [7] = 4, [8] = 4, [9] = 5, [10] = 6, [11] = 6, [12] = 7, [13] = 8, [14] = 8, [15] = 10, [16] = 10, [17] = 11, [18] = 13
	},
	{ -- melee
		[1] = 0, [2] = 0, [3] = 1, [4] = 1, [5] = 2, [6] = 2, [7] = 3, [8] = 4, [9] = 4, [10] = 8, [11] = 8, [12] = 9, [13] = 10, [14] = 11, [15] = 11, [16] = 14, [17] = 14
	},
	{ -- agility
		[1] = 0, [2] = 0, [3] = 1, [4] = 1, [5] = 2, [6] = 3, [7] = 3, [8] = 4, [9] = 6, [10] = 7, [11] = 7, [12] = 8, [13] = 9, [14] = 12, [15] = 12
	},
}

local BUSH_POS = {
	{ -- vitality
		{ -0.489, 0.305 },
		{ -1.097, 0.543 },
		{ -0.663, 0.652 },
		{ -1.551, 0.387 },
		{ -1.711, 0.961 },
		{ -1.122, 0.895 },
		{ -2.089, -0.099 },
		{ -2.056, 0.538 },
		{ -1.945, 1.389 },
		{ -2.718, 0.407 },
		{ -2.063, 0.295 },
		{ -2.232, 1.021 },
		{ -2.441, 1.609 },
		{ -2.062, 1.787 },
		{ -3.306, 0.508 },
		{ -2.871, 1.075 },
	},
	{ -- supply
		{ 0.234, -0.403 },
		{ 0.639, -0.444 },
		{ 0.323, -0.821 },
		{ 0.697, -0.781 },
		{ 0.629, -1.189 },
		{ 1.052, -1.581 },
		{ 0.452, -1.632 },
		{ 1.667, -1.723 },
		{ 1.171, -1.879 },
		{ 0.969, -2.185 },
		{ 2.024, -2.201 },
		{ 1.578, -2.457 },
		{ 0.614, -2.474 },
		{ 1.776, -2.787 },
		{ 1.126, -2.809 },
	},
	{ -- mechanics
		{ 0.464, 0.254 },
		{ 1.000, 0.427 },
		{ 0.925, 0.106 },
		{ 1.019, 0.888 },
		{ 1.444, 0.738 },
		{ 1.672, 0.382 },
		{ 1.388, 0.113 },
		{ 1.728, 1.134 },
		{ 1.943, 0.787 },
		{ 2.132, 0.182 },
		{ 2.421, 1.072 },
		{ 2.040, 0.543 },
		{ 2.771, 0.615 },
		{ 2.693, 0.144 },
		{ 2.088, 1.307 },
		{ 2.514, 1.683 },
		{ 2.957, 1.248 },
		{ 3.288, 0.389 },
	},
	{ -- medicine
		{ -0.083, -0.634 },
		{ -0.399, -1.010 },
		{ 0.121, -1.123 },
		{ -0.364, -1.445 },
		{ 0.065, -1.493 },
		{ -0.146, -1.139 },
		{ -0.217, -1.805 },
		{ 0.281, -2.038 },
		{ 0.067, -2.506 },
		{ -0.459, -2.335 },
		{ 0.574, -3.041 },
		{ -0.077, -3.097 },
		{ -0.569, -2.861 },
		{ -0.824, -2.401 },
	},
	{ -- ranged
		{ 0.212, 0.556 },
		{ 0.145, 0.989 },
		{ 0.648, 0.653 },
		{ 0.277, 1.479 },
		{ 0.424, 0.926 },
		{ 0.698, 1.203 },
		{ 0.143, 2.019 },
		{ 0.603, 1.720 },
		{ 1.052, 1.635 },
		{ 1.208, 1.288 },
		{ 0.187, 2.744 },
		{ 0.639, 2.318 },
		{ 1.198, 2.108 },
		{ 1.816, 2.034 },
		{ 1.766, 1.571 },
		{ 0.952, 2.858 },
		{ 1.727, 2.629 },
	},
	{ -- shadow
		{ -0.368, -0.351 },
		{ -0.701, -0.813 },
		{ -0.815, -0.490 },
		false, -- slot 3 overlapped 5
		{ -1.288, -1.189 },
		{ -0.757, -1.284 },
		{ -1.697, -1.877 },
		{ -1.845, -1.305 },
		{ -0.716, -1.852 },
		{ -1.098, -1.728 },
		{ -2.236, -2.390 },
		{ -2.293, -1.728 },
		{ -1.328, -2.260 },
		{ -1.221, -2.738 },
	},
	{ -- build
		{ 0.642, -0.149 },
		{ 1.211, -0.195 },
		{ 1.085, -0.567 },
		{ 1.785, -0.110 },
		{ 1.500, -0.528 },
		{ 1.035, -0.953 },
		{ 2.299, -0.347 },
		{ 1.842, -0.471 },
		{ 1.570, -0.970 },
		{ 1.364, -1.343 },
		{ 2.877, -0.201 },
		{ 2.531, -0.771 },
		{ 2.105, -0.734 },
		{ 2.196, -1.080 },
		{ 1.816, -1.367 },
		{ 3.402, -0.546 },
		{ 2.853, -0.506 },
		{ 3.014, -1.066 },
		{ 2.418, -1.622 },
	},
	{ -- melee
		{ -0.693, -0.073 },
		{ -1.151, -0.309 },
		{ -0.921, 0.219 },
		{ -1.146, -0.771 },
		{ -1.829, -0.496 },
		{ -1.044, -0.025 },
		{ -1.599, -0.034 },
		{ -1.751, -0.906 },
		{ -2.240, -1.031 },
		{ -2.479, -0.395 },
		{ -2.819, -1.378 },
		{ -2.797, -0.893 },
		{ -2.791, -0.064 },
		{ -2.942, -1.849 },
		{ -2.942, -0.461 },
		{ -2.356, -0.717 },
		{ -3.519, -0.471 },
		{ -3.376, -0.016 },
	},
	{ -- agility
		{ -0.172, 0.427 },
		{ -0.496, 0.917 },
		{ -0.080, 0.822 },
		{ -0.841, 1.205 },
		{ -0.593, 1.526 },
		{ -0.266, 1.371 },
		{ -1.364, 1.271 },
		{ -1.035, 1.790 },
		{ -0.134, 1.760 },
		{ -1.602, 1.824 },
		{ -1.439, 2.450 },
		{ -0.682, 1.893 },
		{ -0.694, 2.453 },
		{ -2.214, 2.403 },
		{ -0.466, 2.932 },
		{ -0.257, 2.420 },
	},
}

local function LayoutBush(treeIndex, tree)
	local coords = BUSH_POS[treeIndex]
	local parents = BUSH_PARENT[treeIndex]
	local nodes = {}
	local bySlot = {}
	for slot = 0, #coords - 1 do
		local c = coords[slot + 1]
		if not c then
			continue
		end
		local x, y = c[1], c[2]
		local parent
		local parentSlot = parents[slot]
		while parentSlot do
			parent = bySlot[parentSlot]
			if parent then
				break
			end
			parentSlot = parents[parentSlot]
		end
		local ang
		if parent then
			ang = math.atan2(y - parent.y, x - parent.x)
		else
			ang = math.atan2(y, x)
		end
		local n = {
			tree = treeIndex,
			treeId = tree.id,
			slot = slot,
			x = x,
			y = y,
			parent = parent,
			ang = ang,
			kind = slot == 0 and "gate" or "twig",
			inx = math.cos(ang),
			iny = math.sin(ang)
		}
		nodes[#nodes + 1] = n
		bySlot[slot] = n
	end
	return nodes
end

GM.CycleGridLayout = nil

function GM:GetCycleGridLayout()
	if self.CycleGridLayout then
		return self.CycleGridLayout
	end

	local nodes = {}
	local edges = {}
	local labels = {}
	local hub = { x = 0, y = 0 }
	local byTree = {}

	for i, tree in ipairs(self.CycleGridTrees) do
		local tnodes = LayoutBush(i, tree)
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
			local d = n.x * n.x + n.y * n.y
			if d > farD then
				far, farD = n, d
			end
		end
		local len = math.sqrt(far.x * far.x + far.y * far.y)
		local ux, uy = 0, 1
		if len > 0.001 then
			ux, uy = far.x / len, far.y / len
		end
		labels[#labels + 1] = {
			tree = i,
			treeId = tree.id,
			nameKey = tree.nameKey,
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
-- Slot 0 is the gate. Other slots are nests on that tree's drawn bush.
GM.CycleGridCatalog = {
	vitality_1 = {
		tree = "vitality",
		slot = 0,
		nameKey = "grid_skill_vitality_1",
		descKey = "grid_skill_vitality_1_desc",
		U = 20,
		Health = 3
	},
	vitality_3 = {
		tree = "vitality",
		slot = 2,
		nameKey = "grid_skill_vitality_3",
		descKey = "grid_skill_vitality_3_desc",
		U = 20,
		need = "vitality_1",
		Health = 3
	},
	vitality_4 = {
		tree = "vitality",
		slot = 5,
		nameKey = "grid_skill_vitality_4",
		descKey = "grid_skill_vitality_4_desc",
		U = 20,
		need = "vitality_3",
		Health = 3
	},
	vitality_2 = {
		tree = "vitality",
		slot = 1,
		nameKey = "grid_skill_vitality_2",
		descKey = "grid_skill_vitality_2_desc",
		U = 20,
		Blood = 2
	},
	vitality_5 = {
		tree = "vitality",
		slot = 3,
		nameKey = "grid_skill_vitality_5",
		descKey = "grid_skill_vitality_5_desc",
		U = 20,
		need = "vitality_2",
		Blood = 2
	},
	vitality_6 = {
		tree = "vitality",
		slot = 7,
		nameKey = "grid_skill_vitality_6",
		descKey = "grid_skill_vitality_6_desc",
		U = 20,
		need = "vitality_5",
		Blood = 2
	},
	vitality_7 = {
		tree = "vitality",
		slot = 6,
		nameKey = "grid_skill_vitality_7",
		descKey = "grid_skill_vitality_7_desc",
		U = 20,
		BloodAbsorb = 0.04
	},
	vitality_8 = {
		tree = "vitality",
		slot = 9,
		nameKey = "grid_skill_vitality_8",
		descKey = "grid_skill_vitality_8_desc",
		U = 20,
		need = "vitality_7",
		BloodAbsorb = 0.04
	},
	vitality_9 = {
		tree = "vitality",
		slot = 15,
		nameKey = "grid_skill_vitality_9",
		descKey = "grid_skill_vitality_9_desc",
		U = 20,
		need = "vitality_8",
		BloodAbsorb = 0.04
	},
	vitality_10 = {
		tree = "vitality",
		slot = 4,
		nameKey = "grid_skill_vitality_10",
		descKey = "grid_skill_vitality_10_desc",
		U = 20,
		BloodGain = 0.03
	},
	vitality_11 = {
		tree = "vitality",
		slot = 8,
		nameKey = "grid_skill_vitality_11",
		descKey = "grid_skill_vitality_11_desc",
		U = 20,
		need = "vitality_10",
		BloodGain = 0.03
	},
	vitality_12 = {
		tree = "vitality",
		slot = 13,
		nameKey = "grid_skill_vitality_12",
		descKey = "grid_skill_vitality_12_desc",
		U = 20,
		need = "vitality_11",
		BloodGain = 0.03
	},
	vitality_13 = {
		tree = "vitality",
		slot = 11,
		nameKey = "grid_skill_vitality_13",
		descKey = "grid_skill_vitality_13_desc",
		U = 20,
		Blood = 5,
		BloodAbsorb = -0.10
	},
	vitality_14 = {
		tree = "vitality",
		slot = 12,
		nameKey = "grid_skill_vitality_14",
		descKey = "grid_skill_vitality_14_desc",
		U = 20,
		FoodBlood = 0.15
	},
	vitality_15 = {
		tree = "vitality",
		slot = 14,
		nameKey = "grid_skill_vitality_15",
		descKey = "grid_skill_vitality_15_desc",
		U = 20,
		BloodReturn = 0.10
	},
	agility_1 = {
		tree = "agility",
		slot = 0,
		nameKey = "grid_skill_agility_1",
		descKey = "grid_skill_agility_1_desc",
		U = 20,
		RunSpeed = 0.03
	},
	agility_3 = {
		tree = "agility",
		slot = 2,
		nameKey = "grid_skill_agility_3",
		descKey = "grid_skill_agility_3_desc",
		U = 20,
		need = "agility_1",
		RunSpeed = 0.03
	},
	agility_6 = {
		tree = "agility",
		slot = 5,
		nameKey = "grid_skill_agility_6",
		descKey = "grid_skill_agility_6_desc",
		U = 20,
		need = "agility_3",
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
	agility_7 = {
		tree = "agility",
		slot = 4,
		nameKey = "grid_skill_agility_7",
		descKey = "grid_skill_agility_7_desc",
		U = 20,
		need = "agility_2",
		Jump = 0.02,
		Climb = 0.02
	},
	agility_8 = {
		tree = "agility",
		slot = 8,
		nameKey = "grid_skill_agility_8",
		descKey = "grid_skill_agility_8_desc",
		U = 20,
		need = "agility_7",
		Jump = 0.02,
		Climb = 0.02
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
		slot = 14,
		nameKey = "grid_skill_agility_5",
		descKey = "grid_skill_agility_5_desc",
		U = 20,
		need = "agility_4",
		RunSpeed = 0.02,
		Jump = 0.02,
		Health = -2
	},
	agility_9 = {
		tree = "agility",
		slot = 3,
		nameKey = "grid_skill_agility_9",
		descKey = "grid_skill_agility_9_desc",
		U = 20,
		Phase = 0.05
	},
	agility_10 = {
		tree = "agility",
		slot = 7,
		nameKey = "grid_skill_agility_10",
		descKey = "grid_skill_agility_10_desc",
		U = 20,
		need = "agility_9",
		Phase = 0.05
	},
	agility_11 = {
		tree = "agility",
		slot = 10,
		nameKey = "grid_skill_agility_11",
		descKey = "grid_skill_agility_11_desc",
		U = 20,
		need = "agility_10",
		Phase = 0.05
	},
	agility_12 = {
		tree = "agility",
		slot = 11,
		nameKey = "grid_skill_agility_12",
		descKey = "grid_skill_agility_12_desc",
		U = 20,
		Phase = 0.10,
		Health = -4
	},
	ranged_1 = {
		tree = "ranged",
		slot = 0,
		nameKey = "grid_skill_ranged_1",
		descKey = "grid_skill_ranged_1_desc",
		U = 20,
		Reload = 0.03
	},
	ranged_3 = {
		tree = "ranged",
		slot = 1,
		nameKey = "grid_skill_ranged_3",
		descKey = "grid_skill_ranged_3_desc",
		U = 20,
		need = "ranged_1",
		Reload = 0.03
	},
	ranged_4 = {
		tree = "ranged",
		slot = 3,
		nameKey = "grid_skill_ranged_4",
		descKey = "grid_skill_ranged_4_desc",
		U = 20,
		need = "ranged_3",
		Reload = 0.03
	},
	ranged_2 = {
		tree = "ranged",
		slot = 2,
		nameKey = "grid_skill_ranged_2",
		descKey = "grid_skill_ranged_2_desc",
		U = 20,
		Recoil = -0.03
	},
	ranged_5 = {
		tree = "ranged",
		slot = 5,
		nameKey = "grid_skill_ranged_5",
		descKey = "grid_skill_ranged_5_desc",
		U = 20,
		need = "ranged_2",
		Recoil = -0.03
	},
	ranged_6 = {
		tree = "ranged",
		slot = 9,
		nameKey = "grid_skill_ranged_6",
		descKey = "grid_skill_ranged_6_desc",
		U = 20,
		need = "ranged_5",
		Recoil = -0.03
	},
	ranged_7 = {
		tree = "ranged",
		slot = 7,
		nameKey = "grid_skill_ranged_7",
		descKey = "grid_skill_ranged_7_desc",
		U = 20,
		Deploy = 0.10
	},
	ranged_8 = {
		tree = "ranged",
		slot = 11,
		nameKey = "grid_skill_ranged_8",
		descKey = "grid_skill_ranged_8_desc",
		U = 20,
		need = "ranged_7",
		Deploy = 0.10
	},
	ranged_9 = {
		tree = "ranged",
		slot = 15,
		nameKey = "grid_skill_ranged_9",
		descKey = "grid_skill_ranged_9_desc",
		U = 20,
		need = "ranged_8",
		Deploy = 0.10
	},
	ranged_10 = {
		tree = "ranged",
		slot = 8,
		nameKey = "grid_skill_ranged_10",
		descKey = "grid_skill_ranged_10_desc",
		U = 20,
		GunFire = 0.02
	},
	ranged_11 = {
		tree = "ranged",
		slot = 12,
		nameKey = "grid_skill_ranged_11",
		descKey = "grid_skill_ranged_11_desc",
		U = 20,
		need = "ranged_10",
		GunFire = 0.02
	},
	ranged_12 = {
		tree = "ranged",
		slot = 16,
		nameKey = "grid_skill_ranged_12",
		descKey = "grid_skill_ranged_12_desc",
		U = 20,
		need = "ranged_11",
		GunFire = 0.02
	},
	ranged_13 = {
		tree = "ranged",
		slot = 13,
		nameKey = "grid_skill_ranged_13",
		descKey = "grid_skill_ranged_13_desc",
		U = 20,
		RangedShop = 0.10
	},
	ranged_14 = {
		tree = "ranged",
		slot = 14,
		nameKey = "grid_skill_ranged_14",
		descKey = "grid_skill_ranged_14_desc",
		U = 20,
		Recoil = -0.09,
		Deploy = -0.30
	},
	build_1 = {
		tree = "build",
		slot = 0,
		nameKey = "grid_skill_build_1",
		descKey = "grid_skill_build_1_desc",
		U = 20,
		Repair = 0.04
	},
	build_5 = {
		tree = "build",
		slot = 2,
		nameKey = "grid_skill_build_5",
		descKey = "grid_skill_build_5_desc",
		U = 20,
		need = "build_1",
		Repair = 0.04
	},
	build_6 = {
		tree = "build",
		slot = 5,
		nameKey = "grid_skill_build_6",
		descKey = "grid_skill_build_6_desc",
		U = 20,
		need = "build_5",
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
	build_7 = {
		tree = "build",
		slot = 4,
		nameKey = "grid_skill_build_7",
		descKey = "grid_skill_build_7_desc",
		U = 20,
		need = "build_2",
		HammerSwing = 0.07
	},
	build_8 = {
		tree = "build",
		slot = 7,
		nameKey = "grid_skill_build_8",
		descKey = "grid_skill_build_8_desc",
		U = 20,
		need = "build_7",
		HammerSwing = 0.07
	},
	build_3 = {
		tree = "build",
		slot = 8,
		nameKey = "grid_skill_build_3",
		descKey = "grid_skill_build_3_desc",
		U = 20,
		NailRange = 0.15
	},
	build_9 = {
		tree = "build",
		slot = 14,
		nameKey = "grid_skill_build_9",
		descKey = "grid_skill_build_9_desc",
		U = 20,
		need = "build_3",
		NailRange = 0.15
	},
	build_4 = {
		tree = "build",
		slot = 12,
		nameKey = "grid_skill_build_4",
		descKey = "grid_skill_build_4_desc",
		U = 20,
		DoorDamage = 0.40
	},
	build_10 = {
		tree = "build",
		slot = 13,
		nameKey = "grid_skill_build_10",
		descKey = "grid_skill_build_10_desc",
		U = 20,
		MaxNails = 1
	},
	build_11 = {
		tree = "build",
		slot = 18,
		nameKey = "grid_skill_build_11",
		descKey = "grid_skill_build_11_desc",
		U = 20,
		need = "build_10",
		MaxNails = 1
	},
	build_12 = {
		tree = "build",
		slot = 3,
		nameKey = "grid_skill_build_12",
		descKey = "grid_skill_build_12_desc",
		U = 20,
		RepairPerNail = 0.01
	},
	build_13 = {
		tree = "build",
		slot = 6,
		nameKey = "grid_skill_build_13",
		descKey = "grid_skill_build_13_desc",
		U = 20,
		need = "build_12",
		RepairPerNail = 0.01
	},
	build_14 = {
		tree = "build",
		slot = 11,
		nameKey = "grid_skill_build_14",
		descKey = "grid_skill_build_14_desc",
		U = 20,
		need = "build_13",
		RepairPerNail = 0.01
	},
	mechanics_1 = {
		tree = "mechanics",
		slot = 0,
		nameKey = "grid_skill_mechanics_1",
		descKey = "grid_skill_mechanics_1_desc",
		U = 20,
		DeviceHealth = 0.05
	},
	mechanics_2 = {
		tree = "mechanics",
		slot = 2,
		nameKey = "grid_skill_mechanics_2",
		descKey = "grid_skill_mechanics_2_desc",
		U = 20,
		need = "mechanics_1",
		DeviceHealth = 0.05
	},
	mechanics_3 = {
		tree = "mechanics",
		slot = 6,
		nameKey = "grid_skill_mechanics_3",
		descKey = "grid_skill_mechanics_3_desc",
		U = 20,
		need = "mechanics_2",
		DeviceHealth = 0.05
	},
	mechanics_4 = {
		tree = "mechanics",
		slot = 1,
		nameKey = "grid_skill_mechanics_4",
		descKey = "grid_skill_mechanics_4_desc",
		U = 20,
		DeviceHandle = 0.07
	},
	mechanics_5 = {
		tree = "mechanics",
		slot = 3,
		nameKey = "grid_skill_mechanics_5",
		descKey = "grid_skill_mechanics_5_desc",
		U = 20,
		need = "mechanics_4",
		DeviceHandle = 0.07
	},
	mechanics_6 = {
		tree = "mechanics",
		slot = 7,
		nameKey = "grid_skill_mechanics_6",
		descKey = "grid_skill_mechanics_6_desc",
		U = 20,
		need = "mechanics_5",
		DeviceHandle = 0.07
	},
	mechanics_7 = {
		tree = "mechanics",
		slot = 5,
		nameKey = "grid_skill_mechanics_7",
		descKey = "grid_skill_mechanics_7_desc",
		U = 20,
		TurretFire = 0.03
	},
	mechanics_8 = {
		tree = "mechanics",
		slot = 9,
		nameKey = "grid_skill_mechanics_8",
		descKey = "grid_skill_mechanics_8_desc",
		U = 20,
		need = "mechanics_7",
		TurretFire = 0.03
	},
	mechanics_9 = {
		tree = "mechanics",
		slot = 13,
		nameKey = "grid_skill_mechanics_9",
		descKey = "grid_skill_mechanics_9_desc",
		U = 20,
		need = "mechanics_8",
		TurretFire = 0.03
	},
	mechanics_10 = {
		tree = "mechanics",
		slot = 17,
		nameKey = "grid_skill_mechanics_10",
		descKey = "grid_skill_mechanics_10_desc",
		U = 20,
		TurretFire = 0.15
	},
	medicine_1 = {
		tree = "medicine",
		slot = 0,
		nameKey = "grid_skill_medicine_1",
		descKey = "grid_skill_medicine_1_desc",
		U = 20,
		MedicHeal = 0.03
	},
	medicine_2 = {
		tree = "medicine",
		slot = 2,
		nameKey = "grid_skill_medicine_2",
		descKey = "grid_skill_medicine_2_desc",
		U = 20,
		need = "medicine_1",
		MedicHeal = 0.03
	},
	medicine_3 = {
		tree = "medicine",
		slot = 4,
		nameKey = "grid_skill_medicine_3",
		descKey = "grid_skill_medicine_3_desc",
		U = 20,
		need = "medicine_2",
		MedicHeal = 0.03
	},
	medicine_5 = {
		tree = "medicine",
		slot = 7,
		nameKey = "grid_skill_medicine_5",
		descKey = "grid_skill_medicine_5_desc",
		U = 20,
		MedicHeal = 0.07,
		Heal = -0.05
	},
	medicine_4 = {
		tree = "medicine",
		slot = 9,
		nameKey = "grid_skill_medicine_4",
		descKey = "grid_skill_medicine_4_desc",
		U = 20,
		UnlockShop = "aloe"
	},
	medicine_12 = {
		tree = "medicine",
		slot = 12,
		nameKey = "grid_skill_medicine_12",
		descKey = "grid_skill_medicine_12_desc",
		U = 20,
		need = "medicine_4",
		AloeRegen = 0.11,
		AloePoison = 0.01
	},
	medicine_13 = {
		tree = "medicine",
		slot = 13,
		nameKey = "grid_skill_medicine_13",
		descKey = "grid_skill_medicine_13_desc",
		U = 20,
		need = "medicine_4",
		AloeGrow = -60
	},
	medicine_6 = {
		tree = "medicine",
		slot = 1,
		nameKey = "grid_skill_medicine_6",
		descKey = "grid_skill_medicine_6_desc",
		U = 20,
		MedkitCharge = 0.10
	},
	medicine_7 = {
		tree = "medicine",
		slot = 3,
		nameKey = "grid_skill_medicine_7",
		descKey = "grid_skill_medicine_7_desc",
		U = 20,
		need = "medicine_6",
		MedkitCharge = 0.10
	},
	medicine_8 = {
		tree = "medicine",
		slot = 6,
		nameKey = "grid_skill_medicine_8",
		descKey = "grid_skill_medicine_8_desc",
		U = 20,
		need = "medicine_7",
		MedkitCharge = 0.10
	},
	melee_1 = {
		tree = "melee",
		slot = 0,
		nameKey = "grid_skill_melee_1",
		descKey = "grid_skill_melee_1_desc",
		U = 20,
		MeleeDamage = 0.03
	},
	melee_5 = {
		tree = "melee",
		slot = 2,
		nameKey = "grid_skill_melee_5",
		descKey = "grid_skill_melee_5_desc",
		U = 20,
		need = "melee_1",
		MeleeDamage = 0.03
	},
	melee_8 = {
		tree = "melee",
		slot = 6,
		nameKey = "grid_skill_melee_8",
		descKey = "grid_skill_melee_8_desc",
		U = 20,
		need = "melee_5",
		MeleeDamage = 0.03
	},
	melee_3 = {
		tree = "melee",
		slot = 1,
		nameKey = "grid_skill_melee_3",
		descKey = "grid_skill_melee_3_desc",
		U = 20,
		MeleeSwing = 0.03
	},
	melee_7 = {
		tree = "melee",
		slot = 3,
		nameKey = "grid_skill_melee_7",
		descKey = "grid_skill_melee_7_desc",
		U = 20,
		need = "melee_3",
		MeleeSwing = 0.03
	},
	melee_10 = {
		tree = "melee",
		slot = 7,
		nameKey = "grid_skill_melee_10",
		descKey = "grid_skill_melee_10_desc",
		U = 20,
		need = "melee_7",
		MeleeSwing = 0.03
	},
	melee_6 = {
		tree = "melee",
		slot = 4,
		nameKey = "grid_skill_melee_6",
		descKey = "grid_skill_melee_6_desc",
		U = 20,
		MeleeStamina = -0.04
	},
	melee_9 = {
		tree = "melee",
		slot = 9,
		nameKey = "grid_skill_melee_9",
		descKey = "grid_skill_melee_9_desc",
		U = 20,
		need = "melee_6",
		MeleeStamina = -0.04
	},
	melee_11 = {
		tree = "melee",
		slot = 12,
		nameKey = "grid_skill_melee_11",
		descKey = "grid_skill_melee_11_desc",
		U = 20,
		need = "melee_9",
		MeleeStamina = -0.04
	},
	melee_12 = {
		tree = "melee",
		slot = 8,
		nameKey = "grid_skill_melee_12",
		descKey = "grid_skill_melee_12_desc",
		U = 20,
		BloodFromMelee = 0.01
	},
	melee_13 = {
		tree = "melee",
		slot = 10,
		nameKey = "grid_skill_melee_13",
		descKey = "grid_skill_melee_13_desc",
		U = 20,
		need = "melee_12",
		BloodFromMelee = 0.01
	},
	melee_14 = {
		tree = "melee",
		slot = 13,
		nameKey = "grid_skill_melee_14",
		descKey = "grid_skill_melee_14_desc",
		U = 20,
		need = "melee_13",
		BloodFromMelee = 0.01
	},
	melee_2 = {
		tree = "melee",
		slot = 11,
		nameKey = "grid_skill_melee_2",
		descKey = "grid_skill_melee_2_desc",
		U = 20,
		MeleeDamage = 0.03,
		MeleeViewPunch = -0.30,
		AimShake = 0.15
	},
	melee_4 = {
		tree = "melee",
		slot = 15,
		nameKey = "grid_skill_melee_4",
		descKey = "grid_skill_melee_4_desc",
		U = 20,
		need = "melee_2",
		MeleeDamage = 0.03,
		AimShakeFear = -0.10,
		AimShakeHP = 0.20
	},
	melee_15 = {
		tree = "melee",
		slot = 17,
		nameKey = "grid_skill_melee_15",
		descKey = "grid_skill_melee_15_desc",
		U = 20,
		need = "melee_2",
		MeleeDamage = 0.03,
		MeleeSwing = 0.07,
		AimShakeFear = 0.25
	},
	melee_16 = {
		tree = "melee",
		slot = 14,
		nameKey = "grid_skill_melee_16",
		descKey = "grid_skill_melee_16_desc",
		U = 20,
		need = "melee_2",
		MeleeDamage = 0.03,
		Heal = -0.05
	},
	melee_17 = {
		tree = "melee",
		slot = 16,
		nameKey = "grid_skill_melee_17",
		descKey = "grid_skill_melee_17_desc",
		U = 20,
		need = "melee_2",
		MeleeDamage = 0.03,
		MeleeMiss = 0.04,
		HitSlow = -0.75
	},
	melee_18 = {
		tree = "melee",
		slot = 5,
		nameKey = "grid_skill_melee_18",
		descKey = "grid_skill_melee_18_desc",
		U = 20,
		MeleeDamage = 0.05,
		MeleeWindup = -0.15
	},
	shadow_1 = {
		tree = "shadow",
		slot = 0,
		nameKey = "grid_skill_shadow_1",
		descKey = "grid_skill_shadow_1_desc",
		U = 20,
		ZombieHealth = 0.03
	},
	shadow_2 = {
		tree = "shadow",
		slot = 2,
		nameKey = "grid_skill_shadow_2",
		descKey = "grid_skill_shadow_2_desc",
		U = 20,
		need = "shadow_1",
		ZombieHealth = 0.03
	},
	shadow_3 = {
		tree = "shadow",
		slot = 1,
		nameKey = "grid_skill_shadow_3",
		descKey = "grid_skill_shadow_3_desc",
		U = 20,
		BarricadeDamage = 0.03
	},
	shadow_4 = {
		tree = "shadow",
		slot = 4,
		nameKey = "grid_skill_shadow_4",
		descKey = "grid_skill_shadow_4_desc",
		U = 20,
		need = "shadow_3",
		BarricadeDamage = 0.03
	},
	shadow_5 = {
		tree = "shadow",
		slot = 6,
		nameKey = "grid_skill_shadow_5",
		descKey = "grid_skill_shadow_5_desc",
		U = 20,
		need = "shadow_4",
		BarricadeDamage = 0.03
	},
	shadow_6 = {
		tree = "shadow",
		slot = 11,
		nameKey = "grid_skill_shadow_6",
		descKey = "grid_skill_shadow_6_desc",
		U = 20,
		LoosePropDamage = 0.20
	},
	shadow_7 = {
		tree = "shadow",
		slot = 10,
		nameKey = "grid_skill_shadow_7",
		descKey = "grid_skill_shadow_7_desc",
		U = 20,
		ZombieDoorDamage = 0.15
	},
	shadow_8 = {
		tree = "shadow",
		slot = 7,
		nameKey = "grid_skill_shadow_8",
		descKey = "grid_skill_shadow_8_desc",
		U = 20,
		BarricadeDamage = 0.05,
		ZombieHumanDamage = -0.07
	},
	shadow_9 = {
		tree = "shadow",
		slot = 5,
		nameKey = "grid_skill_shadow_9",
		descKey = "grid_skill_shadow_9_desc",
		U = 20,
		ZombieHumanDamage = 0.04
	},
	shadow_10 = {
		tree = "shadow",
		slot = 8,
		nameKey = "grid_skill_shadow_10",
		descKey = "grid_skill_shadow_10_desc",
		U = 20,
		need = "shadow_9",
		ZombieHumanDamage = 0.04
	},
	shadow_11 = {
		tree = "shadow",
		slot = 12,
		nameKey = "grid_skill_shadow_11",
		descKey = "grid_skill_shadow_11_desc",
		U = 20,
		need = "shadow_10",
		ZombieHumanDamage = 0.04
	},
	shadow_12 = {
		tree = "shadow",
		slot = 13,
		nameKey = "grid_skill_shadow_12",
		descKey = "grid_skill_shadow_12_desc",
		U = 20,
		ZombieHumanDamage = 0.07,
		BarricadeDamage = -0.05
	},
	supply_1 = {
		tree = "supply",
		slot = 0,
		nameKey = "grid_skill_supply_1",
		descKey = "grid_skill_supply_1_desc",
		U = 20,
		ResupplyAmmo = 0.04
	},
	supply_3 = {
		tree = "supply",
		slot = 1,
		nameKey = "grid_skill_supply_3",
		descKey = "grid_skill_supply_3_desc",
		U = 20,
		need = "supply_1",
		ResupplyAmmo = 0.04
	},
	supply_7 = {
		tree = "supply",
		slot = 3,
		nameKey = "grid_skill_supply_7",
		descKey = "grid_skill_supply_7_desc",
		U = 20,
		need = "supply_3",
		ResupplyAmmo = 0.04
	},
	supply_2 = {
		tree = "supply",
		slot = 2,
		nameKey = "grid_skill_supply_2",
		descKey = "grid_skill_supply_2_desc",
		U = 20,
		ArsenalMargin = 0.02
	},
	supply_4 = {
		tree = "supply",
		slot = 4,
		nameKey = "grid_skill_supply_4",
		descKey = "grid_skill_supply_4_desc",
		U = 20,
		need = "supply_2",
		ArsenalMargin = 0.02
	},
	supply_8 = {
		tree = "supply",
		slot = 6,
		nameKey = "grid_skill_supply_8",
		descKey = "grid_skill_supply_8_desc",
		U = 20,
		need = "supply_4",
		ArsenalMargin = 0.02
	},
	supply_12 = {
		tree = "supply",
		slot = 5,
		nameKey = "grid_skill_supply_12",
		descKey = "grid_skill_supply_12_desc",
		U = 20,
		SupplyHandle = 0.07
	},
	supply_13 = {
		tree = "supply",
		slot = 7,
		nameKey = "grid_skill_supply_13",
		descKey = "grid_skill_supply_13_desc",
		U = 20,
		need = "supply_12",
		SupplyHandle = 0.07
	},
	supply_14 = {
		tree = "supply",
		slot = 10,
		nameKey = "grid_skill_supply_14",
		descKey = "grid_skill_supply_14_desc",
		U = 20,
		need = "supply_13",
		SupplyHandle = 0.07
	},
	supply_15 = {
		tree = "supply",
		slot = 8,
		nameKey = "grid_skill_supply_15",
		descKey = "grid_skill_supply_15_desc",
		U = 20,
		SupplySell = 0.5
	},
	supply_9 = {
		tree = "supply",
		slot = 12,
		nameKey = "grid_skill_supply_9",
		descKey = "grid_skill_supply_9_desc",
		U = 20,
		ArsenalBreakPoints = 30,
		ArsenalMargin = -0.01
	},
	supply_10 = {
		tree = "supply",
		slot = 9,
		nameKey = "grid_skill_supply_10",
		descKey = "grid_skill_supply_10_desc",
		U = 20,
		ArsenalCrateCost = -0.80,
		ArsenalMargin = -0.01
	},
	supply_5 = {
		tree = "supply",
		slot = 11,
		nameKey = "grid_skill_supply_5",
		descKey = "grid_skill_supply_5_desc",
		U = 20,
		ArsenalRivalOthers = 0.02,
		ArsenalRivalSelf = 0.01
	},
	supply_6 = {
		tree = "supply",
		slot = 13,
		nameKey = "grid_skill_supply_6",
		descKey = "grid_skill_supply_6_desc",
		U = 20,
		need = "supply_5",
		ArsenalRivalOthers = 0.02,
		ArsenalRivalSelf = 0.01
	},
	supply_11 = {
		tree = "supply",
		slot = 14,
		nameKey = "grid_skill_supply_11",
		descKey = "grid_skill_supply_11_desc",
		U = 20,
		ArsenalMonopoly = 0.02,
		ArsenalMargin = -0.01
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
	if wipe or not pl.CycleGridMute then
		pl.CycleGridMute = {}
	end
	if wipe or not pl.CycleGridLive then
		pl.CycleGridLive = {}
	end
	if wipe or not pl.CycleGridLiveMute then
		pl.CycleGridLiveMute = {}
	end
end

function GM:CycleGridMuteKey(treeId, slot)
	return tostring(treeId) .. ":" .. tostring(slot)
end

function GM:CycleGridKeyMuted(pl, node, set)
	if not node or node.tree == nil or not IsValid(pl) or not set then
		return false
	end
	local n = node
	while n and n.tree ~= nil do
		if set[self:CycleGridMuteKey(n.treeId, n.slot)] then
			return true
		end
		n = n.parent
	end
	return false
end

function GM:CycleGridNodeMuted(pl, node)
	return self:CycleGridKeyMuted(pl, node, pl.CycleGridMute)
end

function GM:CycleGridLiveNodeMuted(pl, node)
	return self:CycleGridKeyMuted(pl, node, pl.CycleGridLiveMute)
end

function GM:CycleGridIsMuteRoot(pl, node)
	if not node or node.tree == nil or not IsValid(pl) or not pl.CycleGridMute then
		return false
	end
	return pl.CycleGridMute[self:CycleGridMuteKey(node.treeId, node.slot)] == true
end

function GM:CycleGridMutedByAncestor(pl, node)
	return self:CycleGridNodeMuted(pl, node) and not self:CycleGridIsMuteRoot(pl, node)
end

function GM:CycleGridSkillMuted(pl, id)
	local skill = id and self.CycleGridCatalog[id]
	if not skill then
		return false
	end
	return self:CycleGridNodeMuted(pl, self:GetCycleGridNode(skill.tree, skill.slot))
end

function GM:CycleGridLiveSkillMuted(pl, id)
	local skill = id and self.CycleGridCatalog[id]
	if not skill then
		return false
	end
	return self:CycleGridLiveNodeMuted(pl, self:GetCycleGridNode(skill.tree, skill.slot))
end

function GM:CycleGridLiveHas(pl, id)
	return IsValid(pl) and id and pl.CycleGridLive and pl.CycleGridLive[id] == true
end

function GM:CycleGridCommitLive(pl)
	if not IsValid(pl) then
		return
	end
	self:InitCycleGrid(pl)
	local live = {}
	for id in pairs(pl.CycleGridTaken) do
		if self.CycleGridCatalog[id] then
			live[id] = true
		end
	end
	local mute = {}
	for key in pairs(pl.CycleGridMute) do
		mute[key] = true
	end
	pl.CycleGridLive = live
	pl.CycleGridLiveMute = mute
	pl.CycleGridMap = game.GetMap()
end

function GM:CycleGridClearMuteUnder(pl, root)
	if not pl or not pl.CycleGridMute or not root then
		return
	end
	local layout = self:GetCycleGridLayout()
	for _, n in ipairs(layout.nodes) do
		local p = n.parent
		while p do
			if p.treeId == root.treeId and p.slot == root.slot then
				pl.CycleGridMute[self:CycleGridMuteKey(n.treeId, n.slot)] = nil
				break
			end
			p = p.parent
		end
	end
end

function GM:CycleGridMuteEntries(pl)
	local list = {}
	if not IsValid(pl) or not pl.CycleGridMute then
		return list
	end
	for key in pairs(pl.CycleGridMute) do
		local treeId, slot = string.match(key, "^([%w_]+):(%d+)$")
		slot = tonumber(slot)
		if treeId and slot and self:GetCycleGridNode(treeId, slot) then
			list[#list + 1] = { treeId = treeId, slot = slot }
		end
	end
	table.sort(list, function(a, b)
		if a.treeId == b.treeId then
			return a.slot < b.slot
		end
		return a.treeId < b.treeId
	end)
	return list
end

function GM:HasCycleGridSkill(pl, id)
	return IsValid(pl) and id and pl.CycleGridTaken and pl.CycleGridTaken[id] == true
end

function GM:ItemSkillLocked(pl, item)
	if not item then
		return true
	end
	if item.SkillRequirement then
		if not (IsValid(pl) and pl.IsSkillActive and pl:IsSkillActive(item.SkillRequirement)) then
			return true
		end
	end
	if item.CycleGridNeed then
		if not self:CycleGridLiveHas(pl, item.CycleGridNeed) or self:CycleGridLiveSkillMuted(pl, item.CycleGridNeed) then
			return true
		end
	end
	return false
end

function GM:GetItemSkillLockName(item)
	if not item then
		return ""
	end
	if item.CycleGridNeed then
		local skill = self:GetCycleGridSkillById(item.CycleGridNeed)
		if skill and skill.nameKey then
			if CLIENT then
				return translate.Get(skill.nameKey)
			end
			return skill.nameKey
		end
	end
	if item.SkillRequirement then
		local sk = self.Skills and self.Skills[item.SkillRequirement]
		if sk and sk.Name then
			return sk.Name
		end
	end
	return ""
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
	if self:CycleGridTakenCount(pl) > 0 then
		return true
	end
	return IsValid(pl) and pl.CycleGridMute and next(pl.CycleGridMute) ~= nil
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
	if self:CycleGridNodeMuted(pl, self:GetCycleGridNode(treeId, slot)) then
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
	need = true,
	UnlockShop = true
}

function GM:GetCycleGridStatAdd(pl, field)
	if not IsValid(pl) or not pl.CycleGridLive or not field then
		return 0
	end
	local add = 0
	for id in pairs(pl.CycleGridLive) do
		if self:CycleGridLiveSkillMuted(pl, id) then
			continue
		end
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

function GM:GetMaxNails(pl)
	return math.max(0, (self.MaxNails or 4) + self:GetCycleGridStatAdd(pl, "MaxNails"))
end

function GM:CycleGridPayArsenalBreak(pl)
	if not SERVER or not IsValid(pl) or not pl.AddPoints then
		return
	end
	local pts = self:GetCycleGridStatAdd(pl, "ArsenalBreakPoints")
	if pts > 0 then
		pl:AddPoints(pts, nil, nil, true)
	end
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
	if not IsValid(pl) or not pl.CycleGridLive then
		return adds
	end
	for id in pairs(pl.CycleGridLive) do
		if self:CycleGridLiveSkillMuted(pl, id) then continue end
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
	local add = self:GetCycleGridHealthAdd(pl) + (tonumber(pl.AloeMaxHealthAdd) or 0)
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
