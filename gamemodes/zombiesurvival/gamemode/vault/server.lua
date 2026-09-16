GM.VaultFolder = "zombiesurvival_vault"
GM.SkillTreeVersion = 1

function GM:ShouldSaveVault(pl)
	-- Always push accumulated points in to the vault if we have any.
	if pl:IsBot() then return false end

	if self.PointSaving > 0 and pl.PointsVault ~= nil then
		return true
	end

	if pl:GetZSXP() > 0 or pl:GetZSSPUsed() > 0 or pl:GetZSRemortLevel() > 0 then
		return true
	end

	if self.HasRelapseScarVault and self:HasRelapseScarVault(pl) then
		return true
	end

	return false
end

function GM:ShouldLoadVault(pl)
	return not pl:IsBot()
end

--[[function GM:ShouldUseVault(pl)
	return not self.ZombieEscape and not self:IsClassicMode()
end]]

function GM:GetVaultFile(pl)
	local steamid = pl:SteamID64() or "invalid"

	return self.VaultFolder.."/"..steamid:sub(-2).."/"..steamid..".txt"
end

function GM:SaveAllVaults()
	for _, pl in pairs(player.GetAll()) do
		self:SaveVault(pl)
	end
end

function GM:InitializeVault(pl)
	pl.PointsVault = 0
	pl:SetZSXP(0)
	if self.InitRelapseScars then
		self:InitRelapseScars(pl, true)
	end
end

function GM:LoadVault(pl)
	if not self:ShouldLoadVault(pl) then return end

	local filename = self:GetVaultFile(pl)
	local data
	if file.Exists(filename, "DATA") then
		local contents = file.Read(filename, "DATA")
		if contents and #contents > 0 then
			data = Deserialize(contents)
			if data then
				pl.PointsVault = data.Points

				if data.RemortLevel then
					pl:SetZSRemortLevel(data.RemortLevel)
				end
				if data.XP then
					pl:SetZSXP(data.XP)
				end
				if data.UnlockedSkills then
					pl:SetUnlockedSkills(util.DecompressBitTable(data.UnlockedSkills), true)
				end
				if data.DesiredActiveSkills then
					pl:SetDesiredActiveSkills(util.DecompressBitTable(data.DesiredActiveSkills), true)
				end
				if data.NextSkillReset then
					pl.NextSkillReset = data.NextSkillReset
				end
				if not data.Version or data.Version < self.SkillTreeVersion then
					pl:SkillsReset()
					pl.SkillsRefunded = true
				end

				pl.SkillVersion = self.SkillTreeVersion
			end
		end
	end

	if self.ReadRelapseScarVault and data then
		self:ReadRelapseScarVault(pl, data)
	elseif self.InitRelapseScars then
		self:InitRelapseScars(pl)
	end

	pl.PointsVault = pl.PointsVault or 0
end

function GM:PlayerReadyVault(pl)
	local unlocked = pl:GetUnlockedSkills()
	local desired = pl:GetDesiredActiveSkills()
	local active = pl:GetActiveSkills()

	net.Start("zs_skills_init")
	self:WriteSkillBits(unlocked)
	self:WriteSkillBits(desired)

	-- Send this if any key exists.
	for k in pairs(active) do
		net.WriteBool(true)
		self:WriteSkillBits(active)
		net.Send(pl)

		return
	end

	net.WriteBool(false)
	net.Send(pl)

	if pl.NextSkillReset then
		local time = os.time()
		if time < pl.NextSkillReset then
			net.Start("zs_skills_nextreset")
			net.WriteUInt(pl.NextSkillReset - time, 32)
			net.Send(pl)
		end
	end
end

function GM:SaveVault(pl)
	if not self:ShouldSaveVault(pl) then return end

	local tosave = {
		Points = math.floor(pl.PointsVault),
		XP = pl:GetZSXP(),
		RemortLevel = pl:GetZSRemortLevel(),
		DesiredActiveSkills = util.CompressBitTable(pl:GetDesiredActiveSkills()),
		UnlockedSkills = util.CompressBitTable(pl:GetUnlockedSkills()),
		Version = pl.SkillVersion or self.SkillTreeVersion
	}

	if pl.NextSkillReset and os.time() < pl.NextSkillReset then
		tosave.NextSkillReset = pl.NextSkillReset
	end

	if tosave.Points and self.PointSavingLimit > 0 and tosave.Points > self.PointSavingLimit then
		tosave.Points = self.PointSavingLimit
	end

	if self.WriteRelapseScarVault then
		self:WriteRelapseScarVault(pl, tosave)
	end

	local filename = self:GetVaultFile(pl)
	file.CreateDir(string.GetPathFromFilename(filename))
	file.Write(filename, Serialize(tosave))
end
