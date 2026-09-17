GM.ZSInventory = {}
GM.RelapseBag = GM.RelapseBag or {}

INVCAT_TRINKETS = 1
INVCAT_COMPONENTS = 2
INVCAT_CONSUMABLES = 3

local meta = FindMetaTable("Player")
function meta:GetInventoryItems()
	return GAMEMODE.ZSInventory
end

function meta:HasInventoryItem(item)
	return GAMEMODE.ZSInventory[item] and GAMEMODE.ZSInventory[item] > 0
end

net.Receive("zs_inventoryitem", function()
	local item = net.ReadString()
	local count = net.ReadInt(5)
	GAMEMODE.ZSInventory[item] = count

	if GAMEMODE.RefreshRelapseGameInv then
		GAMEMODE:RefreshRelapseGameInv()
	end

	if MySelf and MySelf:IsValid() then
		MySelf:ApplyTrinkets()
	end
end)

net.Receive("zs_wipeinventory", function()
	GAMEMODE.ZSInventory = {}

	if GAMEMODE.RefreshRelapseGameInv then
		GAMEMODE:RefreshRelapseGameInv()
	end

	MySelf:ApplyTrinkets()
end)

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------

local function BagCount(entry)
	if not entry then return 0 end
	if entry.t == "inv" then
		return GAMEMODE.ZSInventory[entry.id] or 0
	end
	if entry.t == "ammo" then
		if not IsValid(MySelf) then return 0 end
		return MySelf:GetAmmoCount(entry.id) or 0
	end
	return 1
end

local function ItemName(entry)
	if not entry then return "" end
	if entry.t == "inv" then
		local data = GAMEMODE.ZSInventoryItemData[entry.id]
		return data and data.PrintName or entry.id
	end
	if entry.t == "ammo" then
		return RelapseUI.ShopAmmo(entry.id)
	end
	local wep = weapons.Get(entry.id)
	if wep then
		return RelapseUI.WepName(wep)
	end
	return entry.id
end

local function ItemDesc(entry)
	if not entry then return "" end
	if entry.t == "inv" then
		local data = GAMEMODE.ZSInventoryItemData[entry.id]
		return data and data.Description or ""
	end
	if entry.t == "ammo" then
		return ""
	end
	local wep = weapons.Get(entry.id)
	if not wep then return "" end
	local desc = RelapseUI.WepDesc(wep)
	if wep.NoDismantle then
		desc = desc .. "\n" .. RelapseUI.T("shop_cannot_dismantle")
	end
	return desc
end

local function IconPath(entry)
	if not entry then return nil end
	if entry.t == "wep" then
		return RelapseUI.CardIconPath({ SWEP = entry.id })
	end
	if entry.t == "ammo" then
		local id = GAMEMODE.RelapseInvAmmoId and GAMEMODE:RelapseInvAmmoId(entry.id) or string.lower(entry.id or "")
		return RelapseUI.AmmoIconPath(id)
	end
	local cat = GAMEMODE:GetInventoryItemType(entry.id)
	local kitbl = killicon.Get(cat == INVCAT_TRINKETS and "weapon_zs_trinket" or "weapon_zs_craftables")
	if istable(kitbl) and #kitbl == 2 and isstring(kitbl[1]) then
		return kitbl[1]
	end
end

local function SlotEntry(zone, index)
	if zone == GAMEMODE.RelapseInvZoneHot then
		local id = GAMEMODE.RelapseLoadout and GAMEMODE.RelapseLoadout[index]
		if isstring(id) and id ~= "" then
			return { t = "wep", id = id }
		end
		return nil
	end
	return GAMEMODE.RelapseBag and GAMEMODE.RelapseBag[index]
end

local function SetSlotEntry(zone, index, entry)
	if zone == GAMEMODE.RelapseInvZoneHot then
		GAMEMODE.RelapseLoadout = GAMEMODE.RelapseLoadout or {}
		GAMEMODE.RelapseLoadout[index] = (entry and entry.t == "wep" and entry.id) or nil
		return
	end
	GAMEMODE.RelapseBag = GAMEMODE.RelapseBag or {}
	GAMEMODE.RelapseBag[index] = entry
