INC_SERVER()

local function RefreshOwners(pl)
	for _, ent in pairs(ents.FindByClass("prop_aloe")) do
		if ent:IsValid() and ent:GetObjectOwner() == pl then
			ent:SetObjectOwner(NULL)
		end
	end
end
hook.Add("PlayerDisconnected", "Aloe.PlayerDisconnected", RefreshOwners)
hook.Add("OnPlayerChangedTeam", "Aloe.OnPlayerChangedTeam", RefreshOwners)

function ENT:Initialize()
	self:SetModel(self.EmptyModel)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:CollisionRulesChanged()

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:EnableMotion(false)
	end

	self:SetMaxObjectHealth(self.MaxHealth)
	self:SetObjectHealth(self:GetMaxObjectHealth())
	self:NextThink(CurTime())
end

function ENT:ApplyGrown(grown)
	grown = grown and true or false
	if self:GetGrown() == grown then
		return
	end

	self:SetGrown(grown)
end

function ENT:BeginGrow(remaining, grown)
	if grown then
		self:ApplyGrown(true)
		self:SetGrowEnd(0)
		return
	end

	local dur = tonumber(remaining)
	if dur and dur <= 0 then
		self:ApplyGrown(true)
		self:SetGrowEnd(0)
		return
	end
	if not dur then
		dur = (GAMEMODE and GAMEMODE.AloeGrowTime) or 180
	end

	self:ApplyGrown(false)
	self:SetGrowEnd(CurTime() + dur)
end

function ENT:OnTakeDamage(dmginfo)
	self:TakePhysicsDamage(dmginfo)
	if dmginfo:GetDamage() <= 0 then return end

	local attacker = dmginfo:GetAttacker()
	if not (attacker:IsValid() and attacker:IsPlayer() and attacker:Team() == TEAM_HUMAN) then
		self:ResetLastBarricadeAttacker(attacker, dmginfo)
		self:SetObjectHealth(self:GetObjectHealth() - dmginfo:GetDamage())
	end
end

function ENT:Harvest(pl)
	if not self:GetGrown() then return false end
	if not (pl:IsValid() and pl:IsPlayer() and pl:Team() == TEAM_HUMAN and pl:Alive()) then
		return false
	end

	local owner = self:GetObjectOwner()
	if not (owner:IsValid() and owner == pl) then
		return false
	end

	local maxadd = (GAMEMODE and GAMEMODE.AloeUseMaxHealth) or 3
	pl.AloeMaxHealthAdd = (pl.AloeMaxHealthAdd or 0) + maxadd
	pl:SetMaxHealth((pl:GetMaxHealth() or 100) + maxadd)
	pl:SetHealth(math.min(pl:GetMaxHealth(), pl:Health() + maxadd))

	self:BeginGrow()
	self:EmitSound("items/medshot4.wav", 70, 100)
	return true
end

function ENT:Use(activator, caller)
	if not (activator:IsValid() and activator:IsPlayer() and activator:Team() == TEAM_HUMAN and activator:Alive()) then
		return
	end

	if self:Harvest(activator) then
		return
	end

	if not self:GetObjectOwner():IsValid() then
		self:SetObjectOwner(activator)
		self:GetObjectOwner():SendDeployableClaimedMessage(self)
	end
end

function ENT:AltUse(activator, tr)
	self:PackUp(activator)
end

function ENT:OnPackedUp(pl)
	pl:GiveEmptyWeapon(self.SWEP)
	pl:GiveAmmo(1, "aloe")

	local grown = self:GetGrown()
	local rem = grown and 0 or self:GetGrowRemaining()
	pl:PushPackedItem(self:GetClass(), self:GetObjectHealth(), rem, grown and 1 or 0)

	self:Remove()
end

function ENT:Think()
	if self.Destroyed then
		local owner = self:GetObjectOwner()
		if owner:IsValidLivingHuman() then
			owner:SendDeployableLostMessage(self)
		end

		local ent = ents.Create("prop_physics")
		if ent:IsValid() then
			ent:SetModel(self:GetModel())
			ent:SetAngles(self:GetAngles())
			ent:SetPos(self:GetPos())
			ent:SetSkin(self:GetSkin() or 0)
			ent:SetColor(self:GetColor())
			ent:Spawn()
			ent:Fire("break", "", 0)
			ent:Fire("kill", "", 0.1)
		end

		self:Remove()
		return
	end

	if not self:GetGrown() and self:GetGrowEnd() > 0 and CurTime() >= self:GetGrowEnd() then
		self:ApplyGrown(true)
		self:SetGrowEnd(0)
		self:EmitSound("physics/surfaces/sand_impact_bullet3.wav", 70, 100)
	end

	self:NextThink(CurTime() + 0.2)
	return true
end

local function AloeAuraThink()
	local gm = GAMEMODE
	if not gm then
		return
	end

	local radius = gm.AloeAuraRadius or 192
	local r2 = radius * radius
	local plants = {}
	for _, ent in ipairs(ents.FindByClass("prop_aloe")) do
		if ent:IsValid() and ent.GetGrown and ent:GetGrown() then
			plants[#plants + 1] = ent
		end
	end
	if #plants == 0 then
		for _, pl in ipairs(team.GetPlayers(TEAM_HUMAN)) do
			if pl:IsValid() then
				pl.AloeRegenNext = nil
			end
		end
		return
	end

	local now = CurTime()
	local interval = gm.AloeRegenInterval or 5
	local heal = gm.AloeRegenHeal or 1

	for _, pl in ipairs(team.GetPlayers(TEAM_HUMAN)) do
		if not (pl:IsValid() and pl:Alive()) then
			pl.AloeRegenNext = nil
			continue
		end

		local origin = pl:WorldSpaceCenter()
		local n = 0
		for i = 1, #plants do
			if origin:DistToSqr(plants[i]:WorldSpaceCenter()) <= r2 then
				n = n + 1
			end
		end
		if n <= 0 then
			pl.AloeRegenNext = nil
			continue
		end

		local gap = math.max(0.05, interval / n)
		local nxt = pl.AloeRegenNext
		if not nxt or nxt > now + gap then
			pl.AloeRegenNext = now + gap
			nxt = pl.AloeRegenNext
		end
		if now < nxt then
			continue
		end

		local maxhp = pl:GetMaxHealth()
		if pl.IsSkillActive and SKILL_D_FRAIL and pl:IsSkillActive(SKILL_D_FRAIL) then
			maxhp = math.floor(maxhp * 0.25)
		end
		if pl:Health() < maxhp then
			pl:SetHealth(math.min(maxhp, pl:Health() + heal))
		end

		pl.AloeRegenNext = now + gap
	end
end
hook.Add("Think", "Relapse.AloeAura", AloeAuraThink)
