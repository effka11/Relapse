function MakepPlayerModel()
	if GAMEMODE.OpenRelapseInventory then
		GAMEMODE:OpenRelapseInventory()
	end
end

function GM:CloseHelpMenu(fromEsc, instant)
	if not (self.HelpMenu and self.HelpMenu:IsValid()) then
		return false
	end
	if fromEsc then
		self.HelpMenuBlockPause = true
	end
	if not instant and fromEsc ~= false then
		self.HelpMenuIgnoreOpen = CurTime() + RelapseUI.Duration(2)
	end
	self.HelpMenu:Close(instant)
	if fromEsc then
		gui.HideGameUI()
	end
	return true
end

function GM:ToggleRelapseInventory()
	if self.RelapseInventoryOpen and self:RelapseInventoryOpen() then
		self:CloseRelapseInventory()
		return
	end
	if self.OpenRelapseInventory then
		self:OpenRelapseInventory()
	end
end

---------------------------------------------------------------------------
-- ESC pause
---------------------------------------------------------------------------

function GM:ClosePauseMenu(fromEsc, instant)
	if not (self.PauseMenu and self.PauseMenu:IsValid()) then
		return false
	end
	if fromEsc then
		self.PauseMenuBlockPause = true
	end
	self.PauseMenu:Close(instant)
	if fromEsc then
		gui.HideGameUI()
	end
	return true
end

local function OverlayOpen(pnl)
	return IsValid(pnl) and (pnl:IsVisible() or pnl._RelapseClosing)
end

local function CloseOverlayPanel(pnl, instant)
	if not OverlayOpen(pnl) then
		return false
	end
	if instant or not pnl._RelapseClosing then
		pnl:Close(instant)
	end
	return true
end

function GM:ShopMenuOpen()
	return OverlayOpen(pWorth) or OverlayOpen(self.ArsenalInterface)
end

function GM:ArsenalMenuOpen()
	return OverlayOpen(self.ArsenalInterface)
end

function GM:OptionsMenuOpen()
	return OverlayOpen(pOptions)
end

function GM:CloseShopMenu(fromEsc, instant)
	local closed = CloseOverlayPanel(pWorth, instant)
	closed = CloseOverlayPanel(self.ArsenalInterface, instant) or closed
	if closed and fromEsc then
		self.ShopOverlayBlockPause = true
		gui.HideGameUI()
	end
	return closed
end

function GM:CloseOptionsMenu(fromEsc, instant)
	local closed = CloseOverlayPanel(pOptions, instant)
	if closed and fromEsc then
		self.ShopOverlayBlockPause = true
		gui.HideGameUI()
	end
	return closed
end

function GM:CreditsMenuOpen()
	return OverlayOpen(pCredits)
end

function GM:CloseCreditsMenu(fromEsc, instant)
	local closed = CloseOverlayPanel(pCredits, instant)
	if closed and fromEsc then
		self.ShopOverlayBlockPause = true
		gui.HideGameUI()
	end
	return closed
end

function GM:CloseHelpGuide(fromEsc, instant)
	local closed = CloseOverlayPanel(pHelp, instant)
	if closed and fromEsc then
		self.ShopOverlayBlockPause = true
		gui.HideGameUI()
	end
	return closed
end

function GM:CloseShopOverlays(fromEsc, instant)
	local closed = self:CloseShopMenu(fromEsc, instant)
	closed = self:CloseOptionsMenu(fromEsc, instant) or closed
	closed = self:CloseCreditsMenu(fromEsc, instant) or closed
	closed = self:CloseHelpGuide(fromEsc, instant) or closed
	if self.CloseRelapseInventory then
		closed = self:CloseRelapseInventory(fromEsc, instant) or closed
	end
	if self.CloseCharacterSheet then
		closed = self:CloseCharacterSheet(fromEsc, instant) or closed
	end
	return closed
end

function GM:CloseOtherOverlays(keep)
	local glass = keep == "shop" or keep == "options" or keep == "credits"
		or keep == "inventory" or keep == "scoreboard" or keep == "helpguide"
		or keep == "character"
	if glass and RelapseUI.PinScrim then
		RelapseUI.PinScrim()
	end
	local instant = glass and RelapseUI.SwapGlass and RelapseUI.SwapGlass()
	if instant then
		RelapseUI.MarkGlassSwap()
	end
	if keep ~= "help" then
		self:CloseHelpMenu(false, instant)
	end
	if keep ~= "helpguide" then
		self:CloseHelpGuide(false, instant)
	end
	if keep ~= "pause" then
		self:ClosePauseMenu(false, instant or glass)
	end
	if keep ~= "shop" then
		self:CloseShopMenu(false, instant)
	end
	if keep ~= "options" then
		self:CloseOptionsMenu(false, instant)
	end
	if keep ~= "credits" then
		self:CloseCreditsMenu(false, instant)
	end
	if keep ~= "inventory" and self.CloseRelapseInventory then
		self:CloseRelapseInventory(false, instant)
	end
	if keep ~= "character" and self.CloseCharacterSheet then
		self:CloseCharacterSheet(false, instant)
	end
	if keep ~= "scoreboard" and self.CloseScoreboard then
		self:CloseScoreboard(false, instant)
	end
