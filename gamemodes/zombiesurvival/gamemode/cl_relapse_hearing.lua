-- Relapse hearing, client.
-- The local human's noise bar follows the rise between peaks, then the release.
-- The peaks themselves stay on their own time. A step uses that footstep wav.
-- A shot uses that shot wav. A zombie
-- does not see that release. Each track sends one peak, its loudest point,
-- scaled by distance inside the track radius; the glow then fades for a few seconds.
-- The halo library is off (nixthelag).

local math_Clamp = math.Clamp
local math_max = math.max
local math_exp = math.exp
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_match = string.match
local ipairs = ipairs
local CurTime = CurTime
local FrameNumber = FrameNumber
local EyePos = EyePos
local IsValid = IsValid
local team_GetPlayers = team.GetPlayers
local util_TraceLine = util.TraceLine
local render_SetBlend = render.SetBlend
local render_ModelMaterialOverride = render.ModelMaterialOverride
local render_SetColorModulation = render.SetColorModulation
local render_SuppressEngineLighting = render.SuppressEngineLighting
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
local cam_IgnoreZ = cam.IgnoreZ
local TEAM_HUMAN = TEAM_HUMAN
local TEAM_UNDEAD = TEAM_UNDEAD

local M_Entity = FindMetaTable("Entity")
local M_Player = FindMetaTable("Player")
local E_GetDTBool = M_Entity.GetDTBool
local P_Team = M_Player.Team
local P_Alive = M_Player.Alive

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

GM.HearingView = {
	FadeIn = 0.7, -- s, eases up toward the distance brightness
	FadeOut = 0.85,
	ProxPow = 1.6, -- 1 against the body, near 0 at the edge of R
	Silhouette = 0.55, -- white blend at alpha 1: a light wash, not a plaster cast
	Ping = true,
	PingPx = 14, -- roughly constant screen size
	PingAlpha = 0.7,
	WallTraceInterval = 0.2, -- s, per human
}

local matWhite = Material("models/debug/debugwhite")
local matGlow = Material("Sprites/light_glow02_add_noz")
local colPing = Color(255, 255, 255, 255)

local HeardList = {} -- [i] = Player with alpha > 0 this frame
local HeardCount = 0
local LastFrame = -1

local traceResult = {}
local traceData = {mask = MASK_SOLID_BRUSHONLY, output = traceResult}

---------------------------------------------------------------------------
-- Envelope
---------------------------------------------------------------------------

local function HeardState(pl)
	local st = pl.RelapseHeard
	if not st then
		st = {
			alpha = 0,
			wall = 0,
			nextTrace = 0,
			dist = 0,
		}
		pl.RelapseHeard = st
	end
	return st
end

local function ClearHeard()
	for i = 1, HeardCount do
		local st = HeardList[i].RelapseHeard
		if st then
			st.alpha = 0
		end
		HeardList[i] = nil
	end
	HeardCount = 0
end

-- Once per frame. Builds HeardList for the draw passes.
local function UpdateHearing(GM)
	local frame = FrameNumber()
	if LastFrame == frame then return end
	LastFrame = frame

	local viewer = MySelf
	if not IsValid(viewer) or P_Team(viewer) ~= TEAM_UNDEAD or GM.Auras == false then
		ClearHeard()
		return
	end

	local H = GM.Hearing
	local V = GM.HearingView
	local now = CurTime()
	local eye = EyePos()
	local rangeMul = GM.ZombieEscape and 4 or 1 -- ZE kept the whole-map aura
	local dt = FrameTime()
	if dt <= 0 or dt > 0.1 then
		dt = 1 / 60
	end

	HeardCount = 0
	for _, pl in ipairs(team_GetPlayers(TEAM_HUMAN)) do
		local st = HeardState(pl)
		local target = 0

		if pl ~= viewer and P_Alive(pl) and not pl:IsDormant() then
			local center = pl:WorldSpaceCenter()
			local dist = center:Distance(eye)
			local hidden = dist * dist < 27500 and E_GetDTBool(pl, DT_PLAYER_BOOL_NECRO)
			st.dist = dist

			-- Track peak already includes distance. It fades on its own clock.
			if not hidden then
				target = GM:GetZombieGlow(pl) / 100
			end

			-- Shots and the other short peaks still use a live radius.
			local noise = GM:GetHumanNoisePeak(pl)
			if not hidden and noise > 1 then
				if now >= st.nextTrace then
					st.nextTrace = now + V.WallTraceInterval
					traceData.start = eye
					traceData.endpos = center
					util_TraceLine(traceData)
					st.wall = traceResult.Hit and 1 or 0
				end

				local radius = GM:GetNoiseRadius(noise) * rangeMul
				if st.wall == 1 then
					radius = radius * H.WallMul
				end

				local prox = radius > 0 and math_Clamp(1 - dist / radius, 0, 1) or 0
				target = math_max(target, prox ^ V.ProxPow)
			end
		end

		local tau = target > st.alpha and V.FadeIn or V.FadeOut
		st.alpha = st.alpha + (target - st.alpha) * (1 - math_exp(-dt / tau))
		if st.alpha < 0.004 then
			st.alpha = 0
		end

		if st.alpha > 0.01 then
			HeardCount = HeardCount + 1
			HeardList[HeardCount] = pl
		end
	end

	for i = HeardCount + 1, #HeardList do
		HeardList[i] = nil
	end
