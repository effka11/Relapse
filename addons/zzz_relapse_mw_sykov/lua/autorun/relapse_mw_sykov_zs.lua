-- ZS needs spare ammo on Give() and a walk speed for ResetSpeed.
-- Do not change MW gunplay here; edit lua/weapons/mg_makarov/ instead.

hook.Add("Initialize", "RelapseMWSykovZS", function()
	local wep = weapons.GetStored("mg_makarov")
	if not wep then return end

	wep.WalkSpeed = SPEED_NORMAL
	wep.NoDeploySpeedChange = true
	if not wep.Description then
		wep.Description = "A compact 9x18mm pistol."
	end

	if wep.Primary and GAMEMODE and GAMEMODE.SetupDefaultClip and not wep.Primary.DefaultClip then
		GAMEMODE:SetupDefaultClip(wep.Primary)
	end
end)
