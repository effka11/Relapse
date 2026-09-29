-- Relapse hearing, client.
-- The local human's noise bar follows the rise between peaks, then the release.
-- The peaks themselves stay on their own time. A step uses that footstep wav.
-- A shot uses that shot wav.
-- A zombie does not see the body and does not see that release. Each heard
-- event plants a static point where the sound was. Size and brightness are
-- the level: the peak times the distance curve. The point fades in place.
-- A later event within Merge refreshes that point; it does not follow the human.
-- Footsteps arrive as one peak. Shots, landings, pain, hammer and nails are
-- read from the noise clock and planted the same way.
-- The halo library is off (nixthelag).

local math_Clamp = math.Clamp
local math_max = math.max
local math_huge = math.huge
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
local render_SetMaterial = render.SetMaterial
local render_DrawSprite = render.DrawSprite
local cam_IgnoreZ = cam.IgnoreZ
local TEAM_HUMAN = TEAM_HUMAN
local TEAM_UNDEAD = TEAM_UNDEAD

local M_Entity = FindMetaTable("Entity")
local M_Player = FindMetaTable("Player")
local E_GetDTBool = M_Entity.GetDTBool
local E_GetDTFloat = M_Entity.GetDTFloat
local P_Team = M_Player.Team
local P_Alive = M_Player.Alive

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

GM.HearingView = {
	FadeIn = 0.15, -- s, the point reaches its level, then GlowHalfLife fades it
	PointMin = 6, -- px, a quiet point. Screen size, not world size.
	PointMax = 26, -- px, level 1
	Merge = 48, -- units. A new event this close to this human's point refreshes it in place.
	MinLevel = 0.03,
}

local matGlow = Material("Sprites/light_glow02_add_noz")
local colPoint = Color(255, 255, 255, 255)

local MAX_POINTS = 64
local Points = {}
local PointCount = 0
local LastFrame = -1

local traceResult = {}
local traceData = {mask = MASK_SOLID_BRUSHONLY, output = traceResult}

---------------------------------------------------------------------------
-- Points
---------------------------------------------------------------------------

local function HeardState(pl)
	local st = pl.RelapseHeard
	if not st then
		st = {}
		pl.RelapseHeard = st
	end
	return st
end

local function PointAlpha(p, now, fadeIn, halfLife)
	local age = now - p.t0
	local appear = 1
	if fadeIn > 0 and age < fadeIn then
		appear = age / fadeIn
	end
	local decayAge = now - p.heard
	if decayAge < 0 then decayAge = 0 end
	local decay = 1
	if halfLife > 0 then
		decay = 0.5 ^ (decayAge / halfLife)
	end
	local a = p.level * appear * decay
	if a < 0 then return 0 end
	if a > 1 then return 1 end
	return a
end

local function DropPoint(i)
	local n = PointCount
	local slot = Points[i]
	Points[i] = Points[n]
	Points[n] = slot
	PointCount = n - 1
end

local function ClearPoints()
	PointCount = 0
end

-- A quieter event inside Merge does not stack a second sprite on a louder one.
function GM:AddHearingPoint(who, pos, level)
	local V = self.HearingView
	if not level or level < (V.MinLevel or 0.03) then return end
	if level > 1 then level = 1 end

	local viewer = MySelf
	if not IsValid(viewer) or P_Team(viewer) ~= TEAM_UNDEAD or self.Auras == false then return end

	local eye = EyePos()
	if pos:DistToSqr(eye) < 27500 and IsValid(who) and E_GetDTBool(who, DT_PLAYER_BOOL_NECRO) then
		return
	end

	local now = CurTime()
	local fadeIn = V.FadeIn or 0.15
	local halfLife = self.Hearing.GlowHalfLife or 1.8
	local mask = self.Hearing.Mask or 0.85
	local merge = V.Merge or 48
	local mergeSqr = merge * merge

	for i = 1, PointCount do
		local p = Points[i]
		if p.who == who then
			local dx = p.pos.x - pos.x
			local dy = p.pos.y - pos.y
			local dz = p.pos.z - pos.z
			if dx * dx + dy * dy + dz * dz <= mergeSqr then
				if level < PointAlpha(p, now, fadeIn, halfLife) * mask then return end
				if level > p.level then
					p.level = level
				end
				p.heard = now
				return
			end
		end
	end

	if PointCount >= MAX_POINTS then
		local oldest, idx = math_huge, 1
		for i = 1, PointCount do
			if Points[i].t0 < oldest then
				oldest = Points[i].t0
				idx = i
			end
		end
		DropPoint(idx)
	end

	PointCount = PointCount + 1
	local p = Points[PointCount]
	if not p then
		p = {pos = Vector()}
		Points[PointCount] = p
	end
	p.who = who
	p.pos.x, p.pos.y, p.pos.z = pos.x, pos.y, pos.z
	p.level = level
	p.t0 = now
	p.heard = now
