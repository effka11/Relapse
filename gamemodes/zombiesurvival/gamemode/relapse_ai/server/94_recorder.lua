-- Flight recorder for AI bugs.
--
-- Two files in data/relapse_ai/rec/, never deleted here:
--   <map>_bug_<time>_<n>_<reason>_<nick>.txt  written on stuck / path fail /
--     ladder abort / give-up / hopeless / startsolid / lua error, and only
--     while a U recording is open. The bug line is a full bot frame taken when
--     that reason is scheduled. The file follows after a short wait, so the
--     ring still holds the lines around that pose. The same reason does not
--     open a second file for 10s; a different reason does.
--   <map>_rec_<time>_<n>.txt  only after relapse_ai_rec, and only while U is held
--     down as a recording. Chunks are 12s; the next chunk is a new file.
--
-- Each line is one JSON object. t is seconds from the start of that file.
-- A bot line is a pose plus the trace in front of the body and the floor under
-- the feet. A note / path / dec line is a decision. A scene line is the props,
-- brushes and nav penalties around the players.

local AI = RelapseAI
local Rec = {}
AI.Rec = Rec

local CurTime = CurTime
local IsValid = IsValid
local ipairs = ipairs
local pairs = pairs
local util_TraceHull = util.TraceHull
local util_TraceLine = util.TraceLine

local SPAN = 12
local DIR = "relapse_ai/rec"
local SAMPLE = 0.2
local SCENE = 3

Rec.Armed = false
Rec.Recording = false
Rec.Seq = 0
Rec.BugSeq = 0
Rec.Span = SPAN

local ring = {}
local pending = {}
local cooldown = {}
local lastBits = {}
local lastText = {}

local traceSelf
local bodyStart, bodyEnd = Vector(), Vector()
local bodyMins, bodyMaxs = Vector(-16, -16, 0), Vector(16, 16, 72)
local bodyRes = {}
-- Same pass-throughs as the locomotion probe: a sigil post, a dropped weapon,
-- prop_prop_blocker (IgnoreTraces, players walk through it). Overlapping one
-- is not a stuck hull. Return true to hit.
local PASSABLE_GROUP = {
	[COLLISION_GROUP_DEBRIS] = true,
	[COLLISION_GROUP_DEBRIS_TRIGGER] = true,
	[COLLISION_GROUP_WEAPON] = true,
	[COLLISION_GROUP_IN_VEHICLE] = true,
	[COLLISION_GROUP_PASSABLE_DOOR] = true,
	[COLLISION_GROUP_DOOR_BLOCKER] = true,
	[COLLISION_GROUP_DISSOLVING] = true,
}
local function BodyHits(ent)
	if ent == traceSelf then return false end
	if ent.IgnoreTraces or PASSABLE_GROUP[ent:GetCollisionGroup()] then return false end
	if ent.ShouldNotCollide and ent:ShouldNotCollide(traceSelf) then return false end
	return true
end
local bodyTr = {
	mask = MASK_PLAYERSOLID,
	collisiongroup = COLLISION_GROUP_PLAYER,
	start = bodyStart,
	endpos = bodyEnd,
	mins = bodyMins,
	maxs = bodyMaxs,
	filter = BodyHits,
	output = bodyRes,
}
local floorStart, floorEnd = Vector(), Vector()
local floorRes = {}
local floorTr = {
	mask = MASK_PLAYERSOLID,
	start = floorStart,
	endpos = floorEnd,
	filter = function(ent)
		return ent ~= traceSelf
	end,
	output = floorRes,
}

local SEG_NAME = {
	[0] = "ground",
	[1] = "drop",
	[2] = "climb",
	[3] = "gap",
	[4] = "ladder_up",
	[5] = "ladder_down",
}

local MOVE_NAME = {
	[MOVETYPE_NONE] = "none",
	[MOVETYPE_WALK] = "walk",
	[MOVETYPE_STEP] = "step",
	[MOVETYPE_FLY] = "fly",
	[MOVETYPE_NOCLIP] = "noclip",
	[MOVETYPE_LADDER] = "ladder",
	[MOVETYPE_VPHYSICS] = "vphys",
	[MOVETYPE_OBSERVER] = "obs",
}

local SOLID_NAME = {}
if SOLID_BSP then SOLID_NAME[SOLID_BSP] = "bsp" end
if SOLID_BBOX then SOLID_NAME[SOLID_BBOX] = "bbox" end
if SOLID_OBB then SOLID_NAME[SOLID_OBB] = "obb" end
if SOLID_VPHYSICS then SOLID_NAME[SOLID_VPHYSICS] = "vphys" end

local BINDS = {
	{IN_ATTACK, "attack"},
	{IN_ATTACK2, "attack2"},
	{IN_JUMP, "jump"},
	{IN_DUCK, "duck"},
	{IN_FORWARD, "fwd"},
	{IN_BACK, "back"},
	{IN_MOVELEFT, "left"},
	{IN_MOVERIGHT, "right"},
	{IN_USE, "use"},
	{IN_RELOAD, "reload"},
	{IN_WALK, "walk"},
	{IN_SPEED, "speed"},
	{IN_ZOOM, "zoom"},
}

