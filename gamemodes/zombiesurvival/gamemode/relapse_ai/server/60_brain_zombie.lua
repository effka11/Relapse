-- Relapse AI zombie brain.
-- Utility-based intent selection with hysteresis: Hunt (visible or remembered humans),
-- Sigil (nearest uncorrupted sigil, balanced across bots), Break (something blocks
-- the way), Wander (horde instinct) and Crow (crow class only). Perception, locomotion,
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
-- Already at a sigil (through the door, not still crossing the map). A human
-- this much farther than that sigil does not pull the bot off it: a teleport
-- to the far sigil used to turn the whole horde around.
local SIGIL_COMMIT = 400
local SIGIL_PULL = 250
-- A human or a live sigil within this Z is still on the surface we stand on.
-- A storey down (the pit under the east ledge) is not.
local FLOOR_BAND = 48
local HOPELESS_SIGIL_COOLDOWN = 30
local HOPELESS_HUMAN_COOLDOWN = 10
-- Same human, still on an island we have no edge to. Walking back to the cliff
-- every cooldown is the basement loop under an upstairs player.
local HOPELESS_ISLAND_COOLDOWN = 45

local function CellAt(pos)
	local mesh = AI.Mesh
	if not (pos and mesh and mesh.IsReady and mesh.IsReady() and mesh.Nearest) then return nil end
	return mesh.Nearest(pos, 240)
end

local function GetProfile(classtab)
	return Brain.Profiles[classtab.Name] or Brain.Profiles.Default
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Brain.OnAttach(brain, bot)
	bot.Combat = AI.Combat.Melee.New(bot)
	bot.BB = {State = "attached", IgnoreHumans = {}, SigilGaveUp = {}, UnreachComp = {}}
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
		UnreachComp = {},
		NextMoan = CurTime() + math.Rand(5, 20),
	}
	bot.Memory.Targets = {}
	bot.Debug.State = "spawned"

	-- Idle with god only during wave-0 prep. Intermission is live play.
	if GAMEMODE:GetWaveActive() or GAMEMODE:GetWave() > 0 then
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
		local gave = bb.SigilGaveUp[cur]
		if not (gave and gave > now) then
			return cur
		end
	end
	bb.SigilReeval = now + SIGIL_REEVAL

	local pos = bot.Player:GetPos()
	local mine = CellAt(pos)
	local best, bestScore
	for _, sigil in ipairs(W.Sigils) do
		if IsValid(sigil) and not sigil:GetSigilCorrupted() then
			local load = W.SigilLoad[sigil] or 0
			if sigil == cur then load = load - 1 end

			local gaveUp = bb.SigilGaveUp[sigil]
			if gaveUp then
				if gaveUp > now then
					-- Unreachable from here (stood at spawn with no path).
				else
					bb.SigilGaveUp[sigil] = nil
					gaveUp = nil
				end
			end
			if not gaveUp then
				-- Another island has no edge. Picking it walks everyone into the same cliff.
				if mine and mine.comp then
					local cell = CellAt(sigil:GetPos())
					if cell and cell.comp and cell.comp ~= mine.comp then
						gaveUp = true
					end
				end
			end
			if not gaveUp then
				local score = pos:Distance(sigil:GetPos()) + load * 350
				if sigil == cur then score = score * 0.8 end
				if not best or score < bestScore then
					best, bestScore = sigil, score
				end
			end
		end
	end

	bb.Sigil = best
	return best
end

-- Inside the commit ball, a far human does not pull us off the sigil. Already
-- walking to it: one step that leaves the ball is not a release. The ledge
-- corner did that every half second — the sigil route stepped out to 415,
-- hunt won, the player route stepped back inside 400, and two bots paced.
local function SigilHolds(sigilDist, humanDist, holding)
	if not (sigilDist and humanDist) then return false end
	if humanDist <= sigilDist + SIGIL_PULL then return false end
	if holding then return true end
	return sigilDist <= SIGIL_COMMIT
end

