INC_CLIENT()

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.AnimTime = 0.25

function ENT:OnRemove()
	local object = self:GetObject()
	if object:IsValid() then
		object.IgnoreMelee = nil
		object.IgnoreTraces = nil
		object.IgnoreBullets = nil
	end

	local owner = self:GetOwner()
	if owner == MySelf then
		local wep = owner:GetActiveWeapon()
		if wep:IsValid() then
			owner:DrawViewModel(true)
			if wep.PlayViewModelAnimation then
				wep:PlayViewModelAnimation("Draw")
			else
				wep:SendWeaponAnim(ACT_VM_DRAW)
			end
		end
	end

	self.BaseClass.OnRemove(self)
end

function ENT:CreateMoveRotate(cmd)
	if self:GetOwner() ~= MySelf then return end
	if bit.band(cmd:GetButtons(), IN_WALK) == 0 then return end

	local gm = GAMEMODE
	local x, y = gm.InputMouseX, gm.InputMouseY
	local snap = gm.PropRotationSnap
	if snap > 0 then
		x = math.Round(x / snap) * snap
		y = math.Round(y / snap) * snap
	end

	net.Start("zs_rotateang", true)
		net.WriteFloat(x)
		net.WriteFloat(y)
	net.SendToServer()
end

function ENT:Initialize()
	hook.Add("Move", self, self.Move)
	hook.Add("CreateMove", self, self.CreateMoveRotate)

	local object = self:GetObject()
	if object:IsValid() then
		object.IgnoreMelee = true
		object.IgnoreTraces = true
		object.IgnoreBullets = true
	end

	self.Created = CurTime()

	local owner = self:GetOwner()
	if owner == MySelf then
		local wep = owner:GetActiveWeapon()
		if wep:IsValid() then
			owner:DrawViewModel(false)
			if wep.PlayViewModelAnimation then
				wep:PlayViewModelAnimation("Holster")
			else
				wep:SendWeaponAnim(ACT_VM_HOLSTER)
			end
		end
	end

	self.BaseClass.Initialize(self)
end

function ENT:Think()
	local owner = self:GetOwner()
	if owner:IsValid() then
		owner.status_human_holding = self
	end

	if owner ~= MySelf then
		self.BaseClass.Think(self)
		return
	end

	self:SetSequence(2)
	self:SetCycle(0.68 + math.sin(CurTime() * math.pi) * 0.01)

	self.BaseClass.Think(self)
end

function ENT:Draw()
	if self:GetOwner() ~= MySelf or MySelf:ShouldDrawLocalPlayer() then return end

	local pos = EyePos()
	local ang = EyeAngles()

	pos = pos + -16 * (1 - math.Clamp((CurTime() - self.Created) / self.AnimTime, 0, 1) ^ 0.5) * ang:Up()

	self:SetPos(pos)
	self:SetAngles(ang)
	self:DrawModel()
end
