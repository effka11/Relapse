-- Replaces the engine flashlight beam with a projected texture.
-- F toggles it. relapse_flashlight_dev opens the sliders; E toggles the cursor.

local TEXTURE = "effects/flashlight001"

local P = {
	fov = 85,
	far = 599,
	bright = 0.10,
	near = 1,
	forward = 28.8,
	wall = 22,
	pullIn = 18.5,
	pullOut = 6,
	side = 0,
	drop = 0,
	reach = 1600,
	spring = 35.4,
	damp = 0.8,
	bob = 0.55,
	shadow = 1.05,
	shadows = true,
	r = 255,
	g = 221,
	b = 188,
}

local DEFAULTS = {}
for key, value in pairs(P) do
	DEFAULTS[key] = value
end

local states = {}

local function dropLamp(lamp)
	if lamp and lamp:IsValid() then
		lamp:Remove()
	end
end

local function dropState(ply)
	local st = states[ply]
	if not st then return end
	dropLamp(st.beam)
	states[ply] = nil
end

local function shutdown()
	for ply in pairs(states) do
		dropState(ply)
	end
	gui.EnableScreenClicker(false)
	if RelapseUI and IsValid(RelapseUI.FlashlightDevPanel) then
		local frame = RelapseUI.FlashlightDevPanel
		RelapseUI.FlashlightDevPanel = nil
		frame.OnClose = function() end
		frame:Remove()
	end
end

if GAMEMODE then
	if GAMEMODE.RelapseFlashlightShutdown then
		GAMEMODE.RelapseFlashlightShutdown()
	end
	GAMEMODE.RelapseFlashlightShutdown = shutdown
end

function GM:ShouldDrawFlashlight(ply)
	return false
end

local function springAxis(cur, vel, goal, dt)
	local err = math.AngleDifference(goal, cur)
	local acc = P.spring * P.spring * err - 2 * P.damp * P.spring * vel
	vel = math.Clamp(vel + acc * dt, -420, 420)
	cur = math.NormalizeAngle(cur + vel * dt)
	return cur, vel
end

local function aimOf(ply, st, dt)
	local goal = ply:EyeAngles()
	if not st.init then
		st.pitch, st.yaw = goal.p, goal.y
		st.vp, st.vy = 0, 0
		st.init = true
	end

	st.pitch, st.vp = springAxis(st.pitch, st.vp, goal.p, dt)
	st.yaw, st.vy = springAxis(st.yaw, st.vy, goal.y, dt)

	local ang = Angle(st.pitch, st.yaw, 0)
	local move = math.Clamp(ply:GetVelocity():Length2D() / 190, 0, 1)
	if move > 0 then
		local t = CurTime()
		ang.p = ang.p + math.sin(t * 14) * P.bob * move
		ang.y = ang.y + math.cos(t * 7) * P.bob * 0.7 * move
	end
	return ang
end

local function originOf(ply, ang, st, dt)
	local pos = ply:GetShootPos()
	local fwd = ang:Forward()
	local tr = util.TraceLine({
		start = pos,
		endpos = pos + fwd * P.wall,
		filter = ply,
		mask = MASK_SOLID,
	})

	local target = P.forward
	if tr.StartSolid then
		target = 0
	elseif tr.Hit then
		target = math.min(P.forward, math.max(0, tr.Fraction * P.wall - 2))
	end

	if st.dist == nil then
		st.dist = target
	else
		local rate = target < st.dist and P.pullIn or P.pullOut
		st.dist = st.dist + (target - st.dist) * (1 - math.exp(-rate * dt))
	end

	return pos + fwd * st.dist + ang:Right() * P.side - ang:Up() * P.drop
end

local function makeLamp()
	local lamp = ProjectedTexture()
	if not lamp then return nil end

	lamp:SetTexture(TEXTURE)
	return lamp
end

local function pushLamp(lamp)
	if not lamp or not lamp:IsValid() then return end
	lamp:SetFOV(P.fov)
	lamp:SetFarZ(P.far)
	lamp:SetNearZ(P.near)
	lamp:SetBrightness(P.bright)
	lamp:SetColor(Color(P.r, P.g, P.b))
	lamp:SetEnableShadows(P.shadows)
	if P.shadows then
		lamp:SetShadowFilter(P.shadow)
	end
end

local function ensure(st)
	local lamp = st.beam
	if lamp and lamp:IsValid() then return lamp end
	lamp = makeLamp()
	st.beam = lamp
	return lamp
end