local function ScoreIntents(bot, bb, senses, now)
	local best, bestScore, data = "wander", 5, nil
	local mem = bot.Memory
	local sigil = PickSigil(bot, bb, now)
	local sigilDist
	if sigil then
		sigilDist = bot.Player:GetPos():Distance(sigil:GetPos())
	end
	local holding = bb.Intent == "sigil"

	for _, c in ipairs(senses) do
		if c.Visible then
			local ent = c.Ent
			local ignore = bb.IgnoreHumans[ent]
			local unreach = bb.UnreachComp and bb.UnreachComp[ent]
			if unreach then
				local cell = CellAt(ent:GetPos())
				if not cell or cell.comp ~= unreach then
					bb.UnreachComp[ent] = nil
					bb.IgnoreHumans[ent] = nil
					ignore = nil
				elseif not ignore or ignore <= now then
					bb.IgnoreHumans[ent] = now + HOPELESS_ISLAND_COOLDOWN
					ignore = bb.IgnoreHumans[ent]
				end
			end
			if ignore and ignore <= now then
				bb.IgnoreHumans[ent] = nil
				ignore = nil
			end

			if not ignore and not SigilHolds(sigilDist, math.sqrt(c.Dist2), holding) then
				-- Distance only trims the score. A human in the same room still
				-- beats the sigil; one a teleport away does not, once we are there.
				local score = 80 - math.min(25, math.sqrt(c.Dist2) / 400)
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
		local memDist = m and bot.Player:GetPos():Distance(m.Pos)
		if m and now - m.Time <= HUNT_MEMORY and not bb.IgnoreHumans[m.Ent] and not SigilHolds(sigilDist, memDist, holding) then
			local score = 55 - (now - m.Time) * 6
			if bb.Intent == "search" then score = score + 8 end
			if score > bestScore then
				best, bestScore, data = "search", score, m
			end
		end
	end

	if sigil then
		local score = 40
		if bb.Intent == "sigil" then score = score + 8 end
		if score > bestScore then
			best, bestScore, data = "sigil", score, sigil
		end
	end

	return best, data
end

-- A living human or an uncorrupted sigil on this surface. The world cache is
-- already the living set.
local function SurfaceHasTarget(pl)
	local z = pl:GetPos().z
	local humans = Percep.World.Humans
	for i = 1, #humans do
		local h = humans[i]
		if IsValid(h) and math.abs(h:GetPos().z - z) <= FLOOR_BAND then
			return true
		end
	end
	local sigils = Percep.World.Sigils
	for i = 1, #sigils do
		local s = sigils[i]
		if IsValid(s) and math.abs(s:GetPos().z - z) <= FLOOR_BAND then
			return true
		end
	end
	return false
end

-- Locomotion gave up on the current goal (no path, a path that ends short and
-- we stood at its end, or stuck three times): drop that goal for a while so the
-- next ScoreIntents picks something else. The mesh already carries shafts and
-- drops, so "he is above us" is not a reason to keep pushing the same request.
-- A one-way drop keeps the pit on the same island, so the path ends on the pit
-- floor and never arrives. No human and no sigil on that floor: die and respawn
-- instead of standing there. A path that does arrive is a stuck body, not an
-- empty floor.
local function HandleHopeless(bot, bb, intent, data, now)
	local loco = bot.Loco
	local pl = bot.Player
	local classtab = pl:GetZombieClassTable()
	if pl:Alive() and not bb.Suicide and not (classtab and classtab.Boss)
		and not loco.PathReached and not SurfaceHasTarget(pl) then
		bb.Suicide = true
		loco:Note("suicide")
		pl:Kill()
		return
	end
	if intent == "hunt" and IsValid(data) then
		local mine = CellAt(bot.Player:GetPos())
		local theirs = CellAt(data:GetPos())
		if mine and theirs and mine.comp and theirs.comp and mine.comp ~= theirs.comp then
			bb.UnreachComp = bb.UnreachComp or {}
			bb.UnreachComp[data] = theirs.comp
			bb.IgnoreHumans[data] = now + HOPELESS_ISLAND_COOLDOWN
		else
			if bb.UnreachComp then bb.UnreachComp[data] = nil end
			bb.IgnoreHumans[data] = now + HOPELESS_HUMAN_COOLDOWN
		end
		bot.Memory.Targets[data] = nil
	elseif intent == "sigil" and IsValid(data) then
		bb.SigilGaveUp[data] = now + HOPELESS_SIGIL_COOLDOWN
		bb.SigilReeval = 0
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
	loco.ClearPath = true
	local standoff = combat:GetStandoff()
	if combat:IsSwinging() then
		standoff = math.max(16, combat.Reach * 0.45)
	end
	loco:SetGoal(target, standoff)
	-- MeleeDelay is ~0.74s. Holding at first "in reach" freezes short of the
	-- claw; walk in through the windup the way a player does.
	loco:SetHold(false)

	-- Looking at someone on another floor yaws us at their XY (under the slab)
	-- and we walk into the wall instead of along the path to the ladder. Close
	-- in, look where the claw actually reaches him (head over a sigil post).
	local aim = combat:GetAimPos()
	if math.abs(target:GetPos().z - bot.Player:GetPos().z) > 40 and not combat.InReach then
		LookAlongPath(bot)
	elseif aim and combat.Dist < 200 then
		view:LookAt(aim, "target")
	else
		view:LookAtEntity(target, "target")
	end
	bb.Target = target
