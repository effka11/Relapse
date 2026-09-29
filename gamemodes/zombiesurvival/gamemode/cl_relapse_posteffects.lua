-- World post for the current map. relapse_posteffects_dev opens the sliders.
-- 0 leaves the map alone. +100 is the ceiling. -100 pulls that axis back.
-- Haze is distance shells. A wall at ~450 (oxygen hall) should already be in the haze.
-- Engine fog is a plane, so it cleared at the sides of the view.

local ASH_R, ASH_G, ASH_B = 126, 120, 108
local FOG_NEAR, FOG_FAR, FOG_COVER = 64, 620, 0.86
local FOG_SHELLS = 24

local grade = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0,
}

local punch = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0,
}

local matSky = CreateMaterial("RelapsePostSky", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$model"] = 1,
})
local colSky = Color(ASH_R, ASH_G, ASH_B, 0)
local matGrain = Material("zombiesurvival/filmgrain/filmgrain")
local matBlur = Material("pp/blurscreen")
local matVig = CreateMaterial("RelapsePostVignette", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
	["$ignorez"] = 1,
	["$nocull"] = 1,
	["$nolod"] = 1,
})
local matSharp = CreateMaterial("RelapsePostSharp", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
	["$ignorez"] = 1,
	["$nocull"] = 1,
	["$nolod"] = 1,
})
local sharpRT
local sharpW, sharpH

local EDGE_SEG = 48
local edgeDir = {}
for i = 0, EDGE_SEG do
	local a = (i / EDGE_SEG) * math.pi * 2
	edgeDir[i] = { c = math.cos(a), s = math.sin(a) }
end

local function BorderDist(c, s, hx, hy)
	local ax = math.abs(c)
	local ay = math.abs(s)
	local tx = ax > 1e-5 and hx / ax or 1e8
	local ty = ay > 1e-5 and hy / ay or 1e8
	return math.min(tx, ty)
end

local function Vert2D(x, y, r, g, b, a, u, v)
	mesh.Position(Vector(x, y, 0))
	mesh.Color(r, g, b, a)
	mesh.TexCoord(0, u, v)
	mesh.AdvanceVertex()
end

local function Tri2D(r, g, b, a0, x0, y0, a1, x1, y1, a2, x2, y2, w, h)
	local u0, v0 = x0 / w, y0 / h
	local u1, v1 = x1 / w, y1 / h
	local u2, v2 = x2 / w, y2 / h
	Vert2D(x0, y0, r, g, b, a0, u0, v0)
	Vert2D(x1, y1, r, g, b, a1, u1, v1)
	Vert2D(x2, y2, r, g, b, a2, u2, v2)
end

local function SharpTarget(w, h)
	if sharpRT and sharpW == w and sharpH == h then
		return sharpRT
	end
	sharpW, sharpH = w, h
	sharpRT = GetRenderTarget("RelapsePostSharp" .. w .. "x" .. h, w, h)
	matSharp:SetTexture("$basetexture", sharpRT)
	return sharpRT
end

