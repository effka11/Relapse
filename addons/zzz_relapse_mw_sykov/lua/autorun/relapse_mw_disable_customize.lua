-- Relapse: MW gunsmith is bound to M (+menu_context). That key is OTS.

CreateConVar("mgbase_sv_customization", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Allow gun customization.", 0, 1)

local function patchBase(wep)
	if not wep or wep.RelapseNoMWCustomize then return end
	wep.RelapseNoMWCustomize = true

	local oldCan = wep.CanPressBind
	if isfunction(oldCan) then
		wep.CanPressBind = function(self, bind)
			if bind == "customize" then return false end
			return oldCan(self, bind)
		end
	end

	local oldHandle = wep.HandleBind
	if isfunction(oldHandle) then
		wep.HandleBind = function(self, bind)
			if bind == "customize" then return end
			return oldHandle(self, bind)
		end
	end

	if isfunction(wep.GetTaskByName) then
		local task = wep:GetTaskByName("Customize")
		if istable(task) then
			task.CanBeSet = function() return false end
		end
	end
end

hook.Add("PreRegisterSWEP", "RelapseDisableMWCustomize", function(SWEP, class)
	if class == "mg_base" then
		patchBase(SWEP)
	end
end)

local function apply()
	if SERVER then
		local cv = GetConVar("mgbase_sv_customization")
		if cv then
			cv:SetInt(0)
		end
	end
	patchBase(weapons.GetStored("mg_base"))
end

hook.Add("Initialize", "RelapseDisableMWCustomize", apply)
hook.Add("InitPostEntity", "RelapseDisableMWCustomize", apply)
hook.Add("OnReloaded", "RelapseDisableMWCustomize", apply)
