-- Relapse glue for D3bot: quota, one-shot mesh from Source .nav + BSP ladders.
-- Stock convert: node at area center, link every Source neighbor, Jumping if |dz|>58.
-- Ladders: AABB center top/bottom + Path=Ladder. Manual edits after that.

if engine.ActiveGamemode() ~= "zombiesurvival" then return end
if not D3bot then
	ErrorNoHalt("[Relapse D3bot] addon d3bot is missing. Clone https://github.com/Dadido3/D3bot into garrysmod/addons/d3bot\n")
	return
end

print("[Relapse D3bot] glue loaded (D3bot spawn is off; live zombies are Relapse AI)")

-- Relapse AI owns the zombie quota. Keep every D3bot spawn term at 0.
D3bot.ZombiesPerPlayer = 0
D3bot.ZombiesPerPlayerWave = 0
D3bot.ZombiesPerWave = 0
D3bot.ZombiesPerMinute = 0
D3bot.ZombiesCountAddition = 0
D3bot.SurvivorsEnabled = false
D3bot.RelapseDisabled = true
D3bot.IsEnabledCached = false

-- Mesh BotMod / NodeZombiesCountAddition would still spawn if we only zeroed the formula terms.
if not D3bot.RelapseDesiredWrapped then
	D3bot.RelapseDesiredWrapped = true
	local oldDesired = D3bot.GetDesiredBotCount
	function D3bot.GetDesiredBotCount()
		if D3bot.RelapseDisabled then
			return 0, 0, game.MaxPlayers() - 2
		end
		if oldDesired then return oldDesired() end
		return 0, 0, game.MaxPlayers() - 2
	end
end

local function round(n)
	return math.Round(n * 10) / 10
end

local function setPos(node, pos)
	node:SetParam("X", round(pos.x))
	node:SetParam("Y", round(pos.y))
	node:SetParam("Z", round(pos.z))
end

local function entityKey(block, key)
	return tonumber(string.match(block, '"' .. key .. '" "([^"]+)"'))
end

local function entityVec(block, key)
	local x, y, z = string.match(block, '"' .. key .. '" "([^%s"]+)%s+([^%s"]+)%s+([^%s"]+)"')
	if x then return tonumber(x), tonumber(y), tonumber(z) end
end

