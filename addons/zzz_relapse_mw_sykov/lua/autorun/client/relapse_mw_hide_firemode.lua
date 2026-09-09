local empty = function() end

local function patchWeapon(wep)
	if wep and wep.DrawFiremode then
		wep.DrawFiremode = empty
	end
end

local function patchStored()
	patchWeapon(weapons.GetStored("mg_base"))

	for _, wep in ipairs(weapons.GetList()) do
		local class = wep.ClassName
		if class and (class == "mg_base" or weapons.IsBasedOn(class, "mg_base")) then
			patchWeapon(weapons.GetStored(class))
		end
	end
end

hook.Add("Initialize", "RelapseHideMWFiremode", patchStored)
hook.Add("InitPostEntity", "RelapseHideMWFiremode", function()
	patchStored()

	local ply = LocalPlayer()
	if IsValid(ply) then
		patchWeapon(ply:GetActiveWeapon())
	end
end)

hook.Add("PlayerSwitchWeapon", "RelapseHideMWFiremode", function(ply, oldWep, newWep)
	if ply ~= LocalPlayer() then return end
	patchWeapon(newWep)
end)
