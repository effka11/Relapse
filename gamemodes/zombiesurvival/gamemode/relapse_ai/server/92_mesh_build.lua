-- Walkable-skin generator: rasterize standable surfaces (top hits per column,
-- any floor below). Not Source .nav tiles, not D3bot nodes.
-- 93_mesh_path.lua links cells and walks the skin; .nav is fallback until linked.

local AI = RelapseAI
local Mesh = AI.Mesh
if not Mesh then return end

util.AddNetworkString("RelapseAI.MeshCells")
util.AddNetworkString("RelapseAI.MeshProgress")

Mesh.Cells = Mesh.Cells or {}
Mesh.Streams = Mesh.Streams or {}
Mesh.GenId = Mesh.GenId or 0
Mesh.CellSize = Mesh.CellSize or 40
Mesh.Building = Mesh.Building or false

local cvCell = CreateConVar("relapse_ai_mesh_cell", "40", FCVAR_NOTIFY, "Relapse mesh sample spacing (units). Smaller = denser paint.")
local cvBudget = CreateConVar("relapse_ai_mesh_budget_ms", "4", FCVAR_NOTIFY, "Milliseconds per tick for mesh generation.")

local WALKABLE_Z = 0.7
local CLEAR_MINS = Vector(-12, -12, 0)
local CLEAR_MAXS = Vector(12, 12, 62)
local BATCH = 180
local MAX_FLOORS = 12
local MAX_COLUMNS = 120000
local MIN_FLOOR_GAP = 24
local CONTENTS_WATER = CONTENTS_WATER or 32
local CONTENTS_SOLID = CONTENTS_SOLID or 1

local downRes, upRes = {}, {}
local startPos, endPos = Vector(), Vector()
local probePos = Vector()

-- World / func_brush / displacements only. Physics crates and static boxes are
-- not map skin; those get painted later by hand if a bot must stand on them.
local TRACE_MASK = MASK_PLAYERSOLID_BRUSHONLY

local downTr = {
	mask = TRACE_MASK,
	output = downRes,
	start = startPos,
	endpos = endPos,
}
local upTr = {
	mask = TRACE_MASK,
	output = upRes,
	mins = CLEAR_MINS,
	maxs = CLEAR_MAXS,
	start = startPos,
	endpos = startPos,
}

local function Expand(mins, maxs, p)
	if p.x < mins.x then mins.x = p.x end
	if p.y < mins.y then mins.y = p.y end
	if p.z < mins.z then mins.z = p.z end
	if p.x > maxs.x then maxs.x = p.x end
	if p.y > maxs.y then maxs.y = p.y end
	if p.z > maxs.z then maxs.z = p.z end
end

-- Playable AABB only (spawns / sigils / .nav envelope). The envelope is not the mesh.
local function PlayableBounds()
	local mins = Vector(math.huge, math.huge, math.huge)
	local maxs = Vector(-math.huge, -math.huge, -math.huge)
	local hits = 0

	local function add(p)
		if not isvector(p) then return end
		Expand(mins, maxs, p)
		hits = hits + 1
	end

	for _, teamid in ipairs({TEAM_HUMAN or 1, TEAM_UNDEAD or 3}) do
		for _, ent in ipairs(team.GetValidSpawnPoint(teamid) or {}) do
			if IsValid(ent) then add(ent:GetPos()) end
		end
	end

	for _, class in ipairs({"info_player_human", "info_player_undead", "info_player_zombie", "info_player_start", "info_sigilnode", "prop_obj_sigil"}) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			add(ent:GetPos())
		end
	end

	for _, node in ipairs((GAMEMODE and GAMEMODE.ProfilerNodes) or {}) do
		add(node)
	end

	if navmesh and navmesh.IsLoaded and navmesh.IsLoaded() and navmesh.GetAllNavAreas then
		local areas = navmesh.GetAllNavAreas()
		if areas then
			for i = 1, #areas do
				local area = areas[i]
				if IsValid(area) then
					for c = 0, 3 do
						add(area:GetCorner(c))
					end
				end
			end
		end
	end

	if hits == 0 then
		return Vector(-2048, -2048, -256), Vector(2048, 2048, 512)
	end

	mins:Add(Vector(-96, -96, -64))
	maxs:Add(Vector(96, 96, 96))
	return mins, maxs
