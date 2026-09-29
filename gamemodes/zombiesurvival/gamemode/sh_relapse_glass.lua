-- Pane and window. A shot window is Breakable.Glass, a glass prop is Glass.Break.
-- Four takes, one picked at random. Bottles, ice, and bullet ticks stay HL2.
-- Files are gained 8 dB toward the HL2 window (Breakable.Glass). Script volume
-- stops at 1, so it cannot close that gap on its own. HL2 plays its takes at 0.7.
-- Level 90: silence near 50 m. HL2's 75 is gone by about 32 m.
-- Registered again after the map loads: the engine sound scripts land later and would put HL2 back.

local SHEET = {
	"relapse/glass_sheet1.ogg",
	"relapse/glass_sheet2.ogg",
	"relapse/glass_sheet3.ogg",
	"relapse/glass_sheet4.ogg",
}

local function addBreak(name)
	sound.Add({
		name = name,
		channel = CHAN_STATIC,
		volume = 1,
		level = 90,
		pitch = 100,
		sound = SHEET,
	})
end

local function register()
	addBreak("Glass.Break")
	addBreak("Breakable.Glass")
end

register()
hook.Add("InitPostEntity", "RelapseGlassSheet", register)

for i = 1, #SHEET do
	util.PrecacheSound(SHEET[i])
end
