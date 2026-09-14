-- Relapse mesh graph: 8-neighbour walk links, hops, one-way drops, ladder
-- shafts; A* through cell centres. Centres stay inside the paint; a taut string
-- hugged cliff lips. Source .nav is fallback until this graph is linked
-- (relapse_ai_mesh_path 0 to stay on .nav).
--
-- A walk link is what a player can do without pressing jump: the chord between
-- the two centres, sampled every few units, never steps more than the step
-- height, and a lifted hull along it meets no wall. Ramps and stair runs pass;
-- a crate face does not (that pair becomes a hop). Drops are found from the
-- higher cell and are one-way: A* never climbs a cliff.

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

local STEP_Z = 18 -- player step height: the most one ground sample may rise over the previous
local JUMP_Z = 68 -- 64u crate + sample lift; loco duck-jump
local DROP_DEFAULT = 200 -- relapse_ai_max_drop; zombies take no fall damage below ~430u
local WALKABLE_Z = 0.7
local MAX_EXPAND = 8000 -- A* expansions before we settle for the closest approach
local MAX_EXPAND_CROSS = 12000 -- other floor: the wrong-floor plateau drains first
local MAX_EXPAND_ISLAND = 1500 -- goal in another component: only find where to stand
Mesh.JumpZ = JUMP_Z

-- Narrow: the paint already guarantees 12u to each side at every centre. A
-- wider box leaning 45° up a stair run clips the next riser.
local LINK_HULL = 8
-- Hull bottom above the chord. On 16u risers the tread edge can sit 15u above
-- the chord (raster phase) plus the 8u the box reaches ahead on a 45° run. A
-- 30u rail or a 48u crate face still ends up inside the box; low curbs and
-- 32u crates are the ground test's job.
local WALK_LIFT = 26
local STAND_TOP = 70
local CROUCH_LIFT = 20
local CROUCH_TOP = 34
local GROUND_STEP = 10 -- chord sampling interval for the step test

local linkRes, groundRes = {}, {}
local linkStart, linkEnd = Vector(), Vector()
local groundStart, groundEnd = Vector(), Vector()
-- Same solids as the paint (92_mesh_build.lua): world, brush entities, static
-- props. A link that saw the brush floor under a prop crate the paint stood on
-- would call the crate top a step.
local LINK_MASK = MASK_PLAYERSOLID
local function LinkFilter(ent)
	return ent:IsWorld() or ent:GetSolid() == SOLID_BSP
end
local linkTr = {
	mask = LINK_MASK,
	filter = LinkFilter,
	output = linkRes,
	mins = Vector(-LINK_HULL, -LINK_HULL, 0),
	maxs = Vector(LINK_HULL, LINK_HULL, STAND_TOP - WALK_LIFT),
	start = linkStart,
	endpos = linkEnd,
}
local groundTr = {
	mask = LINK_MASK,
	filter = LinkFilter,
	output = groundRes,
	start = groundStart,
	endpos = groundEnd,
}
-- Shaft landing: a room behind the wall has paint at the same Z. Trace to the
-- brush centre; a world hit outside the AABB is that wall. No CONTENTS_LADDER
-- (the brush is often SOLID anyway — classify the hit by AABB instead).
local WALL_MASK = bit.bor(CONTENTS_SOLID, CONTENTS_PLAYERCLIP or 0, CONTENTS_MOVEABLE or 0, CONTENTS_WINDOW or 0)
local REACH_Z = 16
local REACH_PAD = 8
local reachRes = {}
local reachStart, reachEnd = Vector(), Vector()
local reachTr = {
	mask = WALL_MASK,
	filter = LinkFilter,
	output = reachRes,
	start = reachStart,
	endpos = reachEnd,
}

Mesh.Blocked = Mesh.Blocked or {}
Mesh.LinkCount = Mesh.LinkCount or 0
Mesh.Linked = Mesh.Linked or false
Mesh.LinkedLadders = Mesh.LinkedLadders or {} -- [ladder id] = true once a shaft is a graph edge

local function CellSize()
	return Mesh.CellSize or 40
end

local function DropZ()
	local cv = AI.cv and AI.cv.max_drop
	local v = cv and cv:GetFloat() or DROP_DEFAULT
	if v < JUMP_Z then v = JUMP_Z end
	return v
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

-- Floor height under (x, y) looking down from zTop; nil when there is none within reach.
local function GroundZ(x, y, zTop, zBottom)
	groundStart:SetUnpacked(x, y, zTop)
	groundEnd:SetUnpacked(x, y, zBottom)
	util.TraceLine(groundTr)
	if groundRes.StartSolid or not groundRes.Hit or groundRes.HitSky then
		return nil
	end
	return groundRes.HitPos.z, groundRes.HitNormal.z
end

