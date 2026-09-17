GM.RelapseInvOwned = {}
GM.RelapseInvModel = nil
GM.RelapseInvMarks = 0

function GM:PlayerOwnsRelapseItem(id)
	return self.RelapseInvOwned[id] and true or false
end

function GM:GetRelapseEquippedModelId()
	local id = self.RelapseInvModel
	if id and self.RelapseInvOwned[id] and self:GetRelapseCosmetic(id) then
		return id
	end
	return self:GetRelapseDefaultModelId()
end

net.Receive("relapse_inv_sync", function()
	local owned = {}
	local n = net.ReadUInt(8)
	for _ = 1, n do
		owned[net.ReadString()] = true
	end
	GAMEMODE.RelapseInvOwned = owned
	GAMEMODE.RelapseInvModel = net.ReadString()
	GAMEMODE.RelapseInvMarks = net.ReadUInt(32)
	if GAMEMODE.RefreshRelapseInventory then
		GAMEMODE:RefreshRelapseInventory()
	end
end)
