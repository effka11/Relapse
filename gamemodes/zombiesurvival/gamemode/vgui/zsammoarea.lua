local PANEL = {}

-- Scratch buffer for HealthCol. Colours come from sh_relapse_theme.lua.
local colAmmo = Color(0, 0, 0, 255)

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
	local step = RelapseUI.Grid15()
	local fine = RelapseUI.Grid5()

	self.LerpClip = Lerp(FrameTime() * 12, self.LerpClip or clip, clip)
	self.LerpSpare = Lerp(FrameTime() * 12, self.LerpSpare or spare, spare)

	local clipstr = tostring(math.Round(self.LerpClip))
	local sparestr = tostring(math.Round(self.LerpSpare))
	local capstr = tostring(maxclip)

	local frac = math.Clamp(clip / maxclip, 0, 1)
	local clipcol = RelapseUI.HealthCol(frac, colAmmo)
	local colMuted = RelapseUI.Col.Muted

	if infinite then
		RelapseUI.HudText(clipstr, "Relapse64", rx, y, clipcol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)
		return true
	end

	surface.SetFont("Relapse32")
	local spareW = surface.GetTextSize(sparestr)
	local capW = surface.GetTextSize(capstr)
	local threeDigitW = surface.GetTextSize("000")
	local colW = math.max(capW, step * 2)
	colW = math.ceil(colW / step) * step

	-- Fixed three-digit reserve column: short values grow right, without moving
	-- the clip/capacity block. Its far edge mirrors the health HUD inset.
	local spareColW = math.ceil(math.max(spareW, threeDigitW) / step) * step
	local spareLeft = rx - spareColW
	local capRight = spareLeft - step * 2
	local clipRight = capRight - colW - step
	RelapseUI.HudText(clipstr, "Relapse64", clipRight, y, clipcol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)
	RelapseUI.HudText(capstr, "Relapse32", capRight, y, colMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)

	local spareY = y - step * 3
	RelapseUI.HudText(sparestr, "Relapse32", spareLeft, spareY, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 4)

	-- \ on the first digit's bottom-left. Slightly longer than one 15-cell.
	local span = step + fine
	local hx = math.floor(spareLeft - span + 0.5)
	local hy = math.floor(spareY - span + fine * 2 + 0.5)
	RelapseUI.PaintHudDiagHair(hx, hy, span, colMuted, RelapseUI.sPx(1), 1)

	return true
end

vgui.Register("ZSAmmoArea", PANEL, "Panel")
