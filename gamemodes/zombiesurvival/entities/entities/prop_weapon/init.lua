INC_SERVER()
AddCSLuaFile("cl_animations.lua")

ENT.CleanupPriority = 1

function ENT:Initialize()
	self.ObjHealth = 200
	self.IgnorePickupCount = self.IgnorePickupCount or false
	self.Forced = self.Forced or false
	self.NeverRemove = self.NeverRemove or false
	self.IgnoreUse = self.IgnoreUse or false
	self.Empty = self.Empty or false
	self.Restrained = self.Restrained or false

	local class = self:GetWeaponType()
	local weptab = class ~= "" and weapons.Get(class) or nil
	self:SetupPhysics(weptab, class)

	self:SetUseType(SIMPLE_USE)

	self:ItemCreated()
end

function ENT:SetupPhysics(weptab, class)
	class = class or (weptab and (weptab.ClassName or weptab.Class)) or self:GetWeaponType()
	-- MW world models have no collision mesh. VPHYSICS on that mdl voids the loot.
	-- PhysicsInitBox only sticks if movetype is already VPHYSICS, before the box.
	local mw = self:IsMWWeaponType(class)
	local useBox = mw or (weptab and weptab.BoxPhysicsMax)
	if useBox then
		local mins, maxs = self:DroppedWeaponBox(weptab, class)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(mins, maxs)
		self:PhysicsInitBox(mins, maxs)
		self:SetCollisionBounds(mins, maxs)
	elseif weptab then
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	local phys = self:GetPhysicsObject()
	if phys and phys:IsValid() then
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)

		phys:SetMaterial("material")
		phys:EnableMotion(not self.Restrained)
		phys:EnableGravity(true)
		phys:SetMass(45)
		phys:Wake()
	elseif useBox and not self.RelapsePhysRetry then
		self.RelapsePhysRetry = true
		local ent = self
		timer.Simple(0, function()
			if IsValid(ent) then
				ent:SetupPhysics(weptab, class)
			end
		end)
	end

	-- SetWeaponType rebuilds physics after Initialize. PhysicsInit clears use.
	self:SetUseType(SIMPLE_USE)
	if self.CollisionRulesChanged then
		self:CollisionRulesChanged()
	end
end

function ENT:ApplyDroppedLie(yaw)
	local ang = self:DropLieAngles(yaw)
	self:SetAngles(ang)
	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:SetAngles(ang)
		phys:EnableMotion(not self.Restrained)
		phys:EnableGravity(true)
		phys:Wake()
	end
end

function ENT:MakeInvItemConvert(class)
	local ent = ents.Create("prop_invitem")
	if ent:IsValid() then
		if not ent:SetInventoryItemType("trinket_"..string.sub(class, 13)) then return end

		ent:Spawn()
		ent:SetPos(self:GetPos())
		ent:SetAngles(self:GetAngles())

		self:RemoveNextFrame()
	end
end

function ENT:SetClip1(ammo)
	self.m_Clip1 = tonumber(ammo) or self:GetClip1()
end

function ENT:GetClip1()
	return self.m_Clip1 or 0
end

function ENT:SetClip2(ammo)
	self.m_Clip2 = tonumber(ammo) or self:GetClip2()
end

function ENT:GetClip2()
	return self.m_Clip2 or 0
end

function ENT:SetShouldRemoveAmmo(bool)
	self.m_DontRemoveAmmo = not bool
end

function ENT:GetShouldRemoveAmmo()
	return not self.m_DontRemoveAmmo
end

function ENT:Use(activator, caller)
	if self.IgnoreUse then return end
	self:GiveToActivator(activator, caller)
end

