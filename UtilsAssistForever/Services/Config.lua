local _, addon = ...
local Config = {}
addon.Config = Config
local defaults = {
    checkRangedAbilities = true,
    checkMeleeAbilities = true,
    highlightQueuedAttacks = true,
    queuedGlowNativeColor = false,
    queuedGlowColor = "ff26d9ff",
    greyOnCooldown = true,
    greyUnusableActions = true,
    greyWithoutResources = false,
    greyPetActions = true,
}
for index = 1, 8 do
    defaults["clickThroughBar" .. index] = false
end
local values
local listeners = {}

local function validValue(key, value)
    if not addon.Client.Readable(value) then
        return false
    end

    if key == "queuedGlowColor" then
        return addon.Client.String(value) and #value == 8 and value:match("^%x+$") ~= nil
    end

    return type(value) == "boolean"
end

local function normalize(key, value)
    if key == "queuedGlowColor" then
        return "ff" .. value:sub(3):lower()
    end

    return value
end

function Config.Initialize()
    if type(UtilsAssistForeverDB) ~= "table" then
        UtilsAssistForeverDB = {}
    end

    values = UtilsAssistForeverDB
    for key, default in pairs(defaults) do
        if validValue(key, values[key]) then
            values[key] = normalize(key, values[key])
        else
            values[key] = default
        end
    end
end

function Config.GetDefault(key)
    return defaults[key]
end

function Config.Get(key)
    if values and values[key] ~= nil then
        return values[key]
    end

    return defaults[key]
end

function Config.GetColor(key)
    local hex = Config.Get(key)
    return {
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        tonumber(hex:sub(7, 8), 16) / 255,
        1,
    }
end

function Config.Set(key, value)
    assert(defaults[key] ~= nil, "Unknown configuration key: " .. key)
    assert(validValue(key, value), "Invalid configuration value: " .. key)
    value = normalize(key, value)

    if not values then
        Config.Initialize()
    end

    if values[key] == value then
        return
    end

    values[key] = value
    for _, listener in ipairs(listeners) do
        listener(key, value)
    end
end

function Config.Subscribe(listener)
    listeners[#listeners + 1] = listener
end
