local _, addon = ...
-- Adapted from BarNoClicky 1.0.6 by mostlyharmlessx (GPL-3.0).
local feature = { buttons = {} }
addon.BarClickThrough = feature
local Client = addon.Client

function feature:Enabled()
    for index = 1, 8 do
        if addon.Config.Get("clickThroughBar" .. index) then
            return true
        end
    end

    return false
end

local function setMouse(button, enabled)
    if InCombatLockdown() or type(button.EnableMouse) ~= "function" then
        return false
    end

    local current = Client.Read(button.IsMouseEnabled, button)
    if Client.Boolean(current) == enabled then
        return true
    end

    local ok = pcall(button.EnableMouse, button, enabled)
    return ok
end

function feature:Discover()
    self.buttons = {}
    for barIndex = 1, 8 do
        for _, button in ipairs(addon.Buttons.Bar(barIndex)) do
            self.buttons[#self.buttons + 1] = { button = button, barIndex = barIndex }
        end
    end
end

function feature:ApplyMouse()
    local shiftHeld = Client.Boolean(Client.Read(IsShiftKeyDown)) == true

    for _, entry in ipairs(self.buttons) do
        local enabled = shiftHeld or not addon.Config.Get("clickThroughBar" .. entry.barIndex)
        setMouse(entry.button, enabled)
    end
end

function feature:OnModifierChanged(key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then
        return
    end

    if InCombatLockdown() or not self:Enabled() then
        return
    end

    self:ApplyMouse()
end

local function refreshMacroIcon(button)
    local slot = button.action
    local kind = Client.ActionInfo(slot)
    if kind ~= "macro" or not button.icon or type(button.icon.SetTexture) ~= "function" then
        return
    end

    local texture = Client.Read(C_ActionBar and C_ActionBar.GetActionTexture, slot)
    if texture == nil then
        texture = Client.Read(GetActionTexture, slot)
    end
    if not Client.Readable(texture) or (not Client.Number(texture) and not Client.String(texture)) then
        return
    end

    local current = Client.Read(button.icon.GetTexture, button.icon)
    if current ~= texture then
        pcall(button.icon.SetTexture, button.icon, texture)
    end
end

function feature:Refresh(discover)
    if discover then
        self:Discover()
        self:ApplyMouse()
    end

    for _, entry in ipairs(self.buttons) do
        if addon.Config.Get("clickThroughBar" .. entry.barIndex)
            and Client.Boolean(Client.Read(entry.button.IsVisible, entry.button)) == true then
            refreshMacroIcon(entry.button)
        end
    end
end

function feature:Stop()
    for _, entry in ipairs(self.buttons) do
        setMouse(entry.button, true)
    end
end

function feature:OnCombatEnd()
    if not self:Enabled() then
        self:Stop()
    end
end

local function selection(argument, clickThrough)
    if argument == "all" or argument == "*" then
        for index = 1, 8 do
            addon.Config.Set("clickThroughBar" .. index, clickThrough)
        end
        return true
    end

    local index = tonumber(argument)
    if index and index == math.floor(index) and index >= 1 and index <= 8 then
        addon.Config.Set("clickThroughBar" .. index, clickThrough)
        return true
    end

    return false
end

function feature:Command(message)
    local command, argument = (message or ""):lower():match("^%s*(%S+)%s*(.-)%s*$")
    if command == "clicky" or command == "c" or command == "noclicky" or command == "nc" then
        local clickThrough = command == "noclicky" or command == "nc"
        if selection(argument, clickThrough) then
            local bars = (argument == "*" or argument == "all") and "all bars" or "bar " .. argument
            print("Click-through " .. (clickThrough and "enabled" or "disabled") .. " for "
                .. bars
                .. (InCombatLockdown() and " (applies after combat)" or ""))
        else
            print("Use /uaf clicky|noclicky 1-8|all")
        end
        return true
    elseif command == "options" or command == "o" then
        addon.SettingsPanel:Open()
        return true
    elseif command == "status" or command == "s" then
        for index = 1, 8 do
            print("Bar " .. index .. ": "
                .. (addon.Config.Get("clickThroughBar" .. index) and "click-through" or "clickable"))
        end
        return true
    elseif command == "version" or command == "v" then
        print("Utils Assist Forever " .. addon.version)
        return true
    end

    return false
end

function feature:Help()
    print("Use /uaf config or /uaf clicky|noclicky 1-8|all; /uaf status lists bars.")
end

addon:RegisterFeature(feature)
