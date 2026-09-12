AddCSLuaFile()

local task = {}
task.Name = "SprintIn"
task.Flag = "Sprinting"
task.Priority = 6

function task:CanBeSet(weapon)
    return weapon:GetOwner():KeyDown(IN_SPEED)
        && weapon:IsOwnerMoving() 
        && weapon:CanSprint()
		&& weapon:GetOwner():IsOnGround()
        && !weapon:GetOwner():Crouching()
end

function task:CanSuperSprint(weapon)
    local sfr = weapon:GetNextSecondaryFire()
    return weapon:GetAnimation("Super_Sprint_In") && (sfr < 0 || CurTime() < sfr) && weapon:GetOwner():KeyDown(IN_FORWARD)
end

function task:SetSuperSprint(weapon, toSet)
    if toSet then
        weapon:PlayViewModelAnimation("Super_Sprint_In")
        weapon:SetNextSecondaryFire(CurTime() + 3)
        weapon:AddFlag("SuperSprint")
    else
        weapon:PlayViewModelAnimation("Sprint_In")
        weapon:RemoveFlag("SuperSprint")
    end
end

function task:OnSet(weapon)
    weapon:PlayerGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, 0)
    weapon:SetNextSecondaryFire(-1)
    self:SetSuperSprint(weapon, false)

    if weapon:GetOwner():GetInfoNum("mgbase_tacsprint", 1) > 1 && CurTime() < weapon:GetSprintTap() && weapon:GetOwner():KeyDown(IN_FORWARD) then
        self:SetSuperSprint(weapon, true)
    end

    weapon:SetSprintTap(CurTime() + 0.3)
end

function task:Think(weapon)
    if !task:CanBeSet(weapon) then
        weapon:TrySetTask("SprintOut")
        return true
    end

    if self:CanSuperSprint(weapon) && !weapon:HasFlag("SuperSprint") && weapon:GetOwner():GetInfoNum("mgbase_tacsprint", 1) == 1 then
        self:SetSuperSprint(weapon, true)
    elseif !self:CanSuperSprint(weapon) && weapon:HasFlag("SuperSprint") then
        self:SetSuperSprint(weapon, false)
    end

    return false
end

function task:SetupDataTables(weapon)
    weapon:CustomNetworkVar("Flag", "Sprinting")
    weapon:CustomNetworkVar("Flag", "SuperSprint")
    weapon:CustomNetworkVar("Float", "SprintTap")
end

SWEP:RegisterTask(task)