-- Hull sweep along the chord a->b with its bottom `lift` above the chord and its
-- top `top` above it. A ramp or stair tread clipped from above is fine
-- (walkable normal); anything else in the way is a wall, a rail or a ceiling.
local function ChordClear(ax, ay, az, bx, by, bz, lift, top)
	linkTr.mins.z = 0
	linkTr.maxs.z = top - lift
	linkStart:SetUnpacked(ax, ay, az + lift)
	linkEnd:SetUnpacked(bx, by, bz + lift)
	util.TraceHull(linkTr)
	if linkRes.StartSolid then
		return false
	end
	if linkRes.Hit and (not linkRes.HitNormal or linkRes.HitNormal.z < WALKABLE_Z) then
		return false
	end
	return true
end

-- Ground under the chord, GROUND_STEP apart: every sample within STEP_Z of the
-- previous one (stairs, ramps, curbs up to the step height), nothing missing
-- (a gap), and no steep face unless the whole thing is a curb.
local function GroundContinuous(ax, ay, az, bx, by, bz, lift)
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local flat = math.sqrt(dx * dx + dy * dy)
	local steps = math.max(2, math.ceil(flat / GROUND_STEP))
	local prevZ = az
	local steep = false
	local low = math.min(az, bz) - STEP_Z - 8
	for s = 1, steps - 1 do
		local t = s / steps
		local cz = az + dz * t
		local gz, nz = GroundZ(ax + dx * t, ay + dy * t, cz + lift, low)
		if not gz then
			return false
		end
		if math.abs(gz - prevZ) > STEP_Z then
			return false
		end
		if nz and nz < WALKABLE_Z then
			steep = true
		end
		prevZ = gz
	end
	if math.abs(bz - prevZ) > STEP_Z then
		return false
	end
	if steep and math.abs(bz - az) > STEP_Z then
		return false
	end
	return true
end

-- Walk link test. Returns ok, crouch.
local function WalkOK(a, b)
	local ax, ay, az = a.pos.x, a.pos.y, a.pos.z
	local bx, by, bz = b.pos.x, b.pos.y, b.pos.z
	-- A cell the paint could only fit a crouched body on is a crouch run.
	local crouch = (a.crouch or b.crouch) and true or false
	if not crouch and not ChordClear(ax, ay, az, bx, by, bz, WALK_LIFT, STAND_TOP) then
		crouch = true
	end
	if crouch then
		-- Vents and low passages: a crouched body still fits.
		if not ChordClear(ax, ay, az, bx, by, bz, CROUCH_LIFT, CROUCH_TOP) then
			return false
		end
	end
	if not GroundContinuous(ax, ay, az, bx, by, bz, crouch and CROUCH_LIFT or WALK_LIFT) then
		return false
	end
	return true, crouch
end

-- Hop from the lower cell onto the higher one: headroom at takeoff, a crouched
-- sweep at lip height (clipping the pad top is fine, a rail is not), a floor to
-- land on.
local function JumpOK(lo, hi)
	local ax, ay, az = lo.pos.x, lo.pos.y, lo.pos.z
	local bx, by, bz = hi.pos.x, hi.pos.y, hi.pos.z
	linkTr.mins.z = 0
	linkTr.maxs.z = 28
	linkStart:SetUnpacked(ax, ay, az + 8)
	linkEnd:SetUnpacked(ax, ay, math.max(az + JUMP_Z + 4, bz + 8))
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
	if linkRes.Hit and (not linkRes.HitNormal or linkRes.HitNormal.z < WALKABLE_Z) then
		return false
	end
	local gz = GroundZ(bx, by, bz + 24, bz - 40)
	return gz ~= nil and math.abs(gz - bz) <= 24
end

-- A rail, curb or parapet on the lip that a hop clears (feet over it with a
-- duck-jump, also from a standstill against it). Its top comes from a line down
-- just past the face the sweep hit. 36 covers the 32u standard rail; taller
-- needs a running duck-jump timed on the rail, which a bot does not have.
local RAIL_MAX = 36

