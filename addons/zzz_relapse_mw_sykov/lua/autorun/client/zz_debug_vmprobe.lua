-- [DEBUG-vmp] Temporary probe: medkit viewmodel invisible until the first step.
-- Writes data/relapse_vmprobe.txt on the client. Delete this file after the fix.

local TARGET = "weapon_zs_medicalkit"
local OUT = "relapse_vmprobe.txt"

local rec
local lastActive
local flags = {}

local function r1(x) return math.floor(x * 10 + 0.5) / 10 end

local function safe(fn, ...)
	local res = { pcall(fn, ...) }
	if not res[1] then return "?" end
	local v = res[2]
	if v == nil then return "nil" end
	if isnumber(v) then return string.format("%.3f", v) end
	if IsEntity(v) then return IsValid(v) and v:GetClass() or "NULL" end
	return tostring(v)
end

local function vmState(lp, vm)
	if not IsValid(vm) then return "nil" end
	local seq = vm:GetSequence()
	local s = string.format("mdl=%s seq=%s(%s) cyc=%s rate=%s nodraw=%s mat=%s a=%s rm=%s wep=%s own=%s",
		safe(vm.GetModel, vm), safe(vm.GetSequenceName, vm, seq), tostring(seq), safe(vm.GetCycle, vm),
		safe(vm.GetPlaybackRate, vm), safe(vm.GetNoDraw, vm), safe(vm.GetMaterial, vm),
		safe(function() return vm:GetColor().a end), safe(vm.GetRenderMode, vm),
		safe(function() return vm:GetWeapon() end), safe(vm.GetOwner, vm))
	local m = vm:GetBoneMatrix(0)
	if m then
		local d = m:GetTranslation() - lp:EyePos()
		local ea = lp:EyeAngles()
		s = s .. string.format(" b0=(f%.1f r%.1f u%.1f)", d:Dot(ea:Forward()), d:Dot(ea:Right()), d:Dot(ea:Up()))
	else
		s = s .. " b0=nil"
	end
	local d = vm:GetPos() - lp:EyePos()
	s = s .. string.format(" pos=%.1f", d:Length())
	return s
end

local function mwState(lp)
	local out = {}
	for _, e in ipairs(ents.FindByClass("mg_viewmodel")) do
		local o = e:GetOwner()
		if IsValid(o) and o.IsCarriedByLocalPlayer and o:IsCarriedByLocalPlayer() then
			out[#out + 1] = string.format("%s{nodraw=%s act=%s}", o:GetClass(), tostring(e:GetNoDraw()),
				tostring(o == lp:GetActiveWeapon()))
		end
	end
	return table.concat(out, ",")
end

local function v3(v)
	if not v then return "nil" end
	if isangle(v) then return string.format("(%.1f %.1f %.1f)", v.p, v.y, v.r) end
	return string.format("(%.1f %.1f %.1f)", v.x, v.y, v.z)
end

local function medkitState(aw)
	if not IsValid(aw) or aw:GetClass() ~= TARGET then return "-" end
	local s = aw.MedkitSway
	local rest = aw.MedkitGunRest
	local hist = s and s.gunHist
	return string.format("gun=%s gunA=%s c=%s o=%s rest=%s restA=%s hist=%s dev=%s proxy=%s",
		v3(s and s.gunPos), v3(s and s.gunAng), v3(s and s.cPos), v3(s and s.oPos),
		v3(rest and rest.pos), v3(rest and rest.ang), hist and #hist or "nil",
		v3(aw.MedkitDevBlend), tostring(IsValid(aw.MedkitSwayProxy)))
end

local function snapshot(lp)
	local aw = lp:GetActiveWeapon()
	local mk = select(2, pcall(medkitState, aw))
	local hands = lp:GetHands()
	local handsS = IsValid(hands) and string.format("%s nodraw=%s par=%s", safe(hands.GetModel, hands),
		safe(hands.GetNoDraw, hands), safe(hands.GetParent, hands)) or "nil"
	local function part(fn, ...)
		local ok, v = pcall(fn, ...)
		return ok and tostring(v) or ("ERR " .. tostring(v))
	end
	mk = "ghost=" .. tostring(lp.GetBarricadeGhosting and lp:GetBarricadeGhosting()) .. " " .. tostring(mk)
	return string.format("mk %s | aw=%s | draw{pvms=%d pre=%d post=%d vmd=%d cvv=%d} | vm0 %s | vm1 %s | hands %s | mw %s",
		tostring(mk), IsValid(aw) and aw:GetClass() or "none",
		flags.pvms or 0, flags.pre or 0, flags.post or 0, flags.vmd or 0, flags.cvv or 0,
		part(vmState, lp, lp:GetViewModel(0)), part(vmState, lp, lp:GetViewModel(1)), handsS, part(mwState, lp))
