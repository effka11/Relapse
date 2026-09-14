INC_CLIENT()

-- Relapse sigil world draw. Colours from RelapseUI.Col (Fog live, Wine corrupt).

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Initialize()
	self:DrawShadow(false)

	self:SetRenderBounds(Vector(-128, -128, -128), Vector(128, 128, 200))

	self:SetModelScaleVector(Vector(1, 1, 1) * self.ModelScale)

	self.AmbientSound = CreateSound(self, "ambient/atmosphere/tunnel1.wav")
end

function ENT:Think()
	if EyePos():DistToSqr(self:GetPos()) <= 4900000 then -- 700^2
		self.AmbientSound:PlayEx(0.33, 75 + (self:GetSigilHealth() / self:GetSigilMaxHealth()) * 25)
	else
		self.AmbientSound:Stop()
	end
end

function ENT:OnRemove()
	self.AmbientSound:Stop()
end

ENT.NextEmit = 0
ENT.Rotation = math.random(360)

local matWhite = Material("models/debug/debugwhite")
local matGlow = Material("sprites/light_glow02_add")
local cDraw = Color(255, 255, 255)
local cDrawCore = Color(255, 255, 255)
local cSigil = Color(0, 0, 0, 255)

local math_sin = math.sin
local math_cos = math.cos
local math_abs = math.abs
local cam_Start3D = cam.Start3D
local cam_End3D = cam.End3D
local render_SetBlend = render.SetBlend
local render_ModelMaterialOverride = render.ModelMaterialOverride
local render_SetColorModulation = render.SetColorModulation
local render_SuppressEngineLighting = render.SuppressEngineLighting
local render_DrawQuadEasy = render.DrawQuadEasy
local render_DrawSprite = render.DrawSprite

function ENT:DrawTranslucent()
	self:RemoveAllDecals()

	local scale = self.ModelScale

	local curtime = CurTime()
	local sat = math_abs(math_sin(curtime))
	local eyepos = EyePos()
	local eyeangles = EyeAngles()
	local forwardoffset = 16 * scale * self:GetForward()
	local rightoffset = 16 * scale * self:GetRight()
	local healthperc = self:GetSigilHealth() / self:GetSigilMaxHealth()
	local radius = (180 + math_cos(sat) * 40) * scale
	local coreradius = (122 + math_sin(sat) * 32) * scale
	local up = self:GetUp()
	local spritepos = self:GetPos() + up
	local spritepos2 = self:WorldSpaceCenter()
	local corrupt = self:GetSigilCorrupted()

	RelapseUI.SigilFromEnt(self, cSigil)
	local r, g, b = cSigil.r / 255, cSigil.g / 255, cSigil.b / 255

	render_SuppressEngineLighting(true)
	render_SetColorModulation(r ^ 0.5, g ^ 0.5, b ^ 0.5)

	self:SetModelScaleVector(Vector(1, 1, 1) * scale)

	self:DrawModel()

	render_SetColorModulation(r, g, b)

	render_ModelMaterialOverride(matWhite)
	render_SetBlend(0.1 * healthperc)

	self:DrawModel()

	render_SetColorModulation(r, g, b)

	self:SetModelScaleVector(Vector(0.1, 0.1, 0.9 * math.max(0.02, healthperc)) * scale)
	render_SetBlend(1)
	cam_Start3D(eyepos + forwardoffset + rightoffset, eyeangles)
	self:DrawModel()
	cam_End3D()
	cam_Start3D(eyepos + forwardoffset - rightoffset, eyeangles)
	self:DrawModel()
	cam_End3D()
	cam_Start3D(eyepos - forwardoffset + rightoffset, eyeangles)
	self:DrawModel()
	cam_End3D()
	cam_Start3D(eyepos - forwardoffset - rightoffset, eyeangles)
	self:DrawModel()
	cam_End3D()
	self:SetModelScaleVector(Vector(1, 1, 1) * scale)

	render_SetBlend(1)
	render_ModelMaterialOverride()
	render_SuppressEngineLighting(false)
	render_SetColorModulation(1, 1, 1)

	self.Rotation = self.Rotation + FrameTime() * 5
	if self.Rotation >= 360 then
		self.Rotation = self.Rotation - 360
	end

	cDraw.r, cDraw.g, cDraw.b = cSigil.r, cSigil.g, cSigil.b
	RelapseUI.LerpCol(RelapseUI.Col.Ink, RelapseUI.Col.Text, healthperc, cDrawCore)

	render.SetMaterial(matGlow)
	if not corrupt then
		render_DrawQuadEasy(spritepos, up, coreradius, coreradius, cDrawCore, self.Rotation)
		render_DrawQuadEasy(spritepos, up * -1, coreradius, coreradius, cDrawCore, self.Rotation)
	end
	render_DrawQuadEasy(spritepos, up, radius, radius, cDraw, self.Rotation)
	render_DrawQuadEasy(spritepos, up * -1, radius, radius, cDraw, self.Rotation)
	render_DrawSprite(spritepos2, radius, radius * 2, cDraw)

	if curtime < self.NextEmit then return end
	self.NextEmit = curtime + 0.05

	local offset = VectorRand()
	offset.z = 0
	offset:Normalize()
	offset = math.Rand(-32, 32) * scale * offset
	offset.z = 1
	local pos = self:LocalToWorld(offset)

	local emitter = ParticleEmitter(pos)
	emitter:SetNearClip(24, 32)

	local particle = emitter:Add(corrupt and "particle/smokesprites_0001" or "sprites/glow04_noz", pos)
	particle:SetDieTime(math.Rand(1.5, 4))
	particle:SetVelocity(Vector(0, 0, math.Rand(32, 64) * scale))
	particle:SetStartAlpha(0)
	particle:SetEndAlpha(255)
	particle:SetStartSize(math.Rand(2, 4) * (corrupt and 3 or 1) * scale)
	particle:SetEndSize(0)
	particle:SetRoll(math.Rand(0, 360))
	particle:SetRollDelta(math.Rand(-1, 1))
	particle:SetColor(cSigil.r, cSigil.g, cSigil.b)
	particle:SetCollide(true)

	emitter:Finish() emitter = nil collectgarbage("step", 64)
end
