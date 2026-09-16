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
local function GetStartingWorth()
	return GAMEMODE.StartingWorth + ExtraStartingWorth
end

net.Receive("zs_extrastartingworth", function(len)
	ExtraStartingWorth = net.ReadUInt(16)
end)

CreateClientConVar("zs_defaultcart", "", true, false)

local remainingworth = 0
local WorthButtons = {}

local function Checkout(tobuy)
	if tobuy and #tobuy > 0 then
		gamemode.Call("SuppressArsenalUpgrades", 1)

		RunConsoleCommand("worthcheckout", unpack(tobuy))

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

	remainingworth = GetStartingWorth()

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

		local itemframe = vgui.Create("DScrollPanel", propertysheet)
		itemframe.Paint = function() return true end
		RelapseUI.StyleScroll(itemframe)
		local trinkets = catid == ITEMCAT_TRINKETS

		local list = RelapseUI.MakeShopGrid(itemframe, L, trinkets)

		local sheet = propertysheet:AddSheet(RelapseUI.ShopCat(catid), itemframe, GAMEMODE.ItemCategoryIcons[catid], false, false)
		sheet.Panel:SetPos(0, tabhei + tabGap)

		for i, tab in ipairs(GAMEMODE.Items) do
			if tab.Category == catid and tab.WorthShop then
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

	GAMEMODE:CreateItemInfoViewer(frame, propertysheet, topspace, bottomspace, MENU_WORTH)
	GAMEMODE:ConfigureMenuTabs(tabs, tabhei)

	GAMEMODE:PrecacheKillicons()
	RelapseUI.FinishShopFrame(frame, propertysheet)

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
		self.ModelFrame:SetVisible(false)
		self.ItemCounter:SetVisible(false)
		self.NameLabel:SetText("")
		return
	end

	self.Signature = tab.Signature
	self.Price = tab.Price

	local missing_skill = tab.SkillRequirement and not (IsValid(MySelf) and MySelf:IsSkillActive(tab.SkillRequirement))

	local nottrinkets = tab.Category ~= ITEMCAT_TRINKETS
	self:SetCardSize(self.CardW or self:GetWide(), nottrinkets and m.cardH or m.trinketH)

	if nottrinkets then
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
		self.PriceLabel:SetText(GAMEMODE.Skills[tab.SkillRequirement].Name)
	elseif tab.Price then
		self.PriceLabel:SetTextColor(RelapseUI.Col.Accent)
		self.PriceLabel:SetText(tostring(tab.Price))
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

	self.NameLabel:SetText(RelapseUI.WepName(tab))
	self.NameLabel:SetTextColor(RelapseUI.Col.Text)
	self.NameLabel:SizeToContents()
	self:InvalidateLayout()
end

function PANEL:Paint(w, h)
	local unaffordable = not self.On and remainingworth < (self.Price or 0)
	RelapseUI.PaintCard(self, w, h, self.On, self.Locked, unaffordable)
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

	if self.On then
		self.On = nil
		if not silent then
			surface.PlaySound("buttons/button18.wav")
		end
		remainingworth = remainingworth + tab.Price
	elseif tab.SkillRequirement and not (IsValid(MySelf) and MySelf:IsSkillActive(tab.SkillRequirement)) then
		surface.PlaySound("buttons/button8.wav")
		return
	else
		if remainingworth < tab.Price then
			if not force then
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
		remainingworth = remainingworth - tab.Price
	end

	RelapseUI.UpdateWorthLabel(pWorth.WorthLab, remainingworth, GetStartingWorth())

	return goodcart
end

vgui.Register("ZSWorthButton", PANEL, "DButton")
