-- Overlay Relapse identity onto MW guns and melee after weapons register.
-- Workshop SWEPs can win the file; the shop still needs Relapse on GetStored.

-- MW BulletCallbackInternal does damage / NumBullets. Relapse.Damage is per pellet.
local function ApplyRelapsePellets(wep, R)
	if not (istable(wep) and istable(R) and R.Pellets) then return end
	local pellets = math.max(1, tonumber(R.Pellets) or 1)
	wep.Primary = wep.Primary or {}
	wep.Primary.NumShots = pellets
	if wep.Bullet then
		local far = math.max(1, (R.Damage or 0) * (1 - math.Clamp(R.Kinetic or 0, 0, 1)))
		wep.Bullet.NumBullets = pellets
		wep.Bullet.Damage = {(R.Damage or 0) * pellets, far * pellets}
		wep.Projectile = nil
	end
end

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
	wep.RelapsePreviewClipZ = def.PreviewClipZ or wep.RelapsePreviewClipZ
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

	-- Hull box lives on prop_weapon (DroppedWeaponBox). A centered X-long cube
	-- here made SCAR stand on end: mesh is +Z, physics rested on XY.

	if R.Melee then
		wep.IsMelee = true
		wep.Melee = true
		wep.MeleeDamage = R.Damage
		wep.MeleeRange = R.Range
		wep.MeleeKnockBack = R.Stopping
		wep.SwingTime = R.Swing
		local dmgtype = R.DamageType or DMG_SLASH
		wep.MeleeDamageType = dmgtype
		if def.Unarmed ~= nil then wep.Unarmed = def.Unarmed end
		if def.IsFistWeapon ~= nil then wep.IsFistWeapon = def.IsFistWeapon end
		if def.Undroppable ~= nil then wep.Undroppable = def.Undroppable end
		if def.NoDismantle ~= nil then wep.NoDismantle = def.NoDismantle end
		if def.NoPickupNotification ~= nil then wep.NoPickupNotification = def.NoPickupNotification end
		if def.NoGlassWeapons ~= nil then wep.NoGlassWeapons = def.NoGlassWeapons end
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
			hit.DamageType = dmgtype
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
	if R.Hitscan then
		wep.Projectile = nil
	end
	if wep.Bullet then
		local far = math.max(1, R.Damage * (1 - math.Clamp(R.Kinetic or 0, 0, 1)))
		wep.Bullet.Damage = {R.Damage, far}
	end
	ApplyRelapsePellets(wep, R)
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
			ApplyRelapsePellets(self, self.Relapse)
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

-- Dropped MW SWEPs have no owner. Pack Think then calls GetInfoNum on NULL.
local function WrapMWThink(wep)
	if not istable(wep) or wep.RelapseThinkOwnerWrap then return end
	if not isfunction(wep.Think) then return end
	wep.RelapseThinkOwnerWrap = true
	local old = wep.Think
	wep.Think = function(self, ...)
		if not IsValid(self:GetOwner()) then return end
		return old(self, ...)
	end
end

local function IsMWWeaponTable(wep, class)
	class = class or (istable(wep) and wep.ClassName)
	if isstring(class) and (class == "mg_base" or string.sub(class, 1, 3) == "mg_") then
		return true
	end
	return isstring(class) and weapons.IsBasedOn and weapons.IsBasedOn(class, "mg_base")
end

-- Engine DropWeapon leaves an MW SWEP in the world (invisible, no physics).
-- Relapse loot is prop_weapon; convert once if DropWeaponByType did not.
-- Only MW: StripWeapon after placing a deployable (ficus) also fires OnDrop.
local function WrapMWDrop(wep)
	if not istable(wep) or wep.RelapseDropWrap then return end
	if not IsMWWeaponTable(wep, wep.ClassName) then return end
	wep.RelapseDropWrap = true
	local old = wep.OnDrop
	wep.OnDrop = function(self, ...)
		if isfunction(old) then
			old(self, ...)
		end
		if not SERVER or not IsValid(self) or self.RelapseConvertedToLoot then
			return
		end
		if not IsMWWeaponTable(self, self:GetClass()) then
			return
		end
		if IsValid(self:GetOwner()) then
			return
		end
		self.RelapseConvertedToLoot = true
		local class = self:GetClass()
		local pos, ang = self:GetPos(), self:GetAngles()
		local ok1, clip1 = pcall(function() return self:Clip1() end)
		local ok2, clip2 = pcall(function() return self:Clip2() end)
		timer.Simple(0, function()
			if IsValid(self) then
				self:Remove()
			end
			local ent = ents.Create("prop_weapon")
			if not (ent and ent:IsValid()) then return end
			ent:Spawn()
			ent:SetWeaponType(class)
			if ent.ApplyDroppedLie then
				ent:ApplyDroppedLie(ang.y)
			else
				ent:SetAngles(ang)
			end
			ent:SetPos(pos + Vector(0, 0, 6))
			ent:SetClip1((ok1 and clip1) or 0)
			ent:SetClip2((ok2 and clip2) or 0)
			ent.DroppedTime = CurTime()
			local phys = ent:GetPhysicsObject()
			if phys:IsValid() then
				phys:SetPos(ent:GetPos())
				phys:Wake()
			end
		end)
	end
