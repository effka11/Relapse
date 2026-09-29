-- Rooms and portals over the air spans of cl_relapse_sound_mesh.lua.
-- Two neighbouring spans are linked when a level ray at ear height joins
-- them; doors and glass are air there. Each span gets its clearance along
-- the floor, links are flooded from the widest down, and where two grown
-- rooms meet on a narrow link the link becomes a portal. Open sky is one
-- room per connected yard before the flood. A sound behind walls is heard
-- from the aperture of the last portal on the shortest portal chain, at the
-- loudness of the whole path. Built once per map and kept in data/.

RelapseSoundRooms = RelapseSoundRooms or {}
local R = RelapseSoundRooms
local Mesh = RelapseSoundMesh
local D = Mesh.D

-- Bump when the build changes: the cache of every map is rebuilt.
local ROOMS_VERSION = 1

local LINK_GAP = 32
local EAR_Z = 56
-- A link whose floors differ more than this is a drop, not floor: it does
-- not carry clearance, and a portal on it is a horizontal plane.
local VERTICAL_Z = 48
local MERGE_ABS = 48
local MERGE_REL = 0.6
local MIN_CELLS = 8
local EVAL_TOP = 4
local APERTURE_INSET = 8
local CACHE_DIR = "relapse_sound/rooms"

local rooms = {}
local portals = {}
local built
local dijCache = {}
local pathCache = {}

local job
local deadline = 0
local tick = 0

local function Pause()
	tick = tick + 1
	if tick < 64 then return end
	tick = 0
	if SysTime() >= deadline then
		coroutine.yield()
	end
end

local function SetPhase(label, total)
	job.label = label
	job.done = 0
	job.total = total or 0
end

local function CachePath()
	return CACHE_DIR .. "/" .. game.GetMap() .. ".txt"
end

local function BspSize()
	return file.Size("maps/" .. game.GetMap() .. ".bsp", "GAME") or -1
end

local function PairKey(a, b)
	if a > b then a, b = b, a end
	return a * 65536 + b
end

local function Other(p, r)
	if p.a == r then return p.b end
	return p.a
end

-- Links --------------------------------------------------------------------

local probeOut = {}
local pStart, pEnd, stepPos = Vector(), Vector(), Vector()
local probeTr = { mask = Mesh.MaskAir, output = probeOut, filter = Mesh.SkipSolid }
local CONTENTS_PANE = bit.bor(CONTENTS_SOLID, CONTENTS_WINDOW, CONTENTS_GRATE)

local function IsGlassHit(o)
	if o.MatType == MAT_GLASS then return true end
	local c = o.Contents
	return c ~= nil and bit.band(c, CONTENTS_WINDOW) ~= 0
end

local PANE_MAX = 24

local function PassesLevel(x0, y0, x1, y1, z)
	local glass = false
	local dx, dy = x1 - x0, y1 - y0
	local len = math.sqrt(dx * dx + dy * dy)
	local ux, uy = dx / len, dy / len
	local sx, sy = x0, y0
	for _ = 1, 3 do
		pStart:SetUnpacked(sx, sy, z)
		pEnd:SetUnpacked(x1, y1, z)
		probeTr.start = pStart
		probeTr.endpos = pEnd
		util.TraceLine(probeTr)
		if probeOut.StartSolid then return false end
		if not probeOut.Hit then return true, glass end
		if probeOut.HitSky then return false end
		local pane = IsGlassHit(probeOut)
		if not pane and probeOut.MatType ~= MAT_GRATE then return false end
		glass = glass or pane
		local hit = probeOut.HitPos
		local hx, hy = hit.x, hit.y
		local t = 1
		while t <= PANE_MAX do
			stepPos:SetUnpacked(hx + ux * t, hy + uy * t, z)
			if bit.band(util.PointContents(stepPos), CONTENTS_PANE) == 0 then break end
			t = t + 2
		end
		if t > PANE_MAX then return false end
		sx, sy = hx + ux * (t + 1), hy + uy * (t + 1)
		if (x1 - sx) * ux + (y1 - sy) * uy <= 0 then return true, glass end
	end
	return false
end

-- Free height at x, y from z up to hi and down to lo. Panes count as air.
local function VerticalAir(x, y, z, lo, hi)
	pStart:SetUnpacked(x, y, z)
	pEnd:SetUnpacked(x, y, hi)
	probeTr.start = pStart
	probeTr.endpos = pEnd
	util.TraceLine(probeTr)
	local top = hi
	if probeOut.StartSolid then return lo, hi end
	if probeOut.Hit and not IsGlassHit(probeOut) then top = probeOut.HitPos.z end
	pEnd:SetUnpacked(x, y, lo)
	util.TraceLine(probeTr)
	local bottom = lo
	if probeOut.Hit and not IsGlassHit(probeOut) then bottom = probeOut.HitPos.z end
	return bottom, top
end

-- Air joins the two centres at height z: returns the passage band and the
-- glass mark. A wall thinner than a cell sits between the centres with no
-- column of its own, so the band is measured where the link crosses it:
-- a slit over a low wall is as tall as the slit, not as the rooms.
local function Probe(x0, y0, x1, y1, z, lo, hi)
	local ok, glass = PassesLevel(x0, y0, x1, y1, z)
	if not ok then return false end
	local mx, my = (x0 + x1) * 0.5, (y0 + y1) * 0.5
	local bottom, top = VerticalAir(mx, my, z, lo, hi)
	return true, glass, bottom, top
end

-- Doors and breakables standing in the air, by the columns their box covers.
local MARK_CLASSES = {
	"prop_door_rotating",
	"func_door",
	"func_door_rotating",
	"func_breakable",
	"func_breakable_surf",
}