local function wantsLight(ply, lp)
	if not IsValid(ply) or not ply:Alive() then return false end
	if ply:Team() ~= TEAM_HUMAN then return false end
	if ply:GetObserverMode() ~= OBS_MODE_NONE then return false end
	if not ply:GetNW2Bool("RelapseFlashlight") then return false end
	if ply ~= lp and ply:GetPos():DistToSqr(lp:GetPos()) > P.reach * P.reach then return false end
	return true
end

hook.Add("Think", "RelapseFlashlight", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local dt = math.min(FrameTime(), 0.05)
	if dt <= 0 then return end

	local seen = {}
	for _, ply in ipairs(player.GetAll()) do
		if wantsLight(ply, lp) then
			seen[ply] = true
			local st = states[ply]
			if not st then
				st = {}
				states[ply] = st
			end

			local beam = ensure(st)
			local ang = aimOf(ply, st, dt)
			local pos = originOf(ply, ang, st, dt)

			if beam then
				pushLamp(beam)
				beam:SetPos(pos)
				beam:SetAngles(ang)
				beam:Update()
			end
		end
	end

	for ply in pairs(states) do
		if not seen[ply] then
			dropState(ply)
		end
	end
end)

hook.Add("OnReloaded", "RelapseFlashlight", shutdown)
hook.Add("ShutDown", "RelapseFlashlight", shutdown)

local DevOn = false
local Clicker = false

local SPECS = {
	{ id = "bright", text = "Яркость", min = 0, max = 3, dec = 2 },
	{ id = "fov", text = "Угол", min = 20, max = 120, dec = 0 },
	{ id = "far", text = "Дальность", min = 100, max = 2000, dec = 0 },
	{ id = "near", text = "Ближняя", min = 1, max = 64, dec = 0 },
	{ id = "forward", text = "Вперёд", min = 0, max = 48, dec = 1 },
	{ id = "side", text = "Вправо", min = -24, max = 24, dec = 1 },
	{ id = "drop", text = "Вниз", min = -24, max = 24, dec = 1 },
	{ id = "wall", text = "Стена", min = 4, max = 96, dec = 0 },
	{ id = "pullIn", text = "К стене", min = 1, max = 40, dec = 1 },
	{ id = "pullOut", text = "В проём", min = 1, max = 40, dec = 1 },
	{ id = "spring", text = "Пружина", min = 1, max = 40, dec = 1 },
	{ id = "damp", text = "Затухание", min = 0.05, max = 2, dec = 2 },
	{ id = "bob", text = "Шаг", min = 0, max = 3, dec = 2 },
	{ id = "reach", text = "Чужие", min = 200, max = 4000, dec = 0 },
	{ id = "shadow", text = "Мягкость тени", min = 0, max = 4, dec = 2 },
	{ id = "r", text = "Красный", min = 0, max = 255, dec = 0 },
	{ id = "g", text = "Зелёный", min = 0, max = 255, dec = 0 },
	{ id = "b", text = "Синий", min = 0, max = 255, dec = 0 },
}

