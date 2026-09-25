-- Relapse hearing, server: turns what a human does into their noise peak.
-- A footstep with a track does not write the fast peak. The human's client
-- plays the curve for their bar and names zombies inside the track radius;
-- bots have no client, so the server does that scan. The zombie receives one
-- peak, the loudest point of the track, already scaled by distance.
-- Shots, landings, pain, hammer and nails still use the short DT peak.

util.AddNetworkString("zs_hearing_peak")
util.AddNetworkString("zs_hearing_glow")

local math_max = math.max
local math_Clamp = math.Clamp
local CurTime = CurTime
local IsValid = IsValid
local TEAM_HUMAN = TEAM_HUMAN

---------------------------------------------------------------------------
-- Emit
---------------------------------------------------------------------------

-- kind: "step" / "shot" / "melee" / "land" / "hurt" / "repair" / "nail". Returns true if the peak was written.
function GM:EmitHumanNoise(pl, peak, kind)
	if not (IsValid(pl) and pl:IsPlayer() and pl:Team() == TEAM_HUMAN and pl:Alive()) then return false end

	peak = math_Clamp(peak or 0, 0, 100)
	if peak <= 0 then return false end

	local now = CurTime()
	local cur = self:GetHumanNoisePeak(pl)

	-- A step under a gunshot's tail is not a new sound to a zombie.
	if peak < cur * self.Hearing.Mask then return false end

	-- Multi-trace shots (pellets, ricochet passes) count once per tick.
	if pl.RelapseNoiseKind == kind and pl.RelapseNoiseAt == now then return false end
	pl.RelapseNoiseKind = kind
	pl.RelapseNoiseAt = now

	pl:SetDTFloat(DT_PLAYER_FLOAT_NOISE, math_max(peak, cur))
	pl:SetDTFloat(DT_PLAYER_FLOAT_NOISETIME, now)

	hook.Run("PlayerMadeNoise", pl, peak, kind)

	return true
end

function GM:EmitWeaponNoise(pl, wep)
	local melee = IsValid(wep) and (wep.IsMelee or wep.Melee or (istable(wep.Relapse) and wep.Relapse.Melee)) and true or false
	return self:EmitHumanNoise(pl, self:GetWeaponNoise(wep), melee and "melee" or "shot")
end

function GM:ResetHumanNoise(pl)
	if not IsValid(pl) then return end

	pl:SetDTFloat(DT_PLAYER_FLOAT_NOISE, 0)
	pl:SetDTFloat(DT_PLAYER_FLOAT_NOISETIME, 0)
	pl.RelapseNoiseKind = nil
	pl.RelapseNoiseAt = nil
	pl.RelapseNoiseFoot = nil
end

---------------------------------------------------------------------------
-- Sources
---------------------------------------------------------------------------

local function SendGlow(human, zombie, level)
	net.Start("zs_hearing_glow")
		net.WriteEntity(human)
		net.WriteFloat(level)
	net.Send(zombie)
end

-- One peak per track: loudest point (the curve is normalized to it) times the distance curve.
function GM:SendHearingGlow(human, trackId, peak)
	local track = self.HearingTracks[trackId]
	if not track or peak <= 0 then return end

	local origin = human:WorldSpaceCenter()
	local radius = track.Radius
	if radius <= 0 then return end

	for _, zombie in ipairs(team.GetPlayers(TEAM_UNDEAD)) do
		if zombie:Alive() then
			local dist = origin:Distance(zombie:WorldSpaceCenter())
			if dist <= radius then
				local level = peak * self:EvalHearingCurve(self.HearingFalloff, dist / radius)
				if level > 0 then
					SendGlow(human, zombie, level)
				end
			end
		end
	end
end

