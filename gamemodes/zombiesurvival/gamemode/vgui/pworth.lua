function InitialWorthMenu()
	timer.Create("WaitUntilSkillsLoaded", 0, 0, function()
		if GAMEMODE.ReceivedInitialSkills then
			timer.Remove("WaitUntilSkillsLoaded")
			MakepWorth()
		end
	end)
end

hook.Add("SetWave", "CloseWorthOnWave1", function(wave)
	if wave > 0 then
		if pWorth and pWorth:IsValid() then
			pWorth:Close()
		end

		hook.Remove("SetWave", "CloseWorthOnWave1")
	end
end)

local ExtraStartingWorth = 0
local RemainingStartingWorth
local remainingworth = 0
local WorthButtons = {}

local function GetStartingWorth()
	return GAMEMODE.StartingWorth + ExtraStartingWorth
end

local function GetSpendableWorth()
	if RemainingStartingWorth ~= nil then
		return RemainingStartingWorth
	end
	return GetStartingWorth()
end

local function WorthLinkedAmmo()
	local linked = {}
	if IsValid(MySelf) then
		for _, wep in pairs(MySelf:GetWeapons()) do
			if not IsValid(wep) then continue end
			local ammo = GAMEMODE.GetWeaponAmmoType and GAMEMODE:GetWeaponAmmoType(wep)
			if not ammo then
				ammo = RelapseUI.ShopItemAmmoId({ SWEP = wep:GetClass() })
			end
			if ammo then
				linked[string.lower(ammo)] = true
			end
		end
	end
	for _, btn in pairs(WorthButtons) do
		if not (IsValid(btn) and btn.On) then continue end
		local tab = FindStartingItem(btn.ID)
		local ammo = RelapseUI.ShopItemAmmoId(tab)
		if ammo then
			linked[string.lower(ammo)] = true
		end
	end
	return linked
end

function GM:RefreshWorthAmmoPackUI()
	if not IsValid(pWorth) then return end
	if pWorth._WorthCheckout or pWorth._RelapseClosing then return end

	local left = GetSpendableWorth()
	for _, btn in pairs(WorthButtons) do
		if not IsValid(btn) then continue end

		local tab = FindStartingItem(btn.ID)
		if tab then
			if tab.AmmoPackScale then
				if not btn.RelapseAmmoPackPts then
					btn.Price = GAMEMODE:GetClientAmmoPackPoints()
				end
				if IsValid(btn.PriceLabel) then
					btn.PriceLabel:SetText(tostring(btn.Price))
					btn.PriceLabel:SizeToContents()
				end
				RelapseUI.BindShopAmmoName(btn.NameLabel, tab, btn.RelapseAmmoPackPts)
				btn:InvalidateLayout()
			end
			if btn.On then
				left = left - (btn.Price or tab.Price)
			end
		end
	end

	remainingworth = left
	RelapseUI.UpdateWorthLabel(pWorth.WorthLab, remainingworth, GetStartingWorth())
	RelapseUI.SyncAmmoCardLinks(WorthButtons, WorthLinkedAmmo())
end

net.Receive("zs_extrastartingworth", function(len)
	ExtraStartingWorth = net.ReadUInt(16)
	if RemainingStartingWorth == nil and IsValid(pWorth) then
		GAMEMODE:RefreshWorthAmmoPackUI()
	end
end)

net.Receive("zs_remainingstartingworth", function(len)
	RemainingStartingWorth = net.ReadInt(16)
	if IsValid(pWorth) and not pWorth._WorthCheckout and not pWorth._RelapseClosing then
		GAMEMODE:RefreshWorthAmmoPackUI()
	end
end)

CreateClientConVar("zs_defaultcart", "", true, false)

local function Checkout(tobuy)
	if tobuy and #tobuy > 0 then
		gamemode.Call("SuppressArsenalUpgrades", 1)

		local pack = GAMEMODE.GetClientAmmoPackPoints and GAMEMODE:GetClientAmmoPackPoints() or 15
		RemainingStartingWorth = remainingworth
		if IsValid(pWorth) then
			pWorth._WorthCheckout = true
		end
		RunConsoleCommand("worthcheckout", "pack:" .. pack, unpack(tobuy))

		if pWorth and pWorth:IsValid() then
			pWorth:Close()
		end
	else
		surface.PlaySound("buttons/combine_button_locked.wav")
	end
