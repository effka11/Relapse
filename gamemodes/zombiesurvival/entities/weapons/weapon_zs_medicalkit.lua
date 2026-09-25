AddCSLuaFile()

SWEP.PrintName = "Medkit"
SWEP.TranslationName = "wep_medkit"
SWEP.TranslationDescription = "wep_medkit_desc"
SWEP.Description = "A field kit. One charge restores 25 health at once, on you or on someone within reach. Then eight seconds. Charges are medical supplies."
SWEP.Slot = 4
SWEP.SlotPos = 0

if CLIENT then
	SWEP.ViewModelFOV = 57
	SWEP.ViewModelFlip = false

	-- HL2 bob and sway would stack on the 1911 viewmodel motion below.
	SWEP.BobScale = 0
	SWEP.SwayScale = 0
end

SWEP.Base = "weapon_zs_base"

SWEP.WorldModel = "models/weapons/w_medkit.mdl"
SWEP.ViewModel = "models/weapons/c_medkit.mdl"
SWEP.UseHands = true

-- One claw is about 35. A charge covers the flesh of an armored hit and
-- leaves an unarmored claw standing. AllyPointBonus is the point payout of
-- one full charge on someone else: less than the 2.5-point cost of a charge
-- bought at 5 points for 2, so healing does not print points.
SWEP.Heal = 25
SWEP.AllyPointBonus = 3
SWEP.Primary.Delay = 8

-- Charges live in the reserve. A clip would be handed out by EmptyAll on purchase.
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Ammo = "battery"

SWEP.Secondary.ClipSize = 1
SWEP.Secondary.DefaultClip = 1
SWEP.Secondary.Ammo = "dummy"

SWEP.WalkSpeed = SPEED_NORMAL

SWEP.HealRange = 36

SWEP.NoMagazine = true
SWEP.AllowQualityWeapons = true

SWEP.HoldType = "slam"

GAMEMODE:SetPrimaryWeaponModifier(SWEP, WEAPON_MODIFIER_HEALCOOLDOWN, -0.8)
GAMEMODE:AttachWeaponModifier(SWEP, WEAPON_MODIFIER_HEALRANGE, 4, 1)
GAMEMODE:AttachWeaponModifier(SWEP, WEAPON_MODIFIER_HEALING, 1.5)

function SWEP:Initialize()
	self:SetWeaponHoldType(self.HoldType)
	GAMEMODE:DoChangeDeploySpeed(self)
end

function SWEP:GetPrimaryAmmoCount()
	local owner = self:GetOwner()
	if not owner:IsValid() then return 0 end
	return owner:GetAmmoCount(self.Primary.Ammo)
end

function SWEP:GetCombinedPrimaryAmmo()
	return self:GetPrimaryAmmoCount()
end

function SWEP:TakeCombinedPrimaryAmmo(amount)
	local owner = self:GetOwner()
	if not owner:IsValid() then return end
	owner:RemoveAmmo(amount, self.Primary.Ammo)
end

function SWEP:Think()
	if self.IdleAnimation and self.IdleAnimation <= CurTime() then
		self.IdleAnimation = nil
		self:SendWeaponAnim(ACT_VM_IDLE)
	end
end

function SWEP:ApplyCharge(ent)
	if not self:CanPrimaryAttack() then return end

	local owner = self:GetOwner()
	if not (ent and ent:IsValidLivingHuman() and gamemode.Call("PlayerCanBeHealed", ent)) then return end

	local pointmul = 0
	if ent ~= owner and self.Heal > 0 then
		pointmul = (self.AllyPointBonus or 0) / self.Heal
	end
	local healed = owner:HealPlayer(ent, self.Heal, pointmul)
	if healed <= 0 then return end

	local cd = self.Primary.Delay * (self.MedicCooldownMul or 1)
	self:SetNextCharge(CurTime() + cd)
	owner.NextMedKitUse = self:GetNextCharge()
	self:TakeCombinedPrimaryAmmo(1)

	self:EmitSound(ent == owner and "items/smallmedkit1.wav" or "items/medshot4.wav")
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	owner:DoAttackEvent()
	self.IdleAnimation = CurTime() + self:SequenceDuration()
