-- Relapse mesh overlay: painted walkable skin (heightfield samples), not .nav tiles.
-- Depth-tested wireframe (no xray). Corners are baked on receive; draw iterates nearby buckets only.

local Mode = 0 -- 0 off, 1 view, 2 edit
local GenId = 0
local CellSize = 40
local CellN = 0
local Ladders = {} -- linked shafts only (AABB + snapped cell ends)
local Count = 0
local Pct = 0
local Building = false

local Buckets = {} -- [ix][iy][iz] = {cells}
local VisCells = {}
local VisAlpha = {}
local VisLadders = {}
local VisLadderAlpha = {}

local cvDist = CreateClientConVar("relapse_mesh_drawdistance", "1024", true, false, "How far to draw Relapse mesh paint.")

local BUCKET = 256
local BATCH = 4000
local LADDER_BATCH = 700
local LIFT = 2
local AXIS_X = Vector(1, 0, 0)
local AXIS_Z = Vector(0, 0, 1)
local BOX_EDGES = {
	{1, 2}, {2, 3}, {3, 4}, {4, 1},
	{5, 6}, {6, 7}, {7, 8}, {8, 5},
	{1, 5}, {2, 6}, {3, 7}, {4, 8},
}
local SQ_EDGES = {{1, 2}, {2, 3}, {3, 4}, {4, 1}}

local function SmoothAlpha(d2, fadeEnd2, fadeInv)
	if d2 >= fadeEnd2 then return 0 end
	local t = 1 - math.sqrt(d2) * fadeInv
	return math.floor(t * t * (3 - 2 * t) * 255 + 0.5)
end

local function InView(dx, dy, dz, d2, fx, fy, fz, margin, cos2)
	local along = dx * fx + dy * fy + dz * fz
	return along > -margin and (along <= 0 or along * along >= d2 * cos2)
end

local function PushEdge(p, q, cr, cg, cb, a)
	mesh.Color(cr, cg, cb, a)
	mesh.Position(p)
	mesh.AdvanceVertex()
	mesh.Color(cr, cg, cb, a)
	mesh.Position(q)
	mesh.AdvanceVertex()
end

local function PushLoop(pts, edges, cr, cg, cb, a)
	for i = 1, #edges do
		local e = edges[i]
		PushEdge(pts[e[1]], pts[e[2]], cr, cg, cb, a)
	end
end

local function PrepareLadder(mins, maxs, bot, top)
	local mh = math.max(14, math.max(8, CellSize > 0 and CellSize or 40) * 0.616) * 0.5
	local function flatSq(p)
		return {
			Vector(p.x - mh, p.y - mh, p.z + 1.5),
			Vector(p.x + mh, p.y - mh, p.z + 1.5),
			Vector(p.x + mh, p.y + mh, p.z + 1.5),
			Vector(p.x - mh, p.y + mh, p.z + 1.5),
		}
	end
	return {
		mins = mins,
		maxs = maxs,
		bot = bot,
		top = top,
		box = {
			Vector(mins.x, mins.y, mins.z),
			Vector(maxs.x, mins.y, mins.z),
			Vector(maxs.x, maxs.y, mins.z),
			Vector(mins.x, maxs.y, mins.z),
			Vector(mins.x, mins.y, maxs.z),
			Vector(maxs.x, mins.y, maxs.z),
			Vector(maxs.x, maxs.y, maxs.z),
			Vector(mins.x, maxs.y, maxs.z),
		},
		botSq = flatSq(bot),
		topSq = flatSq(top),
	}
end

local function EmitLadderLines(from, to, cr, cg, cb)
	mesh.Begin(MATERIAL_LINES, (to - from + 1) * 21)
	for i = from, to do
		local L = VisLadders[i]
		local a = VisLadderAlpha[i]
		PushLoop(L.box, BOX_EDGES, cr, cg, cb, a)
		PushEdge(L.bot, L.top, cr, cg, cb, a)
		PushLoop(L.botSq, SQ_EDGES, cr, cg, cb, a)
		PushLoop(L.topSq, SQ_EDGES, cr, cg, cb, a)
	end
	mesh.End()
end

local function ResetCells()
	Buckets = {}
	CellN = 0
end

