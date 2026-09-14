AddCSLuaFile()

DEFINE_BASECLASS(SWEP.Base or "mg_base")

SWEP.Melee = true

SWEP.Primary.Sound = ""
SWEP.Primary.Ammo = "None"
SWEP.Primary.ClipSize = -1
SWEP.Primary.Automatic = true
SWEP.Secondary.Automatic = false
SWEP.Primary.BurstRounds = 1
SWEP.Primary.BurstDelay = 0
SWEP.Primary.RPM = 600
SWEP.CanChamberRound = false

SWEP.Firemodes = {
	[1] = {
		Name = "",
		OnSet = function()
			return nil
		end
	}
}

SWEP.Cone = {
	Hip = 0.5,
	Ads = 0.5,
	Increase = 0,
	AdsMultiplier = 1,
	Max = 1.5,
	Decrease = 1,
	Seed = 0,
}

SWEP.Recoil = {
	Vertical = {0, 0},
	Horizontal = {0, 0},
	Shake = 0,
	AdsMultiplier = 0,
	Seed = 0,
}

SWEP.Zoom = {
	FovMultiplier = 1,
	ViewModelFovMultiplier = 1,
	Blur = {
		EyeFocusDistance = 15
	}
}

function SWEP:CanAim()
	return false
end

SWEP.MeleeSurfaceTypes = {
	Flesh = {
		"flesh",
		"bloodyflesh",
		"alienflesh",
		"watermelon",
	},
	Cement = {
		"tile",
		"glass",
		"concrete",
		"rock",
		"porcelain",
		"boulder",
		"brick",
		"ice",
		"plaster",
		"plastic",
	},
	Metal = {
		"solidmetal",
		"Metal_Box",
		"metal",
		"metal_bouncy",
		"slipperymetal",
		"metalgrate",
		"metalvent",
		"metalpanel",
		"ladder",
		"chainlink",
		"chain",
	},
	Soft = {
		"dirt",
		"mud",
		"slipperyslime",
		"grass",
		"slime",
		"quicksand",
		"gravel",
		"snow",
		"carpet",
		"cardboard",
		"sand",
		"rubber",
	},
	Wood = {
		"Wood",
		"Wood_lowdensity",
		"Wood_Box",
		"Wood_Crate",
		"Wood_Plank",
		"Wood_Solid",
		"Wood_Furniture",
		"Wood_Panel",
		"woodladder",
	},
}

SWEP.MeleeWorldMatTypes = {
	[MAT_ANTLION] = "Flesh",
	[MAT_BLOODYFLESH] = "Flesh",
	[MAT_FLESH] = "Flesh",
	[MAT_ALIENFLESH] = "Flesh",
	[MAT_CONCRETE] = "Cement",
	[MAT_EGGSHELL] = "Cement",
	[MAT_PLASTIC] = "Cement",
	[MAT_TILE] = "Cement",
	[MAT_GLASS] = "Cement",
	[MAT_GRATE] = "Metal",
	[MAT_METAL] = "Metal",
	[MAT_COMPUTER] = "Metal",
	[MAT_VENT] = "Metal",
	[MAT_DIRT] = "Soft",
	[MAT_SNOW] = "Soft",
	[MAT_SAND] = "Soft",
	[MAT_FOLIAGE] = "Soft",
	[MAT_SLOSH] = "Soft",
	[MAT_GRASS] = "Soft",
	[MAT_WOOD] = "Wood",
}
for sub, tbl in pairs(SWEP.MeleeSurfaceTypes) do
	for _, mat in ipairs(tbl) do
		SWEP.MeleeWorldMatTypes[mat] = sub
	end
end

SWEP.MeleeSounds = {
	-- Flesh = "MW_Melee.Flesh_Small",
	-- Cement = "",
	-- Metal = "",
	-- Soft = "",
	-- Wood = "",
}

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	if owner:IsPlayer() and not owner:KeyDown(IN_ATTACK) then return end
	self:TrySetTask("Melee")
end
function SWEP:SecondaryAttack()
	local owner = self:GetOwner()

	if IsValid(owner) and (not owner:IsPlayer() or owner:KeyPressed(IN_ATTACK2)) then
		if not self:TrySetTaskAndCheck("Melee_Heavy_In") then
			self:TrySetTask("Melee")
		end
	end
end

-- Melee viewmodel camera bone is applied 1:1 to the eye. Scale it down so a
-- slash does not roll the whole view.
if CLIENT then
	function SWEP:CalcView(ply, pos, ang, fov)
		local origPos = Vector(pos)
		local origAng = Angle(ang)
		local p, a, f = BaseClass.CalcView(self, ply, pos, ang, fov)
		if not isvector(p) then
			return pos, ang, fov
		end
		local scale = self.RelapseMeleeCameraScale or 0.10
		if scale >= 1 then
			return p, a, f
		end
		return LerpVector(scale, origPos, p), LerpAngle(scale, origAng, a), f
	end
end

if SERVER then
	function SWEP:GetCapabilities()
		return CAP_WEAPON_MELEE_ATTACK1
	end
end
