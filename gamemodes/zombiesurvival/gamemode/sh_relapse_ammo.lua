-- Real cartridge types for Relapse guns. Same brass = same id. Do not reuse HL2
-- class ammo (pistol / smg1 / ar2 / 357 / buckshot) on Relapse weapons.
-- Dollars are bulk FMJ / surplus USD per round. Stick is 9×18 at $0.30:
-- round cost is the old pistol box (14 for 9 points). Shop packs are 15
-- points; count = round(15 / round points), then snap to a multiple of 3
-- so a 5-point pack is an integer (15/3). Do not hardcode ShopCount.

GM.RelapseAmmoPrice = {
	StickDollars = 0.30,
	StickRoundPoints = 9 / 14,
	AmmoMulW = 0.05, -- outside Π, like TypeMul. Stick cartridge → 1.
	ShopPoints = 15, -- one shelf; count from round cost
	ShopPointsMin = 5,
	ShopPointsMax = 75,
	ShopPointsStep = 5,
	Worth2Mul = 15 / 18, -- two shop boxes at the old worth discount
	Worth3Mul = 20 / 27,
}

GM.RelapseAmmoOrder = {
	"9x18",
	"9x19",
	"45acp",
	"357mag",
	"3030win",
	"12ga",
	"9x39",
	"556x45",
	"762x39",
	"762x51",
	"762x54r",
	"50bmg",
}

GM.RelapseAmmo = {
	["9x18"] = {
		PrintName = "9×18",
		Dollars = 0.30,
		Icon = "ammo_9x18",
		Model = "models/Items/BoxSRounds.mdl",
	},
	["9x19"] = {
		PrintName = "9×19",
		Dollars = 0.28,
		Icon = "ammo_9x19",
		Model = "models/Items/BoxSRounds.mdl",
	},
	["45acp"] = {
		PrintName = ".45 ACP",
		Dollars = 0.45,
		Icon = "ammo_45acp",
		Model = "models/Items/BoxSRounds.mdl",
	},
	["357mag"] = {
		PrintName = ".357 Magnum",
		Dollars = 0.65,
		Icon = "ammo_357mag",
		Model = "models/Items/BoxSRounds.mdl",
	},
	["3030win"] = {
		PrintName = ".30-30",
		Dollars = 0.50,
		Icon = "ammo_3030",
		Model = "models/props_lab/box01a.mdl",
	},
	["12ga"] = {
		PrintName = "12 gauge",
		Dollars = 1.00,
		Icon = "ammo_12ga",
		Model = "models/Items/BoxBuckshot.mdl",
	},
	["9x39"] = {
		PrintName = "9×39",
		Dollars = 0.45,
		Icon = "ammo_9x39",
		Model = "models/props_lab/box01a.mdl",
	},
	["556x45"] = {
		PrintName = "5.56×45",
		Dollars = 0.32,
		Icon = "ammo_556x45",
		Model = "models/props_lab/box01a.mdl",
	},
	["762x39"] = {
		PrintName = "7.62×39",
		Dollars = 0.36,
		Icon = "ammo_762x39",
		Model = "models/props_lab/box01a.mdl",
	},
	["762x51"] = {
		PrintName = "7.62×51",
		Dollars = 0.55,
		Icon = "ammo_762x51",
		Model = "models/props_lab/box01a.mdl",
	},
	["762x54r"] = {
		PrintName = "7.62×54R",
		Dollars = 0.40,
		Icon = "ammo_762x54r",
		Model = "models/props_lab/box01a.mdl",
	},
	["50bmg"] = {
		PrintName = ".50 BMG",
		Dollars = 2.50,
		Icon = "ammo_50bmg",
		Model = "models/props_lab/box01a.mdl",
	},
}

-- Not cartridges. Nails stay on the 15-pt shelf: PackCount is that box.
-- Medical supplies use the same slider. PackCount 6 is the 15-pt box, so the
-- 5-pt step is 2 charges (6 * 5/15). One charge is 25 health on the medkit.
GM.RelapseShopPackOrder = {
	"battery",
	"gaussenergy",
}

GM.RelapseShopPacks = {
	["battery"] = {
		PrintName = "Medical Supplies",
		Icon = "ammo_medpower",
		PackCount = 6,
	},
	["gaussenergy"] = {
		PrintName = "Nails",
		Icon = "ammo_nail",
		PackCount = 4,
		NoClassicMode = true,
	},
}

