local _, addon = ...
local panel = { controls = {}, sections = {} }
addon.SettingsPanel = panel

local function checkbox(section, key, label, y)
    local setting = Settings.RegisterProxySetting(panel.category, "UtilsAssistForever_" .. key,
        Settings.VarType.Boolean, label, addon.Config.GetDefault(key), function()
            return addon.Config.Get(key)
        end, function(value)
            addon.Config.Set(key, value)
        end)

    panel.controls[key] = addon.SettingsWidgets.Checkbox(section, label, y, setting,
        "Tint these abilities when your living attackable target is out of range. With no target selected, checks your mouseover.")
end

function panel:Refresh()
    for _, control in pairs(self.controls) do
        control.refresh()
    end
end

function panel:Initialize()
    if self.category then
        return
    end

    local widgets = addon.SettingsWidgets
    local canvas = CreateFrame("Frame")
    self.canvas = canvas
    canvas:Hide()
    self.category = Settings.RegisterCanvasLayoutCategory(canvas, "Utils Assist Forever")

    widgets.Text(canvas, "Utils Assist Forever", 8, -8, "GameFontNormalLarge")
    local range = widgets.Section(canvas, "Range checks", "All classes · all eight default action bars", -48, 146)
    self.sections = { range }
    checkbox(range, "checkRangedAbilities", "Check ranged abilities", -62)
    checkbox(range, "checkMeleeAbilities", "Check melee abilities", -96)

    canvas:SetScript("OnShow", function()
        self:Refresh()
    end)
    addon.Config.Subscribe(function()
        self:Refresh()
    end)
    self:Refresh()
    Settings.RegisterAddOnCategory(self.category)
end

function panel:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
