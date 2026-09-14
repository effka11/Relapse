-- Relapse AI debug streaming. debugoverlay does nothing on a dedicated server, so
-- the overlay is drawn client-side (relapse_ai/client/cl_debug.lua) from a compact
-- snapshot sent a few times per second while relapse_ai_debug > 0.

local AI = RelapseAI
local Debug = {}
AI.Debug = Debug

local CurTime = CurTime
local IsValid = IsValid
local ipairs = ipairs

util.AddNetworkString("RelapseAI.Debug")
util.AddNetworkString("RelapseAI.DebugCmd")

Debug.Interval = 0.2
Debug.MaxPathPoints = 24

local MODE_ID = {stop = 0, path = 1, direct = 2}

local function WriteOptionalVector(vec)
	if vec then
		net.WriteBool(true)
		net.WriteVector(vec)
	else
		net.WriteBool(false)
	end
end

local function CanWatch(pl, level)
	if not IsValid(pl) then return false end
	if level >= 2 then return true end
	if pl:IsSuperAdmin() then return true end
	local Mesh = AI.Mesh
	return Mesh and Mesh.IsOwner and Mesh.IsOwner(pl)
end

local function Recipients(level)
	local out = {}
	for _, pl in ipairs(player.GetHumans()) do
		if CanWatch(pl, level) then
			out[#out + 1] = pl
		end
	end
	return out
end

local nextSend = 0

hook.Add("Think", "RelapseAI.Debug", function()
	local level = AI.cv.debug:GetInt()
	if level <= 0 then return end

	local now = CurTime()
	if now < nextSend then return end
	nextSend = now + Debug.Interval

	local recipients = Recipients(level)
	if #recipients == 0 then return end

	local bots = {}
	for _, bot in ipairs(AI.BotList) do
		if IsValid(bot.Player) then
			bots[#bots + 1] = bot
		end
	end

	net.Start("RelapseAI.Debug", true)
	net.WriteUInt(math.min(#bots, 255), 8)

	for i = 1, math.min(#bots, 255) do
		local bot = bots[i]
		local pl = bot.Player
		local loco = bot.Loco
		local combat = bot.Combat

		net.WriteEntity(pl)
		-- State plus the last locomotion decision (jump:climb, duck:under, detour, ladder:climb...).
		local state = bot.Debug.State or ""
		if loco.Ladder then
			state = state .. " ladder:" .. loco.Ladder.Phase
		end
		local note = loco.GetNote and loco:GetNote(2)
		net.WriteString(state .. (note and (" " .. note) or ""))
		net.WriteFloat(bot.ThinkMs or 0)
		net.WriteUInt(math.min(loco.StuckLevel or 0, 15), 4)
		net.WriteUInt((MODE_ID[loco.Mode] or 0) + (loco.Hold and 4 or 0), 3)

		WriteOptionalVector(loco.Goal)
		WriteOptionalVector(loco.SteerPos)

		local aim = combat and combat.Target and combat:GetAimPos() or nil
		WriteOptionalVector(aim)
		net.WriteBool(combat and combat.InReach or false)

		local target = combat and combat.Target
		net.WriteEntity(IsValid(target) and target or NULL)

		local segs = loco.PathValid and loco.Segments or nil
		if segs and #segs > 0 then
			local n = #segs
			local step = math.max(1, math.ceil(n / Debug.MaxPathPoints))
			local pts = {}
			for j = 1, n, step do
				pts[#pts + 1] = segs[j].pos
			end
			if pts[#pts] ~= segs[n].pos then
				pts[#pts + 1] = segs[n].pos
			end
			net.WriteUInt(#pts, 6)
			for _, p in ipairs(pts) do
				net.WriteVector(p)
			end
		else
			net.WriteUInt(0, 6)
		end
	end

	net.WriteFloat(AI.Nav.Stats.ComputesPerSec or 0)
	net.WriteFloat(AI.Nav.Stats.AvgMs or 0)
	net.WriteUInt(math.min(table.Count(AI.Nav.BlockedAreas), 65535), 16)
	net.Send(recipients)
end)

local function CanToggle(pl)
	if not IsValid(pl) then return true end
	if pl:IsSuperAdmin() then return true end
	local Mesh = AI.Mesh
	return Mesh and Mesh.IsOwner and Mesh.IsOwner(pl)
end

net.Receive("RelapseAI.DebugCmd", function(_, pl)
	if not CanToggle(pl) then return end
	local n = net.ReadInt(3)
	if n < 0 then
		n = AI.cv.debug:GetInt() > 0 and 0 or 1
	end
	n = math.Clamp(n, 0, 2)
	AI.cv.debug:SetInt(n)
	local msg = n == 0 and "[Relapse AI] debug overlay off"
		or (n >= 2 and "[Relapse AI] debug overlay on (everyone)" or "[Relapse AI] debug overlay on")
	print(msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
		pl:ChatPrint(msg)
	end
end)