function ENT:GiveToActivator(activator, caller)
	if self.Removing then return end
	if  not activator:IsPlayer()
		or not activator:Alive()
		or activator:Team() ~= TEAM_HUMAN
		or self.Removing
		or (activator:KeyDown(GAMEMODE.UtilityKey) and not self.Forced)
		or self.NoPickupsTime and CurTime() < self.NoPickupsTime and self.NoPickupsOwner ~= activator then

		self:Input("OnPickupFailed", activator)
		return
	end

	local weptype = self:GetWeaponType()
	if not weptype then
		self:Input("OnPickupFailed", activator)
		return
	end

	if activator:HasWeapon(weptype) and (self.Forced or not GAMEMODE.MaxWeaponPickups) then
		local weptab = weapons.Get(weptype)
		if not (weptab and weptab.NoPickupIfHas) then
			local wep = activator:GetWeapon(weptype)
			if wep:IsValid() then
				local primary = wep:ValidPrimaryAmmo()
				local secondary = wep:ValidSecondaryAmmo()

				if weptab.AmmoIfHas and self.PlacedInMap then
					self:SetClip1(1)
					self:SetClip2(1)
				end

				if primary then activator:GiveAmmo(self:GetClip1(), primary) self:SetClip1(0) end
				if secondary then activator:GiveAmmo(self:GetClip2(), secondary) self:SetClip2(0) end

				if weptab.AmmoIfHas then
					self:Input("OnPickupPassed", activator)
					if not self.NeverRemove then self:RemoveNextFrame() end
				end
				return
			end
		end
	end

	if not self.PlacedInMap or not GAMEMODE.MaxWeaponPickups or (activator.WeaponPickups or 0) < GAMEMODE.MaxWeaponPickups or team.NumPlayers(TEAM_HUMAN) <= 1 then
		local wep = (self.PlacedInMap and not self.Empty) and activator:Give(weptype) or activator:GiveEmptyWeapon(weptype)
		if wep and wep:IsValid() and wep:GetOwner():IsValid() then
			if self:GetShouldRemoveAmmo() then
				wep:SetClip1(self:GetClip1())
				wep:SetClip2(self:GetClip2())
			end

			if self.PlacedInMap and not self.IgnorePickupCount then
				activator.WeaponPickups = (activator.WeaponPickups or 0) + 1
			end
			self:Input("OnPickupPassed", activator)
			if not self.NeverRemove then self:RemoveNextFrame() end
		else
			self:Input("OnPickupFailed", activator)
		end
	else
		self:Input("OnPickupFailed", activator)
		activator:CenterNotify(COLOR_RED, translate.ClientGet(activator, "you_decide_to_leave_some"))
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	if key == "weapontype" then
		self:SetWeaponType(value)
	elseif key == "ignorepickupcount" then
		self.IgnorePickupCount = tonumber(value) == 1
	elseif key == "neverremove" then
		self.NeverRemove = tonumber(value) == 1
	elseif key == "ignoreuse" then
		self.IgnoreUse = tonumber(value) == 1
	elseif key == "empty" then
		self.Empty = tonumber(value) == 1
	elseif key == "restrained" then
		self.Restrained = tonumber(value) == 1
	elseif string.sub(key, 1, 2) == "on" then
		self:AddOnOutput(key, value)
	end
end

function ENT:AcceptInput(name, activator, caller, arg)
	name = string.lower(name)
	if name == "givetoactivator" then
		self.Forced = true
		self:GiveToActivator(activator,caller)
		return true
	elseif name == "setneverremove" then
		self.NeverRemove = tonumber(arg) == 1
		return true
	elseif name == "setignorepickupcount" then
		self.IgnorePickupCount = tonumber(arg) == 1
		return true
	elseif name == "setignoreuse" then
		self.IgnoreUse = tonumber(arg) == 1
		return true
	elseif name == "setweapontype" then
		self:SetWeaponType(arg)
		return true
	elseif name == "setempty" then
		self.Empty = tonumber(arg) == 1
	elseif string.sub(name, 1, 2) == "on" then
		self:FireOutput(name, activator, caller, args)
	end
end

function ENT:OnTakeDamage(dmginfo)
	if dmginfo:GetDamage() <= 0 then return end

	if self.NeverRemove then return end
	self:TakePhysicsDamage(dmginfo)

	local attacker = dmginfo:GetAttacker()
	if attacker:IsValid() and attacker:IsPlayer() and attacker:Team() == TEAM_HUMAN then return end

	self.ObjHealth = self.ObjHealth - dmginfo:GetDamage()
	if self.ObjHealth <= 0 then
		self:RemoveNextFrame()
	end
end

-- Eye trace often hits the floor under the bone-merged mag. E still takes the gun
-- when the crosshair is on the loot and nothing solid is in the way.
hook.Add("KeyPress", "RelapsePropWeaponUse", function(pl, key)
	if key ~= IN_USE then return end
	if not IsValid(pl) or not pl:Alive() or pl:Team() ~= TEAM_HUMAN then return end
	if pl.IsHolding and pl:IsHolding() then return end

	local shoot = pl:GetShootPos()
	local aim = pl:GetAimVector()
	local best, bestDot
	for _, ent in ipairs(ents.FindInSphere(shoot, 96)) do
		if ent:GetClass() == "prop_weapon" and not ent.Removing and not ent.IgnoreUse and ent.GiveToActivator then
			local center = ent:GetPos()
			local delta = center - shoot
			local len = delta:Length()
			if len > 1 and len < 96 then
				local dot = delta:Dot(aim) / len
				if dot > 0.8 then
					local tr = util.TraceLine({
						start = shoot,
						endpos = center,
						mask = MASK_SOLID_BRUSHONLY,
						filter = pl,
					})
					if not tr.Hit and (not bestDot or dot > bestDot) then
						best, bestDot = ent, dot
					end
				end
			end
		end
	end
	if best then
		best:GiveToActivator(pl, pl)
	end
end)
