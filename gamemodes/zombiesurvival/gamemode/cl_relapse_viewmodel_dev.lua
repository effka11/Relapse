-- `relapse_viewmodel_dev` arms the editor. I opens the pose panel.
-- X is right, Y is forward, Z is up. One pose is active at a time. Sync copies the open tab onto the rest.

local POSES = {
	{ id = "stand", key = "Stand", text = "Стоя" },
	{ id = "crouch", key = "Crouch", text = "Сидя" },
	{ id = "jump", key = "Jump", text = "Прыжок" },
	{ id = "walk", key = "Walk", text = "Ходьба" },
	{ id = "run", key = "Run", text = "Бег" },
}

local SHIPPED = {
	Stand = { x = 0.77, y = -1.15, z = -7.68 },
	Crouch = { x = 0.77, y = -1.15, z = -7.68 },
	Jump = { x = 0.77, y = -1.15, z = -7.68 },
	Walk = { x = 0.77, y = -1.15, z = -7.68 },
	Run = { x = 0.77, y = -1.15, z = -11.14 },
}

local function shippedPose(key)
	local src = SHIPPED[key] or SHIPPED.Stand
	return { x = src.x, y = src.y, z = src.z }
end

RelapseUI.ViewmodelDev = RelapseUI.ViewmodelDev or { On = false }
local store = RelapseUI.ViewmodelDev
for _, pose in ipairs(POSES) do
	store[pose.key] = store[pose.key] or shippedPose(pose.key)
end

local SLIDER_MIN = -24
local SLIDER_MAX = 24

local function dev()
	return RelapseUI.ViewmodelDev
end

local function poseById(id)
	for _, pose in ipairs(POSES) do
		if pose.id == id then return pose end
	end
end

local function dump()
	local d = dev()
	for _, pose in ipairs(POSES) do
		local v = d[pose.key]
		print(string.format("viewmodel %-6s %.2f %.2f %.2f", pose.id, v.x, v.y, v.z))
	end
end

local function closePanel()
	local frame = RelapseUI.ViewmodelDevPanel
	if IsValid(frame) then
		frame:Close()
	end
	RelapseUI.ViewmodelDevPanel = nil
end

