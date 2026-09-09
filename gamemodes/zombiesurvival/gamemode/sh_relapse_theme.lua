-- Relapse colour tokens. Change this table to retheme the whole UI.
-- Layout (5/15) lives in vgui/relapse_ui.lua and reads only these colours.

RelapseUI = RelapseUI or {}

RelapseUI.Col = {
	-- Surfaces. Slight glass, dense enough that type does not fight the world.
	Bg        = Color(16, 14, 13, 242),
	Header    = Color(16, 14, 13, 242),
	Panel     = Color(30, 27, 24, 236),
	Card      = Color(48, 44, 40, 250),
	CardHover = Color(60, 55, 50, 255),
	CardOn    = Color(184, 156, 108, 70),

	-- Kept for rare fills (stat tracks). Do not use as window chrome.
	Hairline  = Color(255, 255, 255, 18),
	Border    = Color(255, 255, 255, 18),
	Track     = Color(255, 255, 255, 16),

	Text      = Color(236, 232, 224, 255),
	Muted     = Color(160, 154, 146, 255),

	Accent    = Color(184, 156, 108, 255),
	AccentDim = Color(184, 156, 108, 88),

	Ok        = Color(184, 156, 108, 255),
	Warn      = Color(196, 154, 86, 255),
	Danger    = Color(196, 86, 78, 255),

	-- Health: olive / warm red derived from Accent (H≈38°, muted).
	HealthMax = Color(136, 166, 108, 255),
	HealthMin = Color(196, 90, 78, 255)
}

-- Flora-like radii in reference px (sPx). Fills only — no 1px outlines.
RelapseUI.Rad = {
	Window = 18,
	Panel  = 14,
	Card   = 14,
	Button = 16,
	Bar    = 8
}
