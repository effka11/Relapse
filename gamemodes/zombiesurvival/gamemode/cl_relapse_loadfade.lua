-- Fade the world in from black once the loading page is gone.
-- worldspawn startdark does this too, on its own clock, so it is cleared.
-- A hitch must not skip ahead: the first drawn frame is solid black, and
-- each later frame moves the cosine by at most one thirtieth of a second.

local FADE = 2
local STEP = 1 / 30

local function PurgeEngineFade()
	local pl = LocalPlayer()
	if not IsValid(pl) then return end
	pl:ScreenFade(SCREENFADE.PURGE, color_black, 0, 0)
end

local shown
local last
local purgeUntil = RealTime() + 8

hook.Add("Think", "RelapseMapFadePurge", function()
	PurgeEngineFade()
	if RealTime() >= purgeUntil then
		hook.Remove("Think", "RelapseMapFadePurge")
	end
end)

hook.Add("DrawOverlay", "RelapseMapFade", function()
	-- Hold solid black while the load dialog is up. The fade starts when it closes.
	if gui.IsGameUIVisible() then
		shown = nil
		last = nil
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, ScrW(), ScrH())
		return
	end

	local now = RealTime()
	if not shown then
		shown = 0
		last = now
	else
		local dt = now - last
		last = now
		if dt < 0 then dt = 0 end
		if dt > STEP then dt = STEP end
		shown = shown + dt
	end

	local u = shown / FADE
	if u >= 1 then
		hook.Remove("DrawOverlay", "RelapseMapFade")
		return
	end

	surface.SetDrawColor(0, 0, 0, math.floor(math.cos(u * math.pi * 0.5) * 255 + 0.5))
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)