-- rad 0 is the center, rad 1 is the screen border along that ray.
-- A chord between the two rays that straddle a corner misses that corner.
local function DrawRadial(w, h, rings, keys, r, g, b, aMax)
	local hx, hy = w * 0.5, h * 0.5
	local function pt(i, rad)
		local d = edgeDir[i]
		local edge = BorderDist(d.c, d.s, hx, hy)
		return hx + d.c * edge * rad, hy + d.s * edge * rad
	end
	local function edgeOf(c, s)
		local ax, ay = math.abs(c), math.abs(s)
		local tx = ax > 1e-5 and hx / ax or 1e8
		local ty = ay > 1e-5 and hy / ay or 1e8
		if tx < ty then return c >= 0 and 1 or 3 end
		if ty < tx then return s >= 0 and 2 or 0 end
		return -1
	end
	local function cornerOf(e)
		if e == 1 then return w, h end
		if e == 2 then return 0, h end
		if e == 3 then return 0, 0 end
		return w, 0
	end
	local function spanCorner(i)
		local d0, d1 = edgeDir[i], edgeDir[i + 1]
		local e0 = edgeOf(d0.c, d0.s)
		local e1 = edgeOf(d1.c, d1.s)
		if e0 < 0 or e1 < 0 or e0 == e1 then return nil end
		return cornerOf(e0)
	end
	local bands = #rings - 1
	local quadBands = bands
	local tris = 0
	if rings[1] == 0 then
		tris = EDGE_SEG
		quadBands = bands - 1
	end
	tris = tris + EDGE_SEG * quadBands * 2
	local fillCorner = rings[#rings] == 1
	if fillCorner then
		for i = 0, EDGE_SEG - 1 do
			if spanCorner(i) ~= nil then tris = tris + 1 end
		end
	end
	mesh.Begin(MATERIAL_TRIANGLES, tris)
	local startBand = 1
	if rings[1] == 0 then
		local a = math.floor(aMax * keys[1] + 0.5)
		for i = 0, EDGE_SEG - 1 do
			local x1, y1 = pt(i, rings[2])
			local x2, y2 = pt(i + 1, rings[2])
			Tri2D(r, g, b, a, hx, hy, a, x1, y1, a, x2, y2, w, h)
		end
		startBand = 2
	end
	for band = startBand, bands do
		local r0, r1 = rings[band], rings[band + 1]
		local a0 = math.floor(aMax * keys[band] + 0.5)
		local a1 = math.floor(aMax * keys[band + 1] + 0.5)
		local cap = fillCorner and r1 == 1
		for i = 0, EDGE_SEG - 1 do
			local ix0, iy0 = pt(i, r0)
			local ox0, oy0 = pt(i, r1)
			local ox1, oy1 = pt(i + 1, r1)
			local ix1, iy1 = pt(i + 1, r0)
			local cx, cy
			if cap then cx, cy = spanCorner(i) end
			if cx ~= nil then
				Tri2D(r, g, b, a0, ix0, iy0, a1, ox0, oy0, a1, cx, cy, w, h)
				Tri2D(r, g, b, a0, ix0, iy0, a1, cx, cy, a1, ox1, oy1, w, h)
				Tri2D(r, g, b, a0, ix0, iy0, a1, ox1, oy1, a0, ix1, iy1, w, h)
			else
				Tri2D(r, g, b, a0, ix0, iy0, a1, ox0, oy0, a1, ox1, oy1, w, h)
				Tri2D(r, g, b, a0, ix0, iy0, a1, ox1, oy1, a0, ix1, iy1, w, h)
			end
		end
	end
	mesh.End()
end

local function DrawSoft(t)
	local w, h = ScrW(), ScrH()
	local rt = SharpTarget(w, h)
	render.UpdateScreenEffectTexture()
	render.CopyTexture(render.GetScreenEffectTexture(), rt)

	local blur = 0.4 + 2.2 * t
	local inner = math.max(0.22, 0.5 - 0.16 * t)
	cam.Start2D()
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(matBlur)
		for i = 1, 2 do
			matBlur:SetFloat("$blur", blur * i * 0.5)
			matBlur:Recompute()
			if i == 2 then
				render.UpdateScreenEffectTexture()
			end
			surface.DrawTexturedRect(0, 0, w, h)
		end

		matSharp:SetTexture("$basetexture", rt)
		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD)
		render.SetMaterial(matSharp)
		DrawRadial(w, h, { 0, inner, (inner + 1) * 0.5, 1 }, { 1, 1, 0.35, 0 }, 255, 255, 255, 255)
		render.OverrideBlend(false)
	cam.End2D()
end

local LABEL = {
	strength = "Сила",
	desat = "Выцвет",
	contrast = "Контраст",
	dark = "Затемнение",
	ash = "Пепел",
	fog = "Дымка",
	sky = "Небо",
	ambient = "Тени",
	bloom = "Засвет",
	grain = "Зерно",
	vignette = "Края",
	soft = "Мягкость",
	dust = "Пыль",
}

local function Near(a, b)
	return math.abs(a - b) < 0.001
end

local function ClampByte(n)
	return math.Clamp(n, 0, 255)
end

function GM:RelapsePostFogUnit()
	if not self.RelapseFogCaptured then return 0 end
	local t = self:RelapsePostUnit("fog")
	if self.RelapsePostDevOpen then
		self.RelapseFogBlend = 1
		return t
	end
	return t * (self.RelapseFogBlend or 0)
end

function GM:RelapsePostWantsFog()
	return self:RelapsePostFogUnit() < 0
end

function GM:RelapsePostHazeUnit()
	local t = self:RelapsePostUnit("fog")
	if t <= 0 then return 0 end
	t = t * (1 - (self.DeathFog or 0))
	if t <= 0 then return 0 end
	if self.RelapsePostDevOpen then return t end
	if not self.RelapseFogCaptured then return 0 end
	return t * (self.RelapseFogBlend or 0)
end

-- Positive haze is drawn as shells. This only pushes a map's own fog away.
function GM:RelapsePostFogBase(start, endp, r, g, b, density)
	local t = self:RelapsePostFogUnit()
	if t >= 0 then return start, endp, r, g, b, density end
	if (self.FogMode or 0) == 0 or endp <= 0 then
		return start, endp, r, g, b, density
	end

	local u = -t
	local far = math.max(endp * 3, 16000)
	local s = Lerp(u, start, endp)
	local e = Lerp(u, endp, far)
	local bd = Lerp(u, density, 0)
	if e < s + 32 then e = s + 32 end
	return s, e, ClampByte(r), ClampByte(g), ClampByte(b), math.Clamp(bd, 0, 1)
