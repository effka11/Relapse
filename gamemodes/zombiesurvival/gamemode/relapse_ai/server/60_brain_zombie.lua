-- Relapse AI zombie brain.
-- Utility-based intent selection with hysteresis: Hunt (visible or remembered humans),
-- Sigil (nearest uncorrupted sigil, balanced across bots), Break (something blocks
-- the way), Wander (horde instinct) and Crow (intermission). Perception, locomotion,
-- view and combat are shared services; this file only decides.

local AI = RelapseAI
local Percep = AI.Perception
local Nav = AI.Nav

local CurTime = CurTime
local IsValid = IsValid
local ipairs = ipairs
local bit_bor = bit.bor

local Brain = {Team = TEAM_UNDEAD, NavProfile = "zombie"}

-- Per-class tuning. Anything not listed falls back to Default.
Brain.Profiles = {
	Default = {
		View = {YawRate = 380, YawAccel = 2200, PitchRate = 200, PitchAccel = 1400},
		WanderSpeed = 0.55,
		SigilSpeed = 0.9,
		SenseMul = 1,
	},
	["Zombie"] = {},
	["Ghoul"] = {
		View = {YawRate = 420, YawAccel = 2600, PitchRate = 220, PitchAccel = 1500},
	},
	["Fast Zombie"] = {
		View = {YawRate = 650, YawAccel = 4500, PitchRate = 320, PitchAccel = 2400},
		WanderSpeed = 0.5,
	},
	["Crow"] = {Crow = true},
}
for name, profile in pairs(Brain.Profiles) do
	if name ~= "Default" then
		setmetatable(profile, {__index = Brain.Profiles.Default})
	end
end
AI.ZombieProfiles = Brain.Profiles

-- Classes the manager may hand out on death. Only melee classes the brain understands.
Brain.DeathClasses = {"Zombie", "Ghoul"}

local HUNT_MEMORY = 5 -- seconds to chase a lost target's last known position
local SIGIL_REEVAL = 5
local HOPELESS_SIGIL_COOLDOWN = 30
local HOPELESS_HUMAN_COOLDOWN = 10

local function GetProfile(classtab)
	return Brain.Profiles[classtab.Name] or Brain.Profiles.Default
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Brain.OnAttach(brain, bot)
	bot.Combat = AI.Combat.Melee.New(bot)
	bot.BB = {State = "attached", IgnoreHumans = {}, SigilGaveUp = {}}
end

function Brain.OnSpawn(brain, bot)
	local pl = bot.Player
	local classtab = pl:GetZombieClassTable()
	local profile = GetProfile(classtab)

	bot.View:Reset(pl:EyeAngles())
	bot.View:SetParams(AI.View.Defaults)
	bot.View:SetParams(profile.View)
	bot.SenseMul = profile.SenseMul

	bot.Loco:Stop()
	bot.Loco.StuckEpisodes = 0
	bot.Loco.FailedPaths = 0
	bot.Loco:ClearObstacle()
	bot.Combat:SetTarget(nil)

	local old = bot.BB
	bot.BB = {
		State = "spawned",
		IgnoreHumans = {},
		SigilGaveUp = old.SigilGaveUp or {},
		NextMoan = CurTime() + math.Rand(5, 20),
	}
	bot.Memory.Targets = {}
	bot.Debug.State = "spawned"

	if GAMEMODE:GetWaveActive() then
		pl:GodDisable()
	else
		pl:GodEnable()
	end
end

function Brain.OnDeath(brain, bot)
	bot.Loco:Stop()
	bot.Combat:SetTarget(nil)
	bot.BB.State = "dead"
	bot.Debug.State = "dead"
	bot.Player.DeathClass = brain.PickDeathClass(brain, bot)
end

function Brain.OnDamaged(brain, bot, dmginfo, attacker)
	-- Perception already remembered the attacker; make the brain react on its next think.
	bot.NextThink = math.min(bot.NextThink, CurTime() + 0.1)
end

