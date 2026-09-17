-- Relapse loadout HUD: 1-9 slot cards, bottom center.
-- Hidden until a slot is chosen; fades in, holds, fades out.

local SLOT_MAX = 9
local HOLD = 3

local PANEL = {}

---------------------------------------------------------------------------
-- Slot paint
---------------------------------------------------------------------------

local function PaintSlot(self, w, h)
	local host = self:GetParent()
	local fade = (IsValid(host) and host:GetAlpha() or self:GetAlpha()) / 255
	if fade <= 0 then return true end

	surface.SetAlphaMultiplier(fade)
	RelapseUI.PaintCard(self, w, h, self.Selected, false, false)

	local mat = self.IconMat
	if mat and not mat:IsError() then
		RelapseUI.DrawInvSlotIcon(mat, w, h, RelapseUI.Col.Text, self.ItemClass)
	end

	RelapseUI.DrawInvSlotIndex(w, h, self.SlotIndex)
	surface.SetAlphaMultiplier(1)
	return true
end

local function SetSlotClass(slot, class)
	slot.ItemClass = class
	local path = class and RelapseUI.CardIconPath({ SWEP = class }) or nil
	if path ~= slot.IconPath then
		slot.IconPath = path
		slot.IconMat = path and Material(path, "smooth") or nil
	end
end

local function HeldClass()
	local lp = MySelf
	if not IsValid(lp) then return nil end
	local wep = lp:GetActiveWeapon()
	if not IsValid(wep) then return nil end
	local class = wep:GetClass()
	if GAMEMODE.IsHumanUnarmedWeapon and GAMEMODE:IsHumanUnarmedWeapon(class) then
		return nil
	end
	return class
end

function PANEL:Init()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:SetPaintBackgroundEnabled(false)
	self:ParentToHUD()
	self:SetAlpha(0)

	self.Slots = {}
	self.VisibleCount = 1
	self.HoldUntil = 0
	for i = 1, SLOT_MAX do
		local slot = vgui.Create("Panel", self)
		slot:SetMouseInputEnabled(false)
		slot:SetPaintBackgroundEnabled(false)
		slot.SlotIndex = i
		slot.Paint = PaintSlot
		slot:SetVisible(i == 1)
		self.Slots[i] = slot
	end

	self:ApplyLoadout()
end

function PANEL:CanShow()
	local lp = MySelf
	return IsValid(lp) and lp:Alive() and lp:Team() == TEAM_HUMAN and not (GAMEMODE and GAMEMODE.FilmMode)
end

function PANEL:Pulse()
	if not self:CanShow() then return end
	if GAMEMODE and GAMEMODE.InventoryMenu and GAMEMODE.InventoryMenu:IsValid() and GAMEMODE.InventoryMenu:IsVisible() then return end
	self:SetVisible(true)
	self.HoldUntil = RealTime() + HOLD
	RelapseUI.PlayFade(self, 255, RelapseUI.Duration(4), RelapseUI.EaseOut)
end

function PANEL:ApplyLoadout()
	RelapseUI.CreateFonts()
	local gm = GAMEMODE
	local list = (gm and gm.RelapseLoadout) or {}
	local n = gm and gm.RelapseLoadoutBarCount and gm:RelapseLoadoutBarCount(list) or math.max(1, math.min(SLOT_MAX, #list))
	local held = HeldClass()

	if n ~= self.VisibleCount then
		self.VisibleCount = n
		self:InvalidateLayout()
	end

	for i, slot in ipairs(self.Slots) do
		local show = i <= n
		if slot:IsVisible() ~= show then
			slot:SetVisible(show)
		end
		if show then
			SetSlotClass(slot, list[i])
			slot.Selected = list[i] ~= nil and list[i] == held
		end
	end
end

function PANEL:PerformLayout()
	RelapseUI.CreateFonts()
	local size = RelapseUI.Grid15(4)
	local gap = RelapseUI.Grid15()
	local n = self.VisibleCount or 1
	local w = n * size + math.max(0, n - 1) * gap
	self:SetSize(w, size)
	self:CenterHorizontal()
	self:AlignBottom(RelapseUI.Grid15(3))

	for i, slot in ipairs(self.Slots) do
		slot:SetSize(size, size)
		slot:SetPos((i - 1) * (size + gap), 0)
	end
end

function PANEL:Think()
	local altOpen = GAMEMODE and GAMEMODE.InventoryMenu and GAMEMODE.InventoryMenu:IsValid() and GAMEMODE.InventoryMenu:IsVisible()
	if altOpen or not self:CanShow() then
		self.HoldUntil = 0
		if self:GetAlpha() > 0 then
			self:SetAlpha(0)
		end
	elseif (self.HoldUntil or 0) > 0 and RealTime() >= self.HoldUntil then
		self.HoldUntil = 0
		RelapseUI.PlayFade(self, 0, RelapseUI.Duration(8), RelapseUI.EaseIn)
	end

	local gm = GAMEMODE
	local list = (gm and gm.RelapseLoadout) or {}
	local n = gm and gm.RelapseLoadoutBarCount and gm:RelapseLoadoutBarCount(list) or 1
	if n ~= self.VisibleCount then
		self:ApplyLoadout()
	else
		local held = HeldClass()
		for i = 1, n do
			local slot = self.Slots[i]
			if slot then
				slot.Selected = list[i] ~= nil and list[i] == held
			end
		end
	end
end

function PANEL:Paint()
	return true
end

vgui.Register("ZSInvArea", PANEL, "Panel")
