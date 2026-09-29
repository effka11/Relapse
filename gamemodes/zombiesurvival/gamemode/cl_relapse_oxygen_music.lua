-- Wave music for zs_oxygen_b4. The map soundtrack entity is removed in
-- maps/zs_oxygen_b4.lua. This bed plays only while a wave is active.
--
-- Cold start (nothing was already playing): S-curve from 0 to 1 over 0..10.58s.
-- Loop: the current copy falls from 1:37.5 to the end of the file. The next
-- copy starts at 1:37.55 and rises to 1 by 1:44. Same handoff again.
-- Wave end: that same tail length, S-curve down to silence. The next wave
-- is a cold start. Round end is a short fade under the end-round track,
-- which starts on its own at that moment.

if game.GetMap() ~= "zs_oxygen_b4" then return end

local SOUND = "sound/relapse/oxygen_signal.mp3"

-- The file already carries the phrase lift at GM.RelapsePhraseStrength.
-- Playback is the wave fade times the music slider.

local INTRO_END = 10.58
local OUT_START = 97.5
local IN_START = 97.55
local IN_FULL = 104
local IN_RISE = IN_FULL - IN_START

-- Frame walk of the mp3. The channel length replaces this once it decodes.
local FILE_LEN = 106.371
local WAVE_FADE = FILE_LEN - OUT_START
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
local fadeDur = WAVE_FADE
local opening = false
local openToken = 0
local openAfter = 0
local arming = false
local armToken = 0
local armAfter = 0
local armed
local complained = false

local function SCurve(t)
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end
	return t * t * (3 - 2 * t)
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
		if got > 90 and got < 140 then
			slot.len = got
			return got
		end
	end
	return FILE_LEN
end

local function Volume(slot, now)
	local t = slot.chan:GetTime() or 0
	local vol
	if slot.intro then
		vol = SCurve(t / INTRO_END)
	else
		vol = SCurve(t / IN_RISE)
	end
	local len = LengthOf(slot)
	if t >= OUT_START and len > OUT_START then
		vol = vol * (1 - SCurve((t - OUT_START) / (len - OUT_START)))
	end
	if fadeStart and slot.gen == fadeGen then
		vol = vol * (1 - SCurve((now - fadeStart) / fadeDur))
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

hook.Add("Think", "RelapseOxygenMusic", function()
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
		local head = FindHead(gen)
		local len = head and LengthOf(head) or FILE_LEN
		if GAMEMODE.OxygenHoldStop then
			fadeDur = ROUND_FADE
		else
			fadeDur = math.max(0.05, len - OUT_START)
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
					print("[Relapse] oxygen music: " .. tostring(errName or errId))
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
		if t >= IN_START - PRELOAD and t < len - 0.5 then
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
						print("[Relapse] oxygen music: " .. tostring(errName or errId))
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
		local t = head and IsValid(head.chan) and (head.chan:GetTime() or 0) or IN_START
		if not head or t >= IN_START then
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
			elseif slot.head and slot.gen == gen and t >= len - 0.05 and t > OUT_START then
				for j = 1, #tracks do
					local other = tracks[j]
					if other ~= slot and other.gen == slot.gen and not other.head then
						other.head = true
						break
					end
				end
				drop = true
			elseif state == CHANNEL_STOPPED and t > OUT_START then
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

hook.Add("EndRound", "RelapseOxygenMusic", function()
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

hook.Add("RestartRound", "RelapseOxygenMusic", function()
	GAMEMODE.OxygenHoldStop = nil
	hook.Remove("EntityEmitSound", "RelapseOxygenEndMute")
end)
