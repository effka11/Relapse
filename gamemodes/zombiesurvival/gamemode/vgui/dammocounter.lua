local PANEL = {}

PANEL.NextRefresh = 0
PANEL.RefreshTime = 1

local function GetTargetEntIndex()
	return GAMEMODE.HumanMenuLockOn and GAMEMODE.HumanMenuLockOn:IsValid() and GAMEMODE.HumanMenuLockOn:EntIndex() or 0
end

local function DropDoClick(self)
	RunConsoleCommand("zsdropammo", self:GetParent():GetAmmoType())
end

local function GiveDoClick(self)
	RunConsoleCommand("zsgiveammo", self:GetParent():GetAmmoType(), GetTargetEntIndex())
end

function PANEL:Init()
	RelapseUI.CreateFonts()
	self.m_AmmoCountLabel = EasyLabel(self, "0", "Relapse20", RelapseUI.Col.Text)
	self.m_AmmoTypeLabel = EasyLabel(self, " ", "Relapse15", RelapseUI.Col.Muted)

	self.m_DropButton = vgui.Create("DButton", self)
	self.m_DropButton:SetFont("Relapse15")
	self.m_DropButton:SetText(RelapseUI.T("inv_drop"))
	self.m_DropButton:SetTooltip(RelapseUI.T("inv_drop"))
	self.m_DropButton:SetPaintBackgroundEnabled(false)
	self.m_DropButton.Paint = RelapseUI.PaintGhostButton
	self.m_DropButton.DoClick = DropDoClick

	self.m_GiveButton = vgui.Create("DButton", self)
	self.m_GiveButton:SetFont("Relapse15")
	self.m_GiveButton:SetText(RelapseUI.T("inv_give"))
	self.m_GiveButton:SetTooltip(RelapseUI.T("inv_give"))
	self.m_GiveButton:SetPaintBackgroundEnabled(false)
	self.m_GiveButton.Paint = RelapseUI.PaintGhostButton
	self.m_GiveButton.DoClick = GiveDoClick

	self:SetAmmoType("pistol")
end

function PANEL:Paint(w, h)
	RelapseUI.PaintCard(self, w, h, false, false, false)
	return true
end

function PANEL:Think()
	if RealTime() >= self.NextRefresh then
		self.NextRefresh = RealTime() + self.RefreshTime
		self:RefreshContents()
	end
end

function PANEL:RefreshContents()
	local count = MySelf:GetAmmoCount(self:GetAmmoType())
	self.m_AmmoCountLabel:SetTextColor(count == 0 and RelapseUI.Col.Muted or RelapseUI.Col.Text)
	self.m_AmmoCountLabel:SetText(count)
	self.m_AmmoCountLabel:SizeToContents()
	self:InvalidateLayout()
end

function PANEL:PerformLayout(w, h)
	w = w or self:GetWide()
	h = h or self:GetTall()
	local pad = RelapseUI.Grid5()
	local btnW = RelapseUI.Grid15(4)
	local btnH = RelapseUI.Grid15(2)

	self.m_GiveButton:SetSize(btnW, btnH)
	self.m_DropButton:SetSize(btnW, btnH)
	local by = math.floor((h - btnH) * 0.5 + 0.5)
	self.m_DropButton:SetPos(w - pad - btnW, by)
	self.m_GiveButton:SetPos(w - pad - btnW * 2 - RelapseUI.Grid5(), by)

	self.m_AmmoCountLabel:SetPos(RelapseUI.Grid15(), math.floor((h - self.m_AmmoCountLabel:GetTall()) * 0.5 + 0.5))
	local nameX = RelapseUI.Grid15() + RelapseUI.Grid15(3)
	self.m_AmmoTypeLabel:SetPos(nameX, math.floor((h - self.m_AmmoTypeLabel:GetTall()) * 0.5 + 0.5))
	self.m_AmmoTypeLabel:SetWide(math.max(1, w - nameX - pad - btnW * 2 - RelapseUI.Grid5()))
end

function PANEL:SetAmmoType(ammotype)
	self.m_AmmoType = ammotype
	self.m_AmmoTypeLabel:SetText(RelapseUI.ShopAmmo(ammotype))
	self.m_AmmoTypeLabel:SizeToContents()
	self:RefreshContents()
end

function PANEL:GetAmmoType()
	return self.m_AmmoType
end

vgui.Register("DAmmoCounter", PANEL, "DPanel")
