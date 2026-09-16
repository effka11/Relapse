util.AddNetworkString("zs_scars_sync")
util.AddNetworkString("zs_scars_take")
util.AddNetworkString("zs_scars_request")

function GM:InitRelapseScars(pl, wipe)
	if not IsValid(pl) then return end

	if wipe then
		pl.RelapseScarRanks = {}
		pl.RelapseScarPicks = 0
		pl.RelapseScarOffer = {}
		pl.RelapseScarMeters = {}
		pl.RelapseScarRemainder = {}
		return
	end

	pl.RelapseScarRanks = pl.RelapseScarRanks or {}
	pl.RelapseScarPicks = pl.RelapseScarPicks or 0
	pl.RelapseScarOffer = pl.RelapseScarOffer or {}
	pl.RelapseScarMeters = pl.RelapseScarMeters or {}
	pl.RelapseScarRemainder = pl.RelapseScarRemainder or {}
end

function GM:ResetRelapseScarMap(pl)
	if not IsValid(pl) then return end
	pl.RelapseScarRemainder = {}
end

function GM:HasRelapseScarVault(pl)
	if not IsValid(pl) then return false end
	if (pl.RelapseScarPicks or 0) > 0 then return true end
	if pl.RelapseScarOffer and #pl.RelapseScarOffer > 0 then return true end
	if pl.RelapseScarRanks then
		for _, n in pairs(pl.RelapseScarRanks) do
			if (n or 0) > 0 then return true end
		end
	end
	if pl.RelapseScarMeters then
		for _, m in pairs(pl.RelapseScarMeters) do
			if m and ((m.count or 0) > 0 or (m.meter or 0) > 0) then
				return true
			end
		end
	end
	return false
end

function GM:WriteRelapseScarVault(pl, tosave)
	if not IsValid(pl) or not tosave then return end
	self:InitRelapseScars(pl)
	tosave.ScarRanks = pl.RelapseScarRanks
	tosave.ScarPicks = pl.RelapseScarPicks
	tosave.ScarOffer = pl.RelapseScarOffer
	tosave.ScarMeters = pl.RelapseScarMeters
end

