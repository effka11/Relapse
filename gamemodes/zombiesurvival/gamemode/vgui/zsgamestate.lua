local PANEL = {}

local function WaveTitle()
	if not MySelf:IsValid() then return "" end

	local override = GetGlobalString("hudoverride" .. MySelf:Team(), "")
	if override and #override > 0 then
		return override
	end

	if GAMEMODE:IsEscapeSequence() then
		return translate.Get(MySelf:Team() == TEAM_UNDEAD and "prop_obj_exit_z" or "prop_obj_exit_h")
	end

	local wave = GAMEMODE:GetWave()
	if wave <= 0 then
		return translate.Get("prepare_yourself")
	end

	if GAMEMODE.ZombieEscape then
		return translate.Get("zombie_escape") .. " · " .. translate.Format("round_x_of_y", GAMEMODE.CurrentRound or 1, 2)
	end

	local maxwaves = GAMEMODE:GetNumberOfWaves()
	if maxwaves ~= -1 then
		local text = translate.Format("wave_x_of_y", wave, maxwaves)
		if not GAMEMODE:GetWaveActive() then
			text = translate.Get("intermission") .. " · " .. text
		end
		return text
	end

	if not GAMEMODE:GetWaveActive() then
		return translate.Get("intermission")
	end

	return translate.Format("wave_x_of_y", wave, wave)
end

local function WaveClock()
	if GAMEMODE:GetWave() <= 0 then
		local timeleft = math.max(0, GAMEMODE:GetWaveStart() - CurTime())
		return translate.Get("hud_invasion"), util.ToMinutesSecondsCD(timeleft), timeleft
	elseif GAMEMODE:GetWaveActive() then
		local waveend = GAMEMODE:GetWaveEnd()
		if waveend ~= -1 then
			local timeleft = math.max(0, waveend - CurTime())
			return translate.Get("hud_wave_ends"), util.ToMinutesSecondsCD(timeleft), timeleft
		end
	else
		local wavestart = GAMEMODE:GetWaveStart()
		if wavestart ~= -1 then
			local timeleft = math.max(0, wavestart - CurTime())
			return translate.Get("hud_next_wave"), util.ToMinutesSecondsCD(timeleft), timeleft
		end
	end
end

function PANEL:Init()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:ParentToHUD()
	self:InvalidateLayout()
end

function PANEL:SetTextFont()
end

function PANEL:Think()
	local _, clock = WaveClock()
	local has = clock ~= nil
	if has ~= self._HasClock then
		self._HasClock = has
		self:InvalidateLayout()
	end
end

local TITLE_FONT = "Relapse25"
local CLOCK_FONT = "Relapse30"

-- Relapse25 keeps ~6px under the baseline; Relapse30 sits ~6px above lining figures.
local function ClockY(titleY, titleH)
	return titleY + titleH - RelapseUI.sPx(6) + RelapseUI.sPx(30) - RelapseUI.sPx(6)
end

function PANEL:PerformLayout()
	RelapseUI.CreateFonts()
	local inset = RelapseUI.HudInset()
	local _, clock = WaveClock()
	self._HasClock = clock ~= nil
	local row = RelapseUI.Grid15(2)
	surface.SetFont("Relapse17")
	local _, pairH = surface.GetTextSize("Ay")
	local h = RelapseUI.Grid15(6)
	if self._HasClock then
		surface.SetFont(TITLE_FONT)
		local _, titleH = surface.GetTextSize("Ay")
		surface.SetFont(CLOCK_FONT)
		local _, clockH = surface.GetTextSize("Ay")
		h = ClockY(0, titleH) + clockH + row + pairH + row + pairH
	end
	self:SetSize(RelapseUI.HudW(), h)
	-- Relapse25 cell sits ~5px above caps; 45px is to the capital, not the em-box.
	self:SetPos(inset, RelapseUI.sPx(45) - RelapseUI.sPx(5))

	if GAMEMODE.XPHUD and GAMEMODE.XPHUD:IsValid() then
		GAMEMODE.XPHUD:InvalidateLayout()
	end
end

local function DrawPair(x, y, lab, val, valCol)
	local font = "Relapse17"
	RelapseUI.HudText(lab, font, x, y, RelapseUI.Col.Muted)
	surface.SetFont(font)
	local lw = surface.GetTextSize(lab) or 0
	RelapseUI.HudText(tostring(val), font, x + lw + RelapseUI.Grid5(), y, valCol)
end

function PANEL:Paint()
	RelapseUI.CreateFonts()
	local c = RelapseUI.Col
	local x = 0
	local y = 0
	local row = RelapseUI.Grid15(2)
	local col = RelapseUI.Grid15(12)

	RelapseUI.HudText(WaveTitle(), TITLE_FONT, x, y, c.Text, nil, nil, RelapseUI.Shadow - 1)

	local _, clock, remain = WaveClock()
	if clock then
		surface.SetFont(TITLE_FONT)
		local _, titleH = surface.GetTextSize("Ay")
		-- 30px is first-line glyph bottom → clock glyph top, not em-box.
		local clockY = ClockY(y, titleH)
		RelapseUI.HudText(clock, CLOCK_FONT, x, clockY, RelapseUI.UrgentCol(remain, c.Text))
		surface.SetFont(CLOCK_FONT)
		local _, clockH = surface.GetTextSize("Ay")
		y = clockY + clockH + row
	else
		y = y + row
	end

	DrawPair(x, y, translate.Get("hud_humans"), team.NumPlayers(TEAM_HUMAN), c.Text)
	DrawPair(x + col, y, translate.Get("hud_undead"), team.NumPlayers(TEAM_UNDEAD), c.Danger)
	y = y + row

	if MySelf:IsValid() then
		if MySelf:Team() == TEAM_UNDEAD then
			local toredeem = GAMEMODE:GetRedeemBrains()
			local brains = toredeem > 0 and (MySelf:Frags() .. " / " .. toredeem) or MySelf:Frags()
			RelapseUI.HudText(translate.Format("brains_eaten_x", brains), "Relapse17", x, y, c.Danger)
		else
			RelapseUI.HudText(translate.Format("points_x", MySelf:GetPoints()), "Relapse17", x, y, c.Accent)
			DrawPair(x + col, y, translate.Get("hud_score"), MySelf:Frags(), c.Text)
		end
	end

	return true
end

vgui.Register("ZSGameState", PANEL, "Panel")
