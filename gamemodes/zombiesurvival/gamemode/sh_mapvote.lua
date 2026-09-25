-- Next-map vote. The ballot is at most five maps, shuffled from the pool.
-- GM.MapVotePool, when filled, is the pool. Empty means the mapcycle
-- (if it lists at least two maps) or the installed zs_ / ze_ / zm_ maps.
-- MinPlayers / MaxPlayers are read when set. Nothing sets them yet.

GM.MapVoteSlots = 5

GM.MapVotePool = {
	-- { Map = "zs_oxygen_b4", MinPlayers = 4, MaxPlayers = 16 },
}

GM.MapVoteRules = {
	-- ["zs_oxygen_b4"] = { MinPlayers = 4, MaxPlayers = 16 },
}

function GM:MapVoteContext()
	local players = 0
	if player.GetCount then
		players = player.GetCount()
	else
		players = #player.GetAll()
	end
	return {
		Players = players,
		Map = string.lower(game.GetMap() or "")
	}
end

function GM:MapVoteAllows(entry, ctx)
	if not entry or not entry.Map or entry.Map == "" then return false end
	ctx = ctx or self:MapVoteContext()

	local rules = self.MapVoteRules and self.MapVoteRules[string.lower(entry.Map)]
	local minp = entry.MinPlayers
	local maxp = entry.MaxPlayers
	if rules then
		if minp == nil then minp = rules.MinPlayers end
		if maxp == nil then maxp = rules.MaxPlayers end
	end

	local players = ctx.Players or 0
	if minp and players < minp then return false end
	if maxp and players > maxp then return false end
	return true
end

function GM:MapVoteLabel(map)
	if not map or map == "" then return "" end
	local key = "map_" .. string.lower(map)
	if CLIENT and RelapseUI and RelapseUI.T then
		local name = RelapseUI.T(key, "")
		if name ~= "" then return name end
	end
	return string.gsub(map, "_", " ")
end
