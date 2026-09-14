-- Relapse mesh overlay: painted walkable skin (heightfield samples), not .nav tiles.

local Mode = 0 -- 0 off, 1 view, 2 edit
local GenId = 0
local CellSize = 40
local Cells = {}
local Count = 0
local Pct = 0
local Building = false

local cvDist = CreateClientConVar("relapse_mesh_drawdistance", "1024", true, false, "How far to draw Relapse mesh paint.")

net.Receive("RelapseAI.MeshEdit", function()
	Mode = net.ReadUInt(2)
	if Mode <= 0 then
		Cells = {}
		Count = 0
		GenId = 0
	end
end)

net.Receive("RelapseAI.MeshProgress", function()
	local gen = net.ReadUInt(16)
	if gen ~= GenId then
		GenId = gen
		Cells = {}
	end
	Pct = net.ReadUInt(7)
	Count = net.ReadUInt(20)
	CellSize = net.ReadFloat()
	Building = net.ReadBool()
end)

net.Receive("RelapseAI.MeshCells", function()
	local gen = net.ReadUInt(16)
	if gen ~= GenId then
		GenId = gen
		Cells = {}
	end
	CellSize = net.ReadFloat()
	local n = net.ReadUInt(8)
	for _ = 1, n do
		Cells[#Cells + 1] = {pos = net.ReadVector(), n = net.ReadNormal()}
	end
end)

hook.Add("InitPostEntity", "RelapseAI.MeshEdit", function()
	Mode = 0
	Cells = {}
	GenId = 0
end)

hook.Add("PostDrawTranslucentRenderables", "RelapseAI.MeshEdit", function(_, skybox)
	if skybox or Mode <= 0 then return end

	local eye = EyePos()
	local maxd = math.max(256, cvDist:GetFloat())
	local maxd2 = maxd * maxd
	local size = math.max(8, (CellSize > 0 and CellSize or 40) * 1.12)

	cam.IgnoreZ(true)
	render.SetColorMaterialIgnoreZ()

	for i = 1, #Cells do
		local c = Cells[i]
		local d2 = eye:DistToSqr(c.pos)
		if d2 <= maxd2 then
			local fade = 1 - (d2 / maxd2)
			local a = 28 + math.floor(fade * fade * 90)
			local band = math.floor((c.pos.z + 32768) / 96)
			local col = (band % 2 == 0) and Color(35, 200, 155, a) or Color(55, 145, 220, a)
			render.DrawQuadEasy(c.pos, c.n, size, size, col, 0)
		end
	end

	cam.IgnoreZ(false)
end)

hook.Add("HUDPaint", "RelapseAI.MeshEdit", function()
	if Mode <= 0 then return end

	local x, y = 18, 18
	local title = Mode == 2 and "Relapse mesh  EDIT" or "Relapse mesh  VIEW"
	draw.SimpleTextOutlined(title, "DermaDefaultBold", x, y, Color(255, 210, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 18

	local status
	if Building then
		status = string.format("painting %d%%   %d samples   %su", Pct, math.max(Count, #Cells), CellSize)
	elseif Count > 0 or #Cells > 0 then
		status = string.format("walkable skin   %d samples   %su", math.max(Count, #Cells), CellSize)
	else
		status = "no paint — relapse_buildmesh"
	end
	draw.SimpleTextOutlined(status, "DermaDefault", x, y, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 16
	draw.SimpleTextOutlined("Standable skin, not Source tiles. Bots walk it after links.", "DermaDefault", x, y, Color(170, 170, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 16
	draw.SimpleTextOutlined("relapse_buildmesh   relapse_hidemesh   relapse_savemesh", "DermaDefault", x, y, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
end)
