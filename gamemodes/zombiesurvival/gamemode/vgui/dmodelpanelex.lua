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

	local seqs = {"idle", "idle_unholstered", "inspect", "draw", "walk", "Run1", "walk_all", "WalkUnarmed_all", "walk_all_moderate"}
	for _, name in ipairs(seqs) do
		local iSeq = self.Entity:LookupSequence(name)
		if iSeq > 0 then
			self.Entity:ResetSequence(iSeq)
			break
		end
	end
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