function Brain.PickDeathClass(brain, bot)
	local options = {}
	for _, name in ipairs(Brain.DeathClasses) do
		local tab = GAMEMODE.ZombieClasses[name]
		if tab and not tab.Hidden and not tab.Boss and GAMEMODE:IsClassUnlocked(name) then
			options[#options + 1] = tab.Index
		end
	end
	if #options == 0 then
		return GAMEMODE.DefaultZombieClass
	end
	return options[math.random(#options)]
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local lookTmp = Vector(0, 0, 0)

local function LookAlongPath(bot)
	local p = bot.Loco:GetLookPoint()
	if p then
		lookTmp.x, lookTmp.y, lookTmp.z = p.x, p.y, p.z + 60
		bot.View:LookAt(lookTmp, "path")
	else
		bot.View:Idle()
	end
end

local function PickSigil(bot, bb, now)
	local W = Percep.World
	if #W.Sigils == 0 then
		bb.Sigil = nil
		return nil
	end

	local cur = bb.Sigil
	if IsValid(cur) and not cur:GetSigilCorrupted() and now < (bb.SigilReeval or 0) then
		return cur
	end
	bb.SigilReeval = now + SIGIL_REEVAL

	local pos = bot.Player:GetPos()
	local best, bestScore
	for _, sigil in ipairs(W.Sigils) do
		if IsValid(sigil) and not sigil:GetSigilCorrupted() then
			local load = W.SigilLoad[sigil] or 0
			if sigil == cur then load = load - 1 end

			local score = pos:Distance(sigil:GetPos()) + load * 350
			if sigil == cur then score = score * 0.8 end

			local gaveUp = bb.SigilGaveUp[sigil]
			if gaveUp then
				if gaveUp > now then
					score = score + 5000
				else
					bb.SigilGaveUp[sigil] = nil
				end
			end

			if not best or score < bestScore then
				best, bestScore = sigil, score
			end
		end
	end

	bb.Sigil = best
	return best
end

local function ScoreIntents(bot, bb, senses, now)
	local best, bestScore, data = "wander", 5, nil
	local mem = bot.Memory

	for _, c in ipairs(senses) do
		if c.Visible then
			local ent = c.Ent
			local ignore = bb.IgnoreHumans[ent]
			if ignore and ignore <= now then
				bb.IgnoreHumans[ent] = nil
				ignore = nil
			end

			if not ignore then
				local score = 100 - math.sqrt(c.Dist2) / 16
				if ent == bb.Target then score = score + 12 end
				if mem.LastAttacker == ent and now - (mem.LastAttackTime or 0) < 6 then score = score + 20 end
				if score > bestScore then
					best, bestScore, data = "hunt", score, ent
				end
			end
		end
	end

	if best ~= "hunt" then
		local m = Percep.BestMemory(bot)
		if m and now - m.Time <= HUNT_MEMORY and not bb.IgnoreHumans[m.Ent] then
			local score = 55 - (now - m.Time) * 6
			if bb.Intent == "search" then score = score + 8 end
			if score > bestScore then
				best, bestScore, data = "search", score, m
			end
		end
	end

	local sigil = PickSigil(bot, bb, now)
	if sigil then
		local score = 40
		if bb.Intent == "sigil" then score = score + 8 end
		if score > bestScore then
			best, bestScore, data = "sigil", score, sigil
		end
	end

	return best, data
end

local function HandleHopeless(bot, bb, intent, data, now)
	local loco = bot.Loco
	if intent == "sigil" and IsValid(data) then
		bb.SigilGaveUp[data] = now + HOPELESS_SIGIL_COOLDOWN
		bb.SigilReeval = 0
	elseif intent == "hunt" and IsValid(data) then
		bb.IgnoreHumans[data] = now + HOPELESS_HUMAN_COOLDOWN
		bot.Memory.Targets[data] = nil
	elseif intent == "search" and data then
		bot.Memory.Targets[data.Ent] = nil
	else
		bb.WanderPos = nil
	end

	loco.StuckEpisodes = 0
	loco.FailedPaths = 0
	loco.Exhausted = false
	loco:Stop()
end

---------------------------------------------------------------------------
-- Intents
---------------------------------------------------------------------------

local function DoHunt(bot, bb, target)
	local loco, combat, view = bot.Loco, bot.Combat, bot.View
	combat:SetTarget(target)
	combat:Think()
	loco.SpeedFrac = 1
	loco:SetGoal(target, combat:GetStandoff())
	loco:SetHold(combat.InReach)
	view:LookAtEntity(target, "target")
	bb.Target = target
end

local function DoSearch(bot, bb, mem)
	local loco, combat, view = bot.Loco, bot.Combat, bot.View
	combat:SetTarget(nil)
	loco.SpeedFrac = 1
	loco:SetGoal(mem.Pos, 48)
	loco:SetHold(false)
	bb.Target = nil

	if loco:IsGoalReached() then
		bot.Memory.Targets[mem.Ent] = nil
	end

	if bot.Player:GetPos():DistToSqr(mem.Pos) < 300 * 300 then
		lookTmp.x, lookTmp.y, lookTmp.z = mem.Pos.x, mem.Pos.y, mem.Pos.z + 50
		view:LookAt(lookTmp, "look")
	else
		LookAlongPath(bot)
	end
end

local function DoSigil(bot, bb, sigil, profile)
	local loco, combat, view = bot.Loco, bot.Combat, bot.View
	combat:SetTarget(sigil)
	combat:Think()
	bb.Target = nil

	local pos = bot.Player:GetPos()
	local approach
	if combat.Dist > 300 then
		approach = sigil:GetPos()
	else
		approach = combat:GetApproachPos(pos)
	end

	loco.SpeedFrac = profile.SigilSpeed
	loco:SetGoal(approach, combat:GetStandoff(), sigil)
	loco:SetHold(combat.InReach)
	if combat.WantDuck then
		loco:Duck(0.3)
	end

	local aim = combat:GetAimPos()
	if aim and combat.Dist < 350 then
		view:LookAt(aim, "target")
	else
		LookAlongPath(bot)
	end
end

local function DoBreak(bot, bb, obstacle)
	local loco, combat, view = bot.Loco, bot.Combat, bot.View
	combat:SetTarget(obstacle)
	combat:Think()
	loco.SpeedFrac = 1
	loco:SetGoal(combat:GetApproachPos(bot.Player:GetPos()), combat:GetStandoff(), obstacle)
	loco:SetHold(combat.InReach)
	if combat.InReach then
		loco:TouchObstacle()
	end
	if combat.WantDuck then
		loco:Duck(0.3)
	end
	local aim = combat:GetAimPos()
	if aim then
		view:LookAt(aim, "target")
	else
		view:LookAtEntity(obstacle, "target")
	end
end

local function DoWander(bot, bb, profile, now)
	local loco, combat, view = bot.Loco, bot.Combat, bot.View
	local pl = bot.Player
	combat:SetTarget(nil)
	loco:SetHold(false)
	bb.Target = nil

	if not bb.WanderPos or now >= (bb.NextWander or 0) or (bb.WanderSet and loco:IsGoalReached()) then
		bb.NextWander = now + math.Rand(8, 14)
		bb.WanderPos = nil

		local W = Percep.World
		if AI.cv.horde_instinct:GetBool() and #W.Humans > 0 then
			local human = W.Humans[math.random(#W.Humans)]
			if IsValid(human) then
				local rough = human:GetPos() + Vector(math.Rand(-256, 256), math.Rand(-256, 256), 0)
				bb.WanderPos = Nav.SnapToMesh(rough, 500)
			end
		end

		if not bb.WanderPos then
			bb.WanderPos = Nav.RandomPointNear(pl:GetPos(), 700)
		end
		bb.WanderSet = false
	end

	if not bb.WanderPos then
		loco:Stop()
		view:Idle()
		return
	end

	loco.SpeedFrac = profile.WanderSpeed
	loco:SetGoal(bb.WanderPos, 48)
	bb.WanderSet = true
	LookAlongPath(bot)

	if now >= (bb.NextMoan or 0) then
		bb.NextMoan = now + math.Rand(20, 45)
		bb.PressReload = now + 0.05
	end
end

local function CrowThink(bot, bb)
	bot.Loco:Stop()
	bot.Combat:SetTarget(nil)
	bot.View:Idle()
	bb.State = "crow"
	bot.Debug.State = "crow"
end

---------------------------------------------------------------------------
-- Think / BuildCommand
---------------------------------------------------------------------------

function Brain.Think(brain, bot, dt)
	local pl = bot.Player
	local bb = bot.BB
	local now = CurTime()

	if pl:Team() ~= TEAM_UNDEAD then
		bot.Loco:Stop()
		bb.State = "wrong team"
		bot.Debug.State = bb.State
		return
	end

	local classtab = pl:GetZombieClassTable()
	local profile = GetProfile(classtab)
	if profile.Crow or classtab.Name == "Crow" then
		CrowThink(bot, bb)
		return
	end

	-- Prep / intermission: stand as a real zombie so TAB matches the bodies in the world.
	if not GAMEMODE:GetWaveActive() then
		if not pl:HasGodMode() then pl:GodEnable() end
		CrowThink(bot, bb)
		bb.State = "wait"
		bot.Debug.State = "wait"
		return
	elseif pl:HasGodMode() then
		pl:GodDisable()
	end

	if pl.KnockedDown or IsValid(pl.FeignDeath) then
		bot.Loco:SetHold(true)
		bb.State = "down"
		bot.Debug.State = bb.State
		return
	end

	Percep.UpdateWorld()
	Percep.Forget(bot)
	local senses = Percep.Sense(bot)

	local intent, data = ScoreIntents(bot, bb, senses, now)

	if bot.Loco:IsHopeless() then
		HandleHopeless(bot, bb, bb.Intent, bb.IntentData, now)
		intent, data = ScoreIntents(bot, bb, senses, now)
	end

	bb.Intent = intent
	bb.IntentData = data

	-- Something breakable is in the way and the real target is out of reach: punch through.
	local state = intent
	local obstacle = bot.Loco:GetObstacle()
	if obstacle then
		local intentTarget = (intent == "hunt" or intent == "sigil") and data or nil
		if intentTarget and bot.Combat:IsInReachOf(intentTarget) then
			obstacle = nil
		end
	end

	if obstacle then
		DoBreak(bot, bb, obstacle)
		state = "break"
	elseif intent == "hunt" then
		DoHunt(bot, bb, data)
	elseif intent == "search" then
		DoSearch(bot, bb, data)
	elseif intent == "sigil" then
		DoSigil(bot, bb, data, profile)
	else
		DoWander(bot, bb, profile, now)
	end

	bb.State = state
	bot.Debug.State = state
end

function Brain.BuildCommand(brain, bot, cmd, buttons)
	local combat = bot.Combat
	if combat.Target and combat:WantsAttack(bot.View:GetAngles()) then
		buttons = bit_bor(buttons, IN_ATTACK)
	end

	local bb = bot.BB
	if bb.PressReload then
		if CurTime() < bb.PressReload then
			buttons = bit_bor(buttons, IN_RELOAD)
		else
			bb.PressReload = nil
		end
	end

	return buttons
end

AI.RegisterBrain("zombie", Brain)
