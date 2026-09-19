AddCSLuaFile()

local task = {}
task.Name = "Melee_Heavy_In"
task.Priority = 3

function task:CanBeSet(weapon)
	if weapon:GetAnimation("Melee_Heavy_In") == nil or not weapon:CanMelee() then
		return false
	end
	local gm = GAMEMODE or GM
	local owner = weapon:GetOwner()
	if gm and gm.CanHumanStaminaMelee and IsValid(owner) and owner:IsPlayer() then
		return gm:CanHumanStaminaMelee(owner, weapon, true)
	end
	return true
end

function task:OnSet(weapon)
	local anim = weapon:GetAnimation("Melee_Heavy_In")

	local time = weapon:GetAnimLength("Melee_Heavy_In", anim.Length)
	local ct = CurTime()

	weapon:SetNextSecondaryFire(ct + time)
	weapon:SetNextPrimaryFire(ct + time)

	weapon:PlayViewModelAnimation("Melee_Heavy_In")
end

local sp = game.SinglePlayer()

function task:Think(weapon)
	local owner = weapon:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return true end

	if sp and SERVER then weapon:CallOnClient("TickTasks") end

	local vm = weapon:GetViewModel()
	if IsValid(vm) and vm:GetCycle() >= 1 and weapon:GetAnimation("Melee_Heavy_Loop") ~= nil then
		weapon:PlayViewModelAnimation("Melee_Heavy_Loop")
	end

	if owner:KeyDown(IN_ATTACK2) then return false end

	if CurTime() >= weapon:GetNextSecondaryFire() then
		return weapon:TrySetTaskAndCheck("Melee_Heavy") -- heavy
	else
		return weapon:TrySetTaskAndCheck("Melee") -- regular
	end
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