end

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	local trtbl = owner:CompensatedPenetratingMeleeTrace(self.HealRange, 2, nil, nil, true)
	local ent
	for _, tr in pairs(trtbl) do
		local test = tr.Entity
		if test and test:IsValidLivingHuman() and gamemode.Call("PlayerCanBeHealed", test) then
			ent = test
			break
		end
	end

	if not ent then return end
	self:ApplyCharge(ent)
end

function SWEP:SecondaryAttack()
	self:ApplyCharge(self:GetOwner())
end

function SWEP:Deploy()
	gamemode.Call("WeaponDeployed", self:GetOwner(), self)

	self.IdleAnimation = CurTime() + self:SequenceDuration()

	if CLIENT then
		hook.Add("PostPlayerDraw", "PostPlayerDrawMedical", GAMEMODE.PostPlayerDrawMedical)
		GAMEMODE.MedicalAura = true
	end

	return true
end

function SWEP:Holster()
	if CLIENT and self:GetOwner() == MySelf then
		hook.Remove("PostPlayerDraw", "PostPlayerDrawMedical")
		GAMEMODE.MedicalAura = false
	end

	return true
end

function SWEP:OnRemove()
	if CLIENT and self:GetOwner() == MySelf then
		hook.Remove("PostPlayerDraw", "PostPlayerDrawMedical")
		GAMEMODE.MedicalAura = false
	end
end

function SWEP:Reload()
end

function SWEP:SetNextCharge(tim)
	self:SetDTFloat(0, tim)
end

function SWEP:GetNextCharge()
	return self:GetDTFloat(0)
end

function SWEP:CanPrimaryAttack()
	local owner = self:GetOwner()
	if owner:IsHolding() or owner:GetBarricadeGhosting() then return false end

	if self:GetPrimaryAmmoCount() <= 0 then
		self:EmitSound("items/medshotno1.wav")

		self:SetNextCharge(CurTime() + 0.75)
		return false
	end

	return self:GetNextCharge() <= CurTime() and (owner.NextMedKitUse or 0) <= CurTime()
end

if not CLIENT then return end

-- Colt 1911 viewmodel. Idle offsets on that gun are zero, so the shared MW
-- springs are its whole procedural sway, and the walk is j_gun against tag_camera.
local PISTOL_VM = "models/viper/mw/weapons/v_m1911.mdl"

local function subAng(a, b)
	return Angle(
		math.AngleDifference(a.p, b.p),
		math.AngleDifference(a.y, b.y),
		math.AngleDifference(a.r, b.r)
	)
end

local function ensureMath()
	if mw_math and mw_math.CreateSpring then return true end
	pcall(require, "mw_math")
	return mw_math and mw_math.CreateSpring and true or false
end

function SWEP:DropSwayProxy()
	if IsValid(self.MedkitSwayProxy) then
		self.MedkitSwayProxy:Remove()
	end
	self.MedkitSwayProxy = nil
	self.MedkitGunRest = nil
	if self.MedkitSway then
		self.MedkitSway.gunHist = nil
	end
end

function SWEP:Holster(other)
	self:DropSwayProxy()
	local base = self.BaseClass
	if base and base.Holster then
		return base.Holster(self, other)
	end
	return true
end

function SWEP:OnRemove()
	self:DropSwayProxy()
	local base = self.BaseClass
	if base and base.OnRemove then
		base.OnRemove(self)
	end
end

