local Helpers = {}

function Helpers.equal(actual, expected, message)
    assert(actual == expected, (message or 'values differ') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

function Helpers.new()
    local world = {
        spells = {
            [10] = { name = 'Ranged shot', spellID = 10, minRange = 8, maxRange = 35 },
            [20] = { name = 'Short ranged spell', spellID = 20, minRange = 0, maxRange = 15 },
            [30] = { name = 'Long ranged spell', spellID = 30, minRange = 0, maxRange = 100 },
            [40] = { name = 'Melee strike', spellID = 40, minRange = 0, maxRange = 5 },
        },
        learned = { 10, 20, 30, 40 },
        ranges = { [10] = false, [20] = true, [30] = true, [40] = false },
        queries = {},
        mouseover = { exists = false, attackable = false, dead = false, ranges = {} },
        actions = {},
        exists = true,
        attackable = true,
        dead = false,
        class = 'HUNTER',
        combat = false,
        frames = {},
        messages = {},
        bookReads = 0,
    }
    local secret = setmetatable({}, {
        __eq = function() error('restricted comparison') end,
        __lt = function() error('restricted ordering') end,
        __le = function() error('restricted ordering') end,
        __tostring = function() error('restricted stringification') end,
    })
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.issecretvalue = function(value) return rawequal(value, secret) end
    env.Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2, PetAction = 3 } }
    local function unitState(unit)
        assert(unit == 'target' or unit == 'mouseover')
        if unit == 'mouseover' then return world.mouseover end
        return world
    end
    env.UnitExists = function(unit) return unitState(unit).exists end
    env.UnitCanAttack = function(player, unit) assert(player == 'player'); return unitState(unit).attackable end
    env.UnitIsDeadOrGhost = function(unit) return unitState(unit).dead end
    env.UnitClass = function() return 'Hunter', world.class end
    env.InCombatLockdown = function() return world.combat end
    env.C_Spell = {
        GetSpellInfo = function(id) return world.spells[id] end,
        IsSpellHarmful = function(id) return not world.helpful or not world.helpful[id] end,
        IsSpellInRange = function(id, unit)
            local state = unitState(unit)
            world.queries[id] = (world.queries[id] or 0) + 1
            return state.ranges[id]
        end,
    }
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() world.bookReads = world.bookReads + 1; return 1 end,
        GetSpellBookSkillLineInfo = function()
            return { name = 'Hunter', iconID = 1, itemIndexOffset = 0, numSpellBookItems = #world.learned,
                isGuild = false, shouldHide = false }
        end,
        GetSpellBookItemInfo = function(index, bank)
            assert(bank == 0)
            local id = world.learned[index]
            return { actionID = id, spellID = id, itemType = 1, name = 'Spell', subName = '', iconID = 1,
                isPassive = false, isOffSpec = false, skillLineIndex = 1 }
        end,
    }
    env.GetActionInfo = function(slot)
        local action = world.actions[slot]
        if action then return action[1], action[2], action[3] end
    end
    env.hooksecurefunc = function(object, method, callback)
        local original = assert(object[method], 'unknown hook: ' .. method)
        object[method] = function(...)
            original(...)
            callback(...)
        end
    end
    env.SlashCmdList = {}
    env.GetBuildInfo = function() return '1.60.1', 'test', 'date', 16001 end
    env.print = function(message) world.messages[#world.messages + 1] = message end

    world.env = env
    world.secret = secret
    world.addon = {}

    function world:load(...)
        for _, file in ipairs({ ... }) do
            local chunk = loadfile('UtilsAssistForever/' .. file .. '.lua', 't', self.env)
            if chunk then chunk('UtilsAssistForever', self.addon) end
        end
        return self.addon
    end

    local function frame(kind, name, parent, template)
        local value = { scripts = {}, events = {}, shown = true, width = 580, kind = kind, parent = parent,
            template = template, children = {}, color = { 1, 1, 1, 1 }, desaturation = 0, writes = 0,
            mouseEnabled = true, mouseWrites = 0, textureWrites = 0 }
        function value:SetPoint(...)
            self.point = { ... }
            self.points = self.points or {}
            self.points[#self.points + 1] = self.point
        end
        function value:SetSize(width, height) self.width = width; self.height = height end
        function value:SetWidth(width) self.width = width end
        function value:GetWidth() return self.width end
        function value:SetHeight(height) self.height = height end
        function value:SetBackdrop(backdrop) self.backdrop = backdrop end
        function value:SetBackdropColor(...) self.backdropColor = { ... } end
        function value:SetBackdropBorderColor(...) self.borderColor = { ... } end
        function value:SetJustifyH(justify) self.justify = justify end
        function value:SetText(text) self.text = text end
        function value:SetTextColor(...) self.textColor = { ... } end
        function value:SetFontObject(font) self.font = font end
        function value:SetMinMaxValues(minimum, maximum) self.minimum = minimum; self.maximum = maximum end
        function value:SetValueStep(step) self.step = step end
        function value:SetObeyStepOnDrag(obey) self.obeyStepOnDrag = obey end
        function value:SetValue(amount)
            self.value = amount
            if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, amount) end
        end
        function value:GetValue() return self.value end
        function value:SetEnabled(enabled) self.enabled = enabled end
        function value:IsEnabled() return self.enabled ~= false end
        function value:SetChecked(checked) self.checked = checked end
        function value:GetChecked() return self.checked end
        function value:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
        function value:SetShown(shown) if shown then self:Show() else self:Hide() end end
        function value:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
        function value:IsVisible() return self.shown end
        function value:SetScript(event, callback) self.scripts[event] = callback end
        function value:RegisterEvent(event) self.events[event] = true end
        function value:UnregisterAllEvents() self.events = {} end
        function value:CreateFontString() return frame('FontString', nil, self) end
        function value:CreateTexture() return frame('Texture', nil, self) end
        function value:SetTexture(texture) self.texture = texture; self.textureWrites = self.textureWrites + 1 end
        function value:GetTexture() return self.texture end
        function value:SetAllPoints() end
        function value:SetScrollChild(child) self.scrollChild = child end
        function value:ClearAllPoints() self.point = nil; self.points = {} end
        function value:SetMovable(movable) self.movable = movable end
        function value:SetClampedToScreen(clamped) self.clamped = clamped end
        function value:EnableMouse(enabled)
            self.mouseEnabled = enabled
            self.mouseWrites = self.mouseWrites + 1
        end
        function value:IsMouseEnabled() return self.mouseEnabled end
        function value:RegisterForDrag(...) self.dragButtons = { ... } end
        function value:StartMoving() self.moving = true end
        function value:StopMovingOrSizing() self.moving = false end
        function value:GetCenter() return self.centerX or 500, self.centerY or 500 end
        function value:GetFrameLevel() return self.level or 1 end
        function value:SetFrameLevel(level) self.level = level end
        function value:SetFrameStrata(strata) self.strata = strata end
        function value:SetAutoFocus(value) self.autoFocus = value end
        function value:SetNumeric(value) self.numeric = value end
        function value:SetMaxLetters(value) self.maxLetters = value end
        function value:GetText() return self.text end
        function value:ClearFocus() self.focused = false end
        function value:SetVertexColor(r, g, b, a) self.color = { r, g, b, a or 1 }; self.writes = self.writes + 1 end
        function value:GetVertexColor() return table.unpack(self.color) end
        function value:SetDesaturated(active) self.desaturation = active and 1 or 0; self.writes = self.writes + 1 end
        function value:SetDesaturation(amount) self.desaturation = amount; self.writes = self.writes + 1 end
        function value:GetDesaturation() return self.desaturation end
        function value:IsDesaturated() return self.desaturation == 1 end

        if template == 'UICheckButtonTemplate' then value.Text = frame('FontString', nil, value) end
        if name then env[name] = value end
        if parent then parent.children[#parent.children + 1] = value end
        world.frames[#world.frames + 1] = value
        return value
    end

    env.UIParent = frame('Frame')
    env.CreateFrame = frame
    env.Settings = {
        VarType = { Boolean = 'boolean', Number = 'number' },
        RegisterCanvasLayoutCategory = function(canvas, name)
            world.category = { canvas = canvas, name = name, GetID = function() return 123 end }
            return world.category
        end,
        RegisterProxySetting = function(category, variable, valueType, name, default, getter, setter)
            assert(category == world.category and (valueType == 'boolean' or valueType == 'number'))
            world.setting = { GetValue = function() return getter() end, SetValue = function(_, value) setter(value) end }
            return world.setting
        end,
        RegisterAddOnCategory = function(category) assert(category == world.category) end,
        OpenToCategory = function(id) world.openCategory = id end,
    }

    function world:button(name, slot)
        local button = frame('CheckButton', name)
        button.action = slot
        button.icon = frame('Texture', nil, button)
        return button
    end

    function world:fire(event, ...)
        for _, value in ipairs(self.frames) do
            if value.events[event] and value.scripts.OnEvent then value.scripts.OnEvent(value, event, ...) end
        end
    end

    function world:tick(elapsed)
        for _, value in ipairs(self.frames) do
            if value.scripts.OnUpdate then value.scripts.OnUpdate(value, elapsed) end
        end
    end

    return world
end

return Helpers
