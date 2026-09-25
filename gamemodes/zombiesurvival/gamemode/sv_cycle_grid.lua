util.AddNetworkString("zs_cycle_grid_sync")
util.AddNetworkString("zs_cycle_grid_unlock")
util.AddNetworkString("zs_cycle_grid_mute")

local function CatalogIds(set)
	local ids = {}
	if not set then
		return ids
	end
	for id in pairs(set) do
		if GAMEMODE.CycleGridCatalog[id] then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	return ids
end

local function MuteKeys(gm, set)
	local keys = {}
	if not set then
		return keys
	end
	for key in pairs(set) do
		local treeId, slot = string.match(key, "^([%w_]+):(%d+)$")
		slot = tonumber(slot)
		if treeId and slot and gm:GetCycleGridNode(treeId, slot) then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	return keys
end

function GM:WriteCycleGridVault(pl, tosave)
	if not IsValid(pl) or not tosave then
		return
	end
	self:InitCycleGrid(pl)
	tosave.CycleGrid = CatalogIds(pl.CycleGridTaken)
	local mutes = MuteKeys(self, pl.CycleGridMute)
	if #mutes > 0 then
		tosave.CycleGridMute = mutes
	end
	tosave.CycleGridLive = CatalogIds(pl.CycleGridLive)
	local liveMutes = MuteKeys(self, pl.CycleGridLiveMute)
	if #liveMutes > 0 then
		tosave.CycleGridLiveMute = liveMutes
	end
	tosave.CycleGridMap = pl.CycleGridMap or game.GetMap()
end

function GM:ReadCycleGridVault(pl, contents)
	if not IsValid(pl) then
		return
	end
	self:InitCycleGrid(pl, true)
	if contents and istable(contents.CycleGrid) then
		for i = 1, #contents.CycleGrid do
			local id = contents.CycleGrid[i]
			if self.CycleGridCatalog[id] then
				pl.CycleGridTaken[id] = true
			end
		end
	end
	if contents and istable(contents.CycleGridMute) then
		for i = 1, #contents.CycleGridMute do
			local key = contents.CycleGridMute[i]
			if isstring(key) then
				local treeId, slot = string.match(key, "^([%w_]+):(%d+)$")
				slot = tonumber(slot)
				if treeId and slot and self:GetCycleGridNode(treeId, slot) then
					pl.CycleGridMute[self:CycleGridMuteKey(treeId, slot)] = true
				end
			end
		end
	end
	local sameMap = contents and contents.CycleGridMap == game.GetMap()
	if contents and istable(contents.CycleGridLive) and sameMap then
		for i = 1, #contents.CycleGridLive do
			local id = contents.CycleGridLive[i]
			if self.CycleGridCatalog[id] then
				pl.CycleGridLive[id] = true
			end
		end
		if istable(contents.CycleGridLiveMute) then
			for i = 1, #contents.CycleGridLiveMute do
				local key = contents.CycleGridLiveMute[i]
				if isstring(key) then
					local treeId, slot = string.match(key, "^([%w_]+):(%d+)$")
					slot = tonumber(slot)
					if treeId and slot and self:GetCycleGridNode(treeId, slot) then
						pl.CycleGridLiveMute[self:CycleGridMuteKey(treeId, slot)] = true
					end
				end
			end
		end
		pl.CycleGridMap = game.GetMap()
	else
		self:CycleGridCommitLive(pl)
	end
end

function GM:SendCycleGrid(pl)
	if not IsValid(pl) then
		return
	end
	self:InitCycleGrid(pl)
	local function writeIds(set)
		local ids = CatalogIds(set)
		net.WriteUInt(math.min(#ids, 255), 8)
		for i = 1, math.min(#ids, 255) do
			net.WriteString(ids[i])
		end
	end
	local function writeMutes(set)
		local keys = MuteKeys(self, set)
		net.WriteUInt(math.min(#keys, 255), 8)
		for i = 1, math.min(#keys, 255) do
			local treeId, slot = string.match(keys[i], "^([%w_]+):(%d+)$")
			net.WriteString(treeId or "")
			net.WriteUInt(tonumber(slot) or 0, 5)
		end
	end
	net.Start("zs_cycle_grid_sync")
	writeIds(pl.CycleGridTaken)
	writeMutes(pl.CycleGridMute)
	writeIds(pl.CycleGridLive)
	writeMutes(pl.CycleGridLiveMute)
	net.Send(pl)
end

function GM:ClearCycleGrid(pl)
	if not IsValid(pl) then
		return
	end
	self:InitCycleGrid(pl, true)
	self:SendCycleGrid(pl)
	self:SaveVault(pl)
end

function GM:UnlockCycleGrid(pl, treeId, slot)
	if not IsValid(pl) then
		return false
	end
	local skill = self:GetCycleGridSkill(treeId, slot)
	if not skill then
		return false
	end
	if self:HasCycleGridSkill(pl, skill.id) then
		return false
	end
	if self:CycleGridNodeMuted(pl, self:GetCycleGridNode(treeId, slot)) then
		return false
	end
	if not self:CycleGridNeighborOk(pl, treeId, slot) then
		return false
	end
	if self:GetCycleGridSPRemaining(pl) < 1 then
		pl:CenterNotify(COLOR_RED, translate.ClientGet(pl, "grid_skill_need_sp"))
		return false
	end

	self:InitCycleGrid(pl)
	pl.CycleGridTaken[skill.id] = true
	self:SendCycleGrid(pl)
	self:SaveVault(pl)

	local name = translate.ClientGet(pl, skill.nameKey)
	pl:CenterNotify(COLOR_GREEN, translate.ClientFormat(pl, "grid_skill_unlocked", name))
	pl:PrintMessage(HUD_PRINTTALK, translate.ClientFormat(pl, "grid_skill_unlocked", name))
	return true
end

function GM:ToggleCycleGridMute(pl, treeId, slot)
	if not IsValid(pl) then
		return false
	end
	local node = self:GetCycleGridNode(treeId, slot)
	if not node or node.tree == nil then
		return false
	end
	self:InitCycleGrid(pl)
	if self:CycleGridMutedByAncestor(pl, node) then
		return false
	end
	local key = self:CycleGridMuteKey(treeId, slot)
	if pl.CycleGridMute[key] then
		pl.CycleGridMute[key] = nil
	else
		local skill = self:GetCycleGridSkill(treeId, slot)
		if not skill or not self:HasCycleGridSkill(pl, skill.id) then
			return false
		end
		pl.CycleGridMute[key] = true
		self:CycleGridClearMuteUnder(pl, node)
	end
	self:SendCycleGrid(pl)
	self:SaveVault(pl)
	return true
end

net.Receive("zs_cycle_grid_unlock", function(_, pl)
	if not IsValid(pl) then
		return
	end
	local treeId = net.ReadString()
	local slot = net.ReadUInt(5)
	if #treeId > 32 then
		return
	end
	GAMEMODE:UnlockCycleGrid(pl, treeId, slot)
end)

net.Receive("zs_cycle_grid_mute", function(_, pl)
	if not IsValid(pl) then
		return
	end
	local treeId = net.ReadString()
	local slot = net.ReadUInt(5)
	if #treeId > 32 then
		return
	end
	GAMEMODE:ToggleCycleGridMute(pl, treeId, slot)
end)
