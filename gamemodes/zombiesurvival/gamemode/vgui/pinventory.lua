local pRelapseInventory

local function OwnedModelIds()
	local ids = {}
	for _, id in ipairs(GAMEMODE.RelapseCosmeticOrder or {}) do
		local item = GAMEMODE:GetRelapseCosmetic(id)
		if item and item.Kind == GAMEMODE.RelapseCosmeticKind.MODEL and GAMEMODE:PlayerOwnsRelapseItem(id) then
			ids[#ids + 1] = id
		end
	end
	return ids
end

local function UpdateEquipButton(frame)
	if not IsValid(frame) or not IsValid(frame.Equip) then return end
	local id = frame.RelapseSelectedId
	local equipped = id and id == GAMEMODE:GetRelapseEquippedModelId()
	frame.Equip.RelapseCurrent = equipped and true or false
	frame.Equip:SetText(equipped and RelapseUI.T("inv_equipped") or RelapseUI.T("inv_equip"))
	frame.Equip:SetCursor(equipped and "arrow" or "hand")
	frame.Equip.Paint = equipped and RelapseUI.PaintGhostButton or RelapseUI.PaintPrimaryButton
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
	UpdateEquipButton(frame)

	if not silent then
		surface.PlaySound("buttons/button14.wav")
	end
end

local INV_CARD = {}

function INV_CARD:Init()
	self:SetText("")
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)

	local m = RelapseUI.M()
	self:SetCardSize(RelapseUI.Cells(18), m.cardH)

	self.ModelFrame = vgui.Create("DPanel", self)
	RelapseUI.PlaceCardIcon(self.ModelFrame, self:GetWide(), self.CardH)
	self.ModelFrame:SetMouseInputEnabled(false)
	self.ModelFrame.Paint = function() end

	self.NameLabel = EasyLabel(self, "", "Relapse20")
	self.NameLabel:SetContentAlignment(4)
	self.NameLabel:SetTextColor(RelapseUI.Col.Text)

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
	if IsValid(self.NameLabel) then
		self.NameLabel:SetPos(inset, inset)
		self.NameLabel:SetWide(math.max(0, w - 2 * inset))
	end
	if IsValid(self.StatusLabel) then
		self.StatusLabel:SetPos(inset, h - self.StatusLabel:GetTall() - inset)
	end
	if IsValid(self.ModelFrame) then
		RelapseUI.PlaceCardIcon(self.ModelFrame, w, h)
	end
end

function INV_CARD:SetItem(id)
	self.ItemId = id
	local item = GAMEMODE:GetRelapseCosmetic(id)
	if not item then return end

	self.NameLabel:SetText(GAMEMODE:RelapseCosmeticName(id))
	self.NameLabel:SizeToContents()

	local equipped = id == GAMEMODE:GetRelapseEquippedModelId()
	self.StatusLabel:SetText(equipped and RelapseUI.T("inv_equipped") or "")
	self.StatusLabel:SetTextColor(RelapseUI.Col.Muted)
	self.StatusLabel:SizeToContents()
	self.StatusLabel:SetVisible(equipped)

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
	local frame = pRelapseInventory
	if not IsValid(frame) then return end
	SelectInventoryModel(frame, self.ItemId)
end

vgui.Register("RelapseInvCard", INV_CARD, "DButton")

function GM:RefreshRelapseInventory()
	local frame = pRelapseInventory
	if not IsValid(frame) or not IsValid(frame.Grid) then return end

	for _, btn in ipairs(frame.RelapseCards or {}) do
		if IsValid(btn) then
			frame.Grid:RemoveItem(btn)
			btn:Remove()
		end
	end
	frame.RelapseCards = {}

	local keep = frame.RelapseSelectedId
	if keep and not self:PlayerOwnsRelapseItem(keep) then
		keep = nil
	end
	keep = keep or self:GetRelapseEquippedModelId()

	for _, id in ipairs(OwnedModelIds()) do
		local button = vgui.Create("RelapseInvCard")
		button:SetCardSize(frame.RelapseCardW, RelapseUI.M().cardH)
		button:SetItem(id)
		frame.Grid:AddItem(button)
		frame.RelapseCards[#frame.RelapseCards + 1] = button
	end

	if keep then
		SelectInventoryModel(frame, keep, true)
	end
	UpdateEquipButton(frame)
end

function GM:OpenRelapseInventory()
	if self.CloseOtherOverlays then
		self:CloseOtherOverlays("inventory")
	end
	PlayMenuOpenSound()

	if pRelapseInventory and pRelapseInventory:IsValid() then
		RelapseUI.ShowShopFrame(pRelapseInventory)
		self:RefreshRelapseInventory()
		return
	end

	RelapseUI.CreateFonts()

	local frame, L, topspace, bottomspace, propertysheet = RelapseUI.BuildShopFrame("menu_inventory", {
		deleteOnClose = false
	})
	pRelapseInventory = frame
	frame.RelapseCardW = L.cardW
	frame.RelapseCards = {}

	local itemframe = vgui.Create("DScrollPanel", propertysheet)
	itemframe.Paint = function() return true end
	RelapseUI.StyleScroll(itemframe)
	local list = RelapseUI.MakeShopGrid(itemframe, L, false)
	frame.Grid = list

	propertysheet:AddSheet(RelapseUI.T("inv_tab_models"), itemframe, nil, false, false)

	local tabs = {}
	for i, item in ipairs(propertysheet.Items or {}) do
		tabs[i] = item.Tab
	end

	self:CreateItemInfoViewer(frame, propertysheet, topspace, bottomspace, MENU_WORTH)

	local equip = vgui.Create("DButton", bottomspace)
	equip:SetFont("Relapse20")
	equip:SetText(RelapseUI.T("inv_equip"))
	equip:SetSize(RelapseUI.Cells(12), L.m.btnH)
	RelapseUI.AlignFooterRight(equip)
	RelapseUI.AlignFooterBottom(equip)
	equip.Paint = RelapseUI.PaintPrimaryButton
	equip.DoClick = function(me)
		if me.RelapseCurrent then return end
		local id = frame.RelapseSelectedId
		if not id then
			surface.PlaySound("buttons/button8.wav")
			return
		end
		surface.PlaySound("buttons/button14.wav")
		net.Start("relapse_inv_equip")
			net.WriteString(id)
		net.SendToServer()
	end
	frame.Equip = equip

	self:ConfigureMenuTabs(tabs, L.tabhei)
	RelapseUI.FinishShopFrame(frame, propertysheet)
	self:RefreshRelapseInventory()
end

function GM:RelapseInventoryOpen()
	return IsValid(pRelapseInventory) and (pRelapseInventory:IsVisible() or pRelapseInventory._RelapseClosing)
end

function GM:CloseRelapseInventory(fromEsc, instant)
	if not (pRelapseInventory and pRelapseInventory:IsValid()) then
		return false
	end
	if not (pRelapseInventory:IsVisible() or pRelapseInventory._RelapseClosing) then
		return false
	end
	if instant or not pRelapseInventory._RelapseClosing then
		pRelapseInventory:Close(instant)
	end
	if fromEsc then
		self.ShopOverlayBlockPause = true
		gui.HideGameUI()
	end
	return true
end
