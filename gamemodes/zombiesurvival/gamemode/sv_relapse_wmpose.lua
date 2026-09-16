-- Relapse worldmodel pose editor. relapse_wmpose flies a hidden camera (the
-- pawn stays in ar2 so shoulder/palm binds hold). No V x-ray. Binds replicate
-- so every client draws the same worldmodel.

util.AddNetworkString("zs_relapse_wmpose")
util.AddNetworkString("zs_relapse_wmpose_bind")
util.AddNetworkString("zs_relapse_wmpose_sync")

local function CanEdit(pl)
	if not IsValid(pl) or pl:IsBot() or pl.IsRelapseAIBot then return false end
	if game.SinglePlayer() or pl:IsListenServerHost() then return true end
	if pl:IsSuperAdmin() then return true end
	local Mesh = RelapseAI and RelapseAI.Mesh
	return (Mesh and Mesh.IsOwner and Mesh.IsOwner(pl)) or false
end

local function CanStay(pl)
	return IsValid(pl) and not pl:IsBot() and not pl.IsRelapseAIBot
		and pl:Alive() and pl:GetObserverMode() == OBS_MODE_NONE
end

local function SendEditor(pl, on)
	net.Start("zs_relapse_wmpose")
		net.WriteBool(on)
	net.Send(pl)
end

local function SendAllBinds(pl)
	local n = 0
	for _ in pairs(GAMEMODE.RelapseWMBinds) do
		n = n + 1
	end
	net.Start("zs_relapse_wmpose_sync")
		net.WriteUInt(n, 8)
		for class, bind in pairs(GAMEMODE.RelapseWMBinds) do
			net.WriteString(class)
			GAMEMODE:RelapseWMBindWrite(bind)
		end
	net.Send(pl)
end

local function BroadcastBind(class, bind)
	net.Start("zs_relapse_wmpose_bind")
		net.WriteString(class)
		GAMEMODE:RelapseWMBindWrite(bind)
	net.Broadcast()
end

function GM:SetRelapseWMPose(pl, on)
	if not IsValid(pl) then return end

	on = on and CanEdit(pl) and CanStay(pl)
	if (pl.RelapseWMPose == true) == (on == true) then
		return
	end

	if on then
		self:SetRelapseFreecam(pl, false)
		self:SetRelapseNoclip(pl, false)
		pl.RelapseWMPose = true
		pl.RelapseWMPoseAng = pl:EyeAngles()
		SendAllBinds(pl)
	else
		pl.RelapseWMPose = nil
		pl.RelapseWMPoseAng = nil
	end

	SendEditor(pl, on and true or false)
end

function GM:ToggleRelapseWMPose(pl)
	if not IsValid(pl) then return end
	if not CanEdit(pl) then
		pl:ChatPrint("relapse_wmpose: no access")
		return
	end
	if (pl.RelapseWMPoseNext or 0) > CurTime() then return end
	pl.RelapseWMPoseNext = CurTime() + 0.2

	self:SetRelapseWMPose(pl, not pl.RelapseWMPose)
end

concommand.Add("relapse_wmpose", function(pl)
	if not IsValid(pl) then return end
	GAMEMODE:ToggleRelapseWMPose(pl)
end)

net.Receive("zs_relapse_wmpose", function(_, pl)
	GAMEMODE:ToggleRelapseWMPose(pl)
end)

net.Receive("zs_relapse_wmpose_bind", function(_, pl)
	if not CanEdit(pl) or not pl.RelapseWMPose then return end
	if (pl.RelapseWMPoseBindNext or 0) > CurTime() then return end
	pl.RelapseWMPoseBindNext = CurTime() + 0.03

	local class = net.ReadString()
	if not class or class == "" or #class > 64 then return end
	if not string.match(class, "^[%w_]+$") then return end

	local bind = GAMEMODE:RelapseWMBindRead()
	GAMEMODE:RelapseWMBindSet(class, bind)
	BroadcastBind(class, GAMEMODE.RelapseWMBinds[class])
end)

hook.Add("StartCommand", "RelapseWMPose", function(pl, cmd)
	if not pl.RelapseWMPose then return end

	if not CanStay(pl) then
		GAMEMODE:SetRelapseWMPose(pl, false)
		return
	end

	cmd:ClearMovement()
	cmd:SetButtons(bit.band(cmd:GetButtons(), IN_SCORE))
	if pl.RelapseWMPoseAng then
		cmd:SetViewAngles(pl.RelapseWMPoseAng)
	end
end)

local function ClearEditor(pl)
	if pl.RelapseWMPose then
		GAMEMODE:SetRelapseWMPose(pl, false)
	end
end

hook.Add("PlayerDeath", "RelapseWMPose", ClearEditor)
hook.Add("PlayerSpawn", "RelapseWMPose", ClearEditor)
hook.Add("PlayerSilentDeath", "RelapseWMPose", ClearEditor)
hook.Add("PlayerDisconnected", "RelapseWMPose", ClearEditor)

hook.Add("PlayerInitialSpawn", "RelapseWMPose", function(pl)
	timer.Simple(1, function()
		if IsValid(pl) then
			SendAllBinds(pl)
		end
	end)
end)

hook.Add("SetupPlayerVisibility", "RelapseWMPose", function(pl)
	if not pl.RelapseWMPose then return end

	for _, other in ipairs(player.GetAll()) do
		if IsValid(other) and other:Alive() and other:GetObserverMode() == OBS_MODE_NONE then
			AddOriginToPVS(other:WorldSpaceCenter())
		end
	end
end)
