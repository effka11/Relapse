local function CanBuy(item, pan)
	if item.NoClassicMode and GAMEMODE:IsClassicMode() then
		return false
	end

	if item.Tier and GAMEMODE.LockItemTiers and not GAMEMODE.ZombieEscape and not GAMEMODE.ObjectiveMap and not GAMEMODE:IsClassicMode() then
		if not GAMEMODE:GetWaveActive() then -- We can buy during the wave break before hand.
			if GAMEMODE:GetWave() + 1 < item.Tier then
				return false
			end
		elseif GAMEMODE:GetWave() < item.Tier then
			return false
		end
	end

	if item.MaxStock and not GAMEMODE:HasItemStocks(item.Signature) then
		return false
	end

	if not IsValid(MySelf) then
		return false
	end

	if not pan.NoPoints and MySelf:GetPoints() < math.floor(item.Price * (MySelf.ArsenalDiscount or 1)) then
		return false
	elseif pan.NoPoints and MySelf:GetAmmoCount("scrap") < math.ceil(GAMEMODE:PointsToScrap(item.Price)) then
		return false
	end

	return true
end

local function ItemIsLocked(item)
	if not item then return true end
	if item.SkillRequirement and not (IsValid(MySelf) and MySelf:IsSkillActive(item.SkillRequirement)) then
		return true
	end
	if item.NoClassicMode and GAMEMODE:IsClassicMode() then
		return true
	end
	if item.NoZombieEscape and GAMEMODE.ZombieEscape then
		return true
	end
	if item.Tier and GAMEMODE.LockItemTiers and not GAMEMODE.ZombieEscape and not GAMEMODE.ObjectiveMap and not GAMEMODE:IsClassicMode() then
		if not GAMEMODE:GetWaveActive() then
			if GAMEMODE:GetWave() + 1 < item.Tier then
				return true
			end
		elseif GAMEMODE:GetWave() < item.Tier then
			return true
		end
	end
	return false
end

local function SetViewerPurchaseVisible(viewer, vis)
	if not IsValid(viewer) then return end
	if IsValid(viewer.m_PurchaseB) then viewer.m_PurchaseB:SetVisible(vis) end
	if IsValid(viewer.m_PurchaseLabel) then viewer.m_PurchaseLabel:SetVisible(vis) end
	if IsValid(viewer.m_PurchasePrice) then viewer.m_PurchasePrice:SetVisible(vis) end
	if vis then return end
	if IsValid(viewer.m_AmmoB) then viewer.m_AmmoB:SetVisible(false) end
	if IsValid(viewer.m_AmmoL) then viewer.m_AmmoL:SetVisible(false) end
	if IsValid(viewer.m_AmmoPrice) then viewer.m_AmmoPrice:SetVisible(false) end
end

local function ItemPanelThink(self)
	local itemtab = FindItem(self.ID)
	if itemtab then
		local newstate = CanBuy(itemtab, self)
		if newstate ~= self.m_LastAbleToBuy then
			self.m_LastAbleToBuy = newstate
			if newstate then
				self.NameLabel:SetTextColor(RelapseUI.Col.Text)
				self.NameLabel:InvalidateLayout()
			else
				self.NameLabel:SetTextColor(RelapseUI.Col.Danger)
				self.NameLabel:InvalidateLayout()
			end
		end

		if self.StockLabel then
			local stocks = GAMEMODE:GetItemStocks(self.ID)
			if stocks ~= self.m_LastStocks then
				self.m_LastStocks = stocks

				self.StockLabel:SetText(RelapseUI.TF("shop_remaining", stocks))
				self.StockLabel:SizeToContents()
				self.StockLabel:AlignRight(10)
				self.StockLabel:SetTextColor(stocks > 0 and RelapseUI.Col.Muted or RelapseUI.Col.Danger)
				self.StockLabel:InvalidateLayout()
			end
		end
	end
end

local function ItemPanelPaint(self, w, h)
	local selected = self.On
	local unaffordable = self.m_LastAbleToBuy == false
	RelapseUI.PaintCard(self, w, h, selected, false, unaffordable)

	if self.ShopTabl.SWEP and IsValid(MySelf) and MySelf:HasInventoryItem(self.ShopTabl.SWEP) then
		local wash = RelapseUI.Col.Wash
		surface.SetDrawColor(wash.r, wash.g, wash.b, wash.a or 40)
		surface.DrawRect(0, 0, w, h)
	end

	return true
end

local function FormatRelapseStat(id, val)
	if id == "Weight" then
		return string.format(RelapseUI.T("shop_stat_kg_fmt", "%.2f kg"), val)
	end
	if id == "Clip" then
		return tostring(math.floor(val + 0.5))
	end
	if id == "Damage" then
		if val == math.floor(val) then
			return tostring(math.floor(val))
		end
		return string.format("%.1f", val)
	end
	if id == "FireRate" or id == "Delay" or id == "Reload" then
		return RelapseUI.TF("shop_stat_sec_fmt", val)
	end
	if id == "Stability" then
		return string.format("%.2f", val)
	end
	if id == "Kinetic" or id == "Recoil" or id == "Accuracy" then
		return string.format("%.2f", val)
	end

	return tostring(val)
end

