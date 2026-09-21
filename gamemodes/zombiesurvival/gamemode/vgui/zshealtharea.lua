local PANEL = {}

-- Scratch buffer for HealthCol. Colours come from sh_relapse_theme.lua.
local colHealth = Color(0, 0, 0, 255)
local colAloeIcon = Color(0, 0, 0, 255)
local matAloeFicus

local function AloeIconCol(src, alpha)
	colAloeIcon.r = src.r
	colAloeIcon.g = src.g
	colAloeIcon.b = src.b
	colAloeIcon.a = math.floor((src.a or 255) * alpha + 0.5)
	return colAloeIcon
end

local function AloeFicusMat()
	if not matAloeFicus then
		matAloeFicus = Material("zombiesurvival/hud_ficus.png", "smooth noclamp")
	end
	return matAloeFicus
end

local function DrawAloeIcon(mat, cx, cy, s, col)
	if not mat or mat:IsError() then
		return
	end
	s = math.max(1, math.floor(s + 0.5))
	local x = math.floor(cx - s * 0.5 + 0.5)
	local y = math.floor(cy - s * 0.5 + 0.5)
	surface.SetMaterial(mat)
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	surface.DrawTexturedRect(x, y, s, s)
end

function PANEL:Init()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:InvalidateLayout()
end

function PANEL:Think()
	local lp = MySelf
	local showarmor = IsValid(lp) and lp:Team() == TEAM_HUMAN and lp:GetBloodArmor() > 0
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
	-- 45 at 1080p: health bar's bottom edge (no shadow) sits this far from the screen.
	self:AlignBottom(RelapseUI.sPx(45))

	if GAMEMODE.StatusHUD and GAMEMODE.StatusHUD:IsValid() then
		GAMEMODE.StatusHUD:InvalidateLayout()
	end
end

function PANEL:Paint(w, h)
	local lp = MySelf
	if not IsValid(lp) then return true end

	RelapseUI.CreateFonts()
	local c = RelapseUI.Col
	local pad = RelapseUI.sPx(8)
	local barw = RelapseUI.Cells(26)
	local barh = RelapseUI.sPx(10)
	local x = pad
	-- Panel bottom is sPx(45) from the screen; bar sits on that edge. Shadow is 120° (down-right).
	local y = h
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

	DisableClipping(true)
	surface.DisableClipping(true)

	RelapseUI.PaintHudHairBar(x, y - barh, barw, barh, self.LerpFrac, hpcol, phantomfrac, c.Phantom, 4)
	local barRight = x + barw

	local stam = 1
	local spending = false
	if lp:Team() == TEAM_HUMAN and lp:Alive() and not GAMEMODE.ZombieEscape and lp.GetStamina then
		stam = lp:GetStamina()
		spending = GAMEMODE.IsHumanRunning and GAMEMODE:IsHumanRunning(lp)
	end
	-- Appear while stamina is being spent. Stay until full so the remaining pool is readable.
	local showStam = spending or stam < 0.995
	self.StaminaAlpha = Lerp(FrameTime() * 8, self.StaminaAlpha or 0, showStam and 1 or 0)
	self.LerpStamina = Lerp(FrameTime() * 10, self.LerpStamina or stam, stam)
	if self.StaminaAlpha > 0.02 then
		-- 3px tall so 1px corners have a middle row.
		local stamh = math.max(3, RelapseUI.sPx(3))
		surface.SetAlphaMultiplier(self.StaminaAlpha)
		RelapseUI.PaintHudHairBar(x, y + RelapseUI.sPx(4) + 1, barw, stamh, self.LerpStamina, c.Stamina or c.Muted, nil, nil, 4, 1)
		surface.SetAlphaMultiplier(1)
	end

	y = y - barh - RelapseUI.sPx(15)

	local hpText = tostring(math.Round(self.LerpHP))
	RelapseUI.HudText(hpText, "Relapse64", x, y, hpcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 4)

	local wantAloe = 0
	if lp:Team() == TEAM_HUMAN and lp:Alive() and GAMEMODE.CountAloeAura then
		if GAMEMODE:CountAloeAura(lp) > 0 then
			wantAloe = 1
		end
	end
	self.AloeIconAlpha = Lerp(FrameTime() * 8, self.AloeIconAlpha or 0, wantAloe)
	if self.AloeIconAlpha > 0.02 then
		surface.SetFont("Relapse64")
		local _, hpH = surface.GetTextSize(hpText)
		local midY = RelapseUI.Snap(y - hpH * 0.5) + RelapseUI.Grid5()
		local iconS = RelapseUI.sPx(45)
		local iconX = barRight - RelapseUI.sPx(45)
		local a = self.AloeIconAlpha
		DrawAloeIcon(AloeFicusMat(), iconX, midY, iconS, AloeIconCol(c.Text, a))
	end

	if self._ShowArmor then
		local armor = lp:GetBloodArmor()
		local maxarmor = 15
		if GAMEMODE.GetHumanBloodArmorMax then
			maxarmor = GAMEMODE:GetHumanBloodArmorMax(lp)
		elseif isnumber(lp.MaxBloodArmor) then
			maxarmor = lp.MaxBloodArmor
		end
		maxarmor = math.max(maxarmor, 1)
		self.LerpArmor = Lerp(FrameTime() * 10, self.LerpArmor or math.Clamp(armor / maxarmor, 0, 1), math.Clamp(armor / maxarmor, 0, 1))

		local ax = pad
		local ay = h - pad
		RelapseUI.PaintHudHairBar(ax, ay - RelapseUI.sPx(5), barw, RelapseUI.sPx(5), self.LerpArmor, c.Armor, nil, nil, 4)
		RelapseUI.HudText(translate.Get("hud_armor") .. "  " .. math.ceil(armor), "Relapse15", ax, ay - RelapseUI.sPx(8), c.Armor, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 4)
	end

	surface.DisableClipping(false)
	DisableClipping(false)
	return true
end

vgui.Register("ZSHealthArea", PANEL, "Panel")
