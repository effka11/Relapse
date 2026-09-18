-- Relapse cosmetic inventory. Persist per SteamID64. Grants merge on join.
-- Marks live in this file: remort drop, not the cycle vault.

util.AddNetworkString("relapse_inv_sync")
util.AddNetworkString("relapse_inv_equip")
util.AddNetworkString("relapse_inv_buy")

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
		model = self:GetRelapseDefaultModelId(),
		marks = 0,
		starter_rolled = false
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
		clean.starter_rolled = true
	elseif data.starter_rolled then
		clean.starter_rolled = true
	end
	clean.marks = self:ClampRelapseMarks(data.marks)
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
		model = pl.RelapseInv.model,
		marks = self:ClampRelapseMarks(pl.RelapseInv.marks),
		starter_rolled = pl.RelapseInv.starter_rolled and true or false
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

	if not pl.RelapseInv.starter_rolled then
		pl.RelapseInv.model = self:PickRelapseSurvivorModel()
		pl.RelapseInv.starter_rolled = true
		dirty = true
	elseif not self:PlayerOwnsRelapseItem(pl, pl.RelapseInv.model) then
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
		net.WriteUInt(math.min(self:GetRelapseMarks(pl), 4294967295), 32)
	net.Send(pl)
end

function GM:SetRelapseMarks(pl, n)
	if not IsValid(pl) or pl:IsBot() then return 0 end
	self:EnsureRelapseInventory(pl, true)
	pl.RelapseInv.marks = self:ClampRelapseMarks(n)
	self:SaveRelapseInventory(pl)
	self:SyncRelapseInventory(pl)
	return pl.RelapseInv.marks
end

function GM:AddRelapseMarks(pl, n)
	n = math.floor(tonumber(n) or 0)
	if n == 0 or not IsValid(pl) or pl:IsBot() then
		return self:GetRelapseMarks(pl)
	end
	self:EnsureRelapseInventory(pl, true)
	pl.RelapseInv.marks = self:ClampRelapseMarks((pl.RelapseInv.marks or 0) + n)
	self:SaveRelapseInventory(pl)
	self:SyncRelapseInventory(pl)
	return pl.RelapseInv.marks
end

function GM:GrantRelapseMarks(pl)
	if not IsValid(pl) or pl:IsBot() then return 0 end
	local gained = self:RollRelapseMarks()
	self:AddRelapseMarks(pl, gained)
	return gained
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

function GM:BuyRelapseCosmetic(pl, id)
	if not IsValid(pl) or pl:IsBot() then return false end
	self:EnsureRelapseInventory(pl)

	local item = self:GetRelapseCosmetic(id)
	if not item then
		return false
	end
	if not self:RelapseCosmeticForSale(id) then
		return false
	end
	if self:PlayerOwnsRelapseItem(pl, id) then
		return false
	end

	local price = self:RelapseCosmeticMarks(id)
	if self:GetRelapseMarks(pl) < price then
		return false
	end
	if not self:GiveRelapseItem(pl, id) then
		return false
	end

	pl.RelapseInv.marks = self:ClampRelapseMarks((pl.RelapseInv.marks or 0) - price)
	self:SaveRelapseInventory(pl)
	self:SyncRelapseInventory(pl)
	return true
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

function GM:UnequipRelapseModel(pl)
	return self:EquipRelapseModel(pl, self:GetRelapseDefaultModelId())
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

local function ReplyGiveMarks(pl, msg)
	print(msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
		pl:ChatPrint(msg)
	end
end

local function FindPlayerByNickPartial(nick)
	nick = string.Trim(nick or "")
	if nick == "" then return nil, "empty name" end

	local needle = string.lower(nick)
	local exact, partial = {}, {}
	for _, ply in ipairs(player.GetAll()) do
		local name = string.lower(ply:Nick())
		if name == needle then
			exact[#exact + 1] = ply
		elseif string.find(name, needle, 1, true) then
			partial[#partial + 1] = ply
		end
	end

	local pool = #exact > 0 and exact or partial
	if #pool == 0 then
		return nil, "no player named '" .. nick .. "' on the server"
	end
	if #pool > 1 then
		local names = {}
		for i, ply in ipairs(pool) do
			names[i] = ply:Nick()
		end
		return nil, "ambiguous name '" .. nick .. "': " .. table.concat(names, ", ")
	end

	return pool[1]
end

concommand.Add("relapse_givemarks", function(pl, _, args)
	if not CanManageInventory(pl) then return end

	local usage = "[Relapse] usage: relapse_givemarks <n>  or  relapse_givemarks <nick|steamid|steamid64> <n>"
	if #args == 0 then
		ReplyGiveMarks(pl, usage)
		return
	end

	local n, who
	if #args == 1 then
		n = tonumber(args[1])
		if not IsValid(pl) or not n then
			ReplyGiveMarks(pl, usage)
			return
		end
	else
		n = tonumber(args[#args])
		who = table.concat(args, " ", 1, #args - 1)
	end

	n = n and math.floor(n) or nil
	if not n or n == 0 then
		ReplyGiveMarks(pl, "[Relapse] n must be a non-zero number")
		return
	end

	local target
	if not who then
		target = pl
	else
		target = FindPlayerByArg(who)
		if not IsValid(target) then
			local err
			target, err = FindPlayerByNickPartial(who)
			if err and string.find(err, "ambiguous", 1, true) then
				ReplyGiveMarks(pl, "[Relapse] " .. err)
				return
			end
		end
	end

	if IsValid(target) then
		if target:IsBot() then
			ReplyGiveMarks(pl, "[Relapse] " .. target:Nick() .. " is a bot")
			return
		end
		local now = GAMEMODE:AddRelapseMarks(target, n)
		ReplyGiveMarks(pl, string.format("[Relapse] gave %d marks to %s (now %d)", n, target:Nick(), now))
		if target ~= pl then
			target:ChatPrint(string.format("[Relapse] you received %d marks (now %d)", n, now))
		end
		return
	end

	if not who then
		ReplyGiveMarks(pl, usage)
		return
	end

	local sid64 = select(1, ResolveSteamID64(who))
	if not sid64 then
		ReplyGiveMarks(pl, "[Relapse] player not found")
		return
	end

	local now = 0
	WriteOfflineInventory(GAMEMODE, sid64, function(data)
		data.marks = GAMEMODE:ClampRelapseMarks((data.marks or 0) + n)
		now = data.marks
	end)
	ReplyGiveMarks(pl, string.format("[Relapse] gave %d marks to %s (now %d, offline)", n, sid64, now))
end)

net.Receive("relapse_inv_equip", function(_, pl)
	if not IsValid(pl) then return end
	if pl.RelapseInvEquipAt and pl.RelapseInvEquipAt > CurTime() then return end
	pl.RelapseInvEquipAt = CurTime() + 0.25
	local id = net.ReadString()
	if not id or #id > 64 then return end
	if id == "" then
		GAMEMODE:UnequipRelapseModel(pl)
		return
	end
	GAMEMODE:EquipRelapseModel(pl, id)
end)

net.Receive("relapse_inv_buy", function(_, pl)
	if not IsValid(pl) then return end
	if pl.RelapseInvBuyAt and pl.RelapseInvBuyAt > CurTime() then return end
	pl.RelapseInvBuyAt = CurTime() + 0.25
	local id = net.ReadString()
	if not id or id == "" or #id > 64 then return end
	GAMEMODE:BuyRelapseCosmetic(pl, id)
end)
