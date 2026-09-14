-- Overlay Relapse identity onto MW guns and melee after weapons register.
-- Workshop SWEPs can win the file; the shop still needs Relapse on GetStored.

local function ApplyOne(class, def)
	local wep = weapons.GetStored(class)
	if not wep then return end

	local R = (def and def.Relapse) or wep.Relapse
	if not R then return end

	wep.Relapse = R
	if def.Tier then
		wep.Tier = def.Tier
	end
	wep.PrintName = def.PrintName or wep.PrintName
	wep.TranslationName = def.TranslationName or wep.TranslationName
	wep.TranslationDescription = def.TranslationDescription or wep.TranslationDescription
	wep.RelapsePreviewIcon = def.PreviewIcon or wep.RelapsePreviewIcon
	wep.RelapsePreviewParts = def.PreviewParts or wep.RelapsePreviewParts
	if def.PreviewBoneMerge ~= nil then
		wep.RelapsePreviewBoneMerge = def.PreviewBoneMerge
	end
	if def.PreviewHullBounds ~= nil then
		wep.RelapsePreviewHullBounds = def.PreviewHullBounds
	end
	wep.RelapsePreviewBodygroups = def.PreviewBodygroups
	wep.RelapsePreviewAngle = def.PreviewAngle or wep.RelapsePreviewAngle or Angle(8, 90, 0)
	wep.RelapsePreviewLocalAng = def.PreviewLocalAng or wep.RelapsePreviewLocalAng
	wep.RelapsePreviewOffset = def.PreviewOffset or wep.RelapsePreviewOffset
	wep.RelapsePreviewLift = def.PreviewLift or wep.RelapsePreviewLift
	wep.RelapsePreviewCamScale = def.PreviewCamScale or wep.RelapsePreviewCamScale
	if CLIENT and isstring(wep.RelapsePreviewIcon) then
		killicon.Add(class, wep.RelapsePreviewIcon, Color(255, 255, 255, 255))
		wep.WepSelectIcon = surface.GetTextureID(wep.RelapsePreviewIcon)
	end
	if def.Description then
		wep.Description = def.Description
	end
	wep.WalkSpeed = SPEED_NORMAL or 95
	wep.NoDeploySpeedChange = true

	if R.Melee then
		wep.IsMelee = true
		wep.Melee = true
		wep.MeleeDamage = R.Damage
		wep.MeleeRange = R.Range
		wep.MeleeKnockBack = R.Stopping
		wep.SwingTime = R.Swing
		wep.MeleeDamageType = DMG_SLASH
		wep.Primary = wep.Primary or {}
		wep.Primary.Damage = R.Damage
		wep.Primary.Delay = R.Delay
		wep.Primary.ClipSize = -1
		wep.Primary.Ammo = "none"
		wep.Primary.Automatic = true
		wep.Primary.RPM = math.floor(60 / math.max(R.Delay or 0.5, 0.05) + 0.5)
		if wep.Bullet then
			wep.Bullet.Damage = {R.Damage, R.Damage}
		end
		local melee = wep.Animations and wep.Animations.Melee
		if melee then
			if R.Range then melee.Range = R.Range end
			if R.Swing then melee.Delay = R.Swing end
			if R.Delay then melee.Length = R.Delay end
		end
		local hit = wep.Animations and wep.Animations.Melee_Hit
		if hit then
			hit.Damage = R.Damage
			if R.Delay then
				hit.Length = R.Delay * (11 / 15)
			end
			hit.DamageType = DMG_SLASH
			if R.Stopping then
				hit.DamageForce = R.Stopping * 20
			end
		end
		return
	end

	wep.Primary = wep.Primary or {}
	wep.Primary.Damage = R.Damage
	wep.Primary.Delay = R.Delay
	wep.Primary.ClipSize = R.Clip
	wep.Primary.Ammo = def.Ammo or wep.Primary.Ammo
	wep.Primary.RPM = math.floor(60 / math.max(R.Delay or 0.2, 0.05) + 0.5)
	if R.Automatic ~= nil then
		wep.Primary.Automatic = R.Automatic
	end
	if wep.Bullet then
		local far = math.max(1, R.Damage * (1 - math.Clamp(R.Kinetic or 0, 0, 1)))
		wep.Bullet.Damage = {R.Damage, far}
		if R.Pellets then
			wep.Bullet.NumBullets = R.Pellets
		end
	end
	if R.Pellets then
		wep.Primary.NumShots = R.Pellets
	end
	wep.ReloadTime = R.Reload
	wep.ConeMin = R.Accuracy * 0.5
	wep.ConeMax = R.Accuracy * 1.5
	wep.ConeRamp = wep.ConeRamp or 2
	wep.DrawCrosshair = false

	-- Hipfire uses the ADS cone. Bloom while hip matches ADS (Increase * AdsMultiplier).
	if istable(wep.Cone) then
		if wep.Cone.Ads ~= nil then
			wep.Cone.Hip = wep.Cone.Ads
		end
		if not wep.Cone.RelapseAdsBloomBaked and wep.Cone.AdsMultiplier ~= nil then
			wep.Cone.Increase = (wep.Cone.Increase or 0) * wep.Cone.AdsMultiplier
			wep.Cone.AdsMultiplier = 1
			wep.Cone.RelapseAdsBloomBaked = true
		end
	end

	local gm = GAMEMODE or GM
	if gm and gm.SetupDefaultClip and not wep.Primary.DefaultClip then
		gm:SetupDefaultClip(wep.Primary)
	end

	if isfunction(wep.Initialize) and not wep.RelapseReconnectInit then
		wep.RelapseReconnectInit = true
		local oldInit = wep.Initialize
		wep.Initialize = function(self, ...)
			oldInit(self, ...)
			self.m_bInitialized = true
			if istable(self.Cone) and self.Cone.Ads ~= nil then
				self.Cone.Hip = self.Cone.Ads
			end
			local gm = GAMEMODE or GM
			local owner = self.GetOwner and self:GetOwner()
			if gm and gm.ReconnectWeaponEmptyLocked and IsValid(owner) and gm:ReconnectWeaponEmptyLocked(self, owner) then
				self:SetClip1(0)
			elseif self.GetNW2Bool and self:GetNW2Bool("zs_reconnect_empty", false) then
				self:SetClip1(0)
			elseif self.GetNW2Int then
				local want = self:GetNW2Int("zs_reconnect_clip1", -1)
				if want >= 0 then
					self:SetClip1(want)
				end
			end
		end
	end

	local function WrapEmptyGate(name)
		if wep["RelapseEmptyGate_" .. name] then return end
		local old = wep[name]
		wep["RelapseEmptyGate_" .. name] = true
		wep[name] = function(self, ...)
			local gm = GAMEMODE or GM
			local owner = self.GetOwner and self:GetOwner()
			if gm and gm.ReconnectWeaponEmptyLocked and IsValid(owner) and gm:ReconnectWeaponEmptyLocked(self, owner) then
				return false
			end
			if isfunction(old) then
				return old(self, ...)
			end
			local base = self.BaseClass
			if istable(base) and isfunction(base[name]) then
				return base[name](self, ...)
			end
			local stored = self.Base and weapons.GetStored(self.Base)
			if istable(stored) and isfunction(stored[name]) then
				return stored[name](self, ...)
			end
		end
	end

	WrapEmptyGate("CanAttack")
	WrapEmptyGate("CanTrigger")
	WrapEmptyGate("CanReload")
	WrapEmptyGate("CanPrimaryAttack")
