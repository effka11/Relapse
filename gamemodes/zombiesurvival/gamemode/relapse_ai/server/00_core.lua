-- Relapse AI core: registry, config and the Brain protocol.
-- Bots are NextBot players (player.CreateNextBot) driven from StartCommand.
-- Everything lives under RelapseAI; brains (zombie now, human later) plug into the
-- same locomotion / view / perception / combat services.

RelapseAI = RelapseAI or {}
local AI = RelapseAI

AI.Version = 1
AI.Bots = AI.Bots or {} -- [Player] = bot
AI.BotList = AI.BotList or {} -- array for cheap iteration
AI.Brains = AI.Brains or {} -- [name] = brain definition

local CurTime = CurTime
local IsValid = IsValid
local ipairs = ipairs
local pairs = pairs

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------

function AI.Log(fmt, ...)
	print("[Relapse AI] " .. string.format(fmt, ...))
end

function AI.Warn(fmt, ...)
	ErrorNoHalt("[Relapse AI] " .. string.format(fmt, ...) .. "\n")
end

---------------------------------------------------------------------------
-- ConVars
---------------------------------------------------------------------------

local function ServerVar(name, default, help, flags)
	return CreateConVar(name, default, flags or bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY), help)
end

AI.cv = {
	zombies = ServerVar("relapse_ai_zombies", "4", "Number of AI zombie bots kept on the server while a real player is connected. Same count in TAB and in the world."),
	sense_radius = ServerVar("relapse_ai_sense_radius", "1024", "Radius in which a zombie bot notices humans (line of sight required)."),
	horde_instinct = ServerVar("relapse_ai_horde_instinct", "1", "With no sigils and no sensed humans, drift toward a rough human position."),
	think_rate = ServerVar("relapse_ai_think_rate", "10", "Brain thinks per second per bot.", FCVAR_ARCHIVE),
	path_budget = ServerVar("relapse_ai_path_budget", "2", "Max path computations per server tick.", FCVAR_ARCHIVE),
	nav_autogen = ServerVar("relapse_ai_nav_autogen", "1", "Generate a navmesh automatically on an empty server when the map has none."),
	name_prefix = ServerVar("relapse_ai_name_prefix", "", "Prefix added to bot names.", FCVAR_ARCHIVE),
	debug = ServerVar("relapse_ai_debug", "0", "1 = stream bot debug overlay to superadmins, 2 = to everyone.", FCVAR_ARCHIVE),
	max_drop = ServerVar("relapse_ai_max_drop", "200", "Max drop height (units) a bot path may include.", FCVAR_ARCHIVE),
}

function AI.ThinkInterval()
	local rate = AI.cv.think_rate:GetFloat()
	if rate < 2 then rate = 2 elseif rate > 33 then rate = 33 end
	return 1 / rate
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

AI.Names = {
	"Kolyan", "Dendy", "Sanya", "Vitalik", "Serega", "Pasha", "Dimon", "Zhenya",
	"Lexa", "Tolik", "Vovan", "Maks", "Danila", "Artem", "Kostya", "Nikita",
	"Ruslan", "Timur", "Egorka", "Stas", "Gleb", "Fedya", "Arseny", "Roma",
	"Marat", "Ilyas", "Bogdan", "Vadim", "Oleg", "Yura", "Misha", "Kirill",
	"Grisha", "Slavik", "Zhora", "Borya", "Gena", "Valera", "Anton", "Denis",
	"Vanya", "Petya", "Lyosha", "Andryukha", "Semyon", "Matvey", "Rodion", "Tema",
}

