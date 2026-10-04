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
    world.side = world:button('MultiBarLeftButton7', 67)
    world.actions = { [1] = { 'spell', 10 }, [67] = { 'spell', 10 } }
    if configure then configure(world) end

    local manifest = io.open('UtilsAssistForever/UtilsAssistForever.toc')
    assert(manifest, 'addon manifest is not implemented')
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

local function tinted(button)
    equal(button.icon.desaturation, 1, 'icon must be desaturated')
    equal(button.icon.color[1], 1, 'red component')
    equal(button.icon.color[2], 0.25, 'green component')
    equal(button.icon.color[3], 0.25, 'blue component')
end

local function native(button)
    equal(button.icon.desaturation, 0, 'icon saturation restored')
    equal(button.icon.color[1], 1)
    equal(button.icon.color[2], 1)
    equal(button.icon.color[3], 1)
end

test('login colors a shot on both main and side bars', function()
    local world = setup()

    tinted(world.main)
    tinted(world.side)
    equal(world.queries[10], 1, 'duplicate abilities share queries')
end)

test('all eight default bar prefixes participate', function()
    local prefixes = { 'ActionButton', 'MultiBarBottomLeftButton', 'MultiBarBottomRightButton',
        'MultiBarRightButton', 'MultiBarLeftButton', 'MultiBar5Button', 'MultiBar6Button', 'MultiBar7Button' }
    local world = setup(function(w)
        for index, prefix in ipairs(prefixes) do
            w:button(prefix .. '12', index + 100)
            w.actions[index + 100] = { 'spell', 10 }
        end
    end)

    for _, prefix in ipairs(prefixes) do tinted(world.env[prefix .. '12']) end
end)

test('custom bars are left untouched', function()
    local world = setup(function(w)
        w.custom = w:button('BT4Button1', 1)
    end)

    native(world.custom)
end)

test('in-range target restores all tracked icons', function()
    local world = setup()
    world.ranges[10] = true

    world:tick(0.1)

    native(world.main)
    native(world.side)
end)

test('new target clears prior evidence immediately', function()
    local world = setup()
    world.exists = false

    world:fire('PLAYER_TARGET_CHANGED')

    native(world.main)
    native(world.side)
end)

test('paged main slot checks the current melee action', function()
    local world = setup()
    world.actions[13] = { 'spell', 40 }
    world.main.action = 13

    world:fire('ACTIONBAR_PAGE_CHANGED')
    world:tick(0.1)

    tinted(world.main)
    tinted(world.side)
end)

test('replacing spell in the same slot removes tint', function()
    local world = setup()
    world.actions[67] = { 'item', 10 }

    world:fire('ACTIONBAR_SLOT_CHANGED', 67)
    world:tick(0.1)

    native(world.side)
end)

test('macro follows the client-reported displayed spell', function()
    local world = setup(function(w)
        w.actions[67] = { 'macro', 10, 'spell' }
    end)
    tinted(world.side)
    world.actions[67] = { 'macro', 20, 'spell' }

    world:tick(0.1)

    native(world.side)
end)

test('unknown macro payload is not confused with a spell ID', function()
    local world = setup(function(w)
        w.actions[67] = { 'macro', 10 }
    end)

    native(world.side)
end)

test('restricted action identifiers clear previous tint', function()
    local world = setup()
    world.actions[67] = { 'spell', world.secret }

    world:tick(0.1)

    native(world.side)
end)

test('hidden button releases its tint', function()
    local world = setup()
    world.side:Hide()

    world:tick(0.1)

    native(world.side)
end)

test('native color updates retain red but restore the latest mana color', function()
    local world, addon = setup()
    world.side.icon:SetVertexColor(0.5, 0.5, 1, 0.8)
    tinted(world.side)

    addon.Config.Set('checkRangedAbilities', false)

    equal(world.side.icon.color[1], 0.5)
    equal(world.side.icon.color[2], 0.5)
    equal(world.side.icon.color[3], 1)
    equal(world.side.icon.color[4], 0.8)
    equal(world.side.icon.desaturation, 0)
end)

test('native desaturation refresh does not erase an active tint', function()
    local world = setup()

    world.side.icon:SetDesaturated(false)

    tinted(world.side)
end)

test('partial native desaturation is restored on disable', function()
    local world, addon = setup()
    world.side.icon:SetDesaturation(0.4)

    addon.Config.Set('checkRangedAbilities', false)

    equal(world.side.icon.desaturation, 0.4)
end)

test('unchanged range polls do not rewrite icon textures', function()
    local world = setup()
    local writes = world.side.icon.writes
    local bookReads = world.bookReads

    for _ = 1, 20 do world:tick(0.1) end

    equal(world.side.icon.writes, writes)
    equal(world.bookReads, bookReads, 'spellbook is not rescanned by polling')
end)