end

-- MW BulletCallbackInternal pre-scales for sandbox: head *0.5 (undo *2), arms/legs *4 (undo *0.25).
-- Relapse hitgroups are 0.5 legs / 1 body+arms / 2 head, so that *4 on arms is real 4x damage.
local function WrapMWCallback(wep)
	if not istable(wep) or not isfunction(wep.BulletCallbackInternal) then return end
	if wep.RelapseHitgroupsWrapped then return end
	wep.RelapseHitgroupsWrapped = true

	local old = wep.BulletCallbackInternal
	wep.BulletCallbackInternal = function(self, tbl, attacker, tr, dmgInfo)
		local trTorso = setmetatable({HitGroup = HITGROUP_CHEST}, {
			__index = tr,
			__newindex = function(_, key, value)
				tr[key] = value
			end
		})
		return old(self, tbl, attacker, trTorso, dmgInfo)
	end
end

local function WrapMWHitgroups()
	WrapMWCallback(weapons.GetStored("mg_base"))
	local list = weapons.GetList()
	if not list then return end
	for i = 1, #list do
		local class = list[i].ClassName
		if class then
			WrapMWCallback(weapons.GetStored(class))
		end
	end
end

local function ApplyRelapseMWGuns()
	WrapMWHitgroups()

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
hook.Add("OnReloaded", "RelapseMWSykovZS", ApplyRelapseMWGuns)
-- Workshop SWEP files can killicon.Add after ours. Re-apply once entities exist.
if CLIENT then
	hook.Add("InitPostEntity", "RelapseMWSykovKillicons", function()
		timer.Simple(0, ApplyRelapseMWGuns)
	end)
end