end

function GM:RelapsePostSkyUnit()
	return self:RelapsePostUnit("sky") * (1 - (self.DeathFog or 0))
end

function GM:RelapsePostWantsSky()
	if not self:RelapsePostEnabled() then return false end
	return self:RelapsePostPercent("sky") ~= 0
end

function GM:RelapsePostSkyDistances(scale, start, endp, r, g, b, density)
	scale = scale or 1
	start = start * scale
	endp = endp * scale
	local t = self:RelapsePostSkyUnit()
	if t > 0 then
		local goalS, goalE, goalD = 180 * scale, 1200 * scale, 0.9
		local clear = density <= 0.01 or endp >= 8000 * scale
		if clear then
			r, g, b = ASH_R, ASH_G, ASH_B
		else
			goalS = math.min(start, goalS)
			goalE = math.min(endp, goalE)
			goalD = math.max(density, goalD)
		end
		if goalE < goalS + 16 then goalE = goalS + 16 end
		start = Lerp(t, start, goalS)
		endp = Lerp(t, endp, goalE)
		density = Lerp(t, density, goalD)
		r = Lerp(t, r, ASH_R)
		g = Lerp(t, g, ASH_G)
		b = Lerp(t, b, ASH_B)
	elseif t < 0 then
		local u = -t
		local far = endp + 8000 * scale
		start = Lerp(u, start, endp)
		endp = Lerp(u, endp, far)
		density = Lerp(u, density, 0)
	end
	if endp < start + 16 then endp = start + 16 end
	return start, endp, ClampByte(r), ClampByte(g), ClampByte(b), math.Clamp(density, 0, 1)
end

function GM:RelapsePostDrawSky()
	local t = self:RelapsePostSkyUnit()
	if t <= 0 then return end
	colSky.r, colSky.g, colSky.b = ASH_R, ASH_G, ASH_B
	colSky.a = math.floor(170 * t)
	cam.Start3D(EyePos(), EyeAngles())
		render.SuppressEngineLighting(true)
		render.SetMaterial(matSky)
		render.DrawQuadEasy(Vector(0, 0, 10240), Vector(0, 0, -1), 20480, 20480, colSky, 0)
		render.DrawQuadEasy(Vector(0, 10240, 0), Vector(0, -1, 0), 20480, 20480, colSky, 0)
		render.DrawQuadEasy(Vector(0, -10240, 0), Vector(0, 1, 0), 20480, 20480, colSky, 0)
		render.DrawQuadEasy(Vector(10240, 0, 0), Vector(-1, 0, 0), 20480, 20480, colSky, 0)
		render.DrawQuadEasy(Vector(-10240, 0, 0), Vector(1, 0, 0), 20480, 20480, colSky, 0)
		render.SuppressEngineLighting(false)
	cam.End3D()
end

local hazeCol = Color(188, 182, 166, 0)
local hazeCR, hazeCG, hazeCB = 0.74, 0.71, 0.64

local function FogFade(u)
	if u <= 0 then return 0 end
	if u >= 1 then return 1 end
	return u * u * (3 - 2 * u)
end

local function HazeTint(eye)
	local lc = render.GetLightColor(eye)
	local r, g, b = lc.x, lc.y, lc.z
	local m = math.max(r, g, b)
	local tr, tg, tb = 0.74, 0.71, 0.64
	if m >= 0.08 then
		r, g, b = r / m, g / m, b / m
		tr = tr * 0.75 + r * 0.25
		tg = tg * 0.75 + g * 0.25
		tb = tb * 0.75 + b * 0.25
	end
	local k = math.Clamp(FrameTime() * 1.5, 0, 1)
	hazeCR = hazeCR + (tr - hazeCR) * k
	hazeCG = hazeCG + (tg - hazeCG) * k
	hazeCB = hazeCB + (tb - hazeCB) * k
	hazeCol.r = math.floor(hazeCR * 255 + 0.5)
	hazeCol.g = math.floor(hazeCG * 255 + 0.5)
	hazeCol.b = math.floor(hazeCB * 255 + 0.5)
end

local function DrawHaze(t)
	local eye = EyePos()
	local far = Lerp(t, 1000, FOG_FAR)
	local n = FOG_SHELLS
	local target = math.Clamp(FOG_COVER * t, 0, 0.86)
	if target < 0.02 then return end

	local shells = {}
	for i = n, 1, -1 do
		local u1 = i / n
		local u0 = (i - 1) / n
		local c1 = target * FogFade(u1)
		local c0 = target * FogFade(u0)
		local span = 1 - c0
		if span > 0.001 then
			local a = 1 - (1 - c1) / span
			if a >= 2 / 255 then
				shells[#shells + 1] = {
					a = a,
					r = Lerp((i - 0.5) / n, FOG_NEAR, far),
				}
			end
		end
	end
	if #shells == 0 then return end

	HazeTint(eye)

	local prev = render.GetFogMode()
	render.FogMode(0)
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.SetColorMaterial()
	for _, sh in ipairs(shells) do
		hazeCol.a = math.floor(sh.a * 255 + 0.5)
		render.DrawSphere(eye, -sh.r, 28, 16, hazeCol)
	end
	render.FogMode(prev or 0)
