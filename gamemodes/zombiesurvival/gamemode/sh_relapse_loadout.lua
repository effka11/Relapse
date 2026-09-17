-- Relapse loadout bar: 1-9 cells. Fists are never a cell.
-- Alt inventory: 3×9 bag + 9 hotbar cells, drag to rearrange.

AddCSLuaFile()

GM.RelapseLoadoutMin = 1
GM.RelapseLoadoutMax = 9

GM.RelapseLoadoutBand = {
	WEAPON = 1,
	TOOL = 2,
	DEVICE = 3
}

---------------------------------------------------------------------------
-- Classification
---------------------------------------------------------------------------

GM.RelapseInvBagSlots = 27
GM.RelapseInvIndexBits = 5
GM.RelapseInvZoneBag = 0
GM.RelapseInvZoneHot = 1
GM.RelapseInvKindWep = 1
GM.RelapseInvKindInv = 2
GM.RelapseInvKindAmmo = 3

function GM:RelapseInvZoneMax(zone)
	if zone == self.RelapseInvZoneHot then
		return self.RelapseLoadoutMax
	end
	return self.RelapseInvBagSlots
end

function GM:RelapseLoadoutCellCount(n)
	if type(n) == "table" then
		return self:RelapseLoadoutBarCount(n)
	end
	return math.Clamp(tonumber(n) or 0, self.RelapseLoadoutMin, self.RelapseLoadoutMax)
end

function GM:RelapseLoadoutSlotFilled(list, i)
	local id = list and list[i]
	return isstring(id) and id ~= ""
end

function GM:RelapseLoadoutLastSlot(list)
	list = list or self.RelapseLoadout or {}
	local last = 0
	for i = 1, self.RelapseLoadoutMax do
		if self:RelapseLoadoutSlotFilled(list, i) then
			last = i
		end
	end
	return last
end

function GM:RelapseLoadoutBarCount(list)
	return math.Clamp(math.max(self:RelapseLoadoutLastSlot(list), self.RelapseLoadoutMin), self.RelapseLoadoutMin, self.RelapseLoadoutMax)
end

function GM:RelapseLoadoutStepSlot(list, cur, dir)
	list = list or {}
	cur = math.floor(tonumber(cur) or 1)
	dir = dir < 0 and -1 or 1
	for _ = 1, self.RelapseLoadoutMax do
		cur = cur + dir
		if cur > self.RelapseLoadoutMax then cur = 1 end
		if cur < 1 then cur = self.RelapseLoadoutMax end
		if self:RelapseLoadoutSlotFilled(list, cur) then
			return cur
		end
	end
	return nil
end

function GM:RelapseInvAmmoId(id)
	if not isstring(id) or id == "" then return nil end
	return string.lower(id)
end

function GM:RelapseInvIsBagAmmo(id)
	id = self:RelapseInvAmmoId(id)
	if not id then return false end
	if self.RelapseAmmo and self.RelapseAmmo[id] then return true end
	if self.AmmoResupply and self.AmmoResupply[id] then return true end
	return false
end

