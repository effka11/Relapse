-- Floor pickups on zs_oxygen_b4. The wall health charger stays.
-- This hook runs before the gamemode converts map entities into loot.
hook.Add("InitPostEntityMap", "Adding", function()
	for _, ent in pairs(ents.FindByClass("item_healthkit")) do ent:Remove() end
	for _, ent in pairs(ents.FindByClass("item_healthvial")) do ent:Remove() end
	util.RemoveAll("item_ammo_*")
	util.RemoveAll("item_box_buckshot")
	util.RemoveAll("item_rpg_round")

	local conversions = GAMEMODE.WorldConversions
	if conversions then
		for _, ent in pairs(ents.FindByClass("prop_physics*")) do
			local mdl = ent:GetModel()
			if mdl and conversions[string.lower(mdl)] then
				ent:Remove()
			end
		end
	end

	-- Weapon and food props are turned into prop_weapon inside InitPostEntityMap,
	-- after this hook. PlacedInMap is set on those before the next tick.
	timer.Simple(0, function()
		for _, ent in pairs(ents.FindByClass("prop_weapon")) do
			if ent.PlacedInMap or ent.IsPreplaced then ent:Remove() end
		end
		for _, ent in pairs(ents.FindByClass("prop_ammo")) do
			if ent.PlacedInMap then ent:Remove() end
		end
	end)
end)
