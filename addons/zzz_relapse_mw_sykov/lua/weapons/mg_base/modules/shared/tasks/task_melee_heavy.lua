AddCSLuaFile()
require("mw_input")

local task = table.Copy((SWEP or weapons.GetStored("mg_base")):GetTaskByName("Melee"))
task.Name = "Melee_Heavy"

function task:CanBeSet(weapon)
	if weapon:GetAnimation("Melee_Heavy") == nil then return false end
	if not weapon:GetAnimation("Melee_Heavy_Hit") then return false end
	if not weapon:CanMelee() then return false end
	local gm = GAMEMODE or GM
	local owner = weapon:GetOwner()
	if gm and gm.CanHumanStaminaMelee and IsValid(owner) and owner:IsPlayer() then
		return gm:CanHumanStaminaMelee(owner, weapon, true)
	end
	return true
end

function task:OnSet(weapon)
	local gm = GAMEMODE or GM
	local owner = weapon:GetOwner()
	if gm and gm.ConsumeHumanStaminaMelee and IsValid(owner) and owner:IsPlayer() then
		if not gm:ConsumeHumanStaminaMelee(owner, weapon, true) then
			weapon:SetNextPrimaryFire(CurTime() + 0.12)
			weapon:SetNextSecondaryFire(CurTime() + 0.12)
			return
		end
	end

	weapon:PlayerGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, weapon.HoldTypes[weapon:GetCurrentHoldType()].Melee)

	local meleeAnim = weapon:GetAnimation("Melee_Heavy")
	local meleeHitAnim = weapon:GetAnimation("Melee_Heavy_Hit")

	local tr = {}
	tr.start = owner:EyePos()
	tr.endpos = tr.start + owner:EyeAngles():Forward() * meleeAnim.Range
	tr.filter = owner
	tr.maxs = Vector(meleeAnim.Size, meleeAnim.Size, meleeAnim.Size)
	tr.mins = tr.maxs * -1
	tr.mask = MASK_SHOT_HULL

	local bTrace = util.TraceHull(tr)

	local timeMul = 1
	if gm and gm.GetMeleeAttackDelayMul then
		timeMul = gm:GetMeleeAttackDelayMul(owner, weapon)
	end

	if bTrace and bTrace.Hit then
		weapon:SetNextPrimaryFire(CurTime() + weapon:GetAnimLength("Melee_Heavy_Hit", meleeHitAnim.Length) * timeMul)
		weapon:PlayViewModelAnimation("Melee_Heavy_Hit")
	else
		weapon:SetNextPrimaryFire(CurTime() + weapon:GetAnimLength("Melee_Heavy", meleeAnim.Length) * timeMul)
		weapon:PlayViewModelAnimation("Melee_Heavy")
	end

	weapon:SetNextSecondaryFire(weapon:GetNextPrimaryFire())

	if owner:IsNPC() then
		timer.Create("mwb_melee_" .. owner:EntIndex() .. "_" .. weapon:EntIndex(), (meleeAnim.Delay or 0) * timeMul, 0, function()
			if IsValid(weapon) then
				self:DelayedMeleeHit(weapon)
			end
		end)

		return -- SWEP:Think doesn't run for NPCs so tasks don't tick as well
	end

	weapon:SetDelayedMeleeAttackTime(CurTime() + (meleeAnim.Delay or 0) * timeMul)
	weapon:AddFlag("DelayedMeleeAttack")
end

function task:DelayedMeleeHit(weapon)
	weapon:RemoveFlag("DelayedMeleeAttack")

	local meleeAnim = weapon:GetAnimation("Melee")
	local meleeHitAnim = weapon:GetAnimation("Melee_Hit")

	local owner = weapon:GetOwner()

	owner:FireBullets({
		Src = owner:EyePos(),
		Dir = owner:EyeAngles():Forward(),
		Distance = meleeAnim.Range,
		HullSize = meleeAnim.Size,
		Tracer = 0,
		Callback = function(attacker, btr, dmgInfo)
			dmgInfo:SetDamage(meleeHitAnim.Damage)
			dmgInfo:SetInflictor(weapon)
			dmgInfo:SetAttacker(owner)
			dmgInfo:SetDamagePosition(btr.HitPos)
			dmgInfo:SetDamageForce(owner:EyeAngles():Forward() * (meleeHitAnim.DamageForce or (meleeHitAnim.Damage * 100)))
			dmgInfo:SetDamageType(meleeHitAnim.DamageType or (DMG_CLUB + DMG_ALWAYSGIB))

			if btr.Hit and weapon.MeleeWorldMatTypes and weapon.MeleeSounds then
				local hitType = weapon.MeleeWorldMatTypes[util.GetSurfacePropName(btr.SurfaceProps):lower()] or weapon.MeleeWorldMatTypes[btr.MatType] or "Cement"

				if hitType and weapon.MeleeSounds[hitType] then
					weapon:EmitSound(weapon.MeleeSounds[hitType])
				end
			end
		end
	})
end

function task:Think(weapon)
	weapon:SetCone(weapon:GetConeMax())

	-- if CurTime() > weapon:GetNextSecondaryFire() and mw_input.IsBindPressed(weapon:GetOwner(), "melee") then
	-- 	self:OnSet(weapon)
	-- end

	if weapon:HasFlag("DelayedMeleeAttack") and CurTime() >= weapon:GetDelayedMeleeAttackTime() then
		self:DelayedMeleeHit(weapon)
	end

	return CurTime() > weapon:GetNextPrimaryFire()
end

if not SWEP then
	weapons.GetStored("mg_base"):RegisterTask(task)

	for _, ent in ipairs(ents.GetAll()) do
		if ent:IsWeapon() and ent:IsScripted() and weapons.IsBasedOn(ent:GetClass(), "mg_base") then
			ent:RegisterTask(task)
		end
	end

	return
end

SWEP:RegisterTask(task)