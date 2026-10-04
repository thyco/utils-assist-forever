local _, addon = ...
local Widgets = {}
addon.SettingsWidgets = Widgets

function Widgets.Text(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)

    return label
end

function Widgets.Tooltip(frame, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Widgets.Section(parent, title, description, y, height)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    section:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    section:SetHeight(height)
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    section:SetBackdropColor(0.035, 0.035, 0.045, 0.8)
    section:SetBackdropBorderColor(0.35, 0.31, 0.22, 1)

    Widgets.Text(section, title, 16, -14, "GameFontNormalLarge")
    local subtitle = Widgets.Text(section, description, 16, -38)
    subtitle:SetPoint("TOPRIGHT", section, "TOPRIGHT", -16, -38)
    subtitle:SetTextColor(0.7, 0.7, 0.7)

    return section
end

function Widgets.Checkbox(parent, label, y, setting, tooltip)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    check.Text:SetText(label)
    check.Text:SetFontObject("GameFontHighlight")
    check:SetScript("OnClick", function(self)
        setting:SetValue(not not self:GetChecked())
    end)
    check.refresh = function()
        check:SetChecked(setting:GetValue())
    end
    Widgets.Tooltip(check, tooltip)

    return check
end

