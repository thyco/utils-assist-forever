local _, addon = ...
local Buttons = {}
addon.Buttons = Buttons
local prefixes = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}
Buttons.BarPrefixes = prefixes

function Buttons.Bar(index)
    local buttons = {}
    local prefix = prefixes[index]
    if not prefix then
        return buttons
    end

    for buttonIndex = 1, 12 do
        local button = _G[prefix .. buttonIndex]
        if button then
            buttons[#buttons + 1] = button
        end
    end

    return buttons
end

function Buttons.All()
    local buttons = {}
    for barIndex = 1, #prefixes do
        for _, button in ipairs(Buttons.Bar(barIndex)) do
            buttons[#buttons + 1] = button
        end
    end

    return buttons
end

function Buttons.CooldownAll()
    local buttons = {}
    local seen = {}

    local function add(button, kind)
        if button and not seen[button] then
            seen[button] = true
            buttons[#buttons + 1] = { button = button, kind = kind }
        end
    end

    for _, button in ipairs(Buttons.All()) do
        add(button, "action")
    end

    for _, prefix in ipairs({ "ExtraActionButton", "StanceButton", "PossessButton",
        "OverrideActionBarButton", "SpellFlyoutPopupButton" }) do
        for index = 1, prefix == "SpellFlyoutPopupButton" and 40 or 12 do
            add(_G[prefix .. index], "action")
        end
    end

    for index = 1, NUM_PET_ACTION_SLOTS or 10 do
        add(_G["PetActionButton" .. index], "pet")
    end

    if LibStub and type(LibStub.GetLibrary) == "function" then
        local ok, library = pcall(LibStub.GetLibrary, LibStub, "LibActionButton-1.0", true)
        if ok and type(library) == "table" and type(library.buttonRegistry) == "table" then
            for button in pairs(library.buttonRegistry) do
                add(button, "lab")
            end
        end
    end

    if Dominos and Dominos.ActionButtons and type(Dominos.ActionButtons.buttons) == "table" then
        for button in pairs(Dominos.ActionButtons.buttons) do
            add(button, "action")
        end
    end

    if Bartender4 and type(Bartender4.GetModule) == "function" then
        local ok, module = pcall(Bartender4.GetModule, Bartender4, "PetBar")
        if ok and module and module.bar and type(module.bar.buttons) == "table" then
            for _, button in ipairs(module.bar.buttons) do
                add(button, "pet")
            end
        end
    end

    return buttons
end
