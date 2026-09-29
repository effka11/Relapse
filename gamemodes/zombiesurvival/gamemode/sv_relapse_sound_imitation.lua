-- relapse_sound_imitation <kind>
-- Plays that sound at spread-out spots so occlusion can be heard from
-- where you stand. Points are spawns and sigils, one per room.

util.AddNetworkString("relapse_sound_imitation")
util.AddNetworkString("relapse_sound_log")

local LOG_DIR = "D:/Relapse/server/garrysmod/devlogs"
local logN = 0
local logParts = {}

net.Receive("relapse_sound_log", function(_, pl)
	if not IsValid(pl) then return end
	local index = net.ReadUInt(8)
	local parts = net.ReadUInt(8)
	local piece = net.ReadString() or ""
	if parts < 1 or index < 1 or index > parts then return end
	local buf = logParts[pl]
	if not buf or index == 1 then
		buf = { n = parts, got = {}, count = 0 }
		logParts[pl] = buf
	end
	if not buf.got[index] then
		buf.got[index] = piece
		buf.count = buf.count + 1
	end
	if buf.count < buf.n then return end
	local text = table.concat(buf.got)
	logParts[pl] = nil
	file.CreateDir("devlogs")
	logN = logN + 1
	local name = string.format("sound_u_%s_%s_%d.txt", game.GetMap(), os.date("%Y%m%d_%H%M%S"), logN)
	local ok = file.Write("devlogs/" .. name, text .. "\n")
	local msg = ok and ("[Relapse] лог " .. LOG_DIR .. "/" .. name) or "[Relapse] лог не записался"
	print(msg)
	pl:PrintMessage(HUD_PRINTCONSOLE, msg)
end)

local CLASSES = {
	"info_player_human",
	"info_player_zombie",
	"info_player_undead",
	"info_player_start",
	"info_player_deathmatch",
	"info_player_terrorist",
	"info_player_counterterrorist",
	"prop_obj_sigil",
	"info_sigilnode",
}

local ROOM = 320
local MAX_POINTS = 12
local KINDS = {
	glass = true,
}

local function Reply(pl, msg)
	print(msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
		pl:ChatPrint(msg)
	end
end

local function CollectPoints()
	local points = {}
	local function add(pos)
		pos = Vector(pos.x, pos.y, pos.z + 40)
		for i = 1, #points do
			if points[i]:DistToSqr(pos) < ROOM * ROOM then return end
		end
		points[#points + 1] = pos
	end

	for _, class in ipairs(CLASSES) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if IsValid(ent) then
				add(ent:GetPos())
			end
		end
	end
	return points
end

-- Nearest first, then the spots farthest from the ones already kept,
-- so twelve points still cover the map.
local function Spread(points, origin)
	if #points <= MAX_POINTS then
		table.sort(points, function(a, b)
			return a:DistToSqr(origin) < b:DistToSqr(origin)
		end)
		return points
	end

	local used = {}
	local nearest, nearestD = 1, math.huge
	for i = 1, #points do
		local d = points[i]:DistToSqr(origin)
		if d < nearestD then
			nearest, nearestD = i, d
		end
	end

	local chosen = { points[nearest] }
	used[nearest] = true
	while #chosen < MAX_POINTS do
		local pick, pickD = nil, -1
		for i = 1, #points do
			if not used[i] then
				local near = math.huge
				for j = 1, #chosen do
					local d = points[i]:DistToSqr(chosen[j])
					if d < near then near = d end
				end
				if near > pickD then
					pick, pickD = i, near
				end
			end
		end
		if not pick then break end
		used[pick] = true
		chosen[#chosen + 1] = points[pick]
	end

	table.sort(chosen, function(a, b)
		return a:DistToSqr(origin) < b:DistToSqr(origin)
	end)
	return chosen
end

local function SendImitation(pl, kind, points)
	net.Start("relapse_sound_imitation")
		net.WriteString(kind or "")
		net.WriteUInt(points and #points or 0, 8)
		if points then
			for i = 1, #points do
				net.WriteVector(points[i])
			end
		end
	net.Send(pl)
end

concommand.Add("relapse_sound_imitation", function(pl, _, args)
	if not IsValid(pl) then
		print("[Relapse] relapse_sound_imitation: из игровой консоли")
		return
	end

	local kind = string.lower(args[1] or "")
	if pl.RelapseSoundImitation then
		pl.RelapseSoundImitation = nil
		SendImitation(pl, "", nil)
		Reply(pl, "[Relapse] имитация выключена")
		return
	end
	if not KINDS[kind] then
		Reply(pl, "[Relapse] relapse_sound_imitation glass")
		return
	end

	local points = Spread(CollectPoints(), pl:EyePos())
	if #points == 0 then
		Reply(pl, "[Relapse] нет точек спавна или сигилов")
		return
	end

	pl.RelapseSoundImitation = kind
	SendImitation(pl, kind, points)
	Reply(pl, string.format("[Relapse] стекло, %d точек. U — запись, I — оверлей.", #points))
end)