function GM:RelapseInvAmmoList()
	local list, seen = {}, {}
	for _, id in ipairs(self.RelapseAmmoOrder or {}) do
		id = self:RelapseInvAmmoId(id)
		if id and self.RelapseAmmo and self.RelapseAmmo[id] then
			list[#list + 1] = id
			seen[id] = true
		end
	end
	local extra = {}
	for id in pairs(self.AmmoResupply or {}) do
		id = self:RelapseInvAmmoId(id)
		if id and not seen[id] then
			extra[#extra + 1] = id
			seen[id] = true
		end
	end
	table.sort(extra)
	for _, id in ipairs(extra) do
		list[#list + 1] = id
	end
	return list
end

function GM:RelapseInvCanPlace(entry, zone)
	if not entry then return true end
	if zone == self.RelapseInvZoneHot then
		return entry.t == "wep" and self:RelapseLoadoutBandOf(entry.id) ~= nil
	end
	return entry.t == "wep" or entry.t == "inv" or entry.t == "ammo"
end

function GM:RelapseLoadoutShopCategory(class)
	if not class then return nil end

	self.RelapseLoadoutCatBySWEP = self.RelapseLoadoutCatBySWEP or {}
	local cached = self.RelapseLoadoutCatBySWEP[class]
	if cached ~= nil then
		return cached or nil
	end

	local found
	for _, tab in ipairs(self.Items or {}) do
		if tab.SWEP == class and tab.Category then
			found = tab.Category
			if tab.PointShop then break end
		end
	end

	self.RelapseLoadoutCatBySWEP[class] = found or false
	return found
end

function GM:IsRelapseDeployableWeapon(class)
	if not class then return false end

	self.RelapseLoadoutDeployWep = self.RelapseLoadoutDeployWep or {}
	local cached = self.RelapseLoadoutDeployWep[class]
	if cached ~= nil then return cached end

	local hit = false
	for _, tab in ipairs(self.DeployableInfo or {}) do
		if tab.WepClass == class then
			hit = true
			break
		end
	end

	self.RelapseLoadoutDeployWep[class] = hit
	return hit
end

function GM:RelapseLoadoutBandOf(class)
	if not class or self:IsHumanUnarmedWeapon(class) then return nil end

	local stored = weapons.GetStored(class)
	if not stored or stored.ZombieOnly or stored.IsTrinket then return nil end
	if stored.Slot == 5 then return nil end

	local cat = self:RelapseLoadoutShopCategory(class)
	if cat == ITEMCAT_GUNS or cat == ITEMCAT_MELEE then
		return self.RelapseLoadoutBand.WEAPON
	end
	if cat == ITEMCAT_TOOLS then
		return self.RelapseLoadoutBand.TOOL
	end
	if cat == ITEMCAT_DEPLOYABLES then
		return self.RelapseLoadoutBand.DEVICE
	end
	if cat == ITEMCAT_TRINKETS or cat == ITEMCAT_AMMO or cat == ITEMCAT_OTHER then
		return nil
	end

	if self:IsRelapseDeployableWeapon(class) or stored.DeployClass or stored.DeployableAmmo then
		return self.RelapseLoadoutBand.DEVICE
	end

	if string.find(class, "control", 1, true) or string.find(class, "remote", 1, true) then
		return self.RelapseLoadoutBand.DEVICE
	end

	local ammo = stored.Primary and stored.Primary.Ammo
	if ammo == "GaussEnergy" or stored.HealStrength then
		return self.RelapseLoadoutBand.TOOL
	end

	if stored.IsMelee then
		return self.RelapseLoadoutBand.WEAPON
	end

	if stored.Heal or stored.Slot == 4 then
		return self.RelapseLoadoutBand.TOOL
	end

	return self.RelapseLoadoutBand.WEAPON
end

---------------------------------------------------------------------------
-- Switch
-- MW Holster returns false until CanSwitch, so engine SelectWeapon cancels.
-- Empty guns also fail HasAnyAmmo. SetActiveWeapon skips Deploy, so the
-- MW viewmodel never draws.
---------------------------------------------------------------------------

function GM:RelapsePrepareWeaponSwitch(wep)
	if not IsValid(wep) then return end

	if wep.AddFlag then
		wep:AddFlag("CanSwitch")
	end

	if wep.RelapseAllowEmptySelect then return end
	wep.RelapseAllowEmptySelect = true

	wep.HasAnyAmmo = function()
		return true
	end

	local oldHolster = wep.Holster
	wep.Holster = function(self, nextWep)
		if isfunction(oldHolster) then
			oldHolster(self, nextWep)
		end
		return true
	end
end

local function RelapseEnsureDeploy(wep)
	if wep.RelapseDidDeploy then return end
	wep.RelapseDidDeploy = true
	if wep.Deploy and not (wep.HasFlag and wep:HasFlag("Drawing")) then
		wep:Deploy()
	end
end

function GM:RelapseSelectWeapon(pl, class)
	if not IsValid(pl) or not class then return false end
	if not pl:HasWeapon(class) then return false end

	local wep = pl:GetWeapon(class)
	if not (wep and wep:IsValid()) then return false end

	local cur = pl:GetActiveWeapon()
	if IsValid(cur) then
		self:RelapsePrepareWeaponSwitch(cur)
		if cur ~= wep then
			cur.RelapseDidDeploy = nil
		end
	end
	self:RelapsePrepareWeaponSwitch(wep)

	if CLIENT then
		input.SelectWeapon(wep)
		return true
	end

	if pl:GetActiveWeapon() == wep then
		RelapseEnsureDeploy(wep)
		return true
	end

	pl:SelectWeapon(class)
	if pl:GetActiveWeapon() == wep then
		wep.RelapseDidDeploy = true
		return true
	end

	-- Last resort: engine still refused. Deploy ourselves so MW starts Drawing.
	pl:SetActiveWeapon(wep)
	if pl:GetActiveWeapon() ~= wep then return false end
	wep.RelapseDidDeploy = nil
	RelapseEnsureDeploy(wep)
	if SERVER then
		net.Start("relapse_loadout_use")
			net.WriteString(class)
		net.Send(pl)
	end
	return true
end