local function paramText()
	local lines = { P.shadows and "Тени: вкл" or "Тени: выкл" }
	for _, spec in ipairs(SPECS) do
		lines[#lines + 1] = string.format("%s %." .. spec.dec .. "f", spec.text, P[spec.id])
	end
	return table.concat(lines, "\n")
end

local function dump()
	print(paramText())
end

local function setClicker(on)
	Clicker = on and true or false
	gui.EnableScreenClicker(Clicker)
	local frame = RelapseUI and RelapseUI.FlashlightDevPanel
	if not IsValid(frame) then return end
	frame:SetMouseInputEnabled(Clicker)
	frame:SetKeyboardInputEnabled(false)
	if Clicker then
		frame:MakePopup()
		frame:SetKeyboardInputEnabled(false)
	end
end

local function paintButton(me, w, h)
	local col = RelapseUI.Col
	surface.SetDrawColor(me:IsHovered() and col.CardHover or col.Card)
	surface.DrawRect(0, 0, w, h)
	draw.SimpleText(me:GetText(), "Relapse20", w * 0.5, h * 0.5, col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	return true
end

local function openPanel()
	if IsValid(RelapseUI.FlashlightDevPanel) then
		RelapseUI.FlashlightDevPanel:SetVisible(true)
		setClicker(true)
		return
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(380, math.min(760, ScrH() - 48))
	frame:SetPos(24, 24)
	frame:SetTitle("")
	frame:SetDraggable(true)
	frame:ShowCloseButton(true)
	frame:SetDeleteOnClose(true)
	frame.Paint = function(me, w, h)
		RelapseUI.PaintWindow(me, w, h)
		draw.SimpleText("Фонарик", "Relapse20", 14, 10, RelapseUI.Col.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("E — курсор", "Relapse15", 14, 30, RelapseUI.Col.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	frame.OnClose = function()
		dump()
		Clicker = false
		gui.EnableScreenClicker(false)
		DevOn = false
		if RelapseUI.FlashlightDevPanel == frame then
			RelapseUI.FlashlightDevPanel = nil
		end
	end

	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:SetPos(4, 52)
	scroll:SetSize(frame:GetWide() - 8, frame:GetTall() - 108)
	local canvas = scroll:GetCanvas()

	local sliders = {}
	local filling = false

	local shadows = vgui.Create("DButton", canvas)
	shadows:Dock(TOP)
	shadows:SetTall(32)
	shadows:DockMargin(8, 0, 8, 6)
	shadows:SetText(P.shadows and "Тени: вкл" or "Тени: выкл")
	shadows.Paint = paintButton
	shadows.DoClick = function()
		P.shadows = not P.shadows
		shadows:SetText(P.shadows and "Тени: вкл" or "Тени: выкл")
	end

	local function resetParams()
		filling = true
		for key, value in pairs(DEFAULTS) do
			P[key] = value
		end
		for _, spec in ipairs(SPECS) do
			if IsValid(sliders[spec.id]) then
				sliders[spec.id]:SetValue(P[spec.id])
			end
		end
		shadows:SetText(P.shadows and "Тени: вкл" or "Тени: выкл")
		filling = false
	end

	for _, spec in ipairs(SPECS) do
		local slider = vgui.Create("DNumSlider", canvas)
		slider:Dock(TOP)
		slider:SetTall(40)
		slider:DockMargin(8, 0, 8, 0)
		slider:SetText(spec.text)
		slider:SetMin(spec.min)
		slider:SetMax(spec.max)
		slider:SetDecimals(spec.dec)
		RelapseUI.StyleNumSlider(slider)
		slider.OnValueChanged = function(_, value)
			if filling then return end
			P[spec.id] = value
		end
		slider:SetValue(P[spec.id])
		sliders[spec.id] = slider
	end

	local gap = 8
	local wide = math.floor((frame:GetWide() - 24 - gap) / 2)
	local rowY = frame:GetTall() - 44

	local reset = vgui.Create("DButton", frame)
	reset:SetPos(12, rowY)
	reset:SetSize(wide, 32)
	reset:SetText("Сброс")
	reset.Paint = paintButton
	reset.DoClick = resetParams

	local copy = vgui.Create("DButton", frame)
	copy:SetPos(12 + wide + gap, rowY)
	copy:SetSize(wide, 32)
	copy:SetText("Копировать")
	copy.Paint = paintButton
	copy.DoClick = function()
		local text = paramText()
		SetClipboardText(text)
		print(text)
		local ply = LocalPlayer()
		if IsValid(ply) then
			ply:ChatPrint("Параметры фонарика скопированы")
		end
	end

	RelapseUI.FlashlightDevPanel = frame
	setClicker(true)
end

local function closePanel()
	local frame = RelapseUI and RelapseUI.FlashlightDevPanel
	if IsValid(frame) then
		frame:Close()
		return
	end
	setClicker(false)
	DevOn = false
end

concommand.Add("relapse_flashlight_dev", function(_, _, args)
	if args[1] ~= nil and args[1] ~= "" then
		local v = string.lower(tostring(args[1]))
		DevOn = not (v == "0" or v == "false" or v == "off")
	else
		DevOn = not DevOn
	end

	if DevOn then
		openPanel()
	else
		closePanel()
	end

	local ply = LocalPlayer()
	if IsValid(ply) then
		ply:ChatPrint(DevOn and "relapse_flashlight_dev: E — курсор" or "relapse_flashlight_dev: выкл")
	end
	print("relapse_flashlight_dev = " .. (DevOn and "1" or "0"))
end)

hook.Add("PlayerBindPress", "RelapseFlashlightDev", function(pl, bind, pressed)
	if not DevOn or pl ~= LocalPlayer() or not pressed then return end
	if bind ~= "+use" then return end
	return true
end)

hook.Add("PlayerButtonDown", "RelapseFlashlightDev", function(pl, button)
	if button ~= KEY_E then return end
	if pl ~= LocalPlayer() then return end
	if not IsFirstTimePredicted() then return end
	if not DevOn then return end
	if gui.IsConsoleVisible() or gui.IsGameUIVisible() then return end
	if pl.IsTyping and pl:IsTyping() then return end
	local focus = vgui.GetKeyboardFocus()
	if IsValid(focus) and focus.IsEditing and focus:IsEditing() then return end
	setClicker(not Clicker)
end)
