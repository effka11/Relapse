-- Air columns for sound. Each column is the open gap from a floor to the
-- ceiling above it. A gap whose top is open sky is marked. Rooms and
-- portals are built on top of these spans in cl_relapse_sound_rooms.lua.
-- Built once per map, a few milliseconds a tick, then read from the cache.

RelapseSoundMesh = RelapseSoundMesh or {}

local CELL_BASE = 32
local MAX_COLUMNS = 250000
local MIN_SPAN = 24
local BUDGET = 0.004

local REF_DIST = 36
local MAX_DIST = 2000

-- Clip brushes stop players, not sound: a clip lid over a yard is still sky.
local MASK_AIR = MASK_SOLID_BRUSHONLY

-- Doors and breakables are portal state, not walls. The column under a shut
-- door still has its air.
local PASS_CLASS = {
	prop_door_rotating = true,
	func_door = true,
	func_door_rotating = true,
	func_breakable = true,
	func_breakable_surf = true,
}
RelapseSoundMesh.PassClass = PASS_CLASS

-- phase: idle -> load -> (ready | columns -> rooms -> ready), or fail
local state = "idle"
local buildIndex, buildTotal = 0, 0

-- Shared with cl_relapse_sound_rooms.lua. Spans live in parallel arrays;
-- grid[key] lists the span ids of one column.
local D = RelapseSoundMesh.D or {}
RelapseSoundMesh.D = D

local function ClearData()
	D.cell = CELL_BASE
	D.originX, D.originY = 0, 0
	D.zmin, D.zmax = 0, 0
	D.nx, D.ny = 0, 0
	D.stride = 1
	D.grid = {}
	D.floor = {}
	D.ceil = {}
	D.col = {}
	D.sky = {}
	D.room = {}
	D.count = 0
end
ClearData()

local trOut = {}
local trStart, trEnd = Vector(), Vector()
local probe = Vector()
local tr = { mask = MASK_AIR, output = trOut }

-- true: the ray hits this entity (same contract as Mesh.TraceFilter).
local function SkipSolid(ent)
	if not IsValid(ent) then return false end
	if ent:IsPlayer() then return false end
	if PASS_CLASS[ent:GetClass()] then return false end
	if ent:IsWorld() or ent:GetSolid() == SOLID_BSP then return true end
	return false
end

tr.filter = SkipSolid
RelapseSoundMesh.SkipSolid = SkipSolid
RelapseSoundMesh.MaskAir = MASK_AIR

local function Key(ix, iy)
	return ix + iy * D.stride
end
RelapseSoundMesh.Key = Key

function RelapseSoundMesh.SpanXY(id)
	local key = D.col[id]
	local stride = D.stride
	local iy = math.floor(key / stride)
	local ix = key - iy * stride
	return D.originX + (ix + 0.5) * D.cell, D.originY + (iy + 0.5) * D.cell, ix, iy
end

