-- Relapse colour tokens. Change this table to retheme the whole UI.
-- Layout (5/15) lives in vgui/relapse_ui.lua and reads only these colours.
--
-- The shop is one opaque slab. No glass over the world — that is what
-- read as dirt. Cards are a slight lift on the same ash. Khaki = on.

RelapseUI = RelapseUI or {}

local Ash    = Color(22, 23, 22)      -- charcoal, fully opaque in the shop
local Bone   = Color(236, 232, 224)   -- beige, closer to paper-white
local Khaki  = Color(158, 160, 118)   -- faded military olive
local Blood  = Color(148, 48, 52)     -- oxblood
local Sulfur = Color(186, 162, 62)    -- hazard yellow

local function With(c, a)
	return Color(c.r, c.g, c.b, a)
end

local function AshAt(n)
	return Color(Ash.r + n, Ash.g + n, Ash.b + n, 255)
end

RelapseUI.Col = {
	Bg        = AshAt(0),
	Header    = AshAt(0),
	Panel     = AshAt(0),
	Card      = AshAt(16),
	CardHover = AshAt(28),
	CardOn    = With(Khaki, 255),

	Hairline  = AshAt(28),
	Border    = AshAt(28),
	Track     = AshAt(28),
	Hover     = AshAt(28),
	TabOn     = AshAt(28),
	Lock      = Color(0, 0, 0, 80),
	HudTrack  = Color(0, 0, 0, 80),
	Shadow    = Color(0, 0, 0, 255),
	Wash      = With(Bone, 40),
	DangerDim = With(Blood, 40),

	Text      = With(Bone, 255),
	Muted     = Color(152, 150, 142, 255),
	Ink       = With(Ash, 255),

	Accent    = With(Bone, 255),
	AccentDim = AshAt(16),
	AccentSoft = AshAt(28),

	Ok        = With(Khaki, 255),
	Warn      = With(Sulfur, 255),
	Danger    = With(Blood, 255),

	HealthMax = With(Khaki, 255),
	HealthMin = Color(156, 50, 54, 255),
	Phantom   = Color(128, 130, 122, 130),
	Armor     = Color(120, 40, 46, 230)
}

-- Flora-like radii in reference px (sPx). Fills only — no 1px outlines.
RelapseUI.Rad = {
	Window = 18,
	Panel  = 14,
	Card   = 14,
	Button = 16,
	Bar    = 8
}