function GM:ViewerStatBarUpdate(viewer, display, sweptable)
	local barCount = viewer.ItemStatBars and #viewer.ItemStatBars or 0
	if barCount < 1 then return end
	if display then
		for i = 1, barCount do
			viewer.ItemStats[i]:SetText("")
			viewer.ItemStatValues[i]:SetText("")
			viewer.ItemStatBars[i]:SetVisible(false)
		end
		RelapseUI.LayoutViewerStats(viewer)
		return
	end

	local debugRows = math.min(tonumber(sweptable.RelapseStatDebugRows) or 0, RelapseUI.ViewerStatMax())
	if debugRows > 0 then
		for i = 1, barCount do
			if i <= debugRows then
				viewer.ItemStats[i]:SetText("Stat " .. i)
				viewer.ItemStatValues[i]:SetText(tostring(i))
				viewer.ItemStatBars[i].Stat = i
				viewer.ItemStatBars[i].StatMin = 0
				viewer.ItemStatBars[i].StatMax = debugRows
				viewer.ItemStatBars[i].BadHigh = false
				viewer.ItemStatBars[i]:SetVisible(true)
			else
				viewer.ItemStats[i]:SetText("")
				viewer.ItemStatValues[i]:SetText("")
				viewer.ItemStatBars[i]:SetVisible(false)
			end
		end
		RelapseUI.LayoutViewerStats(viewer)
		return
	end

	if GAMEMODE:GetWeaponRelapse(sweptable) then
		local specs = GAMEMODE.RelapseWeaponStatBarVals
		for i = 1, barCount do
			local spec = specs and specs[i]
			local val = spec and GAMEMODE:RelapseStatValue(sweptable, spec[1])
			local fill = val ~= nil and GAMEMODE:RelapseShopBarFill(sweptable, spec[1])
			if not spec or val == nil or fill == nil then
				viewer.ItemStats[i]:SetText("")
				viewer.ItemStatValues[i]:SetText("")
				viewer.ItemStatBars[i]:SetVisible(false)
			else
				viewer.ItemStats[i]:SetText(RelapseUI.ShopStat(spec[1], spec[2]))
				local text = FormatRelapseStat(spec[1], val)
				if spec[1] == "Damage" then
					local r = GAMEMODE:GetWeaponRelapse(sweptable)
					local pellets = r and tonumber(r.Pellets)
					if pellets and pellets > 1 then
						text = text .. " × " .. math.floor(pellets + 0.5)
					end
				end
				viewer.ItemStatValues[i]:SetText(text)
				viewer.ItemStatBars[i].Stat = fill
				viewer.ItemStatBars[i].StatMin = 0
				viewer.ItemStatBars[i].StatMax = 100
				viewer.ItemStatBars[i].BadHigh = false
				viewer.ItemStatBars[i]:SetVisible(true)
			end
		end
		RelapseUI.LayoutViewerStats(viewer)
		return
	end

	local done, statshow = {}
	local speedtotext = GAMEMODE.SpeedToText
	for i = 1, barCount do
		local statshowbef = statshow
		for k, stat in pairs(GAMEMODE.WeaponStatBarVals) do
			local statval = stat[6] and sweptable[stat[6]][stat[1]] or sweptable[stat[1]]
			if not done[stat] and statval and statval ~= -1 then
				statshow = stat
				done[stat] = true

				break
			end
		end
		if statshowbef and statshowbef[1] == statshow[1] then
			viewer.ItemStats[i]:SetText("")
			viewer.ItemStatValues[i]:SetText("")
			viewer.ItemStatBars[i]:SetVisible(false)
			continue
		end

		local statnum, stattext = statshow[6] and sweptable[statshow[6]][statshow[1]] or sweptable[statshow[1]]
		if statshow[1] == "Damage" and sweptable.Primary.NumShots and sweptable.Primary.NumShots > 1 then
			stattext = statnum .. " x " .. sweptable.Primary.NumShots-- .. " (" .. (statnum * sweptable.Primary.NumShots) .. ")"
		elseif statshow[1] == "WalkSpeed" then
			stattext = speedtotext[SPEED_NORMAL]
			if speedtotext[sweptable[statshow[1]]] then
				stattext = speedtotext[sweptable[statshow[1]]]
			elseif sweptable[statshow[1]] < SPEED_SLOWEST then
				stattext = speedtotext[-1]
			end
		elseif statshow[1] == "ClipSize" then
			stattext = statnum / (sweptable.RequiredClip or 1)
		else
			stattext = statnum
		end

		viewer.ItemStats[i]:SetText(RelapseUI.ShopStat(statshow[1], statshow[2]))
		viewer.ItemStatValues[i]:SetText(stattext)

		if statshow[1] == "Damage" then
			statnum = statnum * (sweptable.Primary.NumShots or 1)
		elseif statshow[1] == "ClipSize" then
			statnum = statnum / (sweptable.RequiredClip or 1)
		end

		viewer.ItemStatBars[i].Stat = statnum
		viewer.ItemStatBars[i].StatMin = statshow[3]
		viewer.ItemStatBars[i].StatMax = statshow[4]
		viewer.ItemStatBars[i].BadHigh = statshow[5]
		viewer.ItemStatBars[i]:SetVisible(true)
	end
	RelapseUI.LayoutViewerStats(viewer)
end

function GM:HasPurchaseableAmmo(sweptable)
	local lower = self:GetWeaponAmmoType(sweptable)
	if not lower and sweptable and sweptable.Primary then
		lower = sweptable.Primary.Ammo
	end
	return self:GetAmmoPurchaseSignature(lower) ~= nil
end

function GM:SupplyItemViewerDetail(viewer, sweptable, shoptbl)
	if shoptbl and shoptbl.SWEP then
		sweptable.ClassName = sweptable.ClassName or shoptbl.SWEP
		sweptable.SWEP = sweptable.SWEP or shoptbl.SWEP
	end
	self:BindRelapseWeapon(sweptable)
	self:BindRelapseWeapon(shoptbl)

	viewer.m_Title:SetText(RelapseUI.WepName(sweptable))
	viewer.m_Title:PerformLayout()

	local desctext = RelapseUI.WepDesc(sweptable)
	if not self.ZSInventoryItemData[shoptbl.SWEP] then
		RelapseUI.SetShopPreview(viewer.ModelPanel, sweptable, viewer)
		viewer.m_VBG:SetVisible(true)

		if sweptable.NoDismantle then
			desctext = desctext .. "\n" .. RelapseUI.T("shop_cannot_dismantle")
		end

	else
		viewer.ModelPanel:SetModel("")
		viewer.m_VBG:SetVisible(true)
	end
	local debugLines = tonumber(sweptable.RelapseDescDebugLines) or 0
	if debugLines > 0 then
		local lines = {}
		for i = 1, debugLines do
			lines[i] = "Desc " .. i
		end
		desctext = table.concat(lines, "\n")
	end
	viewer.m_Desc:SetText(desctext)

	self:ViewerStatBarUpdate(viewer, shoptbl.Category ~= ITEMCAT_GUNS and shoptbl.Category ~= ITEMCAT_MELEE, sweptable)

	if self:HasPurchaseableAmmo(sweptable) then
		local lower = self:GetWeaponAmmoType(sweptable)

		viewer.m_AmmoType:SetText(RelapseUI.ShopAmmo(lower))
		viewer.m_AmmoType:SizeToContents()
		viewer.m_AmmoType:PerformLayout()

		local ki = lower and self.AmmoIcons[lower] and killicon.Get(self.AmmoIcons[lower])
		if istable(ki) and ki[1] then
			viewer.m_AmmoIcon:SetImage(ki[1])
			viewer.m_AmmoIcon:SetImageColor(RelapseUI.Col.Text)
			viewer.m_AmmoIcon:SetVisible(true)
		else
			viewer.m_AmmoIcon:SetVisible(false)
		end

		viewer.m_AmmoType:SetVisible(true)
		viewer.m_AmmoType:MoveToFront()
		if viewer.m_AmmoIcon:IsVisible() then
			viewer.m_AmmoIcon:MoveToFront()
		end
	else
		viewer.m_AmmoType:SetText("")
		viewer.m_AmmoIcon:SetVisible(false)
		viewer.m_AmmoType:SetVisible(false)
	end
	RelapseUI.LayoutViewerAmmo(viewer)
