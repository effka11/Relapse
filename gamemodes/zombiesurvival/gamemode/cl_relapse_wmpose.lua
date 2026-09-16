-- Relapse worldmodel pose editor. Fly camera like V, no x-ray. Params are
-- HUD hits (ZS VGUI on the HUD does not take mouse). E toggles the cursor.

local Active = false
local Clicker = false
local Pos = Vector()
local Ang = Angle()
local BodyAng = Angle()
local SpeedMul = 1
local WishF, WishS, WishU = 0, 0, 0
local WishSprint = false
local Selected = nil -- "stock" | "palm"
local Hovered = nil
local PushAt = 0
local LastClass = ""
local LastFov = 90
local LastE = 0
local Drag
local Hits = {}
local Card = { x = 0, y = 0, w = 0, h = 0 }
local MouseWasDown = false

local SPEED = 900
local SPEED_FAST = 2200
local SPHERE_MIN = 0.28
local SPHERE_DIST = 0.0035

local COL_STOCK = Color(116, 38, 52, 255)
local COL_MUZZLE = Color(208, 211, 214, 255)
local COL_LINE = Color(154, 122, 70, 220)
local COL_SEL = Color(154, 122, 70, 255)
local COL_AXIS_X = Color(196, 72, 72, 255)
local COL_AXIS_Y = Color(88, 168, 88, 255)
local COL_AXIS_Z = Color(80, 120, 196, 255)

function GM:IsRelapseWMPose()
	return Active
end

local function WeaponClass()
	local pl = LocalPlayer()
	if not IsValid(pl) then return end
	local wep = pl:GetActiveWeapon()
	if not IsValid(wep) or wep.Unarmed then return end
	return wep:GetClass(), wep
end

local function EnsureBind()
	local class, wep = WeaponClass()
	if not class then return end
	if GAMEMODE.RelapseWMBinds[class] then
		return GAMEMODE.RelapseWMBinds[class], class
	end

	local pl = LocalPlayer()
	local seeded
	if RelapseMWSeedWMBind and IsValid(wep) and IsValid(pl) then
		seeded = RelapseMWSeedWMBind(wep, pl)
	end
	GAMEMODE:RelapseWMBindSet(class, seeded)
	return GAMEMODE.RelapseWMBinds[class], class
end

local function PushBind()
	if not Active then return end
	local class = WeaponClass()
	if not class then return end
	local bind = GAMEMODE.RelapseWMBinds[class]
	if not bind then return end
	net.Start("zs_relapse_wmpose_bind")
		net.WriteString(class)
		GAMEMODE:RelapseWMBindWrite(bind)
	net.SendToServer()
end

local function DirtyPush()
	PushAt = RealTime() + 0.03
end

local function ReadSpec(spec)
	local b = EnsureBind()
	if not b then return 0 end
	return b[spec.field][spec.key] or 0
end

local function WriteSpec(spec, val)
	local b = EnsureBind()
	if not b then return end
	val = math.Clamp(val, spec.min, spec.max)
	b[spec.field][spec.key] = val
	DirtyPush()
end

