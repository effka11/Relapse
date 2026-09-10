local PANEL = {}

function PANEL:SetModel(strModelName)
	if RelapseUI and RelapseUI.ClearShopPreviewParts then
		RelapseUI.ClearShopPreviewParts(self)
	end

	if IsValid(self.Entity) then
		self.Entity:Remove()
		self.Entity = nil
	end

	if not ClientsideModel then return end

	self.Entity = ClientsideModel(strModelName, RENDER_GROUP_OPAQUE_ENTITY)
	if not IsValid(self.Entity) then return end

	self.Entity:SetNoDraw(true)
	if self.Entity.SetIK then
		self.Entity:SetIK(false)
	end

	-- Shop preview draws bind-pose meshes. Idle/inspect on MW VMs splits the gun.
	if self.RelapseShopPreview then
		if self.Entity.SetPlaybackRate then
			self.Entity:SetPlaybackRate(0)
		end
		if self.Entity.SetCycle then
			self.Entity:SetCycle(0)
		end
		return
	end

	local seqs = {"idle", "idle_unholstered", "inspect", "draw", "walk", "Run1", "walk_all", "WalkUnarmed_all", "walk_all_moderate"}
	for _, name in ipairs(seqs) do
		local iSeq = self.Entity:LookupSequence(name)
		if iSeq > 0 then
			self.Entity:ResetSequence(iSeq)
			break
		end
	end
end

function PANEL:DrawModel()
	local ent = self.Entity
	if not IsValid(ent) then return end

	local leftx, topy = self:LocalToScreen(0, 0)
	local rightx, bottomy = self:LocalToScreen(self:GetWide(), self:GetTall())
	local curparent = self
	while IsValid(curparent:GetParent()) do
		curparent = curparent:GetParent()
		local x1, y1 = curparent:LocalToScreen(0, 0)
		local x2, y2 = curparent:LocalToScreen(curparent:GetWide(), curparent:GetTall())
		leftx = math.max(leftx, x1)
		topy = math.max(topy, y1)
		rightx = math.min(rightx, x2)
		bottomy = math.min(bottomy, y2)
	end

	render.SetScissorRect(leftx, topy, rightx, bottomy, true)

	if self.RelapseShopPreview and RelapseUI and RelapseUI.DrawShopPreviewGun then
		RelapseUI.DrawShopPreviewGun(self, ent)
	else
		local ret = self:PreDrawModel(ent)
		if ret ~= false then
			ent:DrawModel()
			self:PostDrawModel(ent)
		end
	end

	render.SetScissorRect(0, 0, 0, 0, false)
end

function PANEL:LayoutEntity(ent)
	if not IsValid(ent) then return end

	if self.RelapseShopPreview and RelapseUI and RelapseUI.OrbitShopPreview then
		RelapseUI.OrbitShopPreview(self, ent)
		return
	end

	if self.bAnimated then
		self:RunAnimation()
	end
end

function PANEL:PostDrawModel(ent)
	if self.RelapseShopPreview then return end
	if RelapseUI and RelapseUI.DrawShopPreviewParts then
		RelapseUI.DrawShopPreviewParts(self, ent)
	end
end

function PANEL:OnRemove()
	if RelapseUI and RelapseUI.ClearShopPreviewParts then
		RelapseUI.ClearShopPreviewParts(self)
	end
end

function PANEL:AutoCam()
	if RelapseUI and RelapseUI.FrameModelPanel then
		RelapseUI.FrameModelPanel(self)
		return
	end
	if IsValid(self.Entity) then
		local mins, maxs = self.Entity:GetRenderBounds()
		self:SetCamPos(mins:Distance(maxs) * Vector(0.75, 0.75, 0.5))
		self:SetLookAt((mins + maxs) / 2)
	end
end

vgui.Register("DModelPanelEx", PANEL, "DModelPanel")
