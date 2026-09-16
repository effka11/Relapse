local PANEL = {}

-- Scratch buffer for HealthCol. Colours come from sh_relapse_theme.lua.
local colAmmo = Color(0, 0, 0, 255)

-- Hammer nails: one pool, no magazine. Relapse64 in the spare corner (same as infinite mag).
local function PoolAmmo(wep)
	if not wep.RelapsePoolAmmo or GetGlobalBool("classicmode") then return end

	local n = wep.GetPrimaryAmmoCount and wep:GetPrimaryAmmoCount() or 0
	local maxn = wep.Primary and wep.Primary.DefaultClip or 16
	if not maxn or maxn < 1 then maxn = 16 end
	return math.max(n, 0), maxn, 0, true
end

local function AmmoCounts(lp)
	if not lp:IsValid() or not lp:Alive() or lp:Team() ~= TEAM_HUMAN then return end

	local wep = lp:GetActiveWeapon()
	if not wep:IsValid() then return end
	if wep.IsMelee then
		return PoolAmmo(wep)
	end

	local ammotype = wep.ValidPrimaryAmmo and wep:ValidPrimaryAmmo()
	local primary = wep.Primary
	if (not ammotype or not primary) and weapons.GetStored then
		local stored = weapons.GetStored(wep:GetClass())
		if stored and stored.Primary then
			primary = primary or stored.Primary
			ammotype = ammotype or stored.Primary.Ammo
		end
	end
	if not ammotype or not primary then return end

	local clip = wep:Clip1()
	local spare = lp:GetAmmoCount(ammotype)
	local maxclip = primary.ClipSize or 0
	if GAMEMODE.GetReconnectAmmoDisplay then
		clip, spare = GAMEMODE:GetReconnectAmmoDisplay(wep, clip, spare, ammotype)
	end
	if wep.GetDisplayAmmo then
		clip, spare, maxclip = wep:GetDisplayAmmo(clip, spare, maxclip)
	end

	if (not maxclip or maxclip < 1) and weapons.GetStored then
		local stored = weapons.GetStored(wep:GetClass())
		maxclip = stored and stored.Primary and stored.Primary.ClipSize or maxclip
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
	-- 90 at 1080p: spare's right and bottom edges sit 6 cells in from the screen.
	local margin = RelapseUI.Grid15(6)
	self:SetSize(RelapseUI.Cells(32), RelapseUI.Cells(13))
	self:AlignRight(margin)
	self:AlignBottom(margin)
end

function PANEL:Paint(w, h)
	local lp = MySelf
	if not lp:IsValid() then return true end

	local clip, maxclip, spare, infinite = AmmoCounts(lp)
	if not clip or maxclip < 1 then return true end

	RelapseUI.CreateFonts()
	local rx = w

	self.LerpClip = Lerp(FrameTime() * 12, self.LerpClip or clip, clip)
	self.LerpSpare = Lerp(FrameTime() * 12, self.LerpSpare or spare, spare)
	if self.SnapAmmo then
		self.LerpClip = clip
		self.LerpSpare = spare
		self.SnapAmmo = nil
	end

	local clipstr = tostring(math.Round(self.LerpClip))
	local sparestr = tostring(math.Round(self.LerpSpare))

	local frac = math.Clamp(clip / maxclip, 0, 1)
	local clipcol = RelapseUI.HealthCol(frac, colAmmo)

	-- Shadow is 120° (down-right). Spare sits on the panel's right edge; don't clip it.
	DisableClipping(true)
	surface.DisableClipping(true)

	surface.SetFont("Relapse64")
	local _, clipH = surface.GetTextSize(clipstr)
	local _, clipRsb, clipBelow = RelapseUI.ManropeDigitEdges(clipstr, clipH, true)

	if infinite then
		RelapseUI.HudText(clipstr, "Relapse64", rx, h + clipBelow, clipcol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)
		local sx = select(1, self:LocalToScreen(rx, 0))
		self.ClipRightScreen = sx
		surface.DisableClipping(false)
		DisableClipping(false)
		return true
	end

	-- Gaps are ink-to-ink: 45px spare-left to clip-right, 15px clip-bottom above spare-bottom.
	surface.SetFont("Relapse32")
	local spareW, spareH = surface.GetTextSize(sparestr)
	local spareLsb, _, spareBelow = RelapseUI.ManropeDigitEdges(sparestr, spareH, false)
	local clipRight = rx - spareW - RelapseUI.sPx(45) + spareLsb + clipRsb
	RelapseUI.HudText(clipstr, "Relapse64", clipRight, h - RelapseUI.sPx(15) + clipBelow, clipcol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)
	RelapseUI.HudText(sparestr, "Relapse32", rx, h + spareBelow, RelapseUI.Col.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)
	local sx = select(1, self:LocalToScreen(clipRight, 0))
	self.ClipRightScreen = sx

	surface.DisableClipping(false)
	DisableClipping(false)
	return true
end

vgui.Register("ZSAmmoArea", PANEL, "Panel")
