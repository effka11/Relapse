-- Own-crate margin as a separate popup (inventory DSideMenu pattern).
-- Never parented to the shop frame — that path ate Buy clicks.

local MARGIN_SEND_GAP = 0.08
local OWN_CRATE_RANGE_SQR = 10000

local function FmtMarginPct(p)
	local n = (tonumber(p) or 0) * 100
	if math.abs(n - math.floor(n + 0.5)) < 0.05 then
		return tostring(math.floor(n + 0.5))
	end
	return string.format("%.1f", n)
end

local function SendArsenalMarginKeep(share)
	net.Start("zs_arsenal_margin")
		net.WriteFloat(math.Clamp(tonumber(share) or 1, 0, 1))
	net.SendToServer()
end

local function QueueArsenalMargin(frame, share)
	share = math.Clamp(tonumber(share) or 1, 0, 1)
	frame._MarginShare = share
	frame._MarginPending = share
	if CurTime() >= (frame._MarginSent or 0) + MARGIN_SEND_GAP then
		SendArsenalMarginKeep(share)
		frame._MarginSent = CurTime()
		frame._MarginPending = nil
	end
end

local function FlushArsenalMargin(frame)
	if not IsValid(frame) or frame._MarginPending == nil then return end
	if CurTime() < (frame._MarginSent or 0) + MARGIN_SEND_GAP then return end
	if frame._MarginDrag then return end
	SendArsenalMarginKeep(frame._MarginPending)
	frame._MarginSent = CurTime()
	frame._MarginPending = nil
end

local function LayoutMarginKnob(track, share)
	local knob = IsValid(track) and track.Knob
	if not IsValid(knob) then return end
	share = math.Clamp(tonumber(share) or 1, 0, 1)
	local kw, kh = knob:GetWide(), knob:GetTall()
	local x = math.floor((track:GetWide() - kw) * share + 0.5)
	local y = math.floor((track:GetTall() - kh) * 0.5)
	knob:SetPos(x, y)
end

local function ShareFromTrack(track, x)
	local knob = track.Knob
	local kw = IsValid(knob) and knob:GetWide() or RelapseUI.Grid15()
	local span = math.max(1, track:GetWide() - kw)
	return math.Clamp((x - kw * 0.5) / span, 0, 1)
end

local function StopMarginDrag(frame)
	frame._MarginDrag = false
	local track = frame.MarginTrack
	if IsValid(track) then
		track:MouseCapture(false)
	end
end

local function HideMarginSide(frame)
	StopMarginDrag(frame)
	local wrap = frame.MarginWrap
	if IsValid(wrap) then
		wrap:SetVisible(false)
		wrap:SetMouseInputEnabled(false)
	end
end

local function CrateOwner(ent)
	if not IsValid(ent) then
		return nil
	end
	if GAMEMODE and GAMEMODE.GetArsenalCrateOwner then
		local owner = GAMEMODE:GetArsenalCrateOwner(ent)
		if owner then
			return owner
		end
	end
	if ent.GetObjectOwner then
		local owner = ent:GetObjectOwner()
		if IsValid(owner) then
			return owner
		end
	end
	if ent.GetOwner then
		local owner = ent:GetOwner()
		if IsValid(owner) then
			return owner
		end
	end
end

-- Nearest own crate/pack in shop range. No WorldVisible: pack on the back fails that trace.
local function AtOwnCrateShop()
	if not IsValid(MySelf) then
		return nil
	end
	local pos = MySelf:EyePos()
	local entsAround = ents.FindByClass("prop_arsenalcrate")
	table.Add(entsAround, ents.FindByClass("status_arsenalpack"))
	local best, bestDist
	for i = 1, #entsAround do
		local ent = entsAround[i]
		if CrateOwner(ent) == MySelf then
			local nearest = ent:NearestPoint(pos)
			local dist = pos:DistToSqr(nearest)
			if dist <= OWN_CRATE_RANGE_SQR and (not best or dist < bestDist) then
				best, bestDist = ent, dist
			end
		end
	end
	return best
end

local function MarginRate()
	if GAMEMODE and GAMEMODE.GetArsenalMarginRate then
		return GAMEMODE:GetArsenalMarginRate(MySelf, AtOwnCrateShop())
	end
	return (GAMEMODE and GAMEMODE.ArsenalCrateCommission) or 0.04
end

local function FitPctLabel(lab)
	if not IsValid(lab) then return end
	lab:SizeToContents()
	lab:SetWide(lab:GetWide() + RelapseUI.sPx(8))
	lab:NoClipping(true)
end

