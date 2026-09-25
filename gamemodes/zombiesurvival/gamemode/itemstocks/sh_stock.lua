GM.ItemStocks = {}

function GM:RelapseShopUnlimited(item)
	if not istable(item) then
		item = FindItem(item)
	end
	if not item then return false end
	if item.Category == ITEMCAT_DEPLOYABLES then
		return true
	end
	local swep = item.SWEP
	return swep == "weapon_zs_hammer" or swep == "weapon_zs_wrench"
end

function GM:GetItemStocks(itemid)
	if self.ItemStocks[itemid] then
		return self.ItemStocks[itemid]
	end

	local item = FindItem(itemid)
	if item and self:RelapseShopUnlimited(item) then
		return 0
	end
	if item and item.MaxStock then
		return item.MaxStock
	end

	return -1
end

function GM:HasItemStocks(itemid)
	local item = FindItem(itemid)
	if item and self:RelapseShopUnlimited(item) then
		return true
	end
	local stock = self:GetItemStocks(itemid)
	return stock > 0 or stock == -1
end
