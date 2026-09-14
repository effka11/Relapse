-- Relapse F4 options: shop chrome, tab strip, token form controls.
-- Hidden rows: documents/options-hidden.md

function MakepOptions()
	PlayMenuOpenSound()

	if pOptions and pOptions:IsValid() then
		RelapseUI.ShowShopFrame(pOptions)
		return
	end

	RelapseUI.CreateFonts()

	local frame, L, _, bottomspace, propertysheet = RelapseUI.BuildShopFrame("menu_options", {
		deleteOnClose = false
	})
	pOptions = frame
	if IsValid(bottomspace) then
		bottomspace:SetVisible(false)
	end
	propertysheet:SetSize(L.innerW, L.hei - L.headerh - RelapseUI.Grid15(3))

	local gameTab = RelapseUI.MakeOptionsScroll(propertysheet)

	RelapseUI.OptionsCombo(gameTab, RelapseUI.T("options_prop_snap"), {
		{ RelapseUI.T("options_snap_none"), 0 },
		{ RelapseUI.T("options_snap_15"), 15 },
		{ RelapseUI.T("options_snap_30"), 30 },
		{ RelapseUI.T("options_snap_45"), 45 }
	}, GAMEMODE.PropRotationSnap or 0, function(data)
		RunConsoleCommand("zs_proprotationsnap", data)
	end)

	propertysheet:AddSheet(RelapseUI.T("options_tab_game"), gameTab)

	local hudTab = RelapseUI.MakeOptionsScroll(propertysheet)
	local hudCap = RelapseUI.OptionsCaption(hudTab, RelapseUI.T("options_hud_general"))
	-- Check cap sits 5px into the row; 2 cells minus that = 30 to the capital.
	hudCap:DockMargin(0, 0, 0, RelapseUI.Grid15(2) - RelapseUI.sPx(5))
	RelapseUI.OptionsCheck(hudTab, RelapseUI.T("options_draw_xp"), "zs_drawxp")
	propertysheet:AddSheet(RelapseUI.T("options_tab_hud"), hudTab)

	local tabs = {}
	for i, item in ipairs(propertysheet.Items or {}) do
		tabs[i] = item.Tab
	end
	GAMEMODE:ConfigureMenuTabs(tabs, L.tabhei)
	RelapseUI.FinishShopFrame(frame, propertysheet)
end
