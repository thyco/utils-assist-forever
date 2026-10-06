local _, addon = ...
local Graphics = {}
addon.Graphics = Graphics

Graphics.settings = {
    {
        key = "groundEffectDensity",
        label = "Grass & ground-effect density",
        description = "Direct ground-effect density; higher values add more grass and small ground details.",
        min = 16,
        max = 256,
        step = 8,
        parent = "graphicsGroundClutter",
    },
}

local byKey = {}
for _, setting in ipairs(Graphics.settings) do
    byKey[setting.key] = setting
end

local saved
local refreshPending = {}

local function readableNumber(value)
    if not addon.Client.Readable(value) or (type(value) ~= "number" and type(value) ~= "string") then
        return nil
    end

    local number = tonumber(value)
    if addon.Client.Number(number) then
        return number
    end
end

local function read(api, name)
    if type(api) ~= "function" then
        return nil
    end

    local ok, value = pcall(api, name)
    if ok and addon.Client.Readable(value) then
        return value
    end
end

local function notBlocked(value)
    if not addon.Client.Readable(value) then
        return false
    end

    return value == nil or addon.Client.Boolean(value) == false
end

function Graphics.Status(key)
    local setting = byKey[key]
    if not setting then
        return { available = false, writable = false }
    end

    local current, default, locked, readOnly
    if C_CVar and type(C_CVar.GetCVarInfo) == "function" then
        local ok, value, defaultValue, _, _, lockedValue, _, readOnlyValue = pcall(C_CVar.GetCVarInfo, key)
        if not ok or not addon.Client.Readable(value) then
            return { available = false, writable = false }
        end

        current, default, locked, readOnly = value, defaultValue, lockedValue, readOnlyValue
    else
        current = read(C_CVar and C_CVar.GetCVar, key) or read(GetCVar, key)
    end

    local value = readableNumber(current)
    if not value then
        return { available = false, writable = false }
    end

    local defaultValue = readableNumber(default)
        or readableNumber(read(C_CVar and C_CVar.GetCVarDefault, key))
        or readableNumber(read(GetCVarDefault, key))
    local inCombat = false
    if type(InCombatLockdown) == "function" then
        local ok, value = pcall(InCombatLockdown)
        inCombat = not ok or addon.Client.Boolean(value) ~= false
    end

    return {
        available = true,
        writable = notBlocked(locked) and notBlocked(readOnly) and not inCombat
            and type(C_CVar and C_CVar.SetCVar or SetCVar) == "function",
        value = value,
        default = defaultValue,
    }
end

local function valid(setting, value)
    return addon.Client.Number(value) and value >= setting.min and value <= setting.max
        and (value - setting.min) % setting.step == 0
end

local function write(key, value)
    local status = Graphics.Status(key)
    if not status.writable or not addon.Client.Number(value) then
        return false
    end

    if status.value == value then
        return true
    end

    local api = C_CVar and C_CVar.SetCVar or SetCVar
    if type(api) ~= "function" then
        return false
    end

    local ok, result = pcall(api, key, tostring(value))
    if not ok or not addon.Client.Readable(result) or result == false then
        return false
    end

    return Graphics.Status(key).value == value
end

function Graphics.Set(key, value)
    local setting = byKey[key]
    if not setting or not valid(setting, value) or not write(key, value) then
        return false
    end

    saved[key] = value
    return true
end

function Graphics.Reset(key)
    if not byKey[key] then
        return false
    end

    local default = Graphics.Status(key).default
    if not default or not write(key, default) then
        return false
    end

    saved[key] = nil
    return true
end

function Graphics.ApplySaved(key)
    if not saved then
        return
    end

    for _, setting in ipairs(Graphics.settings) do
        if not key or key == setting.key then
            local value = saved[setting.key]
            if valid(setting, value) then
                write(setting.key, value)
            elseif value ~= nil then
                saved[setting.key] = nil
            end
        end
    end
end

function Graphics.Initialize()
    if type(UtilsAssistForeverGraphicsDB) ~= "table" then
        UtilsAssistForeverGraphicsDB = {}
    end

    saved = UtilsAssistForeverGraphicsDB
    Graphics.ApplySaved()
end

function Graphics.OnCVarUpdate(name)
    if not addon.Client.String(name) then
        return
    end

    for _, setting in ipairs(Graphics.settings) do
        if name == setting.parent and saved and valid(setting, saved[setting.key])
            and not refreshPending[setting.key] then
            local key = setting.key
            refreshPending[key] = true
            local function restore()
                refreshPending[key] = nil
                Graphics.ApplySaved(key)
                addon.SettingsPanel:Refresh()
            end

            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0.1, restore)
            else
                restore()
            end
        end
    end

    if byKey[name] then
        addon.SettingsPanel:Refresh()
    end
end
