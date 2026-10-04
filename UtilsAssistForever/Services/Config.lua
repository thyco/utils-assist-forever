local _, addon = ...
local Config = {}
addon.Config = Config
local defaults = { checkRangedAbilities = true, checkMeleeAbilities = true }
local values
local listeners = {}

function Config.Initialize()
    if type(UtilsAssistForeverDB) ~= "table" then
        UtilsAssistForeverDB = {}
    end

    values = UtilsAssistForeverDB
    for key, default in pairs(defaults) do
        if type(values[key]) ~= "boolean" then
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

function Config.Set(key, value)
    assert(defaults[key] ~= nil, "Unknown configuration key: " .. key)
    assert(type(value) == "boolean", "Invalid configuration value: " .. key)
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