end

local function CheckoutDoClick(self)
	local tobuy = {}
	for _, btn in pairs(WorthButtons) do
		if btn and btn.On and btn.ID then
			table.insert(tobuy, btn.ID)
			if btn.RelapseAmmoPackPts then
				table.insert(tobuy, "packid:" .. tostring(btn.ID) .. ":" .. btn.RelapseAmmoPackPts)
			end
		end
	end

	if remainingworth >= 0 then
		Checkout(tobuy)
	else
		surface.PlaySound("buttons/button8.wav")
	end
end

GM.SavedCarts = {}
hook.Add("Initialize", "LoadCarts", function()
	if file.Exists(GAMEMODE.CartFile, "DATA") then
		GAMEMODE.SavedCarts = Deserialize(file.Read(GAMEMODE.CartFile)) or {}
	end
end)

local function ClearCartDoClick()
	for _, btn in ipairs(WorthButtons) do
		if btn.On then
			btn:DoClick(true, true)
		end
	end

	surface.PlaySound("buttons/button11.wav")
end

local function WorthThink(self)
	if not IsValid(MySelf) then return end
	if MySelf:Team() ~= TEAM_HUMAN then
		self:Close()
		return
	end
	local classes = {}
	for _, wep in pairs(MySelf:GetWeapons()) do
		if IsValid(wep) then
			classes[#classes + 1] = wep:GetClass()
		end
	end
	table.sort(classes)
	local key = table.concat(classes, ",")
	if self._AmmoLinkKey ~= key then
		self._AmmoLinkKey = key
		RelapseUI.SyncAmmoCardLinks(WorthButtons, WorthLinkedAmmo())
	end
end

function MakepWorth()
	if GAMEMODE.CloseOtherOverlays then
		GAMEMODE:CloseOtherOverlays("shop")
	end
	RelapseUI.HideOtherShops("worth")
	if pWorth and pWorth:IsValid() then
		local host = RelapseUI.MenuHost(pWorth)
		pWorth:Remove()
		if IsValid(host) then
			host:Remove()
		end
		pWorth = nil
	end

	remainingworth = GetSpendableWorth()
	for k in pairs(WorthButtons) do
		WorthButtons[k] = nil
	end

	local frame, L, topspace, bottomspace, propertysheet = RelapseUI.BuildShopFrame("shop_worth_title", {
		shop = "worth"
	})
	pWorth = frame
	frame.Think = WorthThink

	local m = L.m
	local cardW = L.cardW
	local tabhei = L.tabhei
	local tabGap = L.tabGap

	for catid in ipairs(GAMEMODE.ItemCategories) do
		if catid == ITEMCAT_OTHER then continue end

		local hasItems = false
		for _, tab in ipairs(GAMEMODE.Items) do
			if tab.WorthShop and not tab.WorthHidden and tab.Category == catid then
				hasItems = true
				break
			end
		end
		if not hasItems then continue end

		local itemframe = vgui.Create("DScrollPanel", propertysheet)
		itemframe.Paint = function() return true end
		RelapseUI.StyleScroll(itemframe)
		itemframe.RelapseAmmoTab = catid == ITEMCAT_AMMO
		local trinkets = catid == ITEMCAT_TRINKETS

		local list = RelapseUI.MakeShopGrid(itemframe, L, trinkets)

		local sheet = propertysheet:AddSheet(RelapseUI.ShopCat(catid), itemframe, GAMEMODE.ItemCategoryIcons[catid], false, false)
		sheet.Panel:SetPos(0, tabhei + tabGap)

		for i, tab in ipairs(GAMEMODE.Items) do
			if tab.Category == catid and tab.WorthShop and not tab.WorthHidden then
				local button = vgui.Create("ZSWorthButton")
				button:SetCardSize(cardW, trinkets and m.trinketH or m.cardH)
				button:SetWorthID(i)
				list:AddItem(button)
				WorthButtons[i] = button
			end
		end
	end

	local checkout = vgui.Create("DButton", bottomspace)
	checkout:SetFont("Relapse20")
	checkout:SetText(RelapseUI.T("shop_checkout"))
	checkout:SetSize(RelapseUI.Cells(12), m.btnH)
	RelapseUI.AlignFooterRight(checkout)
	RelapseUI.AlignFooterBottom(checkout)
	checkout.Paint = RelapseUI.PaintPrimaryButton
	checkout.DoClick = CheckoutDoClick
	frame.Checkout = checkout

	local clearbutton = vgui.Create("DButton", bottomspace)
	clearbutton:SetFont("Relapse20")
	clearbutton:SetText(RelapseUI.T("shop_clear"))
	clearbutton:SetSize(RelapseUI.Cells(6), m.btnH)
	clearbutton:MoveLeftOf(checkout, m.gutter)
	RelapseUI.AlignFooterBottom(clearbutton)
	clearbutton.Paint = RelapseUI.PaintGhostButton
	clearbutton.DoClick = ClearCartDoClick

	local worthbox, worthcap, worthlab = RelapseUI.CreateShopChip(bottomspace, RelapseUI.T("shop_worth_label"), remainingworth)
	worthlab.RelapseBottomOf = checkout
	frame.WorthLab = worthlab
	frame.WorthChip = worthbox

	local tabs = {}
	for i, item in ipairs(propertysheet.Items or {}) do
		tabs[i] = item.Tab
	end

	local packSlider = RelapseUI.CreateShopAmmoPackSlider(bottomspace, L)
	frame.AmmoPackSlider = packSlider

	local function syncSubTabs(tabpanel)
		local pan = tabpanel and tabpanel.GetPanel and tabpanel:GetPanel()
		local showAmmo = IsValid(pan) and pan.RelapseAmmoTab
		if not showAmmo then
			GAMEMODE:ClearAmmoPackTabSession()
		end
		packSlider:SetVisible(showAmmo)
		if showAmmo then
			RelapseUI.SyncAmmoPackSliders()
			RelapseUI.PlaceShopAmmoPack(packSlider, L)
			GAMEMODE:RefreshWorthAmmoPackUI()
		end
	end
	frame.SyncShopSubTabs = syncSubTabs
	frame.RelapseSheet = propertysheet

	GAMEMODE:CreateItemInfoViewer(frame, propertysheet, topspace, bottomspace, MENU_WORTH)
	GAMEMODE:ConfigureMenuTabs(tabs, tabhei, syncSubTabs)
	GAMEMODE:BeginAmmoPackShopVisit()
	syncSubTabs(propertysheet:GetActiveTab())

	GAMEMODE:PrecacheKillicons()
	RelapseUI.FinishShopFrame(frame, propertysheet)
	RelapseUI.SyncAmmoCardLinks(WorthButtons, WorthLinkedAmmo())

	return frame
end

local PANEL = {}
PANEL.m_ItemID = 0
PANEL.RefreshTime = 1
PANEL.NextRefresh = 0

function PANEL:Init()
	self:SetFont("Relapse13")
end

function PANEL:Think()
	if CurTime() >= self.NextRefresh then
		self.NextRefresh = CurTime() + self.RefreshTime
		self:RefreshWorth()
	end
end

function PANEL:RefreshWorth()
	local count = GAMEMODE:GetCurrentEquipmentCount(self:GetItemID())
	if count == 0 then
		self:SetText(" ")
	else
		self:SetText(count)
	end

	self:SizeToContents()
end

function PANEL:SetItemID(id) self.m_ItemID = id end
function PANEL:GetItemID() return self.m_ItemID end

vgui.Register("ItemAmountCounter", PANEL, "DLabel")

PANEL = {}

local function PlaceKilliconFrame(frame, cardw, cardh)
	RelapseUI.PlaceCardIcon(frame, cardw, cardh)
end

function PANEL:Init()
	self:SetText("")
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)

	local m = RelapseUI.M()
	self:SetCardSize(RelapseUI.Cells(18), m.cardH)

	self.ModelFrame = vgui.Create("DPanel", self)
	PlaceKilliconFrame(self.ModelFrame, self:GetWide(), self.CardH)
	self.ModelFrame:SetVisible(false)
	self.ModelFrame:SetMouseInputEnabled(false)
	self.ModelFrame.Paint = function() end

	self.NameLabel = EasyLabel(self, "", "Relapse20")
	self.NameLabel:SetContentAlignment(4)
	self.NameLabel:SetTextColor(RelapseUI.Col.Text)
	self.NameLabel:DockPadding(0, 0, 0, 0)
	self.NameLabel:DockMargin(0, 0, 0, 0)

	self.PriceLabel = EasyLabel(self, "", "Relapse20")
	self.PriceLabel:SetContentAlignment(6)
	self.PriceLabel:SetTextColor(RelapseUI.Col.Accent)
	self.PriceLabel:DockPadding(0, 0, 0, 0)
	self.PriceLabel:DockMargin(0, 0, 0, 0)

	self.ItemCounter = vgui.Create("ItemAmountCounter", self)

	self:SetWorthID(nil)
