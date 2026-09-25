-- Walkable-skin generator: rasterize standable surfaces (top hits per column,
-- any floor below). Not Source .nav tiles, not D3bot nodes.
-- 93_mesh_path.lua links cells and walks the skin; .nav is fallback until linked.

local AI = RelapseAI
local Mesh = AI.Mesh
if not Mesh then return end

util.AddNetworkString("RelapseAI.MeshCells")
util.AddNetworkString("RelapseAI.MeshProgress")
util.AddNetworkString("RelapseAI.MeshLadders")

Mesh.Cells = Mesh.Cells or {}
Mesh.Streams = Mesh.Streams or {}
Mesh.GenId = Mesh.GenId or 0
Mesh.CellSize = Mesh.CellSize or 40
Mesh.Building = Mesh.Building or false
-- Bumped when the sampler or its bounds change what gets painted; an older file
-- still loads (bots walk it meanwhile) and a repaint follows once the map is up.
-- v2: hull lifted to step height (ramps, stair runs). v3: bounds from the map,
-- not a +-2048 x -256..512 box (pits and high stairs were cut off).
-- v4: a column that lands on a stair nosing steps uphill onto the flatter
-- tread, staying in its raster bucket. The nosing never linked, so a 16u
-- stair stayed an island cut.
-- v5: a puddle shallower than a step is a floor. The stand test used to drop
-- any hit whose point is in water, so the hall under a few units of water
-- never painted and the room past it stayed another island.
Mesh.PaintVersion = 5

-- 32u: a 48u-wide stair still gets a column (the clearance hull needs 12u to each
-- wall, so a 40u raster could miss it entirely).
local cvCell = CreateConVar("relapse_ai_mesh_cell", "32", FCVAR_NOTIFY, "Relapse mesh sample spacing (units). Smaller = denser paint.")
local cvBudget = CreateConVar("relapse_ai_mesh_budget_ms", "4", FCVAR_NOTIFY, "Milliseconds per tick for mesh generation.")

local WALKABLE_Z = 0.7 -- Source walkable limit: slopes up to ~45 degrees
local STEP_HEIGHT = 18
-- Standing room above a sample. The hull starts at step height: a flat-bottomed
-- hull sitting on the surface intersected any slope over ~13 degrees and every
-- stair riser within its footprint, so ramps and stair runs never painted.
-- Whatever is below step height is walked over anyway.
local CLEAR_MINS = Vector(-12, -12, STEP_HEIGHT)
local CLEAR_MAXS = Vector(12, 12, 64)
-- Crouched body (36u): vents and low passages paint too, flagged so the graph
-- links them as crouch runs (a standing body walks around).
local CROUCH_MAXS = Vector(12, 12, 34)
local SAMPLE_LIFT = Vector(0, 0, 1.5)
local BATCH = 180
local MAX_FLOORS = 12
local MAX_COLUMNS = 120000
local MIN_FLOOR_GAP = 24
local CONTENTS_WATER = CONTENTS_WATER or 32
local CONTENTS_SOLID = CONTENTS_SOLID or 1

local downRes, upRes = {}, {}
local startPos, endPos = Vector(), Vector()
local probePos = Vector()

-- Map skin: world brushes, displacements, brush entities (func_brush, doors at
-- their start pose) and static props (the crate stair, the container roof, the
-- pedestal under a sigil). The engine reports static props as the world; the
-- brush-only mask skipped them, so a prop platform had no floor and no path.
-- Nothing that moves or breaks: physics props, nailed barricades, players.
-- 93_mesh_path.lua links with the same filter so ground and walls agree.
local TRACE_MASK = MASK_PLAYERSOLID
function Mesh.TraceFilter(ent)
	return ent:IsWorld() or ent:GetSolid() == SOLID_BSP
end

