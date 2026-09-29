-- Spot 2 is the node at -96, 1592. The point at 110, 1625, 0 takes its place.

hook.Add("InitPostEntityMap", "RelapseJailSigils", function()
	for _, ent in ipairs(ents.FindByClass("info_sigilnode")) do
		if IsValid(ent) and ent:GetPos():DistToSqr(Vector(-96, 1592, 1.28125)) < 64 then
			ent:Remove()
		end
	end

	local pos = Vector(110, 1625, 0)
	for _, ent in ipairs(ents.FindByClass("info_sigilnode")) do
		if IsValid(ent) and ent:GetPos():DistToSqr(pos) < 16 then
			return
		end
	end

	local node = ents.Create("info_sigilnode")
	if IsValid(node) then
		node:SetPos(pos)
		node:Spawn()
	end
end)
