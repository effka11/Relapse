RelapseUI = RelapseUI or {}

-- Shared shop 3D camera. Per-gun etalon (PM/1911/.357/680/SKS): .cursor/rules/relapse-shop-preview.mdc
RelapseUI.PreviewEtalon = {
	FOV = 43,
	CamScale = 1.4,
	Lift = 3.5,
	SpanMul = 1.32,
	CamDir = Vector(0.82, 0.52, 0.34),
}

-- Quantum 5/15 (Flora layout law). Colours stay in sh_relapse_theme.lua.
-- Grid5 / Grid15 = Flora --flora-grid-step-fine / --flora-grid-step.
-- sPx = extra-grid only (type, icons, radii, hairlines).
RelapseUI.FINE = 5
RelapseUI.STEP = 15

local function Round(n)
	return math.floor(n + 0.5)
end

function RelapseUI.S()
	local raw = math.max(ScrH() / 1080, 0.6)
	if GAMEMODE and GAMEMODE.InterfaceSize then
		raw = raw * GAMEMODE.InterfaceSize
	end
	local k = math.max(3, Round(raw * 5))
	return k / 5
end

function RelapseUI.sPx(n)
	return Round(n * RelapseUI.S())
end

function RelapseUI.Fine()
	return RelapseUI.FINE * RelapseUI.S()
end

function RelapseUI.Step()
	return RelapseUI.STEP * RelapseUI.S()
end

function RelapseUI.Grid5(n)
	return (n or 1) * RelapseUI.Fine()
end

function RelapseUI.Grid15(n)
	return (n or 1) * RelapseUI.Step()
end

function RelapseUI.Cells(n)
	return RelapseUI.Grid15(n)
end

function RelapseUI.Snap(n)
	local step = RelapseUI.Grid15()
	return math.floor((n or 0) / step + 0.5) * step
end

function RelapseUI.M()
	local step = RelapseUI.Grid15()
	return {
		s = RelapseUI.S(),
		step = step,
		fine = RelapseUI.Grid5(),
		pad = RelapseUI.Grid15(3),
		header = RelapseUI.Grid15(6),
		tabs = RelapseUI.Grid15(3),
		tabGap = RelapseUI.Grid15(2),
		footer = RelapseUI.Grid15(5) + RelapseUI.sPx(15),
		sidebar = RelapseUI.ViewerW(),
		gutter = RelapseUI.Grid15(),
		cardGap = RelapseUI.Grid15(2),
		scroll = RelapseUI.ScrollGap() + RelapseUI.ScrollBarW(),
		cardH = RelapseUI.Grid15(7),
		trinketH = RelapseUI.Grid15(5),
		cardPad = RelapseUI.Grid15(),
		btnH = RelapseUI.Grid15(3),
		close = RelapseUI.Grid15(3)
	}
end

function RelapseUI.ScrollBarW()
	return RelapseUI.sPx(10)
end

function RelapseUI.ScrollGap()
	return RelapseUI.Grid15(2)
end

function RelapseUI.ViewerGap()
	return RelapseUI.sPx(45)
end

function RelapseUI.ViewerW()
	return RelapseUI.sPx(300)
end

-- Inventory presentation column. Grid15(24) minus 5px width and 5px side inset.
function RelapseUI.InvViewerW()
	return RelapseUI.Grid15(24) - RelapseUI.Grid5()
end

function RelapseUI.InvViewerInnerW()
	local side = RelapseUI.Grid15(2) - RelapseUI.Grid5()
	return RelapseUI.InvViewerW() - side * 2
end

-- Relapse20 hang sPx(5). Inventory chrome uses RelapseInvTitleGap (45px visual).
function RelapseUI.ViewerTitleTop(viewer)
	local hang = RelapseUI.sPx(5)
	local visual = RelapseUI.sPx(15)
	if IsValid(viewer) and viewer.RelapseInvTitleGap then
		visual = viewer.RelapseInvTitleGap
	end
	return visual - hang
end

-- Full weapon presentation: title, ammo, model, desc, six stat rows, pad.
function RelapseUI.ViewerH()
	local titleTop = RelapseUI.sPx(45) - RelapseUI.sPx(5)
	local titleH = RelapseUI.sPx(20)
	local ammoY = titleTop + titleH + RelapseUI.sPx(15)
	local visualTop = ammoY + RelapseUI.ViewerModelH() + RelapseUI.Grid15()
	local firstY = visualTop + RelapseUI.ViewerDescH() + RelapseUI.Grid15(2) + RelapseUI.Grid5()
	local barH = RelapseUI.Grid5(2)
	local barGap = RelapseUI.Grid15(2)
	local n = RelapseUI.ViewerStatMax()
	local statsBottom = firstY
	if n > 0 then
		statsBottom = firstY + n * barH + (n - 1) * barGap
	end
	return statsBottom + RelapseUI.M().pad
end

-- Universal shop preview: wide enough for rifles, short enough to sit beside ammo.
function RelapseUI.ViewerModelW()
	return RelapseUI.Grid15(11)
end

function RelapseUI.ViewerModelH()
	return RelapseUI.Grid15(7)
end

function RelapseUI.ViewerDescH()
	return RelapseUI.Grid15(4)
end

function RelapseUI.ViewerStatMax()
	return 6
end

function RelapseUI.ViewerStatLeft()
	return RelapseUI.sPx(90)
end

function RelapseUI.ViewerStatRight()
	return RelapseUI.sPx(75)
end

function RelapseUI.CardIconPath(tab)
	if not tab then return nil end

	if GAMEMODE and GAMEMODE.BindRelapseWeapon then
		GAMEMODE:BindRelapseWeapon(tab)
	end

	if isstring(tab.RelapsePreviewIcon) and tab.RelapsePreviewIcon ~= "" then
		return tab.RelapsePreviewIcon
	end

	local class = tab.SWEP
	local wep = class and weapons.GetStored(class)
	if wep and isstring(wep.RelapsePreviewIcon) and wep.RelapsePreviewIcon ~= "" then
		return wep.RelapsePreviewIcon
	end

	local def = GAMEMODE and GAMEMODE.RelapseWeapons and class and GAMEMODE.RelapseWeapons[class]
	if def and isstring(def.PreviewIcon) and def.PreviewIcon ~= "" then
		return def.PreviewIcon
	end

	-- MW workshop killicons are CAC spawn renders. They punch holes / cyan boxes in the card.
	if class then
		local kitbl = killicon.Get(class)
		if istable(kitbl) and #kitbl == 2 and isstring(kitbl[1]) then
			local path = string.lower(kitbl[1])
			if not string.find(path, "vgui/entities", 1, true) and not string.find(path, "spawnicons", 1, true) then
				return kitbl[1]
			end
		end
	end

	return nil
end

function RelapseUI.AmmoIconPath(ammoId)
	if not isstring(ammoId) or ammoId == "" then return nil end
	local id = string.lower(ammoId)
	local gm = GAMEMODE
	local name = gm and gm.AmmoIcons and gm.AmmoIcons[id]
	if not name and gm and gm.RelapseAmmo and gm.RelapseAmmo[id] then
		name = gm.RelapseAmmo[id].Icon
	end
	if not name then return nil end
	local ki = killicon.Get(name)
	if istable(ki) and #ki == 2 and isstring(ki[1]) then
		return ki[1]
	end
	return nil
end

function RelapseUI.FitIcon(img, maximgx, maximgy)
	if not IsValid(img) then return end
	if img.SizeToContents then
		img:SizeToContents()
	end
	local iwidth, height = img:GetSize()
	if height > maximgy and height > 0 then
		img:SetSize(maximgy / height * img:GetWide(), maximgy)
		iwidth, height = img:GetSize()
	end
	if iwidth > maximgx and iwidth > 0 then
		local s = maximgx / iwidth
		img:SetSize(maximgx, height * s)
	end
	img:Center()
end

function RelapseUI.MakeSilhouetteIcon(parent, path)
	local img = vgui.Create("DImage", parent)
	img:SetMouseInputEnabled(false)
	img:SetKeepAspect(true)
	img:SetImage(path)
	img:SetImageColor(RelapseUI.Col.Text)
	img:SizeToContents()
	return img
end

-- Inventory / HUD 1-9: shop silhouettes face right. Mirror, then tilt muzzle up-left.
RelapseUI.InvSlotIconZoom = {
	mg_uzulu = 1.12,
	mg_m1911 = 1.12,
	mg_sksierra = 1.40,
	mg_romeo870 = 1.30,
	weapon_zs_hammer = 0.8,
	weapon_zs_wrench = 0.90,
	mg_357 = 1.15,
	mg_makarov = 1.4,
	mg_me_t9cane = 1.4,
}
-- Extra-grid px, +x is right, +y is down.
RelapseUI.InvSlotIconShift = {
	mg_uzulu = { -4, 1 },
	mg_m1911 = { -4, 1 },
	mg_sksierra = { -3, 0 },
	mg_romeo870 = { -3, 0 },
	mg_cinderblock = { -3, 0 },
	weapon_zs_wrench = { -1, 0 },
	mg_357 = { -2, 2 },
	mg_makarov = { -4, 1 },
	mg_me_t9cane = { -1, 2 },
}

function RelapseUI.DrawInvSlotIcon(mat, w, h, col, class)
	if not mat or mat:IsError() then return end
	col = col or RelapseUI.Col.Text
	local pad = RelapseUI.Grid5()
	local tw, th = mat:Width(), mat:Height()
	if tw < 1 then tw = 1 end
	if th < 1 then th = 1 end
	local maxs = math.max(1, w - pad * 2)
	local tilt = 45
	local ac, as = math.abs(math.cos(math.rad(tilt))), math.abs(math.sin(math.rad(tilt)))
	local scale = math.min(maxs / math.max(1, tw * ac + th * as), maxs / math.max(1, th * ac + tw * as))
	scale = scale * ((class and RelapseUI.InvSlotIconZoom[class]) or 1)
	local iw, ih = tw * scale, th * scale
	local shift = (class and RelapseUI.InvSlotIconShift[class]) or 0
	local sx, sy = 0, 0
	if istable(shift) then
		sx, sy = shift[1] or 0, shift[2] or 0
	else
		sx = shift
	end
	local cx, cy = w * 0.5 + RelapseUI.sPx(sx), h * 0.5 + RelapseUI.sPx(sy)
	local hw, hh = iw * 0.5, ih * 0.5
	local ang = math.rad(tilt)
	local c, s = math.cos(ang), math.sin(ang)
	local function xf(lx, ly)
		return cx + lx * c - ly * s, cy + lx * s + ly * c
	end
	local x1, y1 = xf(-hw, -hh)
	local x2, y2 = xf(hw, -hh)
	local x3, y3 = xf(hw, hh)
	local x4, y4 = xf(-hw, hh)
	surface.SetMaterial(mat)
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	local v1 = { x = x1, y = y1, u = 1, v = 0 }
	local v2 = { x = x2, y = y2, u = 0, v = 0 }
	local v3 = { x = x3, y = y3, u = 0, v = 1 }
	local v4 = { x = x4, y = y4, u = 1, v = 1 }
	surface.DrawPoly({ v1, v2, v3 })
	surface.DrawPoly({ v1, v3, v4 })
end

