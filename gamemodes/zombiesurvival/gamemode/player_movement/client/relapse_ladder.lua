-- Billboard on an ellipse around the ladder AABB, so a flat ladder stays
-- flat. Direction is atan2 to the player; center is sticky.

local USE = 104
-- Shorter band from fully visible down to invisible at the oval.
local FADE_OUT = 40
local LEAVE_PAD = 32
local MERGE = 96
local colHint = Color(0, 0, 0, 255)
local fontReady
local stick

local function EnsureFont()
	if fontReady then return end
	fontReady = true
	surface.CreateFont("RelapseLadderHint", {
		font = "Manrope",
		size = 48,
		weight = 500,
		antialias = true,
		extended = true,
		shadow = false,
		outline = false,
	})
end

local function WallBlocks(pl, dest)
	local eye = pl:EyePos()
	local dx, dy, dz = dest.x - eye.x, dest.y - eye.y, dest.z - eye.z
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len < 12 then return false end
	local tr = util.TraceLine({
		start = eye,
		endpos = Vector(dest.x - dx / len * 8, dest.y - dy / len * 8, dest.z - dz / len * 8),
		mask = MASK_SOLID_BRUSHONLY,
		filter = function(ent)
			return ent == pl or (IsValid(ent) and ent.RelapseLadderClip)
		end,
	})
	-- Ignore grazes at the dest (ladder wall). A real blocker is mid-trace.
	return tr.Hit and not tr.HitSky and tr.Fraction < 0.8
end

local function EllipseReach(c, s, rx, ry)
	local a = (c * c) / (rx * rx) + (s * s) / (ry * ry)
	if a <= 1e-8 then return math.max(rx, ry) end
	return 1 / math.sqrt(a)
end

-- Opacity 0-1 from gap outside the oval. gap<=0 (on/inside) is 0.
-- Far: 0. Mid: 1. Oval: 0. Fade-out to the oval is shorter than fade-in.
local function HintAlpha(gap, useR)
	if gap <= 0 or gap >= useR then return 0 end
	local peak = FADE_OUT
	if peak > useR * 0.45 then peak = useR * 0.45 end
	if peak < 16 then peak = 16 end
	if gap <= peak then
		local t = gap / peak
		return t * (2 - t)
	end
	local t = (useR - gap) / (useR - peak)
	if t < 0 then return 0 end
	if t > 1 then return 1 end
	return t
end

local function ClipAxis(ent)
	local ac = ent.GetAxisCenter and ent:GetAxisCenter()
	local ar = ent.GetAxisRadii and ent:GetAxisRadii()
	local oval = GAMEMODE and GAMEMODE.RelapseLadderOvalRadii
	local hx, hy = 0, 0
	if ar then
		hx, hy = ar.x, ar.y
	end
	if (hx < 1 and hy < 1) then
		local r = ent.GetAxisRadius and ent:GetAxisRadius() or 0
		hx, hy = r, r * 0.3
	end
	local rx, ry
	if oval then
		rx, ry = oval(hx, hy)
	else
		rx, ry = hx + 16, hy + 16
	end
	if ac and (ac.x ~= 0 or ac.y ~= 0) then
		return ac.x, ac.y, rx, ry
	end
	local p = ent:GetPos()
	return p.x, p.y, rx, ry
end

local function ClipZ(ent)
	local wm, wx = ent:WorldSpaceAABB()
	if wm and wx and wx.z > wm.z + 8 then
		return wm.z, wx.z
	end
	local pos = ent:GetPos()
	local mins = ent.GetBoxMins and ent:GetBoxMins()
	local maxs = ent.GetBoxMaxs and ent:GetBoxMaxs()
	if mins and maxs then
		return pos.z + mins.z, pos.z + maxs.z
	end
	return pos.z - 32, pos.z + 32
end

local function UseKeyLabel()
	local bind = input.LookupBinding("+use")
	if not bind or bind == "" then return "E" end
	return string.upper(bind)
end

local function PlayerHalf(pl)
	if pl.GetHull then
		local mins, maxs = pl:GetHull()
		if mins and maxs then
			return math.max(32, (maxs.z - mins.z) * 0.5)
		end
	end
	return 36
end

local function Clusters()
	local list = ents.FindByClass("relapse_ladder_clip")
	local clusters = {}
	for i = 1, #list do
		local ent = list[i]
		if IsValid(ent) then
			local x, y, rx, ry = ClipAxis(ent)
			local zmin, zmax = ClipZ(ent)
			local merged
			for c = 1, #clusters do
				local cl = clusters[c]
				local dx, dy = cl.x - x, cl.y - y
				if dx * dx + dy * dy < MERGE * MERGE then
					cl.n = cl.n + 1
					cl.sx = cl.sx + x
					cl.sy = cl.sy + y
					if zmin < cl.zmin then cl.zmin = zmin end
					if zmax > cl.zmax then cl.zmax = zmax end
					if rx >= 8 and ry >= 8 then
						cl.axisn = cl.axisn + 1
						cl.ax = cl.ax + x
						cl.ay = cl.ay + y
						if rx > cl.rx then cl.rx = rx end
						if ry > cl.ry then cl.ry = ry end
					end
					merged = true
					break
				end
			end
			if not merged then
				clusters[#clusters + 1] = {
					x = x, y = y,
					rx = math.max(rx, 16), ry = math.max(ry, 16),
					zmin = zmin, zmax = zmax,
					sx = x, sy = y, n = 1,
					ax = (rx >= 8) and x or 0, ay = (rx >= 8) and y or 0,
					axisn = (rx >= 8 and ry >= 8) and 1 or 0,
				}
			end
		end
	end
	for c = 1, #clusters do
		local cl = clusters[c]
		if cl.axisn > 0 then
			cl.x = cl.ax / cl.axisn
			cl.y = cl.ay / cl.axisn
		else
			cl.x = cl.sx / cl.n
			cl.y = cl.sy / cl.n
		end
		if cl.rx < 16 then cl.rx = 16 end
		if cl.ry < 16 then cl.ry = 16 end
	end
	return clusters
