local pRelapseInventory
local pRelapseInvShop

local function OverlayOpen(pnl)
	return IsValid(pnl) and (pnl:IsVisible() or pnl._RelapseClosing)
end

local function ModelIds(ownedOnly)
	local ids = {}
	for _, id in ipairs(GAMEMODE.RelapseCosmeticOrder or {}) do
		local item = GAMEMODE:GetRelapseCosmetic(id)
		if item and item.Kind == GAMEMODE.RelapseCosmeticKind.MODEL then
			if ownedOnly then
				if GAMEMODE:PlayerOwnsRelapseItem(id) then
					ids[#ids + 1] = id
				end
			elseif GAMEMODE:RelapseCosmeticForSale(id) then
				ids[#ids + 1] = id
			end
		end
	end
	return ids
end

local function UpdateActionButton(frame)
	if not IsValid(frame) or not IsValid(frame.Action) then return end
	local id = frame.RelapseSelectedId
	local shop = frame.RelapseShopMode
	local current
	if shop then
		current = id and GAMEMODE:PlayerOwnsRelapseItem(id) and true or false
		frame.Action:SetText(current and RelapseUI.T("inv_owned") or RelapseUI.T("shop_purchase"))
		frame.Action.RelapseUnequip = false
		frame.Action.RelapseCurrent = current
		frame.Action:SetCursor(current and "arrow" or "hand")
		frame.Action.Paint = current and RelapseUI.PaintGhostButton or RelapseUI.PaintPrimaryButton
	else
		local equipped = id and id == GAMEMODE:GetRelapseEquippedModelId() and true or false
		frame.Action:SetText(equipped and RelapseUI.T("inv_unequip") or RelapseUI.T("inv_equip"))
		frame.Action.RelapseUnequip = equipped
		frame.Action.RelapseCurrent = false
		frame.Action:SetCursor("hand")
		frame.Action.Paint = RelapseUI.PaintPrimaryButton
	end
end

local function SelectInventoryModel(frame, id, silent)
	if not IsValid(frame) then return end
	local item = GAMEMODE:GetRelapseCosmetic(id)
	if not item then return end

	frame.RelapseSelectedId = id
	for _, btn in ipairs(frame.RelapseCards or {}) do
		if IsValid(btn) then
			btn.On = btn.ItemId == id
		end
	end

	local viewer = frame.Viewer
	if not IsValid(viewer) then return end

	viewer.RelapsePlayerView = true
	viewer.m_Title:SetText(GAMEMODE:RelapseCosmeticName(id))
	viewer.m_Title:PerformLayout()
	viewer.m_Desc:SetText(GAMEMODE:RelapseCosmeticDesc(id))
	viewer.m_AmmoType:SetText("")
	viewer.m_AmmoType:SetVisible(false)
	if IsValid(viewer.m_AmmoIcon) then
		viewer.m_AmmoIcon:SetVisible(false)
	end
	GAMEMODE:ViewerStatBarUpdate(viewer, true, {})
	RelapseUI.SetPlayerPreview(viewer.ModelPanel, item.Model, viewer)
	if IsValid(viewer.m_VBG) then
		viewer.m_VBG:SetVisible(true)
	end
	RelapseUI.LayoutViewerPlayerModel(viewer)
	UpdateActionButton(frame)

	if not silent then
		surface.PlaySound("buttons/button14.wav")
	end
end

local INV_CARD = {}

function INV_CARD:Init()
	self:SetText("")
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	if self.SetPaintBackground then
		self:SetPaintBackground(false)
	end

	local m = RelapseUI.M()
	self:SetCardSize(RelapseUI.Cells(18), m.cardH)

	self.ModelFrame = vgui.Create("DPanel", self)
	RelapseUI.PlaceCardIcon(self.ModelFrame, self:GetWide(), self.CardH)
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
	self.PriceLabel:SetVisible(false)

	self.StatusLabel = EasyLabel(self, "", "Relapse13")
	self.StatusLabel:SetContentAlignment(4)
	self.StatusLabel:SetTextColor(RelapseUI.Col.Muted)
	self.StatusLabel:SetVisible(false)
end

function INV_CARD:SetCardSize(w, h)
	self.CardW = w
	self.CardH = h
	self:SetSize(w, h)
end

function INV_CARD:ApplySchemeSettings()
end

function INV_CARD:PerformLayout(w, h)
	if self.CardW then
		self:SetSize(self.CardW, self.CardH)
		w, h = self.CardW, self.CardH
	else
		w = w or self:GetWide()
		h = h or self:GetTall()
	end

	local m = RelapseUI.M()
	local inset = m.cardPad
	local priceW = 0
	if IsValid(self.PriceLabel) and self.PriceLabel:IsVisible() then
		priceW = self.PriceLabel:GetWide()
		self.PriceLabel:SetPos(w - priceW - inset, inset)
		self.PriceLabel:MoveToFront()
	end
	if IsValid(self.NameLabel) then
		self.NameLabel:SetPos(inset, inset)
		self.NameLabel:SetWide(math.max(0, w - 2 * inset - priceW - (priceW > 0 and m.fine or 0)))
		self.NameLabel:MoveToFront()
	end
	if IsValid(self.StatusLabel) then
		self.StatusLabel:SetPos(inset, h - self.StatusLabel:GetTall() - inset)
	end
	if IsValid(self.ModelFrame) then
		RelapseUI.PlaceCardIcon(self.ModelFrame, w, h)
	end
	if IsValid(self.Preview) then
		self.Preview._RelapsePFW = nil
		self.Preview._RelapsePFH = nil
		RelapseUI.FramePlayerPreview(self.Preview)
	end
end

function INV_CARD:SetItem(id)
	self.ItemId = id
	local item = GAMEMODE:GetRelapseCosmetic(id)
	if not item then return end

	self.NameLabel:SetText(GAMEMODE:RelapseCosmeticName(id))
	self.NameLabel:SizeToContents()

	local owned = GAMEMODE:PlayerOwnsRelapseItem(id)
	self.RelapseOwned = owned
	if self.RelapseShopMode then
		local price = GAMEMODE:RelapseCosmeticMarks(id)
		if price > 0 then
			self.PriceLabel:SetText(tostring(price))
			local short = not owned and (GAMEMODE:GetRelapseMarks() or 0) < price
			self.PriceLabel:SetTextColor(short and RelapseUI.Col.Danger or RelapseUI.Col.Accent)
		else
			self.PriceLabel:SetText("")
		end
		self.PriceLabel:SizeToContents()
		self.PriceLabel:SetVisible(price > 0)
		self.StatusLabel:SetText("")
		self.StatusLabel:SetVisible(false)
	else
		self.PriceLabel:SetText("")
		self.PriceLabel:SetVisible(false)
		local equipped = id == GAMEMODE:GetRelapseEquippedModelId()
		self.StatusLabel:SetText(equipped and RelapseUI.T("inv_equipped") or "")
		self.StatusLabel:SetTextColor(RelapseUI.Col.Muted)
		self.StatusLabel:SizeToContents()
		self.StatusLabel:SetVisible(equipped)
	end

	for _, ch in ipairs(self.ModelFrame:GetChildren()) do
		if IsValid(ch) then ch:Remove() end
	end

	local mdl = vgui.Create("DModelPanelEx", self.ModelFrame)
	mdl:Dock(FILL)
	mdl:SetPaintBackground(false)
	mdl:SetMouseInputEnabled(false)
	mdl.RelapsePlayerPreview = true
	mdl.RelapsePlayerPreviewStatic = true
	mdl:SetModel(item.Model)
	mdl:SetAnimated(false)
	mdl._RelapsePFW = nil
	mdl._RelapsePFH = nil
	RelapseUI.FramePlayerPreview(mdl)
	self.Preview = mdl
	self:InvalidateLayout()
end

function INV_CARD:Paint(w, h)
	RelapseUI.PaintCard(self, w, h, self.On, false, false)
	return true
end

function INV_CARD:DoClick()
	local frame = self.RelapseFrame
	if not IsValid(frame) then return end
	SelectInventoryModel(frame, self.ItemId)
end

vgui.Register("RelapseInvCard", INV_CARD, "DButton")

local function FillModelGrid(frame, ownedOnly)
	if not IsValid(frame) or not IsValid(frame.Grid) then return end

	for _, btn in ipairs(frame.RelapseCards or {}) do
		if IsValid(btn) then
			frame.Grid:RemoveItem(btn)
			btn:Remove()
		end
	end
	frame.RelapseCards = {}

	local keep = frame.RelapseSelectedId
	if keep then
		local item = GAMEMODE:GetRelapseCosmetic(keep)
		if not item then
			keep = nil
		elseif ownedOnly and not GAMEMODE:PlayerOwnsRelapseItem(keep) then
			keep = nil
		elseif not ownedOnly and not GAMEMODE:RelapseCosmeticForSale(keep) then
			keep = nil
		end
	end
	if ownedOnly then
		keep = keep or GAMEMODE:GetRelapseEquippedModelId()
	end

	for _, id in ipairs(ModelIds(ownedOnly)) do
		local button = vgui.Create("RelapseInvCard")
		button:SetCardSize(frame.RelapseCardW, RelapseUI.M().cardH)
		button.RelapseFrame = frame
		button.RelapseShopMode = frame.RelapseShopMode
		button:SetItem(id)
		frame.Grid:AddItem(button)
		frame.RelapseCards[#frame.RelapseCards + 1] = button
		if not keep then
			keep = id
		end
	end

	if keep then
		SelectInventoryModel(frame, keep, true)
	end
	UpdateActionButton(frame)
	if IsValid(frame.MarksLab) then
		RelapseUI.UpdateWorthLabel(frame.MarksLab, GAMEMODE:GetRelapseMarks())
	end
end

local function ApplyShopTab(frame, tab)
	if not IsValid(frame) or not frame.RelapseShopMode then return end
	local marks = IsValid(frame.MarksTab) and tab == frame.MarksTab
	if IsValid(frame.Action) then
		frame.Action:SetVisible(not marks)
	end
	if IsValid(frame.Viewer) then
		frame.Viewer:SetVisible(not marks)
	end
end

local function OpenShopModelsTab(frame)
	if not IsValid(frame) or not IsValid(frame.RelapseSheet) or not IsValid(frame.ModelsTab) then
		return
	end
	frame.RelapseSheet:SetActiveTab(frame.ModelsTab)
	ApplyShopTab(frame, frame.ModelsTab)
end

local function MakeInvWindow(titleKey, shopKind, shopMode)
	local frame, L, topspace, bottomspace, propertysheet = RelapseUI.BuildShopFrame(titleKey, {
		deleteOnClose = false,
		shop = shopKind
	})
	frame.RelapseCardW = L.cardW
	frame.RelapseCards = {}
	frame.RelapseShopMode = shopMode and true or false
	frame.RelapseSheet = propertysheet

	if shopMode then
		local marksframe = vgui.Create("DScrollPanel", propertysheet)
		marksframe.Paint = function() return true end
		RelapseUI.StyleScroll(marksframe)
		local marksSheet = propertysheet:AddSheet(RelapseUI.T("inv_tab_marks"), marksframe, nil, false, false)
		frame.MarksTab = marksSheet.Tab
	end

	local itemframe = vgui.Create("DScrollPanel", propertysheet)
	itemframe.Paint = function() return true end
	RelapseUI.StyleScroll(itemframe)
	frame.Grid = RelapseUI.MakeShopGrid(itemframe, L, false)

	local modelSheet = propertysheet:AddSheet(RelapseUI.T("inv_tab_models"), itemframe, nil, false, false)
	frame.ModelsTab = modelSheet.Tab

	local tabs = {}
	for i, item in ipairs(propertysheet.Items or {}) do
		tabs[i] = item.Tab
	end

	GAMEMODE:CreateItemInfoViewer(frame, propertysheet, topspace, bottomspace, MENU_WORTH)

	local action = vgui.Create("DButton", bottomspace)
	action:SetFont("Relapse20")
	action:SetText(shopMode and RelapseUI.T("shop_purchase") or RelapseUI.T("inv_equip"))
	action:SetSize(RelapseUI.Cells(12), L.m.btnH)
	RelapseUI.AlignFooterRight(action)
	RelapseUI.AlignFooterBottom(action)
	action.Paint = RelapseUI.PaintPrimaryButton
	action.DoClick = function(me)
		if me.RelapseCurrent then return end
		local id = frame.RelapseSelectedId
		if not id then
			surface.PlaySound("buttons/button8.wav")
			return
		end
		if shopMode then
			surface.PlaySound("buttons/button8.wav")
			return
		end
		surface.PlaySound("buttons/button14.wav")
		net.Start("relapse_inv_equip")
			net.WriteString(me.RelapseUnequip and "" or id)
		net.SendToServer()
	end
	frame.Action = action
	if not shopMode then
		frame.Equip = action
	end

	local chip, _, markslab = RelapseUI.CreateShopChip(bottomspace, RelapseUI.T("shop_marks_label"), GAMEMODE:GetRelapseMarks())
	frame.MarksLab = markslab
	frame.MarksChip = chip
	RelapseUI.UpdateWorthLabel(markslab, GAMEMODE:GetRelapseMarks())

	GAMEMODE:ConfigureMenuTabs(tabs, L.tabhei, shopMode and function(tab)
		ApplyShopTab(frame, tab)
	end or nil)
	if shopMode then
		propertysheet:SetActiveTab(frame.ModelsTab)
	end
	RelapseUI.FinishShopFrame(frame, propertysheet)
	FillModelGrid(frame, not shopMode)
	if shopMode then
		ApplyShopTab(frame, frame.ModelsTab)
	end
	return frame
end

function GM:RefreshRelapseInventory()
	FillModelGrid(pRelapseInventory, true)
	FillModelGrid(pRelapseInvShop, false)
end

function GM:OpenRelapseInventory()
	if self.CloseOtherOverlays then
		self:CloseOtherOverlays("inventory")
	end
	local switching = OverlayOpen(pRelapseInvShop)
	RelapseUI.HideOtherShops("inventory")
	if not switching then
		PlayMenuOpenSound()
	end

	if pRelapseInventory and pRelapseInventory:IsValid() then
		RelapseUI.ShowShopFrame(pRelapseInventory)
		self:RefreshRelapseInventory()
		return
	end

	RelapseUI.CreateFonts()
	pRelapseInventory = MakeInvWindow("menu_inventory", "inventory", false)
	self.RelapseInventoryInterface = pRelapseInventory
end

function GM:OpenRelapseInvShop()
	if self.CloseOtherOverlays then
		self:CloseOtherOverlays("inventory")
	end
	local switching = OverlayOpen(pRelapseInventory)
	RelapseUI.HideOtherShops("invshop")
	if not switching then
		PlayMenuOpenSound()
	end

	if pRelapseInvShop and pRelapseInvShop:IsValid() then
		RelapseUI.ShowShopFrame(pRelapseInvShop)
		FillModelGrid(pRelapseInvShop, false)
		OpenShopModelsTab(pRelapseInvShop)
		return
	end

	RelapseUI.CreateFonts()
	pRelapseInvShop = MakeInvWindow("shop_inv_title", "invshop", true)
	self.RelapseInvShopInterface = pRelapseInvShop
end

function GM:RelapseInventoryOpen()
	return OverlayOpen(pRelapseInventory) or OverlayOpen(pRelapseInvShop)
end

function GM:CloseRelapseInventory(fromEsc, instant)
	local closed = false
	for _, pnl in ipairs({ pRelapseInventory, pRelapseInvShop }) do
		if OverlayOpen(pnl) then
			if instant or not pnl._RelapseClosing then
				pnl:Close(instant)
			end
			closed = true
		end
	end
	if not closed then
		return false
	end
	if fromEsc then
		self.ShopOverlayBlockPause = true
		gui.HideGameUI()
	end
	return true
end