end

-- 0..1 for HUD / other draw code. Zero for anyone the local zombie does not hear.
function GM:GetHeardHighlight(pl)
	local st = pl.RelapseHeard
	return st and st.alpha or 0
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

-- From _PostDrawTranslucentRenderables. DrawModel here reaches humans the engine culled.
function GM:DrawHeardHumans()
	UpdateHearing(self)
	if HeardCount == 0 then return end

	local V = self.HearingView

	-- Per player: DrawModel runs _PrePlayerDraw / _PostPlayerDraw, which may reset render state.
	for i = 1, HeardCount do
		local pl = HeardList[i]
		cam_IgnoreZ(true)
		render_SuppressEngineLighting(true)
		render_ModelMaterialOverride(matWhite)
		render_SetColorModulation(1, 1, 1)
		render_SetBlend(pl.RelapseHeard.alpha * V.Silhouette)
		pl:DrawModel()
	end
	render_SetBlend(1)
	render_SetColorModulation(1, 1, 1)
	render_ModelMaterialOverride()
	render_SuppressEngineLighting(false)
	cam_IgnoreZ(false)

	if not V.Ping then return end

	local scale = V.PingPx * 2 / math_max(ScrW(), 1)
	render_SetMaterial(matGlow)
	for i = 1, HeardCount do
		local pl = HeardList[i]
		local st = pl.RelapseHeard
		if st.alpha > 0.04 then
			local size = math_max(4, st.dist * scale)
			colPing.a = math_Clamp(st.alpha * V.PingAlpha * 255, 0, 255)
			render_DrawSprite(pl:WorldSpaceCenter(), size, size, colPing)
		end
	end
end

---------------------------------------------------------------------------
-- Local bar
---------------------------------------------------------------------------

local Bands = {} -- {peaks, t0, peak} sounds playing on this client