end

-- Empty clip fails engine SelectWeapon. MW Holster returns false until
-- CanSwitch, which cancels 1-9 and leaves Deploy uncalled (no viewmodel).
local function WrapMWSelect(wep)
	if not istable(wep) or wep.RelapseSelectWrapped then return end
	if not isfunction(wep.AddFlag) or not isfunction(wep.Holster) then return end

	wep.RelapseSelectWrapped = true
	wep.HasAnyAmmo = function()
		return true
	end

	local oldHolster = wep.Holster
	wep.Holster = function(self, weapon)
		if isfunction(oldHolster) then
			oldHolster(self, weapon)
		end
		return true
	end
end

-- MW reload duration is seq.Fps / 30 via GetAnimation (task timer + VM).
local function IsReloadAnim(seqIndex)
	if not isstring(seqIndex) then
		return false
	end
	local low = string.lower(seqIndex)
	if string.find(low, "inspect", 1, true) then
		return false
	end
	return string.find(low, "reload", 1, true) ~= nil
end

local function WrapReloadAnim(wep)
	if not istable(wep) or wep.RelapseReloadAnimWrap then
		return
	end
	if not isfunction(wep.GetAnimation) then
		return
	end
	wep.RelapseReloadAnimWrap = true
	local old = wep.GetAnimation
	wep.GetAnimation = function(self, seqIndex)
		local seq = old(self, seqIndex)
		if not seq or not IsReloadAnim(seqIndex) then
			return seq
		end
		local gm = GAMEMODE or GM
		local owner = self.GetOwner and self:GetOwner()
		local mul = 1
		if gm and gm.GetReloadPercentMul and IsValid(owner) then
			mul = gm:GetReloadPercentMul(owner)
		end
		if mul == 1 then
			return seq
		end
		seq = table.Copy(seq)
		seq.Fps = (seq.Fps or 30) * mul
		return seq
	end
end

local function IsMWMelee(self)
	if not istable(self) then
		return false
	end
	if self.Melee or self.IsMelee then
		return true
	end
	local R = self.Relapse
	return istable(R) and R.Melee
end

-- MW punch is CalculateRecoil * GetRecoilMultiplier (bipod 0.1, else 1).
local function WrapRecoilMul(wep)
	if not istable(wep) or wep.RelapseRecoilMulWrap then
		return
	end
	if not isfunction(wep.GetRecoilMultiplier) then
		return
	end
	wep.RelapseRecoilMulWrap = true
	local old = wep.GetRecoilMultiplier
	wep.GetRecoilMultiplier = function(self)
		local mul = old(self)
		if IsMWMelee(self) then
			return mul
		end
		local gm = GAMEMODE or GM
		local owner = self.GetOwner and self:GetOwner()
		if gm and gm.GetUpgradePercentMul and IsValid(owner) then
			return mul * gm:GetUpgradePercentMul(owner, "Recoil")
		end
		return mul
	end
end

local function WrapMWHitgroups()
	WrapMWCallback(weapons.GetStored("mg_base"))
	WrapMWSelect(weapons.GetStored("mg_base"))
	WrapMWThink(weapons.GetStored("mg_base"))
	WrapMWDrop(weapons.GetStored("mg_base"))
	WrapReloadAnim(weapons.GetStored("mg_base"))
	WrapRecoilMul(weapons.GetStored("mg_base"))
	local list = weapons.GetList()
	if not list then return end
	for i = 1, #list do
		local class = list[i].ClassName
		if class then
			local stored = weapons.GetStored(class)
			if IsMWWeaponTable(stored, class) then
				WrapMWCallback(stored)
				WrapMWSelect(stored)
				WrapMWThink(stored)
				WrapMWDrop(stored)
				WrapReloadAnim(stored)
				WrapRecoilMul(stored)
			end
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