local function SetMarginHead(frame, rate)
	local cap = frame.MarginCap
	if IsValid(cap) then
		cap:SetText(RelapseUI.T("shop_arsenal_margin", "Margin") .. "  " .. FmtMarginPct(rate) .. "%")
		FitPctLabel(cap)
	end
end

local function UpdateMarginHint(frame)
	local hint = frame.MarginHint
	if not IsValid(hint) then return end
	local rate = MarginRate()
	local share = frame._MarginShare or 1
	local keep = rate * share
	local give = rate * (1 - share)
	if give >= 0.0005 then
		hint:SetText(RelapseUI.TF("shop_arsenal_margin_give", FmtMarginPct(give)))
	else
		hint:SetText(RelapseUI.TF("shop_arsenal_margin_keep", FmtMarginPct(keep)))
	end
	FitPctLabel(hint)
end

local function PlaceMarginSide(frame)
	local wrap = frame.MarginWrap
	if not (IsValid(frame) and IsValid(wrap) and wrap:IsVisible()) then return end
	local L = RelapseUI.InvWindowSize()
	local gap = (L and L.actionGap) or RelapseUI.sPx(30)
	local pad = RelapseUI.Grid15(3)
	local fx, fy = frame:GetPos()
	wrap:SetWide(RelapseUI.Grid15(18))
	wrap:InvalidateLayout(true)
	local wantH = wrap._NeedH or RelapseUI.Grid15(12)
	wrap:SetTall(wantH)
	local ax = fx + frame:GetWide() + gap
	local maxX = ScrW() - pad - wrap:GetWide()
	if ax > maxX then
		ax = math.max(pad, maxX)
	end
	wrap:SetPos(ax, fy)
	wrap:MoveToFront()
end

local function SyncArsenalMarginUI(frame)
	if not IsValid(frame) then return end
	local wrap = frame.MarginWrap
	local track = frame.MarginTrack
	local cap = frame.MarginCap
	local hint = frame.MarginHint
	if not (IsValid(wrap) and IsValid(track) and IsValid(hint)) then return end

	if not frame:IsVisible() or frame._RelapseClosing then
		HideMarginSide(frame)
		return
	end

	if not AtOwnCrateShop() then
		HideMarginSide(frame)
		return
	end

	local maxPct = MarginRate()
	if maxPct < 0.01 then
		HideMarginSide(frame)
		return
	end

	if not wrap:IsVisible() then
		wrap:SetVisible(true)
		wrap:MakePopup()
		wrap:SetKeyboardInputEnabled(false)
	end
	wrap:SetMouseInputEnabled(true)
	wrap:SetAlpha(frame:GetAlpha())
	track:SetVisible(true)
	if IsValid(cap) then cap:SetVisible(true) end
	hint:SetVisible(true)

	if not frame._MarginDrag then
		local share = 1
		if MySelf.GetArsenalMarginKeepShare then
			share = MySelf:GetArsenalMarginKeepShare()
		end
		frame._MarginShare = share
		LayoutMarginKnob(track, share)
		UpdateMarginHint(frame)
		SetMarginHead(frame, maxPct)
	end
	PlaceMarginSide(frame)
	FlushArsenalMargin(frame)
end