function GM:StartLocalHearingBand(id, peak, peaks)
	if not peak or peak <= 0 then return end
	if not peaks then
		local track = id and self.HearingTracks[id]
		peaks = track and track.Peaks
	end
	if not peaks or not peaks[1] then return end
	local band = {peaks = peaks, t0 = CurTime(), peak = peak}
	Bands[#Bands + 1] = band
	return band
end

-- Max of every sound still playing. The bar reads this through GetHumanNoise.
function GM:GetLocalHearingLevel()
	local now = CurTime()
	local best = 0
	local i = 1
	while i <= #Bands do
		local band = Bands[i]
		local peaks = band.peaks
		local t = now - band.t0
		local lastT = peaks and peaks[#peaks] and peaks[#peaks][1] or 0
		local hl = self:GetNoiseHalfLife(math_max(band.peak, 1))
		if not peaks or not peaks[1] or t > lastT + hl * 8 then
			table.remove(Bands, i)
		else
			local y = self:EvalHearingRise(peaks, t, band.peak) * band.peak
			if y > best then
				best = y
			end
			i = i + 1
		end
	end
	return best
end

local function HearingSoundPath(name)
	name = string_lower(name)
	name = string_gsub(name, "\\", "/")
	name = string_gsub(name, "^[%(%)%*%#%>%<%^%@]+", "")
	if string_sub(name, 1, 6) == "sound/" then
		name = string_sub(name, 7)
	end
	return name
end

function GM:LookupHearingPeaks(name)
	local lib = self.HearingPeaks
	if not lib or not isstring(name) or name == "" then return end
	local row = lib[HearingSoundPath(name)]
	if row and row.Peaks and row.Peaks[1] then
		return row.Peaks
	end
end

function GM:StartHearingFootstep(pl, soundName)
	if pl ~= LocalPlayer() then return end
	local peaks = self:LookupHearingPeaks(soundName)
	if not peaks then
		local track = self.HearingTracks.step
		peaks = track and track.Peaks
	end
	local speed = pl:GetVelocity():Length2D()
	local Stride = self.Stride
	if Stride and Stride.Get then
		local st = Stride:Get(pl)
		if st and st.speed then
			speed = st.speed
		end
	end
	self:StartLocalHearingBand(nil, self:GetFootstepNoise(pl, speed, pl:Crouching()), peaks)
end

-- A shot file, or a script whose name is the shot. Foley around it is not.
local function HearingShotRank(path)
	local file = string_match(path, "[^/]+$") or path
	local shot = string_find(file, "fire", 1, true) or string_find(file, "_sup_", 1, true)
	if not shot then return end
	if string_find(file, "first", 1, true) then return 2 end
	if string_find(file, "dist", 1, true) or string_find(file, "_npc", 1, true) then return 3 end
	return 1
end

local function ConsiderShotWave(lib, path, bestPeaks, bestRank)
	path = HearingSoundPath(path)
	local rank = HearingShotRank(path)
	if not rank or (bestRank and rank >= bestRank) then return bestPeaks, bestRank end
	local row = lib[path]
	if row and row.Peaks and row.Peaks[1] then
		return row.Peaks, rank
	end
	return bestPeaks, bestRank
end

local function HearingPlayer(ent)
	if not IsValid(ent) then return end
	if ent:IsPlayer() then return ent end
	if ent.GetOwner then
		local owner = ent:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then return owner end
	end
end

hook.Add("EntityEmitSound", "RelapseHearingShot", function(data)
	local lp = LocalPlayer()
	if not IsValid(lp) or P_Team(lp) ~= TEAM_HUMAN or not P_Alive(lp) then return end
	if HearingPlayer(data.Entity) ~= lp then return end

	local GM = GAMEMODE
	local lib = GM.HearingPeaks
	local name = data.SoundName
	if not lib or not isstring(name) or name == "" then return end
	if not HearingShotRank(HearingSoundPath(name)) then return end

	local peaks, rank = ConsiderShotWave(lib, name)
	if sound and sound.GetProperties then
		local props = sound.GetProperties(name)
		local snd = props and props.sound
		if isstring(snd) then
			peaks, rank = ConsiderShotWave(lib, snd, peaks, rank)
		elseif istable(snd) then
			for i = 1, #snd do
				local s = snd[i]
				local path = s
				if istable(s) then
					path = s.sound or s[1]
				end
				if isstring(path) then
					peaks, rank = ConsiderShotWave(lib, path, peaks, rank)
				end
			end
		end
	end
	if not peaks or not rank then return end

	local now = CurTime()
	local prev = lp.RelapseHearingShotAt
	if prev and now - prev < 0.05 and lp.RelapseHearingShotRank and rank >= lp.RelapseHearingShotRank then
		return
	end

	local wep = data.Entity
	if not (IsValid(wep) and wep:IsWeapon()) then
		wep = lp:GetActiveWeapon()
	end
	local amp = GM:GetWeaponNoise(wep)
	local band = lp.RelapseHearingShotBand
	if prev and now - prev < 0.05 and band then
		band.peaks = peaks
		band.peak = amp
		band.t0 = now
	else
		lp.RelapseHearingShotBand = GM:StartLocalHearingBand(nil, amp, peaks)
	end
	lp.RelapseHearingShotAt = now
	lp.RelapseHearingShotRank = rank
end)

-- Names zombies whose client-side position is inside the track radius.
function GM:OfferHearingPeak(trackId, idByte)
	local track = self.HearingTracks[trackId]
	local lp = LocalPlayer()
	if not track or not IsValid(lp) then return end

	local now = CurTime()
	if lp.HearingPeakNext and now < lp.HearingPeakNext then return end

	local origin = lp:WorldSpaceCenter()
	local radius = track.Radius
	local list = {}
	for _, zombie in ipairs(team_GetPlayers(TEAM_UNDEAD)) do
		if zombie:Alive() and origin:Distance(zombie:WorldSpaceCenter()) <= radius then
			list[#list + 1] = zombie
			if #list >= 16 then
				break
			end
		end
	end
	if #list == 0 then return end

	lp.HearingPeakNext = now + 1
	net.Start("zs_hearing_peak")
		net.WriteUInt(idByte, 4)
		net.WriteUInt(#list, 5)
		for i = 1, #list do
			net.WriteEntity(list[i])
		end
	net.SendToServer()
end

hook.Add("FinishMove", "RelapseHearingStepLocal", function(pl, mv)
	if pl ~= LocalPlayer() or not IsFirstTimePredicted() then return end

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

	GM:OfferHearingPeak("step", 1)
end)

---------------------------------------------------------------------------
-- Zombie memory
---------------------------------------------------------------------------

function GM:GetZombieGlow(pl)
	local st = pl.RelapseHeard
	if not st or not st.glow or not st.glowAt then return 0 end

	local dt = CurTime() - st.glowAt
	if dt <= 0 then return st.glow end
	return st.glow * 0.5 ^ (dt / (self.Hearing.GlowHalfLife or 1.8))
end

-- A quieter peak does not erase a louder one that is still fading.
function GM:NoteZombieGlow(pl, level)
	if not IsValid(pl) or level <= 0 then return end

	local st = HeardState(pl)
	if level > self:GetZombieGlow(pl) then
		st.glow = level
		st.glowAt = CurTime()
	end
end

net.Receive("zs_hearing_glow", function()
	local human = net.ReadEntity()
	local level = net.ReadFloat()
	if IsValid(human) then
		GAMEMODE:NoteZombieGlow(human, level)
	end
end)