local ATTRS = {}
local function addAttr(name, flag)
	if flag then ATTRS[#ATTRS + 1] = {name, flag} end
end
addAttr("CROUCH", NAV_MESH_CROUCH)
addAttr("JUMP", NAV_MESH_JUMP)
addAttr("PRECISE", NAV_MESH_PRECISE)
addAttr("NO_JUMP", NAV_MESH_NO_JUMP)
addAttr("STOP", NAV_MESH_STOP)
addAttr("RUN", NAV_MESH_RUN)
addAttr("WALK", NAV_MESH_WALK)
addAttr("AVOID", NAV_MESH_AVOID)
addAttr("TRANSIENT", NAV_MESH_TRANSIENT)
addAttr("DONT_HIDE", NAV_MESH_DONT_HIDE)
addAttr("STAND", NAV_MESH_STAND)
addAttr("STAIRS", NAV_MESH_STAIRS)
addAttr("CLIFF", NAV_MESH_CLIFF)
addAttr("OBSTACLE_TOP", NAV_MESH_OBSTACLE_TOP)
addAttr("NAV_BLOCKER", NAV_MESH_NAV_BLOCKER)

---------------------------------------------------------------------------
-- Small packs
---------------------------------------------------------------------------

local function rnd(v)
	if not v or v ~= v or v >= math.huge or v <= -math.huge then return 0 end
	return math.floor(v + 0.5)
end

local function vec(v)
	if not v then return nil end
	return {rnd(v.x), rnd(v.y), rnd(v.z)}
end

local function norm(v)
	if not v then return nil end
	return {
		math.floor(v.x * 100 + 0.5) / 100,
		math.floor(v.y * 100 + 0.5) / 100,
		math.floor(v.z * 100 + 0.5) / 100,
	}
end

local function vec2(x, y)
	return {math.floor(x * 100 + 0.5) / 100, math.floor(y * 100 + 0.5) / 100}
end

local function Safe(s)
	s = tostring(s or "x")
	s = string.gsub(s, "[^%w_%-]", "_")
	if s == "" then s = "x" end
	if #s > 32 then s = string.sub(s, 1, 32) end
	return s
end

local function JSON(ev)
	local ok, s = pcall(util.TableToJSON, ev)
	if not ok then return nil end
	return s
end

-- t on the table is absolute CurTime. The line stores seconds from t0.
local function Line(ev, t0)
	local abs = ev.t or t0
	local dt = abs - t0
	if dt < 0 then dt = 0 end
	ev.t = math.floor(dt * 100 + 0.5) / 100
	local ok, s = pcall(util.TableToJSON, ev)
	ev.t = abs
	if not ok then return nil end
	return s
end

local function TeamName(pl)
	local t = pl:Team()
	if t == TEAM_HUMAN then return "human" end
	if t == TEAM_UNDEAD then return "undead" end
	return tostring(t)
end

local function Role(pl)
	if pl:Team() == TEAM_UNDEAD and pl.GetZombieClassTable then
		local tab = pl:GetZombieClassTable()
		if tab and tab.Name then return tab.Name end
	end
	return "human"
end

local function Weapon(pl)
	local wep = pl:GetActiveWeapon()
	if IsValid(wep) then return wep:GetClass() end
end

local function MoveName(mt)
	return MOVE_NAME[mt] or tostring(mt)
end

local function BtnText(bits)
	local t = {}
	for i = 1, #BINDS do
		local mask = BINDS[i][1]
		if mask and bit.band(bits, mask) ~= 0 then
			t[#t + 1] = BINDS[i][2]
		end
	end
	if #t == 0 then return "-" end
	return table.concat(t, "+")
end

local function EyePair(pl)
	local ang = pl:EyeAngles()
	return {rnd(ang.p), rnd(ang.y)}
end

local function EyeFlat(pl)
	local f = Angle(0, pl:EyeAngles().y, 0):Forward()
	return f.x, f.y
end

local function CanUse(pl)
	if not IsValid(pl) then return true end
	if pl:IsSuperAdmin() then return true end
	local Mesh = AI.Mesh
	return Mesh and Mesh.IsOwner and Mesh.IsOwner(pl) or false
end

local function Reply(pl, msg)
	if AI.Mesh and AI.Mesh.Reply then
		AI.Mesh.Reply(pl, msg)
		return
	end
	print(msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
		pl:ChatPrint(msg)
	end
end

local function Notify(msg)
	print(msg)
	for _, pl in ipairs(player.GetHumans()) do
		if CanUse(pl) then
			pl:PrintMessage(HUD_PRINTCONSOLE, msg)
			pl:ChatPrint(msg)
		end
	end
end

function Rec.Warn(err)
	local now = CurTime()
	if now < (Rec.NextErr or 0) then return end
	Rec.NextErr = now + 5
	AI.Warn("recorder: %s", tostring(err))
end

---------------------------------------------------------------------------
-- Ring and disk
---------------------------------------------------------------------------

local function Prune(now)
	local n = #ring
	if n == 0 then return end
	local cut = now - SPAN
	if ring[1].t >= cut and n <= 3000 then return end
	local fresh = {}
	for i = 1, n do
		local ev = ring[i]
		if ev.t and ev.t >= cut then
			fresh[#fresh + 1] = ev
		end
	end
	local extra = #fresh - 3000
	if extra > 0 then
		local slim = {}
		for i = extra + 1, #fresh do
			slim[#slim + 1] = fresh[i]
		end
		fresh = slim
	end
	ring = fresh
end

local function Flush()
	if not Rec.Path or not Rec.Buf or #Rec.Buf == 0 then return end
	local text = table.concat(Rec.Buf, "\n") .. "\n"
	Rec.Buf = {}
	local ok, err = pcall(file.Append, Rec.Path, text)
	if not ok then Rec.Warn(err) end
end

local function Push(ev, at)
	ev.t = at or CurTime()
	ring[#ring + 1] = ev
	if not Rec.Recording or not Rec.Path then return end
	local line = Line(ev, Rec.ChunkStart or ev.t)
	if not line then return end
	local buf = Rec.Buf
	if not buf then
		buf = {}
		Rec.Buf = buf
	end
	buf[#buf + 1] = line
	if #buf >= 40 then Flush() end
end

local function WriteChunks(path, lines)
	if #lines == 0 then return false end
	local ok, err = pcall(file.Write, path, lines[1] .. "\n")
	if not ok then
		Rec.Warn(err)
		return false
	end
	local buf = {}
	for i = 2, #lines do
		buf[#buf + 1] = lines[i]
		if #buf >= 40 then
			ok, err = pcall(file.Append, path, table.concat(buf, "\n") .. "\n")
			if not ok then Rec.Warn(err) end
			buf = {}
		end
	end
	if #buf > 0 then
		ok, err = pcall(file.Append, path, table.concat(buf, "\n") .. "\n")
		if not ok then Rec.Warn(err) end
	end
	return true
end

---------------------------------------------------------------------------
-- World: mesh cell, nav quad, props
---------------------------------------------------------------------------

local function NavAttrText(area)
	local bits = area:GetAttributes()
	if not bits or bits == 0 then return nil end
	local names = {}
	for i = 1, #ATTRS do
		local flag = ATTRS[i][2]
		if bit.band(bits, flag) ~= 0 then
			names[#names + 1] = ATTRS[i][1]
		end
	end
	if #names == 0 then return tostring(bits) end
	return table.concat(names, ",")
end

local function CellInfo(pos, wantLinks)
	local Mesh = AI.Mesh
	if not Mesh or not Mesh.NearestOnFloor or not pos then return {miss = 1} end
	local c = Mesh.NearestOnFloor(pos, 96, 64)
	local air
	if not c and Mesh.Nearest then
		c = Mesh.Nearest(pos, 180, 220)
		air = c and 1 or nil
	end
	if not c then return {miss = 1} end
	local sizes = Mesh.ComponentSizes
	local info = {
		i = c.i,
		p = vec(c.pos),
		z = rnd(c.pos.z),
		dz = rnd(c.pos.z - pos.z),
		d = rnd(pos:Distance(c.pos)),
		comp = c.comp,
		csz = c.comp and sizes and sizes[c.comp] or nil,
		air = air,
	}
	if c.crouch then info.crouch = 1 end
	local blocked = Mesh.Blocked and Mesh.Blocked[c.i]
	if blocked and blocked.Expiry > CurTime() then
		info.block = blocked.Penalty
		info.blockleft = rnd(blocked.Expiry - CurTime())
	end
	if wantLinks and c.nbs then
		local nbs = {}
		local cells = Mesh.Cells
		local walks = 0
		for k = 1, #c.nbs do
			local e = c.nbs[k]
			local door = e.kind == "door"
			if door or walks < 8 then
				if not door then walks = walks + 1 end
				local o = cells and cells[e.j]
				local item = {j = e.j, k = e.kind}
				if o then item.dz = rnd(o.pos.z - c.pos.z) end
				if e.crouch then item.cr = 1 end
				if e.door then
					item.door = e.door
					if Mesh.DoorPassable then
						item.pass = Mesh.DoorPassable(e.door) and 1 or 0
					end
				end
				if e.ladder and AI.Nav and AI.Nav.LadderID then
					item.lad = AI.Nav.LadderID(e.ladder)
				end
				nbs[#nbs + 1] = item
			end
		end
		info.nbs = nbs
	end
	return info
end

local function AreaInfo(pos, wantShape)
	if not navmesh or not navmesh.IsLoaded or not navmesh.IsLoaded() then
		return {loaded = 0}
	end
	local area = navmesh.GetNavArea(pos, 48)
	if not IsValid(area) then
		local near = navmesh.GetNearestNavArea(pos, false, 220, false, true)
		if not IsValid(near) then return {miss = 1} end
		return {miss = 1, near = near:GetID(), nd = rnd(pos:Distance(near:GetCenter()))}
	end
	local id = area:GetID()
	local info = {id = id, c = vec(area:GetCenter()), attr = NavAttrText(area)}
	local blocked = AI.Nav and AI.Nav.BlockedAreas and AI.Nav.BlockedAreas[id]
	if blocked then
		info.block = blocked.Penalty
		info.left = rnd((blocked.Expiry or 0) - CurTime())
	end
	if wantShape then
		local quad = {}
		for corner = 0, 3 do
			local ok, v = pcall(area.GetCorner, area, corner)
			if ok and v then quad[#quad + 1] = vec(v) end
		end
		if #quad > 0 then info.quad = quad end
		local ok, adj = pcall(area.GetAdjacentAreas, area)
		if ok and adj then
			local ids = {}
			for i = 1, math.min(#adj, 8) do
				if IsValid(adj[i]) then ids[#ids + 1] = adj[i]:GetID() end
			end
			if #ids > 0 then info.adj = ids end
		end
	end
	return info
end

local function SkipClass(cls)
	return string.sub(cls, 1, 8) == "trigger_"
		or string.sub(cls, 1, 5) == "info_"
		or string.sub(cls, 1, 4) == "env_"
		or string.sub(cls, 1, 6) == "logic_"
		or string.sub(cls, 1, 6) == "point_"
		or string.sub(cls, 1, 6) == "light_"
		or string.sub(cls, 1, 8) == "ambient_"
end

-- Nearest solids only: brushes are the planes around the bot, props are what it walks into.
local function KeepEnt(ent)
	if not IsValid(ent) or ent:IsWorld() or ent:IsPlayer() then return false end
	local cls = ent:GetClass()
	if SkipClass(cls) then return false end
	if cls == "predicted_viewmodel" or cls == "gmod_hands" then return false end
	if ent:IsWeapon() and IsValid(ent:GetOwner()) then return false end
	return ent:GetSolid() ~= SOLID_NONE
end

-- prop_door: 0 closed, 1 opening, 2 open, 3 closing.
-- func_door: 0 open, 1 closed, 2 opening, 3 closing.
local function DoorLeaf(ent)
	if not IsValid(ent) then return nil end
	local cls = ent:GetClass()
	local st, names
	if cls == "prop_door_rotating" then
		st = ent.GetInternalVariable and ent:GetInternalVariable("m_eDoorState")
		names = {[0] = "closed", [1] = "opening", [2] = "open", [3] = "closing"}
	elseif cls == "func_door" or cls == "func_door_rotating" then
		st = ent.GetInternalVariable and ent:GetInternalVariable("m_toggle_state")
		names = {[0] = "open", [1] = "closed", [2] = "opening", [3] = "closing"}
	else
		return nil
	end
	local info = {leaf = names[st] or tostring(st or "?")}
	local ban = AI.Mesh and AI.Mesh.DoorBan and AI.Mesh.DoorBan[ent:EntIndex()]
	if ban and ban > CurTime() then info.ban = rnd(ban - CurTime()) end
	-- Doors keep their pool in ent.Heal (nil = untouched); Health() is always 0.
	if ent.Heal then
		info.hp = rnd(ent.Heal)
		info.hpmax = rnd(ent.TotalHeal or ent.Heal)
	end
	if ent.IsDoorLocked and ent:IsDoorLocked() then info.locked = 1 end
	if AI.Loco and AI.Loco.DoorBreakable and not AI.Loco.DoorBreakable(ent) then info.wall = 1 end
	return info
end

local function PackEnt(ent)
	local cls = ent:GetClass()
	local info = {
		ev = "ent",
		id = ent:EntIndex(),
		cls = cls,
		p = vec(ent:GetPos()),
		a = (function()
			local ang = ent:GetAngles()
			return {rnd(ang.p), rnd(ang.y), rnd(ang.r)}
		end)(),
		solid = SOLID_NAME[ent:GetSolid()] or ent:GetSolid(),
		move = MoveName(ent:GetMoveType()),
	}
	local mdl = ent:GetModel()
	if mdl and mdl ~= "" then info.mdl = mdl end
	local hp = ent:Health()
	if hp and hp > 0 then info.hp = hp end
	if ent.IsNailed and ent:IsNailed() then info.nail = 1 end
	-- Barricade pool (nails, deployables): Health() is 0 there. Same source as
	-- locomotion's ObstacleHealth, so a flat hp across a break means no dent.
	if ent.IsBarricadeProp and ent.GetBarricadeHealth and ent:IsBarricadeProp() then
		local bh = ent:GetBarricadeHealth()
		if bh and bh > 0 then
			info.hp = rnd(bh)
			local mx = ent.GetMaxBarricadeHealth and ent:GetMaxBarricadeHealth()
			if mx and mx > 0 then info.hpmax = rnd(mx) end
		end
	elseif ent.PropHealth then
		info.hp = rnd(ent.PropHealth)
		if ent.TotalHealth then info.hpmax = rnd(ent.TotalHealth) end
	end
	if cls == "prop_obj_sigil" and ent.GetSigilHealth then
		info.hp = rnd(ent:GetSigilHealth())
		info.corrupt = ent.GetSigilCorrupted and ent:GetSigilCorrupted() and 1 or 0
	end
	local parent = ent:GetParent()
	if IsValid(parent) then
		info.parent = parent:GetClass()
		info.parentid = parent:EntIndex()
	end
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		info.mass = rnd(phys:GetMass())
		if not phys:IsMotionEnabled() then info.frozen = 1 end
		if phys:IsAsleep() then info.asleep = 1 end
	end
	local ok, mn, mx = pcall(ent.WorldSpaceAABB, ent)
	if ok and mn and mx then
		info.mn = vec(mn)
		info.mx = vec(mx)
	end
	local leaf = DoorLeaf(ent)
	if leaf then
		for k, v in pairs(leaf) do info[k] = v end
	end
	return info
end

local function CollectEnts(origins, radius, cap)
	local seen = {}
	local scored = {}
	for o = 1, #origins do
		local found = ents.FindInSphere(origins[o], radius)
		for i = 1, #found do
			local ent = found[i]
			if not seen[ent] and KeepEnt(ent) then
				seen[ent] = true
				local p = ent:GetPos()
				local best = math.huge
				for j = 1, #origins do
					local d = p:DistToSqr(origins[j])
					if d < best then best = d end
				end
				scored[#scored + 1] = {ent, best}
			end
		end
	end
	table.sort(scored, function(a, b) return a[2] < b[2] end)
	local out = {}
	local n = math.min(#scored, cap)
	for i = 1, n do
		out[i] = PackEnt(scored[i][1])
	end
	return out
end

-- Live path prices: Source nav areas (id), Relapse mesh cells (cell + p) and
-- taxed mesh edges (a, b). A bot that keeps walking into a priced spot means
-- the price is on the wrong thing.
local function BlockedList()
	local out = {}
	local now = CurTime()
	local areas = AI.Nav and AI.Nav.BlockedAreas
	if areas then
		for id, entry in pairs(areas) do
			if #out >= 32 then break end
			out[#out + 1] = {
				id = id,
				pen = entry.Penalty,
				left = rnd((entry.Expiry or 0) - now),
			}
		end
	end
	local Mesh = AI.Mesh
	if Mesh and Mesh.Blocked and Mesh.Cells then
		for i, entry in pairs(Mesh.Blocked) do
			if #out >= 64 then break end
			if entry.Expiry > now then
				local c = Mesh.Cells[i]
				if c then
					out[#out + 1] = {cell = i, p = vec(c.pos), pen = entry.Penalty, left = rnd(entry.Expiry - now)}
				end
			end
		end
	end
	if Mesh and Mesh.EdgeTaxList then
		local ok, list = pcall(Mesh.EdgeTaxList, 32)
		if ok and list then
			for _, t in ipairs(list) do
				out[#out + 1] = {edge = 1, a = vec(t.a), b = vec(t.b), pen = t.pen, left = rnd(t.left)}
			end
		end
	end
	if #out == 0 then return nil end
	return out
end

local function LadderList()
	local list = AI.Nav and AI.Nav.Climbables
	if not list or #list == 0 then return nil end
	local out = {}
	local cap = math.min(#list, 64)
	local Mesh = AI.Mesh
	for i = 1, cap do
		local c = list[i]
		local item = {
			id = c.ID,
			b = vec(c.Bottom),
			t = vec(c.Top),
			w = rnd(c.Width or 0),
		}
		if c.Normal then
			item.n = {
				math.floor(c.Normal.x * 100 + 0.5) / 100,
				math.floor(c.Normal.y * 100 + 0.5) / 100,
			}
		end
		if Mesh and Mesh.IsLadderLinked then
			local ok, linked = pcall(Mesh.IsLadderLinked, c)
			if ok and linked then item.link = 1 end
		end
		out[i] = item
	end
	return out, #list
end

local function Roster()
	local out = {}
	for _, pl in ipairs(player.GetAll()) do
		if IsValid(pl) then
			out[#out + 1] = {
				id = pl:EntIndex(),
				name = pl:Nick(),
				team = TeamName(pl),
				role = Role(pl),
				wep = Weapon(pl),
				hp = pl:Alive() and pl:Health() or 0,
				bot = (pl:IsBot() or pl.IsRelapseAIBot) and 1 or nil,
				p = vec(pl:GetPos()),
				alive = pl:Alive() and 1 or 0,
			}
		end
	end
	return out
end

local function MakeHead(kind)
	local Mesh = AI.Mesh
	local mesh = {ready = 0}
	if Mesh then
		-- code is the painter in this build. ver is the file that was loaded.
		-- An empty skin still has code; it does not have ver.
		mesh.code = Mesh.PaintVersion
		mesh.ver = Mesh.PaintedVersion
		mesh.cell = Mesh.CellSize
		mesh.cells = Mesh.Cells and #Mesh.Cells or 0
		mesh.links = Mesh.LinkCount or 0
		mesh.comps = Mesh.ComponentCount
		mesh.big = Mesh.BiggestComponent
		mesh.bigid = Mesh.BiggestId
		mesh.ready = Mesh.IsReady and Mesh.IsReady() and 1 or 0
	end
	local nav = {
		status = AI.Nav and AI.Nav.Status and AI.Nav.Status() or "?",
		areas = (navmesh.IsLoaded and navmesh.IsLoaded()) and navmesh.GetNavAreaCount() or 0,
		blocked = AI.Nav and AI.Nav.BlockedAreas and table.Count(AI.Nav.BlockedAreas) or 0,
	}
	local ladders, ln = LadderList()
	local head = {
		ev = "head",
		kind = kind,
		map = game.GetMap(),
		abs = CurTime(),
		wave = GAMEMODE and GAMEMODE.GetWave and GAMEMODE:GetWave() or 0,
		active = GAMEMODE and GAMEMODE.GetWaveActive and GAMEMODE:GetWaveActive() and 1 or 0,
		tick = rnd((engine.TickInterval() or 0) * 1000),
		ai = AI.Version,
		humans = #player.GetHumans(),
		bots = AI.Count and AI.Count() or 0,
		mesh = mesh,
		nav = nav,
		ladders = ladders,
		ladders_n = ln,
	}
	head.t = 0
	return head
end

local function OriginsAround(focus)
	if focus then return {focus} end
	local origins = {}
	for _, pl in ipairs(player.GetAll()) do
		if IsValid(pl) and pl:Alive() then
			origins[#origins + 1] = pl:GetPos()
		end
	end
	return origins
end

local function PushScene(focus)
	Push({
		ev = "scene",
		wave = GAMEMODE and GAMEMODE.GetWave and GAMEMODE:GetWave() or 0,
		active = GAMEMODE and GAMEMODE.GetWaveActive and GAMEMODE:GetWaveActive() and 1 or 0,
		roster = Roster(),
		blocked = BlockedList(),
	})
	local packed = CollectEnts(OriginsAround(focus), 480, 64)
	for i = 1, #packed do
		Push(packed[i])
	end
end

---------------------------------------------------------------------------
-- Traces and bot frames
---------------------------------------------------------------------------

local function TracePack(tr)
	if not tr then return nil end
	local ent = tr.Entity
	local info = {
		solid = tr.StartSolid and 1 or 0,
		frac = math.floor((tr.Fraction or 0) * 100 + 0.5) / 100,
		hit = tr.Hit and 1 or 0,
	}
	if tr.Hit or tr.StartSolid then
		info.n = norm(tr.HitNormal)
		info.at = vec(tr.HitPos)
		if tr.HitWorld then
			info.world = 1
		elseif IsValid(ent) then
			info.cls = ent:GetClass()
			info.eid = ent:EntIndex()
			local mdl = ent:GetModel()
			if mdl and mdl ~= "" then info.mdl = mdl end
			if ent:IsPlayer() then info.name = ent:Nick() end
			if ent.IsNailed and ent:IsNailed() then info.nail = 1 end
			if ent.IgnoreTraces then info.ign = 1 end
			info.cg = ent:GetCollisionGroup()
		end
		if tr.Contents and tr.Contents ~= 0 then info.contents = tr.Contents end
	end
	if tr.HitSky then info.sky = 1 end
	return info
end

local function ApplyHull(pl)
	local mn, mx
	if pl:Crouching() then
		mn, mx = pl:GetHullDuck()
	else
		mn, mx = pl:GetHull()
	end
	if mn and mx then
		bodyMins:Set(mn)
		bodyMaxs:Set(mx)
	end
end

local function TraceBody(pl, x, y)
	traceSelf = pl
	ApplyHull(pl)
	local pos = pl:GetPos()
	bodyStart:Set(pos)
	bodyEnd:SetUnpacked(pos.x + x * 56, pos.y + y * 56, pos.z)
	local tr = util_TraceHull(bodyTr)
	if not tr or tr.Fraction == nil then tr = bodyRes end
	return TracePack(tr)
end

local function TraceFloor(pl)
	traceSelf = pl
	local pos = pl:GetPos()
	floorStart:SetUnpacked(pos.x, pos.y, pos.z + 8)
	floorEnd:SetUnpacked(pos.x, pos.y, pos.z - 160)
	local tr = util_TraceLine(floorTr)
	if not tr or tr.Fraction == nil then tr = floorRes end
	return TracePack(tr)
end

local function WishDir(pl, loco)
	local wish = loco and loco.WishDir
	if wish and wish:LengthSqr() > 0.04 then
		return wish.x, wish.y, "wish"
	end
	local path = loco and loco.PathDir
	if path and path:LengthSqr() > 0.04 then
		return path.x, path.y, "path"
	end
	local x, y = EyeFlat(pl)
	return x, y, "eye"
end

local function PackSeg(seg, i)
	local item = {
		i = i,
		typ = SEG_NAME[seg.type] or tostring(seg.type or 0),
		p = vec(seg.pos),
		d = rnd(seg.distanceFromStart or 0),
	}
	if seg.length and seg.length > 0 then item.ln = rnd(seg.length) end
	if seg.crouch then item.cr = 1 end
	if seg.hop then item.hop = 1 end
	if seg.ladder and AI.Nav and AI.Nav.LadderID then
		item.lad = AI.Nav.LadderID(seg.ladder)
	end
	return item
end

local function PathBrief(loco)
	if not loco then return nil end
	local info = {
		ok = loco.PathValid and 1 or 0,
		fail = loco.FailedPaths or 0,
		pend = loco.PathPending and 1 or nil,
		off = loco.OffPath and 1 or nil,
		-- Always 0 or 1. A missing reach used to look like a path that arrived.
		reach = loco.PathReached and 1 or 0,
	}
	if loco.Path and loco.Path.GetEnd then
		local okEnd, e = pcall(loco.Path.GetEnd, loco.Path)
		if okEnd and e then info.endp = vec(e) end
	end
	if loco.Path and loco.Path.GetDoor then
		local door = loco.Path:GetDoor()
		if IsValid(door) then info.door = door:EntIndex() end
	end
	if loco.PathValid and loco.Segments then
		local segs = loco.Segments
		local i = loco.SegIndex or 1
		local seg = segs[i]
		info.len = rnd(loco.PathLength or 0)
		info.cur = rnd(loco.Cursor or 0)
		info.n = #segs
		info.i = i
		if seg then info.typ = SEG_NAME[seg.type] or tostring(seg.type) end
		for j = i, math.min(i + 6, #segs) do
			local s = segs[j]
			if s.type and s.type ~= 0 then
				info.nxt = SEG_NAME[s.type] or tostring(s.type)
				info.nd = rnd((s.distanceFromStart or 0) - (loco.Cursor or 0))
				break
			end
		end
	end
	if loco.ExhaustedSince then
		info.exh = rnd(CurTime() - loco.ExhaustedSince)
	elseif loco.Exhausted then
		info.exh = 0
	end
	return info
end

local function SegWindow(loco)
	local segs = loco.Segments
	if not segs then return nil end
	local i = math.max(1, (loco.SegIndex or 1) - 1)
	local out = {}
	for j = i, math.min(#segs, i + 7) do
		out[#out + 1] = PackSeg(segs[j], j)
	end
	if #out == 0 then return nil end
	return out
end

local function ObstacleShort(loco)
	local ent = loco.Obstacle
	if not IsValid(ent) then return nil end
	local info = {
		id = ent:EntIndex(),
		cls = ent:GetClass(),
		loose = loco.ObstacleLoose and 1 or nil,
	}
	local mdl = ent:GetModel()
	if mdl and mdl ~= "" then info.mdl = mdl end
	if ent.IsNailed and ent:IsNailed() then info.nail = 1 end
	info.p = vec(ent:GetPos())
	local hp = ent:Health()
	if hp and hp > 0 then info.hp = hp end
	local leaf = DoorLeaf(ent)
	if leaf then
		for k, v in pairs(leaf) do info[k] = v end
	end
	return info
end

local function Watch(bot)
	local w = bot.Rec
	if not w then
		w = {}
		bot.Rec = w
	end
	return w
end

local function GoalKey(loco)
	if not loco or not loco.Goal then return "" end
	if IsValid(loco.GoalEnt) then return "e" .. loco.GoalEnt:EntIndex() end
	local g = loco.Goal
	return string.format("%d_%d_%d", rnd(g.x / 64) * 64, rnd(g.y / 64) * 64, rnd(g.z / 48) * 48)
end

local function IntentName(data)
	if IsValid(data) then
		return data:IsPlayer() and data:Nick() or data:GetClass()
	end
	if istable(data) and IsValid(data.Ent) then
		local e = data.Ent
		return "mem:" .. (e:IsPlayer() and e:Nick() or e:GetClass())
	end
	return ""
end

-- Which notes are bugs (file name suffix). The note vocabulary is the
-- locomotion contract, see the header of 30_locomotion.lua.
local function BugReason(why)
	if not why or why == "" or why == "stuck:crowd" then return nil end
	if string.find(why, "stuck", 1, true) then return "stuck" end
	if why == "path:fail" then return "path" end
	if string.sub(why, 1, 13) == "ladder:abort:" then return "ladder" end
	if why == "break:noway" then return "break" end
	if string.sub(why, 1, 7) == "giveup:" or why == "door:locked" then return "giveup" end
	return nil
end

local function QuietState(bot)
	local st = bot.Debug and bot.Debug.State
	return st == "wait" or st == "crow" or st == "dead" or st == "down"
end

local BotFrame

-- The note frame is shared with the caller, which still edits it. The bug line
-- keeps its own copy, stamped at this moment, not when the file is written.
-- The file name is the folded bucket (stuck). The line keeps the note's own
-- why (stuck1:snag). first is that word from the note which opened the file.
local function CopyBugFrame(src, firstWhy)
	if not src then return nil end
	local raw = util.TableToJSON(src)
	if not raw then return nil end
	local ok, frame = pcall(util.JSONToTable, raw)
	if not ok or not istable(frame) then return nil end
	frame.ev = "bug"
	if not frame.why or frame.why == "" then
		frame.why = firstWhy
	end
	if firstWhy and frame.why ~= firstWhy then
		frame.first = firstWhy
	end
	return frame
end

local framing = false

local function LiveBugFrame(bot, reason, firstReason)
	if framing or not bot or not IsValid(bot.Player) then return nil end
	framing = true
	local ok, frame = pcall(BotFrame, bot, "bug", true)
	framing = false
	if not ok or not frame then return nil end
	if not frame.why or frame.why == "" then
		frame.why = reason
	end
	if firstReason and frame.why ~= firstReason then
		frame.first = firstReason
	end
	return frame
end

local function Cool(pl, reason, now)
	local bag = cooldown[pl]
	if not bag then
		bag = {}
		cooldown[pl] = bag
	end
	bag[reason] = now + 10
end

-- One bug line per reason, at the pose where it was decided. A later different
-- reason while this one is still waiting replaces the name and the pose.
local function CommitBug(pl, bot, reason, firstReason, frame, now)
	if frame then
		Push(frame, now)
	else
		Push({
			ev = "bug",
			why = reason,
			first = firstReason,
			name = IsValid(pl) and pl:Nick() or "?",
		}, now)
	end
	if IsValid(pl) then
		PushScene(pl:GetPos())
	end
end

local function ScheduleBug(bot, reason, opts)
	opts = opts or {}
	if not Rec.Recording then return end
	local pl = bot and bot.Player
	if not IsValid(pl) then return end
	if not opts.force and QuietState(bot) then return end
	local now = CurTime()
	local delay = opts.delay or 2.2
	local p = pending[pl]
	if p then
		if p.reason ~= reason then
			local frame = opts.frame and CopyBugFrame(opts.frame, p.firstReason) or LiveBugFrame(bot, reason, p.firstReason)
			p.reason = reason
			p.frame = frame
			p.frameAt = now
			p.bot = bot
			CommitBug(pl, bot, reason, p.firstReason, frame, now)
		end
		p.until_ = math.min(p.first + 4, now + delay)
		return
	end
	local bag = cooldown[pl]
	if not opts.force and bag and (bag[reason] or 0) > now then return end
	local noteWhy = (opts.frame and opts.frame.why) or reason
	local frame = opts.frame and CopyBugFrame(opts.frame, noteWhy) or LiveBugFrame(bot, reason, noteWhy)
	pending[pl] = {
		reason = reason,
		firstReason = noteWhy,
		bot = bot,
		name = pl:Nick(),
		until_ = now + delay,
		first = now,
		frame = frame,
		frameAt = now,
	}
	CommitBug(pl, bot, reason, reason, frame, now)
end

BotFrame = function(bot, ev, full)
	local pl = bot.Player
	if not IsValid(pl) then return nil end
	if ev == "bot" and not pl:Alive() then return nil end
	local wantSolid = false
	local loco = bot.Loco
	local pos = pl:GetPos()
	local bb = bot.BB
	local info = {
		ev = ev,
		id = pl:EntIndex(),
		name = pl:Nick(),
		brain = bot.BrainName,
		team = TeamName(pl),
		role = Role(pl),
		wep = Weapon(pl),
		hp = pl:Health(),
		p = vec(pos),
		vel = vec(pl:GetVelocity()),
		eye = EyePair(pl),
		st = (bot.Debug and bot.Debug.State) or (bb and bb.State) or nil,
		ms = math.floor((bot.ThinkMs or 0) * 100 + 0.5) / 100,
	}
	local ar = pl:Armor()
	if ar > 0 then info.ar = ar end
	if pl:HasGodMode() then info.god = 1 end
	local water = pl:WaterLevel()
	if water > 0 then info.water = water end
	if pl:IsOnGround() then info.ground = 1 end
	if pl:Crouching() then info.duck = 1 end
	info.mt = MoveName(pl:GetMoveType())
	if pl.RelapseLadderHold then info.holdlad = 1 end
	local btn = lastText[pl]
	if btn and btn ~= "-" then info.btn = btn end

	local gnd = pl:GetGroundEntity()
	if IsValid(gnd) and not gnd:IsWorld() then
		info.gnd = gnd:GetClass()
		info.gndid = gnd:EntIndex()
		local mdl = gnd:GetModel()
		if mdl and mdl ~= "" then info.gndm = mdl end
		if gnd.IsNailed and gnd:IsNailed() then info.gndnail = 1 end
		local phys = gnd.GetPhysicsObject and gnd:GetPhysicsObject()
		if IsValid(phys) and not phys:IsMotionEnabled() then info.gndfr = 1 end
	end

	if loco then
		info.mode = loco.Mode
		if loco.Hold then info.hold = 1 end
		info.stuck = loco.StuckLevel or 0
		info.fail = loco.FailedPaths or 0
		info.eps = loco.StuckEpisodes or 0
		if loco.ClearPath then info.clear = 1 end
		if loco.LastAction then
			info.note = loco.LastAction
			if loco.LastActionTime then
				info.noteage = math.floor((CurTime() - loco.LastActionTime) * 100 + 0.5) / 100
			end
		end
		local wx, wy, along = WishDir(pl, loco)
		info.wish = vec2(wx, wy)
		info.along = along
		if loco:IsHopeless() then info.hop = 1 end
		if loco.Goal then
			local g = {p = vec(loco.Goal), tol = rnd(loco.GoalTol or 0), d = rnd(pos:Distance(loco.Goal)), dz = rnd(loco.Goal.z - pos.z)}
			if IsValid(loco.GoalEnt) then
				g.id = loco.GoalEnt:EntIndex()
				g.cls = loco.GoalEnt:GetClass()
				if loco.GoalEnt:IsPlayer() then g.name = loco.GoalEnt:Nick() end
			end
			info.goal = g
		end
		if loco.WalkDest then info.dest = vec(loco.WalkDest) end
		if loco.SteerPos then info.steer = vec(loco.SteerPos) end
		if loco.PathGoal and loco.Goal and loco.PathGoal:DistToSqr(loco.Goal) > 32 * 32 then
			info.pathgoal = vec(loco.PathGoal)
		end
		info.path = PathBrief(loco)
		if loco.Ladder then
			local L = loco.Ladder
			info.ladder = L.Phase
			if AI.Nav and AI.Nav.LadderID then info.lad = AI.Nav.LadderID(L.Ent) end
			info.ladup = L.Up and 1 or 0
		end
		-- NoteFocus is the door or prop this note is about, when that ent
		-- was never stored as the obstacle (an opening we walked past).
		local focus = loco.NoteFocus
		if full and IsValid(loco.Obstacle) then
			local packed = PackEnt(loco.Obstacle)
			packed.ev = nil
			packed.loose = loco.ObstacleLoose and 1 or nil
			info.obs = packed
		elseif full and IsValid(focus) then
			local packed = PackEnt(focus)
			packed.ev = nil
			info.obs = packed
		else
			info.obs = ObstacleShort(loco)
		end
		if full then info.win = SegWindow(loco) end
		if pl:Alive() then
			local body = TraceBody(pl, wx, wy)
			if body then body.along = along end
			info.body = body
			info.floor = TraceFloor(pl)
			local w = Watch(bot)
			local mt = pl:GetMoveType()
			local hullSolid = body ~= nil and body.solid == 1
			-- Overlapping a teammate is a crowd, not a stuck brush. Ladder / noclip overlap is expected.
			local solidBug = hullSolid and along == "wish" and body.cls ~= "player"
				and mt ~= MOVETYPE_LADDER and mt ~= MOVETYPE_NOCLIP
			if solidBug and not w.solid and not framing and CurTime() - (bot.Created or 0) > 2 then
				wantSolid = true
			end
			w.solid = hullSolid
		end
	end

	local combat = bot.Combat
	if combat then
		local tgt = combat.Target
		if IsValid(tgt) then
			info.tgt = tgt:IsPlayer() and tgt:Nick() or tgt:GetClass()
			info.tid = tgt:EntIndex()
		end
		-- Melee range. Path arrival is path.reach; the same name on this line
		-- used to be this flag, and a reader took it for the path.
		info.melee = combat.InReach and 1 or 0
		info.td = rnd(combat.Dist or 0)
		info.rch = rnd(combat.Reach or 0)
		if combat.IsSwinging and combat:IsSwinging() then info.swing = 1 end
		if combat.WantDuck then info.wantduck = 1 end
		if full and combat.AimPos and IsValid(combat.Target) then
			info.aim = vec(combat.AimPos)
		end
	end
	if bb then
		local idata = IntentName(bb.IntentData)
		if idata ~= "" then info.idata = idata end
		if bb.Intent then info.intent = bb.Intent end
	end

	if pl:Alive() then
		local cell = CellInfo(pos, false)
		local area = AreaInfo(pos, false)
		local w = Watch(bot)
		if cell.miss then
			info.cellmiss = 1
		else
			info.cell = cell.i
			info.cz = cell.z
			info.cdz = cell.dz
			info.cd = cell.d
			info.comp = cell.comp
			info.csz = cell.csz
			if cell.crouch then info.ccrouch = 1 end
			if cell.air then info.cellair = 1 end
			if full or cell.i ~= w.cell then
				w.cell = cell.i
				local fullCell = CellInfo(pos, true)
				info.nbs = fullCell.nbs
			end
		end
		if area.miss then
			info.areamiss = 1
			info.areanear = area.near
		elseif area.loaded == 0 then
			info.navoff = 1
		else
			info.area = area.id
			info.attr = area.attr
			if area.block then
				info.block = area.block
				info.blockleft = area.left
			end
			if full or area.id ~= w.area then
				w.area = area.id
				local shape = AreaInfo(pos, true)
				info.quad = shape.quad
				info.adj = shape.adj
			end
		end
	end

	if wantSolid then
		ScheduleBug(bot, "solid", {frame = info})
	end
	return info
end

local function PlayerFrame(pl)
	if not IsValid(pl) or not pl:Alive() or pl:IsBot() or pl.IsRelapseAIBot then return nil end
	local x, y = EyeFlat(pl)
	local info = {
		ev = "ply",
		id = pl:EntIndex(),
		name = pl:Nick(),
		team = TeamName(pl),
		role = Role(pl),
		wep = Weapon(pl),
		hp = pl:Health(),
		p = vec(pl:GetPos()),
		vel = vec(pl:GetVelocity()),
		eye = EyePair(pl),
		mt = MoveName(pl:GetMoveType()),
	}
	if pl:IsOnGround() then info.ground = 1 end
	if pl:Crouching() then info.duck = 1 end
	local btn = lastText[pl]
	if btn and btn ~= "-" then info.btn = btn end
	local body = TraceBody(pl, x, y)
	if body then body.along = "eye" end
	info.body = body
	info.floor = TraceFloor(pl)
	local gnd = pl:GetGroundEntity()
	if IsValid(gnd) and not gnd:IsWorld() then
		info.gnd = gnd:GetClass()
		info.gndid = gnd:EntIndex()
	end
	return info
end

local function SampleBots(full)
	local list = AI.BotList
	if not list then return end
	for i = 1, #list do
		local bot = list[i]
		if bot and IsValid(bot.Player) then
			local ok, frame = pcall(BotFrame, bot, full and "snap" or "bot", full and true or false)
			if ok then
				if frame then Push(frame) end
			else
				Rec.Warn(frame)
			end
		end
	end
end

local function SamplePlayers()
	for _, pl in ipairs(player.GetAll()) do
		local ok, frame = pcall(PlayerFrame, pl)
		if ok then
			if frame then Push(frame) end
		else
			Rec.Warn(frame)
		end
	end
end

local function WriteBug(p)
	file.CreateDir("relapse_ai")
	file.CreateDir(DIR)
	Rec.BugSeq = Rec.BugSeq + 1
	local path = string.format("%s/%s_bug_%s_%d_%s_%s.txt",
		DIR, game.GetMap(), os.date("%Y%m%d_%H%M%S"), Rec.BugSeq, Safe(p.reason), Safe(p.name))
	local t0 = ring[1] and ring[1].t or CurTime()
	local head = MakeHead("bug")
	head.why = p.reason
	head.first = p.firstReason
	head.bot = p.name
	head.span = math.floor((CurTime() - t0) * 100 + 0.5) / 100
	local lines = {}
	local h = JSON(head)
	if h then lines[1] = h end
	for i = 1, #ring do
		local line = Line(ring[i], t0)
		if line then lines[#lines + 1] = line end
	end
	if WriteChunks(path, lines) then
		Notify(string.format("[Relapse AI] баг data/%s (%s, %s)", path, tostring(p.reason), tostring(p.name or "?")))
	end
end

local function FlushPending(now)
	for pl, p in pairs(pending) do
		if now >= p.until_ then
			pending[pl] = nil
			Cool(pl, p.reason, now)
			if p.firstReason and p.firstReason ~= p.reason then
				Cool(pl, p.firstReason, now)
			end
			local wrote, werr = pcall(WriteBug, p)
			if not wrote then Rec.Warn(werr) end
		end
	end
end

---------------------------------------------------------------------------
-- Manual recording
---------------------------------------------------------------------------

local function OpenChunk()
	file.CreateDir("relapse_ai")
	file.CreateDir(DIR)
	Rec.ChunkStart = CurTime()
	local name = string.format("%s_rec_%s_%d.txt", game.GetMap(), os.date("%Y%m%d_%H%M%S"), Rec.Seq)
	Rec.Path = DIR .. "/" .. name
	Rec.Buf = {}
	local head = MakeHead("rec")
	local line = JSON(head)
	if not line then
		Rec.Path = nil
		Rec.Warn("head json")
		return false
	end
	local ok, err = pcall(file.Write, Rec.Path, line .. "\n")
	if not ok then
		Rec.Path = nil
		Rec.Warn(err)
		return false
	end
	print("[Relapse AI] rec open data/" .. Rec.Path)
	return true
end

local function FinishChunk(why)
	if not Rec.Recording or not Rec.Path then return end
	local dur = CurTime() - (Rec.ChunkStart or CurTime())
	local path = Rec.Path
	Push({ev = "end", why = why, dur = math.floor(dur * 100 + 0.5) / 100})
	Flush()
	Notify(string.format("[Relapse AI] запись data/%s (%.1f с)", path, dur))
end

function Rec.Broadcast()
	local watchers = {}
	for _, pl in ipairs(player.GetHumans()) do
		if CanUse(pl) then
			watchers[#watchers + 1] = pl
		end
	end
	if #watchers == 0 then return end
	local elapsed = 0
	if Rec.Recording and Rec.ChunkStart then
		elapsed = CurTime() - Rec.ChunkStart
		if elapsed < 0 then elapsed = 0 end
	end
	net.Start("RelapseAI.Rec")
	net.WriteBool(Rec.Armed and true or false)
	net.WriteBool(Rec.Recording and true or false)
	net.WriteFloat(elapsed)
	net.WriteUInt(math.min(Rec.Seq, 1023), 10)
	net.WriteUInt(SPAN, 8)
	net.Send(watchers)
end

function Rec.Start()
	if Rec.Recording then return end
	Rec.Seq = Rec.Seq + 1
	if not OpenChunk() then return end
	Rec.Recording = true
	PushScene()
	SampleBots(true)
	SamplePlayers()
	Flush()
	Rec.NextSample = CurTime() + SAMPLE
	Rec.NextScene = CurTime() + SCENE
	Rec.Broadcast()
end

function Rec.Stop()
	if not Rec.Recording then return end
	-- A bug in the last two seconds of the take still gets its file.
	FlushPending(math.huge)
	FinishChunk("stop")
	Rec.Recording = false
	Rec.Path = nil
	Rec.Buf = {}
	Rec.Broadcast()
end

function Rec.Roll()
	if not Rec.Recording then return end
	FinishChunk("roll")
	Rec.Seq = Rec.Seq + 1
	if not OpenChunk() then
		Rec.Recording = false
		Rec.Path = nil
		Rec.Broadcast()
		return
	end
	PushScene()
	SampleBots(true)
	SamplePlayers()
	Rec.NextSample = CurTime() + SAMPLE
	Rec.NextScene = CurTime() + SCENE
	Rec.Broadcast()
end

function Rec.Tick()
	local now = CurTime()
	if now >= (Rec.NextPrune or 0) then
		Rec.NextPrune = now + 0.5
		Prune(now)
	end
	FlushPending(now)
	if Rec.Recording and Rec.ChunkStart and now - Rec.ChunkStart >= SPAN then
		Rec.Roll()
	end
	if Rec.Armed and now >= (Rec.NextSync or 0) then
		Rec.NextSync = now + (Rec.Recording and 0.25 or 2)
		Rec.Broadcast()
	end
	if now >= (Rec.NextSample or 0) then
		Rec.NextSample = now + SAMPLE
		SampleBots(false)
		SamplePlayers()
	end
	if Rec.Recording and now >= (Rec.NextScene or 0) then
		Rec.NextScene = now + SCENE
		PushScene()
	end
	if Rec.Recording and now >= (Rec.NextFlush or 0) then
		Rec.NextFlush = now + 0.5
		Flush()
	end
end

---------------------------------------------------------------------------
-- Decisions
---------------------------------------------------------------------------

function Rec.OnNote(loco, why)
	local bot = loco and loco.Bot
	local reason = BugReason(why)
	local frame
	if bot and IsValid(bot.Player) then
		local w = Watch(bot)
		local now = CurTime()
		-- Crouch notes repeat every think while the segment lasts.
		if not reason and w.noteWhy == why and now - (w.noteAt or 0) < 0.6 then
			return
		end
		w.noteWhy = why
		w.noteAt = now
		-- Every note carries the path window and the obstacle. A short frame hid
		-- the polyline on obstacle/detour, which is where a door shows up.
		frame = BotFrame(bot, "note", true)
		if frame then
			frame.why = why
			Push(frame)
		end
	else
		Push({ev = "note", why = why})
	end
	if reason and bot then
		ScheduleBug(bot, reason, {frame = frame})
	end
end

function Rec.OnPath(loco, path, reached, goal)
	local pl = loco.Player
	local info = {
		ev = "path",
		ok = (path and path.IsValid and path:IsValid()) and 1 or 0,
		reach = reached and 1 or 0,
		len = rnd(loco.PathLength or 0),
		fail = loco.FailedPaths or 0,
		goal = vec(goal),
		from = IsValid(pl) and vec(pl:GetPos()) or nil,
	}
	if IsValid(pl) then
		info.id = pl:EntIndex()
		info.name = pl:Nick()
	end
	if path and path.GetEnd then
		local ok, e = pcall(path.GetEnd, path)
		if ok then info.endp = vec(e) end
	end
	local segs = loco.Segments
	if segs and #segs > 0 then
		local n = #segs
		local step = n > 70 and math.ceil(n / 50) or 1
		local seen = {}
		local packed = {}
		local function add(i)
			if seen[i] or not segs[i] then return end
			seen[i] = true
			packed[#packed + 1] = PackSeg(segs[i], i)
		end
		for i = 1, n, step do
			add(i)
		end
		add(n)
		for i = 1, n do
			local s = segs[i]
			if s.type and s.type ~= 0 then add(i) end
		end
		table.sort(packed, function(a, b) return a.i < b.i end)
		info.segs = packed
		info.segn = n
		if step > 1 then info.trunc = 1 end
	end
	if IsValid(pl) then
		local here = CellInfo(pl:GetPos(), false)
		local there = goal and CellInfo(goal, false) or nil
		if here and not here.miss then
			info.cell = here.i
			info.comp = here.comp
			info.csz = here.csz
			if here.block then
				info.block = here.block
				info.blockleft = here.blockleft
			end
		end
		if there and not there.miss then
			info.gcell = there.i
			info.gcomp = there.comp
			info.gcsz = there.csz
		end
		local endCell = info.endp and CellInfo(Vector(info.endp[1], info.endp[2], info.endp[3]), false)
		if endCell and not endCell.miss then
			info.ecell = endCell.i
			info.ecomp = endCell.comp
			info.ecsz = endCell.csz
		end
	end
	if path and path.GetDoor then
		local door = path:GetDoor()
		if IsValid(door) then
			info.door = door:EntIndex()
			local leaf = DoorLeaf(door)
			if leaf then
				info.leaf = leaf.leaf
				if leaf.ban then info.ban = leaf.ban end
			end
		end
	end
	-- The same arrival logged with every segment list buried the notes.
	-- Same reach, door, end, goal island and goal cell within 2s is
	-- dropped. A new goal on that same arrival keeps the line without
	-- the polyline.
	local bot = loco.Bot
	if bot then
		local w = Watch(bot)
		local function bucket(p, cell)
			if not p then return "-" end
			return string.format("%d_%d_%d", rnd(p[1] / cell) * cell, rnd(p[2] / cell) * cell, rnd(p[3] / cell) * cell)
		end
		local fat = string.format("%s|%s|%s|%s", tostring(info.reach or 0), tostring(info.door or 0), bucket(info.endp, 16), tostring(info.gcomp or 0))
		local fullSig = fat .. "|" .. bucket(info.goal, 64)
		local now = CurTime()
		if w.pathFull == fullSig and now - (w.pathAt or 0) < 2 then
			return
		end
		if w.pathFat == fat then
			info.segs = nil
			info.segn = nil
			info.trunc = nil
			info.again = 1
		end
		w.pathFat = fat
		w.pathFull = fullSig
		w.pathAt = now
	end
	Push(info)
end

function Rec.OnHopeless(bot, intent)
	local ok, err = pcall(function()
		if not bot or not IsValid(bot.Player) then return end
		local frame = BotFrame(bot, "hopeless", true)
		if frame then
			frame.why = "hopeless"
			frame.abandoned = intent
			Push(frame)
		end
		ScheduleBug(bot, "hopeless", {delay = 1.5, frame = frame})
	end)
	if not ok then Rec.Warn(err) end
end

function Rec.OnLuaError(bot, err)
	local pl = bot and bot.Player
	Push({
		ev = "lua",
		name = IsValid(pl) and pl:Nick() or "?",
		brain = bot and bot.BrainName or "?",
		err = tostring(err),
	})
	if bot then
		ScheduleBug(bot, "lua", {force = true, delay = 0.4})
	end
end

function Rec.AfterThink(bot)
	local pl = bot.Player
	if not IsValid(pl) or not pl:Alive() then return end
	local loco = bot.Loco
	if not loco then return end
	local bb = bot.BB or {}
	local w = Watch(bot)
	local st = (bot.Debug and bot.Debug.State) or bb.State or ""
	local intent = bb.Intent or ""
	local idata = IntentName(bb.IntentData)
	local mode = loco.Mode or ""
	local hold = loco.Hold and 1 or 0
	local pend = loco.PathPending and 1 or 0
	local reach = bot.Combat and bot.Combat.InReach and 1 or 0
	local tgt = ""
	if bot.Combat and IsValid(bot.Combat.Target) then
		local t = bot.Combat.Target
		tgt = t:IsPlayer() and t:Nick() or t:GetClass()
	end
	local gk = GoalKey(loco)
	local phase = loco.Ladder and loco.Ladder.Phase or ""
	local hop = loco:IsHopeless() and 1 or 0
	local obs = IsValid(loco.Obstacle) and loco.Obstacle:GetClass() or ""
	if st == w.st and intent == w.intent and idata == w.idata and mode == w.mode
		and hold == w.hold and pend == w.pend and reach == w.reach and tgt == w.tgt
		and gk == w.gk and phase == w.phase and hop == w.hop and obs == w.obs then
		return
	end
	w.st, w.intent, w.idata, w.mode = st, intent, idata, mode
	w.hold, w.pend, w.reach, w.tgt = hold, pend, reach, tgt
	w.gk, w.phase, w.hop, w.obs = gk, phase, hop, obs
	Push({
		ev = "dec",
		id = pl:EntIndex(),
		name = pl:Nick(),
		st = st ~= "" and st or nil,
		intent = intent ~= "" and intent or nil,
		idata = idata ~= "" and idata or nil,
		mode = mode,
		hold = hold == 1 and 1 or nil,
		pend = pend == 1 and 1 or nil,
		melee = reach,
		tgt = tgt ~= "" and tgt or nil,
		goal = gk ~= "" and gk or nil,
		ladder = phase ~= "" and phase or nil,
		hop = hop == 1 and 1 or nil,
		obs = obs ~= "" and obs or nil,
		note = loco.LastAction,
		stuck = loco.StuckLevel or 0,
	})
end

function Rec.OnCmd(pl, cmd)
	if not IsValid(pl) then return end
	local bits = cmd:GetButtons()
	if lastBits[pl] == bits then return end
	local text = BtnText(bits)
	local was = lastText[pl] or "-"
	local first = lastBits[pl] == nil
	lastBits[pl] = bits
	lastText[pl] = text
	if first and text == "-" then return end
	Push({
		ev = "act",
		id = pl:EntIndex(),
		name = pl:Nick(),
		bot = (pl:IsBot() or pl.IsRelapseAIBot) and 1 or nil,
		btn = text,
		was = was,
		p = vec(pl:GetPos()),
		vel = vec(pl:GetVelocity()),
		eye = EyePair(pl),
		fwd = rnd(cmd:GetForwardMove()),
		side = rnd(cmd:GetSideMove()),
		team = TeamName(pl),
		wep = Weapon(pl),
	})
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

util.AddNetworkString("RelapseAI.Rec")
util.AddNetworkString("RelapseAI.RecKey")

hook.Add("Think", "RelapseAI.Rec", function()
	local ok, err = pcall(Rec.Tick)
	if not ok then Rec.Warn(err) end
end)

hook.Add("StartCommand", "RelapseAI.Rec", function(pl, cmd)
	if not IsValid(pl) or pl:IsBot() or pl.IsRelapseAIBot then return end
	local ok, err = pcall(Rec.OnCmd, pl, cmd)
	if not ok then Rec.Warn(err) end
end)

hook.Add("PlayerDeath", "RelapseAI.Rec", function(pl, inf, atk)
	local atkName
	if IsValid(atk) then
		atkName = atk:IsPlayer() and atk:Nick() or atk:GetClass()
	end
	Push({
		ev = "death",
		id = IsValid(pl) and pl:EntIndex() or nil,
		name = IsValid(pl) and pl:Nick() or "?",
		bot = IsValid(pl) and (pl:IsBot() or pl.IsRelapseAIBot) and 1 or nil,
		atk = atkName,
		inf = IsValid(inf) and inf:GetClass() or nil,
		p = IsValid(pl) and vec(pl:GetPos()) or nil,
	})
end)

hook.Add("PlayerSpawn", "RelapseAI.Rec", function(pl)
	timer.Simple(0, function()
		if not IsValid(pl) then return end
		Push({
			ev = "spawn",
			id = pl:EntIndex(),
			name = pl:Nick(),
			bot = (pl:IsBot() or pl.IsRelapseAIBot) and 1 or nil,
			team = TeamName(pl),
			role = Role(pl),
			p = vec(pl:GetPos()),
		})
	end)
end)

hook.Add("PlayerDisconnected", "RelapseAI.Rec", function(pl)
	local p = pending[pl]
	if p then
		pending[pl] = nil
		if p.frame then p.frame.left = 1 end
		local wrote, werr = pcall(WriteBug, p)
		if not wrote then Rec.Warn(werr) end
	end
	lastBits[pl] = nil
	lastText[pl] = nil
	cooldown[pl] = nil
end)

hook.Add("PlayerInitialSpawn", "RelapseAI.Rec", function(pl)
	timer.Simple(2, function()
		if IsValid(pl) and Rec.Armed then
			Rec.Broadcast()
		end
	end)
end)

hook.Add("ShutDown", "RelapseAI.Rec", function()
	if Rec.Recording then Rec.Stop() end
end)

net.Receive("RelapseAI.RecKey", function(_, pl)
	if not CanUse(pl) or not Rec.Armed then return end
	local now = CurTime()
	if now < (Rec.NextKey or 0) then return end
	Rec.NextKey = now + 0.2
	if Rec.Recording then
		Rec.Stop()
	else
		Rec.Start()
	end
end)

concommand.Add("relapse_ai_rec", function(pl)
	if not CanUse(pl) then
		Reply(pl, "[Relapse AI] запись недоступна")
		return
	end
	if Rec.Armed then
		if Rec.Recording then Rec.Stop() end
		Rec.Armed = false
		Rec.Broadcast()
		Reply(pl, "[Relapse AI] запись выключена")
		return
	end
	Rec.Armed = true
	Rec.Broadcast()
	Reply(pl, "[Relapse AI] запись включена. Сверху таймер. U — старт и стоп, кусок до 12 с, дальше новый файл. Пока таймер на экране, U не открывает командный чат. Файлы: data/relapse_ai/rec/")
end)

-- Loco:Note and Loco:OnPathResult call Rec.OnNote / Rec.OnPath directly (30_locomotion.lua).