end

local function SetupViewerPurchase(self, viewer, shoptbl, sweptable)
	if not IsValid(viewer) then return end

	local arsenal = GAMEMODE.ArsenalInterface
	if IsValid(arsenal) and viewer == arsenal.Viewer and IsValid(arsenal.Purchase) then
		arsenal.SelectedBuy = self
		local ammo = arsenal.AmmoB
		if IsValid(ammo) then
			local canammo = GAMEMODE:HasPurchaseableAmmo(sweptable)
			if canammo then
				local ammoId = GAMEMODE:GetWeaponAmmoType(sweptable) or (sweptable.Primary and sweptable.Primary.Ammo)
				ammo.AmmoType = GAMEMODE:GetAmmoPurchaseSignature(ammoId)
			else
				ammo.AmmoType = nil
			end
		end
		return
	end

	if not IsValid(viewer.m_PurchaseB) then return end

	local m = RelapseUI.M()
	local canammo = GAMEMODE:HasPurchaseableAmmo(sweptable)
	local buyY = viewer:GetTall() - m.btnH - m.gutter

	local purb = viewer.m_PurchaseB
	purb.ID = self.ID
	purb.DoClick = function() RunConsoleCommand("zs_pointsshopbuy", self.ID, self.NoPoints and "scrap") end
	purb:SetPos(canammo and m.gutter or (viewer:GetWide() - purb:GetWide()) * 0.5, buyY)
	purb:SetVisible(true)

	local purl = viewer.m_PurchaseLabel
	purl:SetPos(purb:GetWide() / 2 - purl:GetWide() / 2, purb:GetTall() * 0.35 - purl:GetTall() * 0.5)
	purl:SetVisible(true)

	local ppurbl = viewer.m_PurchasePrice
	local price = self.NoPoints and math.ceil(GAMEMODE:PointsToScrap(shoptbl.Worth)) or math.floor(shoptbl.Worth * (MySelf.ArsenalDiscount or 1))
	ppurbl:SetText(self.NoPoints and RelapseUI.TF("shop_price_scrap", price) or RelapseUI.TF("shop_price_points", price))
	ppurbl:SizeToContents()
	ppurbl:SetPos(purb:GetWide() / 2 - ppurbl:GetWide() / 2, purb:GetTall() * 0.75 - ppurbl:GetTall() * 0.5)
	ppurbl:SetVisible(true)

	purb = viewer.m_AmmoB
	if canammo then
		local ammoId = GAMEMODE:GetWeaponAmmoType(sweptable) or (sweptable.Primary and sweptable.Primary.Ammo)
		purb.AmmoType = GAMEMODE:GetAmmoPurchaseSignature(ammoId)
		purb.DoClick = function() RunConsoleCommand("zs_pointsshopbuy", "ps_"..purb.AmmoType) end
	end
	purb:SetPos(viewer:GetWide() - purb:GetWide() - m.gutter, buyY)
	purb:SetVisible(canammo)

	purl = viewer.m_AmmoL
	purl:SetPos(purb:GetWide() / 2 - purl:GetWide() / 2, purb:GetTall() * 0.35 - purl:GetTall() * 0.5)
	purl:SetVisible(canammo)

	ppurbl = viewer.m_AmmoPrice
	local ammoId = GAMEMODE:GetWeaponAmmoType(sweptable) or (sweptable.Primary and sweptable.Primary.Ammo)
	local ammoSig = GAMEMODE:GetAmmoPurchaseSignature(ammoId)
	local ammoItem = ammoSig and GAMEMODE.Items and GAMEMODE.Items["ps_" .. ammoSig]
	local ammoPts = (ammoItem and ammoItem.Worth) or GAMEMODE:GetAmmoShopPoints(ammoId)
	price = math.floor((ammoPts or 9) * (MySelf.ArsenalDiscount or 1))
	ppurbl:SetText(RelapseUI.TF("shop_price_points", price))
	ppurbl:SizeToContents()
	ppurbl:SetPos(purb:GetWide() / 2 - ppurbl:GetWide() / 2, purb:GetTall() * 0.75 - ppurbl:GetTall() * 0.5)
	ppurbl:SetVisible(canammo)
end

local function ItemPanelDoClick(self)
	local shoptbl = self.ShopTabl
	local viewer = self.NoPoints and GAMEMODE.RemantlerInterface.TrinketsFrame.Viewer or GAMEMODE.ArsenalInterface.Viewer

	if not shoptbl then return end
	local sweptable = GAMEMODE.ZSInventoryItemData[shoptbl.SWEP] or weapons.Get(shoptbl.SWEP)

	if not sweptable or GAMEMODE.AlwaysQuickBuy then
		RunConsoleCommand("zs_pointsshopbuy", self.ID, self.NoPoints and "scrap")
		return
	end

	for _, v in pairs(self:GetParent():GetChildren()) do
		v.On = false
	end
	self.On = true

	GAMEMODE:SupplyItemViewerDetail(viewer, sweptable, shoptbl)
	SetupViewerPurchase(self, viewer, shoptbl, sweptable)
end