local function pushBox(boxes, seen, x0, y0, z0, x1, y1, z1)
	if not (x0 and y0 and z0 and x1 and y1 and z1) then return end
	local mins = Vector(math.min(x0, x1), math.min(y0, y1), math.min(z0, z1))
	local maxs = Vector(math.max(x0, x1), math.max(y0, y1), math.max(z0, z1))
	if maxs.z - mins.z < 40 then return end
	local key = string.format("%.0f_%.0f_%.0f_%.0f_%.0f_%.0f", mins.x, mins.y, mins.z, maxs.x, maxs.y, maxs.z)
	if seen[key] then return end
	seen[key] = true
	boxes[#boxes + 1] = {mins = mins, maxs = maxs}
end

local function pushLadderBox(boxes, seen, ox, oy, oz, x0, y0, z0, x1, y1, z1)
	if not (x0 and y0 and z0 and x1 and y1 and z1) then return end
	if ox then
		local cx, cy, cz = (x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5
		local dx, dy, dz = cx - ox, cy - oy, cz - oz
		if dx * dx + dy * dy + dz * dz > 64 * 64 then
			x0, y0, z0 = x0 + ox, y0 + oy, z0 + oz
			x1, y1, z1 = x1 + ox, y1 + oy, z1 + oz
		end
	end
	pushBox(boxes, seen, x0, y0, z0, x1, y1, z1)
end

local function loadLadderBoxes()
	local boxes, seen = {}, {}
	local f = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME")
	if not f then return boxes end
	f:Seek(8)
	local ofs, len = f:ReadLong(), f:ReadLong()
	local data
	if ofs and len and ofs > 0 and len > 0 and len < 64 * 1024 * 1024 then
		f:Seek(ofs)
		data = f:Read(len)
	end
	f:Close()
	if not data then return boxes end

	for block in string.gmatch(data, "{(.-)}") do
		if string.find(block, '"classname" "info_ladder"', 1, true)
		or string.find(block, '"classname" "func_ladder"', 1, true) then
			local ox, oy, oz = entityVec(block, "origin")
			local x0, y0, z0 = entityKey(block, "mins%.x"), entityKey(block, "mins%.y"), entityKey(block, "mins%.z")
			local x1, y1, z1 = entityKey(block, "maxs%.x"), entityKey(block, "maxs%.y"), entityKey(block, "maxs%.z")
			if not x0 then x0, y0, z0 = entityVec(block, "mins") end
			if not x1 then x1, y1, z1 = entityVec(block, "maxs") end
			pushLadderBox(boxes, seen, ox, oy, oz, x0, y0, z0, x1, y1, z1)
		elseif string.find(block, '"classname" "func_useableladder"', 1, true) then
			local x0, y0, z0 = entityVec(block, "point0")
			local x1, y1, z1 = entityVec(block, "point1")
			if x0 and x1 then
				pushBox(boxes, seen, x0 - 16, y0 - 16, z0, x1 + 16, y1 + 16, z1)
			end
		end
	end
	return boxes
end

local function nearestFloorNode(mesh, pos, skip, maxXY)
	local best, bestD2
	local max2 = maxXY * maxXY
	for _, node in pairs(mesh.NodeById) do
		if not skip[node] and node.Pos then
			local dz = math.abs(node.Pos.z - pos.z)
			if dz <= 56 then
				local dx, dy = node.Pos.x - pos.x, node.Pos.y - pos.y
				local d2 = dx * dx + dy * dy
				if d2 <= max2 and (not best or d2 < bestD2) then
					best, bestD2 = node, d2
				end
			end
		end
	end
	return best
end

local function addLadders(mesh)
	local boxes = loadLadderBoxes()
	local n, wired = 0, 0
	for _, box in ipairs(boxes) do
		local mins, maxs = box.mins, box.maxs
		local cx = (mins.x + maxs.x) * 0.5
		local cy = (mins.y + maxs.y) * 0.5
		local bottom = Vector(cx, cy, mins.z + 8)
		local top = Vector(cx, cy, maxs.z - 8)
		local skip = {}

		local botNode = mesh:NewNode()
		setPos(botNode, bottom)
		botNode:SetParam("AimTo", "Straight")
		botNode:SetParam("AreaXMin", round(math.min(mins.x, maxs.x)))
		botNode:SetParam("AreaXMax", round(math.max(mins.x, maxs.x)))
		botNode:SetParam("AreaYMin", round(math.min(mins.y, maxs.y)))
		botNode:SetParam("AreaYMax", round(math.max(mins.y, maxs.y)))
		skip[botNode] = true

		local topNode = mesh:NewNode()
		setPos(topNode, top)
		topNode:SetParam("AimTo", "Straight")
		topNode:SetParam("Climbing", "Needed")
		topNode:SetParam("AreaXMin", round(math.min(mins.x, maxs.x)))
		topNode:SetParam("AreaXMax", round(math.max(mins.x, maxs.x)))
		topNode:SetParam("AreaYMin", round(math.min(mins.y, maxs.y)))
		topNode:SetParam("AreaYMax", round(math.max(mins.y, maxs.y)))
		skip[topNode] = true

		local link = mesh:ForceGetLink(botNode, topNode)
		if link then
			link:SetParam("Path", "Ladder")
		end

		local floorBot = nearestFloorNode(mesh, bottom, skip, 220) or nearestFloorNode(mesh, bottom, skip, 400)
		if floorBot then
			mesh:ForceGetLink(botNode, floorBot)
			wired = wired + 1
		end
		local floorTop = nearestFloorNode(mesh, top, skip, 220) or nearestFloorNode(mesh, top, skip, 400)
		if floorTop then
			mesh:ForceGetLink(topNode, floorTop)
			wired = wired + 1
		end

		n = n + 1
	end
	return n, wired
end

local function convertSourceNav()
	local mesh = D3bot.NewNavMesh()
	local byArea = {}
	local areas = navmesh.GetAllNavAreas()
	for _, area in ipairs(areas) do
		local node = mesh:NewNode()
		setPos(node, area:GetCenter())
		local xmin, xmax, ymin, ymax = math.huge, -math.huge, math.huge, -math.huge
		for i = 0, 3 do
			local p = area:GetCorner(i)
			if p.x < xmin then xmin = p.x end
			if p.x > xmax then xmax = p.x end
			if p.y < ymin then ymin = p.y end
			if p.y > ymax then ymax = p.y end
		end
		node:SetParam("AreaXMin", round(xmin))
		node:SetParam("AreaXMax", round(xmax))
		node:SetParam("AreaYMin", round(ymin))
		node:SetParam("AreaYMax", round(ymax))
		byArea[area:GetID()] = node
	end

	local links = 0
	for _, area in ipairs(areas) do
		local node = byArea[area:GetID()]
		if node then
			for _, neighbor in ipairs(area:GetAdjacentAreas()) do
				local other = byArea[neighbor:GetID()]
				if other then
					local link = mesh:ForceGetLink(node, other)
					if link then
						links = links + 1
						if math.abs(node.Pos.z - other.Pos.z) > 58 then
							link:SetParam("Jumping", "Needed")
						end
					end
				end
			end
		end
	end

	return mesh, #areas, links
end

local function meshPath()
	return "d3bot/navmesh/map/" .. game.GetMap() .. ".txt"
end

local function finishAndReload(mesh, areas, links)
	D3bot.MapNavMesh = mesh
	local shafts, wired = addLadders(mesh)
	mesh:InvalidateCache()
	D3bot.SaveMapNavMesh()
	if not file.Exists(meshPath(), "DATA") then
		print("[Relapse D3bot] save failed: data/" .. meshPath())
		return
	end
	print(string.format(
		"[Relapse D3bot] saved %s (%d nodes, %d walk links, %d ladder shafts, %d floor ties). Reloading so D3bot uses D3botNav.",
		meshPath(), areas + shafts * 2, links, shafts, wired
	))
	timer.Simple(2, function()
		RunConsoleCommand("changelevel", game.GetMap())
	end)
end

local function buildMesh(force)
	hook.Remove("Think", "ConverterCoroutineStep")
	D3bot.StartedConversion = false

	if not navmesh.IsLoaded() then
		navmesh.Load()
	end
	if not navmesh.IsLoaded() then
		print("[Relapse D3bot] no Source .nav for " .. game.GetMap() .. " — run nav_generate / nav_build.bat first")
		return
	end
	if not force and file.Exists(meshPath(), "DATA") then
		print("[Relapse D3bot] mesh already exists: data/" .. meshPath() .. " — relapse_d3bot_rebuild to regenerate (stock converter)")
		return
	end
	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then
		print("[Relapse D3bot] Source navmesh has 0 areas")
		return
	end

	print("[Relapse D3bot] converting Source navmesh + BSP ladders for " .. game.GetMap() .. " (" .. #areas .. " areas, stock converter) ...")
	local ok, meshOrErr, nAreas, nLinks = pcall(convertSourceNav)
	if not ok then
		ErrorNoHalt("[Relapse D3bot] convert failed: " .. tostring(meshOrErr) .. "\n")
		return
	end
	print(string.format("[Relapse D3bot] nodes %d, walk links %d", nAreas, nLinks))
	local okFinish, err = pcall(finishAndReload, meshOrErr, nAreas, nLinks)
	if not okFinish then
		ErrorNoHalt("[Relapse D3bot] save/ladder pass failed: " .. tostring(err) .. "\n")
	end
end

-- Mesh/rebuild rights by SteamID. Never SetUserGroup — superadmin breaks ZS play.
local OWNERS = {
	["STEAM_0:0:454712632"] = true,
	["76561198869690992"] = true,
}

local function isOwner(pl)
	if not IsValid(pl) then return true end
	if pl:IsBot() then return false end
	local sid = pl:SteamID()
	local sid64 = pl.SteamID64 and pl:SteamID64()
	return OWNERS[sid] or (sid64 and OWNERS[tostring(sid64)]) or false
end

concommand.Add("relapse_d3bot_rebuild", function(pl)
	if IsValid(pl) and not isOwner(pl) then return end
	buildMesh(true)
end)

-- Do not auto-convert Source .nav while Relapse AI is the live bot AI.
hook.Add("InitPostEntity", "RelapseD3bot.BuildMesh", function()
	if D3bot.RelapseDisabled then return end
	timer.Simple(3, function()
		if D3bot.RelapseDisabled then return end
		buildMesh(false)
	end)
end)

---------------------------------------------------------------------------
-- Hunt: D3bot default is 500u LOS steal + table.Random(humans + sigils + crates).
-- After two sigils fall they lock onto a crate/turret and never notice the last
-- sigil or a player on another floor. Relapse AI always knew every human.
---------------------------------------------------------------------------

local FALLBACK_ENTS = {"prop_*turret", "prop_arsenalcrate", "prop_manhack*"}

local function isLivingHuman(bot, target)
	return IsValid(target) and target:IsPlayer() and target ~= bot
		and target:Team() ~= TEAM_UNDEAD
		and target:GetObserverMode() == OBS_MODE_NONE
		and not target:IsFlagSet(FL_NOTARGET)
		and target:Alive()
end

local function nearestOf(bot, list)
	local pos = bot:GetPos()
	local best, bestD
	for _, ent in ipairs(list) do
		if IsValid(ent) then
			local d = pos:DistToSqr(ent:GetPos())
			if not best or d < bestD then
				best, bestD = ent, d
			end
		end
	end
	return best
end

local function collectHumans(bot)
	local t = {}
	for _, pl in ipairs(player.GetAll()) do
		if isLivingHuman(bot, pl) then
			t[#t + 1] = pl
		end
	end
	return t
end

local function collectSigils()
	if GAMEMODE and GAMEMODE.GetUncorruptedSigils then
		return GAMEMODE:GetUncorruptedSigils() or {}
	end
	local t = {}
	for _, e in ipairs(ents.FindByClass("prop_obj_sigil")) do
		if IsValid(e) and e.GetSigilCorrupted and not e:GetSigilCorrupted() then
			t[#t + 1] = e
		end
	end
	return t
end

local function pickHuntTarget(bot)
	local human = nearestOf(bot, collectHumans(bot))
	if human then return human end
	local sigil = nearestOf(bot, collectSigils())
	if sigil then return sigil end
	return nearestOf(bot, D3bot.GetEntsOfClss(FALLBACK_ENTS) or {})
end

local function patchUndeadHandler(handler)
	if not handler then return end
	handler.RelapseOldThink = handler.RelapseOldThink or handler.ThinkFunction

	function handler.CanBeTgt(bot, target)
		if not isLivingHuman(bot, target) then
			if not IsValid(target) then return false end
			if target:GetClass() == "prop_obj_sigil" then
				return not (target.GetSigilCorrupted and target:GetSigilCorrupted())
			end
			return false
		end
		return true
	end

	function handler.RerollTarget(bot)
		bot:D3bot_SetTgtOrNil(pickHuntTarget(bot), false, nil)
	end

	local oldThink = handler.RelapseOldThink
	function handler.ThinkFunction(bot)
		local mem = bot.D3bot_Mem
		if mem and (not mem.RelapseHuntAt or mem.RelapseHuntAt < CurTime()) then
			mem.RelapseHuntAt = CurTime() + 1.25
			local tgt = pickHuntTarget(bot)
			local cur = mem.TgtOrNil
			local locked = IsValid(cur) and cur:IsPlayer() and cur:Team() ~= TEAM_UNDEAD
				and bot:GetPos():DistToSqr(cur:GetPos()) <= (handler.BotTgtFixationDistMin or 250) ^ 2
			if tgt and not locked and tgt ~= cur then
				bot:D3bot_SetTgtOrNil(tgt, false, nil)
			end
		end
		if oldThink then return oldThink(bot) end
	end
	handler.RelapseHuntPatched = true
end

local function patchHunt()
	for name, handler in pairs(D3bot.Handlers or {}) do
		if istable(handler) and (name == "Undead_Fallback" or name == "Undead_Headcrab" or string.find(name, "Undead", 1, true)) then
			if handler.RerollTarget then
				patchUndeadHandler(handler)
			end
		end
	end
	if D3bot.Handlers and D3bot.Handlers.Undead_Fallback and D3bot.Handlers.Undead_Fallback.RelapseHuntPatched then
		print("[Relapse D3bot] hunt: map-wide humans, then nearest uncorrupted sigil (no 500u sight cap)")
	end
end

patchHunt()
hook.Add("InitPostEntity", "RelapseD3bot.Hunt", patchHunt)

---------------------------------------------------------------------------
-- Mesh edit must not KillSilent a human: ZS treats that as a real death
-- (DelayedChangeToZombie + PreviouslyDied) and they spawn undead next join.
-- D3bot's spawnAsTeam stamp is a local in supervisor.lua; if it leaks, the
-- next PlayerInitialSpawn (a reconnecting human) is marked PreviouslyDied.
---------------------------------------------------------------------------

if not D3bot.RelapseNoSpecKill then
	D3bot.RelapseNoSpecKill = true
	local oldSetSub = D3bot.SetMapNavMeshUiSubscription
	function D3bot.SetMapNavMeshUiSubscription(pl, subscriptionTypeOrNil, isSpectator)
		if isSpectator and IsValid(pl) and not pl:IsBot() then
			isSpectator = false
		end
		if oldSetSub then
			oldSetSub(pl, subscriptionTypeOrNil, isSpectator)
		end
		if not IsValid(pl) then return end
		if subscriptionTypeOrNil == "edit" then
			pl:AddFlags(FL_NOTARGET)
			if GAMEMODE and GAMEMODE.SetRelapseNoclip then
				GAMEMODE:SetRelapseNoclip(pl, true)
			end
		elseif subscriptionTypeOrNil == nil then
			pl:RemoveFlags(FL_NOTARGET)
			if GAMEMODE and GAMEMODE.SetRelapseNoclip then
				GAMEMODE:SetRelapseNoclip(pl, false)
			end
		end
	end
end

if not D3bot.RelapseBotSpawnHookPatched then
	D3bot.RelapseBotSpawnHookPatched = true
	local hooks = hook.GetTable().PlayerInitialSpawn
	local old = hooks and hooks[D3bot.BotHooksId]
	if old then
		hook.Add("PlayerInitialSpawn", D3bot.BotHooksId, function(pl)
			if IsValid(pl) and not pl:IsBot() then return end
			return old(pl)
		end)
	end
end

-- Strip usergroup if users.txt / an old glue pass still assigned superadmin.
-- PlayerAuthSpawn from users.txt runs on InitialSpawn; demote on the next tick.
hook.Remove("PlayerAuthed", "RelapseD3bot.Owner")
hook.Remove("PlayerInitialSpawn", "RelapseD3bot.Owner")

local function playAsUser(pl)
	if not isOwner(pl) then return end
	if D3bot.SetMapNavMeshUiSubscription then
		D3bot.SetMapNavMeshUiSubscription(pl, nil)
	end
	if pl:GetUserGroup() ~= "user" then
		pl:SetUserGroup("user")
		print("[Relapse D3bot] group=user for " .. tostring(pl:SteamID()) .. " (play as a normal player)")
	end
end

hook.Add("PlayerAuthed", "RelapseD3bot.PlayAsUser", function(pl)
	timer.Simple(0, function() playAsUser(pl) end)
end)
hook.Add("PlayerInitialSpawn", "RelapseD3bot.PlayAsUser", function(pl)
	timer.Simple(0, function() playAsUser(pl) end)
end)
for _, pl in ipairs(player.GetHumans()) do
	playAsUser(pl)
end

local function reply(pl, msg)
	print(msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
		pl:ChatPrint(msg)
	end
end

local function applyParam(pl, item, name, value)
	if not item then
		reply(pl, "[Relapse D3bot] no node/link")
		return
	end
	item:SetParam(name, value or "")
	D3bot.lastParamKey = name
	D3bot.lastParamValue = value or ""
	D3bot.MapNavMesh:InvalidateCache()
	D3bot.UpdateMapNavMeshUiSubscribers()
	reply(pl, string.format("[Relapse D3bot] %s  %s = %s", tostring(item.Id), name, value == "" and "(cleared)" or tostring(value)))
end

concommand.Add("relapse_d3bot_viewmesh", function(pl)
	if not isOwner(pl) then
		reply(pl, "[Relapse D3bot] denied (group=" .. (IsValid(pl) and pl:GetUserGroup() or "?") .. ")")
		return
	end
	if not IsValid(pl) then
		print("relapse_d3bot_viewmesh: run from the game console, not srcds")
		return
	end
	D3bot.SetMapNavMeshUiSubscription(pl, "view")
	pl:ConCommand("d3bot_navmeshing_smartdraw 0")
	pl:ConCommand("d3bot_navmeshing_drawdistance 1024")
	pl:ConCommand("d3bot_navmeshing_enabled 1")
	reply(pl, "[Relapse D3bot] overlay on (~1024u). relapse_d3bot_hidemesh to hide.")
end)

concommand.Add("relapse_d3bot_editmesh", function(pl)
	if not isOwner(pl) then
		reply(pl, "[Relapse D3bot] denied")
		return
	end
	if not IsValid(pl) then
		print("relapse_d3bot_editmesh: run from the game console, not srcds")
		return
	end
	D3bot.SetMapNavMeshUiSubscription(pl, nil)
	D3bot.SetMapNavMeshUiSubscription(pl, "edit")
	pl:ConCommand("d3bot_navmeshing_smartdraw 0")
	pl:ConCommand("d3bot_navmeshing_drawdistance 1024")
	pl:ConCommand("d3bot_navmeshing_enabled 1")
	reply(pl, "[Relapse D3bot] EDIT + noclip (~1024u). R cycles mode, 1–8 jump. Aim at the pad or beam. relapse_d3bot_savemesh when done.")
end)

concommand.Add("relapse_d3bot_savemesh", function(pl)
	if not isOwner(pl) then
		reply(pl, "[Relapse D3bot] denied")
		return
	end
	D3bot.MapNavMesh:InvalidateCache()
	D3bot.SaveMapNavMesh()
	reply(pl, "[Relapse D3bot] saved data/d3bot/navmesh/map/" .. game.GetMap() .. ".txt")
end)

concommand.Add("relapse_d3bot_hidemesh", function(pl)
	if not isOwner(pl) then
		reply(pl, "[Relapse D3bot] denied")
		return
	end
	if not IsValid(pl) then return end
	D3bot.SetMapNavMeshUiSubscription(pl, nil)
	reply(pl, "[Relapse D3bot] mesh overlay off")
end)

concommand.Add("relapse_d3bot_setparam", function(pl, _, args)
	if IsValid(pl) and not isOwner(pl) then
		reply(pl, "[Relapse D3bot] denied")
		return
	end
	local id, name, value = args[1], args[2], args[3] or ""
	if not id or not name then
		reply(pl, "usage: relapse_d3bot_setparam <id> <name> [value]   e.g. 12-34 Path Ladder")
		return
	end
	local item = D3bot.MapNavMesh.ItemById[D3bot.DeserializeNavMeshItemId(id)]
	applyParam(pl, item, name, value)
end)

concommand.Add("relapse_d3bot_sethovered", function(pl, _, args)
	if not isOwner(pl) then
		reply(pl, "[Relapse D3bot] denied")
		return
	end
	if not IsValid(pl) then
		print("relapse_d3bot_sethovered: look at a node/link in-game")
		return
	end
	local name, value = args[1], args[2] or ""
	if not name then
		reply(pl, "usage: relapse_d3bot_sethovered <name> [value]   look at the item first")
		return
	end
	applyParam(pl, D3bot.MapNavMesh:GetCursoredItemOrNil(pl), name, value)
end)

concommand.Add("relapse_d3bot_status", function(pl)
	if not isOwner(pl) then
		reply(pl, "[Relapse D3bot] denied (group=" .. (IsValid(pl) and pl:GetUserGroup() or "?") .. ")")
		return
	end
	local nodes = D3bot.MapNavMesh and table.Count(D3bot.MapNavMesh.NodeById) or 0
	local links = D3bot.MapNavMesh and table.Count(D3bot.MapNavMesh.LinkById) or 0
	local path = "d3bot/navmesh/map/" .. game.GetMap() .. ".txt"
	reply(pl, string.format("[Relapse D3bot] type=%s UsingSourceNav=%s nodes=%d links=%d file=%s exists=%s group=%s",
		tostring(D3bot.DesiredNavmeshTypeCached),
		tostring(D3bot.UsingSourceNav),
		nodes, links, path, tostring(file.Exists(path, "DATA")),
		IsValid(pl) and pl:GetUserGroup() or "console"))
end)
