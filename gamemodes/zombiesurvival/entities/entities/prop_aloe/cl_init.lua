INC_CLIENT()

local SIGIL_VANISH_RADIUS = 64
local SIGIL_HINT_FADE_OUT = 40
local colHint = Color(220, 220, 220, 255)
local hintFont

local function AppearRadius()
	return (GAMEMODE and GAMEMODE.RelapseLadderUseRadius) or 104
end

local function HintPeak(useR)
	local peak = SIGIL_HINT_FADE_OUT
	if peak > useR * 0.45 then peak = useR * 0.45 end
	if peak < 16 then peak = 16 end
	return peak
end

local function GapAlpha(gap, outer)
	if gap <= 0 or gap >= outer then return 0 end
	local peak = HintPeak(outer)
	if gap <= peak then
		local t = gap / peak
		return t * (2 - t)
	end
	local t = (outer - gap) / (outer - peak)
	if t < 0 then return 0 end
	if t > 1 then return 1 end
	return t
end

local function CircleDist(ent)
	local pl = LocalPlayer()
	if not IsValid(pl) or not IsValid(ent) then return math.huge end
	local ppos = pl:GetPos()
	local spos = ent:GetPos()
	local dx, dy = ppos.x - spos.x, ppos.y - spos.y
	return math.sqrt(dx * dx + dy * dy)
end

local function HintAlpha(dist)
	local vanishR = SIGIL_VANISH_RADIUS
	local appearR = AppearRadius()
	local innerR = vanishR - HintPeak(vanishR)
	return GapAlpha(dist - innerR, appearR)
end

local function AimAmt(pos)
	local eye = EyePos()
	local dx, dy, dz = pos.x - eye.x, pos.y - eye.y, pos.z - eye.z
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len < 12 then return 1 end
	local ev = EyeVector()
	local dot = (ev.x * dx + ev.y * dy + ev.z * dz) / len
	return math.Clamp((dot - 0.92) / 0.065, 0, 1)
end

local function AimAmtEnt(ent)
	local eye = EyePos()
	local center = ent:WorldSpaceCenter()
	local dx, dy, dz = center.x - eye.x, center.y - eye.y, center.z - eye.z
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	if dist < 12 then return 1 end
	local ev = EyeVector()
	local look = Vector(eye.x + ev.x * dist, eye.y + ev.y * dist, eye.z + ev.z * dist)
	return AimAmt(ent:NearestPoint(look))
end

local function StepHover(ent, want)
	local prev = ent.AloeHintHover or 0
	local dt = FrameTime()
	if dt <= 0 then dt = 0.015 elseif dt > 0.05 then dt = 0.05 end
	local nextv
	if want > prev then
		nextv = math.min(want, prev + dt * 4)
	else
		nextv = math.max(want, prev - dt * 5)
	end
	if nextv < 0.01 then
		ent.AloeHintHover = nil
		return 0
	end
	ent.AloeHintHover = nextv
	return nextv
end

local function EnsureFont()
	if hintFont then return end
	hintFont = true
	surface.CreateFont("RelapseAloeHint", {
		font = "Manrope",
		size = 60,
		weight = 500,
		antialias = true,
		extended = true,
		shadow = false,
		outline = false
	})
end

local function AuraRadius()
	return (GAMEMODE and GAMEMODE.AloeAuraRadius) or 192
end

function ENT:Initialize()
	local r = AuraRadius() + 8
	self:SetRenderBounds(Vector(-r, -r, -16), Vector(r, r, 88))
end

function ENT:CreateLeaves()
	if IsValid(self.Leaves) then return end

	util.PrecacheModel(self.LeavesModel)
	local leaves = ClientsideModel(self.LeavesModel, RENDERGROUP_OPAQUE)
	if not IsValid(leaves) then return end

	leaves:SetParent(self)
	leaves:SetNoDraw(true)
	leaves:SetModelScale(1, 0)
	self.Leaves = leaves
	self:PoseLeaves()
end

function ENT:PoseLeaves()
	local leaves = self.Leaves
	if not IsValid(leaves) then return end

	if leaves:GetParent() ~= self then
		leaves:SetParent(self)
	end
	leaves:SetLocalPos(self.LeavesLocalPos)
	leaves:SetLocalAngles(self.LeavesLocalAng)
	leaves:SetModelScale(1, 0)
end

function ENT:OnRemove()
	if IsValid(self.Leaves) then
		self.Leaves:Remove()
		self.Leaves = nil
	end
end