function GM:AttachKillicon(kitbl, itempan, mdlframe, ammo, missing_skill)
	local function imgAdj(img, maximgx, maximgy)
		img:SizeToContents()
		local iwidth, height = img:GetSize()
		if height > maximgy then
			img:SetSize(maximgy / height * img:GetWide(), maximgy)
			iwidth, height = img:GetSize()
		end
		if iwidth > maximgx then
			img:SetWidth(maximgx)
		end

		img:Center()
	end

	if #kitbl == 2 then
		local img = vgui.Create("DImage", mdlframe)
		Material(kitbl[1])
		img:SetImage(kitbl[1])
		img:SetImageColor(RelapseUI.Col.Text)
		if missing_skill then img:SetAlpha(50) end

		imgAdj(img, mdlframe:GetWide() - 6, mdlframe:GetTall() - 3)
		if ammo then img:SetSize(img:GetWide() + 3, img:GetTall() + 3) end

		img:Center()
		itempan.m_Icon = img
	elseif #kitbl == 3 then
		local label = vgui.Create("DLabel", mdlframe)
		label:SetText(kitbl[2])
		label:SetFont(kitbl[1] .. "pa" or DefaultFont)
		label:SetTextColor(RelapseUI.Col.Text)
		label:SizeToContents()
		label:SetContentAlignment(8)
		label:DockMargin(0, label:GetTall() * 0.05, 0, 0)
		label:Dock(FILL)
		itempan.m_Icon = label
	end

	if missing_skill then
		local img = vgui.Create("DImage", mdlframe)
		img:SetImage("zombiesurvival/padlock.png")
		img:SetImageColor(RelapseUI.Col.Muted)
		imgAdj(img, mdlframe:GetWide(), mdlframe:GetTall())

		img:Center()
		itempan.m_Padlock = img
	end
end

function GM:AddShopItem(list, i, tab, issub, nopointshop)
	local screenscale = BetterScreenScale()

	local nottrinkets = tab.Category ~= ITEMCAT_TRINKETS
	local missing_skill = tab.SkillRequirement and not (IsValid(MySelf) and MySelf:IsSkillActive(tab.SkillRequirement))
	local wid = 280

	local itempan = vgui.Create("DButton")
	itempan:SetText("")
	itempan:SetSize(wid * screenscale, (nottrinkets and 100 or 60) * screenscale)
	itempan.ID = tab.Signature or i
	itempan.NoPoints = nopointshop
	itempan.ShopTabl = tab
	itempan.Think = ItemPanelThink
	itempan.Paint = ItemPanelPaint
	itempan.DoClick = ItemPanelDoClick
	itempan.DoRightClick = function()
		local menu = DermaMenu(itempan)
		menu:AddOption(RelapseUI.T("shop_buy"), function() RunConsoleCommand("zs_pointsshopbuy", itempan.ID, itempan.NoPoints and "scrap") end)
		menu:Open()
	end
	list:AddItem(itempan)

	if nottrinkets then
		local mdlframe = vgui.Create("DPanel", itempan)
		mdlframe:SetSize(wid/2 * screenscale, 100/2 * screenscale)
		mdlframe:SetPos(wid/4 * screenscale, 100/5 * screenscale)
		mdlframe:SetMouseInputEnabled(false)
		mdlframe.Paint = function() end

		local kitbl = killicon.Get(GAMEMODE.ZSInventoryItemData[tab.SWEP] and "weapon_zs_craftables" or tab.SWEP or tab.Model)
		if not RelapseUI.TryAttachCardIcon(itempan, mdlframe, tab, missing_skill) then
			if kitbl then
				self:AttachKillicon(kitbl, itempan, mdlframe, tab.Category == ITEMCAT_AMMO, missing_skill)
			elseif tab.Model then
				local mdlpanel = vgui.Create("DModelPanel", mdlframe)
				mdlpanel:SetSize(mdlframe:GetSize())
				mdlpanel:SetModel(tab.Model)
				local mins, maxs = mdlpanel.Entity:GetRenderBounds()
				mdlpanel:SetCamPos(mins:Distance(maxs) * Vector(0.75, 0.75, 0.5))
				mdlpanel:SetLookAt((mins + maxs) / 2)
			end
		end
	end

	if tab.SWEP or tab.Countables then
		local counter = vgui.Create("ItemAmountCounter", itempan)
		counter:SetItemID(i)
	end

	local name = RelapseUI.WepName(tab)
	local namelab = EasyLabel(itempan, name, "Relapse20", RelapseUI.Col.Text)
	namelab:SetPos(12 * screenscale, itempan:GetTall() * (nottrinkets and 0.8 or 0.7) - namelab:GetTall() * 0.5)
	if missing_skill then
		namelab:SetAlpha(30)
	end
	itempan.NameLabel = namelab

	local alignri = (issub and (320 + 32) or (nopointshop and 32 or 20)) * screenscale

	local pricelabel = EasyLabel(itempan, "", "Relapse20")
	if missing_skill then
		pricelabel:SetTextColor(RelapseUI.Col.Danger)
		pricelabel:SetText(GAMEMODE.Skills[tab.SkillRequirement].Name)
	else
		local points = math.floor(tab.Price * (MySelf.ArsenalDiscount or 1))
		local price = tostring(points)
		if nopointshop then
			price = tostring(math.ceil(self:PointsToScrap(tab.Price)))
		end
		pricelabel:SetText(nopointshop and RelapseUI.TF("shop_price_scrap", price) or RelapseUI.TF("shop_price_points", price))
		pricelabel:SetTextColor(RelapseUI.Col.Accent)
	end
	pricelabel:SizeToContents()
	pricelabel:AlignRight(alignri)

	if tab.MaxStock then
		local stocklabel = EasyLabel(itempan, RelapseUI.TF("shop_remaining", tab.MaxStock), "Relapse13")
		stocklabel:SetTextColor(RelapseUI.Col.Muted)
		stocklabel:SizeToContents()
		stocklabel:AlignRight(alignri)
		stocklabel:SetPos(itempan:GetWide() - stocklabel:GetWide(), itempan:GetTall() * 0.45 - stocklabel:GetTall() * 0.5)
		itempan.StockLabel = stocklabel
	end
	pricelabel:SetPos(
		itempan:GetWide() - pricelabel:GetWide() - 12 * screenscale,
		itempan:GetTall() * (nottrinkets and 0.15 or 0.3) - pricelabel:GetTall() * 0.5
	)

	if missing_skill or tab.NoClassicMode and isclassic or tab.NoZombieEscape and GAMEMODE.ZombieEscape then
		itempan:SetAlpha(160)
	end

	if not nottrinkets and tab.SubCategory then
		local catlabel = EasyLabel(itempan, RelapseUI.ShopSubCat(tab.SubCategory), "Relapse13", RelapseUI.Col.Muted)
		catlabel:SizeToContents()
		catlabel:SetPos(10, itempan:GetTall() * 0.3 - catlabel:GetTall() * 0.5)
	end

	return itempan
