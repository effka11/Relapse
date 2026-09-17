AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.DisableDuplicator = true
ENT.PhysgunDisabled = true
ENT.IgnoreMelee = true
ENT.IgnoreBullets = true
ENT.IgnoreTraces = true
ENT.RelapseLadderClip = true

function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "BoxMins")
	self:NetworkVar("Vector", 1, "BoxMaxs")
	self:NetworkVar("Vector", 2, "Inward")
	self:NetworkVar("Vector", 3, "AxisCenter")
	self:NetworkVar("Vector", 4, "AxisRadii")
	self:NetworkVar("Float", 0, "AxisRadius")
end

function ENT:InitClip()
	if self.ClipReady then return true end
	local mins, maxs = self:GetBoxMins(), self:GetBoxMaxs()
	if not mins or not maxs then return false end
	if mins:LengthSqr() + maxs:LengthSqr() < 1 then return false end

	self:SetCollisionBounds(mins, maxs)
	self:SetSolid(SOLID_BBOX)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:CollisionRulesChanged()
	self.ClipReady = true
	return true
end

function ENT:Initialize()
	self:SetModel("models/error.mdl")
	self:DrawShadow(false)
	self:SetNoDraw(true)
	self:SetCustomCollisionCheck(true)
	self:InitClip()
	if not self.ClipReady then
		timer.Simple(0, function()
			if IsValid(self) then self:InitClip() end
		end)
		timer.Simple(0.25, function()
			if IsValid(self) then self:InitClip() end
		end)
	end
end

function ENT:ShouldNotCollide(ent)
	if not IsValid(ent) then return true end
	if ent:IsPlayer() then
		if ent:GetMoveType() == MOVETYPE_NOCLIP then return true end
		-- Seated on this strip: stacked slabs through a floor cell still
		-- kiss the hull. Do not open other faces or walking.
		if ent.RelapseLadderHold or ent:GetNW2Bool("RelapseLadderHold", false) then
			local clip = ent.RelapseLadderClipEnt
			if not IsValid(clip) and ent.GetNW2Entity then
				clip = ent:GetNW2Entity("RelapseLadderClip")
			end
			if clip == self then return true end
			local same = GAMEMODE and GAMEMODE.RelapseLadderSameStrip
			if same and IsValid(clip) and same(clip, self) then return true end
		end
		return false
	end
	if ent.IgnoreBullets or ent:IsWeapon() then return true end
	return false
end
