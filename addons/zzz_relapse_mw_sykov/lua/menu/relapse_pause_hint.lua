-- Relapse ESC pause: GMod shows Shift+Esc from menu/errors.lua after four
-- blocked opens. Addon menu lua can load before that file, so re-silence.

local wrapped

local function FindErrors(fn)
	if not fn or not debug or not debug.getupvalue then
		return nil
	end
	for i = 1, 16 do
		local name, val = debug.getupvalue(fn, i)
		if not name then
			break
		end
		if name == "Errors" and istable(val) then
			return val
		end
	end
	return nil
end

local function WrapErrorOverlay()
	if wrapped then
		return
	end
	local tab = hook.GetTable()["DrawOverlay"]
	local orig = tab and tab["MenuDrawLuaErrors"]
	if not orig then
		return
	end

	local errors = FindErrors(orig)
	hook.Add("DrawOverlay", "MenuDrawLuaErrors", function(...)
		if errors then
			errors["internal_shift+esc"] = nil
		end
		return orig(...)
	end)
	wrapped = true
end

local function Silence()
	hook.Add("OnPauseMenuBlockedTooManyTimes", "TellAboutShiftEsc", function() end)
	WrapErrorOverlay()
end

Silence()
timer.Simple(0, Silence)
timer.Simple(1, Silence)
timer.Create("RelapseNoPauseHint", 2, 0, Silence)