function GM:GetRelapseAmmo(ammoOrId)
	if istable(ammoOrId) then
		if ammoOrId.PackCount and not ammoOrId.Dollars then
			return nil
		end
		return ammoOrId
	end
	if not isstring(ammoOrId) or ammoOrId == "" then
		return nil
	end

	local ammo = self.RelapseAmmo and self.RelapseAmmo[string.lower(ammoOrId)]
	return ammo
end

function GM:GetRelapseShopPack(ammoOrId)
	if istable(ammoOrId) then
		if ammoOrId.PackCount then
			return ammoOrId
		end
		return nil
	end
	if not isstring(ammoOrId) or ammoOrId == "" then
		return nil
	end

	local packs = self.RelapseShopPacks
	return packs and packs[string.lower(ammoOrId)]
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
	if not self:GetRelapseAmmo(ammoOrId) and not self:GetRelapseShopPack(ammoOrId) then
		return 1
	end

	return self.RelapseAmmoPrice.ShopPoints or 15
end

function GM:GetAmmoShopCount(ammoOrId)
	local pack = self:GetRelapseShopPack(ammoOrId)
	if pack then
		return math.max(1, math.floor((tonumber(pack.PackCount) or 1) + 0.5))
	end

	local ammo = self:GetRelapseAmmo(ammoOrId)
	if not ammo then
		return 1
	end

	local roundPts = self:GetAmmoRoundPoints(ammo)
	if not roundPts or roundPts <= 0 then
		return 3
	end

	local shop = self.RelapseAmmoPrice.ShopPoints or 15
	local n = math.max(1, math.floor(shop / roundPts + 0.5))
	n = math.floor(n / 3 + 0.5) * 3
	return math.max(3, n)
end

function GM:ClampAmmoPackPoints(pts)
	local price = self.RelapseAmmoPrice
	local min = price.ShopPointsMin or 5
	local max = price.ShopPointsMax or 75
	local step = price.ShopPointsStep or 5
	pts = tonumber(pts)
	if not pts then
		pts = price.ShopPoints or 15
	end

	pts = math.floor(pts / step + 0.5) * step
	return math.Clamp(pts, min, max)
end

function GM:GetAmmoPackCountForPoints(ammoOrId, pts)
	local base = self:GetAmmoShopCount(ammoOrId)
	local shop = self.RelapseAmmoPrice.ShopPoints or 15
	if shop <= 0 or base <= 0 then
		return 1
	end

	pts = self:ClampAmmoPackPoints(pts)
	return math.max(1, math.floor(base * pts / shop + 0.5))
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
	if self.RelapseShopPacks and self.RelapseShopPacks[lower] then
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
		ammo.ShopCount = self:GetAmmoShopCount(ammo)
		self.AmmoCache[id] = ammo.ShopCount
		self.AmmoNames[id] = ammo.PrintName
		self.AmmoIcons[id] = ammo.Icon
		self.AmmoModels[id] = ammo.Model
		self.AmmoResupply[id] = true
		self.AmmoToPurchaseNames[id] = "ammo_" .. id
	end

	self.AmmoToPurchaseNames["gaussenergy"] = "ammo_gaussenergy"
	self.AmmoToPurchaseNames["battery"] = "ammo_battery"
end

