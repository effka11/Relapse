-- Relapse cosmetic inventory. Persist per SteamID64. Grants merge on join.

util.AddNetworkString("relapse_inv_sync")
util.AddNetworkString("relapse_inv_equip")

GM.RelapseInvFolder = "relapse_inv"

local INV_OWNERS = {
	["STEAM_0:0:454712632"] = true,
	["76561198869690992"] = true
}

local function CanManageInventory(pl)
	if not IsValid(pl) then return true end
	if pl:IsBot() then return false end
	local sid = pl:SteamID()
	local sid64 = pl.SteamID64 and pl:SteamID64()
	return INV_OWNERS[sid] or (sid64 and INV_OWNERS[tostring(sid64)]) or false
end

local function SeenWorkshop()
	return {}
end

local function AddCosmeticWorkshops()
	local gm = GM or GAMEMODE
	local cosmetics = gm and gm.RelapseCosmetics
	if not cosmetics then return end

	local seen = SeenWorkshop()
	for _, item in pairs(cosmetics) do
		if istable(item.Workshop) then
			for _, wid in ipairs(item.Workshop) do
				if wid and not seen[wid] then
					seen[wid] = true
					resource.AddWorkshop(wid)
				end
			end
		end
	end
end

-- Do not index GAMEMODE while init.lua is still including files.
hook.Add("Initialize", "RelapseInvWorkshops", AddCosmeticWorkshops)

function GM:GetRelapseInventoryFile(sid64)
	sid64 = tostring(sid64 or "invalid")
	return self.RelapseInvFolder .. "/" .. sid64:sub(-2) .. "/" .. sid64 .. ".txt"
end

function GM:EmptyRelapseInventory()
	return {
		items = {},
		model = self:GetRelapseDefaultModelId()
	}
end

function GM:SanitizeRelapseInventory(data)
	local clean = self:EmptyRelapseInventory()
	if not istable(data) then
		return clean
	end
	if istable(data.items) then
		for id, owned in pairs(data.items) do
			if owned and self:GetRelapseCosmetic(id) then
				clean.items[id] = true
			end
		end
	end
	if isstring(data.model) and clean.items[data.model] then
		clean.model = data.model
	end
	return clean
end

function GM:PlayerOwnsRelapseItem(pl, id)
	return IsValid(pl) and pl.RelapseInv and pl.RelapseInv.items and pl.RelapseInv.items[id] and true or false
end

function GM:GetRelapseEquippedModelId(pl)
	local fallback = self:GetRelapseDefaultModelId()
	if not IsValid(pl) or not pl.RelapseInv then
		return fallback
	end
	local id = pl.RelapseInv.model
	if self:PlayerOwnsRelapseItem(pl, id) and self:GetRelapseCosmetic(id) then
		return id
	end
	return fallback
end

function GM:GetRelapseEquippedModelItem(pl)
	return self:GetRelapseCosmetic(self:GetRelapseEquippedModelId(pl))
end

function GM:LoadRelapseInventory(pl)
	if not IsValid(pl) or pl:IsBot() then
		pl.RelapseInv = self:EmptyRelapseInventory()
		return
	end

	local sid64 = pl:SteamID64()
	if not sid64 then
		pl.RelapseInv = self:EmptyRelapseInventory()
		return
	end

	local filename = self:GetRelapseInventoryFile(sid64)
	if file.Exists(filename, "DATA") then
		local contents = file.Read(filename, "DATA")
		if contents and #contents > 0 then
			local ok, data = pcall(Deserialize, contents)
			if ok then
				pl.RelapseInv = self:SanitizeRelapseInventory(data)
				return
			end
		end
	end

	pl.RelapseInv = self:EmptyRelapseInventory()
end

function GM:SaveRelapseInventory(pl)
	if not IsValid(pl) or pl:IsBot() or not pl.RelapseInv then return end
	local sid64 = pl:SteamID64()
	if not sid64 then return end

	local filename = self:GetRelapseInventoryFile(sid64)
	file.CreateDir(string.GetPathFromFilename(filename))
	file.Write(filename, Serialize({
		items = pl.RelapseInv.items,
		model = pl.RelapseInv.model
	}))
end

function GM:GiveRelapseItem(pl, id)
	if not IsValid(pl) or not self:GetRelapseCosmetic(id) then
		return false
	end
	if not pl.RelapseInv then
		self:LoadRelapseInventory(pl)
	end
	if pl.RelapseInv.items[id] then
		return false
	end
	pl.RelapseInv.items[id] = true
	return true
