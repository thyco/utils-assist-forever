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
    world.actions[1] = { 'spell', 10 }
    world.ranges[10] = true
    world.cooldowns = {}
    world.usable = {}
    world.env.C_ActionBar = {
        GetActionCooldown = function(slot) return world.cooldowns[slot] end,
        IsUsableAction = function(slot)
            local state = world.usable[slot]
            if state then return state[1], state[2] end
            return true, false
        end,
    }
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

local function native(button)
    equal(button.icon.desaturation, 0, 'native saturation')
    equal(button.icon.color[1], 1, 'native red')
    equal(button.icon.color[2], 1, 'native green')
end

local function grey(button)
    equal(button.icon.desaturation, 1, 'grey saturation')
    equal(button.icon.color[1], 1, 'grey keeps native red')
    equal(button.icon.color[2], 1, 'grey keeps native green')
end

test('cooldown greys action with no range tint', function()
    local world = setup(function(w)
        w.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
        w.env.GetTime = function() return 12 end
    end)

    grey(world.main)
end)

test('global cooldown leaves icon native', function()
    local world = setup(function(w)
        w.cooldowns[1] = { startTime = 10, duration = 1.5, isEnabled = true, isOnGCD = true }
        w.env.GetTime = function() return 10.5 end
    end)

    native(world.main)
end)

test('duration object greys when standard cooldown info is incomplete', function()
    local world = setup(function(w)
        w.cooldowns[1] = { isOnGCD = false, isEnabled = true }
        w.env.C_ActionBar.GetActionCooldownDuration = function()
            return {
                HasSecretValues = function() return false end,
                GetRemainingDuration = function() return 5 end,
            }
        end
    end)

    grey(world.main)
end)

test('explicitly inactive cooldown skips duration-object work', function()
    local durationReads = 0
    local world = setup(function(w)
        w.cooldowns[1] = { startTime = 0, duration = 0, isEnabled = true, isActive = false }
        w.env.C_ActionBar.GetActionCooldownDuration = function()
            durationReads = durationReads + 1
            return nil
        end
    end)

    native(world.main)
    equal(durationReads, 0)
end)

test('secret duration curve result can grey without inspecting the duration', function()
    local world = setup(function(w)
        w.cooldowns[1] = { isOnGCD = false, isEnabled = true }
        w.env.Enum.LuaCurveType = { Step = 'step' }
        w.env.C_CurveUtil = { CreateCurve = function()
            return { SetType = function() end, AddPoint = function() end }
        end }
        w.env.C_ActionBar.GetActionCooldownDuration = function()
            return {
                HasSecretValues = function() return true end,
                EvaluateRemainingDuration = function() return 1 end,
            }
        end
    end)

    grey(world.main)
end)

test('secret cooldown stays grey through its final second without a GCD flag', function()
    local remaining = 1
    local world = setup(function(w)
        w.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true }
        w.env.Enum.LuaCurveType = { Step = 'step' }
        w.env.C_CurveUtil = { CreateCurve = function()
            return {
                SetType = function() end,
                AddPoint = function(self, point, result)
                    if result == 1 then
                        self.threshold = point
                    end
                end,
            }
        end }
        w.env.C_ActionBar.GetActionCooldownDuration = function(slot, ignoreGCD)
            equal(slot, 1)
            equal(ignoreGCD, true)

            return {
                HasSecretValues = function() return true end,
                EvaluateRemainingDuration = function(_, step)
                    return remaining >= step.threshold and 1 or 0
                end,
            }
        end
    end)
    grey(world.main)

    remaining = 0
    world:fire('SPELL_UPDATE_COOLDOWN')
    world:tick(0.1)

    native(world.main)
end)

test('opaque curve result is reapplied without comparing it', function()
    local world = setup(function(w)
        w.cooldowns[1] = { isOnGCD = false, isEnabled = true }
        w.env.Enum.LuaCurveType = { Step = 'step' }
        w.env.C_CurveUtil = { CreateCurve = function()
            return { SetType = function() end, AddPoint = function() end }
        end }
        w.env.C_ActionBar.GetActionCooldownDuration = function()
            return {
                HasSecretValues = function() return true end,
                EvaluateRemainingDuration = function() return w.secret end,
            }
        end
    end)
    local writes = world.main.icon.writes

    world:fire('SPELL_UPDATE_COOLDOWN')
    world:tick(0.1)

    equal(world.main.icon.writes > writes, true)
end)