-- 1-9: glyph 10px from the right and top of the square (Manrope cell is larger than the ink).
function RelapseUI.DrawInvSlotIndex(w, h, n, col)
	col = col or RelapseUI.Col.Muted
	local text = tostring(n)
	local pad = RelapseUI.sPx(10)
	surface.SetFont("Relapse15")
	local _, fontH = surface.GetTextSize(text)
	local _, rsb = RelapseUI.ManropeDigitEdges(text, fontH, false)
	-- Relapse15 cell sits ~5px above caps.
	draw.SimpleText(text, "Relapse15", w - pad + rsb, pad - RelapseUI.sPx(5), col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

function RelapseUI.TryAttachCardIcon(itempan, mdlframe, tab, missing_skill)
	if not IsValid(mdlframe) or not tab or (tab.Category ~= ITEMCAT_GUNS and tab.Category ~= ITEMCAT_MELEE) then
		return false
	end

	local path = RelapseUI.CardIconPath(tab)
	if not path then return false end

	local img = RelapseUI.MakeSilhouetteIcon(mdlframe, path)
	RelapseUI.FitIcon(img, mdlframe:GetWide(), mdlframe:GetTall() + RelapseUI.Grid5(4))
	if missing_skill then
		img:SetAlpha(50)
	end
	if itempan then
		itempan.m_Icon = img
	end
	return true
end

function RelapseUI.PlaceCardIcon(frame, cardw, cardh)
	if not IsValid(frame) then return end
	local m = RelapseUI.M()
	local pad = m.cardPad
	cardh = cardh or m.cardH
	local top = pad + RelapseUI.Grid5(4)
	local fw = math.min(cardw - 2 * pad, RelapseUI.Grid15(10))
	local fh = math.max(m.step, cardh - top - pad)
	frame:SetSize(fw, fh)
	local x = math.floor(cardw * (2 / 3) - fw * 0.5 + 0.5)
	x = math.Clamp(x, pad, math.max(pad, cardw - pad - fw))
	frame:SetPos(x, top)
end

function RelapseUI.T(id, fallback)
	local ru = translate.GetTranslations("ru")
	if ru and ru[id] then
		return ru[id]
	end
	local s = translate.Get(id)
	if type(s) == "string" and string.sub(s, 1, 1) == "@" then
		return fallback or id
	end
	return s
end

function RelapseUI.TF(id, ...)
	return string.format(RelapseUI.T(id), ...)
end

function RelapseUI.WepName(tbl)
	if not tbl then return "" end
	if tbl.AmmoPack then
		local ammoName = RelapseUI.ShopAmmo(tbl.AmmoPack)
		if tbl.AmmoCount then
			return RelapseUI.TF("shop_ammo_pack_fmt", tbl.AmmoCount, ammoName)
		end
		return ammoName
	end
	local key = tbl.TranslationName
	if key then
		return RelapseUI.T(key, tbl.PrintName or tbl.Name or key)
	end
	return tbl.PrintName or tbl.Name or ""
end

function RelapseUI.WepDesc(tbl)
	if not tbl then return "" end
	local key = tbl.TranslationDescription
	if key then
		return RelapseUI.T(key, tbl.Description or "")
	end
	return tbl.Description or ""
end

function RelapseUI.ShopCat(id)
	local keys = {
		[ITEMCAT_GUNS] = "shop_cat_guns",
		[ITEMCAT_AMMO] = "shop_cat_ammo",
		[ITEMCAT_MELEE] = "shop_cat_melee",
		[ITEMCAT_TOOLS] = "shop_cat_tools",
		[ITEMCAT_DEPLOYABLES] = "shop_cat_deployables",
		[ITEMCAT_TRINKETS] = "shop_cat_trinkets",
		[ITEMCAT_OTHER] = "shop_cat_other"
	}
	return RelapseUI.T(keys[id] or "shop_cat_other")
end

function RelapseUI.ShopSubCat(id)
	local keys = {
		[ITEMSUBCAT_TRINKETS_DEFENSIVE] = "shop_subcat_defensive",
		[ITEMSUBCAT_TRINKETS_OFFENSIVE] = "shop_subcat_offensive",
		[ITEMSUBCAT_TRINKETS_MELEE] = "shop_subcat_melee",
		[ITEMSUBCAT_TRINKETS_PERFORMANCE] = "shop_subcat_performance",
		[ITEMSUBCAT_TRINKETS_SUPPORT] = "shop_subcat_support",
		[ITEMSUBCAT_TRINKETS_SPECIAL] = "shop_subcat_special"
	}
	local key = keys[id]
	if not key then return "" end
	return RelapseUI.T(key)
end

function RelapseUI.ShopAmmo(name)
	name = string.lower(name or "")
	local fallback = GAMEMODE and GAMEMODE.AmmoNames and GAMEMODE.AmmoNames[name]
	return RelapseUI.T("shop_ammo_" .. name, fallback or name)
end

function RelapseUI.ShopStat(id, fallback)
	return RelapseUI.T("shop_stat_" .. tostring(id or ""), fallback or id)
end

local colInvisible = Color(0, 0, 0, 0)

function RelapseUI.HookStatCaption(lab, ink)
	if not IsValid(lab) then return end
	lab.RelapseInk = ink
	lab:SetWrap(false)
	lab:SetAutoStretchVertical(false)
	lab:SetTextColor(colInvisible)
	lab.ApplySchemeSettings = function() end
	lab.Paint = function(me, w, h)
		local text = me:GetText() or ""
		if text == "" or w < 1 then return true end
		local a = me:GetContentAlignment() or 5
		local x, ax = 0, TEXT_ALIGN_LEFT
		if a == 6 then
			x, ax = w, TEXT_ALIGN_RIGHT
		elseif a == 5 then
			x, ax = w * 0.5, TEXT_ALIGN_CENTER
		end
		draw.SimpleText(text, me:GetFont() or "Relapse15", x, h * 0.5, me.RelapseInk, ax, TEXT_ALIGN_CENTER)
		return true
	end
end

function RelapseUI.PlaceStatText(lab, x0, x1, mid, clipAlign)
	if not IsValid(lab) then return end
	lab:SetTextColor(colInvisible)
	local slot = math.max(0, x1 - x0)
	local text = lab:GetText() or ""
	if text == "" or slot < 1 then
		lab:SetX(x0)
		lab:SetWide(slot)
		return
	end
	surface.SetFont(lab:GetFont() or "Relapse15")
	local tw = select(1, surface.GetTextSize(text))
	if tw <= slot then
		local x = math.floor((mid or ((x0 + x1) * 0.5)) - tw * 0.5 + 0.5)
		if x < x0 then x = x0 end
		if x + tw > x1 then x = x1 - tw end
		lab:SetX(x)
		lab:SetWide(tw)
		lab:SetContentAlignment(5)
	else
		lab:SetX(x0)
		lab:SetWide(slot)
		lab:SetContentAlignment(clipAlign or 4)
	end
end

function RelapseUI.LayoutViewerStats(viewer)
	if not IsValid(viewer) then return end
	if viewer.RelapsePlayerView then return end
	local bars = viewer.ItemStatBars
	local bar = bars and bars[1]
	if not IsValid(bar) then return end

	local barH = RelapseUI.Grid5(2)
	local barGap = RelapseUI.Grid15(2)
	local gap = RelapseUI.sPx(15)
	local descH = RelapseUI.ViewerDescH()
	local visualTop = viewer.RelapseDescVisualTop
	if not visualTop then
		local box = viewer.m_VBG
		if IsValid(box) then
			visualTop = box:GetY() + box:GetTall() + RelapseUI.Grid15()
		else
			visualTop = RelapseUI.Grid15()
		end
	end
	local firstY = visualTop + descH + RelapseUI.Grid15(2) + RelapseUI.Grid5()
	surface.SetFont("Relapse15")
	local _, labH = surface.GetTextSize("Ay")
	labH = math.max(1, labH)

	local blockW = viewer:GetWide()
	local barX = RelapseUI.ViewerStatLeft()
	local barR = blockW - RelapseUI.ViewerStatRight()
	local barW = math.max(1, barR - barX)

	local function place(i, y)
		local sb = bars[i]
		if not IsValid(sb) then return end
		sb:SetPos(barX, y)
		sb:SetSize(barW, barH)
		local ly = y + math.floor((barH - labH) * 0.5 + 0.5)
		local name = viewer.ItemStats and viewer.ItemStats[i]
		local val = viewer.ItemStatValues and viewer.ItemStatValues[i]
		if IsValid(name) then
			name:SetFont("Relapse15")
			name:SetTall(labH)
			name:SetY(ly)
		end
		if IsValid(val) then
			val:SetFont("Relapse15")
			val:SetTall(labH)
			val:SetY(ly)
		end
	end

	local y = firstY
	for i, sb in ipairs(bars) do
		if not IsValid(sb) or not sb:IsVisible() then continue end
		place(i, y)
		y = y + barH + barGap
	end

	local left0, left1 = 0, barX - gap
	local right0, right1 = barR + gap, blockW
	for _, lab in ipairs(viewer.ItemStats or {}) do
		local t = IsValid(lab) and lab:GetText() or ""
		surface.SetFont("Relapse15")
		local tw = t ~= "" and select(1, surface.GetTextSize(t)) or 0
		RelapseUI.PlaceStatText(lab, left0, left1, left1 - tw * 0.5, 6)
	end
	for _, lab in ipairs(viewer.ItemStatValues or {}) do
		local t = IsValid(lab) and lab:GetText() or ""
		surface.SetFont("Relapse15")
		local tw = t ~= "" and select(1, surface.GetTextSize(t)) or 0
		RelapseUI.PlaceStatText(lab, right0, right1, right0 + tw * 0.5, 4)
	end
end

function RelapseUI.LayoutViewerAmmo(viewer)
	if not IsValid(viewer) then return end
	if viewer.RelapsePlayerView then
		if IsValid(viewer.m_AmmoType) then
			viewer.m_AmmoType:SetVisible(false)
		end
		if IsValid(viewer.m_AmmoIcon) then
			viewer.m_AmmoIcon:SetVisible(false)
		end
		RelapseUI.LayoutViewerPlayerModel(viewer)
		return
	end
	local title = viewer.m_Title
	local icon = viewer.m_AmmoIcon
	local lab = viewer.m_AmmoType
	if not IsValid(title) or not IsValid(icon) or not IsValid(lab) then return end

	local left = viewer.RelapseDescLeft or RelapseUI.sPx(10)
	local iconS = RelapseUI.Grid15(2)
	local y = title:GetY() + title:GetTall() + RelapseUI.sPx(15)
	icon:SetSize(iconS, iconS)
	icon:SetPos(left, y)

	lab:SetFont("Relapse15")
	lab:SetContentAlignment(4)
	lab:SizeToContents()
	local ly = y + math.floor((iconS - lab:GetTall()) * 0.5 + 0.5)
	lab:SetPos(left + iconS + RelapseUI.Grid15(), ly)
	local hasText = (lab:GetText() or "") ~= ""
	lab:SetVisible(hasText)
	if hasText then
		lab:MoveToFront()
		if icon:IsVisible() then
			icon:MoveToFront()
		end
	end
	RelapseUI.LayoutViewerModel(viewer)
end

function RelapseUI.SetViewerAmmoIcon(viewer, ammoId)
	if not IsValid(viewer) or not IsValid(viewer.m_AmmoIcon) then return end
	local path = RelapseUI.AmmoIconPath(ammoId)
	if path then
		viewer.m_AmmoIcon:SetImage(path)
		viewer.m_AmmoIcon:SetImageColor(RelapseUI.Col.Text)
		viewer.m_AmmoIcon:SetVisible(true)
	else
		viewer.m_AmmoIcon:SetVisible(false)
	end
end

function RelapseUI.ShopPreviewParts(sweptable)
	if not sweptable then return nil end

	local raw = sweptable.RelapsePreviewParts
	if not istable(raw) then
		local gm = GAMEMODE or GM
		local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
		local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
		raw = def and def.PreviewParts
	end
	if not istable(raw) or #raw == 0 then return nil end

	local out = {}
	for _, path in ipairs(raw) do
		if isstring(path) and path ~= "" then
			out[#out + 1] = path
		end
	end
	if #out == 0 then return nil end
	return out
end

function RelapseUI.ShopPreviewModel(sweptable)
	if not sweptable then return nil end

	local parts = RelapseUI.ShopPreviewParts(sweptable)
	if parts then
		return parts[1]
	end

	local explicit = sweptable.RelapsePreviewModel
	if isstring(explicit) and explicit ~= "" then
		return explicit
	end

	-- Never the first-person viewmodel: arms + empty MW stub, not a gun.
	local w = sweptable.WorldModel
	if isstring(w) and w ~= "" then
		return w
	end
	return nil
end

function RelapseUI.ShopPreviewAngle(sweptable)
	if not sweptable then return Angle(8, 90, 0) end
	if sweptable.RelapsePreviewAngle then
		return sweptable.RelapsePreviewAngle
	end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	return (def and def.PreviewAngle) or Angle(8, 90, 0)
end

function RelapseUI.ShopPreviewLocalAng(sweptable)
	if not sweptable then return angle_zero end
	if sweptable.RelapsePreviewLocalAng then
		return sweptable.RelapsePreviewLocalAng
	end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	return (def and def.PreviewLocalAng) or angle_zero
end

function RelapseUI.ShopPreviewOffset(sweptable)
	if not sweptable then return nil end
	if isvector(sweptable.RelapsePreviewOffset) then
		return sweptable.RelapsePreviewOffset
	end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	local off = def and def.PreviewOffset
	return isvector(off) and off or nil
end

function RelapseUI.ShopPreviewLift(sweptable)
	local etalon = RelapseUI.PreviewEtalon.Lift
	if not sweptable then return etalon end
	local lift = sweptable.RelapsePreviewLift
	if isnumber(lift) then
		return lift
	end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	lift = def and def.PreviewLift
	return isnumber(lift) and lift or etalon
end

function RelapseUI.ShopPreviewCamScale(sweptable)
	local etalon = RelapseUI.PreviewEtalon.CamScale
	if not sweptable then return etalon end
	local scale = sweptable.RelapsePreviewCamScale
	if isnumber(scale) and scale > 0 then
		return scale
	end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	scale = def and def.PreviewCamScale
	if isnumber(scale) and scale > 0 then
		return scale
	end
	return etalon
end

function RelapseUI.ShopPreviewBoneMerge(sweptable)
	if not sweptable then return false end
	if sweptable.RelapsePreviewBoneMerge then return true end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	return def and def.PreviewBoneMerge or false
end

function RelapseUI.ShopPreviewHullBounds(sweptable)
	if not sweptable then return false end
	if sweptable.RelapsePreviewHullBounds then return true end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	return def and def.PreviewHullBounds or false
end

function RelapseUI.ShopPreviewBodygroups(sweptable)
	if not sweptable then return nil end
	if istable(sweptable.RelapsePreviewBodygroups) then
		return sweptable.RelapsePreviewBodygroups
	end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	return def and def.PreviewBodygroups or nil
end

function RelapseUI.ShopPreviewClipZ(sweptable)
	if not sweptable then return nil end
	if isnumber(sweptable.RelapsePreviewClipZ) then
		return sweptable.RelapsePreviewClipZ
	end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	local clipZ = def and def.PreviewClipZ
	return isnumber(clipZ) and clipZ or nil
end

-- Keep local +Z (blade). WM machete bakes the lanyard past the pommel on j_gun.
local function withPreviewClipZ(pnl, ent, fn)
	local clipZ = pnl and pnl.RelapsePreviewClipZ
	if not isnumber(clipZ) or not IsValid(ent) then
		fn()
		return
	end

	local pos, ang = ent:GetPos(), ent:GetAngles()
	local worldPos = LocalToWorld(Vector(0, 0, clipZ), angle_zero, pos, ang)
	local normal = ang:Up()
	local wasClipping = render.EnableClipping(true)
	render.PushCustomClipPlane(normal, normal:Dot(worldPos))
	local ok, err = pcall(fn)
	render.PopCustomClipPlane()
	render.EnableClipping(wasClipping)
	if not ok then
		error(err)
	end
end

function RelapseUI.ApplyShopPreviewBodygroups(ent, groups)
	if not IsValid(ent) or not istable(groups) then return end

	for k, v in pairs(groups) do
		if isnumber(v) then
			local id
			if isnumber(k) then
				id = k
			elseif isstring(k) and ent.FindBodygroupByName then
				id = ent:FindBodygroupByName(k)
			end
			if isnumber(id) and id >= 0 then
				ent:SetBodygroup(id, v)
			end
		end
	end
end

function RelapseUI.ClearShopPreviewParts(pnl)
	if not pnl then return end
	local parts = pnl.RelapsePreviewEnts
	if parts then
		for _, part in ipairs(parts) do
			if IsValid(part) then
				part:SetParent(NULL)
				part:Remove()
			end
		end
	end
	pnl.RelapsePreviewEnts = nil
	pnl.RelapsePreviewPaths = nil
end

local function prepPreviewEnt(cs)
	if not IsValid(cs) then return end
	cs:SetNoDraw(true)
	if cs.SetIK then
		cs:SetIK(false)
	end
	if cs.SetPlaybackRate then
		cs:SetPlaybackRate(0)
	end
	if cs.SetCycle then
		cs:SetCycle(0)
	end
end

function RelapseUI.AttachShopPreviewParts(pnl, sweptable)
	RelapseUI.ClearShopPreviewParts(pnl)
	if not IsValid(pnl) then return end

	local paths = RelapseUI.ShopPreviewParts(sweptable)
	pnl.RelapsePreviewPaths = paths
	pnl.RelapsePreviewBoneMerge = RelapseUI.ShopPreviewBoneMerge(sweptable)
	if not paths or not ClientsideModel then return end

	local boneMerge = pnl.RelapsePreviewBoneMerge and IsValid(pnl.Entity)
	local extras = {}
	local start = boneMerge and 2 or 1
	for i = start, #paths do
		local cs = ClientsideModel(paths[i], RENDER_GROUP_OPAQUE_ENTITY)
		if IsValid(cs) then
			prepPreviewEnt(cs)
			if boneMerge then
				cs:SetParent(pnl.Entity)
				cs:AddEffects(EF_BONEMERGE)
				cs:AddEffects(EF_BONEMERGE_FASTCULL)
				cs:SetLocalPos(vector_origin)
				cs:SetLocalAngles(angle_zero)
			end
			extras[#extras + 1] = cs
		end
	end
	pnl.RelapsePreviewEnts = extras
end

function RelapseUI.DrawShopPreviewGun(pnl, ent)
	if not IsValid(pnl) or not IsValid(ent) then return end

	local extras = pnl.RelapsePreviewEnts

	if pnl.RelapsePreviewBoneMerge then
		RelapseUI.PrepShopPreview(ent)
		if ent.InvalidateBoneCache then
			ent:InvalidateBoneCache()
		end
		if ent.SetupBones then
			ent:SetupBones()
		end
		withPreviewClipZ(pnl, ent, function()
			ent:DrawModel()
			if istable(extras) then
				for i = 1, #extras do
					local part = extras[i]
					if IsValid(part) then
						if part.SetupBones then
							part:SetupBones()
						end
						part:DrawModel()
					end
				end
			end
		end)
		return
	end

	local pos = ent:GetPos()
	local ang = ent:GetAngles()
	withPreviewClipZ(pnl, ent, function()
		local drew = false
		if istable(extras) then
			for i = 1, #extras do
				local part = extras[i]
				if IsValid(part) then
					part:SetPos(pos)
					part:SetAngles(ang)
					part:DrawModel()
					drew = true
				end
			end
		end
		if not drew then
			ent:DrawModel()
		end
	end)
end

function RelapseUI.DrawShopPreviewParts(pnl, ent)
end

function RelapseUI.PrepShopPreview(ent)
	if not IsValid(ent) then return end

	if ent.SetIK then
		ent:SetIK(false)
	end
	if ent.SetPlaybackRate then
		ent:SetPlaybackRate(0)
	end
	if ent.SetCycle then
		ent:SetCycle(0)
	end
	if istable(ent.RelapsePreviewBodygroups) then
		RelapseUI.ApplyShopPreviewBodygroups(ent, ent.RelapsePreviewBodygroups)
	end
end

local function growBounds(mins, maxs, pmin, pmax)
	return Vector(
		math.min(mins.x, pmin.x),
		math.min(mins.y, pmin.y),
		math.min(mins.z, pmin.z)
	), Vector(
		math.max(maxs.x, pmax.x),
		math.max(maxs.y, pmax.y),
		math.max(maxs.z, pmax.z)
	)
end

local function meshAABB(model, pos, ang, bodyMask)
	if not isstring(model) or model == "" or not util.GetModelMeshes then
		return nil
	end

	local meshes
	if isnumber(bodyMask) and bodyMask > 0 then
		local ok, got = pcall(util.GetModelMeshes, model, 0, bodyMask)
		if ok then
			meshes = got
		end
	end
	if not istable(meshes) then
		meshes = util.GetModelMeshes(model, 0)
	end
	if not istable(meshes) then return nil end

	local minx, miny, minz = math.huge, math.huge, math.huge
	local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge
	local any = false
	local xform = pos ~= nil

	for _, mesh in ipairs(meshes) do
		local verts = mesh.verticies or mesh.vertices
		if verts then
			for i = 1, #verts do
				local p = verts[i].pos
				if p then
					if xform then
						p = LocalToWorld(p, angle_zero, pos, ang)
					end
					any = true
					local x, y, z = p.x, p.y, p.z
					if x < minx then minx = x end
					if y < miny then miny = y end
					if z < minz then minz = z end
					if x > maxx then maxx = x end
					if y > maxy then maxy = y end
					if z > maxz then maxz = z end
				end
			end
		end
	end

	if not any then return nil end
	return Vector(minx, miny, minz), Vector(maxx, maxy, maxz)
end

local function previewMeshBounds(paths)
	local mins, maxs

	local function addModel(mdl)
		local a, b = meshAABB(mdl)
		if not a then return end
		if not mins then
			mins, maxs = a, b
		else
			mins, maxs = growBounds(mins, maxs, a, b)
		end
	end

	if istable(paths) then
		for i = 1, #paths do
			addModel(paths[i])
		end
	end

	return mins, maxs
end

local function bonePosAng(ent, name)
	if not IsValid(ent) then
		return vector_origin, angle_zero
	end
	if isstring(name) and name ~= "" then
		local id = ent:LookupBone(name)
		if id then
			local mat = ent:GetBoneMatrix(id)
			if mat then
				return mat:GetTranslation(), mat:GetAngles()
			end
			local pos, ang = ent:GetBonePosition(id)
			if pos then
				return pos, ang
			end
		end
	end
	return ent:GetPos(), ent:GetAngles()
end

local function assembledPreviewBounds(pnl, ent)
	if not IsValid(ent) then return nil end

	local oldPos, oldAng = ent:GetPos(), ent:GetAngles()
	ent:SetPos(vector_origin)
	ent:SetAngles(angle_zero)
	RelapseUI.PrepShopPreview(ent)
	if ent.InvalidateBoneCache then
		ent:InvalidateBoneCache()
	end
	if ent.SetupBones then
		ent:SetupBones()
	end

	-- Dummy WM: bind-pose GetModelMeshes is the drawn mesh on 1911/.357. Biped WMs
	-- (SKS) store verts along +X and DrawModel along +Z (studio hull). Mixing that
	-- +X box with posed attachment bones makes an L-span and the camera looks down on the rail.
	local mins, maxs
	if pnl.RelapsePreviewHullBounds then
		mins, maxs = ent:GetRenderBounds()
	else
		local mask = 0
		if IsValid(ent) and ent.GetBodygroupMask then
			mask = ent:GetBodygroupMask() or 0
		elseif istable(ent.RelapsePreviewBodygroups) and isnumber(ent.RelapsePreviewBodygroups[0]) then
			mask = ent.RelapsePreviewBodygroups[0]
		end
		mins, maxs = meshAABB(ent:GetModel(), nil, nil, mask)
	end

	local extras = pnl.RelapsePreviewEnts
	-- Hull already covers the in-hand rifle. Attachment GetRenderBounds (stock)
	-- is the whole file hull and sends the camera to the clamp.
	if istable(extras) and not pnl.RelapsePreviewHullBounds then
		for i = 1, #extras do
			local part = extras[i]
			if IsValid(part) then
				if part.SetupBones then
					part:SetupBones()
				end
				local attachBone = part:GetBoneName(0)
				local a, b = meshAABB(part:GetModel(), bonePosAng(ent, attachBone))
				if a then
					if not mins then
						mins, maxs = a, b
					else
						mins, maxs = growBounds(mins, maxs, a, b)
					end
				end
			end
		end
	end

	ent:SetPos(oldPos)
	ent:SetAngles(oldAng)
	return mins, maxs
end

function RelapseUI.OrbitShopPreview(pnl, ent)
	if not IsValid(pnl) or not IsValid(ent) then return end
	if not pnl.RelapseShopPreview then return end

	RelapseUI.PrepShopPreview(ent)

	if not pnl.RelapsePreviewFramed then
		local mins, maxs
		if pnl.RelapsePreviewBoneMerge then
			mins, maxs = assembledPreviewBounds(pnl, ent)
		end
		if not mins then
			mins, maxs = previewMeshBounds(pnl.RelapsePreviewPaths)
		end
		if not mins then
			mins, maxs = meshAABB(ent:GetModel())
		end
		if not mins then
			mins, maxs = ent:GetRenderBounds()
		end

		local size = maxs - mins
		local span = size:Length()
		local center = mins + size * 0.5
		if span < 1 then
			span = 22
		end

		local scale = pnl.RelapsePreviewCamScale
		local etalon = RelapseUI.PreviewEtalon
		if not isnumber(scale) or scale <= 0 then
			scale = etalon.CamScale
		end
		local dist = math.Clamp(span * etalon.SpanMul * scale, 8, 96)
		local off = pnl.RelapsePreviewOffset
		if isvector(off) then
			center = center + off
		end
		pnl.RelapsePreviewCenter = Vector(center)
		-- Offset is model-space and orbits with the gun. Lift is view-space:
		-- look below the origin so the rifle sits higher in the panel.
		local lift = pnl.RelapsePreviewLift
		if not isnumber(lift) then
			lift = etalon.Lift
		end
		local look = Vector(0, 0, -lift)
		local dir = etalon.CamDir
		pnl:SetLookAt(look)
		pnl:SetCamPos(Vector(dist * dir.x, dist * dir.y, dist * dir.z) + look)
		pnl.RelapsePreviewFramed = true
	end

	local base = pnl.RelapsePreviewBaseAng or angle_zero
	local orbit = Angle(base.p, base.y + RealTime() * 28, base.r)
	local localAng = pnl.RelapsePreviewLocalAng or angle_zero
	local m = Matrix()
	m:SetAngles(orbit)
	local laid = Matrix()
	laid:SetAngles(localAng)
	m = m * laid
	local ang = m:GetAngles()
	local pivot = Matrix()
	pivot:SetTranslation(pnl.RelapsePreviewCenter)
	local worldOff = (m * pivot):GetTranslation()
	ent:SetAngles(ang)
	ent:SetPos(-worldOff)
end

function RelapseUI.FrameModelPanel(pnl)
	if not IsValid(pnl) then return end

	local ent = pnl.Entity
	if not IsValid(ent) then return end

	pnl:SetAmbientLight(Color(72, 72, 70))
	pnl:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
	pnl:SetDirectionalLight(BOX_FRONT, Color(230, 228, 220))
	pnl:SetDirectionalLight(BOX_RIGHT, Color(190, 188, 180))
	pnl:SetDirectionalLight(BOX_LEFT, Color(40, 42, 48))
	pnl:SetDirectionalLight(BOX_BOTTOM, Color(24, 24, 24))
	if pnl.SetColor then
		pnl:SetColor(color_white)
	end

	if pnl.RelapseShopPreview then
		pnl:SetFOV(RelapseUI.PreviewEtalon.FOV)
		RelapseUI.OrbitShopPreview(pnl, ent)
		return
	end

	local mins, maxs = ent:GetRenderBounds()
	pnl:SetCamPos(mins:Distance(maxs) * Vector(0.75, 0.75, 0.5))
	pnl:SetLookAt((mins + maxs) / 2)
end

function RelapseUI.PlayerPreviewBounds(ent)
	if not IsValid(ent) then
		return Vector(-16, -16, 0), Vector(16, 16, 72)
	end
	local omins, omaxs = ent:OBBMins(), ent:OBBMaxs()
	local rmins, rmaxs = ent:GetRenderBounds()
	local oh = omaxs.z - omins.z
	local rh = rmaxs.z - rmins.z
	if rh > 16 and rh < math.max(72, oh) * 2.2 then
		return rmins, rmaxs
	end
	if oh > 8 then
		return omins, omaxs
	end
	return rmins, rmaxs
end

function RelapseUI.FramePlayerPreview(pnl)
	if not IsValid(pnl) then return end
	RelapseUI.FrameModelPanel(pnl)
	local ent = pnl.Entity
	if not IsValid(ent) then return end

	local w = math.max(1, pnl:GetWide())
	local h = math.max(1, pnl:GetTall())
	if w < 8 or h < 8 then return end

	local fov = 28
	pnl:SetFOV(fov)

	local mins, maxs = RelapseUI.PlayerPreviewBounds(ent)
	local height = math.max(16, maxs.z - mins.z)
	local width = math.max(12, math.max(maxs.x - mins.x, maxs.y - mins.y))
	local center = Vector(0, 0, mins.z + height * 0.5)

	local hfov = math.rad(fov)
	local aspect = w / h
	local vfov = 2 * math.atan(math.tan(hfov * 0.5) / math.max(0.2, aspect))
	local pad = 1.22
	local dist = math.max(
		(height * 0.5 * pad) / math.max(0.01, math.tan(vfov * 0.5)),
		(width * 0.5 * pad) / math.max(0.01, math.tan(hfov * 0.5))
	)

	local yaw = math.rad(28)
	pnl:SetLookAt(center)
	pnl:SetCamPos(center + Vector(math.cos(yaw) * dist, math.sin(yaw) * dist, height * 0.02))
end

function RelapseUI.ResetPlayerPreviewOrbit(pnl)
	if not IsValid(pnl) then return end
	pnl.RelapseOrbitYaw = 20
	pnl.RelapseOrbitVel = 0
	pnl.RelapseOrbitVelFrom = 0
	pnl.RelapseOrbitAuto = true
	pnl.RelapseOrbitSpeedMul = 0
	pnl.RelapseOrbitIdleAt = nil
	pnl.RelapseOrbitDragging = false
	if pnl.MouseCapture then
		pnl:MouseCapture(false)
	end
end

function RelapseUI.PlayerPreviewDragPress(pnl, mc)
	if not IsValid(pnl) then return false end
	if not pnl.RelapsePlayerPreview or pnl.RelapsePlayerPreviewStatic then
		return false
	end
	if mc ~= MOUSE_LEFT then return false end
	pnl:MouseCapture(true)
	pnl.RelapseOrbitDragging = true
	pnl.RelapseOrbitAuto = false
	pnl.RelapseOrbitSpeedMul = 0
	pnl.RelapseOrbitIdleAt = nil
	pnl.RelapseOrbitVel = 0
	pnl.RelapseOrbitLastMX = select(1, input.GetCursorPos())
	return true
end

function RelapseUI.PlayerPreviewDragRelease(pnl)
	if not IsValid(pnl) or not pnl.RelapseOrbitDragging then
		return false
	end
	pnl:MouseCapture(false)
	pnl.RelapseOrbitDragging = false
	pnl.RelapseOrbitIdleAt = RealTime() + 5
	return true
end

function RelapseUI.OrbitPlayerPreview(pnl, ent)
	if not IsValid(pnl) or not IsValid(ent) then return end
	local w, h = pnl:GetWide(), pnl:GetTall()
	if pnl._RelapsePFW ~= w or pnl._RelapsePFH ~= h then
		pnl._RelapsePFW, pnl._RelapsePFH = w, h
		RelapseUI.FramePlayerPreview(pnl)
	end

	if pnl.RelapsePlayerPreviewStatic then
		ent:SetAngles(Angle(0, 25, 0))
		ent:SetPos(vector_origin)
		return
	end

	local yaw = pnl.RelapseOrbitYaw
	if yaw == nil then
		yaw = 20
		pnl.RelapseOrbitYaw = yaw
		pnl.RelapseOrbitVel = 0
		pnl.RelapseOrbitAuto = true
		pnl.RelapseOrbitSpeedMul = 0
	end

	local vel = pnl.RelapseOrbitVel or 0
	local dt = FrameTime()
	if dt < 0.001 then
		dt = 0.001
	elseif dt > 0.1 then
		dt = 0.1
	end

	if pnl.RelapseOrbitDragging then
		local mx = select(1, input.GetCursorPos())
		local last = pnl.RelapseOrbitLastMX or mx
		local dyaw = (mx - last) * 0.45
		yaw = yaw + dyaw
		pnl.RelapseOrbitLastMX = mx
		local instant = math.Clamp(dyaw / dt, -720, 720)
		local follow = 1 - math.exp(-18 * dt)
		vel = vel + (instant - vel) * follow
	else
		if pnl.RelapseOrbitIdleAt and RealTime() >= pnl.RelapseOrbitIdleAt then
			pnl.RelapseOrbitIdleAt = nil
			pnl.RelapseOrbitAuto = true
			pnl.RelapseOrbitSpeedMul = 0
			pnl.RelapseOrbitVelFrom = vel
		end

		if pnl.RelapseOrbitAuto then
			local mul = math.min(1, (pnl.RelapseOrbitSpeedMul or 0) + dt / 1.1)
			pnl.RelapseOrbitSpeedMul = mul
			local ease = mul * mul * (3 - 2 * mul)
			local from = pnl.RelapseOrbitVelFrom or 0
			vel = from + (16 - from) * ease
		else
			vel = vel * math.exp(-2.15 * dt)
			if math.abs(vel) < 0.35 then
				vel = 0
			end
		end

		yaw = yaw + vel * dt
	end

	pnl.RelapseOrbitVel = vel
	pnl.RelapseOrbitYaw = yaw
	ent:SetAngles(Angle(0, yaw, 0))
	ent:SetPos(vector_origin)
end

function RelapseUI.SetPlayerPreview(pnl, mdl, viewer)
	if IsValid(viewer) and IsValid(viewer.m_ModelIcon) then
		viewer.m_ModelIcon:SetVisible(false)
		viewer.m_ModelIcon:SetMouseInputEnabled(false)
	end
	if not IsValid(pnl) then return end

	pnl:SetVisible(true)
	pnl.RelapseShopPreview = false
	pnl.RelapsePlayerPreview = true
	pnl.RelapsePlayerPreviewStatic = false
	pnl:SetMouseInputEnabled(true)
	pnl:SetCursor("hand")
	if RelapseUI.ClearShopPreviewParts then
		RelapseUI.ClearShopPreviewParts(pnl)
	end
	pnl:SetModel(mdl or "")
	pnl:SetAnimated(true)
	pnl._RelapsePFW = nil
	pnl._RelapsePFH = nil
	RelapseUI.ResetPlayerPreviewOrbit(pnl)
	RelapseUI.FramePlayerPreview(pnl)
end

function RelapseUI.LayoutViewerPlayerModel(viewer)
	if not IsValid(viewer) then return end
	local box = viewer.m_VBG
	if not IsValid(box) then return end
	local title = viewer.m_Title
	local desc = viewer.m_Desc
	local inset = RelapseUI.Grid15()
	local left = viewer.RelapseDescLeft or RelapseUI.sPx(10)
	local right = RelapseUI.sPx(15)
	local y = RelapseUI.sPx(15)
	if IsValid(title) then
		y = title:GetY() + title:GetTall() + RelapseUI.sPx(10)
	end

	if IsValid(desc) then
		local dw = math.max(1, viewer:GetWide() - left - right)
		local text = desc:GetText() or ""
		surface.SetFont("Relapse15")
		local _, lineH = surface.GetTextSize("Ay")
		lineH = math.max(1, lineH)
		local n = 0
		if text ~= "" then
			n = math.Clamp(#RelapseUI.WrapLines(text, "Relapse15", dw), 1, 3)
		end
		local dh = n * lineH
		desc:SetSize(dw, math.max(1, dh))
		desc:SetPos(left, y)
		viewer.RelapseDescVisualTop = y
		if n > 0 then
			y = y + dh + RelapseUI.sPx(15)
		end
	end

	local boxH = math.max(RelapseUI.Grid15(8), viewer:GetTall() - y - RelapseUI.Grid15())
	box:SetSize(math.max(1, viewer:GetWide() - 2 * inset), boxH)
	box:SetPos(inset, y)
	if IsValid(viewer.ModelPanel) then
		viewer.ModelPanel._RelapsePFW = nil
		viewer.ModelPanel._RelapsePFH = nil
	end
end

function RelapseUI.SetShopPreview(pnl, sweptable, viewer)
	if IsValid(viewer) and IsValid(viewer.m_ModelIcon) then
		viewer.m_ModelIcon:SetVisible(false)
	end
	if not IsValid(pnl) then return end

	pnl:SetVisible(true)
	pnl.RelapseShopPreview = true
	pnl.RelapsePlayerPreview = false
	pnl.RelapsePreviewFramed = false
	pnl.RelapsePreviewCenter = nil
	RelapseUI.ClearShopPreviewParts(pnl)

	local mdl = RelapseUI.ShopPreviewModel(sweptable)
	if not mdl then
		pnl:SetModel("")
		return
	end

	pnl.RelapsePreviewBaseAng = RelapseUI.ShopPreviewAngle(sweptable)
	pnl.RelapsePreviewLocalAng = RelapseUI.ShopPreviewLocalAng(sweptable)
	pnl.RelapsePreviewOffset = RelapseUI.ShopPreviewOffset(sweptable)
	pnl.RelapsePreviewLift = RelapseUI.ShopPreviewLift(sweptable)
	pnl.RelapsePreviewCamScale = RelapseUI.ShopPreviewCamScale(sweptable)
	pnl.RelapsePreviewHullBounds = RelapseUI.ShopPreviewHullBounds(sweptable)
	pnl.RelapsePreviewClipZ = RelapseUI.ShopPreviewClipZ(sweptable)
	pnl:SetModel(mdl)
	pnl:SetAnimated(false)
	if IsValid(pnl.Entity) then
		pnl.Entity.RelapsePreviewBodygroups = RelapseUI.ShopPreviewBodygroups(sweptable)
		RelapseUI.ApplyShopPreviewBodygroups(pnl.Entity, pnl.Entity.RelapsePreviewBodygroups)
	end
	RelapseUI.AttachShopPreviewParts(pnl, sweptable)
	RelapseUI.FrameModelPanel(pnl)
end

function RelapseUI.LayoutViewerModel(viewer)
	if not IsValid(viewer) then return end
	if viewer.RelapsePlayerView then
		RelapseUI.LayoutViewerPlayerModel(viewer)
		return
	end
	local box = viewer.m_VBG
	if not IsValid(box) then return end
	local icon = viewer.m_AmmoIcon
	local title = viewer.m_Title
	local boxW = RelapseUI.ViewerModelW()
	local boxH = RelapseUI.ViewerModelH()
	local y = RelapseUI.sPx(15)
	if IsValid(icon) then
		y = icon:GetY()
	elseif IsValid(title) then
		y = title:GetY() + title:GetTall() + RelapseUI.sPx(15)
	end
	box:SetSize(boxW, boxH)
	box:SetPos(viewer:GetWide() - boxW - RelapseUI.Grid15(), y)
	RelapseUI.LayoutViewerDesc(viewer)
end

function RelapseUI.WrapLines(text, font, maxW)
	surface.SetFont(font or "Relapse15")
	maxW = math.max(1, tonumber(maxW) or 1)
	text = string.gsub(tostring(text or ""), "\r\n", "\n")
	text = string.gsub(text, "\r", "\n")
	local out = {}
	for _, paragraph in ipairs(string.Explode("\n", text, false)) do
		if paragraph == "" then
			out[#out + 1] = ""
		else
			local cur = ""
			for word, spaces in string.gmatch(paragraph, "(%S+)(%s*)") do
				local trial = cur .. word
				if cur ~= "" and select(1, surface.GetTextSize(trial)) > maxW then
					out[#out + 1] = string.match(cur, "^(.-)%s*$") or cur
					cur = word .. spaces
				else
					cur = trial .. spaces
				end
			end
			if cur ~= "" then
				out[#out + 1] = string.match(cur, "^(.-)%s*$") or cur
			end
		end
	end
	return out
end

function RelapseUI.HookViewerDesc(lab)
	if not IsValid(lab) then return end
	lab:SetWrap(false)
	lab:SetAutoStretchVertical(false)
	lab:SetMultiline(true)
	lab:SetTextColor(colInvisible)
	lab.ApplySchemeSettings = function() end
	lab.Paint = function(me, w, h)
		local text = me:GetText() or ""
		if text == "" or w < 1 or h < 1 then return true end
		local font = me:GetFont() or "Relapse15"
		surface.SetFont(font)
		local _, lineH = surface.GetTextSize("Ay")
		lineH = math.max(1, lineH)
		local y = 0
		local col = RelapseUI.Col.Muted
		for _, line in ipairs(RelapseUI.WrapLines(text, font, w)) do
			if y + lineH > h then break end
			if line ~= "" then
				draw.SimpleText(line, font, 0, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end
			y = y + lineH
		end
		return true
	end
end

function RelapseUI.LayoutViewerDesc(viewer)
	if not IsValid(viewer) then return end
	if viewer.RelapsePlayerView then return end
	local desc = viewer.m_Desc
	local box = viewer.m_VBG
	if not IsValid(desc) or not IsValid(box) then return end
	local left = viewer.RelapseDescLeft or RelapseUI.sPx(10)
	local right = RelapseUI.sPx(15)
	-- Relapse15 cell sits ~5px above caps; visual gap is to the capital.
	local capNudge = RelapseUI.sPx(5)
	local descH = RelapseUI.ViewerDescH()
	local visualTop = box:GetY() + box:GetTall() + RelapseUI.Grid15()
	viewer.RelapseDescVisualTop = visualTop
	desc:SetSize(math.max(1, viewer:GetWide() - left - right), descH + capNudge)
	desc:SetPos(left, visualTop - capNudge)
	RelapseUI.LayoutViewerStats(viewer)
end

function RelapseUI.CreateFonts()
	local s = RelapseUI.S()
	local rev = 13
	if RelapseUI._FontS == s and RelapseUI._FontRev == rev then return end
	RelapseUI._FontS = s
	RelapseUI._FontRev = rev
	local function mk(name, size, weight)
		surface.CreateFont(name, {
			font = "Manrope",
			size = RelapseUI.sPx(size),
			weight = weight or 400,
			antialias = true,
			extended = true,
			shadow = false,
			outline = false
		})
	end

	mk("Relapse13", 13, 400)
	mk("Relapse15", 15, 400)
	mk("Relapse16", 16, 400)
	mk("Relapse20", 20, 400)
	mk("Relapse17", 17, 400)
	mk("Relapse22", 22, 400)
	mk("Relapse25", 25, 400)
	mk("Relapse27", 27, 400)
	mk("Relapse28", 28, 400)
	mk("Relapse30", 30, 400)
	mk("Relapse32", 32, 400)
	mk("Relapse35", 35, 400)
	mk("Relapse40", 40, 400)
	mk("Relapse45", 45, 400)
	mk("Relapse64", 64, 500)
end

-- CreateFont size maps to the Windows cell (winAscent 2132 + winDescent 600).
-- Lining digits do not fill it; HUD gaps must use ink, not GetTextSize.
RelapseUI.MANROPE_CELL = 2732
RelapseUI.MANROPE_ASCENT = 2132
local MANROPE_DESCENT = 600
-- Per digit 0-9: left bearing, right bearing, ink yMin. Regular 400 / Medium 500.
local MANROPE_REG = {
	{140, 140, -30}, {120, 240, 0}, {100, 100, 1}, {80, 120, -29}, {100, 100, 0},
	{100, 100, -30}, {140, 126, -30}, {80, 100, 0}, {120, 120, -30}, {127, 140, -30}
}
local MANROPE_MED = {
	{140, 140, -30}, {120, 240, 0}, {100, 100, 1}, {80, 120, -28}, {100, 100, 0},
	{100, 100, -30}, {140, 120, -30}, {80, 100, 0}, {120, 120, -30}, {120, 140, -30}
}

function RelapseUI.ManropeBaseline(boxY, fontH)
	return (boxY or 0) + (fontH or 0) * (RelapseUI.MANROPE_ASCENT / RelapseUI.MANROPE_CELL)
end

function RelapseUI.ManropeDigitEdges(text, fontH, medium)
	local t = medium and MANROPE_MED or MANROPE_REG
	local first, last = t[9], t[9]
	local yMin = 0
	local n = 0
	for i = 1, #text do
		local d = string.byte(text, i)
		if d and d >= 48 and d <= 57 then
			local m = t[d - 47]
			n = n + 1
			if n == 1 then first = m end
			last = m
			if m[3] < yMin then yMin = m[3] end
		end
	end
	local k = (fontH or 0) / RelapseUI.MANROPE_CELL
	return first[1] * k, last[2] * k, (MANROPE_DESCENT + yMin) * k
end

-- lsb, rsb. Shop titles + switch glyphs. Fallback is a typical letter.
local MANROPE_PAD = {
	[60] = {280, 386}, -- <
	[62] = {386, 280}, -- >
	[108] = {160, 160}, -- l
	[112] = {139, 80}, -- p
	[1083] = {40, 140}, -- л
}

local function LastCodepoint(s)
	if not isstring(s) or s == "" then return 0 end
	local i = #s
	while i > 1 and bit.band(string.byte(s, i), 0xC0) == 0x80 do
		i = i - 1
	end
	local b1 = string.byte(s, i)
	if not b1 or b1 < 128 then return b1 or 0 end
	local b2 = (string.byte(s, i + 1) or 128) - 128
	if b1 < 224 then
		return (b1 - 192) * 64 + b2
	end
	local b3 = (string.byte(s, i + 2) or 128) - 128
	if b1 < 240 then
		return (b1 - 224) * 4096 + b2 * 64 + b3
	end
	local b4 = (string.byte(s, i + 3) or 128) - 128
	return (b1 - 240) * 262144 + b2 * 4096 + b3 * 64 + b4
end

function RelapseUI.ManropeCharPad(code, fontH)
	local m = MANROPE_PAD[code] or {120, 140}
	local k = (fontH or 0) / RelapseUI.MANROPE_CELL
	return m[1] * k, m[2] * k
end

function RelapseUI.RadPx(key)
	return RelapseUI.sPx(RelapseUI.Rad[key] or 12)
end

function RelapseUI.RoundFill(r, x, y, w, h, col)
	if w < 2 or h < 2 or not col then return end
	x, y = math.floor(x + 0.5), math.floor(y + 0.5)
	w, h = math.floor(w), math.floor(h)
	r = math.max(0, math.min(math.floor(r), math.floor(math.min(w, h) * 0.5)))
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	if r < 1 then
		surface.DrawRect(x, y, w, h)
		return
	end

	draw.NoTexture()
	local segs = math.max(4, math.min(8, r))
	local pts = {}
	local function arc(cx, cy, a0, a1)
		for i = 0, segs do
			local a = math.rad(a0 + (a1 - a0) * (i / segs))
			pts[#pts + 1] = {x = cx + math.cos(a) * r, y = cy + math.sin(a) * r}
		end
	end
	arc(x + w - r, y + r, 270, 360)
	arc(x + w - r, y + h - r, 0, 90)
	arc(x + r, y + h - r, 90, 180)
	arc(x + r, y + r, 180, 270)
	surface.DrawPoly(pts)
end

function RelapseUI.MaskRound(r, w, h, fn)
	if w < 2 or h < 2 or not fn then return end
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.OverrideColorWriteEnable(true, false)
	RelapseUI.RoundFill(r, 0, 0, w, h, RelapseUI.Col.Ink)
	render.OverrideColorWriteEnable(false)
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)
	fn()
	render.SetStencilEnable(false)
	render.ClearStencil()
end

function RelapseUI.FillCircle(cx, cy, rad, col)
	if not col or not rad or rad < 0.75 then return end
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	draw.NoTexture()
	local segs = math.max(16, math.floor(rad * 6 + 0.5))
	local pts = {}
	for i = 0, segs - 1 do
		local a = (i / segs) * math.pi * 2
		pts[#pts + 1] = {x = cx + math.cos(a) * rad, y = cy + math.sin(a) * rad}
	end
	surface.DrawPoly(pts)
end

function RelapseUI.RoundStroke(r, x, y, w, h, col, thick)
	if w < 2 or h < 2 or not col then return end
	x, y = math.floor(x + 0.5), math.floor(y + 0.5)
	w, h = math.floor(w), math.floor(h)
	thick = math.max(1, math.floor((thick or RelapseUI.sPx(2)) + 0.5))
	r = math.max(0, math.min(math.floor(r), math.floor(math.min(w, h) * 0.5)))

	if r < 1 then
		surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
		surface.DrawRect(x, y, w, thick)
		surface.DrawRect(x, y + h - thick, w, thick)
		surface.DrawRect(x, y + thick, thick, math.max(0, h - 2 * thick))
		surface.DrawRect(x + w - thick, y + thick, thick, math.max(0, h - 2 * thick))
		return
	end

	local span = w - 2 * r
	local midh = h - 2 * r
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	if span > 0 then
		surface.DrawRect(x + r, y, span, thick)
		surface.DrawRect(x + r, y + h - thick, span, thick)
	end
	if midh > 0 then
		surface.DrawRect(x, y + r, thick, midh)
		surface.DrawRect(x + w - thick, y + r, thick, midh)
	end

	local ri = math.max(0, r - thick)
	local segs = math.max(4, math.min(8, r))
	local function corner(cx, cy, a0, a1)
		for i = 0, segs - 1 do
			local a = math.rad(a0 + (a1 - a0) * (i / segs))
			local b = math.rad(a0 + (a1 - a0) * ((i + 1) / segs))
			RelapseUI.FillQuad(
				cx + math.cos(a) * ri, cy + math.sin(a) * ri,
				cx + math.cos(a) * r, cy + math.sin(a) * r,
				cx + math.cos(b) * r, cy + math.sin(b) * r,
				cx + math.cos(b) * ri, cy + math.sin(b) * ri,
				col
			)
		end
	end
	corner(x + w - r, y + r, 270, 360)
	corner(x + w - r, y + h - r, 0, 90)
	corner(x + r, y + h - r, 90, 180)
	corner(x + r, y + r, 180, 270)
end

function RelapseUI.RoundRing(r, x, y, w, h, col, inner, thick)
	thick = math.max(1, math.floor((thick or RelapseUI.sPx(2)) + 0.5))
	if inner then
		RelapseUI.RoundFill(math.max(0, r - thick), x + thick, y + thick, w - 2 * thick, h - 2 * thick, inner)
	end
	RelapseUI.RoundStroke(r, x, y, w, h, col, thick)
end

function RelapseUI.HideChrome(frame)
	frame:ShowCloseButton(false)
	frame:SetPaintBackgroundEnabled(false)
	frame:SetPaintBorderEnabled(false)
	if IsValid(frame.btnClose) then frame.btnClose:SetVisible(false) end
	if IsValid(frame.btnMinim) then frame.btnMinim:SetVisible(false) end
	if IsValid(frame.btnMaxim) then frame.btnMaxim:SetVisible(false) end
end

local function DrawCentered(self, w, h, col)
	local text = self.GetText and self:GetText() or ""
	if text == "" then return end
	draw.SimpleText(text, self:GetFont() or "Relapse15", w * 0.5, h * 0.5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function RelapseUI.PaintWindow(self, w, h)
	local fill = RelapseUI.Col.BgGlass
	if GAMEMODE and GAMEMODE.WindowTransparency == false then
		fill = RelapseUI.Col.Bg
	end
	RelapseUI.RoundFill(RelapseUI.RadPx("Window"), 0, 0, w, h, fill)
	return true
end

function RelapseUI.PaintSheet(self, w, h)
	return true
end

function RelapseUI.PaintInsetPanel(self, w, h)
	return true
end

function RelapseUI.PaintCard(self, w, h, selected, locked, unaffordable)
	local c = RelapseUI.Col
	local fill = c.Card
	if self.Hovered then
		fill = c.CardHover
	end
	local r = RelapseUI.RadPx("Card")
	RelapseUI.RoundFill(r, 0, 0, w, h, fill)
	if selected then
		RelapseUI.RoundStroke(r, 0, 0, w, h, c.CardOn)
	end

	if locked then
		RelapseUI.RoundFill(RelapseUI.RadPx("Card"), 0, 0, w, h, c.Lock)
	end

	return true
end

function RelapseUI.PaintPrimaryButton(self, w, h)
	local c = RelapseUI.Col
	RelapseUI.RoundFill(RelapseUI.RadPx("Button"), 0, 0, w, h, self.Hovered and c.CardHover or c.Card)
	DrawCentered(self, w, h, c.Accent)
	return true
end

function RelapseUI.PaintGhostButton(self, w, h)
	local c = RelapseUI.Col
	if self.Hovered then
		RelapseUI.RoundFill(RelapseUI.RadPx("Button"), 0, 0, w, h, c.CardHover)
	end
	DrawCentered(self, w, h, self.Hovered and c.Text or c.Muted)
	return true
end

-- Flora motion: --flora-motion-base 150ms; --flora-ease-out / --flora-ease-in
RelapseUI.MotionBase = 0.15

function RelapseUI.Duration(n)
	return RelapseUI.MotionBase * (n or 1)
end

-- energetic settle: cubic-bezier(0.33, 1, 0.2, 1)
-- --flora-duration-3 = 3 × 150ms
local TAB_EASE_X1, TAB_EASE_X2 = 0.33, 0.2
local TAB_ANIM = RelapseUI.Duration(3)
local TabInk = Color(255, 255, 255, 255)

local function Bez(t, a, b)
	local u = 1 - t
	return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
end

local function BezD(t, a, b)
	local u = 1 - t
	return 3 * u * u * a + 6 * u * t * (b - a) + 3 * t * t * (1 - b)
end

local function CubicBezier(linearT, x1, y1, x2, y2)
	linearT = math.Clamp(linearT, 0, 1)
	if linearT == 0 or linearT == 1 then return linearT end
	local s = linearT
	for _ = 1, 8 do
		local x = Bez(s, x1, x2) - linearT
		if math.abs(x) < 1e-6 then break end
		local d = BezD(s, x1, x2)
		if math.abs(d) < 1e-6 then break end
		s = math.Clamp(s - x / d, 0, 1)
	end
	return Bez(s, y1, y2)
end

function RelapseUI.EaseOut(t)
	return CubicBezier(t, 0.33, 1, 0.2, 1)
end

function RelapseUI.EaseIn(t)
	return CubicBezier(t, 0.36, 0, 0.64, 1)
end

local FadePanels = {}

local function ClearFade(panel)
	if IsValid(panel) then
		panel._RelapseFade = nil
	end
	FadePanels[panel] = nil
end

-- t0 starts on first tick after the open hitch, not when the frame is built.
local function StepFade(f, now)
	if not f.armed then
		f.armed = true
		f.t0 = now
		return f.from, false
	end
	local u = (now - f.t0) / math.max(0.01, f.dur)
	if u >= 1 then
		return f.to, true
	end
	return f.from + (f.to - f.from) * f.ease(math.Clamp(u, 0, 1)), false
end

local function PumpFades()
	local now = RealTime()
	local finished = {}
	for pnl in pairs(FadePanels) do
		if not IsValid(pnl) then
			FadePanels[pnl] = nil
		else
			local f = pnl._RelapseFade
			if not f then
				FadePanels[pnl] = nil
			else
				local a, done = StepFade(f, now)
				pnl:SetAlpha(math.floor(a + 0.5))
				if done then
					local cb = f.done
					ClearFade(pnl)
					if cb then
						finished[#finished + 1] = { cb, pnl }
					end
				end
			end
		end
	end
	for i = 1, #finished do
		finished[i][1](finished[i][2])
	end
	if not next(FadePanels) then
		hook.Remove("Think", "RelapseUI.Fades")
	end
end

function RelapseUI.PlayFade(panel, target, duration, easeFn, onDone, from)
	if not IsValid(panel) then return end
	panel._RelapseFade = {
		from = from ~= nil and from or panel:GetAlpha(),
		to = target,
		armed = false,
		dur = math.max(0.01, duration or RelapseUI.Duration()),
		ease = easeFn or RelapseUI.EaseOut,
		done = onDone
	}
	FadePanels[panel] = true
	hook.Add("Think", "RelapseUI.Fades", PumpFades)
end

local function ReleasePopupInput(panel)
	local focus = vgui.GetKeyboardFocus()
	if IsValid(focus) then
		focus:KillFocus()
	end
	panel:KillFocus()
	panel:MouseCapture(false)
	panel:SetMouseInputEnabled(false)
	panel:SetKeyboardInputEnabled(false)
end

-- MakePopup re-enables keyboard and eats WASD. Tab never MakePopups, so
-- movement stays on the game. Shop/options must do the same after popup.
local function IsTextEntry(panel)
	if not IsValid(panel) then return false end
	local class = panel.ClassName
	if class == "DTextEntry" or class == "TextEntry" then
		return true
	end
	return panel.IsEditing and panel:IsEditing()
end

local function LetMove(panel)
	if not IsValid(panel) then return end
	if IsTextEntry(vgui.GetKeyboardFocus()) then return end
	if IsTextEntry(panel) then return end
	panel:SetKeyboardInputEnabled(false)
	for _, child in ipairs(panel:GetChildren()) do
		LetMove(child)
	end
end

local function BindLetMove(panel)
	if not IsValid(panel) then return end
	if not panel._RelapseLetMove then
		panel._RelapseLetMove = true
		local prev = panel.Think
		panel.Think = function(me)
			if prev then prev(me) end
			LetMove(me)
		end
	end
	LetMove(panel)
end

function RelapseUI.FadeOpen(panel)
	if not IsValid(panel) then return end
	panel._RelapseClosing = nil
	if panel ~= RelapseUI.SharedScrim then
		panel:SetMouseInputEnabled(true)
	end
	panel:SetAlpha(0)
	RelapseUI.PlayFade(panel, 255, RelapseUI.Duration(3), RelapseUI.EaseOut, nil, 0)
end

function RelapseUI.FadeClose(panel, instant, onGone)
	if not IsValid(panel) then return end
	if not panel:IsVisible() and not panel._RelapseClosing then return end
	local finish = function(pnl)
		if not IsValid(pnl) then return end
		pnl._RelapseClosing = nil
		if onGone then
			onGone(pnl)
		else
			pnl:Remove()
		end
	end
	if instant then
		ClearFade(panel)
		ReleasePopupInput(panel)
		finish(panel)
		return
	end
	if panel._RelapseClosing then return end
	panel._RelapseClosing = true
	RelapseUI.PlayFade(panel, 0, RelapseUI.Duration(2), RelapseUI.EaseIn, function(pnl)
		ReleasePopupInput(pnl)
		finish(pnl)
	end)
end

function RelapseUI.MenuHost(panel)
	if IsValid(panel) and IsValid(panel.RelapseScrim) then
		return panel.RelapseScrim
	end
	return panel
end

function RelapseUI.PaintBlank()
	return true
end

local function CountScrimUsers()
	local users = RelapseUI._ScrimUsers
	if not users then
		return 0
	end
	local n = 0
	for pnl in pairs(users) do
		if IsValid(pnl) then
			n = n + 1
		else
			users[pnl] = nil
		end
	end
	return n
end

-- Plates stay while the glass is on screen. cover 0 = full hole, 1 = no hole.
-- Opening fades the cutout with the plate's fade. Swap and close keep it put.
local function MenuScrimHole(host, w, h)
	local plates = RelapseUI._ScrimPlates
	if not plates then return end
	local hx, hy = host:LocalToScreen(0, 0)
	local x, y, ww, hh
	local cover = 0
	local openingCover
	local now = RealTime()
	for pnl in pairs(plates) do
		if not IsValid(pnl) or not pnl:IsVisible() then
			plates[pnl] = nil
		else
			local pw, ph = pnl:GetWide(), pnl:GetTall()
			if pw >= 2 and ph >= 2 and (pw < w - 1 or ph < h - 1) then
				local sx, sy = pnl:LocalToScreen(0, 0)
				local px = math.floor(sx - hx + 0.5)
				local py = math.floor(sy - hy + 0.5)
				if not x then
					x, y, ww, hh = px, py, pw, ph
				elseif x ~= px or y ~= py or ww ~= pw or hh ~= ph then
					return
				end
				local f = pnl._RelapseFade
				if f and f.to > f.from then
					-- Hole only after the plate can hide the world. Early punch
					-- is the ESC→window blink: empty cutout, then glass.
					local a = StepFade(f, now)
					local t = math.Clamp(a / 255, 0, 1)
					local hole = t > 0.8 and (t - 0.8) / 0.2 or 0
					local c = 1 - hole
					openingCover = openingCover and math.min(openingCover, c) or c
				end
			end
		end
	end
	if not x then return end
	if openingCover then
		cover = openingCover
	end
	return x, y, ww, hh, cover
end

-- AABB dim plus per-row ears so the hole matches RoundFill without stencil.
local function DimRoundEars(x, y, w, h, r)
	r = math.max(0, math.min(math.floor(r), math.floor(math.min(w, h) * 0.5)))
	if r < 1 then return end
	local r2 = r * r
	for i = 0, r - 1 do
		local t = r - i
		local chord = math.floor(math.sqrt(math.max(0, r2 - t * t)) + 0.5)
		local span = r - chord
		if span > 0 then
			surface.DrawRect(x, y + i, span, 1)
			surface.DrawRect(x + w - span, y + i, span, 1)
			surface.DrawRect(x, y + h - 1 - i, span, 1)
			surface.DrawRect(x + w - span, y + h - 1 - i, span, 1)
		end
	end
end

local function DrawDimExcept(sw, sh, x, y, hw, hh)
	if hw < 1 or hh < 1 or x >= sw or y >= sh then
		surface.DrawRect(0, 0, sw, sh)
		return
	end
	if y > 0 then
		surface.DrawRect(0, 0, sw, y)
	end
	local below = y + hh
	if below < sh then
		surface.DrawRect(0, below, sw, sh - below)
	end
	if x > 0 then
		surface.DrawRect(0, y, x, hh)
	end
	local right = x + hw
	if right < sw then
		surface.DrawRect(right, y, sw - right, hh)
	end
	DimRoundEars(x, y, hw, hh, RelapseUI.RadPx("Window"))
end

-- Inverse of DimRoundEars. DrawRect only — RoundFill does not paint on the scrim.
local function FillRoundRect(x, y, w, h, r)
	r = math.max(0, math.min(math.floor(r), math.floor(math.min(w, h) * 0.5)))
	if r < 1 then
		surface.DrawRect(x, y, w, h)
		return
	end
	if h > 2 * r then
		surface.DrawRect(x, y + r, w, h - 2 * r)
	end
	local r2 = r * r
	for i = 0, r - 1 do
		local t = r - i
		local chord = math.floor(math.sqrt(math.max(0, r2 - t * t)) + 0.5)
		local span = r - chord
		local inner = w - 2 * span
		if inner > 0 then
			surface.DrawRect(x + span, y + i, inner, 1)
			surface.DrawRect(x + span, y + h - 1 - i, inner, 1)
		end
	end
end

local function PinSharedScrim(scrim)
	if not IsValid(scrim) then return end
	scrim._RelapseClosing = nil
	ClearFade(scrim)
	scrim:SetVisible(true)
	scrim:SetAlpha(255)
	scrim:SetMouseInputEnabled(false)
	scrim:MoveToBack()
end

local function SharedScrim()
	local scrim = RelapseUI.SharedScrim
	if IsValid(scrim) then
		scrim:SetSize(ScrW(), ScrH())
		scrim:SetPos(0, 0)
		return scrim
	end
	scrim = vgui.Create("DPanel")
	scrim:SetSize(ScrW(), ScrH())
	scrim:SetPos(0, 0)
	scrim:SetMouseInputEnabled(false)
	scrim:SetKeyboardInputEnabled(false)
	scrim:SetPaintBackground(false)
	scrim:SetVisible(false)
	scrim:SetAlpha(0)
	scrim.Paint = function(me, w, h)
		if w ~= ScrW() or h ~= ScrH() then
			me:SetSize(ScrW(), ScrH())
			w, h = ScrW(), ScrH()
		end
		return RelapseUI.PaintMenuScrim(me, w, h)
	end
	RelapseUI.SharedScrim = scrim
	return scrim
end

-- One dim for every overlay. Hold/Release so window-to-window swaps keep it put.
function RelapseUI.HoldMenuScrim(user)
	RelapseUI._ScrimUsers = RelapseUI._ScrimUsers or {}
	RelapseUI._ScrimPlates = RelapseUI._ScrimPlates or {}
	if IsValid(user) then
		RelapseUI._ScrimUsers[user] = true
		RelapseUI._ScrimPlates[user] = true
	end
	local scrim = SharedScrim()
	local pin = RelapseUI._GlassSwap or RelapseUI._PinScrim
	RelapseUI._PinScrim = nil
	if pin or (scrim:IsVisible() and (scrim:GetAlpha() > 0 or scrim._RelapseClosing)) then
		if scrim:IsVisible() or scrim._RelapseClosing then
			PinSharedScrim(scrim)
			return
		end
	end
	scrim:SetVisible(true)
	RelapseUI.FadeOpen(scrim)
	scrim:SetMouseInputEnabled(false)
	scrim:MoveToBack()
end

function RelapseUI.ReleaseMenuScrim(user, instant)
	local users = RelapseUI._ScrimUsers
	if users and user ~= nil then
		users[user] = nil
	end
	if CountScrimUsers() > 0 then
		return
	end
	local scrim = RelapseUI.SharedScrim
	if not IsValid(scrim) then return end
	if RelapseUI._GlassSwap or RelapseUI._PinScrim then
		PinSharedScrim(scrim)
		return
	end
	RelapseUI.FadeClose(scrim, instant, function(pnl)
		if CountScrimUsers() > 0 then
			PinSharedScrim(pnl)
			return
		end
		pnl:SetVisible(false)
		pnl:SetAlpha(0)
		pnl:SetMouseInputEnabled(false)
	end)
end

-- Click-catcher behind chrome. Dim lives on SharedScrim, not here.
function RelapseUI.CreateMenuScrim(opts)
	opts = opts or {}
	local scrim = vgui.Create(opts.class or "DFrame")
	scrim:SetSize(ScrW(), ScrH())
	scrim:SetPos(0, 0)
	scrim:SetMouseInputEnabled(true)
	scrim:SetKeyboardInputEnabled(false)
	if scrim.SetPaintBackground then
		scrim:SetPaintBackground(false)
	end
	scrim.Paint = RelapseUI.PaintBlank
	scrim:SetVisible(false)
	scrim:SetAlpha(0)
	if scrim.SetTitle then
		scrim:SetDeleteOnClose(true)
		scrim:SetTitle("")
		scrim:SetDraggable(false)
		scrim:SetSizable(false)
		scrim:DockPadding(0, 0, 0, 0)
		RelapseUI.HideChrome(scrim)
	end
	return scrim
end

function RelapseUI.LinkMenuScrim(window, scrim, opts)
	if not (IsValid(window) and IsValid(scrim)) then return end
	opts = opts or {}
	window.RelapseScrim = scrim
	scrim.RelapseWindow = window
	if opts.closeOnClick ~= false then
		scrim.OnMousePressed = function()
			if IsValid(window) and window.Close then
				window:Close()
			end
		end
	end
	local prev = window.OnRemove
	window.OnRemove = function(me)
		if prev then prev(me) end
		RelapseUI.ReleaseMenuScrim(me)
		local host = me.RelapseScrim
		me.RelapseScrim = nil
		if IsValid(host) and not host._RelapseDead then
			host._RelapseDead = true
			host.RelapseWindow = nil
			host:Remove()
		end
	end
end

function RelapseUI.MarkGlassSwap()
	RelapseUI._GlassSwap = true
end

function RelapseUI.PinScrim()
	RelapseUI._PinScrim = true
end

function RelapseUI.TakeGlassSwap()
	local swap = RelapseUI._GlassSwap
	RelapseUI._GlassSwap = nil
	return swap
end

function RelapseUI.SwapGlass()
	local plates = RelapseUI._ScrimPlates
	if not plates then
		return false
	end
	for pnl in pairs(plates) do
		if IsValid(pnl) and pnl:IsVisible() and not pnl._RelapseClosing then
			local pw, ph = pnl:GetWide(), pnl:GetTall()
			if pw >= 2 and ph >= 2 and (pw < ScrW() - 1 or ph < ScrH() - 1) then
				return true
			end
		end
	end
	return false
end

function RelapseUI.SetMenuVisible(panel, vis)
	if not IsValid(panel) then return end
	panel:SetVisible(vis)
	local host = panel.RelapseScrim
	if IsValid(host) then
		host:SetVisible(vis)
	end
	if vis then
		RelapseUI.HoldMenuScrim(panel)
	else
		RelapseUI.ReleaseMenuScrim(panel)
	end
end

function RelapseUI.FadeOpenMenu(panel)
	if not IsValid(panel) then return end
	local host = RelapseUI.MenuHost(panel)
	local swap = RelapseUI.TakeGlassSwap()
	panel._RelapseClosing = nil
	panel:SetVisible(true)
	panel:SetMouseInputEnabled(true)
	if host ~= panel then
		host._RelapseClosing = nil
		host:SetVisible(true)
		host:SetAlpha(255)
		host:SetMouseInputEnabled(true)
	end
	if swap then
		ClearFade(panel)
		panel:SetAlpha(255)
		RelapseUI.HoldMenuScrim(panel)
		return
	end
	panel:SetAlpha(0)
	RelapseUI.FadeOpen(panel)
	RelapseUI.HoldMenuScrim(panel)
end

function RelapseUI.FadeCloseMenu(panel, instant, onGone)
	if not IsValid(panel) then return end
	RelapseUI.ReleaseMenuScrim(panel, instant)
	RelapseUI.FadeClose(panel, instant, function(pnl)
		if IsValid(pnl) then
			pnl._RelapseClosing = nil
		end
		if onGone then
			onGone(pnl)
		end
	end)
end

function RelapseUI.FadeOpenOverlay(panel)
	if not IsValid(panel) then return end
	RelapseUI._GlassSwap = nil
	RelapseUI.HoldMenuScrim(panel)
	RelapseUI.FadeOpen(panel)
end

function RelapseUI.TabStrip(sheet)
	if IsValid(sheet) and IsValid(sheet.tabScroller) then
		return sheet.tabScroller
	end
	return sheet
end

function RelapseUI.StepTabIndicator(sheet)
	if not IsValid(sheet) then return end
	local tab = sheet.GetActiveTab and sheet:GetActiveTab()
	if not IsValid(tab) then return end

	local host = RelapseUI.TabStrip(sheet)
	local sx = select(1, host:ScreenToLocal(tab:LocalToScreen(0, 0)))
	local tw = tab:GetWide()
	local now = RealTime()
	local st = sheet._TabInd
	if not st then
		sheet._TabInd = {
			x = sx, w = tw,
			fromX = sx, fromW = tw,
			toX = sx, toW = tw,
			t0 = now, primed = tw > 1
		}
		return
	end

	if tw > 1 and (not st.primed or math.abs(sx - st.toX) > 0.5 or math.abs(tw - st.toW) > 0.5) then
		if st.primed then
			st.fromX, st.fromW = st.x, st.w
			st.t0 = now
		else
			st.fromX, st.fromW = sx, tw
			st.t0 = now - TAB_ANIM
		end
		st.toX, st.toW = sx, tw
		st.primed = true
	end

	local e = RelapseUI.EaseOut(math.Clamp((now - st.t0) / TAB_ANIM, 0, 1))
	st.x = st.fromX + (st.toX - st.fromX) * e
	st.w = st.fromW + (st.toW - st.fromW) * e
end

function RelapseUI.PaintTabIndicator(sheet, w, h)
	local st = sheet._TabInd
	if not st or not st.primed or st.w < 1 then return end

	local thick = math.max(2, RelapseUI.sPx(2))
	local x1 = math.max(0, st.x)
	local x2 = math.min(w, st.x + st.w)
	local dw = x2 - x1
	if dw < 2 then return end

	local r = math.min(RelapseUI.RadPx("Bar"), math.floor(math.min(dw, thick) * 0.5))
	DisableClipping(true)
	RelapseUI.RoundFill(r, x1, h, dw, thick, RelapseUI.Col.Accent)
	DisableClipping(false)
end

function RelapseUI.BindTabIndicator(sheet)
	if not IsValid(sheet) or sheet._RelapseTabInd then return end
	sheet._RelapseTabInd = true

	local prevThink = sheet.Think
	sheet.Think = function(me)
		if prevThink then prevThink(me) end
		RelapseUI.StepTabIndicator(me)
	end

	local scroller = sheet.tabScroller
	if not IsValid(scroller) or scroller._RelapseTabIndPaint then return end
	scroller._RelapseTabIndPaint = true
	local prevOver = scroller.PaintOver
	scroller.PaintOver = function(me, w, h)
		if prevOver then prevOver(me, w, h) end
		RelapseUI.PaintTabIndicator(sheet, w, h)
	end
end

function RelapseUI.PaintTab(self, w, h)
	local c = RelapseUI.Col
	local act = 0
	local sheet = self.GetPropertySheet and self:GetPropertySheet()
	local st = IsValid(sheet) and sheet._TabInd
	if st and st.primed and st.w > 1 then
		local host = RelapseUI.TabStrip(sheet)
		local sx = select(1, host:ScreenToLocal(self:LocalToScreen(0, 0)))
		local ov = math.max(0, math.min(st.x + st.w, sx + w) - math.max(st.x, sx))
		act = ov / math.max(1, math.min(st.w, w))
	elseif self.IsActive and self:IsActive() then
		act = 1
	end
	if self.Hovered then
		act = math.max(act, 1)
	end
	RelapseUI.LerpCol(c.Muted, c.Text, act, TabInk)
	local text = self.GetText and self:GetText() or ""
	if text ~= "" then
		draw.SimpleText(text, self:GetFont() or "Relapse20", w * 0.5, h * 0.5, TabInk, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	return true
end

local colStatBar = Color(0, 0, 0, 255)

function RelapseUI.PaintStatBar(self, w, h)
	self.LerpStat = Lerp(FrameTime() * 6, self.LerpStat or self.Stat, self.Stat)
	local span = math.max(1e-6, self.StatMax - self.StatMin)
	local progress = math.Clamp((self.LerpStat - self.StatMin) / span, 0, 1)
	if self.BadHigh then
		progress = 1 - progress
	end

	RelapseUI.PaintHudBar(0, 0, w, h, progress, RelapseUI.HealthCol(progress, colStatBar))
	return true
end

function RelapseUI.HudInset()
	return RelapseUI.Grid15(3)
end

function RelapseUI.HudW()
	return RelapseUI.Grid15(24)
end

RelapseUI.Shadow = 3
RelapseUI.ShadowAngle = 120 -- 0° up, clockwise
RelapseUI.ShadowOn = false -- trial: HUD/sigil/crosshair stamp off

function RelapseUI.EachShadow(fn, n)
	if not RelapseUI.ShadowOn then return end
	n = n or RelapseUI.Shadow
	local rad = math.rad(RelapseUI.ShadowAngle)
	local dx, dy = math.sin(rad), -math.cos(rad)
	for i = 1, n do
		fn(Round(i * dx), Round(i * dy))
	end
end

local quadPts = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}

function RelapseUI.FillQuad(x1, y1, x2, y2, x3, y3, x4, y4, col)
	if not col then return end
	quadPts[1].x, quadPts[1].y = x1, y1
	quadPts[2].x, quadPts[2].y = x2, y2
	quadPts[3].x, quadPts[3].y = x3, y3
	quadPts[4].x, quadPts[4].y = x4, y4
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	draw.NoTexture()
	surface.DrawPoly(quadPts)
end

-- Tiny 45° \ hairline. span on the 15-grid. sPx stroke; shadow is thickness along ShadowAngle.
function RelapseUI.PaintHudDiagHair(x, y, span, col, thick, shadow)
	x = math.floor(x + 0.5)
	y = math.floor(y + 0.5)
	span = math.floor(span + 0.5)
	local t = math.max(1, thick or RelapseUI.sPx(1))
	if span <= t * 2 then return end

	local function quad(ox, oy, fill)
		RelapseUI.FillQuad(
			x + ox + t, y + oy,
			x + ox + span, y + oy + span - t,
			x + ox + span - t, y + oy + span,
			x + ox, y + oy + t,
			fill
		)
	end

	if shadow and shadow > 0 then
		RelapseUI.EachShadow(function(ox, oy)
			quad(ox, oy, RelapseUI.Col.Shadow)
		end, shadow)
	end
	quad(0, 0, col)
end

function RelapseUI.HudText(text, font, x, y, col, ax, ay, shadow)
	if not text or text == "" then return end
	col = col or RelapseUI.Col.Text
	ax = ax or TEXT_ALIGN_LEFT
	ay = ay or TEXT_ALIGN_TOP

	surface.SetFont(font)
	local tw, th = surface.GetTextSize(text)
	local px, py = x, y
	if ax == TEXT_ALIGN_RIGHT then
		px = x - tw
	elseif ax == TEXT_ALIGN_CENTER then
		px = x - tw * 0.5
	end
	if ay == TEXT_ALIGN_BOTTOM then
		py = y - th
	elseif ay == TEXT_ALIGN_CENTER then
		py = y - th * 0.5
	end
	px = math.floor(px + 0.5)
	py = math.floor(py + 0.5)

	local sh = RelapseUI.Col.Shadow
	surface.SetTextColor(sh.r, sh.g, sh.b, col.a or 255)
	RelapseUI.EachShadow(function(ox, oy)
		surface.SetTextPos(px + ox, py + oy)
		surface.DrawText(text)
	end, shadow)
	surface.SetTextColor(col.r, col.g, col.b, col.a or 255)
	surface.SetTextPos(px, py)
	surface.DrawText(text)
end

function RelapseUI.PaintHudHairBar(x, y, w, h, frac, col, extrafrac, extracol, shadow)
	if w < 2 or h < 1 then return end
	frac = math.Clamp(frac or 0, 0, 1)
	extrafrac = math.Clamp(extrafrac or 0, 0, 1 - frac)
	local r = math.min(RelapseUI.RadPx("Bar"), math.floor(math.min(w, h) * 0.5))
	local c = RelapseUI.Col
	RelapseUI.EachShadow(function(ox, oy)
		RelapseUI.RoundFill(r, x + ox, y + oy, w, h, c.Shadow)
	end, shadow)
	RelapseUI.RoundFill(r, x, y, w, h, c.HudTrack)
	local extraW = extrafrac > 0 and math.floor(w * (frac + extrafrac) + 0.5) or 0
	local fillW = frac >= 0.995 and w or math.floor(w * frac + 0.5)
	if extraW > fillW and extracol then
		RelapseUI.RoundFill(math.min(r, math.floor(extraW * 0.5)), x, y, extraW, h, extracol)
	end
	if fillW > 0 and col then
		RelapseUI.RoundFill(math.min(r, math.floor(fillW * 0.5)), x, y, fillW, h, col)
	end
end

function RelapseUI.CreateWorldFonts()
	if RelapseUI._WorldFonts then return end
	RelapseUI._WorldFonts = true
	surface.CreateFont("Relapse3D", {
		font = "Manrope",
		size = 128,
		weight = 500,
		antialias = true,
		extended = true,
		shadow = false,
		outline = false
	})
end

local colWorldText = Color(0, 0, 0, 255)
local matWorldSigil

-- Through-wall sigil: grayscale photo of the post, Fog/Gray/Wine multiply, 120° shadow.
function RelapseUI.PaintWorldSigil(letter, frac, col, alpha)
	RelapseUI.CreateWorldFonts()
	if not matWorldSigil then
		matWorldSigil = Material("zombiesurvival/relapse_sigil.png")
	end
	frac = math.Clamp(frac or 0, 0, 1)
	alpha = math.Clamp(alpha or 255, 0, 255)
	local c = RelapseUI.Col
	local shadow = 8
	local x, y, w, h = -64, -128, 128, 256

	surface.SetMaterial(matWorldSigil)
	RelapseUI.EachShadow(function(ox, oy)
		surface.SetDrawColor(c.Shadow.r, c.Shadow.g, c.Shadow.b, alpha)
		surface.DrawTexturedRect(x + ox, y + oy, w, h)
	end, shadow)
	surface.SetDrawColor(col.r, col.g, col.b, alpha)
	surface.DrawTexturedRect(x, y, w, h)
	if frac < 0.995 then
		local missing = 1 - frac
		surface.SetDrawColor(c.Ink.r, c.Ink.g, c.Ink.b, alpha)
		surface.DrawTexturedRectUV(x, y, w, h * missing, 0, 0, 1, missing)
	end

	colWorldText.r, colWorldText.g, colWorldText.b, colWorldText.a = col.r, col.g, col.b, alpha
	RelapseUI.HudText(letter, "Relapse3D", 0, y + h + 8, colWorldText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, shadow)
end

-- Scratch buffers only. Values are always overwritten from RelapseUI.Col.
-- LerpCol lives next to the token table in sh_relapse_theme.lua.
local colHealthA = Color(0, 0, 0, 255)
local colUrgent = Color(0, 0, 0, 255)

function RelapseUI.HealthCol(frac, out)
	local c = RelapseUI.Col
	frac = math.Clamp(frac or 0, 0, 1)
	return RelapseUI.LerpCol(c.HealthMin, c.HealthMax, frac, out or colHealthA)
end

function RelapseUI.UrgentCol(seconds, calm)
	if (seconds or 999) > 10 then
		return calm or RelapseUI.Col.Text
	end
	local d = RelapseUI.Col.Danger
	colUrgent.r, colUrgent.g, colUrgent.b = d.r, d.g, d.b
	colUrgent.a = 90 + math.abs(math.sin(RealTime() * 8)) * 165
	return colUrgent
end

function RelapseUI.PaintHudBar(x, y, w, h, frac, col, extrafrac, extracol)
	if w < 2 or h < 2 then return end
	local r = math.min(RelapseUI.RadPx("Bar"), math.floor(math.min(w, h) * 0.5))
	RelapseUI.RoundFill(r, x, y, w, h, RelapseUI.Col.Track)
	frac = math.Clamp(frac or 0, 0, 1)
	extrafrac = math.Clamp(extrafrac or 0, 0, 1 - frac)
	local extraW = extrafrac > 0 and math.floor(w * (frac + extrafrac) + 0.5) or 0
	local fillW = frac >= 0.995 and w or math.floor(w * frac + 0.5)
	if extraW > fillW and extracol then
		RelapseUI.RoundFill(math.min(r, math.floor(extraW * 0.5)), x, y, extraW, h, extracol)
	end
	if fillW > 0 and col then
		RelapseUI.RoundFill(math.min(r, math.floor(fillW * 0.5)), x, y, fillW, h, col)
	end
end

function RelapseUI.StyleScroll(pnl)
	if not IsValid(pnl) then return end

	if pnl.SetPaintBackground then
		pnl:SetPaintBackground(false)
	end
	local canvas = pnl.GetCanvas and pnl:GetCanvas()
	if IsValid(canvas) and canvas.SetPaintBackground then
		canvas:SetPaintBackground(false)
	end

	local bar = pnl.GetVBar and pnl:GetVBar() or pnl.VBar
	if not IsValid(bar) then return end

	local wide = RelapseUI.ScrollBarW()
	bar:SetWide(wide)
	bar:DockMargin(RelapseUI.ScrollGap(), 0, 0, 0)
	if bar.SetHideButtons then
		bar:SetHideButtons(true)
	end

	bar.Paint = function()
		return true
	end
	if IsValid(bar.btnGrip) then
		bar.btnGrip.Paint = function(me, w, h)
			RelapseUI.RoundFill(w * 0.5, 0, 0, w, h, RelapseUI.Col.Text)
		end
	end
	if IsValid(bar.btnUp) then
		bar.btnUp:SetVisible(false)
		bar.btnUp.Paint = function() return true end
	end
	if IsValid(bar.btnDown) then
		bar.btnDown:SetVisible(false)
		bar.btnDown.Paint = function() return true end
	end
end

function RelapseUI.PinTabContent(sheet, tabhei, gap)
	if not IsValid(sheet) or sheet._RelapseTabGap then return end
	tabhei = tabhei or RelapseUI.M().tabs
	gap = gap or RelapseUI.M().tabGap
	sheet._RelapseTabGap = gap
	sheet._RelapseTabHei = tabhei
	RelapseUI.BindTabIndicator(sheet)
	local prev = sheet.PerformLayout
	sheet.PerformLayout = function(me, w, h)
		if prev then
			prev(me, w, h)
		end
		local top = tabhei + gap
		if IsValid(me.tabScroller) then
			local host = me:GetParent()
			local scroller = me.tabScroller
			scroller:Dock(NODOCK)
			scroller:DockMargin(0, 0, 0, 0)
			if scroller.SetOverlap then
				scroller:SetOverlap(0)
			end
			if IsValid(host) then
				local sx, sy = me:GetPos()
				local span = math.max(me:GetWide(), host:GetWide() - sx - RelapseUI.FooterSideInset())
				scroller:SetParent(host)
				scroller:Dock(NODOCK)
				scroller:DockMargin(0, 0, 0, 0)
				scroller:SetPos(sx, sy)
				scroller:SetSize(span, tabhei)
				scroller:InvalidateLayout(true)
			else
				scroller:SetParent(me)
				scroller:SetPos(0, 0)
				scroller:SetSize(me:GetWide(), tabhei)
			end
		end
		for _, item in ipairs(me.Items or {}) do
			local pan = item.Panel
			if IsValid(pan) then
				pan:SetPos(0, top)
				pan:SetSize(me:GetWide(), math.max(0, me:GetTall() - top))
			end
		end
		RelapseUI.PinViewerToItems(me:GetParent(), me)
	end
	sheet:InvalidateLayout(true)
end

function RelapseUI.PinViewerToItems(frame, sheet)
	if not IsValid(frame) or not IsValid(sheet) then return end
	local viewer = frame.Viewer
	if not IsValid(viewer) then return end
	if viewer.GetDock and viewer:GetDock() ~= NODOCK then return end

	-- Item panes sit at (0, tabhei+gap) in the sheet. Do not use
	-- LocalToScreen on the active pane: nested DPanel hosts (arsenal
	-- T1–T5) report the sheet origin, so the sidebar climbs into the tabs.
	local _, sheetY = sheet:GetPos()
	local top = (sheet._RelapseTabHei or RelapseUI.M().tabs) + (sheet._RelapseTabGap or RelapseUI.M().tabGap)
	local h = math.max(0, sheet:GetTall() - top)
	viewer:SetPos(frame:GetWide() - RelapseUI.FooterSideInset() - viewer:GetWide(), sheetY + top)
	if h > 0 then
		viewer:SetTall(h)
	end
	if IsValid(viewer.m_Title) then
		viewer.m_Title:InvalidateLayout(true)
	end
	if viewer.RelapsePlayerView then
		RelapseUI.LayoutViewerPlayerModel(viewer)
	end
	RelapseUI.LayoutViewerAmmo(viewer)
	RelapseUI.LayoutViewerStats(viewer)
end

function RelapseUI.FooterInset()
	return RelapseUI.sPx(30)
end

function RelapseUI.FooterSideInset()
	return RelapseUI.sPx(45)
end

function RelapseUI.AlignFooterBottom(pnl)
	if not IsValid(pnl) then return end
	local host = pnl:GetParent()
	if not IsValid(host) then return end
	pnl:SetY(host:GetTall() - RelapseUI.FooterInset() - pnl:GetTall())
end

function RelapseUI.AlignFooterLeft(pnl)
	if not IsValid(pnl) then return end
	local host = pnl:GetParent()
	if not IsValid(host) then return end
	pnl:SetX(RelapseUI.FooterSideInset() - host:GetX())
end

function RelapseUI.AlignFooterRight(pnl)
	if not IsValid(pnl) then return end
	local host = pnl:GetParent()
	if not IsValid(host) then return end
	local frame = host:GetParent()
	local fw = IsValid(frame) and frame:GetWide() or (host:GetX() + host:GetWide())
	pnl:SetX(fw - RelapseUI.FooterSideInset() - pnl:GetWide() - host:GetX())
end

function RelapseUI.PlaceShopTiers(strip, L)
	if not IsValid(strip) then return end
	if strip.RelapseLayout then
		strip.RelapseLayout(strip)
	end
	RelapseUI.AlignFooterBottom(strip)
	strip:SetX((L and L.gridW or 0) - RelapseUI.sPx(15) - strip:GetWide())
end

function RelapseUI.LayoutWorthChip(lab)
	if not IsValid(lab) then return end
	local cap = lab.RelapseAfter
	local box = lab:GetParent()
	if not IsValid(cap) or not IsValid(box) then return end
	local gap = RelapseUI.Grid15()
	surface.SetFont("Relapse30")
	local capW, capH = surface.GetTextSize(cap:GetText() or "")
	surface.SetFont("Relapse45")
	local numW, numH = surface.GetTextSize(lab:GetText() or "")
	local nudge = RelapseUI.WorthNumNudge(capH, numH)
	local h = math.max(capH, numH)
	box:SetSize(capW + gap + numW, h)
	local host = box:GetParent()
	if IsValid(host) then
		box:SetY(host:GetTall() - RelapseUI.FooterInset() - h)
		RelapseUI.AlignFooterLeft(box)
	end
	box._WorthNudge = nudge
	box:NoClipping(true)
end

-- Larger type keeps more empty cell below the glyph. Drop the counter onto the cap line.
function RelapseUI.WorthNumNudge(capH, numH)
	return math.max(0, math.floor((numH - capH) * 0.34 + 0.5))
end

function RelapseUI.PaintWorthChip(cap, lab, w, h)
	if not IsValid(cap) or not IsValid(lab) then return end
	local gap = RelapseUI.Grid15()
	surface.SetFont("Relapse30")
	local capW, capH = surface.GetTextSize(cap:GetText() or "")
	surface.SetFont("Relapse45")
	local _, numH = surface.GetTextSize(lab:GetText() or "0")
	local y = h
	draw.SimpleText(cap:GetText(), "Relapse30", 0, y, RelapseUI.Col.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	draw.SimpleText(lab:GetText(), "Relapse45", capW + gap, y + RelapseUI.WorthNumNudge(capH, numH), lab:GetTextColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
end

function RelapseUI.WarmPropertySheet(sheet)
	if not IsValid(sheet) then return end

	sheet:InvalidateLayout(true)

	local active = sheet:GetActiveTab()
	for _, item in ipairs(sheet.Items or {}) do
		local pan = item.Panel
		if not IsValid(pan) then continue end

		pan:SetVisible(true)
		pan:InvalidateLayout(true)
		if pan.InvalidateChildren then
			pan:InvalidateChildren(true)
		end

		local canvas = pan.GetCanvas and pan:GetCanvas()
		if IsValid(canvas) then
			canvas:InvalidateLayout(true)
			if canvas.PaintAt then
				canvas:PaintAt(-8192, -8192)
			end
		elseif pan.PaintAt then
			pan:PaintAt(-8192, -8192)
		end

		if item.Tab ~= active then
			pan:SetVisible(false)
		end
	end

	sheet:InvalidateLayout(true)
end

function RelapseUI.UpdateWorthLabel(lab, remaining, starting)
	if not IsValid(lab) then return end
	lab:SetText(tostring(remaining))
	if remaining <= 0 then
		lab:SetTextColor(RelapseUI.Col.Danger)
	else
		lab:SetTextColor(RelapseUI.Col.Ok)
	end
	lab:SizeToContents()
	if IsValid(lab.RelapseAfter) then
		RelapseUI.LayoutWorthChip(lab)
	elseif lab.RelapseAlignRight then
		lab:AlignRight(0)
	elseif lab.RelapseAlignLeft then
		lab:AlignLeft(0)
	end
	lab:InvalidateLayout()
end

function RelapseUI.SyncPointsChip(lab)
	if not IsValid(lab) or not IsValid(MySelf) then return end
	local points = MySelf:GetPoints() or 0
	if lab.m_LastPoints == points then return end
	lab.m_LastPoints = points
	RelapseUI.UpdateWorthLabel(lab, points)
end

function RelapseUI.FrameSize(maxCols, maxRows)
	local m = RelapseUI.M()
	local cols = math.min(math.floor((ScrW() - 2 * m.pad) / m.step), maxCols)
	local rows = math.min(math.floor((ScrH() - 2 * m.pad) / m.step), maxRows)
	cols = math.max(40, cols)
	rows = math.max(32, rows)
	return cols * m.step, rows * m.step, m
end

function RelapseUI.ShopWindowSize()
	local m = RelapseUI.M()
	local gridW = RelapseUI.Cells(45)
	local cardGap = m.cardGap
	local cardW = math.floor((gridW - cardGap) / 2)
	local sheetW = gridW + m.scroll
	local needW = m.pad + sheetW + RelapseUI.ViewerGap() + RelapseUI.ViewerW() + RelapseUI.FooterSideInset()
	local cols = math.ceil(needW / m.step)
	local wid, hei, m = RelapseUI.FrameSize(cols, 51)
	return {
		wid = wid,
		hei = hei,
		m = m,
		gridW = gridW,
		cardW = cardW,
		cardGap = cardGap,
		sheetW = sheetW,
		pad = m.pad,
		headerh = m.header,
		footerh = m.footer,
		tabhei = m.tabs,
		tabGap = m.tabGap,
		innerW = wid - 2 * m.pad,
		sheetH = hei - m.header - m.footer
	}
end

function RelapseUI.InvWindowSize()
	local m = RelapseUI.M()
	local cell = RelapseUI.Grid15(4)
	local gap = RelapseUI.Grid15()
	local pad = m.pad
	local bagCols, bagRows = 9, 3
	local hotN = 9
	local bagW = bagCols * cell + (bagCols - 1) * gap
	local bagH = bagRows * cell + (bagRows - 1) * gap
	local hotW = hotN * cell + (hotN - 1) * gap
	-- Relapse30 cell hangs sPx(6) under ink. 45px from ink to the card top.
	local titleY = RelapseUI.Grid15(2)
	surface.SetFont("Relapse30")
	local _, titleCell = surface.GetTextSize("Ay")
	if not titleCell or titleCell < 1 then
		titleCell = RelapseUI.sPx(30)
	end
	local header = titleY + titleCell - RelapseUI.sPx(6) + RelapseUI.sPx(45)
	local split = RelapseUI.Grid15(2)
	return {
		m = m,
		cell = cell,
		gap = gap,
		pad = pad,
		titleY = titleY,
		header = header,
		split = split,
		bagCols = bagCols,
		bagRows = bagRows,
		bagN = 27,
		hotN = hotN,
		bagW = bagW,
		bagH = bagH,
		hotW = hotW,
		wid = pad + hotW + pad,
		hei = header + bagH + split + cell + pad,
		viewerGap = RelapseUI.sPx(30),
		actionGap = RelapseUI.sPx(30)
	}
end

function RelapseUI.ScoreboardWindowSize()
	local L = RelapseUI.ShopWindowSize()
	local m = L.m
	local colGap = RelapseUI.Grid15(3)
	local listW = math.floor((L.innerW - colGap) * 0.5)
	return {
		wid = L.wid,
		hei = L.hei,
		m = m,
		pad = L.pad,
		headerh = L.headerh,
		headingH = L.tabhei,
		tabhei = L.tabhei,
		tabGap = L.tabGap,
		colGap = colGap,
		colW = math.max(m.step, listW - m.scroll),
		listW = listW,
		rowH = RelapseUI.Grid15(2) + RelapseUI.Grid15() * 2,
		rowGap = RelapseUI.Grid15(),
		innerW = L.innerW
	}
end

-- 45px from Relapse30 optical bottom to the Relapse20 tab capital.
function RelapseUI.TitleAboveTabY(L, titleCell)
	surface.SetFont("Relapse20")
	local _, tabCell = surface.GetTextSize("Ay")
	if not tabCell or tabCell < 1 then
		tabCell = RelapseUI.sPx(20)
	end
	if not titleCell or titleCell < 1 then
		surface.SetFont("Relapse30")
		titleCell = select(2, surface.GetTextSize("Ay"))
		if not titleCell or titleCell < 1 then
			titleCell = RelapseUI.sPx(30)
		end
	end
	local tabhei = L.tabhei or L.headingH or RelapseUI.M().tabs
	local tabCapY = L.headerh + math.ceil((tabhei - tabCell) * 0.5) + RelapseUI.sPx(5)
	return math.max(0, tabCapY - RelapseUI.sPx(45) - (titleCell - RelapseUI.sPx(6)))
end

function RelapseUI.PlaceShopTitle(title, L)
	if not IsValid(title) then return end
	title:SetPos(L.pad, RelapseUI.TitleAboveTabY(L, title:GetTall()))
	RelapseUI.PlaceShopSwitch(title:GetParent())
end

function RelapseUI.ShopSwitchPair(kind)
	if kind == "worth" or kind == "points" then
		return { "worth", "points" }
	end
	if kind == "inventory" or kind == "invshop" then
		return { "inventory", "invshop" }
	end
end

local function HideShopSibling(kind, name, panel)
	if kind == name or not IsValid(panel) or not panel:IsVisible() then
		return
	end
	RelapseUI.MarkGlassSwap()
	RelapseUI.SetMenuVisible(panel, false)
end

function RelapseUI.HideOtherShops(kind)
	HideShopSibling(kind, "worth", pWorth)
	HideShopSibling(kind, "points", GAMEMODE and GAMEMODE.ArsenalInterface)
	HideShopSibling(kind, "inventory", GAMEMODE and GAMEMODE.RelapseInventoryInterface)
	HideShopSibling(kind, "invshop", GAMEMODE and GAMEMODE.RelapseInvShopInterface)
end

function RelapseUI.ShowShopFrame(frame)
	if not IsValid(frame) then return end
	local host = RelapseUI.MenuHost(frame)
	if not RelapseUI._GlassSwap then
		frame:SetAlpha(0)
	end
	host:SetVisible(true)
	frame:SetVisible(true)
	host:MakePopup()
	host:MoveToFront()
	if host ~= frame then
		frame:MoveToFront()
	end
	if not RelapseUI._GlassSwap then
		frame:SetAlpha(0)
	end
	BindLetMove(host)
	RelapseUI.FadeOpenMenu(frame)
end

function RelapseUI.OpenShop(kind)
	if kind == "points" then
		if GAMEMODE and GAMEMODE.OpenArsenalMenu then
			GAMEMODE:OpenArsenalMenu()
		end
		return
	end
	if kind == "inventory" then
		if GAMEMODE and GAMEMODE.OpenRelapseInventory then
			GAMEMODE:OpenRelapseInventory()
		end
		return
	end
	if kind == "invshop" then
		if GAMEMODE and GAMEMODE.OpenRelapseInvShop then
			GAMEMODE:OpenRelapseInvShop()
		end
		return
	end

	RelapseUI.HideOtherShops("worth")
	if pWorth and pWorth:IsValid() then
		RelapseUI.ShowShopFrame(pWorth)
	elseif MakepWorth then
		MakepWorth()
	end
end

local function ShopSwitchFont()
	return "Relapse30"
end

local function ShopSwitchGlyph(dir)
	return (dir or 1) < 0 and "<" or ">"
end

local function SizeShopSwitch(btn)
	if not IsValid(btn) then return end
	surface.SetFont(ShopSwitchFont())
	local tw, th = surface.GetTextSize(ShopSwitchGlyph(btn.RelapseDir))
	btn:SetSize(math.max(1, tw), math.max(1, th))
end

function RelapseUI.PlaceShopSwitch(frame)
	if not IsValid(frame) then return end
	local title = frame.RelapseTitle
	local prev = frame.RelapseShopPrev
	local nxt = frame.RelapseShopNext
	if not IsValid(title) or not IsValid(prev) or not IsValid(nxt) then return end

	SizeShopSwitch(prev)
	SizeShopSwitch(nxt)

	surface.SetFont(title:GetFont() or "Relapse30")
	local textW, fontH = surface.GetTextSize(title:GetText() or "")
	if textW < 1 then
		textW = title:GetWide()
		fontH = title:GetTall()
	end
	local _, lastRsb = RelapseUI.ManropeCharPad(LastCodepoint(title:GetText() or ""), fontH)
	lastRsb = math.ceil(lastRsb - 1e-6)

	local gap = RelapseUI.sPx(30)
	local pair = RelapseUI.Grid15()
	local tx, ty = title:GetPos()
	local th = title:GetTall()
	local bh = prev:GetTall()
	local by = ty + math.floor((th - bh) * 0.5)
	prev:SetPos(tx + textW - lastRsb + gap, by)
	nxt:SetPos(tx + textW - lastRsb + gap + prev:GetWide() + pair, by)
end

local function PaintShopSwitch(self, w, h)
	local c = RelapseUI.Col
	local on = not self.RelapseCurrent
	local col = on and c.Text or c.Muted
	local lsb = math.ceil(RelapseUI.ManropeCharPad(60, h) - 1e-6)
	draw.SimpleText(ShopSwitchGlyph(self.RelapseDir), ShopSwitchFont(), -lsb, h * 0.5, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	return true
end

function RelapseUI.MakeDirSwitch(frame, dir, current, onClick)
	local btn = vgui.Create("DButton", frame)
	btn:SetText("")
	btn:SetFont(ShopSwitchFont())
	btn:SetPaintBackground(false)
	btn:SetPaintBackgroundEnabled(false)
	btn.ApplySchemeSettings = function() end
	btn:SetCursor(current and "arrow" or "hand")
	btn.RelapseDir = dir
	btn.RelapseCurrent = current
	SizeShopSwitch(btn)
	btn.Paint = PaintShopSwitch
	btn.DoClick = function(me)
		if me.RelapseCurrent then return end
		surface.PlaySound("buttons/button14.wav")
		if onClick then
			onClick(me)
		end
	end
	return btn
end

local function MakeShopSwitch(frame, dir, target, current)
	local btn = RelapseUI.MakeDirSwitch(frame, dir, current, function(me)
		RelapseUI.OpenShop(me.RelapseTarget)
	end)
	btn.RelapseTarget = target
	return btn
end

function RelapseUI.BuildShopFrame(titleKey, opts)
	opts = opts or {}
	RelapseUI.CreateFonts()
	local L = RelapseUI.ShopWindowSize()
	local m = L.m
	local pad = L.pad

	local scrim = RelapseUI.CreateMenuScrim()
	local frame = vgui.Create("DFrame", scrim)
	frame:SetSize(L.wid, L.hei)
	frame:SetDeleteOnClose(opts.deleteOnClose ~= false)
	frame:SetKeyboardInputEnabled(false)
	frame:SetTitle("")
	frame:SetDraggable(opts.draggable ~= false)
	frame:DockPadding(0, 0, 0, 0)
	frame.RelapseFooter = L.footerh
	frame.RelapseLayout = L
	frame.RelapseShop = opts.shop
	frame.Paint = RelapseUI.PaintWindow
	frame:SetAlpha(0)
	RelapseUI.HideChrome(frame)
	RelapseUI.LinkMenuScrim(frame, scrim)
	frame.Close = function(me, instant)
		RelapseUI.FadeCloseMenu(me, instant, function(pnl)
			if not IsValid(pnl) then return end
			pnl:SetVisible(false)
			if pnl.OnClose then
				pnl:OnClose()
			end
			local host = RelapseUI.MenuHost(pnl)
			if pnl:GetDeleteOnClose() then
				if IsValid(host) and host ~= pnl then
					pnl.RelapseScrim = nil
					host._RelapseDead = true
					host.RelapseWindow = nil
					host:Remove()
				else
					pnl:Remove()
				end
			else
				if IsValid(host) and host ~= pnl then
					host:SetVisible(false)
					host:SetAlpha(0)
				end
			end
		end)
	end

	local title = EasyLabel(frame, RelapseUI.T(titleKey), "Relapse30", RelapseUI.Col.Text)
	title:SetContentAlignment(4)
	title:SizeToContents()
	frame.RelapseTitle = title
	local shopPair = RelapseUI.ShopSwitchPair(opts.shop)
	if shopPair then
		frame.RelapseShopPrev = MakeShopSwitch(frame, -1, shopPair[1], opts.shop == shopPair[1])
		frame.RelapseShopNext = MakeShopSwitch(frame, 1, shopPair[2], opts.shop == shopPair[2])
	end
	RelapseUI.PlaceShopTitle(title, L)

	local close = vgui.Create("DButton", frame)
	close:SetText("×")
	close:SetFont("Relapse30")
	close:SetSize(m.close, m.close)
	close:AlignRight(pad)
	close:AlignTop(RelapseUI.Grid15(2))
	close.Paint = RelapseUI.PaintGhostButton
	close.DoClick = function() frame:Close() end
	frame.RelapseClose = close

	local topspace = vgui.Create("DPanel", frame)
	topspace:SetPaintBackground(false)
	topspace:SetSize(L.innerW, 0)
	topspace:SetPos(pad, L.headerh)

	local bottomspace = vgui.Create("DPanel", frame)
	bottomspace:SetPaintBackground(false)
	bottomspace:SetSize(L.innerW, L.footerh)
	bottomspace:SetPos(pad, L.hei - L.footerh)

	local propertysheet = vgui.Create("DPropertySheet", frame)
	propertysheet:SetSize(L.sheetW, L.sheetH)
	propertysheet:SetPos(pad, L.headerh)
	propertysheet:SetPadding(0)
	propertysheet.Paint = RelapseUI.PaintSheet

	if IsValid(frame.RelapseShopPrev) then
		frame.RelapseShopPrev:MoveToFront()
		frame.RelapseShopNext:MoveToFront()
	end
	if IsValid(close) then
		close:MoveToFront()
	end

	return frame, L, topspace, bottomspace, propertysheet
end

function RelapseUI.CreateShopChip(bottomspace, capText, valueText)
	local box = vgui.Create("DPanel", bottomspace)
	box:SetPaintBackground(false)

	local cap = EasyLabel(box, capText, "Relapse30", RelapseUI.Col.Muted)
	cap:SetVisible(false)

	local lab = EasyLabel(box, tostring(valueText), "Relapse45", RelapseUI.Col.Ok)
	lab:SetVisible(false)
	lab.RelapseAfter = cap
	box.Paint = function(me, w, h)
		RelapseUI.PaintWorthChip(cap, lab, w, h)
		return true
	end
	RelapseUI.LayoutWorthChip(lab)
	return box, cap, lab
end

function RelapseUI.MakeShopGrid(parent, L, trinkets)
	local list = vgui.Create("DGrid", parent)
	list:SetSize(L.gridW, L.sheetH - L.tabhei - L.tabGap)
	list:SetCols(2)
	list:SetColWide(L.cardW + L.cardGap)
	list:SetRowHeight((trinkets and L.m.trinketH or L.m.cardH) + L.cardGap)
	return list
end

function RelapseUI.TabInkPad()
	return RelapseUI.Grid15(2)
end

function RelapseUI.SizeTabButton(tab)
	if not IsValid(tab) then return end
	surface.SetFont(tab.m_FontName or "Relapse20")
	local tw = surface.GetTextSize(tab:GetText() or "")
	local pad = RelapseUI.TabInkPad()
	local w = tw + pad * 2
	local h = tab.GetTabHeight and tab:GetTabHeight() or RelapseUI.M().tabs
	if tab:GetWide() ~= w or tab:GetTall() ~= h then
		tab:SetSize(w, h)
	end
end

function RelapseUI.CreateFilterStrip(parent, labels, defaultIndex, onSelect)
	local strip = vgui.Create("DPanel", parent)
	strip:SetPaintBackground(false)
	strip.Paint = function() return true end
	strip.Tabs = {}
	strip._Active = nil
	strip.GetActiveTab = function(me) return me._Active end
	strip.tabScroller = strip

	local function selectTab(btn, silent)
		strip._Active = btn
		if not silent and onSelect then
			onSelect(btn.RelapseIndex, btn)
		end
	end

	for i, label in ipairs(labels) do
		local btn = vgui.Create("DButton", strip)
		btn:SetText(label)
		btn:SetFont("Relapse20")
		btn:SetTextColor(RelapseUI.Col.Muted)
		btn:SetPaintBackground(false)
		btn.RelapseIndex = i
		btn.GetTabHeight = function()
			return RelapseUI.M().tabs
		end
		btn.GetPropertySheet = function()
			return strip
		end
		btn.IsActive = function(me)
			return strip._Active == me
		end
		btn.Paint = RelapseUI.PaintTab
		btn.ApplySchemeSettings = function(me)
			RelapseUI.SizeTabButton(me)
		end
		btn.DoClick = function(me)
			selectTab(me)
		end
		RelapseUI.SizeTabButton(btn)
		strip.Tabs[i] = btn
	end

	strip.RelapseLayout = function(me)
		local x = 0
		local h = RelapseUI.M().tabs
		for _, btn in ipairs(me.Tabs) do
			RelapseUI.SizeTabButton(btn)
			btn:SetPos(x, 0)
			btn:SetTall(h)
			x = x + btn:GetWide()
		end
		me:SetSize(x, h)
	end
	strip.RelapseLayout(strip)
	RelapseUI.BindTabIndicator(strip)

	local start = strip.Tabs[defaultIndex or 1]
	if IsValid(start) then
		selectTab(start, true)
	end

	return strip
end

function RelapseUI.FinishShopFrame(frame, propertysheet)
	RelapseUI.WarmPropertySheet(propertysheet)
	frame:Center()
	RelapseUI.ShowShopFrame(frame)
	return frame
end

function RelapseUI.PaintMenuRow(self, w, h)
	local text = self.GetText and self:GetText() or ""
	local shadow = RelapseUI.Shadow
	DisableClipping(true)
	if text ~= "" then
		RelapseUI.HudText(text, self:GetFont() or "Relapse25", w * 0.5, h * 0.5, RelapseUI.Col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)
	end
	if self.RelapseRule then
		local thick = math.max(1, RelapseUI.sPx(1))
		local col = RelapseUI.Col.Muted
		surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
		surface.DrawRect(0, h, w, thick)
	end
	DisableClipping(false)
	return true
end

-- ESC pause: Relapse30. 30px (Grid15(2)) between ink, no rules.
-- Relapse30 cell sits ~6px above caps and ~6px under the baseline.
function RelapseUI.PauseRowMetrics(font)
	font = font or "Relapse30"
	surface.SetFont(font)
	local _, cellH = surface.GetTextSize("Ay")
	if not cellH or cellH < 1 then
		cellH = RelapseUI.sPx(30)
	end
	local capNudge = RelapseUI.sPx(6)
	local botNudge = RelapseUI.sPx(6)
	local inkH = math.max(1, cellH - capNudge - botNudge)
	local gap = RelapseUI.Grid15(2)
	return {
		cellH = cellH,
		gap = gap,
		inkH = inkH,
		rowH = inkH + gap,
		textY = -capNudge
	}
end

function RelapseUI.PaintPauseRow(self, w, h)
	local text = self.GetText and self:GetText() or ""
	local c = RelapseUI.Col
	local font = self:GetFont() or "Relapse30"
	local col = c.Muted
	if self.Hovered or self.RelapsePrimary then
		col = c.Text
	end
	if text ~= "" then
		local met = RelapseUI.PauseRowMetrics(font)
		DisableClipping(true)
		RelapseUI.HudText(text, font, 0, met.textY, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, RelapseUI.Shadow)
		DisableClipping(false)
	end
	return true
end

function RelapseUI.PaintMenuClose(self, w, h)
	local col = RelapseUI.Col.Text
	local thick = math.max(1, RelapseUI.sPx(1))
	local span = RelapseUI.Grid15(2)
	local x = math.floor((w - span) * 0.5)
	local y = math.floor((h - span) * 0.5)
	RelapseUI.FillQuad(
		x + thick, y,
		x + span, y + span - thick,
		x + span - thick, y + span,
		x, y + thick,
		col
	)
	RelapseUI.FillQuad(
		x + span - thick, y,
		x + span, y + thick,
		x + thick, y + span,
		x, y + span - thick,
		col
	)
	return true
end

function RelapseUI.PaintMenuScrim(self, w, h)
	local c = RelapseUI.Col.Scrim
	surface.SetDrawColor(c.r, c.g, c.b, c.a or 100)
	local x, y, hw, hh, cover = MenuScrimHole(self, w, h)
	if not x or cover >= 0.995 then
		surface.DrawRect(0, 0, w, h)
		return true
	end
	DrawDimExcept(w, h, x, y, hw, hh)
	if cover > 0 then
		surface.SetDrawColor(c.r, c.g, c.b, math.floor((c.a or 100) * cover + 0.5))
		FillRoundRect(x, y, hw, hh, RelapseUI.RadPx("Window"))
	end
	return true
end

function RelapseUI.BuildMenuFrame()
	RelapseUI.CreateFonts()
	local frame = vgui.Create("DFrame")
	frame:SetSize(ScrW(), ScrH())
	frame:SetPos(0, 0)
	frame:SetDeleteOnClose(true)
	frame:SetKeyboardInputEnabled(false)
	frame:SetTitle("")
	frame:SetDraggable(false)
	frame:SetSizable(false)
	frame:DockPadding(0, 0, 0, 0)
	frame.Paint = RelapseUI.PaintBlank
	RelapseUI.HideChrome(frame)
	frame.OnMousePressed = function(me)
		me:Close()
	end
	frame.OnKeyCodePressed = function(me, key)
		if key == KEY_ESCAPE then
			GAMEMODE:CloseHelpMenu(true)
		end
	end
	frame.Close = function(me, instant)
		RelapseUI.ReleaseMenuScrim(me, instant)
		RelapseUI.FadeClose(me, instant)
	end
	return frame
end

function RelapseUI.MakeMenuButton(parent, text, onClick)
	local btn = vgui.Create("DButton", parent)
	btn:SetText(text)
	btn:SetFont("Relapse25")
	btn:SetTextColor(Color(0, 0, 0, 0))
	btn:SetPaintBackground(false)
	btn:SetTall(RelapseUI.Grid15(4))
	btn.Paint = RelapseUI.PaintMenuRow
	btn.DoClick = onClick
	return btn
end

function RelapseUI.BuildPauseFrame()
	RelapseUI.CreateFonts()
	local frame = vgui.Create("DFrame")
	frame:SetSize(ScrW(), ScrH())
	frame:SetPos(0, 0)
	frame:SetDeleteOnClose(true)
	frame:SetKeyboardInputEnabled(false)
	frame:SetTitle("")
	frame:SetDraggable(false)
	frame:SetSizable(false)
	frame:DockPadding(0, 0, 0, 0)
	frame.Paint = RelapseUI.PaintBlank
	RelapseUI.HideChrome(frame)
	frame.OnMousePressed = function()
		if GAMEMODE and GAMEMODE.ClosePauseMenu then
			GAMEMODE:ClosePauseMenu()
		end
	end
	frame.Close = function(me, instant)
		RelapseUI.ReleaseMenuScrim(me, instant)
		RelapseUI.FadeClose(me, instant)
	end
	return frame
end

function RelapseUI.MakePauseButton(parent, text, onClick)
	local btn = vgui.Create("DButton", parent)
	btn:SetText(text)
	btn:SetFont("Relapse30")
	btn:SetTextColor(Color(0, 0, 0, 0))
	btn:SetPaintBackground(false)
	btn:SetCursor("hand")
	btn:SetTall(RelapseUI.PauseRowMetrics("Relapse30").rowH)
	btn.Paint = RelapseUI.PaintPauseRow
	btn.DoClick = onClick
	return btn
end

function RelapseUI.MakeMenuClose(parent, onClick)
	local close = vgui.Create("DButton", parent)
	local s = RelapseUI.Grid15(3)
	close:SetText("")
	close:SetTextColor(Color(0, 0, 0, 0))
	close:SetPaintBackground(false)
	close:SetKeyboardInputEnabled(false)
	close:SetSize(s, s)
	close.Paint = RelapseUI.PaintMenuClose
	close.DoClick = onClick
	return close
end

function RelapseUI.PaintOptionsCheck(self, w, h)
	local cv = GetConVar(self.RelapseCvar)
	local on = cv and cv:GetBool()
	local cell = RelapseUI.sPx(20)
	local capNudge = RelapseUI.sPx(5)
	local s = math.max(1, math.floor(RelapseUI.ManropeBaseline(0, cell) - capNudge + 0.5))
	local y = capNudge
	local c = RelapseUI.Col
	local cx, cy = s * 0.5, y + s * 0.5
	local rad = s * 0.5
	local fill = c.Card
	if on then
		fill = c.Text
	elseif self.Hovered then
		fill = c.CardHover
	end
	RelapseUI.FillCircle(cx, cy, rad, fill)
	draw.SimpleText(self.RelapseLabel or "", "Relapse20", s + RelapseUI.Grid15(2), 0, c.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	return true
end

function RelapseUI.PaintSliderTrack(self, w, h)
	local th = math.max(2, RelapseUI.sPx(2))
	local y = math.floor((h - th) * 0.5)
	RelapseUI.RoundFill(RelapseUI.RadPx("Bar"), 0, y, w, th, RelapseUI.Col.Track)
	return true
end

function RelapseUI.PaintSliderKnob(self, w, h)
	local c = RelapseUI.Col
	local s = math.min(w, h)
	local x = math.floor((w - s) * 0.5)
	local y = math.floor((h - s) * 0.5)
	RelapseUI.RoundFill(RelapseUI.RadPx("Bar"), x, y, s, s, (self.Hovered or self:IsDown()) and c.Text or c.Muted)
	return true
end

function RelapseUI.MakeOptionsScroll(sheet)
	local scroll = vgui.Create("DScrollPanel", sheet)
	scroll.Paint = function() return true end
	RelapseUI.StyleScroll(scroll)
	-- Tab rule → first Relapse20 cap = 3 cells. tabGap is 2; cell sits 5px above caps.
	local top = RelapseUI.Grid15(3) - RelapseUI.M().tabGap - RelapseUI.sPx(5)
	local canvas = scroll:GetCanvas()
	if IsValid(canvas) then
		canvas:DockPadding(0, top, RelapseUI.Grid5(23), RelapseUI.Grid15())
	end
	local bar = scroll:GetVBar()
	if IsValid(bar) then
		bar:DockMargin(0, top, 0, RelapseUI.Grid15())
	end
	return scroll
end

function RelapseUI.OptionsCheckGap()
	-- Check cap sits 5px into the row; 2 cells minus that = 30 to the capital.
	return RelapseUI.Grid15(2) - RelapseUI.sPx(5)
end

function RelapseUI.OptionsCheck(parent, text, cvar)
	local row = vgui.Create("DButton", parent)
	row:SetText("")
	row:SetTall(RelapseUI.sPx(20))
	row:Dock(TOP)
	row:DockMargin(0, 0, 0, RelapseUI.OptionsCheckGap())
	row:SetPaintBackground(false)
	row.RelapseCvar = cvar
	row.RelapseLabel = text
	row.Paint = RelapseUI.PaintOptionsCheck
	row.DoClick = function(me)
		local cv = GetConVar(me.RelapseCvar)
		if not cv then return end
		cv:SetBool(not cv:GetBool())
	end
	return row
end

function RelapseUI.OptionsCaption(parent, text)
	local lab = EasyLabel(parent, text, "Relapse20", RelapseUI.Col.Muted)
	lab:SetContentAlignment(7)
	lab:Dock(TOP)
	lab:DockMargin(0, 0, 0, RelapseUI.Grid15(2))
	lab:SetTall(RelapseUI.sPx(20))
	return lab
end

function RelapseUI.CreditsTitleGap()
	return RelapseUI.sPx(75)
end

-- Relapse30 optical bottom of the window title → Relapse20 capital of the first section.
function RelapseUI.PadCreditsScroll(scroll, frame, L)
	local title = frame and frame.RelapseTitle
	if not (IsValid(scroll) and IsValid(title) and L) then
		return
	end
	local _, titleY = title:GetPos()
	local firstCapY = titleY + title:GetTall() - RelapseUI.sPx(6) + RelapseUI.CreditsTitleGap()
	local top = math.max(0, firstCapY - L.headerh - RelapseUI.sPx(5))
	local canvas = scroll:GetCanvas()
	if IsValid(canvas) then
		canvas:DockPadding(0, top, RelapseUI.Grid5(23), RelapseUI.Grid15())
	end
	local bar = scroll:GetVBar()
	if IsValid(bar) then
		bar:DockMargin(0, top, 0, RelapseUI.Grid15())
	end
end

function RelapseUI.CreditsSection(parent, text, first)
	local lab = RelapseUI.OptionsCaption(parent, text)
	local top = first and 0 or RelapseUI.Grid15(3)
	lab:DockMargin(0, top, 0, RelapseUI.Grid15(2))
	return lab
end

function RelapseUI.PaintCreditsRow(self, w, h)
	local c = RelapseUI.Col
	local name = self.RelapseName or ""
	draw.SimpleText(name, "Relapse20", 0, 0, c.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local role = self.RelapseRole or ""
	if role ~= "" then
		surface.SetFont("Relapse20")
		local nw = surface.GetTextSize(name)
		draw.SimpleText(role, "Relapse20", nw + RelapseUI.Grid15(2), 0, c.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	return true
end

function RelapseUI.CreditsRow(parent, name, role)
	local row = vgui.Create("DPanel", parent)
	row:SetTall(RelapseUI.sPx(20))
	row:Dock(TOP)
	row:DockMargin(0, 0, 0, RelapseUI.OptionsCheckGap())
	row:SetPaintBackground(false)
	row.RelapseName = name or ""
	row.RelapseRole = role or ""
	row.Paint = RelapseUI.PaintCreditsRow
	return row
end

function RelapseUI.OptionsSlider(parent, text, cvar, min, max, decimals)
	local wrap = vgui.Create("DPanel", parent)
	wrap:SetTall(RelapseUI.Grid15(5))
	wrap:Dock(TOP)
	wrap:DockMargin(0, 0, 0, RelapseUI.Grid15())
	wrap:SetPaintBackground(false)
	wrap.Paint = function() return true end

	local slider = vgui.Create("DNumSlider", wrap)
	slider:Dock(FILL)
	slider:SetText(text)
	slider:SetMinMax(min, max)
	slider:SetDecimals(decimals or 0)
	slider:SetConVar(cvar)
	slider:SetDark(false)
	if IsValid(slider.Label) then
		slider.Label:SetFont("Relapse20")
		slider.Label:SetTextColor(RelapseUI.Col.Text)
	end
	if IsValid(slider.TextArea) then
		slider.TextArea:SetFont("Relapse20")
		slider.TextArea:SetTextColor(RelapseUI.Col.Muted)
		slider.TextArea:SetDrawBackground(false)
		slider.TextArea.Paint = function(me, w, h)
			draw.SimpleText(me:GetValue(), "Relapse20", w, h * 0.5, RelapseUI.Col.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			return true
		end
	end
	local bar = slider.Slider
	if IsValid(bar) then
		bar.Paint = RelapseUI.PaintSliderTrack
		if IsValid(bar.Knob) then
			local s = RelapseUI.Grid15()
			bar.Knob:SetSize(s, s)
			bar.Knob.Paint = RelapseUI.PaintSliderKnob
		end
	end
	return slider
end

function RelapseUI.PaintComboMenu(self, w, h)
	RelapseUI.RoundFill(RelapseUI.RadPx("Card"), 0, 0, w, h, RelapseUI.Col.Bg)
	return true
end

function RelapseUI.PaintComboOption(self, w, h)
	local c = RelapseUI.Col
	local hot = self.Hovered or self.Highlight
	local on = self.RelapseSelected
	if hot or on then
		RelapseUI.RoundFill(RelapseUI.RadPx("Bar"), 0, 0, w, h, c.Hover)
	end
	local col = (hot or on) and c.Text or c.Muted
	draw.SimpleText(self:GetText() or "", "Relapse20", RelapseUI.Grid15(), h * 0.5, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	return true
end

function RelapseUI.PaintComboCaret(x, y, open, col)
	local s = RelapseUI.sPx(5)
	if open then
		RelapseUI.FillQuad(x - s, y + s * 0.4, x + s, y + s * 0.4, x, y - s * 0.5, x, y - s * 0.5, col)
	else
		RelapseUI.FillQuad(x - s, y - s * 0.4, x + s, y - s * 0.4, x, y + s * 0.5, x, y + s * 0.5, col)
	end
end

function RelapseUI.StyleComboMenu(combo)
	local menu = combo.Menu
	if not IsValid(menu) then return end

	local pad = RelapseUI.Grid5()
	local rowH = RelapseUI.Grid15(3)
	local selected = combo:GetText()

	menu:SetDrawBorder(false)
	menu:SetPaintBackground(false)
	menu:SetPadding(0)
	menu.Paint = RelapseUI.PaintComboMenu

	RelapseUI.StyleScroll(menu)
	local canvas = menu.GetCanvas and menu:GetCanvas()
	if IsValid(canvas) then
		canvas:SetPaintBackground(false)
		canvas.Paint = function() return true end
	end

	local kids = IsValid(canvas) and canvas:GetChildren() or menu:GetChildren()
	for _, opt in ipairs(kids) do
		if not isfunction(opt.SetMenu) then continue end
		opt:SetFont("Relapse20")
		opt:SetTextColor(Color(0, 0, 0, 0))
		opt:SetTextInset(RelapseUI.Grid15(), 0)
		opt:SetContentAlignment(4)
		opt:SetPaintBackground(false)
		opt.RelapseSelected = opt:GetText() == selected
		opt.Paint = RelapseUI.PaintComboOption
		opt.PerformLayout = function(me)
			me:SetTall(rowH)
		end
	end

	menu.PerformLayout = function(me)
		local minW = math.max(me:GetMinimumWidth() or 0, combo:GetWide())
		local host = me:GetCanvas()
		if not IsValid(host) then return end

		local y = pad
		for _, pnl in ipairs(host:GetChildren()) do
			pnl:InvalidateLayout(true)
			pnl:SetWide(minW - pad * 2)
			pnl:SetPos(pad, y)
			y = y + pnl:GetTall()
		end
		y = y + pad

		local maxH = me:GetMaxHeight() or ScrH() * 0.9
		local tall = math.min(y, maxH)
		me:SetSize(minW, tall)
		host:SetPos(0, 0)
		host:SetSize(minW, y)

		local bar = me.GetVBar and me:GetVBar()
		if IsValid(bar) then
			if y <= maxH then
				bar:SetVisible(false)
				bar:SetWide(0)
			else
				bar:SetVisible(true)
				RelapseUI.StyleScroll(me)
				bar:SetUp(tall, y)
			end
		end
	end

	menu:InvalidateLayout(true)

	local gap = RelapseUI.Grid5()
	local x, y = combo:LocalToScreen(0, combo:GetTall() + gap)
	local mw, mh = menu:GetWide(), menu:GetTall()
	if y + mh > ScrH() then
		x, y = combo:LocalToScreen(0, -mh - gap)
	end
	if x + mw > ScrW() then x = ScrW() - mw end
	if x < 1 then x = 1 end
	if y < 1 then y = 1 end

	local parent = menu:GetParent()
	if IsValid(parent) and parent.IsModal and parent:IsModal() then
		x, y = parent:ScreenToLocal(x, y)
	end
	menu:SetPos(x, y)
end

function RelapseUI.OptionsCombo(parent, caption, choices, current, onSelect)
	RelapseUI.OptionsCaption(parent, caption)

	local row = vgui.Create("DPanel", parent)
	row:SetTall(RelapseUI.Grid15(3))
	row:Dock(TOP)
	row:DockMargin(0, 0, 0, RelapseUI.Grid15())
	row:SetPaintBackground(false)
	row.Paint = function() return true end

	local combo = vgui.Create("DComboBox", row)
	combo:SetWide(RelapseUI.Grid15(20))
	combo:Dock(LEFT)
	combo:SetFont("Relapse20")
	combo:SetTextColor(Color(0, 0, 0, 0))
	combo:SetPaintBackground(false)
	combo:SetSortItems(false)
	if IsValid(combo.DropButton) then
		combo.DropButton:SetVisible(false)
		combo.DropButton.Paint = function() return true end
	end
	for _, choice in ipairs(choices) do
		combo:AddChoice(choice[1], choice[2], current == choice[2])
	end
	combo.Paint = function(me, w, h)
		RelapseUI.PaintCard(me, w, h, me:IsMenuOpen(), false, false)
		draw.SimpleText(me:GetText() or "", "Relapse20", RelapseUI.Grid15(), h * 0.5, RelapseUI.Col.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		RelapseUI.PaintComboCaret(w - RelapseUI.Grid15() - RelapseUI.sPx(4), h * 0.5, me:IsMenuOpen(), RelapseUI.Col.Muted)
		return true
	end
	combo.OnMenuOpened = function(me)
		RelapseUI.StyleComboMenu(me)
	end
	combo.OnSelect = function(me, index, value, data)
		if onSelect then onSelect(data, value) end
	end
	return combo
end

function RelapseUI.OptionsColor(parent, caption, cr, cg, cb, ca)
	RelapseUI.OptionsCaption(parent, caption)
	local mix = vgui.Create("DColorMixer", parent)
	mix:SetTall(RelapseUI.Grid15(8))
	mix:Dock(TOP)
	mix:DockMargin(0, 0, 0, RelapseUI.Grid15())
	mix:SetPalette(false)
	mix:SetAlphaBar(ca ~= nil)
	mix:SetConVarR(cr)
	mix:SetConVarG(cg)
	mix:SetConVarB(cb)
	if ca then
		mix:SetConVarA(ca)
	end
	return mix
end


