-- Shop card icon editor. `relapse_iconsdev` toggles; sliders are live deltas.
-- Kind `shop` writes CardIcon*; `inv` writes InvSlotIcon*.

RelapseUI.IconsDevDelta = RelapseUI.IconsDevDelta or {}
RelapseUI.IconsDevInvDelta = RelapseUI.IconsDevInvDelta or {}
RelapseUI.IconsDevKind = RelapseUI.IconsDevKind or "shop"

local function Enabled()
	return RelapseUI.IconsDevOn == true
end

local function IsInv()
	return RelapseUI.IconsDevKind == "inv"
end

local function DeltaStore()
	if IsInv() then
		RelapseUI.IconsDevInvDelta = RelapseUI.IconsDevInvDelta or {}
		return RelapseUI.IconsDevInvDelta
	end
	RelapseUI.IconsDevDelta = RelapseUI.IconsDevDelta or {}
	return RelapseUI.IconsDevDelta
end

local ActiveShop

local function LuaNum(n, digits)
	n = math.Round(tonumber(n) or 0, digits)
	local s = string.format("%." .. digits .. "f", n)
	s = s:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return s
end

local function LuaKey(class)
	if string.match(class or "", "^[%a_][%w_]*$") then
		return class
	end
	return string.format("[%q]", class)
end

local function EnsureDelta(class)
	if not class then return end
	local store = DeltaStore()
	local d = store[class]
	if not d then
		d = { zoom = 0, ang = 0, x = 0, y = 0, gap = 0, count = 0 }
		store[class] = d
	else
		d.zoom = d.zoom or 0
		d.ang = d.ang or 0
		d.x = d.x or 0
		d.y = d.y or 0
		d.gap = d.gap or 0
		d.count = d.count or 0
	end
	return d
end

local function LiveValues(class)
	if IsInv() then
		local x, y = RelapseUI.InvSlotIconShiftValue(class)
		return RelapseUI.InvSlotIconZoomValue(class), RelapseUI.InvSlotIconTiltValue(class), x, y
	end
	local x, y = RelapseUI.CardIconPosValue(class)
	return RelapseUI.CardIconZoomValue(class), RelapseUI.CardIconAngValue(class), x, y
end

function RelapseUI.IconsDevItemName(class)
	if not class or class == "" then
		return ""
	end
	local wep = weapons.GetStored(class)
	if wep then
		local n = RelapseUI.WepName(wep)
		if n and n ~= "" then
			return n
		end
	end
	if GAMEMODE and GAMEMODE.Items then
		for _, tab in ipairs(GAMEMODE.Items) do
			if tab.SWEP == class then
				local n = RelapseUI.WepName(tab)
				if n and n ~= "" then
					return n
				end
			end
		end
	end
	if GAMEMODE and ((GAMEMODE.RelapseAmmo and GAMEMODE.RelapseAmmo[class]) or (GAMEMODE.RelapseShopPacks and GAMEMODE.RelapseShopPacks[class])) then
		local n = RelapseUI.ShopAmmo(class)
		if n and n ~= "" then
			return n
		end
	end
	return class
end

function RelapseUI.IconsDevCollect()
	local rows = {}
	for class, d in pairs(DeltaStore()) do
		if not class or class == "" then
			continue
		end
		if not (d and ((tonumber(d.zoom) or 0) ~= 0 or (tonumber(d.ang) or 0) ~= 0 or (tonumber(d.x) or 0) ~= 0 or (tonumber(d.y) or 0) ~= 0 or (tonumber(d.gap) or 0) ~= 0 or (tonumber(d.count) or 0) ~= 0)) then
			continue
		end
		local z, a, px, py = LiveValues(class)
		local gap = RelapseUI.AmmoIconGapValue and RelapseUI.AmmoIconGapValue(class, IsInv()) or nil
		local count = RelapseUI.AmmoIconCountValue and RelapseUI.AmmoIconCountValue(class, IsInv()) or nil
		rows[#rows + 1] = {
			class = class,
			name = RelapseUI.IconsDevItemName(class),
			zoom = math.Round(z, 2),
			ang = math.Round(a, 1),
			x = math.Round(px, 0),
			y = math.Round(py, 0),
			gap = gap,
			count = count
		}
	end
	table.sort(rows, function(x, y)
		if x.name == y.name then
			return x.class < y.class
		end
		return x.name < y.name
	end)
	return rows
