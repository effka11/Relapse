-- wave01_music and wave06_music are the map stings. Unstoppable replaces them.
-- The relays stay: start text, the storm line, colour correction, and the wave 6 camera still fire.

hook.Add("InitPostEntityMap", "RelapseMonsoonMusic", function()
	for _, name in ipairs({ "wave01_music", "wave06_music" }) do
		for _, ent in pairs(ents.FindByName(name)) do
			ent:Fire("StopSound")
			ent:Remove()
		end
	end
end)
