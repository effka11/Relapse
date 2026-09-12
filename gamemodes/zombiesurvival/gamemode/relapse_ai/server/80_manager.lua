-- Relapse AI manager: keeps relapse_ai_zombies AI zombies on the server while a
-- real player is connected (idle until wave 1, hunting from wave 1), wires the
-- engine hooks (StartCommand/Think/spawn/death) to the bots, and exposes admin commands.
--
-- Never create a NextBot player on a server without a real client: it breaks the
-- entity snapshot until srcds restarts. Every creation path checks HasRealPlayer().

local AI = RelapseAI
local Mgr = {}
AI.Manager = Mgr

local CurTime = CurTime
local SysTime = SysTime
local IsValid = IsValid
local ipairs = ipairs

RelapseAIPending = nil -- {brain = name, team = id} while player.CreateNextBot runs

Mgr.WarnedNav = false
Mgr.Creating = false
Mgr.MaxCreatePerPass = 8

---------------------------------------------------------------------------
-- Creation / removal
---------------------------------------------------------------------------

function Mgr.CanCreate()
	if game.SinglePlayer() then return false, "singleplayer" end
	if not AI.HasRealPlayer() then return false, "no real players" end
	if not GAMEMODE or GAMEMODE.RoundEnded then return false, "round ended" end
	if not AI.Nav.IsReady() then return false, "navmesh " .. AI.Nav.Status() end
	return true
end

function Mgr.CreateBot(brainName)
	local brain = AI.GetBrain(brainName)
	if not brain then
		AI.Warn("no brain '%s'", tostring(brainName))
		return
	end

	local ok, why = Mgr.CanCreate()
	if not ok then
		AI.Log("not creating a bot: %s", why)
		return
	end

	if Mgr.Creating then return end
	Mgr.Creating = true

	local name = AI.PickName()
	RelapseAIPending = {brain = brainName, team = brain.Team}
	local created, pl = pcall(player.CreateNextBot, name)
	RelapseAIPending = nil
	Mgr.Creating = false

	if not created then
		AI.Warn("player.CreateNextBot failed: %s", tostring(pl))
		return
	end
	if not IsValid(pl) or not pl:IsBot() then
		AI.Warn("player.CreateNextBot returned an invalid player (server full?)")
		return
	end

	pl.PlayerReady = true
	local bot = AI.Register(pl, brainName)

	if pl:Team() ~= brain.Team then
		pl:ChangeTeam(brain.Team)
	end

	if brain.Team == TEAM_UNDEAD then
		local class = brain.PickDeathClass(brain, bot) or GAMEMODE.DefaultZombieClass
		pl:SetZombieClass(class)
		pl.DeathClass = class
	end

	pl:UnSpectateAndSpawn()

	AI.Log("created %s bot '%s' (%d AI bots)", brainName, name, AI.Count())
	return pl
end

function Mgr.KickBot(pl, reason)
	if not IsValid(pl) then return end
	AI.Unregister(pl)
	pl:Kick("Relapse AI: " .. (reason or "removed"))
end

function Mgr.KickAll(reason)
	local n = 0
	for i = #AI.BotList, 1, -1 do
		local bot = AI.BotList[i]
		if IsValid(bot.Player) then
			Mgr.KickBot(bot.Player, reason)
			n = n + 1
		end
	end
	if n > 0 then
		AI.Log("kicked %d AI bots (%s)", n, reason or "")
	end
end

-- Drop leftover TAB-filler NextBots (Zombie / Spetsnaz) from sv_relapse_bots.lua.
function Mgr.KickStrays()
	for _, pl in ipairs(player.GetAll()) do
		if IsValid(pl) and pl:IsBot() and not pl.IsRelapseAIBot
		and (pl.IsRelapseBot or pl:Nick() == "Zombie" or pl:Nick() == "Spetsnaz") then
			pl:Kick("Relapse AI: placeholder removed")
		end
	end
end

