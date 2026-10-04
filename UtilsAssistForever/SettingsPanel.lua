local _, addon = ...
local panel = { controls = {}, sections = {} }
addon.SettingsPanel = panel

local function checkbox(section, key, label, y, tooltip, x)
    local setting = Settings.RegisterProxySetting(panel.category, "UtilsAssistForever_" .. key,
        Settings.VarType.Boolean, label, addon.Config.GetDefault(key), function()
            return addon.Config.Get(key)
        end, function(value)
            addon.Config.Set(key, value)
        end)

    panel.controls[key] = addon.SettingsWidgets.Checkbox(section, label, y, setting, tooltip, x)
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

    local scroll = CreateFrame("ScrollFrame", nil, canvas, "ScrollFrameTemplate")
    self.scroll = scroll
    scroll:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -28, 0)

    local content = CreateFrame("Frame", nil, scroll)
    self.content = content
    content:SetSize(math.max(scroll:GetWidth(), 1), 704)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(width, 1))
    end)

    widgets.Text(content, "Utils Assist Forever", 8, -8, "GameFontNormalLarge")
    local range = widgets.Section(content, "Range checks", "All classes · all eight default action bars", -48, 146)
    self.sections = { range }
    local rangeTip = "Tint these abilities when your living attackable target is out of range. With no target selected, checks your mouseover."
    checkbox(range, "checkRangedAbilities", "Check ranged abilities", -62, rangeTip)
    checkbox(range, "checkMeleeAbilities", "Check melee abilities", -96, rangeTip)

    local cooldown = widgets.Section(content, "Cooldown greying", "Action icons on cooldown or unusable", -210, 248)
    self.sections[#self.sections + 1] = cooldown
    checkbox(cooldown, "greyOnCooldown", "Grey actions on cooldown", -62,
        "Desaturate action icons on a real cooldown. The global cooldown is ignored.")
    checkbox(cooldown, "greyUnusableActions", "Grey unusable actions", -96,
        "Desaturate actions WoW reports as unusable, except resource shortages.")
    checkbox(cooldown, "greyWithoutResources", "Grey actions without resources", -130,
        "Also desaturate actions when WoW reports insufficient mana, rage, energy or another resource.")
    checkbox(cooldown, "greyPetActions", "Grey pet actions", -164,
        "Include Blizzard pet action buttons in cooldown and unusable checks.")

    local click = widgets.Section(content, "Action bar click-through",
        "Mouse clicks pass through selected bars; key bindings still work", -474, 210)
    self.sections[#self.sections + 1] = click
    for index = 1, 8 do
        local column = index > 4 and 1 or 0
        local row = (index - 1) % 4
        checkbox(click, "clickThroughBar" .. index, "Bar " .. index .. " click-through",
            -62 - row * 34, "Disable mouse clicks on this default action bar. Changes made in combat apply when combat ends.",
            12 + column * 270)
    end

    canvas:SetScript("OnShow", function()
        content:SetWidth(math.max(scroll:GetWidth(), 1))
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
