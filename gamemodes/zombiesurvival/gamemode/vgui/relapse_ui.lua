RelapseUI = RelapseUI or {}

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

function RelapseUI.TryAttachCardIcon(itempan, mdlframe, tab, missing_skill)
	if not IsValid(mdlframe) or not tab or tab.Category ~= ITEMCAT_GUNS then
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

	for i, sb in ipairs(bars) do
		if not IsValid(sb) then continue end
		local y = firstY + (i - 1) * (barH + barGap)
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

function RelapseUI.ShopPreviewBoneMerge(sweptable)
	if not sweptable then return false end
	if sweptable.RelapsePreviewBoneMerge then return true end

	local gm = GAMEMODE or GM
	local class = sweptable.ClassName or sweptable.Class or sweptable.SWEP
	local def = gm and class and gm.RelapseWeapons and gm.RelapseWeapons[class]
	return def and def.PreviewBoneMerge or false
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
		return
	end

	local pos = ent:GetPos()
	local ang = ent:GetAngles()
	if istable(extras) then
		for i = 1, #extras do
			local part = extras[i]
			if IsValid(part) then
				part:SetPos(pos)
				part:SetAngles(ang)
				part:DrawModel()
			end
		end
	end
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

local function meshAABB(model, pos, ang)
	if not isstring(model) or model == "" or not util.GetModelMeshes then
		return nil
	end

	local meshes = util.GetModelMeshes(model, 0)
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

	local rootBone = "tag_pistol_offset"
	if not ent:LookupBone(rootBone) then
		rootBone = "j_gun"
	end
	local mins, maxs = meshAABB(ent:GetModel(), bonePosAng(ent, rootBone))

	local extras = pnl.RelapsePreviewEnts
	if istable(extras) then
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

		local dist = math.Clamp(span * 1.32, 20, 48)
		pnl.RelapsePreviewCenter = Vector(center)
		pnl:SetLookAt(vector_origin)
		pnl:SetCamPos(Vector(dist * 0.82, dist * 0.52, dist * 0.34))
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
		pnl:SetFOV(43)
		RelapseUI.OrbitShopPreview(pnl, ent)
		return
	end

	local mins, maxs = ent:GetRenderBounds()
	pnl:SetCamPos(mins:Distance(maxs) * Vector(0.75, 0.75, 0.5))
	pnl:SetLookAt((mins + maxs) / 2)
end

function RelapseUI.SetShopPreview(pnl, sweptable, viewer)
	if IsValid(viewer) and IsValid(viewer.m_ModelIcon) then
		viewer.m_ModelIcon:SetVisible(false)
	end
	if not IsValid(pnl) then return end

	pnl:SetVisible(true)
	pnl.RelapseShopPreview = true
	pnl.RelapsePreviewFramed = false
	pnl.RelapsePreviewCenter = nil
	RelapseUI.ClearShopPreviewParts(pnl)

	local mdl = RelapseUI.ShopPreviewModel(sweptable)
	if not mdl then
		pnl:SetModel("")
		return
	end

	pnl.RelapsePreviewBaseAng = sweptable.RelapsePreviewAngle or Angle(8, 90, 0)
	pnl.RelapsePreviewLocalAng = RelapseUI.ShopPreviewLocalAng(sweptable)
	pnl:SetModel(mdl)
	pnl:SetAnimated(false)
	RelapseUI.AttachShopPreviewParts(pnl, sweptable)
	RelapseUI.FrameModelPanel(pnl)
end

function RelapseUI.LayoutViewerModel(viewer)
	if not IsValid(viewer) then return end
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
	local rev = 10
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

function RelapseUI.RoundRing(r, x, y, w, h, col, inner, thick)
	thick = math.max(1, math.floor((thick or RelapseUI.sPx(2)) + 0.5))
	RelapseUI.RoundFill(r, x, y, w, h, col)
	if w <= thick * 2 or h <= thick * 2 then return end
	RelapseUI.RoundFill(math.max(0, r - thick), x + thick, y + thick, w - 2 * thick, h - 2 * thick, inner)
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
	RelapseUI.RoundFill(RelapseUI.RadPx("Window"), 0, 0, w, h, RelapseUI.Col.Bg)
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
	if selected then
		RelapseUI.RoundRing(r, 0, 0, w, h, c.CardOn, fill)
	else
		RelapseUI.RoundFill(r, 0, 0, w, h, fill)
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

-- Flora --flora-ease-out / energetic settle: cubic-bezier(0.33, 1, 0.2, 1)
-- --flora-duration-3 = 3 × 150ms
local TAB_EASE_X1, TAB_EASE_X2 = 0.33, 0.2
local TAB_ANIM = 0.45
local TabInk = Color(255, 255, 255, 255)

local function Bez(t, a, b)
	local u = 1 - t
	return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
end

local function BezD(t, a, b)
	local u = 1 - t
	return 3 * u * u * a + 6 * u * t * (b - a) + 3 * t * t * (1 - b)
end

function RelapseUI.EaseOut(t)
	t = math.Clamp(t, 0, 1)
	if t == 0 or t == 1 then return t end
	local s = t
	for _ = 1, 8 do
		local x = Bez(s, TAB_EASE_X1, TAB_EASE_X2) - t
		if math.abs(x) < 1e-6 then break end
		local d = BezD(s, TAB_EASE_X1, TAB_EASE_X2)
		if math.abs(d) < 1e-6 then break end
		s = math.Clamp(s - x / d, 0, 1)
	end
	local u = 1 - s
	return 1 - u * u * u
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

function RelapseUI.EachShadow(fn, n)
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

-- Scratch buffers only. Values are always overwritten from RelapseUI.Col.
local colHealthA = Color(0, 0, 0, 255)
local colUrgent = Color(0, 0, 0, 255)

function RelapseUI.LerpCol(a, b, t, out)
	t = math.Clamp(t or 0, 0, 1)
	out = out or Color(0, 0, 0, 255)
	out.r = a.r + (b.r - a.r) * t
	out.g = a.g + (b.g - a.g) * t
	out.b = a.b + (b.b - a.b) * t
	out.a = (a.a or 255) + ((b.a or 255) - (a.a or 255)) * t
	return out
end

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
	local pan
	local tab = sheet.GetActiveTab and sheet:GetActiveTab()
	if IsValid(tab) and tab.GetPanel then
		pan = tab:GetPanel()
	end
	if not IsValid(pan) then
		for _, item in ipairs(sheet.Items or {}) do
			if IsValid(item.Panel) then
				pan = item.Panel
				break
			end
		end
	end
	if not IsValid(pan) then return end
	local sx, sy = pan:LocalToScreen(0, 0)
	local _, y = frame:ScreenToLocal(sx, sy)
	viewer:SetPos(frame:GetWide() - RelapseUI.FooterSideInset() - viewer:GetWide(), y)
	local h = pan:GetTall()
	if h > 0 then
		viewer:SetTall(h)
	end
	if IsValid(viewer.m_Title) then
		viewer.m_Title:InvalidateLayout(true)
	end
	RelapseUI.LayoutViewerAmmo(viewer)
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

function RelapseUI.FrameSize(maxCols, maxRows)
	local m = RelapseUI.M()
	local cols = math.min(math.floor((ScrW() - 2 * m.pad) / m.step), maxCols)
	local rows = math.min(math.floor((ScrH() - 2 * m.pad) / m.step), maxRows)
	cols = math.max(40, cols)
	rows = math.max(32, rows)
	return cols * m.step, rows * m.step, m
end