end

---------------------------------------------------------------------------
-- Drag
---------------------------------------------------------------------------

local Drag

local function DragGhostPaint(self, w, h)
	RelapseUI.PaintCard(self, w, h, true, false, false)
	local mat = self.IconMat
	if mat and not mat:IsError() then
		RelapseUI.DrawInvSlotIcon(mat, w, h, RelapseUI.Col.Text, self.ItemId)
	end
	return true
end

local function StopDrag()
	if Drag and IsValid(Drag.Ghost) then
		Drag.Ghost:Remove()
	end
	if Drag and IsValid(Drag.Slot) then
		Drag.Slot:MouseCapture(false)
	end
	Drag = nil
end

local function SlotAtCursor(frame)
	if not IsValid(frame) then return end
	local mx, my = gui.MousePos()
	local function hit(list)
		for _, slot in ipairs(list or {}) do
			if IsValid(slot) then
				local x, y = slot:LocalToScreen(0, 0)
				if mx >= x and my >= y and mx < x + slot:GetWide() and my < y + slot:GetTall() then
					return slot
				end
			end
		end
	end
	return hit(frame.BagSlots) or hit(frame.HotSlots)
end

---------------------------------------------------------------------------
-- Slot
---------------------------------------------------------------------------

local SLOT = {}

function SLOT:Init()
	self:SetText("")
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function SLOT:ApplySchemeSettings()
end

function SLOT:SetSlot(zone, index, numbered)
	self.Zone = zone
	self.Index = index
	self.Numbered = numbered and true or false
end

function SLOT:ApplyEntry(entry)
	self.Entry = entry
	self.ItemId = entry and entry.id or nil
	self.Kind = entry and entry.t or nil
	local path = IconPath(entry)
	if path ~= self.IconPath then
		self.IconPath = path
		self.IconMat = path and Material(path, "smooth") or nil
	end
	self.Count = BagCount(entry)
end

