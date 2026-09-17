--CACHED GLOBALS
local math_min = math.min
local curtime = CurTime

local TEAM_HUMAN = TEAM_HUMAN
local IN_SPEED = IN_SPEED
local MOVETYPE_NOCLIP = MOVETYPE_NOCLIP

local GM_MaxLegDamage = GM.MaxLegDamage

local M_Entity = FindMetaTable("Entity")
local M_Player = FindMetaTable("Player")
local M_CMoveData = FindMetaTable("CMoveData")

local E_GetTable = M_Entity.GetTable
local E_GetDTFloat = M_Entity.GetDTFloat
local E_GetDTBool = M_Entity.GetDTBool
local E_GetMoveType = M_Entity.GetMoveType
local P_Team = M_Player.Team
local P_Crouching = M_Player.Crouching
local P_GetWalkSpeed = M_Player.GetWalkSpeed
local P_GetRunSpeed = M_Player.GetRunSpeed
local P_CallZombieFunction1 = M_Player.CallZombieFunction1
local P_GetLegDamage = M_Player.GetLegDamage
local P_GetBarricadeGhosting = M_Player.GetBarricadeGhosting
local P_GetActiveWeapon = M_Player.GetActiveWeapon
local M_SetVelocity = M_CMoveData.SetVelocity
local M_GetVelocity = M_CMoveData.GetVelocity
local M_SetMaxSpeed = M_CMoveData.SetMaxSpeed
local M_GetMaxSpeed = M_CMoveData.GetMaxSpeed
local M_SetMaxClientSpeed = M_CMoveData.SetMaxClientSpeed
local M_GetMaxClientSpeed = M_CMoveData.GetMaxClientSpeed
local M_GetForwardSpeed = M_CMoveData.GetForwardSpeed
local M_GetSideSpeed = M_CMoveData.GetSideSpeed
local M_KeyDown = M_CMoveData.KeyDown

-- Shift is IN_SPEED. Run anim / MW sprint follow the button; engine speed
-- follows a sticky SprintEnable flag that can stay off after SprintDisable
-- (round restart used to disable it after human spawn). Apply walk/run here.
-- Ghosting (Z) already caps speed in Move; drop IN_SPEED so anims do not sprint.
function GM:StartCommand(pl, cmd)
	if P_Team(pl) ~= TEAM_HUMAN then return end
	if not P_GetBarricadeGhosting(pl) then return end

	cmd:RemoveKey(IN_SPEED)
end

function GM:SetupMove(pl, move, cmd)
	if P_Team(pl) ~= TEAM_HUMAN then return end
	if E_GetMoveType(pl) == MOVETYPE_NOCLIP then return end

	local spd
	if M_KeyDown(move, IN_SPEED) and not P_Crouching(pl) then
		spd = P_GetRunSpeed(pl)
	else
		spd = P_GetWalkSpeed(pl)
	end

	M_SetMaxSpeed(move, spd)
	M_SetMaxClientSpeed(move, spd)
end

local fw, sd, pt, vel, mul, phase
function GM:Move(pl, move)
	if self.RelapseLadderClimb and self:RelapseLadderClimb(pl, move) then
		return true
	end

	if pl:GetMoveType() == MOVETYPE_NOCLIP then return end

	pt = E_GetTable(pl)

	if P_Team(pl) == TEAM_HUMAN then
		if P_GetBarricadeGhosting(pl) and not E_GetDTBool(pl, 1)
			and (pt.RelapseLadderGhostHop or 0) <= curtime() then
			-- Use 7, because friction will amount this to a velocity of 1 roughly.
			phase = pt.NoGhosting and E_GetDTFloat(pl, DT_PLAYER_FLOAT_WIDELOAD) > curtime()
			M_SetMaxClientSpeed(move, math_min(M_GetMaxClientSpeed(move), phase and 7 or ((GAMEMODE.BarricadeGhostSpeed or 10) * (pt.BarricadePhaseSpeedMul or 1))))
		elseif not pt.NoBWSpeedPenalty then
			fw = M_GetForwardSpeed(move)
			if fw < 0 then
				sd = M_GetSideSpeed(move)
				if sd < 0 then sd = -sd end

				if sd > fw then
					M_SetMaxClientSpeed(move, M_GetMaxClientSpeed(move) * (P_GetActiveWeapon(pl).IsMelee and 0.75 or 0.5))
				end
			end
		end
	else
		if pt.SpawnProtection then
			M_SetMaxSpeed(move, M_GetMaxSpeed(move) * 1.15)
			M_SetMaxClientSpeed(move, M_GetMaxClientSpeed(move) * 1.15)
		end

		if P_CallZombieFunction1(pl, "Move", move) then return end
	end

	legdmg = P_GetLegDamage(pl)
	if legdmg > 0 then
		M_SetMaxClientSpeed(move, M_GetMaxClientSpeed(move) * (1 - math_min(1, legdmg / GM_MaxLegDamage)))
	end
end

function GM:FinishMove(pl, move)
	if pl:GetMoveType() == MOVETYPE_NOCLIP then return end

	pt = E_GetTable(pl)

	-- Simple anti bunny hopping. Flag is set in OnPlayerHitGround
	if pt.LandSlow then
		pt.LandSlow = false

		vel = M_GetVelocity(move)
		mul = 1 - 0.25 * (pt.FallDamageSlowDownMul or 1)
		vel.x = vel.x * mul
		vel.y = vel.y * mul
		M_SetVelocity(move, vel)
	end
end
