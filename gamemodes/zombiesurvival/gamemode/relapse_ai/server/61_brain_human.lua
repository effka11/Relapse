-- Relapse AI human brain: interface stub.
-- Registers a complete Brain so the protocol is validated at load time. The manager
-- never creates human bots yet; a future implementation replaces Think/BuildCommand
-- and attaches a Gun combat adapter (see 50_combat.lua for the adapter interface).

local AI = RelapseAI

local Brain = {Team = TEAM_HUMAN, NavProfile = "human"}

function Brain.OnAttach(brain, bot)
	bot.Combat = nil -- Gun adapter goes here
	bot.BB = {State = "attached"}
end

function Brain.OnSpawn(brain, bot)
	bot.View:Reset(bot.Player:EyeAngles())
	bot.Loco:Stop()
	bot.BB = {State = "spawned"}
	bot.Debug.State = "spawned"
end

function Brain.OnDeath(brain, bot)
	bot.Loco:Stop()
	bot.BB.State = "dead"
	bot.Debug.State = "dead"
end

function Brain.OnDamaged(brain, bot, dmginfo, attacker)
end

function Brain.PickDeathClass(brain, bot)
	return nil
end

function Brain.Think(brain, bot, dt)
	-- Placeholder: stand still and look around.
	bot.Loco:Stop()
	bot.View:Idle()
	bot.BB.State = "idle"
	bot.Debug.State = "idle"
end

function Brain.BuildCommand(brain, bot, cmd, buttons)
	return buttons
end

AI.RegisterBrain("human", Brain)
