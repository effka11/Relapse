AddCSLuaFile()

SWEP.StatDefinitions = {
    ["SWEP.Primary.ClipSize"] = "ClipSize",
    ["SWEP.Primary.RPM"] = "RPM",
    ["SWEP.Animations.Ads_Out.Fps"] = "AimSpeed",
    ["SWEP.Animations.Ads_In.Fps"] = "AimSpeed",
    ["SWEP.Animations.Sprint_Out.Fps"] = "SprintSpeed",
    ["SWEP.Animations.Rechamber.Fps"] = "RechamberSpeed",
    ["SWEP.Cone.Ads"] = "AimAccuracy",
    ["SWEP.Cone.Hip"] = "Accuracy",
    ["SWEP.Cone.TacStance"] = "TacAccuracy",
    ["SWEP.Cone.Increase"] = "ConeIncrease",
    ["SWEP.Animations.Reload.Fps"] = "ReloadSpeed",
    ["SWEP.Animations.Reload_Empty.Fps"] = "ReloadSpeed",
    ["SWEP.Animations.Reload_Start.Fps"] = "ReloadSpeed",
    ["SWEP.Animations.Draw.Fps"] = "SwitchSpeed",
    ["SWEP.Animations.Holster.Fps"] = "SwitchSpeed",
    ["SWEP.Bullet.Damage.1"] = "DamageClose",
    ["SWEP.Bullet.Damage.2"] = "DamageClose",
    ["SWEP.Bullet.TorsoMultiplier"] = "Damage",
    ["SWEP.Bullet.HeadshotMultiplier"] = "HeadshotDamage",
    ["SWEP.Bullet.LimbMultiplier"] = "LimbDamage",
    ["SWEP.Bullet.DropOffStartRange"] = "Range",
    ["SWEP.Bullet.EffectiveRange"] = "Range",
    ["SWEP.Bullet.Penetration.Thickness"] = "PenetrationThickness",
    ["SWEP.Recoil.AdsMultiplier"] = "ADSRecoil",
    ["SWEP.Recoil.Vertical.1"] = "VerticalRecoil",
    ["SWEP.Recoil.Vertical.2"] = "VerticalRecoil",
    ["SWEP.Recoil.Horizontal.1"] = "HorizontalRecoil",
    ["SWEP.Recoil.Horizontal.2"] = "HorizontalRecoil",
    ["SWEP.Animations.Melee_Hit.Length"] = "MeleeLength",
    ["SWEP.Animations.Melee.Length"] = "MeleeLength",
    ["SWEP.Animations.Melee_Hit.Damage"] = "MeleeDamage",
    ["SWEP.Projectile.Speed"] = "ProjectileSpeed",
    ["SWEP.Projectile.Gravity"] = "ProjectileGravity",
    ["SWEP.Projectile.Stability"] = "ProjectileStability",
    ["SWEP.Projectile.Fuel"] = "ProjectileFuel",
    ["SWEP.Projectile.TrackingFraction"] = "TrackingSpeed",
    ["SWEP.Bullet.NumBullets"] = "Bullets",
    ["SWEP.Zoom.FovMultiplier"] = "Zoom",
    ["SWEP.Zoom.IdleSway"] = "IdleSway",
    ["SWEP.Recoil.DecreaseEveryShot"] = "RecoilStability",
    ["SWEP.Trigger.Time"] = "TriggerTime",
    ["SWEP.Explosive.BlastRadius"] = "BlastRadius",
    ["SWEP.Explosive.ImpactBlastRatio"] = "ImpactDamage",
    ["SWEP.TrackingInfo.PingTime"] = "PingSpeed",
}

