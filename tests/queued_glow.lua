local H = dofile('tests/helpers.lua')
local equal = H.equal
local passed, failed = 0, 0

local function test(name, run)
    local ok, message = pcall(run)
    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(message))
    end
end

local function setup(configure)
    local world = H.new()
    world.class = 'WARRIOR'
    world.spells[78] = { name = 'Heroic Strike', spellID = 78, minRange = 0, maxRange = 0 }
    world.spells[1715] = { name = 'Hamstring', spellID = 1715, minRange = 0, maxRange = 5 }
    world.learned = { 78, 1715 }
    world.exists = false
    world.actions[1] = { 'spell', 78 }
    world.main = world:button('ActionButton1', 1)
    world.main:SetChecked(false)
    world.env.UtilsAssistForeverDB = {
        checkRangedAbilities = false,
        checkMeleeAbilities = false,
        greyOnCooldown = false,
        greyUnusableActions = false,
        greyPetActions = false,
    }
    world.env.C_Spell.GetSpellSubtext = function() return '' end
    world.env.C_ActionBar = { GetActionText = function(slot) return world.actionNames and world.actionNames[slot] end }
    world.env.Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120 } }
    world.env.GetNumMacros = function() return world.macros and 1 or 0, 0 end
    world.env.GetMacroInfo = function(index)
        local macro = world.macros and world.macros[index]
        if macro then return macro[1], 1, macro[2] end
    end
    world.env.SecureCmdOptionParse = function(args)
        equal(args, '[combat] Heroic Strike; Shoot Bow')
        return world.combat and 'Heroic Strike' or 'Shoot Bow'
    end

    world.glowStarts = 0
    local library = {}
    function library.PixelGlow_Start(frame, color, count, frequency, length, thickness, x, y, border, key)
        equal(count, 4)
        equal(border, true)
        world.glowStarts = world.glowStarts + 1
        world.glowStartColor = color and { color[1], color[2], color[3], color[4] } or nil
        if not frame['_PixelGlow' .. key] then
            local effect = world.env.CreateFrame('Frame', nil, frame)
            effect.textures = { effect:CreateTexture(), effect:CreateTexture() }
            frame['_PixelGlow' .. key] = effect
        end
        local applied = color or world.nativePixelColor or { 0.95, 0.95, 0.32, 1 }
        for _, texture in ipairs(frame['_PixelGlow' .. key].textures) do
            texture:SetVertexColor(applied[1], applied[2], applied[3], applied[4])
        end
    end
    world.env.LibStub = function(name)
        equal(name, 'LibCustomGlow-1.0')
        return library
    end
    world.env.ColorPickerFrame = {
        SetupColorPickerAndShow = function(self, info) self.info = info end,
        GetColorRGB = function(self) return self.r, self.g, self.b end,
    }

    if configure then configure(world) end

    local manifest = assert(io.open('UtilsAssistForever/UtilsAssistForever.toc'))
    for line in manifest:lines() do
        if line:match('%.lua$') and not line:match('^Libs/') then
            assert(loadfile('UtilsAssistForever/' .. line, 't', world.env))('UtilsAssistForever', world.addon)
        end
    end
    manifest:close()
    world:fire('PLAYER_LOGIN')

    return world, world.addon
end

local function visible(world)
    for _, child in ipairs(world.main.children) do
        local effect = child._PixelGlowUtilsAssistForeverQueued
        if effect then return effect:IsVisible() end
    end

    return false
end

local function effect(world)
    for _, child in ipairs(world.main.children) do
        if child._PixelGlowUtilsAssistForeverQueued then
            return child._PixelGlowUtilsAssistForeverQueued
        end
    end
end

test('queued direct Heroic Strike glows without a target', function()
    local world = setup()

    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)
end)

test('clearing native checked state clears queued glow', function()
    local world = setup()
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    world.main:SetChecked(false)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)
end)

test('conditional macro glows only while combat branch is active', function()
    local world = setup(function(w)
        w.macros = { [1] = { 'Switch', '#showtooltip\n/cast [combat] Heroic Strike; Shoot Bow' } }
        w.actionNames = { [1] = 'Switch' }
        w.actions[1] = { 'macro', 78, 'spell' }
    end)
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)

    world.combat = true
    world:fire('PLAYER_REGEN_DISABLED')
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)

    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')

    equal(visible(world), false)
end)

test('checked ordinary spell does not glow', function()
    local world = setup(function(w) w.actions[1] = { 'spell', 1715 } end)

    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)
end)

test('explicit mouseover macro can glow without a range target', function()
    local world = setup(function(w)
        w.macros = { [1] = { 'Mouseover Swing', '/cast [@mouseover] Heroic Strike' } }
        w.actionNames = { [1] = 'Mouseover Swing' }
        w.actions[1] = { 'macro', 78, 'spell' }
        w.env.SecureCmdOptionParse = function() return 'Heroic Strike', 'mouseover' end
    end)

    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)
end)

test('target change refreshes a target-conditional macro branch', function()
    local world = setup(function(w)
        w.exists = true
        w.macros = { [1] = { 'Target Swing', '/cast [harm] Heroic Strike; Shoot Bow' } }
        w.actionNames = { [1] = 'Target Swing' }
        w.actions[1] = { 'macro', 78, 'spell' }
        w.env.SecureCmdOptionParse = function()
            return w.exists and 'Heroic Strike' or 'Shoot Bow'
        end
    end)
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)

    world.exists = false
    world:fire('PLAYER_TARGET_CHANGED')

    equal(visible(world), false)