end

function GM:ConfigureMenuTabs(tabs, tabhei, callback)
	tabhei = tabhei or RelapseUI.M().tabs
	local labelApply = vgui.GetControlTable("DLabel")
	labelApply = labelApply and labelApply.ApplySchemeSettings

	for _, tab in ipairs(tabs) do
		tab.GetTabHeight = function()
			return tabhei
		end
		tab.Paint = RelapseUI.PaintTab
		-- Must be installed before SetFont: DLabel.SetFont always calls ApplySchemeSettings.
		tab.ApplySchemeSettings = function(me)
			if IsValid(me.Image) then
				me.Image:SetVisible(false)
				me.Image:SetSize(0, 0)
			end
			if labelApply then
				labelApply(me)
			end
			RelapseUI.SizeTabButton(me)
		end
		tab.PerformLayout = function(me)
			if IsValid(me.Image) then
				me.Image:SetVisible(false)
				me.Image:SetSize(0, 0)
			end
		end
		tab:SetFont("Relapse20")
		tab:SetTextColor(RelapseUI.Col.Muted)
		tab.DoClick = function(me)
			me:GetPropertySheet():SetActiveTab(me)
			if callback then callback(me) end
		end

		local sheet = tab.GetPropertySheet and tab:GetPropertySheet()
		if IsValid(sheet) then
			sheet:SetFadeTime(0)
			if IsValid(sheet.tabScroller) then
				sheet.tabScroller:SetTall(tabhei)
			end
			RelapseUI.PinTabContent(sheet, tabhei, RelapseUI.M().tabGap)
		end
	end
end

local PANEL = {}

PANEL.Stat = 50
PANEL.StatMin = 0
PANEL.StatMax = 100
PANEL.BadHigh = false
PANEL.LerpStat = 50
function PANEL:Init()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

local matGradientLeft = CreateMaterial("gradient-l", "UnlitGeneric", {["$basetexture"] = "vgui/gradient-l", ["$vertexalpha"] = "1", ["$vertexcolor"] = "1", ["$ignorez"] = "1", ["$nomip"] = "1"})
function PANEL:Paint(w, h)
	return RelapseUI.PaintStatBar(self, w, h)
end
vgui.Register("ZSItemStatBar", PANEL, "Panel")

