-- Relapse wave announcement. Title Relapse30 + Relapse20 lines, 5/15 optical stack.
-- Replaces the ZS center toast (ZSHUDFont, killicons, gradient-r) for wave start/end.

local PANEL = {}

local TITLE_FONT = "Relapse30"
local LINE_FONT = "Relapse20"
-- Relapse30 hangs ~6px over caps / under the baseline; Relapse20 hangs ~5px.
local TITLE_HANG = 6
local LINE_HANG = 5

local function FontH(font)
	surface.SetFont(font)
	local _, h = surface.GetTextSize("Ay")
	return h
end

-- Optical next-line y: prev glyph bottom + gap → next glyph top.
local function NextGlyphY(prevY, prevH, prevBot, gap, nextTop)
	return prevY + prevH - RelapseUI.sPx(prevBot) + gap - RelapseUI.sPx(nextTop)
end

local function CollectLines(...)
	local lines = {}
	for i = 1, select("#", ...) do
		local s = select(i, ...)
		if isstring(s) and s ~= "" then
			lines[#lines + 1] = s
		end
	end
	return lines
end

local function Stack(lines)
	local titleH = FontH(TITLE_FONT)
	local titleY = 0
	local n = lines and #lines or 0
	if n < 1 then
		return titleY, nil, titleY + titleH
	end

	local lineH = FontH(LINE_FONT)
	local ys = {}
	local y = NextGlyphY(titleY, titleH, TITLE_HANG, RelapseUI.Grid15(2), LINE_HANG)
	ys[1] = y
	for i = 2, n do
		y = NextGlyphY(y, lineH, LINE_HANG, RelapseUI.Grid15(), LINE_HANG)
		ys[i] = y
	end
	return titleY, ys, ys[n] + lineH
end

function PANEL:Init()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetAlpha(0)
	self:SetVisible(false)
	self.Title = ""
	self.Lines = {}
	self:InvalidateLayout()
end

function PANEL:Announce(title, ...)
	RelapseUI.CreateFonts()
	self.Title = title or ""
	self.Lines = CollectLines(...)
	if self.Title == "" then return end

	self:InvalidateLayout()
	if not (GAMEMODE and GAMEMODE.FilmMode) then
		self:SetVisible(true)
	end

	local hold = (GAMEMODE and GAMEMODE.NotifyFadeTime) or 8
	local fadeOut = RelapseUI.Duration(8)
	self.HoldUntil = RealTime() + math.max(0, hold - fadeOut)
	RelapseUI.PlayFade(self, 255, RelapseUI.Duration(1), RelapseUI.EaseOut)
end

function PANEL:PerformLayout()
	RelapseUI.CreateFonts()
	local _, _, h = Stack(self.Lines)
	self:SetSize(ScrW(), math.max(1, h))
	-- Relapse30 cell sits ~6px above caps; 3 cells is to the capital, not the em-box.
	self:SetPos(0, RelapseUI.Grid15(3) - RelapseUI.sPx(TITLE_HANG))
end

function PANEL:Think()
	local film = GAMEMODE and GAMEMODE.FilmMode
	if film then
		if self:IsVisible() then self:SetVisible(false) end
	elseif (self.Title or "") ~= "" and not self:IsVisible() then
		self:SetVisible(true)
	end

	local untilT = self.HoldUntil
	if not untilT then return end
	if RealTime() < untilT then return end

	self.HoldUntil = nil
	RelapseUI.PlayFade(self, 0, RelapseUI.Duration(8), RelapseUI.EaseIn, function(pnl)
		if IsValid(pnl) then
			pnl:SetVisible(false)
			pnl.Title = ""
			pnl.Lines = {}
		end
	end)
end

function PANEL:Paint(w, h)
	local title = self.Title
	if not title or title == "" then return true end

	local fade = self:GetAlpha() / 255
	if fade <= 0 then return true end

	RelapseUI.CreateFonts()
	local c = RelapseUI.Col
	local titleY, lineYs = Stack(self.Lines)
	local x = math.floor(w * 0.5 + 0.5)
	local shadow = RelapseUI.Shadow

	surface.SetAlphaMultiplier(fade)
	RelapseUI.HudText(title, TITLE_FONT, x, titleY, c.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, shadow)
	if lineYs then
		for i, y in ipairs(lineYs) do
			RelapseUI.HudText(self.Lines[i], LINE_FONT, x, y, c.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, shadow)
		end
	end
	surface.SetAlphaMultiplier(1)
	return true
end

vgui.Register("ZSWaveNotify", PANEL, "Panel")

function RelapseUI.WaveNotify(title, ...)
	if not title or title == "" then return end

	local gm = GAMEMODE
	local pan = gm and gm.WaveNotifyHUD
	if not (IsValid(pan) and pan.Announce) then
		if not vgui.GetControlTable("ZSWaveNotify") then
			if gm then
				gm:CenterNotify({font = "Relapse30"}, RelapseUI.Col.Text, title)
				for i = 1, select("#", ...) do
					local s = select(i, ...)
					if isstring(s) and s ~= "" then
						gm:CenterNotify({font = "Relapse20"}, RelapseUI.Col.Muted, s)
					end
				end
			end
			return
		end
		pan = vgui.Create("ZSWaveNotify")
		if gm then
			gm.WaveNotifyHUD = pan
		end
	end

	if IsValid(pan) and pan.Announce then
		return pan:Announce(title, ...)
	end
end
