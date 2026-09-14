INC_CLIENT()

SWEP.ViewModelFOV = 75

function SWEP:DrawHUD()
	if GetConVar("crosshair"):GetInt() ~= 1 then return end
	self:DrawCrosshairDot()
end
