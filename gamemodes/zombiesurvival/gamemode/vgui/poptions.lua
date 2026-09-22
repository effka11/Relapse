-- Relapse F4 options: shop chrome, tab strip, token form controls.
-- Hidden rows: documents/options-hidden.md

function MakepOptions()
	if GAMEMODE.CloseOtherOverlays then
		GAMEMODE:CloseOtherOverlays("options")
	end
	PlayMenuOpenSound()

	if pOptions and pOptions:IsValid() then
		RelapseUI.ShowShopFrame(pOptions)
		if RelapseUI.SyncAmmoPackSliders then
			RelapseUI.SyncAmmoPackSliders()
		end
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

	local shopCap = RelapseUI.OptionsCaption(gameTab, RelapseUI.T("options_shop_heading"))
	shopCap:DockMargin(0, RelapseUI.Grid15(3), 0, RelapseUI.Grid15(2))

	local min = GAMEMODE.RelapseAmmoPrice and GAMEMODE.RelapseAmmoPrice.ShopPointsMin or 5
	local max = GAMEMODE.RelapseAmmoPrice and GAMEMODE.RelapseAmmoPrice.ShopPointsMax or 75
	local step = GAMEMODE.RelapseAmmoPrice and GAMEMODE.RelapseAmmoPrice.ShopPointsStep or 5
	local packSlider, packWrap, packCap = RelapseUI.OptionsStepSlider(gameTab, RelapseUI.T("options_shop_ammo_pack"), "zs_ammopackpoints", min, max, step)
	RelapseUI.BindAmmoPackSlider(packSlider, "default")
	local packTip = RelapseUI.T("options_shop_ammo_pack_tip")
	packSlider:SetTooltip(packTip)
	if IsValid(packWrap) then
		packWrap:SetTooltip(packTip)
	end
	if IsValid(packCap) then
		packCap:SetTooltip(packTip)
		packCap:SetMouseInputEnabled(true)
	end

	local saveCheck = RelapseUI.OptionsCheck(gameTab, RelapseUI.T("options_shop_ammo_remember"), "zs_ammopackremember")
	saveCheck:SetTooltip(RelapseUI.T("options_shop_ammo_remember_tip"))

	local saveBox = vgui.Create("DPanel", gameTab)
	saveBox:SetPaintBackground(false)
	saveBox.Paint = function() return true end
	saveBox:Dock(TOP)
	saveBox:SetMouseInputEnabled(true)
	saveBox:SetTooltip(RelapseUI.T("options_shop_ammo_remember_scope_tip"))

	local rememberCombo = RelapseUI.OptionsCombo(saveBox, RelapseUI.T("options_shop_ammo_remember_scope"), {
		{ RelapseUI.T("options_shop_ammo_remember_window"), "window" },
		{ RelapseUI.T("options_shop_ammo_remember_game"), "game" },
		{ RelapseUI.T("options_shop_ammo_remember_always"), "always" }
	}, GetConVar("zs_ammopackremembermode") and GetConVar("zs_ammopackremembermode"):GetString() or "window", function(data)
		RunConsoleCommand("zs_ammopackremembermode", data)
	end)
	rememberCombo:SetTooltip(RelapseUI.T("options_shop_ammo_remember_scope_tip"))

	local function layoutSaveBox()
		local on = GetConVar("zs_ammopackremember") and GetConVar("zs_ammopackremember"):GetBool()
		saveBox:SetVisible(on)
		saveBox:SetTall(on and RelapseUI.Grid15(9) or 0)
	end
	saveCheck.DoClick = function(me)
		local cv = GetConVar(me.RelapseCvar)
		if not cv then return end
		cv:SetBool(not cv:GetBool())
		layoutSaveBox()
	end
	layoutSaveBox()

	propertysheet:AddSheet(RelapseUI.T("options_tab_game"), gameTab)

	local hudTab = RelapseUI.MakeOptionsScroll(propertysheet)
	local hudCap = RelapseUI.OptionsCaption(hudTab, RelapseUI.T("options_hud_general"))
	hudCap:DockMargin(0, 0, 0, RelapseUI.OptionsCheckGap())
	RelapseUI.OptionsCheck(hudTab, RelapseUI.T("options_draw_xp"), "zs_drawxp")
	RelapseUI.OptionsCheck(hudTab, RelapseUI.T("options_window_transparency"), "zs_windowtransparency")
	propertysheet:AddSheet(RelapseUI.T("options_tab_hud"), hudTab)

	local tabs = {}
	for i, item in ipairs(propertysheet.Items or {}) do
		tabs[i] = item.Tab
	end
	GAMEMODE:ConfigureMenuTabs(tabs, L.tabhei)
	RelapseUI.FinishShopFrame(frame, propertysheet)
end