function SLOT:Paint(w, h)
	RelapseUI.PaintCard(self, w, h, self.On or (Drag and Drag.Hover == self), false, false)

	local mat = self.IconMat
	if mat and not mat:IsError() then
		RelapseUI.DrawInvSlotIcon(mat, w, h, RelapseUI.Col.Text, self.ItemId)
	end

	local pad = RelapseUI.sPx(5)
	if self.Numbered then
		RelapseUI.DrawInvSlotIndex(w, h, self.Index)
	end
	local showCount = self.Count and ((self.Kind == "ammo" and self.Count > 0) or self.Count > 1)
	if showCount then
		draw.SimpleText(tostring(self.Count), "Relapse15", w - pad, h - pad, RelapseUI.Col.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end
	return true
end

function SLOT:OnMousePressed(mc)
	if mc ~= MOUSE_LEFT then return end
	if not self.Entry then
		GAMEMODE:SelectRelapseGameInv(nil)
		return
	end
	Drag = {
		Slot = self,
		Zone = self.Zone,
		Index = self.Index,
		Entry = self.Entry,
		SX = gui.MouseX(),
		SY = gui.MouseY(),
		Moved = false
	}
	self:MouseCapture(true)
end

function SLOT:Think()
	if self.Kind == "ammo" and self.ItemId and IsValid(MySelf) then
		self.Count = MySelf:GetAmmoCount(self.ItemId) or 0
	end
	if not Drag or Drag.Slot ~= self then return end
	local dx = math.abs(gui.MouseX() - Drag.SX)
	local dy = math.abs(gui.MouseY() - Drag.SY)
	if not Drag.Moved and (dx >= RelapseUI.Grid5() or dy >= RelapseUI.Grid5()) then
		Drag.Moved = true
		local ghost = vgui.Create("DPanel")
		ghost:SetSize(self:GetSize())
		ghost:SetMouseInputEnabled(false)
		ghost:SetKeyboardInputEnabled(false)
		ghost:SetPaintBackground(false)
		ghost:SetDrawOnTop(true)
		ghost.IconMat = self.IconMat
		ghost.ItemId = self.ItemId
		ghost.Paint = DragGhostPaint
		Drag.Ghost = ghost
	end
	if Drag.Ghost and IsValid(Drag.Ghost) then
		local cell = Drag.Ghost:GetWide()
		Drag.Ghost:SetPos(gui.MouseX() - cell * 0.5, gui.MouseY() - cell * 0.5)
	end
	Drag.Hover = SlotAtCursor(GAMEMODE.InventoryMenu)
end

function SLOT:OnMouseReleased(mc)
	if mc ~= MOUSE_LEFT then return end
	self:MouseCapture(false)
	if not Drag or Drag.Slot ~= self then return end

	local moved = Drag.Moved
	local frame = GAMEMODE.InventoryMenu
	local dest = SlotAtCursor(frame)
	StopDrag()

	if moved and dest and (dest.Zone ~= self.Zone or dest.Index ~= self.Index) then
		GAMEMODE:RelapseGameInvMove(self.Zone, self.Index, dest.Zone, dest.Index)
		return
	end

	if not moved then
		GAMEMODE:SelectRelapseGameInv(self)
	end
end

vgui.Register("RelapseGameInvSlot", SLOT, "DButton")

---------------------------------------------------------------------------
-- Viewer
---------------------------------------------------------------------------

local function TryCraftWithComponent(me)
	net.Start("zs_trycraft")
		net.WriteString(me.Item)
		net.WriteString(me.WeaponCraft)
	net.SendToServer()
end

local function LayoutCraftButtons(viewer, item)
	local L = RelapseUI.InvWindowSize()
	for i = 1, 3 do
		local crab, cral = viewer.m_CraftBtns[i][1], viewer.m_CraftBtns[i][2]
		crab:SetVisible(false)
		cral:SetVisible(false)
	end

	local assembles = {}
	if item then
		for k, v in pairs(GAMEMODE.Assemblies) do
			if v[1] == item then
				assembles[v[2]] = k
			end
		end
	end

	local count = 0
	for k, v in pairs(assembles) do
		count = count + 1
		local crab, cral = viewer.m_CraftBtns[count][1], viewer.m_CraftBtns[count][2]
		local iitype = GAMEMODE:GetInventoryItemType(k) ~= -1
		crab.Item = item
		crab.WeaponCraft = k
		crab.DoClick = TryCraftWithComponent
		crab:SetSize(viewer:GetWide() - L.pad * 2, L.m.btnH)
		crab:SetPos(L.pad, viewer:GetTall() - L.pad - count * (L.m.btnH + L.gap))
		crab:SetVisible(true)
		local dest = iitype and GAMEMODE.ZSInventoryItemData[k] or weapons.Get(k)
		cral:SetText((dest and dest.PrintName) or k)
		cral:SizeToContents()
		cral:Center()
		cral:SetVisible(true)
	end

	if count > 0 then
		viewer.m_CraftWith:SetText(RelapseUI.T("inv_craft_with"))
		viewer.m_CraftWith:SizeToContents()
		viewer.m_CraftWith:SetPos(
			math.floor((viewer:GetWide() - viewer.m_CraftWith:GetWide()) * 0.5 + 0.5),
			viewer:GetTall() - L.pad - (count + 1) * (L.m.btnH + L.gap)
		)
		viewer.m_CraftWith:SetVisible(true)
	else
		viewer.m_CraftWith:SetVisible(false)
	end
end

function GM:PlaceRelapseInvChrome()
	local frame = self.InventoryMenu
	if not IsValid(frame) then return end
	local L = RelapseUI.InvWindowSize()
	frame:SetSize(L.wid, L.hei)
	frame:Center()

	local viewer = self.m_InvViewer
	if not (IsValid(viewer) and viewer:IsVisible()) then
		local actions = self.HumanMenuPanel
		if IsValid(actions) and actions.InvalidateLayout then
			actions:InvalidateLayout(true)
		end
		return
	end
	viewer.RelapseInvTitleGap = RelapseUI.sPx(45)
	local fx, fy = frame:GetPos()
	local vw = RelapseUI.InvViewerW()
	local vh = math.max(frame:GetTall(), RelapseUI.ViewerH())
	local floor = ScrH() - L.pad
	if fy + vh > floor then
		vh = math.max(frame:GetTall(), floor - fy)
	end
	viewer:SetSize(vw, vh)
	local gap = L.viewerGap or RelapseUI.sPx(30)
	local vx = math.max(L.pad, fx - gap - vw)
	viewer:SetPos(vx, fy)

	local actions = self.HumanMenuPanel
	if IsValid(actions) and actions.InvalidateLayout then
		actions:InvalidateLayout(true)
	end

	local inner = viewer.RelapseInner
	if not IsValid(inner) then
		if IsValid(viewer.m_Title) then
			inner = viewer
		else
			inner = vgui.Create("DPanel", viewer)
			inner:SetPaintBackground(false)
			inner.Paint = function() return true end
			viewer.RelapseInner = inner
		end
	end
	if inner ~= viewer then
		local iw = RelapseUI.InvViewerInnerW()
		inner:SetSize(iw, vh)
		inner:SetPos(math.floor((vw - iw) * 0.5 + 0.5), 0)
		inner.RelapseInvTitleGap = viewer.RelapseInvTitleGap
	end
	if IsValid(inner.m_Title) then
		inner.m_Title:InvalidateLayout(true)
	end
	RelapseUI.LayoutViewerAmmo(inner)
end

local function InvViewerBody(chrome)
	if not IsValid(chrome) then return nil end
	local inner = chrome.RelapseInner
	if IsValid(inner) and IsValid(inner.m_Title) then
		return inner
	end
	if IsValid(inner) and not IsValid(inner.m_Title) and IsValid(chrome.m_Title) then
		inner:Remove()
		chrome.RelapseInner = nil
	end
	if IsValid(chrome.m_Title) then
		return chrome
	end
	return nil
end

function GM:CreateInventoryInfoViewer()
	if self.m_InvViewer and self.m_InvViewer:IsValid() then
		self:PlaceRelapseInvChrome()
		return
	end

	local leftframe = self.InventoryMenu
	if not IsValid(leftframe) then return end
	local viewer = vgui.Create("DFrame")
	viewer:SetDeleteOnClose(false)
	viewer:SetTitle("")
	viewer:SetDraggable(false)
	viewer:SetKeyboardInputEnabled(false)
	viewer:SetSize(RelapseUI.InvViewerW(), math.max(leftframe:GetTall(), RelapseUI.ViewerH()))
	viewer.Paint = RelapseUI.PaintWindow
	RelapseUI.HideChrome(viewer)
	viewer.RelapseInvTitleGap = RelapseUI.sPx(45)
	viewer:SetVisible(false)
	viewer:SetAlpha(0)
	self.m_InvViewer = viewer

	local inner = vgui.Create("DPanel", viewer)
	inner:SetPaintBackground(false)
	inner.Paint = function() return true end
	inner.RelapseInvTitleGap = viewer.RelapseInvTitleGap
	viewer.RelapseInner = inner
	local iw = RelapseUI.InvViewerInnerW()
	inner:SetSize(iw, viewer:GetTall())
	inner:SetPos(math.floor((viewer:GetWide() - iw) * 0.5 + 0.5), 0)
	self:CreateItemViewerGenericElems(inner)

	local craftbtns = {}
	for i = 1, 3 do
		local craftb = vgui.Create("DButton", inner)
		craftb:SetText("")
		craftb:SetFont("Relapse20")
		craftb.Paint = RelapseUI.PaintPrimaryButton
		craftb:SetVisible(false)

		local namelab = EasyLabel(craftb, "...", "Relapse20", RelapseUI.Col.Accent)
		namelab:SetVisible(false)
		craftbtns[i] = {craftb, namelab}
	end
	inner.m_CraftBtns = craftbtns

	local craftwith = EasyLabel(inner, RelapseUI.T("inv_craft_with"), "Relapse15", RelapseUI.Col.Muted)
	craftwith:SetVisible(false)
	inner.m_CraftWith = craftwith
end

local function InvFromClose(pnl)
	if not IsValid(pnl) then return false end
	if pnl._RelapseClosing then return true end
	local f = pnl._RelapseFade
	return f and f.to == 0
end

local function HideInvPanel(pnl)
	if not IsValid(pnl) then return end
	pnl._RelapseFade = nil
	pnl._RelapseClosing = nil
	pnl:SetVisible(false)
	pnl:SetAlpha(255)
end

local function PrepInvOpen(pnl)
	if not IsValid(pnl) then return end
	local fromClose = InvFromClose(pnl)
	pnl._RelapseClosing = nil
	pnl:SetVisible(true)
	if not fromClose then
		pnl:SetAlpha(0)
	end
end

function GM:FadeRelapseGameInv(open)
	local panels = { self.InventoryMenu, self.HumanMenuPanel, self.m_InvViewer }
	if open then
		self._RelapseGameInvClosing = nil
		for _, pnl in ipairs(panels) do
			if IsValid(pnl) and pnl:IsVisible() then
				if pnl == self.m_InvViewer and not (IsValid(self.InventoryMenu) and self.InventoryMenu.SelKind) then
					HideInvPanel(pnl)
				else
					local fromClose = InvFromClose(pnl)
					pnl._RelapseClosing = nil
					if pnl == self.InventoryMenu or pnl == self.HumanMenuPanel then
						pnl:MakePopup()
						pnl:SetKeyboardInputEnabled(false)
					end
					pnl:SetMouseInputEnabled(true)
					if not fromClose then
						pnl:SetAlpha(0)
					end
					RelapseUI.PlayFade(pnl, 255, RelapseUI.Duration(3), RelapseUI.EaseOut)
				end
			end
		end
		return
	end

	if self._RelapseGameInvClosing then return end
	self._RelapseGameInvClosing = true

	local n = 0
	local function done(pnl)
		HideInvPanel(pnl)
		n = n - 1
		if n > 0 then return end
		self._RelapseGameInvClosing = nil
		if self.SelectRelapseGameInv then
			self:SelectRelapseGameInv(nil)
		end
	end
	for _, pnl in ipairs(panels) do
		if IsValid(pnl) and pnl:IsVisible() and not pnl._RelapseClosing then
			n = n + 1
			RelapseUI.FadeClose(pnl, false, done)
		end
	end
	if n == 0 then
		self._RelapseGameInvClosing = nil
	end
end

function GM:CloseRelapseGameInv()
	if self.CancelRelapseGameInvDrag then
		self:CancelRelapseGameInvDrag()
	end
	self:FadeRelapseGameInv(false)
end

function GM:ShowRelapseInvViewer(show, instant)
	if show then
		self:CreateInventoryInfoViewer()
		local pnl = self.m_InvViewer
		if not IsValid(pnl) then return end
		-- Already up (or fading in): swap contents without a new fade.
		if pnl:IsVisible() and not pnl._RelapseClosing then
			self:PlaceRelapseInvChrome()
			return
		end
		if instant then
			pnl._RelapseFade = nil
			pnl._RelapseClosing = nil
			pnl:SetVisible(true)
			pnl:SetAlpha(255)
			self:PlaceRelapseInvChrome()
			return
		end
		PrepInvOpen(pnl)
		self:PlaceRelapseInvChrome()
		RelapseUI.PlayFade(pnl, 255, RelapseUI.Duration(3), RelapseUI.EaseOut)
		return
	end
	local pnl = self.m_InvViewer
	if not IsValid(pnl) then return end
	if instant then
		HideInvPanel(pnl)
		return
	end
	if not pnl:IsVisible() and not pnl._RelapseClosing then return end
	if self._RelapseGameInvClosing then return end
	if IsValid(self.InventoryMenu) and self.InventoryMenu._RelapseClosing then return end
	if pnl._RelapseClosing then return end
	RelapseUI.FadeClose(pnl, false, HideInvPanel)
end

local function FindSlotByEntry(frame, kind, id)
	if not kind or not id then return end
	local function scan(list)
		for _, slot in ipairs(list or {}) do
			if IsValid(slot) and slot.Entry and slot.Entry.t == kind and slot.Entry.id == id then
				return slot
			end
		end
	end
	return scan(frame.HotSlots) or scan(frame.BagSlots)
end

function GM:RelapseGameInvHeldClass()
	if not IsValid(MySelf) then return end
	local wep = MySelf:GetActiveWeapon()
	if not IsValid(wep) then return end
	local class = wep:GetClass()
	if self:IsHumanUnarmedWeapon(class) then return end
	return class
end

function GM:SelectRelapseGameInv(slot, opts)
	local frame = self.InventoryMenu
	if not IsValid(frame) then return end
	opts = opts or {}

	for _, s in ipairs(frame.BagSlots or {}) do
		if IsValid(s) then s.On = false end
	end
	for _, s in ipairs(frame.HotSlots or {}) do
		if IsValid(s) then s.On = false end
	end

	if not slot or not slot.Entry then
		frame.SelInv = nil
		frame.SelKind = nil
		frame.SelId = nil
		self:DoAltSelectedItemUpdate()
		self:ShowRelapseInvViewer(false)
		return
	end

	slot.On = true
	local entry = slot.Entry
	frame.SelKind = entry.t
	frame.SelId = entry.id
	if entry.t == "inv" then
		frame.SelInv = entry.id
	else
		frame.SelInv = nil
	end
	if entry.t == "wep" and not opts.silent and self.RelapseSelectWeapon and IsValid(MySelf) then
		local cur = MySelf:GetActiveWeapon()
		if not (IsValid(cur) and cur:GetClass() == entry.id) then
			self:RelapseSelectWeapon(MySelf, entry.id)
		end
	end
	self:DoAltSelectedItemUpdate()

	self:CreateInventoryInfoViewer()
	self:FillRelapseInvViewer(entry)
	self:ShowRelapseInvViewer(true)
end

function GM:FillRelapseInvViewer(entry)
	local chrome = self.m_InvViewer
	if not IsValid(chrome) then return end
	local viewer = InvViewerBody(chrome)
	if not IsValid(viewer) or not IsValid(viewer.m_Title) then return end
	viewer.RelapsePlayerView = false
	viewer.m_Title:SetText(ItemName(entry))
	viewer.m_Title:PerformLayout()
	if IsValid(viewer.m_Desc) then
		viewer.m_Desc:SetText(ItemDesc(entry))
		viewer.m_Desc:SetFont("Relapse15")
	end

	if entry.t == "wep" then
		local sweptable = weapons.Get(entry.id)
		RelapseUI.SetShopPreview(viewer.ModelPanel, sweptable, viewer)
		viewer.m_VBG:SetVisible(true)
		if IsValid(viewer.ModelPanel) then
			viewer.ModelPanel:SetVisible(true)
		end
		local canammo = sweptable and self:HasPurchaseableAmmo(sweptable)
		if canammo then
			local ammotype = self:GetWeaponAmmoType(sweptable) or (sweptable.Primary and sweptable.Primary.Ammo)
			viewer.m_AmmoType:SetText(RelapseUI.ShopAmmo(ammotype))
			viewer.m_AmmoType:SetVisible(true)
			RelapseUI.SetViewerAmmoIcon(viewer, ammotype)
		else
			viewer.m_AmmoType:SetText("")
			viewer.m_AmmoType:SetVisible(false)
			RelapseUI.SetViewerAmmoIcon(viewer, nil)
		end
		RelapseUI.LayoutViewerAmmo(viewer)
		self:ViewerStatBarUpdate(viewer, false, sweptable)
	else
		if IsValid(viewer.ModelPanel) then
			viewer.ModelPanel:SetModel("")
			viewer.ModelPanel:SetVisible(false)
		end
		if entry.t == "ammo" then
			viewer.m_VBG:SetVisible(true)
			local path = IconPath(entry)
			if path and IsValid(viewer.m_ModelIcon) then
				viewer.m_ModelIcon:SetImage(path)
				viewer.m_ModelIcon:SetImageColor(RelapseUI.Col.Text)
				viewer.m_ModelIcon:SetVisible(true)
			elseif IsValid(viewer.m_ModelIcon) then
				viewer.m_ModelIcon:SetVisible(false)
			end
			viewer.m_AmmoType:SetText("")
			viewer.m_AmmoType:SetVisible(false)
			RelapseUI.SetViewerAmmoIcon(viewer, nil)
			RelapseUI.LayoutViewerAmmo(viewer)
			if IsValid(viewer.m_ModelIcon) and viewer.m_ModelIcon:IsVisible() and IsValid(viewer.m_VBG) then
				viewer.m_ModelIcon:Dock(NODOCK)
				RelapseUI.FitIcon(viewer.m_ModelIcon, viewer.m_VBG:GetWide(), viewer.m_VBG:GetTall())
			end
			self:ViewerStatBarUpdate(viewer, true, {})
		else
			if IsValid(viewer.m_ModelIcon) then
				viewer.m_ModelIcon:SetVisible(false)
			end
			viewer.m_VBG:SetVisible(false)
			viewer.m_VBG:SetSize(1, 1)
			local title = viewer.m_Title
			local y = RelapseUI.sPx(15)
			if IsValid(title) then
				y = title:GetY() + RelapseUI.sPx(20)
			end
			viewer.m_VBG:SetPos(RelapseUI.Grid15(), y)
			viewer.m_AmmoType:SetText("")
			viewer.m_AmmoType:SetVisible(false)
			RelapseUI.SetViewerAmmoIcon(viewer, nil)
			RelapseUI.LayoutViewerDesc(viewer)
			self:ViewerStatBarUpdate(viewer, true, {})
		end
	end

	LayoutCraftButtons(viewer, entry.t == "inv" and entry.id or nil)
end

function GM:RelapseGameInvMove(fromZone, fromIdx, toZone, toIdx)
	local a = SlotEntry(fromZone, fromIdx)
	if not a then return end
	local b = SlotEntry(toZone, toIdx)
	if not self:RelapseInvCanPlace(a, toZone) then
		surface.PlaySound("buttons/button8.wav")
		return
	end
	if b and not self:RelapseInvCanPlace(b, fromZone) then
		surface.PlaySound("buttons/button8.wav")
		return
	end

	SetSlotEntry(toZone, toIdx, a)
	SetSlotEntry(fromZone, fromIdx, b)
	self:RefreshRelapseGameInv()

	local bits = self.RelapseInvIndexBits or 5
	net.Start("relapse_inv_move")
		net.WriteUInt(fromZone, 2)
		net.WriteUInt(fromIdx, bits)
		net.WriteUInt(toZone, 2)
		net.WriteUInt(toIdx, bits)
	net.SendToServer()
	surface.PlaySound("buttons/button14.wav")
end

function GM:CancelRelapseGameInvDrag()
	StopDrag()
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

function GM:RefreshRelapseGameInv(opts)
	local frame = self.InventoryMenu
	if not IsValid(frame) then return end
	opts = opts or {}

	for _, slot in ipairs(frame.BagSlots or {}) do
		if IsValid(slot) then
			slot:ApplyEntry(SlotEntry(self.RelapseInvZoneBag, slot.Index))
		end
	end
	for _, slot in ipairs(frame.HotSlots or {}) do
		if IsValid(slot) then
			slot:ApplyEntry(SlotEntry(self.RelapseInvZoneHot, slot.Index))
		end
	end

	if not frame:IsVisible() then return end

	local keep
	if not opts.preferHeld and frame.SelKind and frame.SelId then
		keep = { t = frame.SelKind, id = frame.SelId }
	end
	if not keep then
		local held = self:RelapseGameInvHeldClass()
		if held then
			keep = { t = "wep", id = held }
		end
	end

	local selected = keep and FindSlotByEntry(frame, keep.t, keep.id)
	if selected then
		if selected.On and frame.SelKind == keep.t and frame.SelId == keep.id
			and IsValid(self.m_InvViewer) and self.m_InvViewer:IsVisible() then
			return
		end
		self:SelectRelapseGameInv(selected, { silent = true })
	else
		self:SelectRelapseGameInv(nil)
	end
end

function GM:InventoryAddGridItem()
	self:RefreshRelapseGameInv()
end

function GM:InventoryRemoveGridItem(item)
	self:RefreshRelapseGameInv()
	local frame = self.InventoryMenu
	if IsValid(frame) and frame.SelInv == item then
		self:SelectRelapseGameInv(nil)
	end
end

function GM:InventoryWipeGrid()
	self:RefreshRelapseGameInv()
	self:SelectRelapseGameInv(nil)
end

function GM:OpenInventory()
	RelapseUI.CreateFonts()

	local L = RelapseUI.InvWindowSize()
	if self.InventoryMenu and self.InventoryMenu:IsValid() then
		if #(self.InventoryMenu.BagSlots or {}) ~= L.bagN then
			self.InventoryMenu:Remove()
			self.InventoryMenu = nil
			if self.m_InvViewer and self.m_InvViewer:IsValid() then
				self.m_InvViewer:Remove()
				self.m_InvViewer = nil
			end
		end
	end

	if self.InventoryMenu and self.InventoryMenu:IsValid() then
		PrepInvOpen(self.InventoryMenu)
		self.InventoryMenu:MakePopup()
		self.InventoryMenu:SetKeyboardInputEnabled(false)
		self:PlaceRelapseInvChrome()
		net.Start("relapse_inv_sync")
		net.SendToServer()
		self:RefreshRelapseGameInv({ preferHeld = true })
		return
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(L.wid, L.hei)
	frame:Center()
	frame:SetDeleteOnClose(false)
	frame:SetTitle("")
	frame:SetDraggable(false)
	frame:SetKeyboardInputEnabled(false)
	frame.Paint = RelapseUI.PaintWindow
	RelapseUI.HideChrome(frame)
	frame.SelInv = nil
	frame.SelKind = nil
	frame.SelId = nil
	self.InventoryMenu = frame
	PrepInvOpen(frame)

	local title = EasyLabel(frame, RelapseUI.T("menu_inventory"), "Relapse30", RelapseUI.Col.Text)
	title:SetContentAlignment(4)
	title:SizeToContents()
	title:SetPos(L.pad, L.titleY)
	frame.RelapseTitle = title

	frame.BagSlots = {}
	local bagX = L.pad + math.floor((L.hotW - L.bagW) * 0.5 + 0.5)
	local bagY = L.header
	for i = 1, L.bagN do
		local col = (i - 1) % L.bagCols
		local row = math.floor((i - 1) / L.bagCols)
		local slot = vgui.Create("RelapseGameInvSlot", frame)
		slot:SetSlot(self.RelapseInvZoneBag, i, false)
		slot:SetSize(L.cell, L.cell)
		slot:SetPos(bagX + col * (L.cell + L.gap), bagY + row * (L.cell + L.gap))
		frame.BagSlots[i] = slot
	end

	frame.HotSlots = {}
	local hotY = L.header + L.bagH + L.split
	for i = 1, L.hotN do
		local slot = vgui.Create("RelapseGameInvSlot", frame)
		slot:SetSlot(self.RelapseInvZoneHot, i, true)
		slot:SetSize(L.cell, L.cell)
		slot:SetPos(L.pad + (i - 1) * (L.cell + L.gap), hotY)
		frame.HotSlots[i] = slot
	end

	frame.Grid = frame
	net.Start("relapse_inv_sync")
	net.SendToServer()
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	self:PlaceRelapseInvChrome()
	self:RefreshRelapseGameInv({ preferHeld = true })
end
