-- Floor pickups on zs_oxygen_b4. The wall health charger stays.
-- This hook runs before the gamemode converts map entities into loot.
-- Climb columns to skip: invisible shaft the player stands on at 5, 4,
-- and the metal ladder the player stands on at -4, 718. Outside ladder stays.
-- map_start_music is the map sting. Signal Interference replaces it.
-- The relay stays: start text, VO, schedules, and spawns still fire.
GM.RelapseLadderDeny = {
	{5, 4},
	{-4, 718},
}

hook.Add("InitPostEntityMap", "Adding", function()
	for _, ent in pairs(ents.FindByName("map_start_music")) do
		ent:Fire("StopSound")
		ent:Remove()
	end

	if SERVER then
		local px, py, reach = 5, 4, 120
		local reachSqr = reach * reach
		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) then
				local class = ent:GetClass()
				if class == "func_brush" or class == "func_breakable" or class == "func_illusionary" then
					local mins, maxs = ent:WorldSpaceAABB()
					if mins and maxs then
						local sx = maxs.x - mins.x
						local sy = maxs.y - mins.y
						local sz = maxs.z - mins.z
						local thin = math.min(sx, sy)
						if thin <= 8 and sz >= 48 and sz <= 160 then
							local cx = (mins.x + maxs.x) * 0.5
							local cy = (mins.y + maxs.y) * 0.5
							local dx, dy = cx - px, cy - py
							if dx * dx + dy * dy <= reachSqr then
								ent:Remove()
							end
						end
					end
				end
			end
		end
		local extra = {
			Vector(800.00, 224.00, -64.00),
			Vector(1563, 1185, -64),
		}
		local placed = ents.FindByClass("info_sigilnode")
		for _, pos in ipairs(extra) do
			local have = false
			for _, ent in ipairs(placed) do
				if ent:GetPos():DistToSqr(pos) < 16 then
					have = true
					break
				end
			end
			if not have then
				local node = ents.Create("info_sigilnode")
				if IsValid(node) then
					node:SetPos(pos)
					node:Spawn()
					placed[#placed + 1] = node
				end
			end
		end
	end

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
