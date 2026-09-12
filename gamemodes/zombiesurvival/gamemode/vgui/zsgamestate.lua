local PANEL = {}

local function WaveTitle()
	if not IsValid(MySelf) then return "" end

	local teamid = MySelf:Team()
	if not teamid then return "" end

	local override = GetGlobalString("hudoverride" .. teamid, "")
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
local CLOCK_FONT = "Relapse40"
local PAIR_FONT = "Relapse25"
local NUM_FONT = "Relapse30"

-- Optical next-line y: prev glyph bottom + gap → next glyph top.
-- Relapse25/30 keep ~6px under the baseline; Relapse40 sits ~7px above lining figures;
-- Relapse25 sits ~5px above caps, Relapse30 ~6px.
local function NextGlyphY(prevY, prevH, prevBot, gap, nextTop)
	return prevY + prevH - RelapseUI.sPx(prevBot) + RelapseUI.sPx(gap) - RelapseUI.sPx(nextTop)
end

local function FontH(font)
	surface.SetFont(font)
	local _, h = surface.GetTextSize("Ay")
	return h
end

local function HudStack()
	local titleH = FontH(TITLE_FONT)
	local numH = FontH(NUM_FONT)
	local titleY = 0
	local _, clock = WaveClock()
	local clockY, capY
	if clock then
		local clockH = FontH(CLOCK_FONT)
		clockY = NextGlyphY(titleY, titleH, 6, 30, 7)
		-- 45px is clock glyph bottom → number glyph top.
		capY = NextGlyphY(clockY, clockH, 7, 45, 6)
	else
		capY = NextGlyphY(titleY, titleH, 6, 30, 6)
	end
	return titleY, clockY, capY, capY + numH
end

function PANEL:PerformLayout()
	RelapseUI.CreateFonts()
	local inset = RelapseUI.HudInset()
	local _, clock = WaveClock()
	self._HasClock = clock ~= nil
	local _, _, _, h = HudStack()
	self:SetSize(RelapseUI.HudW(), h)
	-- Relapse25 cell sits ~5px above caps; 45px is to the capital, not the em-box.
	self:SetPos(inset, RelapseUI.sPx(45) - RelapseUI.sPx(5))

	if GAMEMODE.XPHUD and GAMEMODE.XPHUD:IsValid() then
		GAMEMODE.XPHUD:InvalidateLayout()
	end
end

local function DrawPair(x, yNum, lab, val, valCol)
	lab = lab .. ":"
	val = tostring(val)
	surface.SetFont(PAIR_FONT)
	local lw = surface.GetTextSize(lab) or 0
	-- CreateFont size is the Windows cell. Caps and lining figures share the baseline.
	local labY = RelapseUI.ManropeBaseline(yNum, RelapseUI.sPx(30)) - RelapseUI.ManropeBaseline(0, RelapseUI.sPx(25))
	RelapseUI.HudText(lab, PAIR_FONT, x, labY, RelapseUI.Col.Text)
	RelapseUI.HudText(val, NUM_FONT, x + lw + RelapseUI.Grid5(2), yNum + RelapseUI.sPx(1), valCol)
end

function PANEL:Paint()
	RelapseUI.CreateFonts()
	local c = RelapseUI.Col
	local x = 0
	local titleY, clockY, capY = HudStack()

	RelapseUI.HudText(WaveTitle(), TITLE_FONT, x, titleY, c.Text)

	local _, clock, remain = WaveClock()
	if clock then
		RelapseUI.HudText(clock, CLOCK_FONT, x, clockY, RelapseUI.UrgentCol(remain, c.Text))
	end

	if IsValid(MySelf) then
		if MySelf:Team() == TEAM_UNDEAD then
			local toredeem = GAMEMODE:GetRedeemBrains()
			local brains = toredeem > 0 and (MySelf:Frags() .. " / " .. toredeem) or MySelf:Frags()
			local labY = capY + FontH(NUM_FONT) - FontH(PAIR_FONT)
			RelapseUI.HudText(translate.Format("brains_eaten_x", brains), PAIR_FONT, x, labY, c.Danger)
		else
			DrawPair(x, capY, translate.Get("hud_points"), MySelf:GetPoints(), c.Ok)
		end
	end

	return true
end

vgui.Register("ZSGameState", PANEL, "Panel")
