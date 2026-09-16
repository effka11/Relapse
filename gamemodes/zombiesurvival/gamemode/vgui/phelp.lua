GM.Help = {
{Name = "help_cat_introduction",
Content = "help_cont_introduction"},

{Name = "help_cat_survival",
Content = "help_cont_survival"},

{Name = "help_cat_barricading",
Content = "help_cont_barricading"},

{Name = "help_cat_upgrades",
Content = "help_cont_upgrades"},

{Name = "help_cat_being_a_zombie",
Content = "help_cont_being_a_zombie"}
}

function MakepCredits()
	if GAMEMODE.CloseOtherOverlays then
		GAMEMODE:CloseOtherOverlays("credits")
	end
	PlayMenuOpenSound()

	if pCredits and pCredits:IsValid() then
		RelapseUI.ShowShopFrame(pCredits)
		return
	end

	RelapseUI.CreateFonts()

	local frame, L, _, bottomspace, propertysheet = RelapseUI.BuildShopFrame("menu_credits", {
		deleteOnClose = false
	})
	pCredits = frame
	if IsValid(bottomspace) then
		bottomspace:SetVisible(false)
	end
	if IsValid(propertysheet) then
		propertysheet:SetVisible(false)
		propertysheet:SetMouseInputEnabled(false)
	end

	local scroll = RelapseUI.MakeOptionsScroll(frame)
	scroll:SetSize(L.innerW, L.hei - L.headerh - RelapseUI.Grid15(3))
	scroll:SetPos(L.pad, L.headerh)
	RelapseUI.PadCreditsScroll(scroll, frame, L)

	local sections = GAMEMODE.RelapseCreditSections
	for i, section in ipairs(sections or {}) do
		RelapseUI.CreditsSection(scroll, RelapseUI.T(section.Title), i == 1)
		for _, person in ipairs(section.People or {}) do
			local role = person[2]
			if role and role ~= "" then
				role = RelapseUI.T(role)
			else
				role = ""
			end
			RelapseUI.CreditsRow(scroll, person[1], role)
		end
	end

	RelapseUI.FinishShopFrame(frame, propertysheet)
end

function MakepHelp()
	PlayMenuOpenSound()

	if IsValid(pHelp) then
		RelapseUI.ShowShopFrame(pHelp)
		return
	end

	local wide, tall = 500, 480

	local scrim = RelapseUI.CreateMenuScrim()
	local Window = vgui.Create("DFrame", scrim)
	Window:SetParent(scrim)
	if Window.SetFocusTopLevel then
		Window:SetFocusTopLevel(false)
	end
	Window:SetSize(wide, tall)
	Window:SetTitle(" ")
	Window:SetDraggable(false)
	Window:SetDeleteOnClose(false)
	Window:SetKeyboardInputEnabled(false)
	Window:SetCursor("pointer")
	RelapseUI.LinkMenuScrim(Window, scrim)
	Window.Close = function(me, instant)
		RelapseUI.FadeCloseMenu(me, instant, function(pnl)
			if not IsValid(pnl) then return end
			pnl:SetVisible(false)
			local host = RelapseUI.MenuHost(pnl)
			if IsValid(host) and host ~= pnl then
				host:SetVisible(false)
				host:SetAlpha(0)
			end
		end)
	end
	pHelp = Window

	local label = EasyLabel(Window, "Help", "ZSHUDFont", color_white)
	label:CenterHorizontal()
	label:AlignTop(8)

	local propertysheet = vgui.Create("DPropertySheet", Window)
	propertysheet:StretchToParent(12, 52, 12, 64)

	for _, helptab in ipairs(GAMEMODE.Help) do
		local htmlpanel = vgui.Create("DHTML", propertysheet)
		htmlpanel:StretchToParent(4, 4, 4, 24)
		htmlpanel:SetHTML([[<html>
		<head>
		<style type="text/css">
		@font-face {
			font-family: Manrope;
			src: url('asset://garrysmod/resource/fonts/Manrope-Regular.ttf') format('truetype');
			font-weight: 400 600;
		}
		@font-face {
			font-family: Manrope;
			src: url('asset://garrysmod/resource/fonts/Manrope-Bold.ttf') format('truetype');
			font-weight: 700 800;
		}
		body
		{
			font-family: Manrope, sans-serif;
			font-size: 13px;
			color: white;
			background-color: black;
			width:]].. htmlpanel:GetWide() - 48 ..[[px;
		}
		div p
		{
			margin:10px;
			padding:2px;
		}
		</style>
		</head>
		<body>
<center><span style="font-size:22px;font-weight:bold;color:limegreen;text-decoration:underline;">Zombie Survival</span><br>
]]..translate.Get(helptab.Name)..[[</center><br><br><div>]]..translate.Get(helptab.Content)..[[</div>
</body>
</html>]])
		propertysheet:AddSheet(translate.Get(helptab.Name), htmlpanel, helptab.Icon, false, false)
	end

	Window:Center()

	local button = EasyButton(Window, "Credits", 8, 4)
	button:SetPos(wide - button:GetWide() - 12, tall - button:GetTall() - 12)
	button:SetText("Credits")
	button.DoClick = function()
		if IsValid(pHelp) then
			pHelp:Close(true)
		end
		MakepCredits()
	end

	gamemode.Call("BuildHelpMenu", Window, propertysheet)

	RelapseUI.ShowShopFrame(Window)
end

function GM:BuildHelpMenu(window, propertysheet)
end
