-- relapse_sigils_dev: use a sigil to fly like V, without the player glow.
-- E switches flight and the cursor. Yaw spins the sigil in place.

local Armed = false

function RelapseSigilDevArmed()
	return Armed
end
local Active = false
local Clicker = false
local Sigil = NULL
local SpotIndex = 0
local Pos = Vector()
local Ang = Angle()
local BodyAng = Angle()
local EditPos = Vector()
local EditYaw = 0
local SpeedMul = 1
local WishF, WishS, WishU = 0, 0, 0
local WishSprint = false
local LastE = 0
local PushAt = 0
local Drag
local Hits = {}
local Card = { x = 0, y = 0, w = 0, h = 0 }
local MouseWasDown = false

local SPEED = 240
local SPEED_FAST = 640
local NEAR_BODY_SQR = 16 * 16

local SPECS = {
	{ id = "x", label = "X", step = 1, drag = 0.5, fine = 0.05 },
	{ id = "y", label = "Y", step = 1, drag = 0.5, fine = 0.05 },
	{ id = "z", label = "Z", step = 1, drag = 0.5, fine = 0.05 },
	{ id = "yaw", label = "Поворот", step = 5, drag = 0.35, fine = 0.05 },
}

local function ReadSpec(spec)
	if spec.id == "x" then return EditPos.x end
	if spec.id == "y" then return EditPos.y end
	if spec.id == "z" then return EditPos.z end
	return EditYaw
end

local function EditingSpot()
	return SpotIndex > 0 and RelapseSigilSpotPos and RelapseSigilSpotPos(SpotIndex) ~= nil
end

local function ApplyLocal()
	if IsValid(Sigil) then
		Sigil:SetPos(EditPos)
		Sigil:SetAngles(Angle(0, EditYaw, 0))
		return
	end
	if EditingSpot() and RelapseSigilSpotMove then
		RelapseSigilSpotMove(SpotIndex, EditPos)
	end
end

local function Push()
	if not Active then return end
	if not IsValid(Sigil) and not EditingSpot() then return end
	ApplyLocal()
	net.Start("zs_sigildev_set")
		net.WriteEntity(IsValid(Sigil) and Sigil or NULL)
		net.WriteUInt(IsValid(Sigil) and 0 or SpotIndex, 8)
		net.WriteVector(EditPos)
		net.WriteFloat(EditYaw)
	net.SendToServer()
end

local function DirtyPush()
	PushAt = RealTime() + 0.03
end

local function WriteSpec(spec, val)
	if spec.id == "x" then
		EditPos.x = val
	elseif spec.id == "y" then
		EditPos.y = val
	elseif spec.id == "z" then
		EditPos.z = val
	else
		EditYaw = math.NormalizeAngle(val)
	end
	DirtyPush()
	ApplyLocal()
end

local function CopyPose()
	local line = string.format("Vector(%.2f, %.2f, %.2f)", EditPos.x, EditPos.y, EditPos.z)
	if math.abs(EditYaw) > 0.05 then
		line = line .. string.format("\nAngle(0, %.2f, 0)", EditYaw)
	end
	SetClipboardText(line)
	print(line)
	chat.AddText(RelapseUI and RelapseUI.Col and RelapseUI.Col.Text or color_white, line)
end

local function SetClicker(on)
	Clicker = on and true or false
	gui.EnableScreenClicker(Clicker)
	if not Clicker then
		Drag = nil
	end
end

local function TellCam(on)
	net.Start("zs_sigildev_cam")
		net.WriteBool(on and true or false)
	net.SendToServer()
end

local function Disable()
	if not Active then return end
	Active = false
	Sigil = NULL
	SpotIndex = 0
	Drag = nil
	Hits = {}
	WishF, WishS, WishU = 0, 0, 0
	SetClicker(false)
	TellCam(false)
end

local function EnableCam()
	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() then return end
	Pos:Set(pl:EyePos())
	Ang:Set(pl:EyeAngles())
	Ang.r = 0
	BodyAng:Set(pl:EyeAngles())
	Active = true
	SetClicker(false)
