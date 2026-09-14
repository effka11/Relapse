AddCSLuaFile()
require("mw_input")

local task = table.Copy((SWEP or weapons.GetStored("mg_base")):GetTaskByName("Melee"))

function task:OnSet(weapon)
	weapon:PlayerGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, weapon.HoldTypes[weapon:GetCurrentHoldType()].Melee)

	local meleeAnim = weapon:GetAnimation("Melee")
	local meleeHitAnim = weapon:GetAnimation("Melee_Hit")

	local owner = weapon:GetOwner()

	local tr = {}
	tr.start = owner:EyePos()
	tr.endpos = tr.start + owner:EyeAngles():Forward() * meleeAnim.Range
	tr.filter = owner
	tr.maxs = Vector(meleeAnim.Size, meleeAnim.Size, meleeAnim.Size)
	tr.mins = tr.maxs * -1
	tr.mask = MASK_SHOT_HULL

	local bTrace = util.TraceHull(tr)

	if bTrace and bTrace.Hit then
		weapon:SetNextPrimaryFire(CurTime() + weapon:GetAnimLength("Melee_Hit", meleeHitAnim.Length))
		weapon:PlayViewModelAnimation("Melee_Hit")
	else
		weapon:SetNextPrimaryFire(CurTime() + weapon:GetAnimLength("Melee", meleeAnim.Length))
		weapon:PlayViewModelAnimation("Melee")
	end

	weapon:SetNextSecondaryFire(weapon:GetNextPrimaryFire())

	if owner:IsNPC() then
		timer.Create("mwb_melee_" .. owner:EntIndex() .. "_" .. weapon:EntIndex(), meleeAnim.Delay or 0, 0, function()
			if IsValid(weapon) then
				self:DelayedMeleeHit(weapon)
			end
		end)

		return -- SWEP:Think doesn't run for NPCs so tasks don't tick as well
	end

	weapon:SetDelayedMeleeAttackTime(CurTime() + (meleeAnim.Delay or 0))
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

	if CurTime() > weapon:GetNextSecondaryFire() and mw_input.IsBindPressed(weapon:GetOwner(), "melee") then
		self:OnSet(weapon)
	end

	if weapon:HasFlag("DelayedMeleeAttack") and CurTime() >= weapon:GetDelayedMeleeAttackTime() then
		self:DelayedMeleeHit(weapon)
	end

	return CurTime() > weapon:GetNextPrimaryFire()
end

function task:SetupDataTables(weapon)
	weapon:CustomNetworkVar("Flag", "Meleeing")

	weapon:CustomNetworkVar("Flag", "DelayedMeleeAttack")
	weapon:CustomNetworkVar("Float", "DelayedMeleeAttackTime")
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