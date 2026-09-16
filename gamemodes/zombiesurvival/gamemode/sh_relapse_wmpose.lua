-- Relapse worldmodel pose binds. Stock sits on the shoulder bone, muzzle on
-- the palm. Extra Pos/Ang are a post-solve in the barrel frame. Session table
-- is networked so every client draws the same hold.

GM.RelapseWMBinds = GM.RelapseWMBinds or {}

GM.RelapseWMPoseBone = {
	Stock = "ValveBiped.Bip01_R_Clavicle",
	Palm = "ValveBiped.Bip01_R_Hand"
}

function GM:RelapseWMBindCopy(src)
	src = src or {}
	return {
		Pos = Vector(src.Pos or vector_origin),
		Ang = Angle(src.Ang or angle_zero),
		Stock = Vector(src.Stock or vector_origin),
		Palm = Vector(src.Palm or vector_origin)
	}
end

function GM:RelapseWMBindClamp(b)
	b = self:RelapseWMBindCopy(b)
	local function ClampVec(v)
		v.x = math.Clamp(v.x, -128, 128)
		v.y = math.Clamp(v.y, -128, 128)
		v.z = math.Clamp(v.z, -128, 128)
		return v
	end
	b.Pos = ClampVec(b.Pos)
	b.Stock = ClampVec(b.Stock)
	b.Palm = ClampVec(b.Palm)
	b.Ang.p = math.Clamp(math.NormalizeAngle(b.Ang.p), -180, 180)
	b.Ang.y = math.Clamp(math.NormalizeAngle(b.Ang.y), -180, 180)
	b.Ang.r = math.Clamp(math.NormalizeAngle(b.Ang.r), -180, 180)
	return b
end

function GM:RelapseWMBindWrite(b)
	b = self:RelapseWMBindClamp(b)
	net.WriteVector(b.Pos)
	net.WriteAngle(b.Ang)
	net.WriteVector(b.Stock)
	net.WriteVector(b.Palm)
end

function GM:RelapseWMBindRead()
	return self:RelapseWMBindClamp({
		Pos = net.ReadVector(),
		Ang = net.ReadAngle(),
		Stock = net.ReadVector(),
		Palm = net.ReadVector()
	})
end

function GM:RelapseWMBindGet(class)
	if not class or class == "" then return end
	local row = self.RelapseWMBinds[class]
	if not row then return end
	return self:RelapseWMBindCopy(row)
end

function GM:RelapseWMBindSet(class, bind)
	if not class or class == "" then return end
	self.RelapseWMBinds[class] = self:RelapseWMBindClamp(bind)
	return self.RelapseWMBinds[class]
end
