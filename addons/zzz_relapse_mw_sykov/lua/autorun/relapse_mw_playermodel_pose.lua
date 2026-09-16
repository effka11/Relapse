-- OTS: pack sling keeps the mesh lying in Source space; then stock→shoulder
-- and grip→hands. Never copy viewmodel camera angles (that stood the gun up).

local function DemoteRpgHoldTypes(ht)
	if not istable(ht) then return end
	for name, set in pairs(ht) do
		if name == "RPG" or not istable(set) then continue end
		if set.Idle and set.Idle.Standing == "rpg" then
			set.Idle.Standing = "ar2"
		end
		if set.Aim and set.Aim.Standing == "rpg" then
			set.Aim.Standing = "ar2"
		end
	end
end

local function RevertSlingPitch(wep)
	local off = wep.WorldModelOffsets
	if not off or not off.Angles or not wep.RelapseWMPitch then return end
	local a = off.Angles
	off.Angles = Angle(a.p - wep.RelapseWMPitch, a.y, a.r)
	wep.RelapseWMPitch = nil
end

local function IsPistolWorldModel(wep)
	local off = wep.WorldModelOffsets
	return istable(off) and off.Bone == "tag_pistol_offset"
end

local function PatchSetShouldHoldType(wep)
	if not wep or wep.RelapseHoldTypePatched then return end
	if not isfunction(wep.SetShouldHoldType) then return end
	wep.RelapseHoldTypePatched = true

	wep.SetShouldHoldType = function(self, force)
		if not IsValid(self:GetOwner()) then return end

		-- Pistols stay on MW Idle. Spawn uses SWEP.HoldType "Pistol" → HL2
		-- one-hand until Think runs (often only after sprint).
		local pistol = IsPistolWorldModel(self)
		local ht = "Idle"
		if not pistol then
			if self.GetAimDelta and self:GetAimDelta() > 0 then
				ht = "Aim"
			elseif self.HasFlag and (self:HasFlag("Sprinting") or self:HasFlag("Holstering") or self:HasFlag("Lowered")) then
				ht = "Down"
			end
		end

		local types = self.HoldTypes
		local cur = self.GetCurrentHoldType and self:GetCurrentHoldType()
		local row = types and cur and types[cur] and types[cur][ht]
		local fullht
		if row then
			fullht = self:GetOwner():IsFlagSet(4) and row.Crouching or row.Standing
		elseif pistol then
			fullht = "duel"
		else
			return
		end

		if self.m_RelapseLastHoldType ~= fullht or force then
			self:SetHoldType(fullht)
			self.m_RelapseLastHoldType = fullht
		end
	end

	if isfunction(wep.Deploy) and not wep.RelapseDeployHoldType then
		wep.RelapseDeployHoldType = true
		local oldDeploy = wep.Deploy
		wep.Deploy = function(self, ...)
			self.m_RelapseLastHoldType = nil
			local ret = oldDeploy(self, ...)
			local function apply()
				if IsValid(self) and IsValid(self:GetOwner()) then
					self:SetShouldHoldType(true)
				end
			end
			apply()
			timer.Simple(0, apply)
			return ret
		end
	end
end

local PatchClientDraw = function() end

-- Rifle/SMG tag_sling hold. Pistols stay on MW DrawWorldModel;
-- extras are written into WorldModelOffsets in PrePlayerDraw.
local function ShouldPoseWorldModel(wep)
	if not wep or wep.Unarmed then return false end
	if IsPistolWorldModel(wep) then return false end
	local off = wep.WorldModelOffsets
	return istable(off) and off.Bone and off.Bone ~= ""
end

local function RestoreWorldModelDraw(wep)
	if not wep or (not wep.RelapseWMPoseDraw and not wep.RelapseTPIKCalcView) then return end
	wep.DrawWorldModel = wep.RelapseOldDrawWorldModel
	wep.DrawWorldModelTranslucent = wep.RelapseOldDrawWorldModelTranslucent
	wep.RenderOverride = wep.RelapseOldRenderOverride
	if wep.RelapseOldCalcView then
		wep.CalcView = wep.RelapseOldCalcView
	end
	wep.RelapseTPIKCalcView = nil
	wep.RelapseWMPoseDraw = nil
end

