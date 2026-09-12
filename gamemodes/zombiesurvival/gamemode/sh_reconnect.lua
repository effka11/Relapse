-- Reconnect ammo rules that don't need the engine.

-- An empty mag is not "spent". Keep locking Clip1 to 0 or MW Initialize
-- refills ClipSize and the gun looks infinite after reconnect.
function GM:ReconnectClipWasSpent(live, saved)
	return live ~= nil and live >= 0 and saved ~= nil and saved > 0 and live < saved
end

function GM:ShouldSaveReconnectAmmo(count, held)
	count = tonumber(count) or 0
	return held or count > 0
end

function GM:ReconnectAmmoTypeIsLive(ammo)
	return isstring(ammo) and ammo ~= "" and ammo ~= "none" and ammo ~= "dummy"
end

function GM:ReconnectWeaponShouldEmptyLock(clip1, spare, ammo)
	return self:ReconnectAmmoTypeIsLive(ammo)
		and (tonumber(clip1) or 0) <= 0
		and (tonumber(spare) or 0) <= 0
end

-- True while this gun must not fire or reload: 0/0 at reconnect.
-- Buying a box clears the lock; ghost ClipSize from MW Initialize is dumped.
function GM:ReconnectWeaponEmptyLocked(wep, pl)
	if not (wep and wep:IsValid()) then return false end
	if wep.IsMelee then return false end

	local flagged = wep.m_ReconnectForceEmpty
	if wep.GetNW2Bool and wep:GetNW2Bool("zs_reconnect_empty", false) then
		flagged = true
	end
	if not flagged then return false end

	local ammo = wep.Primary and wep.Primary.Ammo
	if not self:ReconnectAmmoTypeIsLive(ammo) then return false end

	if IsValid(pl) and pl:GetAmmoCount(ammo) > 0 then
		if not wep.m_ReconnectEmptyCleared then
			wep.m_ReconnectEmptyCleared = true
			wep.m_ReconnectForceEmpty = nil
			wep:SetClip1(0)
			if SERVER and wep.SetNW2Bool then
				wep:SetNW2Bool("zs_reconnect_empty", false)
				if pl.m_ReconnectEmptyLock then
					pl.m_ReconnectEmptyLock[wep:GetClass()] = nil
				end
			end
		end
		return false
	end

	return true
end

-- Empty snapshot: keep the overlay until the server drops it. Finishing when
-- Clip1 is briefly 0 lets MW refill the mag and HUD/gun treat it as infinite.
function GM:ShouldKeepReconnectAmmoOverlay(wantclip, clip, wantspare, spare, overlay_active)
	if not overlay_active then
		return false
	end
	if wantclip == nil then
		return false
	end
	if wantclip <= 0 then
		return true
	end
	if clip > 0 and clip < wantclip then
		return false
	end
	if clip == wantclip and (wantspare == nil or spare == wantspare) then
		return false
	end

	return true
end

-- MW Think can Initialize/autoreload AFTER PlayerPostThink. Block the usercmd
-- before that, or one shot per tick looks like infinite ammo.
hook.Add("StartCommand", "ZS.ReconnectEmptyLock", function(pl, cmd)
	if not IsValid(pl) then return end

	local wep = pl:GetActiveWeapon()
	if not (wep and wep:IsValid()) then return end

	local gm = GAMEMODE or GM
	if not (gm and gm.ReconnectWeaponEmptyLocked) then return end
	if not gm:ReconnectWeaponEmptyLocked(wep, pl) then return end

	-- Do not set m_bInitialized here. MW client Initialize creates the
	-- viewmodel; skipping it leaves empty hands after reconnect.
	if wep:Clip1() ~= 0 then
		wep:SetClip1(0)
	end
	if wep.SetIsReloading then
		wep:SetIsReloading(false)
	end

	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_RELOAD)
end)