-- Walk off the higher cell and land on the lower one: a standing body clears
-- the lip, or a crouched one clears it above a low rail (then the lip is a
-- hop: returns true, true), then falls straight onto that floor with nothing
-- (a ledge, an awning) in between. Only from the higher cell: one-way.
local function DropOK(hi, lo)
	local ax, ay, az = hi.pos.x, hi.pos.y, hi.pos.z
	local bx, by, bz = lo.pos.x, lo.pos.y, lo.pos.z
	local lift = WALK_LIFT - 6
	local hop = false
	if not ChordClear(ax, ay, az, bx, by, az, lift, STAND_TOP) then
		if linkRes.StartSolid or not linkRes.Hit then
			return false
		end
		local hp = linkRes.HitPos
		local dx, dy = bx - ax, by - ay
		local flat = math.sqrt(dx * dx + dy * dy)
		if flat < 1 then return false end
		-- The hull stopped LINK_HULL short of the face. Probe just inside it (a
		-- 2u fence bar) and a little deeper (a coping stone); take the taller.
		local ux, uy = dx / flat, dy / flat
		local railZ = GroundZ(hp.x + ux * (LINK_HULL + 1), hp.y + uy * (LINK_HULL + 1), az + RAIL_MAX + 2, az + 1)
		local deeper = GroundZ(hp.x + ux * (LINK_HULL + 6), hp.y + uy * (LINK_HULL + 6), az + RAIL_MAX + 2, az + 1)
		if deeper and (not railZ or deeper > railZ) then
			railZ = deeper
		end
		if not railZ or railZ - az > RAIL_MAX then
			return false
		end
		lift = railZ - az + 2
		if not ChordClear(ax, ay, az, bx, by, az, lift, lift + CROUCH_TOP - CROUCH_LIFT) then
			return false
		end
		hop = true
	end
	linkTr.mins.z = 0
	linkTr.maxs.z = STAND_TOP - WALK_LIFT
	linkStart:SetUnpacked(bx, by, az + lift)
	linkEnd:SetUnpacked(bx, by, bz + 2)
	util.TraceHull(linkTr)
	if linkRes.StartSolid then
		return false
	end
	if linkRes.Hit and math.abs(linkRes.HitPos.z - bz) > 12 then
		return false
	end
	return true, hop
end