end

function PANEL:SetCardSize(w, h)
	self.CardW = w
	self.CardH = h
	self:SetSize(w, h)
end

function PANEL:ApplySchemeSettings()
end

function PANEL:PerformLayout(w, h)
	if self.CardW then
		self:SetSize(self.CardW, self.CardH)
		w, h = self.CardW, self.CardH
	else
		w = w or self:GetWide()
		h = h or self:GetTall()
	end

	local m = RelapseUI.M()
	local inset = m.cardPad

	if IsValid(self.NameLabel) then
		local priceW = IsValid(self.PriceLabel) and self.PriceLabel:GetWide() or 0
		self.NameLabel:SetPos(inset, inset)
		self.NameLabel:SetWide(math.max(0, w - 2 * inset - priceW - m.fine))
	end
	if IsValid(self.PriceLabel) then
		self.PriceLabel:SetPos(w - self.PriceLabel:GetWide() - inset, inset)
	end
	if IsValid(self.ModelFrame) and self.ModelFrame:IsVisible() then
		PlaceKilliconFrame(self.ModelFrame, w, h)
	end
	if IsValid(self.ItemCounter) and self.ItemCounter:IsVisible() then
		self.ItemCounter:SetPos(w - self.ItemCounter:GetWide() - inset, h - self.ItemCounter:GetTall() - inset)
	end
