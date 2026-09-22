INC_CLIENT()
include("cl_animations.lua")

ENT.ColorModulation = Color(1, 1, 1)

local function PrepLootEnt(ent)
	if not IsValid(ent) then return end
	if ent.SetIK then
		ent:SetIK(false)
	end
	if ent.SetPlaybackRate then
		ent:SetPlaybackRate(0)
	end
	if ent.SetCycle then
		ent:SetCycle(0)
	end
end

function ENT:RemoveRelapseLootParts()
	local vis = self.RelapseLootVis
	if IsValid(vis) then
		vis:SetParent(NULL)
		vis:Remove()
	end
	self.RelapseLootVis = nil

	local parts = self.RelapseLootParts
	if not parts then return end
	for i = 1, #parts do
		local part = parts[i]
		if IsValid(part) then
			part:SetParent(NULL)
			part:Remove()
		end
	end
	self.RelapseLootParts = nil
end

function ENT:CreateRelapseLootParts(weptab)
	self:RemoveRelapseLootParts()
	if not weptab then return end

	PrepLootEnt(self)
	self:ApplyDroppedBodygroups(weptab)

	local useVis = self:IsMWWeaponType()
	local parent = self

	if useVis then
		local mdl = weptab.WorldModel
		if (not isstring(mdl) or mdl == "") and istable(weptab.RelapsePreviewParts) then
			mdl = weptab.RelapsePreviewParts[1]
		end
		if isstring(mdl) and mdl ~= "" and ClientsideModel then
			local vis = ClientsideModel(mdl, RENDER_GROUP_OPAQUE_ENTITY)
			if IsValid(vis) then
				PrepLootEnt(vis)
				vis:SetParent(self)
				vis:SetLocalAngles(self:DroppedLootLocalAng(weptab))
				vis:SetLocalPos(self:DroppedLootLocalPos(weptab))
				vis:SetNoDraw(true)
				self:ApplyDroppedBodygroups(weptab, vis)
				self.RelapseLootVis = vis
				self.ShowBaseModel = false
				parent = vis
			end
		end
	end

	if not weptab.RelapsePreviewBoneMerge then return end
	local paths = weptab.RelapsePreviewParts
	if not istable(paths) or not ClientsideModel then return end

	if parent.SetupBones then
		parent:SetupBones()
	end

	local extras = {}
	for i = 2, #paths do
		local mdl = paths[i]
		if isstring(mdl) and mdl ~= "" then
			local cs = ClientsideModel(mdl, RENDER_GROUP_OPAQUE_ENTITY)
			if IsValid(cs) then
				PrepLootEnt(cs)
				cs:SetParent(parent)
				cs:AddEffects(EF_BONEMERGE)
				cs:SetNoDraw(true)
				extras[#extras + 1] = cs
			end
		end
	end
	if #extras > 0 then
		self.RelapseLootParts = extras
	end
end

function ENT:DrawRelapseLootParts()
	local vis = self.RelapseLootVis
	if IsValid(vis) then
		if vis.GetParent and vis:GetParent() ~= self then
			vis:SetParent(self)
		end
		vis:SetLocalAngles(self:DroppedLootLocalAng())
		vis:SetLocalPos(self:DroppedLootLocalPos())
		if vis.SetupBones then
			vis:SetupBones()
		end
		vis:DrawModel()
	elseif self.SetupBones then
		self:SetupBones()
	end

	local parts = self.RelapseLootParts
	if not parts then return end
	for i = 1, #parts do
		local part = parts[i]
		if IsValid(part) then
			if part.SetupBones then
				part:SetupBones()
			end
			part:DrawModel()
		end
	end
end

local OldRenderModels = ENT.RenderModels
function ENT:RenderModels(ble, cmod)
	if OldRenderModels then
		OldRenderModels(self, ble, cmod)
	end
	self:DrawRelapseLootParts()
end

local OldRemoveModels = ENT.RemoveModels
function ENT:RemoveModels()
	self:RemoveRelapseLootParts()
	if OldRemoveModels then
		OldRemoveModels(self)
	end
end

function ENT:Think()
	local class = self:GetWeaponType()
	if class ~= self.LastWeaponType then
		self.LastWeaponType = class

		self:RemoveModels()

		local weptab = weapons.Get(class)
		if weptab then
			self.ShowBaseModel = true
			if weptab.ShowWorldModel == false then
				local showmdl = not self:LookupBone("ValveBiped.Bip01_R_Hand") and not weptab.NoDroppedWorldModel
				self.ShowBaseModel = showmdl and true or false
			end
			if self:IsMWWeaponType(class) then
				self.ShowBaseModel = true
			end

			if weptab.WElements then
				self.WElements = table.FullCopy(weptab.WElements)
				self:CreateModels(self.WElements)
			end

			self:CreateRelapseLootParts(weptab)

			self.ColorModulation = weptab.DroppedColorModulation or self.ColorModulation
			self.PropWeapon = true
			self.QualityTier = weptab.QualityTier
			self.Branch = weptab.Branch
			self.BranchData = weptab.Branches and weptab.Branches[self.Branch]
		end
	end
end

function ENT:OnRemove()
	self:RemoveModels()
end