end

local function CanStand(pos, normal)
	startPos:Set(pos)
	startPos:Add(normal)
	startPos.z = startPos.z + 2
	if bit.band(util.PointContents(startPos), CONTENTS_WATER) ~= 0 then
		return false
	end
	upTr.start = startPos
	upTr.endpos = startPos
	util.TraceHull(upTr)
	return not upRes.StartSolid
end

local function LeaveSolid(x, y, z, zmin)
	local guard = 0
	while guard < 32 and z > zmin do
		probePos:SetUnpacked(x, y, z)
		if bit.band(util.PointContents(probePos), CONTENTS_SOLID) == 0 then
			return z
		end
		z = z - 8
		guard = guard + 1
	end
	return z
end

local function SampleColumn(x, y, zmax, zmin, cells)
	local z = zmax
	local lastZ
	local floors = 0
	while z > zmin and floors < MAX_FLOORS do
		startPos:SetUnpacked(x, y, z)
		endPos:SetUnpacked(x, y, zmin)
		downTr.start = startPos
		downTr.endpos = endPos
		util.TraceLine(downTr)

		if downRes.StartSolid then
			z = LeaveSolid(x, y, z - 8, zmin)
			if lastZ and z > lastZ - MIN_FLOOR_GAP then
				z = lastZ - MIN_FLOOR_GAP
			end
		elseif not downRes.Hit or downRes.HitSky then
			break
		else
			local hitz = downRes.HitPos.z
			if lastZ and lastZ - hitz < MIN_FLOOR_GAP then
				z = hitz - MIN_FLOOR_GAP
			else
				local n = downRes.HitNormal
				if n.z >= WALKABLE_Z and CanStand(downRes.HitPos, n) then
					local pn = Vector(n.x, n.y, n.z)
					cells[#cells + 1] = {
						pos = Vector(downRes.HitPos.x, downRes.HitPos.y, downRes.HitPos.z) + pn * 1.5,
						n = pn,
					}
					floors = floors + 1
					lastZ = hitz
				end
				z = hitz - 4
			end
			z = LeaveSolid(x, y, z, zmin)
			if lastZ and z > lastZ - MIN_FLOOR_GAP then
				z = lastZ - MIN_FLOOR_GAP
			end
		end
	end
end