end

function PANEL:SetWorthID(id)
	self.ID = id

	local tab = FindStartingItem(id)
	local m = RelapseUI.M()
	local inset = m.cardPad

	if not tab then
		RelapseUI.ClearCardSilhouette(self)
		self.ModelFrame:SetVisible(false)
		self.ItemCounter:SetVisible(false)
		RelapseUI.BindShopAmmoName(self.NameLabel)
		return
	end

	self.Signature = tab.Signature
	self.Price = GAMEMODE:GetPointShopAmmoPrice(tab)
	if not tab.AmmoPackScale then
		self.Price = (GAMEMODE.GetWorthShopCost and IsValid(MySelf) and GAMEMODE:GetWorthShopCost(MySelf, tab)) or tab.Price
	end

	local missing_skill = GAMEMODE.ItemSkillLocked and GAMEMODE:ItemSkillLocked(MySelf, tab)

	local nottrinkets = tab.Category ~= ITEMCAT_TRINKETS
	self:SetCardSize(self.CardW or self:GetWide(), nottrinkets and m.cardH or m.trinketH)

	if nottrinkets then
		RelapseUI.ClearCardSilhouette(self)
		PlaceKilliconFrame(self.ModelFrame, self:GetWide(), self.CardH)
		self.ModelFrame:SetVisible(true)
		for _, ch in ipairs(self.ModelFrame:GetChildren()) do
			if IsValid(ch) then ch:Remove() end
		end
		local kitbl = killicon.Get(GAMEMODE.ZSInventoryItemData[tab.SWEP] and "weapon_zs_craftables" or tab.SWEP or tab.Model)
		if not RelapseUI.TryAttachCardIcon(self, self.ModelFrame, tab, missing_skill) then
			if kitbl then
				GAMEMODE:AttachKillicon(kitbl, self, self.ModelFrame, tab.Category == ITEMCAT_AMMO, missing_skill)
			elseif tab.Model then
				local mdlpanel = vgui.Create("DModelPanel", self.ModelFrame)
				mdlpanel:SetSize(self.ModelFrame:GetSize())
				mdlpanel:SetModel(tab.Model)
				local mins, maxs = mdlpanel.Entity:GetRenderBounds()
				mdlpanel:SetCamPos(mins:Distance(maxs) * Vector(0.75, 0.75, 0.5))
				mdlpanel:SetLookAt((mins + maxs) / 2)
			end
		end
	end

	self.ItemCounter:SetVisible(false)

	if missing_skill then
		self.PriceLabel:SetTextColor(RelapseUI.Col.Danger)
		self.PriceLabel:SetText(GAMEMODE:GetItemSkillLockName(tab))
	elseif tab.Price then
		self.PriceLabel:SetTextColor(RelapseUI.Col.Accent)
		self.PriceLabel:SetText(tostring(self.Price))
	else
		self.PriceLabel:SetText("")
	end
	self.PriceLabel:SizeToContents()

	self.Locked = missing_skill or tab.NoClassicMode and GAMEMODE:IsClassicMode() or tab.NoZombieEscape and GAMEMODE.ZombieEscape

	if not nottrinkets and tab.SubCategory then
		local catlabel = EasyLabel(self, RelapseUI.ShopSubCat(tab.SubCategory), "Relapse13", RelapseUI.Col.Muted)
		catlabel:SizeToContents()
		catlabel:SetPos(inset, self:GetTall() * 0.55 - catlabel:GetTall() * 0.5)
	end

	RelapseUI.BindShopAmmoName(self.NameLabel, tab)
	self:InvalidateLayout()
