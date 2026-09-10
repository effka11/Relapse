-- In-round reconnect: keep team, loadout, and position if a player drops.

GM.ReconnectData = {}

local SKIP_AMMO = {
	dummy = true,
	none = true,
}

function GM:GetReconnectKeys(pl)
	local keys = {pl:UniqueID()}
	local sid = pl:SteamID64()
	if sid then
		keys[#keys + 1] = sid
	end

	return keys
end

function GM:ClearReconnectStates()
	self.ReconnectData = {}
end

function GM:PeekReconnectState(pl)
	for _, key in ipairs(self:GetReconnectKeys(pl)) do
		local state = self.ReconnectData[key]
		if state then
			if state.round ~= nil and state.round ~= self.CurrentRound then
				self:ForgetReconnectState(pl)
				return nil
			end

			return state
		end
	end
end

function GM:ForgetReconnectState(pl)
	for _, key in ipairs(self:GetReconnectKeys(pl)) do
		self.ReconnectData[key] = nil
	end
end

function GM:StoreReconnectState(pl, state)
	for _, key in ipairs(self:GetReconnectKeys(pl)) do
		self.ReconnectData[key] = state
	end
end

local function CollectAmmoTypes(gm)
	local types = {}

	local function add(name)
		if not name or name == "" or not isstring(name) or SKIP_AMMO[string.lower(name)] then return end
		types[name] = true
	end

	if gm.AmmoCache then
		for name in pairs(gm.AmmoCache) do
			add(name)
		end
	end

	if gm.AmmoNames then
		for name in pairs(gm.AmmoNames) do
			add(name)
		end
	end

	if gm.AmmoModels then
		for name in pairs(gm.AmmoModels) do
			add(name)
		end
	end

	if CUSTOM_AMMO then
		for name in pairs(CUSTOM_AMMO) do
			if isstring(name) then
				add(name)
			end
		end
	end

	return types
end

function GM:CollectPlayerAmmo(pl)
	local ammo = {}
	local types = CollectAmmoTypes(self)

	for _, wep in pairs(pl:GetWeapons()) do
		if wep:IsValid() then
			if wep.Primary and wep.Primary.Ammo then
				types[wep.Primary.Ammo] = true
			end
			if wep.Secondary and wep.Secondary.Ammo then
				types[wep.Secondary.Ammo] = true
			end
		end
	end

	for ammotype in pairs(types) do
		if not SKIP_AMMO[string.lower(tostring(ammotype))] then
			local count = pl:GetAmmoCount(ammotype)
			if count and count > 0 then
				ammo[ammotype] = count
			end
		end
	end

	return ammo
end

function GM:BuildReconnectState(pl)
	if not IsValid(pl) or pl:IsBot() or pl.IsZSBot then return end

	local teamid = pl:Team()
	if teamid ~= TEAM_HUMAN and teamid ~= TEAM_UNDEAD then return end

	local observer = pl:GetObserverMode()
	local alive = pl:Alive() and observer == OBS_MODE_NONE
	-- Death already dropped the human loadout; they are about to become undead.
	if not alive and teamid == TEAM_HUMAN then
		teamid = TEAM_UNDEAD
	end

	local weapons = {}
	if alive and teamid == TEAM_HUMAN then
		for _, wep in pairs(pl:GetWeapons()) do
			if wep:IsValid() then
				weapons[#weapons + 1] = {
					class = wep:GetClass(),
					clip1 = math.max(0, wep:Clip1()),
					clip2 = math.max(0, wep:Clip2())
				}
			end
		end
	end

	local active = pl:GetActiveWeapon()

	return {
		round = self.CurrentRound,
		team = teamid,
		alive = alive,
		pos = alive and pl:GetPos() or nil,
		ang = alive and pl:EyeAngles() or nil,
		velocity = alive and pl:GetVelocity() or nil,
		health = alive and pl:Health() or nil,
		bloodarmor = teamid == TEAM_HUMAN and pl:GetBloodArmor() or nil,
		points = pl:GetPoints(),
		pointsremainder = pl.PointsRemainder or 0,
		pointqueue = pl.PointQueue or 0,
		frags = pl:Frags(),
		deaths = pl:Deaths(),
		weapons = weapons,
		ammo = (alive and teamid == TEAM_HUMAN) and self:CollectPlayerAmmo(pl) or nil,
		inventory = (teamid == TEAM_HUMAN and pl.ZSInventory) and table.Copy(pl.ZSInventory) or nil,
		packeditems = (teamid == TEAM_HUMAN and pl.PackedItems) and table.Copy(pl.PackedItems) or nil,
		activeweapon = (active and active:IsValid()) and active:GetClass() or nil,
		zombieclass = pl:GetZombieClass(),
		deathclass = pl.DeathClass,
		wavejoined = pl.WaveJoined,
		spawnedtime = pl.SpawnedTime,
		zombieskilled = pl.ZombiesKilled or 0,
		zombieskilledassists = pl.ZombiesKilledAssists or 0,
		headshots = pl.Headshots or 0,
		brainseaten = pl.BrainsEaten or 0,
		crowkills = pl.CrowKills or 0,
		defencedamage = pl.DefenceDamage or 0,
		strengthboostdamage = pl.StrengthBoostDamage or 0,
		barricadedamage = pl.BarricadeDamage or 0,
		damagedealt = pl.DamageDealt and table.Copy(pl.DamageDealt) or nil,
		healedthisround = pl.HealedThisRound or 0,
		repairedthisround = pl.RepairedThisRound or 0,
		resupplyboxusedbyothers = pl.ResupplyBoxUsedByOthers or 0,
		nestsdestroyed = pl.NestsDestroyed or 0,
		nestspawns = pl.NestSpawns or 0,
		wavebarricadedamage = pl.WaveBarricadeDamage or 0,
		wavehumandamage = pl.WaveHumanDamage or 0,
		lifebarricadedamage = pl.LifeBarricadeDamage or 0,
		lifehumandamage = pl.LifeHumanDamage or 0,
		lifebrainseaten = pl.LifeBrainsEaten or 0,
		nextresupplyuse = pl.NextResupplyUse,
		stowagecaches = pl.StowageCaches or 0,
		latebuyermessage = pl.LateBuyerMessage,
		diedduringwave0 = pl.DiedDuringWave0,
		checkedout = self.CheckedOut[pl:UniqueID()]
	}
end

function GM:SaveReconnectState(pl)
	local state = self:BuildReconnectState(pl)
	if not state then return false end

	self:StoreReconnectState(pl, state)
	return true
end

function GM:ApplyReconnectRoundStats(pl, state)
	if not state then return end

	pl.WaveJoined = state.wavejoined or pl.WaveJoined
	pl.SpawnedTime = state.spawnedtime or pl.SpawnedTime
	pl.ZombiesKilled = state.zombieskilled or 0
	pl.ZombiesKilledAssists = state.zombieskilledassists or 0
	pl.Headshots = state.headshots or 0
	pl.BrainsEaten = state.brainseaten or 0
	pl.CrowKills = state.crowkills or 0
	pl.DefenceDamage = state.defencedamage or 0
	pl.StrengthBoostDamage = state.strengthboostdamage or 0
	pl.BarricadeDamage = state.barricadedamage or 0
	pl.PointsRemainder = state.pointsremainder or 0
	pl.PointQueue = state.pointqueue or 0
	pl.HealedThisRound = state.healedthisround or 0
	pl.RepairedThisRound = state.repairedthisround or 0
	pl.ResupplyBoxUsedByOthers = state.resupplyboxusedbyothers or 0
	pl.NestsDestroyed = state.nestsdestroyed or 0
	pl.NestSpawns = state.nestspawns or 0
	pl.WaveBarricadeDamage = state.wavebarricadedamage or 0
	pl.WaveHumanDamage = state.wavehumandamage or 0
	pl.LifeBarricadeDamage = state.lifebarricadedamage or 0
	pl.LifeHumanDamage = state.lifehumandamage or 0
	pl.LifeBrainsEaten = state.lifebrainseaten or 0
	pl.LateBuyerMessage = state.latebuyermessage
	pl.DiedDuringWave0 = state.diedduringwave0

	if state.checkedout then
		self.CheckedOut[pl:UniqueID()] = true
	end

	if state.damagedealt then
		pl.DamageDealt = table.Copy(state.damagedealt)
	end

	if state.frags ~= nil then
		pl:SetFrags(state.frags)
	end
	if state.deaths ~= nil then
		pl:SetDeaths(state.deaths)
	end
end

function GM:TryReconnectTeam(pl)
	local state = self:PeekReconnectState(pl)
	if not state then return false end

	pl.m_ReconnectRestore = state
	pl.DidntSpawnOnSpawnPoint = true

	if state.team == TEAM_UNDEAD then
		pl:ChangeTeam(TEAM_UNDEAD)
		self.PreviouslyDied[pl:UniqueID()] = self.PreviouslyDied[pl:UniqueID()] or CurTime()
	else
		pl:ChangeTeam(TEAM_HUMAN)
		pl.SpawnedTime = state.spawnedtime or CurTime()
	end

	if state.team == TEAM_UNDEAD then
		if state.alive and state.zombieclass then
			pl:SetZombieClass(state.zombieclass)
			pl.DeathClass = state.deathclass
		elseif not self:GetWaveActive() then
			pl:SetZombieClassName("Crow")
			pl.DeathClass = state.deathclass or self.DefaultZombieClass
		elseif state.zombieclass then
			pl:SetZombieClass(state.zombieclass)
			pl.DeathClass = state.deathclass
		else
			pl:SetZombieClass(self.DefaultZombieClass)
		end

		if state.alive and state.ang then
			pl.ForceSpawnAngles = state.ang
		end
	else
		pl:SetZombieClass(self.DefaultZombieClass)
	end

	self:ApplyReconnectRoundStats(pl, state)

	return true
end

function GM:SyncReconnectInventory(pl)
	if not pl.ZSInventory then return end

	for item, count in pairs(pl.ZSInventory) do
		net.Start("zs_inventoryitem")
			net.WriteString(item)
			net.WriteInt(count, 5)
		net.Send(pl)
	end
end

local function GiveReconnectWeapon(pl, class)
	if not class or pl:HasWeapon(class) then
		return pl:GetWeapon(class)
	end

	-- noAmmo avoids DefaultClip, which Equip would otherwise treat as a live pool.
	local wep = pl:Give(class, true)
	if not (wep and wep:IsValid() and wep:IsWeapon()) then
		wep = pl:Give(class)
	end

	if wep and wep:IsValid() and wep:IsWeapon() and wep.EmptyAll then
		wep:EmptyAll(true)
	end

	return wep
end

local function WeaponPrimarySpare(pl, class, state)
	local function count_for(ammotype)
		if not ammotype or ammotype == "" then return end

		if state and state.ammo then
			if state.ammo[ammotype] ~= nil then
				return math.max(0, state.ammo[ammotype])
			end
			local lower = string.lower(ammotype)
			if state.ammo[lower] ~= nil then
				return math.max(0, state.ammo[lower])
			end
		end

		return math.max(0, pl:GetAmmoCount(ammotype))
	end

	local wep = class and pl:GetWeapon(class)
	if wep and wep:IsValid() and wep.ValidPrimaryAmmo then
		local spare = count_for(wep:ValidPrimaryAmmo())
		if spare then return spare end
	end

	local stored = weapons.GetStored(class)
	local spare = count_for(stored and stored.Primary and stored.Primary.Ammo)
	if spare then return spare end

	return 0
end

function GM:ApplyReconnectWeaponAmmo(pl, state)
	if not IsValid(pl) or not state then return end

	for ammotype, count in pairs(state.ammo or {}) do
		pl:SetAmmo(math.max(0, count), ammotype)
	end

	for _, wepdata in ipairs(state.weapons or {}) do
		local wep = wepdata.class and pl:GetWeapon(wepdata.class)
		if wep and wep:IsValid() then
			-- Clip1/2 of -1 is Source "infinite clip".
			if wepdata.clip1 ~= nil and wepdata.clip1 >= 0 then
				wep:SetClip1(wepdata.clip1)
				wep:SetNW2Int("zs_reconnect_clip1", wepdata.clip1)
			end
			if wepdata.clip2 ~= nil and wepdata.clip2 >= 0 then
				wep:SetClip2(wepdata.clip2)
			end
			wep:SetNW2Int("zs_reconnect_spare", WeaponPrimarySpare(pl, wepdata.class, state))
		end
	end
end

function GM:ReconnectAmmoSpent(pl, state)
	state = state or (IsValid(pl) and pl.m_ReconnectAmmoState)
	if not IsValid(pl) or not state then return true end

	for _, wepdata in ipairs(state.weapons or {}) do
		local wep = wepdata.class and pl:GetWeapon(wepdata.class)
		if wep and wep:IsValid() then
			local live = wep:Clip1()
			if live >= 0 and wepdata.clip1 and live < wepdata.clip1 then
				return true
			end
		end
	end

	return false
end

function GM:SendReconnectWeaponAmmo(pl, state)
	state = state or (IsValid(pl) and pl.m_ReconnectAmmoState)
	if not IsValid(pl) or not state then return end

	local weps = state.weapons or {}
	local packed = {}
	for name in pairs(CollectAmmoTypes(self)) do
		packed[#packed + 1] = {name, math.max(0, pl:GetAmmoCount(name))}
	end

	net.Start("zs_reconnectammo")
		net.WriteUInt(math.min(#weps, 255), 8)
		for i = 1, math.min(#weps, 255) do
			local wepdata = weps[i]
			local class = wepdata.class or ""
			net.WriteString(class)
			net.WriteInt(wepdata.clip1 or 0, 16)
			net.WriteInt(wepdata.clip2 or 0, 16)
			net.WriteUInt(math.min(WeaponPrimarySpare(pl, class, state), 65535), 16)
		end
		net.WriteUInt(math.min(#packed, 255), 8)
		for i = 1, math.min(#packed, 255) do
			net.WriteString(packed[i][1])
			net.WriteUInt(math.min(packed[i][2], 65535), 16)
		end
	net.Send(pl)
end

function GM:StampReconnectAmmo(pl, state)
	state = state or (IsValid(pl) and pl.m_ReconnectAmmoState)
	if not IsValid(pl) or not state then return end
	if self:ReconnectAmmoSpent(pl, state) then
		for _, wepdata in ipairs(state.weapons or {}) do
			local wep = wepdata.class and pl:GetWeapon(wepdata.class)
			if wep and wep:IsValid() then
				wep:SetNW2Int("zs_reconnect_clip1", -1)
				wep:SetNW2Int("zs_reconnect_spare", -1)
			end
		end
		if pl.m_ReconnectAmmoState == state then
			pl.m_ReconnectAmmoState = nil
		end
		return
	end

	self:ApplyReconnectWeaponAmmo(pl, state)
	self:SendReconnectWeaponAmmo(pl, state)
end

function GM:FinishReconnectAmmo(pl)
	local state = pl.m_ReconnectAmmoState
	if not state then return end

	self:StampReconnectAmmo(pl, state)

	local delays = {0, 0.15, 0.4, 1, 2}
	for _, delay in ipairs(delays) do
		timer.Simple(delay, function()
			if not IsValid(pl) then return end
			self:StampReconnectAmmo(pl, state)
		end)
	end

	timer.Simple(3, function()
		if IsValid(pl) and pl.m_ReconnectAmmoState == state then
			pl.m_ReconnectAmmoState = nil
		end
	end)
end

function GM:ApplyReconnectSpawn(pl)
	local state = pl.m_ReconnectRestore
	pl.m_ReconnectRestore = nil
	self:ForgetReconnectState(pl)

	if not state or not IsValid(pl) then return end

	pl.m_ReconnectRestored = true

	if state.team == TEAM_HUMAN then
		pl.PackedItems = state.packeditems and table.Copy(state.packeditems) or {}
		pl.ZSInventory = state.inventory and table.Copy(state.inventory) or {}
		pl:ApplyTrinkets()
		self:SyncReconnectInventory(pl)

		for _, wepdata in ipairs(state.weapons or {}) do
			GiveReconnectWeapon(pl, wepdata.class)
		end

		if not pl:HasWeapon("weapon_zs_fists") and not self.ZombieEscape then
			GiveReconnectWeapon(pl, "weapon_zs_fists")
		end

		for _, wep in pairs(pl:GetWeapons()) do
			if wep:IsValid() and wep.EmptyAll then
				wep:EmptyAll(true)
			end
		end

		pl:StripAmmo()
		self:ApplyReconnectWeaponAmmo(pl, state)
		pl.m_ReconnectAmmoState = {
			weapons = table.Copy(state.weapons or {}),
			ammo = table.Copy(state.ammo or {})
		}
		self:SendReconnectWeaponAmmo(pl, pl.m_ReconnectAmmoState)

		if state.activeweapon and pl:HasWeapon(state.activeweapon) then
			pl:SelectWeapon(state.activeweapon)
		end

		pl:SetPoints(state.points or 0)
		pl.PointsRemainder = state.pointsremainder or 0
		pl.PointQueue = state.pointqueue or 0

		if state.bloodarmor ~= nil then
			pl:SetBloodArmor(math.min(state.bloodarmor, pl.MaxBloodArmor or state.bloodarmor))
		end

		pl.StowageCaches = state.stowagecaches or 0
		net.Start("zs_stowagecaches")
			net.WriteInt(pl.StowageCaches, 8)
		net.Send(pl)

		if state.nextresupplyuse then
			pl.NextResupplyUse = state.nextresupplyuse
			net.Start("zs_nextresupplyuse")
				net.WriteFloat(pl.NextResupplyUse)
			net.Send(pl)
		end
	end

	self:ApplyReconnectRoundStats(pl, state)

	if state.alive and state.health then
		if state.team == TEAM_HUMAN then
			pl:SetHealth(math.max(1, math.min(state.health, pl:GetMaxHealth())))
		else
			pl:SetHealth(math.max(1, state.health))
		end
	end

	if state.team == TEAM_HUMAN then
		timer.Simple(0, function()
			self:ApplyReconnectWeaponAmmo(pl, state)
		end)
	end

	if not state.alive or not state.pos then return end
	if not util.IsInWorld(state.pos) then return end

	local pos = state.pos
	local ang = state.ang
	local vel = state.velocity
	local human = state.team == TEAM_HUMAN

	local function place()
		if not IsValid(pl) then return end

		pl:SetPos(pos)
		if ang then
			pl:SetEyeAngles(ang)
		end
		pl:SetLocalVelocity(vel or vector_origin)

		if human then
			local tr = util.TraceHull({
				start = pos + Vector(0, 0, 1),
				endpos = pos + Vector(0, 0, 1),
				mins = pl:OBBMins(),
				maxs = pl:OBBMaxs(),
				filter = pl,
				mask = MASK_PLAYERSOLID
			})
			if tr.Hit then
				pl:SetBarricadeGhosting(true, true)
			end
		end

		if state.activeweapon and pl:HasWeapon(state.activeweapon) then
			pl:SelectWeapon(state.activeweapon)
		end

		if human then
			self:ApplyReconnectWeaponAmmo(pl, state)
		end
	end

	place()
	timer.Simple(0, place)
end

hook.Add("WeaponEquip", "ZS.ReconnectAmmo", function(wep, ply)
	local pl = ply
	if not IsValid(pl) and IsValid(wep) then
		pl = wep:GetOwner()
	end
	if not IsValid(pl) or not pl.m_ReconnectAmmoState then return end

	timer.Simple(0, function()
		if IsValid(pl) then
			GAMEMODE:StampReconnectAmmo(pl)
		end
	end)
end)