function GM:CreateItemViewerGenericElems(viewer)
	local m = RelapseUI.M()
	local inset = m.cardPad
	local innerW = viewer:GetWide() - 2 * inset

	local descLeft = math.max(0, inset - RelapseUI.sPx(5))
	local descRight = RelapseUI.sPx(15)

	-- Relapse20 cell sits ~5px above caps; y is to the capital, not the em-box.
	local titleTop = RelapseUI.sPx(15) - RelapseUI.sPx(5)
	local titleH = RelapseUI.sPx(20)
	local vtitle = EasyLabel(viewer, "", "Relapse20", RelapseUI.Col.Text)
	vtitle:SetContentAlignment(7)
	vtitle:SetTextColor(Color(0, 0, 0, 0))
	vtitle.ApplySchemeSettings = function() end
	vtitle.PerformLayout = function(me)
		local host = me:GetParent()
		local bw = IsValid(host) and host:GetWide() or viewer:GetWide()
		me:SetSize(math.max(1, bw - descLeft - descRight), titleH)
		me:SetPos(descLeft, titleTop)
	end
	vtitle.Paint = function(me, w, h)
		local t = me:GetText() or ""
		if t ~= "" then
			draw.SimpleText(t, "Relapse20", 0, 0, RelapseUI.Col.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
		return true
	end
	vtitle:InvalidateLayout(true)
	viewer.m_Title = vtitle
	viewer.RelapseDescLeft = descLeft

	local vammot = EasyLabel(viewer, "", "Relapse15", RelapseUI.Col.Muted)
	vammot:SetContentAlignment(4)
	viewer.m_AmmoType = vammot

	local vammoi = vgui.Create("DImage", viewer)
	vammoi:SetSize(RelapseUI.Grid15(2), RelapseUI.Grid15(2))
	vammoi:SetVisible(false)
	viewer.m_AmmoIcon = vammoi
	vammot:SetVisible(false)
	RelapseUI.LayoutViewerAmmo(viewer)

	local vbg = vgui.Create("DPanel", viewer)
	vbg:SetPaintBackground(false)
	vbg.Paint = function() return true end
	viewer.m_VBG = vbg
	RelapseUI.LayoutViewerModel(viewer)

	local modelpanel = vgui.Create("DModelPanelEx", vbg)
	modelpanel:SetPaintBackground(false)
	modelpanel:SetModel("")
	modelpanel:Dock(FILL)
	viewer.ModelPanel = modelpanel

	local modelicon = vgui.Create("DImage", vbg)
	modelicon:SetVisible(false)
	modelicon:SetKeepAspect(true)
	modelicon:Dock(FILL)
	viewer.m_ModelIcon = modelicon

	local itemdesc = vgui.Create("DLabel", viewer)
	itemdesc:SetFont("Relapse15")
	itemdesc:SetTextColor(RelapseUI.Col.Muted)
	itemdesc:SetWide(math.max(1, viewer:GetWide() - descLeft - descRight))
	itemdesc:SetText("")
	RelapseUI.HookViewerDesc(itemdesc)
	viewer.m_Desc = itemdesc
	RelapseUI.LayoutViewerDesc(viewer)

	local blockW = viewer:GetWide()
	local left = RelapseUI.ViewerStatLeft()
	local right = RelapseUI.ViewerStatRight()
	local barW = math.max(1, blockW - left - right)
	local barH = RelapseUI.Grid5(2)
	local itemstats, itemsbs, itemsvs = {}, {}, {}
	local statCount = RelapseUI.ViewerStatMax()
	for i = 1, statCount do
		local itemstat = vgui.Create("DLabel", viewer)
		itemstat:SetFont("Relapse15")
		RelapseUI.HookStatCaption(itemstat, RelapseUI.Col.Muted)
		itemstat:SetWide(left)
		itemstat:SetText("")
		itemstat:SetX(0)
		table.insert(itemstats, itemstat)

		local itemsb = vgui.Create("ZSItemStatBar", viewer)
		itemsb:SetWide(barW)
		itemsb:SetTall(barH)
		itemsb:SetVisible(false)
		itemsb:SetX(left)
		table.insert(itemsbs, itemsb)

		local itemsv = vgui.Create("DLabel", viewer)
		itemsv:SetFont("Relapse15")
		RelapseUI.HookStatCaption(itemsv, RelapseUI.Col.Text)
		itemsv:SetWide(right)
		itemsv:SetText("")
		itemsv:SetX(blockW - right)
		table.insert(itemsvs, itemsv)
	end
	viewer.ItemStats = itemstats
	viewer.ItemStatValues = itemsvs
	viewer.ItemStatBars = itemsbs
	RelapseUI.LayoutViewerStats(viewer)
end

MENU_POINTSHOP = 1
MENU_WORTH = 2
MENU_REMANTLER = 3

function GM:CreateItemInfoViewer(frame, propertysheet, topspace, bottomspace, menutype)
	local m = RelapseUI.M()
	local screenscale = RelapseUI.S()

	local worthmenu = menutype == MENU_WORTH
	local remantler = menutype == MENU_REMANTLER

	local viewer = vgui.Create("DPanel", frame)

	viewer:SetPaintBackground(false)
	viewer.Paint = RelapseUI.PaintInsetPanel
	viewer:NoClipping(false)

	if remantler then
		local __, topy = topspace:GetPos()
		local ___, boty = bottomspace:GetPos()
		viewer:SetSize(m.sidebar, boty - topy - 8 - topspace:GetTall())
		viewer:MoveBelow(topspace, 4)
		viewer:Dock(RIGHT)
	else
		local sheetX, sheetY = propertysheet:GetPos()
		local sheetW, sheetH = propertysheet:GetSize()
		local vw = RelapseUI.ViewerW()
		viewer:SetSize(vw, math.max(m.step, sheetH - m.tabs - m.tabGap))
		viewer:SetPos(frame:GetWide() - RelapseUI.FooterSideInset() - vw, sheetY + m.tabs + m.tabGap)
	end
	frame.Viewer = viewer

	self:CreateItemViewerGenericElems(viewer)
	RelapseUI.PinViewerToItems(frame, propertysheet)

	if not remantler then return end

	local purchaseb = vgui.Create("DButton", viewer)
	purchaseb:SetText("")
	purchaseb:SetSize(RelapseUI.Cells(10), m.btnH)
	purchaseb:SetVisible(false)
	purchaseb.Paint = RelapseUI.PaintPrimaryButton
	viewer.m_PurchaseB = purchaseb

	local namelab = EasyLabel(purchaseb, RelapseUI.T("shop_purchase"), "Relapse15", RelapseUI.Col.Accent)
	namelab:SetVisible(false)
	viewer.m_PurchaseLabel = namelab

	local pricelab = EasyLabel(purchaseb, "", "Relapse13", RelapseUI.Col.Muted)
	pricelab:SetVisible(false)
	viewer.m_PurchasePrice = pricelab

	local ammopb = vgui.Create("DButton", viewer)
	ammopb:SetText("")
	ammopb:SetSize(RelapseUI.Cells(6), m.btnH)
	ammopb:SetVisible(false)
	ammopb.Paint = RelapseUI.PaintGhostButton
	viewer.m_AmmoB = ammopb

	namelab = EasyLabel(ammopb, RelapseUI.T("shop_ammo"), "Relapse15", RelapseUI.Col.Text)
	namelab:SetVisible(false)
	viewer.m_AmmoL = namelab

	pricelab = EasyLabel(ammopb, "", "Relapse13", RelapseUI.Col.Muted)
	pricelab:SetVisible(false)
	viewer.m_AmmoPrice = pricelab
end

local ARSENAL_CARD = {}

function ARSENAL_CARD:Init()
	self:SetText("")
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)

	local m = RelapseUI.M()
	self:SetCardSize(RelapseUI.Cells(18), m.cardH)

	self.ModelFrame = vgui.Create("DPanel", self)
	RelapseUI.PlaceCardIcon(self.ModelFrame, self:GetWide(), self.CardH)
	self.ModelFrame:SetVisible(false)
	self.ModelFrame:SetMouseInputEnabled(false)
	self.ModelFrame.Paint = function() end

	self.NameLabel = EasyLabel(self, "", "Relapse20")
	self.NameLabel:SetContentAlignment(4)
	self.NameLabel:SetTextColor(RelapseUI.Col.Text)
	self.NameLabel:DockPadding(0, 0, 0, 0)
	self.NameLabel:DockMargin(0, 0, 0, 0)

	self.PriceLabel = EasyLabel(self, "", "Relapse20")
	self.PriceLabel:SetContentAlignment(6)
	self.PriceLabel:SetTextColor(RelapseUI.Col.Accent)
	self.PriceLabel:DockPadding(0, 0, 0, 0)
	self.PriceLabel:DockMargin(0, 0, 0, 0)

	self.ItemCounter = vgui.Create("ItemAmountCounter", self)
	self:SetShopItem(nil, nil)
end

function ARSENAL_CARD:SetCardSize(w, h)
	self.CardW = w
	self.CardH = h
	self:SetSize(w, h)
end

function ARSENAL_CARD:ApplySchemeSettings()
end

function ARSENAL_CARD:PerformLayout(w, h)
	if self.CardW then
		self:SetSize(self.CardW, self.CardH)
		w, h = self.CardW, self.CardH
	else
		w = w or self:GetWide()
		h = h or self:GetTall()
	end

	local m = RelapseUI.M()
	local inset = m.cardPad

	if IsValid(self.NameLabel) then
		local priceW = IsValid(self.PriceLabel) and self.PriceLabel:GetWide() or 0
		self.NameLabel:SetPos(inset, inset)
		self.NameLabel:SetWide(math.max(0, w - 2 * inset - priceW - m.fine))
	end
	if IsValid(self.PriceLabel) then
		self.PriceLabel:SetPos(w - self.PriceLabel:GetWide() - inset, inset)
	end
	if IsValid(self.ModelFrame) and self.ModelFrame:IsVisible() then
		RelapseUI.PlaceCardIcon(self.ModelFrame, w, h)
	end
	if IsValid(self.ItemCounter) and self.ItemCounter:IsVisible() then
		self.ItemCounter:SetPos(w - self.ItemCounter:GetWide() - inset, h - self.ItemCounter:GetTall() - inset)
	end
	if IsValid(self.StockLabel) then
		self.StockLabel:SetPos(inset, h - self.StockLabel:GetTall() - inset)
	end
end