end

function RelapseUI.IconsDevDumpText()
	local rows = RelapseUI.IconsDevCollect()
	local zoomKey = IsInv() and "RelapseUI.InvSlotIconZoom" or "RelapseUI.CardIconZoom"
	local angKey = IsInv() and "RelapseUI.InvSlotIconTilt" or "RelapseUI.CardIconAng"
	local posKey = IsInv() and "RelapseUI.InvSlotIconShift" or "RelapseUI.CardIconPos"
	local lines = {}
	lines[#lines + 1] = "Имя\tРазмер\tУгол\tX\tY"
	for _, r in ipairs(rows) do
		lines[#lines + 1] = string.format("%s\t%s\t%s\t%s\t%s", r.name, LuaNum(r.zoom, 2), LuaNum(r.ang, 1), LuaNum(r.x, 0), LuaNum(r.y, 0))
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = zoomKey .. " = {"
	for _, r in ipairs(rows) do
		if math.abs(r.zoom - 1) > 0.001 then
			lines[#lines + 1] = string.format("\t%s = %s, -- %s", LuaKey(r.class), LuaNum(r.zoom, 2), r.name)
		end
	end
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = angKey .. " = {"
	for _, r in ipairs(rows) do
		local dumpAng = (IsInv() and math.abs(r.ang - 45) >= 0.05) or (not IsInv() and math.abs(r.ang) > 0.05)
		if dumpAng then
			lines[#lines + 1] = string.format("\t%s = %s, -- %s", LuaKey(r.class), LuaNum(r.ang, 1), r.name)
		end
	end
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = posKey .. " = {"
	for _, r in ipairs(rows) do
		if math.abs(r.x) >= 1 or math.abs(r.y) >= 1 then
			lines[#lines + 1] = string.format("\t%s = { %s, %s }, -- %s", LuaKey(r.class), LuaNum(r.x, 0), LuaNum(r.y, 0), r.name)
		end
	end
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "RelapseUI.AmmoIconGap = {"
	for _, r in ipairs(rows) do
		local base = RelapseUI.AmmoIconGapDefault or 18
		if r.gap and math.abs(r.gap - base) >= 0.5 then
			lines[#lines + 1] = string.format("\t%s = %s, -- %s", LuaKey(r.class), LuaNum(r.gap, 0), r.name)
		end
	end
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "RelapseUI.AmmoIconCount = {"
	for _, r in ipairs(rows) do
		local base = RelapseUI.AmmoIconCountDefault or 3
		if r.count and math.abs(r.count - base) >= 0.5 then
			lines[#lines + 1] = string.format("\t%s = %s, -- %s", LuaKey(r.class), LuaNum(r.count, 0), r.name)
		end
	end
	lines[#lines + 1] = "}"
	return table.concat(lines, "\n"), rows
end

local function SetSliderSilent(slider, val)
	if not IsValid(slider) then return end
	slider._RelapseSilent = true
	slider:SetValue(val)
	slider._RelapseSilent = false
end

local function CopyDump()
	local text = RelapseUI.IconsDevDumpText()
	RelapseUI.IconsDevLastDump = text
	SetClipboardText(text)
	print(text)
	file.Write(IsInv() and "relapse_invicons.lua" or "relapse_cardicons.lua", text)
	return text
end

local function ResetCurrent()
	local class = RelapseUI.IconsDevClass
	if not class then return end
	DeltaStore()[class] = nil
end

local function MakeSlider(parent, min, max, decimals)
	local slider = vgui.Create("DNumSlider", parent)
	slider:SetText("")
	slider:SetMinMax(min, max)
	slider:SetDecimals(decimals)
	slider:SetValue(0)
	if IsValid(slider.Label) then
		slider.Label:SetVisible(false)
		slider.Label:SetText("")
		slider.Label:SetWide(0)
	end
	RelapseUI.StyleNumSlider(slider)
	if IsValid(slider.TextArea) then
		slider.TextArea:SetTextColor(RelapseUI.Col.Text)
		slider.TextArea.Paint = function(me, w, h)
			draw.SimpleText(me:GetValue(), "Relapse20", w, h * 0.5, RelapseUI.Col.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			return true
		end
	end
	slider.PerformLayout = function(me, w, h)
		w = w or me:GetWide()
		h = h or me:GetTall()
		local text = me.TextArea
		local slide = me.Slider
		local tw = RelapseUI.Grid15(4)
		if IsValid(me.Label) then
			me.Label:SetVisible(false)
			me.Label:SetSize(0, 0)
		end
		if IsValid(text) then
			text:SetSize(tw, h)
			text:SetPos(w - tw, 0)
		end
		if IsValid(slide) then
			slide:SetPos(0, 0)
			slide:SetSize(math.max(1, w - tw - RelapseUI.Grid15()), h)
		end
	end
	return slider
end

local function FitName(name, maxW)
	surface.SetFont("Relapse15")
	if surface.GetTextSize(name) <= maxW then
		return name
	end
	local ell = "…"
	local n = (utf8 and utf8.len(name)) or #name
	for i = n, 1, -1 do
		local cut
		if utf8 and utf8.offset then
			cut = utf8.offset(name, i + 1)
		end
		local s = string.sub(name, 1, (cut or (#name + 1)) - 1) .. ell
		if surface.GetTextSize(s) <= maxW then
			return s
		end
	end
	return ell
end

local function MakeBtn(parent, text, paint, click)
	local btn = vgui.Create("DButton", parent)
	btn:SetText(text)
	btn:SetFont("Relapse20")
	btn:SetTall(RelapseUI.Grid15(3))
	btn:SetPaintBackgroundEnabled(false)
	btn.Paint = paint
	btn.DoClick = click
	return btn
end

local function RefreshDumpPanel(panel)
	if not IsValid(panel) or not IsValid(panel.DumpList) then
		return
	end
	local _, rows = RelapseUI.IconsDevDumpText()
	panel.DumpRows = rows
	local rowH = RelapseUI.Grid15(2)
	panel.DumpList:SetTall(math.max(0, #rows * rowH))
	local canvas = panel.DumpList:GetParent()
	if IsValid(canvas) then
		panel.DumpList:SetWide(math.max(1, canvas:GetWide()))
	end
	panel.DumpList:InvalidateParent(true)
end

local function SyncSliders(panel)
	if not IsValid(panel) then return end
	local class = RelapseUI.IconsDevClass
	local d = class and EnsureDelta(class)
	SetSliderSilent(panel.ZoomSlider, d and d.zoom or 0)
	SetSliderSilent(panel.AngSlider, d and d.ang or 0)
	SetSliderSilent(panel.XSlider, d and d.x or 0)
	SetSliderSilent(panel.YSlider, d and d.y or 0)
	local ammo = class and RelapseUI.AmmoIconRound and RelapseUI.AmmoIconRound[class]
	if IsValid(panel.GapLab) then
		panel.GapLab:SetVisible(ammo and true or false)
		panel.GapLab:SetTall(ammo and RelapseUI.sPx(18) or 0)
	end
	if IsValid(panel.GapSlider) then
		panel.GapSlider:SetVisible(ammo and true or false)
		panel.GapSlider:SetTall(ammo and RelapseUI.Grid15(3) or 0)
		panel.GapSlider:DockMargin(0, 0, 0, ammo and RelapseUI.Grid15() or 0)
		panel.GapSlider:SetEnabled(ammo and true or false)
		local base = (class and RelapseUI.AmmoIconGap and RelapseUI.AmmoIconGap[class]) or RelapseUI.AmmoIconGapDefault or 18
		SetSliderSilent(panel.GapSlider, base + (d and d.gap or 0))
		local host = panel.GapSlider:GetParent()
		if IsValid(host) then
			host:InvalidateLayout(true)
		end
	end
	if IsValid(panel.CountLab) then
		panel.CountLab:SetVisible(ammo and true or false)
		panel.CountLab:SetTall(ammo and RelapseUI.sPx(18) or 0)
	end
	if IsValid(panel.CountSlider) then
		panel.CountSlider:SetVisible(ammo and true or false)
		panel.CountSlider:SetTall(ammo and RelapseUI.Grid15(3) or 0)
		panel.CountSlider:DockMargin(0, 0, 0, ammo and RelapseUI.Grid15() or 0)
		panel.CountSlider:SetEnabled(ammo and true or false)
		local base = (class and RelapseUI.AmmoIconCount and RelapseUI.AmmoIconCount[class]) or RelapseUI.AmmoIconCountDefault or 3
		SetSliderSilent(panel.CountSlider, base + (d and d.count or 0))
	end
	if IsValid(panel.Title) then
		if class then
			panel.Title:SetText(RelapseUI.IconsDevItemName(class))
		else
			panel.Title:SetText("Предмет не выбран")
		end
	end
	local has = class ~= nil
	if IsValid(panel.ZoomSlider) then
		panel.ZoomSlider:SetEnabled(has)
	end
	if IsValid(panel.AngSlider) then
		panel.AngSlider:SetEnabled(has)
	end
	if IsValid(panel.XSlider) then
		panel.XSlider:SetEnabled(has)
	end
	if IsValid(panel.YSlider) then
		panel.YSlider:SetEnabled(has)
	end
	if IsValid(panel.ResetBtn) then
		panel.ResetBtn:SetEnabled(has)
	end
	if IsValid(panel.Note) then
		if not class then
			panel.Note:SetText("")
		elseif RelapseUI.CardIconSmooth and RelapseUI.CardIconSmooth[class] then
			panel.Note:SetText("Иконка сглажена")
			panel.Note:SetTextColor(RelapseUI.Col.Text)
		else
			panel.Note:SetText("Иконка не сглажена")
			panel.Note:SetTextColor(RelapseUI.Col.Muted)
		end
	end
	RefreshDumpPanel(panel)
end

local function WorldParent()
	return vgui.GetWorldPanel()
end

local function VisibleInv()
	local inv = GAMEMODE and GAMEMODE.InventoryMenu
	if IsValid(inv) and inv:IsVisible() then
		return inv
	end
end

local function ResolveAnchor()
	if IsInv() then
		local inv = VisibleInv()
		if inv then
			return inv, true
		end
		local shop = ActiveShop()
		if shop then
			return shop, false
		end
	else
		local shop = ActiveShop()
		if shop then
			return shop, false
		end
		local inv = VisibleInv()
		if inv then
			return inv, true
		end
	end
end

local function AttachPanel(panel, host, invRoot)
	if invRoot then
		if not panel._RelapseInvRoot then
			panel:SetParent()
			panel:MakePopup()
			panel:SetKeyboardInputEnabled(false)
			panel:SetMouseInputEnabled(true)
			panel._RelapseInvRoot = true
			panel._RelapseNeedPlace = true
		end
		return
	end
	if IsValid(host) and (panel._RelapseInvRoot or panel:GetParent() ~= host) then
		panel:SetParent(host)
		panel._RelapseInvRoot = false
		panel:SetKeyboardInputEnabled(false)
		panel:SetMouseInputEnabled(true)
		panel._RelapseNeedPlace = true
	end
end

local function PlaceBeside(panel, anchor, invRoot)
	local gap = RelapseUI.Grid15()
	local x, y = anchor:GetPos()
	local aw = anchor:GetWide()
	if invRoot then
		local actions = GAMEMODE and GAMEMODE.HumanMenuPanel
		if IsValid(actions) and actions:IsVisible() then
			local ax, ay = actions:GetPos()
			if ax + actions:GetWide() > x + aw then
				x, y = ax, ay
				aw = actions:GetWide()
			end
		end
	end
	local pw, ph = panel:GetWide(), panel:GetTall()
	local parent = panel:GetParent()
	local sw, sh = ScrW(), ScrH()
	if IsValid(parent) and parent ~= WorldParent() then
		sw, sh = parent:GetWide(), parent:GetTall()
	end
	local px = x + aw + gap
	if px + pw > sw - gap then
		px = math.max(gap, sw - pw - gap)
	end
	local py = math.Clamp(y, gap, math.max(gap, sh - ph - gap))
	panel:SetPos(px, py)
end

local function EnsurePanel(host)
	local panel = RelapseUI.IconsDevPanel
	if IsValid(panel) then
		return panel
	end

	RelapseUI.CreateFonts()
	local m = RelapseUI.M()
	local pad = RelapseUI.Grid15()
	local headerh = RelapseUI.Grid15(4)
	panel = vgui.Create("DFrame", IsValid(host) and host or nil)
	panel:SetSize(RelapseUI.Grid15(24), RelapseUI.Grid15(58))
	panel:SetDeleteOnClose(false)
	panel:SetKeyboardInputEnabled(false)
	panel:SetTitle("")
	panel:SetDraggable(true)
	panel:SetSizable(false)
	panel:DockPadding(0, 0, 0, 0)
	panel:SetMouseInputEnabled(true)
	panel:SetAlpha(255)
	panel.Paint = RelapseUI.PaintWindow
	panel.DumpRows = {}
	panel._RelapseNeedPlace = true
	panel._RelapseInvRoot = not IsValid(host)
	RelapseUI.HideChrome(panel)
	if panel._RelapseInvRoot then
		panel:MakePopup()
		panel:SetKeyboardInputEnabled(false)
	end
	panel.Close = function(me)
		RelapseUI.IconsDevOn = false
		me:SetVisible(false)
	end

	local title = EasyLabel(panel, "Иконки", "Relapse30", RelapseUI.Col.Text)
	title:SetContentAlignment(4)
	title:SizeToContents()
	title:SetPos(pad, RelapseUI.Grid15(2))

	local close = vgui.Create("DButton", panel)
	close:SetText("×")
	close:SetFont("Relapse30")
	close:SetSize(m.close, m.close)
	close:AlignRight(pad)
	close:AlignTop(RelapseUI.Grid15(2))
	close.Paint = RelapseUI.PaintGhostButton
	close.DoClick = function()
		panel:Close()
	end

	local body = vgui.Create("DPanel", panel)
	body:SetPaintBackground(false)
	body:Dock(FILL)
	body:DockMargin(pad, headerh, pad, pad)
	body:DockPadding(0, 0, 0, 0)

	local modes = vgui.Create("DPanel", body)
	modes:SetTall(RelapseUI.Grid15(3))
	modes:Dock(TOP)
	modes:DockMargin(0, 0, 0, RelapseUI.Grid5())
	modes:SetPaintBackground(false)
	panel.ModeRow = modes

	local function ModePaint(me, w, h)
		if RelapseUI.IconsDevKind == me._RelapseKind then
			return RelapseUI.PaintPrimaryButton(me, w, h)
		end
		return RelapseUI.PaintGhostButton(me, w, h)
	end

	local shopMode = MakeBtn(modes, "Шоп", ModePaint, function()
		RelapseUI.IconsDevSetKind("shop")
	end)
	shopMode._RelapseKind = "shop"
	panel.ShopModeBtn = shopMode

	local invMode = MakeBtn(modes, "Инвентарь", ModePaint, function()
		RelapseUI.IconsDevSetKind("inv")
	end)
	invMode._RelapseKind = "inv"
	panel.InvModeBtn = invMode

	modes.PerformLayout = function(me, w, h)
		w = w or me:GetWide()
		h = h or me:GetTall()
		local gap = RelapseUI.Grid5()
		local bw = math.floor((w - gap) * 0.5)
		shopMode:SetSize(bw, h)
		shopMode:SetPos(0, 0)
		invMode:SetSize(math.max(1, w - bw - gap), h)
		invMode:SetPos(bw + gap, 0)
	end

	local item = EasyLabel(body, "Предмет не выбран", "Relapse20", RelapseUI.Col.Text)
	item:SetContentAlignment(4)
	item:Dock(TOP)
	item:DockMargin(0, 0, 0, RelapseUI.Grid5())
	panel.Title = item

	local zoomLab = EasyLabel(body, "Размер", "Relapse15", RelapseUI.Col.Muted)
	zoomLab:Dock(TOP)
	local zoom = MakeSlider(body, -1.5, 1.5, 2)
	zoom:SetTall(RelapseUI.Grid15(3))
	zoom:Dock(TOP)
	zoom:DockMargin(0, 0, 0, pad)
	zoom.OnValueChanged = function(me, val)
		if me._RelapseSilent then return end
		local class = RelapseUI.IconsDevClass
		if not class then return end
		EnsureDelta(class).zoom = tonumber(val) or 0
		RefreshDumpPanel(panel)
	end
	panel.ZoomSlider = zoom

	local angLab = EasyLabel(body, "Угол", "Relapse15", RelapseUI.Col.Muted)
	angLab:Dock(TOP)
	local ang = MakeSlider(body, -180, 180, 1)
	ang:SetTall(RelapseUI.Grid15(3))
	ang:Dock(TOP)
	ang:DockMargin(0, 0, 0, pad)
	ang.OnValueChanged = function(me, val)
		if me._RelapseSilent then return end
		local class = RelapseUI.IconsDevClass
		if not class then return end
		EnsureDelta(class).ang = tonumber(val) or 0
		RefreshDumpPanel(panel)
	end
	panel.AngSlider = ang

	local xLab = EasyLabel(body, "X", "Relapse15", RelapseUI.Col.Muted)
	xLab:Dock(TOP)
	local xSlider = MakeSlider(body, -48, 48, 0)
	xSlider:SetTall(RelapseUI.Grid15(3))
	xSlider:Dock(TOP)
	xSlider:DockMargin(0, 0, 0, pad)
	xSlider.OnValueChanged = function(me, val)
		if me._RelapseSilent then return end
		local class = RelapseUI.IconsDevClass
		if not class then return end
		EnsureDelta(class).x = tonumber(val) or 0
		RefreshDumpPanel(panel)
	end
	panel.XSlider = xSlider

	local yLab = EasyLabel(body, "Y", "Relapse15", RelapseUI.Col.Muted)
	yLab:Dock(TOP)
	local ySlider = MakeSlider(body, -48, 48, 0)
	ySlider:SetTall(RelapseUI.Grid15(3))
	ySlider:Dock(TOP)
	ySlider:DockMargin(0, 0, 0, pad)
	ySlider.OnValueChanged = function(me, val)
		if me._RelapseSilent then return end
		local class = RelapseUI.IconsDevClass
		if not class then return end
		EnsureDelta(class).y = tonumber(val) or 0
		RefreshDumpPanel(panel)
	end
	panel.YSlider = ySlider

	local gapLab = EasyLabel(body, "Отступ", "Relapse15", RelapseUI.Col.Muted)
	gapLab:Dock(TOP)
	gapLab:SetVisible(false)
	gapLab:SetTall(0)
	panel.GapLab = gapLab
	local gapSlider = MakeSlider(body, 0, 64, 0)
	gapSlider:SetTall(0)
	gapSlider:Dock(TOP)
	gapSlider:SetVisible(false)
	gapSlider.OnValueChanged = function(me, val)
		if me._RelapseSilent then return end
		local class = RelapseUI.IconsDevClass
		if not class then return end
		local base = (RelapseUI.AmmoIconGap and RelapseUI.AmmoIconGap[class]) or RelapseUI.AmmoIconGapDefault or 18
		EnsureDelta(class).gap = (tonumber(val) or base) - base
		RefreshDumpPanel(panel)
	end
	panel.GapSlider = gapSlider

	local countLab = EasyLabel(body, "Количество", "Relapse15", RelapseUI.Col.Muted)
	countLab:Dock(TOP)
	countLab:SetVisible(false)
	countLab:SetTall(0)
	panel.CountLab = countLab
	local countSlider = MakeSlider(body, 1, 7, 0)
	countSlider:SetTall(0)
	countSlider:Dock(TOP)
	countSlider:SetVisible(false)
	countSlider.OnValueChanged = function(me, val)
		if me._RelapseSilent then return end
		local class = RelapseUI.IconsDevClass
		if not class then return end
		local base = (RelapseUI.AmmoIconCount and RelapseUI.AmmoIconCount[class]) or RelapseUI.AmmoIconCountDefault or 3
		EnsureDelta(class).count = (tonumber(val) or base) - base
		RefreshDumpPanel(panel)
	end
	panel.CountSlider = countSlider

	local btns = vgui.Create("DPanel", body)
	btns:SetTall(RelapseUI.Grid15(3))
	btns:Dock(TOP)
	btns:DockMargin(0, 0, 0, pad)
	btns:SetPaintBackground(false)

	local copy = MakeBtn(btns, "Копировать", RelapseUI.PaintPrimaryButton, function(me)
		CopyDump()
		me:SetText("Скопировано")
		timer.Create("RelapseIconsDevCopyLabel", 1.2, 1, function()
			if IsValid(me) then
				me:SetText("Копировать")
			end
		end)
	end)
	panel.CopyBtn = copy

	local reset = MakeBtn(btns, "Сброс", RelapseUI.PaintGhostButton, function()
		ResetCurrent()
		SyncSliders(panel)
	end)
	panel.ResetBtn = reset

	btns.PerformLayout = function(me, w, h)
		w = w or me:GetWide()
		h = h or me:GetTall()
		local gap = RelapseUI.Grid5()
		local bw = math.floor((w - gap) * 0.5)
		copy:SetSize(bw, h)
		copy:SetPos(0, 0)
		reset:SetSize(math.max(1, w - bw - gap), h)
		reset:SetPos(bw + gap, 0)
	end

	local note = EasyLabel(body, "", "Relapse15", RelapseUI.Col.Muted)
	note:SetContentAlignment(4)
	note:SetTall(RelapseUI.Grid15(2))
	note:Dock(BOTTOM)
	note:DockMargin(0, RelapseUI.Grid5(), 0, 0)
	panel.Note = note

	local head = vgui.Create("DPanel", body)
	head:SetTall(RelapseUI.Grid15(2))
	head:Dock(TOP)
	head:SetPaintBackground(false)
	head.Paint = function(me, w, h)
		local c = RelapseUI.Col.Muted
		draw.SimpleText("Имя", "Relapse15", 0, h * 0.5, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Размер", "Relapse15", w - RelapseUI.Grid15(12), h * 0.5, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Угол", "Relapse15", w - RelapseUI.Grid15(8), h * 0.5, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.SimpleText("X", "Relapse15", w - RelapseUI.Grid15(4), h * 0.5, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Y", "Relapse15", w, h * 0.5, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		return true
	end

	local scroll = vgui.Create("DScrollPanel", body)
	scroll:Dock(FILL)
	RelapseUI.StyleScroll(scroll)

	local list = vgui.Create("DPanel", scroll)
	list:Dock(TOP)
	list:SetPaintBackground(false)
	list.Paint = function(me, w, h)
		local rows = panel.DumpRows or {}
		local rowH = RelapseUI.Grid15(2)
		local c = RelapseUI.Col.Text
		local nameW = math.max(1, w - RelapseUI.Grid15(16))
		for i, r in ipairs(rows) do
			local y = (i - 1) * rowH + rowH * 0.5
			draw.SimpleText(FitName(r.name, nameW), "Relapse15", 0, y, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(LuaNum(r.zoom, 2), "Relapse15", w - RelapseUI.Grid15(12), y, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			draw.SimpleText(LuaNum(r.ang, 1), "Relapse15", w - RelapseUI.Grid15(8), y, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			draw.SimpleText(LuaNum(r.x, 0), "Relapse15", w - RelapseUI.Grid15(4), y, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			draw.SimpleText(LuaNum(r.y, 0), "Relapse15", w, y, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		return true
	end
	panel.DumpList = list

	close:MoveToFront()

	local oldThink = panel.Think
	panel.Think = function(me)
		if oldThink then oldThink(me) end
		RelapseUI.IconsDevLayout()
	end

	RelapseUI.IconsDevPanel = panel
	return panel
end

function ActiveShop()
	local shop = RelapseUI.IconsDevShop
	if IsValid(shop) and shop:IsVisible() then
		return shop
	end
	if IsValid(pWorth) and pWorth:IsVisible() then
		return pWorth
	end
	local arsenal = GAMEMODE and GAMEMODE.ArsenalInterface
	if IsValid(arsenal) and arsenal:IsVisible() then
		return arsenal
	end
end

function RelapseUI.IconsDevLayout()
	local panel = RelapseUI.IconsDevPanel
	if not IsValid(panel) then return end
	if not Enabled() then
		panel:SetVisible(false)
		return
	end

	local anchor, invRoot = ResolveAnchor()
	if not IsValid(anchor) then
		panel:SetVisible(false)
		return
	end
	if not invRoot then
		RelapseUI.IconsDevShop = anchor
	end

	local host = invRoot and WorldParent() or RelapseUI.MenuHost(anchor)
	AttachPanel(panel, host, invRoot)

	if panel._RelapseNeedPlace then
		panel._RelapseNeedPlace = nil
		PlaceBeside(panel, anchor, invRoot)
	end
	panel:SetAlpha(255)
	panel:SetVisible(true)
	panel:MoveToFront()
end

function RelapseUI.IconsDevRaise()
	local panel = RelapseUI.IconsDevPanel
	if IsValid(panel) and panel:IsVisible() then
		panel:MoveToFront()
	end
end

function RelapseUI.IconsDevRefresh()
	if not Enabled() then
		if IsValid(RelapseUI.IconsDevPanel) then
			RelapseUI.IconsDevPanel:SetVisible(false)
		end
		return
	end
	local anchor, invRoot = ResolveAnchor()
	if not IsValid(anchor) then
		if IsValid(RelapseUI.IconsDevPanel) then
			RelapseUI.IconsDevPanel:SetVisible(false)
		end
		return
	end
	if not invRoot then
		RelapseUI.IconsDevShop = anchor
	end
	local host = invRoot and nil or RelapseUI.MenuHost(anchor)
	local panel = EnsurePanel(host)
	if not IsValid(panel) then return end
	AttachPanel(panel, invRoot and WorldParent() or host, invRoot)
	if not panel:IsVisible() then
		panel._RelapseNeedPlace = true
	end
	SyncSliders(panel)
	RelapseUI.IconsDevLayout()
end

function RelapseUI.IconsDevSetKind(kind)
	if kind ~= "inv" then
		kind = "shop"
	end
	RelapseUI.IconsDevKind = kind
	if IsValid(RelapseUI.IconsDevPanel) then
		RelapseUI.IconsDevPanel._RelapseNeedPlace = true
	end
	if Enabled() then
		RelapseUI.IconsDevRefresh()
	end
end

function RelapseUI.IconsDevBindShop(frame)
	RelapseUI.IconsDevShop = frame
	RelapseUI.IconsDevKind = "shop"
	if IsValid(RelapseUI.IconsDevPanel) then
		RelapseUI.IconsDevPanel._RelapseNeedPlace = true
	end
	if Enabled() then
		RelapseUI.IconsDevRefresh()
	elseif IsValid(RelapseUI.IconsDevPanel) then
		RelapseUI.IconsDevPanel:SetVisible(false)
	end
end

function RelapseUI.IconsDevBindInv(frame)
	RelapseUI.IconsDevInv = frame
	RelapseUI.IconsDevKind = "inv"
	if IsValid(RelapseUI.IconsDevPanel) then
		RelapseUI.IconsDevPanel._RelapseNeedPlace = true
	end
	if Enabled() then
		RelapseUI.IconsDevRefresh()
	elseif IsValid(RelapseUI.IconsDevPanel) then
		RelapseUI.IconsDevPanel:SetVisible(false)
	end
end

function RelapseUI.IconsDevSelect(tab, kind)
	if kind == "inv" or kind == "shop" then
		if RelapseUI.IconsDevKind ~= kind then
			RelapseUI.IconsDevKind = kind
			if IsValid(RelapseUI.IconsDevPanel) then
				RelapseUI.IconsDevPanel._RelapseNeedPlace = true
			end
		end
	end
	if isstring(tab) then
		RelapseUI.IconsDevClass = tab ~= "" and tab or nil
	else
		RelapseUI.IconsDevClass = tab and (tab.AmmoPack or tab.SWEP or tab.Signature) or nil
	end
	if Enabled() then
		RelapseUI.IconsDevRefresh()
	end
end

concommand.Add("relapse_iconsdev", function(_, _, args)
	if args[1] ~= nil and args[1] ~= "" then
		local v = string.lower(tostring(args[1]))
		RelapseUI.IconsDevOn = not (v == "0" or v == "false" or v == "off")
	else
		RelapseUI.IconsDevOn = not RelapseUI.IconsDevOn
	end
	print("relapse_iconsdev = " .. (RelapseUI.IconsDevOn and "1" or "0"))
	RelapseUI.IconsDevRefresh()
end)
