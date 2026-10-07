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
    world.cvars = { groundEffectDensity = '64', graphicsGroundClutter = '5' }
    world.defaults = { groundEffectDensity = '32', graphicsGroundClutter = '4' }
    world.cvarWrites = {}
    world.locked = {}
    world.readOnly = {}
    world.rejected = {}
    world.timers = {}
    world.env.C_CVar = {
        GetCVarInfo = function(name)
            if world.cvars[name] == nil then
                return nil
            end

            return world.cvars[name], world.defaults[name], false, false,
                world.locked[name] or false, false, world.readOnly[name] or false
        end,
        SetCVar = function(name, value)
            if world.rejected[name] then
                return false
            end

            world.cvars[name] = tostring(value)
            world.cvarWrites[#world.cvarWrites + 1] = { name, tostring(value) }
            return true
        end,
    }
    world.env.C_Timer = { After = function(delay, callback)
        world.timers[#world.timers + 1] = { delay, callback }
    end }

    function world:runTimers()
        local pending = self.timers
        self.timers = {}

        for _, timer in ipairs(pending) do
            timer[2]()
        end
    end

    if configure then configure(world) end

    local manifest = assert(io.open('UtilsAssistForever/UtilsAssistForever.toc'))
    for line in manifest:lines() do
        if line:match('%.lua$') and not line:match('^Libs/') then
            local chunk = assert(loadfile('UtilsAssistForever/' .. line, 't', world.env))
            chunk('UtilsAssistForever', world.addon)
        end
    end
    manifest:close()
    world:fire('PLAYER_LOGIN')

    return world, world.addon
end

test('graphics box shows the live density and client default without changing either', function()
    local world, addon = setup()
    local control = addon.SettingsPanel.graphicsControls.groundEffectDensity

    equal(control.slider:IsEnabled(), true)
    equal(control.reset:IsEnabled(), true)
    equal(control.slider:GetValue(), 64)
    equal(control.status.text, 'Current: 64  |  Default: 32')
    equal(#world.cvarWrites, 0)
    equal(world.env.UtilsAssistForeverGraphicsDB.groundEffectDensity, nil)
end)

test('slider writes density and saves an accepted account-wide override', function()
    local world, addon = setup()
    local control = addon.SettingsPanel.graphicsControls.groundEffectDensity

    control.slider:SetValue(88)

    equal(world.cvars.groundEffectDensity, '88')
    equal(world.env.UtilsAssistForeverGraphicsDB.groundEffectDensity, 88)
    equal(control.status.text, 'Current: 88  |  Default: 32')
end)

test('reset restores the client-reported default for only this graphic setting', function()
    local world, addon = setup()
    local control = addon.SettingsPanel.graphicsControls.groundEffectDensity
    control.slider:SetValue(88)

    control.reset.scripts.OnClick(control.reset)

    equal(world.cvars.groundEffectDensity, '32')
    equal(world.cvars.graphicsGroundClutter, '5')
    equal(world.env.UtilsAssistForeverGraphicsDB.groundEffectDensity, nil)
    equal(control.slider:GetValue(), 32)
end)

test('saved override applies across characters and reset removes it', function()
    local account = {}
    local _, addon = setup(function(world)
        world.env.UtilsAssistForeverGraphicsDB = account
    end)
    addon.Graphics.Set('groundEffectDensity', 96)
    local overridden = setup(function(world)
        world.env.UtilsAssistForeverGraphicsDB = account
    end)

    addon.Graphics.Reset('groundEffectDensity')
    local reset = setup(function(world)
        world.env.UtilsAssistForeverGraphicsDB = account
        world.cvars.groundEffectDensity = '32'
    end)

    equal(overridden.cvars.groundEffectDensity, '96')
    equal(reset.cvars.groundEffectDensity, '32')
    equal(#reset.cvarWrites, 0)
    equal(account.groundEffectDensity, nil)
end)

test('unavailable or locked CVar disables its controls and prevents writes', function()
    local missing, missingAddon = setup(function(world)
        world.cvars.groundEffectDensity = nil
    end)
    local locked, lockedAddon = setup(function(world)
        world.locked.groundEffectDensity = true
    end)

    equal(missingAddon.SettingsPanel.graphicsControls.groundEffectDensity.slider:IsEnabled(), false)
    equal(missingAddon.SettingsPanel.graphicsControls.groundEffectDensity.reset:IsEnabled(), false)
    equal(lockedAddon.SettingsPanel.graphicsControls.groundEffectDensity.slider:IsEnabled(), false)
    equal(lockedAddon.SettingsPanel.graphicsControls.groundEffectDensity.reset:IsEnabled(), false)
    equal(#missing.cvarWrites, 0)
    equal(#locked.cvarWrites, 0)
end)

test('missing write API disables the graphic control', function()
    local _, addon = setup(function(world)
        world.env.C_CVar.SetCVar = nil
        world.env.SetCVar = false
    end)
    local control = addon.SettingsPanel.graphicsControls.groundEffectDensity

    equal(control.slider:IsEnabled(), false)
    equal(control.reset:IsEnabled(), false)
end)

test('combat-disabled graphics control uses the zero-argument combat API', function()
    local world, addon = setup(function(w)
        w.combat = true
        w.env.InCombatLockdown = function(...)
            assert(select('#', ...) == 0)
            return w.combat
        end
    end)
    local control = addon.SettingsPanel.graphicsControls.groundEffectDensity

    equal(control.slider:IsEnabled(), false)
    equal(control.reset:IsEnabled(), false)
    equal(#world.cvarWrites, 0)
end)

test('graphics control disables and reenables as combat changes', function()
    local world, addon = setup()
    local control = addon.SettingsPanel.graphicsControls.groundEffectDensity
    world.combat = true

    world:fire('PLAYER_REGEN_DISABLED')

    equal(control.slider:IsEnabled(), false)
    equal(control.reset:IsEnabled(), false)

    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')

    equal(control.slider:IsEnabled(), true)
    equal(control.reset:IsEnabled(), true)
end)

test('rejected CVar writes leave saved settings and displayed value unchanged', function()
    local world, addon = setup(function(w)
        w.rejected.groundEffectDensity = true
    end)
    local control = addon.SettingsPanel.graphicsControls.groundEffectDensity

    control.slider:SetValue(120)

    equal(world.cvars.groundEffectDensity, '64')
    equal(world.env.UtilsAssistForeverGraphicsDB.groundEffectDensity, nil)
    equal(control.slider:GetValue(), 64)
end)

test('ground clutter preset changes reapply only a manual density override', function()
    local world, addon = setup()
    addon.Graphics.Set('groundEffectDensity', 88)
    world.cvars.groundEffectDensity = '40'

    world:fire('CVAR_UPDATE', 'graphicsGroundClutter')
    world:runTimers()

    equal(world.cvars.groundEffectDensity, '88')
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
