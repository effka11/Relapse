util.AddNetworkString("zs_mapvote")
util.AddNetworkString("zs_mapvote_cast")
util.AddNetworkString("zs_mapvote_uncast")
util.AddNetworkString("zs_mapvote_open")
util.AddNetworkString("zs_mapvote_dev")

local function TrimMap(name)
	name = string.lower(string.Trim(tostring(name or "")))
	name = string.gsub(name, "%.bsp$", "")
	return name
end

function GM:AddMapVoteCandidate(list, seen, entry)
	if isstring(entry) then
		entry = { Map = entry }
	end
	if not entry then return end
	local name = TrimMap(entry.Map)
	if name == "" or seen[name] then return end
	if not file.Exists("maps/" .. name .. ".bsp", "GAME") then return end
	seen[name] = true
	list[#list + 1] = {
		Map = name,
		MinPlayers = entry.MinPlayers,
		MaxPlayers = entry.MaxPlayers
	}
end

function GM:ReadMapCycle()
	local cv = GetConVar("mapcyclefile")
	local path = cv and cv:GetString() or ""
	if path == "" or not file.Exists(path, "GAME") then return {} end
	local body = file.Read(path, "GAME")
	if not body or body == "" then return {} end

	local names = {}
	for line in string.gmatch(body, "[^\r\n]+") do
		local trimmed = string.Trim(line)
		if trimmed ~= "" and string.sub(trimmed, 1, 2) ~= "//" and string.sub(trimmed, 1, 1) ~= "#" then
			local name = string.match(trimmed, "^([%w_%-]+)")
			if name then
				names[#names + 1] = name
			end
		end
	end
	return names
end

function GM:CollectMapVotePool()
	local list, seen = {}, {}
	local curated = self.MapVotePool
	if istable(curated) and curated[1] ~= nil then
		for _, entry in ipairs(curated) do
			self:AddMapVoteCandidate(list, seen, entry)
		end
		return list
	end

	local cycle = self:ReadMapCycle()
	if #cycle >= 2 then
		for _, name in ipairs(cycle) do
			self:AddMapVoteCandidate(list, seen, name)
		end
		return list
	end

	for _, pattern in ipairs({ "maps/zs_*.bsp", "maps/ze_*.bsp", "maps/zm_*.bsp" }) do
		local files = file.Find(pattern, "GAME")
		for _, fn in ipairs(files or {}) do
			self:AddMapVoteCandidate(list, seen, fn)
		end
	end
	return list
end

function GM:PickMapVoteBallot()
	local ctx = self:MapVoteContext()
	local pool = self:CollectMapVotePool()
	local allowed = {}
	for _, entry in ipairs(pool) do
		if entry.Map ~= ctx.Map and self:MapVoteAllows(entry, ctx) then
			allowed[#allowed + 1] = entry.Map
		end
	end
	if #allowed == 0 then
		for _, entry in ipairs(pool) do
			if self:MapVoteAllows(entry, ctx) then
				allowed[#allowed + 1] = entry.Map
			end
		end
	end

	for i = #allowed, 2, -1 do
		local j = math.random(i)
		allowed[i], allowed[j] = allowed[j], allowed[i]
	end

	local slots = math.min(5, math.max(1, self.MapVoteSlots or 5))
	local ballot = {}
	for i = 1, math.min(slots, #allowed) do
		ballot[i] = allowed[i]
	end
	return ballot
end

function GM:MapVoteSecondsLeft()
	if not self.RoundEnded or not self.RoundEndedTime then return -1 end
	return math.max(0, (self.RoundEndedTime + (self.EndGameTime or 0)) - CurTime())
end

function GM:SendMapVote(target, force)
	local vote = self.MapVote
	if not vote then return end
	if not target then
		for _, pl in ipairs(player.GetAll()) do
			self:SendMapVote(pl, force)
		end
		return
	end
	if not IsValid(target) then return end

	self:PadMapVoteSlots(vote)
	net.Start("zs_mapvote")
		net.WriteUInt(#vote.Maps, 3)
		for _, name in ipairs(vote.Maps) do
			net.WriteString(name)
		end
		for i = 1, #vote.Maps do
			net.WriteUInt(math.min(vote.Counts[i] or 0, 65535), 16)
		end
		net.WriteUInt(vote.ByID[target:SteamID()] or 0, 3)
		self:WriteMapVoteFaces(vote)
		net.WriteFloat(self:MapVoteSecondsLeft())
		net.WriteBool(force and true or false)
	net.Send(target)
end

function GM:EnsureMapVoteFaces(vote)
	if not vote then return end
	if not vote.BySlot then
		vote.BySlot = {}
		for i = 1, #vote.Maps do
			vote.BySlot[i] = {}
		end
		for id, slot in pairs(vote.ByID or {}) do
			local list = vote.BySlot[slot]
			if list then
				list[#list + 1] = id
			end
		end
		return
	end
	for i = 1, #vote.Maps do
		vote.BySlot[i] = vote.BySlot[i] or {}
	end
end

function GM:PullMapVoteFace(vote, id)
	if not vote or not vote.BySlot or not id or id == "" then return end
	for i = 1, #vote.BySlot do
		local list = vote.BySlot[i]
		if list then
			for k = #list, 1, -1 do
				if list[k] == id then
					table.remove(list, k)
				end
			end
		end
	end
end

function GM:WriteMapVoteFaces(vote)
	self:EnsureMapVoteFaces(vote)
	for i = 1, #vote.Maps do
		local list = vote.BySlot[i] or {}
		local n = math.min(7, #list)
		net.WriteUInt(n, 3)
		for k = 1, n do
			local pl = player.GetBySteamID(list[k])
			net.WriteUInt((IsValid(pl) and pl:EntIndex()) or 0, 8)
		end
	end
end

function GM:MapVoteDevOn(pl)
	if not IsValid(pl) or not self.MapVoteDev then return false end
	return self.MapVoteDev[pl:SteamID()] and true or false
end

function GM:EnableMapVoteDev(pl)
	if not IsValid(pl) then return end
	local id = pl:SteamID()
	if id == "" then return end
	self.MapVoteDev = self.MapVoteDev or {}
	self.MapVoteDev[id] = true
	pl:PrintMessage(HUD_PRINTTALK, "Голоса без лимита включены.")
end

function GM:PadMapVoteSlots(vote)
	if not vote then return end
	self:EnsureMapVoteFaces(vote)
	local slots = math.min(5, math.max(1, self.MapVoteSlots or 5))
	vote.Maps = vote.Maps or {}
	vote.Counts = vote.Counts or {}
	for i = 1, slots do
		if vote.Maps[i] == nil then
			vote.Maps[i] = ""
		end
		if vote.Counts[i] == nil then
			vote.Counts[i] = 0
		end
		vote.BySlot[i] = vote.BySlot[i] or {}
	end
end

function GM:RecountMapVote()
	local vote = self.MapVote
	if not vote then return end
	self:PadMapVoteSlots(vote)
	for i = 1, #vote.Maps do
		vote.Counts[i] = #(vote.BySlot[i] or {})
	end
end

function GM:OpenMapVote(force)
	if self.MapVoteFinished then return end
	if not self.MapVote then
		local maps = self:PickMapVoteBallot()
		local counts = {}
		for i = 1, #maps do
			counts[i] = 0
		end
		local bySlot = {}
		for i = 1, #maps do
			bySlot[i] = {}
		end
		self.MapVote = {
			Maps = maps,
			Counts = counts,
			ByID = {},
			BySlot = bySlot
		}
	end
	self:PadMapVoteSlots(self.MapVote)
	self:SendMapVote(nil, force)
end

function GM:CastMapVote(pl, slot)
	local vote = self.MapVote
	if not vote or not IsValid(pl) then return end
	self:PadMapVoteSlots(vote)
	slot = math.floor(tonumber(slot) or 0)
	if slot < 1 or slot > #vote.Maps then return end
	local id = pl:SteamID()
	if id == "" then return end
	self:EnsureMapVoteFaces(vote)
	if not self:MapVoteDevOn(pl) then
		if vote.ByID[id] == slot then return end
		self:PullMapVoteFace(vote, id)
	end
	vote.ByID[id] = slot
	local list = vote.BySlot[slot]
	if list then
		table.insert(list, 1, id)
	end
	self:RecountMapVote()
	self:SendMapVote()
end

function GM:DropMapVote(pl, slot)
	local vote = self.MapVote
	if not vote or not IsValid(pl) then return end
	self:PadMapVoteSlots(vote)
	slot = math.floor(tonumber(slot) or 0)
	if slot < 1 or slot > #vote.Maps then return end
	local id = pl:SteamID()
	if id == "" then return end
	local list = vote.BySlot[slot]
	if not list then return end
	local removed = false
	for k = 1, #list do
		if list[k] == id then
			table.remove(list, k)
			removed = true
			break
		end
	end
	if not removed then return end
	if vote.ByID[id] == slot then
		local left = nil
		for i = 1, #vote.BySlot do
			for _, sid in ipairs(vote.BySlot[i]) do
				if sid == id then
					left = i
					break
				end
			end
			if left then break end
		end
		vote.ByID[id] = left
	end
	self:RecountMapVote()
	self:SendMapVote()
end

function GM:MapVoteWinner()
	local vote = self.MapVote
	if not vote or #vote.Maps == 0 then return end
	local best, tied = -1, {}
	for i, name in ipairs(vote.Maps) do
		if not name or name == "" then continue end
		local n = vote.Counts[i] or 0
		if n > best then
			best = n
			tied = { name }
		elseif n == best then
			tied[#tied + 1] = name
		end
	end
	if #tied == 0 then return end
	return tied[math.random(#tied)]
end

function GM:FinishMapVote()
	if self.MapVoteFinished then return end
	self.MapVoteFinished = true

	local map = self:MapVoteWinner()
	local from = string.lower(game.GetMap() or "")
	self.MapVote = nil

	if not map or map == "" then
		self:LoadNextMap()
		return
	end

	RunConsoleCommand("changelevel", map)
	timer.Simple(12, function()
		if string.lower(game.GetMap() or "") ~= from then return end
		if GAMEMODE and GAMEMODE.LoadNextMap then
			GAMEMODE:LoadNextMap()
		end
	end)
end

net.Receive("zs_mapvote_cast", function(_, pl)
	GAMEMODE:CastMapVote(pl, net.ReadUInt(3))
end)

net.Receive("zs_mapvote_uncast", function(_, pl)
	GAMEMODE:DropMapVote(pl, net.ReadUInt(3))
end)

net.Receive("zs_mapvote_open", function(_, pl)
	if not IsValid(pl) then return end
	GAMEMODE:OpenMapVote(true)
end)

net.Receive("zs_mapvote_dev", function(_, pl)
	GAMEMODE:EnableMapVoteDev(pl)
end)

concommand.Add("relapse_votemap", function()
	GAMEMODE:OpenMapVote(true)
end)

concommand.Add("relapse_votemap_dev", function(pl)
	GAMEMODE:EnableMapVoteDev(pl)
end)

hook.Add("PlayerDisconnected", "RelapseMapVote", function(pl)
	local vote = GAMEMODE.MapVote
	if not vote or not IsValid(pl) then return end
	local id = pl:SteamID()
	if not vote.ByID[id] then return end
	self:PullMapVoteFace(vote, id)
	vote.ByID[id] = nil
	GAMEMODE:RecountMapVote()
	GAMEMODE:SendMapVote()
end)
