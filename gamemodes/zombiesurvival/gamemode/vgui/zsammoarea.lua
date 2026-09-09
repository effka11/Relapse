local PANEL = {}

local colAmmo = Color(184, 156, 108, 255)
local colCap = Color(160, 154, 146, 255)
local colSpare = Color(160, 154, 146, 255)
local colStripe = Color(236, 232, 224, 255)

local function AmmoCounts(lp)
	if not lp:IsValid() or not lp:Alive() or lp:Team() ~= TEAM_HUMAN then return end

	local wep = lp:GetActiveWeapon()
	if not wep:IsValid() or wep.IsMelee then return end

	local ammotype = wep.ValidPrimaryAmmo and wep:ValidPrimaryAmmo()
	if not ammotype then return end

	local primary = wep.Primary
	if not primary then return end

	local clip = wep:Clip1()
	local spare = lp:GetAmmoCount(ammotype)
	local maxclip = primary.ClipSize or 0
	if wep.GetDisplayAmmo then
		clip, spare, maxclip = wep:GetDisplayAmmo(clip, spare, maxclip)
	end

	clip = math.max(clip or 0, 0)
	spare = math.max(spare or 0, 0)
	maxclip = maxclip or 0

	local infinite = primary.DefaultClip == 99999
	return clip, maxclip, spare, infinite
end

function PANEL:Init()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:InvalidateLayout()
end

function PANEL:PerformLayout()
	RelapseUI.CreateFonts()
	local inset = RelapseUI.HudInset()
	self:SetSize(RelapseUI.Cells(32), RelapseUI.Cells(13))
	self:AlignRight(inset)
	self:AlignBottom(inset)
end

function PANEL:Paint(w, h)
	local lp = MySelf
	if not lp:IsValid() then return true end

	local clip, maxclip, spare, infinite = AmmoCounts(lp)
	if not clip or maxclip < 1 then return true end

	RelapseUI.CreateFonts()
	local pad = RelapseUI.sPx(8)
	local y = h - pad - RelapseUI.sPx(4) - RelapseUI.sPx(10) - RelapseUI.sPx(10)
	local rx = w - pad

	self.LerpClip = Lerp(FrameTime() * 12, self.LerpClip or clip, clip)

	local frac = math.Clamp(clip / maxclip, 0, 1)
	local col = RelapseUI.HealthCol(frac, colAmmo)
	local clipstr = tostring(math.Round(self.LerpClip))
	local suffix = "/" .. tostring(maxclip)

	colCap.r, colCap.g, colCap.b = RelapseUI.Col.Muted.r, RelapseUI.Col.Muted.g, RelapseUI.Col.Muted.b
	surface.SetFont("Relapse32")
	local sw = select(1, surface.GetTextSize(suffix))
	surface.SetFont("Relapse64")
	local _, ch = surface.GetTextSize(clipstr)

	RelapseUI.HudText(suffix, "Relapse32", rx, y, colCap, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)
	RelapseUI.HudText(clipstr, "Relapse64", rx - sw, y, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)

	if not infinite then
		local span = RelapseUI.Grid15(4)
		local thick = math.max(2, RelapseUI.sPx(2))
		local ox = rx - span
		local oy = y - ch

		colStripe.r, colStripe.g, colStripe.b = RelapseUI.Col.Muted.r, RelapseUI.Col.Muted.g, RelapseUI.Col.Muted.b
		colStripe.a = 255
		RelapseUI.PaintHudDiagBand(ox, oy, span, thick, colStripe, 2)

		self.LerpSpare = Lerp(FrameTime() * 12, self.LerpSpare or spare, spare)
		if spare <= 0 then
			colSpare.r, colSpare.g, colSpare.b = RelapseUI.Col.Danger.r, RelapseUI.Col.Danger.g, RelapseUI.Col.Danger.b
		else
			colSpare.r, colSpare.g, colSpare.b = RelapseUI.Col.Muted.r, RelapseUI.Col.Muted.g, RelapseUI.Col.Muted.b
		end

		RelapseUI.HudText(tostring(math.Round(self.LerpSpare)), "Relapse32", rx, oy, colSpare, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 4)
	end

	return true
end

vgui.Register("ZSAmmoArea", PANEL, "Panel")