local downTr = {
	mask = TRACE_MASK,
	filter = Mesh.TraceFilter,
	output = downRes,
	start = startPos,
	endpos = endPos,
}
local upTr = {
	mask = TRACE_MASK,
	filter = Mesh.TraceFilter,
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

-- Raster AABB. XY: the .nav envelope when there is one (it covers every floor
-- the humans reach); else the whole map, since a spawn/sigil envelope stops 96u
-- past the last node and cuts the far courtyard. Z: always the whole map.
local function PlayableBounds()
	local mins = Vector(math.huge, math.huge, math.huge)
	local maxs = Vector(-math.huge, -math.huge, -math.huge)
	local hits, navHits = 0, 0

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
						navHits = navHits + 1
					end
				end
			end
		end
	end

	local wmins, wmaxs
	local world = game.GetWorld()
	if IsValid(world) and world.GetModelBounds then
		wmins, wmaxs = world:GetModelBounds()
		if wmins and wmaxs and (wmaxs.x - wmins.x < 512 or wmaxs.z - wmins.z < 64) then
			wmins, wmaxs = nil, nil
		end
	end

	if wmins and wmaxs then
		if navHits == 0 then
			-- No .nav: the whole map in XY (a 3D skybox far out costs columns,
			-- the cell size grows to fit MAX_COLUMNS; a cut-off yard costs bots).
			return Vector(wmins.x - 16, wmins.y - 16, wmins.z), Vector(wmaxs.x + 16, wmaxs.y + 16, wmaxs.z), "world"
		end
		mins:Add(Vector(-96, -96, 0))
		maxs:Add(Vector(96, 96, 0))
		-- Z from the world: the pit under the courtyard and the roof above the
		-- highest .nav area are floors too; a +-64/96 envelope cut both off.
		mins.z = wmins.z
		maxs.z = wmaxs.z
		return mins, maxs, "nav"
	end

	if hits == 0 then
		return Vector(-4096, -4096, -1024), Vector(4096, 4096, 1024), "default"
	end
	mins:Add(Vector(-96, -96, -512))
	maxs:Add(Vector(96, 96, 512))
	return mins, maxs, "playable"
end

-- Water over the hit, but the surface is within a step of the floor. The stand
-- hull starts a step up, so the body is in air and this bottom is walked.
-- Deeper than a step is a swim: still not a floor.
local function Puddle(x, y, z)
	local top = z + STEP_HEIGHT
	local wz = z + 1
	while wz < top do
		wz = wz + 4
		probePos:SetUnpacked(x, y, wz)
		if bit.band(util.PointContents(probePos), CONTENTS_WATER) == 0 then
			return true
		end
	end
	return false
end

-- Room over a surface hit: "stand", "crouch" or nil. Vertical only: an offset
-- along the normal moves the column off its raster on slopes.
local function CanStand(pos)
	startPos:Set(pos)
	startPos.z = startPos.z + 1
	if bit.band(util.PointContents(startPos), CONTENTS_WATER) ~= 0 and not Puddle(pos.x, pos.y, pos.z) then
		return nil
	end
	upTr.start = startPos
	upTr.endpos = startPos
	upTr.maxs = CLEAR_MAXS
	util.TraceHull(upTr)
	if not upRes.StartSolid then
		return "stand"
	end
	upTr.maxs = CROUCH_MAXS
	util.TraceHull(upTr)
	if not upRes.StartSolid then
		return "crouch"
	end
	return nil
end

-- A 32u column often hits the sloped nosing of a stair, not the tread. The
-- nosing is still walkable, so it is stored, the tread between columns is
-- never stored, and the step does not link. A short step uphill onto a flatter
-- floor within one step is that tread. The sample stays in its raster bucket:
-- leaving it puts the tread two buckets from the step below, and a walk link
-- is only searched one bucket out. A uniform ramp keeps its own normal.
local function PreferTread(hitPos, normal)
	local hx, hy = normal.x, normal.y
	local horiz = math.sqrt(hx * hx + hy * hy)
	if horiz < 0.2 or normal.z > 0.97 then
		return nil
	end
	local ux, uy = -hx / horiz, -hy / horiz
	local cell = Mesh.CellSize or 32
	local gx, gy = math.floor(hitPos.x / cell), math.floor(hitPos.y / cell)
	local reach = {cell * 0.25, cell * 0.5}
	for i = 1, #reach do
		local x = hitPos.x + ux * reach[i]
		local y = hitPos.y + uy * reach[i]
		if math.floor(x / cell) == gx and math.floor(y / cell) == gy then
			startPos:SetUnpacked(x, y, hitPos.z + STEP_HEIGHT + 8)
			endPos:SetUnpacked(x, y, hitPos.z - 8)
			downTr.start = startPos
			downTr.endpos = endPos
			util.TraceLine(downTr)
			if not downRes.StartSolid and downRes.Hit and not downRes.HitSky then
				local n = downRes.HitNormal
				local dz = downRes.HitPos.z - hitPos.z
				if n.z >= normal.z + 0.05 and dz >= -2 and dz <= STEP_HEIGHT then
					local room = CanStand(downRes.HitPos)
					if room then
						return Vector(downRes.HitPos.x, downRes.HitPos.y, downRes.HitPos.z), Vector(n.x, n.y, n.z), room
					end
				end
			end
		end
	end
	return nil
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
				local hit = Vector(downRes.HitPos.x, downRes.HitPos.y, downRes.HitPos.z)
				local nrm = Vector(n.x, n.y, n.z)
				local room = nrm.z >= WALKABLE_Z and CanStand(hit) or nil
				if room then
					local treadPos, treadN, treadRoom = PreferTread(hit, nrm)
					if treadRoom then
						hit, nrm, room = treadPos, treadN, treadRoom
					end
					cells[#cells + 1] = {
						pos = hit + SAMPLE_LIFT,
						n = nrm,
						crouch = room == "crouch" or nil,
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

-- A 10u shaft is invisible as a box; pad XY so the overlay reads as a column.
local LADDER_PAD_XY = 24

local function PadLadderBox(mins, maxs)
	local cx = (mins.x + maxs.x) * 0.5
	local cy = (mins.y + maxs.y) * 0.5
	if maxs.x - mins.x < LADDER_PAD_XY then
		mins.x, maxs.x = cx - LADDER_PAD_XY * 0.5, cx + LADDER_PAD_XY * 0.5
	end
	if maxs.y - mins.y < LADDER_PAD_XY then
		mins.y, maxs.y = cy - LADDER_PAD_XY * 0.5, cy + LADDER_PAD_XY * 0.5
	end
	if maxs.z < mins.z then
		mins.z, maxs.z = maxs.z, mins.z
	end
	return mins, maxs
end

local function LadderOverlayBox(ladder, ends)
	local Nav = AI.Nav
	local vol = Nav and Nav.LadderVolumeOf and Nav.LadderVolumeOf(ladder)
	local mins, maxs
	if vol and vol.mins then
		mins = Vector(vol.mins.x, vol.mins.y, vol.landingBotZ or vol.mins.z)
		maxs = Vector(vol.maxs.x, vol.maxs.y, vol.landingTopZ or vol.maxs.z)
	else
		local b, t = ladder:GetBottom(), ladder:GetTop()
		local w = (ladder.GetWidth and ladder:GetWidth() or 32) * 0.5
		local cx = (b.x + t.x) * 0.5
		local cy = (b.y + t.y) * 0.5
		mins = Vector(cx - w, cy - w, math.min(b.z, t.z))
		maxs = Vector(cx + w, cy + w, math.max(b.z, t.z))
	end
	mins, maxs = PadLadderBox(mins, maxs)
	local gm = GAMEMODE or GM
	if gm and gm.RelapseLadderModelColumns then
		local cols = gm:RelapseLadderModelColumns()
		for i = 1, cols and #cols or 0 do
			local col = cols[i]
			if col.maxs.x >= mins.x - 64 and col.mins.x <= maxs.x + 64
				and col.maxs.y >= mins.y - 64 and col.mins.y <= maxs.y + 64 then
				if col.maxs.z > maxs.z then maxs.z = col.maxs.z end
				if col.mins.z < mins.z then mins.z = col.mins.z end
			end
		end
	end
	local bot, top
	if istable(ends) and ends.bot and ends.top then
		bot, top = ends.bot, ends.top
	else
		local cx = (mins.x + maxs.x) * 0.5
		local cy = (mins.y + maxs.y) * 0.5
		bot = Vector(cx, cy, mins.z)
		top = Vector(cx, cy, maxs.z)
	end
	return mins, maxs, bot, top
end

-- Shafts that A* can actually use (Mesh.LinkedLadders). Overlay only; paint
-- cells stay the walkable skin.
function Mesh.SendLinkedLadders(pl)
	local targets
	if pl then
		if not IsValid(pl) then return end
		targets = {pl}
	else
		targets = {}
		for p in pairs(Mesh.Editors or {}) do
			if IsValid(p) then
				targets[#targets + 1] = p
			end
		end
	end
	if #targets == 0 then return end

	local boxes = {}
	local Nav = AI.Nav
	local linked = Mesh.LinkedLadders
	if linked and Nav then
		local list = Nav.Climbables
		if not list or #list == 0 then
			list = Nav.GetAllLadders and Nav.GetAllLadders() or {}
		end
		for i = 1, #list do
			local ladder = list[i]
			local id = Nav.LadderID and Nav.LadderID(ladder)
			if not id and ladder.GetID then
				id = ladder:GetID()
			end
			local ends = id and linked[id]
			if ends then
				local mins, maxs, bot, top = LadderOverlayBox(ladder, ends)
				boxes[#boxes + 1] = {mins, maxs, bot, top}
				if #boxes >= 255 then break end
			end
		end
	end

	for i = 1, #targets do
		net.Start("RelapseAI.MeshLadders")
		net.WriteUInt(#boxes, 8)
		for j = 1, #boxes do
			local b = boxes[j]
			net.WriteVector(b[1])
			net.WriteVector(b[2])
			net.WriteVector(b[3])
			net.WriteVector(b[4])
		end
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
		Mesh.SendLinkedLadders(pl)
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
		"RelapseMesh " .. tostring(Mesh.PaintVersion),
		"map " .. game.GetMap(),
		"cell " .. tostring(Mesh.CellSize or 40),
		"count " .. tostring(#Mesh.Cells),
	}
	for i = 1, #Mesh.Cells do
		local c = Mesh.Cells[i]
		local p, n = c.pos, c.n
		lines[#lines + 1] = string.format("%.1f %.1f %.1f %.3f %.3f %.3f%s", p.x, p.y, p.z, n.x, n.y, n.z,
			c.crouch and " c" or "")
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
	local version = tonumber(string.match(lines[1], "RelapseMesh%s+(%d+)")) or 1
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
				local x, y, z, nx, ny, nz, flag = string.match(line, "([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s*(%a*)")
				if x then
					cells[#cells + 1] = {
						pos = Vector(tonumber(x), tonumber(y), tonumber(z)),
						n = Vector(tonumber(nx), tonumber(ny), tonumber(nz)),
						crouch = flag == "c" or nil,
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
	AI.Log("mesh loaded %d cells (%su, paint v%d) from data/%s", #cells, Mesh.CellSize, version, path)
	-- Stale paint (old sampler or old bounds) still links so bots have something
	-- now; the repaint waits for InitPostEntity, when spawns, sigil nodes and
	-- the .nav exist to bound it. Painting here, at Lua init, saw no entities
	-- and rasterised a +-2048 x -256..512 box: pits and high stairs were cut.
	Mesh.PaintedVersion = version
	Mesh.NeedRepaint = version < Mesh.PaintVersion
	if Mesh.NeedRepaint then
		AI.Warn("mesh data/%s is paint v%d (current v%d): stale, repainting once the map is up", path, version, Mesh.PaintVersion)
	end
	if Mesh.StartLink then
		Mesh.StartLink()
	end
	return true, #cells
end

function Mesh.FinishBuild()
	Mesh.Building = false
	Mesh.PaintedVersion = Mesh.PaintVersion
	Mesh.NeedRepaint = false
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

	local mins, maxs, how = PlayableBounds()
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
	Mesh.NeedRepaint = false
	-- A link job over the old cells would index into the new, empty table, and
	-- the old grid would hand out stale indices.
	Mesh.Linking = nil
	Mesh.Linked = false
	Mesh.LinkCount = 0
	Mesh.LinkedLadders = {}
	Mesh.Grid = {}
	Mesh.SendLinkedLadders()
	AI.Log("mesh paint bounds (%s): x %.0f..%.0f  y %.0f..%.0f  z %.0f..%.0f, %dx%d columns at %du",
		how or "?", mins.x, maxs.x, mins.y, maxs.y, mins.z, maxs.z, nx, ny, cell)
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
		-- Stale file: repaint now that spawns, sigil nodes and the .nav bound
		-- the raster. Bots fall back to .nav (or retry) for the minute it takes;
		-- a skin with the pit and the stair tops missing is worse than that.
		if Mesh.NeedRepaint and not Mesh.Building then
			AI.Warn("mesh paint is stale (v%d < v%d): repainting %s", Mesh.PaintedVersion or 0, Mesh.PaintVersion, game.GetMap())
			Mesh.StartBuild(nil, true)
		end
	end)
end)

if #Mesh.Cells == 0 then
	Mesh.Load()
end
