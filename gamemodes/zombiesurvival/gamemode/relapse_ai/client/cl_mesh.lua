-- Relapse mesh overlay. Shows editor HUD only — does not draw CNavAreas / .nav tiles.

local Mode = 0 -- 0 off, 1 view, 2 edit

net.Receive("RelapseAI.MeshEdit", function()
	Mode = net.ReadUInt(2)
end)

hook.Add("InitPostEntity", "RelapseAI.MeshEdit", function()
	Mode = 0
end)

hook.Add("HUDPaint", "RelapseAI.MeshEdit", function()
	if Mode <= 0 then return end

	local x, y = 18, 18
	local title = Mode == 2 and "Relapse mesh  EDIT" or "Relapse mesh  VIEW"
	draw.SimpleTextOutlined(title, "DermaDefaultBold", x, y, Color(255, 210, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 18
	draw.SimpleTextOutlined("Custom graph — not Source .nav, not nav_edit.", "DermaDefault", x, y, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 16
	draw.SimpleTextOutlined("Empty stub. Walking still uses .nav until this format exists.", "DermaDefault", x, y, Color(180, 180, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	y = y + 16
	draw.SimpleTextOutlined("relapse_hidemesh   relapse_savemesh", "DermaDefault", x, y, Color(160, 160, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
end)
