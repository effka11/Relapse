-- Relapse AI debug overlay (client). Receives snapshots from relapse_ai/server/90_debug.lua
-- while the server has relapse_ai_debug > 0 and draws paths, goals, aim points and
-- state labels. Toggle locally with relapse_ai_debug_draw 0/1.

local cvDraw = CreateClientConVar("relapse_ai_debug_draw", "1", true, false, "Draw the Relapse AI debug overlay when the server streams it.")
local cvXray = CreateClientConVar("relapse_ai_debug_xray", "1", true, false, "Draw Relapse AI debug lines through walls.")

concommand.Add("relapse_ai_debug", function(_, _, args)
	local n = tonumber(args[1])
	net.Start("RelapseAI.DebugCmd")
	net.WriteInt(n == nil and -1 or math.Clamp(math.floor(n), 0, 2), 3)
	net.SendToServer()
end)

local Snapshot = {Bots = {}, Time = -10, ComputesPerSec = 0, AvgMs = 0, Blocked = 0}

local MODE_NAME = {[0] = "stop", [1] = "path", [2] = "direct"}

local STATE_COLORS = {
	hunt = Color(255, 70, 70),
	search = Color(255, 160, 60),
	sigil = RelapseUI.CopyCol(RelapseUI.Col.Text),
	["break"] = Color(255, 230, 60),
	wander = Color(120, 220, 120),
	crow = Color(200, 200, 200),
	dead = Color(90, 90, 90),
}
local DEFAULT_COLOR = Color(200, 200, 200)

local function ReadOptionalVector()
	if net.ReadBool() then
		return net.ReadVector()
	end
	return nil
end

net.Receive("RelapseAI.Debug", function()
	local count = net.ReadUInt(8)
	local bots = {}

	for i = 1, count do
		local bot = {}
		bot.Player = net.ReadEntity()
		bot.State = net.ReadString()
		bot.ThinkMs = net.ReadFloat()
		bot.Stuck = net.ReadUInt(4)
		local mode = net.ReadUInt(3)
		bot.Hold = mode >= 4
		bot.Mode = MODE_NAME[mode % 4] or "?"
		bot.Goal = ReadOptionalVector()
		bot.Steer = ReadOptionalVector()
		bot.Aim = ReadOptionalVector()
		bot.InReach = net.ReadBool()
		bot.Target = net.ReadEntity()

		local n = net.ReadUInt(6)
		local pts = {}
		for j = 1, n do
			pts[j] = net.ReadVector()
		end
		bot.Path = pts

		bots[i] = bot
	end

	Snapshot.Bots = bots
	Snapshot.ComputesPerSec = net.ReadFloat()
	Snapshot.AvgMs = net.ReadFloat()
	Snapshot.Blocked = net.ReadUInt(16)
	Snapshot.Time = RealTime()
end)

local function Active()
	return cvDraw:GetBool() and RealTime() - Snapshot.Time < 2
end

hook.Add("PostDrawTranslucentRenderables", "RelapseAI.Debug", function(depth, skybox)
	if skybox or not Active() then return end

	local xray = cvXray:GetBool()
	if xray then
		cam.IgnoreZ(true)
		render.SetColorMaterialIgnoreZ()
	else
		render.SetColorMaterial()
	end

	local lift = Vector(0, 0, 4)
	for _, bot in ipairs(Snapshot.Bots) do
		local color = STATE_COLORS[bot.State] or DEFAULT_COLOR

		local pts = bot.Path
		for i = 1, #pts - 1 do
			render.DrawLine(pts[i] + lift, pts[i + 1] + lift, color, false)
		end

		if bot.Goal then
			render.DrawWireframeSphere(bot.Goal, 10, 6, 6, color, false)
		end
		if bot.Steer then
			render.DrawWireframeSphere(bot.Steer, 4, 4, 4, Color(255, 255, 255), false)
		end

		local pl = bot.Player
		if IsValid(pl) and bot.Aim then
			local eye = pl:EyePos()
			render.DrawLine(eye, bot.Aim, bot.InReach and Color(255, 40, 40) or Color(255, 140, 140), false)
			render.DrawWireframeSphere(bot.Aim, 3, 4, 4, Color(255, 40, 40), false)
		end

		if IsValid(pl) and bot.Steer then
			render.DrawLine(pl:GetPos() + Vector(0, 0, 8), bot.Steer, Color(255, 255, 255, 120), false)
		end
	end

	if xray then
		cam.IgnoreZ(false)
	end
end)

hook.Add("HUDPaint", "RelapseAI.Debug", function()
	if not Active() then return end

	local y = 220
	draw.SimpleTextOutlined(string.format("Relapse AI: %d bots | paths %.1f/s (avg %.2f ms) | blocked areas %d",
		#Snapshot.Bots, Snapshot.ComputesPerSec, Snapshot.AvgMs, Snapshot.Blocked),
		"DermaDefaultBold", 16, y, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))

	for _, bot in ipairs(Snapshot.Bots) do
		local pl = bot.Player
		if IsValid(pl) then
			local pos = pl:EyePos() + Vector(0, 0, 20)
			local scr = pos:ToScreen()
			if scr.visible then
				local color = STATE_COLORS[bot.State] or DEFAULT_COLOR
				local label = string.format("%s  [%s]  %s%s  stuck %d  %.2f ms",
					pl:Nick(), bot.State, bot.Mode, bot.Hold and "/hold" or "", bot.Stuck, bot.ThinkMs)
				draw.SimpleTextOutlined(label, "DermaDefaultBold", scr.x, scr.y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 220))

				local target = bot.Target
				if IsValid(target) then
					local tname = target:IsPlayer() and target:Nick() or target:GetClass()
					draw.SimpleTextOutlined("-> " .. tname .. (bot.InReach and " (in reach)" or ""), "DermaDefault", scr.x, scr.y + 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
				end
			end
		end
	end
end)