end

hook.Add("PostDrawOpaqueRenderables", "RelapsePostFog", function(depth, sky)
	if depth or sky then return end
	local gm = GAMEMODE
	if not gm or not gm.RelapsePostHazeUnit then return end
	local t = gm:RelapsePostHazeUnit()
	if t <= 0.01 then return end
	DrawHaze(t)
end)

hook.Add("PreDrawOpaqueRenderables", "RelapsePostAmbient", function()
	local t = GAMEMODE:RelapsePostUnit("ambient")
	if t <= 0 then return end
	render.SetAmbientLight(0.18 * t, 0.17 * t, 0.15 * t)
end)

hook.Add("RenderScreenspaceEffects", "RelapsePostEffects", function()
	local gm = GAMEMODE
	if not gm or not gm.RelapsePostUnit then return end
	if render.GetDXLevel and render.GetDXLevel() < 80 then return end

	local tDesat = gm:RelapsePostUnit("desat")
	local tCon = gm:RelapsePostUnit("contrast")
	local tDark = gm:RelapsePostUnit("dark")
	local tAsh = gm:RelapsePostUnit("ash")
	local tAmb = gm:RelapsePostUnit("ambient")

	local colour = 1
	if tDesat >= 0 then
		colour = 1 + (0.05 - 1) * tDesat
	else
		colour = 1 + (-tDesat)
	end
	local contrast = math.Clamp(1 + 0.45 * tCon - 0.12 * tAmb, 0.4, 1.8)
	local bright = math.Clamp(-0.18 * tDark + 0.05 * tAmb, -0.4, 0.4)
	local addr = 0.045 * math.max(tAmb, 0)
	local addg = 0.042 * math.max(tAmb, 0)
	local addb = 0.038 * math.max(tAmb, 0)
	local mulr, mulg, mulb = 0, 0, 0
	if tAsh >= 0 then
		colour = colour * (1 - 0.45 * tAsh)
		mulr = 0.04 * tAsh
		mulg = -0.04 * tAsh
		mulb = -0.16 * tAsh
	else
		local u = -tAsh
		mulr = -0.1 * u
		mulg = -0.02 * u
		mulb = 0.12 * u
	end

	if not (Near(colour, 1) and Near(contrast, 1) and Near(bright, 0) and Near(addr, 0) and Near(addg, 0) and Near(addb, 0) and Near(mulr, 0) and Near(mulg, 0) and Near(mulb, 0)) then
		grade["$pp_colour_colour"] = colour
		grade["$pp_colour_contrast"] = contrast
		grade["$pp_colour_brightness"] = bright
		grade["$pp_colour_addr"] = addr
		grade["$pp_colour_addg"] = addg
		grade["$pp_colour_addb"] = addb
		grade["$pp_colour_mulr"] = mulr
		grade["$pp_colour_mulg"] = mulg
		grade["$pp_colour_mulb"] = mulb
		DrawColorModify(grade)
	end

	local tBloom = gm:RelapsePostUnit("bloom")
	if tBloom > 0.01 then
		local t = tBloom
		-- darken is a cutoff. 0.78 left only near-white pixels, so a dark map showed nothing.
		DrawBloom(
			Lerp(t, 0.55, 0.2),
			1.2 + 2.2 * t,
			4 + 10 * t,
			4 + 10 * t,
			1 + math.floor(t * 2),
			1.2 + 1.6 * t,
			1, 0.96, 0.88
		)
	elseif tBloom < -0.01 then
		local u = -tBloom
		punch["$pp_colour_contrast"] = 1 + 0.22 * u
		punch["$pp_colour_brightness"] = -0.06 * u
		punch["$pp_colour_colour"] = 1
		punch["$pp_colour_addr"] = 0
		punch["$pp_colour_addg"] = 0
		punch["$pp_colour_addb"] = 0
		DrawColorModify(punch)
	end

	local tSoft = gm:RelapsePostUnit("soft")
	if tSoft > 0.01 then
		DrawSoft(tSoft)
	elseif tSoft < -0.01 then
		DrawSharpen(0.35 * -tSoft, 0.3)
	end
end)

