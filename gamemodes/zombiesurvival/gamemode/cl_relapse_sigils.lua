-- relapse_sigils: every place a sigil can be chosen from, not only the live ones.

local spots = {}
local shown = false

surface.CreateFont("RelapseSigilSpot", {
	font = "Manrope",
	size = 64,
	weight = 600,
	antialias = true,
	extended = true,
})

net.Receive("zs_sigilspots", function()
	shown = net.ReadBool()
	spots = {}
	if not shown then return end
	local n = net.ReadUInt(8)
	for i = 1, n do
		spots[i] = net.ReadVector()
	end
end)

function RelapseSigilSpotsShown()
	return shown
end

function RelapseSigilSpotPos(index)
	return spots[index]
end

function RelapseSigilSpotMove(index, pos)
	local spot = spots[index]
	if not spot or not pos then return end
	spot:Set(pos)
end

hook.Add("PostDrawTranslucentRenderables", "RelapseSigilSpots", function(depth, sky)
	if depth or sky or not shown or #spots == 0 then return end

	local col = RelapseUI and RelapseUI.Col and RelapseUI.Col.Text or Color(208, 211, 214)
	local eye = EyeAngles()
	eye:RotateAroundAxis(eye:Right(), 90)
	eye:RotateAroundAxis(eye:Up(), -90)

	cam.IgnoreZ(true)
	for i = 1, #spots do
		local pos = spots[i]
		render.DrawLine(pos, pos + Vector(0, 0, 72), col, false)
		render.DrawLine(pos + Vector(-14, 0, 2), pos + Vector(14, 0, 2), col, false)
		render.DrawLine(pos + Vector(0, -14, 2), pos + Vector(0, 14, 2), col, false)
		cam.Start3D2D(pos + Vector(0, 0, 84), eye, 0.12)
			draw.SimpleText(tostring(i), "RelapseSigilSpot", 1, 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(tostring(i), "RelapseSigilSpot", 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
	cam.IgnoreZ(false)
end)