end)

test('spellbook change clears a no-longer-learned queued attack', function()
    local world = setup()
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)

    world.learned = { 1715 }
    world:fire('SPELLS_CHANGED')
    world:tick(0.1)

    equal(visible(world), false)
end)

test('unknown checked state does not glow', function()
    local world = setup()
    world.main.GetChecked = function() return world.secret end

    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)
end)

test('setting disables queued glow and is saved per character', function()
    local world, addon = setup()
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    addon.Config.Set('highlightQueuedAttacks', false)

    equal(visible(world), false)
    equal(world.env.UtilsAssistForeverDB.highlightQueuedAttacks, false)
end)

test('saved per-character color is used when the glow is prepared', function()
    local world = setup(function(w)
        w.env.UtilsAssistForeverDB.queuedGlowColor = 'ffcc4d1a'
    end)

    local texture = effect(world).textures[1]
    equal(texture.color[1], 204 / 255)
    equal(texture.color[2], 77 / 255)
    equal(texture.color[3], 26 / 255)
    equal(texture.color[4], 1)
    equal(world.glowStartColor, nil)
end)

test('changing color recolors an active glow without recreating the effect', function()
    local world, addon = setup()
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)
    local starts = world.glowStarts

    addon.Config.Set('queuedGlowColor', 'ffe6331a')

    local texture = effect(world).textures[1]
    equal(texture.color[1], 230 / 255)
    equal(texture.color[2], 51 / 255)
    equal(texture.color[3], 26 / 255)
    equal(texture.color[4], 1)
    equal(world.glowStarts, starts)
    equal(world.env.UtilsAssistForeverDB.queuedGlowColor, 'ffe6331a')
end)

test('invalid saved color resets to cyan default', function()
    local world, addon = setup(function(w)
        w.env.UtilsAssistForeverDB.queuedGlowColor = 'invalid'
    end)

    equal(addon.Config.Get('queuedGlowColor'), 'ff26d9ff')
    equal(effect(world).textures[1].color[1], 38 / 255)
end)

test('native glow color uses the library default without disabling the glow', function()
    local world, addon = setup(function(w)
        w.env.UtilsAssistForeverDB.queuedGlowNativeColor = true
    end)
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(world.glowStartColor, nil)
    equal(visible(world), true)

    addon.Config.Set('queuedGlowNativeColor', false)
    equal(effect(world).textures[1].color[1], 38 / 255)

    addon.Config.Set('queuedGlowNativeColor', true)
    equal(effect(world).textures[1].color[1], 0.95)
    equal(visible(world), true)
end)

test('native glow restores the actual library default after a custom color', function()
    local world, addon = setup(function(w)
        w.nativePixelColor = { 0.4, 0.5, 0.6, 1 }
    end)

    addon.Config.Set('queuedGlowNativeColor', true)

    equal(effect(world).textures[1].color[1], 0.4)
    equal(effect(world).textures[1].color[2], 0.5)
    equal(effect(world).textures[1].color[3], 0.6)
end)

test('Blizzard color picker updates the glow and cancel restores the prior color', function()
    local world, addon = setup()
    local swatch = addon.SettingsPanel.controls.queuedGlowColor
    swatch.scripts.OnClick(swatch)
    local picker = world.env.ColorPickerFrame
    local original = picker.info

    equal(original.r, 38 / 255)
    equal(original.g, 217 / 255)
    equal(original.b, 1)
    equal(original.hasOpacity, false)
    picker.r, picker.g, picker.b = 1, 0.25, 0.5
    original.swatchFunc()

    equal(addon.Config.Get('queuedGlowColor'), 'ffff4080')
    equal(effect(world).textures[1].color[2], 64 / 255)

    original.cancelFunc()

    equal(addon.Config.Get('queuedGlowColor'), 'ff26d9ff')
end)

test('restricted color picker values leave the saved color unchanged', function()
    local world, addon = setup()
    local swatch = addon.SettingsPanel.controls.queuedGlowColor
    swatch.scripts.OnClick(swatch)
    world.env.ColorPickerFrame.GetColorRGB = function() return world.secret, 0, 0 end

    world.env.ColorPickerFrame.info.swatchFunc()

    equal(addon.Config.Get('queuedGlowColor'), 'ff26d9ff')
end)

test('queued glow has its own setting in the settings page', function()
    local world, addon = setup()

    assert(addon.SettingsPanel.controls.highlightQueuedAttacks)
    equal(world.category.name, 'Utils Assist Forever')
end)

test('idle polls do not rescan queued button state', function()
    local reads = 0
    local world = setup(function(w)
        local getChecked = w.main.GetChecked
        w.main.GetChecked = function(button)
            reads = reads + 1
            return getChecked(button)
        end
    end)
    local initialReads = reads

    world:tick(0.1)
    world:tick(0.1)
    world:tick(0.1)

    equal(reads, initialReads)
end)

print(('Queued glow: %d passed, %d failed'):format(passed, failed))
if failed > 0 then os.exit(1) end