local function Specs()
	local list = {
		{ label = "Move X", field = "Pos", key = "x", min = -80, max = 80, step = 0.5 },
		{ label = "Move Y", field = "Pos", key = "y", min = -80, max = 80, step = 0.5 },
		{ label = "Move Z", field = "Pos", key = "z", min = -80, max = 80, step = 0.5 },
		{ label = "Pitch", field = "Ang", key = "p", min = -180, max = 180, step = 1 },
		{ label = "Yaw", field = "Ang", key = "y", min = -180, max = 180, step = 1 },
		{ label = "Roll", field = "Ang", key = "r", min = -180, max = 180, step = 1 }
	}
	if Selected == "stock" then
		list[#list + 1] = { label = "Bone X", field = "Stock", key = "x", min = -64, max = 64, step = 0.25 }
		list[#list + 1] = { label = "Bone Y", field = "Stock", key = "y", min = -64, max = 64, step = 0.25 }
		list[#list + 1] = { label = "Bone Z", field = "Stock", key = "z", min = -64, max = 64, step = 0.25 }
	elseif Selected == "palm" then
		list[#list + 1] = { label = "Bone X", field = "Palm", key = "x", min = -64, max = 64, step = 0.25 }
		list[#list + 1] = { label = "Bone Y", field = "Palm", key = "y", min = -64, max = 64, step = 0.25 }
		list[#list + 1] = { label = "Bone Z", field = "Palm", key = "z", min = -64, max = 64, step = 0.25 }
	end
	return list
end

local function AddHit(x, y, w, h, kind, spec)
	Hits[#Hits + 1] = { x = x, y = y, w = w, h = h, kind = kind, spec = spec }
end

local function HitAt(mx, my)
	for i = #Hits, 1, -1 do
		local h = Hits[i]
		if mx >= h.x and my >= h.y and mx <= h.x + h.w and my <= h.y + h.h then
			return h
		end
	end
end

local function InCard(mx, my)
	return mx >= Card.x and my >= Card.y and mx <= Card.x + Card.w and my <= Card.y + Card.h
end

local function BoneWorld(ply, name)
	if not IsValid(ply) then return end
	ply:SetupBones()
	local id = ply:LookupBone(name)
	if id == nil then return end
	local mat = ply:GetBoneMatrix(id)
	if not mat then return end
	return mat:GetTranslation(), mat:GetAngles()
end

local function BindWorldPoints(ply, bind)
	if not bind or not IsValid(ply) then return end
	local names = GAMEMODE.RelapseWMPoseBone
	local sPos, sAng = BoneWorld(ply, names.Stock)
	local pPos, pAng = BoneWorld(ply, names.Palm)
	if not sPos or not pPos then return end
	local stock = LocalToWorld(bind.Stock, angle_zero, sPos, sAng)
	local palm = LocalToWorld(bind.Palm, angle_zero, pPos, pAng)
	return stock, palm, sAng, pAng
end

local function GunEnds(wep, ply)
	if RelapseMWWeaponEnds and IsValid(wep) then
		local a, b = RelapseMWWeaponEnds(wep, ply)
		if a and b then return a, b end
	end
	if IsValid(wep) and wep.RelapseWMLastStock and wep.RelapseWMLastMuzzle then
		return wep.RelapseWMLastStock, wep.RelapseWMLastMuzzle
	end
	local bind = GAMEMODE.RelapseWMBinds[wep and wep:GetClass() or ""]
	if bind then
		return BindWorldPoints(ply, bind)
	end
end

local function SetClicker(on)
	Clicker = on and true or false
	gui.EnableScreenClicker(Clicker)
	if not Clicker then
		Drag = nil
	end
end

local function Disable()
	if not Active then return end
	Active = false
	GAMEMODE.RelapseWMPoseActive = false
	WishF, WishS, WishU = 0, 0, 0
	Selected = nil
	Hovered = nil
	Drag = nil
	Hits = {}
	SetClicker(false)
end

local function Enable()
	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() then return end

	local look = pl:WorldSpaceCenter()
	Ang = pl:EyeAngles()
	Ang.r = 0
	Pos = look - Ang:Forward() * 72 + Vector(0, 0, 16)
	Ang = (look - Pos):Angle()
	Ang.r = 0
	BodyAng:Set(pl:EyeAngles())
	Active = true
	GAMEMODE.RelapseWMPoseActive = true
	LastClass = WeaponClass() or ""
	EnsureBind()
	PushBind()
	SetClicker(true)
end

net.Receive("zs_relapse_wmpose", function()
	if net.ReadBool() then
		Enable()
	else
		Disable()
	end
end)

net.Receive("zs_relapse_wmpose_bind", function()
	local class = net.ReadString()
	local bind = GAMEMODE:RelapseWMBindRead()
	if Drag then return end
	GAMEMODE:RelapseWMBindSet(class, bind)
end)

net.Receive("zs_relapse_wmpose_sync", function()
	local n = net.ReadUInt(8)
	for _ = 1, n do
		local class = net.ReadString()
		local bind = GAMEMODE:RelapseWMBindRead()
		GAMEMODE:RelapseWMBindSet(class, bind)
	end
end)

local function SphereHit(start, dir, center, radius)
	local oc = start - center
	local a = dir:Dot(dir)
	local b = 2 * oc:Dot(dir)
	local c = oc:Dot(oc) - radius * radius
	local disc = b * b - 4 * a * c
	if disc < 0 then return end
	local t = (-b - math.sqrt(disc)) / (2 * a)
	if t < 0 then
		t = (-b + math.sqrt(disc)) / (2 * a)
	end
	if t < 0 then return end
	return t
end

local function SphereRadius(center)
	local dist = Pos:Distance(center)
	return math.max(SPHERE_MIN, dist * SPHERE_DIST)
end

local function PickPoint()
	local pl = LocalPlayer()
	local class, wep = WeaponClass()
	if not IsValid(pl) or not wep then return end
	local stock, muzzle = GunEnds(wep, pl)
	if not stock or not muzzle then
		local bind = GAMEMODE.RelapseWMBinds[class]
		stock, muzzle = BindWorldPoints(pl, bind)
	end
	if not stock or not muzzle then return end

	local mx, my = gui.MousePos()
	local dir = util.AimVector(Ang, LastFov, mx, my, ScrW(), ScrH())
	dir:Normalize()

	local tStock = SphereHit(Pos, dir, stock, SphereRadius(stock) * 2.8)
	local tMuzzle = SphereHit(Pos, dir, muzzle, SphereRadius(muzzle) * 2.8)
	if tStock and tMuzzle then
		if tStock < tMuzzle then return "stock" end
		return "palm"
	end
	if tStock then return "stock" end
	if tMuzzle then return "palm" end
end

local function ToggleClicker()
	local now = RealTime()
	if now - LastE < 0.18 then return end
	LastE = now
	SetClicker(not Clicker)
end

local function PaintParams()
	RelapseUI.CreateFonts()
	local ui = RelapseUI
	local specs = Specs()
	local rowH = ui.Grid15(2)
	local gap = ui.Grid5()
	local pad = ui.Grid15()
	local w = ui.Grid15(16)
	local h = pad + ui.Grid15(2) + #specs * (rowH + gap) + pad
	local x = ScrW() - ui.Grid15(6) - w
	local y = ui.Snap(ScrH() * 0.18)
	Card.x, Card.y, Card.w, Card.h = x, y, w, h
	Hits = {}

	ui.RoundFill(ui.RadPx("Card"), x, y, w, h, ui.Col.BgGlass)

	local title = Selected == "stock" and "Stock" or (Selected == "palm" and "Palm" or "Worldmodel")
	ui.HudText(title, "Relapse22", x + pad, y + pad + ui.Grid15(), ui.Col.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)

	local btn = rowH
	local yRow = y + pad + ui.Grid15(2)
	for i = 1, #specs do
		local spec = specs[i]
		local rx, ry = x, yRow
		AddHit(rx, ry, w, rowH, "drag", spec)

		local plusX = x + w - pad - btn
		local minusX = plusX - gap - btn
		AddHit(minusX, ry, btn, rowH, "minus", spec)
		AddHit(plusX, ry, btn, rowH, "plus", spec)

		local mx, my = gui.MousePos()
		local hot = Clicker and mx >= rx and my >= ry and mx <= rx + w and my <= ry + rowH
		if hot then
			ui.RoundFill(ui.RadPx("Card"), rx + gap, ry, w - gap * 2, rowH, ui.Col.CardHover)
		end
		ui.RoundFill(ui.RadPx("Button"), minusX, ry, btn, rowH, ui.Col.Card)
		ui.RoundFill(ui.RadPx("Button"), plusX, ry, btn, rowH, ui.Col.Card)

		local ink = Clicker and ui.Col.Text or ui.Col.Muted
		ui.HudText(spec.label, "Relapse15", x + pad, ry + rowH * 0.5, ink, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
		ui.HudText(string.format("%.2f", ReadSpec(spec)), "Relapse15", minusX - gap, ry + rowH * 0.5, ui.Col.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1)
		ui.HudText("-", "Relapse22", minusX + btn * 0.5, ry + rowH * 0.5, ui.Col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
		ui.HudText("+", "Relapse22", plusX + btn * 0.5, ry + rowH * 0.5, ui.Col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)

		yRow = yRow + rowH + gap
	end
end

local function HandleMouse()
	if not Clicker then
		MouseWasDown = false
		Drag = nil
		return
	end

	local down = input.IsMouseDown(MOUSE_LEFT)
	local mx, my = gui.MousePos()

	if down and not MouseWasDown then
		local hit = HitAt(mx, my)
		if hit then
			if hit.kind == "minus" then
				WriteSpec(hit.spec, ReadSpec(hit.spec) - hit.spec.step)
			elseif hit.kind == "plus" then
				WriteSpec(hit.spec, ReadSpec(hit.spec) + hit.spec.step)
			else
				Drag = {
					spec = hit.spec,
					startX = mx,
					startVal = ReadSpec(hit.spec)
				}
			end
		elseif not InCard(mx, my) then
			local nextSel = PickPoint()
			if nextSel ~= Selected then
				Selected = nextSel
			end
		end
	elseif not down then
		Drag = nil
	end

	MouseWasDown = down
end

hook.Add("PlayerBindPress", "RelapseWMPose", function(pl, bind, pressed)
	if not Active or pl ~= LocalPlayer() or not pressed then return end

	if bind == "+use" then
		ToggleClicker()
		return true
	end

	if bind == "invprev" then
		SpeedMul = math.Clamp(SpeedMul * 1.25, 0.25, 4)
		return true
	elseif bind == "invnext" then
		SpeedMul = math.Clamp(SpeedMul * 0.8, 0.25, 4)
		return true
	elseif bind == "lastinv" or string.sub(bind, 1, 4) == "slot" then
		return true
	end
end)

hook.Add("PlayerButtonDown", "RelapseWMPose", function(pl, button)
	if not Active or pl ~= LocalPlayer() then return end
	if not IsFirstTimePredicted() then return end
	if button == KEY_E then
		ToggleClicker()
	end
end)

hook.Add("InputMouseApply", "RelapseWMPose", function(cmd, x, y, ang)
	if not Active or Clicker then return end

	local pitch = 0.022
	local yaw = 0.022
	local cvPitch = GetConVar("m_pitch")
	local cvYaw = GetConVar("m_yaw")
	if cvPitch then pitch = cvPitch:GetFloat() end
	if cvYaw then yaw = cvYaw:GetFloat() end

	Ang.p = math.Clamp(math.NormalizeAngle(Ang.p + y * pitch), -89, 89)
	Ang.y = math.NormalizeAngle(Ang.y - x * yaw)
	Ang.r = 0
	cmd:SetViewAngles(BodyAng)
	return true
end)

hook.Add("CreateMove", "RelapseWMPose", function(cmd)
	if not Active then return end

	if not Clicker then
		WishF = cmd:GetForwardMove()
		WishS = cmd:GetSideMove()
		WishU = 0
		local buttons = cmd:GetButtons()
		if bit.band(buttons, IN_JUMP) ~= 0 then WishU = WishU + 1 end
		if bit.band(buttons, IN_DUCK) ~= 0 then WishU = WishU - 1 end
		WishSprint = bit.band(buttons, IN_SPEED) ~= 0
	else
		WishF, WishS, WishU = 0, 0, 0
		WishSprint = false
	end

	cmd:ClearMovement()
	cmd:SetButtons(bit.band(cmd:GetButtons(), IN_SCORE))
	cmd:SetViewAngles(BodyAng)
	return true
end)

hook.Add("Think", "RelapseWMPose", function()
	if not Active then return end

	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() or pl:GetObserverMode() ~= OBS_MODE_NONE then
		Disable()
		return
	end

	local class = WeaponClass()
	if class and class ~= LastClass then
		LastClass = class or ""
		Selected = nil
		EnsureBind()
		PushBind()
	end

	HandleMouse()

	if Drag then
		if not input.IsMouseDown(MOUSE_LEFT) then
			Drag = nil
		else
			local step = input.IsKeyDown(KEY_LSHIFT) and 0.01 or 0.08
			WriteSpec(Drag.spec, Drag.startVal + (gui.MouseX() - Drag.startX) * step)
		end
	end

	if PushAt > 0 and RealTime() >= PushAt then
		PushAt = 0
		PushBind()
	end

	if Clicker then
		local mx, my = gui.MousePos()
		if not InCard(mx, my) then
			Hovered = PickPoint()
		else
			Hovered = nil
		end
	else
		Hovered = nil
	end

	if Clicker or pl:IsTyping() or gui.IsConsoleVisible() or gui.IsGameUIVisible() then
		return
	end

	local speed = (WishSprint and SPEED_FAST or SPEED) * SpeedMul
	local move = Vector()
	if WishF > 0 then move:Add(Ang:Forward()) elseif WishF < 0 then move:Sub(Ang:Forward()) end
	if WishS > 0 then move:Add(Ang:Right()) elseif WishS < 0 then move:Sub(Ang:Right()) end
	move.z = move.z + WishU
	if move:LengthSqr() > 0 then
		move:Normalize()
		Pos:Add(move * speed * FrameTime())
	end
end)

hook.Add("CalcView", "RelapseWMPose", function(pl, origin, angles, fov, znear, zfar)
	if not Active or pl ~= LocalPlayer() then return end
	LastFov = fov or 90
	return {
		origin = Pos,
		angles = Ang,
		fov = fov,
		znear = znear,
		zfar = zfar,
		drawviewer = true
	}
end)

hook.Add("ShouldDrawLocalPlayer", "RelapseWMPose", function(pl)
	if not Active or pl ~= LocalPlayer() then return end
	return true
end)

hook.Add("HUDPaint", "RelapseWMPose", function()
	if not Active then return end
	PaintParams()
	local key = RelapseHint.BindLabel("+use")
	local text = translate.Format("relapse_wmpose_hint", key)
	RelapseUI.HudText(text, "Relapse22", ScrW() * 0.5, ScrH() - RelapseUI.Grid15(4), RelapseUI.Col.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
end)

hook.Add("PostDrawTranslucentRenderables", "RelapseWMPose", function(depth, skybox)
	if depth or skybox or not Active then return end

	local pl = LocalPlayer()
	local class, wep = WeaponClass()
	if not IsValid(pl) or not wep then return end

	local stock, muzzle = GunEnds(wep, pl)
	local bind = GAMEMODE.RelapseWMBinds[class]
	local _, _, stockAng, palmAng = BindWorldPoints(pl, bind)
	if not stock or not muzzle then return end

	cam.IgnoreZ(true)
	render.SetColorMaterial()
	render.DrawLine(stock, muzzle, COL_LINE, true)

	local function DrawDot(center, which)
		local r = SphereRadius(center)
		local col = which == "stock" and COL_STOCK or COL_MUZZLE
		if Selected == which then
			col = COL_SEL
			r = r * 1.12
		elseif Hovered == which then
			r = r * 1.08
		end
		render.DrawSphere(center, r, 12, 12, col)
	end

	DrawDot(stock, "stock")
	DrawDot(muzzle, "palm")

	if Selected then
		local origin = Selected == "stock" and stock or muzzle
		local bang = Selected == "stock" and stockAng or palmAng
		if origin and bang then
			local len = SphereRadius(origin) * 8
			render.DrawLine(origin, origin + bang:Forward() * len, COL_AXIS_X, true)
			render.DrawLine(origin, origin + bang:Right() * len, COL_AXIS_Y, true)
			render.DrawLine(origin, origin + bang:Up() * len, COL_AXIS_Z, true)
		end
	end

	cam.IgnoreZ(false)
end)

concommand.Add("relapse_wmpose_dump", function()
	local class = WeaponClass()
	if not class then
		print("relapse_wmpose_dump: no weapon")
		return
	end
	local b = GAMEMODE.RelapseWMBinds[class]
	if not b then
		print("relapse_wmpose_dump: no bind for " .. class)
		return
	end
	print(string.format(
		"-- %s\nPos = Vector(%.3f, %.3f, %.3f),\nAng = Angle(%.3f, %.3f, %.3f),\nStock = Vector(%.3f, %.3f, %.3f),\nPalm = Vector(%.3f, %.3f, %.3f),",
		class,
		b.Pos.x, b.Pos.y, b.Pos.z,
		b.Ang.p, b.Ang.y, b.Ang.r,
		b.Stock.x, b.Stock.y, b.Stock.z,
		b.Palm.x, b.Palm.y, b.Palm.z
	))
end)
