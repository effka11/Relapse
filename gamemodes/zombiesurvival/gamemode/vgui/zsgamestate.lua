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

function PANEL:PerformLayout()
	RelapseUI.CreateFonts()
	local inset = RelapseUI.HudInset()
	local _, clock = WaveClock()
	self._HasClock = clock ~= nil
	self:SetSize(RelapseUI.HudW(), RelapseUI.Grid15(self._HasClock and 10 or 6))
	self:SetPos(inset, inset)

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

	RelapseUI.HudText(WaveTitle(), "Relapse22", x, y, c.Text)
	y = y + row

	local _, clock, remain = WaveClock()
	if clock then
		RelapseUI.HudText(clock, "Relapse64", x, y, RelapseUI.UrgentCol(remain, c.Text))
		y = y + RelapseUI.Grid15(5)
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