local function SendProgress(pl)
	local targets = pl and {pl} or nil
	if not targets then
		targets = {}
		for p in pairs(Mesh.Editors or {}) do
			if IsValid(p) then
				targets[#targets + 1] = p
			end
		end
	elseif not IsValid(pl) then
		return
	end

	local pct = 100
	if Mesh.Building and Mesh.Build and Mesh.Build.total > 0 then
		pct = math.Clamp(math.floor(Mesh.Build.done / Mesh.Build.total * 100), 0, 99)
	end

	for i = 1, #targets do
		net.Start("RelapseAI.MeshProgress")
		net.WriteUInt(Mesh.GenId, 16)
		net.WriteUInt(pct, 7)
		net.WriteUInt(math.min(#Mesh.Cells, 1048575), 20)
		net.WriteFloat(Mesh.CellSize or 40)
		net.WriteBool(Mesh.Building)
		net.Send(targets[i])
	end
end

local function SendBatch(pl, stream)
	local cells = Mesh.Cells
	local n = #cells
	if stream.i > n and not Mesh.Building then
		return
	end
	local count = math.min(BATCH, n - stream.i + 1)
	if count <= 0 then return end

	net.Start("RelapseAI.MeshCells", true)
	net.WriteUInt(Mesh.GenId, 16)
	net.WriteFloat(Mesh.CellSize or 40)
	net.WriteUInt(count, 8)
	for k = 0, count - 1 do
		local c = cells[stream.i + k]
		net.WriteVector(c.pos)
		net.WriteNormal(c.n)
	end
	net.Send(pl)
	stream.i = stream.i + count
end

function Mesh.StreamStep()
	for pl, stream in pairs(Mesh.Streams) do
		if not IsValid(pl) or not Mesh.Editors[pl] then
			Mesh.Streams[pl] = nil
		else
			if stream.gen ~= Mesh.GenId then
				stream.gen = Mesh.GenId
				stream.i = 1
			end
			SendBatch(pl, stream)
		end
	end
end

function Mesh.OnMode(pl, mode)
	if mode then
		Mesh.Streams[pl] = {i = 1, gen = Mesh.GenId}
		SendProgress(pl)
		if not Mesh.Building and #Mesh.Cells == 0 then
			Mesh.StartBuild(pl, false)
		end
	else
		Mesh.Streams[pl] = nil
	end
end

function Mesh.Save()
	if #Mesh.Cells == 0 then
		return false, "no cells"
	end
	file.CreateDir("relapse_ai")
	file.CreateDir("relapse_ai/mesh")
	local lines = {
		"RelapseMesh 1",
		"map " .. game.GetMap(),
		"cell " .. tostring(Mesh.CellSize or 40),
		"count " .. tostring(#Mesh.Cells),
	}
	for i = 1, #Mesh.Cells do
		local c = Mesh.Cells[i]
		local p, n = c.pos, c.n
		lines[#lines + 1] = string.format("%.1f %.1f %.1f %.3f %.3f %.3f", p.x, p.y, p.z, n.x, n.y, n.z)
	end
	file.Write(Mesh.FilePath(), table.concat(lines, "\n"))
	if not file.Exists(Mesh.FilePath(), "DATA") then
		return false, "write failed"
	end
	return true
end

function Mesh.Load()
	local path = Mesh.FilePath()
	if not file.Exists(path, "DATA") then
		return false, "missing"
	end
	local raw = file.Read(path, "DATA")
	if not raw or raw == "" then
		return false, "empty"
	end
	local lines = string.Explode("\n", raw, false)
	if not string.StartWith(lines[1] or "", "RelapseMesh") then
		return false, "bad header"
	end
	local map, cell, expect
	local cells = {}
	for i = 2, #lines do
		local line = string.Trim(lines[i])
		if line ~= "" then
			local m = string.match(line, "^map%s+(.+)$")
			local cl = tonumber(string.match(line, "^cell%s+([%d%.]+)"))
			local cn = tonumber(string.match(line, "^count%s+(%d+)"))
			if m then
				map = string.Trim(m)
			elseif cl then
				cell = cl
			elseif cn then
				expect = cn
			else
				local x, y, z, nx, ny, nz = string.match(line, "([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)")
				if x then
					cells[#cells + 1] = {
						pos = Vector(tonumber(x), tonumber(y), tonumber(z)),
						n = Vector(tonumber(nx), tonumber(ny), tonumber(nz)),
					}
				end
			end
		end
	end
	if map and map ~= game.GetMap() then
		return false, "map mismatch " .. map
	end
	if #cells == 0 then
		return false, "no cells in file"
	end
	Mesh.GenId = Mesh.GenId + 1
	Mesh.Cells = cells
	Mesh.CellSize = cell or Mesh.CellSize or 40
	for _, stream in pairs(Mesh.Streams) do
		stream.gen = Mesh.GenId
		stream.i = 1
	end
	AI.Log("mesh loaded %d cells (%su) from data/%s", #cells, Mesh.CellSize, path)
	if Mesh.StartLink then
		Mesh.StartLink()
	end
	return true, #cells
end

function Mesh.FinishBuild()
	Mesh.Building = false
	local elapsed = Mesh.Build and (SysTime() - Mesh.Build.t0) or 0
	AI.Log("mesh paint %d cells in %.1fs (cell %su) on %s", #Mesh.Cells, elapsed, Mesh.CellSize, game.GetMap())
	local ok, err = Mesh.Save()
	if ok then
		AI.Log("mesh saved data/%s", Mesh.FilePath())
	else
		AI.Warn("mesh save failed: %s", tostring(err))
	end
	SendProgress()
	Mesh.Build = nil
	if Mesh.StartLink then
		Mesh.StartLink()
	end
end

function Mesh.BuildStep()
	local b = Mesh.Build
	if not b then
		Mesh.Building = false
		return
	end

	local deadline = SysTime() + math.max(0.001, cvBudget:GetFloat() / 1000)
	local cell = b.cell
	local x0, y0 = b.x0, b.y0
	local nx, ny = b.nx, b.ny
	local zmax, zmin = b.zmax, b.zmin

	while Mesh.Building and SysTime() < deadline do
		if b.ix >= nx then
			b.ix = 0
			b.iy = b.iy + 1
		end
		if b.iy >= ny then
			Mesh.FinishBuild()
			return
		end
		SampleColumn(x0 + (b.ix + 0.5) * cell, y0 + (b.iy + 0.5) * cell, zmax, zmin, Mesh.Cells)
		b.ix = b.ix + 1
		b.done = b.done + 1
		if #Mesh.Cells >= 250000 then
			AI.Warn("mesh paint hit 250000 samples, stopping")
			Mesh.FinishBuild()
			return
		end
	end

	if (b.nextPing or 0) < CurTime() then
		b.nextPing = CurTime() + 0.5
		SendProgress()
	end
end

function Mesh.StartBuild(pl, force)
	if Mesh.Building and not force then
		Mesh.Reply(pl, "[Relapse AI] mesh already painting")
		return
	end

	if not force and #Mesh.Cells > 0 then
		Mesh.Reply(pl, string.format("[Relapse AI] mesh already has %d cells. relapse_buildmesh to regenerate.", #Mesh.Cells))
		return
	end

	if not force and #Mesh.Cells == 0 then
		local ok, n = Mesh.Load()
		if ok then
			Mesh.Reply(pl, string.format("[Relapse AI] loaded %d painted cells from data/%s", n, Mesh.FilePath()))
			SendProgress(pl)
			return
		end
	end

	local mins, maxs = PlayableBounds()
	local cell = math.Clamp(cvCell:GetFloat(), 16, 128)
	local spanx, spany = maxs.x - mins.x, maxs.y - mins.y
	while (spanx / cell) * (spany / cell) > MAX_COLUMNS and cell < 128 do
		cell = cell + 8
	end

	local nx = math.max(1, math.ceil(spanx / cell))
	local ny = math.max(1, math.ceil(spany / cell))

	Mesh.GenId = Mesh.GenId + 1
	Mesh.Cells = {}
	Mesh.CellSize = cell
	Mesh.Building = true
	Mesh.Build = {
		ix = 0,
		iy = 0,
		x0 = mins.x,
		y0 = mins.y,
		nx = nx,
		ny = ny,
		zmax = maxs.z,
		zmin = mins.z,
		cell = cell,
		total = nx * ny,
		done = 0,
		t0 = SysTime(),
	}

	for _, stream in pairs(Mesh.Streams) do
		stream.gen = Mesh.GenId
		stream.i = 1
	end

	Mesh.Reply(pl, string.format("[Relapse AI] painting walkable skin: %dx%d columns, cell %su, z %.0f..%.0f. Stay in relapse_editmesh.",
		nx, ny, cell, mins.z, maxs.z))
	SendProgress()
end

concommand.Add("relapse_buildmesh", function(pl)
	if IsValid(pl) and not Mesh.IsOwner(pl) then
		Mesh.Reply(pl, "[Relapse AI] mesh denied")
		return
	end
	Mesh.StartBuild(pl, true)
end)

hook.Add("Think", "RelapseAI.MeshBuild", function()
	if Mesh.Building then
		Mesh.BuildStep()
	end
	Mesh.StreamStep()
end)

hook.Add("InitPostEntity", "RelapseAI.MeshLoad", function()
	timer.Simple(1, function()
		if #Mesh.Cells == 0 then
			Mesh.Load()
		end
	end)
end)

if #Mesh.Cells == 0 then
	Mesh.Load()
end
