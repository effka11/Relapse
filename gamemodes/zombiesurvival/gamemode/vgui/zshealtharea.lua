local PANEL = {}

-- Scratch buffer for HealthCol. Colours come from sh_relapse_theme.lua.
local colHealth = Color(0, 0, 0, 255)

function PANEL:Init()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:InvalidateLayout()
end

function PANEL:Think()
	local lp = MySelf
	local showarmor = lp:IsValid() and lp:Team() == TEAM_HUMAN and lp:GetBloodArmor() > 0
	if showarmor ~= self._ShowArmor then
		self._ShowArmor = showarmor
		self:InvalidateLayout()
		if GAMEMODE.StatusHUD and GAMEMODE.StatusHUD:IsValid() then
			GAMEMODE.StatusHUD:InvalidateLayout()
		end
	end
end

function PANEL:PerformLayout()
	RelapseUI.CreateFonts()
	local inset = RelapseUI.HudInset()
	self:SetSize(RelapseUI.Cells(32), RelapseUI.Cells(self._ShowArmor and 16 or 13))
	self:AlignLeft(inset)
	self:AlignBottom(inset)

	if GAMEMODE.StatusHUD and GAMEMODE.StatusHUD:IsValid() then
		GAMEMODE.StatusHUD:InvalidateLayout()
	end
end

function PANEL:Paint(w, h)
	local lp = MySelf
	if not lp:IsValid() then return true end

	RelapseUI.CreateFonts()
	local c = RelapseUI.Col
	local pad = RelapseUI.sPx(8)
	local barw = RelapseUI.Cells(26)
	local barh = RelapseUI.sPx(10)
	local x = pad
	local y = h - pad - RelapseUI.sPx(4)
	if self._ShowArmor then
		y = y - RelapseUI.sPx(36)
	end

	local health = math.max(lp:Health(), 0)
	local maxhealth = math.max(lp:GetMaxHealthEx(), 1)
	local frac = math.Clamp(health / maxhealth, 0, 1)
	self.LerpFrac = Lerp(FrameTime() * 10, self.LerpFrac or frac, frac)
	self.LerpHP = Lerp(FrameTime() * 12, self.LerpHP or health, health)

	local phantom = math.max(lp:GetPhantomHealth(), 0)
	local phantomfrac = math.Clamp(phantom / maxhealth, 0, 1 - self.LerpFrac)
	local hpcol = RelapseUI.HealthCol(self.LerpFrac, colHealth)

	RelapseUI.PaintHudHairBar(x, y - barh, barw, barh, self.LerpFrac, hpcol, phantomfrac, c.Phantom, 4)
	y = y - barh - RelapseUI.sPx(10)

	RelapseUI.HudText(tostring(math.Round(self.LerpHP)), "Relapse64", x, y, hpcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 4)

	if self._ShowArmor then
		local armor = lp:GetBloodArmor()
		local maxarmor = math.max(lp.MaxBloodArmor or 10, 1)
		self.LerpArmor = Lerp(FrameTime() * 10, self.LerpArmor or math.Clamp(armor / maxarmor, 0, 1), math.Clamp(armor / maxarmor, 0, 1))

		local ax = pad
		local ay = h - pad
		RelapseUI.PaintHudHairBar(ax, ay - RelapseUI.sPx(5), barw, RelapseUI.sPx(5), self.LerpArmor, c.Armor, nil, nil, 4)
		RelapseUI.HudText(translate.Get("hud_armor") .. "  " .. math.ceil(armor), "Relapse15", ax, ay - RelapseUI.sPx(8), c.Armor, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 4)
	end

	return true
end

vgui.Register("ZSHealthArea", PANEL, "Panel")
