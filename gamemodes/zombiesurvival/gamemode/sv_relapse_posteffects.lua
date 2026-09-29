-- Server copy of the per-map post sliders. The client previews live and sends the row.

util.AddNetworkString("zs_posteffects")
util.AddNetworkString("zs_posteffects_set")

local FILE = "relapse_posteffects.json"
local savePending = false

local function CanEdit(pl)
	if not IsValid(pl) or pl:IsBot() or pl.IsRelapseAIBot then return false end
	if game.SinglePlayer() or pl:IsListenServerHost() then return true end
	if pl:IsSuperAdmin() then return true end
	local Mesh = RelapseAI and RelapseAI.Mesh
	return (Mesh and Mesh.IsOwner and Mesh.IsOwner(pl)) or false
end

local function CleanRow(row)
	if not istable(row) then return nil end
	local out
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		local n = tonumber(row[key])
		if n and n ~= 0 then
			n = math.Clamp(math.floor(n + 0.5), -100, 100)
			if n ~= 0 then
				out = out or {}
				out[key] = n
			end
		end
	end
	return out
end

function GM:LoadRelapsePostEffects()
	self.RelapsePostSaved = {}
	local raw = file.Read(FILE, "DATA")
	if raw and raw ~= "" then
		local tbl = util.JSONToTable(raw)
		if istable(tbl) and istable(tbl.maps) then
			for map, row in pairs(tbl.maps) do
				if isstring(map) and not (self.RelapsePostShipped and self.RelapsePostShipped[map]) then
					self.RelapsePostSaved[map] = true
					self.RelapsePostEffects[map] = CleanRow(row)
				end
			end
		else
			print("relapse posteffects: data file ignored")
		end
	end
	self:RelapsePostApplyShipped()
end

function GM:SaveRelapsePostEffects()
	local maps = {}
	for map in pairs(self.RelapsePostSaved or {}) do
		local src = self.RelapsePostEffects[map]
		local clean = {}
		if src then
			for _, key in ipairs(self.RelapsePostKeys) do
				local n = tonumber(src[key])
				if n and n ~= 0 then
					clean[key] = math.Clamp(math.floor(n + 0.5), -100, 100)
				end
			end
		end
		if not next(clean) then
			clean._keep = 1
		end
		maps[map] = clean
	end
	file.Write(FILE, util.TableToJSON({ maps = maps }, true))
end

function GM:SendRelapsePostEffects(pl, forced)
	if not IsValid(pl) or pl:IsBot() then return end
	net.Start("zs_posteffects")
		net.WriteBool(forced and true or false)
		net.WriteString(game.GetMap())
		for _, key in ipairs(self.RelapsePostKeys) do
			net.WriteInt(self:RelapsePostPercent(key), 8)
		end
	net.Send(pl)
end

local function QueueSave(except)
	if savePending then return end
	savePending = true
	timer.Simple(0.2, function()
		savePending = false
		if not GAMEMODE or not GAMEMODE.SaveRelapsePostEffects then return end
		GAMEMODE:SaveRelapsePostEffects()
		for _, pl in ipairs(player.GetAll()) do
			if pl ~= except and not pl:IsBot() then
				GAMEMODE:SendRelapsePostEffects(pl, false)
			end
		end
	end)
end

hook.Add("Initialize", "RelapsePostEffects", function()
	GAMEMODE:LoadRelapsePostEffects()
end)

hook.Add("PlayerReady", "RelapsePostEffects", function(pl)
	if GAMEMODE.SendRelapsePostEffects then
		GAMEMODE:SendRelapsePostEffects(pl, true)
	end
end)

net.Receive("zs_posteffects_set", function(_, pl)
	local vals = {}
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		vals[key] = net.ReadInt(8)
	end
	if not CanEdit(pl) then
		GAMEMODE:SendRelapsePostEffects(pl, true)
		if IsValid(pl) and not pl.RelapsePostTold then
			pl.RelapsePostTold = true
			pl:ChatPrint("Постэффекты: нет доступа.")
		end
		return
	end
	local map = game.GetMap()
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		GAMEMODE:RelapsePostWrite(map, key, vals[key])
	end
	GAMEMODE.RelapsePostSaved = GAMEMODE.RelapsePostSaved or {}
	GAMEMODE.RelapsePostSaved[map] = true
	QueueSave(pl)
end)