function GM:RelapsePostPaintHUD()
	local g = self:RelapsePostUnit("grain")
	if g > 0.01 then
		surface.SetMaterial(matGrain)
		surface.SetDrawColor(0, 0, 0, math.floor(56 * g))
		local u = (CurTime() * 0.04) % 1
		surface.DrawTexturedRectUV(0, 0, ScrW(), ScrH(), u, 0, u + 2, 2)
	end

	local v = self:RelapsePostUnit("vignette")
	if math.abs(v) <= 0.01 then return end
	local w, h = ScrW(), ScrH()
	local a = math.floor((v > 0 and 170 or 70) * math.abs(v))
	local r, g, b = 0, 0, 0
	if v < 0 then
		r, g, b = 255, 255, 255
	end
	render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD)
	render.SetMaterial(matVig)
	DrawRadial(w, h, { 0.32, 0.55, 0.78, 1 }, { 0, 0.16, 0.48, 1 }, r, g, b, a)
	render.OverrideBlend(false)
end

local DUST_CLASS = {
	func_dustmotes = true,
	func_dustcloud = true,
}

local dustList
local lastDust
local dustAcc = 0
local emitter
local emitterAt

local function CollectDust()
	dustList = {}
	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) and DUST_CLASS[ent:GetClass()] then
			dustList[#dustList + 1] = ent
		end
	end
	table.sort(dustList, function(a, b)
		return a:EntIndex() < b:EntIndex()
	end)
end

local function ApplyMapDust(t)
	if not dustList then CollectDust() end
	local live = {}
	for _, ent in ipairs(dustList) do
		if IsValid(ent) then
			live[#live + 1] = ent
		end
	end
	local hide = 0
	if t < 0 then
		hide = math.floor(#live * math.min(1, -t) + 0.5)
	end
	for i, ent in ipairs(live) do
		local off = t < 0 and i <= hide
		if off then
			if not ent.RelapsePostDustOff then
				ent.RelapsePostDustWas = ent:GetNoDraw()
				ent:Fire("TurnOff")
				ent.RelapsePostDustOff = true
			end
			ent:SetNoDraw(true)
		elseif ent.RelapsePostDustOff then
			ent:Fire("TurnOn")
			ent:SetNoDraw(ent.RelapsePostDustWas and true or false)
			ent.RelapsePostDustOff = nil
			ent.RelapsePostDustWas = nil
		end
	end
end

local function DustEmitter()
	local eye = EyePos()
	if emitter and emitterAt and eye:DistToSqr(emitterAt) > 200 * 200 then
		emitter:Finish()
		emitter = nil
	end
	if not emitter then
		emitter = ParticleEmitter(eye, false)
	end
	if not emitter then return end
	emitter:SetPos(eye)
	emitterAt = eye
	return emitter
end

local function SpawnMote(t)
	local em = DustEmitter()
	if not em then return end
	local eye = EyePos()
	local dir = VectorRand()
	dir.z = dir.z * 0.55
	if dir:LengthSqr() < 0.01 then
		dir = Vector(0, 0, 1)
	else
		dir:Normalize()
	end
	local pos = eye + dir * math.Rand(36, 160)
	local ok, p = pcall(em.Add, em, "particle/particle_smokegrenade", pos)
	if not ok or not p then return end
	p:SetStartAlpha(math.floor(70 + 90 * t))
	p:SetEndAlpha(0)
	p:SetStartSize(4 + 5 * t)
	p:SetEndSize(9 + 14 * t)
	p:SetDieTime(math.Rand(3.5, 6.5))
	p:SetRoll(math.Rand(0, 360))
	p:SetRollDelta(math.Rand(-8, 8))
	p:SetColor(186, 176, 160)
	p:SetLighting(false)
	p:SetAirResistance(18)
	p:SetGravity(Vector(0, 0, -2))
	p:SetVelocity(Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(-2, 4)))
	p:SetCollide(false)
end

local function DustThink()
	local t = GAMEMODE:RelapsePostUnit("dust")
	if dustList == nil or t ~= lastDust then
		if dustList == nil then CollectDust() end
		lastDust = t
		ApplyMapDust(t)
	end
	if t <= 0 then
		dustAcc = 0
		return
	end
	dustAcc = dustAcc + FrameTime() * (16 + 28 * t)
	local n = 0
	while dustAcc >= 1 and n < 6 do
		dustAcc = dustAcc - 1
		n = n + 1
		SpawnMote(t)
	end
	if dustAcc > 6 then dustAcc = 6 end
end

hook.Add("InitPostEntity", "RelapsePostDust", function()
	dustList = nil
	lastDust = nil
	if emitter then
		emitter:Finish()
		emitter = nil
		emitterAt = nil
	end
	timer.Simple(2, function() dustList = nil end)
	timer.Simple(8, function() dustList = nil end)
end)

local sendAt = 0

local function SendState()
	if not IsValid(LocalPlayer()) then return end
	net.Start("zs_posteffects_set")
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		net.WriteInt(GAMEMODE:RelapsePostPercent(key), 8)
	end
	net.SendToServer()
end

local function QueueSend()
	sendAt = RealTime() + 0.12
end

hook.Add("Think", "RelapsePostEffects", function()
	local gm = GAMEMODE
	if not gm then return end
	if not gm.RelapseFogCaptured and gm.GetFogData then
		gm:GetFogData()
	end
	if gm.RelapseFogCaptured and not gm.RelapsePostDevOpen and (gm.RelapseFogBlend or 0) < 1 then
		gm.RelapseFogBlend = math.min(1, (gm.RelapseFogBlend or 0) + FrameTime() * 0.35)
	end
	DustThink()
	if sendAt > 0 and RealTime() >= sendAt then
		sendAt = 0
		SendState()
	end
end)

local Panel
local Filling = false
local Sliders = {}
local Clicker = false
local LastE = 0
local eWas = false

local function SetClicker(on)
	Clicker = on and true or false
	local frame = Panel
	if not IsValid(frame) then
		gui.EnableScreenClicker(false)
		return
	end
	if Clicker then
		frame:MakePopup()
		frame:SetMouseInputEnabled(true)
		-- MakePopup takes the keyboard, so E never reaches the bind.
		frame:SetKeyboardInputEnabled(false)
		gui.EnableScreenClicker(true)
	else
		local focus = vgui.GetKeyboardFocus()
		if IsValid(focus) and focus.KillFocus then
			focus:KillFocus()
		end
		frame:SetMouseInputEnabled(false)
		frame:SetKeyboardInputEnabled(false)
		gui.EnableScreenClicker(false)
	end
end

local function ToggleClicker()
	if not IsValid(Panel) then return end
	local now = RealTime()
	if now - LastE < 0.18 then return end
	LastE = now
	SetClicker(not Clicker)
end

hook.Add("Think", "RelapsePostEffectsUse", function()
	if not IsValid(Panel) or not Panel:IsVisible() then
		eWas = false
		return
	end
	local pl = LocalPlayer()
	local blocked = (IsValid(pl) and pl:IsTyping()) or gui.IsConsoleVisible() or gui.IsGameUIVisible()
	local down = not blocked and input.IsKeyDown(KEY_E)
	if down and not eWas then
		ToggleClicker()
	end
	eWas = down and not blocked
end)

local function Snippet()
	local map = game.GetMap()
	local row = GAMEMODE.RelapsePostEffects and GAMEMODE.RelapsePostEffects[map]
	local parts = {}
	if row then
		for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
			local n = tonumber(row[key])
			if n and n ~= 0 then
				parts[#parts + 1] = string.format("%s = %d", key, n)
			end
		end
	end
	if #parts == 0 then
		return "-- " .. map .. " = 0"
	end
	return string.format("[%s] = { %s },", string.format("%q", map), table.concat(parts, ", "))
end

local function Fill()
	if not IsValid(Panel) then return end
	Filling = true
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		local slider = Sliders[key]
		if IsValid(slider) then
			slider:SetValue(GAMEMODE:RelapsePostPercent(key))
		end
	end
	Filling = false
end

local function PaintButton(me, w, h)
	local col = RelapseUI.Col
	surface.SetDrawColor(me:IsHovered() and col.CardHover or col.Card)
	surface.DrawRect(0, 0, w, h)
	draw.SimpleText(me:GetText(), "Relapse20", w * 0.5, h * 0.5, col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	return true
end

local UndoStack = {}
local RedoStack = {}
local Gesture
local HistoryLock = false
local UndoBtn
local RedoBtn

local function Snapshot()
	local snap = {}
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		snap[key] = GAMEMODE:RelapsePostPercent(key)
	end
	return snap
end

local function RefreshHistory()
	if IsValid(UndoBtn) then UndoBtn:SetEnabled(#UndoStack > 0) end
	if IsValid(RedoBtn) then RedoBtn:SetEnabled(#RedoStack > 0) end
end

local function ApplySnap(snap)
	HistoryLock = true
	local map = game.GetMap()
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		GAMEMODE:RelapsePostWrite(map, key, snap[key] or 0)
	end
	Fill()
	sendAt = 0
	SendState()
	HistoryLock = false
	Gesture = nil
	RefreshHistory()
end

local function RememberBefore(key)
	if HistoryLock or Filling then return end
	local now = RealTime()
	if Gesture and Gesture.key == key and (input.IsMouseDown(MOUSE_LEFT) or now - Gesture.at < 0.5) then
		Gesture.at = now
		return
	end
	UndoStack[#UndoStack + 1] = Snapshot()
	if #UndoStack > 50 then
		table.remove(UndoStack, 1)
	end
	RedoStack = {}
	Gesture = { key = key, at = now }
	RefreshHistory()
end

local function Undo()
	if #UndoStack == 0 then return end
	local back = table.remove(UndoStack)
	RedoStack[#RedoStack + 1] = Snapshot()
	ApplySnap(back)
end

local function Redo()
	if #RedoStack == 0 then return end
	local fwd = table.remove(RedoStack)
	UndoStack[#UndoStack + 1] = Snapshot()
	ApplySnap(fwd)
end

local function PaintArrow(me, w, h, dir)
	local col = RelapseUI.Col
	local off = me:GetDisabled()
	surface.SetDrawColor((me:IsHovered() and not off) and col.CardHover or col.Card)
	surface.DrawRect(0, 0, w, h)
	local ink = off and col.Muted or col.Text
	surface.SetDrawColor(ink)
	local cx, cy = w * 0.5, h * 0.5
	local s = 5
	for o = 0, 1 do
		if dir < 0 then
			surface.DrawLine(cx + 3, cy - s + o, cx - 2, cy + o)
			surface.DrawLine(cx - 2, cy + o, cx + 3, cy + s + o)
		else
			surface.DrawLine(cx - 3, cy - s + o, cx + 2, cy + o)
			surface.DrawLine(cx + 2, cy + o, cx - 3, cy + s + o)
		end
	end
	return true
end

local function ApplyKey(key, value)
	if Filling or HistoryLock then return end
	local n = math.Clamp(math.floor(value + 0.5), -100, 100)
	if GAMEMODE:RelapsePostPercent(key) == n then return end
	RememberBefore(key)
	GAMEMODE:RelapsePostWrite(game.GetMap(), key, n)
	QueueSend()
end

local function OpenPanel()
	if not RelapseUI or not RelapseUI.PaintWindow then return end
	if IsValid(Panel) then
		Panel:SetVisible(true)
		SetClicker(true)
		Fill()
		RefreshHistory()
		return
	end

	GAMEMODE.RelapsePostDevOpen = true
	GAMEMODE.RelapseFogBlend = 1

	local tall = math.min(640, ScrH() - 48)
	local frame = vgui.Create("DFrame")
	frame:SetSize(420, tall)
	frame:SetPos(24, 24)
	frame:SetTitle("")
	frame:SetDraggable(true)
	frame:ShowCloseButton(true)
	frame:SetDeleteOnClose(true)
	frame.Paint = function(me, w, h)
		RelapseUI.PaintWindow(me, w, h)
		draw.SimpleText("Постэффекты", "Relapse20", 14, 8, RelapseUI.Col.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(game.GetMap(), "Relapse15", 14, 28, RelapseUI.Col.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	frame.OnClose = function()
		GAMEMODE.RelapsePostDevOpen = false
		Clicker = false
		gui.EnableScreenClicker(false)
		if Panel == frame then
			Panel = nil
		end
	end

	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:SetPos(8, 52)
	scroll:SetSize(404, tall - 52 - 52)
	scroll.Paint = function() end

	local function Arrow(dir, px)
		local b = vgui.Create("DButton", frame)
		b:SetPos(px, 4)
		b:SetSize(28, 28)
		b:SetText("")
		b.Paint = function(me, w, h)
			return PaintArrow(me, w, h, dir)
		end
		b.DoClick = dir < 0 and Undo or Redo
		return b
	end
	local wide = frame:GetWide()
	UndoBtn = Arrow(-1, wide - 8 - 31 - 4 - 28 - 4 - 28)
	RedoBtn = Arrow(1, wide - 8 - 31 - 4 - 28)

	local canvas = scroll:GetCanvas()
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		local id = key
		local slider = vgui.Create("DNumSlider", canvas)
		slider:Dock(TOP)
		slider:SetTall(40)
		slider:DockMargin(8, 0, 8, 0)
		slider:SetText(LABEL[id] or id)
		slider:SetMin(-100)
		slider:SetMax(100)
		slider:SetDecimals(0)
		RelapseUI.StyleNumSlider(slider)
		local bar = slider.Slider
		if IsValid(bar) then
			bar.RelapseCode = GAMEMODE:RelapsePostCode(id)
			bar.Paint = function(me, w, h)
				RelapseUI.PaintSliderTrack(me, w, h)
				local mark = me.RelapseCode
				if mark == nil then return true end
				local frac = math.Clamp((mark + 100) / 200, 0, 1)
				local knob = me.Knob
				local iw = IsValid(knob) and knob:GetWide() or 0
				local ih = IsValid(knob) and knob:GetTall() or 0
				local x = math.floor(iw * 0.5 + (w - iw) * frac + 0.5)
				local tickH = math.max(ih + RelapseUI.sPx(10), h - RelapseUI.sPx(8))
				local ty = math.floor((h - tickH) * 0.5)
				local col = RelapseUI.Col.Text
				surface.SetDrawColor(col.r, col.g, col.b, 200)
				surface.DrawRect(x - 1, ty, 2, tickH)
				return true
			end
		end
		-- Drag reports fractions. The text box rounds those to an integer and
		-- feeds them back, so any move smaller than 1 snaps the knob to 0.
		local area = slider.TextArea
		if IsValid(area) then
			area.OnGetFocus = function()
				if IsValid(Panel) and Clicker then
					Panel:SetKeyboardInputEnabled(true)
				end
			end
			area.OnLoseFocus = function()
				if IsValid(Panel) and Clicker then
					Panel:SetKeyboardInputEnabled(false)
				end
			end
			area.OnChange = function()
				if vgui.GetKeyboardFocus() ~= area then return end
				local n = tonumber(area:GetText())
				if not n then return end
				slider:SetValue(n)
			end
		end
		slider.OnValueChanged = function(_, value)
			ApplyKey(id, value)
		end
		Sliders[id] = slider
	end

	local reset = vgui.Create("DButton", frame)
	reset:SetPos(12, tall - 44)
	reset:SetSize(192, 32)
	reset:SetText("Сброс")
	reset.Paint = PaintButton
	reset.DoClick = function()
		local map = game.GetMap()
		local atCode = true
		for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
			if GAMEMODE:RelapsePostPercent(key) ~= GAMEMODE:RelapsePostCode(key) then
				atCode = false
				break
			end
		end
		local changed = false
		for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
			local n = atCode and 0 or GAMEMODE:RelapsePostCode(key)
			if GAMEMODE:RelapsePostPercent(key) ~= n then
				changed = true
				break
			end
		end
		if changed then
			RememberBefore("*")
		end
		for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
			local n = atCode and 0 or GAMEMODE:RelapsePostCode(key)
			GAMEMODE:RelapsePostWrite(map, key, n)
		end
		Fill()
		sendAt = 0
		SendState()
		RefreshHistory()
	end

	local copy = vgui.Create("DButton", frame)
	copy:SetPos(216, tall - 44)
	copy:SetSize(192, 32)
	copy:SetText("Копировать")
	copy.Paint = PaintButton
	copy.DoClick = function()
		local text = Snippet()
		SetClipboardText(text)
		print(text)
		if IsValid(LocalPlayer()) then
			LocalPlayer():ChatPrint(text)
		end
	end

	Panel = frame
	Fill()
	RefreshHistory()
	SetClicker(true)

	print("relapse_posteffects_dev " .. game.GetMap())
	print(Snippet())
	if IsValid(LocalPlayer()) then
		LocalPlayer():ChatPrint("Постэффекты: 0 — карта как есть. Минус снижает, плюс добавляет.")
	end
end

local function ClosePanel()
	if IsValid(Panel) then
		Panel:Close()
	end
	Panel = nil
	Clicker = false
	gui.EnableScreenClicker(false)
	GAMEMODE.RelapsePostDevOpen = false
end

local function PanelOpen()
	return IsValid(Panel) and Panel:IsVisible()
end

hook.Add("PlayerBindPress", "RelapsePostEffects", function(pl, bind, pressed)
	if pl ~= LocalPlayer() or not pressed or not PanelOpen() then return end
	if bind ~= "+use" then return end
	if pl:IsTyping() or gui.IsConsoleVisible() or gui.IsGameUIVisible() then return end
	ToggleClicker()
	return true
end)

hook.Add("PlayerButtonDown", "RelapsePostEffects", function(pl, button)
	if pl ~= LocalPlayer() or not IsFirstTimePredicted() then return end
	if button ~= KEY_E or not PanelOpen() then return end
	if pl:IsTyping() or gui.IsConsoleVisible() or gui.IsGameUIVisible() then return end
	ToggleClicker()
end)

hook.Add("HUDPaint", "RelapsePostEffects", function()
	if not PanelOpen() or not RelapseUI then return end
	RelapseUI.CreateFonts()
	local key = RelapseHint and RelapseHint.BindLabel and RelapseHint.BindLabel("+use") or "E"
	local text = Clicker and (key .. " — управление") or (key .. " — курсор")
	RelapseUI.HudText(text, "Relapse22", ScrW() * 0.5, ScrH() - RelapseUI.Grid15(4), RelapseUI.Col.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
end)

concommand.Add("relapse_posteffects_dev", function()
	if IsValid(Panel) and Panel:IsVisible() then
		ClosePanel()
	else
		OpenPanel()
	end
end)

net.Receive("zs_posteffects", function()
	local forced = net.ReadBool()
	local map = net.ReadString()
	local vals = {}
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		vals[key] = net.ReadInt(8)
	end
	if map ~= game.GetMap() then return end
	if not forced and GAMEMODE.RelapsePostDevOpen then return end

	local row
	for _, key in ipairs(GAMEMODE.RelapsePostKeys) do
		local n = math.Clamp(vals[key] or 0, -100, 100)
		if n ~= 0 then
			row = row or {}
			row[key] = n
		end
	end
	GAMEMODE.RelapsePostEffects[map] = row
	dustList = nil
	Fill()
end)