end

function PANEL:Paint(w, h)
	local unaffordable = not self.On and remainingworth < (self.Price or 0)
	RelapseUI.PaintCard(self, w, h, self.On, self.Locked, unaffordable)
	RelapseUI.PaintShopAmmoLink(self, w, h)
	return true
end

function PANEL:OnCursorEntered()
	local shoptbl = FindStartingItem(self.ID)
	if not shoptbl then return end

	local sweptable = GAMEMODE.ZSInventoryItemData[shoptbl.SWEP] or weapons.Get(shoptbl.SWEP)
	if sweptable --[[and not GAMEMODE.AlwaysQuickBuy]] then
		GAMEMODE:SupplyItemViewerDetail(pWorth.Viewer, sweptable, shoptbl)
	end
end

--[[function PANEL:OnCursorExited()
end]]

function PANEL:DoClick(silent, force)
	local id = self.ID
	local tab = FindStartingItem(id)
	local goodcart = true

	if not tab then return end

	if not silent and RelapseUI.IconsDevSelect then
		RelapseUI.IconsDevSelect(tab, "shop")
	end

	if self.On then
		self.On = nil
		if not silent then
			surface.PlaySound("buttons/button18.wav")
		end
		remainingworth = remainingworth + (self.Price or tab.Price)
		RelapseUI.SetAmmoPackCardFrozen(self, false)
	elseif GAMEMODE.ItemSkillLocked and GAMEMODE:ItemSkillLocked(MySelf, tab) then
		surface.PlaySound("buttons/button8.wav")
		return
	else
		RelapseUI.SetAmmoPackCardFrozen(self, true)
		local price = self.Price or tab.Price
		if remainingworth < price then
			if not force then
				RelapseUI.SetAmmoPackCardFrozen(self, false)
				surface.PlaySound("buttons/button8.wav")
				return
			else
				goodcart = false
			end
		end
		self.On = true
		if not silent then
			surface.PlaySound("buttons/button17.wav")
		end
		remainingworth = remainingworth - price
	end

	RelapseUI.UpdateWorthLabel(pWorth.WorthLab, remainingworth, GetStartingWorth())
	RelapseUI.SyncAmmoCardLinks(WorthButtons, WorthLinkedAmmo())

	return goodcart
end

vgui.Register("ZSWorthButton", PANEL, "DButton")
