-- Real cartridge types for Relapse guns. Same brass = same id. Do not reuse HL2
-- class ammo (pistol / smg1 / ar2 / 357 / buckshot) on Relapse weapons.
-- Dollars are bulk FMJ / surplus USD per round. Stick is 9×18 at $0.30:
-- that matches the old pistol box (14 rounds for 9 points).

GM.RelapseAmmoPrice = {
	StickDollars = 0.30,
	StickRoundPoints = 9 / 14,
	AmmoMulW = 0.05, -- outside Π, like TypeMul. Stick cartridge → 1.
	Worth2Mul = 15 / 18, -- two shop boxes at the old worth discount
	Worth3Mul = 20 / 27,
}

GM.RelapseAmmoOrder = {
	"9x18",
	"9x19",
	"45acp",
	"357mag",
	"12ga",
	"762x39",
}

GM.RelapseAmmo = {
	["9x18"] = {
		PrintName = "9×18",
		Dollars = 0.30,
		ShopCount = 16,
		Icon = "ammo_pistol",
		Model = "models/Items/BoxSRounds.mdl",
	},
	["9x19"] = {
		PrintName = "9×19",
		Dollars = 0.28,
		ShopCount = 16,
		Icon = "ammo_smg",
		Model = "models/Items/BoxSRounds.mdl",
	},
	["45acp"] = {
		PrintName = ".45 ACP",
		Dollars = 0.45,
		ShopCount = 14,
		Icon = "ammo_pistol",
		Model = "models/Items/BoxSRounds.mdl",
	},
	["357mag"] = {
		PrintName = ".357 Magnum",
		Dollars = 0.65,
		ShopCount = 12,
		Icon = "ammo_pistol",
		Model = "models/Items/BoxSRounds.mdl",
	},
	["12ga"] = {
		PrintName = "12 gauge",
		Dollars = 1.00,
		ShopCount = 12,
		Icon = "ammo_shotgun",
		Model = "models/Items/BoxBuckshot.mdl",
	},
	["762x39"] = {
		PrintName = "7.62×39",
		Dollars = 0.36,
		ShopCount = 20,
		Icon = "ammo_rifle",
		Model = "models/props_lab/box01a.mdl",
	},
}

function GM:GetRelapseAmmo(ammoOrId)
	if istable(ammoOrId) then
		return ammoOrId
	end
	if not isstring(ammoOrId) or ammoOrId == "" then
		return nil
	end

	local ammo = self.RelapseAmmo and self.RelapseAmmo[string.lower(ammoOrId)]
	return ammo
end

function GM:GetAmmoRoundPoints(ammoOrId)
	local price = self.RelapseAmmoPrice
	local dollars = price.StickDollars
	local ammo = self:GetRelapseAmmo(ammoOrId)
	if ammo and ammo.Dollars then
		dollars = ammo.Dollars
	end

	return dollars / price.StickDollars * price.StickRoundPoints
end

function GM:GetAmmoShopPoints(ammoOrId)
	local ammo = self:GetRelapseAmmo(ammoOrId)
	if not ammo then
		return 1
	end

	return math.max(1, math.floor(ammo.ShopCount * self:GetAmmoRoundPoints(ammo) + 0.5))
end

function GM:GetAmmoRoundUsefulness(ammoOrId)
	return self:GetAmmoRoundPoints(ammoOrId) * self:GetPointUsefulness()
end

function GM:GetAmmoPurchaseSignature(ammoOrId)
	if not isstring(ammoOrId) or ammoOrId == "" then
		return nil
	end

	local lower = string.lower(ammoOrId)
	if self.RelapseAmmo and self.RelapseAmmo[lower] then
		return "ammo_" .. lower
	end

	local names = self.AmmoToPurchaseNames
	if not names then
		return nil
	end
	if names[ammoOrId] then
		return names[ammoOrId]
	end
	if names[lower] then
		return names[lower]
	end

	for k, sig in pairs(names) do
		if string.lower(k) == lower then
			return sig
		end
	end
end

function GM:BindRelapseAmmoTables()
	if not self.RelapseAmmo then
		return
	end

	self.AmmoCache = self.AmmoCache or {}
	self.AmmoNames = self.AmmoNames or {}
	self.AmmoIcons = self.AmmoIcons or {}
	self.AmmoModels = self.AmmoModels or {}
	self.AmmoResupply = self.AmmoResupply or {}
	self.AmmoToPurchaseNames = self.AmmoToPurchaseNames or {}

	for id, ammo in pairs(self.RelapseAmmo) do
		self.AmmoCache[id] = ammo.ShopCount
		self.AmmoNames[id] = ammo.PrintName
		self.AmmoIcons[id] = ammo.Icon
		self.AmmoModels[id] = ammo.Model
		self.AmmoResupply[id] = true
		self.AmmoToPurchaseNames[id] = "ammo_" .. id
	end
end

function GM:RegisterRelapseAmmoShopItems()
	if not self.RelapseAmmo or not self.RelapseAmmoOrder then
		return
	end

	local price = self.RelapseAmmoPrice
	for _, id in ipairs(self.RelapseAmmoOrder) do
		local ammo = self.RelapseAmmo[id]
		if ammo then
			local ammoId = id
			local shopCount = ammo.ShopCount
			local shopPts = self:GetAmmoShopPoints(ammo)
			local shop = self:AddPointShopItem("ammo_" .. ammoId, ITEMCAT_AMMO, shopPts, nil, ammo.PrintName, nil, ammo.Icon, function(pl)
				pl:GiveAmmo(shopCount, ammoId, true)
			end)
			shop.AmmoPack = ammoId
			shop.AmmoCount = shopCount

			local count2 = shopCount * 2
			local worth2 = math.max(1, math.floor(shopPts * 2 * price.Worth2Mul + 0.5))
			local start2 = self:AddStartingItem("2ammo_" .. ammoId, ITEMCAT_AMMO, worth2, nil, ammo.PrintName, nil, ammo.Icon, function(pl)
				pl:GiveAmmo(count2, ammoId, true)
			end)
			start2.AmmoPack = ammoId
			start2.AmmoCount = count2

			local count3 = shopCount * 3
			local worth3 = math.max(1, math.floor(shopPts * 3 * price.Worth3Mul + 0.5))
			local start3 = self:AddStartingItem("3ammo_" .. ammoId, ITEMCAT_AMMO, worth3, nil, ammo.PrintName, nil, ammo.Icon, function(pl)
				pl:GiveAmmo(count3, ammoId, true)
			end)
			start3.AmmoPack = ammoId
			start3.AmmoCount = count3
		end
	end
end

GM:BindRelapseAmmoTables()
