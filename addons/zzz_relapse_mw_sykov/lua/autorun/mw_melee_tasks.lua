hook.Add("PreRegisterSWEP", "MW_RegisterMeleeTask", function(SWEP, ClassName)
	if ClassName == "mg_base" then
		function SWEP:TrySetTaskAndCheck(name, ...)
			self:TrySetTask(name, ...)

			local task = self.Tasks[self:GetCurrentTask()]
			return task ~= nil and task.Name == name
		end

		include("weapons/mg_base/modules/shared/tasks/task_melee_override.lua")
		include("weapons/mg_base/modules/shared/tasks/task_melee_heavy_in.lua")
		include("weapons/mg_base/modules/shared/tasks/task_melee_heavy.lua")
	end
end)
