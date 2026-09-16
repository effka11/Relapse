-- Relapse cosmetic inventory: playermodels, later avatars. Server owns the
-- list; cl_playermodel is not trusted. Workshop addons still supply mdl/vtf.

GM.RelapseCosmeticKind = {
	MODEL = "model"
}

GM.RelapseCosmeticOrder = {
	"undercover_spetsnaz",
	"wuchang"
}

GM.RelapseCosmetics = {
	undercover_spetsnaz = {
		Kind = "model",
		Name = "Survivor",
		Model = "models/humangrunt/bo1/undercoverspetsnaz_pm.mdl",
		PlayerManager = "Undercover Spetsnaz",
		Hands = "models/humangrunt/bo1/c_arms_undercoverspetsnaz.mdl",
		HandsBody = "00000000",
		Workshop = { "2904144632" },
		Default = true
	},
	wuchang = {
		Kind = "model",
		Name = "Bai Wuchang",
		Model = "models/alvaroports/WuchangPM.mdl",
		PlayerManager = "Wuchang - Wuchang Fallen Feathers",
		Hands = "models/alvaroports/WuchangVM.mdl",
		HandsBody = "0000000",
		Workshop = { "3486238431", "3571846979" },
		Female = true,
		VoiceSet = VOICESET_FEMALE
	}
}

-- SteamID / SteamID64 -> extra item ids. Merged on join, does not revoke.
GM.RelapseInventoryPlayerGrants = {
	["STEAM_0:0:454712632"] = { "wuchang" }, -- effka
	["76561198869690992"] = { "wuchang" }
}

function GM:RegisterRelapseCosmeticModels()
	for _, item in pairs(self.RelapseCosmetics) do
		if item.Kind == self.RelapseCosmeticKind.MODEL and item.PlayerManager and item.Model then
			player_manager.AddValidModel(item.PlayerManager, item.Model)
			if item.Hands then
				player_manager.AddValidHands(item.PlayerManager, item.Hands, item.HandsSkin or 0, item.HandsBody or "00000000")
			end
		end
	end
end

GM:RegisterRelapseCosmeticModels()

function GM:GetRelapseCosmetic(id)
	return id and self.RelapseCosmetics[id] or nil
end

function GM:GetRelapseDefaultModelId()
	for _, id in ipairs(self.RelapseCosmeticOrder) do
		local item = self.RelapseCosmetics[id]
		if item and item.Kind == self.RelapseCosmeticKind.MODEL and item.Default then
			return id
		end
	end
	return self.RelapseCosmeticOrder[1]
end

function GM:RelapseCosmeticName(id)
	local item = self:GetRelapseCosmetic(id)
	if not item then return id or "" end
	if CLIENT and RelapseUI and RelapseUI.T then
		return RelapseUI.T("inv_item_" .. id, item.Name)
	end
	return item.Name
end

function GM:RelapseCosmeticDesc(id)
	local item = self:GetRelapseCosmetic(id)
	if not item then return "" end
	if CLIENT and RelapseUI and RelapseUI.T then
		return RelapseUI.T("inv_item_" .. id .. "_desc", item.Description or "")
	end
	return item.Description or ""
end
