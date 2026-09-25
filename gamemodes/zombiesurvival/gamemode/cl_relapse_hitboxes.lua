-- relapse_hitboxes: wire the collision of nearby props and deployables.

local enabled = false

local COL_PROP = Color(208, 211, 214)
local COL_DEPLOY = Color(116, 38, 52)
local REACH = 1600
local REACH_SQR = REACH * REACH
local MAX_TRIS = 800

local HITBOX_CLASS = {
	prop_resupplybox_hit = true,
	prop_deployablehitbox = true,
}

local function VertPos(v)
	if isvector(v) then return v end
	if istable(v) then return v.pos end
end

local function IsDeployableClass(class)
	local info = GAMEMODE.DeployableInfo
	return info ~= nil and info[class] ~= nil
end

local function HitboxKind(ent)
	local class = ent:GetClass()
	if not class or string.sub(class, 1, 7) == "status_" then return end
	if class == "prop_obj_sigil" or class == "prop_prop_blocker" then return end

	if string.sub(class, 1, 12) == "prop_physics" or string.sub(class, 1, 12) == "func_physbox" then
		return "prop"
	end

	if IsDeployableClass(class) or ent.IsBarricadeObject or HITBOX_CLASS[class] or string.sub(class, 1, 11) == "prop_hitbox_" then
		return "deploy"
	end

	local parent = ent:GetParent()
	if IsValid(parent) and IsDeployableClass(parent:GetClass()) then
		return "deploy"
	end
end

local function DrawMesh(phys, col)
	local ok, convexes = pcall(phys.GetMeshConvexes, phys)
	if not ok or not convexes then return false end

	local tris = 0
	for i = 1, #convexes do
		tris = tris + math.floor(#convexes[i] / 3)
	end
	if tris <= 0 or tris > MAX_TRIS then return false end

	for i = 1, #convexes do
		local convex = convexes[i]
		for v = 1, #convex - 2, 3 do
			local a = VertPos(convex[v])
			local b = VertPos(convex[v + 1])
			local c = VertPos(convex[v + 2])
			if a and b and c then
				a = phys:LocalToWorld(a)
				b = phys:LocalToWorld(b)
				c = phys:LocalToWorld(c)
				render.DrawLine(a, b, col, false)
				render.DrawLine(b, c, col, false)
				render.DrawLine(c, a, col, false)
			end
		end
	end

	return true
end

local function DrawHitbox(ent, kind)
	local col = kind == "deploy" and COL_DEPLOY or COL_PROP
	if ent:GetClass() == "prop_resupplybox_hit" then
		local mins, maxs = ent:GetModelBounds()
		if mins and maxs then
			render.DrawWireframeBox(ent:GetPos(), ent:GetAngles(), mins, maxs, col, false)
		end
		return
	end

	local count = ent:GetPhysicsObjectCount() or 0
	local drew = false

	for i = 0, count - 1 do
		local phys = ent:GetPhysicsObjectNum(i)
		if IsValid(phys) and DrawMesh(phys, col) then
			drew = true
		end
	end
	if drew then return end
	if ent:GetSolid() == SOLID_NONE then return end

	local mins, maxs = ent:GetCollisionBounds()
	if not mins or not maxs or mins:DistToSqr(maxs) <= 1 then return end
	render.DrawWireframeBox(ent:GetPos(), ent:GetAngles(), mins, maxs, col, false)
end

hook.Add("PostDrawTranslucentRenderables", "RelapseHitboxes", function(depth, sky)
	if not enabled or depth or sky then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	-- After the sigil glow. Opaque-pass lines sit under that sprite and vanish while you stand next to it.
	cam.IgnoreZ(true)
	render.SetColorMaterialIgnoreZ()

	local origin = ply:EyePos()
	for _, ent in ipairs(ents.FindInSphere(origin, REACH)) do
		if ent ~= ply and ent:GetPos():DistToSqr(origin) <= REACH_SQR then
			local kind = HitboxKind(ent)
			if kind then
				DrawHitbox(ent, kind)
			end
		end
	end

	cam.IgnoreZ(false)
end)

concommand.Add("relapse_hitboxes", function(_, _, args)
	local arg = args[1]
	if arg == "0" then
		enabled = false
	elseif arg == "1" then
		enabled = true
	else
		enabled = not enabled
	end
	print(enabled and "relapse_hitboxes: on" or "relapse_hitboxes: off")
end)
