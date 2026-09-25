INC_CLIENT()

ENT.Dinged = true

function ENT:Initialize()
	self:ApplyOpenCrate()
	self:KillModelCollision()
	self:SetRenderBounds(Vector(-72, -72, -72), Vector(72, 72, 128))
end

function ENT:SetObjectHealth(health)
	self:SetDTFloat(0, health)
end

local aOffset = Angle(0, 90, 90)
local aOffset2 = Angle(0, 270, 90)
local vOffsetEE = Vector(-15, 0, 8)

local STEP = 15
local NUM_SIZE = 60
local MARK_SIZE = 45
local NAME_SIZE = 45
local NUM_TOP = -60
local NAME_TOP = 15
local COL_NUM = Color(255, 255, 255)
local fontsReady = false

local function EnsureCrateFonts()
	if fontsReady then return end
	fontsReady = true
	surface.CreateFont("RelapseCrateNum", {
		font = "Manrope",
		size = NUM_SIZE,
		weight = 500,
		antialias = true,
		extended = true
	})
	surface.CreateFont("RelapseCrateMark", {
		font = "Manrope",
		size = MARK_SIZE,
		weight = 500,
		antialias = true,
		extended = true
	})
	surface.CreateFont("RelapseCrateName", {
		font = "Manrope",
		size = NAME_SIZE,
		weight = 400,
		antialias = true,
		extended = true
	})
end

function ENT:Think()
	if MySelf:IsValid() and MySelf:Team() == TEAM_HUMAN then
		local nextuse = GAMEMODE.ResupplyNext or 0
		if nextuse <= 0 then
			self.Dinged = true
		elseif self.Dinged then
			if CurTime() < nextuse then
				self.Dinged = false
			end
		elseif CurTime() >= nextuse then
			self.Dinged = true

			self:EmitSound("zombiesurvival/ding.ogg")
		end
	end

	self:ApplyOpenCrate()
	self:KillModelCollision()
	self:NextThink(CurTime())
	return true
end

local function MaxDigitWidth()
	local w = 0
	for d = 0, 9 do
		local dw = surface.GetTextSize(tostring(d))
		if dw > w then w = dw end
	end
	return w
end

local function DrawCell(text, right, y, col)
	draw.SimpleText(text, "RelapseCrateNum", right, y, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

function ENT:RenderInfo(pos, ang, owner)
	EnsureCrateFonts()

	local remain = math.max(0, (GAMEMODE.ResupplyNext or 0) - CurTime())
	local secs = math.ceil(remain)
	local charges = math.max(0, GAMEMODE.ResupplyCharges or 0)
	local mins = math.floor(secs / 60)
	local minStr = tostring(mins)
	local secStr = string.format("%02d", secs % 60)
	local numStr = tostring(charges)

	surface.SetFont("RelapseCrateMark")
	local markW = surface.GetTextSize("x")
	surface.SetFont("RelapseCrateNum")
	local digit = MaxDigitWidth()
	local colon = surface.GetTextSize(":")
	local markGap = 5
	local gap = STEP * 3
	local numCells = 2
	local chargeSlot = digit * numCells
	local groupW = chargeSlot + markGap + markW
	local timerSlot = digit + colon + digit * 2
	local left = -math.floor((groupW + gap + timerSlot) * 0.5) - 13
	local numRight = left + chargeSlot
	local colonX = left + groupW + gap + digit
	local markY = NUM_TOP
	if RelapseUI and RelapseUI.ManropeBaseline then
		markY = RelapseUI.ManropeBaseline(NUM_TOP, NUM_SIZE) - RelapseUI.ManropeBaseline(0, MARK_SIZE)
	end

	local muted = RelapseUI and RelapseUI.Col and RelapseUI.Col.Muted or Color(114, 116, 118)
	local numCol = charges == 0 and (RelapseUI and RelapseUI.Col and RelapseUI.Col.Danger or Color(116, 38, 52)) or COL_NUM
	local rightBear = 0
	if RelapseUI and RelapseUI.ManropeDigitEdges then
		local _, rb = RelapseUI.ManropeDigitEdges(numStr:sub(-1), NUM_SIZE, true)
		rightBear = rb or 0
	end
	local markX = numRight + markGap

	cam.Start3D2D(pos, ang, 0.08)
		draw.SimpleText(numStr, "RelapseCrateNum", numRight + rightBear, NUM_TOP, numCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText("x", "RelapseCrateMark", markX, markY, numCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local minX = colonX
		for i = #minStr, 1, -1 do
			minX = minX - digit
			DrawCell(minStr:sub(i, i), minX + digit, NUM_TOP, muted)
		end
		DrawCell(":", colonX + colon, NUM_TOP, muted)
		draw.SimpleText(secStr, "RelapseCrateNum", colonX + colon, NUM_TOP, muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if owner:IsValid() and owner:IsPlayer() then
			draw.SimpleText(owner:ClippedName(), "RelapseCrateName", -13, NAME_TOP, muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	cam.End3D2D()
end

function ENT:Draw()
	self:DrawModel()

	if not MySelf:IsValid() or MySelf:Team() ~= TEAM_HUMAN then return end

	local owner = self:GetObjectOwner()
	local ang = self:LocalToWorldAngles(aOffset)
	local scale = self:GetModelScale()
	if not scale or scale <= 0 then scale = 1 end
	local mins, maxs = self:GetModelBounds()
	local zMid = maxs.z * scale * 0.5

	self:RenderInfo(self:LocalToWorld(Vector(mins.x * scale - 1, 0, zMid)), self:LocalToWorldAngles(aOffset2), owner)

	cam.Start3D2D(self:LocalToWorld(vOffsetEE), ang, 0.01)

		draw.SimpleText("ur a faget", "ZS3D2DFont2", 0, 0, color_white, TEXT_ALIGN_CENTER)

	cam.End3D2D()
end

net.Receive("zs_resupplystock", function()
	GAMEMODE.ResupplyCharges = net.ReadUInt(16)
	GAMEMODE.ResupplyNext = net.ReadFloat()
end)

net.Receive("zs_nextresupplyuse", function(length)
	MySelf.NextUse = net.ReadFloat()
end)

net.Receive("zs_stowagecaches", function(length)
	MySelf.StowageCaches = net.ReadInt(8)
end)
