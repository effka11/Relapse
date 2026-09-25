INC_SERVER()

local function RefreshCrateOwners(pl)
	for _, ent in pairs(ents.FindByClass("prop_resupplybox")) do
		if ent:IsValid() and ent:GetObjectOwner() == pl then
			ent:SetObjectOwner(NULL)
		end
	end
end
hook.Add("PlayerDisconnected", "ResupplyBox.PlayerDisconnected", RefreshCrateOwners)
hook.Add("OnPlayerChangedTeam", "ResupplyBox.OnPlayerChangedTeam", RefreshCrateOwners)

function ENT:Initialize()
	self:SetModel("models/ammo/fas2/ammocrate.mdl")
	self:SetModelScale(self.CrateScale or 1, 0)
	self:SetUseType(SIMPLE_USE)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:ApplyOpenCrate()
	self:KillModelCollision()
	self:SpawnCrateHit()

	self:SetMaxObjectHealth(400)
	self:SetObjectHealth(self:GetMaxObjectHealth())

	if GAMEMODE.BeginResupplyClock then
		GAMEMODE:BeginResupplyClock()
	end
end

function ENT:SpawnCrateHit()
	if self.HitBox and self.HitBox:IsValid() then return end

	local box = ents.Create("prop_resupplybox_hit")
	if not box:IsValid() then return end

	box.Crate = self
	box:SetPos(self:GetPos())
	box:SetAngles(self:GetAngles())
	box:Spawn()
	self:DeleteOnRemove(box)
	self.HitBox = box
	box:GhostAllPlayersInMe(5)
end

function ENT:OnRemove()
	if GAMEMODE.StopResupplyClockIfEmpty then
		GAMEMODE:StopResupplyClockIfEmpty()
	end
end

function ENT:KeyValue(key, value)
	key = string.lower(key)
	if key == "maxcratehealth" then
		value = tonumber(value)
		if not value then return end

		self:SetMaxObjectHealth(value)
	elseif key == "cratehealth" then
		value = tonumber(value)
		if not value then return end

		self:SetObjectHealth(value)
	end
end

function ENT:AcceptInput(name, activator, caller, args)
	if name == "setcratehealth" then
		self:KeyValue("cratehealth", args)
		return true
	elseif name == "setmaxcratehealth" then
		self:KeyValue("maxcratehealth", args)
		return true
	end
end

function ENT:SetObjectHealth(health)
	self:SetDTFloat(0, health)
	if health <= 0 and not self.Destroyed then
		self.Destroyed = true

		if self:GetObjectOwner():IsValidLivingHuman() then
			self:GetObjectOwner():SendDeployableLostMessage(self)
		end

		local ent = ents.Create("prop_physics")
		if ent:IsValid() then
			ent:SetModel(self:GetModel())
			ent:SetMaterial(self:GetMaterial())
			ent:SetAngles(self:GetAngles())
			ent:SetPos(self:GetPos())
			ent:SetSkin(self:GetSkin() or 0)
			ent:SetColor(self:GetColor())
			ent:Spawn()
			ent:Fire("break", "", 0)
			ent:Fire("kill", "", 0.1)
		end
	end
end

function ENT:OnTakeDamage(dmginfo)
	if dmginfo:GetDamage() <= 0 then return end

	self:TakePhysicsDamage(dmginfo)

	local attacker = dmginfo:GetAttacker()
	if not (attacker:IsValid() and attacker:IsPlayer() and attacker:Team() == TEAM_HUMAN) then
		self:SetObjectHealth(self:GetObjectHealth() - dmginfo:GetDamage())
		self:ResetLastBarricadeAttacker(attacker, dmginfo)
	end
end

function ENT:AltUse(activator, tr)
	if activator:Crouching() and GAMEMODE.BeginSupplySell and GAMEMODE:BeginSupplySell(activator, self) then
		return
	end
	self:PackUp(activator)
end

function ENT:OnPackedUp(pl)
	pl:GiveEmptyWeapon("weapon_zs_resupplybox")
	pl:GiveAmmo(1, "helicoptergun")

	pl:PushPackedItem(self:GetClass(), self:GetObjectHealth())

	self:Remove()
end

-- The ammo mesh is not solid, so the use line falls through to the floor.
-- Take the crate the crosshair is on, the same way a dropped gun is taken.
function GAMEMODE:ResupplyCrateUnderUse(pl)
	local shoot = pl:GetShootPos()
	local aim = pl:GetAimVector()
	local best, bestDot

	for _, box in ipairs(ents.FindByClass("prop_resupplybox")) do
		if box:IsValid() then
			local point = box:NearestPoint(shoot)
			local delta = point - shoot
			local len = delta:Length()
			if len > 1 and len <= 128 then
				local dot = delta:Dot(aim) / len
				if dot >= 0.45 and (not bestDot or dot > bestDot) then
					local tr = util.TraceLine({
						start = shoot,
						endpos = point,
						mask = MASK_SOLID_BRUSHONLY,
						filter = pl,
					})
					if not tr.Hit then
						best, bestDot = box, dot
					end
				end
			end
		end
	end

	return best
end

function ENT:Think()
	if self.Destroyed then
		self:Remove()
		return
	end

	self:ApplyOpenCrate()
	self:KillModelCollision()
	self:NextThink(CurTime())
	return true
end

function ENT:Use(activator, caller)
	if not activator:IsValid() or not activator:IsPlayer() then return end
	if activator:Team() ~= TEAM_HUMAN or not activator:Alive() then return end
	if activator.RelapseResupplyTick == engine.TickCount() then return end
	activator.RelapseResupplyTick = engine.TickCount()

	if not self:GetObjectOwner():IsValid() then
		self:SetObjectOwner(activator)
		self:GetObjectOwner():SendDeployableClaimedMessage(self)
	end

	local owner = self:GetObjectOwner()
	local resup = activator:Resupply(owner, self)

	if resup then
		self:EmitSound("items/ammocrate_open.wav")
	end
end