function GM:RegisterRelapseAmmoShopItems()
	if not self.RelapseAmmo or not self.RelapseAmmoOrder then
		return
	end

	local price = self.RelapseAmmoPrice
	local function addPack(ammoId, ammo)
		if not ammo then return end

		local shopCount = self:GetAmmoShopCount(ammo) or 1
		local shopPts = self:GetAmmoShopPoints(ammo) or 15
		local shop = self:AddPointShopItem("ammo_" .. ammoId, ITEMCAT_AMMO, shopPts, nil, ammo.PrintName, nil, ammo.Icon, function(pl)
			pl:GiveAmmo(shopCount, ammoId, true)
		end)
		shop.AmmoPack = ammoId
		shop.AmmoCount = shopCount

		local start = self:AddStartingItem("ammo_" .. ammoId, ITEMCAT_AMMO, shopPts, nil, ammo.PrintName, nil, ammo.Icon, function(pl)
			pl:GiveAmmo(shopCount, ammoId, true)
		end)
		start.AmmoPack = ammoId
		start.AmmoCount = shopCount
		start.AmmoPackScale = true

		local count2 = shopCount * 2
		local worth2 = math.max(1, math.floor(shopPts * 2 * price.Worth2Mul + 0.5))
		local start2 = self:AddStartingItem("2ammo_" .. ammoId, ITEMCAT_AMMO, worth2, nil, ammo.PrintName, nil, ammo.Icon, function(pl)
			pl:GiveAmmo(count2, ammoId, true)
		end)
		start2.AmmoPack = ammoId
		start2.AmmoCount = count2
		start2.WorthHidden = true

		local count3 = shopCount * 3
		local worth3 = math.max(1, math.floor(shopPts * 3 * price.Worth3Mul + 0.5))
		local start3 = self:AddStartingItem("3ammo_" .. ammoId, ITEMCAT_AMMO, worth3, nil, ammo.PrintName, nil, ammo.Icon, function(pl)
			pl:GiveAmmo(count3, ammoId, true)
		end)
		start3.AmmoPack = ammoId
		start3.AmmoCount = count3
		start3.WorthHidden = true

		if ammo.NoClassicMode then
			shop.NoClassicMode = true
			start.NoClassicMode = true
			start2.NoClassicMode = true
			start3.NoClassicMode = true
		end
	end

	for _, id in ipairs(self.RelapseAmmoOrder) do
		addPack(id, self.RelapseAmmo[id])
	end
	for _, id in ipairs(self.RelapseShopPackOrder or {}) do
		addPack(id, self.RelapseShopPacks and self.RelapseShopPacks[id])
	end
end

GM:BindRelapseAmmoTables()

if CLIENT then
	function GM:GetAmmoPackRememberMode()
		local remember = GetConVar("zs_ammopackremember")
		if not remember or not remember:GetBool() then
			return "off"
		end

		local cv = GetConVar("zs_ammopackremembermode")
		local mode = string.lower(cv and cv:GetString() or "window")
		if mode == "game" or mode == "always" or mode == "window" then
			return mode
		end

		return "window"
	end

	function GM:GetClientAmmoPackPoints()
		local def = self:ClampAmmoPackPoints(GetConVar("zs_ammopackpoints") and GetConVar("zs_ammopackpoints"):GetInt())
		if self:GetAmmoPackRememberMode() ~= "always" and self.AmmoPackPointsSession then
			return self:ClampAmmoPackPoints(self.AmmoPackPointsSession)
		end

		return def
	end

	function GM:GetPointShopAmmoPrice(item)
		if item and item.AmmoPack and (item.PointShop or item.AmmoPackScale) then
			return self:GetClientAmmoPackPoints()
		end

		return item and item.Price or 0
	end

	function GM:BeginAmmoPackShopVisit()
		local mode = self:GetAmmoPackRememberMode()
		if mode ~= "game" then
			self.AmmoPackPointsSession = nil
		end
	end

	function GM:ClearAmmoPackTabSession()
		if self:GetAmmoPackRememberMode() == "off" then
			self.AmmoPackPointsSession = nil
		end
	end

	function GM:SetClientAmmoPackPoints(pts)
		pts = self:ClampAmmoPackPoints(pts)
		if self:GetAmmoPackRememberMode() == "always" then
			self.AmmoPackPointsSession = nil
			local cv = GetConVar("zs_ammopackpoints")
			if cv and cv:GetInt() ~= pts then
				cv:SetInt(pts)
			end
		else
			self.AmmoPackPointsSession = pts
		end

		if RelapseUI and RelapseUI.SyncAmmoPackSliders then
			RelapseUI.SyncAmmoPackSliders()
		end
		if self.RefreshAmmoPackShopUI then
			self:RefreshAmmoPackShopUI()
		end
	end

	function GM:RunPointsShopBuy(id, usescrap)
		local item = FindItem and FindItem(id)
		if item and item.PointShop and item.AmmoPack then
			local pts = self:GetClientAmmoPackPoints()
			local frame = self.ArsenalInterface
			local card = IsValid(frame) and frame.SelectedBuy
			if not (IsValid(card) and card.ID == id) and IsValid(frame) and frame.ArsenalCards then
				card = frame.ArsenalCards[id] or frame.ArsenalCards["ps_" .. tostring(id)]
			end
			if IsValid(card) and card.RelapseAmmoPackPts then
				pts = card.RelapseAmmoPackPts
			end
			if usescrap then
				RunConsoleCommand("zs_pointsshopbuy", id, "scrap", pts)
			else
				RunConsoleCommand("zs_pointsshopbuy", id, pts)
			end
			return
		end

		RunConsoleCommand("zs_pointsshopbuy", id, usescrap and "scrap" or "")
	end
end