test('updates are throttled rather than running on every frame', function()
    local world = setup()
    local queries = world.queries[10]

    world:tick(0.02)
    world:tick(0.02)
    world:tick(0.02)

    equal(world.queries[10], queries)
    world:tick(0.05)
    equal(world.queries[10], queries + 1)
end)

test('checkbox defaults on and switches coloring immediately', function()
    local world, addon = setup()
    local check = addon.SettingsPanel.controls.checkRangedAbilities
    equal(check:GetChecked(), true)
    check:SetChecked(false)

    check.scripts.OnClick(check)

    native(world.main)
    native(world.side)
    equal(world.env.UtilsAssistForeverDB.checkRangedAbilities, false)
    check:SetChecked(true)
    check.scripts.OnClick(check)
    tinted(world.side)
end)

test('disabled checkbox stops range polling', function()
    local world, addon = setup()
    addon.Config.Set('checkRangedAbilities', false)
    local queries = world.queries[10]

    for _ = 1, 100 do world:tick(0.1) end

    equal(world.queries[10], queries)
    native(world.side)
end)

test('saved disabled preference survives initialization and reenable discovers bars', function()
    local world, addon = setup(function(w)
        w.env.UtilsAssistForeverDB = { checkRangedAbilities = false }
    end)
    native(world.main)
    equal(next(world.queries), nil)
    equal(addon.SettingsPanel.controls.checkRangedAbilities:GetChecked(), false)

    addon.Config.Set('checkRangedAbilities', true)

    tinted(world.side)
end)

test('invalid saved setting gets the enabled default', function()
    local world, addon = setup(function(w)
        w.env.UtilsAssistForeverDB = { checkRangedAbilities = 'false' }
    end)

    equal(addon.Config.Get('checkRangedAbilities'), true)
    tinted(world.side)
end)

test('range checkbox remains inside its own settings section', function()
    local _, addon = setup()
    local panel = addon.SettingsPanel
    local count = 0
    for _ in pairs(panel.controls) do count = count + 1 end

    equal(count, 14)
    equal(#panel.sections, 3)
    equal(panel.controls.checkRangedAbilities.Text.text, 'Check ranged abilities')
    equal(panel.controls.checkRangedAbilities.parent, panel.sections[1])
    equal(panel.sections[1].children[1].text, 'Range checks')
    equal(panel.controls.greyOnCooldown.parent, panel.sections[2])
    equal(panel.sections[2].children[1].text, 'Cooldown greying')
    equal(panel.controls.clickThroughBar1.parent, panel.sections[3])
    equal(panel.sections[3].children[1].text, 'Action bar click-through')
end)

test('settings groups live inside a bounded scroll viewport', function()
    local _, addon = setup()
    local panel = addon.SettingsPanel
    local scroll = panel.scroll

    equal(scroll.kind, 'ScrollFrame')
    equal(scroll.template, 'ScrollFrameTemplate')
    equal(scroll.parent, panel.canvas)
    equal(scroll.scrollChild, panel.content)
    equal(panel.content.parent, scroll)
    equal(panel.content.height, 704)
    equal(panel.sections[1].parent, panel.content)
    equal(panel.sections[3].parent, panel.content)
    equal(scroll.points[1][1], 'TOPLEFT')
    equal(scroll.points[2][1], 'BOTTOMRIGHT')

    scroll.scripts.OnSizeChanged(scroll, 440, 400)

    equal(panel.content.width, 440)

    scroll:SetWidth(380)
    panel.canvas:Show()

    equal(panel.content.width, 380)
end)

test('slash config command opens registered native category', function()
    local world = setup()

    world.env.SlashCmdList.UTILSASSISTFOREVER(' config ')

    equal(world.openCategory, 123)
end)

test('all classes run range checks', function()
    for _, class in ipairs({ 'WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID' }) do
        local world, addon = setup(function(w) w.class = class end)

        world:tick(0.1)

        tinted(world.main)
        assert(addon.started)
    end
end)

test('late-created button waits for combat to end before preparing hooks', function()
    local world = setup()
    world.combat = true
    local late = world:button('MultiBar7Button8', 88)
    world.actions[88] = { 'spell', 10 }
    world:tick(0.5)
    native(late)
    world.combat = false

    world:fire('PLAYER_REGEN_ENABLED')

    tinted(late)
end)

test('prepared buttons continue updating in combat', function()
    local world = setup()
    world.combat = true
    world.ranges[10] = true
    world:tick(0.1)
    native(world.side)
    world.ranges[10] = false

    world:tick(0.1)

    tinted(world.side)
end)

test('newly learned spell is discovered', function()
    local world = setup(function(w) w.learned = { 20, 30 } end)
    native(world.side)
    world.learned = { 10, 20, 30 }

    world:fire('SPELLS_CHANGED')
    world:tick(0.1)

    tinted(world.side)
end)

test('attackable mouseover colors without a selected target', function()
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true, [40] = false } }
    end)

    tinted(world.side)
