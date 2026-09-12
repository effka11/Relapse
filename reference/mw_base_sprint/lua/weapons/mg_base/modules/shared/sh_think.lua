AddCSLuaFile()

function SWEP:Think()
    --fallback initialize
    if (!self.m_bInitialized) then
        self:Initialize()
    end

    self:LoadSpawnPreset()
    
    if (CLIENT && game.SinglePlayer()) then
        --removing garrys hack
        --we already have server-first everything anyways, might as well save more perf on client
        return
    end
    
    self:TickTasks()

    --cone
    self:SetCone(math.max(self:GetCone() - (FrameTime() * 5), self:GetConeMin()))

    --auto reload
    if (self:GetOwner():GetInfoNum("mgbase_autoreload", 1)) >= 1 then
        if (self:Clip1() <= 0 || (self:HasFlag("UsingUnderbarrel") && self:Clip2() <= 0)) then
            self:Reload()
        end
    end

    --priority will auto sort these tasks. just spam the gun until it can do them
    self:TrySetTask("SprintIn")
    self:TrySetTask("Rechamber") --think runs before primaryattack, so it will always play before next attack even if same priority as primaryfire

    self:AimLogic()
    self:TacStanceLogic()
    self:BipodLogic()

    --ladder
    if (self:GetOwner():GetMoveType() == MOVETYPE_LADDER || self:GetOwner():WaterLevel() == 3) then
        self:AddFlag("OnLadder")
        self:Holster()
    else
        if (self:HasFlag("OnLadder")) then
            self:Deploy()
        end
    end

    if (self:HasFlag("UsingUnderbarrel")) then
        if ((self.Secondary.Automatic && self:GetOwner():KeyDown(IN_ATTACK)) || self:GetOwner():KeyPressed(IN_ATTACK)) then
            self:UnderbarrelAttack()
        end
    end

    --holdtypes
    --new meme marine way
    self:SetShouldHoldType()

    --reverb
    self:CreateAndResumeReverbJob()
    self:TriggerLogic()
end