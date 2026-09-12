-- Relapse spectator / noclip: V (noclip bind) flies a hidden camera; B flies
-- the pawn (MOVETYPE_NOCLIP). Hidden never moves the body so bots keep seeing
-- a standing player. No camera entity is spawned — nothing to render or sense.

util.AddNetworkString("zs_relapse_freecam")
util.AddNetworkString("zs_relapse_noclip")

local IN_SCORE = IN_SCORE

local function CanEnter(pl)
	return IsValid(pl) and not pl:IsBot() and not pl.IsRelapseAIBot
		and pl:Alive() and pl:GetObserverMode() == OBS_MODE_NONE
end

local function RestoreMoveType(pl)
	if not pl:Alive() then return end

	local mt = MOVETYPE_WALK
	if pl:Team() == TEAM_UNDEAD then
		local classtab = pl:GetZombieClassTable()
		if classtab and classtab.MoveType then
			mt = classtab.MoveType
		end
	end
	pl:SetMoveType(mt)
end

local function Send(pl, on)
	net.Start("zs_relapse_freecam")
		net.WriteBool(on)
	net.Send(pl)
end

function GM:SetRelapseNoclip(pl, on)
	if not IsValid(pl) then return end

	on = on and CanEnter(pl)
	if (pl.RelapseNoclip == true) == (on == true) then
		if on then
			pl:SetMoveType(MOVETYPE_NOCLIP)
		end
		return
	end

	if on then
		if pl.RelapseFreecam then
			self:SetRelapseFreecam(pl, false)
		end
		pl.RelapseNoclip = true
		pl:SetMoveType(MOVETYPE_NOCLIP)
	else
		pl.RelapseNoclip = nil
		if pl:GetMoveType() == MOVETYPE_NOCLIP then
			RestoreMoveType(pl)
		end
	end
end

function GM:ToggleRelapseNoclip(pl)
	if not IsValid(pl) or pl:IsBot() or pl.IsRelapseAIBot then return end
	if (pl.RelapseNoclipNext or 0) > CurTime() then return end
	pl.RelapseNoclipNext = CurTime() + 0.2

	if pl.RelapseNoclip or pl:GetMoveType() == MOVETYPE_NOCLIP then
		self:SetRelapseNoclip(pl, false)
		return
	end

	if CanEnter(pl) then
		self:SetRelapseNoclip(pl, true)
	end
end

function GM:SetRelapseFreecam(pl, on)
	if not IsValid(pl) then return end

	on = on and CanEnter(pl)
	if (pl.RelapseFreecam == true) == (on == true) then
		return
	end

	if on and (pl.RelapseNoclip or pl:GetMoveType() == MOVETYPE_NOCLIP) then
		self:SetRelapseNoclip(pl, false)
	end

	pl.RelapseFreecam = on or nil
	if on then
		pl.RelapseFreecamAng = pl:EyeAngles()
	else
		pl.RelapseFreecamAng = nil
	end

	Send(pl, on and true or false)
end

function GM:ToggleRelapseFreecam(pl)
	if not IsValid(pl) or pl:IsBot() or pl.IsRelapseAIBot then return end
	if (pl.RelapseFreecamNext or 0) > CurTime() then return end
	pl.RelapseFreecamNext = CurTime() + 0.2

	if pl.RelapseFreecam then
		self:SetRelapseFreecam(pl, false)
		return
	end

	if CanEnter(pl) then
		self:SetRelapseFreecam(pl, true)
	end
end

function GM:RelapseFreecamNoclip(pl)
	self:ToggleRelapseFreecam(pl)
	return false
end

net.Receive("zs_relapse_freecam", function(_, pl)
	GAMEMODE:ToggleRelapseFreecam(pl)
end)

net.Receive("zs_relapse_noclip", function(_, pl)
	GAMEMODE:ToggleRelapseNoclip(pl)
end)

hook.Add("StartCommand", "RelapseFreecam", function(pl, cmd)
	if not pl.RelapseFreecam then return end

	if not CanEnter(pl) then
		GAMEMODE:SetRelapseFreecam(pl, false)
		return
	end

	cmd:ClearMovement()
	cmd:SetButtons(bit.band(cmd:GetButtons(), IN_SCORE))
	if pl.RelapseFreecamAng then
		cmd:SetViewAngles(pl.RelapseFreecamAng)
	end
end)

local function ClearSpectator(pl)
	if pl.RelapseFreecam then
		GAMEMODE:SetRelapseFreecam(pl, false)
	end
	if pl.RelapseNoclip then
		GAMEMODE:SetRelapseNoclip(pl, false)
	end
end

hook.Add("PlayerDeath", "RelapseFreecam", ClearSpectator)
hook.Add("PlayerSpawn", "RelapseFreecam", ClearSpectator)
hook.Add("PlayerSilentDeath", "RelapseFreecam", ClearSpectator)

-- Body stays put, so default PVS is around the pawn. Push every living
-- player into the spectator's PVS or the client never receives them.
hook.Add("SetupPlayerVisibility", "RelapseFreecam", function(pl)
	if not pl.RelapseFreecam then return end

	for _, other in ipairs(player.GetAll()) do
		if IsValid(other) and other:Alive() and other:GetObserverMode() == OBS_MODE_NONE then
			AddOriginToPVS(other:WorldSpaceCenter())
		end
	end
end)
