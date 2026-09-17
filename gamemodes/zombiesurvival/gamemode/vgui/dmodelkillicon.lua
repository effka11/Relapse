local PANEL = {}

function PANEL:SetModel(strModelName)
	self.BaseClass.SetModel(self, strModelName)

	self:AutoCam()
end

local matWhite = Material("models/debug/debugwhite")
function PANEL:Paint(w, h)
	if not IsValid(self.Entity) then return end

	self:LayoutEntity(self.Entity)

	local fade = RelapseUI and RelapseUI.PanelFadeAlpha and RelapseUI.PanelFadeAlpha(self) or (self:GetAlpha() / 255)
	if fade <= 0 then
		self.LastPaint = RealTime()
		return
	end

	local ang = self.aLookAngle
	local x, y = self:LocalToScreen(0, 0)
	local col = self.colColor or color_white

	if not ang then
		ang = (self.vLookatPos - self.vCamPos):Angle()
	end

	cam.Start3D(self.vCamPos, ang, self.fFOV, x, y, w, h, 5, self.FarZ)
	cam.IgnoreZ(true)

	render.SuppressEngineLighting(true)
	render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
	render.SetBlend((col.a / 255) * fade)
	if render.OverrideBlend then
		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD)
	end
	render.ModelMaterialOverride(matWhite)

	self:DrawModel()

	render.ModelMaterialOverride()
	if render.OverrideBlend then
		render.OverrideBlend(false)
	end
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.SuppressEngineLighting(false)

	cam.IgnoreZ(false)
	cam.End3D()

	self.LastPaint = RealTime()
end

vgui.Register("DModelKillIcon", PANEL, "DModelPanelEx")
