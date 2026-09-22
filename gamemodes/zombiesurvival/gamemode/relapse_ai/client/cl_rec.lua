-- Recorder HUD. relapse_ai_rec arms it; U starts and stops the chunk.
-- The clock is the server's current file: at 12s it returns to 0 and a new file opens.

local State = {
	armed = false,
	recording = false,
	elapsed = 0,
	at = 0,
	seq = 0,
	dur = 12,
}

local nextU = 0

surface.CreateFont("RelapseRec", {
	font = "Tahoma",
	size = 18,
	weight = 700,
	antialias = true,
	extended = true,
})

net.Receive("RelapseAI.Rec", function()
	State.armed = net.ReadBool()
	State.recording = net.ReadBool()
	State.elapsed = net.ReadFloat()
	State.seq = net.ReadUInt(10)
	State.dur = net.ReadUInt(8)
	if State.dur < 1 then State.dur = 12 end
	State.at = RealTime()
end)

local function Elapsed()
	local elapsed = State.elapsed + (RealTime() - State.at)
	if elapsed < 0 then elapsed = 0 end
	if State.recording and State.dur > 0 and elapsed >= State.dur then
		elapsed = elapsed % State.dur
	end
	return elapsed
end

local function Pulse()
	if not State.armed then return end
	if RealTime() < nextU then return end
	if gui.IsConsoleVisible() or gui.IsGameUIVisible() then return end
	if vgui.GetKeyboardFocus() then return end
	nextU = RealTime() + 0.2
	net.Start("RelapseAI.RecKey")
	net.SendToServer()
end

hook.Add("PlayerButtonDown", "RelapseAI.Rec", function(pl, button)
	if pl ~= LocalPlayer() or button ~= KEY_U then return end
	Pulse()
end)

hook.Add("PlayerBindPress", "RelapseAI.Rec", function(pl, bind, pressed)
	if not State.armed or not pressed or bind ~= "messagemode2" then return end
	if pl ~= LocalPlayer() then return end
	if gui.IsConsoleVisible() or gui.IsGameUIVisible() then return end
	if vgui.GetKeyboardFocus() then return end
	Pulse()
	return true
end)

hook.Add("HUDPaint", "RelapseAI.Rec", function()
	if not State.armed then return end

	local elapsed = Elapsed()
	local text
	local col
	if State.recording then
		text = string.format("REC  %.2f / %d    #%d    U — стоп", elapsed, State.dur, State.seq)
		col = Color(255, 84, 84)
	else
		text = "WAIT  0.00    U — запись"
		col = Color(232, 232, 232)
	end

	surface.SetFont("RelapseRec")
	local tw, th = surface.GetTextSize(text)
	local pad = 10
	local w, h = tw + pad * 2, th + 12
	local x = ScrW() * 0.5 - w * 0.5
	local y = 8

	draw.RoundedBox(4, x, y, w, h, Color(8, 8, 8, 210))
	draw.SimpleText(text, "RelapseRec", x + pad, y + 4, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	if State.recording and State.dur > 0 then
		local frac = math.Clamp(elapsed / State.dur, 0, 1)
		surface.SetDrawColor(255, 72, 72, 230)
		surface.DrawRect(x + 2, y + h - 3, (w - 4) * frac, 2)
	end
end)
