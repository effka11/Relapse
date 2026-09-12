local pPlayerModel
local function SwitchPlayerModel(self)
	surface.PlaySound("buttons/button14.wav")
	RunConsoleCommand("cl_playermodel", self.m_ModelName)
	chat.AddText(COLOR_LIMEGREEN, "You've changed your desired player model to "..tostring(self.m_ModelName))

	pPlayerModel:Close()
end
function MakepPlayerModel()
	if pPlayerModel and pPlayerModel:IsValid() then pPlayerModel:Remove() end

	PlayMenuOpenSound()

	local numcols = 8
	local wid = numcols * 68 + 24
	local hei = 400

	pPlayerModel = vgui.Create("DFrame")
	pPlayerModel:SetSkin("Default")
	pPlayerModel:SetTitle("Player model selection")
	pPlayerModel:SetSize(wid, hei)
	pPlayerModel:Center()
	pPlayerModel:SetDeleteOnClose(true)

	local list = vgui.Create("DPanelList", pPlayerModel)
	list:StretchToParent(8, 24, 8, 8)
	list:EnableVerticalScrollbar()

	local grid = vgui.Create("DGrid", pPlayerModel)
	grid:SetCols(numcols)
	grid:SetColWide(68)
	grid:SetRowHeight(68)

	for name, mdl in pairs(player_manager.AllValidModels()) do
		local button = vgui.Create("SpawnIcon", grid)
		button:SetPos(0, 0)
		button:SetModel(mdl)
		button.m_ModelName = name
		button.OnMousePressed = SwitchPlayerModel
		grid:AddItem(button)
	end
	grid:SetSize(wid - 16, math.ceil(table.Count(player_manager.AllValidModels()) / numcols) * grid:GetRowHeight())

	list:AddItem(grid)

	pPlayerModel:SetSkin("Default")
	pPlayerModel:MakePopup()
end

function GM:CloseHelpMenu(fromEsc)
	if not (self.HelpMenu and self.HelpMenu:IsValid()) then
		return false
	end
	if fromEsc then
		self.HelpMenuBlockPause = true
	end
	self.HelpMenuIgnoreOpen = CurTime() + RelapseUI.Duration(2)
	self.HelpMenu:Close()
	if fromEsc then
		gui.HideGameUI()
	end
	return true
end

function GM:ShowHelp()
	if self.HelpMenuIgnoreOpen and self.HelpMenuIgnoreOpen > CurTime() then
		return
	end
	if self:CloseHelpMenu() then
		return
	end

	PlayMenuOpenSound()
	RelapseUI.CreateFonts()

	local items = {
		{ "menu_help", MakepHelp },
		{ "menu_player_model", MakepPlayerModel },
		{ "menu_options", MakepOptions },
		{ "menu_skills", function() GAMEMODE:ToggleSkillWeb() end },
		{ "menu_credits", MakepCredits }
	}

	local font = "Relapse25"
	local rowH = RelapseUI.Grid15(4)
	local n = #items
	local innerW = RelapseUI.HudW()
	local bodyH = n * rowH
	local frame = RelapseUI.BuildMenuFrame()
	self.HelpMenu = frame

	local x = RelapseUI.Snap((ScrW() - innerW) * 0.5)
	local y = RelapseUI.Snap((ScrH() - bodyH) * 0.5)
	local close = RelapseUI.MakeMenuClose(frame, function()
		GAMEMODE:CloseHelpMenu()
	end)
	close:SetPos(x + innerW + RelapseUI.Grid15(), y - close:GetTall() - RelapseUI.Grid15())
	for i, item in ipairs(items) do
		local fn = item[2]
		local btn = RelapseUI.MakeMenuButton(frame, RelapseUI.T(item[1]), function()
			if IsValid(frame) then
				frame:Close(true)
			end
			fn()
		end)
		btn:SetFont(font)
		btn:SetPos(x, y)
		btn:SetSize(innerW, rowH)
		btn.RelapseRule = i < n
		y = y + rowH
	end

	frame:SetAlpha(0)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	RelapseUI.PlayFade(frame, 255, RelapseUI.Duration(3), RelapseUI.EaseOut)
end

hook.Add("PlayerButtonDown", "RelapseHelpMenuF1", function(pl, button)
	if button ~= KEY_F1 then return end
	if not IsFirstTimePredicted() then return end
	if pl ~= MySelf then return end
	local gm = GAMEMODE
	if gm and gm.CloseHelpMenu then
		gm:CloseHelpMenu()
	end
end)

function GM:OnPauseMenuShow()
	if self:CloseHelpMenu(true) or self.HelpMenuBlockPause then
		self.HelpMenuBlockPause = nil
		gui.HideGameUI()
		return false
	end
end
