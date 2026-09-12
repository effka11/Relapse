AddCSLuaFile()

local task = {}
task.Name = "SprintOut"
task.Priority = 6

function task:CanBeSet(weapon)
    return weapon:HasFlag("Sprinting")
end

function task:WasSuperSprinting(weapon)
    return weapon:GetAnimation("Super_Sprint_Out") && weapon:GetNextSecondaryFire() > 0 && CurTime() <= weapon:GetNextSecondaryFire()
end

function task:OnSet(weapon)
    weapon:RemoveFlag("Sprinting")
    
    if self:WasSuperSprinting(weapon) then
        weapon:PlayViewModelAnimation("Super_Sprint_Out")
        weapon:SetNextPrimaryFire(CurTime() + weapon:GetAnimLength("Super_Sprint_Out"))
    else
        weapon:PlayViewModelAnimation("Sprint_Out")
        weapon:SetNextPrimaryFire(CurTime() + weapon:GetAnimLength("Sprint_Out"))
    end
end

function task:Think(weapon)
    return CurTime()
end

SWEP:RegisterTask(task)