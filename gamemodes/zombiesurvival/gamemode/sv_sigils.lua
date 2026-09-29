function GM:PreOnSigilCorrupted(ent, dmginfo)
end

function GM:OnSigilCorrupted(ent, dmginfo)
	local attacker = dmginfo and dmginfo:GetAttacker()
	if attacker and attacker:IsValid() and attacker:IsPlayer() then
		attacker.SigilsCorrupted = (attacker.SigilsCorrupted or 0) + 1
	end

	net.Start("zs_sigilcorrupted")
		net.WriteUInt(self:NumCorruptedSigils(), 8)
		net.WriteEntity(ent)
	net.Broadcast()
end

function GM:PreOnSigilUncorrupted(ent, dmginfo)
end

function GM:OnSigilUncorrupted(ent, dmginfo)
	local attacker = dmginfo and dmginfo:GetAttacker()
	if attacker and attacker:IsValid() and attacker:IsPlayer() then
		attacker.SigilsRestored = (attacker.SigilsRestored or 0) + 1
	end

	net.Start("zs_sigiluncorrupted")
		net.WriteEntity(ent)
	net.Broadcast()
end

local function SortDistFromLast(a, b)
	return a.d < b.d
end

local validity_trace = {
	start = Vector(0, 0, 0), endpos = Vector(0, 0, 0), mins = Vector(-18, -18, 0), maxs = Vector(18, 18, 2), mask = MASK_SOLID_BRUSHONLY
}
function GM:CreateSigils(secondtry, rearrange)
	local alreadycreated = self:NumSigils()

	--if #self.ProfilerNodes < self.MaxSigils
	if self.ZombieEscape or self.ObjectiveMap
	or self:IsClassicMode() or self.PantsMode or self:IsBabyMode() then
		self:SetUseSigils(false)
		return
	end

	if alreadycreated >= self.MaxSigils and not rearrange then return end

	local nodes = {}

	-- Maybe the mapper made some!
	local vec
	local mapplacednodes = ents.FindByClass("info_sigilnode")
	if #mapplacednodes > 0 and not self.ProfilerIsPreMade then -- or maybe they're a twit
		for _, placednode in pairs(mapplacednodes) do
			nodes[#nodes + 1] = {v = placednode:GetPos(), en = placednode}
		end
	else
		-- Copy from profile
		for _, node in pairs(self.ProfilerNodes) do
			-- Check to see if this node is stuck in something.
			validity_trace.start:Set(node)
			validity_trace.start.z = node.z + 1
			validity_trace.endpos:Set(node)
			validity_trace.endpos.z = node.z + 73
			if util.TraceHull(validity_trace).Hit then
				print("bad sigil node at", node)
			else
				vec = Vector(0, 0, 0)
				vec:Set(node)
				nodes[#nodes + 1] = {v = vec}
			end
		end
	end

	--[[if secondtry then
		local needed = self.MaxSigils - #nodes - alreadycreated
		if needed > 0 then
			-- We seem to be missing some nodes...
			-- This might happen if nobody seeds the map and the round begins.
			for i = 1, needed do
				local spawns = team.GetSpawnPoint(TEAM_HUMAN)
				if #spawns > 0 then
					local spawnid = math.random(#spawns)
					local spawn = spawns[spawnid]

					nodes[#nodes + 1] = {v = spawn:GetPos()}
					spawn.Disabled = true
				end
			end
		end
	end]]

	local spawns = team.GetSpawnPoint(TEAM_UNDEAD)
	for i = 1 + (rearrange and 0 or alreadycreated), self.MaxSigils do
		local id
		local sigs = ents.FindByClass("prop_obj_sigil")
		local numsigs = #sigs
		if rearrange then
			for _, sig in pairs(sigs) do
				sig.NodePos = Vector(99999, 99999, 99999)
			end
		end

		local force
		for _, n in pairs(nodes) do
			if n.en and n.en.ForceSpawn then
				force = n
			end

			n.d = 999999

			if numsigs == 0 then
				for __, spawn in pairs(spawns) do
					n.d = math.min(n.d, n.v:Distance(spawn:GetPos()))
				end
			else
				for __, sig in pairs(sigs) do
					n.d = math.min(n.d, n.v:Distance(sig.NodePos))
				end
			end

			local tr = util.TraceLine({start = n.v + Vector(0, 0, 8), endpos = n.v + Vector(0, 0, 512), mask = MASK_SOLID_BRUSHONLY})
			n.d = n.d * (2 - tr.Fraction)
		end

		-- Sort the nodes by their distances.
		table.sort(nodes, SortDistFromLast)

		-- Now select a node using an exponential weight.
		-- We use a random float between 0 and 1 and use exponential on it.
		-- This way we're much more likely to get a lower index but a higher index is still possible.
		id = math.Rand(0, 0.7) ^ 0.3
		id = math.Clamp(math.ceil(id * #nodes), 1, #nodes)
		if force then
			id = table.KeyFromValue(nodes, force)
		end

		-- Remove the chosen point from the temp table and make the sigil.
		local node = nodes[id]
		if node then
			local point = node.v
			table.remove(nodes, id)

			local ent = rearrange and sigs[i] or ents.Create("prop_obj_sigil")
			if ent:IsValid() then
				ent:SetPos(point)
				if not rearrange then
					ent:Spawn()
				end
				ent.NodePos = point
			end
		end
	end

	self:SetUseSigils(self:NumSigils() > 0)
end

function GM:SetUseSigils(use)
	--if self:GetUseSigils() ~= use then
		self.UseSigils = use
		SetGlobalBool("sigils", use)
	--end
end

function GM:GetUseSigils(use)
	return self.UseSigils
end

util.AddNetworkString("zs_sigilspots")

local SigilSpotWatch = {}

local function SigilSpotReply(pl, msg)
	print(msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
		pl:ChatPrint(msg)
	end
end

local function CanSeeSigilSpots(pl)
	if not IsValid(pl) or pl:IsBot() then return false end
	if pl:IsSuperAdmin() then return true end
	local Mesh = RelapseAI and RelapseAI.Mesh
	return Mesh and Mesh.IsOwner and Mesh.IsOwner(pl) or false
end

function GM:CollectSigilSpots()
	local spots = {}
	local placed = ents.FindByClass("info_sigilnode")
	if #placed > 0 and not self.ProfilerIsPreMade then
		for _, ent in ipairs(placed) do
			if IsValid(ent) then
				spots[#spots + 1] = ent:GetPos()
			end
		end
		return spots
	end

	local indexed = {}
	for key, node in pairs(self.ProfilerNodes or {}) do
		if isvector(node) then
			indexed[#indexed + 1] = { key = tonumber(key) or 0, pos = Vector(node) }
		end
	end
	table.sort(indexed, function(a, b)
		return a.key < b.key
	end)
	for i = 1, #indexed do
		spots[i] = indexed[i].pos
	end
	return spots
end

local function SendSigilSpots(pl, show)
	local spots = show and GAMEMODE:CollectSigilSpots() or {}
	net.Start("zs_sigilspots")
		net.WriteBool(show)
		net.WriteUInt(#spots, 8)
		for i = 1, #spots do
			net.WriteVector(spots[i])
		end
	net.Send(pl)
	return #spots
end

local SigilRespawnPending = false

local function SigilListEmpty()
	for _, ent in pairs(ents.FindByClass("prop_obj_sigil")) do
		if IsValid(ent) then return false end
	end
	return true
end

local function PlaceFreshSigils(pl, tries)
	if not SigilListEmpty() then
		if tries < 8 then
			timer.Simple(0.05, function() PlaceFreshSigils(pl, tries + 1) end)
			return
		end
		SigilRespawnPending = false
		SigilSpotReply(IsValid(pl) and pl or nil, "Сигилы не встали.")
		return
	end

	gamemode.Call("CreateSigils")
	SigilRespawnPending = false
	SigilSpotReply(IsValid(pl) and pl or nil, string.format("Сигилы перемешаны: %d.", GAMEMODE:NumSigils()))
end

concommand.Add("relapse_sigils_respawn", function(pl)
	if not IsValid(pl) then
		print("relapse_sigils_respawn: из игровой консоли")
		return
	end
	if not CanSeeSigilSpots(pl) then return end
	if SigilRespawnPending then return end

	SigilRespawnPending = true
	for _, ent in pairs(ents.FindByClass("prop_obj_sigil")) do
		if IsValid(ent) then ent:Remove() end
	end
	timer.Simple(0.05, function() PlaceFreshSigils(pl, 1) end)
end)

concommand.Add("relapse_sigils", function(pl)
	if not IsValid(pl) then
		print("relapse_sigils: из игровой консоли")
		return
	end
	if not CanSeeSigilSpots(pl) then return end

	local show = not SigilSpotWatch[pl]
	SigilSpotWatch[pl] = show or nil
	local n = SendSigilSpots(pl, show)
	if show then
		SigilSpotReply(pl, string.format("Точки сигилов: %d. Ещё раз — скрыть.", n))
	else
		SigilSpotReply(pl, "Точки сигилов скрыты.")
	end
end)

hook.Add("PlayerDisconnected", "RelapseSigilSpots", function(pl)
	SigilSpotWatch[pl] = nil
end)

util.AddNetworkString("zs_sigildev")
util.AddNetworkString("zs_sigildev_set")
util.AddNetworkString("zs_sigildev_cam")

util.AddNetworkString("zs_sigildev_grab")

local function SendSigilDev(pl, on, ent, spot)
	net.Start("zs_sigildev")
		net.WriteBool(on and true or false)
		net.WriteEntity(IsValid(ent) and ent or NULL)
		net.WriteUInt(spot or 0, 8)
	net.Send(pl)
end

local function MoveSigilDev(ent, pos, yaw)
	if not IsValid(ent) or ent:GetClass() ~= "prop_obj_sigil" then return end

	pos = Vector(
		math.Clamp(pos.x, -16384, 16384),
		math.Clamp(pos.y, -16384, 16384),
		math.Clamp(pos.z, -16384, 16384)
	)
	local ang = Angle(0, math.NormalizeAngle(yaw), 0)

	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent.NodePos = Vector(pos)

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetPos(pos)
		phys:SetAngles(ang)
		phys:EnableMotion(false)
		phys:Wake()
	end

	for _, blocker in ipairs(ents.FindByClass("prop_prop_blocker")) do
		if blocker:GetOwner() == ent then
			blocker:SetPos(pos)
			blocker:SetAngles(ang)
			local bphys = blocker:GetPhysicsObject()
			if IsValid(bphys) then
				bphys:SetPos(pos)
				bphys:SetAngles(ang)
				bphys:EnableMotion(false)
			end
		end
	end
end

local function MoveSigilSpot(index, pos, yaw)
	pos = Vector(
		math.Clamp(pos.x, -16384, 16384),
		math.Clamp(pos.y, -16384, 16384),
		math.Clamp(pos.z, -16384, 16384)
	)
	local ang = Angle(0, math.NormalizeAngle(yaw or 0), 0)
	local placed = ents.FindByClass("info_sigilnode")
	if #placed > 0 and not GAMEMODE.ProfilerIsPreMade then
		local n = 0
		for _, ent in ipairs(placed) do
			if not IsValid(ent) then continue end
			n = n + 1
			if n == index then
				ent:SetPos(pos)
				ent:SetAngles(ang)
				return true
			end
		end
		return false
	end

	local indexed = {}
	for key, node in pairs(GAMEMODE.ProfilerNodes or {}) do
		if isvector(node) then
			indexed[#indexed + 1] = { key = key, n = tonumber(key) or 0 }
		end
	end
	table.sort(indexed, function(a, b)
		return a.n < b.n
	end)
	local row = indexed[index]
	if not row then return false end
	GAMEMODE.ProfilerNodes[row.key] = Vector(pos)
	return true
end

local function StopSigilDevCam(pl)
	if not IsValid(pl) then return end
	pl.RelapseSigilDevCam = nil
	pl.RelapseSigilDevEnt = nil
	pl.RelapseSigilDevSpot = nil
end

local function BeginSigilDevCam(pl)
	if not IsValid(pl) or not pl.RelapseSigilDev then return end
	if not pl:Alive() or pl:GetObserverMode() ~= OBS_MODE_NONE then return end

	if pl.RelapseFreecam then GAMEMODE:SetRelapseFreecam(pl, false) end
	if pl.RelapseNoclip or pl:GetMoveType() == MOVETYPE_NOCLIP then
		GAMEMODE:SetRelapseNoclip(pl, false)
	end
	if pl.RelapseWMPose then GAMEMODE:SetRelapseWMPose(pl, false) end
	pl.RelapseSigilDevCam = true
	return true
end

function GM:RelapseSigilDevGrab(pl, ent)
	if not IsValid(ent) or ent:GetClass() ~= "prop_obj_sigil" then return end
	if not BeginSigilDevCam(pl) then return end

	pl.RelapseSigilDevEnt = ent
	pl.RelapseSigilDevSpot = nil
	SendSigilDev(pl, true, ent, 0)
end

function GM:RelapseSigilDevGrabSpot(pl, index)
	local spots = self:CollectSigilSpots()
	if not spots[index] then return end
	if not BeginSigilDevCam(pl) then return end

	pl.RelapseSigilDevEnt = nil
	pl.RelapseSigilDevSpot = index
	SendSigilDev(pl, true, NULL, index)
end

local function ClearSigilDev(pl)
	if not IsValid(pl) or not pl.RelapseSigilDev then return end
	pl.RelapseSigilDev = nil
	StopSigilDevCam(pl)
	SendSigilDev(pl, false, NULL)
end

concommand.Add("relapse_sigils_dev", function(pl)
	if not IsValid(pl) then
		print("relapse_sigils_dev: из игровой консоли")
		return
	end
	if not CanSeeSigilSpots(pl) then return end

	if pl.RelapseSigilDev then
		ClearSigilDev(pl)
		SigilSpotReply(pl, "Редактор сигилов выключен.")
		return
	end

	pl.RelapseSigilDev = true
	SigilSpotWatch[pl] = true
	SendSigilSpots(pl, true)
	SendSigilDev(pl, true, NULL, 0)
	SigilSpotReply(pl, "Редактор сигилов. Использование на сигиле или точке включает полёт.")
end)

hook.Add("PlayerUse", "RelapseSigilDev", function(pl, ent)
	if not pl.RelapseSigilDev then return end
	if not IsValid(ent) or ent:GetClass() ~= "prop_obj_sigil" then return end
	GAMEMODE:RelapseSigilDevGrab(pl, ent)
	return false
end)

net.Receive("zs_sigildev_set", function(_, pl)
	if not pl.RelapseSigilDev or not pl.RelapseSigilDevCam then return end
	if (pl.RelapseSigilDevNext or 0) > CurTime() then return end
	pl.RelapseSigilDevNext = CurTime() + 0.03

	local ent = net.ReadEntity()
	local spot = net.ReadUInt(8)
	local pos = net.ReadVector()
	local yaw = net.ReadFloat()
	if IsValid(ent) and ent:GetClass() == "prop_obj_sigil" then
		pl.RelapseSigilDevEnt = ent
		pl.RelapseSigilDevSpot = nil
		MoveSigilDev(ent, pos, yaw)
		return
	end
	if spot < 1 or not MoveSigilSpot(spot, pos, yaw) then return end
	pl.RelapseSigilDevEnt = nil
	pl.RelapseSigilDevSpot = spot
end)

net.Receive("zs_sigildev_grab", function(_, pl)
	if not pl.RelapseSigilDev then return end
	GAMEMODE:RelapseSigilDevGrabSpot(pl, net.ReadUInt(8))
end)

net.Receive("zs_sigildev_cam", function(_, pl)
	if not pl.RelapseSigilDev then return end
	if net.ReadBool() then return end
	StopSigilDevCam(pl)
end)

hook.Add("StartCommand", "RelapseSigilDev", function(pl, cmd)
	if not pl.RelapseSigilDevCam then return end
	if not pl:Alive() or pl:GetObserverMode() ~= OBS_MODE_NONE then
		ClearSigilDev(pl)
		return
	end
	cmd:ClearMovement()
	cmd:SetButtons(bit.band(cmd:GetButtons(), IN_SCORE))
end)

hook.Add("PlayerDeath", "RelapseSigilDev", ClearSigilDev)
hook.Add("PlayerSpawn", "RelapseSigilDev", ClearSigilDev)
hook.Add("PlayerSilentDeath", "RelapseSigilDev", ClearSigilDev)
hook.Add("PlayerDisconnected", "RelapseSigilDev", ClearSigilDev)
