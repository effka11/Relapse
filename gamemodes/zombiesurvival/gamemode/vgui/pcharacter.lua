local pCharacter

local function State()
	local gm = GAMEMODE
	return gm and gm.RelapseScarState or {Picks = 0, Offer = {}, Ranks = {}, Counts = {}, Meters = {}}
end

local function Phrase(key, fallback)
	return RelapseUI.T(key, fallback)
end

local function PhraseF(key, ...)
	return RelapseUI.TF(key, ...)
end

local function CutChars(s, n)
	if n <= 0 then return "" end
	if utf8 and utf8.len and utf8.offset then
		local len = utf8.len(s)
		if not len or len <= n then return s end
		local pos = utf8.offset(s, n + 1)
		if not pos then return s end
		return string.sub(s, 1, pos - 1)
	end
	if #s <= n then return s end
	return string.sub(s, 1, n)
end

local function CommaNum(n)
	if string.Comma then
		return string.Comma(n)
	end
	return tostring(n)
end

local function Ellipsize(text, font, maxW)
	text = tostring(text or "")
	surface.SetFont(font)
	if surface.GetTextSize(text) <= maxW then
		return text
	end
	local ell = "…"
	local lo, hi = 1, (utf8 and utf8.len and utf8.len(text)) or #text
	local best = ell
	while lo <= hi do
		local mid = math.floor((lo + hi) * 0.5)
		local trial = CutChars(text, mid) .. ell
		if surface.GetTextSize(trial) <= maxW then
			best = trial
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	return best
end