end

-- Shot, landing, pain, hammer, nail: one point at the body when the clock moves.
-- The brush test is the existing wall muffling (Hearing.WallMul), once per event.
local function NoisePointLevel(GM, pl, eye)
	local noise = GM:GetHumanNoisePeak(pl)
	if noise <= 1 then return end

	local center = pl:WorldSpaceCenter()
	local dist = center:Distance(eye)
	if dist * dist < 27500 and E_GetDTBool(pl, DT_PLAYER_BOOL_NECRO) then return end

	traceData.start = eye
	traceData.endpos = center
	util_TraceLine(traceData)

	local radius = GM:GetNoiseRadius(noise)
	if GM.ZombieEscape then
		radius = radius * 4
	end
	if traceResult.Hit then
		radius = radius * GM.Hearing.WallMul
	end
	if radius <= 0 or dist >= radius then return end

	local fall = GM:EvalHearingCurve(GM.HearingFalloff, dist / radius)
	return (noise / 100) * fall, center
end

-- Once per frame. Plants points for new noise-clock events and drops dead ones.
local function UpdateHearing(GM)
	local frame = FrameNumber()
	if LastFrame == frame then return end
	LastFrame = frame

	local viewer = MySelf
	if not IsValid(viewer) or P_Team(viewer) ~= TEAM_UNDEAD or GM.Auras == false then
		ClearPoints()
		return
	end

	local now = CurTime()
	local eye = EyePos()
	local fadeIn = GM.HearingView.FadeIn or 0.15
	local halfLife = GM.Hearing.GlowHalfLife or 1.8

	for i = PointCount, 1, -1 do
		local p = Points[i]
		if now - p.t0 >= fadeIn and PointAlpha(p, now, fadeIn, halfLife) < 0.02 then
			DropPoint(i)
		end
	end

	for _, pl in ipairs(team_GetPlayers(TEAM_HUMAN)) do
		if pl ~= viewer then
			local st = HeardState(pl)
			local nt = E_GetDTFloat(pl, DT_PLAYER_FLOAT_NOISETIME) or 0
			if not P_Alive(pl) or pl:IsDormant() then
				st.noiseAt = nt
			elseif nt ~= st.noiseAt then
				local prev = st.noiseAt
				st.noiseAt = nt
				if prev ~= nil and nt > 0 then
					local level, pos = NoisePointLevel(GM, pl, eye)
					if level then
						GM:AddHearingPoint(pl, pos, level)
					end
				end
			end
		end
	end
end

-- 0..1, loudest live point of this human. Zero when the local zombie hears nothing there.
function GM:GetHeardHighlight(pl)
	local best = 0
	local now = CurTime()
	local V = self.HearingView
	local fadeIn = V and V.FadeIn or 0.15
	local halfLife = self.Hearing.GlowHalfLife or 1.8
	for i = 1, PointCount do
		local p = Points[i]
		if p.who == pl then
			local a = PointAlpha(p, now, fadeIn, halfLife)
			if a > best then
				best = a
			end
		end
	end
	return best
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function GM:DrawHeardHumans()
	UpdateHearing(self)
	if PointCount == 0 then return end

	local V = self.HearingView
	local now = CurTime()
	local eye = EyePos()
	local fadeIn = V.FadeIn or 0.15
	local halfLife = self.Hearing.GlowHalfLife or 1.8
	local pxMin = V.PointMin or 6
	local pxSpan = (V.PointMax or 26) - pxMin
	local scale = 2 / math_max(ScrW(), 1)

	cam_IgnoreZ(true)
	render_SetMaterial(matGlow)
	for i = 1, PointCount do
		local p = Points[i]
		local a = PointAlpha(p, now, fadeIn, halfLife)
		if a > 0.02 then
			local dist = p.pos:Distance(eye)
			local px = pxMin + pxSpan * p.level
			local size = math_max(3, dist * px * scale)
			colPoint.a = math_Clamp(a * 255, 0, 255)
			render_DrawSprite(p.pos, size, size, colPoint)
		end
	end
	cam_IgnoreZ(false)
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
-- Footstep peak. The position is where the step was, not where the body is now.
---------------------------------------------------------------------------

net.Receive("zs_hearing_glow", function()
	local human = net.ReadEntity()
	local level = net.ReadFloat()
	local pos = net.ReadVector()
	if level <= 0 then return end
	GAMEMODE:AddHearingPoint(human, pos, level / 100)
end)
