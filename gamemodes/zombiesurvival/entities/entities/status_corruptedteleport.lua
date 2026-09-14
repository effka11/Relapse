AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "status_sigilteleport"

ENT.ParticleMaterial = "particle/smokesprites_0001"

function ENT:SetParticleColor(particle)
	local c = RelapseUI.Col.Danger
	particle:SetColor(c.r, c.g, c.b)
end
