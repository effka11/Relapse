-- MW prompts that sat under the crosshair. Firemode name stays hidden.
-- Drawn on the top row of the Relapse HUD. MW's own draw is silenced.

local empty = function() end

local LINE = "Relapse20"
-- Relapse20 hangs ~5px above caps and under the baseline.
local LINE_HANG = 5
local SEP = "   –   "

local function Silence(wep)
	if not wep then return end
	if wep.DrawFiremode ~= empty then
		wep.DrawFiremode = empty
	end
	if wep.DrawCommands ~= empty then
		wep.DrawCommands = empty
	end
	if wep.Crosshair and wep.Crosshair ~= empty then
		wep.Crosshair = empty
	end
	if wep.DrawCrosshairSticks and wep.DrawCrosshairSticks ~= empty then
		wep.DrawCrosshairSticks = empty
	end
	wep.DrawCrosshair = false
end

local function IsMW(class)
	return class and (class == "mg_base" or weapons.IsBasedOn(class, "mg_base"))
end

local function SilenceStored()
	Silence(weapons.GetStored("mg_base"))
	for _, wep in ipairs(weapons.GetList()) do
		if IsMW(wep.ClassName) then
			Silence(weapons.GetStored(wep.ClassName))
		end
	end
end

hook.Add("Initialize", "RelapseHideMWFiremode", SilenceStored)
hook.Add("InitPostEntity", "RelapseHideMWFiremode", function()
	SilenceStored()
	local ply = LocalPlayer()
	if IsValid(ply) then
		Silence(ply:GetActiveWeapon())
	end
end)

hook.Add("PlayerSwitchWeapon", "RelapseHideMWFiremode", function(ply, oldWep, newWep)
	if ply ~= LocalPlayer() then return end
	Silence(newWep)
end)

local function KeyLabel(bind)
	local name
	local lead = string.sub(bind or "", 1, 1)
	if lead == "+" or lead == "-" or bind == "impulse 100" then
		name = input.LookupBinding(bind)
	elseif mw_input and mw_input.GetBindKeyString then
		local ok, got = pcall(mw_input.GetBindKeyString, bind)
		if ok then
			name = got
		end
	end
	if not name or name == "" then return end
	return string.upper(name)
end

local function Prompt(bind, id)
	local action = RelapseUI.T(id)
	local key = KeyLabel(bind)
	if key then
		return key .. SEP .. action
	end
	return action
end

local function Prompts(wep)
	local list = {}
	local aim = wep.GetAimDelta and wep:GetAimDelta() or 0
	if aim > 0.5 and wep.GetHybrid and wep:GetHybrid() then
		list[#list + 1] = Prompt("switchsights", "hud_switch_sights")
	end

	if aim > 0.5 and wep.GetSight then
		local sight = wep:GetSight()
		local breath = GetConVar("mgbase_sv_breathing")
		local mode = wep.GetAimModeDelta and wep:GetAimModeDelta() or 0
		local thresh = wep.m_hybridSwitchThreshold or 0
		local owner = wep:GetOwner()
		if sight and sight.Optic and mode <= thresh and IsValid(owner) and not owner:KeyDown(IN_SPEED) and breath and breath:GetInt() > 0 then
			list[#list + 1] = Prompt("+speed", "hud_hold_breath")
		end
	end

	if wep.GetFlashlightAttachment and wep:GetFlashlightAttachment() then
		list[#list + 1] = Prompt("impulse 100", "hud_flashlight")
	end
	return list
end

local function BannerUp()
	local pan = GAMEMODE and GAMEMODE.WaveNotifyHUD
	return IsValid(pan) and pan:IsVisible() and pan:GetAlpha() > 12
end

local function FontH(font)
	surface.SetFont(font)
	local _, h = surface.GetTextSize("Ay")
	return h
end

-- Glyph bottom of the previous line + one cell → glyph top of the next.
local function NextY(prevY, prevH, prevBot, nextTop)
	return prevY + prevH - RelapseUI.sPx(prevBot) + RelapseUI.Grid15() - RelapseUI.sPx(nextTop)
end

hook.Add("HUDPaint", "RelapseFiremode", function()
	local gm = GAMEMODE
	if not gm or gm.FilmMode or gm.RelapseFreecamActive then return end
	if not RelapseUI or not RelapseUI.HudText or not RelapseUI.Col then return end

	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() or pl:InVehicle() then return end
	local wep = pl:GetActiveWeapon()
	if not IsValid(wep) or not IsMW(wep:GetClass()) then return end
	Silence(wep)
	if BannerUp() then return end
	if wep.HasFlag and (wep:HasFlag("Holstering") or wep:HasFlag("Customizing")) then return end

	local prompts = Prompts(wep)
	if #prompts == 0 then return end

	RelapseUI.CreateFonts()
	local x = math.floor(ScrW() * 0.5 + 0.5)
	local y = RelapseUI.sPx(45) - RelapseUI.sPx(LINE_HANG)
	local shadow = 1
	local lineH = FontH(LINE)

	for i = 1, #prompts do
		RelapseUI.HudText(prompts[i], LINE, x, y, RelapseUI.Col.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, shadow)
		y = NextY(y, lineH, LINE_HANG, LINE_HANG)
	end
end)
