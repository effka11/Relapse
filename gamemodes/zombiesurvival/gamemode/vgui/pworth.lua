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

local cvarDefaultCart = CreateClientConVar("zs_defaultcart", "", true, false)

local function DefaultDoClick(btn)
	if cvarDefaultCart:GetString() == btn.Name then
		RunConsoleCommand("zs_defaultcart", "")
		surface.PlaySound("buttons/button11.wav")
	else
		RunConsoleCommand("zs_defaultcart", btn.Name)
		surface.PlaySound("buttons/button14.wav")
	end

	timer.Simple(0.1, MakepWorth)
end

local remainingworth = 0
local WorthButtons = {}

local function CartHasItems()
	for _, btn in pairs(WorthButtons) do
		if IsValid(btn) and btn.On then
			return true
		end
	end
	return false
end

local function SyncWorthCheckout()
	if pWorth and pWorth:IsValid() and IsValid(pWorth.Checkout) then
		pWorth.Checkout.RelapseArmed = CartHasItems()
	end
end

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

local function ClickWorthButton(id)
	local result = true
	for _, btn in pairs(WorthButtons) do
		if not btn then continue end

		if btn.ID == id or btn.Signature == id then
			result = btn:DoClick(true, true)
			break
		end
	end
	return result
end

local function LoadCart(cartid, silent)
	if not GAMEMODE.SavedCarts[cartid] then return end

	MakepWorth()

	for _, id in pairs(GAMEMODE.SavedCarts[cartid][2]) do
		if not ClickWorthButton(id) then
			surface.PlaySound("buttons/button8.wav")
			return false
		end
	end

	if not silent then
		surface.PlaySound("buttons/combine_button1.wav")
	end

	return true
end

local function LoadDoClick(self)
	LoadCart(self.ID)
end

