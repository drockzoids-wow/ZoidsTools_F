local _, ns = ...

function ns:HasDamageMeterAPI()
    return type(C_DamageMeter) == "table"
        and type(C_DamageMeter.GetCombatSessionFromType) == "function"
        and Enum and Enum.DamageMeterSessionType
        and Enum.DamageMeterSessionType.Current ~= nil
        and Enum.DamageMeterSessionType.Overall ~= nil
        and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone ~= nil
        and true or false
end

function ns:IsMeterDataAvailable()
    if not self:HasDamageMeterAPI() then return false end
    if type(C_DamageMeter.IsDamageMeterAvailable) == "function" then
        local ok, available = pcall(C_DamageMeter.IsDamageMeterAvailable)
        return ok and available == true
    end
    return true
end

function ns:RegisterCompatibleEvent(frame, event)
    -- New beta clients may not expose every retail meter event yet.
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
        return false
    end
    return pcall(frame.RegisterEvent, frame, event)
end

ns.RegisterMeterEvent = ns.RegisterCompatibleEvent

function ns:GetCompatibilityStatus()
    local version, build, _, interface = GetBuildInfo()
    local state = self:IsMeterDataAvailable() and "Meter API available; in-game validation required."
        or "Meter data unavailable on this client. Preview remains available."
    return string.format("Client %s (%s), interface %s. %s", tostring(version), tostring(build), tostring(interface), state)
end

function ns:GetBlizzardDamageMeterEnabled()
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    if type(getter) ~= "function" then return false end
    local ok, value = pcall(getter, "damageMeterEnabled")
    return ok and value == "1"
end

function ns:SetBlizzardDamageMeterEnabled(value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if type(setter) ~= "function" then return false end
    local ok, result = pcall(setter, "damageMeterEnabled", value and "1" or "0")
    if not ok or result == false then return false end
    if DamageMeter and DamageMeter.UpdateShownState then
        pcall(DamageMeter.UpdateShownState, DamageMeter)
    end
    return self:GetBlizzardDamageMeterEnabled() == (value == true)
end