end

function GM:ToggleShopMenu()
	if self:ArsenalMenuOpen() then
		self:CloseShopMenu()
		return
	end
	if not (IsValid(MySelf) and MySelf:Team() == TEAM_HUMAN and MySelf:Alive()) then
		return
	end
	self:OpenArsenalMenu()
end

function GM:ToggleOptionsMenu()
	if self:OptionsMenuOpen() then
		self:CloseOptionsMenu()
		return
	end
	MakepOptions()
end

function GM:ShowPauseMenu()
	if self.PauseMenu and self.PauseMenu:IsValid() then
		if self.PauseMenu._RelapseClosing then
			self.PauseMenu:Remove()
		else
			return
		end
	end
	self:CloseOtherOverlays("pause")

	PlayMenuOpenSound()
	RelapseUI.CreateFonts()

	local items = {
		{ "menu_continue", breakAfter = true },
		{ "menu_options", MakepOptions },
		{ "menu_help", MakepHelp },
		{ "menu_inventory", function() GAMEMODE:OpenRelapseInventory() end },
		{ "menu_credits", MakepCredits, breakAfter = true },
		{ "menu_disconnect", function() RunConsoleCommand("disconnect") end },
		{ "menu_quit", function() RunConsoleCommand("quit") end }
	}

	local font = "Relapse30"
	surface.SetFont(font)
	local maxW = RelapseUI.Grid15(14)
	for _, item in ipairs(items) do
		maxW = math.max(maxW, surface.GetTextSize(RelapseUI.T(item[1])))
	end

	local colW = math.max(RelapseUI.Grid15(14), RelapseUI.Snap(maxW + RelapseUI.Grid15()))
	local met = RelapseUI.PauseRowMetrics(font)
	local groupGap = RelapseUI.Grid15(3)
	local n = #items
	local groupH = 0
	for i, item in ipairs(items) do
		local gap = 0
		if i < n then
			gap = item.breakAfter and groupGap or met.gap
		end
		groupH = groupH + met.inkH + gap
	end
	local x = RelapseUI.HudInset()
	local y = RelapseUI.Snap((ScrH() - groupH) * 0.5)

	local frame = RelapseUI.BuildPauseFrame()
	self.PauseMenu = frame

	for i, item in ipairs(items) do
		local fn = item[2]
		local gap = 0
		if i < n then
			gap = item.breakAfter and groupGap or met.gap
		end
		local rowH = met.inkH + gap
		local leave = item[1] == "menu_disconnect" or item[1] == "menu_quit"
		local btn = RelapseUI.MakePauseButton(frame, RelapseUI.T(item[1]), function()
			if not fn then
				GAMEMODE:ClosePauseMenu()
				return
			end
			if not leave and RelapseUI.PinScrim then
				RelapseUI.PinScrim()
			end
			if IsValid(frame) then
				frame:Close(true)
			end
			fn()
		end)
		btn:SetFont(font)
		btn:SetPos(x, y)
		btn:SetSize(colW, math.max(rowH, met.rowH))
		btn.RelapsePrimary = not fn
		y = y + rowH
	end

	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	RelapseUI.FadeOpenOverlay(frame)
end

function GM:OnPauseMenuShow()
	if self:CloseHelpMenu(true) or self.HelpMenuBlockPause then
		self.HelpMenuBlockPause = nil
		gui.HideGameUI()
		return false
	end
	if self:ClosePauseMenu(true) or self.PauseMenuBlockPause then
		self.PauseMenuBlockPause = nil
		gui.HideGameUI()
		return false
	end
	if self:CloseShopOverlays(true) or self.ShopOverlayBlockPause then
		self.ShopOverlayBlockPause = nil
		gui.HideGameUI()
		return false
	end
	if (self.CloseScoreboard and self:CloseScoreboard(true)) or self.ScoreboardBlockPause then
		self.ScoreboardBlockPause = nil
		gui.HideGameUI()
		return false
	end
	gui.HideGameUI()
	self:ShowPauseMenu()
	return false
end

function GM:OnPauseMenuBlockedTooManyTimes()
end

hook.Add("OnPauseMenuBlockedTooManyTimes", "TellAboutShiftEsc", function() end)
