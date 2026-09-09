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
		tabs = RelapseUI.Grid15(4),
		footer = RelapseUI.Grid15(5),
		sidebar = RelapseUI.Grid15(20),
		gutter = RelapseUI.Grid15(2),
		cardH = RelapseUI.Grid15(7),
		trinketH = RelapseUI.Grid15(5),
		cardPad = RelapseUI.Grid15(),
		btnH = RelapseUI.Grid15(3),
		close = RelapseUI.Grid15(3)
	}
end

function RelapseUI.CreateFonts()
	local s = RelapseUI.S()
	local rev = 5
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
	mk("Relapse17", 17, 400)
	mk("Relapse22", 22, 400)
	mk("Relapse32", 32, 400)
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
	RelapseUI.RoundFill(RelapseUI.RadPx("Panel"), 0, 0, w, h, RelapseUI.Col.Panel)
	return true
end

function RelapseUI.PaintCard(self, w, h, selected, locked, unaffordable)
	local c = RelapseUI.Col
	local fill = c.Card
	if selected then
		fill = c.CardOn
	elseif self.Hovered and unaffordable then
		fill = Color(c.Danger.r, c.Danger.g, c.Danger.b, 40)
	elseif self.Hovered then
		fill = c.CardHover
	end
	RelapseUI.RoundFill(RelapseUI.RadPx("Card"), 0, 0, w, h, fill)

	if locked then
		RelapseUI.RoundFill(RelapseUI.RadPx("Card"), 0, 0, w, h, Color(0, 0, 0, 80))
	end

	return true
end

function RelapseUI.PaintPrimaryButton(self, w, h)
	local c = RelapseUI.Col
	local fill = self.Hovered and Color(c.Accent.r, c.Accent.g, c.Accent.b, 120) or c.AccentDim
	RelapseUI.RoundFill(RelapseUI.RadPx("Button"), 0, 0, w, h, fill)
	DrawCentered(self, w, h, self.Hovered and c.Text or c.Accent)
	return true
end

function RelapseUI.PaintGhostButton(self, w, h)
	local c = RelapseUI.Col
	if self.Hovered then
		RelapseUI.RoundFill(RelapseUI.RadPx("Button"), 0, 0, w, h, Color(255, 255, 255, 16))
	end
	DrawCentered(self, w, h, self.Hovered and c.Text or c.Muted)
	return true
end

function RelapseUI.PaintTab(self, w, h)
	local c = RelapseUI.Col
	local inset = math.min(RelapseUI.Grid5(2), math.max(1, math.floor((h - RelapseUI.sPx(18)) * 0.5)))
	local active = self.IsActive and self:IsActive()
	if active then
		RelapseUI.RoundFill(RelapseUI.RadPx("Button"), 0, inset, w, h - 2 * inset, Color(255, 255, 255, 22))
	end
	local col = active and c.Text or (self.Hovered and c.Text or c.Muted)
	local text = self.GetText and self:GetText() or ""
	if text ~= "" then
		draw.SimpleText(text, "Relapse15", w * 0.5, h * 0.5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

local colHudShadow = Color(0, 0, 0, 255)

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

-- 45° \ band. x, y, span, thick on the 5-grid. thick is the axis offset (Grid5 / Grid15).
function RelapseUI.PaintHudDiagBand(x, y, span, thick, col, shadow)
	x = math.floor(x + 0.5)
	y = math.floor(y + 0.5)
	span = math.floor(span + 0.5)
	thick = math.max(1, math.floor(thick + 0.5))
	if span <= thick * 2 then return end

	local function band(ox, oy, c)
		RelapseUI.FillQuad(
			x + thick + ox, y + oy,
			x + span + ox, y + span - thick + oy,
			x + span - thick + ox, y + span + oy,
			x + ox, y + thick + oy,
			c
		)
	end

	RelapseUI.EachShadow(function(ox, oy)
		band(ox, oy, colHudShadow)
	end, shadow)
	band(0, 0, col)
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

	surface.SetTextColor(0, 0, 0, col.a or 255)
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
	RelapseUI.EachShadow(function(ox, oy)
		RelapseUI.RoundFill(r, x + ox, y + oy, w, h, colHudShadow)
	end, shadow)
	RelapseUI.RoundFill(r, x, y, w, h, Color(0, 0, 0, 90))
	local extraW = extrafrac > 0 and math.floor(w * (frac + extrafrac) + 0.5) or 0
	local fillW = frac >= 0.995 and w or math.floor(w * frac + 0.5)
	if extraW > fillW and extracol then
		RelapseUI.RoundFill(math.min(r, math.floor(extraW * 0.5)), x, y, extraW, h, extracol)
	end
	if fillW > 0 and col then
		RelapseUI.RoundFill(math.min(r, math.floor(fillW * 0.5)), x, y, fillW, h, col)
	end
end

local colHealthA = Color(0, 0, 0, 255)
local colUrgent = Color(196, 86, 78, 255)

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

	local wide = math.max(6, RelapseUI.sPx(8))
	bar:SetWide(wide)
	if bar.SetHideButtons then
		bar:SetHideButtons(true)
	end

	bar.Paint = function(me, w, h)
		RelapseUI.RoundFill(w * 0.5, 0, 0, w, h, Color(255, 255, 255, 12))
	end
	if IsValid(bar.btnGrip) then
		bar.btnGrip.Paint = function(me, w, h)
			local c = RelapseUI.Col
			local col = me.Depressed and c.Text or (me.Hovered and c.Accent or Color(c.Accent.r, c.Accent.g, c.Accent.b, 140))
			RelapseUI.RoundFill(w * 0.5, 0, 0, w, h, col)
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
	elseif remaining < starting then
		lab:SetTextColor(RelapseUI.Col.Warn)
	else
		lab:SetTextColor(RelapseUI.Col.Accent)
	end
	lab:SizeToContents()
	if lab.RelapseAlignRight then
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
