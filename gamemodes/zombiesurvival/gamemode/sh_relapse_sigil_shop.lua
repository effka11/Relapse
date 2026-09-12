-- Uncorrupted sigils are a points shop, same gate as an arsenal crate.
-- Range is nest-sized. World brushes block; nailed props do not.

GM.SigilShopRange = 256
GM.SigilShopRangeSqr = GM.SigilShopRange * GM.SigilShopRange

local meta = FindMetaTable("Player")
local NearArsenalCrate = meta.NearArsenalCrate

function meta:NearUncorruptedSigil()
	local gm = GAMEMODE
	if not (gm and gm.GetUseSigils and gm:GetUseSigils()) then
		return false
	end

	local sigils = gm.GetUncorruptedSigils and gm:GetUncorruptedSigils()
	if not sigils then
		return false
	end

	local pos = self:EyePos()
	local maxsqr = gm.SigilShopRangeSqr
	local lookrange = gm.SigilShopRange

	for _, ent in ipairs(sigils) do
		if IsValid(ent) then
			local nearest = ent:NearestPoint(pos)
			if pos:DistToSqr(nearest) <= maxsqr and (WorldVisible(pos, nearest) or self:TraceLine(lookrange).Entity == ent) then
				return true
			end
		end
	end

	return false
end

function meta:NearArsenalCrate()
	return NearArsenalCrate(self) or self:NearUncorruptedSigil()
end
meta.IsNearArsenalCrate = meta.NearArsenalCrate
