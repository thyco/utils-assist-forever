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
    world.main = world:button('ActionButton1', 1)
    world.side = world:button('MultiBarBottomLeftButton1', 61)
    world.actions[1] = { 'macro', 10, 'spell' }
    world.actions[61] = { 'spell', 20 }
    world.main.icon.texture = 101
    world.side.icon.texture = 201
    world.env.C_ActionBar = {
        GetActionTexture = function(slot)
            if slot == 1 then return world.combat and 102 or 101 end
            return 202
        end,
    }

    world.shift = false
    world.env.IsShiftKeyDown = function() return world.shift end
    function world:holdShift(held)
        self.shift = held
        self:fire('MODIFIER_STATE_CHANGED', 'LSHIFT', held and 1 or 0)
    end

    world.env.UtilsAssistForeverDB = { clickThroughBar1 = true }
    if configure then configure(world) end

    local manifest = assert(io.open('UtilsAssistForever/UtilsAssistForever.toc'))
    for line in manifest:lines() do
        if line:match('%.lua$') then
            local chunk = assert(loadfile('UtilsAssistForever/' .. line, 't', world.env))
            chunk('UtilsAssistForever', world.addon)
        end
    end
    manifest:close()
    world:fire('PLAYER_LOGIN')

    return world, world.addon
end

test('selected bar becomes click-through and other bars stay clickable', function()
    local world = setup()

    equal(world.main.mouseEnabled, false)
    equal(world.side.mouseEnabled, true)
end)

test('holding Shift temporarily restores clicks without changing the saved bar choice', function()
    local world = setup()

    world:holdShift(true)

    equal(world.main.mouseEnabled, true)
    equal(world.side.mouseEnabled, true)
    equal(world.env.UtilsAssistForeverDB.clickThroughBar1, true)

    world:holdShift(false)

    equal(world.main.mouseEnabled, false)
    equal(world.side.mouseEnabled, true)
end)

test('Shift already held at login leaves a selected bar clickable until released', function()
    local world = setup(function(w)
        w.shift = true
    end)

    equal(world.main.mouseEnabled, true)

    world:holdShift(false)

    equal(world.main.mouseEnabled, false)
end)

test('bar choices changed while Shift is held apply when Shift is released', function()
    local world, addon = setup()
    world:holdShift(true)

    addon.Config.Set('clickThroughBar2', true)

    equal(world.side.mouseEnabled, true)
    equal(world.env.UtilsAssistForeverDB.clickThroughBar2, true)

    world:holdShift(false)

    equal(world.main.mouseEnabled, false)
    equal(world.side.mouseEnabled, false)
end)

test('Shift released in combat restores the saved choice after combat', function()
    local world = setup()
    world:holdShift(true)
    world.combat = true

    world:holdShift(false)
    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')

    equal(world.main.mouseEnabled, false)
end)

test('all eight bars have independent per-character settings', function()
    local world, addon = setup(function(w)
        for index, prefix in ipairs({ 'ActionButton', 'MultiBarBottomLeftButton',
            'MultiBarBottomRightButton', 'MultiBarRightButton', 'MultiBarLeftButton',
            'MultiBar5Button', 'MultiBar6Button', 'MultiBar7Button' }) do
            w:button(prefix .. '12', index + 100)
            w.actions[index + 100] = { 'spell', 20 }
        end
    end)
    addon.Config.Set('clickThroughBar8', true)

    equal(world.env.MultiBar7Button12.mouseEnabled, false)
    equal(world.env.MultiBar6Button12.mouseEnabled, true)
    equal(world.env.UtilsAssistForeverDB.clickThroughBar8, true)
end)

test('macro icon follows combat and no-combat branches while mouse is disabled', function()
    local world = setup()
    equal(world.main.icon.texture, 101)

    world.combat = true
    world:tick(0.1)
    equal(world.main.icon.texture, 102)

    world.combat = false
    world:tick(0.1)
    equal(world.main.icon.texture, 101)
end)