function AI.PickName()
	local used = {}
	for _, pl in ipairs(player.GetAll()) do
		used[pl:Nick()] = true
	end

	local prefix = AI.cv.name_prefix:GetString()
	local pool = {}
	for _, name in ipairs(AI.Names) do
		if not used[prefix .. name] then
			pool[#pool + 1] = name
		end
	end

	local name
	if #pool > 0 then
		name = pool[math.random(#pool)]
	else
		name = AI.Names[math.random(#AI.Names)] .. math.random(10, 99)
	end

	return prefix .. name
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function AI.IsAIBot(pl)
	return IsValid(pl) and pl.IsRelapseAIBot == true and pl:IsBot()
end

function AI.HasRealPlayer()
	for _, pl in ipairs(player.GetAll()) do
		if not pl:IsBot() and not pl.Disconnecting then
			return true
		end
	end
	return false
end

function AI.GetBot(pl)
	return AI.Bots[pl]
end

function AI.Count(brainName)
	local n = 0
	for _, bot in ipairs(AI.BotList) do
		if IsValid(bot.Player) and (not brainName or bot.BrainName == brainName) then
			n = n + 1
		end
	end
	return n
end

---------------------------------------------------------------------------
-- Brain protocol
--
-- A brain is a table with:
--   Name, Team
--   OnAttach(bot)          bot created (components exist, player may not be spawned)
--   OnSpawn(bot)           player spawned (class, weapon and hull are final)
--   OnDeath(bot)           player died
--   OnDamaged(bot, dmginfo, attacker)
--   PickDeathClass(bot)    zombie class index for the next spawn (undead brains)
--   Think(bot, dt)         decision tick (relapse_ai_think_rate Hz)
--   BuildCommand(bot, cmd, buttons) -> buttons   per tick, after locomotion and view
---------------------------------------------------------------------------

local REQUIRED = {"OnAttach", "OnSpawn", "OnDeath", "OnDamaged", "Think", "BuildCommand"}

function AI.RegisterBrain(name, def)
	assert(type(name) == "string" and type(def) == "table", "RelapseAI.RegisterBrain(name, table)")
	for _, fn in ipairs(REQUIRED) do
		assert(type(def[fn]) == "function", "brain '" .. name .. "' is missing " .. fn)
	end
	assert(def.Team, "brain '" .. name .. "' needs a Team")

	def.Name = name
	AI.Brains[name] = def
	return def
end

function AI.GetBrain(name)
	return AI.Brains[name]
end

---------------------------------------------------------------------------
-- Bot registry
---------------------------------------------------------------------------

local slot = 0

function AI.Register(pl, brainName)
	local brain = AI.Brains[brainName]
	if not brain then
		AI.Warn("unknown brain '%s'", tostring(brainName))
		return
	end

	if AI.Bots[pl] then
		AI.Unregister(pl)
	end

	slot = slot + 1

	local bot = {
		Player = pl,
		Brain = brain,
		BrainName = brainName,
		BB = {}, -- brain blackboard
		Memory = {Targets = {}},
		Slot = slot,
		NextThink = CurTime() + math.Rand(0, AI.ThinkInterval()),
		LastThink = CurTime(),
		ThinkMs = 0,
		Created = CurTime(),
		Debug = {State = "new"},
	}

	bot.View = AI.View.New(pl, bot)
	bot.Loco = AI.Loco.New(pl, bot)

	pl.IsRelapseAIBot = true
	pl.RelapseAIBrain = brainName
	pl:SetNWBool("RelapseAIBot", true)

	AI.Bots[pl] = bot
	AI.BotList[#AI.BotList + 1] = bot

	brain.OnAttach(brain, bot)

	return bot
end

function AI.Unregister(pl)
	local bot = AI.Bots[pl]
	if not bot then return end

	AI.Bots[pl] = nil
	for i, b in ipairs(AI.BotList) do
		if b == bot then
			table.remove(AI.BotList, i)
			break
		end
	end

	if bot.Loco then bot.Loco:Destroy() end
	if IsValid(pl) then
		pl:SetNWBool("RelapseAIBot", false)
	end
end

function AI.ForEachBot(fn)
	for i = #AI.BotList, 1, -1 do
		local bot = AI.BotList[i]
		if IsValid(bot.Player) then
			fn(bot)
		else
			table.remove(AI.BotList, i)
		end
	end
end

-- Drop registry entries for players that vanished (lua refresh, kicks we did not see).
function AI.Prune()
	for pl, bot in pairs(AI.Bots) do
		if not IsValid(pl) then
			AI.Bots[pl] = nil
			for i, b in ipairs(AI.BotList) do
				if b == bot then
					table.remove(AI.BotList, i)
					break
				end
			end
		end
	end
end