end

function GM:TakeRelapseItem(pl, id)
	if not self:PlayerOwnsRelapseItem(pl, id) then
		return false
	end
	local item = self:GetRelapseCosmetic(id)
	if item and item.Default then
		return false
	end
	pl.RelapseInv.items[id] = nil
	if pl.RelapseInv.model == id then
		pl.RelapseInv.model = self:GetRelapseDefaultModelId()
	end
	return true
end

function GM:GrantRelapseInventoryDefaults(pl)
	if not IsValid(pl) then return end
	self:EnsureRelapseInventory(pl, true)

	local dirty = false
	for _, id in ipairs(self.RelapseCosmeticOrder) do
		local item = self.RelapseCosmetics[id]
		if item and item.Default and self:GiveRelapseItem(pl, id) then
			dirty = true
		end
	end

	if not pl:IsBot() then
		local extra = self.RelapseInventoryPlayerGrants[pl:SteamID()]
			or self.RelapseInventoryPlayerGrants[tostring(pl:SteamID64() or "")]
		if extra then
			for _, id in ipairs(extra) do
				if self:GiveRelapseItem(pl, id) then
					dirty = true
				end
			end
		end
	end

	if not self:PlayerOwnsRelapseItem(pl, pl.RelapseInv.model) then
		pl.RelapseInv.model = self:GetRelapseDefaultModelId()
		dirty = true
	end

	if dirty then
		self:SaveRelapseInventory(pl)
	end
end

function GM:EnsureRelapseInventory(pl, skipGrant)
	if not IsValid(pl) then return end
	if not pl.RelapseInv then
		self:LoadRelapseInventory(pl)
	end
	if not skipGrant then
		self:GrantRelapseInventoryDefaults(pl)
	end
end

