-- Relapse: MW first-person DOF (reload, inspect, optic) stays off.

local hooked

local function patch()
	local stored = scripted_ents.GetStored("mg_viewmodel")
	local ent = stored and stored.t
	if not ent or not isfunction(ent.ViewBlur) then
		return false
	end

	if not ent.RelapseNoViewBlur then
		ent.RelapseNoViewBlur = true
		ent.ViewBlur = function() end
	end

	local cv = GetConVar("mgbase_fx_blur")
	if cv and cv:GetInt() ~= 0 then
		cv:SetInt(0)
	end

	if not hooked and cv then
		hooked = true
		cvars.AddChangeCallback("mgbase_fx_blur", function(_, _, new)
			if new ~= "0" then
				RunConsoleCommand("mgbase_fx_blur", "0")
			end
		end, "RelapseMWNoViewBlur")
	end

	return ent.RelapseNoViewBlur and cv ~= nil
end

-- Returning true from these hooks stops the gamemode call, so the HUD is never created.
local function patchHook()
	patch()
end

hook.Add("Initialize", "RelapseMWNoViewBlur", patchHook)
hook.Add("InitPostEntity", "RelapseMWNoViewBlur", patchHook)
hook.Add("OnReloaded", "RelapseMWNoViewBlur", patchHook)

hook.Add("Think", "RelapseMWNoViewBlur", function()
	if patch() then
		hook.Remove("Think", "RelapseMWNoViewBlur")
	end
end)
