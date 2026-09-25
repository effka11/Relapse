-- Post-round map vote. Five cards. Empty slots and missing thumbs are gray.

local SLOTS = 5

local thumbs = {}

local function MapThumb(map)
	if not map or map == "" then return end
	local cached = thumbs[map]
	if cached ~= nil then
		return cached or nil
	end
	local path = "maps/thumb/" .. map .. ".png"
	local found = file.Exists("materials/" .. path, "GAME") or file.Exists(path, "GAME")
	if not found then
		thumbs[map] = false
		return
	end
	local mat = Material(path, "smooth")
	if not mat or mat:IsError() then
		thumbs[map] = false
		return
	end
	thumbs[map] = mat
	return mat
end

local function FitText(text, font, maxW)
	if not text or text == "" or maxW < 1 then return "" end
	surface.SetFont(font)
	if surface.GetTextSize(text) <= maxW then return text end

	local ell = "…"
	if surface.GetTextSize(ell) > maxW then return "" end

	local acc, shown = "", ""
	for ch in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
		local trial = acc .. ch
		if surface.GetTextSize(trial .. ell) > maxW then break end
		acc = trial
		shown = trial .. ell
	end
	return shown
end

local function CardHeight()
	local pad = RelapseUI.Grid15()
	return pad + RelapseUI.Grid15(7) + pad + RelapseUI.Grid15(2) + pad
end

local FACE_ALPHA = { 1, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4 }
local FACE_MAX = 7
local FACE_POOL = FACE_MAX + 1

local function MakeVoterFace(parent, index)
	local face = vgui.Create("DPanel", parent)
	face:SetPaintBackground(false)
	face:SetMouseInputEnabled(false)
	face:SetKeyboardInputEnabled(false)
	face:SetZPos(20 - index)
	face.Index = index

	local av = vgui.Create("AvatarImage", face)
	av:SetMouseInputEnabled(false)
	av:SetKeyboardInputEnabled(false)
	av:SetPaintedManually(true)
	av:SetVisible(false)
	face.Avatar = av

	face.Paint = function(me, w, h)
		local img = me.Avatar
		if not (IsValid(img) and img:IsVisible()) then return true end
		local a = me._a or FACE_ALPHA[me.Index] or 1
		if a < 0.01 then return true end
		local rad = RelapseUI.RadPx("Avatar")
		img:SetAlpha(255)
		RelapseUI.MaskRound(rad, w, h, function()
			surface.SetAlphaMultiplier(a)
			img:PaintManual()
			surface.SetAlphaMultiplier(1)
		end)

		local card = me:GetParent()
		local shade = me._retire and 0 or (a * 0.5)
		if me.Index > 1 and card and me.Index <= (card.FaceCount or 0) and shade > 0 then
			local step = RelapseUI.Grid15()
			local shift = RelapseUI.sPx(RelapseUI.Shadow or 3)
			local seam = math.max(0, w - step)
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
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect(seam, 0, shift, h)
			render.OverrideColorWriteEnable(false)
			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilPassOperation(STENCIL_KEEP)
			RelapseUI.RoundFill(rad, -step + shift, 0, w, h, RelapseUI.CopyCol(RelapseUI.Col.Shadow, math.floor(255 * shade + 0.5)))
			render.SetStencilEnable(false)
			render.ClearStencil()
		end
		return true
	end
	face.PerformLayout = function(me, w, h)
		if IsValid(me.Avatar) then
			me.Avatar:SetPos(0, 0)
			me.Avatar:SetSize(w, h)
		end
	end
	return face
end

local PANEL = {}

function PANEL:Init()
	self:SetText("")
	self:SetPaintBackground(false)
	self:SetKeyboardInputEnabled(false)
	self.Slot = 1
	self.MapName = ""
	self.Count = 0
	self.Chosen = false
	self.Voters = {}
	self.VoterFaces = {}
	for i = 1, FACE_POOL do
		self.VoterFaces[i] = MakeVoterFace(self, i)
	end
end

local function FaceSlotX(i)
	return RelapseUI.Grid15() + (i - 1) * RelapseUI.Grid15()
end