function ARSENAL_CARD:SetShopItem(id, tab)
	self.ID = tab and (tab.Signature or id) or id
	self.ShopTabl = tab
	self.NoPoints = false

	local m = RelapseUI.M()
	local inset = m.cardPad

	if not tab then
		self.ModelFrame:SetVisible(false)
		self.ItemCounter:SetVisible(false)
		self.NameLabel:SetText("")
		return
	end

	local missing_skill = tab.SkillRequirement and not (IsValid(MySelf) and MySelf:IsSkillActive(tab.SkillRequirement))
	local nottrinkets = tab.Category ~= ITEMCAT_TRINKETS
	self:SetCardSize(self.CardW or self:GetWide(), nottrinkets and m.cardH or m.trinketH)

	if nottrinkets then
		RelapseUI.PlaceCardIcon(self.ModelFrame, self:GetWide(), self.CardH)
		self.ModelFrame:SetVisible(true)
		for _, ch in ipairs(self.ModelFrame:GetChildren()) do
			if IsValid(ch) then ch:Remove() end
		end
		local kitbl = killicon.Get(GAMEMODE.ZSInventoryItemData[tab.SWEP] and "weapon_zs_craftables" or tab.SWEP or tab.Model)
		if not RelapseUI.TryAttachCardIcon(self, self.ModelFrame, tab, missing_skill) then
			if kitbl then
				GAMEMODE:AttachKillicon(kitbl, self, self.ModelFrame, tab.Category == ITEMCAT_AMMO, missing_skill)
			elseif tab.Model then
				local mdlpanel = vgui.Create("DModelPanel", self.ModelFrame)
				mdlpanel:SetSize(self.ModelFrame:GetSize())
				mdlpanel:SetModel(tab.Model)
				local mins, maxs = mdlpanel.Entity:GetRenderBounds()
				mdlpanel:SetCamPos(mins:Distance(maxs) * Vector(0.75, 0.75, 0.5))
				mdlpanel:SetLookAt((mins + maxs) / 2)
			end
		end
	else
		self.ModelFrame:SetVisible(false)
	end

	if tab.SWEP or tab.Countables then
		self.ItemCounter:SetVisible(true)
		self.ItemCounter:SetItemID(id)
	else
		self.ItemCounter:SetVisible(false)
	end

	if missing_skill then
		self.PriceLabel:SetTextColor(RelapseUI.Col.Danger)
		self.PriceLabel:SetText(GAMEMODE.Skills[tab.SkillRequirement].Name)
	elseif tab.Price then
		local price = math.floor(tab.Price * (MySelf.ArsenalDiscount or 1))
		self.PriceLabel:SetTextColor(RelapseUI.Col.Accent)
		self.PriceLabel:SetText(tostring(price))
	else
		self.PriceLabel:SetText("")
	end
	self.PriceLabel:SizeToContents()

	if tab.MaxStock then
		if not IsValid(self.StockLabel) then
			self.StockLabel = EasyLabel(self, "", "Relapse13", RelapseUI.Col.Muted)
		end
		self.StockLabel:SetText(RelapseUI.TF("shop_remaining", tab.MaxStock))
		self.StockLabel:SizeToContents()
	elseif IsValid(self.StockLabel) then
		self.StockLabel:SetVisible(false)
	end

	self.Locked = missing_skill or ItemIsLocked(tab)

	if not nottrinkets and tab.SubCategory then
		local catlabel = EasyLabel(self, RelapseUI.ShopSubCat(tab.SubCategory), "Relapse13", RelapseUI.Col.Muted)
		catlabel:SizeToContents()
		catlabel:SetPos(inset, self:GetTall() * 0.55 - catlabel:GetTall() * 0.5)
	end

	self.NameLabel:SetText(RelapseUI.WepName(tab))
	self.NameLabel:SetTextColor(RelapseUI.Col.Text)
	self.NameLabel:SizeToContents()
	self:InvalidateLayout()
end

function ARSENAL_CARD:Think()
	local tab = self.ShopTabl
	if not tab then return end

	self.Locked = ItemIsLocked(tab)
	self.m_LastAbleToBuy = CanBuy(tab, self)

	if IsValid(self.StockLabel) and tab.MaxStock then
		local stocks = GAMEMODE:GetItemStocks(self.ID)
		if stocks ~= self.m_LastStocks then
			self.m_LastStocks = stocks
			self.StockLabel:SetText(RelapseUI.TF("shop_remaining", stocks))
			self.StockLabel:SizeToContents()
			self.StockLabel:SetTextColor(stocks > 0 and RelapseUI.Col.Muted or RelapseUI.Col.Danger)
			self:InvalidateLayout()
		end
	end
end

function ARSENAL_CARD:Paint(w, h)
	RelapseUI.PaintCard(self, w, h, self.On, self.Locked, self.m_LastAbleToBuy == false)
	if self.ShopTabl and self.ShopTabl.SWEP and IsValid(MySelf) and MySelf:HasInventoryItem(self.ShopTabl.SWEP) then
		local wash = RelapseUI.Col.Wash
		surface.SetDrawColor(wash.r, wash.g, wash.b, wash.a or 40)
		surface.DrawRect(0, 0, w, h)
	end
	return true
end

function ARSENAL_CARD:OnCursorEntered()
	local shoptbl = self.ShopTabl
	if not shoptbl then return end

	local viewer = GAMEMODE.ArsenalInterface and GAMEMODE.ArsenalInterface.Viewer
	local sweptable = GAMEMODE.ZSInventoryItemData[shoptbl.SWEP] or weapons.Get(shoptbl.SWEP)
	if sweptable and IsValid(viewer) then
		GAMEMODE:SupplyItemViewerDetail(viewer, sweptable, shoptbl)
		if self.On then
			SetupViewerPurchase(self, viewer, shoptbl, sweptable)
		end
	end
end

function ARSENAL_CARD:DoClick()
	ItemPanelDoClick(self)
end

function ARSENAL_CARD:DoRightClick()
	local menu = DermaMenu(self)
	menu:AddOption(RelapseUI.T("shop_buy"), function()
		RunConsoleCommand("zs_pointsshopbuy", self.ID, self.NoPoints and "scrap")
	end)
	menu:Open()
end

vgui.Register("ZSArsenalButton", ARSENAL_CARD, "DButton")

