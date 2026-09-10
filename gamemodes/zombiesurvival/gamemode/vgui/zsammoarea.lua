local PANEL = {}

-- Scratch buffer for HealthCol. Colours come from sh_relapse_theme.lua.
local colAmmo = Color(0, 0, 0, 255)

local function AmmoCounts(lp)
	if not lp:IsValid() or not lp:Alive() or lp:Team() ~= TEAM_HUMAN then return end

	local wep = lp:GetActiveWeapon()
	if not wep:IsValid() or wep.IsMelee then return end

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
	-- Relapse32 cell sits ~6px above lining figures; y is the glyph bottom, not the em-box.
	local y = h + RelapseUI.sPx(6)
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

	if infinite then
		RelapseUI.HudText(clipstr, "Relapse64", rx, y, clipcol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)
		surface.DisableClipping(false)
		DisableClipping(false)
		return true
	end

	-- Spare: Relapse32. Clip bottom sits 15px above spare bottom; 45px from spare's left to clip's right.
	surface.SetFont("Relapse32")
	local spareW = surface.GetTextSize(sparestr)
	local clipRight = rx - spareW - RelapseUI.sPx(45)
	RelapseUI.HudText(clipstr, "Relapse64", clipRight, y - RelapseUI.sPx(15), clipcol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)
	RelapseUI.HudText(sparestr, "Relapse32", rx, y, RelapseUI.Col.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 4)

	surface.DisableClipping(false)
	DisableClipping(false)
	return true
end

vgui.Register("ZSAmmoArea", PANEL, "Panel")
