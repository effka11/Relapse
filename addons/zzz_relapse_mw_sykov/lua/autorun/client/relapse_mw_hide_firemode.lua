-- Relapse HUD on MW guns: drop MW firemode and custom crosshair.

local empty = function() end

local function patchWeapon(wep)
	if not wep then return end

	if wep.DrawFiremode then
		wep.DrawFiremode = empty
	end
	if wep.Crosshair then
		wep.Crosshair = empty
	end
	if wep.DrawCrosshairSticks then
		wep.DrawCrosshairSticks = empty
	end

	wep.DrawCrosshair = false
end

local function isMWBase(class)
	return class and (class == "mg_base" or weapons.IsBasedOn(class, "mg_base"))
end

local function patchStored()
	patchWeapon(weapons.GetStored("mg_base"))

	for _, wep in ipairs(weapons.GetList()) do
		if isMWBase(wep.ClassName) then
			patchWeapon(weapons.GetStored(wep.ClassName))
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