local function swayState(self)
	if self.MedkitSway then return self.MedkitSway end
	if not ensureMath() then return nil end
	local s = {
		move = {
			x = mw_math.CreateSpring(150, 0.9),
			y = mw_math.CreateSpring(150, 0.9),
			z = mw_math.CreateSpring(150, 0.9),
		},
		sway = {
			p = mw_math.CreateSpring(150, 0.75),
			ya = mw_math.CreateSpring(120, 1),
			r = mw_math.CreateSpring(60, 0.85),
			x = mw_math.CreateSpring(145, 1),
			y = mw_math.CreateSpring(100, 1),
			z = mw_math.CreateSpring(150, 0.75),
		},
		breath = {
			p = mw_math.CreateSpring(100, 1),
			ya = mw_math.CreateSpring(100, 1),
		},
		offPos = mw_math.CreateVectorSpring(150, 1.5),
		offAng = {
			p = mw_math.CreateSpring(150, 0.75),
			ya = mw_math.CreateSpring(120, 1),
			r = mw_math.CreateSpring(100, 1.5),
		},
		lastZ = 0,
		land = 0,
		loco = 0,
		slowMin = 0,
		swayAng = nil,
		cPos = Vector(),
		cAng = Angle(),
		gunPos = Vector(),
		gunAng = Angle(),
		oPos = Vector(),
		oAng = Angle(),
	}
	self.MedkitSway = s
	return s
end

local function pistolProxy(self)
	if IsValid(self.MedkitSwayProxy) then return self.MedkitSwayProxy end
	if not util.IsValidModel(PISTOL_VM) then return nil end
	local ok, vm = pcall(ClientsideModel, PISTOL_VM, RENDERGROUP_OTHER)
	if not ok or not IsValid(vm) then return nil end
	vm:SetNoDraw(true)
	vm:DrawShadow(false)
	vm:SetPos(vector_origin)
	vm:SetAngles(angle_zero)
	local seq = vm:LookupSequence("idle")
	if not seq or seq < 0 then seq = 0 end
	vm:ResetSequence(seq)
	vm:SetCycle(0)
	vm:SetPlaybackRate(0)
	self.MedkitSwayProxy = vm
	self.MedkitGunRest = nil
	return vm
end

local function bonePair(vm)
	local camId = vm:LookupBone("tag_camera")
	local gunId = vm:LookupBone("j_gun")
	if not camId or not gunId then return end
	vm:InvalidateBoneCache()
	vm:SetupBones()
	local cam = vm:GetBoneMatrix(camId)
	local gun = vm:GetBoneMatrix(gunId)
	if not cam or not gun then return end
	local cp, gp = cam:GetTranslation(), gun:GetTranslation()
	return Vector(gp.x - cp.x, gp.y - cp.y, gp.z - cp.z), subAng(gun:GetAngles(), cam:GetAngles())
end

local function pose(vm, name, value)
	vm:SetPoseParameter(name, value)
end