end

local function SelectSigil(ent)
	if not IsValid(ent) then return end
	Sigil = ent
	SpotIndex = 0
	EditPos:Set(ent:GetPos())
	EditYaw = ent:GetAngles().y
end

local function SelectSpot(index)
	local pos = RelapseSigilSpotPos and RelapseSigilSpotPos(index)
	if not pos then return end
	Sigil = NULL
	SpotIndex = index
	EditPos:Set(pos)
	EditYaw = 0
	for _, ent in ipairs(ents.FindByClass("info_sigilnode")) do
		if IsValid(ent) and ent:GetPos():DistToSqr(pos) < 16 then
			EditYaw = ent:GetAngles().y
			break
		end
	end
end

net.Receive("zs_sigildev", function()
	local on = net.ReadBool()
	local ent = net.ReadEntity()
	local spot = net.ReadUInt(8)
	if not on then
		Armed = false
		Disable()
		return
	end
	Armed = true
	if IsValid(ent) then
		if not Active then EnableCam() end
		SelectSigil(ent)
	elseif spot > 0 then
		if not Active then EnableCam() end
		SelectSpot(spot)
	end
end)

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

local function Consider(best, origin, dir, point, radius, kind, data)
	local rel = point - origin
	local along = rel:Dot(dir)
	if along < 32 or along > 8192 then return best end
	local off = (rel - dir * along):LengthSqr()
	if off > radius * radius then return best end
	if not best or along < best.along - 8 or (math.abs(along - best.along) <= 8 and off < best.off) then
		return { along = along, off = off, kind = kind, data = data }
	end
	return best
end

local function PickTarget(origin, dir)
	local best
	for _, ent in ipairs(ents.FindByClass("prop_obj_sigil")) do
		if IsValid(ent) then
			best = Consider(best, origin, dir, ent:WorldSpaceCenter(), 72, "sigil", ent)
		end
	end
	if RelapseSigilSpotsShown and RelapseSigilSpotsShown() and RelapseSigilSpotPos then
		for i = 1, 255 do
			local spot = RelapseSigilSpotPos(i)
			if not spot then break end
			best = Consider(best, origin, dir, spot, 48, "spot", i)
			best = Consider(best, origin, dir, spot + Vector(0, 0, 40), 48, "spot", i)
			best = Consider(best, origin, dir, spot + Vector(0, 0, 84), 36, "spot", i)
		end
	end
	return best
end

local function GrabPicked(pick)
	if not pick then return end
	if pick.kind == "sigil" then
		if pick.data == Sigil then return end
		SelectSigil(pick.data)
		Push()
	elseif pick.kind == "spot" then
		if pick.data == SpotIndex then return end
		SelectSpot(pick.data)
		Push()
	end
end