local function AddDirected(i, j, cost, kind, segType, extra)
	local a = Mesh.Cells[i]
	local e = {j = j, cost = cost, kind = kind, seg = segType}
	if extra then
		for k, v in pairs(extra) do e[k] = v end
	end
	a.nbs[#a.nbs + 1] = e
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

-- Paint floors next to a shaft: both open faces (±normal), not a room 200u away
-- and not Mesh.Nearest without a Z cap (that snaps the pit to the roof).
-- Same-Z paint behind a wall is not a landing: the trace to the shaft must
-- not hit world outside the brush AABB. Then the wider reachable pad wins.
local LANDING_XY = 96
local LANDING_ZPAD = 72
local CLUSTER_Z = 48

local function WalkDegree(c)
	local nbs = c.nbs
	if not nbs then return 0 end
	local n = 0
	for i = 1, #nbs do
		if nbs[i].kind == "walk" then
			n = n + 1
		end
	end
	return n
end

-- A walkable pad (higher walk degree) over a speck in the hole; then nearer.
local function BetterLanding(cur, nxt)
	local cDeg, nDeg = WalkDegree(cur.c), WalkDegree(nxt.c)
	if nDeg ~= cDeg then return nDeg > cDeg end
	return nxt.d2 < cur.d2
end

local function SideWeight(list)
	local w = 0
	for i = 1, #list do
		w = w + WalkDegree(list[i].c)
	end
	return w
end

local function BestOnSide(list)
	local best = list[1]
	for i = 2, #list do
		if BetterLanding(best, list[i]) then
			best = list[i]
		end
	end
	return best.c
end

-- Brush AABB, not the overlay pad (that inflates XY and can swallow the wall).
local function ShaftAABB(ladder)
	local vol = Nav.LadderVolumeOf and Nav.LadderVolumeOf(ladder)
	if vol and vol.mins and vol.maxs then
		return vol.mins, vol.maxs
	end
	local b = ladder.GetBottom and ladder:GetBottom()
	local t = ladder.GetTop and ladder:GetTop()
	if not b or not t then
		return Vector(-1, -1, -1), Vector(1, 1, 1)
	end
	local w = (ladder.GetWidth and ladder:GetWidth() or 32) * 0.5
	local cx = (b.x + t.x) * 0.5
	local cy = (b.y + t.y) * 0.5
	local z0, z1 = math.min(b.z, t.z), math.max(b.z, t.z)
	return Vector(cx - w, cy - w, z0), Vector(cx + w, cy + w, z1)
end

local function InShaftAABB(x, y, z, mins, maxs)
	return x >= mins.x - REACH_PAD and x <= maxs.x + REACH_PAD
		and y >= mins.y - REACH_PAD and y <= maxs.y + REACH_PAD
		and z >= mins.z - REACH_PAD and z <= maxs.z + REACH_PAD
end

-- Horizontal poke at knee height toward the shaft centre.
local function ReachToShaft(px, py, pz, cx, cy, mins, maxs)
	local z = pz + REACH_Z
	reachStart:SetUnpacked(px, py, z)
	reachEnd:SetUnpacked(cx, cy, z)
	util.TraceLine(reachTr)
	if reachRes.StartSolid then return false end
	if not reachRes.Hit then return true end
	local h = reachRes.HitPos
	return InShaftAABB(h.x, h.y, h.z, mins, maxs)
end

-- One landing per Z: the half-plane with more walk links (big pad vs wall strip).
-- Sign of LadderNormal is not a filter; it only splits the cluster.
local function PickFloor(group, cx, cy, nx, ny)
	local pos, neg = {}, {}
	for i = 1, #group do
		local e = group[i]
		local p = e.c.pos
		if (p.x - cx) * nx + (p.y - cy) * ny >= 0 then
			e.d2 = e.d2pos
			pos[#pos + 1] = e
		else
			e.d2 = e.d2neg
			neg[#neg + 1] = e
		end
	end
	if #pos == 0 then return BestOnSide(neg) end
	if #neg == 0 then return BestOnSide(pos) end
	local wp, wn = SideWeight(pos), SideWeight(neg)
	if wn > wp then return BestOnSide(neg) end
	if wp > wn then return BestOnSide(pos) end
	if #neg > #pos then return BestOnSide(neg) end
	return BestOnSide(pos)
end

local function ShaftLandings(ladder)
	local cx, cy = Nav.LadderCenter(ladder)
	local nrm = Nav.LadderNormal and Nav.LadderNormal(ladder) or Vector(0, 0, 0)
	local mins, maxs = ShaftAABB(ladder)
	local z0 = Nav.LadderLandingZ(ladder, false)
	local z1 = Nav.LadderLandingZ(ladder, true)
	if z0 > z1 then z0, z1 = z1, z0 end
	z0, z1 = z0 - LANDING_ZPAD, z1 + LANDING_ZPAD

	local mx1, my1 = cx + nrm.x * 24, cy + nrm.y * 24
	local mx2, my2 = cx - nrm.x * 24, cy - nrm.y * 24
	local size = CellSize()
	local maxd2 = LANDING_XY * LANDING_XY
	local reach = math.max(2, math.ceil(LANDING_XY / size) + 1)
	local cands, seen = {}, {}

	local function consider(mx, my)
		local gx, gy = math.floor(mx / size), math.floor(my / size)
		for dx = -reach, reach do
			for dy = -reach, reach do
				local bucket = GridGet(gx + dx, gy + dy)
				if bucket then
					for b = 1, #bucket do
						local idx = bucket[b]
						local c = Mesh.Cells[idx]
						if c and not seen[idx] and c.pos.z >= z0 and c.pos.z <= z1 then
							local xyd1 = (c.pos.x - mx1) * (c.pos.x - mx1) + (c.pos.y - my1) * (c.pos.y - my1)
							local xyd2 = (c.pos.x - mx2) * (c.pos.x - mx2) + (c.pos.y - my2) * (c.pos.y - my2)
							local d2 = xyd1 < xyd2 and xyd1 or xyd2
							if d2 <= maxd2 then
								seen[idx] = true
								if not c.i then c.i = idx end
								cands[#cands + 1] = {c = c, d2pos = xyd1, d2neg = xyd2}
							end
						end
					end
				end
			end
		end
	end
	consider(mx1, my1)
	consider(mx2, my2)

	if #cands == 0 then return cands end
	table.sort(cands, function(a, b) return a.c.pos.z < b.c.pos.z end)

	local floors = {}
	local i, n = 1, #cands
	while i <= n do
		local seedZ = cands[i].c.pos.z
		local group = {cands[i]}
		i = i + 1
		while i <= n and cands[i].c.pos.z - seedZ <= CLUSTER_Z do
			group[#group + 1] = cands[i]
			i = i + 1
		end
		local live = {}
		for g = 1, #group do
			local p = group[g].c.pos
			if ReachToShaft(p.x, p.y, p.z, cx, cy, mins, maxs) then
				live[#live + 1] = group[g]
			end
		end
		if #live > 0 then
			floors[#floors + 1] = PickFloor(live, cx, cy, nrm.x, nrm.y)
		end
	end
	return floors
end

-- Shafts become graph edges so A* can chain two ladders (down, street, up)
-- between same-Z roofs. One brush may pass several floors; each pair of
-- neighbouring landings is an edge (cost is that rise, not the whole brush).
function Mesh.LinkLadders()
	if not Nav or not Mesh.Cells or #Mesh.Cells == 0 or not Mesh.Grid then
		return 0
	end
	StripLadderNbs()
	Mesh.LinkedLadders = {}
	local list = Nav.Climbables
	if not list or #list == 0 then
		list = Nav.GetAllLadders and Nav.GetAllLadders() or {}
	end
	local n = 0
	local stairs, noBottom, noTop, flat = 0, 0, 0, 0
	for i = 1, #list do
		local ladder = list[i]
		if not Nav.HasLadder(ladder) then
			-- skip
		elseif Nav.IsShaft and not Nav.IsShaft(ladder) then
			stairs = stairs + 1
		else
			local floors = ShaftLandings(ladder)
			local id = (Nav.LadderID and Nav.LadderID(ladder)) or (ladder.GetID and ladder:GetID()) or 0
			if #floors == 0 then
				noBottom = noBottom + 1
				if AI.cv.debug:GetInt() > 0 then
					local b = ladder.GetBottom and ladder:GetBottom()
					AI.Log("mesh ladder #%s: no paint at a landing%s", tostring(id),
						b and string.format(" (%.0f %.0f %.0f)", b.x, b.y, b.z) or "")
				end
			elseif #floors == 1 then
				local botZ = Nav.LadderLandingZ(ladder, false)
				local topZ = Nav.LadderLandingZ(ladder, true)
				local z = floors[1].pos.z
				if math.abs(z - botZ) > 56 then
					noBottom = noBottom + 1
				elseif math.abs(z - topZ) > 56 then
					noTop = noTop + 1
				else
					flat = flat + 1
				end
			else
				local added = false
				for k = 1, #floors - 1 do
					local lo, hi = floors[k], floors[k + 1]
					local dz = hi.pos.z - lo.pos.z
					if dz >= CLUSTER_Z and AddLadderEdge(lo.i, hi.i, ladder, dz) then
						added = true
					end
				end
				if added then
					n = n + 1
					Mesh.LinkedLadders[id] = {
						bot = Vector(floors[1].pos),
						top = Vector(floors[#floors].pos),
					}
				else
					flat = flat + 1
				end
			end
		end
	end
	Mesh.LadderCount = n
	AI.Log("mesh ladders %d shafts of %d climbables (%d stair volumes, %d no paint at bottom, %d no paint at top, %d same floor)",
		n, #list, stairs, noBottom, noTop, flat)
	if Mesh.SendLinkedLadders then
		Mesh.SendLinkedLadders()
	end
	if Mesh.Linked then
		Mesh.ComputeComponents()
	end
	return n
end

function Mesh.IsLadderLinked(ladder)
	if not ladder then return false end
	local id = Nav.LadderID and Nav.LadderID(ladder)
	if not id and ladder.GetID then
		id = ladder:GetID()
	end
	return id ~= nil and Mesh.LinkedLadders[id] ~= nil
end

-- Pair (a, b) seen once (j > i). Walk both ways; else a hop up and the drop
-- back; else a plain one-way drop from the higher cell.
local function LinkPair(i, j, a, b, cell, dropZ)
	local dx, dy, dz = b.pos.x - a.pos.x, b.pos.y - a.pos.y, b.pos.z - a.pos.z
	local flat = math.sqrt(dx * dx + dy * dy)
	if flat < 4 then return end -- same column, another floor
	local adz = math.abs(dz)
	local dist = math.sqrt(flat * flat + dz * dz)
	local near = flat <= cell * 1.6

	if near and adz <= JUMP_Z then
		local ok, crouch = WalkOK(a, b)
		if ok then
			local cost = crouch and dist * 1.6 or dist
			local extra = crouch and {crouch = true} or nil
			AddDirected(i, j, cost, "walk", SEG_GROUND, extra)
			AddDirected(j, i, cost, "walk", SEG_GROUND, extra)
			return
		end
	end
	if adz <= STEP_Z then return end

	local lo, hi, li, hj = a, b, i, j
	if dz < 0 then
		lo, hi, li, hj = b, a, j, i
	end

	if near and adz <= JUMP_Z and JumpOK(lo, hi) then
		AddDirected(li, hj, dist + 55, "jump", SEG_CLIMB)
		AddDirected(hj, li, dist, "drop", SEG_DROP)
		return
	end

	if adz > dropZ then return end
	-- The lip cell sits up to a cell in from the edge and the landing cell up
	-- to a cell out from the wall base (plus a curb between): three cells of
	-- reach (and one aside) for every drop height, or low ledges never get a
	-- landing. Scaling this with the height starved the low ones.
	if flat > cell * 3.2 then return end
	local ok, hop = DropOK(hi, lo)
	if ok then
		AddDirected(hj, li, dist + adz * 0.5 + 30 + (hop and 60 or 0), "drop", SEG_DROP, hop and {hop = true} or nil)
	end
end

local function LinkCell(i, dropZ)
	local cells = Mesh.Cells
	local a = cells[i]
	local cell = CellSize()
	-- Walk/hop partners sit in the 8 neighbouring buckets; a landing may be up
	-- to three buckets out (the roof cell is inset from the lip, the street cell
	-- from the wall base).
	local reach = 3
	for ox = -reach, reach do
		for oy = -reach, reach do
			local bucket = GridGet(a.gx + ox, a.gy + oy)
			if bucket then
				local wide = ox < -1 or ox > 1 or oy < -1 or oy > 1
				for bi = 1, #bucket do
					local j = bucket[bi]
					if j > i then
						local b = cells[j]
						local adz = math.abs(b.pos.z - a.pos.z)
						if adz <= dropZ and (not wide or adz > STEP_Z) then
							LinkPair(i, j, a, b, cell, dropZ)
						end
					end
				end
			end
		end
	end
end

-- Union-find over all edges (direction ignored): a goal in another component is
-- unreachable for sure, so A* does not burn its budget draining the island.
function Mesh.ComputeComponents()
	local cells = Mesh.Cells
	local n = #cells
	local parent = {}
	for i = 1, n do parent[i] = i end
	local function find(x)
		while parent[x] ~= x do
			parent[x] = parent[parent[x]]
			x = parent[x]
		end
		return x
	end
	for i = 1, n do
		local nbs = cells[i].nbs
		if nbs then
			for k = 1, #nbs do
				local ri, rj = find(i), find(nbs[k].j)
				if ri ~= rj then parent[ri] = rj end
			end
		end
	end
	local count, sizes = 0, {}
	for i = 1, n do
		local r = find(i)
		cells[i].comp = r
		if not sizes[r] then
			sizes[r] = 0
			count = count + 1
		end
		sizes[r] = sizes[r] + 1
	end
	local biggest = 0
	for _, s in pairs(sizes) do
		if s > biggest then biggest = s end
	end
	Mesh.ComponentCount = count
	Mesh.BiggestComponent = biggest
	return count, biggest
end

function Mesh.StartLink()
	if Mesh.Building or #Mesh.Cells == 0 then return end

	Mesh.Linked = false
	Mesh.LinkCount = 0
	Mesh.Grid = {}
	Mesh.Blocked = {}
	Mesh.LinkedLadders = {}
	if Mesh.SendLinkedLadders then
		Mesh.SendLinkedLadders()
	end
	local size = CellSize()
	local cells = Mesh.Cells
	for i = 1, #cells do
		local c = cells[i]
		c.i = i
		c.nbs = {}
		c.comp = nil
		c.gx = math.floor(c.pos.x / size)
		c.gy = math.floor(c.pos.y / size)
		GridAdd(c.gx, c.gy, i)
	end
	Mesh.Linking = {i = 1, n = #cells, t0 = SysTime(), ping = 0, dropZ = DropZ()}
	AI.Log("mesh linking %d cells...", #cells)
end

function Mesh.LinkStep()
	local job = Mesh.Linking
	if not job then return end
	local deadline = SysTime() + math.max(0.001, cvBudget:GetFloat() / 1000)
	local n = job.n
	while job.i <= n and SysTime() < deadline do
		LinkCell(job.i, job.dropZ)
		job.i = job.i + 1
	end
	if job.i > n then
		local elapsed = SysTime() - job.t0
		local walks, jumps, drops, crouches = 0, 0, 0, 0
		for k = 1, n do
			local c = Mesh.Cells[k]
			local w = 0
			for _, e in ipairs(c.nbs) do
				if e.kind == "walk" then
					w = w + 1
					walks = walks + 1
					if e.crouch then crouches = crouches + 1 end
				elseif e.kind == "jump" then
					jumps = jumps + 1
				elseif e.kind == "drop" then
					drops = drops + 1
				end
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
		Mesh.LinkLadders()
		local comps, biggest = Mesh.ComputeComponents()
		Mesh.Linking = nil
		Mesh.Linked = true
		AI.Log("mesh linked %d cells: %d walk (%d crouch), %d jump, %d drop, %d ladders; %d components (largest %d) in %.1fs",
			n, walks, crouches, jumps, drops, Mesh.LadderCount or 0, comps, biggest, elapsed)
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

-- Wander target: a cell in our own component when we know it (no wandering
-- toward a balcony we cannot reach).
function Mesh.RandomPointNear(pos, radius)
	local size = CellSize()
	local gx, gy = math.floor(pos.x / size), math.floor(pos.y / size)
	local reach = math.max(1, math.ceil((radius or 600) / size))
	local here = Mesh.Nearest(pos, 200, 72)
	local comp = here and here.comp
	local pool, same = {}, {}
	local r2 = (radius or 600) * (radius or 600)
	for dx = -reach, reach do
		for dy = -reach, reach do
			local bucket = GridGet(gx + dx, gy + dy)
			if bucket then
				for i = 1, #bucket do
					local c = Mesh.Cells[bucket[i]]
					if pos:DistToSqr(c.pos) <= r2 then
						pool[#pool + 1] = c
						if comp and c.comp == comp then
							same[#same + 1] = c
						end
					end
				end
			end
		end
	end
	if #same > 0 then pool = same end
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

-- Chain of cells from start to `last`, with the edge that entered each cell.
local function Unwind(last, came, cameEdge)
	local chain, edgeChain = {}, {}
	local cur = last
	while cur do
		chain[#chain + 1] = cur
		if came[cur] then
			edgeChain[#edgeChain + 1] = cameEdge[cur]
		end
		cur = came[cur]
	end
	local ids, edges = {}, {}
	for k = #chain, 1, -1 do
		ids[#ids + 1] = chain[k]
	end
	for k = #edgeChain, 1, -1 do
		edges[#edges + 1] = edgeChain[k]
	end
	return ids, edges
end

-- Returns ids, edges, reached. When the goal cannot be reached (island, one-way
-- drop, budget) the result is the path to the expanded cell closest to the goal:
-- the bot walks to the cliff edge under the balcony instead of standing at spawn.
local function AStar(startI, goalI, expandCap)
	local cells = Mesh.Cells
	if startI == goalI then
		return {startI}, {}, true
	end

	local g = {}
	local came = {}
	local cameEdge = {}
	local closed = {}
	local h = {n = 0, node = {}, f = {}}
	local goal = cells[goalI]
	g[startI] = 0
	HeapPush(h, startI, Heuristic(cells[startI], goal))

	local expanded = 0
	local bestI, bestH = startI, Heuristic(cells[startI], goal)
	local bad = Nav and Nav.BadLadders
	local now = CurTime()
	while h.n > 0 do
		local i = HeapPop(h)
		if not closed[i] then
			if i == goalI then
				local ids, edges = Unwind(i, came, cameEdge)
				return ids, edges, true
			end
			closed[i] = true
			expanded = expanded + 1
			local hi = Heuristic(cells[i], goal)
			if hi < bestH then
				bestI, bestH = i, hi
			end
			if expanded > expandCap then
				break
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
							cameEdge[j] = e
							HeapPush(h, j, ng + Heuristic(cells[j], goal))
						end
					end
				end
			end
		end
	end
	if bestI == startI then
		return {startI}, {}, false
	end
	local ids, edges = Unwind(bestI, came, cameEdge)
	return ids, edges, false
end

-- Stay on cell centres. A taut string hugs the paint boundary (cliff lips,
-- outer corners). Lookahead on the centre polyline is the smoothing.
-- Only drop a centre that already sits on the line between its neighbours and
-- whose edges match (a crouch run keeps both its ends).
-- Waypoints: {pos, freeze, crouch, enter, leave}; crouch = the run leaving here.
local function CollapseWaypoints(pts)
	if #pts <= 2 then return pts end
	local out = {pts[1]}
	for i = 2, #pts - 1 do
		local cur, nxt = pts[i], pts[i + 1]
		local prev = out[#out]
		local cr = cur.crouch or false
		if cur.freeze or nxt.freeze or cr ~= (nxt.crouch or false) or cr ~= (prev.crouch or false) then
			out[#out + 1] = cur
		else
			local a, b, c = out[#out].pos, cur.pos, nxt.pos
			local abx, aby = b.x - a.x, b.y - a.y
			local bcx, bcy = c.x - b.x, c.y - b.y
			local cross = abx * bcy - aby * bcx
			local dot = abx * bcx + aby * bcy
			if math.abs(cross) > 80 or dot <= 0 then
				out[#out + 1] = cur
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

-- Source PathFollower:MoveCursor is a delta; MoveCursorTo is an absolute
-- distance. After a ladder leave we snap past the shaft chord so ClosestPosition
-- cannot pull the cursor back onto it.
function Path:MoveCursor(delta)
	local d = (self._cursor or 0) + (delta or 0)
	if d < 0 then d = 0 elseif d > self._length then d = self._length end
	self._cursor = d
end

function Path:MoveCursorTo(d)
	d = d or 0
	if d < 0 then d = 0 elseif d > self._length then d = self._length end
	self._cursor = d
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

function Path:MoveCursorToClosestPosition(worldPos, seek, minCursor)
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
	-- SEEK_AHEAD looks in a window around the cursor: a path that comes back
	-- past us (around a building, a switchback) must not pull the cursor onto
	-- its far leg. Off the window the caller rescans the whole path.
	-- minCursor: after a ladder leave, do not snap back onto the spent chord.
	local minD, maxD = 0, math.huge
	if seek == 1 then
		minD = math.max(0, self._cursor - 64)
		maxD = self._cursor + 320
	end
	if minCursor and minCursor > minD then
		minD = minCursor
	end
	local bestD, bestDist = minD, math.huge
	local wx, wy, wz = worldPos.x, worldPos.y, worldPos.z
	for i = 1, n - 1 do
		local a, b = segs[i], segs[i + 1]
		if b.distanceFromStart >= minD and a.distanceFromStart <= maxD then
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

-- Segments follow the Source PathFollower convention the locomotion reads:
-- seg.type is how to move from this waypoint to the next one (the lip carries
-- DROP, the launch cell CLIMB, the ladder foot LADDER_UP plus seg.ladder). The
-- type comes from the graph edge, never from the Z of a chord: a long straight
-- ramp collapses into one steep GROUND segment and stays a walk. Both ends of a
-- hop, drop or shaft chord are kept; crouch runs keep their boundaries.
local function BuildPath(from, goal, ids, edges)
	local cells = Mesh.Cells
	local pts = {{pos = Vector(from.x, from.y, from.z)}}
	for k = 1, #ids do
		local p = cells[ids[k]].pos
		pts[#pts + 1] = {pos = Vector(p.x, p.y, p.z), enter = edges[k - 1]}
	end
	local lastCell = cells[ids[#ids]].pos
	local onFloor = math.abs(goal.z - lastCell.z) < 48 and goal:DistToSqr(lastCell) <= 128 * 128
	if onFloor then
		pts[#pts + 1] = {pos = Vector(goal.x, goal.y, goal.z)}
	end
	for i = 1, #pts do
		local wp = pts[i]
		local nxt = pts[i + 1]
		local leave = nxt and nxt.enter
		local ek = wp.enter and wp.enter.kind
		local lk = leave and leave.kind
		wp.leave = leave
		wp.freeze = (ek ~= nil and ek ~= "walk") or (lk ~= nil and lk ~= "walk")
		wp.crouch = (leave and leave.crouch) and true or false
	end

	local pulled = CollapseWaypoints(pts)
	local path = NewPath()
	local dist = 0
	local prev
	for i = 1, #pulled do
		local wp = pulled[i]
		local p = wp.pos
		if prev then
			dist = dist + prev:Distance(p)
		end
		local leave = wp.leave
		local segType = leave and leave.seg or SEG_GROUND
		path._segs[i] = {
			pos = p,
			distanceFromStart = dist,
			type = segType,
			how = segType,
			length = prev and prev:Distance(p) or 0,
			area = nil,
			ladder = leave and leave.ladder or nil,
			crouch = wp.crouch or nil,
			hop = leave and leave.hop or nil, -- DROP over a rail: jump at the lip
		}
		prev = p
	end
	path._valid = #path._segs >= 1
	path._length = dist
	path._end = pulled[#pulled] and pulled[#pulled].pos or Vector(goal)
	path._cursor = 0
	return path
end

local function PathUsesLadder(path)
	local segs = path:GetAllSegments()
	for i = 1, #segs do
		if segs[i].ladder ~= nil then return true end
	end
	return false
end

-- Snap start and goal to cells, A*, build. Returns path, reached, startC.
-- A path that does not reach ends at the closest approach (reached = false).
function Mesh.FindPath(from, goal)
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

	local cap = MAX_EXPAND
	if startC.comp and goalC.comp and startC.comp ~= goalC.comp then
		cap = MAX_EXPAND_ISLAND
	elseif math.abs(startC.pos.z - goalC.pos.z) > 48 then
		cap = MAX_EXPAND_CROSS
	end
	local ids, edges, found = AStar(startC.i, goalC.i, cap)
	local path = BuildPath(from, goal, ids, edges)
	local last = Mesh.Cells[ids[#ids]].pos
	local reached = found and math.abs(goal.z - last.z) < 48
		and (goal.x - last.x) * (goal.x - last.x) + (goal.y - last.y) * (goal.y - last.y) <= 180 * 180
	return path, reached, startC
end

-- Path request on the paint. Returns false only when the bot stands off the
-- paint (then Source .nav may try); everything else is answered here.
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

	local path, reached, startC = Mesh.FindPath(from, goal)
	if not startC then
		stamp()
		return false
	end
	if reached or not loco then
		return accept(path, reached, goal)
	end

	-- Did not reach and the goal is on another floor: a BSP shaft the graph does
	-- not carry (no cells at an end, CreateNavLadder refused) may still get us
	-- there. Linked shafts were already open to A*; asking for them again would
	-- only send the bot to a mount it cannot use.
	local hunt = loco.Goal
	local toHunt = hunt and goal:DistToSqr(hunt) < 80 * 80
	if toHunt and math.abs(goal.z - from.z) > 40 and Nav and Nav.FindLadderForGoal
	and not (path and PathUsesLadder(path)) then
		local ladder, up = Nav.FindLadderForGoal(from, goal)
		if Nav.HasLadder(ladder) and not Mesh.IsLadderLinked(ladder) and loco.LadderMountPos then
			local mount = loco:LadderMountPos(ladder, up)
			local snap = Mesh.Snap(mount, 160)
			local mpath, mreached = Mesh.FindPath(from, snap)
			if mpath and mreached then
				loco.ViaLadder = ladder
				loco.ViaUp = up
				loco.NeedLadder = true
				return accept(mpath, true, snap)
			end
		end
	end

	return accept(path, false, goal)
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
		if Mesh.Building and Mesh.Build then
			return string.format("relapse mesh painting %d%% (%d cells so far), bots on %s",
				math.floor(Mesh.Build.done / math.max(1, Mesh.Build.total) * 100), #Mesh.Cells, Nav.SourceStatus())
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
