-- Relapse colour tokens. Change this table to retheme the whole UI.
-- Layout (5/15) lives in vgui/relapse_ui.lua and reads only these colours.
--
-- Off-white, same-hue gray. Surfaces are neutral value steps.
-- Wine only for damage and shortage. World sigils use the same tokens:
-- live Fog (Text / HealthMax), hurt and corrupt Wine.

RelapseUI = RelapseUI or {}

local Fog   = Color(214, 211, 205)   -- chrome: bright enough to snap, not paper
local Gray  = Color(118, 116, 112)   -- captions, spare
local Wine  = Color(116, 38, 52)     -- бордо, not tomato
local Brass = Color(154, 122, 70)    -- old lamp

local function With(c, a)
	return Color(c.r, c.g, c.b, a)
end

-- Surfaces: Fog's value, no hue. Dust stays in the ink, not the slab.
local FogLum = math.floor((Fog.r + Fog.g + Fog.b) / 3 + 0.5)

local function FogVal(t)
	t = math.Clamp(t or 1, 0, 1)
	local v = math.floor(FogLum * t + 0.5)
	return Color(v, v, v, 255)
end

local function FogValA(t, a)
	local c = FogVal(t)
	c.a = a
	return c
end

local GlassA = 246
local CardA  = 200

RelapseUI.Col = {
	Bg        = FogVal(0.09),
	BgGlass   = FogValA(0.09, GlassA),
	Header    = FogVal(0.09),
	Panel     = FogVal(0.09),
	Card      = FogValA(0.16, CardA),
	CardHover = FogValA(0.22, CardA),
	CardOn    = With(Fog, 255),

	Hairline  = FogVal(0.22),
	Border    = FogVal(0.22),
	Track     = FogVal(0.22),
	Hover     = FogVal(0.22),
	TabOn     = FogVal(0.22),
	Lock      = Color(0, 0, 0, 80),
	HudTrack  = Color(0, 0, 0, 80),
	Scrim     = Color(0, 0, 0, 160),
	Shadow    = Color(0, 0, 0, 255),
	Wash      = Color(FogLum, FogLum, FogLum, 28),
	DangerDim = With(Wine, 40),

	Text      = With(Fog, 255),
	Muted     = With(Gray, 255),
	Ink       = FogVal(0.09),

	Accent    = With(Fog, 255),
	AccentDim = FogValA(0.16, CardA),
	AccentSoft = FogValA(0.22, CardA),

	Ok        = With(Fog, 255),
	Warn      = With(Brass, 255),
	Danger    = With(Wine, 255),

	HealthMax = With(Fog, 255),
	HealthMin = Color(128, 42, 56, 255),
	Phantom   = With(Gray, 160),
	Armor     = Color(102, 32, 44, 230)
}

-- Flora-like radii in reference px (sPx). Fills only — no 1px outlines.
RelapseUI.Rad = {
	Window = 18,
	Panel  = 14,
	Card   = 14,
	Button = 16,
	Bar    = 8
}

local colSigil = Color(0, 0, 0, 255)

function RelapseUI.CopyCol(c, a)
	return Color(c.r, c.g, c.b, a or c.a or 255)
end

function RelapseUI.LerpCol(a, b, t, out)
	t = math.Clamp(t or 0, 0, 1)
	out = out or Color(0, 0, 0, 255)
	out.r = a.r + (b.r - a.r) * t
	out.g = a.g + (b.g - a.g) * t
	out.b = a.b + (b.b - a.b) * t
	out.a = (a.a or 255) + ((b.a or 255) - (a.a or 255)) * t
	return out
end

-- Live Fog, corrupt Wine. healthfrac 1 is full. flashfrac 1 is a just-hit pulse.
function RelapseUI.SigilCol(corrupt, healthfrac, flashfrac, out)
	local c = RelapseUI.Col
	out = out or colSigil
	healthfrac = math.Clamp(healthfrac or 1, 0, 1)
	flashfrac = math.Clamp(flashfrac or 0, 0, 1)
	if corrupt then
		RelapseUI.LerpCol(c.HealthMin, c.Danger, healthfrac, out)
		if flashfrac > 0 then
			RelapseUI.LerpCol(out, c.Text, flashfrac, out)
		end
	else
		RelapseUI.LerpCol(c.HealthMin, c.HealthMax, healthfrac, out)
		if flashfrac > 0 then
			RelapseUI.LerpCol(out, c.Danger, flashfrac, out)
		end
	end
	return out
end

function RelapseUI.SigilFromEnt(ent, out)
	if not (ent and ent:IsValid()) then
		return RelapseUI.SigilCol(false, 0, 0, out)
	end

	local maxh = ent:GetSigilMaxHealth()
	local frac = maxh > 0 and ent:GetSigilHealth() / maxh or 0
	local flash = 1 - math.min((CurTime() - ent:GetSigilLastDamaged()) * 2, 1)
	return RelapseUI.SigilCol(ent:GetSigilCorrupted(), frac, flash, out)
end
