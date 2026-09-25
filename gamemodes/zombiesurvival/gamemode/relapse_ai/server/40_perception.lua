-- Relapse AI perception: a shared world cache (humans, sigils, sigil load) refreshed
-- a few times per second, per-bot sensing (every living human, no LOS), target
-- memory and damage awareness.

local AI = RelapseAI
local Percep = {}
AI.Perception = Percep

local CurTime = CurTime
local IsValid = IsValid
local ipairs = ipairs
local pairs = pairs
local util_TraceLine = util.TraceLine

Percep.World = {Humans = {}, Sigils = {}, SigilLoad = {}, Time = -1}
Percep.WorldInterval = 0.25
Percep.MemoryTime = 6

---------------------------------------------------------------------------
-- World cache
---------------------------------------------------------------------------

function Percep.UpdateWorld(force)
	local W = Percep.World
	local now = CurTime()
	if not force and now - W.Time < Percep.WorldInterval then return W end
	W.Time = now

	local humans = {}
	for _, pl in ipairs(team.GetPlayers(TEAM_HUMAN)) do
		if IsValid(pl) and pl:Alive() and pl:GetObserverMode() == OBS_MODE_NONE
			and (not pl.IsRelapseAIBot or pl.RelapseAIBrain == "human")
			and not (AI.Mesh and AI.Mesh.Editors[pl] == "edit") then
			humans[#humans + 1] = pl
		end
	end
	W.Humans = humans

	local sigils = {}
	if GAMEMODE.GetUncorruptedSigils then
		for _, sigil in ipairs(GAMEMODE:GetUncorruptedSigils()) do
			if IsValid(sigil) then
				sigils[#sigils + 1] = sigil
			end
		end
	end
	W.Sigils = sigils

	local load = {}
	for _, bot in ipairs(AI.BotList) do
		local sigil = bot.BB.Sigil
		if IsValid(sigil) then
			load[sigil] = (load[sigil] or 0) + 1
		end
	end
	W.SigilLoad = load

	return W
end

function Percep.GetWorld()
	return Percep.World
end

---------------------------------------------------------------------------
-- Line of sight
---------------------------------------------------------------------------

local losTrace = {mask = MASK_BLOCKLOS, filter = nil}

function Percep.CanSee(pl, eye, ent)
	losTrace.start = eye
	losTrace.filter = pl
	losTrace.endpos = ent:WorldSpaceCenter()
	local tr = util_TraceLine(losTrace)
	if tr.Fraction >= 1 or tr.Entity == ent then
		return true
	end

	if ent:IsPlayer() then
		losTrace.endpos = ent:EyePos()
		tr = util_TraceLine(losTrace)
		return tr.Fraction >= 1 or tr.Entity == ent
	end

	return false
end

---------------------------------------------------------------------------
-- Memory
---------------------------------------------------------------------------

function Percep.Remember(bot, ent, pos, reason)
	local targets = bot.Memory.Targets
	local mem = targets[ent]
	if not mem then
		mem = {Ent = ent, Pos = Vector(pos)}
		targets[ent] = mem
	else
		mem.Pos:Set(pos)
	end
	mem.Time = CurTime()
	mem.Reason = reason
	return mem
end

function Percep.Forget(bot, maxAge)
	maxAge = maxAge or Percep.MemoryTime
	local now = CurTime()
	for ent, mem in pairs(bot.Memory.Targets) do
		if not IsValid(ent) or now - mem.Time > maxAge or (ent:IsPlayer() and (not ent:Alive() or ent:Team() == bot.Player:Team())) then
			bot.Memory.Targets[ent] = nil
		end
	end
end

function Percep.GetMemory(bot, ent)
	return bot.Memory.Targets[ent]
end

-- Most recent memory, preferring things that hurt us.
function Percep.BestMemory(bot)
	local best, bestScore
	local now = CurTime()
	for _, mem in pairs(bot.Memory.Targets) do
		local score = -(now - mem.Time)
		if mem.Reason == "damage" then score = score + 2 end
		if not best or score > bestScore then
			best, bestScore = mem, score
		end
	end
	return best
end

---------------------------------------------------------------------------
-- Sensing
---------------------------------------------------------------------------

local function SortByDist(a, b)
	return a.Dist2 < b.Dist2
end

-- Every living human on the map, nearest first. Walls and floors do not hide them.
function Percep.Sense(bot)
	local eye = bot.Player:EyePos()
	local list = {}
	for _, human in ipairs(Percep.World.Humans) do
		if IsValid(human) and human:Alive() then
			local d2 = eye:DistToSqr(human:WorldSpaceCenter())
			list[#list + 1] = {Ent = human, Dist2 = d2, Visible = true}
			Percep.Remember(bot, human, human:GetPos(), "seen")
		end
	end
	table.sort(list, SortByDist)
	return list
end

---------------------------------------------------------------------------
-- Damage awareness
---------------------------------------------------------------------------

hook.Add("PostEntityTakeDamage", "RelapseAI.Perception", function(ent, dmginfo, took)
	if not took or not ent:IsPlayer() then return end
	local bot = AI.Bots[ent]
	if not bot then return end

	local attacker = dmginfo:GetAttacker()
	if not IsValid(attacker) or not attacker:IsPlayer() or attacker == ent or attacker:Team() == ent:Team() then return end

	Percep.Remember(bot, attacker, attacker:GetPos(), "damage")
	bot.Memory.LastAttacker = attacker
	bot.Memory.LastAttackTime = CurTime()

	local brain = bot.Brain
	brain.OnDamaged(brain, bot, dmginfo, attacker)
end)