-- Stride owns the gait. A real player's client offers the peak; a bot has no client.
hook.Add("FinishMove", "RelapseHearingSteps", function(pl, mv)
	local GM = GAMEMODE
	local Stride = GM.Stride
	if not Stride or not Stride:UsesStride(pl) then
		pl.RelapseNoiseFoot = nil
		return
	end

	local st = Stride:Get(pl)
	if not st then return end

	local foot = st.foot
	local prev = pl.RelapseNoiseFoot
	pl.RelapseNoiseFoot = foot
	if prev == nil or foot == prev then return end
	if not st.grounded or st.speed < (Stride.MinSpeed or 20) then return end
	if not pl:IsBot() then return end

	GM:SendHearingGlow(pl, "step", GM:GetFootstepNoise(pl, st.speed, pl:Crouching()))
end)

-- Client already dropped anyone outside the radius. Recompute the level here.
net.Receive("zs_hearing_peak", function(_, pl)
	if not IsValid(pl) or pl:Team() ~= TEAM_HUMAN or not pl:Alive() then return end

	local now = CurTime()
	if pl.HearingPeakNext and now < pl.HearingPeakNext then return end
	pl.HearingPeakNext = now + 1

	local id = net.ReadUInt(4)
	if id ~= 1 then return end

	local track = GAMEMODE.HearingTracks.step
	local radius = track.Radius
	if radius <= 0 then return end

	local count = math.min(net.ReadUInt(5), 16)
	local peak = GAMEMODE:GetFootstepNoise(pl, pl:GetVelocity():Length2D(), pl:Crouching())
	local origin = pl:WorldSpaceCenter()
	for _ = 1, count do
		local zombie = net.ReadEntity()
		if IsValid(zombie) and zombie:IsPlayer() and zombie:Team() == TEAM_UNDEAD and zombie:Alive() then
			local dist = origin:Distance(zombie:WorldSpaceCenter())
			if dist <= radius then
				local level = peak * GAMEMODE:EvalHearingCurve(GAMEMODE.HearingFalloff, dist / radius)
				if level > 0 then
					SendGlow(pl, zombie, level)
				end
			end
		end
	end
end)

-- MW base shoots through the engine; melee tasks trace with FireBullets too.
hook.Add("EntityFireBullets", "RelapseHearingShots", function(ent, data)
	if not IsValid(ent) then return end

	local pl, wep
	if ent:IsPlayer() then
		pl = ent
		wep = ent:GetActiveWeapon()
	elseif ent:IsWeapon() then
		wep = ent
		pl = ent:GetOwner()
	else
		return
	end

	if not (IsValid(pl) and pl:IsPlayer()) then return end

	GAMEMODE:EmitWeaponNoise(pl, wep)
end)

hook.Add("OnPlayerHitGround", "RelapseHearingLand", function(pl, inwater, hitfloater, speed)
	if inwater then return end

	local L = GAMEMODE.Hearing.Land
	if (speed or 0) < L.SpeedMin then return end

	local t = math_Clamp((speed - L.SpeedMin) / (L.SpeedMax - L.SpeedMin), 0, 1)
	GAMEMODE:EmitHumanNoise(pl, Lerp(t, L.Min, L.Max), "land")
end)

hook.Add("PlayerHurt", "RelapseHearingHurt", function(victim, attacker, healthremaining, damage)
	local H = GAMEMODE.Hearing
	if (damage or 0) < H.HurtMinDamage then return end

	GAMEMODE:EmitHumanNoise(victim, H.Hurt, "hurt")
end)

hook.Add("PlayerRepairedObject", "RelapseHearingRepair", function(pl, ent, healed, wep)
	GAMEMODE:EmitHumanNoise(pl, GAMEMODE.Hearing.Repair, "repair")
end)

hook.Add("OnNailCreated", "RelapseHearingNail", function(trent, ent, nail)
	if not IsValid(nail) or not nail.GetDeployer then return end

	GAMEMODE:EmitHumanNoise(nail:GetDeployer(), GAMEMODE.Hearing.Nail, "nail")
end)

hook.Add("PlayerSpawn", "RelapseHearingReset", function(pl)
	GAMEMODE:ResetHumanNoise(pl)
end)

hook.Add("PlayerDeath", "RelapseHearingReset", function(pl)
	GAMEMODE:ResetHumanNoise(pl)
end)