local function PaintCard()
	if not RelapseUI or not RelapseUI.CreateFonts then return end
	RelapseUI.CreateFonts()
	local ui = RelapseUI
	local rowH = ui.Grid15(2)
	local gap = ui.Grid5()
	local pad = ui.Grid15()
	local w = ui.Grid15(16)
	local rows = #SPECS + 1
	local h = pad + ui.Grid15(2) + rows * (rowH + gap) + pad
	local x = ScrW() - ui.Grid15(6) - w
	local y = ui.Snap(ScrH() * 0.18)
	Card.x, Card.y, Card.w, Card.h = x, y, w, h
	Hits = {}

	ui.RoundFill(ui.RadPx("Card"), x, y, w, h, ui.Col.BgGlass)
	local title = EditingSpot() and ("Точка " .. SpotIndex) or "Сигил"
	ui.HudText(title, "Relapse22", x + pad, y + pad + ui.Grid15(), ui.Col.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)

	local btn = rowH
	local yRow = y + pad + ui.Grid15(2)
	local mx, my = gui.MousePos()
	for i = 1, #SPECS do
		local spec = SPECS[i]
		AddHit(x, yRow, w, rowH, "drag", spec)
		local plusX = x + w - pad - btn
		local minusX = plusX - gap - btn
		AddHit(minusX, yRow, btn, rowH, "minus", spec)
		AddHit(plusX, yRow, btn, rowH, "plus", spec)

		local hot = Clicker and mx >= x and my >= yRow and mx <= x + w and my <= yRow + rowH
		if hot then
			ui.RoundFill(ui.RadPx("Card"), x + gap, yRow, w - gap * 2, rowH, ui.Col.CardHover)
		end
		ui.RoundFill(ui.RadPx("Button"), minusX, yRow, btn, rowH, ui.Col.Card)
		ui.RoundFill(ui.RadPx("Button"), plusX, yRow, btn, rowH, ui.Col.Card)

		local ink = Clicker and ui.Col.Text or ui.Col.Muted
		ui.HudText(spec.label, "Relapse15", x + pad, yRow + rowH * 0.5, ink, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
		ui.HudText(string.format("%.2f", ReadSpec(spec)), "Relapse15", minusX - gap, yRow + rowH * 0.5, ui.Col.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1)
		ui.HudText("-", "Relapse22", minusX + btn * 0.5, yRow + rowH * 0.5, ui.Col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
		ui.HudText("+", "Relapse22", plusX + btn * 0.5, yRow + rowH * 0.5, ui.Col.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
		yRow = yRow + rowH + gap
	end

	AddHit(x, yRow, w, rowH, "copy")
	local copyHot = Clicker and mx >= x and my >= yRow and mx <= x + w and my <= yRow + rowH
	if copyHot then
		ui.RoundFill(ui.RadPx("Card"), x + gap, yRow, w - gap * 2, rowH, ui.Col.CardHover)
	end
	ui.HudText("Копировать", "Relapse15", x + pad, yRow + rowH * 0.5, Clicker and ui.Col.Text or ui.Col.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)
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
			if hit.kind == "copy" then
				CopyPose()
			elseif hit.kind == "minus" then
				WriteSpec(hit.spec, ReadSpec(hit.spec) - hit.spec.step)
			elseif hit.kind == "plus" then
				WriteSpec(hit.spec, ReadSpec(hit.spec) + hit.spec.step)
			else
				Drag = { spec = hit.spec, startX = mx, startVal = ReadSpec(hit.spec) }
			end
		elseif not InCard(mx, my) then
			local dir = util.AimVector(Ang, LocalPlayer():GetFOV(), mx, my, ScrW(), ScrH())
			dir:Normalize()
			GrabPicked(PickTarget(Pos, dir))
		end
	elseif not down then
		Drag = nil
	end
	MouseWasDown = down
end

local function LeaveCam()
	if not Active then return end
	gui.HideGameUI()
	Disable()
end

local function ToggleClicker()
	local now = RealTime()
	if now - LastE < 0.18 then return end
	LastE = now
	SetClicker(not Clicker)
end

local function DrawViewer(pl)
	return Pos:DistToSqr(pl:EyePos()) > NEAR_BODY_SQR
end

hook.Add("PlayerBindPress", "RelapseSigilDev", function(pl, bind, pressed)
	if pl ~= LocalPlayer() or not pressed then return end
	if bind == "cancelselect" and Active then
		LeaveCam()
		return true
	end
	if bind == "+use" and Armed and not Active and RelapseSigilSpotsShown and RelapseSigilSpotsShown() then
		local eye = pl:EyePos()
		local dir = pl:EyeAngles():Forward()
		local pick = PickTarget(eye, dir)
		if pick and pick.kind == "spot" then
			net.Start("zs_sigildev_grab")
				net.WriteUInt(pick.data, 8)
			net.SendToServer()
			return true
		end
	end
	if not Active then return end
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

hook.Add("PlayerButtonDown", "RelapseSigilDev", function(pl, button)
	if pl ~= LocalPlayer() then return end
	if not IsFirstTimePredicted() then return end
	if button == KEY_ESCAPE and Active then
		LeaveCam()
		return
	end
	if not Active then return end
	if button == KEY_E then
		ToggleClicker()
	end
end)

hook.Add("OnPauseMenuShow", "RelapseSigilDev", function()
	if not Active then return end
	LeaveCam()
	return false
end)

hook.Add("InputMouseApply", "RelapseSigilDev", function(cmd, x, y, ang)
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

hook.Add("CreateMove", "RelapseSigilDev", function(cmd)
	if not Active then return end

	if Clicker then
		WishF, WishS, WishU = 0, 0, 0
		WishSprint = false
	else
		WishF = cmd:GetForwardMove()
		WishS = cmd:GetSideMove()
		WishU = 0
		local buttons = cmd:GetButtons()
		if bit.band(buttons, IN_JUMP) ~= 0 then WishU = WishU + 1 end
		if bit.band(buttons, IN_DUCK) ~= 0 then WishU = WishU - 1 end
		WishSprint = bit.band(buttons, IN_SPEED) ~= 0
	end

	cmd:ClearMovement()
	cmd:SetButtons(bit.band(cmd:GetButtons(), IN_SCORE))
	cmd:SetViewAngles(BodyAng)
	return true
end)

hook.Add("Think", "RelapseSigilDev", function()
	if not Active then return end

	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() or pl:GetObserverMode() ~= OBS_MODE_NONE then
		Disable()
		return
	end
	if not IsValid(Sigil) and not EditingSpot() then
		Disable()
		return
	end

	HandleMouse()

	if Drag then
		if not input.IsMouseDown(MOUSE_LEFT) then
			Drag = nil
		else
			local spec = Drag.spec
			local step = input.IsKeyDown(KEY_LSHIFT) and spec.fine or spec.drag
			WriteSpec(spec, Drag.startVal + (gui.MouseX() - Drag.startX) * step)
		end
	end

	if PushAt > 0 and RealTime() >= PushAt then
		PushAt = 0
		Push()
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

hook.Add("CalcView", "RelapseSigilDev", function(pl, origin, angles, fov, znear, zfar)
	if not Active or pl ~= LocalPlayer() then return end
	return {
		origin = Pos,
		angles = Ang,
		fov = fov,
		znear = znear,
		zfar = zfar,
		drawviewer = DrawViewer(pl),
	}
end)

hook.Add("ShouldDrawLocalPlayer", "RelapseSigilDev", function(pl)
	if not Active or pl ~= LocalPlayer() then return end
	return DrawViewer(pl)
end)

hook.Add("HUDPaint", "RelapseSigilDev", function()
	if not Armed or not RelapseUI then return end
	RelapseUI.CreateFonts()

	if not Active then
		local hint = (RelapseSigilSpotsShown and RelapseSigilSpotsShown()) and "Использование на сигиле или точке — полёт" or "Использование на сигиле — полёт"
		RelapseUI.HudText(hint, "Relapse22", ScrW() * 0.5, ScrH() - RelapseUI.Grid15(4), RelapseUI.Col.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
		return
	end

	PaintCard()
	local key = RelapseHint and RelapseHint.BindLabel and RelapseHint.BindLabel("+use") or "E"
	local text = Clicker and (key .. " — полёт") or (key .. " — курсор")
	RelapseUI.HudText(text, "Relapse22", ScrW() * 0.5, ScrH() - RelapseUI.Grid15(4), RelapseUI.Col.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
end)

hook.Add("PostDrawTranslucentRenderables", "RelapseSigilDev", function(depth, sky)
	if depth or sky or not Active or (not IsValid(Sigil) and not EditingSpot()) then return end
	local col = RelapseUI and RelapseUI.Col and RelapseUI.Col.Text or Color(208, 211, 214)
	local base = EditPos
	render.DrawLine(base, base + Vector(0, 0, 120), col, true)
end)