function GM:AddArsenalCard(list, i, tab, L)
	local button = vgui.Create("ZSArsenalButton")
	local trinkets = tab.Category == ITEMCAT_TRINKETS
	button:SetCardSize(L.cardW, trinkets and L.m.trinketH or L.m.cardH)
	button:SetShopItem(i, tab)
	list:AddItem(button)
	return button
end

local function ArsenalThink(self)
	if not IsValid(MySelf) then return end
	if MySelf:Team() ~= TEAM_HUMAN then
		self:Close()
	end
end

function GM:OpenArsenalMenu()
	RelapseUI.HideOtherShops("points")
	if self.ArsenalInterface and self.ArsenalInterface:IsValid() then
		RelapseUI.ShowShopFrame(self.ArsenalInterface)
		return
	end

	local frame, L, topspace, bottomspace, propertysheet = RelapseUI.BuildShopFrame("shop_points_title", {
		deleteOnClose = false,
		shop = "points"
	})
	frame.Think = ArsenalThink
	self.ArsenalInterface = frame

	local m = L.m
	local chip, _, pointslab = RelapseUI.CreateShopChip(bottomspace, RelapseUI.T("shop_points_label"), IsValid(MySelf) and MySelf:GetPoints() or 0)
	frame.WorthLab = pointslab
	frame.WorthChip = chip
	pointslab.Think = function(me)
		if not IsValid(MySelf) then return end
		local points = MySelf:GetPoints()
		if me.m_LastPoints ~= points then
			me.m_LastPoints = points
			RelapseUI.UpdateWorthLabel(me, points)
		end
	end

	local buy = vgui.Create("DButton", bottomspace)
	buy:SetFont("Relapse20")
	buy:SetText(RelapseUI.T("shop_purchase"))
	buy:SetSize(RelapseUI.Cells(12), m.btnH)
	RelapseUI.AlignFooterRight(buy)
	RelapseUI.AlignFooterBottom(buy)
	buy.Paint = RelapseUI.PaintPrimaryButton
	buy.DoClick = function()
		local card = frame.SelectedBuy
		if not IsValid(card) then
			surface.PlaySound("buttons/button8.wav")
			return
		end
		RunConsoleCommand("zs_pointsshopbuy", card.ID, card.NoPoints and "scrap")
	end
	frame.Purchase = buy

	local ammo = vgui.Create("DButton", bottomspace)
	ammo:SetFont("Relapse20")
	ammo:SetText(RelapseUI.T("shop_ammo"))
	ammo:SetSize(RelapseUI.Cells(6), m.btnH)
	ammo:MoveLeftOf(buy, m.gutter)
	RelapseUI.AlignFooterBottom(ammo)
	ammo.Paint = RelapseUI.PaintGhostButton
	ammo.DoClick = function(me)
		if not me.AmmoType then
			surface.PlaySound("buttons/button8.wav")
			return
		end
		RunConsoleCommand("zs_pointsshopbuy", "ps_" .. me.AmmoType)
	end
	frame.AmmoB = ammo
	pointslab.RelapseBottomOf = buy

	local tierPanes = {}

	for catid in ipairs(GAMEMODE.ItemCategories) do
		if catid == ITEMCAT_OTHER then continue end

		local trinkets = catid == ITEMCAT_TRINKETS
		local usecats = catid == ITEMCAT_GUNS or catid == ITEMCAT_MELEE
		local host, grids

		if usecats then
			host = vgui.Create("DPanel", propertysheet)
			host.Paint = function() return true end
			host.Grids = {}
			host.TierFrames = {}
			host.PerformLayout = function(me, w, h)
				for _, sp in pairs(me.TierFrames) do
					sp:SetPos(0, 0)
					sp:SetSize(w, h)
				end
			end
			for i = 1, 5 do
				local itemframe = vgui.Create("DScrollPanel", host)
				itemframe.Paint = function() return true end
				RelapseUI.StyleScroll(itemframe)
				host.Grids[i] = RelapseUI.MakeShopGrid(itemframe, L, false)
				host.TierFrames[i] = itemframe
				itemframe:SetVisible(i == 1)
			end
			grids = host.Grids
			tierPanes[catid] = host
		else
			host = vgui.Create("DScrollPanel", propertysheet)
			host.Paint = function() return true end
			RelapseUI.StyleScroll(host)
			host.Grid = RelapseUI.MakeShopGrid(host, L, trinkets)
			grids = nil
		end

		local sheet = propertysheet:AddSheet(RelapseUI.ShopCat(catid), host, GAMEMODE.ItemCategoryIcons[catid], false, false)
		sheet.Panel:SetPos(0, L.tabhei + L.tabGap)

		for i, tab in ipairs(GAMEMODE.Items) do
			if tab.PointShop and tab.Category == catid then
				local list = host.Grid or grids[tab.Tier or 1]
				if IsValid(list) then
					self:AddArsenalCard(list, i, tab, L)
				end
			end
		end
	end

	local labels = {}
	for i = 1, 5 do
		labels[i] = RelapseUI.TF("shop_tier_short", i)
	end

	local function applyTier(idx)
		frame.RelapseTier = idx
		for _, pane in pairs(tierPanes) do
			for k, sp in pairs(pane.TierFrames) do
				sp:SetVisible(k == idx)
				if k == idx then
					sp:InvalidateLayout(true)
				end
			end
		end
	end

	local strip = RelapseUI.CreateFilterStrip(bottomspace, labels, 1, applyTier)
	strip:SetVisible(false)
	applyTier(1)
	RelapseUI.PlaceShopTiers(strip, L)

	local function syncSubTabs(tabpanel)
		local pan = tabpanel and tabpanel.GetPanel and tabpanel:GetPanel()
		local show = IsValid(pan) and pan.Grids ~= nil
		strip:SetVisible(show)
		if show then
			RelapseUI.PlaceShopTiers(strip, L)
		end
		if IsValid(frame.Viewer) then
			SetViewerPurchaseVisible(frame.Viewer, false)
		end
	end

	local tabs = {}
	for i, item in ipairs(propertysheet.Items or {}) do
		tabs[i] = item.Tab
	end

	self:CreateItemInfoViewer(frame, propertysheet, topspace, bottomspace, MENU_POINTSHOP)
	self:ConfigureMenuTabs(tabs, L.tabhei, syncSubTabs)
	syncSubTabs(propertysheet:GetActiveTab())

	self:PrecacheKillicons()
	RelapseUI.FinishShopFrame(frame, propertysheet)
end
