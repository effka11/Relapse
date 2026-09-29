-- Wave music for zs_monsoon_b2. The map soundtrack entities are removed in
-- maps/zs_monsoon_b2.lua. This bed plays only while a wave is active.
--
-- Fades are the one clip in Desktop a.cpr (44100 Hz).
-- Cold start and the next copy's entrance: the same constrained spline,
-- 0 at the start, then
--   2.388 s  0.383
--   4.775 s  0.68
--   7.704 s  0.92
--   9.551 s  1
-- Crossfade departure: linear over the last 12.695 s. The next copy starts
-- when that tail starts, so its spline rises while the current copy falls.
-- Wave end uses that same linear tail. The next wave is a cold start.
-- Round end is a short fade under the end-round track.

if game.GetMap() ~= "zs_monsoon_b2" then return end

local SOUND = "sound/relapse/jail_unstoppable.mp3"

-- Match 0.745 and the phrase lift at GM.RelapsePhraseStrength are in the file.
-- The source was −14.04 LUFS. Playback is the wave fade times the music slider.

local KNOT_T = {
	0,
	2.3876757300856766,
	4.775351460171358,
	7.704233689076454,
	9.550702920342706,
}
local KNOT_V = { 0, 0.38268343236, 0.68, 0.92, 1 }
local FADE_IN = KNOT_T[#KNOT_T]
local FADE_OUT = 12.695197068514295

local knotSlope = {}
do
	local n = #KNOT_T
	local delta = {}
	for i = 1, n - 1 do
		delta[i] = (KNOT_V[i + 1] - KNOT_V[i]) / (KNOT_T[i + 1] - KNOT_T[i])
	end
	knotSlope[1] = delta[1]
	knotSlope[n] = delta[n - 1]
	for i = 2, n - 1 do
		if delta[i - 1] * delta[i] <= 0 then
			knotSlope[i] = 0
		else
			local w1 = 2 * (KNOT_T[i + 1] - KNOT_T[i]) + (KNOT_T[i] - KNOT_T[i - 1])
			local w2 = (KNOT_T[i + 1] - KNOT_T[i]) + 2 * (KNOT_T[i] - KNOT_T[i - 1])
			knotSlope[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])
		end
	end
end

-- Decoded length replaces this once the channel reports it.
local FILE_LEN = 151.275
local ROUND_FADE = 0.3
local PRELOAD = 3
local CHANNEL_STOPPED = GMOD_CHANNEL_STOPPED or 0

local tracks = {}
local gen = 0
local wantPrev = false
local forceEnd = false
local wasActive = false
local fadeStart
local fadeGen
local fadeDur = FADE_OUT
local opening = false
local openToken = 0
local openAfter = 0
local arming = false
local armToken = 0
local armAfter = 0
local armed
local complained = false

local function FadeIn(t)
	if t <= 0 then return 0 end
	if t >= FADE_IN then return 1 end
	local i = 1
	local n = #KNOT_T
	while i < n - 1 and t > KNOT_T[i + 1] do
		i = i + 1
	end
	local h = KNOT_T[i + 1] - KNOT_T[i]
	local u = (t - KNOT_T[i]) / h
	local u2 = u * u
	local u3 = u2 * u
	local m0 = knotSlope[i] * h
	local m1 = knotSlope[i + 1] * h
	return (2 * u3 - 3 * u2 + 1) * KNOT_V[i]
		+ (u3 - 2 * u2 + u) * m0
		+ (-2 * u3 + 3 * u2) * KNOT_V[i + 1]
		+ (u3 - u2) * m1
end

local function Want()
	local cv = GetConVar("zs_playmusic")
	if cv and not cv:GetBool() then return false end
	if forceEnd then return false end
	return GAMEMODE:GetWaveActive()
end

local function StopChan(chan)
	if IsValid(chan) then
		chan:Stop()
	end
end

local function LengthOf(slot)
	if slot.len then return slot.len end
	local chan = slot.chan
	if IsValid(chan) then
		local got = chan:GetLength() or 0
		if got > 140 and got < 170 then
			slot.len = got
			return got
		end
	end
	return FILE_LEN
end

local function TailStart(len)
	return math.max(0, len - FADE_OUT)
end

local function Volume(slot, now)
	local t = slot.chan:GetTime() or 0
	local vol = FadeIn(t)
	local len = LengthOf(slot)
	local outStart = TailStart(len)
	if t >= outStart and len > outStart then
		vol = vol * (1 - math.Clamp((t - outStart) / FADE_OUT, 0, 1))
	end
	if fadeStart and slot.gen == fadeGen then
		vol = vol * (1 - math.Clamp((now - fadeStart) / fadeDur, 0, 1))
	end
	return vol * GAMEMODE:RelapseMusicVolume()
end

local function FindHead(which)
	for i = 1, #tracks do
		local slot = tracks[i]
		if slot.head and slot.gen == which then
			return slot
		end
	end
end

local function HasSuccessor()
	if IsValid(armed) or arming then return true end
	for i = 1, #tracks do
		local slot = tracks[i]
		if slot.gen == gen and not slot.head then
			return true
		end
	end
	return false
end

