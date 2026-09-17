-- Client loadout bar: keys 1-9, eat HL2 slots, draw from server list.

GM.RelapseLoadout = GM.RelapseLoadout or {}
GM.RelapseBag = GM.RelapseBag or {}
GM.RelapseLoadoutSlot = nil
GM.RelapseLoadoutHolstered = true

local IgnoreUseUntil = 0

---------------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------------

local function ApplyInvHUD()
	local hud = GAMEMODE.InvHUD
	if hud and hud:IsValid() and hud.ApplyLoadout then
		hud:ApplyLoadout()
	end
end

net.Receive("relapse_loadout", function()
	local n = GAMEMODE.RelapseLoadoutMax or 9
	local list = {}
	for i = 1, n do
		local class = net.ReadString()
		if class ~= "" then
			list[i] = class
		end
	end
	local slot = net.ReadUInt(4)
	GAMEMODE.RelapseLoadout = list
	GAMEMODE.RelapseLoadoutSlot = slot > 0 and slot or nil
	local holstered = net.ReadBool()
	local drew = GAMEMODE.RelapseLoadoutHolstered and not holstered
	GAMEMODE.RelapseLoadoutHolstered = holstered

	local bagN = GAMEMODE.RelapseInvBagSlots or 9
	local bag = {}
	local kindWep = GAMEMODE.RelapseInvKindWep or 1
	local kindInv = GAMEMODE.RelapseInvKindInv or 2
	local kindAmmo = GAMEMODE.RelapseInvKindAmmo or 3
	for i = 1, bagN do
		local kind = net.ReadUInt(2)
		if kind == kindWep then
			bag[i] = { t = "wep", id = net.ReadString() }
		elseif kind == kindInv then
			bag[i] = { t = "inv", id = net.ReadString() }
		elseif kind == kindAmmo then
			bag[i] = { t = "ammo", id = net.ReadString() }
		end
	end
	GAMEMODE.RelapseBag = bag

	ApplyInvHUD()
	if GAMEMODE.RefreshRelapseGameInv then
		GAMEMODE:RefreshRelapseGameInv()
	end
	if drew then
		local hud = GAMEMODE.InvHUD
		if hud and hud:IsValid() and hud.Pulse then
			hud:Pulse()
		end
	end
end)

net.Receive("relapse_loadout_use", function()
	local class = net.ReadString()
	if RealTime() < IgnoreUseUntil then return end

	local gm = GAMEMODE
	local lp = LocalPlayer()
	if not IsValid(lp) or not class or not gm.RelapseSelectWeapon then return end
	if not lp:HasWeapon(class) then return end

	local cur = lp:GetActiveWeapon()
	if IsValid(cur) and cur:GetClass() ~= class then
		if not (gm.IsHumanUnarmedWeapon and gm:IsHumanUnarmedWeapon(cur:GetClass())) then
			return
		end
	end

	gm:RelapseSelectWeapon(lp, class)
end)

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

local function InputBlocked()
	local focus = vgui.GetKeyboardFocus()
	if IsValid(focus) then return true end
	if gui.IsGameUIVisible and gui.IsGameUIVisible() then return true end
	return false
end

local LastPress = 0
local LastSlot
local LastFrame

local function SendPress(slot)
	if not slot then return end

	local frame = FrameNumber()
	if LastFrame == frame then return end

	local now = RealTime()
	if slot == LastSlot and now - LastPress < 0.18 then return end

	local gm = GAMEMODE
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local list = gm.RelapseLoadout or {}
	local class = list[slot]
	local active = lp:GetActiveWeapon()
	local activeClass = IsValid(active) and active:GetClass() or nil
	local holster = false
	if not class then
		holster = activeClass ~= nil and not (gm.IsHumanUnarmedWeapon and gm:IsHumanUnarmedWeapon(activeClass))
	else
		holster = activeClass == class
	end

	LastFrame, LastPress, LastSlot = frame, now, slot
	if holster then
		IgnoreUseUntil = now + 0.6
	end

	local target = holster and gm.HumanUnarmedWeapon or class
	if target and gm.RelapseSelectWeapon then
		gm:RelapseSelectWeapon(lp, target)
	end

	net.Start("relapse_loadout_press")
		net.WriteUInt(slot, 4)
		net.WriteBool(holster)
	net.SendToServer()
	local hud = gm.InvHUD
	if hud and hud:IsValid() and hud.Pulse then
		hud:Pulse()
	end
end

function GM:RelapseLoadoutBindPress(pl, bind, wasin)
	if not IsValid(pl) or pl:Team() ~= TEAM_HUMAN then return false end

	if string.sub(bind, 1, 4) == "slot" then
		return true
	end

	if bind == "lastinv" then
		return true
	end

	if not wasin then return false end

	if bind == "invnext" or bind == "invprev" then
		local list = self.RelapseLoadout or {}
		local cur = self.RelapseLoadoutSlot or 1
		local nextSlot = self:RelapseLoadoutStepSlot(list, cur, bind == "invnext" and 1 or -1)
		if nextSlot then
			SendPress(nextSlot)
		end
		return true
	end

	return false
end

local KeyDown = {}

hook.Add("PlayerButtonDown", "RelapseLoadout", function(pl, button)
	if not IsValid(pl) or pl ~= LocalPlayer() then return end
	if pl:Team() ~= TEAM_HUMAN or not pl:Alive() then return end
	if InputBlocked() then return end
	if button < KEY_1 or button > KEY_9 then return end
	if KeyDown[button] then return end
	KeyDown[button] = true
	SendPress(button - KEY_1 + 1)
end)

hook.Add("PlayerButtonUp", "RelapseLoadout", function(pl, button)
	if not IsValid(pl) or pl ~= LocalPlayer() then return end
	KeyDown[button] = nil
end)