local function BuildArsenalMarginUI(frame)
	if not IsValid(frame) then return end

	if IsValid(frame.MarginWrap) then
		return
	end

	local wrap = vgui.Create("DPanel")
	wrap:SetMouseInputEnabled(false)
	wrap:SetKeyboardInputEnabled(false)
	wrap:SetWide(RelapseUI.Grid15(18))
	wrap:SetTall(RelapseUI.Grid15(12))
	wrap.Paint = RelapseUI.PaintWindow
	wrap:SetVisible(false)
	frame.MarginWrap = wrap

	local cap = EasyLabel(wrap, RelapseUI.T("shop_arsenal_margin", "Margin"), "Relapse20", RelapseUI.Col.Text)
	frame.MarginCap = cap

	local track = vgui.Create("DButton", wrap)
	track:SetText("")
	track:SetKeyboardInputEnabled(false)
	track.Paint = function(me, w, h)
		RelapseUI.PaintSliderTrack(me, w, h)
		return true
	end
	frame.MarginTrack = track

	local knob = vgui.Create("DButton", track)
	knob:SetText("")
	knob:SetKeyboardInputEnabled(false)
	local ks = RelapseUI.Grid15()
	knob:SetSize(ks, ks)
	knob.Paint = RelapseUI.PaintSliderKnob
	track.Knob = knob

	local hint = EasyLabel(wrap, "", "Relapse15", RelapseUI.Col.Muted)
	frame.MarginHint = hint
	frame._MarginShare = 1

	local function applyFromX(x)
		local share = ShareFromTrack(track, x)
		QueueArsenalMargin(frame, share)
		LayoutMarginKnob(track, share)
		UpdateMarginHint(frame)
		SetMarginHead(frame, MarginRate())
	end

	local function finishMarginDrag()
		frame._MarginDrag = false
		track:MouseCapture(false)
		FlushArsenalMargin(frame)
	end

	local function startDrag(x)
		frame._MarginDrag = true
		track:MouseCapture(true)
		applyFromX(x)
	end

	track.Think = function(me)
		if not frame._MarginDrag then return end
		if not input.IsMouseDown(MOUSE_LEFT) then
			finishMarginDrag()
			return
		end
		local mx = me:ScreenToLocal(gui.MousePos())
		applyFromX(mx)
	end
	track.OnMousePressed = function(me, mc)
		if mc ~= MOUSE_LEFT then return end
		local mx = me:ScreenToLocal(gui.MousePos())
		startDrag(mx)
	end
	track.OnMouseReleased = function(me, mc)
		if mc == MOUSE_LEFT then
			finishMarginDrag()
		end
	end
	knob.OnMousePressed = function(me, mc)
		if mc ~= MOUSE_LEFT then return end
		local mx = track:ScreenToLocal(gui.MousePos())
		startDrag(mx)
	end
	knob.OnMouseReleased = track.OnMouseReleased

	wrap.PerformLayout = function(me, w, h)
		local pad = RelapseUI.Grid15(2)
		local inner = math.max(1, w - pad * 2)
		local capH = IsValid(cap) and cap:GetTall() or RelapseUI.sPx(20)
		local trackH = RelapseUI.Grid15()
		local hintH = IsValid(hint) and hint:GetTall() or RelapseUI.sPx(15)
		local y = pad
		if IsValid(cap) then
			cap:SetPos(pad, y)
			y = y + capH + RelapseUI.sPx(8)
		end
		track:SetPos(pad, y)
		track:SetSize(inner, trackH)
		LayoutMarginKnob(track, frame._MarginShare or 1)
		y = y + trackH + RelapseUI.sPx(8)
		if IsValid(hint) then
			hint:SetPos(pad, y)
			hint:SetWide(math.max(hint:GetWide(), inner))
			y = y + hintH
		end
		me._NeedH = y + pad
	end

	wrap.OnRemove = function()
		if IsValid(frame) then
			frame.MarginWrap = nil
		end
	end

	local prevRemove = frame.OnRemove
	frame.OnRemove = function(me)
		if prevRemove then prevRemove(me) end
		if IsValid(me.MarginWrap) then
			me.MarginWrap:Remove()
		end
	end
end

local function HookMarginThink(frame)
	if frame._RelapseMarginThink then return end
	frame._RelapseMarginThink = true
	local prev = frame.Think
	frame.Think = function(self)
		if prev then prev(self) end
		if not IsValid(self) then return end
		local ok, err = pcall(SyncArsenalMarginUI, self)
		if not ok then
			ErrorNoHalt("[Relapse] arsenal margin: " .. tostring(err) .. "\n")
			HideMarginSide(self)
		end
	end
end

local function AttachArsenalMargin(frame)
	if not IsValid(frame) then return end
	BuildArsenalMarginUI(frame)
	HookMarginThink(frame)
	SyncArsenalMarginUI(frame)
end

local function InstallArsenalMarginWrap()
	local gm = GAMEMODE or GM
	if not (gm and gm.OpenArsenalMenu) or gm._RelapseArsenalMarginWrap then
		return gm and gm._RelapseArsenalMarginWrap
	end
	gm._RelapseArsenalMarginWrap = true
	local OpenArsenalMenu = gm.OpenArsenalMenu
	function gm:OpenArsenalMenu(...)
		OpenArsenalMenu(self, ...)
		local frame = self.ArsenalInterface
		if not IsValid(frame) then return end
		local ok, err = pcall(AttachArsenalMargin, frame)
		if not ok then
			ErrorNoHalt("[Relapse] arsenal margin: " .. tostring(err) .. "\n")
			pcall(HideMarginSide, frame)
			local wrap = frame.MarginWrap
			if IsValid(wrap) then
				frame.MarginWrap = nil
				wrap:Remove()
			end
		end
	end
	return true
end

if not InstallArsenalMarginWrap() then
	hook.Add("InitPostEntity", "RelapseArsenalMarginWrap", function()
		InstallArsenalMarginWrap()
	end)
end