end

local function Dist2(x1, y1, x2, y2)
	local dx, dy = x1 - x2, y1 - y2
	return math.sqrt(dx * dx + dy * dy)
end

local function StickReach(st)
	return math.max(st.rx, st.ry)
end

hook.Add("PostDrawTranslucentRenderables", "RelapseLadderHint", function(depth, sky)
	if sky or depth then return end
	if render.GetRenderTarget() then return end
	local GM = GAMEMODE
	if not GM or GM.FilmMode then return end
	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() then return end
	if pl:GetMoveType() == MOVETYPE_NOCLIP then return end
	if pl:Team() ~= TEAM_HUMAN and pl:Team() ~= TEAM_UNDEAD then return end
	if GM.RelapseLadderUseBlocked and GM:RelapseLadderUseBlocked(pl) then return end

	local ppos = pl:GetPos()
	local useR = (GM.RelapseLadderUseRadius or USE)

	if stick then
		if Dist2(ppos.x, ppos.y, stick.x, stick.y) > StickReach(stick) + useR + LEAVE_PAD then
			stick = nil
		end
	end
	if not stick then
		local best, bestD
		local clusters = Clusters()
		for i = 1, #clusters do
			local cl = clusters[i]
			local d = Dist2(ppos.x, ppos.y, cl.x, cl.y)
			if d <= math.max(cl.rx, cl.ry) + useR and (not bestD or d < bestD) then
				best, bestD = cl, d
			end
		end
		if not best then return end
		stick = {x = best.x, y = best.y, rx = best.rx, ry = best.ry, zmin = best.zmin, zmax = best.zmax}
	end

	if pl.RelapseLadderHold or pl:GetNW2Bool("RelapseLadderHold", false) then
		return
	end

	-- Same range as E: do not start the hint before the player can seat.
	local clipDist = GM.RelapseLadderUseDist and GM:RelapseLadderUseDist(pl)
	if not clipDist or clipDist > useR then return end

	local dx, dy = ppos.x - stick.x, ppos.y - stick.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < 1 then return end
	local c, s = dx / dist, dy / dist
	local reach = EllipseReach(c, s, stick.rx, stick.ry)
	local gap = dist - reach
	-- Outer edge of the fade is the E sphere, not oval+useR.
	local outer = gap + (useR - clipDist)
	if outer < FADE_OUT + 8 then outer = FADE_OUT + 8 end
	local alpha = HintAlpha(gap, outer)
	if alpha <= 0.02 then return end

	-- Follow player mid-height, but never more than half a player above/below the ladder.
	local z = pl:WorldSpaceCenter().z
	local half = PlayerHalf(pl)
	if stick.zmin and stick.zmax then
		local zLo, zHi = stick.zmin - half, stick.zmax + half
		if z < zLo then z = zLo elseif z > zHi then z = zHi end
	end
	local drawAt = Vector(
		stick.x + c * (reach + 2),
		stick.y + s * (reach + 2),
		z
	)
	if WallBlocks(pl, drawAt) then return end

	local txt = translate.Format("press_e_to_climb_ladder", UseKeyLabel())
	if not txt or txt == "" then return end

	local look = EyePos()
	if look:DistToSqr(drawAt) < 36 then return end

	local ang = (look - drawAt):Angle()
	ang:RotateAroundAxis(ang:Right(), 270)
	ang:RotateAroundAxis(ang:Up(), 90)

	local col = RelapseUI and RelapseUI.Col and RelapseUI.Col.Text
	colHint.r = col and col.r or 220
	colHint.g = col and col.g or 220
	colHint.b = col and col.b or 220
	colHint.a = math.floor(alpha * 255 + 0.5)

	EnsureFont()
	local fog = render.GetFogMode()
	cam.IgnoreZ(true)
	render.FogMode(0)
	cam.Start3D2D(drawAt, ang, 0.05)
	surface.SetAlphaMultiplier(alpha)
	draw.SimpleText(txt, "RelapseLadderHint", 0, 0, colHint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	surface.SetAlphaMultiplier(1)
	cam.End3D2D()
	render.FogMode(fog)
	cam.IgnoreZ(false)
end)

hook.Remove("Think", "RelapseLadderStepHint")
if RelapseHint and RelapseHint.Registry and RelapseHint.Registry.ladder_step then
	RelapseHint.Registry.ladder_step:Hide()
end
--[[ Step-off HUD hint (E onto a landing). Leave is jump toward the camera.
hook.Add("Think", "RelapseLadderStepHint", function()
	if not RelapseHint then return end
	local hint = RelapseHint.New("ladder_step")
	hint:SetBind("+use")
	hint:SetOrder(10)
	hint:SetText(translate and translate.Get("hint_step_off") or "Step off")

	local pl = LocalPlayer()
	if not IsValid(pl) or not pl:Alive() then
		hint:Hide()
		return
	end
	local hold = pl.RelapseLadderHold or pl:GetNW2Bool("RelapseLadderHold", false)
	local blocked = GAMEMODE and GAMEMODE.RelapseLadderUseBlocked and GAMEMODE:RelapseLadderUseBlocked(pl)
	local can = hold and not blocked and (pl.RelapseLadderCanStep or pl:GetNW2Bool("RelapseLadderCanStep", false))
	if can then
		hint:Show()
	else
		hint:Hide()
	end
end)
]]
