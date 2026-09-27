-- Zombie win. beyond_arrival is longer than the post-round clock, so the
-- tail fades to silence exactly when that clock hits zero. The clock is
-- EndTime + EndGameTime, the same one the end screen draws, so a different
-- EndGameTime moves the fade with it.

local SOUND = "zombiesurvival/beyond_arrival.ogg"
local DATA = "relapse_music/beyond_arrival.ogg"
local FADE = 4

local station
local loading
local gen = 0
local playing
local copied

local function timeLeft()
	if not GAMEMODE.EndTime then return 0 end
	return (GAMEMODE.EndTime + (GAMEMODE.EndGameTime or 0)) - CurTime()
end

local function volumeFor(left)
	local span = math.min(FADE, math.max(GAMEMODE.EndGameTime or 0, 0.05))
	if left <= 0 then return 0 end
	if left >= span then return 1 end
	return left / span
end

function GM:StopZombieWinMusic()
	gen = gen + 1
	loading = false
	playing = false
	if station then
		station:Stop()
		station = nil
	end
	if IsValid(MySelf) then
		MySelf:StopSound(SOUND)
	end
	timer.Remove("RelapseZombieWinMusic")
end

local function ensureCopy()
	if copied then return true end
	if file.Exists(DATA, "DATA") and (file.Size(DATA, "DATA") or 0) > 100000 then
		copied = true
		return true
	end
	local src = file.Open("sound/" .. SOUND, "rb", "GAME")
	if not src then return false end
	local bytes = src:Read(src:Size())
	src:Close()
	if not bytes or #bytes < 100000 then return false end
	file.CreateDir("relapse_music")
	local dst = file.Open(DATA, "wb", "DATA")
	if not dst then return false end
	dst:Write(bytes)
	dst:Close()
	copied = file.Exists(DATA, "DATA")
	return copied
end

local function playFallback()
	if not IsValid(MySelf) then return end
	MySelf:EmitSound(SOUND, 0, 100, 1)
end

function GM:StartZombieWinMusic()
	if playing or loading then return end
	if (GAMEMODE.EndGameTime or 0) <= 0 then return end
	if not file.Exists("sound/" .. SOUND, "GAME") then
		MsgN("[Relapse] missing sound/" .. SOUND)
		return
	end

	playing = true
	util.PrecacheSound(SOUND)

	if not ensureCopy() then
		playFallback()
		return
	end

	loading = true
	local ticket = gen
	sound.PlayFile("data/" .. DATA, "noplay noblock", function(chan, errCode, errStr)
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
			MsgN("[Relapse] beyond_arrival PlayFile failed: " .. tostring(errCode) .. " " .. tostring(errStr))
			playFallback()
			return
		end
		station = chan
		chan:EnableLooping(false)
		chan:SetVolume(volumeFor(timeLeft()))
		chan:Play()
	end)
end

hook.Add("InitPostEntity", "RelapseZombieWinMusicCopy", function()
	ensureCopy()
end)

hook.Add("Think", "RelapseZombieWinMusic", function()
	if not playing then return end

	if not GAMEMODE.RoundEnded then
		GAMEMODE:StopZombieWinMusic()
		return
	end

	local left = timeLeft()
	local vol = volumeFor(left)
	if station then
		station:SetVolume(vol)
	end
	if left <= 0 then
		GAMEMODE:StopZombieWinMusic()
	end
end)
