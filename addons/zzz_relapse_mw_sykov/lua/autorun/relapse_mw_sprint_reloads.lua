-- Relapse: MW sprint (priority 6) beats reload (4). The pack convar
-- raises reload to 7 so R works while running and Shift does not cancel it.

CreateConVar("mgbase_sv_sprintreloads", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables sprint reloads.", 0, 1)

local function apply()
	if SERVER then
		local cv = GetConVar("mgbase_sv_sprintreloads")
		if cv then
			cv:SetInt(1)
		end
	end
end

hook.Add("Initialize", "RelapseMWSprintReloads", apply)
hook.Add("InitPostEntity", "RelapseMWSprintReloads", apply)
hook.Add("OnReloaded", "RelapseMWSprintReloads", apply)
