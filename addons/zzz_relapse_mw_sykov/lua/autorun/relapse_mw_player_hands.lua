-- Relapse: MW default rig is chands. CHands only draw if GetHands() exists.
-- Cosmetic c_arms live on zs_hands; copy them even when that entity is late.

local function HandsInfo()
	local gm = GAMEMODE or gmod.GetGamemode()
	if gm and gm.GetRelapseHandsInfo then
		return gm:GetRelapseHandsInfo(LocalPlayer())
	end
end

local function ApplyHandsModel(ch, model, skin, body)
	if not IsValid(ch) or not model or model == "" then return end
	if ch:GetModel() ~= model then
		ch:SetModel(model)
	end
	if skin then
		ch:SetSkin(skin)
	end
	if isstring(body) then
		ch:SetBodyGroups(body)
	end
end

local function PatchCHands(ch)
	if not IsValid(ch) or ch.RelapseHandsDraw then return end
	ch.RelapseHandsDraw = true

	ch.CanDraw = function(self)
		if self:GetNoDraw() then
			return false
		end
		local ply = LocalPlayer()
		if IsValid(ply) and IsValid(ply:GetHands()) then
			return true
		end
		local info = HandsInfo()
		return info and info.model ~= nil
	end

	ch.RenderOverride = function(self, flags)
		if not self:CanDraw() then
			return
		end

		local ply = LocalPlayer()
		local hands = IsValid(ply) and ply:GetHands()
		if IsValid(hands) then
			if VManip ~= nil then
				hands:SetParent(self:GetParent())
				hands:DrawModel(flags)
				return
			end
			ApplyHandsModel(self, hands:GetModel(), hands:GetSkin())
			for b = 0, hands:GetNumBodyGroups() do
				self:SetBodygroup(b, hands:GetBodygroup(b))
			end
		else
			local info = HandsInfo()
			if not info then
				return
			end
			ApplyHandsModel(self, info.model, info.skin, info.body)
		end

		self:DrawModel(flags)
	end
end

local function PatchCreate(tbl)
	if not tbl or tbl.RelapseCHandsPatch or not isfunction(tbl.CreateCHands) then
		return false
	end
	tbl.RelapseCHandsPatch = true
	local old = tbl.CreateCHands
	tbl.CreateCHands = function(self)
		old(self)
		PatchCHands(self.m_CHands)
	end
	return true
end

local function PatchEntity(ent)
	if not IsValid(ent) or ent:GetClass() ~= "mg_viewmodel" then return end
	PatchCreate(ent)
	PatchCHands(ent.m_CHands)
end

local function PatchStored()
	local stored = scripted_ents.GetStored("mg_viewmodel")
	if not stored or not stored.t then return false end
	return PatchCreate(stored.t)
end

local function apply()
	local gm = GAMEMODE or gmod.GetGamemode()
	if gm then
		gm.ForcePlayerHands = true
	end
	PatchStored()
	if CLIENT then
		for _, ent in ipairs(ents.FindByClass("mg_viewmodel")) do
			PatchEntity(ent)
		end
	end
end

hook.Add("Initialize", "RelapseMWPlayerHands", apply)
hook.Add("InitPostEntity", "RelapseMWPlayerHands", apply)
hook.Add("OnReloaded", "RelapseMWPlayerHands", apply)

if CLIENT then
	hook.Add("OnEntityCreated", "RelapseMWPlayerHands", function(ent)
		timer.Simple(0, function()
			PatchEntity(ent)
		end)
	end)

	hook.Add("Think", "RelapseMWPlayerHands", function()
		if PatchStored() then
			hook.Remove("Think", "RelapseMWPlayerHands")
		end
	end)
end
