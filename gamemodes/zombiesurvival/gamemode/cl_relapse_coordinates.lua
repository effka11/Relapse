-- relapse_coordinates: player origin in the top-right corner.

local enabled = false

surface.CreateFont("RelapseCoordinates", {
	font = "Manrope",
	size = 18,
	weight = 500,
	antialias = true,
	extended = true,
})

local COL = Color(236, 236, 236)
local SHADOW = Color(0, 0, 0, 180)
local PAD = 16

hook.Add("HUDPaint", "RelapseCoordinates", function()
	if not enabled then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local pos = ply:GetPos()
	local lines = {
		string.format("x  %.0f", pos.x),
		string.format("y  %.0f", pos.y),
		string.format("z  %.0f", pos.z),
	}

	local font = "RelapseCoordinates"
	local lineH = draw.GetFontHeight(font)
	local x = ScrW() - PAD
	local y = PAD

	for i = 1, #lines do
		local ly = y + (i - 1) * lineH
		draw.SimpleText(lines[i], font, x + 1, ly + 1, SHADOW, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText(lines[i], font, x, ly, COL, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
end)

concommand.Add("relapse_coordinates", function(_, _, args)
	local arg = args[1]
	if arg == "0" then
		enabled = false
	elseif arg == "1" then
		enabled = true
	else
		enabled = not enabled
	end
	print(enabled and "relapse_coordinates: on" or "relapse_coordinates: off")
end)