end)

test('selected target takes precedence without mixing mouseover evidence', function()
    local world = setup()
    world.ranges[10] = true
    world.mouseover = { exists = true, attackable = true, dead = false,
        ranges = { [10] = false, [20] = true, [40] = false } }

    world:fire('UPDATE_MOUSEOVER_UNIT')

    native(world.side)
end)

test('mouseover departure clears tint on the next poll when no target is selected', function()
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true, [40] = false } }
    end)
    tinted(world.side)
    world.mouseover.exists = false

    world:tick(0.1)

    native(world.side)
end)

test('friendly mouseover cannot color when no attackable target exists', function()
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = false, dead = false,
            ranges = { [10] = false, [20] = true } }
    end)

    native(world.side)
    equal(next(world.queries), nil)
end)

test('dead mouseover cannot color when no attackable target exists', function()
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = true,
            ranges = { [10] = false, [20] = true } }
    end)

    native(world.side)
    equal(next(world.queries), nil)
end)

test('restricted mouseover attackability safely falls back to attackable target', function()
    local world = setup(function(w)
        w.mouseover = { exists = true, attackable = w.secret, dead = false, ranges = {} }
    end)

    tinted(world.side)
end)

test('spellbook and spell-ID fallback both check the mouseover unit', function()
    local calls = 0
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true, [40] = false } }
        w.env.C_SpellBook.IsSpellBookItemInRange = function(slot, bank, unit)
            equal(unit, 'mouseover')
            calls = calls + 1
            return nil
        end
    end)

    tinted(world.side)
    assert(calls > 0)
    world.env.SlashCmdList.UTILSASSISTFOREVER('')
    assert(table.concat(world.messages, '\n'):find('Checking: mouseover', 1, true))
end)

test('friendly selected target blocks mouseover fallback', function()
    local world = setup(function(w)
        w.attackable = false
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true } }
    end)

    native(world.side)
    equal(next(world.queries), nil)
end)

test('dead selected target blocks mouseover fallback', function()
    local world = setup(function(w)
        w.dead = true
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true } }
    end)

    native(world.side)
    equal(next(world.queries), nil)
end)

test('selecting then clearing a target switches evidence immediately', function()
    local world = setup(function(w)
        w.exists = false
        w.ranges[10] = true
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true, [40] = false } }
    end)
    tinted(world.side)
    world.exists = true

    world:fire('PLAYER_TARGET_CHANGED')

    native(world.side)
    world.exists = false
    world:fire('PLAYER_TARGET_CHANGED')
    tinted(world.side)
end)

test('melee checkbox is independent of ranged checkbox', function()
    local world, addon = setup(function(w) w.actions[67] = { 'spell', 40 } end)
    tinted(world.main)
    tinted(world.side)

    addon.Config.Set('checkRangedAbilities', false)

    native(world.main)
    tinted(world.side)

    addon.Config.Set('checkRangedAbilities', true)
    local check = addon.SettingsPanel.controls.checkMeleeAbilities
    equal(check.Text.text, 'Check melee abilities')
    equal(check.parent, addon.SettingsPanel.sections[1])
    check:SetChecked(false)
    check.scripts.OnClick(check)

    tinted(world.main)
    native(world.side)
    equal(world.env.UtilsAssistForeverDB.checkMeleeAbilities, false)
end)

test('all utility features disabled remove the polling handler', function()
    local world, addon = setup()

    addon.Config.Set('checkRangedAbilities', false)
    addon.Config.Set('checkMeleeAbilities', false)
    addon.Config.Set('greyOnCooldown', false)

    for _, frame in ipairs(world.frames) do equal(frame.scripts.OnUpdate, nil) end
    native(world.main)
end)

test('unknown result clears active tint', function()
    local world = setup()
    world.ranges[10] = nil

    world:tick(0.1)

    native(world.main)
end)

test('restricted result clears active tint', function()
    local world = setup()
    world.ranges[10] = world.secret

    world:tick(0.1)

    native(world.main)
end)

test('far target tints without proximity inference', function()
    local world = setup(function(w)
        w.ranges = { [10] = false, [20] = false, [30] = false, [40] = false }
        w.env.CheckInteractDistance = function() error('must never infer proximity') end
    end)

    tinted(world.main)
    equal(world.queries[20], nil)
    equal(world.queries[40], nil)
end)

test('manifest stores settings per character only', function()
    local file = assert(io.open('UtilsAssistForever/UtilsAssistForever.toc'))
    local manifest = file:read('*a')
    file:close()

    assert(manifest:find('## SavedVariablesPerCharacter: UtilsAssistForeverDB', 1, true))
    assert(manifest:find('## Title: Utils Assist Forever', 1, true))
    assert(not manifest:find('## SavedVariables:', 1, true))
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
