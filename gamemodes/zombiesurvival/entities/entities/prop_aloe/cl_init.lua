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
local AURA_RING = 4
local colAuraFill = {186, 186, 186}
local colAuraEdge = {255, 255, 255}
local auraFillPoly = {}
local auraFade = 0

for i = 0, AURA_SEGS do
	local a = (i / AURA_SEGS) * math.pi * 2
	auraFillPoly[i + 1] = {c = math.cos(a), s = math.sin(a)}
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

local function AuraVert(x, y, z, r, g, b, a)
	mesh.Color(r, g, b, a)
	mesh.Position(Vector(x, y, z))
	mesh.TexCoord(0, 0, 0)
	mesh.AdvanceVertex()
end

local function AuraTri(r, g, b, a, ax, ay, bx, by, cx, cy, z)
	AuraVert(ax, ay, z, r, g, b, a)
	AuraVert(bx, by, z, r, g, b, a)
	AuraVert(cx, cy, z, r, g, b, a)
	AuraVert(ax, ay, z, r, g, b, a)
	AuraVert(cx, cy, z, r, g, b, a)
	AuraVert(bx, by, z, r, g, b, a)
end

local function DrawAloeRadius(origin, radius, alpha)
	if alpha <= 0.01 or radius <= 1 then
		return
	end

	local z = origin.z + 1.6
	local ox, oy = origin.x, origin.y
	local fa = math.floor(24 * alpha + 0.5)
	local ea = math.floor(100 * alpha + 0.5)
	if fa < 1 and ea < 1 then
		return
	end

	render.SetColorMaterial()
	render.OverrideDepthEnable(true, false)

	if fa > 0 then
		mesh.Begin(MATERIAL_TRIANGLES, AURA_SEGS * 2)
		for i = 1, AURA_SEGS do
			local a = auraFillPoly[i]
			local b = auraFillPoly[i + 1]
			AuraTri(
				colAuraFill[1], colAuraFill[2], colAuraFill[3], fa,
				ox, oy,
				ox + a.c * radius, oy + a.s * radius,
				ox + b.c * radius, oy + b.s * radius,
				z
			)
		end
		mesh.End()
	end

	if ea > 0 then
		local inner = math.max(0, radius - AURA_RING)
		mesh.Begin(MATERIAL_TRIANGLES, AURA_SEGS * 4)
		for i = 1, AURA_SEGS do
			local a = auraFillPoly[i]
			local b = auraFillPoly[i + 1]
			local i1x, i1y = ox + a.c * inner, oy + a.s * inner
			local o1x, o1y = ox + a.c * radius, oy + a.s * radius
			local o2x, o2y = ox + b.c * radius, oy + b.s * radius
			local i2x, i2y = ox + b.c * inner, oy + b.s * inner
			AuraTri(colAuraEdge[1], colAuraEdge[2], colAuraEdge[3], ea, i1x, i1y, o1x, o1y, o2x, o2y, z)
			AuraTri(colAuraEdge[1], colAuraEdge[2], colAuraEdge[3], ea, i1x, i1y, o2x, o2y, i2x, i2y, z)
		end
		mesh.End()
	end

	render.OverrideDepthEnable(false, false)
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