local function stepPistol(self, owner, s)
	local vm = pistolProxy(self)
	if not vm then
		s.gunPos:SetUnpacked(0, 0, 0)
		s.gunAng:SetUnpacked(0, 0, 0)
		return
	end

	-- Keep the proxy in the player's leaf. A model under the map never refreshes bones.
	vm:SetPos(owner:EyePos())
	vm:SetAngles(angle_zero)
	pose(vm, "walk_loop", 0)
	pose(vm, "jog_loop", 0)
	pose(vm, "sprint_loop", 0)
	pose(vm, "super_sprint_loop", 0)
	pose(vm, "jog_offset", 0)
	pose(vm, "sprint_offset", 0)
	pose(vm, "super_sprint_offset", 0)

	if not self.MedkitGunRest then
		local pos, ang = bonePair(vm)
		if not pos or pos:LengthSqr() < 1 then return end
		self.MedkitGunRest = { pos = pos, ang = ang }
	end

	local vel = owner:GetVelocity()
	local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
	local walk = math.max(owner:GetWalkSpeed(), 1)
	local rft = RealFrameTime()
	local target = 0
	if owner:IsOnGround() then
		target = speed / walk
	end
	local rate = owner:IsOnGround() and 4 or 6
	s.loco = mw_math.SafeLerp(rate * rft, s.loco, target)

	local slowPoint = math.max(owner:GetSlowWalkSpeed() / walk, 0.01)
	local slow = 1 - math.abs(slowPoint - s.loco) / slowPoint
	slow = math.max(slow, s.slowMin or 0)
	local jog = s.loco - slow
	local run = math.max(owner:GetRunSpeed() / walk, 1.01)
	local sprint = math.Clamp((s.loco - 1) / (run - 1), 0, 1)
	local offset = s.loco * math.Clamp(1 - sprint, 0, 1)
	offset = (1 - math.cos(math.Clamp(offset, 0, 1) * math.pi)) * 0.5

	pose(vm, "walk_loop", math.min(slow, 1))
	pose(vm, "jog_loop", math.min(jog, 1))
	pose(vm, "sprint_loop", sprint)
	pose(vm, "jog_offset", offset)

	local pos, ang = bonePair(vm)
	local rest = self.MedkitGunRest
	if not pos or not rest then return end
	local rawPos = Vector(pos.x - rest.pos.x, pos.y - rest.pos.y, pos.z - rest.pos.z)
	local rawAng = subAng(ang, rest.ang)
	-- SetupBones holds the pose for the whole tick. Play the latest step across
	-- the next tick on the render clock, one sample behind, so it does not snap.
	local now = RealTime()
	local hist = s.gunHist
	if not hist then
		hist = {}
		s.gunHist = hist
	end
	if s.gunTick ~= CurTime() then
		s.gunTick = CurTime()
		hist[#hist + 1] = { t = now, pos = rawPos, ang = rawAng }
		if #hist > 3 then
			table.remove(hist, 1)
		end
	end
	local newest = hist[#hist]
	local prev = hist[#hist - 1]
	if not prev then
		s.gunPos:Set(newest.pos)
		s.gunAng:Set(newest.ang)
		return
	end
	local span = math.max(newest.t - prev.t, 0.001)
	local frac = math.Clamp((now - newest.t) / span, 0, 1)
	s.gunPos = LerpVector(frac, prev.pos, newest.pos)
	s.gunAng = LerpAngle(frac, prev.ang, newest.ang)
end

local function stepSprings(self, owner, ang, s)
	local rft = RealFrameTime()
	local vel = owner:GetVelocity()

	if not owner:IsOnGround() then
		s.lastZ = math.Clamp(vel.z * 0.003, -1, 1) * 2
		s.land = 0
	else
		if s.lastZ ~= 0 then
			s.land = -s.lastZ * 5
			s.lastZ = 0
		end
		s.land = mw_math.SafeLerp(20 * FrameTime(), s.land, 0)
	end

	s.move.z:SetTarget(s.lastZ + s.land)
	s.move.z:Decay()

	local walk = math.max(owner:GetWalkSpeed(), 1)
	local flat = Vector(vel.x / walk, vel.y / walk, 0)
	local moveAng = Angle(0, owner:EyeAngles().y, 0)
	local dotY = math.Clamp(-moveAng:Forward():Dot(flat), -1.25, 1.25)
	local dotX = math.Clamp(-moveAng:Right():Dot(flat), -1.25, 1.25)
	-- Sprint leans the pistol through its animation. The hip spring stays off, same as MW.
	if vel.x * vel.x + vel.y * vel.y > walk * walk * 1.1 then
		dotX, dotY = 0, 0
	end
	s.move.x:SetTarget(dotX)
	s.move.y:SetTarget(dotY)
	s.move.x:Decay()
	s.move.y:Decay()

	if not s.swayAng then
		s.swayAng = Angle(ang)
	end
	local diffY = math.AngleDifference(s.swayAng.y, ang.y)
	local diffP = math.AngleDifference(s.swayAng.p, ang.p)
	if rft > 0 then
		diffY = math.Clamp(diffY / rft * 0.01, -3, 3)
		diffP = math.Clamp(diffP / rft * 0.01, -3, 3)
	else
		diffY, diffP = 0, 0
	end
	s.slowMin = mw_math.SafeLerp(5 * rft, s.slowMin or 0, math.abs(diffY * 0.5))
	s.swayAng:Set(ang)

	s.sway.z:SetTarget(diffP * 0.75)
	s.sway.x:SetTarget(diffY)
	s.sway.y:SetTarget(diffY)
	s.sway.x:Decay()
	s.sway.y:Decay()
	s.sway.z:Decay()
	s.sway.p:SetTarget(diffP * 0.75)
	s.sway.ya:SetTarget(diffY)
	s.sway.r:SetTarget(diffY)
	s.sway.p:Decay()
	s.sway.ya:Decay()
	s.sway.r:Decay()

	local breath = angle_zero
	if RelapseBreath and RelapseBreath.IdleAngle then
		breath = RelapseBreath.IdleAngle(self, owner)
	end
	s.breath.p:SetTarget(breath.p * 0.25)
	s.breath.ya:SetTarget(breath.y * 0.25)
	s.breath.p:Decay()
	s.breath.ya:Decay()

	local live = rft > 0 and (1 / rft) >= 14
	if live then
		-- Hip: mouse sway is angle only. Position sway is an ADS term and stays at 0.
		local bx = s.breath.ya:GetValue()
		local by = s.breath.p:GetValue()
		s.cPos:SetUnpacked(s.move.x:GetValue() + bx * 0.5, s.move.y:GetValue(), -s.move.z:GetValue() + by * 0.5)
		s.cAng:SetUnpacked(s.move.z:GetValue() - s.sway.p:GetValue() - by, s.move.x:GetValue() + s.sway.ya:GetValue(), -s.sway.r:GetValue())
	else
		s.cPos:SetUnpacked(0, 0, 0)
		s.cAng:SetUnpacked(0, 0, 0)
	end

	local eyePitch = owner:EyeAngles().p / 90
	local ducked = owner:Crouching()
	local ox = ducked and -1 or 0
	local oy = (ducked and -0.5 or 0) + eyePitch
	local oz = ducked and -1 or 0
	local op = 0
	local oya = 0
	local oroll = (ducked and -5 or 0) + eyePitch * 5
	s.offPos:SetTarget(Vector(ox, oy, oz))
	s.offAng.p:SetTarget(op)
	s.offAng.ya:SetTarget(oya)
	s.offAng.r:SetTarget(oroll)
	mw_math.DecaySprings(s.offAng.p, s.offAng.ya, s.offAng.r, s.offPos)
	local ov = s.offPos:GetValue()
	s.oPos:SetUnpacked(ov.x, ov.y, ov.z)
	s.oAng:SetUnpacked(-s.offAng.p:GetValue(), s.offAng.ya:GetValue(), s.offAng.r:GetValue())
end

local function addLocal(pos, ang, localPos)
	pos:Add(ang:Right() * localPos.x)
	pos:Add(ang:Forward() * localPos.y)
	pos:Add(ang:Up() * localPos.z)
end

-- Shipped pose. The editor overrides these while relapse_viewmodel_dev is on.
local MEDKIT_POSE = {
	Stand = { x = 0.77, y = -1.15, z = -7.68 },
	Crouch = { x = 0.77, y = -1.15, z = -7.68 },
	Jump = { x = 0.77, y = -1.15, z = -7.68 },
	Walk = { x = 0.77, y = -1.15, z = -7.68 },
	Run = { x = 0.77, y = -1.15, z = -11.14 },
}

local function applyDevOffset(self, owner, pos, ang)
	local key = "Stand"
	if not owner:IsOnGround() then
		key = "Jump"
	elseif owner:Crouching() then
		key = "Crouch"
	else
		local vel = owner:GetVelocity()
		local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)
		local walk = math.max(owner:GetWalkSpeed(), 1)
		local run = math.max(owner:GetRunSpeed(), walk + 1)
		if speed >= (walk + run) * 0.5 then
			key = "Run"
		elseif speed > 8 then
			key = "Walk"
		end
	end

	local src = MEDKIT_POSE[key]
	local dev = RelapseUI and RelapseUI.ViewmodelDev
	if dev and dev.On and dev[key] then
		src = dev[key]
	end
	if not src then return pos, ang end
	local tx, ty, tz = src.x or 0, src.y or 0, src.z or 0

	local blend = self.MedkitDevBlend
	if not blend then
		blend = Vector(tx, ty, tz)
		self.MedkitDevBlend = blend
		self.MedkitDevFrame = FrameNumber()
	elseif self.MedkitDevFrame ~= FrameNumber() then
		self.MedkitDevFrame = FrameNumber()
		local k = 1 - math.exp(-RealFrameTime() / 0.14)
		blend.x = blend.x + (tx - blend.x) * k
		blend.y = blend.y + (ty - blend.y) * k
		blend.z = blend.z + (tz - blend.z) * k
	end

	pos = Vector(pos)
	addLocal(pos, ang, blend)
	return pos, ang
end

-- No base CalcViewModelView: it tilts the gun 30 degrees while barricade ghosting
-- (standing in the arsenal crate after a purchase), and the kit sits low enough
-- to leave the screen behind the camera. The kit has no ironsights to inherit.
function SWEP:CalcViewModelView(vm, oldpos, oldang, pos, ang)
	if not pos or not ang then return pos, ang end

	self.BobScale = 0
	self.SwayScale = 0

	local owner = self:GetOwner()
	if not IsValid(owner) then return pos, ang end

	ang = Angle(ang.p, ang.y, ang.r)
	if RelapseBreath and RelapseBreath.IdleAngle then
		ang:Add(RelapseBreath.IdleAngle(self, owner))
	end

	local s = swayState(self)
	if not s then return applyDevOffset(self, owner, pos, ang) end

	if self.MedkitSwayFrame ~= FrameNumber() then
		self.MedkitSwayFrame = FrameNumber()
		stepSprings(self, owner, ang, s)
		stepPistol(self, owner, s)
	end

	pos = Vector(pos)
	addLocal(pos, ang, s.cPos)
	ang:RotateAroundAxis(ang:Right(), s.cAng.p)
	ang:RotateAroundAxis(ang:Up(), s.cAng.y)
	ang:RotateAroundAxis(ang:Forward(), s.cAng.r)

	local gunWorld = LocalToWorld(s.gunPos, angle_zero, vector_origin, ang)
	pos:Add(gunWorld)
	ang:RotateAroundAxis(ang:Right(), s.gunAng.p)
	ang:RotateAroundAxis(ang:Up(), s.gunAng.y)
	ang:RotateAroundAxis(ang:Forward(), s.gunAng.r)

	addLocal(pos, ang, s.oPos)
	ang:RotateAroundAxis(ang:Right(), s.oAng.p)
	ang:RotateAroundAxis(ang:Up(), s.oAng.y)
	ang:RotateAroundAxis(ang:Forward(), s.oAng.r)

	return applyDevOffset(self, owner, pos, ang)
end

function SWEP:DrawWeaponSelection(x, y, w, h, alpha)
	self:BaseDrawWeaponSelection(x, y, w, h, alpha)
end

local texGradDown = surface.GetTextureID("VGUI/gradient_down")
function SWEP:DrawHUD()
	local wid, hei = 384, 16
	local x, y = ScrW() - wid - 32, ScrH() - hei - 72
	local texty = y - 4 - draw.GetFontHeight("ZSHUDFontSmall")
	local owner = self:GetOwner()

	local timeleft = (owner.NextMedKitUse or self:GetNextCharge()) - CurTime()
	if 0 < timeleft then
		surface.SetDrawColor(5, 5, 5, 180)
		surface.DrawRect(x, y, wid, hei)

		surface.SetDrawColor(50, 255, 50, 180)
		surface.SetTexture(texGradDown)
		surface.DrawTexturedRect(x, y, math.min(1, timeleft / self.Primary.Delay) * wid, hei)

		surface.SetDrawColor(50, 255, 50, 180)
		surface.DrawOutlinedRect(x, y, wid, hei)
	end

	draw.SimpleText(self.PrintName, "ZSHUDFontSmall", x, texty, COLOR_GREEN, TEXT_ALIGN_LEFT)

	local charges = self:GetPrimaryAmmoCount()
	if charges > 0 then
		draw.SimpleText(charges, "ZSHUDFontSmall", x + wid, texty, COLOR_GREEN, TEXT_ALIGN_RIGHT)
	else
		draw.SimpleText(charges, "ZSHUDFontSmall", x + wid, texty, COLOR_DARKRED, TEXT_ALIGN_RIGHT)
	end

	if GetConVar("crosshair"):GetInt() == 1 then
		self:DrawCrosshairDot()
	end
end
