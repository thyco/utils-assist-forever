local _, addon = ...
local panel = { controls = {}, sections = {} }
addon.SettingsPanel = panel

local function checkbox(section, key, label, y, tooltip)
    local setting = Settings.RegisterProxySetting(panel.category, "UtilsAssistForever_" .. key,
        Settings.VarType.Boolean, label, addon.Config.GetDefault(key), function()
            return addon.Config.Get(key)
        end, function(value)
            addon.Config.Set(key, value)
        end)

    panel.controls[key] = addon.SettingsWidgets.Checkbox(section, label, y, setting, tooltip)
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
    canvas:SetHeight(520)
    canvas:Hide()
    self.category = Settings.RegisterCanvasLayoutCategory(canvas, "Utils Assist Forever")

    widgets.Text(canvas, "Utils Assist Forever", 8, -8, "GameFontNormalLarge")
    local range = widgets.Section(canvas, "Range checks", "All classes · all eight default action bars", -48, 146)
    self.sections = { range }
    local rangeTip = "Tint these abilities when your living attackable target is out of range. With no target selected, checks your mouseover."
    checkbox(range, "checkRangedAbilities", "Check ranged abilities", -62, rangeTip)
    checkbox(range, "checkMeleeAbilities", "Check melee abilities", -96, rangeTip)

    local cooldown = widgets.Section(canvas, "Cooldown greying", "Action icons on cooldown or unusable", -210, 248)
    self.sections[#self.sections + 1] = cooldown
    checkbox(cooldown, "greyOnCooldown", "Grey actions on cooldown", -62,
        "Desaturate action icons on a real cooldown. The global cooldown is ignored.")
    checkbox(cooldown, "greyUnusableActions", "Grey unusable actions", -96,
        "Desaturate actions WoW reports as unusable, except resource shortages.")
    checkbox(cooldown, "greyWithoutResources", "Grey actions without resources", -130,
        "Also desaturate actions when WoW reports insufficient mana, rage, energy or another resource.")
    checkbox(cooldown, "greyPetActions", "Grey pet actions", -164,
        "Include Blizzard pet action buttons in cooldown and unusable checks.")

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
