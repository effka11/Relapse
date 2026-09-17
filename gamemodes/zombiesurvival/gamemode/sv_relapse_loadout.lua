-- Server loadout: insert by band on Give/Equip, sync the bar, handle 1–9.

util.AddNetworkString("relapse_loadout")
util.AddNetworkString("relapse_loadout_press")
util.AddNetworkString("relapse_loadout_use")
util.AddNetworkString("relapse_inv_move")
util.AddNetworkString("relapse_inv_sync")

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

function GM:RelapseInvEnsure(pl)
	if not IsValid(pl) then return end
	pl.RelapseLoadout = pl.RelapseLoadout or {}
	pl.RelapseBag = pl.RelapseBag or {}
end

function GM:ResetRelapseLoadout(pl)
	if not IsValid(pl) then return end
	pl.RelapseLoadout = {}
	pl.RelapseBag = {}
	pl.RelapseLoadoutSlot = nil
	pl.RelapseLoadoutHolstered = true
	self:SyncRelapseLoadout(pl)
end

local function WriteBagEntry(entry)
	if not entry or not entry.t or not entry.id then
		net.WriteUInt(0, 2)
		return
	end
	local gm = GAMEMODE
	if entry.t == "wep" then
		net.WriteUInt(gm.RelapseInvKindWep, 2)
		net.WriteString(entry.id)
		return
	end
	if entry.t == "inv" then
		net.WriteUInt(gm.RelapseInvKindInv, 2)
		net.WriteString(entry.id)
		return
	end
	if entry.t == "ammo" then
		net.WriteUInt(gm.RelapseInvKindAmmo, 2)
		net.WriteString(entry.id)
		return
	end
	net.WriteUInt(0, 2)
end

function GM:SyncRelapseLoadout(pl)
	if not IsValid(pl) then return end
	self:RelapseInvSanitize(pl)

	local list = pl.RelapseLoadout or {}
	local bag = pl.RelapseBag or {}
	net.Start("relapse_loadout")
		for i = 1, self.RelapseLoadoutMax do
			net.WriteString(list[i] or "")
		end
		net.WriteUInt(pl.RelapseLoadoutSlot or 0, 4)
		net.WriteBool(pl.RelapseLoadoutHolstered and true or false)
		for i = 1, self.RelapseInvBagSlots do
			WriteBagEntry(bag[i])
		end
	net.Send(pl)
end

function GM:RelapseLoadoutDirty(pl)
	if not IsValid(pl) then return end
	local id = "RelapseLoadoutSync" .. pl:EntIndex()
	timer.Create(id, 0, 1, function()
		if IsValid(pl) then
			GAMEMODE:SyncRelapseLoadout(pl)
		end
	end)
end

---------------------------------------------------------------------------
-- Mutate
---------------------------------------------------------------------------

function GM:RelapseInvGet(pl, zone, i)
	self:RelapseInvEnsure(pl)
	if zone == self.RelapseInvZoneHot then
		local id = pl.RelapseLoadout[i]
		if isstring(id) and id ~= "" then
			return { t = "wep", id = id }
		end
		return nil
	end
	return pl.RelapseBag[i]
end

function GM:RelapseInvSet(pl, zone, i, entry)
	self:RelapseInvEnsure(pl)
	if zone == self.RelapseInvZoneHot then
		pl.RelapseLoadout[i] = (entry and entry.t == "wep" and entry.id) or nil
		return
	end
	pl.RelapseBag[i] = entry
end

function GM:RelapseInvHas(pl, kind, id)
	self:RelapseInvEnsure(pl)
	for i = 1, self.RelapseLoadoutMax do
		if kind == "wep" and pl.RelapseLoadout[i] == id then
			return self.RelapseInvZoneHot, i
		end
	end
	for i = 1, self.RelapseInvBagSlots do
		local e = pl.RelapseBag[i]
		if e and e.t == kind and e.id == id then
			return self.RelapseInvZoneBag, i
		end
	end
end

function GM:RelapseInvFirstEmpty(pl, zone)
	self:RelapseInvEnsure(pl)
	local n = zone == self.RelapseInvZoneHot and self.RelapseLoadoutMax or self.RelapseInvBagSlots
	for i = 1, n do
		if not self:RelapseInvGet(pl, zone, i) then
			return i
		end
	end
end

