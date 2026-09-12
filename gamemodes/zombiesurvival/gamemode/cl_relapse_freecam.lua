-- Relapse spectator / noclip (client). V flies a local-only camera: no entity,
-- so other players and bots cannot see or chase it. B asks the server for real
-- MOVETYPE_NOCLIP. WASD / jump / duck fly the hidden camera; the pawn stays.

local Active = false
local Pos = Vector()
local Ang = Angle()
local BodyAng = Angle()
local SpeedMul = 1
local WishF, WishS, WishU = 0, 0, 0
local WishSprint = false
local LastToggle = 0

local SPEED = 900
local SPEED_FAST = 2200
local NEAR_BODY_SQR = 16 * 16

function GM:IsRelapseFreecam()
	return Active
end

local function Disable()
	if not Active then return end
	Active = false
	GAMEMODE.RelapseFreecamActive = false
	WishF, WishS, WishU = 0, 0, 0
end

local function Enable()
	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() then return end

	Pos:Set(pl:EyePos())
	Ang:Set(pl:EyeAngles())
	Ang.r = 0
	BodyAng:Set(pl:EyeAngles())
	Active = true
	GAMEMODE.RelapseFreecamActive = true
end

local function CanRequest()
	local pl = LocalPlayer()
	if IsValid(pl) and pl:IsTyping() then return false end
	if gui.IsConsoleVisible() then return false end

	local now = RealTime()
	if now - LastToggle < 0.12 then return false end
	LastToggle = now
	return true
end

local function RequestToggle()
	if not CanRequest() then return end
	net.Start("zs_relapse_freecam")
	net.SendToServer()
end

local function RequestNoclip()
	if not CanRequest() then return end
	net.Start("zs_relapse_noclip")
	net.SendToServer()
end

net.Receive("zs_relapse_freecam", function()
	if net.ReadBool() then
		Enable()
	else
		Disable()
	end
end)

local function DrawViewer(pl)
	return Pos:DistToSqr(pl:EyePos()) > NEAR_BODY_SQR
end

hook.Add("PlayerBindPress", "RelapseFreecam", function(pl, bind, pressed, code)
	if not pressed then return end

	if code == KEY_B then
		return true
	end

	if bind == "noclip" then
		RequestToggle()
		return true
	end

	if not Active then return end

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

hook.Add("PlayerButtonDown", "RelapseFreecam", function(pl, button)
	if pl ~= LocalPlayer() then return end
	if not IsFirstTimePredicted() then return end
	if button == KEY_V then
		RequestToggle()
	elseif button == KEY_B then
		RequestNoclip()
	end
end)

hook.Add("InputMouseApply", "RelapseFreecam", function(cmd, x, y, ang)
	if not Active then return end

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

hook.Add("CreateMove", "RelapseFreecam", function(cmd)
	if not Active then return end

	WishF = cmd:GetForwardMove()
	WishS = cmd:GetSideMove()
	WishU = 0
	local buttons = cmd:GetButtons()
	if bit.band(buttons, IN_JUMP) ~= 0 then WishU = WishU + 1 end
	if bit.band(buttons, IN_DUCK) ~= 0 then WishU = WishU - 1 end
	WishSprint = bit.band(buttons, IN_SPEED) ~= 0

	cmd:ClearMovement()
	cmd:SetButtons(bit.band(buttons, IN_SCORE))
	cmd:SetViewAngles(BodyAng)
	return true
end)

hook.Add("Think", "RelapseFreecam", function()
	if not Active then return end

	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() or pl:GetObserverMode() ~= OBS_MODE_NONE then
		Disable()
		return
	end

	if pl:IsTyping() or gui.IsConsoleVisible() or gui.IsGameUIVisible() then return end

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

hook.Add("CalcView", "RelapseFreecam", function(pl, origin, angles, fov, znear, zfar)
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

hook.Add("ShouldDrawLocalPlayer", "RelapseFreecam", function(pl)
	if not Active or pl ~= LocalPlayer() then return end
	return DrawViewer(pl)
end)

hook.Add("HUDPaint", "RelapseFreecam", function()
	if not Active then return end
	local text = translate.Get("relapse_freecam_hint")
	draw.SimpleText(text, "ZSHUDFontSmaller", ScrW() * 0.5, ScrH() * 0.9, Color(200, 200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

---------------------------------------------------------------------------
-- Player x-ray
---------------------------------------------------------------------------

local matXRay = Material("models/debug/debugwhite")
local DrawingXRay = false

-- Overlay DrawModel runs PrePlayerDraw; skip class hooks that hide wraiths.
hook.Add("PrePlayerDraw", "RelapseFreecamXRay", function()
	if DrawingXRay then return false end
end)

hook.Add("PostPlayerDraw", "RelapseFreecamXRay", function()
	if DrawingXRay then return true end
end)

local function DrawXRayEnt(ent)
	if IsValid(ent) then
		ent:SetupBones()
		ent:DrawModel()
	end
end

hook.Add("PostDrawTranslucentRenderables", "RelapseFreecamXRay", function(depth, skybox)
	if depth or skybox or not Active then return end

	local me = LocalPlayer()
	if not IsValid(me) then return end

	cam.IgnoreZ(true)
	render.SuppressEngineLighting(true)
	render.ModelMaterialOverride(matXRay)
	render.SetBlend(0.82)

	DrawingXRay = true
	for _, pl in ipairs(player.GetAll()) do
		if not IsValid(pl) or not pl:Alive() or pl:GetObserverMode() ~= OBS_MODE_NONE then continue end
		if pl == me and not DrawViewer(me) then continue end

		local undead = pl:Team() == TEAM_UNDEAD
		local maxhp = undead and pl.GetMaxZombieHealth and pl:GetMaxZombieHealth() or pl:GetMaxHealth()
		local hp = math.Clamp(pl:Health() / math.max(maxhp, 1), 0, 1)
		if undead then
			render.SetColorModulation(0.35 + 0.65 * hp, 0.04 + 0.08 * hp, 0.02)
		else
			render.SetColorModulation(0.05, 0.35 + 0.65 * hp, 1)
		end

		DrawXRayEnt(pl)
		DrawXRayEnt(pl.status_overridemodel)

		for _, child in ipairs(pl:GetChildren()) do
			if IsValid(child) and child:GetClass() == "relapse_bot_visual" then
				DrawXRayEnt(child)
			end
		end
	end
	DrawingXRay = false

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.ModelMaterialOverride()
	render.SuppressEngineLighting(false)
	cam.IgnoreZ(false)
end)
