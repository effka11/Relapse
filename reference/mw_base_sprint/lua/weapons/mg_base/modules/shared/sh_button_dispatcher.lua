AddCSLuaFile()
require("mw_input")

--binds
--local mbind, sbind, cbind, ibind, fbind = input.LookupBinding(), input.LookupBinding("+zoom"), input.LookupBinding("+menu_context"), input.LookupBinding("+reload"), input.LookupBinding("+grenade1")

--CreateClientConVar("mgbase_binds_melee", mbind and input.GetKeyCode(mbind) or "0", true, true)
--CreateClientConVar("mgbase_binds_switchsights", sbind and input.GetKeyCode(sbind) or "0", true, true)
--CreateClientConVar("mgbase_binds_customize", cbind and input.GetKeyCode(cbind) or "0", true, true)
--CreateClientConVar("mgbase_binds_safety", "0", true, true)
--CreateClientConVar("mgbase_binds_inspect", ibind and input.GetKeyCode(ibind) or "0", true, true)
--CreateClientConVar("mgbase_binds_firemode", fbind and input.GetKeyCode(fbind) or "0", true, true)
--CreateClientConVar("mgbase_binds_holster", "0", true, true)
--CreateClientConVar("mgbase_binds_underbarrel", "0", true, true)

CreateClientConVar("mgbase_binds_doubletap_delay", "0.3", true, true)

mw_input.RegisterBind("melee", "+grenade2")
mw_input.RegisterBind("switchsights", "+use")
mw_input.RegisterBind("tacstance", "+use")
mw_input.RegisterBind("customize", "+menu_context")
mw_input.RegisterBind("safety")
mw_input.RegisterBind("inspect", "+reload")
mw_input.RegisterBind("firemode", "+grenade1")
mw_input.RegisterBind("holster")
mw_input.RegisterBind("underbarrel") 

local buttonFunctions = {
    ["melee"] = {
        CanPress = function(weapon)
            return !weapon:HasFlag("Holstering") 
                && weapon:GetTaskByName("Melee"):CanBeSet(weapon)
        end,

        OnPress = function(weapon) 
            weapon:TrySetTask("Melee")
        end
    },

    ["firemode"] = {
        CanPress = function(weapon)
            return !weapon:HasFlag("Holstering")
                && weapon:GetTaskByName("Firemode"):CanBeSet(weapon)
        end,

        OnPress = function(weapon)
            weapon:TrySetTask("Firemode")
        end
    },

    ["safety"] = {
        CanPress = function(weapon)
            return !weapon:HasFlag("Holstering") 
                && weapon:GetTaskByName("Lower"):CanBeSet(weapon)
        end,

        OnPress = function(weapon)
            if (!weapon:HasFlag("Lowered")) then
                weapon:TrySetTask("Lower")
            else
                weapon:TrySetTask("Raise")
            end
        end
    },

    ["inspect"] = {
        CanPress = function(weapon)
            return !weapon:HasFlag("Holstering") 
                && weapon:GetTaskByName("Inspect"):CanBeSet(weapon)
        end,

        OnPress = function(weapon)
            if (weapon:HasFlag("Inspecting")) then
                weapon:ToggleFlag("StoppedInspectAnimation")
            end
    
            weapon:TrySetTask("Inspect")
        end
    },

    ["customize"] = {
        CanPress = function(weapon)
            return !weapon:HasFlag("Holstering") 
                && weapon:GetTaskByName("Customize"):CanBeSet(weapon)
        end,

        OnPress = function(weapon)
            if (weapon:HasFlag("Customizing")) then
                weapon:RemoveFlag("Customizing")
            end 
    
            weapon:TrySetTask("Customize")
        end
    },

    ["switchsights"] = {
        CanPress = function(weapon)
            return !weapon:HasFlag("Holstering") 
                && weapon:GetTaskByName("AimMode"):CanBeSet(weapon)
        end,

        OnPress = function(weapon)
            weapon:TrySetTask("AimMode")
        end
    },

    ["tacstance"] = {
        CanPress = function(weapon)
            return !weapon:HasFlag("Holstering") 
                && weapon:CanTacStance()
        end,

        OnPress = function(weapon)
            weapon:TacStance()
        end
    },

    ["holster"] = {
        CanPress = function(weapon)
            return true
        end,

        OnPress = function(weapon) 
            if (weapon:HasFlag("Holstering") && weapon:GetNextWeapon() != weapon:GetOwner()) then 
                weapon:Deploy() 
            else 
                weapon:Holster() 
            end 
        end
    },
    
    ["underbarrel"] = {
        CanPress = function(weapon)
            return !weapon:HasFlag("Holstering") 
                && weapon:GetTaskByName(weapon:HasFlag("UsingUnderbarrel") && "UnderbarrelOut" || "UnderbarrelIn"):CanBeSet(weapon)
        end,

        OnPress = function(weapon)
            weapon:TrySetTask(weapon:HasFlag("UsingUnderbarrel") && "UnderbarrelOut" || "UnderbarrelIn")
        end
    }
}

hook.Add("PlayerButtonDown", "MW19_PlayerButtonDown", function(p, button)
    mw_input.ButtonDown(p, button)
end)

hook.Add("PlayerButtonUp", "MW19_PlayerButtonUp", function(p, button)
    mw_input.ButtonUp(p, button)
end)

mw_input.AddDelegate(
    "mwb",  
    function(ply, bind)
        local w = ply:GetActiveWeapon()

        if (IsValid(w) && w.HandleBind != nil) then
            w:HandleBind(bind)
        end 
    end, 
    function(ply, bind)
        local w = ply:GetActiveWeapon()

        if (IsValid(w) && w.CanPressBind != nil) then
            return w:CanPressBind(bind)
        end
    end
) 

function SWEP:CanPressBind(bind)
    return buttonFunctions[bind].CanPress(self)
end

function SWEP:HandleBind(bind)
    buttonFunctions[bind].OnPress(self)
end