if CLIENT then
	local drawnFrame = {}
	local ApplyPackSling
	local DrawHeldWorldModel
	local DrawAttachments
	local IsDepthPass
	local PistolDrawWorldModel
	local PistolRenderOverride
	local PistolHideMat = CreateMaterial("RelapsePistolHideWM", "UnlitGeneric", {
		["$basetexture"] = "color/white",
		["$alpha"] = "0",
		["$translucent"] = "1",
		["$vertexalpha"] = "1",
		["$color"] = "[0 0 0]"
	})

	local STOCK_BONES = {
		"tag_stock_attach",
		"tag_stock",
		"j_stock",
	}
	local MUZZLE_BONES = {
		"tag_flash",
		"tag_silencer",
		"tag_barrel",
		"j_barrel",
	}

	local function UseTwoPointHold(ply)
		if not IsValid(ply) or ply ~= LocalPlayer() then return false end
		if GAMEMODE and GAMEMODE.RelapseWMPoseActive then return true end
		return ply:ShouldDrawLocalPlayer()
	end

	local function BoneMatrix(ent, name)
		local id = ent:LookupBone(name)
		if id == nil then return end
		return ent:GetBoneMatrix(id)
	end

	local function FirstBone(ent, names)
		for i = 1, #names do
			local m = BoneMatrix(ent, names[i])
			if m then return m end
		end
	end

	local function SafeAngleEx(fwd, up)
		if up and fwd:Cross(up):LengthSqr() > 0.001 then
			return fwd:AngleEx(up)
		end
		return fwd:Angle()
	end

	local function RotationTaking(from, to, fromUp, toUp)
		from = from:GetNormalized()
		to = to:GetNormalized()
		local aFrom = SafeAngleEx(from, fromUp)
		local aTo = SafeAngleEx(to, toUp)
		local _, invAng = WorldToLocal(vector_origin, angle_zero, vector_origin, aFrom)
		local _, composed = LocalToWorld(vector_origin, invAng, vector_origin, aTo)
		return composed
	end

	local function ShoulderPocket(owner)
		local clav = BoneMatrix(owner, "ValveBiped.Bip01_R_Clavicle")
		local upper = BoneMatrix(owner, "ValveBiped.Bip01_R_UpperArm")
		local spine = BoneMatrix(owner, "ValveBiped.Bip01_Spine2")
		if not clav and not upper then return end

		local shoulder
		if clav and upper then
			shoulder = LerpVector(0.65, clav:GetTranslation(), upper:GetTranslation())
		else
			shoulder = (clav or upper):GetTranslation()
		end
		if spine then
			shoulder = LerpVector(0.22, shoulder, spine:GetTranslation())
		end
		shoulder:Sub(Vector(0, 0, 2))
		local yaw = Angle(0, owner:EyeAngles().y, 0)
		shoulder:Add(yaw:Forward() * 3)
		return shoulder
	end

	local function PoseViewmodel(self, owner)
		local vm = self.GetViewModel and self:GetViewModel()
		if not IsValid(vm) or not isfunction(vm.CalcViewModelView) then
			return
		end

		local vpos, vang = Vector(owner:EyePos()), Angle(owner:EyeAngles())
		vm:CalcViewModelView(vpos, vang)
		vm:SetRenderOrigin(vpos)
		vm:SetRenderAngles(vang)
		vm:SetNoDraw(true)
		vm.bRendering = true
		vm:SetupBones()

		if IsValid(vm.m_CHands) then
			vm.m_CHands:SetupBones()
		end
		return vm
	end

	local function HandMatrix(vm, name)
		return BoneMatrix(vm, name)
			or (IsValid(vm.m_CHands) and BoneMatrix(vm.m_CHands, name))
			or (IsValid(vm.m_Rig) and BoneMatrix(vm.m_Rig, name))
	end

	local function WorldMuzzle(ent)
		local m = FirstBone(ent, MUZZLE_BONES)
		if m then return m:GetTranslation() end
		local att = ent:LookupAttachment("muzzle")
		if att and att > 0 then
			local data = ent:GetAttachment(att)
			if data then return data.Pos end
		end
	end

	local function WorldStock(ent)
		local m = FirstBone(ent, STOCK_BONES)
		if m then return m:GetTranslation() end
	end

	local function Orthonormal(fwd, upHint)
		fwd = fwd:GetNormalized()
		local right = fwd:Cross(upHint)
		if right:LengthSqr() < 0.001 then
			right = fwd:Cross(Vector(0, 0, 1))
		end
		if right:LengthSqr() < 0.001 then
			right = fwd:Cross(Vector(0, 1, 0))
		end
		right:Normalize()
		local up = right:Cross(fwd)
		up:Normalize()
		return fwd, right, up
	end

	local function FrameCoords(worldPos, origin, fwd, right, up)
		local d = worldPos - origin
		return d:Dot(fwd), d:Dot(right), d:Dot(up)
	end

	local function HandHoldTarget(ply, left)
		local attName = left and "anim_attachment_LH" or "anim_attachment_RH"
		local boneName = left and "ValveBiped.Bip01_L_Hand" or "ValveBiped.Bip01_R_Hand"
		local id = ply:LookupAttachment(attName)
		if id and id > 0 then
			local data = ply:GetAttachment(id)
			if data then return data.Pos, data.Ang end
		end
		local m = BoneMatrix(ply, boneName)
		if not m then return end
		local pos, ang = Vector(m:GetTranslation()), m:GetAngles()
		-- Wrist bone → palm / fingers (ValveBiped: +X fingers, +Z out the back of the hand).
		pos:Add(ang:Forward() * 3.2)
		pos:Sub(ang:Up() * 1.2)
		return pos, ang
	end

	local function IsWorldTpModel(att)
		return IsValid(att.m_TpModel)
			and not att.DisableWorldModelRender
			and att.ShowOnWorldModel ~= false
	end

	local function EachTpModel(self, fn)
		if not isfunction(self.GetAllAttachmentsInUse) then return end
		for _, att in pairs(self:GetAllAttachmentsInUse()) do
			if IsWorldTpModel(att) then
				fn(att.m_TpModel)
			end
		end
	end

	local function AddPoint(pts, p)
		if p then pts[#pts + 1] = p end
	end

	local function ClosestPoint(origin, pts)
		local best, bestD
		for i = 1, #pts do
			local d = pts[i]:DistToSqr(origin)
			if not bestD or d < bestD then
				best, bestD = pts[i], d
			end
		end
		return best
	end

	local function FarthestPoint(origin, pts)
		local best, bestD
		for i = 1, #pts do
			local d = pts[i]:DistToSqr(origin)
			if not bestD or d > bestD then
				best, bestD = pts[i], d
			end
		end
		return best
	end

	local function AddAABBCorners(pts, mins, maxs)
		if not mins or not maxs then return end
		if mins:DistToSqr(maxs) < 4 then return end
		AddPoint(pts, Vector(mins.x, mins.y, mins.z))
		AddPoint(pts, Vector(mins.x, mins.y, maxs.z))
		AddPoint(pts, Vector(mins.x, maxs.y, mins.z))
		AddPoint(pts, Vector(mins.x, maxs.y, maxs.z))
		AddPoint(pts, Vector(maxs.x, mins.y, mins.z))
		AddPoint(pts, Vector(maxs.x, mins.y, maxs.z))
		AddPoint(pts, Vector(maxs.x, maxs.y, mins.z))
		AddPoint(pts, Vector(maxs.x, maxs.y, maxs.z))
	end

	local function AddBonePoints(ent, pts)
		local n = ent.GetBoneCount and ent:GetBoneCount()
		if not n or n < 1 then return end
		for i = 0, n - 1 do
			local m = ent:GetBoneMatrix(i)
			if m then
				AddPoint(pts, m:GetTranslation())
			end
		end
	end

	local function NamedEnd(self, fn)
		local p = fn(self)
		if p then return p end
		local found
		EachTpModel(self, function(m)
			if found then return end
			found = fn(m)
		end)
		return found
	end

	-- Named muzzle/stock first. All-bones closest-to-shoulder is the grip, not the stock.
	local function GunEnds(self, owner)
		EachTpModel(self, function(m)
			m:SetupBones()
		end)

		local stockPos = NamedEnd(self, WorldStock)
		local muzzlePos = NamedEnd(self, WorldMuzzle)

		if not stockPos or not muzzlePos then
			local pts = {}
			AddBonePoints(self, pts)
			EachTpModel(self, function(m)
				AddBonePoints(m, pts)
				AddAABBCorners(pts, m:WorldSpaceAABB())
			end)
			AddAABBCorners(pts, self:WorldSpaceAABB())
			local spine = BoneMatrix(owner, "ValveBiped.Bip01_Spine2")
			local rear = (spine and spine:GetTranslation()) or owner:WorldSpaceCenter()
			if not stockPos then
				stockPos = ClosestPoint(rear, pts)
			end
			if stockPos and not muzzlePos then
				muzzlePos = FarthestPoint(stockPos, pts)
			end
		end
		if not stockPos or not muzzlePos then return end
		if muzzlePos:DistToSqr(stockPos) < 16 then return end
		return stockPos, muzzlePos
	end

	-- Pivot at the grip (weapon parent / right hand). tag_sling sits on the
	-- stock: rotating that bone keeps the stock high. Entity angles seesaw
	-- stock down and muzzle up without moving the whole gun.
	local function PlaceWorldModelInHands(self, owner)
		local off = self.WorldModelOffsets
		if istable(off) and off.Bone == "tag_pistol_offset" then
			return false
		end

		owner:SetupBones()
		-- Zero first so leftover extras cannot leak into the barrel measure.
		local resetId = istable(off) and off.Bone and self:LookupBone(off.Bone)
		if resetId then
			self:ManipulateBoneAngles(resetId, angle_zero)
			self:ManipulateBonePosition(resetId, vector_origin)
		end
		ApplyPackSling(self, owner)
		self:SetRenderOrigin()
		self:SetRenderAngles()
		self:InvalidateBoneCache()
		self:SetupBones()
		EachTpModel(self, function(m)
			m:SetRenderOrigin()
			m:SetRenderAngles()
			m:InvalidateBoneCache()
			m:SetupBones()
		end)

		local grip = HandHoldTarget(owner, false)
		if not grip then return false end
		local left = HandHoldTarget(owner, true)
		local wantFwd = left and (left - grip) or nil
		if not wantFwd or wantFwd:LengthSqr() < 1 then
			local sh = ShoulderPocket(owner)
			if sh then
				wantFwd = grip - sh
			end
		end
		if not wantFwd or wantFwd:LengthSqr() < 1 then return false end
		wantFwd:Normalize()

		local _, muzzlePos = GunEnds(self, owner)
		if not muzzlePos then
			muzzlePos = NamedEnd(self, WorldMuzzle)
		end
		if not muzzlePos then return false end
		local barrel = muzzlePos - grip
		if barrel:LengthSqr() < 4 then return false end
		barrel:Normalize()

		local rot = RotationTaking(barrel, wantFwd, Vector(0, 0, 1), Vector(0, 0, 1))
		local _, newAng = LocalToWorld(vector_origin, self:GetAngles(), vector_origin, rot)
		self:SetRenderAngles(newAng)
		self:InvalidateBoneCache()
		self:SetupBones()

		-- Grip pivot left the stock. Extra sling twist around the stock lifts only the muzzle.
		if istable(off) and off.Bone and off.Bone ~= "tag_pistol_offset" then
			local boneId = self:LookupBone(off.Bone)
			local stockPos, muz = GunEnds(self, owner)
			local mat = boneId and self:GetBoneMatrix(boneId)
			if boneId and stockPos and muz and mat then
				local along = (muz - stockPos):GetNormalized()
				local axis = along:Cross(Vector(0, 0, 1))
				if axis:LengthSqr() > 1e-6 then
					axis:Normalize()
					local bonePos, boneAng = mat:GetTranslation(), mat:GetAngles()
					local localAxis = WorldToLocal(bonePos + axis, angle_zero, bonePos, boneAng)
					if localAxis:LengthSqr() > 1e-8 then
						localAxis:Normalize()
						local extra = Angle(0, 0, 0)
						extra:RotateAroundAxis(localAxis, 8)
						local packAng = Angle(off.Angles or angle_zero)
						local _, composed = LocalToWorld(vector_origin, extra, vector_origin, packAng)
						self:ManipulateBoneAngles(boneId, composed)
						self.RelapseWMBaseSlingAng = Angle(composed)
						self:InvalidateBoneCache()
						self:SetupBones()
					end
				end
			end
		end
		if not self.RelapseWMBaseSlingAng and istable(off) and off.Angles then
			self.RelapseWMBaseSlingAng = Angle(off.Angles)
		end
		return true
	end

	local SHOULDER_BONE = "ValveBiped.Bip01_R_Clavicle"
	local PALM_BONE = "ValveBiped.Bip01_R_Hand"

	local function GetWMBind(wep)
		local gm = GAMEMODE
		if not gm or not gm.RelapseWMBinds then return end
		local class = wep.GetClass and wep:GetClass()
		return class and gm.RelapseWMBinds[class]
	end

	local function SlingInfo(self)
		local off = self.WorldModelOffsets
		if not istable(off) or not off.Bone then return end
		local id = self:LookupBone(off.Bone)
		if id == nil then return end
		return id, off
	end

	local function ParentFrame(self, boneId)
		local parent = self:GetBoneParent(boneId)
		if parent and parent >= 0 then
			local pm = self:GetBoneMatrix(parent)
			if pm then
				return pm:GetTranslation(), pm:GetAngles()
			end
		end
		return self:GetPos(), self:GetAngles()
	end

	-- MW WM lives on tag_sling. SetRenderOrigin does not move that mesh.
	local function SlingRotateWorld(self, worldAxis, degrees)
		if not worldAxis or worldAxis:LengthSqr() < 1e-8 then return false end
		if degrees * degrees < 1e-4 then return false end
		local boneId, off = SlingInfo(self)
		if not boneId then return false end
		local mat = self:GetBoneMatrix(boneId)
		if not mat then return false end
		local bonePos, boneAng = mat:GetTranslation(), mat:GetAngles()
		worldAxis = worldAxis:GetNormalized()
		local localAxis = WorldToLocal(bonePos + worldAxis, angle_zero, bonePos, boneAng)
		if localAxis:LengthSqr() < 1e-8 then return false end
		localAxis:Normalize()
		local extra = Angle(0, 0, 0)
		extra:RotateAroundAxis(localAxis, degrees)
		local current = self:GetManipulateBoneAngles(boneId)
		if current.p == 0 and current.y == 0 and current.r == 0 then
			current = Angle(off.Angles or angle_zero)
		end
		local _, composed = LocalToWorld(vector_origin, extra, vector_origin, current)
		self:ManipulateBoneAngles(boneId, composed)
		return true
	end

	local function SlingTranslateWorld(self, worldDelta)
		if not worldDelta or worldDelta:LengthSqr() < 1e-8 then return false end
		local boneId, off = SlingInfo(self)
		if not boneId then return false end
		local origin, oang = ParentFrame(self, boneId)
		local localDelta = WorldToLocal(origin + worldDelta, angle_zero, origin, oang)
		local current = Vector(self:GetManipulateBonePosition(boneId))
		if current:LengthSqr() < 1e-10 then
			current = Vector(off.Pos or vector_origin)
		end
		self:ManipulateBonePosition(boneId, current + localDelta)
		return true
	end

	local function PoseTpModels(self, oldPos, oldAng, newPos, newAng)
		EachTpModel(self, function(m)
			local lp, la = WorldToLocal(m:GetPos(), m:GetAngles(), oldPos, oldAng)
			local np, na = LocalToWorld(lp, la, newPos, newAng)
			m:SetRenderOrigin(np)
			m:SetRenderAngles(na)
			m:InvalidateBoneCache()
			m:SetupBones()
		end)
	end

	local function ClearTpModels(self)
		EachTpModel(self, function(m)
			m:SetRenderOrigin()
			m:SetRenderAngles()
		end)
	end

	local function AlignBarrel(self, haveStock, haveMuzzle, wantFwd)
		local barrel = haveMuzzle - haveStock
		if barrel:LengthSqr() < 4 then return false end
		barrel:Normalize()
		wantFwd = wantFwd:GetNormalized()
		local axis = barrel:Cross(wantFwd)
		local deg = math.deg(math.acos(math.Clamp(barrel:Dot(wantFwd), -1, 1)))
		if axis:LengthSqr() < 1e-8 or deg < 0.05 then return true end
		axis:Normalize()
		return SlingRotateWorld(self, axis, deg)
	end

	-- Stock on clavicle, muzzle on palm. Extra Pos/Ang are barrel-frame after.
	-- Applied on tag_sling: that is the mesh other players see.
	local function PlaceByBind(self, owner, bind)
		if not IsValid(owner) or not bind then return false end

		owner:SetupBones()
		local sm = BoneMatrix(owner, SHOULDER_BONE)
		local pm = BoneMatrix(owner, PALM_BONE)
		if not sm or not pm then return false end

		local wantStock = LocalToWorld(bind.Stock or vector_origin, angle_zero, sm:GetTranslation(), sm:GetAngles())
		local wantMuzzle = LocalToWorld(bind.Palm or vector_origin, angle_zero, pm:GetTranslation(), pm:GetAngles())
		local wantFwd = wantMuzzle - wantStock
		if wantFwd:LengthSqr() < 1 then return false end
		wantFwd:Normalize()

		ApplyPackSling(self, owner)
		self:SetRenderOrigin()
		self:SetRenderAngles()
		self:InvalidateBoneCache()
		self:SetupBones()

		local haveStock, haveMuzzle = GunEnds(self, owner)
		if not haveStock or not haveMuzzle then return false end
		if (haveMuzzle - haveStock):LengthSqr() < 4 then return false end

		local oldPos, oldAng = self:GetPos(), self:GetAngles()
		local usedSling = false

		if AlignBarrel(self, haveStock, haveMuzzle, wantFwd) then
			usedSling = SlingInfo(self) and true or usedSling
			self:InvalidateBoneCache()
			self:SetupBones()
			haveStock, haveMuzzle = GunEnds(self, owner)
			if not haveStock or not haveMuzzle then return false end
		end

		if SlingTranslateWorld(self, wantStock - haveStock) then
			usedSling = true
			self:InvalidateBoneCache()
			self:SetupBones()
			haveStock, haveMuzzle = GunEnds(self, owner)
			if not haveStock or not haveMuzzle then return false end
		end

		local extraAng = bind.Ang or angle_zero
		if extraAng.p ~= 0 or extraAng.y ~= 0 or extraAng.r ~= 0 then
			local fwd, right, up = Orthonormal(haveMuzzle - haveStock, Vector(0, 0, 1))
			if extraAng.p ~= 0 then SlingRotateWorld(self, right, extraAng.p) end
			if extraAng.y ~= 0 then SlingRotateWorld(self, up, extraAng.y) end
			if extraAng.r ~= 0 then SlingRotateWorld(self, fwd, extraAng.r) end
			usedSling = SlingInfo(self) and true or usedSling
			self:InvalidateBoneCache()
			self:SetupBones()
			haveStock, haveMuzzle = GunEnds(self, owner)
			if not haveStock or not haveMuzzle then return false end
		end

		local extraPos = bind.Pos or vector_origin
		if extraPos:LengthSqr() > 0 then
			local fwd, right, up = Orthonormal(haveMuzzle - haveStock, Vector(0, 0, 1))
			if SlingTranslateWorld(self, fwd * extraPos.x + right * extraPos.y + up * extraPos.z) then
				usedSling = true
			end
			self:InvalidateBoneCache()
			self:SetupBones()
			haveStock, haveMuzzle = GunEnds(self, owner)
		end

		if not usedSling then
			haveStock, haveMuzzle = GunEnds(self, owner)
			if not haveStock or not haveMuzzle then return false end
			local barrel = haveMuzzle - haveStock
			if barrel:LengthSqr() < 4 then return false end
			local rot = RotationTaking(barrel, wantFwd, Vector(0, 0, 1), Vector(0, 0, 1))
			local newPos = LocalToWorld(oldPos - haveStock, angle_zero, wantStock, rot)
			local _, newAng = LocalToWorld(vector_origin, oldAng, vector_origin, rot)
			if extraAng.p ~= 0 or extraAng.y ~= 0 or extraAng.r ~= 0 then
				local fwd, right, up = Orthonormal(wantFwd, Vector(0, 0, 1))
				local extra = Angle(0, 0, 0)
				extra:RotateAroundAxis(right, extraAng.p)
				extra:RotateAroundAxis(up, extraAng.y)
				extra:RotateAroundAxis(fwd, extraAng.r)
				newPos = LocalToWorld(newPos - wantStock, angle_zero, wantStock, extra)
				_, newAng = LocalToWorld(vector_origin, newAng, vector_origin, extra)
			end
			if extraPos:LengthSqr() > 0 then
				local fwd, right, up = Orthonormal(wantFwd, Vector(0, 0, 1))
				newPos = newPos + fwd * extraPos.x + right * extraPos.y + up * extraPos.z
			end
			self:SetRenderOrigin(newPos)
			self:SetRenderAngles(newAng)
			self:InvalidateBoneCache()
			self:SetupBones()
			PoseTpModels(self, oldPos, oldAng, newPos, newAng)
		end

		return true
	end

	local function BoneLocalDelta(owner, boneName, localVec)
		if not localVec or localVec:LengthSqr() < 1e-8 then return end
		local m = BoneMatrix(owner, boneName)
		if not m then return end
		local origin, ang = m:GetTranslation(), m:GetAngles()
		return LocalToWorld(localVec, angle_zero, origin, ang) - origin
	end

	local function ComposeWorldAxis(baseAng, bonePos, boneAng, worldAxis, degrees)
		if not worldAxis or degrees * degrees < 1e-8 then return baseAng end
		worldAxis = worldAxis:GetNormalized()
		local localAxis = WorldToLocal(bonePos + worldAxis, angle_zero, bonePos, boneAng)
		if localAxis:LengthSqr() < 1e-8 then return baseAng end
		localAxis:Normalize()
		local extra = Angle(0, 0, 0)
		extra:RotateAroundAxis(localAxis, degrees)
		local _, composed = LocalToWorld(vector_origin, extra, vector_origin, baseAng)
		return composed
	end

	-- Sewn MW hold extra (barrel frame). Editor sliders are deltas on top.
	local MW_HOLD_POS = Vector(6, -0.5, 0)
	local MW_HOLD_ANG = Angle(0, 0, 0)
	local CLASS_HOLD = {
		mg_m1911 = {
			Pos = Vector(-0.81, -0.97, 0.38),
			Ang = Angle(8.84, 0.22, -14.41)
		},
		mg_357 = {
			Pos = Vector(-1.00, -1.41, 0.50),
			Ang = Angle(5.25, -1.25, -9.50)
		}
	}

	local function CombineBindExtra(owner, bind, withBase, wep)
		local extraPos = withBase and Vector(MW_HOLD_POS) or Vector(0, 0, 0)
		local extraAng = withBase and Angle(MW_HOLD_ANG) or Angle(0, 0, 0)
		local class = wep and (wep.ClassName or (isfunction(wep.GetClass) and wep:GetClass()))
		local sewn = class and CLASS_HOLD[class]
		if sewn then
			extraPos:Add(sewn.Pos)
			extraAng.p = extraAng.p + sewn.Ang.p
			extraAng.y = extraAng.y + sewn.Ang.y
			extraAng.r = extraAng.r + sewn.Ang.r
		end
		local dStock, dPalm
		if bind then
			if bind.Pos then extraPos:Add(bind.Pos) end
			if bind.Ang then
				extraAng.p = extraAng.p + bind.Ang.p
				extraAng.y = extraAng.y + bind.Ang.y
				extraAng.r = extraAng.r + bind.Ang.r
			end
			dStock = BoneLocalDelta(owner, SHOULDER_BONE, bind.Stock)
			dPalm = BoneLocalDelta(owner, PALM_BONE, bind.Palm)
		end
		return extraPos, extraAng, dStock, dPalm
	end

	local function BarrelAxes(self, owner, fallbackAng)
		local stock, muzzle = GunEnds(self, owner)
		if stock and muzzle and (muzzle - stock):LengthSqr() >= 1 then
			return Orthonormal(muzzle - stock, Vector(0, 0, 1))
		end
		fallbackAng = fallbackAng or angle_zero
		return fallbackAng:Forward(), fallbackAng:Right(), fallbackAng:Up()
	end

	-- pack Pos/Ang plus editor extra, in the offset-bone's local space.
	-- boneEnt is the entity that has WorldModelOffsets.Bone (weapon unless given).
	local function OffsetWithBind(self, owner, bind, withBase, boneEnt)
		boneEnt = boneEnt or self
		local off = self.WorldModelOffsets
		local packPos = Vector(off and off.Pos or vector_origin)
		local packAng = self.RelapseWMBaseSlingAng and Angle(self.RelapseWMBaseSlingAng)
			or Angle(off and off.Angles or angle_zero)
		if not istable(off) or not off.Bone then
			return packPos, packAng
		end
		local boneId = boneEnt:LookupBone(off.Bone)
		if boneId == nil then
			return packPos, packAng
		end

		local extraPos, extraAng, dStock, dPalm = CombineBindExtra(owner, bind, withBase, self)
		local hasAng = extraAng.p ~= 0 or extraAng.y ~= 0 or extraAng.r ~= 0
		local hasPos = extraPos:LengthSqr() > 0 or dStock or dPalm
		if not hasAng and not hasPos then
			return packPos, packAng
		end

		local nfwd, right, up = BarrelAxes(self, owner, packAng)
		local worldDelta = Vector(0, 0, 0)
		if extraPos:LengthSqr() > 0 then
			worldDelta:Add(nfwd * extraPos.x + right * extraPos.y + up * extraPos.z)
		end
		if dStock then worldDelta:Add(dStock) end
		if dPalm then worldDelta:Add(dPalm) end

		if worldDelta:LengthSqr() > 0 then
			local origin, oang = ParentFrame(boneEnt, boneId)
			local localDelta = WorldToLocal(origin + worldDelta, angle_zero, origin, oang)
			packPos:Add(localDelta)
		end

		if hasAng then
			local mat = boneEnt:GetBoneMatrix(boneId)
			if mat then
				local bonePos, boneAng = mat:GetTranslation(), mat:GetAngles()
				if extraAng.p ~= 0 then
					packAng = ComposeWorldAxis(packAng, bonePos, boneAng, right, extraAng.p)
				end
				if extraAng.y ~= 0 then
					packAng = ComposeWorldAxis(packAng, bonePos, boneAng, up, extraAng.y)
				end
				if extraAng.r ~= 0 then
					packAng = ComposeWorldAxis(packAng, bonePos, boneAng, nfwd, extraAng.r)
				end
			end
		end
		return packPos, packAng
	end

	-- Absolute extras on the offset bone. Rotation goes here, not SetRenderAngles:
	-- the MW mesh lives on tag_sling / tag_pistol_offset.
	local function ApplyHoldExtra(self, owner, bind, withBase)
		local extraPos, extraAng, dStock, dPalm = CombineBindExtra(owner, bind, withBase, self)
		local hasAng = extraAng.p ~= 0 or extraAng.y ~= 0 or extraAng.r ~= 0
		local hasPos = extraPos:LengthSqr() > 0 or dStock or dPalm
		if not hasAng and not hasPos then return end

		local boneId, off = SlingInfo(self)
		if not boneId or not off then return end

		local pos, ang = OffsetWithBind(self, owner, bind, withBase)
		if hasAng then
			self:ManipulateBoneAngles(boneId, ang)
		end
		if hasPos then
			self:ManipulateBonePosition(boneId, pos)
		end
		self:InvalidateBoneCache()
		self:SetupBones()
		EachTpModel(self, function(m)
			m:InvalidateBoneCache()
			m:SetupBones()
		end)
	end

	local function ResetPistolOwnerHold(owner)
		if not IsValid(owner) then return end
		local bone = owner.RelapsePistolHoldBone
		if bone == nil then return end
		owner:ManipulateBoneAngles(bone, angle_zero)
		owner:ManipulateBonePosition(bone, vector_origin)
		owner.RelapsePistolHoldBone = nil
	end

	-- Stored pack hold. Live WorldModelOffsets may already have extras.
	local function PistolPackOffsets(self)
		local class = self.GetClass and self:GetClass()
		local stored = class and weapons.GetStored(class)
		local src = stored and stored.WorldModelOffsets
		if not istable(src) then src = self.WorldModelOffsets end
		return Vector(src and src.Pos or vector_origin), Angle(src and src.Angles or angle_zero)
	end

	-- Colt pipeline: extras are composed in pack pose (barrel axes as
	-- sewn). PoseTpModels copies only that extra onto slide/barrel.
	local function ApplyPistolBindToOffsets(self, owner)
		local off = self.WorldModelOffsets
		if not istable(off) or not IsValid(owner) then return end

		local packPos, packAng = PistolPackOffsets(self)
		off.Pos = Vector(packPos)
		off.Angles = Angle(packAng)
		self.RelapseWMBaseSlingAng = nil

		local hold = owner:LookupBone(off.Bone)
		if hold ~= nil then
			owner:ManipulateBoneAngles(hold, packAng)
			owner:ManipulateBonePosition(hold, packPos)
			owner.RelapsePistolHoldBone = hold
		else
			ResetPistolOwnerHold(owner)
		end

		local wepBone = off.Bone and self:LookupBone(off.Bone)
		if wepBone == nil then return end

		ClearTpModels(self)
		self:ManipulateBonePosition(wepBone, packPos)
		self:ManipulateBoneAngles(wepBone, packAng)
		owner:SetupBones()
		self:InvalidateBoneCache()
		self:SetupBones()
		EachTpModel(self, function(m)
			m:InvalidateBoneCache()
			m:SetupBones()
		end)

		local oldMat = self:GetBoneMatrix(wepBone)
		local bind = GetWMBind(self)
		local pos, ang = OffsetWithBind(self, owner, bind, false, self)
		self:ManipulateBonePosition(wepBone, pos)
		self:ManipulateBoneAngles(wepBone, ang)
		self:InvalidateBoneCache()
		self:SetupBones()
		local newMat = self:GetBoneMatrix(wepBone)
		if oldMat and newMat then
			PoseTpModels(self,
				oldMat:GetTranslation(), oldMat:GetAngles(),
				newMat:GetTranslation(), newMat:GetAngles())
		end
	end

	-- Pistol WM: GMod calls DrawWorldModel then RenderOverride. Empty DWM
	-- drops the gun out of the pipeline. DWM DrawModel is the bare w_m1911
	-- on the hand; hide that pass. Pack RenderOverride is the assembled gun.
	-- Keepalive DrawModel must not run our RO wrapper (drawnFrame would eat
	-- the later assemble). Point instance RO at pack while pack draws.
	local mwPistolRO

	local function CaptureMWPistolRO(wep)
		if isfunction(mwPistolRO) then return mwPistolRO end
		local base = weapons.GetStored("mg_base")
		local fn = base and base.RenderOverride
		if isfunction(fn) and fn ~= DrawHeldWorldModel and fn ~= PistolRenderOverride then
			mwPistolRO = fn
			return mwPistolRO
		end
		if wep then
			fn = wep.RelapseOldRenderOverride
			if isfunction(fn) and fn ~= DrawHeldWorldModel and fn ~= PistolRenderOverride then
				mwPistolRO = fn
			end
		end
		return mwPistolRO
	end

	local function PistolFallbackAssemble(self, flags)
		if IsValid(self.SpawnEffect) then
			self.SpawnEffect.ParentEntity = nil
		end
		local owner = self:GetOwner()
		if IsValid(owner) then
			ApplyPistolBindToOffsets(self, owner)
		else
			self:SetupBones()
		end
		EachTpModel(self, function(m)
			m:InvalidateBoneCache()
			m:SetupBones()
		end)
		self:DrawModel(flags)
		DrawAttachments(self, flags)
	end

	PistolDrawWorldModel = function(self, flags)
		local blend = render.GetBlend()
		local ro = self.RenderOverride
		self.RenderOverride = nil
		render.SetBlend(0)
		render.OverrideColorWriteEnable(true, false)
		render.OverrideDepthEnable(true, false)
		render.MaterialOverride(PistolHideMat)
		self:DrawModel(flags)
		render.MaterialOverride()
		render.OverrideColorWriteEnable(false)
		render.OverrideDepthEnable(false)
		render.SetBlend(blend)
		self.RenderOverride = ro
	end

	PistolRenderOverride = function(self, flags)
		if not IsDepthPass(flags) then
			local idx = self:EntIndex()
			if drawnFrame[idx] == FrameNumber() then return end
			drawnFrame[idx] = FrameNumber()
		end
		render.SetBlend(1)
		render.OverrideColorWriteEnable(false)
		render.OverrideDepthEnable(false)
		render.MaterialOverride()
		-- Pack RO would write WorldModelOffsets onto the weapon and eat extras.
		-- Draw the assemble here: receiver extras + posed slide/mag.
		self.RenderOverride = nil
		PistolFallbackAssemble(self, flags)
		self.RenderOverride = PistolRenderOverride
	end

	local function WrapPistolDraw(wep)
		wep:SetNoDraw(false)
		if not isfunction(mwPistolRO) then
			local live = wep.RenderOverride
			if isfunction(live)
				and live ~= PistolRenderOverride
				and live ~= PistolDrawWorldModel
				and live ~= PistolFallbackAssemble
				and live ~= DrawHeldWorldModel then
				mwPistolRO = live
			end
		end
		CaptureMWPistolRO(wep)
		if wep.RelapseOldRenderOverride == DrawHeldWorldModel then
			wep.RelapseOldRenderOverride = nil
		end
		wep.DrawWorldModel = PistolDrawWorldModel
		wep.DrawWorldModelTranslucent = PistolDrawWorldModel
		wep.RenderOverride = PistolRenderOverride
		wep.RelapsePistolDraw = true
	end

	function RelapseMWWeaponEnds(wep, owner)
		if not IsValid(wep) then return end
		if IsPistolWorldModel(wep) then
			if IsValid(owner) then owner:SetupBones() end
			wep:SetupBones()
			return GunEnds(wep, owner)
		end
		if wep.RelapseWMLastStock and wep.RelapseWMLastMuzzle then
			return wep.RelapseWMLastStock, wep.RelapseWMLastMuzzle
		end
		if IsValid(owner) then
			owner:SetupBones()
		end
		wep:SetupBones()
		return GunEnds(wep, owner)
	end

	function RelapseMWSeedWMBind(wep, owner)
		if GAMEMODE and GAMEMODE.RelapseWMBindCopy then
			return GAMEMODE:RelapseWMBindCopy()
		end
		return {
			Pos = Vector(0, 0, 0),
			Ang = Angle(0, 0, 0),
			Stock = Vector(0, 0, 0),
			Palm = Vector(0, 0, 0)
		}
	end

	DrawAttachments = function(self, flags)
		if not isfunction(self.GetAllAttachmentsInUse) then return end
		for _, att in pairs(self:GetAllAttachmentsInUse()) do
			if IsWorldTpModel(att) and #att.m_TpModel:GetChildren() <= 0 then
				att.m_TpModel:DrawModel(flags)
				if att.WorldModelRender then
					att:WorldModelRender(self)
				elseif not att.RenderOverride and att.Render then
					att:Render(self, att.m_TpModel)
				end
			end
		end
	end

	ApplyPackSling = function(self, owner)
		local off = self.WorldModelOffsets
		if not istable(off) or not off.Bone then return end
		if off.Bone == "tag_pistol_offset" then return end
		local bone = self:LookupBone(off.Bone)
		if bone == nil then return end
		if IsValid(owner) then
			local pos = Vector(off.Pos or vector_origin)
			local ang = Angle(off.Angles or angle_zero)
			self:ManipulateBoneAngles(bone, ang)
			self:ManipulateBonePosition(bone, pos)
		else
			self:ManipulateBoneAngles(bone, angle_zero)
			self:ManipulateBonePosition(bone, vector_origin)
		end
	end

	IsDepthPass = function(flags)
		flags = flags or 0
		return bit.band(flags, STUDIO_SHADOWDEPTHTEXTURE) ~= 0
			or bit.band(flags, STUDIO_SSAODEPTHTEXTURE) ~= 0
	end

	DrawHeldWorldModel = function(self, flags)
		if not IsDepthPass(flags) then
			local idx = self:EntIndex()
			if drawnFrame[idx] == FrameNumber() then return end
			drawnFrame[idx] = FrameNumber()
		end

		if IsValid(self.SpawnEffect) then
			self.SpawnEffect.ParentEntity = nil
		end

		local owner = self:GetOwner()
		local bind = IsValid(owner) and GetWMBind(self)
		if IsValid(owner) and PlaceWorldModelInHands(self, owner) then
			ApplyHoldExtra(self, owner, bind, true)
			self:DrawModel(flags)
			DrawAttachments(self, flags)
		else
			self.RelapseWMBaseSlingAng = nil
			ApplyPackSling(self, owner)
			self:SetupBones()
			ApplyHoldExtra(self, owner, bind, false)
			self:DrawModel(flags)
			DrawAttachments(self, flags)
		end
		if IsValid(owner) then
			local s, m = GunEnds(self, owner)
			if s then self.RelapseWMLastStock = Vector(s) end
			if m then self.RelapseWMLastMuzzle = Vector(m) end
		end
		self:SetRenderOrigin()
		self:SetRenderAngles()
		ClearTpModels(self)
	end

	PatchClientDraw = function(wep)
		if not ShouldPoseWorldModel(wep) then
			RestoreWorldModelDraw(wep)
			return
		end
		if not wep.RelapseWMPoseDraw then
			wep.RelapseOldDrawWorldModel = wep.DrawWorldModel
			wep.RelapseOldDrawWorldModelTranslucent = wep.DrawWorldModelTranslucent
			wep.RelapseOldRenderOverride = wep.RenderOverride
		end
		wep.RelapseWMPoseDraw = true
		wep.DrawWorldModel = DrawHeldWorldModel
		wep.DrawWorldModelTranslucent = DrawHeldWorldModel
		wep.RenderOverride = DrawHeldWorldModel

		if isfunction(wep.CalcView) then
			if not wep.RelapseOldCalcView then
				wep.RelapseOldCalcView = wep.CalcView
			end
			local oldCalc = wep.RelapseOldCalcView
			wep.RelapseTPIKCalcView = true
			wep.CalcView = function(self, ply, pos, ang, fov)
				if UseTwoPointHold(ply) then
					local vm = self.GetViewModel and self:GetViewModel()
					if IsValid(vm) then
						vm:SetNoDraw(true)
					end
					-- Keep OTS camera. oldCalc would replace it with first-person ADS.
					local d = self.GetAimDelta and self:GetAimDelta() or 0
					if d > 0 then
						local mul = (self.Zoom and self.Zoom.FovMultiplier) or 0.72
						if mul > 0.85 then mul = 0.72 end
						fov = Lerp(d, fov, fov * mul)
					end
					return pos, ang, fov
				end
				return oldCalc(self, ply, pos, ang, fov)
			end
		end
	end

	hook.Add("PrePlayerDraw", "RelapseMWPlayermodelPose", function(ply)
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep.Unarmed then
			ResetPistolOwnerHold(ply)
			return
		end
		if IsPistolWorldModel(wep) then
			if isfunction(wep.SetShouldHoldType) then
				wep:SetShouldHoldType()
			end
			WrapPistolDraw(wep)
			ApplyPistolBindToOffsets(wep, ply)
			if ply == LocalPlayer() then
				local vm = wep.GetViewModel and wep:GetViewModel()
				if IsValid(vm) then
					vm:SetNoDraw(UseTwoPointHold(ply))
				end
			end
			return
		end
		ResetPistolOwnerHold(ply)
		if wep.DrawWorldModel ~= DrawHeldWorldModel then
			PatchClientDraw(wep)
		end
	end)
end

local function PatchShared(wep)
	if not istable(wep) or wep.Unarmed then return end
	RevertSlingPitch(wep)
	DemoteRpgHoldTypes(wep.HoldTypes)
	PatchSetShouldHoldType(wep)
	if ShouldPoseWorldModel(wep) then
		PatchClientDraw(wep)
	else
		RestoreWorldModelDraw(wep)
	end
end

local function PatchStored()
	-- Do not patch stored mg_base: pistols inherit its RenderOverride.
	local list = weapons.GetList()
	if not list then return end
	for i = 1, #list do
		local class = list[i].ClassName
		if class and class ~= "mg_base" and weapons.IsBasedOn(class, "mg_base") then
			PatchShared(weapons.GetStored(class))
		end
	end
end

local function PatchLive()
	for _, ply in ipairs(player.GetAll()) do
		for _, wep in ipairs(ply:GetWeapons()) do
			if IsValid(wep) then
				PatchShared(wep)
				if wep.SetShouldHoldType and wep == ply:GetActiveWeapon() and IsValid(wep:GetOwner()) then
					wep:SetShouldHoldType(true)
				end
			end
		end
	end
end

local function Apply()
	PatchStored()
	PatchLive()
end

hook.Add("Initialize", "RelapseMWPlayermodelPose", Apply)
hook.Add("InitPostEntity", "RelapseMWPlayermodelPose", Apply)
hook.Add("OnReloaded", "RelapseMWPlayermodelPose", Apply)

-- SWEP:Think is frozen during draw; sprint was the first tick that applied
-- Idle. Drive the pistol hold from the player so spawn matches the screenshot.
hook.Add("PlayerPostThink", "RelapseMWPistolHold", function(ply)
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep.Unarmed or not IsPistolWorldModel(wep) then return end
	if not wep.RelapseHoldTypePatched then
		PatchSetShouldHoldType(wep)
	end
	if isfunction(wep.SetShouldHoldType) then
		wep:SetShouldHoldType()
	end
end)

if SERVER then
	hook.Add("WeaponEquip", "RelapseMWPistolHold", function(wep, ply)
		if not IsValid(wep) then return end
		PatchShared(wep)
		timer.Simple(0, function()
			if not IsValid(wep) or not IsValid(ply) then return end
			if ply:GetActiveWeapon() ~= wep then return end
			if isfunction(wep.SetShouldHoldType) then
				wep:SetShouldHoldType(true)
			end
		end)
	end)
end