end

local function flush()
	if not rec then return end
	file.Write(OUT, table.concat(rec.lines, "\n") .. "\n")
	print("[DEBUG-vmp] wrote data/" .. OUT .. " (" .. #rec.lines .. " lines)")
	local wep = rec.wep
	if IsValid(wep) and wep.DebugVmpOldVMD ~= nil then
		wep.ViewModelDrawn = wep.DebugVmpOldVMD or nil
		wep.DebugVmpOldVMD = nil
	end
	rec = nil
end

local function add(line)
	rec.lines[#rec.lines + 1] = line
end

hook.Add("Think", "DEBUG_vmp", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	local aw = lp:GetActiveWeapon()
	local cls = IsValid(aw) and aw:GetClass() or "none"

	if cls ~= lastActive then
		if cls == TARGET and not rec then
			rec = { t0 = RealTime(), lines = {}, wep = aw, moved = nil, last = nil, rep = 0 }
			add(string.format("[DEBUG-vmp] start: %s -> %s, map %s, frame %d", tostring(lastActive), cls, game.GetMap(), FrameNumber()))
			local old = aw.ViewModelDrawn
			aw.DebugVmpOldVMD = old or false
			aw.ViewModelDrawn = function(self, ...)
				flags.vmd = (flags.vmd or 0) + 1
				if old then return old(self, ...) end
			end
		elseif rec then
			add(string.format("t=%.3f active changed %s -> %s", RealTime() - rec.t0, tostring(lastActive), cls))
		end
		lastActive = cls
	end

	if not rec then
		flags = {}
		return
	end

	local now = RealTime() - rec.t0
	local v = lp:GetVelocity()
	local spd = math.sqrt(v.x * v.x + v.y * v.y)
	if spd > 1 and not rec.moved then
		rec.moved = now
		add(string.format("t=%.3f f=%d ---- FIRST MOVE spd=%.1f", now, FrameNumber(), spd))
	end

	local ok, s = pcall(snapshot, lp)
	if not ok then s = "ERR " .. tostring(s) end
	if s ~= rec.last then
		if rec.rep > 0 then add(string.format("   (same x%d)", rec.rep)) end
		add(string.format("t=%.3f f=%d spd=%.0f %s", now, FrameNumber(), r1(spd), s))
		rec.last = s
		rec.rep = 0
	else
		rec.rep = rec.rep + 1
	end
	flags = {}

	if (rec.moved and now - rec.moved > 1.5) or now > 20 then
		if rec.rep > 0 then add(string.format("   (same x%d)", rec.rep)) end
		flush()
	end
end)

local deployAt
local function wrapStored()
	local stored = weapons.GetStored(TARGET)
	if not stored or stored.DebugVmpWrapped then return end
	stored.DebugVmpWrapped = true
	local oldDeploy = stored.Deploy
	stored.Deploy = function(self, ...)
		deployAt = RealTime()
		if rec then add(string.format("t=%.3f f=%d CLIENT Deploy", RealTime() - rec.t0, FrameNumber())) end
		return oldDeploy(self, ...)
	end
end
hook.Add("InitPostEntity", "DEBUG_vmp", wrapStored)
timer.Simple(0, wrapStored)

hook.Add("Think", "DEBUG_vmp_deploy", function()
	if rec and not rec.deployNoted then
		rec.deployNoted = true
		add(deployAt and string.format("client Deploy ran %.3f s before start", RealTime() - deployAt) or "client Deploy NOT seen before start")
	end
end)

hook.Add("PreDrawViewModels", "DEBUG_vmp", function()
	if rec then flags.pvms = (flags.pvms or 0) + 1 end
end)

hook.Add("PreDrawViewModel", "DEBUG_vmp", function()
	if rec then flags.pre = (flags.pre or 0) + 1 end
end)

hook.Add("PostDrawViewModel", "DEBUG_vmp", function()
	if rec then flags.post = (flags.post or 0) + 1 end
end)

hook.Add("CalcViewModelView", "DEBUG_vmp", function()
	if rec then flags.cvv = (flags.cvv or 0) + 1 end
end)