end

local function DoSearch(bot, bb, mem)
	local loco, combat, view = bot.Loco, bot.Combat, bot.View
	combat:SetTarget(nil)
	loco.SpeedFrac = 1
	loco.ClearPath = true
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
	loco.ClearPath = true
	loco:SetGoal(approach, combat:GetStandoff(), sigil)
	loco:SetHold(combat.InReach)
	if combat.WantDuck then
		loco:Duck(0.3)
	end

	local aim = combat:GetAimPos()
	-- Looking at a sigil on another floor yaws us at the XY under it and we
	-- walk into the gap instead of along the path down and up a ladder.
	if math.abs(sigil:GetPos().z - pos.z) > 40 then
		LookAlongPath(bot)
	elseif aim and combat.Dist < 350 then
		view:LookAt(aim, "target")
	else
		LookAlongPath(bot)
	end
end

local function DoBreak(bot, bb, obstacle)
	local loco, combat, view = bot.Loco, bot.Combat, bot.View
	combat:SetTarget(obstacle)
	combat:Think()
	-- Stay on the rungs. SetGoal would drop the ladder route and walk off.
	if loco.Ladder then
		if combat.InReach then
			loco:TouchObstacle()
		end
		return
	end
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

	-- Stuck short of a wander cell: that cell is the wall under someone
	-- upstairs. Drop it now instead of grinding the corner for the timer.
	if bb.WanderPos and not loco:IsGoalReached() and (loco.StuckLevel or 0) >= 1 then
		bb.WanderAvoid = Vector(bb.WanderPos)
		bb.WanderAvoidUntil = now + 20
		bb.WanderPos = nil
	end

	local function avoid(pos)
		local bad = bb.WanderAvoid
		if not pos or not bad or now >= (bb.WanderAvoidUntil or 0) then return false end
		return bad:DistToSqr(pos) < 160 * 160
	end

	if not bb.WanderPos or now >= (bb.NextWander or 0) or (bb.WanderSet and loco:IsGoalReached()) then
		bb.NextWander = now + math.Rand(8, 14)
		bb.WanderPos = nil

		local W = Percep.World
		local mine = CellAt(pl:GetPos())
		if AI.cv.horde_instinct:GetBool() and #W.Humans > 0 then
			local human = W.Humans[math.random(#W.Humans)]
			if IsValid(human) then
				local humanCell = CellAt(human:GetPos())
				-- Their cell on our island is the cliff under them. Snapping
				-- there walks every basement bot into the same wall.
				if mine and humanCell and mine.comp and humanCell.comp and mine.comp == humanCell.comp then
					local rough = human:GetPos() + Vector(math.Rand(-256, 256), math.Rand(-256, 256), 0)
					local snapped = Nav.SnapToMesh(rough, 500)
					local cell = snapped and CellAt(snapped)
					if snapped and not avoid(snapped) and (not cell or not cell.comp or cell.comp == mine.comp) then
						bb.WanderPos = snapped
					end
				end
			end
		end

		if not bb.WanderPos then
			local pick = Nav.RandomPointNear(pl:GetPos(), 700)
			if pick and avoid(pick) then
				pick = Nav.RandomPointNear(pl:GetPos(), 700)
			end
			bb.WanderPos = pick
		end
		bb.WanderSet = false
	end

	if not bb.WanderPos then
		loco:Stop()
		view:Idle()
		return
	end

	loco.SpeedFrac = profile.WanderSpeed
	loco.ClearPath = false
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

	-- Wave 0: stand so TAB still matches bodies. Between waves they keep hunting.
	if not GAMEMODE:GetWaveActive() and GAMEMODE:GetWave() == 0 then
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
		-- Snapshot before HandleHopeless clears the path and the goal.
		if AI.Rec then AI.Rec.OnHopeless(bot, bb.Intent) end
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
