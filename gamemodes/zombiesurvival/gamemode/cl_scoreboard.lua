-- Relapse TAB scoreboard: 5/15 grid, shop glass, two team columns.
-- Size and fade follow RelapseUI; JetBoom credits stay in ESC.

local ScoreBoard

local function Ellipsize(text, font, maxW)
	if not text or text == "" or maxW <= 0 then return "" end
	surface.SetFont(font)
	if surface.GetTextSize(text) <= maxW then return text end
	local ell = ".."
	local ew = surface.GetTextSize(ell)
	for i = #text, 1, -1 do
		local b = string.byte(text, i)
		if b and (b < 128 or b >= 192) then
			local s = string.sub(text, 1, i - 1)
			if surface.GetTextSize(s) + ew <= maxW then
				return s .. ell
			end
		end
	end
	return ell
end

local function RemortCaption(pl)
	if not (pl and pl:IsValid()) then return "" end
	local n = pl:GetZSRemortLevel()
	if not n or n < 1 then return "" end
	return tostring(n)
end

local function RowMetrics(w)
	local pad = RelapseUI.Grid15()
	local avatar = RelapseUI.Grid15(2)
	local icon = RelapseUI.sPx(16)
	local num = RelapseUI.Grid15(3)
	local fine = RelapseUI.Grid5()
	local gap = RelapseUI.Grid15()
	local muteX = w - pad - icon
	local friendX = muteX - fine - icon
	local classX = friendX - gap - RelapseUI.Grid15(2)
	local scoreRight = RelapseUI.Grid15(18) + RelapseUI.sPx(35)
	local scoreW = RelapseUI.Grid15(6)
	local scoreX = scoreRight - scoreW
	local remortLeft = scoreRight + RelapseUI.Grid15(5)
	local nameX = pad + avatar + gap
	return {
		pad = pad,
		avatar = avatar,
		icon = icon,
		num = num,
		nameX = nameX,
		nameW = math.max(RelapseUI.Grid15(), scoreX - gap - nameX),
		scoreX = scoreX,
		scoreRight = scoreRight,
		remortLeft = remortLeft,
		classX = classX,
		class = RelapseUI.Grid15(2),
		friendX = friendX,
		muteX = muteX
	}
end

local function CardColumn(list, fallbackW, fallbackX)
	local x = fallbackX or 0
	local w = fallbackW or 0
	if not IsValid(list) then
		return x, w
	end
	x = select(1, list:GetPos())
	w = list:GetWide()
	local canvas = list.GetCanvas and list:GetCanvas()
	if IsValid(canvas) then
		x = x + canvas:GetX()
		if canvas:GetWide() > 1 then
			w = canvas:GetWide()
		end
	end
	return x, w
end

local function TabCellY(h)
	surface.SetFont("Relapse25")
	local _, tabCell = surface.GetTextSize("Ay")
	if not tabCell or tabCell < 1 then
		tabCell = RelapseUI.sPx(25)
	end
	return math.ceil((h - tabCell) * 0.5)
end