function GM:RelapseInvSanitize(pl)
	if not IsValid(pl) then return end
	self:RelapseInvEnsure(pl)

	local seenWep = {}
	for i = 1, self.RelapseLoadoutMax do
		local id = pl.RelapseLoadout[i]
		if not isstring(id) or id == "" or not pl:HasWeapon(id) or seenWep[id] then
			pl.RelapseLoadout[i] = nil
		else
			seenWep[id] = true
		end
	end

	for i = 1, self.RelapseInvBagSlots do
		local e = pl.RelapseBag[i]
		if not e or not e.t or not e.id then
			pl.RelapseBag[i] = nil
		elseif e.t == "wep" then
			if not pl:HasWeapon(e.id) or seenWep[e.id] then
				pl.RelapseBag[i] = nil
			else
				seenWep[e.id] = true
			end
		elseif e.t == "inv" then
			if not (pl.ZSInventory and pl.ZSInventory[e.id] and pl.ZSInventory[e.id] > 0) then
				pl.RelapseBag[i] = nil
			end
		elseif e.t == "ammo" then
			e.id = self:RelapseInvAmmoId(e.id)
			if not e.id or not self:RelapseInvIsBagAmmo(e.id) or pl:GetAmmoCount(e.id) <= 0 then
				pl.RelapseBag[i] = nil
			end
		else
			pl.RelapseBag[i] = nil
		end
	end

	local seenInv = {}
	local seenAmmo = {}
	for i = 1, self.RelapseInvBagSlots do
		local e = pl.RelapseBag[i]
		if e and e.t == "inv" then
			if seenInv[e.id] then
				pl.RelapseBag[i] = nil
			else
				seenInv[e.id] = true
			end
		elseif e and e.t == "ammo" then
			if seenAmmo[e.id] then
				pl.RelapseBag[i] = nil
			else
				seenAmmo[e.id] = true
			end
		end
	end

	if pl:Team() == TEAM_HUMAN then
		for _, wep in ipairs(pl:GetWeapons()) do
			if wep:IsValid() then
				local class = wep:GetClass()
				if self:RelapseLoadoutBandOf(class) and not seenWep[class] then
					local hot = self:RelapseInvFirstEmpty(pl, self.RelapseInvZoneHot)
					if hot then
						pl.RelapseLoadout[hot] = class
					else
						local bag = self:RelapseInvFirstEmpty(pl, self.RelapseInvZoneBag)
						if bag then
							pl.RelapseBag[bag] = { t = "wep", id = class }
						end
					end
					seenWep[class] = true
				end
			end
		end

		local orphans = {}
		for id, count in pairs(pl.ZSInventory or {}) do
			if count and count > 0 and not seenInv[id] then
				orphans[#orphans + 1] = id
			end
		end
		table.sort(orphans, function(a, b)
			local da = self.ZSInventoryItemData[a]
			local db = self.ZSInventoryItemData[b]
			return ((da and da.Index) or 0) < ((db and db.Index) or 0)
		end)
		for _, id in ipairs(orphans) do
			local bag = self:RelapseInvFirstEmpty(pl, self.RelapseInvZoneBag)
			if not bag then break end
			pl.RelapseBag[bag] = { t = "inv", id = id }
			seenInv[id] = true
		end

		for _, id in ipairs(self:RelapseInvAmmoList()) do
			if pl:GetAmmoCount(id) > 0 and not seenAmmo[id] then
				local bag = self:RelapseInvFirstEmpty(pl, self.RelapseInvZoneBag)
				if not bag then break end
				pl.RelapseBag[bag] = { t = "ammo", id = id }
				seenAmmo[id] = true
			end
		end
	end

	if pl.RelapseLoadoutSlot and not self:RelapseLoadoutSlotFilled(pl.RelapseLoadout, pl.RelapseLoadoutSlot) then
		pl.RelapseLoadoutSlot = nil
	end
end

function GM:RelapseInvOnGain(pl, item)
	if not IsValid(pl) then return end
	self:RelapseInvSanitize(pl)
	if not self:RelapseInvHas(pl, "inv", item) then
		local bag = self:RelapseInvFirstEmpty(pl, self.RelapseInvZoneBag)
		if bag then
			pl.RelapseBag[bag] = { t = "inv", id = item }
		end
	end
	self:SyncRelapseLoadout(pl)
end

function GM:RelapseInvOnLose(pl, item)
	if not IsValid(pl) then return end
	self:RelapseInvSanitize(pl)
	self:SyncRelapseLoadout(pl)
end

function GM:RelapseInvMove(pl, fromZone, fromIdx, toZone, toIdx)
	if not IsValid(pl) or not pl:Alive() or pl:Team() ~= TEAM_HUMAN then return end
	fromZone = math.floor(tonumber(fromZone) or -1)
	toZone = math.floor(tonumber(toZone) or -1)
	fromIdx = math.floor(tonumber(fromIdx) or 0)
	toIdx = math.floor(tonumber(toIdx) or 0)
	if fromZone ~= self.RelapseInvZoneBag and fromZone ~= self.RelapseInvZoneHot then return end
	if toZone ~= self.RelapseInvZoneBag and toZone ~= self.RelapseInvZoneHot then return end
	if fromIdx < 1 or fromIdx > self:RelapseInvZoneMax(fromZone) then return end
	if toIdx < 1 or toIdx > self:RelapseInvZoneMax(toZone) then return end
	if fromZone == toZone and fromIdx == toIdx then return end

	self:RelapseInvSanitize(pl)
	local a = self:RelapseInvGet(pl, fromZone, fromIdx)
	if not a then return end
	local b = self:RelapseInvGet(pl, toZone, toIdx)
	if not self:RelapseInvCanPlace(a, toZone) then return end
	if b and not self:RelapseInvCanPlace(b, fromZone) then return end

	self:RelapseInvSet(pl, toZone, toIdx, a)
	self:RelapseInvSet(pl, fromZone, fromIdx, b)
	self:RelapseLoadoutFollowActive(pl)
	self:SyncRelapseLoadout(pl)
end

function GM:RelapseLoadoutFollowActive(pl)
	if not IsValid(pl) then return end
	self:RelapseInvEnsure(pl)

	local list = pl.RelapseLoadout
	local active = pl:GetActiveWeapon()
	if not IsValid(active) then return end

	local class = active:GetClass()
	if self:IsHumanUnarmedWeapon(class) then
		pl.RelapseLoadoutHolstered = true
		return
	end

	for i = 1, self.RelapseLoadoutMax do
		if list[i] == class then
			pl.RelapseLoadoutSlot = i
			pl.RelapseLoadoutHolstered = false
			return
		end
	end
end

function GM:RelapseLoadoutAdd(pl, class, silent)
	if not IsValid(pl) or pl:Team() ~= TEAM_HUMAN then return end
	if not self:RelapseLoadoutBandOf(class) then return end

	self:RelapseInvEnsure(pl)
	if self:RelapseInvHas(pl, "wep", class) then
		if not silent then
			self:RelapseLoadoutFollowActive(pl)
			self:RelapseLoadoutDirty(pl)
		end
		return
	end

	local placedHot
	local hot = self:RelapseInvFirstEmpty(pl, self.RelapseInvZoneHot)
	if hot then
		pl.RelapseLoadout[hot] = class
		placedHot = true
	else
		local bag = self:RelapseInvFirstEmpty(pl, self.RelapseInvZoneBag)
		if bag then
			pl.RelapseBag[bag] = { t = "wep", id = class }
		end
	end

	if not silent then
		self:RelapseLoadoutFollowActive(pl)
		if placedHot then
			self:RelapseLoadoutTryDeployNew(pl, class)
		end
		self:RelapseLoadoutDirty(pl)
	end
end

function GM:RelapseLoadoutRemove(pl, class)
	if not IsValid(pl) or not class then return end
	if pl:HasWeapon(class) then return end

	self:RelapseInvEnsure(pl)
	local changed = false
	for i = 1, self.RelapseLoadoutMax do
		if pl.RelapseLoadout[i] == class then
			pl.RelapseLoadout[i] = nil
			if pl.RelapseLoadoutSlot == i then
				pl.RelapseLoadoutSlot = nil
			end
			changed = true
		end
	end
	for i = 1, self.RelapseInvBagSlots do
		local e = pl.RelapseBag[i]
		if e and e.t == "wep" and e.id == class then
			pl.RelapseBag[i] = nil
			changed = true
		end
	end
	if not changed then return end

	self:RelapseLoadoutFollowActive(pl)
	self:RelapseLoadoutDirty(pl)
end

function GM:RebuildRelapseLoadout(pl)
	if not IsValid(pl) or pl:Team() ~= TEAM_HUMAN then
		self:ResetRelapseLoadout(pl)
		return
	end

	pl.RelapseLoadout = {}
	pl.RelapseBag = pl.RelapseBag or {}
	pl.RelapseLoadoutSlot = nil
	for _, wep in ipairs(pl:GetWeapons()) do
		if wep:IsValid() then
			self:RelapseLoadoutAdd(pl, wep:GetClass(), true)
		end
	end
	self:RelapseLoadoutFollowActive(pl)
	self:SyncRelapseLoadout(pl)
end

---------------------------------------------------------------------------
-- Select
---------------------------------------------------------------------------

function GM:RelapseLoadoutBump(pl)
	if not IsValid(pl) then return 0 end
	pl.RelapseLoadoutGen = (pl.RelapseLoadoutGen or 0) + 1
	return pl.RelapseLoadoutGen
end

-- After a shop Give the player is still on fists: AutoSwitchTo is false, and
-- empty MW guns fail engine SelectWeapon. Put the new item in hands.
function GM:RelapseLoadoutTryDeployNew(pl, class)
	if not IsValid(pl) or not class then return end
	if not pl:HasWeapon(class) then return end
	if not self:RelapseLoadoutBandOf(class) then return end

	local active = pl:GetActiveWeapon()
	if IsValid(active) and not self:IsHumanUnarmedWeapon(active:GetClass()) then
		return
	end

	local gen = self:RelapseLoadoutBump(pl)

	local function apply()
		if not IsValid(pl) or pl.RelapseLoadoutGen ~= gen then return end
		if not pl:HasWeapon(class) then return end

		local cur = pl:GetActiveWeapon()
		if IsValid(cur) and cur:GetClass() ~= class and not self:IsHumanUnarmedWeapon(cur:GetClass()) then
			return
		end

		self:RelapseSelectWeapon(pl, class)
		net.Start("relapse_loadout_use")
			net.WriteString(class)
		net.Send(pl)
		local list = pl.RelapseLoadout or {}
		for i = 1, self.RelapseLoadoutMax do
			if list[i] == class then
				pl.RelapseLoadoutSlot = i
				pl.RelapseLoadoutHolstered = false
				break
			end
		end
		self:RelapseLoadoutDirty(pl)
	end

	apply()
	timer.Simple(0.15, apply)
	timer.Simple(0.4, apply)
end

function GM:RelapseLoadoutHolster(pl)
	self:RelapseLoadoutBump(pl)
	local fists = self.HumanUnarmedWeapon
	if not pl:HasWeapon(fists) then
		pl:Give(fists)
	end
	self:RelapseSelectWeapon(pl, fists)
	pl.RelapseLoadoutHolstered = true
end

function GM:RelapseLoadoutPress(pl, slot, holster)
	if not IsValid(pl) or not pl:Alive() or pl:Team() ~= TEAM_HUMAN then return end

	local list = pl.RelapseLoadout or {}
	slot = math.floor(tonumber(slot) or 0)
	if slot < 1 or slot > self.RelapseLoadoutMax then return end

	self:RelapseLoadoutBump(pl)

	local class = list[slot]
	if holster or not class then
		if IsValid(pl:GetActiveWeapon()) then
			local activeClass = pl:GetActiveWeapon():GetClass()
			if activeClass and not self:IsHumanUnarmedWeapon(activeClass) then
				self:RelapseLoadoutHolster(pl)
			end
		end
		if class then
			pl.RelapseLoadoutSlot = slot
		end
		self:SyncRelapseLoadout(pl)
		return
	end

	if not pl:HasWeapon(class) then
		self:RelapseLoadoutRemove(pl, class)
		return
	end

	self:RelapseSelectWeapon(pl, class)
	pl.RelapseLoadoutSlot = slot
	pl.RelapseLoadoutHolstered = false
	self:SyncRelapseLoadout(pl)
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

hook.Add("WeaponEquip", "RelapseLoadout", function(wep, ply)
	local pl = ply
	if not IsValid(pl) and IsValid(wep) then
		pl = wep:GetOwner()
	end
	timer.Simple(0, function()
		if not (IsValid(pl) and IsValid(wep) and pl:IsPlayer() and pl:Team() == TEAM_HUMAN) then
			return
		end
		GAMEMODE:RelapseLoadoutAdd(pl, wep:GetClass())
	end)
end)

net.Receive("relapse_loadout_press", function(_, pl)
	if not IsValid(pl) then return end
	GAMEMODE:RelapseLoadoutPress(pl, net.ReadUInt(4), net.ReadBool())
end)

net.Receive("relapse_inv_move", function(_, pl)
	if not IsValid(pl) then return end
	if CurTime() < (pl.RelapseInvMoveAt or 0) then return end
	pl.RelapseInvMoveAt = CurTime() + 0.05
	local bits = GAMEMODE.RelapseInvIndexBits or 5
	GAMEMODE:RelapseInvMove(pl, net.ReadUInt(2), net.ReadUInt(bits), net.ReadUInt(2), net.ReadUInt(bits))
end)

net.Receive("relapse_inv_sync", function(_, pl)
	if not IsValid(pl) then return end
	if CurTime() < (pl.RelapseInvSyncAt or 0) then return end
	pl.RelapseInvSyncAt = CurTime() + 0.2
	GAMEMODE:RelapseLoadoutDirty(pl)
end)

hook.Add("PlayerAmmoChanged", "RelapseInvAmmo", function(pl, ammoID, oldcount, newcount)
	if not (IsValid(pl) and pl:IsPlayer() and pl:Team() == TEAM_HUMAN) then return end
	if oldcount == newcount then return end
	local gm = GAMEMODE
	if not gm.RelapseInvIsBagAmmo then return end
	local name = game.GetAmmoName(ammoID)
	if not gm:RelapseInvIsBagAmmo(name) then return end
	gm:RelapseLoadoutDirty(pl)
end)