function RelapseSoundMesh.AddSpan(ix, iy, floorZ, ceilZ, sky)
	local id = D.count + 1
	D.count = id
	local key = Key(ix, iy)
	D.floor[id] = floorZ
	D.ceil[id] = ceilZ
	D.col[id] = key
	D.sky[id] = sky or nil
	local list = D.grid[key]
	if not list then
		list = {}
		D.grid[key] = list
	end
	list[#list + 1] = id
	return id
end

function RelapseSoundMesh.SetGrid(cell, originX, originY, zmin, zmax, nx, ny)
	ClearData()
	D.cell = cell
	D.originX, D.originY = originX, originY
	D.zmin, D.zmax = zmin, zmax
	D.nx, D.ny = nx, ny
	D.stride = nx + 2
end

function RelapseSoundMesh.Ready()
	return state == "ready"
end

function RelapseSoundMesh.Failed()
	return state == "fail"
end

-- Label and 0..1 of the current phase, for the imitation hint.
function RelapseSoundMesh.Phase()
	if state == "ready" then return "готово", 1 end
	if state == "fail" then return "ошибка сборки, см. консоль", 0 end
	if state == "columns" then
		return "колонки", buildTotal > 0 and buildIndex / buildTotal or 0
	end
	if (state == "load" or state == "rooms") and RelapseSoundRooms then
		return RelapseSoundRooms.Phase()
	end
	return "ожидание", 0
end

function RelapseSoundMesh.Fraction()
	local _, frac = RelapseSoundMesh.Phase()
	return frac
end

-- Same fade the 3D channel used to apply. Now the only loudness of a path.
function RelapseSoundMesh.Falloff(dist)
	if dist <= REF_DIST then return 1 end
	if dist >= MAX_DIST then return 0 end
	return (MAX_DIST - dist) / (MAX_DIST - REF_DIST)
end

function RelapseSoundMesh.FadeDistance()
	return REF_DIST, MAX_DIST
end

local function WorldBox()
	local world = game.GetWorld()
	if IsValid(world) and world.GetModelBounds then
		local a, b = world:GetModelBounds()
		if a and b and (b.x - a.x) >= 512 and (b.z - a.z) >= 64 then
			return a, b
		end
	end
end

local function PointBox(points)
	local mins = Vector(points[1])
	local maxs = Vector(points[1])
	for i = 1, #points do
		local p = points[i]
		mins.x = math.min(mins.x, p.x)
		mins.y = math.min(mins.y, p.y)
		mins.z = math.min(mins.z, p.z)
		maxs.x = math.max(maxs.x, p.x)
		maxs.y = math.max(maxs.y, p.y)
		maxs.z = math.max(maxs.z, p.z)
	end
	mins:Add(Vector(-2048, -2048, -512))
	maxs:Add(Vector(2048, 2048, 768))
	return mins, maxs
end

local function ColumnsAt(mins, maxs, size)
	local cx = math.max(1, math.ceil((maxs.x - mins.x) / size))
	local cy = math.max(1, math.ceil((maxs.y - mins.y) / size))
	return cx * cy
end

-- Turning the imitation off keeps the spans and rooms: the next tour and
-- the next map load read them instead of building again.
function RelapseSoundMesh.Reset()
	if RelapseSoundRooms then
		RelapseSoundRooms.ClearRuntime()
	end
end

function RelapseSoundMesh.Ensure(points)
	if state ~= "idle" then return end
	local mins, maxs = WorldBox()
	if not mins then
		if points and points[1] then
			mins, maxs = PointBox(points)
		else
			mins = Vector(-4096, -4096, -512)
			maxs = Vector(4096, 4096, 1024)
		end
	elseif points and points[1] and ColumnsAt(mins, maxs, CELL_BASE) > MAX_COLUMNS then
		mins, maxs = PointBox(points)
	end

	local cell = CELL_BASE
	while ColumnsAt(mins, maxs, cell) > MAX_COLUMNS and cell < 128 do
		cell = cell + 16
	end

	local originX = math.floor(mins.x / cell) * cell
	local originY = math.floor(mins.y / cell) * cell
	local nx = math.floor((maxs.x - originX) / cell) + 1
	local ny = math.floor((maxs.y - originY) / cell) + 1
	RelapseSoundMesh.SetGrid(cell, originX, originY, mins.z, maxs.z, nx, ny)
	buildIndex = 0
	buildTotal = nx * ny
	state = "load"
	RelapseSoundRooms.StartLoad()
end

local function LeaveSolid(x, y, z)
	local guard = 0
	while guard < 24 and z > D.zmin do
		probe:SetUnpacked(x, y, z)
		if bit.band(util.PointContents(probe), CONTENTS_SOLID) == 0 then
			return z
		end
		z = z - 16
		guard = guard + 1
	end
	return z
end

local function IsPane(hit)
	if hit.MatType == MAT_GLASS or hit.MatType == MAT_GRATE then return true end
	local ent = hit.Entity
	return IsValid(ent) and ent:GetClass() == "func_breakable_surf"
end

-- The first span of a column has nothing crossed above it yet. Its top is
-- sky only if a ray straight up from it reaches the skybox or the world edge.
local function SkyAbove(x, y, z)
	trStart:SetUnpacked(x, y, z - 2)
	trEnd:SetUnpacked(x, y, D.zmax + 64)
	tr.start = trStart
	tr.endpos = trEnd
	util.TraceLine(tr)
	if trOut.HitSky then return true end
	return not trOut.Hit
end

local function ColumnSpans(ix, iy)
	local cell = D.cell
	local zmin = D.zmin
	local x = D.originX + (ix + 0.5) * cell
	local y = D.originY + (iy + 0.5) * cell
	local z = D.zmax
	local guard = 0
	-- nil: nothing crossed yet; true: last crossing was sky; false: a floor or a pane
	local open
	while z > zmin and guard < 16 do
		guard = guard + 1
		trStart:SetUnpacked(x, y, z)
		trEnd:SetUnpacked(x, y, zmin)
		tr.start = trStart
		tr.endpos = trEnd
		util.TraceLine(tr)

		if trOut.StartSolid then
			z = LeaveSolid(x, y, z - 16)
		elseif trOut.HitSky then
			open = true
			z = trOut.HitPos.z - 16
		elseif not trOut.Hit then
			break
		elseif IsPane(trOut) then
			open = false
			z = trOut.HitPos.z - 12
		else
			local floorZ = trOut.HitPos.z
			if z - floorZ >= MIN_SPAN then
				local sky = open
				if sky == nil then
					sky = SkyAbove(x, y, z)
				end
				RelapseSoundMesh.AddSpan(ix, iy, floorZ, z, sky)
			end
			open = false
			z = LeaveSolid(x, y, floorZ - 8)
		end
	end
end

hook.Add("Think", "RelapseSoundMeshBuild", function()
	if state == "idle" or state == "ready" or state == "fail" then return end
	local t0 = SysTime()
	local deadline = t0 + BUDGET

	if state == "load" then
		local status = RelapseSoundRooms.Step(deadline)
		if status == "done" then
			state = "ready"
		elseif status == "fail" then
			-- The grid from Ensure is still in D: the load commits only on success.
			state = "columns"
			print(string.format("[Relapse] сетка воздуха: клетка %d, колонок %d", D.cell, buildTotal))
		end
		return
	end

	if state == "columns" then
		local nx = D.nx
		while buildIndex < buildTotal and SysTime() < deadline do
			local ix = buildIndex % nx
			local iy = math.floor(buildIndex / nx)
			ColumnSpans(ix, iy)
			buildIndex = buildIndex + 1
		end
		if buildIndex >= buildTotal then
			print(string.format("[Relapse] сетка воздуха: %d прослоек", D.count))
			state = "rooms"
			RelapseSoundRooms.StartBuild()
		end
		return
	end

	if state == "rooms" then
		local status = RelapseSoundRooms.Step(deadline)
		if status == "done" then
			state = "ready"
		elseif status == "fail" then
			state = "fail"
		end
	end
end)

local function SpanAt(pos)
	local cell = D.cell
	local grid = D.grid
	local floors, ceils = D.floor, D.ceil
	local ix = math.floor((pos.x - D.originX) / cell)
	local iy = math.floor((pos.y - D.originY) / cell)

	local own = grid[Key(ix, iy)]
	if own then
		for i = 1, #own do
			local id = own[i]
			if pos.z >= floors[id] - 4 and pos.z <= ceils[id] + 4 then
				return id
			end
		end
	end

	local best, bestD
	for dy = -1, 1 do
		for dx = -1, 1 do
			local list = grid[Key(ix + dx, iy + dy)]
			if list then
				for i = 1, #list do
					local id = list[i]
					local dz = 0
					if pos.z < floors[id] then
						dz = floors[id] - pos.z
					elseif pos.z > ceils[id] then
						dz = pos.z - ceils[id]
					end
					local sx = D.originX + (ix + dx + 0.5) * cell
					local sy = D.originY + (iy + dy + 0.5) * cell
					local ddx = pos.x - sx
					local ddy = pos.y - sy
					local d = ddx * ddx + ddy * ddy + dz * dz * 4
					if not bestD or d < bestD then
						best, bestD = id, d
					end
				end
			end
		end
	end
	if not best or bestD > 128 * 128 then return end
	return best
end

-- Span id under a point: the one of its own column that holds the height,
-- else the nearest in the 3x3 around it. nil when there is no air nearby.
function RelapseSoundMesh.CellAt(pos)
	if state ~= "ready" and state ~= "rooms" then return end
	return SpanAt(pos)
end

function RelapseSoundMesh.Overlap(a, b)
	return math.min(D.ceil[a], D.ceil[b]) - math.max(D.floor[a], D.floor[b])
end
