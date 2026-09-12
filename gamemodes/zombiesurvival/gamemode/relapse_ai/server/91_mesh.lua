-- Relapse mesh editor shell. Same UX as D3bot (noclip + overlay + owner SteamID),
-- but this is NOT Valve nav_edit and NOT maps/*.nav.
-- Walking still uses Source .nav in 10_nav.lua until this graph exists.

local AI = RelapseAI
local Mesh = {}
AI.Mesh = Mesh

Mesh.Kind = "relapse_graph"
Mesh.Editors = Mesh.Editors or {} -- [Player] = "edit" | "view"

util.AddNetworkString("RelapseAI.MeshEdit")

local OWNERS = {
	["STEAM_0:0:454712632"] = true,
	["76561198869690992"] = true,
}

local function isOwner(pl)
	if not IsValid(pl) then return true end
	if pl:IsBot() then return false end
	local sid = pl:SteamID()
	local sid64 = pl.SteamID64 and pl:SteamID64()
	return OWNERS[sid] or (sid64 and OWNERS[tostring(sid64)]) or false
end

local function reply(pl, msg)
	print(msg)
	if IsValid(pl) then
		pl:PrintMessage(HUD_PRINTCONSOLE, msg)
		pl:ChatPrint(msg)
	end
end

local function sendState(pl, mode)
	if not IsValid(pl) then return end
	net.Start("RelapseAI.MeshEdit")
	net.WriteUInt(mode == "edit" and 2 or (mode == "view" and 1 or 0), 2)
	net.Send(pl)
end

local function applyNoclip(pl, on)
	if not IsValid(pl) then return end
	if on then
		pl:AddFlags(FL_NOTARGET)
		if GAMEMODE and GAMEMODE.SetRelapseNoclip then
			GAMEMODE:SetRelapseNoclip(pl, true)
		end
	else
		pl:RemoveFlags(FL_NOTARGET)
		if GAMEMODE and GAMEMODE.SetRelapseNoclip then
			GAMEMODE:SetRelapseNoclip(pl, false)
		end
	end
end

function Mesh.SetMode(pl, mode)
	if not IsValid(pl) then return end
	if mode ~= "edit" and mode ~= "view" then
		mode = nil
	end

	local prev = Mesh.Editors[pl]
	Mesh.Editors[pl] = mode

	if mode == "edit" then
		applyNoclip(pl, true)
	elseif prev == "edit" then
		applyNoclip(pl, false)
	end

	sendState(pl, mode)
end

function Mesh.FilePath()
	return "relapse_ai/mesh/" .. game.GetMap() .. ".txt"
end

concommand.Add("relapse_viewmesh", function(pl)
	if not isOwner(pl) then
		reply(pl, "[Relapse AI] mesh denied")
		return
	end
	if not IsValid(pl) then
		print("relapse_viewmesh: run from the game console, not srcds")
		return
	end
	Mesh.SetMode(pl, "view")
	reply(pl, "[Relapse AI] mesh overlay on. Custom graph, not Source .nav. relapse_hidemesh to hide.")
end)

concommand.Add("relapse_editmesh", function(pl)
	if not isOwner(pl) then
		reply(pl, "[Relapse AI] mesh denied")
		return
	end
	if not IsValid(pl) then
		print("relapse_editmesh: run from the game console, not srcds")
		return
	end
	Mesh.SetMode(pl, "edit")
	reply(pl, "[Relapse AI] EDIT + noclip. Custom graph (not .nav / not nav_edit). Overlay is a stub until that format exists. relapse_hidemesh to leave.")
end)

concommand.Add("relapse_hidemesh", function(pl)
	if not isOwner(pl) then
		reply(pl, "[Relapse AI] mesh denied")
		return
	end
	if not IsValid(pl) then return end
	Mesh.SetMode(pl, nil)
	reply(pl, "[Relapse AI] mesh overlay off")
end)

concommand.Add("relapse_savemesh", function(pl)
	if IsValid(pl) and not isOwner(pl) then
		reply(pl, "[Relapse AI] mesh denied")
		return
	end
	reply(pl, "[Relapse AI] save skipped: Relapse graph is not wired yet (data/" .. Mesh.FilePath() .. "). Walking still uses Source .nav.")
end)

hook.Add("PlayerSpawn", "RelapseAI.MeshEdit", function(pl)
	if Mesh.Editors[pl] == "edit" then
		timer.Simple(0, function()
			if IsValid(pl) and Mesh.Editors[pl] == "edit" then
				applyNoclip(pl, true)
			end
		end)
	end
end)

hook.Add("PlayerDisconnected", "RelapseAI.MeshEdit", function(pl)
	Mesh.Editors[pl] = nil
end)
