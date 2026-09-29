-- End-round music. The track is longer than the post-round clock, so the
-- tail fades to silence exactly when that clock hits zero. The clock is
-- EndTime + EndGameTime, the same one the end screen draws, so a different
-- EndGameTime moves the fade with it.
-- Zombies: beyond_arrival. Humans: cloud_stillness, unless the map set winmusic.

local FADE = 4

-- Match and the phrase lift at GM.RelapsePhraseStrength are already in the
-- file. Beyond Arrival's first minute was -10.71 LUFS (gain 0.508).
-- Cloud Stillness's first minute was -16.74; the peak ceiling held the
-- match at 0.947, then a uniform 0.18 dB trim kept the encode under -1 dBTP.
local TRACKS = {
	[TEAM_UNDEAD] = {
		sound = "zombiesurvival/beyond_arrival.ogg",
		data = "relapse_music/beyond_arrival.ogg",
		name = "beyond_arrival",
	},
	[TEAM_HUMAN] = {
		sound = "zombiesurvival/cloud_stillness.ogg",
		data = "relapse_music/cloud_stillness.ogg",
		name = "cloud_stillness",
	},
}

local station
local loading
local gen = 0
local playing
local active
local copied = {}

local function timeLeft()
	if GAMEMODE.RelapseEndSecondsLeft then
		return GAMEMODE:RelapseEndSecondsLeft()
	end
	if not GAMEMODE.EndTime then return 0 end
	return (GAMEMODE.EndTime + (GAMEMODE.EndGameTime or 0) + (GAMEMODE.RelapseEndExtra or 0)) - CurTime()
end

local function volumeFor(left)
	local span = math.min(FADE, math.max(GAMEMODE.EndGameTime or 0, 0.05))
	if left <= 0 then return 0 end
	if left >= span then return 1 end
	return left / span
end

local function trackFor(winner)
	return TRACKS[winner]
end

function GM:StopEndMusic()
	gen = gen + 1
	loading = false
	playing = false
	if station then
		station:Stop()
		station = nil
	end
	if IsValid(MySelf) and active then
		MySelf:StopSound(active.sound)
	end
	active = nil
	timer.Remove("RelapseEndMusic")
end

function GM:StopZombieWinMusic()
	self:StopEndMusic()
end

local function ensureCopy(track)
	local src = file.Open("sound/" .. track.sound, "rb", "GAME")
	if not src then return false end
	local bytes = src:Read(src:Size())
	src:Close()
	if not bytes or #bytes < 100000 then return false end
	if file.Exists(track.data, "DATA") and (file.Size(track.data, "DATA") or 0) == #bytes then
		copied[track.data] = true
		return true
	end
	file.CreateDir("relapse_music")
	local dst = file.Open(track.data, "wb", "DATA")
	if not dst then return false end
	dst:Write(bytes)
	dst:Close()
	copied[track.data] = file.Exists(track.data, "DATA")
	return copied[track.data]
end

local function musicGain()
	return GAMEMODE:RelapseMusicVolume()
end

local function playFallback(track)
	if not IsValid(MySelf) then return end
	MySelf:EmitSound(track.sound, 0, 100, musicGain())
end

function GM:StartEndMusic(winner)
	local track = trackFor(winner)
	if not track then return end
	if playing or loading then return end
	if (GAMEMODE.EndGameTime or 0) <= 0 then return end
	if not file.Exists("sound/" .. track.sound, "GAME") then
		MsgN("[Relapse] missing sound/" .. track.sound)
		return
	end

	playing = true
	active = track
	util.PrecacheSound(track.sound)

	if not ensureCopy(track) then
		playFallback(track)
		return
	end

	loading = true
	local ticket = gen
	sound.PlayFile("data/" .. track.data, "noplay noblock", function(chan, errCode, errStr)
		if ticket ~= gen then
			if chan then chan:Stop() end
			return
		end
		loading = false
		if not playing then
			if chan then chan:Stop() end
			return
		end
		if not chan then
			MsgN("[Relapse] " .. track.name .. " PlayFile failed: " .. tostring(errCode) .. " " .. tostring(errStr))
			playFallback(track)
			return
		end
		station = chan
		chan:EnableLooping(false)
		chan:SetVolume(volumeFor(timeLeft()) * musicGain())
		chan:Play()
	end)
end

function GM:StartZombieWinMusic()
	self:StartEndMusic(TEAM_UNDEAD)
end

hook.Add("InitPostEntity", "RelapseEndMusicCopy", function()
	for _, track in pairs(TRACKS) do
		ensureCopy(track)
	end
end)

hook.Add("Think", "RelapseEndMusic", function()
	if not playing then return end

	if not GAMEMODE.RoundEnded then
		GAMEMODE:StopEndMusic()
		return
	end

	local left = timeLeft()
	local vol = volumeFor(left) * musicGain()
	if station then
		station:SetVolume(vol)
	end
	if left <= 0 then
		GAMEMODE:StopEndMusic()
	end
end)