function ENT:DrawHint(txt, extraZ)
	if not IsValid(MySelf) or MySelf:Team() ~= TEAM_HUMAN then return end
	if not txt or txt == "" then return end

	local spos = self:GetPos()
	local mins, maxs = self:WorldSpaceAABB()
	local z = spos.z + 16
	if mins and maxs and maxs.z > mins.z + 8 then
		z = maxs.z + 8
	end
	z = z + (extraZ or 0)
	local drawAt = Vector(spos.x, spos.y, z)
	local hover = StepHover(self, AimAmtEnt(self))
	local alpha = HintAlpha(CircleDist(self)) * hover
	if alpha <= 0.02 then return end

	local look = EyePos()
	if look:DistToSqr(drawAt) < 36 then return end

	local ang = (look - drawAt):Angle()
	ang:RotateAroundAxis(ang:Right(), 270)
	ang:RotateAroundAxis(ang:Up(), 90)

	local col = RelapseUI and RelapseUI.Col and RelapseUI.Col.Text
	colHint.r = col and col.r or 220
	colHint.g = col and col.g or 220
	colHint.b = col and col.b or 220
	colHint.a = math.floor(alpha * 255 + 0.5)

	EnsureFont()
	local fog = render.GetFogMode()
	cam.IgnoreZ(true)
	render.FogMode(0)
	cam.Start3D2D(drawAt, ang, 0.05)
	surface.SetAlphaMultiplier(alpha)
	draw.SimpleText(txt, "RelapseAloeHint", 0, 0, colHint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	surface.SetAlphaMultiplier(1)
	cam.End3D2D()
	render.FogMode(fog)
	cam.IgnoreZ(false)
end

function ENT:Draw()
	self:DrawModel()

	if self:GetGrown() then
		if not IsValid(self.Leaves) then
			self:CreateLeaves()
		end
		if IsValid(self.Leaves) then
			self:PoseLeaves()
			render.SetColorModulation(1, 1, 1)
			render.SetBlend(1)
			render.MaterialOverride()
			render.SuppressEngineLighting(false)
			self.Leaves:SetupBones()
			self.Leaves:DrawModel()
		end

		local owner = self:GetObjectOwner()
		if owner:IsValid() and owner == MySelf then
			local key = RelapseHint and RelapseHint.BindLabel("+use") or "E"
			self:DrawHint(translate.Format("press_e_to_use_aloe", key), 32)
		end
		return
	elseif IsValid(self.Leaves) then
		self.Leaves:Remove()
		self.Leaves = nil
	end

	local rem = self:GetGrowRemaining()
	if rem <= 0 then return end

	local m = math.floor(rem / 60)
	local s = math.floor(rem % 60)
	self:DrawHint(string.format("%d:%02d", m, s))
end

local AURA_SEGS = 72
local AURA_RING = 2.2
local angAuraFloor = Angle(-90, 0, 0)
local colAuraFill = Color(186, 186, 186, 0)
local colAuraEdge = Color(255, 255, 255, 0)
local auraFillPoly = {}
local auraTri = {{x = 0, y = 0}, {}, {}}
local auraRingQuad = {{}, {}, {}, {}}
local auraFade = 0

for i = 0, AURA_SEGS do
	local a = (i / AURA_SEGS) * math.pi * 2
	auraFillPoly[i + 1] = {x = 0, y = 0, c = math.cos(a), s = math.sin(a)}
end

local function AuraWanted()
	if not IsValid(MySelf) or MySelf:Team() ~= TEAM_HUMAN or not MySelf:Alive() then
		return false
	end
	if input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT) then
		return true
	end
	return MySelf:KeyDown(IN_WALK)
end

local function DrawAloeRadius(origin, radius, alpha)
	if alpha <= 0.01 or radius <= 1 then
		return
	end

	local pos = Vector(origin.x, origin.y, origin.z + 1.2)
	colAuraFill.a = math.floor(34 * alpha + 0.5)
	colAuraEdge.a = math.floor(220 * alpha + 0.5)

	local fog = render.GetFogMode()
	render.FogMode(0)
	render.CullMode(MATERIAL_CULLMODE_NONE)
	cam.Start3D2D(pos, angAuraFloor, 1)
	draw.NoTexture()

	surface.SetDrawColor(colAuraFill.r, colAuraFill.g, colAuraFill.b, colAuraFill.a)
	for i = 1, AURA_SEGS do
		local a = auraFillPoly[i]
		local b = auraFillPoly[i + 1]
		auraTri[2].x, auraTri[2].y = a.c * radius, a.s * radius
		auraTri[3].x, auraTri[3].y = b.c * radius, b.s * radius
		surface.DrawPoly(auraTri)
	end

	local inner = math.max(0, radius - AURA_RING)
	surface.SetDrawColor(colAuraEdge.r, colAuraEdge.g, colAuraEdge.b, colAuraEdge.a)
	for i = 1, AURA_SEGS do
		local a = auraFillPoly[i]
		local b = auraFillPoly[i + 1]
		local q1, q2, q3, q4 = auraRingQuad[1], auraRingQuad[2], auraRingQuad[3], auraRingQuad[4]
		q1.x, q1.y = a.c * inner, a.s * inner
		q2.x, q2.y = a.c * radius, a.s * radius
		q3.x, q3.y = b.c * radius, b.s * radius
		q4.x, q4.y = b.c * inner, b.s * inner
		surface.DrawPoly(auraRingQuad)
	end

	cam.End3D2D()
	render.CullMode(MATERIAL_CULLMODE_CCW)
	render.FogMode(fog)
end

hook.Add("PostDrawTranslucentRenderables", "Relapse.AloeAuraRing", function(depth, sky)
	if depth or sky then
		return
	end

	local dt = FrameTime()
	if dt <= 0 then
		dt = 0.015
	elseif dt > 0.05 then
		dt = 0.05
	end
	if AuraWanted() then
		auraFade = math.min(1, auraFade + dt * 8)
	else
		auraFade = math.max(0, auraFade - dt * 10)
	end
	if auraFade <= 0.01 then
		auraFade = 0
		return
	end

	local radius = AuraRadius()
	for _, ent in ipairs(ents.FindByClass("prop_aloe")) do
		if ent:IsValid() then
			DrawAloeRadius(ent:GetPos(), radius, auraFade)
		end
	end
	for _, ent in ipairs(ents.FindByClass("status_ghost_aloe")) do
		if ent:IsValid() then
			DrawAloeRadius(ent:GetPos(), radius, auraFade)
		end
	end
end)