local function DrawWrapped(text, font, x, y, maxW, col, maxLines)
	text = tostring(text or "")
	if text == "" then return y end
	local lines = RelapseUI.WrapLines(text, font, maxW)
	surface.SetFont(font)
	local _, lh = surface.GetTextSize("Ay")
	lh = math.max(1, lh)
	local n = #lines
	if maxLines then
		n = math.min(n, maxLines)
	end
	for i = 1, n do
		local line = lines[i]
		if i == n and maxLines and #lines > maxLines then
			line = Ellipsize(line, font, maxW)
		end
		draw.SimpleText(line, font, x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + lh
	end
	return y
end

local function OfferHas(id)
	return GAMEMODE:RelapseScarOfferHas(State().Offer, id)
end

local function RankOf(id)
	return GAMEMODE:GetRelapseScarRank(id)
end

local function ScarName(id)
	return Phrase("scar_" .. id, id)
end

local function ScarDesc(id)
	return Phrase("scar_" .. id .. "_desc", "")
end

local function ScarEffect(id, rank)
	local scar = GAMEMODE:GetRelapseScar(id)
	if not scar then return "" end
	local key = "scar_" .. id .. "_effect"
	if scar.K1 then
		local n = math.max(1, tonumber(rank) or 1)
		return PhraseF(key, GAMEMODE:RelapseScarK(n, scar.K1, scar.KInf))
	end
	return Phrase(key, "")
end

local function RankCaption(id, lottery)
	local rank = RankOf(id)
	if lottery then
		if rank > 0 then
			return PhraseF("char_upgrade", GAMEMODE:RelapseScarRoman(rank), GAMEMODE:RelapseScarRoman(rank + 1))
		end
		return GAMEMODE:RelapseScarRoman(1)
	end
	if rank > 0 then
		return GAMEMODE:RelapseScarRoman(rank)
	end
	return Phrase("char_locked", "—")
end

local function SyncPreview(pnl, pl)
	if not IsValid(pnl) or not IsValid(pl) then return end
	local mdl = pl:GetModel() or ""
	if mdl == "" then return end
	if pnl.RelapseLastMdl ~= mdl then
		RelapseUI.SetPlayerPreview(pnl, mdl)
		pnl.RelapseLastMdl = mdl
	end
	local ent = pnl.Entity
	if not IsValid(ent) then return end
	ent:SetSkin(pl:GetSkin() or 0)
	local n = pl.GetNumBodyGroups and pl:GetNumBodyGroups() or 0
	for i = 0, n - 1 do
		ent:SetBodygroup(i, pl:GetBodygroup(i))
	end
	if pl.GetPlayerColor then
		local col = pl:GetPlayerColor()
		ent.GetPlayerColor = function()
			return col
		end
	end
end

local function SelectScar(frame, id, lottery, silent)
	if not IsValid(frame) or not id then return end
	frame.SelectedId = id
	frame.SelectedLottery = lottery and true or false
	for _, btn in ipairs(frame.InvCards or {}) do
		if IsValid(btn) then
			btn.On = btn.ScarId == id and not lottery
		end
	end
	for _, btn in ipairs(frame.LotCards or {}) do
		if IsValid(btn) then
			btn.On = btn.ScarId == id and lottery
		end
	end
	if IsValid(frame.Desc) then
		frame.Desc:InvalidateLayout()
	end
	if GAMEMODE.LayoutCharacterFooter then
		GAMEMODE:LayoutCharacterFooter(frame)
	end
	if not silent then
		surface.PlaySound("buttons/button14.wav")
	end
end

local CARD = {}

function CARD:Init()
	self:SetText("")
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self.NameLabel = EasyLabel(self, "", "Relapse15", RelapseUI.Col.Text)
	self.NameLabel:SetContentAlignment(5)
	self.RankLabel = EasyLabel(self, "", "Relapse13", RelapseUI.Col.Muted)
	self.RankLabel:SetContentAlignment(5)
	self.IconFrame = vgui.Create("DPanel", self)
	self.IconFrame:SetPaintBackground(false)
	self.IconFrame:SetMouseInputEnabled(false)
end

function CARD:SetCardSize(w, h)
	self.CardW = w
	self.CardH = h
	self:SetSize(w, h)
end

function CARD:ApplySchemeSettings()
end

function CARD:PerformLayout(w, h)
	w = self.CardW or w or self:GetWide()
	h = self.CardH or h or self:GetTall()
	self:SetSize(w, h)
	local pad = RelapseUI.M().cardPad
	local rankH = IsValid(self.RankLabel) and self.RankLabel:GetTall() or RelapseUI.sPx(13)
	local nameH = IsValid(self.NameLabel) and self.NameLabel:GetTall() or RelapseUI.sPx(15)
	local iconH = math.max(RelapseUI.Grid15(3), h - pad * 2 - nameH - rankH - RelapseUI.Grid5(2))
	if IsValid(self.IconFrame) then
		self.IconFrame:SetSize(w - pad * 2, iconH)
		self.IconFrame:SetPos(pad, pad)
		if IsValid(self.Icon) then
			RelapseUI.FitIcon(self.Icon, self.IconFrame:GetWide(), self.IconFrame:GetTall())
		end
	end
	if IsValid(self.NameLabel) then
		self.NameLabel:SetWide(w - pad * 2)
		self.NameLabel:SetPos(pad, h - pad - rankH - nameH)
	end
	if IsValid(self.RankLabel) then
		self.RankLabel:SetWide(w - pad * 2)
		self.RankLabel:SetPos(pad, h - pad - rankH)
	end
end

function CARD:SetScar(id, lottery)
	self.ScarId = id
	self.Lottery = lottery and true or false
	local scar = GAMEMODE:GetRelapseScar(id)
	if not scar then return end

	local locked = RankOf(id) <= 0 and not lottery
	self.Locked = locked

	local font = lottery and "Relapse20" or "Relapse15"
	self.NameLabel:SetFont(font)
	self.NameLabel:SetText(Ellipsize(ScarName(id), font, math.max(8, (self.CardW or self:GetWide()) - RelapseUI.M().cardPad * 2)))
	self.NameLabel:SizeToContents()
	self.NameLabel:SetTextColor(locked and RelapseUI.Col.Muted or RelapseUI.Col.Text)

	self.RankLabel:SetText(RankCaption(id, lottery))
	self.RankLabel:SizeToContents()
	self.RankLabel:SetTextColor(locked and RelapseUI.Col.Muted or RelapseUI.Col.Accent)

	for _, ch in ipairs(self.IconFrame:GetChildren()) do
		if IsValid(ch) then
			ch:Remove()
		end
	end
	if scar.Icon then
		local img = RelapseUI.MakeSilhouetteIcon(self.IconFrame, scar.Icon)
		if locked then
			img:SetImageColor(RelapseUI.Col.Muted)
			img:SetAlpha(80)
		end
		self.Icon = img
	end
	self:InvalidateLayout(true)
end

function CARD:Paint(w, h)
	RelapseUI.PaintCard(self, w, h, self.On, self.Locked, false)
	if self.Lottery then
		local r = RelapseUI.sPx(6)
		surface.SetDrawColor(RelapseUI.Col.Accent)
		surface.DrawRect(w - RelapseUI.Grid15() - r, RelapseUI.Grid15() - r * 0.5, r, r)
	end
	return true
end

function CARD:DoClick()
	local frame = pCharacter
	if not IsValid(frame) then return end
	SelectScar(frame, self.ScarId, self.Lottery)
end

vgui.Register("RelapseScarCard", CARD, "DButton")

local CHAR_PAGE_GRID = 1
local CHAR_PAGE_SCARS = 2
local LayoutCharacter

local function CharPageTitle(idx)
	if idx == CHAR_PAGE_SCARS then
		return Phrase("char_page_scars", "Scars")
	end
	return Phrase("char_page_grid", "Grid")
end

local matGridBeam = Material("effects/laser1")
local matGridGlow = Material("sprites/glow04_noz")
local GRID_ZOOM_MIN = 2200
local GRID_ZOOM_MAX = 14000
local GRID_ZOOM_START = 5200
local GRID_PAN = 520
local camera_velocity = Vector(0, 0, 0)

local GRID = {}

function GRID:Init()
	self:SetPaintBackground(false)
	self:SetMouseInputEnabled(true)
	self.CamY = 0
	self.CamZ = 0
	self.Zoom = GRID_ZOOM_START
	self.DesiredZoom = GRID_ZOOM_START
	self.FOV = 6
	self.FarZ = 32000
	self.LastPaint = RealTime()
end

function GRID:WorldPos(x, y)
	local u = (GAMEMODE and GAMEMODE.CycleGridUnit) or 20
	return Vector(0, x * u, y * u)
end

function GRID:GridInk(tree)
	local c = RelapseUI.Col
	local hover = self.HoverTree
	if hover and hover ~= tree then
		return Color(c.Muted.r, c.Muted.g, c.Muted.b, 28)
	end
	if hover and hover == tree then
		return c.Text
	end
	return c.Muted
end

function GRID:DoEdgeScroll(dt, w, h)
	if self.Dragging or not self:IsHovered() or not system.HasFocus() then
		camera_velocity = LerpVector(dt * 3, camera_velocity, vector_origin)
		return
	end
	local vx, vy = self:LocalToScreen(0, 0)
	local mx, my = gui.MousePos()
	local edge = math.min(w, h) * 0.06
	local dir = Vector(0, 0, 0)
	if mx <= vx + edge and mx >= vx then
		dir.y = dir.y - 1
	elseif mx >= vx + w - edge and mx <= vx + w then
		dir.y = dir.y + 1
	end
	if my <= vy + edge and my >= vy then
		dir.z = dir.z + 1
	elseif my >= vy + h - edge and my <= vy + h then
		dir.z = dir.z - 1
	end
	dir:Normalize()
	camera_velocity = LerpVector(dt * ((dir.y == 0 and dir.z == 0) and 3 or 1), camera_velocity, dir)
	if camera_velocity.y ~= 0 or camera_velocity.z ~= 0 then
		local step = dt * edge * 14
		self.CamY = math.Clamp(self.CamY + camera_velocity.y * step, -GRID_PAN, GRID_PAN)
		self.CamZ = math.Clamp(self.CamZ + camera_velocity.z * step, -GRID_PAN, GRID_PAN)
	end
end

function GRID:Think()
	if not self.Dragging then return end
	if not input.IsMouseDown(MOUSE_LEFT) and not input.IsMouseDown(MOUSE_MIDDLE) then
		self.Dragging = false
		self:MouseCapture(false)
		return
	end
	local mx, my = gui.MousePos()
	local k = self.Zoom * 0.00016
	self.CamY = math.Clamp(self.DragY - (mx - self.DragMX) * k, -GRID_PAN, GRID_PAN)
	self.CamZ = math.Clamp(self.DragZ + (my - self.DragMY) * k, -GRID_PAN, GRID_PAN)
end

function GRID:OnMousePressed(mc)
	if mc ~= MOUSE_LEFT and mc ~= MOUSE_MIDDLE then return end
	self.Dragging = true
	self.DragMX, self.DragMY = gui.MousePos()
	self.DragY, self.DragZ = self.CamY, self.CamZ
	self:MouseCapture(true)
end

function GRID:OnMouseReleased()
	self.Dragging = false
	self:MouseCapture(false)
end

function GRID:OnMouseWheeled(delta)
	self.DesiredZoom = math.Clamp(self.DesiredZoom - delta * 500, GRID_ZOOM_MIN, GRID_ZOOM_MAX)
	return true
end

function GRID:OnCursorExited()
	if not self.Dragging then
		self.HoverTree = nil
		self.HoverNode = nil
	end
end

function GRID:Paint(w, h)
	local gm = GAMEMODE
	if not gm or not gm.GetCycleGridLayout then
		return true
	end
	local layout = gm:GetCycleGridLayout()
	local realtime = RealTime()
	local dt = math.Clamp(realtime - (self.LastPaint or realtime), 0, 0.1)
	self.LastPaint = realtime
	self:DoEdgeScroll(dt, w, h)
	self.Zoom = math.Approach(self.Zoom, self.DesiredZoom, dt * 13500)

	local campos = Vector(self.Zoom, self.CamY, self.CamZ)
	local lookat = Vector(0, self.CamY, self.CamZ)
	local ang = (lookat - campos):Angle()
	local to_camera = ang:Forward() * -1
	local vx, vy = self:LocalToScreen(0, 0)
	local mx, my = gui.MousePos()
	local aim = util.AimVector(ang, self.FOV, mx - vx, my - vy, w, h)
	local hit = util.IntersectRayWithPlane(campos, aim, lookat, Vector(-1, 0, 0))

	local hoverNode, hoverTree
	local nearest = 160
	if hit then
		if self:WorldPos(layout.hub.x, layout.hub.y):DistToSqr(hit) <= 260 then
			hoverNode = layout.hub
		end
		for _, n in ipairs(layout.nodes) do
			local d = self:WorldPos(n.x, n.y):DistToSqr(hit)
			if d <= nearest then
				nearest = d
				hoverNode = n
				hoverTree = n.tree
			end
		end
	end
	if not hoverTree and self._LabHits then
		local lmx, lmy = self:ScreenToLocal(mx, my)
		for _, labHit in ipairs(self._LabHits) do
			if lmx >= labHit.x1 and lmx <= labHit.x2 and lmy >= labHit.y1 and lmy <= labHit.y2 then
				hoverTree = labHit.tree
				break
			end
		end
	end
	self.HoverNode = hoverNode
	self.HoverTree = hoverTree

	render.SetScissorRect(vx, vy, vx + w, vy + h, true)
	cam.Start3D(campos, ang, self.FOV, vx, vy, w, h, 5, self.FarZ)
	cam.IgnoreZ(true)

	render.SetMaterial(matGridBeam)
	for _, e in ipairs(layout.edges) do
		local a, b = e[1], e[2]
		local tree = b.tree or a.tree
		local col = self:GridInk(tree)
		local pa = self:WorldPos(a.x, a.y) + Vector(-16, 0, 0)
		local pb = self:WorldPos(b.x, b.y) + Vector(-16, 0, 0)
		render.DrawBeam(pa, pb, 3, 0, 1, Color(col.r, col.g, col.b, math.min(col.a or 255, 90)))
		render.DrawBeam(pa, pb, 10, 0, 1, Color(col.r, col.g, col.b, math.min(col.a or 255, 40)))
	end

	render.SetMaterial(matGridGlow)
	render.DrawQuadEasy(self:WorldPos(layout.hub.x, layout.hub.y), to_camera, 32, 32, RelapseUI.Col.Text, realtime * 40)

	for _, n in ipairs(layout.nodes) do
		local col = self:GridInk(n.tree)
		local size = (hoverNode == n) and 22 or 14
		render.DrawQuadEasy(self:WorldPos(n.x, n.y), to_camera, size, size, col, 0)
	end

	local hubScr = self:WorldPos(layout.hub.x, layout.hub.y):ToScreen()
	local labScr = {}
	for _, lab in ipairs(layout.labels) do
		labScr[#labScr + 1] = {
			lab = lab,
			scr = self:WorldPos(lab.x, lab.y):ToScreen()
		}
	end

	cam.IgnoreZ(false)
	cam.End3D()
	render.SetScissorRect(0, 0, 0, 0, false)

	self:DrawGridLabels(w, h, labScr, hubScr)
	return true
end

function GRID:DrawGridLabels(w, h, labScr, hubScr)
	RelapseUI.CreateFonts()
	local font = "Relapse20"
	surface.SetFont(font)
	local pad = RelapseUI.Grid15(2)
	local hx, hy = w * 0.5, h * 0.5
	if hubScr and hubScr.visible ~= false then
		hx, hy = self:ScreenToLocal(hubScr.x, hubScr.y)
	end

	local items = {}
	for _, row in ipairs(labScr) do
		local scr = row.scr
		if scr and scr.visible ~= false then
			local name = RelapseUI.T(row.lab.nameKey, row.lab.treeId)
			local tw, th = surface.GetTextSize(name)
			local x, y = self:ScreenToLocal(scr.x, scr.y)
			local dx, dy = x - hx, y - hy
			local len = math.sqrt(dx * dx + dy * dy)
			if len < 1 then
				dx, dy, len = 0, -1, 1
			end
			local push = RelapseUI.sPx(28) + th * 0.35
			x = x + dx / len * push
			y = y + dy / len * push
			items[#items + 1] = {
				lab = row.lab,
				name = name,
				tw = tw,
				th = th,
				x = x,
				y = y
			}
		end
	end

	for _ = 1, 6 do
		for i = 1, #items do
			for j = i + 1, #items do
				local a, b = items[i], items[j]
				local gapX = (a.tw + b.tw) * 0.5 + RelapseUI.sPx(10)
				local gapY = (a.th + b.th) * 0.5 + RelapseUI.sPx(4)
				local ox, oy = b.x - a.x, b.y - a.y
				if math.abs(ox) < gapX and math.abs(oy) < gapY then
					local nx, ny = ox, oy
					local nlen = math.sqrt(nx * nx + ny * ny)
					if nlen < 1 then
						nx, ny, nlen = 1, 0, 1
					end
					local push = RelapseUI.sPx(8)
					a.x = a.x - nx / nlen * push
					a.y = a.y - ny / nlen * push
					b.x = b.x + nx / nlen * push
					b.y = b.y + ny / nlen * push
				end
			end
		end
	end

	local hits = {}
	for _, it in ipairs(items) do
		it.x = math.Clamp(it.x, pad + it.tw * 0.5, w - pad - it.tw * 0.5)
		it.y = math.Clamp(it.y, pad + it.th * 0.5, h - pad - it.th * 0.5)
		draw.SimpleText(it.name, font, it.x, it.y, self:GridInk(it.lab.tree), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		hits[#hits + 1] = {
			tree = it.lab.tree,
			x1 = it.x - it.tw * 0.5,
			y1 = it.y - it.th * 0.5,
			x2 = it.x + it.tw * 0.5,
			y2 = it.y + it.th * 0.5
		}
	end
	self._LabHits = hits
end

vgui.Register("RelapseCycleGrid", GRID, "DPanel")

local function ApplyCharPage(frame, idx, silent)
	if not IsValid(frame) then return end
	idx = math.Clamp(tonumber(idx) or CHAR_PAGE_GRID, CHAR_PAGE_GRID, CHAR_PAGE_SCARS)
	frame.CharPage = idx
	if IsValid(frame.RelapseTitle) then
		frame.RelapseTitle:SetText(CharPageTitle(idx))
		frame.RelapseTitle:SizeToContents()
	end
	if IsValid(frame.RelapseShopPrev) then
		local onFirst = idx == CHAR_PAGE_GRID
		frame.RelapseShopPrev.RelapseCurrent = onFirst
		frame.RelapseShopPrev:SetCursor(onFirst and "arrow" or "hand")
	end
	if IsValid(frame.RelapseShopNext) then
		local onLast = idx == CHAR_PAGE_SCARS
		frame.RelapseShopNext.RelapseCurrent = onLast
		frame.RelapseShopNext:SetCursor(onLast and "arrow" or "hand")
	end
	if IsValid(frame.RelapseTitle) then
		RelapseUI.PlaceShopTitle(frame.RelapseTitle, frame.RelapseLayout)
	end
	LayoutCharacter(frame)
	if not silent then
		surface.PlaySound("buttons/button14.wav")
	end
end

local function ScarCardSize()
	return RelapseUI.Grid15(9)
end

local function DefaultSelection(frame)
	local st = State()
	local id = frame.SelectedId
	if id and GAMEMODE:GetRelapseScar(id) then
		local lottery = frame.SelectedLottery and OfferHas(id) and (st.Picks or 0) > 0
		return id, lottery
	end
	if st.Offer and st.Offer[1] and (st.Picks or 0) > 0 then
		return st.Offer[1], true
	end
	for _, sid in ipairs(GAMEMODE.RelapseScarOrder or {}) do
		if RankOf(sid) > 0 then
			return sid, false
		end
	end
	return (GAMEMODE.RelapseScarOrder or {})[1], false
end

local function RebuildLottery(frame)
	for _, btn in ipairs(frame.LotCards or {}) do
		if IsValid(btn) then
			btn:Remove()
		end
	end
	frame.LotCards = {}
	if not IsValid(frame.Lottery) then return end

	local st = State()
	local picks = st.Picks or 0
	if IsValid(frame.PicksChip) then
		frame.PicksChip.RelapseText = picks > 1 and PhraseF("char_picks", picks) or ""
		frame.PicksChip:SetVisible(picks > 1)
	end
	if picks <= 0 then
		return
	end

	local gap = RelapseUI.Grid15(2)
	local offer = st.Offer or {}
	local size = ScarCardSize()
	local x = 0
	for i = 1, #offer do
		local btn = vgui.Create("RelapseScarCard", frame.Lottery)
		btn:SetCardSize(size, size)
		btn:SetScar(offer[i], true)
		btn:SetPos(x, RelapseUI.Grid15(3))
		frame.LotCards[#frame.LotCards + 1] = btn
		x = x + size + gap
	end
end

local function RebuildInventory(frame)
	local layout = frame.InvLayout
	if not IsValid(layout) then return end
	for _, ch in ipairs(layout:GetChildren()) do
		if IsValid(ch) then
			ch:Remove()
		end
	end
	frame.InvCards = {}

	local gap = RelapseUI.Grid15(2)
	local size = ScarCardSize()
	layout:SetSpaceX(gap)
	layout:SetSpaceY(gap)

	for _, id in ipairs(GAMEMODE.RelapseScarOrder or {}) do
		local btn = vgui.Create("RelapseScarCard", layout)
		btn:SetCardSize(size, size)
		btn:SetScar(id, false)
		frame.InvCards[#frame.InvCards + 1] = btn
	end
end

function GM:LayoutCharacterFooter(frame)
	if not IsValid(frame) then return end
	local take = frame.Take
	local remort = frame.RelapseBtn
	local classBtn = frame.ClassBtn
	local st = State()
	local pl = MySelf
	local onScars = (frame.CharPage or CHAR_PAGE_GRID) == CHAR_PAGE_SCARS
	local canTake = onScars and IsValid(take) and frame.SelectedId and (st.Picks or 0) > 0 and OfferHas(frame.SelectedId)
	if IsValid(take) then
		take:SetVisible(canTake)
		if canTake then
			RelapseUI.AlignFooterRight(take)
			RelapseUI.AlignFooterBottom(take)
		end
	end
	if IsValid(remort) then
		local canRemort = IsValid(pl) and pl.CanSkillsRemort and pl:CanSkillsRemort()
		remort:SetVisible(canRemort)
		if canRemort then
			RelapseUI.AlignFooterBottom(remort)
			if canTake and IsValid(take) then
				remort:SetX(take:GetX() - RelapseUI.Grid15(2) - remort:GetWide())
			else
				RelapseUI.AlignFooterRight(remort)
			end
		end
	end
	if IsValid(classBtn) then
		local undead = IsValid(pl) and pl:Team() == TEAM_UNDEAD
		local blocked = GAMEMODE.ShouldUseAlternateDynamicSpawn and GAMEMODE:ShouldUseAlternateDynamicSpawn()
		classBtn:SetVisible(undead and not blocked)
		if undead and not blocked then
			RelapseUI.AlignFooterLeft(classBtn)
			RelapseUI.AlignFooterBottom(classBtn)
		end
	end
end

function LayoutCharacter(frame)
	if not IsValid(frame) or not IsValid(frame.Body) then return end
	local body = frame.Body
	local bw, bh = body:GetWide(), body:GetTall()
	local gap = RelapseUI.Grid15(2)
	local leftW = RelapseUI.ViewerW()
	local identH = RelapseUI.Grid15(12)
	local modelH = math.max(RelapseUI.Grid15(14), bh - identH - gap)

	if IsValid(frame.ModelWell) then
		frame.ModelWell:SetPos(0, 0)
		frame.ModelWell:SetSize(leftW, modelH)
		frame.ModelWell:InvalidateLayout(true)
	end
	if IsValid(frame.Model) then
		RelapseUI.FramePlayerPreview(frame.Model)
	end

	if IsValid(frame.Identity) then
		frame.Identity:SetPos(0, modelH + gap)
		frame.Identity:SetSize(leftW, identH)
	end

	local rightX = leftW + RelapseUI.Grid15(4)
	local rightW = math.max(1, bw - rightX)
	local gridPage = (frame.CharPage or CHAR_PAGE_GRID) == CHAR_PAGE_GRID

	if IsValid(frame.GridPane) then
		frame.GridPane:SetVisible(gridPage)
		frame.GridPane:SetMouseInputEnabled(gridPage)
		if gridPage then
			frame.GridPane:SetPos(rightX, 0)
			frame.GridPane:SetSize(rightW, bh)
			frame.GridPane:MoveToFront()
		else
			frame.GridPane.Dragging = false
			frame.GridPane:MouseCapture(false)
		end
	end

	local function showScars(vis)
		if IsValid(frame.Desc) then
			frame.Desc:SetVisible(vis)
			frame.Desc:SetMouseInputEnabled(vis)
		end
		if IsValid(frame.Lottery) then
			frame.Lottery:SetMouseInputEnabled(vis)
		end
		if IsValid(frame.InvHead) then
			frame.InvHead:SetVisible(vis)
			frame.InvHead:SetMouseInputEnabled(vis)
		end
		if IsValid(frame.InvScroll) then
			frame.InvScroll:SetVisible(vis)
			frame.InvScroll:SetMouseInputEnabled(vis)
		end
	end

	if gridPage then
		showScars(false)
		if IsValid(frame.Lottery) then
			frame.Lottery:SetVisible(false)
		end
		GAMEMODE:LayoutCharacterFooter(frame)
		return
	end

	showScars(true)

	local st = State()
	local picks = st.Picks or 0
	local lotH = 0
	if picks > 0 then
		lotH = RelapseUI.Grid15(3) + ScarCardSize()
	end
	local descH = RelapseUI.Grid15(10)
	local invTitleH = RelapseUI.Grid15(3)

	local y = 0
	if IsValid(frame.Desc) then
		frame.Desc:SetPos(rightX, y)
		frame.Desc:SetSize(rightW, descH)
	end
	y = y + descH + gap

	if IsValid(frame.Lottery) then
		if lotH > 0 then
			frame.Lottery:SetVisible(true)
			frame.Lottery:SetPos(rightX, y)
			frame.Lottery:SetSize(rightW, lotH)
			y = y + lotH + gap
		else
			frame.Lottery:SetVisible(false)
			frame.Lottery:SetSize(rightW, 0)
		end
	end

	if IsValid(frame.InvHead) then
		frame.InvHead:SetPos(rightX, y)
		frame.InvHead:SetSize(rightW, invTitleH)
	end
	y = y + invTitleH
	if IsValid(frame.InvScroll) then
		frame.InvScroll:SetPos(rightX, y)
		frame.InvScroll:SetSize(rightW, math.max(1, bh - y))
	end
	if IsValid(frame.InvLayout) then
		frame.InvLayout:SetPos(0, 0)
		frame.InvLayout:SetWide(math.max(1, frame.InvScroll:GetWide() - RelapseUI.ScrollBarW()))
	end
	GAMEMODE:LayoutCharacterFooter(frame)
end

local function DropRemortLab(frame)
	if not IsValid(frame) then return end
	if IsValid(frame.RemortLab) then
		frame.RemortLab:Remove()
		frame.RemortLab = nil
	end
	local ident = frame.Identity
	if not IsValid(ident) then return end
	for _, ch in ipairs(ident:GetChildren()) do
		if IsValid(ch) and ch ~= frame.NameLab and ch ~= frame.CycleLab then
			ch:Remove()
		end
	end
end

local function Ink(text, font, x, y, col)
	text = tostring(text or "")
	draw.SimpleText(text, font, x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	surface.SetFont(font)
	return surface.GetTextSize(text) or 0
end

-- Relapse30 optical bottom → Relapse20 capital: 30px (Grid15(2)).
-- Relapse30 sits ~6px under the baseline; Relapse20 ~5px above caps.
local function PaintIdentity(frame, w, h)
	local y = 0
	DropRemortLab(frame)
	if IsValid(frame.NameLab) then
		frame.NameLab:SetPos(0, y)
		y = y + frame.NameLab:GetTall()
	end
	if IsValid(frame.CycleLab) then
		frame.CycleLab:SetVisible(false)
	end
	local font = "Relapse20"
	local gap = RelapseUI.Grid5()
	surface.SetFont(font)
	local _, rowH = surface.GetTextSize("Ay")
	y = y - RelapseUI.sPx(6) + RelapseUI.Grid15(2) - RelapseUI.sPx(5)
	local rowY = math.max(0, y)
	local c = RelapseUI.Col
	local x = 0
	x = x + Ink(Phrase("char_level_lab", "Уровень") .. ":", font, x, rowY, c.Muted)
	x = x + gap
	x = x + Ink(frame.LevelNum or "1", font, x, rowY, c.Text)
	x = x + Ink("/" .. (frame.MaxLevelNum or "30"), font, x, rowY, c.Muted)
	local have = frame.XPHaveText or "0"
	local need = " / " .. (frame.XPNeedText or "0")
	surface.SetFont(font)
	local haveW = surface.GetTextSize(have) or 0
	local needW = surface.GetTextSize(need) or 0
	local xpX = w - RelapseUI.Grid15() - haveW - needW
	Ink(have, font, xpX, rowY, c.Text)
	Ink(need, font, xpX + haveW, rowY, c.Muted)
	local air = RelapseUI.Grid15(2)
	local capNudge = RelapseUI.sPx(5)
	y = rowY + math.max(1, rowH) - capNudge + air
	local barh = RelapseUI.sPx(10)
	local progress = frame.XPProgress or 0
	frame.LerpXP = Lerp(FrameTime() * 8, frame.LerpXP or progress, progress)
	RelapseUI.PaintHudHairBar(0, y, w, barh, frame.LerpXP, RelapseUI.Col.Ok, nil, nil, RelapseUI.Shadow)
	y = y + barh + air - capNudge
	x = 0
	x = x + Ink(Phrase("char_remort_lab", "Реморт") .. ":", font, x, y, c.Muted)
	x = x + gap
	Ink(frame.RemortNum or "0", font, x, y, c.Text)
	return true
end

local function BindIdentityPaint(frame)
	if not IsValid(frame) or not IsValid(frame.Identity) then return end
	frame.Identity.Paint = function(me, w, h)
		return PaintIdentity(frame, w, h)
	end
end

local function UpdateIdentity(frame)
	if not IsValid(frame) or not IsValid(MySelf) then return end
	local pl = MySelf
	local name = pl:Name() or ""
	if IsValid(frame.NameLab) then
		frame.NameLab:SetText(Ellipsize(name, "Relapse30", math.max(8, frame.Identity:GetWide())))
		frame.NameLab:SizeToContents()
	end
	local level = pl:GetZSLevel() or 1
	local maxLevel = GAMEMODE.MaxLevel or 30
	frame.LevelNum = tostring(level)
	frame.MaxLevelNum = tostring(maxLevel)
	if IsValid(frame.CycleLab) then
		frame.CycleLab:SetVisible(false)
	end
	frame.XPProgress = GAMEMODE:ProgressForXP(pl:GetZSXP() or 0)
	local cur = GAMEMODE:XPForLevel(level)
	local nxt = GAMEMODE:XPForLevel(math.min(level + 1, maxLevel))
	local have = math.max(0, (pl:GetZSXP() or 0) - cur)
	local need = math.max(1, nxt - cur)
	if level >= maxLevel then
		have = need
	end
	frame.XPHaveText = CommaNum(have)
	frame.XPNeedText = CommaNum(need)
	local remort = 0
	if pl.GetZSRemortLevel then
		remort = pl:GetZSRemortLevel() or 0
	end
	frame.RemortNum = tostring(remort)
	if IsValid(frame.Model) then
		SyncPreview(frame.Model, pl)
	end
end

function GM:RefreshCharacterSheet()
	local frame = pCharacter
	if not IsValid(frame) then return end
	DropRemortLab(frame)
	BindIdentityPaint(frame)
	LayoutCharacter(frame)
	RebuildLottery(frame)
	RebuildInventory(frame)
	UpdateIdentity(frame)
	local id, lottery = DefaultSelection(frame)
	if id then
		SelectScar(frame, id, lottery, true)
	end
	self:LayoutCharacterFooter(frame)
end

function GM:CharacterSheetOpen()
	return IsValid(pCharacter) and (pCharacter:IsVisible() or pCharacter._RelapseClosing)
end

function GM:CloseCharacterSheet(fromEsc, instant)
	if not (pCharacter and pCharacter:IsValid()) then
		return false
	end
	if not (pCharacter:IsVisible() or pCharacter._RelapseClosing) then
		return false
	end
	if instant or not pCharacter._RelapseClosing then
		pCharacter:Close(instant)
	end
	if fromEsc then
		self.ShopOverlayBlockPause = true
		gui.HideGameUI()
	end
	return true
end

function GM:ToggleCharacterSheet()
	if self:CharacterSheetOpen() then
		self:CloseCharacterSheet()
		return
	end
	self:OpenCharacterSheet()
end

function GM:OpenCharacterSheet()
	if not IsValid(MySelf) then
		MySelf = LocalPlayer()
	end
	if not IsValid(MySelf) then return end

	if self.CloseOtherOverlays then
		self:CloseOtherOverlays("character")
	end

	PlayMenuOpenSound()
	net.Start("zs_scars_request")
	net.SendToServer()

	if IsValid(pCharacter) then
		DropRemortLab(pCharacter)
		BindIdentityPaint(pCharacter)
		RelapseUI.ShowShopFrame(pCharacter)
		self:RefreshCharacterSheet()
		return
	end
	RelapseUI.CreateFonts()

	local frame, L, topspace, bottomspace, propertysheet = RelapseUI.BuildShopFrame("char_title", {
		deleteOnClose = false
	})
	pCharacter = frame
	self.CharacterSheet = frame

	if IsValid(topspace) then
		topspace:SetVisible(false)
		topspace:SetMouseInputEnabled(false)
	end
	if IsValid(propertysheet) then
		propertysheet:SetVisible(false)
		propertysheet:SetMouseInputEnabled(false)
		propertysheet:SetSize(0, 0)
	end

	local body = vgui.Create("DPanel", frame)
	body:SetPaintBackground(false)
	body:SetPos(L.pad, L.headerh)
	body:SetSize(L.innerW, L.sheetH)
	frame.Body = body

	local modelWell = vgui.Create("DPanel", body)
	modelWell:SetPaintBackground(false)
	frame.ModelWell = modelWell

	local mdl = vgui.Create("DModelPanelEx", modelWell)
	mdl:SetPaintBackground(false)
	mdl:Dock(FILL)
	frame.Model = mdl

	local identity = vgui.Create("DPanel", body)
	identity:SetPaintBackground(false)
	frame.Identity = identity
	frame.NameLab = EasyLabel(identity, "", "Relapse30", RelapseUI.Col.Text)
	frame.CycleLab = EasyLabel(identity, "", "Relapse20", RelapseUI.Col.Muted)
	BindIdentityPaint(frame)

	frame.CharPage = CHAR_PAGE_GRID
	local grid = vgui.Create("RelapseCycleGrid", body)
	frame.GridPane = grid

	local desc = vgui.Create("DPanel", body)
	desc:SetPaintBackground(false)
	frame.Desc = desc
	desc.Paint = function(me, w, h)
		local id = frame.SelectedId
		if not id then
			draw.SimpleText(Phrase("char_empty_desc", ""), "Relapse15", 0, 0, RelapseUI.Col.Muted)
			return true
		end
		local scar = GAMEMODE:GetRelapseScar(id)
		local c = RelapseUI.Col
		local y = 0
		draw.SimpleText(ScarName(id), "Relapse30", 0, y, c.Text)
		surface.SetFont("Relapse30")
		y = y + select(2, surface.GetTextSize("Ay")) + RelapseUI.Grid5()
		local lottery = frame.SelectedLottery
		local rank = RankOf(id)
		local status
		if lottery then
			status = RankCaption(id, true)
		elseif rank > 0 then
			status = PhraseF("char_owned_rank", GAMEMODE:RelapseScarRoman(rank))
		else
			status = Phrase("char_locked", "")
		end
		draw.SimpleText(status, "Relapse15", 0, y, lottery and c.Accent or (rank > 0 and c.Accent or c.Muted))
		surface.SetFont("Relapse15")
		y = y + select(2, surface.GetTextSize("Ay")) + RelapseUI.Grid15()
		y = DrawWrapped(ScarDesc(id), "Relapse15", 0, y, w, c.Text)
		y = y + RelapseUI.Grid15()
		local effectRank = rank
		if lottery then
			effectRank = rank + 1
		elseif effectRank < 1 then
			effectRank = 1
		end
		local effect = ScarEffect(id, effectRank)
		if effect ~= "" then
			y = DrawWrapped(effect, "Relapse15", 0, y, w, c.Accent)
			y = y + RelapseUI.Grid5(2)
		end
		if scar and not scar.InPool then
			y = DrawWrapped(Phrase("char_sketch", ""), "Relapse13", 0, y, w, c.Muted)
			y = y + RelapseUI.Grid5(2)
		end
		local count = State().Counts and State().Counts[id]
		if count and count > 0 then
			DrawWrapped(PhraseF("char_cycle_count", CommaNum(count)), "Relapse13", 0, y, w, c.Muted)
		end
		return true
	end

	local lottery = vgui.Create("DPanel", body)
	lottery:SetPaintBackground(false)
	frame.Lottery = lottery
	local lotTitle = EasyLabel(lottery, Phrase("char_lottery", "Lottery"), "Relapse20", RelapseUI.Col.Muted)
	lotTitle:SetPos(0, 0)
	frame.LotteryTitle = lotTitle
	local chip = vgui.Create("DPanel", lottery)
	chip:SetMouseInputEnabled(false)
	chip.Paint = function(me, w, h)
		if not me.RelapseText or me.RelapseText == "" then return true end
		RelapseUI.RoundFill(RelapseUI.RadPx("Card"), 0, 0, w, h, RelapseUI.Col.Card)
		draw.SimpleText(me.RelapseText, "Relapse20", w * 0.5, h * 0.5, RelapseUI.Col.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return true
	end
	frame.PicksChip = chip
	lottery.PerformLayout = function(me, w, h)
		if IsValid(lotTitle) then
			lotTitle:SizeToContents()
			lotTitle:SetPos(0, math.floor((RelapseUI.Grid15(3) - lotTitle:GetTall()) * 0.5))
		end
		if IsValid(chip) then
			surface.SetFont("Relapse20")
			local tw = surface.GetTextSize(chip.RelapseText or "3×")
			chip:SetSize(math.max(RelapseUI.Grid15(4), tw + RelapseUI.Grid15(2)), RelapseUI.Grid15(3))
			chip:SetPos((IsValid(lotTitle) and lotTitle:GetWide() or 0) + RelapseUI.Grid15(), 0)
		end
	end

	local invHead = vgui.Create("DPanel", body)
	invHead:SetPaintBackground(false)
	frame.InvHead = invHead
	local invTitle = EasyLabel(invHead, Phrase("char_scars", "Scars"), "Relapse20", RelapseUI.Col.Muted)
	invTitle:SetPos(0, 0)
	invHead.PerformLayout = function()
		invTitle:SizeToContents()
		invTitle:SetPos(0, math.floor((RelapseUI.Grid15(3) - invTitle:GetTall()) * 0.5))
	end

	local invScroll = vgui.Create("DScrollPanel", body)
	invScroll.Paint = function() return true end
	RelapseUI.StyleScroll(invScroll)
	frame.InvScroll = invScroll
	local layout = vgui.Create("DIconLayout", invScroll)
	frame.InvLayout = layout

	local take = vgui.Create("DButton", bottomspace)
	take:SetFont("Relapse20")
	take:SetText(Phrase("char_take", "Take"))
	take:SetSize(RelapseUI.Cells(12), L.m.btnH)
	take.Paint = RelapseUI.PaintPrimaryButton
	take.DoClick = function()
		if not frame.SelectedId then
			surface.PlaySound("buttons/button8.wav")
			return
		end
		surface.PlaySound("buttons/button14.wav")
		net.Start("zs_scars_take")
			net.WriteString(frame.SelectedId)
		net.SendToServer()
	end
	frame.Take = take

	local remort = vgui.Create("DButton", bottomspace)
	remort:SetFont("Relapse20")
	remort:SetText(Phrase("char_relapse", "Relapse"))
	remort:SetSize(RelapseUI.Cells(12), L.m.btnH)
	remort.Paint = RelapseUI.PaintGhostButton
	remort.DoClick = function()
		Derma_Query(
			Phrase("char_relapse_confirm", ""),
			Phrase("char_relapse", "Relapse"),
			Phrase("shop_ok", "OK"),
			function()
				net.Start("zs_skills_remort")
				net.SendToServer()
			end,
			Phrase("menu_continue", "Cancel"),
			function() end
		)
	end
	frame.RelapseBtn = remort

	local classBtn = vgui.Create("DButton", bottomspace)
	classBtn:SetFont("Relapse20")
	classBtn:SetText(Phrase("char_class", "Class"))
	classBtn:SetSize(RelapseUI.Cells(12), L.m.btnH)
	classBtn.Paint = RelapseUI.PaintPrimaryButton
	classBtn.DoClick = function()
		surface.PlaySound("buttons/button14.wav")
		if GAMEMODE.OpenClassSelect then
			GAMEMODE:OpenClassSelect()
		end
	end
	frame.ClassBtn = classBtn

	frame.Think = function(me)
		if not me:IsVisible() then return end
		UpdateIdentity(me)
	end

	frame.RelapseShopPrev = RelapseUI.MakeDirSwitch(frame, -1, true, function()
		ApplyCharPage(frame, (frame.CharPage or CHAR_PAGE_GRID) - 1, true)
	end)
	frame.RelapseShopNext = RelapseUI.MakeDirSwitch(frame, 1, false, function()
		ApplyCharPage(frame, (frame.CharPage or CHAR_PAGE_GRID) + 1, true)
	end)
	frame.RelapseShopPrev:MoveToFront()
	frame.RelapseShopNext:MoveToFront()
	if IsValid(frame.RelapseClose) then
		frame.RelapseClose:MoveToFront()
	end
	body.PerformLayout = function()
		LayoutCharacter(frame)
	end

	ApplyCharPage(frame, CHAR_PAGE_GRID, true)
	RelapseUI.FinishShopFrame(frame, propertysheet)
	self:RefreshCharacterSheet()
end

net.Receive("zs_scars_sync", function()
	local gm = GAMEMODE
	local st = gm.RelapseScarState
	if not st then
		st = {Picks = 0, Offer = {}, Ranks = {}, Counts = {}, Meters = {}}
		gm.RelapseScarState = st
	end
	st.Picks = net.ReadUInt(8)
	local nOffer = net.ReadUInt(3)
	st.Offer = {}
	for i = 1, nOffer do
		st.Offer[i] = net.ReadString()
	end
	local nRanks = net.ReadUInt(8)
	st.Ranks = {}
	for _ = 1, nRanks do
		local id = net.ReadString()
		st.Ranks[id] = net.ReadUInt(16)
	end
	local nMeters = net.ReadUInt(8)
	st.Counts = {}
	st.Meters = {}
	for _ = 1, nMeters do
		local id = net.ReadString()
		st.Counts[id] = net.ReadUInt(16)
		st.Meters[id] = net.ReadFloat()
	end
	if gm.RefreshCharacterSheet then
		gm:RefreshCharacterSheet()
	end
end)
