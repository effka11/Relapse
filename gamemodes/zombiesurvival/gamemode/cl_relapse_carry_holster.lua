-- Current MW Base draws via entity mg_viewmodel (RENDERGROUP_VIEWMODEL),
-- not SWEP:PostDrawViewModel. That entity's owner is the weapon.

local function ShouldHolster()
	local ply = LocalPlayer()
	if not IsValid(ply) then return false end
	if GAMEMODE and GAMEMODE.HideViewModels then return true end
	if ply.ShouldHolsterWeaponViewModel then
		return ply:ShouldHolsterWeaponViewModel()
	end
	return false
end

local function WrapDraw(tbl)
	if not tbl or tbl.RelapseCarryHolsterDraw or not isfunction(tbl.Draw) then return end

	tbl.RelapseCarryHolsterDraw = true
	local oldDraw = tbl.Draw
	tbl.Draw = function(self, flags)
		if ShouldHolster() then return end
		return oldDraw(self, flags)
	end

	if isfunction(tbl.DrawTranslucent) then
		local oldTrans = tbl.DrawTranslucent
		tbl.DrawTranslucent = function(self, flags)
			if ShouldHolster() then return end
			return oldTrans(self, flags)
		end
	end
end

local function WrapStored()
	local stored = scripted_ents.GetStored("mg_viewmodel")
	if not stored or not stored.t then return false end

	WrapDraw(stored.t)
	return stored.t.RelapseCarryHolsterDraw
end

local function WrapEntity(ent)
	if not IsValid(ent) then return end
	if ent:GetClass() ~= "mg_viewmodel" then return end
	WrapDraw(ent)
end

hook.Add("InitPostEntity", "RelapseCarryHolsterMWVM", function()
	WrapStored()
	for _, ent in ipairs(ents.FindByClass("mg_viewmodel")) do
		WrapEntity(ent)
	end
end)

hook.Add("OnEntityCreated", "RelapseCarryHolsterMWVM", function(ent)
	timer.Simple(0, function()
		WrapEntity(ent)
	end)
end)

hook.Add("Think", "RelapseCarryHolsterMWVM", function()
	if WrapStored() then
		hook.Remove("Think", "RelapseCarryHolsterMWVM")
	end
end)

local wasHolstered = false

hook.Add("PreDrawViewModels", "RelapseCarryHolsterVM", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local holster = ShouldHolster()
	local wep = ply:GetActiveWeapon()

	if holster then
		if not wasHolstered then
			ply:DrawViewModel(false)
			wasHolstered = true
		end

		if IsValid(wep) then
			WrapEntity(wep.GetViewModel and wep:GetViewModel())
		end
		return
	end

	if wasHolstered then
		ply:DrawViewModel(true)
		wasHolstered = false

		if IsValid(wep) then
			if wep.PlayViewModelAnimation then
				wep:PlayViewModelAnimation("Draw")
			else
				wep:SendWeaponAnim(ACT_VM_DRAW)
			end
		end
	end
end)

hook.Add("PreDrawPlayerHands", "RelapseCarryHolsterHands", function()
	if ShouldHolster() then return true end
end)