-- Bring the AI zombie count to relapse_ai_zombies (or zero when the rules say so).
function Mgr.Maintain(reason)
	if not GAMEMODE then return end
	AI.Prune()
	Mgr.KickStrays()

	if game.SinglePlayer() then return end

	if not AI.HasRealPlayer() then
		if AI.Count() > 0 then Mgr.KickAll("no players") end
		return
	end

	local gm = GAMEMODE
	if gm.RoundEnded then return end

	if gm.ZombieEscape then
		if AI.Count("zombie") > 0 then Mgr.KickAll("zombie escape") end
		return
	end

	local want = math.max(0, AI.cv.zombies:GetInt())
	local have = AI.Count("zombie")

	if have < want then
		if not AI.Nav.IsReady() then
			if not Mgr.WarnedNav then
				Mgr.WarnedNav = true
				AI.Log("no AI zombies: navmesh %s. Use relapse_ai_nav_generate on an empty server or nav_build.bat.", AI.Nav.Status())
			end
			return
		end
		Mgr.WarnedNav = false

		local n = math.min(want - have, Mgr.MaxCreatePerPass)
		for _ = 1, n do
			if not Mgr.CreateBot("zombie") then break end
		end
	elseif have > want then
		-- Drop dead ones first, then the newest.
		local extra = have - want
		local list = {}
		for _, bot in ipairs(AI.BotList) do
			if bot.BrainName == "zombie" and IsValid(bot.Player) then
				list[#list + 1] = bot
			end
		end
		table.sort(list, function(a, b)
			local aa, ba = a.Player:Alive(), b.Player:Alive()
			if aa ~= ba then return not aa end
			return a.Created > b.Created
		end)
		for i = 1, math.min(extra, #list) do
			Mgr.KickBot(list[i].Player, "quota")
		end
	end
end

timer.Create("RelapseAI.Maintain", 5, 0, function()
	Mgr.Maintain("timer")
end)

hook.Add("InitPostEntity", "RelapseAI.Manager", function()
	timer.Simple(1, function()
		local brains = {}
		for name in pairs(AI.Brains) do brains[#brains + 1] = name end
		table.sort(brains)
		AI.Log("ready on %s: brains [%s], quota relapse_ai_zombies=%d, navmesh %s",
			game.GetMap(), table.concat(brains, ", "), AI.cv.zombies:GetInt(), AI.Nav.Status())
		Mgr.Maintain("init")
	end)
end)

-- CreateNextBot is safe once a real client is in; do not wait for wave 1.
hook.Add("PlayerReady", "RelapseAI.Manager", function(pl)
	if not IsValid(pl) or pl:IsBot() then return end
	timer.Simple(1, function() Mgr.Maintain("ready") end)
end)

hook.Add("OnWaveStateChanged", "RelapseAI.Manager", function()
	timer.Simple(1, function() Mgr.Maintain("wave") end)
end)

hook.Add("PlayerDisconnected", "RelapseAI.Manager", function(pl)
	if AI.Bots[pl] then
		AI.Unregister(pl)
	end
	if not pl:IsBot() then
		timer.Simple(0.5, function() Mgr.Maintain("disconnect") end)
	end
end)

---------------------------------------------------------------------------
-- Gamemode integration
---------------------------------------------------------------------------

hook.Add("PrePlayerRedeemed", "RelapseAI.Manager", function(pl)
	if pl.IsRelapseAIBot then return true end
end)

hook.Add("PlayerSpawn", "RelapseAI.Manager", function(pl)
	local bot = AI.Bots[pl]
	if not bot then return end
	-- GM:PlayerSpawn runs after this hook; wait for class, weapon and hull.
	timer.Simple(0, function()
		if not IsValid(pl) or AI.Bots[pl] ~= bot then return end
		bot.Brain.OnSpawn(bot.Brain, bot)
	end)
end)

hook.Add("PostPlayerDeath", "RelapseAI.Manager", function(pl)
	local bot = AI.Bots[pl]
	if not bot then return end
	bot.Brain.OnDeath(bot.Brain, bot)
end)

hook.Add("PlayerDeathThink", "RelapseAI.Manager", function(pl)
	if pl.IsRelapseAIBot then
		pl.RelapseAIDeathThink = CurTime()
	end
end)

---------------------------------------------------------------------------
-- Per tick: StartCommand drives the player, Think runs brains at their rate
---------------------------------------------------------------------------

local errorLog = {}

local function ReportError(bot, err)
	local now = CurTime()
	local key = bot.BrainName
	if (errorLog[key] or 0) <= now then
		errorLog[key] = now + 5
		AI.Warn("brain '%s' error (%s): %s", key, IsValid(bot.Player) and bot.Player:Nick() or "?", tostring(err))
	end
end

hook.Add("StartCommand", "RelapseAI", function(pl, cmd)
	local bot = AI.Bots[pl]
	if not bot then return end

	cmd:ClearMovement()
	cmd:ClearButtons()

	local view = bot.View
	if not pl:Alive() or GAMEMODE.RoundEnded then
		cmd:SetViewAngles(view:GetAngles())
		return
	end

	local dt = engine.TickInterval()
	local ang = view:Step(dt)
	cmd:SetViewAngles(ang)
	pl:SetEyeAngles(ang)

	local buttons = bot.Loco:Step(cmd, ang.y, dt)
	local ok, result = pcall(bot.Brain.BuildCommand, bot.Brain, bot, cmd, buttons)
	if ok then
		buttons = result or buttons
	else
		ReportError(bot, result)
	end
	cmd:SetButtons(buttons)
end)

hook.Add("Think", "RelapseAI.Manager", function()
	local list = AI.BotList
	if #list == 0 then return end

	local now = CurTime()
	local interval = AI.ThinkInterval()

	AI.Nav.Process()
	AI.Perception.UpdateWorld()

	local roundEnded = GAMEMODE.RoundEnded

	for i = #list, 1, -1 do
		local bot = list[i]
		local pl = bot.Player
		if not IsValid(pl) then
			table.remove(list, i)
		elseif now >= bot.NextThink then
			bot.NextThink = now + interval
			local dt = now - bot.LastThink
			bot.LastThink = now

			if pl:Alive() then
				if not roundEnded then
					local t0 = SysTime()
					local ok, err = pcall(bot.Brain.Think, bot.Brain, bot, dt)
					if not ok then ReportError(bot, err) end
					ok, err = pcall(bot.Loco.Think, bot.Loco, dt)
					if not ok then ReportError(bot, err) end
					bot.ThinkMs = (SysTime() - t0) * 1000
				end
			elseif now - (pl.RelapseAIDeathThink or 0) > 0.5 then
				-- The engine normally runs PlayerDeathThink for bots; make sure respawn logic ticks.
				pl.RelapseAIDeathThink = now
				gamemode.Call("PlayerDeathThink", pl)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Console
---------------------------------------------------------------------------

local function Reply(pl, msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
	end
	print(msg)
end

local function IsAllowed(pl)
	return not IsValid(pl) or pl:IsSuperAdmin()
end

concommand.Add("relapse_ai_add", function(pl, _, args)
	if not IsAllowed(pl) then return end
	local n = math.Clamp(tonumber(args[1]) or 1, 1, 32)
	local brainName = args[2] or "zombie"

	local ok, why = Mgr.CanCreate()
	if not ok then
		Reply(pl, "[Relapse AI] cannot create bots: " .. why)
		return
	end

	local made = 0
	for _ = 1, n do
		if Mgr.CreateBot(brainName) then made = made + 1 end
	end
	Reply(pl, string.format("[Relapse AI] created %d %s bot(s); quota relapse_ai_zombies=%d will trim extras", made, brainName, AI.cv.zombies:GetInt()))
end)

concommand.Add("relapse_ai_kick", function(pl)
	if not IsAllowed(pl) then return end
	Mgr.KickAll("relapse_ai_kick")
	Reply(pl, "[Relapse AI] all AI bots kicked; the quota refills them within 5 s while relapse_ai_zombies > 0")
end)

concommand.Add("relapse_ai_status", function(pl)
	Reply(pl, string.format("[Relapse AI] bots: %d (quota %d) | wave %d | navmesh: %s | computes/s %.1f",
		AI.Count(), AI.cv.zombies:GetInt(), GAMEMODE:GetWave(), AI.Nav.Status(), AI.Nav.Stats.ComputesPerSec))
	for _, bot in ipairs(AI.BotList) do
		local p = bot.Player
		if IsValid(p) then
			local loco = bot.Loco
			local state = bot.Debug.State or "?"
			if loco.Ladder then state = state .. "/" .. loco.Ladder.Phase end
			Reply(pl, string.format("  %-16s %-6s hp %3d state=%-12s mode=%-6s path=%s stuck=%d think=%.2fms",
				p:Nick(), p:Alive() and "alive" or "dead", p:Health(), state, loco.Mode,
				loco.PathValid and "ok" or (loco.PathPending and "pending" or "none"), loco.StuckLevel, bot.ThinkMs))
		end
	end
end)

concommand.Add("relapse_ai_debug_toggle", function(pl)
	if not IsAllowed(pl) then return end
	local cur = AI.cv.debug:GetInt()
	AI.cv.debug:SetInt(cur > 0 and 0 or 1)
	Reply(pl, "[Relapse AI] debug overlay " .. (cur > 0 and "off" or "on (superadmins)"))
end)