local function PlaceFace(face)
	if not IsValid(face) then return end
	local parent = face:GetParent()
	local y = RelapseUI.Grid15()
	if IsValid(parent) and parent._faceY then
		y = parent._faceY
	end
	local px = math.floor((face._x or 0) + 0.5)
	if face._px ~= px or face._py ~= y then
		face._px, face._py = px, y
		face:SetPos(px, y)
	end
	local z = face._retire and 1 or (10000 - px)
	if face._z ~= z then
		face._z = z
		face:SetZPos(z)
	end
end

local function EaseFace(face, toX, toA, retire)
	face._fromX = face._x or toX
	face._toX = toX
	face._fromA = face._a or toA
	face._toA = toA
	face._t0 = RealTime()
	face._retire = retire and true or false
	face:SetVisible(true)
	if IsValid(face.Avatar) then
		face.Avatar:SetVisible(true)
	end
end

function PANEL:SyncVoters()
	local voters = self.Voters or {}
	local incoming = {}
	for i = 1, FACE_MAX do
		local idx = tonumber(voters[i]) or 0
		local pl = idx > 0 and Entity(idx) or nil
		if IsValid(pl) and pl:IsPlayer() then
			incoming[#incoming + 1] = idx
		end
	end

	local step = RelapseUI.Grid15()
	if not self._faceInit then
		self._faceInit = true
		self.FaceOrder = {}
		local used = {}
		for j, ent in ipairs(incoming) do
			local face = self.VoterFaces[j]
			if not IsValid(face) then continue end
			used[face] = true
			face.Ent = ent
			face.Index = j
			face._retire = false
			face._x = FaceSlotX(j)
			face._a = FACE_ALPHA[j] or 0.4
			face._fromX, face._toX = face._x, face._x
			face._fromA, face._toA = face._a, face._a
			face._t0 = RealTime()
			face:SetVisible(true)
			face.Avatar:SetPlayer(Entity(ent), 64)
			face.Avatar:SetVisible(true)
			PlaceFace(face)
			self.FaceOrder[j] = { ent = ent, face = face }
		end
		for _, face in ipairs(self.VoterFaces) do
			if not used[face] then
				face:SetVisible(false)
				face.Ent = nil
				face.Index = 0
				face._retire = false
			end
		end
		self.FaceCount = #incoming
		return
	end

	local old = self.FaceOrder or {}
	local used = {}
	local order = {}
	local cursor = 0
	for j, ent in ipairs(incoming) do
		local found
		for i = cursor + 1, #old do
			if not used[i] and old[i].ent == ent and IsValid(old[i].face) then
				found = i
				break
			end
		end
		if not found then
			for i = 1, cursor do
				if not used[i] and old[i].ent == ent and IsValid(old[i].face) then
					found = i
					break
				end
			end
		end
		if found then
			used[found] = true
			if found > cursor then cursor = found end
			order[j] = { ent = ent, face = old[found].face, oldI = found }
		else
			order[j] = { ent = ent, isNew = true }
		end
	end

	local function spare()
		for _, face in ipairs(self.VoterFaces) do
			local taken = false
			for _, item in ipairs(order) do
				if item.face == face then taken = true break end
			end
			if not taken and not face:IsVisible() then return face end
		end
		for _, face in ipairs(self.VoterFaces) do
			local taken = false
			for _, item in ipairs(order) do
				if item.face == face then taken = true break end
			end
			if not taken then return face end
		end
	end

	for j, item in ipairs(order) do
		if not IsValid(item.face) then
			item.face = spare()
			item.isNew = true
		end
	end

	local maxMatched = 0
	local shiftedRight = false
	for j, item in ipairs(order) do
		if item.oldI then
			if j > item.oldI then shiftedRight = true end
			if item.oldI > maxMatched then maxMatched = item.oldI end
		end
	end

	for i, item in ipairs(old) do
		if not used[i] and IsValid(item.face) then
			local face = item.face
			local exitRight = shiftedRight and i > maxMatched
			local from = face._x or FaceSlotX(i)
			face.Index = 0
			EaseFace(face, from + (exitRight and step or -step), 0, true)
			PlaceFace(face)
		end
	end

	self.FaceOrder = {}
	for j, item in ipairs(order) do
		local face = item.face
		if not IsValid(face) then continue end
		local toX = FaceSlotX(j)
		local toA = FACE_ALPHA[j] or 0.4
		local prevEnt = face.Ent
		face.Ent = item.ent
		face.Index = j
		if item.isNew or prevEnt ~= item.ent then
			face.Avatar:SetPlayer(Entity(item.ent), 64)
		end
		if item.isNew then
			face._x = toX - step
			face._a = 0
		end
		EaseFace(face, toX, toA, false)
		PlaceFace(face)
		self.FaceOrder[#self.FaceOrder + 1] = { ent = item.ent, face = face }
	end
	self.FaceCount = #self.FaceOrder
end

function PANEL:Think()
	local now = RealTime()
	local dur = math.max(0.01, RelapseUI.Duration(3))
	for _, face in ipairs(self.VoterFaces or {}) do
		if not face._toX then continue end
		local u = math.Clamp((now - (face._t0 or now)) / dur, 0, 1)
		local e = u >= 1 and 1 or RelapseUI.EaseOut(u)
		face._x = face._fromX + (face._toX - face._fromX) * e
		face._a = face._fromA + (face._toA - face._fromA) * e
		if u >= 1 then
			face._x = face._toX
			face._a = face._toA
		end
		PlaceFace(face)
		if u >= 1 and face._retire then
			face:SetVisible(false)
			face._retire = false
			face._z = nil
			face._toX = nil
			face.Ent = nil
			face.Index = 0
			if IsValid(face.Avatar) then
				face.Avatar:SetVisible(false)
			end
		end
	end
end

function PANEL:PerformLayout(w, h)
	local pad = RelapseUI.Grid15()
	local size = RelapseUI.Grid15(2)
	self._faceY = pad
	for _, face in ipairs(self.VoterFaces or {}) do
		if IsValid(face) and face:GetWide() ~= size then
			face:SetSize(size, size)
		end
	end
end

function PANEL:Refresh()
	self:SetMouseInputEnabled(true)
	self.Mat = self.MapName ~= "" and MapThumb(self.MapName) or nil
end

function PANEL:DoClick()
	net.Start("zs_mapvote_cast")
		net.WriteUInt(self.Slot or 1, 3)
	net.SendToServer()
end

function PANEL:DoRightClick()
	net.Start("zs_mapvote_uncast")
		net.WriteUInt(self.Slot or 1, 3)
	net.SendToServer()
end

local function VoteShare(card)
	local mine = card.Count or 0
	if mine < 1 then return 0 end
	local parent = card:GetParent()
	local total = 0
	if IsValid(parent) and parent.Counts then
		for i = 1, SLOTS do
			total = total + (parent.Counts[i] or 0)
		end
	end
	if total < 1 then return 0 end
	return mine / total
end

function PANEL:Paint(w, h)
	local r = RelapseUI.RadPx("Card")
	local mat = self.MapName ~= "" and self.Mat or nil
	if mat then
		RelapseUI.MaskRound(r, w, h, function()
			surface.SetMaterial(mat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(0, 0, w, h)
		end)
	else
		RelapseUI.RoundFill(r, 0, 0, w, h, RelapseUI.Col.Muted)
	end
	local pad = RelapseUI.Grid15()
	local share = VoteShare(self)
	self.BarShare = Lerp(FrameTime() * 6, self.BarShare or 0, share)
	if share <= 0 and self.BarShare < 0.004 then
		self.BarShare = 0
	end
	local barH = RelapseUI.Grid5()
	local barW = math.floor(w * self.BarShare + 0.5)
	if barW > 0 then
		local ink = RelapseUI.Col.Text
		local br = math.min(RelapseUI.RadPx("Bar"), math.floor(math.min(barW, barH) * 0.5))
		RelapseUI.MaskRound(r, w, h, function()
			RelapseUI.RoundFill(br, 0, h - barH, barW, barH, ink)
		end)
	end

	local named = self.MapName ~= ""
	local votes = self.Count or 0
	if not named and votes < 1 and (self.BarShare or 0) <= 0 then return true end

	local label = named and GAMEMODE:MapVoteLabel(self.MapName) or ""
	local count = tostring(votes)
	surface.SetFont("Relapse25")
	local countW, th = surface.GetTextSize(count)
	if not th or th < 1 then
		th = RelapseUI.sPx(25)
	end
	local gap = RelapseUI.Grid5(2)
	local nameMax = math.max(0, w - pad * 2 - countW - gap)
	local ty = h - pad - th
	draw.SimpleText(FitText(label, "Relapse25", nameMax), "Relapse25", pad, ty, RelapseUI.Col.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(count, "Relapse25", w - pad, ty, RelapseUI.Col.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	return true
end

vgui.Register("DRelapseMapVoteCard", PANEL, "Button")

local function LayoutSig()
	return ScrW() .. ":" .. ScrH() .. ":" .. tostring(RelapseUI.S())
end

local function Reflow(frame)
	RelapseUI.CreateFonts()
	local L = RelapseUI.ScoreboardWindowSize()
	local gap = L.m.cardGap
	local cardH = CardHeight()
	local cardW = math.floor((L.innerW - gap * (SLOTS - 1)) / SLOTS)
	local rowW = cardW * SLOTS + gap * (SLOTS - 1)
	local slack = math.max(0, L.innerW - rowW)

	local scrim = frame.RelapseScrim
	if IsValid(scrim) then
		scrim:SetSize(ScrW(), ScrH())
		scrim:SetPos(0, 0)
	end
	frame:SetSize(L.pad * 2 + L.innerW, cardH)
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
	surface.SetFont("Relapse30")
	local _, titleCell = surface.GetTextSize("Ay")
	if not titleCell or titleCell < 1 then
		titleCell = RelapseUI.sPx(30)
	end
	local titleY = IsValid(frame.RelapseTitle) and frame.RelapseTitle:GetY() or RelapseUI.Grid15(2)
	local ink = titleY + titleCell - RelapseUI.sPx(6)
	local top = ink + RelapseUI.sPx(45)
	local tall = top + cardH + L.pad
	frame:SetTall(tall)
	frame:Center()
	frame.Layout.ink = ink
	frame.Layout.clockRight = L.pad + L.m.close + RelapseUI.Grid15()

	local close = frame.RelapseClose
	if IsValid(close) then
		close:SetSize(L.m.close, L.m.close)
		close:AlignRight(L.pad)
		close:AlignTop(RelapseUI.Grid15(2))
		close:MoveToFront()
	end

	local x = L.pad + math.floor(slack * 0.5)
	local y = top
	for i = 1, SLOTS do
		local card = frame.Rows[i]
		if IsValid(card) then
			card:SetSize(cardW, cardH)
			card:SetPos(x, y)
		end
		x = x + cardW + gap
	end
end

local function BindCards(frame)
	frame.Rows = frame.Rows or {}
	for i = 1, SLOTS do
		local card = frame.Rows[i]
		if not IsValid(card) then
			card = vgui.Create("DRelapseMapVoteCard", frame)
			card.Slot = i
			frame.Rows[i] = card
		end
		card.MapName = (frame.Maps and frame.Maps[i]) or ""
		card.Count = (frame.Counts and frame.Counts[i]) or 0
		card.Voters = (frame.Voters and frame.Voters[i]) or {}
		card.Chosen = frame.Mine == i and card.MapName ~= ""
		card:Refresh()
		card:SyncVoters()
	end
	Reflow(frame)
end

function GM:MapVoteMenuOpen()
	return IsValid(pMapVote) and (pMapVote:IsVisible() or pMapVote._RelapseClosing)
end

function GM:HideMapVote(instant)
	local pnl = pMapVote
	self.MapVoteDismissed = true
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

function GM:CloseMapVote(fromEsc, instant)
	if not self:MapVoteMenuOpen() then
		return false
	end
	self:HideMapVote(instant)
	if fromEsc then
		self.MapVoteBlockPause = true
		gui.HideGameUI()
	end
	return true
end

local function RevealMapVote()
	local pnl = pMapVote
	if not IsValid(pnl) then return end
	if pnl:IsVisible() and not pnl._RelapseClosing and pnl:GetAlpha() > 200 then return end
	if GAMEMODE.CloseOtherOverlays then
		GAMEMODE:CloseOtherOverlays("mapvote")
	end
	gui.EnableScreenClicker(true)
	PlayMenuOpenSound()
	RelapseUI.FadeOpenMenu(pnl)
end

function GM:ApplyMapVote(maps, counts, mine, force, voters)
	maps = maps or {}
	counts = counts or {}
	voters = voters or {}
	if force then
		self.MapVoteDismissed = nil
	end
	local existed = IsValid(pMapVote)
	if self.MapVoteDismissed and existed then
		pMapVote.Maps = maps
		pMapVote.Counts = counts
		pMapVote.Voters = voters
		pMapVote.Mine = mine
		BindCards(pMapVote)
		return
	end

	if not existed then
		self:MakeMapVote()
	end
	if not IsValid(pMapVote) then return end
	pMapVote.Maps = maps
	pMapVote.Counts = counts
	pMapVote.Voters = voters
	pMapVote.Mine = mine
	BindCards(pMapVote)
	if force and existed then
		RevealMapVote()
	end
end

function GM:MakeMapVote()
	if pMapVote and pMapVote:IsValid() then
		pMapVote:Remove()
		pMapVote = nil
	end
	self.MapVoteDismissed = nil

	if self.CloseOtherOverlays then
		self:CloseOtherOverlays("mapvote")
	end
	RelapseUI.CreateFonts()

	local scrim = RelapseUI.CreateMenuScrim({ class = "DPanel" })
	local frame = vgui.Create("DPanel", scrim)
	frame:SetPaintBackground(false)
	frame:SetKeyboardInputEnabled(false)
	frame:SetMouseInputEnabled(true)
	frame.Maps = {}
	frame.Counts = {}
	frame.Voters = {}
	frame.Rows = {}
	frame.Mine = 0
	frame.Close = function(me, instant)
		GAMEMODE:CloseMapVote(false, instant)
	end
	RelapseUI.LinkMenuScrim(frame, scrim)

	local title = EasyLabel(frame, RelapseUI.T("mapvote_title"), "Relapse30", RelapseUI.Col.Text)
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

	frame.Paint = function(self, w, h)
		RelapseUI.PaintWindow(self, w, h)
		local lay = self.Layout
		if not lay then return true end
		local left = GAMEMODE.MapVoteSecondsLeft and GAMEMODE:MapVoteSecondsLeft() or -1
		if left >= 0 and lay.ink then
			draw.SimpleText(util.ToMinutesSecondsCD(left), "Relapse20", w - (lay.clockRight or lay.pad), lay.ink + RelapseUI.sPx(5), RelapseUI.Col.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
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

	pMapVote = frame
	BindCards(frame)
	gui.EnableScreenClicker(true)
	PlayMenuOpenSound()
	RelapseUI.FadeOpenMenu(frame)
	return frame
end

function GM:MapVoteSecondsLeft()
	if not self.MapVoteLeftAt or (self.MapVoteLeft or 0) < 0 then return -1 end
	return math.max(0, self.MapVoteLeft - (CurTime() - self.MapVoteLeftAt))
end

net.Receive("zs_mapvote", function()
	local n = net.ReadUInt(3)
	local maps, counts = {}, {}
	for i = 1, n do
		maps[i] = net.ReadString()
	end
	for i = 1, n do
		counts[i] = net.ReadUInt(16)
	end
	local mine = net.ReadUInt(3)
	local voters = {}
	for i = 1, n do
		local c = net.ReadUInt(3)
		voters[i] = {}
		for k = 1, c do
			voters[i][k] = net.ReadUInt(8)
		end
	end
	local left = net.ReadFloat()
	local force = net.ReadBool()
	GAMEMODE.MapVoteLeft = left
	GAMEMODE.MapVoteLeftAt = CurTime()
	GAMEMODE:ApplyMapVote(maps, counts, mine, force, voters)
end)

concommand.Add("relapse_votemap", function()
	if util.NetworkStringToID("zs_mapvote_open") == 0 then return end
	net.Start("zs_mapvote_open")
	net.SendToServer()
end)

concommand.Add("relapse_votemap_dev", function()
	if util.NetworkStringToID("zs_mapvote_dev") == 0 then return end
	net.Start("zs_mapvote_dev")
	net.SendToServer()
end)
