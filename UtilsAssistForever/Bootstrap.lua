local _, addon = ...
local frame = CreateFrame("Frame")
local elapsedSinceUpdate, elapsedSinceDiscovery = 0, 0
local discoveryDirty, catalogDirty = false, false
local discoveryEvents = {
    "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_MACROS",
    "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID",
}

local function update(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    elapsedSinceDiscovery = elapsedSinceDiscovery + elapsed
    if elapsedSinceUpdate < 0.1 then
        return
    end

    local discover = discoveryDirty or elapsedSinceDiscovery >= 0.5
    elapsedSinceUpdate = 0
    if discover then
        elapsedSinceDiscovery = 0
    end

    addon:Refresh(discover, catalogDirty)
    discoveryDirty, catalogDirty = false, false
end

function addon:SetPolling(enabled)
    elapsedSinceUpdate, elapsedSinceDiscovery = 0, 0
    discoveryDirty, catalogDirty = false, false
    frame:SetScript("OnUpdate", enabled and update or nil)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        addon.Config.Initialize()
        addon.Graphics.Initialize()
        addon.SettingsPanel:Initialize()
        addon:Start()
        if not addon.started then
            self:UnregisterAllEvents()
            return
        end

        for _, name in ipairs(discoveryEvents) do
            self:RegisterEvent(name)
        end
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("CVAR_UPDATE")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("PLAYER_TALENT_UPDATE")
        self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        self:RegisterEvent("SPELL_DATA_LOAD_RESULT")
        self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        self:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELL_UPDATE_USABLE")
        self:RegisterEvent("BAG_UPDATE_COOLDOWN")
        self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
        self:RegisterEvent("PET_BAR_UPDATE_USABLE")
        return
    end

    if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
        addon:Refresh(false, catalogDirty)
        catalogDirty = false
    elseif event == "PLAYER_REGEN_ENABLED" then
        addon.Graphics.ApplySaved()
        addon.SettingsPanel:Refresh()
        addon.BarClickThrough:OnCombatEnd()
        addon:Refresh(true, true)
        discoveryDirty, catalogDirty = false, false
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon.Graphics.ApplySaved()
        addon:Refresh(true, true)
        discoveryDirty, catalogDirty = false, false
    elseif event == "CVAR_UPDATE" then
        addon.Graphics.OnCVarUpdate(...)
    elseif event == "PLAYER_REGEN_DISABLED" then
        addon.SettingsPanel:Refresh()
        if addon.BarClickThrough:Enabled() then
            addon.BarClickThrough:Refresh(false)
        end
    elseif event == "UPDATE_MACROS" then
        catalogDirty, discoveryDirty = true, true
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
        or event == "UPDATE_SHAPESHIFT_FORM" or event == "SPELL_DATA_LOAD_RESULT" then
        catalogDirty = true
    elseif event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_USABLE"
        or event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE"
        or event == "BAG_UPDATE_COOLDOWN" or event == "PET_BAR_UPDATE_COOLDOWN"
        or event == "PET_BAR_UPDATE_USABLE" then
        if addon.CooldownGrey:Enabled() then
            addon.CooldownGrey:Refresh(false)
        end
    else
        discoveryDirty = true
    end
end)

SLASH_UTILSASSISTFOREVER1 = "/uaf"
SlashCmdList.UTILSASSISTFOREVER = function(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "config" then
        addon.SettingsPanel:Open()
        return
    end

    if addon.BarClickThrough:Command(message) then
        return
    end

    addon:Refresh(true, true)
    print("Utils Assist Forever " .. addon.version .. " | /uaf config to configure")
    print("Ranged: " .. (addon.Config.Get("checkRangedAbilities") and "enabled" or "disabled")
        .. " | melee: " .. (addon.Config.Get("checkMeleeAbilities") and "enabled" or "disabled"))
    print("Default buttons: " .. #addon.RangeCheck.buttons
        .. " | out-of-range buttons: " .. addon.RangeCheck.colored)
    print("Cooldown greying: " .. (addon.Config.Get("greyOnCooldown") and "enabled" or "disabled")
        .. " | greyed buttons: " .. addon.CooldownGrey.greyed)
    local clickThrough = {}
    for index = 1, 8 do
        if addon.Config.Get("clickThroughBar" .. index) then
            clickThrough[#clickThrough + 1] = index
        end
    end
    print("Click-through bars: " .. (#clickThrough > 0 and table.concat(clickThrough, ", ") or "none"))
    if addon.RangeCheck:Enabled() then
        for _, line in ipairs(addon.RangeCheck.references) do
            print(line)
        end
        for _, line in ipairs(addon.Range:DescribeChecks()) do
            print(line)
        end
    end
end

SLASH_BNC1 = "/bnc"
SLASH_BNC2 = "/barnoclicky"
SlashCmdList.BNC = function(message)
    if not addon.BarClickThrough:Command(message) then
        addon.BarClickThrough:Help()
    end
end
