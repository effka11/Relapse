-- Relapse HUD action hints: KEY  –  Action. Many at once, vertically
-- centered. Left edge is a fixed inset from the screen's right.

RelapseHint = RelapseHint or {}
RelapseHint.__index = RelapseHint
RelapseHint.Registry = RelapseHint.Registry or {} -- [id] = RelapseHint

local FONT = "Relapse30"
local SEP = "   –   "
local FADE_RATE = 5
local colHint = Color(255, 255, 255, 255)

---------------------------------------------------------------------------
-- RelapseHint
--
-- id     string   stable key ("ladder_step")
-- bind   string   engine bind ("+use") or a raw label
-- text   string   action, already translated
-- order  number   sort, lower first
---------------------------------------------------------------------------

function RelapseHint.New(id)
	id = tostring(id or "")
	local h = RelapseHint.Registry[id]
	if h then
		setmetatable(h, RelapseHint)
		return h
	end
	h = setmetatable({
		id = id,
		bind = "+use",
		text = "",
		order = 0,
		shown = false,
		fade = 0,
	}, RelapseHint)
	RelapseHint.Registry[id] = h
	return h
end

function RelapseHint.BindLabel(bind)
	bind = bind or "+use"
	local first = string.sub(bind, 1, 1)
	if first == "+" or first == "-" then
		local name = input.LookupBinding(bind)
		if name and name ~= "" then
			return string.upper(name)
		end
		return "E"
	end
	return string.upper(bind)
end

function RelapseHint:SetBind(bind)
	self.bind = bind or self.bind
	return self
end

function RelapseHint:SetText(text)
	self.text = text or ""
	return self
end

function RelapseHint:SetOrder(n)
	self.order = n or 0
	return self
end

function RelapseHint:Show()
	self.shown = true
	return self
end

function RelapseHint:Hide()
	self.shown = false
	return self
end

function RelapseHint:IsShown()
	return self.shown and true or false
end

function RelapseHint:KeyLabel()
	return RelapseHint.BindLabel(self.bind)
end

function RelapseHint:KeyPart()
	return self:KeyLabel()
end

function RelapseHint:RestPart()
	return SEP .. (self.text or "")
end

function RelapseHint.Visible()
	local list = {}
	local dt = math.min(FrameTime(), 0.05) * FADE_RATE
	for _, h in pairs(RelapseHint.Registry) do
		h.fade = h.fade or 0
		local want = (h.shown and h.text and h.text ~= "") and 1 or 0
		if h.fade < want then
			h.fade = math.min(want, h.fade + dt)
		elseif h.fade > want then
			h.fade = math.max(want, h.fade - dt)
		end
		if h.fade > 0.01 and h.text and h.text ~= "" then
			list[#list + 1] = h
		end
	end
	table.sort(list, function(a, b)
		if a.order == b.order then
			return a.id < b.id
		end
		return a.order < b.order
	end)
	return list
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function RelapseHint.Paint()
	if not RelapseUI or not RelapseUI.HudText then return end
	local gm = GAMEMODE
	if gm and gm.FilmMode then return end
	local list = RelapseHint.Visible()
	local n = #list
	if n == 0 then return end

	RelapseUI.CreateFonts()
	local font = FONT
	surface.SetFont(font)
	local row = RelapseUI.Grid15(3)
	local stackH = n * row
	local x = ScrW() - RelapseUI.sPx(300)
	local y0 = RelapseUI.Snap((ScrH() - stackH) * 0.5)
	local shadow = RelapseUI.Shadow

	for i = 1, n do
		local hint = list[i]
		local key = hint:KeyPart()
		local keyW = surface.GetTextSize(key)
		local midY = y0 + (i - 1) * row + row * 0.5
		local a = math.floor(hint.fade * 255 + 0.5)
		colHint.a = a
		RelapseUI.HudText(key, font, x, midY, colHint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, shadow)
		RelapseUI.HudText(hint:RestPart(), font, x + keyW, midY, colHint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, shadow)
	end
end

hook.Add("HUDPaint", "RelapseHint", function()
	RelapseHint.Paint()
end)
