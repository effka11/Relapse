local PANEL = {}

PANEL.SlideTime = 0
PANEL.NextRefresh = 0

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self.Items = {}
	self.Canvas = vgui.Create("DScrollPanel", self)
	self.Canvas.Paint = function() return true end
	self:RefreshSize()
	self:SetPos(ScrW() - 1, 0)
end

function PANEL:Think()
	if RelapseUI.IconsDevOn then return end
	local time = RealTime()
	if self.StartChecking and time >= self.StartChecking then
		if not GAMEMODE:IsMenuKeyDown() and not self._RelapseClosing then
			self:CloseMenu()
		end
	end
end

function PANEL:RefreshSize()
	RelapseUI.CreateFonts()
	local L = RelapseUI.InvWindowSize()
	self:SetWide(RelapseUI.Grid15(18))
	self.RelapsePad = L.pad
	self.RelapseGap = L.gap
	if IsValid(self.Canvas) then
		RelapseUI.StyleScroll(self.Canvas)
	end
end

function PANEL:OpenMenu()
	if self.StartChecking and RealTime() < self.StartChecking
		and self:IsVisible() and not self._RelapseClosing then
		return
	end

	self.CloseTime = nil
	local fromClose = self._RelapseClosing or (self._RelapseFade and self._RelapseFade.to == 0)
	self._RelapseClosing = nil
	self:RefreshSize()
	self:SetVisible(true)
	if not fromClose then
		self:SetAlpha(0)
	end
	self:MakePopup()
	self:SetKeyboardInputEnabled(false)
	self.StartChecking = RealTime() + 0.1
	self:RefreshContents()
	self:InvalidateLayout(true)

	timer.Simple(0, function()
		gui.SetMousePos(ScrW() * 0.5, ScrH() * 0.5)
	end)
end

function PANEL:CloseMenu()
	self:RefreshContents()
	if GAMEMODE.CloseRelapseGameInv then
		GAMEMODE:CloseRelapseGameInv()
		return
	end
	if self.CloseTime then return end
	self.CloseTime = RealTime() + self.SlideTime
end

function PANEL:Paint(w, h)
	RelapseUI.PaintWindow(self, w, h)
	return true
end

function PANEL:AddItem(item)
	item:SetParent(self.Canvas)
	table.insert(self.Items, item)
	self:InvalidateLayout()
end

function PANEL:RemoveItem(item)
	for k, v in ipairs(self.Items) do
		if v == item then
			item:Remove()
			table.remove(self.Items, k)
			self:InvalidateLayout()
			break
		end
	end
end

function PANEL:RefreshContents()
	local changed = false
	for _, v in ipairs(self.Items) do
		if v.GetAmmoType then
			if MySelf:GetAmmoCount(v:GetAmmoType()) <= 0 then
				if v:IsVisible() then
					v:SetVisible(false)
					changed = true
				end
			elseif not v:IsVisible() then
				v:SetVisible(true)
				changed = true
			end
		end
	end
	if changed then
		self:InvalidateLayout()
	end
end

function PANEL:PerformLayout()
	self:RefreshSize()
	local pad = self.RelapsePad or RelapseUI.Grid15(3)
	local gap = self.RelapseGap or RelapseUI.Grid15()
	local bar = RelapseUI.ScrollBarW() + RelapseUI.ScrollGap()
	local inner = math.max(1, self:GetWide() - pad * 2)

	local total = 0
	local visible = {}
	for _, item in ipairs(self.Items) do
		if item and item:IsValid() and item:IsVisible() then
			visible[#visible + 1] = item
			total = total + item:GetTall() + gap
		end
	end
	if total > 0 then
		total = total - gap
	end

	local frame = GAMEMODE and GAMEMODE.InventoryMenu
	local L = RelapseUI.InvWindowSize()
	local actionGap = (L and L.actionGap) or RelapseUI.sPx(30)
	local alignInv = IsValid(frame) and frame:IsVisible()
	local maxH = ScrH() - pad * 2
	if alignInv then
		maxH = math.min(maxH, frame:GetTall())
	end
	local needScroll = total + pad * 2 > maxH
	local hei = math.min(maxH, total + pad * 2)
	if alignInv then
		hei = frame:GetTall()
		needScroll = total + pad * 2 > hei
	else
		hei = math.max(RelapseUI.Grid15(8), hei)
	end
	self:SetTall(hei)

	if alignInv then
		local fx, fy = frame:GetPos()
		local ax = fx + frame:GetWide() + actionGap
		local maxX = ScrW() - pad - self:GetWide()
		if ax > maxX then
			ax = math.max(pad, maxX)
		end
		self:SetPos(ax, fy + frame:GetTall() - hei)
	else
		self:AlignRight(pad)
		self:CenterVertical()
	end

	if IsValid(self.Canvas) then
		self.Canvas:SetPos(0, 0)
		self.Canvas:SetSize(self:GetWide(), self:GetTall())
	end

	local itemW = needScroll and math.max(1, inner - bar) or inner
	local y = pad
	for _, item in ipairs(visible) do
		item:SetWide(itemW)
		item:SetPos(pad, y)
		y = y + item:GetTall() + gap
	end
end

vgui.Register("DSideMenu", PANEL, "DPanel")
