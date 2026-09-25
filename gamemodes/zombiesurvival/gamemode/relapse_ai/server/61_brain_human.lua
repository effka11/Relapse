-- Relapse AI human brain: wander a small disc around the spawn point.
-- relapse_ai_spawn_human places one on the aimer. No path and no combat.

local AI = RelapseAI

local Brain = {Team = TEAM_HUMAN, NavProfile = "human"}

local RADIUS = 120
local AHEAD = 40
local HULL_MINS = Vector(-16, -16, 0)
local HULL_MAXS = Vector(16, 16, 48)

local function setDir(bb, yaw)
	local r = math.rad(yaw)
	local x, y = math.cos(r), math.sin(r)
	if bb.Dir then
		bb.Dir.x, bb.Dir.y, bb.Dir.z = x, y, 0
	else
		bb.Dir = Vector(x, y, 0)
	end
end

local function pickDir(bb, pos, now, towardHome)
	local yaw
	if towardHome then
		yaw = (bb.Home - pos):Angle().y + math.Rand(-35, 35)
	else
		yaw = math.Rand(-180, 180)
	end
	setDir(bb, yaw)
	bb.Until = now + math.Rand(1.1, 2.6)
end

function Brain.OnAttach(brain, bot)
	bot.Combat = nil
	bot.BB = {State = "attached"}
end

function Brain.OnSpawn(brain, bot)
	bot.View:Reset(bot.Player:EyeAngles())
	bot.Loco:Stop()
	bot.BB = {
		State = "wander",
		Home = Vector(bot.Player:GetPos()),
		Until = 0,
	}
	pickDir(bot.BB, bot.BB.Home, CurTime(), false)
	bot.Debug.State = "wander"
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
	local pl = bot.Player
	if not pl:Alive() then return end

	local bb = bot.BB
	if not bb.Home then
		bb.Home = Vector(pl:GetPos())
		pickDir(bb, bb.Home, CurTime(), false)
	end

	bot.Loco:Stop()

	local pos = pl:GetPos()
	local now = CurTime()
	local dx, dy = pos.x - bb.Home.x, pos.y - bb.Home.y
	local outside = dx * dx + dy * dy > RADIUS * RADIUS

	if outside then
		if not bb.Out or now >= (bb.Until or 0) then
			pickDir(bb, pos, now, true)
		end
		bb.Out = true
	else
		bb.Out = false
		if now >= (bb.Until or 0) then
			pickDir(bb, pos, now, false)
		end
	end

	local start = Vector(pos.x, pos.y, pos.z + 18)
	local tr = util.TraceHull({
		start = start,
		endpos = start + bb.Dir * AHEAD,
		mins = HULL_MINS,
		maxs = HULL_MAXS,
		filter = pl,
		mask = MASK_PLAYERSOLID,
	})
	if tr.Hit and not tr.StartSolid and math.abs(tr.HitNormal.z) < 0.7 then
		local n = tr.HitNormal
		local d = bb.Dir
		local dot = d.x * n.x + d.y * n.y
		local rx, ry = d.x - 2 * dot * n.x, d.y - 2 * dot * n.y
		setDir(bb, math.deg(math.atan2(ry, rx)) + math.Rand(-25, 25))
		bb.Until = now + math.Rand(0.7, 1.6)
	end

	bot.View:LookAt(pl:EyePos() + bb.Dir * 96)
	bb.State = "wander"
	bot.Debug.State = "wander"
end

function Brain.BuildCommand(brain, bot, cmd, buttons)
	local bb = bot.BB
	local dir = bb and bb.Dir
	if not dir or not bot.Player:Alive() then return buttons end

	local yaw = math.rad(cmd:GetViewAngles().y)
	local fwd = dir.x * math.cos(yaw) + dir.y * math.sin(yaw)
	local side = dir.x * math.sin(yaw) - dir.y * math.cos(yaw)
	local speed = bot.Player:GetWalkSpeed()
	if speed < 1 then speed = 100 end

	cmd:SetForwardMove(fwd * speed)
	cmd:SetSideMove(side * speed)
	if fwd > 0.05 then
		buttons = bit.bor(buttons, IN_FORWARD)
	elseif fwd < -0.05 then
		buttons = bit.bor(buttons, IN_BACK)
	end
	if side > 0.05 then
		buttons = bit.bor(buttons, IN_MOVERIGHT)
	elseif side < -0.05 then
		buttons = bit.bor(buttons, IN_MOVELEFT)
	end
	return buttons
end

AI.RegisterBrain("human", Brain)
