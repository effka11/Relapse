-- Relapse cosmetic inventory: playermodels, later avatars. Marks are the
-- cosmetic wallet; they persist here, not in the round vault.
-- Server owns the list; cl_playermodel is not trusted. Workshop addons still
-- supply mdl/vtf.
--
-- Default = starter Survivor: granted to everyone, cannot be taken, and
-- first join rolls one from this pool (saved, never re-rolled). Expand the
-- pool by adding another model with Default = true.

GM.RelapseCosmeticKind = {
	MODEL = "model"
}

GM.RelapseCosmeticOrder = {
	"undercover_spetsnaz",
	"tropa_z",
	"tropa_z2",
	"wuchang",
	"bunker_soldier1",
	"bunker_soldier2",
	"bunker_soldier3",
	"bunker_soldier4",
	"balkan",
	"park_coventry",
	"backstabber_susie",
	"navy_seals_sniper",
	"alex",
	"kgb_unit",
	"russian_j12"
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
	tropa_z = {
		Kind = "model",
		Name = "Survivor",
		Model = "models/humangrunt/maxpayne3/tropa_z_pm.mdl",
		PlayerManager = "Tropa Z",
		Hands = "models/humangrunt/maxpayne3/c_arms_comandosombra.mdl",
		HandsBody = "00000000",
		Workshop = { "2929135394" },
		Default = true
	},
	tropa_z2 = {
		Kind = "model",
		Name = "Survivor",
		Model = "models/humangrunt/maxpayne3/tropa_z2_pm.mdl",
		PlayerManager = "Tropa Z 2",
		Hands = "models/humangrunt/maxpayne3/c_arms_comandosombra.mdl",
		HandsBody = "00000000",
		Workshop = { "2929135394" },
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
	},
	bunker_soldier1 = {
		Kind = "model",
		Name = "Bunker Soldier 1",
		Model = "models/bunker/playermodels/bunker_soldier1.mdl",
		PlayerManager = "Bunker Soldier 1",
		Hands = "models/weapons/c_arms_cstrike.mdl",
		HandsSkin = 0,
		HandsBody = "10000000",
		Workshop = { "3642088520" },
		Marks = 11990
	},
	bunker_soldier2 = {
		Kind = "model",
		Name = "Bunker Soldier 2",
		Model = "models/bunker/playermodels/bunker_soldier2.mdl",
		PlayerManager = "Bunker Soldier 2",
		Hands = "models/weapons/c_arms_cstrike.mdl",
		HandsSkin = 0,
		HandsBody = "10000000",
		Workshop = { "3642088520" },
		Marks = 11990
	},
	bunker_soldier3 = {
		Kind = "model",
		Name = "Bunker Soldier 3",
		Model = "models/bunker/playermodels/bunker_soldier3.mdl",
		PlayerManager = "Bunker Soldier 3",
		Hands = "models/weapons/c_arms_cstrike.mdl",
		HandsSkin = 0,
		HandsBody = "10000000",
		Workshop = { "3642088520" },
		Marks = 11990
	},
	bunker_soldier4 = {
		Kind = "model",
		Name = "Bunker Soldier 4",
		Model = "models/bunker/playermodels/bunker_soldier4.mdl",
		PlayerManager = "Bunker Soldier 4",
		Hands = "models/weapons/c_arms_cstrike.mdl",
		HandsSkin = 0,
		HandsBody = "10000000",
		Workshop = { "3642088520" },
		Marks = 11990
	},
	balkan = {
		Kind = "model",
		Name = "Balkan",
		Model = "models/munch/balkandude.mdl",
		PlayerManager = "Balkan",
		Hands = "models/munch/balkanvm.mdl",
		HandsBody = "00000000",
		Workshop = { "3641416752" },
		Marks = 23990
	},
	park_coventry = {
		Kind = "model",
		Name = "Helen Park",
		Model = "models/kyo/parkcoventry_PM.mdl",
		PlayerManager = "Cold War - Park (Coventry)",
		Hands = "models/kyo/parkcoventry_Arms.mdl",
		HandsBody = "00000000",
		Workshop = { "3713771232" },
		Female = true,
		VoiceSet = VOICESET_FEMALE,
		Marks = 47990
	},
	backstabber_susie = {
		Kind = "model",
		Name = "Susie",
		Model = "models/player/dbdbackstabbersusie.mdl",
		PlayerManager = "Backstabber Susie (Dead by Daylight)",
		Hands = "models/player/dbdbackstabbersusiearms.mdl",
		HandsBody = "00000000",
		Workshop = { "3747373360" },
		Female = true,
		VoiceSet = VOICESET_FEMALE,
		Marks = 45990
	},
	navy_seals_sniper = {
		Kind = "model",
		Name = "Navy SEALs Sniper",
		Model = "models/humangrunt/mw2/navyseals_sniper_pm.mdl",
		PlayerManager = "Navy SEALs Sniper",
		Hands = "models/humangrunt/mw2/c_arms_seals.mdl",
		HandsBody = "00000000",
		Workshop = { "2893907662" },
		Marks = 13990
	},
	alex = {
		Kind = "model",
		Name = "Alex",
		Model = "models/konni/asapgaming/modernwarfare/alex.mdl",
		PlayerManager = "Alex",
		Hands = "models/weapons/arms/v_arms_mw_alex.mdl",
		HandsBody = "00000000",
		Workshop = { "2317864856" },
		Marks = 45990
	},
	kgb_unit = {
		Kind = "model",
		Name = "KGB Unit",
		Model = "models/arty/mgsdelta/kgb unit/grunt_pm.mdl",
		PlayerManager = "KGB Unit",
		Hands = "models/arty/mgsdelta/kgb unit/grunt_vm.mdl",
		HandsBody = "00",
		Workshop = { "3572296525" },
		Marks = 17990
	},
	russian_j12 = {
		Kind = "model",
		Name = "Russian J-12",
		Model = "models/jq/codmw2019/russian_j-12_player.mdl",
		PlayerManager = "Russian J-12",
		Hands = "models/jq/codmw2019/c_russian_j-12_hands.mdl",
		HandsBody = "00000000",
		Workshop = { "3627414330" },
		Marks = 34990
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

-- MW default rig is chands: the gun copies zs_hands. Prefer the equipped
-- cosmetic's c_arms over player_manager lookup (path/case misses).
function GM:GetRelapseHandsInfo(pl)
	local id
	if SERVER then
		if isfunction(self.GetRelapseEquippedModelId) and IsValid(pl) then
			id = self:GetRelapseEquippedModelId(pl)
		end
	elseif isfunction(self.GetRelapseEquippedModelId) then
		id = self:GetRelapseEquippedModelId()
	end
	if not id then
		id = self:GetRelapseDefaultModelId()
	end
	local item = self:GetRelapseCosmetic(id)
	if not (item and item.Hands) then
		return
	end
	return {
		model = item.Hands,
		skin = item.HandsSkin or 0,
		body = item.HandsBody or "00000000"
	}
end

function GM:GetRelapseSurvivorPool()
	local pool = {}
	for _, id in ipairs(self.RelapseCosmeticOrder) do
		local item = self.RelapseCosmetics[id]
		if item and item.Kind == self.RelapseCosmeticKind.MODEL and item.Default then
			pool[#pool + 1] = id
		end
	end
	return pool
end

function GM:PickRelapseSurvivorModel()
	local pool = self:GetRelapseSurvivorPool()
	if #pool == 0 then
		return self.RelapseCosmeticOrder[1]
	end
	return pool[math.random(#pool)]
end

function GM:GetRelapseDefaultModelId()
	local pool = self:GetRelapseSurvivorPool()
	return pool[1] or self.RelapseCosmeticOrder[1]
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

---------------------------------------------------------------------------
-- Marks
--
-- Cosmetic wallet. Remort drop is a curve, not math.random(min, max):
--   u ~ U(0,1), t = u^2, marks = round(min + (max - min) t)
-- Square piles mass on 100. A line would use t = u (flat chance).
---------------------------------------------------------------------------

GM.RelapseMarksMin = 100
GM.RelapseMarksMax = 3000
GM.RelapseMarksPower = 2

function GM:ClampRelapseMarks(n)
	return math.max(0, math.floor(tonumber(n) or 0))
end

function GM:RollRelapseMarks()
	local u = math.Rand(0, 1)
	local t = u ^ self.RelapseMarksPower
	local marks = self.RelapseMarksMin + (self.RelapseMarksMax - self.RelapseMarksMin) * t
	return math.Clamp(math.floor(marks + 0.5), self.RelapseMarksMin, self.RelapseMarksMax)
end

function GM:GetRelapseMarks(pl)
	if SERVER then
		if not (IsValid(pl) and pl.RelapseInv) then return 0 end
		return pl.RelapseInv.marks or 0
	end
	return self.RelapseInvMarks or 0
end

function GM:RelapseCosmeticMarks(id)
	local item = self:GetRelapseCosmetic(id)
	if not item then return 0 end
	return math.max(0, math.floor(tonumber(item.Marks) or 0))
end

function GM:RelapseCosmeticForSale(id)
	return self:RelapseCosmeticMarks(id) > 0
end
