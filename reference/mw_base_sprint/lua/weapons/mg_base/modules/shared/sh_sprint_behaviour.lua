AddCSLuaFile()

function SWEP:IsOwnerMoving()
    return self:GetOwner():KeyDown(IN_FORWARD) 
        || self:GetOwner():KeyDown(IN_BACK) 
        || self:GetOwner():KeyDown(IN_MOVERIGHT) 
        || self:GetOwner():KeyDown(IN_MOVELEFT)
end

function SWEP:CanSprint()
    return true
end
