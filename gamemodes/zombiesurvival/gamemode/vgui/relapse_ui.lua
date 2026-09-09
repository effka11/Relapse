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
		sidebar = RelapseUI.Grid15(20),
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
	return RelapseUI.sPx(30)
end

function RelapseUI.CreateFonts()
	local s = RelapseUI.S()
	local rev = 8
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
	mk("Relapse28", 28, 400)
	mk("Relapse30", 30, 400)
	mk("Relapse32", 32, 400)
	mk("Relapse40", 40, 400)
	mk("Relapse45", 45, 400)
	mk("Relapse64", 64, 500)
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
	if self.RelapseArmed then
		RelapseUI.RoundFill(RelapseUI.RadPx("Button"), 0, 0, w, h, self.Hovered and c.Ok or c.CardOn)
		DrawCentered(self, w, h, c.Ink)
		return true
	end
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

function RelapseUI.StepTabIndicator(sheet)
	if not IsValid(sheet) then return end
	local tab = sheet.GetActiveTab and sheet:GetActiveTab()
	if not IsValid(tab) then return end

	local sx = select(1, sheet:ScreenToLocal(tab:LocalToScreen(0, 0)))
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

function RelapseUI.PaintTabIndicator(sheet, w)
	local st = sheet._TabInd
	if not st or not st.primed or st.w < 1 then return end

	local thick = math.max(2, RelapseUI.sPx(2))
	local tabhei = sheet._RelapseTabHei or RelapseUI.M().tabs
	local y = tabhei
	local x1 = math.max(0, st.x)
	local x2 = math.min(w, st.x + st.w)
	local dw = x2 - x1
	if dw < 2 then return end

	local r = math.min(RelapseUI.RadPx("Bar"), math.floor(math.min(dw, thick) * 0.5))
	RelapseUI.RoundFill(r, x1, y, dw, thick, RelapseUI.Col.Accent)
end

function RelapseUI.BindTabIndicator(sheet)
	if not IsValid(sheet) or sheet._RelapseTabInd then return end
	sheet._RelapseTabInd = true

	local prevThink = sheet.Think
	sheet.Think = function(me)
		if prevThink then prevThink(me) end
		RelapseUI.StepTabIndicator(me)
	end

	local prevOver = sheet.PaintOver
	sheet.PaintOver = function(me, w, h)
		if prevOver then prevOver(me, w, h) end
		RelapseUI.PaintTabIndicator(me, w)
	end
end

function RelapseUI.PaintTab(self, w, h)
	local c = RelapseUI.Col
	local act = 0
	local sheet = self.GetPropertySheet and self:GetPropertySheet()
	local st = IsValid(sheet) and sheet._TabInd
	if st and st.primed and st.w > 1 then
		local sx = select(1, sheet:ScreenToLocal(self:LocalToScreen(0, 0)))
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

function RelapseUI.PaintStatBar(self, w, h)
	local c = RelapseUI.Col
	self.LerpStat = Lerp(FrameTime() * 6, self.LerpStat or self.Stat, self.Stat)
	local progress = math.Clamp((self.StatMax - self.LerpStat) / math.max(1, self.StatMax - self.StatMin), 0, 1)
	if not self.BadHigh then
		progress = 1 - progress
	end

	RelapseUI.PaintHudBar(0, 0, w, h, progress, c.Accent)
	return true
end

function RelapseUI.HudInset()
	return RelapseUI.Grid15(3)
end

function RelapseUI.HudW()
	return RelapseUI.Grid15(24)
end

RelapseUI.Shadow = 3

function RelapseUI.EachShadow(fn, n)
	n = n or RelapseUI.Shadow
	for i = 1, n do
		fn(i, i)
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

-- Tiny 45° \ hairline. span on the 15-grid. sPx stroke; shadow is thickness down-right.
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
			me.tabScroller:SetParent(me)
			me.tabScroller:SetPos(0, 0)
			me.tabScroller:SetSize(me:GetWide(), tabhei)
		end
		for _, item in ipairs(me.Items or {}) do
			local pan = item.Panel
			if IsValid(pan) then
				pan:SetPos(0, top)
				pan:SetSize(me:GetWide(), math.max(0, me:GetTall() - top))
			end
		end
	end
	sheet:InvalidateLayout(true)
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