local function Adopt(chan)
	if chan.EnableLooping then
		chan:EnableLooping(false)
	end
	chan:SetVolume(0)
end

hook.Add("Think", "RelapseMonsoonMusic", function()
	local active = GAMEMODE:GetWaveActive()
	if active and not wasActive and not GAMEMODE.RoundEnded then
		forceEnd = false
	end
	wasActive = active

	local want = Want()
	local now = CurTime()

	if want and not wantPrev then
		gen = gen + 1
		openToken = openToken + 1
		armToken = armToken + 1
		opening = false
		arming = false
	elseif not want and wantPrev then
		fadeStart = now
		fadeGen = gen
		if GAMEMODE.OxygenHoldStop then
			fadeDur = ROUND_FADE
		else
			fadeDur = FADE_OUT
		end
		openToken = openToken + 1
		armToken = armToken + 1
		opening = false
		arming = false
		StopChan(armed)
		armed = nil
	end
	wantPrev = want

	if want and not FindHead(gen) and not opening and now >= openAfter then
		openToken = openToken + 1
		local token = openToken
		opening = true
		local myGen = gen
		sound.PlayFile(SOUND, "noplay noblock", function(chan, errId, errName)
			if token ~= openToken then
				StopChan(chan)
				return
			end
			opening = false
			if not IsValid(chan) then
				openAfter = CurTime() + 5
				if not complained then
					complained = true
					print("[Relapse] monsoon music: " .. tostring(errName or errId))
				end
				return
			end
			Adopt(chan)
			if myGen ~= gen or not Want() then
				chan:Stop()
				return
			end
			chan:Play()
			tracks[#tracks + 1] = {
				chan = chan,
				intro = true,
				head = true,
				gen = myGen,
			}
		end)
	end

	local head = FindHead(gen)
	if want and head and IsValid(head.chan) and not HasSuccessor() and now >= armAfter then
		local t = head.chan:GetTime() or 0
		local len = LengthOf(head)
		local inStart = TailStart(len)
		if t >= inStart - PRELOAD and t < len - 0.5 then
			armToken = armToken + 1
			local token = armToken
			arming = true
			local myGen = gen
			sound.PlayFile(SOUND, "noplay noblock", function(chan, errId, errName)
				if token ~= armToken then
					StopChan(chan)
					return
				end
				arming = false
				if not IsValid(chan) then
					armAfter = CurTime() + 5
					if not complained then
						complained = true
						print("[Relapse] monsoon music: " .. tostring(errName or errId))
					end
					return
				end
				Adopt(chan)
				if myGen ~= gen or not Want() then
					chan:Stop()
					return
				end
				armed = chan
			end)
		end
	end

	head = FindHead(gen)
	if want and IsValid(armed) then
		local len = head and LengthOf(head) or FILE_LEN
		local inStart = TailStart(len)
		local t = head and IsValid(head.chan) and (head.chan:GetTime() or 0) or inStart
		if not head or t >= inStart then
			local chan = armed
			armed = nil
			chan:Play()
			tracks[#tracks + 1] = {
				chan = chan,
				intro = false,
				head = not head,
				gen = gen,
			}
		end
	end

	local i = 1
	while i <= #tracks do
		local slot = tracks[i]
		local chan = slot.chan
		local alive = IsValid(chan)
		local drop = not alive
		if alive then
			local t = chan:GetTime() or 0
			local len = LengthOf(slot)
			local state = chan:GetState()
			if fadeStart and slot.gen == fadeGen and (now - fadeStart) >= fadeDur then
				drop = true
			elseif slot.head and slot.gen == gen and t >= len - 0.05 and t > TailStart(len) then
				for j = 1, #tracks do
					local other = tracks[j]
					if other ~= slot and other.gen == slot.gen and not other.head then
						other.head = true
						break
					end
				end
				drop = true
			elseif state == CHANNEL_STOPPED and t > TailStart(len) then
				drop = true
			else
				chan:SetVolume(Volume(slot, now))
			end
		end
		if drop then
			if alive then chan:Stop() end
			table.remove(tracks, i)
		else
			i = i + 1
		end
	end

	if fadeStart then
		local pending = false
		for n = 1, #tracks do
			if tracks[n].gen == fadeGen then
				pending = true
				break
			end
		end
		if not pending then
			fadeStart = nil
			if GAMEMODE.OxygenHoldStop then
				GAMEMODE.OxygenHoldStop = nil
				hook.Remove("EntityEmitSound", "RelapseOxygenEndMute")
			end
		end
	end
end)

hook.Add("EndRound", "RelapseMonsoonMusic", function()
	forceEnd = true
	local playing = false
	for i = 1, #tracks do
		if IsValid(tracks[i].chan) then
			playing = true
			break
		end
	end
	if not playing then return end
	GAMEMODE.OxygenHoldStop = true
	if fadeStart then
		fadeStart = CurTime()
		fadeDur = ROUND_FADE
	end
end)

hook.Add("RestartRound", "RelapseMonsoonMusic", function()
	GAMEMODE.OxygenHoldStop = nil
	hook.Remove("EntityEmitSound", "RelapseOxygenEndMute")
end)
