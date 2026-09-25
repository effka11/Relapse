-- End-of-round awards. Same glass as TAB; one list of rows, not a card grid.

local function GroupInt(n)
	n = math.ceil((tonumber(n) or 0) - 1e-9)
	if n < 1 then return "" end
	local s = tostring(n)
	local parts = {}
	while #s > 3 do
		parts[#parts + 1] = string.sub(s, -3)
		s = string.sub(s, 1, #s - 3)
	end
	parts[#parts + 1] = s
	for i = 1, math.floor(#parts / 2) do
		parts[i], parts[#parts - i + 1] = parts[#parts - i + 1], parts[i]
	end
	return table.concat(parts, " ")
end

local function UnitForm(raw, n)
	if not raw or raw == "" then return "" end
	local one, few, many = string.match(raw, "^([^|]+)|([^|]+)|([^|]+)$")
	if not one then return raw end
	n = math.abs(math.floor(tonumber(n) or 0))
	local n10 = n % 10
	local n100 = n % 100
	if n10 == 1 and n100 ~= 11 then return one end
	if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then return few end
	return many
end

local function FitText(text, font, maxW)
	if not text or text == "" or maxW < 1 then return "", 0 end
	surface.SetFont(font)
	local tw = surface.GetTextSize(text)
	if tw <= maxW then return text, tw end

	local ell = "…"
	local ellW = surface.GetTextSize(ell)
	if ellW > maxW then return "", 0 end

	local acc = ""
	local shown, shownW = "", 0
	for ch in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
		local trial = acc .. ch
		local w = surface.GetTextSize(trial .. ell)
		if w > maxW then break end
		acc = trial
		shown = trial .. ell
		shownW = w
	end
	return shown, shownW
end

local function DrawFit(x, y, maxW, text, font, col)
	local shown = FitText(text, font, maxW)
	if shown == "" then return end
	draw.SimpleText(shown, font, x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function AwardStat(aw)
	local n = math.ceil((tonumber(aw and aw.Mag) or 0) - 1e-9)
	local showNum = aw and not aw.NoStat and n >= 1
	local unit = UnitForm(aw and aw.Unit or "", showNum and n or 0)
	return showNum and GroupInt(n) or "", unit, showNum
end

local function TextW(font, text)
	surface.SetFont(font)
	return surface.GetTextSize(text or "") or 0
end

local function MeasureSpec(awards)
	local catW, unitW, numW = 0, 0, 0
	for _, aw in ipairs(awards or {}) do
		local num, unit = AwardStat(aw)
		catW = math.max(catW, TextW("Relapse15", aw.Title or ""))
		unitW = math.max(unitW, TextW("Relapse15", unit))
		if num ~= "" then
			numW = math.max(numW, TextW("Relapse15", num))
		end
	end
	return {
		catW = math.min(math.max(catW, RelapseUI.Grid15(4)), RelapseUI.Grid15(12)),
		unitW = math.min(math.max(unitW, RelapseUI.Grid15(4)), RelapseUI.Grid15(16)),
		numW = math.min(math.max(numW, RelapseUI.Grid15(3)), RelapseUI.Grid15(8))
	}
end

local function ListInner(spec)
	local pad = RelapseUI.Grid15()
	local gap = RelapseUI.Grid15()
	local cluster = RelapseUI.Grid15(2)
	local nameMin = RelapseUI.Grid15(10)
	return pad + RelapseUI.Grid15(2) + gap + nameMin + gap + spec.catW + cluster + spec.numW + gap + spec.unitW + pad
end

local function FitSpec(spec, listW)
	local pad = RelapseUI.Grid15()
	local gap = RelapseUI.Grid15()
	local cluster = RelapseUI.Grid15(2)
	local nameMin = RelapseUI.Grid15(8)
	local fixed = pad + RelapseUI.Grid15(2) + gap + nameMin + gap + cluster + gap + pad
	local room = listW - fixed
	local want = spec.catW + spec.numW + spec.unitW
	if room >= want or want < 1 then return spec end
	local k = math.max(0.35, room / want)
	return {
		catW = math.max(RelapseUI.Grid15(3), math.floor(spec.catW * k)),
		numW = math.max(RelapseUI.Grid15(2), math.floor(spec.numW * k)),
		unitW = math.max(RelapseUI.Grid15(3), math.floor(spec.unitW * k))
	}
end

local function RowMetrics(w, spec)
	local pad = RelapseUI.Grid15()
	local avatar = RelapseUI.Grid15(2)
	local gap = RelapseUI.Grid15()
	local cluster = RelapseUI.Grid15(2)
	local right = w - pad
	local unitX = right - spec.unitW
	local numX = unitX - gap - spec.numW
	local catX = numX - cluster - spec.catW
	local nameX = pad + avatar + gap
	return {
		pad = pad,
		avatar = avatar,
		nameX = nameX,
		nameW = math.max(0, catX - gap - nameX),
		catX = catX,
		catW = spec.catW,
		numX = numX,
		numW = spec.numW,
		unitX = unitX,
		unitW = spec.unitW
	}
end

-- Relapse20 sitting on the TAB heading baseline (the Relapse25 count cell).
local function HeadingInkY(h)
	surface.SetFont("Relapse25")
	local _, tabCell = surface.GetTextSize("Ay")
	if not tabCell or tabCell < 1 then
		tabCell = RelapseUI.sPx(25)
	end
	local yNum = math.ceil((h - tabCell) * 0.5)
	return RelapseUI.ManropeBaseline(yNum, RelapseUI.sPx(25)) - RelapseUI.ManropeBaseline(0, RelapseUI.sPx(20))
end

local PANEL = {}

function PANEL:Init()
	self:SetText("")
	self:SetPaintBackground(false)
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(true)
	self.Title = ""
	self.PName = ""
	self.UnitRaw = ""
	self.Mag = 0

	self.m_AvatarButton = vgui.Create("DButton", self)
	self.m_AvatarButton:SetText("")
	self.m_AvatarButton:SetKeyboardInputEnabled(false)
	self.m_AvatarButton.Row = self
	self.m_AvatarButton.DoClick = function(me)
		local pl = me.Row and me.Row.Player
		if IsValid(pl) then
			pl:ShowProfile()
		end
	end

	self.m_Avatar = vgui.Create("AvatarImage", self.m_AvatarButton)
	self.m_Avatar:SetVisible(false)
	self.m_Avatar:SetMouseInputEnabled(false)
	self.m_Avatar:SetPaintedManually(true)
	self.m_AvatarButton.Paint = function(me, w, h)
		local av = me.Row and me.Row.m_Avatar
		if not (IsValid(av) and av:IsVisible()) then return true end
		RelapseUI.MaskRound(RelapseUI.RadPx("Avatar"), w, h, function()
			av:PaintManual()
		end)
		return true
	end

	self.m_Name = EasyLabel(self, " ", "Relapse20", RelapseUI.Col.Text)
	self.m_Cat = EasyLabel(self, " ", "Relapse15", RelapseUI.Col.Muted)
	self.m_Num = EasyLabel(self, " ", "Relapse15", RelapseUI.Col.Text)
	self.m_Unit = EasyLabel(self, " ", "Relapse15", RelapseUI.Col.Muted)
	self.m_Num:SetContentAlignment(6)
	self.m_Name:SetContentAlignment(4)
	self.m_Cat:SetContentAlignment(4)
	self.m_Unit:SetContentAlignment(4)
end

function PANEL:SetAward(aw)
	self.Player = aw.Player
	self.PName = aw.Name or ""
	self.Title = aw.Title or ""
	self.UnitRaw = aw.Unit or ""
	self.Mag = aw.Mag or 0
	self.Undead = aw.Undead
	self.Mine = aw.Mine
	self.NoStat = aw.NoStat
	if IsValid(self.Player) then
		self.m_Avatar:SetPlayer(self.Player, 64)
		self.m_Avatar:SetVisible(true)
		self.m_AvatarButton:SetVisible(true)
	else
		self.m_Avatar:SetVisible(false)
		self.m_AvatarButton:SetVisible(false)
	end
	self:InvalidateLayout()
end

function PANEL:DoClick()
	local pl = self.Player
	if IsValid(pl) then
		gamemode.Call("ClickedEndBoardPlayerButton", pl, self)
	end
end

function PANEL:Paint(w, h)
	RelapseUI.PaintCard(self, w, h, self.Mine)
	return true
end

function PANEL:PerformLayout()
	local spec = self.Spec
	if not spec then return end
	local h = self:GetTall()
	local met = RowMetrics(self:GetWide(), spec)

	self.m_AvatarButton:SetSize(met.avatar, met.avatar)
	self.m_AvatarButton:SetPos(met.pad, math.floor((h - met.avatar) * 0.5))
	self.m_Avatar:SetSize(met.avatar, met.avatar)
	self.m_Avatar:SetPos(0, 0)

	surface.SetFont("Relapse20")
	local _, nameH = surface.GetTextSize("Ay")
	if not nameH or nameH < 1 then
		nameH = RelapseUI.sPx(20)
	end
	surface.SetFont("Relapse15")
	local _, smallH = surface.GetTextSize("Ay")
	if not smallH or smallH < 1 then
		smallH = RelapseUI.sPx(15)
	end
	local nameY = math.floor((h - nameH) * 0.5)
	local smallY = nameY + nameH - smallH - RelapseUI.sPx(1)

	local name = self.PName
	if IsValid(self.Player) then
		name = self.Player:Name()
	end
	self.m_Name:SetText((FitText(name, "Relapse20", met.nameW)))
	self.m_Name:SetTextColor(RelapseUI.Col.Text)
	self.m_Name:SetPos(met.nameX, nameY)
	self.m_Name:SetSize(met.nameW, nameH)

	self.m_Cat:SetText((FitText(self.Title, "Relapse15", met.catW)))
	self.m_Cat:SetTextColor(self.Undead and RelapseUI.Col.Danger or RelapseUI.Col.Muted)
	self.m_Cat:SetPos(met.catX, smallY)
	self.m_Cat:SetSize(met.catW, smallH)

	local num, unit, showNum = AwardStat({
		Mag = self.Mag,
		NoStat = self.NoStat,
		Unit = self.UnitRaw
	})
	self.m_Num:SetVisible(showNum)
	self.m_Num:SetText(showNum and (FitText(num, "Relapse15", met.numW)) or "")
	self.m_Num:SetTextColor(RelapseUI.Col.Text)
	self.m_Num:SetPos(met.numX, smallY)
	self.m_Num:SetSize(met.numW, smallH)

	self.m_Unit:SetVisible(unit ~= "")
	self.m_Unit:SetText((FitText(unit, "Relapse15", met.unitW)))
	self.m_Unit:SetTextColor(RelapseUI.Col.Muted)
	self.m_Unit:SetPos(met.unitX, smallY)
	self.m_Unit:SetSize(met.unitW, smallH)
end

vgui.Register("DRelapseAwardRow", PANEL, "Button")

local function LayoutSig()
	return ScrW() .. ":" .. ScrH() .. ":" .. tostring(RelapseUI.S())
end

local function Reflow(frame)
	RelapseUI.CreateFonts()
	local L = RelapseUI.ScoreboardWindowSize()
	local measured = MeasureSpec(frame.Awards)
	local listW = math.min(math.max(ListInner(measured), L.listW), L.innerW)
	local spec = FitSpec(measured, listW)
	frame.RowSpec = spec

	local n = #frame.Rows
	local gridH = n > 0 and (n * (L.rowH + L.rowGap)) or 0
	local top = L.headerh + L.headingH + L.tabGap
	local chrome = top + L.pad
	local maxWindow = L.hei
	local viewH = gridH
	if chrome + viewH > maxWindow then
		viewH = math.max(0, maxWindow - chrome)
	end

	local scrim = frame.RelapseScrim
	if IsValid(scrim) then
		scrim:SetSize(ScrW(), ScrH())
		scrim:SetPos(0, 0)
	end
	frame:SetSize(L.pad * 2 + listW, chrome + viewH)
	frame:Center()

	frame.Layout = {
		pad = L.pad,
		headerh = L.headerh,
		headingH = L.headingH,
		tabhei = L.headingH
	}
	frame._lay = LayoutSig()

	if IsValid(frame.RelapseTitle) then
		RelapseUI.PlaceShopTitle(frame.RelapseTitle, frame.Layout)
	end
	local close = frame.RelapseClose
	if IsValid(close) then
		close:SetSize(L.m.close, L.m.close)
		close:AlignRight(L.pad)
		close:AlignTop(RelapseUI.Grid15(2))
		close:MoveToFront()
	end

	local scroll = frame.Scroll
	scroll:SetPos(L.pad, top)
	scroll:SetSize(listW, math.max(viewH, 0))
	scroll:SetVisible(n > 0 and viewH > 0)

	for _, row in ipairs(frame.Rows) do
		row.Spec = spec
		row:SetTall(L.rowH)
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, L.rowGap)
	end
	scroll:InvalidateLayout(true)
	for _, row in ipairs(frame.Rows) do
		row:InvalidateLayout(true)
	end
end

local function Rebuild(frame)
	local canvas = frame.Scroll:GetCanvas()
	for _, row in ipairs(frame.Rows) do
		if IsValid(row) then row:Remove() end
	end
	frame.Rows = {}

	table.sort(frame.Awards, function(a, b)
		if a.Order == b.Order then return a.Id < b.Id end
		return a.Order < b.Order
	end)

	for _, aw in ipairs(frame.Awards) do
		local row = vgui.Create("DRelapseAwardRow", canvas)
		row:SetAward(aw)
		frame.Rows[#frame.Rows + 1] = row
	end
	Reflow(frame)
end

function GM:AwardsMenuOpen()
	return IsValid(pEndBoard) and (pEndBoard:IsVisible() or pEndBoard._RelapseClosing)
end

function GM:HideAwardsMenu(instant)
	local pnl = pEndBoard
	self.AwardsDismissed = true
	if not IsValid(pnl) then
		gui.EnableScreenClicker(false)
		return
	end
	if not pnl:IsVisible() and not pnl._RelapseClosing then
		gui.EnableScreenClicker(false)
		return
	end
	if pnl._RelapseClosing and not instant then return end
	if not instant then
		PlayMenuCloseSound()
	end
	gui.EnableScreenClicker(false)
	RelapseUI.FadeCloseMenu(pnl, instant, function(gone)
		if not IsValid(gone) then return end
		gone:SetVisible(false)
		gone:SetAlpha(255)
		gone:SetMouseInputEnabled(true)
		local host = RelapseUI.MenuHost(gone)
		if IsValid(host) and host ~= gone then
			host:SetVisible(false)
			host:SetAlpha(0)
			host:SetMouseInputEnabled(true)
		end
	end)
end

function GM:CloseAwardsMenu(fromEsc, instant)
	if not self:AwardsMenuOpen() then
		return false
	end
	self:HideAwardsMenu(instant)
	if fromEsc then
		self.AwardsMenuBlockPause = true
		gui.HideGameUI()
	end
	return true
end

function GM:AddHonorableMention(pl, mentionid, magnitude)
	-- Hidden while the post-round screen is the map vote. Set ShowAwards to bring it back.
	if not self.ShowAwards then return end
	if self.AwardsDismissed then return end
	if not (pEndBoard and pEndBoard:IsValid()) then
		MakepEndBoard(ROUNDWINNER)
	end
	if not (pEndBoard and pEndBoard:IsValid()) then return end

	local tab = self.HonorableMentions[mentionid]
	if not tab or not tab.Title then return end

	local row = {
		Id = mentionid,
		Player = pl,
		Name = pl:IsValid() and pl:Name() or "",
		Mag = magnitude or 0,
		Title = RelapseUI.T(tab.Title, tab.Name),
		Unit = RelapseUI.T(tab.Unit or "", ""),
		Undead = tab.Side == TEAM_UNDEAD,
		Order = tab.Order or mentionid,
		NoStat = tab.NoStat and true or false,
		Mine = IsValid(pl) and IsValid(MySelf) and pl == MySelf
	}

	local replaced = false
	for i, old in ipairs(pEndBoard.Awards) do
		if old.Id == mentionid then
			pEndBoard.Awards[i] = row
			replaced = true
			break
		end
	end
	if not replaced then
		pEndBoard.Awards[#pEndBoard.Awards + 1] = row
	end
	Rebuild(pEndBoard)
end

function MakepEndBoard(winner)
	if GAMEMODE.AwardsDismissed then return end
	if pEndBoard and pEndBoard:IsValid() then
		pEndBoard:Remove()
		pEndBoard = nil
	end

	winner = winner or TEAM_UNDEAD
	if GAMEMODE.CloseOtherOverlays then
		GAMEMODE:CloseOtherOverlays("awards")
	end

	RelapseUI.CreateFonts()

	local scrim = RelapseUI.CreateMenuScrim({ class = "DPanel" })
	local frame = vgui.Create("DPanel", scrim)
	frame:SetPaintBackground(false)
	frame:SetKeyboardInputEnabled(false)
	frame:SetMouseInputEnabled(true)
	frame.Winner = winner
	frame.Awards = {}
	frame.Rows = {}
	frame.Close = function(me, instant)
		GAMEMODE:CloseAwardsMenu(false, instant)
	end
	RelapseUI.LinkMenuScrim(frame, scrim)

	local held = winner == TEAM_HUMAN
	local title = EasyLabel(frame, RelapseUI.T(held and "hm_held" or "hm_taken"), "Relapse30", held and RelapseUI.Col.Text or RelapseUI.Col.Danger)
	title:SetContentAlignment(4)
	frame.RelapseTitle = title

	local close = vgui.Create("DButton", frame)
	close:SetText("×")
	close:SetFont("Relapse30")
	close:SetPaintBackground(false)
	close:SetKeyboardInputEnabled(false)
	close.Paint = RelapseUI.PaintGhostButton
	close.DoClick = function()
		frame:Close()
	end
	frame.RelapseClose = close

	local scroll = vgui.Create("DScrollPanel", frame)
	RelapseUI.StyleScroll(scroll)
	scroll.Paint = function() return true end
	frame.Scroll = scroll

	frame.Paint = function(self, w, h)
		RelapseUI.PaintWindow(self, w, h)
		local lay = self.Layout
		if not lay then return true end

		local pad = lay.pad
		local heldNow = self.Winner == TEAM_HUMAN
		local sub = RelapseUI.T(heldNow and "hm_held_sub" or "hm_taken_sub")
		local waveN = GAMEMODE:GetWave()
		local wave = waveN > 0 and RelapseUI.TF("hm_wave", waveN) or ""
		local left = 0
		if GAMEMODE.EndTime then
			left = math.max(0, GAMEMODE.EndTime + (GAMEMODE.EndGameTime or 0) - CurTime())
		end
		local clock = util.ToMinutesSecondsCD(left)
		local subY = (lay.headerh or 0) + HeadingInkY(lay.headingH or 0)

		surface.SetFont("Relapse20")
		local clockW = surface.GetTextSize(clock)
		local waveW = wave ~= "" and surface.GetTextSize(wave) or 0
		local gutter = RelapseUI.Grid15(2)
		local rightW = clockW + (waveW > 0 and gutter + waveW or 0)
		DrawFit(pad, subY, math.max(0, w - pad * 2 - rightW - gutter), sub, "Relapse20", RelapseUI.Col.Text)

		local right = w - pad
		if wave ~= "" then
			draw.SimpleText(wave, "Relapse20", right, subY, RelapseUI.Col.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			right = right - waveW - gutter
		end
		draw.SimpleText(clock, "Relapse20", right, subY, RelapseUI.Col.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		return true
	end

	frame.Think = function(self)
		self:SetKeyboardInputEnabled(false)
		local host = self.RelapseScrim
		if IsValid(host) then
			host:SetKeyboardInputEnabled(false)
		end
		local focus = vgui.GetKeyboardFocus()
		local cursor = focus
		while IsValid(cursor) do
			if cursor == self or cursor == host then
				if IsValid(focus) then
					focus:KillFocus()
				end
				break
			end
			cursor = cursor:GetParent()
		end
		if self._lay ~= LayoutSig() then
			Reflow(self)
		end
	end

	pEndBoard = frame
	Reflow(frame)
	gui.EnableScreenClicker(true)
	PlayMenuOpenSound()
	RelapseUI.FadeOpenMenu(frame)
	return frame
end