test('macro texture refresh preserves the active range tint', function()
    local world = setup(function(w)
        w.ranges[10] = false
    end)
    equal(world.main.icon.color[2], 0.25)
    world.combat = true

    world:tick(0.1)

    equal(world.main.icon.texture, 102)
    equal(world.main.icon.color[2], 0.25)
end)

test('combat event refreshes macro icon without waiting for a poll', function()
    local world = setup()
    world.combat = true

    world:fire('PLAYER_REGEN_DISABLED')

    equal(world.main.icon.texture, 102)
end)

test('paged macro action uses the displayed slot', function()
    local world = setup(function(w)
        w.actions[13] = { 'macro', 10, 'spell' }
        w.env.C_ActionBar.GetActionTexture = function(slot)
            if slot == 13 then return 303 end
            return 101
        end
    end)
    world.main.action = 13

    world:tick(0.1)

    equal(world.main.icon.texture, 303)
end)

test('only macro icons are refreshed', function()
    local world, addon = setup()
    addon.Config.Set('clickThroughBar2', true)

    equal(world.side.icon.texture, 201)
end)

test('unchanged macro texture is not rewritten each poll', function()
    local world = setup()
    local writes = world.main.icon.textureWrites

    world:tick(0.1)

    equal(world.main.icon.textureWrites, writes)
end)

test('restricted action texture leaves current icon intact', function()
    local world = setup(function(w)
        w.env.C_ActionBar.GetActionTexture = function() return w.secret end
    end)

    equal(world.main.icon.texture, 101)
end)

test('click-through works when range and cooldown features are disabled', function()
    local world, addon = setup(function(w)
        w.env.UtilsAssistForeverDB = {
            clickThroughBar1 = true,
            checkRangedAbilities = false,
            checkMeleeAbilities = false,
            greyOnCooldown = false,
        }
    end)

    equal(world.main.mouseEnabled, false)
    equal(addon.running, true)
end)

test('external mouse reset is corrected on rediscovery', function()
    local world = setup()
    world.main:EnableMouse(true)

    world:tick(0.5)

    equal(world.main.mouseEnabled, false)
end)

test('click-through setting changed during combat applies after combat', function()
    local world, addon = setup()
    world.combat = true
    addon.Config.Set('clickThroughBar1', false)
    equal(world.main.mouseEnabled, false)

    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')

    equal(world.main.mouseEnabled, true)
end)

test('enabling click-through during combat waits until combat ends', function()
    local world, addon = setup(function(w)
        w.env.UtilsAssistForeverDB = {}
    end)
    world.combat = true
    addon.Config.Set('clickThroughBar1', true)
    equal(world.main.mouseEnabled, true)

    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')

    equal(world.main.mouseEnabled, false)
end)

test('newly discovered button inherits its bar setting', function()
    local world = setup()
    world.late = world:button('ActionButton2', 2)
    world.actions[2] = { 'spell', 20 }

    world:tick(0.5)

    equal(world.late.mouseEnabled, false)
end)

test('uaf clicky and noclicky commands change one bar', function()
    local world = setup()

    world.env.SlashCmdList.UTILSASSISTFOREVER('noclicky 2')
    equal(world.side.mouseEnabled, false)
    world.env.SlashCmdList.UTILSASSISTFOREVER('clicky 2')
    equal(world.side.mouseEnabled, true)
end)

test('legacy bnc alias can change every bar', function()
    local world = setup()

    world.env.SlashCmdList.BNC('nc *')

    equal(world.main.mouseEnabled, false)
    equal(world.side.mouseEnabled, false)
    equal(world.env.UtilsAssistForeverDB.clickThroughBar8, true)
end)

test('legacy options command opens the integrated settings page', function()
    local world = setup()

    world.env.SlashCmdList.BNC('o')

    equal(world.openCategory, 123)
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