local function SaveCurrentCart(name)
	local tobuy = {}
	for _, btn in pairs(WorthButtons) do
		if btn and btn.On and btn.ID then
			table.insert(tobuy, FindStartingItem(btn.ID).Signature)
		end
	end

	for i, cart in ipairs(GAMEMODE.SavedCarts) do
		if string.lower(cart[1]) == string.lower(name) then
			cart[1] = name
			cart[2] = tobuy

			file.Write(GAMEMODE.CartFile, Serialize(GAMEMODE.SavedCarts))
			print("Saved cart "..tostring(name))

			LoadCart(i, true)
			return
		end
	end

	GAMEMODE.SavedCarts[#GAMEMODE.SavedCarts + 1] = {name, tobuy}

	file.Write(GAMEMODE.CartFile, Serialize(GAMEMODE.SavedCarts))
	print("Saved cart "..tostring(name))

	LoadCart(#GAMEMODE.SavedCarts, true)
end

local function SaveDoClick(self)
	local frame = Derma_StringRequest("Save cart", "Enter a name for this cart.", "Name",
	function(strTextOut) SaveCurrentCart(strTextOut) end,
	function(strTextOut) end,
	"OK", "Cancel")

	frame:GetChildren()[5]:GetChildren()[2]:SetTextColor(RelapseUI.Col.Ink)
end

local function DeleteDoClick(self)
	if GAMEMODE.SavedCarts[self.ID] then
		table.remove(GAMEMODE.SavedCarts, self.ID)
		file.Write(GAMEMODE.CartFile, Serialize(GAMEMODE.SavedCarts))
		surface.PlaySound("buttons/button19.wav")
		MakepWorth()
	end
end

local function QuickCheckDoClick(self)
	if GAMEMODE.SavedCarts[self.ID] and LoadCart(self.ID, true) then
		Checkout(GAMEMODE.SavedCarts[self.ID][2])
	end
end

local function WorthThink(self)
	if MySelf:Team() ~= TEAM_HUMAN then
		self:Close()
	end
end

function MakepWorth()
	if pWorth and pWorth:IsValid() then
		pWorth:Remove()
		pWorth = nil
	end

	remainingworth = GetStartingWorth()
	RelapseUI.CreateFonts()

	local m = RelapseUI.M()
	local gridW = RelapseUI.Cells(45)
	local cardGap = m.cardGap
	local cardW = math.floor((gridW - cardGap) / 2)
	local sheetW = gridW + m.scroll
	local needW = 2 * m.pad + sheetW + RelapseUI.ViewerGap() + m.sidebar
	local cols = math.ceil(needW / m.step)
	local wid, hei, m = RelapseUI.FrameSize(cols, 51)
	local pad = m.pad
	local headerh = m.header
	local footerh = m.footer
	local tabhei = m.tabs
	local tabGap = m.tabGap
	local innerW = wid - 2 * pad
	local sheetH = hei - headerh - footerh

	local frame = vgui.Create("DFrame")
	pWorth = frame
	frame:SetSize(wid, hei)
	frame:SetDeleteOnClose(true)
	frame:SetKeyboardInputEnabled(false)
	frame:SetTitle("")
	frame:SetDraggable(true)
	frame:DockPadding(0, 0, 0, 0)
	frame.Think = WorthThink
	frame.RelapseFooter = footerh
	frame.Paint = RelapseUI.PaintWindow
	RelapseUI.HideChrome(frame)

	local title = EasyLabel(frame, "Worth Shop", "Relapse32", RelapseUI.Col.Text)
	title:SetPos(pad, (headerh - title:GetTall()) * 0.5)

	local close = vgui.Create("DButton", frame)
	close:SetText("×")
	close:SetFont("Relapse32")
	close:SetSize(m.close, m.close)
	close:AlignRight(pad)
	close:AlignTop((headerh - m.close) * 0.5)
	close.Paint = RelapseUI.PaintGhostButton
	close.DoClick = function() frame:Close() end

	local topspace = vgui.Create("DPanel", frame)
	topspace:SetPaintBackground(false)
	topspace:SetSize(innerW, 0)
	topspace:SetPos(pad, headerh)

	local bottomspace = vgui.Create("DPanel", frame)
	bottomspace:SetPaintBackground(false)
	bottomspace:SetSize(innerW, footerh)
	bottomspace:SetPos(pad, hei - footerh)

	local propertysheet = vgui.Create("DPropertySheet", frame)
	propertysheet:SetSize(sheetW, sheetH)
	propertysheet:SetPos(pad, headerh)
	propertysheet:SetPadding(0)
	propertysheet.Paint = RelapseUI.PaintSheet

	local list = vgui.Create("DPanelList", propertysheet)
	local sheet = propertysheet:AddSheet("Favorites", list, "icon16/heart.png", false, false)
	sheet.Panel:SetPos(0, tabhei + tabGap)
	list:EnableVerticalScrollbar(true)
	RelapseUI.StyleScroll(list)
	list:SetWide(sheetW)
	list:SetSpacing(m.gutter)
	list:SetPadding(m.cardPad)

	local savebutton = EasyButton(nil, "Save current loadout", RelapseUI.sPx(8), RelapseUI.sPx(6))
	savebutton.DoClick = SaveDoClick
	savebutton:SetFont("Relapse15")
	savebutton:SetTextColor(RelapseUI.Col.Text)
	savebutton.Paint = RelapseUI.PaintGhostButton
	list:AddItem(savebutton)

	local panfont = "Relapse15"
	local panhei = m.btnH

	local defaultcart = cvarDefaultCart:GetString()

	for i, savetab in ipairs(GAMEMODE.SavedCarts) do
		local cartpan = vgui.Create("DPanel")
		cartpan:SetCursor("pointer")
		cartpan:SetSize(list:GetWide(), panhei)
		cartpan.Paint = function(self, w, h)
			RelapseUI.PaintCard(self, w, h, false, false, false)
		end

		local cartname = savetab[1]

		local x = m.cardPad
		local limitedscale = 1

		if defaultcart == cartname then
			local defimage = vgui.Create("DImage", cartpan)
			defimage:SetImage("icon16/heart.png")
			defimage:SizeToContents()
			defimage:SetSize(16 * limitedscale, 16 * limitedscale)
			defimage:SetMouseInputEnabled(true)
			defimage:SetTooltip("This is your default cart.\nIf you join the game late then you'll spawn with this cart.")
			defimage:SetPos(x, cartpan:GetTall() * 0.5 - defimage:GetTall() * 0.5)
			x = x + defimage:GetWide() + 8
		end

		local cartnamelabel = EasyLabel(cartpan, cartname, panfont, RelapseUI.Col.Text)
		cartnamelabel:SetPos(x, cartpan:GetTall() * 0.5 - cartnamelabel:GetTall() * 0.5)

		x = cartpan:GetWide()

		local checkbutton = vgui.Create("DImageButton", cartpan)
		checkbutton:SetImage("icon16/accept.png")
		checkbutton:SizeToContents()
		checkbutton:SetSize(16 * limitedscale, 16 * limitedscale)
		checkbutton:SetTooltip("Purchase this saved cart.")
		x = x - checkbutton:GetWide() - 12
		checkbutton:SetPos(x, cartpan:GetTall() * 0.5 - checkbutton:GetTall() * 0.5)
		checkbutton.ID = i
		checkbutton.DoClick = QuickCheckDoClick

		local loadbutton = vgui.Create("DImageButton", cartpan)
		loadbutton:SetImage("icon16/folder_go.png")
		loadbutton:SizeToContents()
		loadbutton:SetSize(16 * limitedscale, 16 * limitedscale)
		loadbutton:SetTooltip("Load this saved cart.")
		x = x - loadbutton:GetWide() - 8
		loadbutton:SetPos(x, cartpan:GetTall() * 0.5 - loadbutton:GetTall() * 0.5)
		loadbutton.ID = i
		loadbutton.DoClick = LoadDoClick

		local defaultbutton = vgui.Create("DImageButton", cartpan)
		defaultbutton:SetImage("icon16/heart.png")
		defaultbutton:SizeToContents()
		defaultbutton:SetSize(16 * limitedscale, 16 * limitedscale)
		if cartname == defaultcart then
			defaultbutton:SetTooltip("Remove this cart as your default.")
		else
			defaultbutton:SetTooltip("Make this cart your default.")
		end
		x = x - defaultbutton:GetWide() - 8
		defaultbutton:SetPos(x, cartpan:GetTall() * 0.5 - defaultbutton:GetTall() * 0.5)
		defaultbutton.Name = cartname
		defaultbutton.DoClick = DefaultDoClick

		local deletebutton = vgui.Create("DImageButton", cartpan)
		deletebutton:SetImage("icon16/bin.png")
		deletebutton:SizeToContents()
		deletebutton:SetSize(16 * limitedscale, 16 * limitedscale)
		deletebutton:SetTooltip("Delete this saved cart.")
		x = x - deletebutton:GetWide() - 8
		deletebutton:SetPos(x, cartpan:GetTall() * 0.5 - loadbutton:GetTall() * 0.5)
		deletebutton.ID = i
		deletebutton.DoClick = DeleteDoClick

		list:AddItem(cartpan)
	end

	for catid, catname in ipairs(GAMEMODE.ItemCategories) do
		local itemframe = vgui.Create("DScrollPanel", propertysheet)
		itemframe.Paint = function() return true end
		RelapseUI.StyleScroll(itemframe)
		local trinkets = catid == ITEMCAT_TRINKETS

		list = vgui.Create("DGrid", itemframe)
		list:SetSize(gridW, sheetH - tabhei - tabGap)
		list:SetCols(2)
		list:SetColWide(cardW + cardGap)
		list:SetRowHeight((trinkets and m.trinketH or m.cardH) + cardGap)

		sheet = propertysheet:AddSheet(catname, itemframe, GAMEMODE.ItemCategoryIcons[catid], false, false)
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
	checkout:SetText("Checkout")
	checkout:SetSize(RelapseUI.Cells(12), m.btnH)
	RelapseUI.AlignFooterRight(checkout)
	RelapseUI.AlignFooterBottom(checkout)
	checkout.Paint = RelapseUI.PaintPrimaryButton
	checkout.DoClick = CheckoutDoClick
	checkout.RelapseArmed = false
	frame.Checkout = checkout

	local clearbutton = vgui.Create("DButton", bottomspace)
	clearbutton:SetFont("Relapse20")
	clearbutton:SetText("Clear")
	clearbutton:SetSize(RelapseUI.Cells(6), m.btnH)
	clearbutton:MoveLeftOf(checkout, m.gutter)
	RelapseUI.AlignFooterBottom(clearbutton)
	clearbutton.Paint = RelapseUI.PaintGhostButton
	clearbutton.DoClick = ClearCartDoClick

	local worthbox = vgui.Create("DPanel", bottomspace)
	worthbox:SetPaintBackground(false)

	local worthcap = EasyLabel(worthbox, "WORTH:", "Relapse30", RelapseUI.Col.Muted)
	worthcap:SetVisible(false)

	local worthlab = EasyLabel(worthbox, tostring(remainingworth), "Relapse45", RelapseUI.Col.Ok)
	worthlab:SetVisible(false)
	worthlab.RelapseAfter = worthcap
	worthlab.RelapseBottomOf = checkout
	worthbox.Paint = function(me, w, h)
		RelapseUI.PaintWorthChip(worthcap, worthlab, w, h)
		return true
	end
	RelapseUI.LayoutWorthChip(worthlab)
	frame.WorthLab = worthlab
	frame.WorthChip = worthbox

	frame:Center()

	local tabs = {}
	for i, item in ipairs(propertysheet.Items or {}) do
		tabs[i] = item.Tab
	end

	GAMEMODE:CreateItemInfoViewer(frame, propertysheet, topspace, bottomspace, MENU_WORTH)
	GAMEMODE:ConfigureMenuTabs(tabs, tabhei, function(tabpanel)
		pWorth.Viewer:SetVisible(tabpanel ~= tabs[1])
	end)

	if #GAMEMODE.SavedCarts == 0 then
		propertysheet:SetActiveTab(propertysheet.Items[math.min(2, #propertysheet.Items)].Tab)
	else
		propertysheet:SwitchToName("Favorites")
	end

	GAMEMODE:PrecacheKillicons()
	RelapseUI.WarmPropertySheet(propertysheet)

	frame:SetAlpha(0)
	frame:AlphaTo(255, 0.12, 0)
	frame:MakePopup()

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
	local m = RelapseUI.M()
	local pad = m.cardPad
	cardh = cardh or m.cardH
	local top = pad + RelapseUI.Grid5(4)
	local fw = math.min(cardw - 2 * pad, RelapseUI.Grid15(10))
	local fh = math.max(m.step, cardh - top - pad)
	frame:SetSize(fw, fh)
	frame:SetPos(math.floor((cardw - fw) * 0.5 + 0.5), top)
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

	self.PriceLabel = EasyLabel(self, "", "Relapse15")
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

	local missing_skill = tab.SkillRequirement and not MySelf:IsSkillActive(tab.SkillRequirement)

	local nottrinkets = tab.Category ~= ITEMCAT_TRINKETS
	self:SetCardSize(self.CardW or self:GetWide(), nottrinkets and m.cardH or m.trinketH)

	if nottrinkets then
		PlaceKilliconFrame(self.ModelFrame, self:GetWide(), self.CardH)
		self.ModelFrame:SetVisible(true)
		for _, ch in ipairs(self.ModelFrame:GetChildren()) do
			if IsValid(ch) then ch:Remove() end
		end
		local kitbl = killicon.Get(GAMEMODE.ZSInventoryItemData[tab.SWEP] and "weapon_zs_craftables" or tab.SWEP or tab.Model)
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

	if tab.SWEP or tab.Countables then
		self.ItemCounter:SetItemID(id)
		self.ItemCounter:SetVisible(true)
	else
		self.ItemCounter:SetVisible(false)
	end

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

	self:SetTooltip(tab.Description)

	self.Locked = missing_skill or tab.NoClassicMode and GAMEMODE:IsClassicMode() or tab.NoZombieEscape and GAMEMODE.ZombieEscape

	if not nottrinkets and tab.SubCategory then
		local catlabel = EasyLabel(self, GAMEMODE.ItemSubCategories[tab.SubCategory], "Relapse13", RelapseUI.Col.Muted)
		catlabel:SizeToContents()
		catlabel:SetPos(inset, self:GetTall() * 0.55 - catlabel:GetTall() * 0.5)
	end

	self.NameLabel:SetText(tab.Name or "")
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
	elseif tab.SkillRequirement and not MySelf:IsSkillActive(tab.SkillRequirement) then
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
	SyncWorthCheckout()

	return goodcart
end

vgui.Register("ZSWorthButton", PANEL, "DButton")