SWEP.StatInfo = {
	-- damage
	["DamageClose"] = {
        Name = "Damage",
        ProIfMore = true,
        ShowPercentage = true
    },
	["Damage"] = {
        Name = "Torso Damage",
        ProIfMore = true,
        ShowPercentage = true
    },
	["HeadshotDamage"] = {
        Name = "Headshot Damage",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["LimbDamage"] = {
        Name = "Limb Damage",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["Bullets"] = {
        Name = "Number Of Pellets",
        ProIfMore = true,
        ShowPercentage = false
    },
    ["RPM"] = {
        Name = "Rounds Per Minute",
        ProIfMore = true,
        ShowPercentage = false
    },
	["RechamberSpeed"] = {
        Name = "Rechamber Speed",
        ProIfMore = true,
        ShowPercentage = true
    },
	["ClipSize"] = {
        Name = "Magazine Size",
        ProIfMore = true,
        ShowPercentage = false
    },
    ["Range"] = {
        Name = "Range",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["EffectiveRange"] = {
        Name = "Effective Range",
        ProIfMore = true,
        ShowPercentage = true
    },
	["PenetrationThickness"] = {
        Name = "Penetration Power",
        ProIfMore = true,
        ShowPercentage = true
    },
	
	-- projectile
	["ProjectileSpeed"] = {
        Name = "Projectile Velocity",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["ProjectileGravity"] = {
        Name = "Projectile Drop",
        ProIfMore = false,
        ShowPercentage = true
    },
    ["ProjectileStability"] = {
        Name = "Projectile Stability",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["ProjectileFuel"] = {
        Name = "Projectile Fuel",
        ProIfMore = true,
        ShowPercentage = true
    },

    -- recoil
    ["VerticalRecoil"] = {
        Name = "Vertical Recoil",
        ProIfMore = false,
        ShowPercentage = true
    },
	["HorizontalRecoil"] = {
        Name = "Horizontal Recoil",
        ProIfMore = false,
        ShowPercentage = true
    },
    ["ADSRecoil"] = {
        Name = "Recoil Kick",
        ProIfMore = false,
        ShowPercentage = true
    },
	["RecoilStability"] = {
        Name = "Recoil Stability",
        ProIfMore = true,
        ShowPercentage = true
    },
	
	-- accuracy
    ["Accuracy"] = {
        Name = "Hip Fire Spread",
        ProIfMore = false,
        ShowPercentage = true
    },
	["AimAccuracy"] = {
        Name = "ADS Spread",
        ProIfMore = false,
        ShowPercentage = true
    },
    ["TacAccuracy"] = {
        Name = "Tac-Stance Spread",
        ProIfMore = false,
        ShowPercentage = true
    },
    ["ConeIncrease"] = {
        Name = "Firing Inaccuracy",
        ProIfMore = false,
        ShowPercentage = true
    },
	["IdleSway"] = {
        Name = "Aim Idle Sway",
        ProIfMore = false,
        ShowPercentage = true
    },
    ["Zoom"] = {
        Name = "Magnification",
        ProIfMore = false,
        ShowPercentage = true
    },
	
	-- handling
	["ReloadSpeed"] = {
        Name = "Reload Speed",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["ReloadLength"] = {
        Name = "Reload Time",
        ProIfMore = false,
        ShowPercentage = true
    },
	["AimSpeed"] = {
        Name = "ADS Speed",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["AimLength"] = {
        Name = "ADS Time",
        ProIfMore = false,
        ShowPercentage = true
    },
    ["SprintSpeed"] = {
        Name = "Sprint-to-Fire Speed",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["SprintLength"] = {
        Name = "Sprint-to-Fire Time",
        ProIfMore = false,
        ShowPercentage = false
    },
    ["SwitchSpeed"] = {
        Name = "Swap Speed",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["DrawLength"] = {
        Name = "Draw Time",
        ProIfMore = false,
        ShowPercentage = true
    },
    ["HolsterLength"] = {
        Name = "Holster Time",
        ProIfMore = false,
        ShowPercentage = true
    },
	
    -- melee
    ["MeleeDamage"] = {
        Name = "Damage Melee",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["MeleeLength"] = {
        Name = "Melee Recovery",
        ProIfMore = false,
        ShowPercentage = true
    },
	
	-- misc
	["PingSpeed"] = {
        Name = "Tracking Speed",
        ProIfMore = false,
        ShowPercentage = true
    },
	["TrackingSpeed"] = {
        Name = "Tracking Aggression",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["ImpactDamage"] = {
        Name = "Impact Damage",
        ProIfMore = false,
        ShowPercentage = true
    },
    ["BlastRadius"] = {
        Name = "Blast Radius",
        ProIfMore = true,
        ShowPercentage = true
    },
    ["TriggerTime"] = {
        Name = "Trigger Weight",
        ProIfMore = false,
        ShowPercentage = true
    },
}