local function openPanel()
	if IsValid(RelapseUI.ViewmodelDevPanel) then
		RelapseUI.ViewmodelDevPanel:SetVisible(true)
		RelapseUI.ViewmodelDevPanel:MakePopup()
		RelapseUI.ViewmodelDevPanel:SetKeyboardInputEnabled(false)
		return
	end

	local d = dev()
	if not poseById(d.Tab) then
		d.Tab = "stand"
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(340, 360)
	frame:SetPos(24, 24)
	frame:SetTitle("")
	frame:SetDraggable(true)
	frame:ShowCloseButton(true)
	frame:SetDeleteOnClose(true)
	frame.Paint = function(me, w, h)
		RelapseUI.PaintWindow(me, w, h)
		draw.SimpleText("Viewmodel", "Relapse20", 14, 10, RelapseUI.Col.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("X вправо   Y вперёд   Z вверх", "Relapse15", 14, 32, RelapseUI.Col.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	frame.OnClose = function()
		dump()
		if RelapseUI.ViewmodelDevPanel == frame then
			RelapseUI.ViewmodelDevPanel = nil
		end
	end

	local tabs = vgui.Create("DPanel", frame)
	tabs:SetPos(12, 56)
	tabs:SetSize(316, 68)
	tabs.Paint = function() end

	local body = vgui.Create("DPanel", frame)
	body:SetPos(8, 132)
	body:SetSize(324, 140)
	body.Paint = function() end

	local sliders = {}
	local filling = false

	local function page()
		local pose = poseById(d.Tab) or POSES[1]
		d[pose.key] = d[pose.key] or shippedPose(pose.key)
		return d[pose.key]
	end

	local function fill()
		filling = true
		local src = page()
		sliders.x:SetValue(src.x)
		sliders.y:SetValue(src.y)
		sliders.z:SetValue(src.z)
		filling = false
	end

	local function addSlider(axis, label)
		local slider = vgui.Create("DNumSlider", body)
		slider:Dock(TOP)
		slider:SetTall(40)
		slider:DockMargin(4, 0, 4, 4)
		slider:SetText(label)
		slider:SetMin(SLIDER_MIN)
		slider:SetMax(SLIDER_MAX)
		slider:SetDecimals(2)
		RelapseUI.StyleNumSlider(slider)
		slider.OnValueChanged = function(_, value)
			if filling then return end
			page()[axis] = value
		end
		sliders[axis] = slider
	end

	addSlider("x", "X")
	addSlider("y", "Y")
	addSlider("z", "Z")

	local function paintTab(me, w, h)
		local on = d.Tab == me.RelapseTab
		local col = RelapseUI.Col
		surface.SetDrawColor(on and col.CardHover or col.Card)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText(me:GetText(), "Relapse20", w * 0.5, h * 0.5, col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return true
	end

	local function select(tab)
		d.Tab = tab
		fill()
	end

	local rows = {
		{ POSES[1], POSES[2], POSES[3] },
		{ POSES[4], POSES[5] },
	}
	for row, specs in ipairs(rows) do
		local count = #specs
		local gap = 6
		local wide = math.floor((316 - gap * (count - 1)) / count)
		for i, spec in ipairs(specs) do
			local btn = vgui.Create("DButton", tabs)
			btn:SetPos((i - 1) * (wide + gap), (row - 1) * 36)
			btn:SetSize(wide, 32)
			btn:SetText(spec.text)
			btn.RelapseTab = spec.id
			btn.Paint = paintTab
			btn.DoClick = function()
				select(spec.id)
			end
		end
	end

	local sync = vgui.Create("DButton", frame)
	sync:SetPos(12, 284)
	sync:SetSize(316, 32)
	sync:SetText("Синхронизация")
	sync.Paint = function(me, w, h)
		local col = RelapseUI.Col
		surface.SetDrawColor(me:IsHovered() and col.CardHover or col.Card)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText(me:GetText(), "Relapse20", w * 0.5, h * 0.5, col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return true
	end
	sync.DoClick = function()
		local src = page()
		for _, pose in ipairs(POSES) do
			local dst = d[pose.key]
			dst.x, dst.y, dst.z = src.x, src.y, src.z
		end
	end

	fill()
	RelapseUI.ViewmodelDevPanel = frame
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
end

local function togglePanel()
	if IsValid(RelapseUI.ViewmodelDevPanel) and RelapseUI.ViewmodelDevPanel:IsVisible() then
		closePanel()
	else
		openPanel()
	end
end

concommand.Add("relapse_viewmodel_dev", function(_, _, args)
	local d = dev()
	if args[1] ~= nil and args[1] ~= "" then
		local v = string.lower(tostring(args[1]))
		d.On = not (v == "0" or v == "false" or v == "off")
	else
		d.On = not d.On
	end
	if not d.On then
		closePanel()
	end
	local ply = LocalPlayer()
	if IsValid(ply) then
		ply:ChatPrint(d.On and "relapse_viewmodel_dev: I открывает панель" or "relapse_viewmodel_dev: выкл")
	end
	print("relapse_viewmodel_dev = " .. (d.On and "1" or "0"))
end)

hook.Add("PlayerButtonDown", "RelapseViewmodelDev", function(pl, button)
	if button ~= KEY_I then return end
	if pl ~= LocalPlayer() then return end
	if not IsFirstTimePredicted() then return end
	if not dev().On then return end
	if gui.IsConsoleVisible() or gui.IsGameUIVisible() then return end
	if pl.IsTyping and pl:IsTyping() then return end
	togglePanel()
end)
