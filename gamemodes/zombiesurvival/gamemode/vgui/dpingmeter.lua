-- Relapse ping figure for TAB rows.
-- Fog when the line is clean, wine when it is dying. No Source bars.

local PANEL = {}

PANEL.IdealPing = 50
PANEL.MaxPing = 400
PANEL.RefreshTime = 1
PANEL.PingBars = 5

PANEL.m_Player = NULL
PANEL.m_Ping = 0
PANEL.NextRefresh = 0

local colPing = Color(0, 0, 0, 255)

function PANEL:Paint(w, h)
	local ping = self:GetPing()
	local span = math.max(1, self.MaxPing - self.IdealPing)
	local q = 1 - math.Clamp((ping - self.IdealPing) / span, 0, 1)
	RelapseUI.HealthCol(q, colPing)
	draw.SimpleText(tostring(ping), "Relapse15", w, h * 0.5, colPing, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	return true
end

function PANEL:RefreshContents()
	local pl = self:GetPlayer()
	if pl:IsValid() then
		self:SetPing(pl:Ping())
	else
		self:SetPing(0)
	end
end

function PANEL:Think()
	if RealTime() >= self.NextRefresh then
		self.NextRefresh = RealTime() + self.RefreshTime
		self:RefreshContents()
	end
end

function PANEL:SetPlayer(pl)
	self.m_Player = pl or NULL
	self:RefreshContents()
end

function PANEL:GetPlayer()
	return self.m_Player
end

function PANEL:SetPing(ping)
	self.m_Ping = ping
end

function PANEL:GetPing()
	return self.m_Ping
end

vgui.Register("DPingMeter", PANEL, "Panel")