function GM:SyncRelapseInventory(pl)
	if not IsValid(pl) or pl:IsBot() then return end
	self:EnsureRelapseInventory(pl)

	local ids = {}
	for id in pairs(pl.RelapseInv.items) do
		ids[#ids + 1] = id
	end

	net.Start("relapse_inv_sync")
		net.WriteUInt(#ids, 8)
		for i = 1, #ids do
			net.WriteString(ids[i])
		end
		net.WriteString(self:GetRelapseEquippedModelId(pl) or "")
	net.Send(pl)
end

function GM:RefreshHumanHands(pl)
	if not IsValid(pl) or pl:Team() ~= TEAM_HUMAN then return end

	local oldhands = pl:GetHands()
	if IsValid(oldhands) then
		oldhands:Remove()
	end

	local hands = ents.Create("zs_hands")
	if hands:IsValid() then
		hands:DoSetup(pl)
		hands:Spawn()
	end
end

function GM:ApplyRelapsePlayermodel(pl, refreshHands)
	if not IsValid(pl) then return end
	self:EnsureRelapseInventory(pl)

	local item = self:GetRelapseEquippedModelItem(pl)
	if not item or not item.Model then return end

	local modelname = item.Model
	local lowermodelname = string.lower(modelname)
	util.PrecacheModel(modelname)
	pl:SetModel(modelname)

	if item.Skin then
		pl:SetSkin(item.Skin)
	end
	if istable(item.BodyGroups) then
		for bg, val in pairs(item.BodyGroups) do
			pl:SetBodygroup(bg, val)
		end
	end

	if pl:Team() ~= TEAM_HUMAN then return end

	if item.VoiceSet then
		pl:SetDTInt(DT_PLAYER_INT_VOICESET, item.VoiceSet)
	elseif item.Female or string.find(lowermodelname, "female", 1, true) then
		pl:SetDTInt(DT_PLAYER_INT_VOICESET, VOICESET_FEMALE)
	else
		pl:SetDTInt(DT_PLAYER_INT_VOICESET, VOICESET_MALE)
	end

	if item.PlayerManager then
		pl:ConCommand('cl_playermodel "' .. item.PlayerManager .. '"')
	end

	if refreshHands then
		self:RefreshHumanHands(pl)
	end
end

function GM:EquipRelapseModel(pl, id)
	if not IsValid(pl) then return false end
	self:EnsureRelapseInventory(pl)

	local item = self:GetRelapseCosmetic(id)
	if not item or item.Kind ~= self.RelapseCosmeticKind.MODEL then
		return false
	end
	if not self:PlayerOwnsRelapseItem(pl, id) then
		return false
	end

	pl.RelapseInv.model = id
	self:SaveRelapseInventory(pl)

	if pl:Team() == TEAM_HUMAN and pl:Alive() then
		self:ApplyRelapsePlayermodel(pl, true)
	end

	self:SyncRelapseInventory(pl)
	return true
end

local function WriteOfflineInventory(gm, sid64, mutator)
	local filename = gm:GetRelapseInventoryFile(sid64)
	local data = gm:EmptyRelapseInventory()
	if file.Exists(filename, "DATA") then
		local contents = file.Read(filename, "DATA")
		if contents and #contents > 0 then
			local ok, parsed = pcall(Deserialize, contents)
			if ok then
				data = gm:SanitizeRelapseInventory(parsed)
			end
		end
	end
	mutator(data)
	if not data.items[data.model] then
		data.model = gm:GetRelapseDefaultModelId()
	end
	file.CreateDir(string.GetPathFromFilename(filename))
	file.Write(filename, Serialize(data))
end

local function FindPlayerByArg(arg)
	if not arg or arg == "" then return nil end
	if string.sub(arg, 1, 1) == "#" then
		local ply = Player(tonumber(string.sub(arg, 2)) or -1)
		if IsValid(ply) then return ply end
	end
	for _, pl in ipairs(player.GetAll()) do
		if pl:SteamID() == arg or tostring(pl:SteamID64() or "") == arg or string.lower(pl:Name()) == string.lower(arg) then
			return pl
		end
	end
end

local function ResolveSteamID64(arg)
	local pl = FindPlayerByArg(arg)
	if IsValid(pl) then
		return pl:SteamID64(), pl
	end
	if string.match(arg or "", "^STEAM_%d:%d:%d+$") then
		return util.SteamIDTo64(arg), nil
	end
	if string.match(arg or "", "^%d+$") and #arg >= 15 then
		return arg, nil
	end
end

concommand.Add("relapse_inv_give", function(pl, _, args)
	if not CanManageInventory(pl) then return end
	local who, id = args[1], args[2]
	if not who or not id then
		print("relapse_inv_give <steamid|steamid64|#userid|name> <item>")
		return
	end
	if not GAMEMODE:GetRelapseCosmetic(id) then
		print("unknown item " .. tostring(id))
		return
	end
	local sid64, target = ResolveSteamID64(who)
	if not sid64 then
		print("player not found")
		return
	end
	if IsValid(target) then
		if GAMEMODE:GiveRelapseItem(target, id) then
			GAMEMODE:SaveRelapseInventory(target)
		end
		GAMEMODE:SyncRelapseInventory(target)
		print("gave " .. id .. " to " .. target:Name())
		return
	end
	WriteOfflineInventory(GAMEMODE, sid64, function(data)
		data.items[id] = true
	end)
	print("gave " .. id .. " to " .. sid64 .. " (offline)")
end)

concommand.Add("relapse_inv_take", function(pl, _, args)
	if not CanManageInventory(pl) then return end
	local who, id = args[1], args[2]
	if not who or not id then
		print("relapse_inv_take <steamid|steamid64|#userid|name> <item>")
		return
	end
	local item = GAMEMODE:GetRelapseCosmetic(id)
	if item and item.Default then
		print("cannot take default item")
		return
	end
	local sid64, target = ResolveSteamID64(who)
	if not sid64 then
		print("player not found")
		return
	end
	if IsValid(target) then
		if GAMEMODE:TakeRelapseItem(target, id) then
			GAMEMODE:SaveRelapseInventory(target)
			if target:Team() == TEAM_HUMAN and target:Alive() then
				GAMEMODE:ApplyRelapsePlayermodel(target, true)
			end
			GAMEMODE:SyncRelapseInventory(target)
		end
		print("took " .. id .. " from " .. target:Name())
		return
	end
	WriteOfflineInventory(GAMEMODE, sid64, function(data)
		data.items[id] = nil
	end)
	print("took " .. id .. " from " .. sid64 .. " (offline)")
end)

net.Receive("relapse_inv_equip", function(_, pl)
	if not IsValid(pl) then return end
	if pl.RelapseInvEquipAt and pl.RelapseInvEquipAt > CurTime() then return end
	pl.RelapseInvEquipAt = CurTime() + 0.25
	local id = net.ReadString()
	if not id or #id > 64 then return end
	GAMEMODE:EquipRelapseModel(pl, id)
end)
