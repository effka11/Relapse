-- Relapse team heading for the TAB scoreboard.
-- Name + live count only; column captions are painted by the board.

local PANEL = {}
PANEL.m_Team = 0

function PANEL:Init()
	if self.SetPaintBackground then
		self:SetPaintBackground(false)
	end
end

function PANEL:Paint(w, h)
	local teamid = self:GetTeam()
	local name = teamid == TEAM_UNDEAD and RelapseUI.T("hud_undead") or RelapseUI.T("hud_humans")
	local c = RelapseUI.Col
	surface.SetFont("Relapse25")
	local _, tabCell = surface.GetTextSize("Ay")
	if not tabCell or tabCell < 1 then
		tabCell = RelapseUI.sPx(25)
	end
	local yNum = math.ceil((h - tabCell) * 0.5)
	local label = name .. ":"
	-- Caps and lining figures share the baseline, same as HUD points.
	local labY = RelapseUI.ManropeBaseline(yNum, RelapseUI.sPx(25)) - RelapseUI.ManropeBaseline(0, RelapseUI.sPx(20))
	draw.SimpleText(label, "Relapse20", 0, labY, c.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	surface.SetFont("Relapse20")
	local nw = surface.GetTextSize(label)
	draw.SimpleText(tostring(team.NumPlayers(teamid)), "Relapse25", nw + RelapseUI.Grid15(), yNum - RelapseUI.sPx(1), c.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	return true
end

function PANEL:SetTeam(teamid)
	self.m_Team = teamid
end

function PANEL:GetTeam()
	return self.m_Team
end

vgui.Register("DTeamHeading", PANEL, "DPanel")
