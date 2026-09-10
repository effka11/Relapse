-- Overlay Relapse identity onto MW pistols after weapons register.
-- Workshop pistols can win the SWEP file; the shop still needs Relapse on GetStored.

local function ApplyOne(class, def)
	local wep = weapons.GetStored(class)
	if not wep then return end

	local R = (def and def.Relapse) or wep.Relapse
	if not R then return end

	wep.Relapse = R
	wep.PrintName = def.PrintName or wep.PrintName
	wep.TranslationName = def.TranslationName or wep.TranslationName
	wep.TranslationDescription = def.TranslationDescription or wep.TranslationDescription
	wep.RelapsePreviewIcon = def.PreviewIcon or wep.RelapsePreviewIcon
	wep.RelapsePreviewParts = def.PreviewParts or wep.RelapsePreviewParts
	wep.RelapsePreviewBoneMerge = def.PreviewBoneMerge or wep.RelapsePreviewBoneMerge
	wep.RelapsePreviewAngle = wep.RelapsePreviewAngle or def.PreviewAngle or Angle(8, 90, 0)
	wep.RelapsePreviewLocalAng = def.PreviewLocalAng or wep.RelapsePreviewLocalAng
	if CLIENT and isstring(wep.RelapsePreviewIcon) then
		killicon.Add(class, wep.RelapsePreviewIcon, Color(255, 255, 255, 255))
		wep.WepSelectIcon = surface.GetTextureID(wep.RelapsePreviewIcon)
	end
	if def.Description then
		wep.Description = def.Description
	end
	wep.WalkSpeed = SPEED_NORMAL or 95
	wep.NoDeploySpeedChange = true

	wep.Primary = wep.Primary or {}
	wep.Primary.Damage = R.Damage
	wep.Primary.Delay = R.Delay
	wep.Primary.ClipSize = R.Clip
	wep.Primary.Ammo = def.Ammo or "pistol"
	wep.ReloadTime = R.Reload
	wep.ConeMin = R.Accuracy * 0.5
	wep.ConeMax = R.Accuracy * 1.5
	wep.ConeRamp = wep.ConeRamp or 2
	wep.DrawCrosshair = false

	local gm = GAMEMODE or GM
	if gm and gm.SetupDefaultClip and not wep.Primary.DefaultClip then
		gm:SetupDefaultClip(wep.Primary)
	end
end

local function ApplyRelapseMWGuns()
	local gm = GAMEMODE or GM
	local defs = gm and gm.RelapseWeapons
	if not defs then return end

	for class, def in pairs(defs) do
		if istable(def) and def.Relapse then
			ApplyOne(class, def)
		end
	end
end

hook.Add("Initialize", "RelapseMWSykovZS", ApplyRelapseMWGuns)
hook.Add("InitPostEntity", "RelapseMWSykovZS", ApplyRelapseMWGuns)
-- Workshop SWEP files can killicon.Add after ours. Re-apply once entities exist.
if CLIENT then
	hook.Add("InitPostEntity", "RelapseMWSykovKillicons", function()
		timer.Simple(0, ApplyRelapseMWGuns)
	end)
end
