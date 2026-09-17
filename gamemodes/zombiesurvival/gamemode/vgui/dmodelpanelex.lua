RelapseUI = RelapseUI or {}

-- SetAlpha on a parent fades 2D. DModelPanel draws 3D with its own GetAlpha
-- (always 255) and playermodels ignore render.SetBlend. Fade blit uses an RT;
-- once opaque, draw to the framebuffer so MSAA stays.
function RelapseUI.PanelFadeAlpha(pnl)
	local a = 1
	while IsValid(pnl) do
		a = a * (pnl:GetAlpha() / 255)
		if a <= 0 then
			return 0
		end
		pnl = pnl:GetParent()
	end
	return a
end

local FadeRT = {}

local RT_POINT = bit.bor(1, 4, 8, 256)

local function EnsureFadeRT(w, h)
	w = math.max(1, math.floor(w))
	h = math.max(1, math.floor(h))
	local key = w .. "x" .. h
	local slot = FadeRT[key]
	if slot then
		return slot.rt, slot.mat, w, h
	end

	local rt = GetRenderTargetEx(
		"RelapseModelFade" .. key,
		w,
		h,
		RT_SIZE_NO_CHANGE,
		MATERIAL_RT_DEPTH_SEPARATE,
		RT_POINT,
		0,
		IMAGE_FORMAT_RGBA8888
	)
	if not rt then
		rt = GetRenderTarget("RelapseModelFade" .. key, w, h)
	end
	local mat = CreateMaterial("RelapseModelFadeMat" .. key, "UnlitGeneric", {
		["$basetexture"] = rt:GetName(),
		["$translucent"] = "1",
		["$vertexalpha"] = "1",
		["$vertexcolor"] = "1",
		["$nolod"] = "1",
		["$ignorez"] = "1"
	})
	mat:SetTexture("$basetexture", rt)
	slot = {rt = rt, mat = mat}
	FadeRT[key] = slot
	return rt, mat, w, h
end

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
	if self.RelapsePlayerPreview then
		seqs = {"idle_all_01", "idle_subtle", "menu_walk", "pose_standing_02", "idle", "walk_all", "WalkUnarmed_all"}
	end
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

	if not self._RelapsePaintRT then
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
	end

	if self.RelapseShopPreview and RelapseUI and RelapseUI.DrawShopPreviewGun then
		RelapseUI.DrawShopPreviewGun(self, ent)
	else
		local ret = self:PreDrawModel(ent)
		if ret ~= false then
			ent:DrawModel()
			self:PostDrawModel(ent)
		end
	end

	if not self._RelapsePaintRT then
		render.SetScissorRect(0, 0, 0, 0, false)
	end
end

local function PaintModel3D(self, x, y, w, h)
	local ent = self.Entity
	local ang = self.aLookAngle
	if not ang then
		ang = (self.vLookatPos - self.vCamPos):Angle()
	end

	cam.Start3D(self.vCamPos, ang, self.fFOV, x, y, w, h, 5, self.FarZ or 4096)
	render.SuppressEngineLighting(true)
	render.SetLightingOrigin(ent:GetPos())
	local amb = self.colAmbientLight or color_white
	render.ResetModelLighting(amb.r / 255, amb.g / 255, amb.b / 255)
	local col = self.colColor or color_white
	render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
	render.SetBlend(1)
	local lights = self.DirectionalLight
	if lights then
		for i = 0, 5 do
			local lc = lights[i]
			if lc then
				render.SetModelLighting(i, lc.r / 255, lc.g / 255, lc.b / 255)
			end
		end
	end
	self:DrawModel()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.SuppressEngineLighting(false)
	cam.End3D()
end

function PANEL:Paint(w, h)
	if not IsValid(self.Entity) then return end

	self:LayoutEntity(self.Entity)

	local fade = RelapseUI.PanelFadeAlpha(self)
	if fade <= 0 then
		self.LastPaint = RealTime()
		return
	end

	-- Opaque window fade: draw to the framebuffer so MSAA stays.
	-- Static card previews blit through an RT so 3D does not punch the glass.
	if fade >= 1 and not self.RelapsePlayerPreviewStatic then
		local x, y = self:LocalToScreen(0, 0)
		PaintModel3D(self, x, y, w, h)
		self.LastPaint = RealTime()
		return
	end

	local rt, mat, rtW, rtH = EnsureFadeRT(w, h)
	render.PushRenderTarget(rt)
	render.OverrideAlphaWriteEnable(true, true)
	render.Clear(0, 0, 0, 0, true, true)
	self._RelapsePaintRT = true
	PaintModel3D(self, 0, 0, w, h)
	self._RelapsePaintRT = nil
	render.OverrideAlphaWriteEnable(false)
	render.PopRenderTarget()

	-- 3D ignores parent SetAlpha. Blit as 2D with the window fade, and pin
	-- the surface multiplier so PushRenderTarget cannot double-apply it.
	local prevMul = surface.GetAlphaMultiplier and surface.GetAlphaMultiplier() or 1
	if surface.SetAlphaMultiplier then
		surface.SetAlphaMultiplier(1)
	end
	surface.SetDrawColor(255, 255, 255, math.floor(fade * 255 + 0.5))
	surface.SetMaterial(mat)
	local u, v = w / rtW, h / rtH
	surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, u, v)
	if surface.SetAlphaMultiplier then
		surface.SetAlphaMultiplier(prevMul)
	end

	self.LastPaint = RealTime()
end

function PANEL:LayoutEntity(ent)
	if not IsValid(ent) then return end

	if self.RelapseShopPreview and RelapseUI and RelapseUI.OrbitShopPreview then
		RelapseUI.OrbitShopPreview(self, ent)
		return
	end

	if self.RelapsePlayerPreview and RelapseUI and RelapseUI.OrbitPlayerPreview then
		RelapseUI.OrbitPlayerPreview(self, ent)
		if self.bAnimated then
			self:RunAnimation()
		end
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

function PANEL:OnMousePressed(mc)
	if RelapseUI and RelapseUI.PlayerPreviewDragPress and RelapseUI.PlayerPreviewDragPress(self, mc) then
		return
	end
	if self.BaseClass and self.BaseClass.OnMousePressed then
		self.BaseClass.OnMousePressed(self, mc)
	end
end

function PANEL:OnMouseReleased(mc)
	if RelapseUI and RelapseUI.PlayerPreviewDragRelease and RelapseUI.PlayerPreviewDragRelease(self) then
		return
	end
	if self.BaseClass and self.BaseClass.OnMouseReleased then
		self.BaseClass.OnMouseReleased(self, mc)
	end
end

function PANEL:OnRemove()
	if self.RelapseOrbitDragging then
		self:MouseCapture(false)
		self.RelapseOrbitDragging = false
	end
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