local function InsertCell(cell)
	CellN = CellN + 1
	local pos = cell.pos
	local ix = math.floor(pos.x / BUCKET)
	local iy = math.floor(pos.y / BUCKET)
	local iz = math.floor(pos.z / BUCKET)
	local xs = Buckets[ix]
	if not xs then
		xs = {}
		Buckets[ix] = xs
	end
	local ys = xs[iy]
	if not ys then
		ys = {}
		xs[iy] = ys
	end
	local zs = ys[iz]
	if not zs then
		zs = {}
		ys[iz] = zs
	end
	zs[#zs + 1] = cell
end

local function PrepareCell(pos, n, half)
	local right = n:Cross(math.abs(n.z) < 0.999 and AXIS_Z or AXIS_X)
	right:Normalize()
	local up = right:Cross(n)
	up:Normalize()
	right:Mul(half)
	up:Mul(half)

	local ox = pos.x + n.x * LIFT
	local oy = pos.y + n.y * LIFT
	local oz = pos.z + n.z * LIFT
	local rx, ry, rz = right.x, right.y, right.z
	local ux, uy, uz = up.x, up.y, up.z

	return {
		pos = pos,
		nx = n.x,
		ny = n.y,
		nz = n.z,
		white = math.floor((pos.z + 32768) / 96) % 2 == 0,
		p1 = Vector(ox - rx - ux, oy - ry - uy, oz - rz - uz),
		p2 = Vector(ox + rx - ux, oy + ry - uy, oz + rz - uz),
		p3 = Vector(ox + rx + ux, oy + ry + uy, oz + rz + uz),
		p4 = Vector(ox - rx + ux, oy - ry + uy, oz - rz + uz),
	}
end

local function EmitCellLines(from, to)
	mesh.Begin(MATERIAL_LINES, (to - from + 1) * 4)
	for i = from, to do
		local c = VisCells[i]
		local a = VisAlpha[i]
		local cr, cg, cb
		if c.white then
			cr, cg, cb = 255, 255, 255
		else
			cr, cg, cb = 150, 150, 150
		end
		local p1, p2, p3, p4 = c.p1, c.p2, c.p3, c.p4

		mesh.Color(cr, cg, cb, a)
		mesh.Position(p1)
		mesh.AdvanceVertex()
		mesh.Color(cr, cg, cb, a)
		mesh.Position(p2)
		mesh.AdvanceVertex()

		mesh.Color(cr, cg, cb, a)
		mesh.Position(p2)
		mesh.AdvanceVertex()
		mesh.Color(cr, cg, cb, a)
		mesh.Position(p3)
		mesh.AdvanceVertex()

		mesh.Color(cr, cg, cb, a)
		mesh.Position(p3)
		mesh.AdvanceVertex()
		mesh.Color(cr, cg, cb, a)
		mesh.Position(p4)
		mesh.AdvanceVertex()

		mesh.Color(cr, cg, cb, a)
		mesh.Position(p4)
		mesh.AdvanceVertex()
		mesh.Color(cr, cg, cb, a)
		mesh.Position(p1)
		mesh.AdvanceVertex()
	end
	mesh.End()
end

net.Receive("RelapseAI.MeshEdit", function()
	Mode = net.ReadUInt(2)
	if Mode <= 0 then
		ResetCells()
		Ladders = {}
		Count = 0
		GenId = 0
	end
end)

net.Receive("RelapseAI.MeshProgress", function()
	local gen = net.ReadUInt(16)
	if gen ~= GenId then
		GenId = gen
		ResetCells()
	end
	Pct = net.ReadUInt(7)
	Count = net.ReadUInt(20)
	CellSize = net.ReadFloat()
	Building = net.ReadBool()
end)

net.Receive("RelapseAI.MeshCells", function()
	local gen = net.ReadUInt(16)
	if gen ~= GenId then
		GenId = gen
		ResetCells()
	end
	CellSize = net.ReadFloat()
	local half = math.max(8, CellSize > 0 and CellSize or 40) * 0.5
	local n = net.ReadUInt(8)
	for _ = 1, n do
		InsertCell(PrepareCell(net.ReadVector(), net.ReadNormal(), half))
	end
end)

net.Receive("RelapseAI.MeshLadders", function()
	local n = net.ReadUInt(8)
	local list = {}
	for _ = 1, n do
		list[#list + 1] = PrepareLadder(net.ReadVector(), net.ReadVector(), net.ReadVector(), net.ReadVector())
	end
	Ladders = list
end)

hook.Add("InitPostEntity", "RelapseAI.MeshEdit", function()
	Mode = 0
	ResetCells()
	Ladders = {}
	GenId = 0
end)

hook.Add("PostDrawTranslucentRenderables", "RelapseAI.MeshEdit", function(_, skybox)
	if skybox or Mode <= 0 then return end

	local eye = EyePos()
	local fwd = EyeAngles():Forward()
	local ex, ey, ez = eye.x, eye.y, eye.z
	local fx, fy, fz = fwd.x, fwd.y, fwd.z
	local maxd = math.max(256, cvDist:GetFloat())
	local cell = math.max(8, CellSize > 0 and CellSize or 40)
	local fadeEnd = maxd * 0.85
	local fadeEnd2 = fadeEnd * fadeEnd
	local fadeInv = 1 / fadeEnd

	local lp = LocalPlayer()
	local halfFov = math.rad(((IsValid(lp) and lp:GetFOV() or 90) * 0.5) + 18)
	local cosFov = math.cos(halfFov)
	local cos2 = cosFov > 0 and (cosFov * cosFov) or 0

	local nvis = 0
	local br = math.ceil(fadeEnd / BUCKET)
	local eix = math.floor(ex / BUCKET)
	local eiy = math.floor(ey / BUCKET)
	local eiz = math.floor(ez / BUCKET)

	for ix = eix - br, eix + br do
		local xs = Buckets[ix]
		if xs then
			for iy = eiy - br, eiy + br do
				local ys = xs[iy]
				if ys then
					for iz = eiz - br, eiz + br do
						local list = ys[iz]
						if list then
							for i = 1, #list do
								local c = list[i]
								local pos = c.pos
								local dx, dy, dz = pos.x - ex, pos.y - ey, pos.z - ez
								local d2 = dx * dx + dy * dy + dz * dz
								if InView(dx, dy, dz, d2, fx, fy, fz, cell, cos2)
									and (ex - pos.x) * c.nx + (ey - pos.y) * c.ny + (ez - pos.z) * c.nz > 0 then
									local a = SmoothAlpha(d2, fadeEnd2, fadeInv)
									if a > 0 then
										nvis = nvis + 1
										VisCells[nvis] = c
										VisAlpha[nvis] = a
									end
								end
							end
						end
					end
				end
			end
		end
	end

	local nlad = 0
	for i = 1, #Ladders do
		local L = Ladders[i]
		local mins, maxs = L.mins, L.maxs
		local px = math.Clamp(ex, mins.x, maxs.x)
		local py = math.Clamp(ey, mins.y, maxs.y)
		local pz = math.Clamp(ez, mins.z, maxs.z)
		local dx, dy, dz = px - ex, py - ey, pz - ez
		local d2 = dx * dx + dy * dy + dz * dz
		if InView(dx, dy, dz, d2, fx, fy, fz, cell, cos2) then
			local a = SmoothAlpha(d2, fadeEnd2, fadeInv)
			if a > 0 then
				nlad = nlad + 1
				VisLadders[nlad] = L
				VisLadderAlpha[nlad] = a
			end
		end
	end

	if nvis > 0 or nlad > 0 then
		render.SetColorMaterial()
	end

	if nvis > 0 then
		local from = 1
		while from <= nvis do
			local to = math.min(from + BATCH - 1, nvis)
			EmitCellLines(from, to)
			from = to + 1
		end
	end

	if nlad > 0 then
		local wine = RelapseUI.Col.Danger
		local from = 1
		while from <= nlad do
			local to = math.min(from + LADDER_BATCH - 1, nlad)
			EmitLadderLines(from, to, wine.r, wine.g, wine.b)
			from = to + 1
		end
	end
end)

hook.Add("HUDPaint", "RelapseAI.MeshEdit", function()
	if Mode <= 0 then return end

	local x, y = 18, 18
	local title = Mode == 2 and "Relapse mesh  EDIT" or "Relapse mesh  VIEW"
	draw.SimpleTextOutlined(title, "DermaDefaultBold", x, y, Color(255, 210, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 18

	local status
	if Building then
		status = string.format("painting %d%%   %d samples   %su", Pct, math.max(Count, CellN), CellSize)
	elseif Count > 0 or CellN > 0 then
		status = string.format("walkable skin   %d samples   %su", math.max(Count, CellN), CellSize)
	else
		status = "no paint — relapse_buildmesh"
	end
	draw.SimpleTextOutlined(status, "DermaDefault", x, y, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 16
	if not Building then
		local ladders = string.format("linked shafts   %d   (wine)", #Ladders)
		draw.SimpleTextOutlined(ladders, "DermaDefault", x, y, RelapseUI.Col.Danger, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
		y = y + 16
	end
	draw.SimpleTextOutlined("Standable skin, not Source tiles. Wine = ladder edges in the graph.", "DermaDefault", x, y, Color(170, 170, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 16
	draw.SimpleTextOutlined("relapse_buildmesh   relapse_hidemesh   relapse_savemesh", "DermaDefault", x, y, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
end)
