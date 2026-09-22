ENT.Type = "anim"
ENT.Base = "prop_baseoutlined"

ENT.NoNails = true

function ENT:HumanHoldable(pl)
	if pl:KeyDown(GAMEMODE.UtilityKey) then return true end
	if not pl:HasWeapon(self:GetWeaponType()) then return false end
	-- GetClip1 is server-only. Unknown clips are not an empty husk.
	if not self.GetClip1 then return false end
	return self:GetClip1() == 0 and self:GetClip2() == 0
end

function ENT:IsMWWeaponType(class)
	class = class or self:GetWeaponType()
	if not isstring(class) or class == "" then return false end
	if class == "mg_base" or string.sub(class, 1, 3) == "mg_" then return true end
	return weapons.IsBasedOn and weapons.IsBasedOn(class, "mg_base")
end

-- Shop LocalAng roll 90 = mesh along model +Z (SCAR). Identity = along +X (PKM).
-- Physics stays a floor pancake (thin Z, yaw only). Rolling the physbox stands
-- the +Z mesh back up: the engine rests on the largest face.
function ENT:DroppedPreviewLocalAng(weptab)
	weptab = weptab or weapons.Get(self:GetWeaponType())
	if istable(weptab) and isangle(weptab.RelapsePreviewLocalAng) then
		return weptab.RelapsePreviewLocalAng
	end
	local gm = GAMEMODE or GM
	local def = gm and gm.RelapseWeapons and gm.RelapseWeapons[self:GetWeaponType()]
	if def and isangle(def.PreviewLocalAng) then
		return def.PreviewLocalAng
	end
	return nil
end

function ENT:DroppedHullAlongZ(weptab)
	if not self:IsMWWeaponType() then
		return false
	end
	local la = self:DroppedPreviewLocalAng(weptab)
	-- Explicit +X hull: shop did not roll the preview.
	if isangle(la) and math.abs(la.r) < 45 and math.abs(la.p) < 45 then
		return false
	end
	return true
end

function ENT:DroppedLootLocalAng(weptab)
	local ang = Angle(0, 0, 0)
	-- Identity: Forward +X, Left +Y, Up +Z. Barrel left first, then 90 around
	-- that barrel so the mag faces the player — not the sky.
	local fwd = Vector(1, 0, 0)
	local left = Vector(0, 1, 0)
	if self:DroppedHullAlongZ(weptab) then
		ang:RotateAroundAxis(fwd, -90)
	else
		ang:RotateAroundAxis(vector_up, 90)
	end
	ang:RotateAroundAxis(left, -90)
	return ang
end

function ENT:DroppedLootPlacement(weptab)
	-- Same angle as the drawn mesh. Shift so that mesh sits on the phys box:
	-- the model origin is not the gun center, so a bare rotate lifts it into the air.
	local mins, maxs = self:GetModelBounds()
	local ang = self:DroppedLootLocalAng(weptab)
	if not mins or not maxs or (maxs.x - mins.x) + (maxs.y - mins.y) + (maxs.z - mins.z) < 8 then
		return Vector(-22, -10, -4), Vector(22, 10, 4), vector_origin
	end

	local minv = Vector(math.huge, math.huge, math.huge)
	local maxv = Vector(-math.huge, -math.huge, -math.huge)
	local xs = {mins.x, maxs.x}
	local ys = {mins.y, maxs.y}
	local zs = {mins.z, maxs.z}
	for ix = 1, 2 do
		for iy = 1, 2 do
			for iz = 1, 2 do
				local p = LocalToWorld(Vector(xs[ix], ys[iy], zs[iz]), angle_zero, vector_origin, ang)
				if p.x < minv.x then minv.x = p.x end
				if p.y < minv.y then minv.y = p.y end
				if p.z < minv.z then minv.z = p.z end
				if p.x > maxv.x then maxv.x = p.x end
				if p.y > maxv.y then maxv.y = p.y end
				if p.z > maxv.z then maxv.z = p.z end
			end
		end
	end

	local center = (minv + maxv) * 0.5
	local h = (maxv - minv) * 0.5
	h.x = h.x + 2
	h.y = h.y + 2
	-- Thin on local Z (world up: the prop only yaws). A tall box stands the gun up.
	-- At least 10 tall so the eye trace meets the receiver, not the floor under it.
	if h.z > math.min(h.x, h.y) then
		h.z = 6
	else
		h.z = math.max(h.z, 6) + 2
	end
	return Vector(-h.x, -h.y, -h.z), Vector(h.x, h.y, h.z), -center
end

function ENT:DroppedLootLocalPos(weptab)
	local _, _, shift = self:DroppedLootPlacement(weptab)
	return shift
end

function ENT:DroppedWeaponBox(weptab, class)
	if self:IsMWWeaponType(class) then
		local mins, maxs = self:DroppedLootPlacement(weptab)
		return mins, maxs
	end
	if istable(weptab) and weptab.BoxPhysicsMax then
		return weptab.BoxPhysicsMin or Vector(-12, -8, -6), weptab.BoxPhysicsMax
	end
	return Vector(-10, -10, -8), Vector(10, 10, 8)
end

function ENT:DropLieAngles(yaw)
	return Angle(0, tonumber(yaw) or 0, 0)
end

function ENT:ApplyDroppedBodygroups(weptab, target)
	if not istable(weptab) then return end
	target = target or self
	local groups = weptab.RelapsePreviewBodygroups
	if not istable(groups) then return end
	for k, v in pairs(groups) do
		if isnumber(k) and isnumber(v) then
			target:SetBodygroup(k, v)
		end
	end
end

function ENT:SetWeaponType(class)
	self:SetDTString(0, class or "")

	if string.sub(class or "", 1, 12) == "weapon_zs_t_" then -- Convertor
		if SERVER then
			self:MakeInvItemConvert(class)
		end
		return
	end

	local weptab = weapons.Get(class)
	if not weptab then return end

	if weptab.WorldModel then
		self:SetModel(weptab.WorldModel)
	end

	if weptab.ModelScale then
		self:SetModelScale(weptab.ModelScale, 0)
	end

	self:ApplyDroppedBodygroups(weptab)

	if SERVER then
		self:SetupPhysics(weptab, class)
	end
end

function ENT:GetWeaponType()
	return self:GetDTString(0)
end
