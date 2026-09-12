-- Wider, distance-capped mesh picking. D3bot stock uses a 5° cone: far
-- nodes steal the cursor, near spheres (2u) almost never hit.

local DEFAULT_DRAW = 1024
local PICK_RADIUS = 96
local PICK_RADIUS_SQR = PICK_RADIUS * PICK_RADIUS
-- Pads score as if 40u from the ray, so a closer beam wins over the field.
local AREA_BIAS_SQR = 40 * 40

local function drawDist(pl)
	local d = 0
	if IsValid(pl) then
		d = pl:GetInfoNum("d3bot_navmeshing_drawdistance", 0)
	elseif CLIENT and D3bot and D3bot.Convar_Navmeshing_DrawDistance then
		d = D3bot.Convar_Navmeshing_DrawDistance:GetInt()
	end
	if d <= 0 then d = DEFAULT_DRAW end
	return d
end

local function rayToPoint(eye, dir, pos, maxDist)
	local along = (pos - eye):Dot(dir)
	if along < 8 or along > maxDist then return nil end
	local onRay = eye + dir * along
	return along, onRay:DistToSqr(pos)
end

local function rayToSegment(eye, dir, a, b, maxDist)
	local bestAlong, bestD2
	for i = 0, 8 do
		local q = LerpVector(i / 8, a, b)
		local along = (q - eye):Dot(dir)
		if along >= 8 and along <= maxDist then
			local d2 = (eye + dir * along):DistToSqr(q)
			if not bestD2 or d2 < bestD2 then
				bestAlong, bestD2 = along, d2
			end
		end
	end
	return bestAlong, bestD2
end

local function rayToNode(eye, dir, node, maxDist)
	local along, d2 = rayToPoint(eye, dir, node.Pos, maxDist)
	if node.HasArea and node.Params and node.Params.AreaXMin then
		local z = node.Pos.z
		if math.abs(dir.z) > 0.04 then
			local t = (z - eye.z) / dir.z
			if t >= 8 and t <= maxDist then
				local hit = eye + dir * t
				local p = node.Params
				if hit.x >= p.AreaXMin - 16 and hit.x <= p.AreaXMax + 16
				and hit.y >= p.AreaYMin - 16 and hit.y <= p.AreaYMax + 16 then
					if not d2 or AREA_BIAS_SQR < d2 then
						along, d2 = t, AREA_BIAS_SQR
					end
				end
			end
		end
		local s = (node.Pos - eye):Dot(dir)
		if s >= 8 and s <= maxDist then
			local alongPt = eye + dir * s
			local onArea = node:GetClosestPointOnArea(Vector(alongPt.x, alongPt.y, z))
			local areaD2 = alongPt:DistToSqr(onArea)
			if areaD2 < 16 then
				areaD2 = AREA_BIAS_SQR
			end
			if not d2 or areaD2 < d2 then
				along, d2 = s, areaD2
			end
		end
	end
	return along, d2
end

local function getCursored(self, pl)
	if not IsValid(pl) or not self.ItemById then return end
	local maxDist = drawDist(pl)
	local eye, dir = pl:EyePos(), pl:GetAimVector()
	local best, bestScore

	for _, item in pairs(self.ItemById) do
		local along, d2
		if item.Type == "link" and item.Nodes and item.Nodes[1] and item.Nodes[2] then
			along, d2 = rayToSegment(eye, dir, item.Nodes[1].Pos, item.Nodes[2].Pos, maxDist)
		elseif item.Pos then
			along, d2 = rayToNode(eye, dir, item, maxDist)
		end
		if along and d2 and d2 <= PICK_RADIUS_SQR then
			local score = math.sqrt(d2) + along * 0.02
			if not bestScore or score < bestScore then
				best, bestScore = item, score
			end
		end
	end

	return best
end

local function patch()
	if not D3bot or not D3bot.NavMeshMeta or not D3bot.NavMeshMeta.__index then return false end
	D3bot.NavMeshMeta.__index.GetCursoredItemOrNil = getCursored
	return true
end

if not patch() then
	hook.Add("InitPostEntity", "RelapseD3bot.MeshPick", function()
		timer.Simple(0, patch)
	end)
end
timer.Simple(0, patch)
timer.Simple(1, patch)
