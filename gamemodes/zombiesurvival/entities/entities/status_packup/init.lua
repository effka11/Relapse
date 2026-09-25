INC_SERVER()

function ENT:PlayerSet(pPlayer, bExists)
	pPlayer:EmitSound("items/ammocrate_open.wav")

	pPlayer.PackUp = pPlayer

	if self:GetStartTime() == 0 then
		self:SetStartTime(CurTime())
	end
end

function ENT:Think()
	if self.Removing then return end

	local packer = self:GetOwner()
	local owner = packer
	local pack = self:GetPackUpEntity()

	if pack:IsValid() then
		local eyepos = owner:EyePos()
		local aimvec = owner:GetAimVector()
		local point = pack:NearestPoint(eyepos)
		local dist = point:DistToSqr(eyepos)
		local traced = owner:CompensatedMeleeTrace(64, 4, nil, nil, nil, true).Entity
		-- Resupply is packed as the model, but the swing hits its solid box.
		local onPack = traced == pack or (traced:IsValid() and traced.Crate == pack)
		if onPack or ((dist <= 64 or (point - eyepos):GetNormalized():Dot(aimvec) >= 0.75) and dist <= 4096 and WorldVisible(eyepos, point)) then
			if not self:GetNotOwner() and pack.GetObjectOwner then
				local packowner = pack:GetObjectOwner()
				if packowner:IsValid() and packowner:Team() == TEAM_HUMAN and packowner ~= packer and not gamemode.Call("PlayerIsAdmin", packer) then
					self:SetNotOwner(true)
				end
			end

			if self:GetSupplySell() and not packer:Crouching() then
				packer:EmitSound("items/medshotno1.wav")
				self.Removing = true
				self:Remove()
				self:NextThink(CurTime())
				return true
			end

			if CurTime() >= self:GetEndTime() then
				if self:GetSupplySell() then
					local packer = self:GetOwner()
					if GAMEMODE.CompleteSupplySell and GAMEMODE:CompleteSupplySell(packer, pack) then
						packer:EmitSound("items/ammocrate_close.wav")
					else
						packer:EmitSound("items/medshotno1.wav")
					end
					self.Removing = true
					self:Remove()
					self:NextThink(CurTime())
					return true
				end

				if self:GetNotOwner() then
					local count = 0
					for _, ent in pairs(ents.FindByClass("status_packup")) do
						if ent:GetPackUpEntity() == pack then
							count = count + 1
						end
					end

					if count < self.PackUpOverride then
						self:NextThink(CurTime())
						return true
					end

					if pack.GetObjectOwner then
						local objowner = pack:GetObjectOwner()
						if objowner:IsValid() and objowner:Team() == TEAM_HUMAN and objowner:IsValid() then
							owner = objowner
						end
					end
				end

				if pack.OnPackedUp and not pack:OnPackedUp(owner) then
					owner:EmitSound("items/ammocrate_close.wav")
					self.Removing = true

					gamemode.Call("ObjectPackedUp", pack, packer, owner)

					self:Remove()
				end
			end
		else
			owner:EmitSound("items/medshotno1.wav")

			self:Remove()
			self.Removing = true
		end
	else
		owner:EmitSound("items/medshotno1.wav")

		self:Remove()
		self.Removing = true
	end

	self:NextThink(CurTime())
	return true
end
