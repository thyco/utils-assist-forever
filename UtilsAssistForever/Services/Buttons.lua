local _, addon = ...
local Buttons = {}
addon.Buttons = Buttons
local prefixes = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}

function Buttons.All()
    local buttons = {}
    for _, prefix in ipairs(prefixes) do
        for index = 1, 12 do
            local button = _G[prefix .. index]
            if button then
                buttons[#buttons + 1] = button
            end
        end
    end

    return buttons
end
