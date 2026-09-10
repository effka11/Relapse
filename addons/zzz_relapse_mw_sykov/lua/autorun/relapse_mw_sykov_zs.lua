-- Overlay Relapse identity onto mg_makarov after weapons register.
-- Workshop pistols can win the SWEP file; the shop still needs Relapse on GetStored.

local function ApplyMakarovRelapse()
	local wep = weapons.GetStored("mg_makarov")
	if not wep then return end

	local gm = GAMEMODE or GM
	local def = gm and gm.RelapseWeapons and gm.RelapseWeapons.mg_makarov
	local R = (def and def.Relapse) or wep.Relapse
	if not R then return end

	wep.Relapse = R
	wep.PrintName = "Пистолет Макарова"
	wep.TranslationName = def and def.TranslationName or "wep_makarov"
	wep.TranslationDescription = def and def.TranslationDescription or "wep_makarov_desc"
	wep.RelapsePreviewIcon = "zombiesurvival/killicons/weapon_zs_makarov.png"
	wep.RelapsePreviewParts = (def and def.PreviewParts) or {
		"models/viper/mw/attachments/attachment_vm_pi_mike_barrel.mdl",
		"models/viper/mw/attachments/attachment_vm_pi_mike_grip.mdl",
	}
	wep.RelapsePreviewAngle = wep.RelapsePreviewAngle or (def and def.PreviewAngle) or Angle(8, 90, 0)
	wep.Description = "A compact service sidearm. Issued to everyone and valued by no one\194\160\194\160–\194\160\194\160until there was nothing else left."
	wep.WalkSpeed = SPEED_NORMAL or 95
	wep.NoDeploySpeedChange = true

	wep.Primary = wep.Primary or {}
	wep.Primary.Damage = R.Damage
	wep.Primary.Delay = R.Delay
	wep.Primary.ClipSize = R.Clip
	wep.Primary.Ammo = "pistol"
	wep.ReloadTime = R.Reload
	wep.ConeMin = R.Accuracy * 0.5
	wep.ConeMax = R.Accuracy * 1.5
	wep.ConeRamp = wep.ConeRamp or 2
	wep.DrawCrosshair = false

	if gm and gm.SetupDefaultClip and not wep.Primary.DefaultClip then
		gm:SetupDefaultClip(wep.Primary)
	end
end

hook.Add("Initialize", "RelapseMWSykovZS", ApplyMakarovRelapse)
hook.Add("InitPostEntity", "RelapseMWSykovZS", ApplyMakarovRelapse)