test('opaque cooldown is checked before comparing it with a readable update', function()
    local world, addon = setup(function(w)
        w.cooldowns[1] = { isOnGCD = false, isEnabled = true }
        w.env.Enum.LuaCurveType = { Step = 'step' }
        w.env.C_CurveUtil = { CreateCurve = function()
            return { SetType = function() end, AddPoint = function() end }
        end }
        w.env.C_ActionBar.GetActionCooldownDuration = function()
            return {
                HasSecretValues = function() return true end,
                EvaluateRemainingDuration = function() return w.secret end,
            }
        end
    end)
    local readable = addon.Client.Readable
    local checkedStoredValue = false
    addon.Client.Readable = function(value)
        if rawequal(value, world.secret) then
            checkedStoredValue = true
        end

        return readable(value)
    end

    world.usable[1] = { false, false }
    world:fire('ACTIONBAR_UPDATE_USABLE')
    world:tick(0.1)

    equal(checkedStoredValue, true, 'stored opaque amount must be guarded')
    grey(world.main)
end)

test('restricted cooldown without a safe duration leaves native appearance', function()
    local world = setup(function(w)
        w.env.C_ActionBar.GetActionCooldown = function() return w.secret end
        w.env.C_ActionBar.GetActionCooldownDuration = function() return w.secret end
    end)

    native(world.main)
end)

test('finished cooldown restores native icon', function()
    local world = setup(function(w)
        w.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
        w.env.GetTime = function() return 12 end
    end)
    grey(world.main)

    world.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
    world.env.GetTime = function() return 19 end
    world:tick(0.3)

    native(world.main)
end)

test('cooldown event refreshes on the next short poll', function()
    local world = setup(function(w)
        w.env.GetTime = function() return 12 end
    end)
    native(world.main)

    world.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
    world:fire('SPELL_UPDATE_COOLDOWN')
    native(world.main)

    world:tick(0.1)

    grey(world.main)
end)

test('multiple cooldown events share one button scan', function()
    local reads = 0
    local world = setup(function(w)
        w.env.GetTime = function() return 12 end
        w.env.C_ActionBar.IsUsableAction = function()
            reads = reads + 1
            return true, false
        end
    end)
    local baseline = reads

    world.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
    world:fire('SPELL_UPDATE_COOLDOWN')
    world:fire('ACTIONBAR_UPDATE_COOLDOWN')
    world:fire('ACTIONBAR_UPDATE_USABLE')
    equal(reads, baseline)

    world:tick(0.1)

    equal(reads, baseline + 1)
    grey(world.main)
end)

test('mouseover event bursts queue one cooldown scan', function()
    local reads = 0
    local world = setup(function(w)
        w.env.C_ActionBar.IsUsableAction = function()
            reads = reads + 1
            return true, false
        end
    end)
    local baseline = reads

    world:fire('UPDATE_MOUSEOVER_UNIT')
    world:fire('UPDATE_MOUSEOVER_UNIT')
    world:fire('UPDATE_MOUSEOVER_UNIT')
    equal(reads, baseline)

    world:tick(0.1)

    equal(reads, baseline + 1)
end)

test('target change queues a fresh usability check', function()
    local world = setup()
    native(world.main)

    world.usable[1] = { false, false }
    world:fire('PLAYER_TARGET_CHANGED')
    native(world.main)

    world:tick(0.1)

    grey(world.main)
end)

test('quiet cooldown changes are found by the fallback poll', function()
    local world = setup(function(w)
        w.env.GetTime = function() return 12 end
    end)
    world.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }

    world:tick(0.1)
    native(world.main)
    world:tick(0.1)
    native(world.main)
    world:tick(0.1)

    grey(world.main)
end)