local function PaintColCaps(x, y, w, h, scoreKey)
	local met = RowMetrics(w)
	local c = RelapseUI.Col.Muted
	local yNum = TabCellY(h)
	local labY = RelapseUI.ManropeBaseline(yNum, RelapseUI.sPx(25)) - RelapseUI.ManropeBaseline(0, RelapseUI.sPx(20))
	draw.SimpleText(RelapseUI.T(scoreKey), "Relapse20", x + met.scoreRight, y + labY, c, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	draw.SimpleText(RelapseUI.T("hud_class"), "Relapse20", x + met.remortLeft, y + labY, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function ScoreCapKey(pl)
	if pl and pl:IsValid() and pl:Team() == TEAM_UNDEAD then
		return "hud_brains"
	end
	return "hud_score"
end

local function ScoreLabelX(text, scoreRight, capKey)
	surface.SetFont("Relapse20")
	local capW = surface.GetTextSize(RelapseUI.T(capKey) or "") or 0
	local capCenter = scoreRight - capW * 0.5
	surface.SetFont("Relapse15")
	text = text or ""
	local slash = string.find(text, "/", 1, true)
	if not slash then
		local tw = surface.GetTextSize(text)
		return math.floor(capCenter - tw * 0.5 + 0.5)
	end
	local beforeW = surface.GetTextSize(string.sub(text, 1, slash - 1))
	local slashW = surface.GetTextSize("/")
	return math.floor(capCenter - beforeW - slashW * 0.5 + 0.5)
end

local function ClassCapCenter(remortLeft)
	surface.SetFont("Relapse20")
	local capW = surface.GetTextSize(RelapseUI.T("hud_class") or "") or 0
	return remortLeft + capW * 0.5
end

local function DrawClassIcon(name, x, y, sz, col)
	local mat = GAMEMODE:GetTabClassMaterial(name)
	if not mat then return end
	surface.SetMaterial(mat)
	surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
	surface.DrawTexturedRect(math.floor(x + 0.5), math.floor(y + 0.5), sz, sz)
end

local function ClassIconSize(name)
	local def = GAMEMODE.TabClassDefs and GAMEMODE.TabClassDefs[name]
	return RelapseUI.sPx((def and def.Size) or 24)
end

local function ClassIconGap(name)
	local def = GAMEMODE.TabClassDefs and GAMEMODE.TabClassDefs[name]
	return RelapseUI.Grid5((def and def.PlusGap) or 2)
end

local function PaintClassSplit(originX, cy, remortLeft, classA, classB)
	if not classA then return end
	local cx = originX + ClassCapCenter(remortLeft)
	local ink = RelapseUI.Col.Text
	local szA = ClassIconSize(classA)
	if not classB then
		DrawClassIcon(classA, cx - szA * 0.5, cy - szA * 0.5, szA, ink)
		return
	end
	local szB = ClassIconSize(classB)
	local gapA = ClassIconGap(classA)
	local gapB = ClassIconGap(classB)
	draw.SimpleText("+", "Relapse20", cx, cy, RelapseUI.Col.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	surface.SetFont("Relapse20")
	local plusW = surface.GetTextSize("+") or RelapseUI.sPx(12)
	DrawClassIcon(classA, cx - plusW * 0.5 - gapA - szA, cy - szA * 0.5, szA, ink)
	DrawClassIcon(classB, cx + plusW * 0.5 + gapB, cy - szB * 0.5, szB, ink)
end

function GM:IsScoreboardOpen()
	return IsValid(ScoreBoard) and (ScoreBoard:IsVisible() or ScoreBoard._RelapseClosing)
end

function GM:CloseScoreboard(fromEsc, instant)
	if not self:IsScoreboardOpen() then
		return false
	end
	self:ScoreboardHide(instant)
	if fromEsc then
		self.ScoreboardBlockPause = true
		gui.HideGameUI()
	end
	return true
end

function GM:ScoreboardShow()
	if self.CloseOtherOverlays then
		self:CloseOtherOverlays("scoreboard")
	end
	gui.EnableScreenClicker(true)
	PlayMenuOpenSound()
	RelapseUI.CreateFonts()

	if not IsValid(ScoreBoard) then
		local scrim = RelapseUI.CreateMenuScrim({ class = "DPanel" })
		scrim:SetVisible(false)
		scrim:SetAlpha(0)
		ScoreBoard = vgui.Create("ZSScoreBoard", scrim)
		RelapseUI.LinkMenuScrim(ScoreBoard, scrim, { closeOnClick = false })
	end

	ScoreBoard:ApplyLayout()
	RelapseUI.FadeOpenMenu(ScoreBoard)
end

function GM:ScoreboardRebuild()
	local vis = IsValid(ScoreBoard) and ScoreBoard:IsVisible()
	if IsValid(ScoreBoard) then
		ScoreBoard:Remove()
	end
	ScoreBoard = nil
	if vis then
		self:ScoreboardShow()
	else
		gui.EnableScreenClicker(false)
	end
end

function GM:ScoreboardHide(instant)
	gui.EnableScreenClicker(false)
	if not IsValid(ScoreBoard) then return end
	if not ScoreBoard:IsVisible() and not ScoreBoard._RelapseClosing then return end
	if ScoreBoard._RelapseClosing and not instant then return end
	if not instant then
		PlayMenuCloseSound()
	end
	RelapseUI.FadeCloseMenu(ScoreBoard, instant, function(pnl)
		if not IsValid(pnl) then return end
		pnl:SetVisible(false)
		pnl:SetAlpha(255)
		pnl:SetMouseInputEnabled(true)
		local host = RelapseUI.MenuHost(pnl)
		if IsValid(host) and host ~= pnl then
			host:SetVisible(false)
			host:SetAlpha(0)
			host:SetMouseInputEnabled(true)
		end
	end)
end

---------------------------------------------------------------------------
-- Board
---------------------------------------------------------------------------

local PANEL = {}

PANEL.RefreshTime = 2
PANEL.NextRefresh = 0

function PANEL:Init()
	RelapseUI.CreateFonts()
	self.NextRefresh = RealTime() + 0.1
	self.PlayerPanels = {}
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(false)
	self:SetVisible(false)
	self:SetAlpha(0)

	local title = EasyLabel(self, RelapseUI.T("menu_title"), "Relapse30", RelapseUI.Col.Text)
	title:SetContentAlignment(4)
	title:SizeToContents()
	self.m_TitleLabel = title
	self.RelapseTitle = title

	self.m_HumanHeading = vgui.Create("DTeamHeading", self)
	self.m_HumanHeading:SetTeam(TEAM_HUMAN)
	self.m_HumanHeading:SetMouseInputEnabled(false)

	self.m_ZombieHeading = vgui.Create("DTeamHeading", self)
	self.m_ZombieHeading:SetTeam(TEAM_UNDEAD)
	self.m_ZombieHeading:SetMouseInputEnabled(false)

	self.ZombieList = vgui.Create("DScrollPanel", self)
	self.ZombieList.Team = TEAM_UNDEAD
	self.ZombieList.Paint = function() return true end
	RelapseUI.StyleScroll(self.ZombieList)

	self.HumanList = vgui.Create("DScrollPanel", self)
	self.HumanList.Team = TEAM_HUMAN
	self.HumanList.Paint = function() return true end
	RelapseUI.StyleScroll(self.HumanList)
end

function PANEL:ApplyLayout()
	RelapseUI.CreateFonts()
	local L = RelapseUI.ScoreboardWindowSize()
	self.RelapseLayout = L
	local scrim = self.RelapseScrim
	if IsValid(scrim) then
		scrim:SetSize(ScrW(), ScrH())
		scrim:SetPos(0, 0)
	end
	self:SetSize(L.wid, L.hei)
	self:Center()
	for _, panel in pairs(self.PlayerPanels or {}) do
		if IsValid(panel) then
			panel:SetTall(L.rowH)
			panel:DockMargin(0, 0, 0, L.rowGap)
			panel:InvalidateLayout(true)
		end
	end
	self:InvalidateLayout(true)
end

function PANEL:PerformLayout()
	local L = self.RelapseLayout or RelapseUI.ScoreboardWindowSize()
	self.RelapseLayout = L
	local x = L.pad
	local y = L.headerh
	local listY = y + L.headingH + L.tabGap
	local listH = math.max(L.m.step, L.hei - listY - L.pad)

	self.HumanList:SetSize(L.listW, listH)
	self.HumanList:SetPos(x, listY)
	self.HumanList:InvalidateLayout(true)

	self.ZombieList:SetSize(L.listW, listH)
	self.ZombieList:SetPos(x + L.listW + L.colGap, listY)
	self.ZombieList:InvalidateLayout(true)

	local hx, hw = CardColumn(self.HumanList, L.colW, x)
	self.m_HumanHeading:SetSize(hw, L.headingH)
	self.m_HumanHeading:SetPos(hx, y)

	local zx, zw = CardColumn(self.ZombieList, L.colW, x + L.listW + L.colGap)
	self.m_ZombieHeading:SetSize(zw, L.headingH)
	self.m_ZombieHeading:SetPos(zx, y)

	RelapseUI.PlaceShopTitle(self.m_TitleLabel, L)
end

function PANEL:Paint(w, h)
	RelapseUI.PaintWindow(self, w, h)
	return true
end

function PANEL:PaintOver()
	local L = self.RelapseLayout
	if not L then return end
	local _, hy = self.m_HumanHeading:GetPos()
	local hx, hw = CardColumn(self.HumanList, L.colW, L.pad)
	PaintColCaps(hx, hy, hw, L.headingH, "hud_score")
	local _, zy = self.m_ZombieHeading:GetPos()
	local zx, zw = CardColumn(self.ZombieList, L.colW, L.pad + L.listW + L.colGap)
	PaintColCaps(zx, zy, zw, L.headingH, "hud_brains")
end

function PANEL:Think()
	if RealTime() >= self.NextRefresh then
		self.NextRefresh = RealTime() + self.RefreshTime
		self:RefreshScoreboard()
	end
end

function PANEL:GetPlayerPanel(pl)
	for _, panel in pairs(self.PlayerPanels) do
		if panel:IsValid() and panel:GetPlayer() == pl then
			return panel
		end
	end
end

function PANEL:CreatePlayerPanel(pl)
	local curpan = self:GetPlayerPanel(pl)
	if curpan and curpan:IsValid() then return curpan end
	if pl:Team() == TEAM_SPECTATOR then return end

	local L = self.RelapseLayout or RelapseUI.ScoreboardWindowSize()
	local panel = vgui.Create("ZSPlayerPanel", pl:Team() == TEAM_UNDEAD and self.ZombieList or self.HumanList)
	panel:SetTall(L.rowH)
	panel:Dock(TOP)
	panel:DockMargin(0, 0, 0, L.rowGap)
	panel:SetPlayer(pl)

	self.PlayerPanels[pl] = panel
	return panel
end

function PANEL:RefreshScoreboard()
	if self.PlayerPanels == nil then self.PlayerPanels = {} end

	for pl, panel in pairs(self.PlayerPanels) do
		if not panel:IsValid() or pl:IsValid() and pl:IsSpectator() then
			self:RemovePlayerPanel(panel)
		end
	end

	for _, pl in pairs(player.GetAllActive()) do
		self:CreatePlayerPanel(pl)
	end
end

function PANEL:RemovePlayerPanel(panel)
	if panel:IsValid() then
		self.PlayerPanels[panel:GetPlayer()] = nil
		panel:Remove()
	end
end

vgui.Register("ZSScoreBoard", PANEL, "Panel")

---------------------------------------------------------------------------
-- Player row
---------------------------------------------------------------------------

PANEL = {}

PANEL.RefreshTime = 1
PANEL.m_Player = NULL
PANEL.NextRefresh = 0

local function MuteDoClick(self)
	local pl = self:GetParent():GetPlayer()
	if pl:IsValid() then
		pl:SetMuted(not pl:IsMuted())
		self:GetParent().NextRefresh = RealTime()
	end
end

GM.ZSFriends = {}

local function ToggleZSFriend(self)
	if MySelf.LastFriendAdd and MySelf.LastFriendAdd + 2 > CurTime() then return end

	local pl = self:GetParent():GetPlayer()
	if pl:IsValid() then
		if GAMEMODE.ZSFriends[pl:SteamID()] then
			GAMEMODE.ZSFriends[pl:SteamID()] = nil
		else
			GAMEMODE.ZSFriends[pl:SteamID()] = true
		end

		self:GetParent().NextRefresh = RealTime()

		net.Start("zs_zsfriend")
			net.WriteString(pl:SteamID())
			net.WriteBool(GAMEMODE.ZSFriends[pl:SteamID()])
		net.SendToServer()

		MySelf.LastFriendAdd = CurTime()
	end
end

net.Receive("zs_zsfriendadded", function()
	local pl = net:ReadEntity()
	pl.ZSFriendAdded = net:ReadBool()
end)

local function AvatarDoClick(self)
	local pl = self.PlayerPanel:GetPlayer()
	if pl:IsValidPlayer() then
		pl:ShowProfile()
	end
end

function PANEL:Init()
	RelapseUI.CreateFonts()
	self:SetTall(RelapseUI.ScoreboardWindowSize().rowH)

	self.m_AvatarButton = self:Add("DButton", self)
	self.m_AvatarButton:SetText(" ")
	self.m_AvatarButton.DoClick = AvatarDoClick
	self.m_AvatarButton.PlayerPanel = self

	self.m_Avatar = vgui.Create("AvatarImage", self.m_AvatarButton)
	self.m_Avatar:SetVisible(false)
	self.m_Avatar:SetMouseInputEnabled(false)
	self.m_Avatar:SetPaintedManually(true)
	self.m_AvatarButton.Paint = function(me, w, h)
		local av = me.PlayerPanel and me.PlayerPanel.m_Avatar
		if not (IsValid(av) and av:IsVisible()) then return true end
		RelapseUI.MaskRound(RelapseUI.RadPx("Avatar"), w, h, function()
			av:PaintManual()
		end)
		return true
	end

	self.m_SpecialImage = vgui.Create("DImage", self)
	self.m_SpecialImage:SetMouseInputEnabled(true)
	self.m_SpecialImage:SetVisible(false)

	self.m_ClassImage = vgui.Create("DImage", self)
	self.m_ClassImage:SetMouseInputEnabled(false)
	self.m_ClassImage:SetVisible(false)

	self.m_PlayerLabel = EasyLabel(self, " ", "Relapse20", RelapseUI.Col.Text)
	self.m_ScoreLabel = EasyLabel(self, " ", "Relapse15", RelapseUI.Col.Text)
	self.m_RemortLabel = EasyLabel(self, " ", "Relapse15", RelapseUI.Col.Muted)
	self.m_RemortLabel:SetVisible(false)

	self.m_Mute = vgui.Create("DImageButton", self)
	if self.m_Mute.SetPaintBackground then
		self.m_Mute:SetPaintBackground(false)
	end
	self.m_Mute.DoClick = MuteDoClick

	self.m_Friend = vgui.Create("DImageButton", self)
	if self.m_Friend.SetPaintBackground then
		self.m_Friend:SetPaintBackground(false)
	end
	self.m_Friend.DoClick = ToggleZSFriend
end

function PANEL:Paint(w, h)
	local selected = false
	local hovered = self.Hovered
	local pl = self:GetPlayer()
	if pl:IsValid() then
		selected = pl == MySelf
		if self.m_Flash then
			self.Hovered = hovered or math.abs(math.sin(RealTime() * 6)) > 0.35
		end
	end
	RelapseUI.PaintCard(self, w, h, selected)
	self.Hovered = hovered
	if pl:IsValid() and pl:Team() == TEAM_HUMAN then
		local classA, classB = GAMEMODE:GetPlayerTabClasses(pl)
		PaintClassSplit(0, h * 0.5, RowMetrics(w).remortLeft, classA, classB)
	end
	return true
end

function PANEL:DoClick()
	local pl = self:GetPlayer()
	if pl:IsValid() then
		gamemode.Call("ClickedPlayerButton", pl, self)
	end
end

function PANEL:PerformLayout()
	local L = RelapseUI.ScoreboardWindowSize()
	self:SetTall(L.rowH)
	local w, h = self:GetWide(), L.rowH
	local met = RowMetrics(w)

	self.m_AvatarButton:SetSize(met.avatar, met.avatar)
	self.m_AvatarButton:SetPos(met.pad, met.pad)
	self.m_Avatar:SetSize(met.avatar, met.avatar)
	self.m_Avatar:SetPos(0, 0)

	self.m_PlayerLabel:SetPos(met.nameX, 0)
	self.m_PlayerLabel:SetSize(met.nameW, h)
	self.m_PlayerLabel:SetContentAlignment(4)

	self.m_ScoreLabel:SizeToContents()
	self.m_ScoreLabel:SetPos(
		ScoreLabelX(self.m_ScoreLabel:GetText(), met.scoreRight, ScoreCapKey(self:GetPlayer())),
		math.floor((h - self.m_ScoreLabel:GetTall()) * 0.5)
	)

	local remort = self.m_RemortLabel
	local remortText = remort:GetText() or ""
	if remortText == "" or remortText == " " then
		remort:SetVisible(false)
	else
		remort:SetVisible(true)
		remort:SetTextColor(RelapseUI.Col.Muted)
		surface.SetFont("Relapse20")
		local nickW, nickH = surface.GetTextSize(self.m_PlayerLabel:GetText() or "")
		if not nickH or nickH < 1 then
			nickH = RelapseUI.sPx(20)
		end
		surface.SetFont("Relapse15")
		local remortW, remortH = surface.GetTextSize(remortText)
		if not remortH or remortH < 1 then
			remortH = RelapseUI.sPx(15)
		end
		local nickY = math.floor((h - nickH) * 0.5)
		remort:SetSize(remortW, remortH)
		remort:SetContentAlignment(4)
		remort:SetPos(met.nameX + nickW + RelapseUI.sPx(15), nickY + nickH - remortH - RelapseUI.sPx(1))
	end

	self.m_ClassImage:SetSize(met.class, met.class)
	self.m_ClassImage:SetPos(met.classX, math.floor((h - met.class) * 0.5))

	self.m_SpecialImage:SetSize(met.icon, met.icon)
	self.m_SpecialImage:SetPos(met.pad + met.avatar - met.icon, met.pad + met.avatar - met.icon)

	if IsValid(self.m_PingMeter) then
		self.m_PingMeter:Remove()
		self.m_PingMeter = nil
	end

	self.m_Mute:SetSize(met.icon, met.icon)
	self.m_Mute:SetPos(met.muteX, math.floor((h - met.icon) * 0.5))

	self.m_Friend:SetSize(met.icon, met.icon)
	self.m_Friend:SetPos(met.friendX, math.floor((h - met.icon) * 0.5))
end

function PANEL:RefreshPlayer()
	local pl = self:GetPlayer()
	if not pl:IsValid() then
		self:Remove()
		return
	end

	local met = RowMetrics(self:GetWide())
	local remortText = RemortCaption(pl)
	local nameMax = met.nameW
	if remortText ~= "" then
		surface.SetFont("Relapse15")
		local remortW = surface.GetTextSize(remortText)
		nameMax = math.max(RelapseUI.Grid15(), met.nameW - RelapseUI.sPx(15) - remortW)
	end
	self.m_PlayerLabel:SetText(Ellipsize(pl:Name(), "Relapse20", nameMax))
	self.m_PlayerLabel:SetTextColor(RelapseUI.Col.Text)

	if pl:Team() == TEAM_HUMAN then
		self.m_ScoreLabel:SetText(math.floor(pl:GetPoints()) .. " / " .. pl:Frags())
	else
		self.m_ScoreLabel:SetText(tostring(pl:Frags()))
	end
	self.m_ScoreLabel:SetTextColor(RelapseUI.Col.Text)

	self.m_RemortLabel:SetText(remortText)
	self.m_RemortLabel:SetTextColor(RelapseUI.Col.Muted)
	self.m_RemortLabel:SetVisible(remortText ~= "")

	if IsValid(MySelf) and MySelf:Team() == TEAM_UNDEAD and pl:Team() == TEAM_UNDEAD and pl:GetZombieClassTable().Icon then
		self.m_ClassImage:SetVisible(true)
		self.m_ClassImage:SetImage(pl:GetZombieClassTable().Icon)
		self.m_ClassImage:SetImageColor(pl:GetZombieClassTable().IconColor or RelapseUI.Col.Text)
	else
		self.m_ClassImage:SetVisible(false)
	end

	local ink = RelapseUI.Col.Muted
	if pl == MySelf then
		self.m_Mute:SetVisible(false)
		self.m_Friend:SetVisible(false)
	else
		self.m_Mute:SetVisible(true)
		self.m_Friend:SetVisible(true)
		if pl:IsMuted() then
			self.m_Mute:SetImage("icon16/sound_mute.png")
			self.m_Mute:SetColor(RelapseUI.Col.Danger)
		else
			self.m_Mute:SetImage("icon16/sound.png")
			self.m_Mute:SetColor(ink)
		end

		self.m_Friend:SetColor(pl.ZSFriendAdded and RelapseUI.Col.Text or ink)
		self.m_Friend:SetImage(GAMEMODE.ZSFriends[pl:SteamID()] and "icon16/heart_delete.png" or "icon16/heart.png")
	end

	self:SetZPos(-pl:Frags())

	if pl:Team() ~= self._LastTeam then
		self._LastTeam = pl:Team()
		local L = RelapseUI.ScoreboardWindowSize()
		self:SetParent(self._LastTeam == TEAM_HUMAN and ScoreBoard.HumanList or ScoreBoard.ZombieList)
		self:SetTall(L.rowH)
		self:Dock(TOP)
		self:DockMargin(0, 0, 0, L.rowGap)
	end

	self:InvalidateLayout()
end

function PANEL:Think()
	if RealTime() >= self.NextRefresh then
		self.NextRefresh = RealTime() + self.RefreshTime
		self:RefreshPlayer()
	end
end

function PANEL:SetPlayer(pl)
	self.m_Player = pl or NULL

	if pl:IsValidPlayer() then
		self.m_Avatar:SetPlayer(pl)
		self.m_Avatar:SetVisible(true)

		if gamemode.Call("IsSpecialPerson", pl, self.m_SpecialImage) then
			self.m_SpecialImage:SetVisible(true)
		else
			self.m_SpecialImage:SetTooltip()
			self.m_SpecialImage:SetVisible(false)
		end

		self.m_Flash = pl:SteamID() == "STEAM_0:1:3307510"
	else
		self.m_Avatar:SetVisible(false)
		self.m_SpecialImage:SetVisible(false)
	end

	self:RefreshPlayer()
end

function PANEL:GetPlayer()
	return self.m_Player
end

vgui.Register("ZSPlayerPanel", PANEL, "Button")