function GM:ReadRelapseScarVault(pl, contents)
	if not IsValid(pl) or not contents then return end
	self:InitRelapseScars(pl, true)
	pl.RelapseScarRanks = istable(contents.ScarRanks) and contents.ScarRanks or {}
	pl.RelapseScarPicks = math.max(0, math.floor(tonumber(contents.ScarPicks) or 0))
	pl.RelapseScarOffer = istable(contents.ScarOffer) and contents.ScarOffer or {}
	pl.RelapseScarMeters = istable(contents.ScarMeters) and contents.ScarMeters or {}
	pl.RelapseScarRemainder = {}

	local cleanOffer = {}
	for i = 1, #pl.RelapseScarOffer do
		local id = pl.RelapseScarOffer[i]
		if self:GetRelapseScar(id) then
			cleanOffer[#cleanOffer + 1] = id
		end
	end
	pl.RelapseScarOffer = cleanOffer
end

local function ScarAffinity(gm, pl, id)
	local scar = gm:GetRelapseScar(id)
	if not scar then return 0 end
	local row = pl.RelapseScarMeters and pl.RelapseScarMeters[id]
	local meter = row and tonumber(row.meter) or 0
	return meter / math.max(1, scar.Pace or 1)
end

local function ScarWeight(gm, pl, id, feedScale)
	local scar = gm:GetRelapseScar(id)
	if not scar then return 0 end
	local w = (ScarAffinity(gm, pl, id) + 0.25) ^ 0.65
	if scar.Feed and feedScale[scar.Feed] then
		w = w * feedScale[scar.Feed]
	end
	return w
end

local function WeightedPick(gm, pl, ids, taken, feedScale)
	local sum = 0
	local weights = {}
	for i = 1, #ids do
		local id = ids[i]
		if not taken[id] then
			local w = ScarWeight(gm, pl, id, feedScale)
			weights[id] = w
			sum = sum + w
		end
	end
	if sum <= 0 then
		for i = 1, #ids do
			local id = ids[i]
			if not taken[id] then
				return id
			end
		end
		return nil
	end

	local r = math.Rand(0, sum)
	local last
	for i = 1, #ids do
		local id = ids[i]
		local w = weights[id]
		if w then
			last = id
			r = r - w
			if r <= 0 then
				return id
			end
		end
	end
	return last
end

local function TopSet(gm, pl, pool, n)
	local scored = {}
	for i = 1, #pool do
		local id = pool[i]
		scored[i] = {id = id, a = ScarAffinity(gm, pl, id)}
	end
	table.sort(scored, function(a, b)
		if a.a == b.a then
			return a.id < b.id
		end
		return a.a > b.a
	end)
	local set = {}
	for i = 1, math.min(n, #scored) do
		set[scored[i].id] = true
	end
	return set
end

function GM:RollRelapseScarOffer(pl)
	self:InitRelapseScars(pl)
	local pool = self:RelapseScarPool()
	local want = math.min(3, #pool)
	if want <= 0 then
		return {}
	end

	local taken = {}
	local feedScale = {}
	local chosen = {}
	for _ = 1, want do
		local id = WeightedPick(self, pl, pool, taken, feedScale)
		if not id then break end
		chosen[#chosen + 1] = id
		taken[id] = true
		local scar = self:GetRelapseScar(id)
		if scar and scar.Feed then
			feedScale[scar.Feed] = 0.4
		end
	end

	if want == 3 and #pool > 3 and #chosen == 3 then
		local top = TopSet(self, pl, pool, 3)
		local exact = true
		for i = 1, 3 do
			if not top[chosen[i]] then
				exact = false
				break
			end
		end
		if exact then
			taken[chosen[3]] = nil
			local replacement = WeightedPick(self, pl, pool, taken, feedScale)
			if replacement then
				chosen[3] = replacement
			else
				taken[chosen[3]] = true
			end
		end
	end

	return chosen
end

function GM:SendRelapseScars(pl)
	if not IsValid(pl) then return end
	self:InitRelapseScars(pl)

	net.Start("zs_scars_sync")
	net.WriteUInt(math.Clamp(math.floor(pl.RelapseScarPicks or 0), 0, 255), 8)

	local offer = pl.RelapseScarOffer or {}
	local nOffer = math.min(#offer, 7)
	net.WriteUInt(nOffer, 3)
	for i = 1, nOffer do
		net.WriteString(offer[i])
	end

	local ranks = {}
	for id, n in pairs(pl.RelapseScarRanks or {}) do
		if self:GetRelapseScar(id) and (n or 0) > 0 then
			ranks[#ranks + 1] = {id, math.floor(n)}
		end
	end
	net.WriteUInt(math.min(#ranks, 255), 8)
	for i = 1, #ranks do
		net.WriteString(ranks[i][1])
		net.WriteUInt(math.Clamp(ranks[i][2], 1, 65535), 16)
	end

	local meters = {}
	for id, row in pairs(pl.RelapseScarMeters or {}) do
		if self:GetRelapseScar(id) and row then
			meters[#meters + 1] = {
				id,
				math.floor(tonumber(row.count) or 0),
				tonumber(row.meter) or 0
			}
		end
	end
	net.WriteUInt(math.min(#meters, 255), 8)
	for i = 1, #meters do
		net.WriteString(meters[i][1])
		net.WriteUInt(math.Clamp(meters[i][2], 0, 65535), 16)
		net.WriteFloat(meters[i][3])
	end
	net.Send(pl)
end

function GM:GrantRelapseScarPick(pl)
	if not IsValid(pl) then return end
	self:InitRelapseScars(pl)
	if not pl.RelapseScarOffer or #pl.RelapseScarOffer == 0 then
		pl.RelapseScarOffer = self:RollRelapseScarOffer(pl)
	end
	pl.RelapseScarPicks = (pl.RelapseScarPicks or 0) + 1
	pl.RelapseScarMeters = {}
	pl.RelapseScarRemainder = {}
	self:SendRelapseScars(pl)
	self:SaveVault(pl)
end

function GM:TakeRelapseScar(pl, id)
	if not IsValid(pl) then return false end
	self:InitRelapseScars(pl)
	if (pl.RelapseScarPicks or 0) < 1 then return false end

	local scar = self:GetRelapseScar(id)
	if not (scar and scar.InPool) then return false end
	if not self:RelapseScarOfferHas(pl.RelapseScarOffer, id) then return false end

	pl.RelapseScarRanks[id] = (pl.RelapseScarRanks[id] or 0) + 1
	pl.RelapseScarPicks = pl.RelapseScarPicks - 1
	pl.RelapseScarOffer = {}
	if pl.RelapseScarPicks > 0 then
		pl.RelapseScarOffer = self:RollRelapseScarOffer(pl)
	end

	self:SendRelapseScars(pl)
	self:SaveVault(pl)
	return true
end

function GM:CreditRelapseScarLastHit(attacker, zombie)
	if not (IsValid(attacker) and attacker:IsPlayer() and attacker:Team() == TEAM_HUMAN) then
		return
	end

	self:InitRelapseScars(attacker)

	local classtbl = zombie.GetZombieClassTable and zombie:GetZombieClassTable()
	local points = classtbl and tonumber(classtbl.Points) or 0
	if points <= 0 then return end

	local meters = attacker.RelapseScarMeters
	local row = meters.mercenary or {count = 0, meter = 0}
	row.count = (row.count or 0) + 1
	row.meter = (row.meter or 0) + points / 5
	meters.mercenary = row

	local rank = attacker.RelapseScarRanks.mercenary or 0
	if rank < 1 then return end

	local scar = self.RelapseScarCatalog.mercenary
	local k = self:RelapseScarK(rank, scar.K1, scar.KInf)
	local rem = (attacker.RelapseScarRemainder.mercenary or 0) + 1
	local gained = 0
	while rem >= k do
		rem = rem - k
		gained = gained + 1
	end
	attacker.RelapseScarRemainder.mercenary = rem
	if gained > 0 then
		attacker:AddPoints(gained, nil, nil, true)
	end
end

net.Receive("zs_scars_take", function(_, pl)
	if not IsValid(pl) then return end
	local id = net.ReadString()
	if not id or #id > 32 then return end
	GAMEMODE:TakeRelapseScar(pl, id)
end)

net.Receive("zs_scars_request", function(_, pl)
	if not IsValid(pl) then return end
	GAMEMODE:SendRelapseScars(pl)
end)
