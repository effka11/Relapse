-- Per-map post. A missing map or a missing key is 0: the map is left alone.
-- Each key is -100..100. +100 is the authored ceiling. -100 pulls that axis the other way.
-- strength is the whole stack: 0 leaves the other sliders as set, +100 doubles them up to that ceiling, -100 fades them out.
-- The shipped row is applied on every map load. A live edit lasts until the next changelevel.

local POST_KEYS = {
	"strength",
	"desat",
	"contrast",
	"dark",
	"ash",
	"fog",
	"sky",
	"ambient",
	"bloom",
	"grain",
	"vignette",
	"soft",
	"dust",
}

GM.RelapsePostKeys = POST_KEYS

-- Paste a copied line from the dev panel here. This row is what the map loads.
local shipped = {
	["zs_antarctic_hospital_v7"] = { strength = -36, desat = 38, contrast = 28, dark = 13, ash = 44, ambient = 25, bloom = -35, vignette = 61 },
	["zs_hades3"] = { strength = -36, desat = 38, contrast = 28, dark = 13, ash = 44, ambient = 25, bloom = -35, vignette = 61 },
	["zs_jail_b2"] = { strength = -36, desat = 38, contrast = 28, dark = 13, ash = 44, ambient = 25, bloom = -35, vignette = 61 },
	["zs_monsoon_b2"] = { strength = -36, desat = 38, contrast = 28, dark = 13, ash = 44, ambient = 25, bloom = -35, vignette = 61 },
	["zs_oxygen_b4"] = { strength = -36, desat = 38, contrast = 28, dark = 13, ash = 44, ambient = 25, bloom = -35, vignette = 61 },
}

GM.RelapsePostEffects = GM.RelapsePostEffects or {}

local function CopyRow(row)
	if not istable(row) then return nil end
	local out
	for _, key in ipairs(POST_KEYS) do
		local n = tonumber(row[key])
		if n and n ~= 0 then
			n = math.Clamp(math.floor(n + 0.5), -100, 100)
			if n ~= 0 then
				out = out or {}
				out[key] = n
			end
		end
	end
	return out
end

GM.RelapsePostShipped = shipped

function GM:RelapsePostCode(key)
	local row = self.RelapsePostShipped and self.RelapsePostShipped[game.GetMap()]
	local n = row and tonumber(row[key]) or 0
	return math.Clamp(math.floor((n or 0) + 0.5), -100, 100)
end

function GM:RelapsePostApplyShipped()
	for map, row in pairs(self.RelapsePostShipped or {}) do
		self.RelapsePostEffects[map] = CopyRow(row)
	end
end

GM:RelapsePostApplyShipped()

function GM:RelapsePostPercent(key)
	local row = self.RelapsePostEffects and self.RelapsePostEffects[game.GetMap()]
	local n = row and tonumber(row[key]) or 0
	return math.Clamp(math.floor((n or 0) + 0.5), -100, 100)
end

function GM:RelapsePostScale()
	return math.Clamp(1 + self:RelapsePostPercent("strength") * 0.01, 0, 2)
end

function GM:RelapsePostEnabled()
	if SERVER then return true end
	if self.RelapsePostDevOpen then return true end
	local cv = GetConVar("zs_posteffects")
	if not cv then return true end
	return cv:GetBool()
end

function GM:RelapsePostUnit(key)
	if not self:RelapsePostEnabled() then return 0 end
	local unit = self:RelapsePostPercent(key) * 0.01
	if key == "strength" then return unit end
	return math.Clamp(unit * self:RelapsePostScale(), -1, 1)
end

function GM:RelapsePostWrite(map, key, percent)
	percent = math.Clamp(math.floor((tonumber(percent) or 0) + 0.5), -100, 100)
	local row = self.RelapsePostEffects[map]
	if percent == 0 then
		if not row then return end
		row[key] = nil
		if not next(row) then
			self.RelapsePostEffects[map] = nil
		end
		return
	end
	if not row then
		row = {}
		self.RelapsePostEffects[map] = row
	end
	row[key] = percent
end