local function CollectMarks(cell)
	local byKey = {}
	local count = 0
	for c = 1, #MARK_CLASSES do
		local found = ents.FindByClass(MARK_CLASSES[c])
		for i = 1, #found do
			local ent = found[i]
			if IsValid(ent) then
				local mins, maxs = ent:WorldSpaceAABB()
				local box = { mins.x - 4, mins.y - 4, mins.z - 4, maxs.x + 4, maxs.y + 4, maxs.z + 4 }
				count = count + 1
				local ix0 = math.floor((box[1] - D.originX) / cell)
				local ix1 = math.floor((box[4] - D.originX) / cell)
				local iy0 = math.floor((box[2] - D.originY) / cell)
				local iy1 = math.floor((box[5] - D.originY) / cell)
				for iy = iy0, iy1 do
					for ix = ix0, ix1 do
						local key = Mesh.Key(ix, iy)
						local list = byKey[key]
						if not list then
							list = {}
							byKey[key] = list
						end
						list[#list + 1] = box
					end
				end
			end
		end
	end
	return byKey, count
end

local function MarkedAt(list, x, y, z)
	if not list then return false end
	for i = 1, #list do
		local b = list[i]
		if x >= b[1] and x <= b[4] and y >= b[2] and y <= b[5] and z >= b[3] and z <= b[6] then
			return true
		end
	end
	return false
end

local function LinkZ(fa, ca, fb, cb)
	local lo = math.max(fa, fb)
	local hi = math.min(ca, cb)
	if hi - lo < 16 then return (lo + hi) * 0.5 end
	return math.Clamp(lo + EAR_Z, lo + 8, hi - 8)
end

-- Portals ------------------------------------------------------------------

local function FinishPortal(p)
	local mins, maxs = p.mins, p.maxs
	local lo, hi = {}, {}
	for i = 1, 3 do
		local half = (maxs[i] - mins[i]) * 0.5
		local inset = math.min(APERTURE_INSET, half)
		lo[i] = mins[i] + inset
		hi[i] = maxs[i] - inset
	end
	lo[p.axis] = p.plane
	hi[p.axis] = p.plane
	p.lo, p.hi = lo, hi
	local c = (mins + maxs) * 0.5
	if p.axis == 1 then c.x = p.plane elseif p.axis == 2 then c.y = p.plane else c.z = p.plane end
	p.center = c
	p.ents = p.ents or {}
end

local BIND_CLASSES = {
	"prop_door_rotating",
	"func_door",
	"func_door_rotating",
	"func_breakable",
	"func_breakable_surf",
}

local function InBox(pos, p, pad)
	return pos.x >= p.mins.x - pad and pos.x <= p.maxs.x + pad
		and pos.y >= p.mins.y - pad and pos.y <= p.maxs.y + pad
		and pos.z >= p.mins.z - pad and pos.z <= p.maxs.z + pad
end

-- Doors and breakables become state of the portal they stand in.
local function BindEntities()
	for i = 1, #portals do
		portals[i].ents = {}
	end
	local bound = 0
	for c = 1, #BIND_CLASSES do
		local found = ents.FindByClass(BIND_CLASSES[c])
		for i = 1, #found do
			local ent = found[i]
			if not IsValid(ent) then continue end
			local pos = ent:WorldSpaceCenter()
			local best, bestD
			for j = 1, #portals do
				local p = portals[j]
				local d = pos:DistToSqr(p.center)
				if InBox(pos, p, 24) or d <= 64 * 64 then
					if not bestD or d < bestD then
						best, bestD = p, d
					end
				end
			end
			if best then
				best.ents[#best.ents + 1] = ent
				bound = bound + 1
			end
		end
	end
	return bound
end

local function RoomColor(id, alpha)
	local c = HSVToColor((id * 137.508) % 360, 0.6, 1)
	return Color(c.r, c.g, c.b, alpha)
end

-- Rebuild the room table from span rooms and the portal list.
local function Commit(from, secs)
	rooms = {}
	local roomOf = D.room
	local sky = D.sky
	for s = 1, D.count do
		local r = roomOf[s]
		if r then
			local rm = rooms[r]
			if not rm then
				rm = { id = r, cells = 0, sky = false, portals = {} }
				rooms[r] = rm
			end
			rm.cells = rm.cells + 1
			if sky[s] then rm.sky = true end
		end
	end
	for i = 1, #portals do
		local p = portals[i]
		p.id = i
		FinishPortal(p)
		if rooms[p.a] then table.insert(rooms[p.a].portals, i) end
		if rooms[p.b] then table.insert(rooms[p.b].portals, i) end
	end
	local nRooms = 0
	for id, rm in pairs(rooms) do
		nRooms = nRooms + 1
		rm.color = RoomColor(id, 255)
		rm.dim = RoomColor(id, 60)
	end
	local bound = BindEntities()
	dijCache = {}
	pathCache = {}
	built = { from = from, secs = secs, rooms = nRooms, portals = #portals, spans = D.count, ents = bound }
	print(string.format("[Relapse] комнаты звука (%s): %d прослоек, %d комнат, %d порталов, дверей и стёкол %d, %.1f с",
		from, D.count, nRooms, #portals, bound, secs))
end

-- Build --------------------------------------------------------------------

local function BuildAll()
	local t0 = SysTime()
	local N = D.count
	local cell = D.cell
	local stride = D.stride
	local originX, originY = D.originX, D.originY
	local floors, ceils, cols, sky, grid = D.floor, D.ceil, D.col, D.sky, D.grid

	-- 1. links along +X and +Y, confirmed by a level ray. A link through glass,
	-- a door or a breakable is marked: it is always a portal, never a merge.
	SetPhase("связи", N)
	local marks = CollectMarks(cell)
	local eA, eB, eDir, eGlass, eFlat, eLo, eHi, eMark = {}, {}, {}, {}, {}, {}, {}, {}
	local nE = 0
	local flatMask = {}
	for s = 1, N do
		job.done = s
		Pause()
		local key = cols[s]
		local iy = math.floor(key / stride)
		local ix = key - iy * stride
		local sx = originX + (ix + 0.5) * cell
		local sy = originY + (iy + 0.5) * cell
		local fs, cs = floors[s], ceils[s]
		for d = 1, 2 do
			local list = grid[key + (d == 1 and 1 or stride)]
			if list then
				local tx = d == 1 and sx + cell or sx
				local ty = d == 2 and sy + cell or sy
				for j = 1, #list do
					local t = list[j]
					local ft, ct = floors[t], ceils[t]
					local lo, hi = math.max(fs, ft), math.min(cs, ct)
					if hi - lo >= LINK_GAP then
						local z = LinkZ(fs, cs, ft, ct)
						local ok, glass, bottom, top = Probe(sx, sy, tx, ty, z, lo, hi)
						if ok then
							nE = nE + 1
							eA[nE] = s
							eB[nE] = t
							eDir[nE] = d
							eGlass[nE] = glass or false
							eLo[nE] = bottom
							eHi[nE] = top
							local mx, my = (sx + tx) * 0.5, (sy + ty) * 0.5
							eMark[nE] = glass or MarkedAt(marks[key], mx, my, z)
								or MarkedAt(marks[key + (d == 1 and 1 or stride)], mx, my, z)
							eFlat[nE] = math.abs(fs - ft) <= VERTICAL_Z
							if eFlat[nE] then
								local ms = flatMask[s] or 0
								local mt = flatMask[t] or 0
								if d == 1 then
									flatMask[s] = bit.bor(ms, 1)
									flatMask[t] = bit.bor(mt, 2)
								else
									flatMask[s] = bit.bor(ms, 4)
									flatMask[t] = bit.bor(mt, 8)
								end
							end
						end
					end
				end
			end
		end
	end

	-- 2. adjacency, then clearance along the floor: cells from the nearest
	-- side without a flat link, times the cell size
	SetPhase("зазор", N)
	local deg = {}
	for s = 1, N do deg[s] = 0 end
	for e = 1, nE do
		deg[eA[e]] = deg[eA[e]] + 1
		deg[eB[e]] = deg[eB[e]] + 1
	end
	local first = {}
	local at = 1
	for s = 1, N do
		first[s] = at
		at = at + deg[s]
		deg[s] = 0
	end
	first[N + 1] = at
	local adj = {}
	for e = 1, nE do
		local a, b = eA[e], eB[e]
		adj[first[a] + deg[a]] = e
		deg[a] = deg[a] + 1
		adj[first[b] + deg[b]] = e
		deg[b] = deg[b] + 1
		Pause()
	end
	deg = nil

	-- A wall thinner than a cell has no column of its own, so a doorway cell
	-- in it keeps all four links. It still touches the wall: the face of its
	-- side neighbour ends at its corner. Such a jamb counts as a wall cell.
	local level = {}
	local queue = {}
	local qTail = 0
	for s = 1, N do
		local ms = flatMask[s] or 0
		local wall = ms ~= 15
		if not wall then
			for i = first[s], first[s + 1] - 1 do
				local e = adj[i]
				if eFlat[e] then
					local t = eA[e] == s and eB[e] or eA[e]
					local across = eDir[e] == 2 and 3 or 12
					if bit.band(ms, bit.bnot(flatMask[t] or 0), across) ~= 0 then
						wall = true
						break
					end
				end
			end
		end
		if wall then
			level[s] = 1
			qTail = qTail + 1
			queue[qTail] = s
		end
		Pause()
	end
	local qHead = 1
	while qHead <= qTail do
		local s = queue[qHead]
		qHead = qHead + 1
		job.done = qHead
		Pause()
		local nextLevel = level[s] + 1
		for i = first[s], first[s + 1] - 1 do
			local e = adj[i]
			if eFlat[e] then
				local t = eA[e] == s and eB[e] or eA[e]
				if not level[t] then
					level[t] = nextLevel
					qTail = qTail + 1
					queue[qTail] = t
				end
			end
		end
	end
	queue = nil
	flatMask = nil
	local clear = {}
	for s = 1, N do
		clear[s] = (level[s] or 1) * cell
	end
	level = nil

	-- 3. pass of each link, bucketed by whole units
	SetPhase("водораздел", nE)
	local eCap = {}
	local buckets = {}
	local maxCap = 0
	for e = 1, nE do
		local a, b = eA[e], eB[e]
		local ov = eHi[e] - eLo[e]
		local cap = math.floor(math.max(0, math.min(clear[a], clear[b], ov * 0.5)))
		eCap[e] = cap
		local list = buckets[cap]
		if not list then
			list = {}
			buckets[cap] = list
		end
		list[#list + 1] = e
		if cap > maxCap then maxCap = cap end
		Pause()
	end

	local parent, peak, size = {}, {}, {}
	for s = 1, N do
		parent[s] = s
		peak[s] = clear[s]
		size[s] = 1
	end
	local function Find(x)
		while parent[x] ~= x do
			local up = parent[parent[x]]
			parent[x] = up
			x = up
		end
		return x
	end
	local function Union(a, b)
		if size[a] < size[b] then a, b = b, a end
		parent[b] = a
		size[a] = size[a] + size[b]
		if peak[b] > peak[a] then peak[a] = peak[b] end
		return a
	end

	-- one room per connected patch of open sky
	for e = 1, nE do
		local a, b = eA[e], eB[e]
		if sky[a] and sky[b] and not eMark[e] then
			local ra, rb = Find(a), Find(b)
			if ra ~= rb then Union(ra, rb) end
		end
		Pause()
	end

	-- Flood from the widest links down. A set whose every cell sits at the
	-- current level has not risen into a room yet and joins a room along the
	-- floor; the rim of a hole does not pour into the room below. Such a
	-- plateau is taken in waves from the rooms around it, one cell a wave,
	-- so a doorway strip goes to the room it touches, not to whichever edge
	-- came first. Two rooms that meet keep the rule of the plan.
	local function Basins(c, pa, pb)
		return c >= MERGE_ABS or c >= MERGE_REL * math.max(pa, pb)
	end
	local done = 0
	local joinA = {}
	for c = maxCap, 0, -1 do
		local pending = buckets[c]
		local level = c + 0.5
		while pending and #pending > 0 do
			local deferred = {}
			local nJoin = 0
			for i = 1, #pending do
				local e = pending[i]
				done = done + 1
				job.done = done
				Pause()
				local ra, rb = Find(eA[e]), Find(eB[e])
				if ra ~= rb and not eMark[e] then
					local pa, pb = peak[ra], peak[rb]
					local roomA, roomB = pa > level, pb > level
					if roomA and roomB then
						if Basins(c, pa, pb) then Union(ra, rb) end
					elseif roomA or roomB then
						if eFlat[e] then
							nJoin = nJoin + 1
							joinA[nJoin] = e
						elseif Basins(c, pa, pb) then
							Union(ra, rb)
						end
					else
						deferred[#deferred + 1] = e
					end
				end
			end
			for i = 1, nJoin do
				local e = joinA[i]
				local ra, rb = Find(eA[e]), Find(eB[e])
				if ra ~= rb then
					local pa, pb = peak[ra], peak[rb]
					if pa > level and pb > level then
						if Basins(c, pa, pb) then Union(ra, rb) end
					else
						Union(ra, rb)
					end
				end
				joinA[i] = nil
			end
			if nJoin == 0 then
				-- A plateau no room touches: its own cells join, it is a peak.
				for i = 1, #deferred do
					local e = deferred[i]
					local ra, rb = Find(eA[e]), Find(eB[e])
					if ra ~= rb then
						if eFlat[e] then
							Union(ra, rb)
						elseif Basins(c, peak[ra], peak[rb]) then
							Union(ra, rb)
						end
					end
				end
				break
			end
			pending = deferred
		end
	end
	buckets = nil

	-- Rooms under MIN_CELLS join the neighbour they share the widest opening
	-- with. A closet behind a door or glass keeps its portal.
	for _ = 1, 4 do
		local tally = {}
		for e = 1, nE do
			local ra, rb = Find(eA[e]), Find(eB[e])
			if ra ~= rb and not eMark[e] then
				if size[ra] < MIN_CELLS then
					local t = tally[ra] or {}
					tally[ra] = t
					t[rb] = (t[rb] or 0) + 1
				end
				if size[rb] < MIN_CELLS then
					local t = tally[rb] or {}
					tally[rb] = t
					t[ra] = (t[ra] or 0) + 1
				end
			end
			Pause()
		end
		local changed = false
		for small, t in pairs(tally) do
			local best, bestN
			for other, n in pairs(t) do
				if not bestN or n > bestN then
					best, bestN = other, n
				end
			end
			local ra, rb = Find(small), Find(best)
			if ra ~= rb and size[ra] < MIN_CELLS then
				Union(ra, rb)
				changed = true
			end
			Pause()
		end
		if not changed then break end
	end

	local roomOf = D.room
	local rootId = {}
	local nRooms = 0
	for s = 1, N do
		local r = Find(s)
		local id = rootId[r]
		if not id then
			nRooms = nRooms + 1
			id = nRooms
			rootId[r] = id
		end
		roomOf[s] = id
		Pause()
	end
	parent, peak, size, clear = nil, nil, nil, nil

	-- 4. portals: crossing links of one room pair, clustered in space
	SetPhase("порталы", nE)
	local pe = {}
	local peMx, peMy, peLo, peHi, pePair = {}, {}, {}, {}, {}
	local hash = {}
	local function HashKey(bx, by, bz)
		return ((bx + 100000) * 200000 + (by + 100000)) * 4096 + (bz + 2048)
	end
	for e = 1, nE do
		job.done = e
		Pause()
		local a, b = eA[e], eB[e]
		local ra, rb = roomOf[a], roomOf[b]
		if ra ~= rb then
			local n = #pe + 1
			pe[n] = e
			local ax, ay = Mesh.SpanXY(a)
			local bx, by = Mesh.SpanXY(b)
			peMx[n] = (ax + bx) * 0.5
			peMy[n] = (ay + by) * 0.5
			peLo[n] = eLo[e]
			peHi[n] = eHi[e]
			pePair[n] = PairKey(ra, rb)
			local hk = HashKey(math.floor(peMx[n] / cell), math.floor(peMy[n] / cell), math.floor((peLo[n] + peHi[n]) * 0.5 / 64))
			local list = hash[hk]
			if not list then
				list = {}
				hash[hk] = list
			end
			list[#list + 1] = n
		end
	end

	local cParent = {}
	for n = 1, #pe do cParent[n] = n end
	local function CFind(x)
		while cParent[x] ~= x do
			local up = cParent[cParent[x]]
			cParent[x] = up
			x = up
		end
		return x
	end
	for n = 1, #pe do
		Pause()
		local bx = math.floor(peMx[n] / cell)
		local by = math.floor(peMy[n] / cell)
		local bz = math.floor((peLo[n] + peHi[n]) * 0.5 / 64)
		for dz = -1, 1 do
			for dy = -1, 1 do
				for dx = -1, 1 do
					local list = hash[HashKey(bx + dx, by + dy, bz + dz)]
					if list then
						for i = 1, #list do
							local m = list[i]
							if m ~= n and pePair[m] == pePair[n] then
								local ra, rb = CFind(n), CFind(m)
								if ra ~= rb then cParent[rb] = ra end
							end
						end
					end
				end
			end
		end
	end
	hash = nil

	local clusters = {}
	local order = {}
	for n = 1, #pe do
		local r = CFind(n)
		local list = clusters[r]
		if not list then
			list = {}
			clusters[r] = list
			order[#order + 1] = r
		end
		list[#list + 1] = n
	end

	portals = {}
	local half = cell * 0.5
	for oi = 1, #order do
		Pause()
		local list = clusters[order[oi]]
		local e0 = pe[list[1]]
		local ra, rb = roomOf[eA[e0]], roomOf[eB[e0]]
		if ra > rb then ra, rb = rb, ra end
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		local zlo, zhi = math.huge, -math.huge
		local sumA, sumB = 0, 0
		local nX, nY = 0, 0
		local glass, cap = false, 0
		for i = 1, #list do
			local n = list[i]
			local e = pe[n]
			local s, t = eA[e], eB[e]
			if roomOf[s] ~= ra then s, t = t, s end
			sumA = sumA + floors[s]
			sumB = sumB + floors[t]
			minX = math.min(minX, peMx[n])
			maxX = math.max(maxX, peMx[n])
			minY = math.min(minY, peMy[n])
			maxY = math.max(maxY, peMy[n])
			zlo = math.min(zlo, peLo[n])
			zhi = math.max(zhi, peHi[n])
			if eDir[e] == 1 then nX = nX + 1 else nY = nY + 1 end
			if eGlass[e] then glass = true end
			if eCap[e] > cap then cap = eCap[e] end
		end
		local floorA = sumA / #list
		local floorB = sumB / #list
		local p = { a = ra, b = rb, glass = glass, cap = cap, width = #list }
		if math.abs(floorA - floorB) > VERTICAL_Z then
			p.vertical = true
			p.axis = 3
			p.plane = math.max(floorA, floorB)
			if maxX - minX < cell then
				minX, maxX = minX - half, maxX + half
			end
			if maxY - minY < cell then
				minY, maxY = minY - half, maxY + half
			end
			p.mins = Vector(minX, minY, p.plane)
			p.maxs = Vector(maxX, maxY, p.plane)
		elseif nX >= nY then
			p.axis = 1
			p.plane = (minX + maxX) * 0.5
			p.mins = Vector(minX, minY - half, zlo)
			p.maxs = Vector(maxX, maxY + half, zhi)
		else
			p.axis = 2
			p.plane = (minY + maxY) * 0.5
			p.mins = Vector(minX - half, minY, zlo)
			p.maxs = Vector(maxX + half, maxY, zhi)
		end
		portals[#portals + 1] = p
	end

	Commit("сборка", SysTime() - t0)

	-- 5. cache
	SetPhase("запись", N)
	local lines = {
		"RelapseRooms " .. ROOMS_VERSION,
		"map " .. game.GetMap(),
		"bsp " .. BspSize(),
		string.format("grid %d %.1f %.1f %.1f %.1f %d %d", cell, originX, originY, D.zmin, D.zmax, D.nx, D.ny),
		"spans " .. N,
		"portals " .. #portals,
	}
	for s = 1, N do
		job.done = s
		Pause()
		local key = cols[s]
		local iy = math.floor(key / stride)
		local ix = key - iy * stride
		lines[#lines + 1] = string.format("%d %d %d %d %d%s", ix, iy,
			math.floor(floors[s] + 0.5), math.floor(ceils[s] + 0.5), roomOf[s], sky[s] and " s" or "")
	end
	for i = 1, #portals do
		local p = portals[i]
		lines[#lines + 1] = string.format("P %d %d %d %.1f %.1f %.1f %.1f %.1f %.1f %.1f %d %d %d %d",
			p.a, p.b, p.axis, p.plane,
			p.mins.x, p.mins.y, p.mins.z, p.maxs.x, p.maxs.y, p.maxs.z,
			p.glass and 1 or 0, p.cap, p.width, p.vertical and 1 or 0)
	end
	file.CreateDir("relapse_sound")
	file.CreateDir(CACHE_DIR)
	file.Write(CachePath(), table.concat(lines, "\n"))
	if file.Exists(CachePath(), "DATA") then
		print("[Relapse] кеш комнат: data/" .. CachePath())
	else
		print("[Relapse] кеш комнат не записался: data/" .. CachePath())
	end
end

-- Load ---------------------------------------------------------------------

local function LoadAll()
	local t0 = SysTime()
	SetPhase("чтение кеша", 0)
	local path = CachePath()
	if not file.Exists(path, "DATA") then
		job.failed = "файла нет"
		return
	end
	local raw = file.Read(path, "DATA")
	if not raw or raw == "" then
		job.failed = "файл пуст"
		return
	end
	local n = #raw
	local pos = 1
	local function NextLine()
		if pos > n then return end
		local nl = string.find(raw, "\n", pos, true)
		local last = nl and (nl - 1) or n
		local line = string.sub(raw, pos, last)
		pos = nl and (nl + 1) or (n + 1)
		return line
	end

	local head = {}
	for _ = 1, 6 do
		local line = NextLine()
		if not line then break end
		local k, v = string.match(line, "^(%S+)%s+(.+)$")
		if k then head[k] = string.Trim(v) end
	end
	local version = tonumber(head.RelapseRooms or "")
	if version ~= ROOMS_VERSION then
		job.failed = string.format("версия %s, нужна %d", tostring(head.RelapseRooms), ROOMS_VERSION)
		return
	end
	if head.map ~= game.GetMap() then
		job.failed = "другая карта " .. tostring(head.map)
		return
	end
	if tonumber(head.bsp or "") ~= BspSize() then
		job.failed = string.format("размер bsp %s, сейчас %d", tostring(head.bsp), BspSize())
		return
	end
	local gc, gox, goy, gz0, gz1, gnx, gny = string.match(head.grid or "",
		"^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")
	local nSpans = tonumber(head.spans or "")
	local nPortals = tonumber(head.portals or "")
	if not gc or not nSpans or not nPortals then
		job.failed = "шапка битая"
		return
	end

	SetPhase("чтение кеша", nSpans + nPortals)
	local sIx, sIy, sF, sC, sR, sS = {}, {}, {}, {}, {}, {}
	local list = {}
	local got = 0
	while got < nSpans do
		local line = NextLine()
		if not line then break end
		Pause()
		local ix, iy, f, c, r, flag = string.match(line, "^(%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%d+)(.*)$")
		if ix then
			got = got + 1
			job.done = got
			sIx[got] = tonumber(ix)
			sIy[got] = tonumber(iy)
			sF[got] = tonumber(f)
			sC[got] = tonumber(c)
			sR[got] = tonumber(r)
			sS[got] = string.find(flag, "s", 1, true) and true or nil
		end
	end
	if got ~= nSpans then
		job.failed = string.format("прослоек %d из %d", got, nSpans)
		return
	end
	local pGot = 0
	while pGot < nPortals do
		local line = NextLine()
		if not line then break end
		Pause()
		local f = string.Explode(" ", line)
		if f[1] == "P" and #f >= 15 then
			pGot = pGot + 1
			job.done = nSpans + pGot
			local num = {}
			for i = 2, 15 do num[i] = tonumber(f[i]) end
			list[pGot] = {
				a = num[2],
				b = num[3],
				axis = num[4],
				plane = num[5],
				mins = Vector(num[6], num[7], num[8]),
				maxs = Vector(num[9], num[10], num[11]),
				glass = num[12] == 1,
				cap = num[13],
				width = num[14],
				vertical = num[15] == 1 or nil,
			}
		end
	end
	if pGot ~= nPortals then
		job.failed = string.format("порталов %d из %d", pGot, nPortals)
		return
	end

	Mesh.SetGrid(tonumber(gc), tonumber(gox), tonumber(goy), tonumber(gz0), tonumber(gz1), tonumber(gnx), tonumber(gny))
	local roomOf = D.room
	for i = 1, nSpans do
		Pause()
		local id = Mesh.AddSpan(sIx[i], sIy[i], sF[i], sC[i], sS[i])
		roomOf[id] = sR[i]
	end
	portals = list
	Commit("кеш", SysTime() - t0)
end

-- Jobs ---------------------------------------------------------------------

local function StartJob(fn)
	job = { label = "ожидание", done = 0, total = 0 }
	job.co = coroutine.create(function()
		local ok, err = xpcall(fn, debug.traceback)
		if not ok then job.failed = err end
	end)
end

function R.StartLoad()
	built = nil
	rooms, portals, dijCache, pathCache = {}, {}, {}, {}
	StartJob(LoadAll)
	job.kind = "load"
end

function R.StartBuild()
	built = nil
	rooms, portals, dijCache, pathCache = {}, {}, {}, {}
	StartJob(BuildAll)
	job.kind = "build"
end

-- "run", "done" or "fail". A missing or stale cache is a fail: the caller builds.
function R.Step(dl)
	if not job then return "fail" end
	deadline = dl
	tick = 0
	local ok, err = coroutine.resume(job.co)
	if not ok then job.failed = err end
	if job.failed then
		if job.kind == "load" then
			print("[Relapse] кеш комнат: " .. tostring(job.failed) .. ", собираю заново")
		else
			print("[Relapse] комнаты звука, ошибка сборки: " .. tostring(job.failed))
		end
		job = nil
		return "fail"
	end
	if coroutine.status(job.co) == "dead" then
		job = nil
		return "done"
	end
	return "run"
end

function R.Phase()
	if not job then return "ожидание", 0 end
	local frac = job.total > 0 and math.min(1, job.done / job.total) or 0
	return job.label, frac
end

function R.Stats()
	return built
end

function R.ClearRuntime()
	dijCache = {}
	pathCache = {}
end

-- Runtime ------------------------------------------------------------------

function R.RoomAt(pos)
	if not built then return end
	local id = Mesh.CellAt(pos)
	if not id then return end
	return D.room[id], id
end

function R.Room(id)
	return rooms[id]
end

function R.Portal(id)
	return portals[id]
end

local function DoorState(ent)
	local class = ent:GetClass()
	local ok, st
	if class == "prop_door_rotating" then
		ok, st = pcall(ent.GetInternalVariable, ent, "m_eDoorState")
		local names = { [0] = "закрыта", [1] = "открывается", [2] = "открыта", [3] = "закрывается" }
		return ok and (names[st] or tostring(st)) or "?"
	end
	if class == "func_door" or class == "func_door_rotating" then
		ok, st = pcall(ent.GetInternalVariable, ent, "m_toggle_state")
		local names = { [0] = "открыта", [1] = "закрыта", [2] = "открывается", [3] = "закрывается" }
		return ok and (names[st] or tostring(st)) or "?"
	end
	return "цела"
end

function R.PortalKind(p)
	for i = 1, #p.ents do
		local ent = p.ents[i]
		if IsValid(ent) then
			local class = ent:GetClass()
			if class ~= "func_breakable_surf" and class ~= "func_breakable" then return "дверь" end
		end
	end
	for i = 1, #p.ents do
		local ent = p.ents[i]
		if IsValid(ent) and ent:GetClass() == "func_breakable_surf" then return "стекло" end
	end
	if p.glass then return "стекло" end
	if p.vertical then return "пол" end
	return "проём"
end

-- One line per bound entity: class, index and state now.
function R.PortalEnts(p)
	local out = {}
	for i = 1, #p.ents do
		local ent = p.ents[i]
		if IsValid(ent) then
			out[#out + 1] = string.format("%s#%d %s", ent:GetClass(), ent:EntIndex(), DoorState(ent))
		end
	end
	return table.concat(out, ", ")
end

local function HeapPush(h, d, c)
	local i = #h + 1
	h[i] = { d, c }
	while i > 1 do
		local up = math.floor(i / 2)
		if h[up][1] <= h[i][1] then break end
		h[up], h[i] = h[i], h[up]
		i = up
	end
end

local function HeapPop(h)
	local n = #h
	if n == 0 then return end
	local top = h[1]
	h[1] = h[n]
	h[n] = nil
	n = n - 1
	local i = 1
	while true do
		local l = i * 2
		local r = l + 1
		local s = i
		if l <= n and h[l][1] < h[s][1] then s = l end
		if r <= n and h[r][1] < h[s][1] then s = r end
		if s == i then break end
		h[i], h[s] = h[s], h[i]
		i = s
	end
	return top
end

-- A crossing is a portal walked into one of its two rooms.
local function Crossing(pid, into)
	return pid * 2 + (portals[pid].b == into and 1 or 0)
end

local function CrossingInto(c)
	local pid = math.floor(c / 2)
	local p = portals[pid]
	return pid, (c % 2 == 1) and p.b or p.a
end

-- Portal-to-portal distances from every exit of the ear room. One wave
-- serves every source until the ear walks into another room.
local function Dijkstra(ear)
	local dist, prev = {}, {}
	local rm = rooms[ear]
	if not rm then return { dist = dist, prev = prev } end
	local heap = {}
	for i = 1, #rm.portals do
		local pid = rm.portals[i]
		local c = Crossing(pid, Other(portals[pid], ear))
		dist[c] = 0
		HeapPush(heap, 0, c)
	end
	while true do
		local top = HeapPop(heap)
		if not top then break end
		local d, c = top[1], top[2]
		if d <= dist[c] then
			local pid, into = CrossingInto(c)
			local here = portals[pid].center
			local nextRoom = rooms[into]
			if nextRoom then
				for i = 1, #nextRoom.portals do
					local q = nextRoom.portals[i]
					if q ~= pid then
						local qp = portals[q]
						local nd = d + here:Distance(qp.center)
						local nc = Crossing(q, Other(qp, into))
						if nd < (dist[nc] or math.huge) then
							dist[nc] = nd
							prev[nc] = c
							HeapPush(heap, nd, nc)
						end
					end
				end
			end
		end
	end
	return { dist = dist, prev = prev }
end

-- Portal chains from the source room to the ear room, one per portal the
-- source room is entered through. chain[1] is next to the source.
-- No ear room, or the same room: one empty chain. No way at all: empty list.
function R.Routes(ear, src)
	if not built or not src then return {} end
	if not ear or ear == src then
		return { { chain = {}, key = "", base = 0 } }
	end
	local dj = dijCache[ear]
	if not dj then
		dj = Dijkstra(ear)
		dijCache[ear] = dj
	end
	local out = {}
	local rm = rooms[src]
	if not rm then return out end
	for i = 1, #rm.portals do
		local pid = rm.portals[i]
		local c = Crossing(pid, src)
		local d = dj.dist[c]
		if d then
			local chain = {}
			local k = c
			local guard = 0
			while k and guard < 512 do
				chain[#chain + 1] = math.floor(k / 2)
				k = dj.prev[k]
				guard = guard + 1
			end
			out[#out + 1] = { chain = chain, key = table.concat(chain, ">"), base = d }
		end
	end
	return out
end

local function RectDistSqr(p, x, y, z)
	local lo, hi = p.lo, p.hi
	local dx = x < lo[1] and lo[1] - x or (x > hi[1] and x - hi[1] or 0)
	local dy = y < lo[2] and lo[2] - y or (y > hi[2] and y - hi[2] or 0)
	local dz = z < lo[3] and lo[3] - z or (z > hi[3] and z - hi[3] or 0)
	return dx * dx + dy * dy + dz * dz
end

local function Clamp3(p, x, y, z)
	local lo, hi = p.lo, p.hi
	return math.Clamp(x, lo[1], hi[1]), math.Clamp(y, lo[2], hi[2]), math.Clamp(z, lo[3], hi[3])
end

-- Point of the portal frame closest to the segment a-b. If the segment
-- goes through the frame, the point is on it: the way is a straight line.
local function FramePoint(p, ax, ay, az, bx, by, bz)
	local k, c = p.axis, p.plane
	local ak = k == 1 and ax or (k == 2 and ay or az)
	local bk = k == 1 and bx or (k == 2 and by or bz)
	if (ak - c) * (bk - c) < 0 then
		local t = (c - ak) / (bk - ak)
		local x, y, z = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t
		if RectDistSqr(p, x, y, z) < 1 then
			return Clamp3(p, x, y, z)
		end
	end
	local t0, t1 = 0, 1
	for _ = 1, 16 do
		local m1 = t0 + (t1 - t0) / 3
		local m2 = t1 - (t1 - t0) / 3
		local f1 = RectDistSqr(p, ax + (bx - ax) * m1, ay + (by - ay) * m1, az + (bz - az) * m1)
		local f2 = RectDistSqr(p, ax + (bx - ax) * m2, ay + (by - ay) * m2, az + (bz - az) * m2)
		if f1 <= f2 then t1 = m2 else t0 = m1 end
	end
	local t = (t0 + t1) * 0.5
	return Clamp3(p, ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t)
end

local function XYCell(x, y)
	return math.floor((x - D.originX) / D.cell), math.floor((y - D.originY) / D.cell)
end

local function CellKey(ix, iy)
	return ix .. "," .. iy
end

-- A span of this room covers z. An empty column is a wall.
local function RoomOpen(ix, iy, z, room)
	local list = D.grid[Mesh.Key(ix, iy)]
	if not list then return false end
	for i = 1, #list do
		local id = list[i]
		if D.room[id] == room and z >= D.floor[id] and z <= D.ceil[id] then
			return true
		end
	end
	return false
end

local function ZAt(ix, iy, ax, ay, az, bx, by, bz)
	local cx = D.originX + (ix + 0.5) * D.cell
	local cy = D.originY + (iy + 0.5) * D.cell
	local dx, dy = bx - ax, by - ay
	local len2 = dx * dx + dy * dy
	local t = 0
	if len2 > 1 then
		t = ((cx - ax) * dx + (cy - ay) * dy) / len2
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
	end
	return az + (bz - az) * t
end

-- Every cell the segment crosses. A diagonal step that only touches a blocked
-- corner still fails. exempt cells are the portal-plane cells of the endpoints.
local function SegmentInside(room, ax, ay, az, bx, by, bz, exA, exB)
	if not room then
		local ix, iy = XYCell(ax, ay)
		return false, ix, iy
	end
	local function exempt(ix, iy)
		if exA and ix == exA[1] and iy == exA[2] then return true end
		if exB and ix == exB[1] and iy == exB[2] then return true end
		return false
	end
	local function closed(ix, iy, z)
		if exempt(ix, iy) then return false end
		return not RoomOpen(ix, iy, z, room)
	end
	local cell = D.cell
	local ox, oy = D.originX, D.originY
	local ix, iy = XYCell(ax, ay)
	local ex, ey = XYCell(bx, by)
	local dx, dy = bx - ax, by - ay
	local stepX, stepY = 0, 0
	local tMaxX, tMaxY = math.huge, math.huge
	local tDeltaX, tDeltaY = math.huge, math.huge
	if dx > 0 then
		stepX = 1
		tDeltaX = cell / dx
		tMaxX = (ox + (ix + 1) * cell - ax) / dx
	elseif dx < 0 then
		stepX = -1
		tDeltaX = cell / -dx
		tMaxX = (ox + ix * cell - ax) / dx
	end
	if dy > 0 then
		stepY = 1
		tDeltaY = cell / dy
		tMaxY = (oy + (iy + 1) * cell - ay) / dy
	elseif dy < 0 then
		stepY = -1
		tDeltaY = cell / -dy
		tMaxY = (oy + iy * cell - ay) / dy
	end
	if tMaxX < 0 then tMaxX = 0 end
	if tMaxY < 0 then tMaxY = 0 end
	local tEnter = 0
	local guard = 0
	while guard < 4096 do
		guard = guard + 1
		local tExit, alongX
		if tMaxX < tMaxY then
			tExit, alongX = tMaxX, true
		else
			tExit, alongX = tMaxY, false
		end
		if tExit > 1 then tExit = 1 end
		local tm = (tEnter + tExit) * 0.5
		local z = az + (bz - az) * tm
		if closed(ix, iy, z) then return false, ix, iy end
		if stepX ~= 0 and stepY ~= 0 and math.abs(tMaxX - tMaxY) < 1e-6 and tMaxX <= 1 then
			local zc = az + (bz - az) * math.min(tMaxX, 1)
			if closed(ix + stepX, iy, zc) then return false, ix + stepX, iy end
			if closed(ix, iy + stepY, zc) then return false, ix, iy + stepY end
		end
		if (ix == ex and iy == ey) or tExit >= 1 then return true end
		if alongX then
			ix = ix + stepX
			tMaxX = tMaxX + tDeltaX
		else
			iy = iy + stepY
			tMaxY = tMaxY + tDeltaY
		end
		tEnter = tExit
	end
	return false, ix, iy
end

local function Flood(room, six, siy, ax, ay, az, bx, by, bz)
	local dist, parent = {}, {}
	local start = CellKey(six, siy)
	dist[start] = 0
	local heap = {}
	HeapPush(heap, 0, start)
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local guard = 0
	while guard < 20000 do
		local top = HeapPop(heap)
		if not top then break end
		guard = guard + 1
		local d, key = top[1], top[2]
		if d == dist[key] then
			local comma = string.find(key, ",", 1, true)
			local ix = tonumber(string.sub(key, 1, comma - 1))
			local iy = tonumber(string.sub(key, comma + 1))
			for i = 1, 4 do
				local nx, ny = ix + dirs[i][1], iy + dirs[i][2]
				local z = ZAt(nx, ny, ax, ay, az, bx, by, bz)
				if RoomOpen(nx, ny, z, room) then
					local nk = CellKey(nx, ny)
					local nd = d + 1
					if nd < (dist[nk] or math.huge) then
						dist[nk] = nd
						parent[nk] = { ix, iy }
						HeapPush(heap, nd, nk)
					end
				end
			end
		end
	end
	return dist, parent
end

local function CellsBetween(dist, parent, six, siy, eix, eiy)
	if not dist[CellKey(eix, eiy)] then return end
	if six == eix and siy == eiy then return { { six, siy } } end
	local cells = {}
	local ix, iy = eix, eiy
	local guard = 0
	while guard < 8192 do
		guard = guard + 1
		cells[#cells + 1] = { ix, iy }
		if ix == six and iy == siy then break end
		local prev = parent[CellKey(ix, iy)]
		if not prev then return end
		ix, iy = prev[1], prev[2]
	end
	if ix ~= six or iy ~= siy then return end
	local out = {}
	for i = #cells, 1, -1 do
		out[#out + 1] = cells[i]
	end
	return out
end

local function PlanePair(portal)
	local origin = portal.axis == 1 and D.originX or D.originY
	local iLo = math.floor((portal.plane - origin) / D.cell - 1e-6)
	return iLo, iLo + 1
end

local function CellOnPlane(portal, along, tang)
	if portal.axis == 1 then return along, tang end
	return tang, along
end

-- Shared side of two cells across the door, point on that side closest to the hint.
local function CollectFaces(portal, roomA, roomB, hint)
	local out = {}
	if portal.axis == 3 then return out end
	local iLo, iHi = PlanePair(portal)
	local tangAxis = portal.axis == 1 and 2 or 1
	local tangOrigin = portal.axis == 1 and D.originY or D.originX
	local loT, hiT = portal.lo[tangAxis], portal.hi[tangAxis]
	local j0 = math.floor((loT - tangOrigin) / D.cell)
	local j1 = math.floor((hiT - tangOrigin) / D.cell)
	local hintT = portal.axis == 1 and hint.y or hint.x
	local function spans(ix, iy, room)
		local list = D.grid[Mesh.Key(ix, iy)]
		if not list then return end
		local got
		for s = 1, #list do
			local id = list[s]
			if D.room[id] == room then
				got = got or {}
				got[#got + 1] = id
			end
		end
		return got
	end
	local function consider(j, ixA, iyA, ixB, iyB)
		local sa, sb = spans(ixA, iyA, roomA), spans(ixB, iyB, roomB)
		if not sa or not sb then return end
		for ia = 1, #sa do
			for ib = 1, #sb do
				local ida, idb = sa[ia], sb[ib]
				local z0 = math.max(D.floor[ida], D.floor[idb], portal.lo[3])
				local z1 = math.min(D.ceil[ida], D.ceil[idb], portal.hi[3])
				if z1 >= z0 then
					local cellLo = tangOrigin + j * D.cell
					local segLo = math.max(cellLo, loT)
					local segHi = math.min(cellLo + D.cell, hiT)
					if segHi >= segLo then
						local tangent = math.Clamp(hintT, segLo, segHi)
						local z = math.Clamp(hint.z, z0, z1)
						local x, y
						if portal.axis == 1 then x, y = portal.plane, tangent else x, y = tangent, portal.plane end
						local dx, dy, dz = x - hint.x, y - hint.y, z - hint.z
						out[#out + 1] = {
							ixA = ixA, iyA = iyA, ixB = ixB, iyB = iyB,
							x = x, y = y, z = z,
							d2 = dx * dx + dy * dy + dz * dz,
						}
					end
				end
			end
		end
	end
	for j = j0, j1 do
		local ax, ay = CellOnPlane(portal, iLo, j)
		local bx, by = CellOnPlane(portal, iHi, j)
		consider(j, ax, ay, bx, by)
		consider(j, bx, by, ax, ay)
	end
	table.sort(out, function(a, b) return a.d2 < b.d2 end)
	return out
end

local function AnchorInRoom(portal, x, y, z, room)
	if not portal or portal.axis == 3 or not room then return XYCell(x, y) end
	local iLo, iHi = PlanePair(portal)
	local tangOrigin = portal.axis == 1 and D.originY or D.originX
	local tang = portal.axis == 1 and y or x
	local j = math.floor((tang - tangOrigin) / D.cell)
	local ax, ay = CellOnPlane(portal, iLo, j)
	local bx, by = CellOnPlane(portal, iHi, j)
	if RoomOpen(ax, ay, z, room) then return ax, ay end
	if RoomOpen(bx, by, z, room) then return bx, by end
	return XYCell(x, y)
end

local function Pull(seq, room)
	local n = #seq
	if n <= 2 then return seq end
	local out = { seq[1] }
	local i = 1
	while i < n do
		local j = n
		while j > i + 1 do
			local a, b = seq[i], seq[j]
			if SegmentInside(room, a[1], a[2], a[3], b[1], b[2], b[3]) then break end
			j = j - 1
		end
		out[#out + 1] = seq[j]
		i = j
	end
	return out
end

-- Cell centres between the endpoints. A face point is a stub: the pull stops
-- on the door cell and does not treat the face as a shortcut target.
local function Interiors(room, ax, ay, az, bx, by, bz, cells, stubA, stubB)
	if not cells or #cells <= 1 then return {} end
	local centers = {}
	for i = 1, #cells do
		local ix, iy = cells[i][1], cells[i][2]
		centers[i] = {
			D.originX + (ix + 0.5) * D.cell,
			D.originY + (iy + 0.5) * D.cell,
			ZAt(ix, iy, ax, ay, az, bx, by, bz),
		}
	end
	local seq = {}
	if not stubA then seq[1] = { ax, ay, az } end
	local first = stubA and 1 or 2
	local last = stubB and #centers or (#centers - 1)
	for i = first, last do
		seq[#seq + 1] = centers[i]
	end
	if not stubB then seq[#seq + 1] = { bx, by, bz } end
	if #seq <= 1 then return {} end
	local pulled = Pull(seq, room)
	local out = {}
	for i = 1, #pulled do
		local p = pulled[i]
		local da = (p[1] - ax) * (p[1] - ax) + (p[2] - ay) * (p[2] - ay)
		local db = (p[1] - bx) * (p[1] - bx) + (p[2] - by) * (p[2] - by)
		if da > 1 and db > 1 then out[#out + 1] = p end
	end
	return out
end

local function PolyInside(room, points, exA, exB)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local ok, ix, iy = SegmentInside(room, a[1], a[2], a[3], b[1], b[2], b[3], i == 2 and exA or nil, i == #points and exB or nil)
		if not ok then return false, ix, iy end
	end
	return true
end

local function SharedRoom(p, q)
	if not p or not q then return end
	if p.a == q.a or p.a == q.b then return p.a end
	if p.b == q.a or p.b == q.b then return p.b end
end

local function HintPoints(chain, src, eye)
	local n = #chain
	local px, py, pz = {}, {}, {}
	for i = 1, n do
		local c = portals[chain[i]].center
		px[i], py[i], pz[i] = c.x, c.y, c.z
	end
	for _ = 1, 3 do
		for i = 1, n do
			local ax, ay, az, bx, by, bz
			if i == 1 then
				ax, ay, az = src.x, src.y, src.z
			else
				ax, ay, az = px[i - 1], py[i - 1], pz[i - 1]
			end
			if i == n then
				bx, by, bz = eye.x, eye.y, eye.z
			else
				bx, by, bz = px[i + 1], py[i + 1], pz[i + 1]
			end
			px[i], py[i], pz[i] = FramePoint(portals[chain[i]], ax, ay, az, bx, by, bz)
		end
	end
	local hints = {}
	for i = 1, n do
		hints[i] = Vector(px[i], py[i], pz[i])
	end
	return hints
end

local function CacheKey(chain, src, eye, hints)
	local six, siy = XYCell(src.x, src.y)
	local eix, eiy = XYCell(eye.x, eye.y)
	local parts = {
		table.concat(chain, ">"),
		R.RoomAt(src) or 0, six, siy,
		R.RoomAt(eye) or 0, eix, eiy,
	}
	for i = 1, #hints do
		local hx, hy = XYCell(hints[i].x, hints[i].y)
		parts[#parts + 1] = hx
		parts[#parts + 1] = hy
	end
	return table.concat(parts, ":")
end

-- Live hints where the chord stayed in the room. A snapped face and the
-- corners around it stay until the ear cell or the hint cell changes.
local function Stitch(chain, src, eye, hints, built)
	local n = #chain
	local function pend(i)
		if i == 0 then return src.x, src.y, src.z end
		if i == n + 1 then return eye.x, eye.y, eye.z end
		local face = built.face[i]
		if face then return face[1], face[2], face[3] end
		local h = hints[i]
		return h.x, h.y, h.z
	end
	local raw = {}
	local function push(x, y, z, portal)
		local prev = raw[#raw]
		if prev and (prev[1] - x) ^ 2 + (prev[2] - y) ^ 2 + (prev[3] - z) ^ 2 < 1 then
			if portal then prev.portal = portal end
			return #raw
		end
		raw[#raw + 1] = { x, y, z, portal = portal }
		return #raw
	end
	local miss = {}
	local portalIndex
	for i = 1, n + 1 do
		local x, y, z = pend(i - 1)
		local at = push(x, y, z, i > 1 and (i - 1) or nil)
		if i == n + 1 and n > 0 then portalIndex = at end
		local info = built.legs[i]
		if info and info.corners then
			for c = 1, #info.corners do
				local p = info.corners[c]
				push(p[1], p[2], p[3], nil)
			end
		end
		if info and info.miss then
			miss[#miss + 1] = { at = at, ix = info.miss[1], iy = info.miss[2] }
		end
	end
	local x, y, z = pend(n + 1)
	push(x, y, z, nil)
	local pts = {}
	local portal = {}
	for i = 1, #raw do
		pts[i] = Vector(raw[i][1], raw[i][2], raw[i][3])
		if raw[i].portal then portal[i] = raw[i].portal end
	end
	pts.portal = portal
	pts.portalIndex = portalIndex
	if #miss > 0 then pts.miss = miss end
	local L = 0
	for i = 2, #pts do
		L = L + pts[i]:Distance(pts[i - 1])
	end
	local point = portalIndex and Vector(pts[portalIndex]) or Vector(pts[1])
	return point, L, pts
end

local function BendLegs(chain, src, eye, hints)
	local n = #chain
	local srcRoom = R.RoomAt(src)
	local earRoom = R.RoomAt(eye)
	local legRoom = {}
	legRoom[1] = srcRoom
	for i = 1, n - 1 do
		legRoom[i + 1] = SharedRoom(portals[chain[i]], portals[chain[i + 1]])
	end
	if n > 0 then legRoom[n + 1] = earRoom end
	local function hintAt(i)
		if i == 0 then return src end
		if i == n + 1 then return eye end
		return hints[i]
	end
	local function vertical(i)
		if i <= n and portals[chain[i]].axis == 3 then return true end
		if i > 1 and portals[chain[i - 1]].axis == 3 then return true end
		return false
	end
	local function exempts(i, a, b)
		local exA, exB
		if i > 1 then
			local ix, iy = XYCell(a.x, a.y)
			exA = { ix, iy }
		end
		if i <= n then
			local ix, iy = XYCell(b.x, b.y)
			exB = { ix, iy }
		end
		return exA, exB
	end
	local legBad = {}
	for i = 1, n + 1 do
		local a, b = hintAt(i - 1), hintAt(i)
		local exA, exB = exempts(i, a, b)
		local ok = SegmentInside(legRoom[i], a.x, a.y, a.z, b.x, b.y, b.z, exA, exB)
		legBad[i] = not ok
	end
	local chosen = {}
	local function Solve(i, ix, iy)
		if i > n then return true end
		local portal = portals[chain[i]]
		local before, after = legRoom[i], legRoom[i + 1]
		local hint = hints[i]
		local need = (legBad[i] or legBad[i + 1]) and portal.axis ~= 3 and before and after
		if not need then
			local nx, ny = ix, iy
			if after then nx, ny = AnchorInRoom(portal, hint.x, hint.y, hint.z, after) end
			return Solve(i + 1, nx, ny)
		end
		local from = hintAt(i - 1)
		local cands = CollectFaces(portal, before, after, hint)
		local lim = math.min(#cands, 16)
		for c = 1, lim do
			local face = cands[c]
			local dist, parent = Flood(before, ix, iy, from.x, from.y, from.z, face.x, face.y, face.z)
			if dist[CellKey(face.ixA, face.iyA)] and RoomOpen(face.ixA, face.iyA, face.z, before) and RoomOpen(face.ixB, face.iyB, face.z, after) then
				local rest
				if i == n then
					local ex, ey = XYCell(eye.x, eye.y)
					local distE = Flood(after, face.ixB, face.iyB, face.x, face.y, face.z, eye.x, eye.y, eye.z)
					rest = distE[CellKey(ex, ey)] ~= nil
				else
					rest = Solve(i + 1, face.ixB, face.iyB)
				end
				if rest then
					face.floodDist, face.floodParent = dist, parent
					face.fromIx, face.fromIy = ix, iy
					chosen[i] = face
					return true
				end
			end
		end
		return false
	end
	local solved = n == 0
	if n > 0 then
		local sx, sy = XYCell(src.x, src.y)
		solved = Solve(1, sx, sy)
		if not solved then
			for i = 1, n do chosen[i] = nil end
		end
	end
	local built = { face = {}, legs = {} }
	for i = 1, n do
		local face = chosen[i]
		if face then built.face[i] = { face.x, face.y, face.z } end
	end
	if n > 0 and not solved then
		for i = 1, n + 1 do
			if legBad[i] then
				local a, b = hintAt(i - 1), hintAt(i)
				local exA, exB = exempts(i, a, b)
				local _, ix, iy = SegmentInside(legRoom[i], a.x, a.y, a.z, b.x, b.y, b.z, exA, exB)
				built.legs[i] = { miss = { ix, iy } }
			end
		end
		return built
	end
	local function pointAt(i)
		if i == 0 then return src.x, src.y, src.z end
		if i == n + 1 then return eye.x, eye.y, eye.z end
		local face = built.face[i]
		if face then return face[1], face[2], face[3] end
		local h = hints[i]
		return h.x, h.y, h.z
	end
	for i = 1, n + 1 do
		local ax, ay, az = pointAt(i - 1)
		local bx, by, bz = pointAt(i)
		local room = legRoom[i]
		local a = { x = ax, y = ay, z = az }
		local b = { x = bx, y = by, z = bz }
		local exA, exB = exempts(i, a, b)
		if not room or vertical(i) then
			local ok, ix, iy = SegmentInside(room, ax, ay, az, bx, by, bz, exA, exB)
			if not ok then built.legs[i] = { miss = { ix, iy } } end
		else
			local ok = SegmentInside(room, ax, ay, az, bx, by, bz, exA, exB)
			if not ok then
				local six, siy
				if i == 1 then
					six, siy = XYCell(ax, ay)
				elseif chosen[i - 1] then
					six, siy = chosen[i - 1].ixB, chosen[i - 1].iyB
				else
					six, siy = AnchorInRoom(portals[chain[i - 1]], ax, ay, az, room)
				end
				local eix, eiy
				if i == n + 1 then
					eix, eiy = XYCell(bx, by)
				elseif chosen[i] then
					eix, eiy = chosen[i].ixA, chosen[i].iyA
				else
					eix, eiy = AnchorInRoom(portals[chain[i]], bx, by, bz, room)
				end
				local dist, parent = Flood(room, six, siy, ax, ay, az, bx, by, bz)
				local cells = CellsBetween(dist, parent, six, siy, eix, eiy)
				local missIx, missIy
				if not cells then
					_, missIx, missIy = SegmentInside(room, ax, ay, az, bx, by, bz, exA, exB)
					built.legs[i] = { miss = { missIx, missIy } }
				else
					local corners = Interiors(room, ax, ay, az, bx, by, bz, cells, i > 1, i <= n)
					local poly = { { ax, ay, az } }
					for c = 1, #corners do poly[#poly + 1] = corners[c] end
					poly[#poly + 1] = { bx, by, bz }
					local inside, ix, iy = PolyInside(room, poly, exA, exB)
					if inside then
						built.legs[i] = { corners = corners }
					else
						built.legs[i] = { miss = { ix, iy } }
					end
				end
			end
		end
	end
	return built
end

-- source -> P1 -> ... -> Pn -> ear. A straight leg stays while its cells are
-- in its room. A leg that leaves is bent through those cells. The heard point
-- is the last portal, or the source when the chain is empty.
function R.Aperture(chain, src, eye)
	local hints = HintPoints(chain, src, eye)
	local key = CacheKey(chain, src, eye, hints)
	local built = pathCache[key]
	if not built then
		built = BendLegs(chain, src, eye, hints)
		pathCache[key] = built
	end
	return Stitch(chain, src, eye, hints, built)
end

-- Real length for the few cheapest routes, and always for the one held now.
function R.Evaluate(routes, src, eye, keepKey)
	local rough = {}
	for i = 1, #routes do
		local route = routes[i]
		local ch = route.chain
		local cost
		if #ch == 0 then
			cost = src:Distance(eye)
		else
			cost = src:Distance(portals[ch[1]].center) + route.base + eye:Distance(portals[ch[#ch]].center)
		end
		rough[i] = { route = route, cost = cost }
	end
	table.sort(rough, function(a, b) return a.cost < b.cost end)
	local out = {}
	for i = 1, #rough do
		local route = rough[i].route
		if i <= EVAL_TOP or route.key == keepKey then
			local point, L, pts = R.Aperture(route.chain, src, eye)
			out[#out + 1] = { key = route.key, chain = route.chain, point = point, L = L, pts = pts }
		end
	end
	table.sort(out, function(a, b) return a.L < b.L end)
	return out
end

-- Overlay ------------------------------------------------------------------

local PORTAL_COLOR = {
	["проём"] = Color(90, 220, 230),
	["стекло"] = Color(120, 150, 255),
	["дверь"] = Color(255, 160, 60),
	["пол"] = Color(180, 255, 120),
}
local CHAIN_COLOR = Color(255, 220, 70)
local LINE_COLOR = Color(255, 130, 220)
local POINT_COLOR = Color(255, 90, 210)
local bot, top = Vector(), Vector()
local padV = Vector(1, 1, 1)

-- Columns around the ear coloured by room; the ear room is bright, the rest dim.
function R.DrawCells(eye, radius, earRoom)
	if not built then return end
	local cell = D.cell
	local ix = math.floor((eye.x - D.originX) / cell)
	local iy = math.floor((eye.y - D.originY) / cell)
	local r = math.ceil(radius / cell)
	local grid, floors, ceils, roomOf = D.grid, D.floor, D.ceil, D.room
	for dy = -r, r do
		for dx = -r, r do
			local list = grid[Mesh.Key(ix + dx, iy + dy)]
			if list then
				local x = D.originX + (ix + dx + 0.5) * cell
				local y = D.originY + (iy + dy + 0.5) * cell
				for i = 1, #list do
					local id = list[i]
					local z0 = floors[id] + 4
					local z1 = ceils[id] - 4
					if z1 - z0 > 140 then z1 = z0 + 140 end
					if z1 > z0 and math.abs(z0 - eye.z) < 400 then
						local rm = rooms[roomOf[id]]
						local col = color_white
						if rm then
							col = roomOf[id] == earRoom and rm.color or rm.dim
						end
						bot:SetUnpacked(x, y, z0)
						top:SetUnpacked(x, y, z1)
						render.DrawLine(bot, top, col, false)
					end
				end
			end
		end
	end
end

local function ChainSet(last)
	local set = {}
	if last and last.chain then
		for i = 1, #last.chain do
			set[last.chain[i]] = i
		end
	end
	return set
end

-- Portal frames near the ear, the held chain in yellow with its number,
-- the taut line through the portal points and the heard point.
function R.DrawPortals(eye, radius, last)
	if not built then return end
	local inChain = ChainSet(last)
	local r2 = radius * radius
	for i = 1, #portals do
		local p = portals[i]
		if inChain[i] or p.center:DistToSqr(eye) <= r2 then
			local col = inChain[i] and CHAIN_COLOR or PORTAL_COLOR[R.PortalKind(p)] or color_white
			render.DrawWireframeBox(vector_origin, angle_zero, p.mins - padV, p.maxs + padV, col, false)
		end
	end
	if last and last.pts then
		local pts = last.pts
		for i = 2, #pts - 1 do
			render.DrawLine(pts[i - 1], pts[i], LINE_COLOR, false)
		end
	end
	if last and last.point then
		render.DrawLine(last.point - Vector(0, 0, 8), last.point + Vector(0, 0, 72), POINT_COLOR, false)
		render.DrawWireframeSphere(last.point, 11, 12, 12, POINT_COLOR, false)
	end
end
