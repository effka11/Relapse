-- Idle breath for SWEPs that are not MW. MW already adds RelapseBreath.IdleAngle
-- through GetBreathingSwayAngle -> Camera.LerpBreathing.

function GM:ApplyRelapseIdleBreath(pl, angles)
	if not isangle(angles) then return end
	if not IsValid(pl) or not pl:Alive() then return end
	if pl:Team() ~= TEAM_HUMAN then return end
	if pl:GetObserverMode() ~= OBS_MODE_NONE then return end
	if pl:ShouldDrawLocalPlayer() then return end
	if not RelapseBreath or not RelapseBreath.IdleAngle then return end

	local wep = pl:GetActiveWeapon()
	if not IsValid(wep) then return end
	if isfunction(wep.GetBreathingSwayAngle) then return end

	angles:Add(RelapseBreath.IdleAngle(wep, pl))
end
