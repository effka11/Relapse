-- Default overlay range. Stock D3bot uses 0 = entire map.

local function applyDraw()
	RunConsoleCommand("d3bot_navmeshing_drawdistance", "1024")
end

hook.Add("InitPostEntity", "RelapseD3bot.DrawDist", applyDraw)
timer.Simple(0, applyDraw)

timer.Simple(0, function()
	if not D3bot or not D3bot.SetIsMapNavMeshViewEnabled or D3bot.RelapseDrawDistWrapped then return end
	D3bot.RelapseDrawDistWrapped = true
	local old = D3bot.SetIsMapNavMeshViewEnabled
	function D3bot.SetIsMapNavMeshViewEnabled(bool)
		if bool then applyDraw() end
		return old(bool)
	end
end)
