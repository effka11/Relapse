-- zs_hades3: kill the map soundtrack. Wave 1 plays music/ava.mp3, wave 6 plays
-- music/limbo.mp3. Relays stay so the start text and colour-correction still fire.

hook.Add("InitPostEntityMap", "Adding", function()
	for _, name in ipairs({"map_start_music", "wave06_music"}) do
		for _, ent in pairs(ents.FindByName(name)) do
			ent:Fire("StopSound")
			ent:Remove()
		end
	end
end)