test('native icon changes during grey are restored on cooldown completion', function()
    local world = setup(function(w)
        w.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
        w.env.GetTime = function() return 12 end
    end)
    world.main.icon:SetVertexColor(0.3, 0.4, 0.5, 0.6)
    world.main.icon:SetDesaturation(0.25)

    world.env.GetTime = function() return 19 end
    world:fire('SPELL_UPDATE_COOLDOWN')
    world:tick(0.1)

    equal(world.main.icon.desaturation, 0.25)
    equal(world.main.icon.color[1], 0.3)
    equal(world.main.icon.color[4], 0.6)
end)

test('unusable action greys by default', function()
    local world = setup(function(w)
        w.usable[1] = { false, false }
    end)

    grey(world.main)
end)

test('resource shortage remains native by default', function()
    local world = setup(function(w)
        w.usable[1] = { false, true }
    end)

    native(world.main)
end)

test('resource setting greys resource shortage', function()
    local world, addon = setup(function(w)
        w.usable[1] = { false, true }
    end)
    addon.Config.Set('greyWithoutResources', true)

    grey(world.main)
end)

test('range red takes priority and clears back to grey', function()
    local world = setup(function(w)
        w.ranges[10] = false
        w.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
        w.env.GetTime = function() return 12 end
    end)
    equal(world.main.icon.color[2], 0.25)

    world.ranges[10] = true
    world:tick(0.1)

    grey(world.main)
end)

test('disabling cooldown feature restores native while range continues', function()
    local world, addon = setup(function(w)
        w.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
        w.env.GetTime = function() return 12 end
    end)
    addon.Config.Set('greyOnCooldown', false)

    native(world.main)
    equal(addon.running, true)
end)

test('cooldown works when both range settings are disabled', function()
    local world, addon = setup(function(w)
        w.cooldowns[1] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
        w.env.GetTime = function() return 12 end
    end)
    addon.Config.Set('checkRangedAbilities', false)
    addon.Config.Set('checkMeleeAbilities', false)

    grey(world.main)
    equal(addon.running, true)
end)

test('pet action greys on a real pet cooldown', function()
    local world = setup(function(w)
        w.pet = w:button('PetActionButton1')
        w.pet.index = 1
        w.env.GetPetActionInfo = function() return 'Bite' end
        w.env.GetPetActionSlotUsable = function() return true end
        w.env.GetPetActionCooldown = function() return 10, 8, 1 end
        w.env.GetTime = function() return 12 end
    end)

    grey(world.pet)
end)

test('pet setting restores a grey pet icon', function()
    local world, addon = setup(function(w)
        w.pet = w:button('PetActionButton1')
        w.pet.index = 1
        w.env.GetPetActionInfo = function() return 'Bite' end
        w.env.GetPetActionCooldown = function() return 10, 8, 1 end
        w.env.GetTime = function() return 12 end
    end)
    addon.Config.Set('greyPetActions', false)

    native(world.pet)
end)

test('pet global cooldown remains native', function()
    local world = setup(function(w)
        w.pet = w:button('PetActionButton1')
        w.pet.index = 1
        w.env.GetPetActionInfo = function() return 'Bite' end
        w.env.GetPetActionCooldown = function() return 10, 1.5, 1 end
        w.env.GetTime = function() return 10.5 end
    end)

    native(world.pet)
end)

test('LibActionButton spell button greys from its active spell state', function()
    local world = setup(function(w)
        w.custom = w:button('CustomSpellButton')
        w.custom._state_type = 'spell'
        w.custom._state_action = 10
        w.env.LibStub = { GetLibrary = function()
            return { buttonRegistry = { [w.custom] = true } }
        end }
        w.env.C_Spell.GetSpellCooldown = function(id)
            if id == 10 then
                return { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
            end
        end
        w.env.GetTime = function() return 12 end
    end)

    grey(world.custom)
end)

test('Dominos registered action button greys from its live slot', function()
    local world = setup(function(w)
        w.custom = w:button('DominosActionButton1', 2)
        w.actions[2] = { 'item', 100 }
        w.env.Dominos = { ActionButtons = { buttons = { [w.custom] = true } } }
        w.cooldowns[2] = { startTime = 10, duration = 8, isEnabled = true, isOnGCD = false }
        w.env.GetTime = function() return 12 end
    end)

    grey(world.custom)
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
