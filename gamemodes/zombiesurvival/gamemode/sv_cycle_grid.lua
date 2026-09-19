util.AddNetworkString("zs_cycle_grid_sync")
util.AddNetworkString("zs_cycle_grid_unlock")

function GM:WriteCycleGridVault(pl, tosave)
	if not IsValid(pl) or not tosave then
		return
	end
	self:InitCycleGrid(pl)
	local ids = {}
	for id in pairs(pl.CycleGridTaken) do
		if self.CycleGridCatalog[id] then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	tosave.CycleGrid = ids
end

function GM:ReadCycleGridVault(pl, contents)
	if not IsValid(pl) then
		return
	end
	self:InitCycleGrid(pl, true)
	if not contents or not istable(contents.CycleGrid) then
		return
	end
	for i = 1, #contents.CycleGrid do
		local id = contents.CycleGrid[i]
		if self.CycleGridCatalog[id] then
			pl.CycleGridTaken[id] = true
		end
	end
end

function GM:SendCycleGrid(pl)
	if not IsValid(pl) then
		return
	end
	self:InitCycleGrid(pl)
	local ids = {}
	for id in pairs(pl.CycleGridTaken) do
		if self.CycleGridCatalog[id] then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	net.Start("zs_cycle_grid_sync")
	net.WriteUInt(math.min(#ids, 255), 8)
	for i = 1, math.min(#ids, 255) do
		net.WriteString(ids[i])
	end
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

	if pl:Alive() and pl:Team() == TEAM_HUMAN then
		pl:ApplySkills()
	end

	local name = translate.ClientGet(pl, skill.nameKey)
	pl:CenterNotify(COLOR_GREEN, translate.ClientFormat(pl, "grid_skill_unlocked", name))
	pl:PrintMessage(HUD_PRINTTALK, translate.ClientFormat(pl, "grid_skill_unlocked", name))
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
