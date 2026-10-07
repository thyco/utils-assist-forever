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
    local w = H.new()
    w.class = 'DRUID'
    w.spells[6603] = { name = 'Attack', minRange = 0, maxRange = 0 }
    w.spells[2973] = { name = 'Raptor Strike', minRange = 0, maxRange = 0 }
    w.spells[78] = { name = 'Heroic Strike', minRange = 0, maxRange = 0 }
    w.spells[845] = { name = 'Cleave', minRange = 0, maxRange = 0 }
    w.spells[6807] = { name = 'Maul', minRange = 0, maxRange = 0 }
    w.learned = { 10, 20, 40, 6603, 2973, 78, 845, 6807 }
    w.helpful = { [6603] = true, [2973] = true }
    w.ranges[6603] = false
    w.ranges[2973] = true
    w.ranges[40] = true
    w.macros = { [1] = { 'Melee', '#showtooltip Melee strike\n/cast !Raptor Strike\n/cast Melee strike' } }
    w.macroReads = 0
    w.actionNames = { [1] = 'Melee' }
    w.actions[1] = { 'macro', 40, 'spell' }
    w.main = w:button('ActionButton1', 1)
    w.env.Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120 } }
    w.env.GetNumMacros = function() return w.accountCount or 1, w.characterCount or 0 end
    w.env.GetMacroInfo = function(index)
        w.macroReads = w.macroReads + 1
        local macro = w.macros[index]
        if macro then return macro[1], 1, macro[2] end
    end
    w.env.C_ActionBar = { GetActionText = function(slot) return w.actionNames[slot] end }
    w.env.C_Spell.IsAutoAttackSpell = function(id) return id == 6603 end
    w.env.C_Spell.GetSpellSubtext = function(id) return id == 14260 and 'Rank 2' or '' end
    w.env.SecureCmdOptionParse = function(args)
        if args == '[mod:shift] Raptor Strike; Melee strike' then
            return w.shift and 'Raptor Strike' or 'Melee strike'
        elseif args == '[@mouseover] Raptor Strike' then
            return 'Raptor Strike', 'mouseover'
        end
        error('unexpected options: ' .. args)
    end
    if configure then configure(w) end

    local manifest = assert(io.open('UtilsAssistForever/UtilsAssistForever.toc'))
    for line in manifest:lines() do
        if line:match('%.lua$') then
            assert(loadfile('UtilsAssistForever/' .. line, 't', w.env))('UtilsAssistForever', w.addon)
        end
    end
    manifest:close()
    w:fire('PLAYER_LOGIN')

    return w, w.addon
end

local function tinted(w)
    equal(w.main.icon.desaturation, 1)
    equal(w.main.icon.color[2], 0.25)
end

local function native(w)
    equal(w.main.icon.desaturation, 0)
    equal(w.main.icon.color[2], 1)
end

test('macro body finds queued attack behind another displayed melee spell', function()
    local w = setup()

    tinted(w)
    equal(w.queries[6603], 1)
    equal(w.queries[2973], nil)
end)

test('next-swing explanations are collected only for diagnostics', function()
    local w, addon = setup()

    equal(addon.RangeCheck.references, nil)
    w:tick(0.1)
    equal(addon.RangeCheck.references, nil)

    w.env.SlashCmdList.UTILSASSISTFOREVER('')

    assert(addon.RangeCheck.references[1]:find('macro body', 1, true))
end)

test('direct raptor strike uses auto attack even when harmfulness excludes it', function()
    local w = setup(function(w) w.actions[1] = { 'spell', 2973 } end)

    tinted(w)
end)

test('direct heroic strike uses auto attack', function()
    local w = setup(function(w) w.actions[1] = { 'spell', 78 } end)

    tinted(w)
end)

test('direct cleave uses auto attack', function()
    local w = setup(function(w) w.actions[1] = { 'spell', 845 } end)

    tinted(w)
end)

test('direct maul uses auto attack', function()
    local w = setup(function(w) w.actions[1] = { 'spell', 6807 } end)

    tinted(w)
end)

test('auto attack in range keeps macro native despite queued spell false', function()
    local w = setup(function(w)
        w.ranges[6603] = true
        w.ranges[2973] = false
    end)

    native(w)
end)

test('unknown auto attack clears tint without another spell inference', function()
    local w = setup()
    w.ranges[6603] = nil
    w.ranges[40] = false

    w:tick(0.1)

    native(w)
end)

test('restricted auto attack clears tint', function()
    local w = setup()
    w.ranges[6603] = w.secret

    w:tick(0.1)

    native(w)
end)

test('missing auto attack leaves queued attack native', function()
    local w = setup(function(w) w.learned = { 2973, 40 } end)

    native(w)
end)

test('auto attack spellbook result precedes ID API', function()
    local w = setup(function(w)
        w.ranges[6603] = true
        w.env.C_SpellBook.IsSpellBookItemInRange = function(slot, bank, unit)
            equal(slot, 4)
            equal(bank, 0)
            equal(unit, 'target')
            return false
        end
    end)

    tinted(w)
    equal(w.queries[6603], nil)
end)

test('multiple buttons share auto attack query', function()
    local w = setup(function(w)
        w:button('MultiBar7Button12', 96)
        w.actions[96] = { 'spell', 78 }
    end)

    tinted(w)
    equal(w.queries[6603], 1)
    equal(w.env.MultiBar7Button12.icon.desaturation, 1)
end)

test('melee checkbox disables the reference check', function()
    local w, addon = setup()

    addon.Config.Set('checkMeleeAbilities', false)

    native(w)
end)

test('ranged checkbox does not disable the reference check', function()
    local w, addon = setup()

    addon.Config.Set('checkRangedAbilities', false)

    tinted(w)
end)

test('localized learned rank and explicit rank suffix match', function()
    local w = setup(function(w)
        w.spells[2973].name = 'Attaque du raptor'
        w.spells[14260] = { name = 'Attaque du raptor', minRange = 0, maxRange = 0 }
        w.learned[5] = 14260
        w.macros[1][2] = '/cast !Attaque du raptor(Rank 2)\n/cast Melee strike'
    end)

    tinted(w)
end)

test('unlearned queued spell is not inferred from macro text', function()
    local w = setup(function(w) w.learned = { 40, 6603 } end)

    native(w)
end)

test('mention in tooltip or chat is not a cast', function()
    local w = setup(function(w) w.macros[1][2] = '#showtooltip Raptor Strike\n/say Raptor Strike\n/cast Melee strike' end)

    native(w)
end)

test('partial spell name is not a match', function()
    local w = setup(function(w) w.macros[1][2] = '/cast Raptor Strike Extra' end)

    native(w)
end)

test('use command and localized cast alias are recognized', function()
    local w = setup(function(w)
        w.env.SLASH_CAST3 = '/lancer'
        w.macros[1][2] = '/lancer !Raptor Strike\n/use Melee strike'
    end)

    tinted(w)
end)

test('unselected conditional branch does not override displayed spell', function()
    local w = setup(function(w) w.macros[1][2] = '/cast [mod:shift] Raptor Strike; Melee strike' end)
    native(w)
    w.shift = true

    w:tick(0.1)

    tinted(w)
    w.shift = false
    w:tick(0.1)
    native(w)
end)

test('explicit mouseover branch cannot override selected target', function()
    local w = setup(function(w) w.macros[1][2] = '/cast [@mouseover] Raptor Strike' end)

    native(w)
end)

test('explicit mouseover branch works with no target', function()
    local w = setup(function(w)
        w.macros[1][2] = '/cast [@mouseover] Raptor Strike'
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = false, ranges = { [6603] = false } }
    end)

    tinted(w)
end)

test('unknown conditional result is ignored safely', function()
    local w = setup(function(w)
        w.macros[1][2] = '/cast [mod:shift] Raptor Strike'
        w.env.SecureCmdOptionParse = function() return w.secret end
    end)

    native(w)
end)

test('sequence and stopmacro prevent body inference', function()
    local w = setup(function(w) w.macros[1][2] = '/stopmacro [combat]\n/cast Raptor Strike' end)
    native(w)
    w.macros[1][2] = '/cast Raptor Strike\n/castsequence Melee strike, Raptor Strike'

    w:fire('UPDATE_MACROS')
    w:tick(0.1)

    native(w)
end)

test('duplicate names across account and character are ambiguous', function()
    local w = setup(function(w)
        w.characterCount = 1
        w.macros[121] = { 'Melee', '/cast Melee strike' }
    end)

    native(w)
end)

test('character macro is resolved with account slot offset', function()
    local w = setup(function(w)
        w.accountCount = 0
        w.characterCount = 1
        w.macros[121] = w.macros[1]
        w.macros[1] = nil
    end)

    tinted(w)
end)

test('custom icon macro with no displayed spell can use body', function()
    local w = setup(function(w) w.actions[1] = { 'macro', 1 } end)

    tinted(w)
end)

test('restricted macro body is never parsed', function()
    local w = setup(function(w) w.macros[1][2] = w.secret end)

    native(w)
end)

test('macro text is not reread every poll', function()
    local w = setup()
    local reads = w.macroReads

    for _ = 1, 20 do w:tick(0.1) end

    equal(w.macroReads, reads)
end)

test('macro edit clears cached body detection', function()
    local w = setup()
    tinted(w)
    w.macros[1][2] = '/cast Melee strike'

    w:fire('UPDATE_MACROS')
    w:tick(0.1)

    native(w)
end)

test('paging to a different macro checks the live slot', function()
    local w = setup(function(w)
        w.accountCount = 2
        w.macros[2] = { 'Other', '/cast Melee strike' }
        w.actions[13] = { 'macro', 40, 'spell' }
        w.actionNames[13] = 'Other'
    end)
    tinted(w)
    w.main.action = 13

    w:fire('ACTIONBAR_PAGE_CHANGED')
    w:tick(0.1)

    native(w)
end)

test('diagnostics identify reference and body detection', function()
    local w = setup()

    w.env.SlashCmdList.UTILSASSISTFOREVER('')

    local output = table.concat(w.messages, '\n')
    assert(output:find('Auto Attack reference', 1, true))
    assert(output:find('macro body', 1, true))
end)

test('use command detects next-swing attack', function()
    local w = setup(function(w) w.macros[1][2] = '/use !Raptor Strike' end)

    tinted(w)
end)

test('restricted macro name invalidates ambiguous catalog safely', function()
    local w = setup(function(w)
        w.accountCount = 2
        w.macros[2] = { w.secret, '/cast Melee strike' }
    end)

    native(w)
end)

test('macro read error leaves displayed-spell behavior intact', function()
    local w = setup(function(w)
        w.env.GetMacroInfo = function() error('private error') end
    end)

    native(w)
end)

test('conditional parser error cannot infer melee', function()
    local w = setup(function(w)
        w.macros[1][2] = '/cast [mod:shift] Raptor Strike'
        w.env.SecureCmdOptionParse = function() error('private error') end
    end)

    native(w)
end)

test('restricted explicit unit cannot infer melee', function()
    local w = setup(function(w)
        w.macros[1][2] = '/cast [mod:shift] Raptor Strike'
        w.env.SecureCmdOptionParse = function() return 'Raptor Strike', w.secret end
    end)

    native(w)
end)

test('missing conditional parser still allows plain casts only', function()
    local w = setup(function(w)
        w.macros[1][2] = '/cast [mod:shift] Raptor Strike'
        w.env.SecureCmdOptionParse = nil
    end)
    native(w)
    w.macros[1][2] = '/cast Raptor Strike'

    w:fire('UPDATE_MACROS')
    w:tick(0.1)

    tinted(w)
end)

test('unreadable attack predicate leaves reference unavailable', function()
    local w = setup(function(w)
        w.env.C_Spell.IsAutoAttackSpell = function() return w.secret end
    end)

    native(w)
    equal(w.queries[6603], nil)
end)

test('friendly selected target blocks auto attack mouseover fallback', function()
    local w = setup(function(w)
        w.attackable = false
        w.mouseover = { exists = true, attackable = true, dead = false, ranges = { [6603] = false } }
    end)

    native(w)
    equal(w.queries[6603], nil)
end)

test('auto attack tint restores latest native shading in combat', function()
    local w = setup()
    w.combat = true
    w.main.icon:SetVertexColor(0.4, 0.5, 0.8, 0.6)
    w.main.icon:SetDesaturation(0.3)
    w.ranges[6603] = nil

    w:tick(0.1)

    equal(w.main.icon.color[1], 0.4)
    equal(w.main.icon.color[2], 0.5)
    equal(w.main.icon.color[3], 0.8)
    equal(w.main.icon.color[4], 0.6)
    equal(w.main.icon.desaturation, 0.3)
end)

test('displayed queued spell cannot bypass body target mismatch', function()
    local w = setup(function(w)
        w.actions[1] = { 'macro', 2973, 'spell' }
        w.macros[1][2] = '/cast [@mouseover] Raptor Strike'
        w.mouseover = { exists = true, attackable = true, dead = false, ranges = { [6603] = true } }
    end)

    native(w)
    equal(w.queries[6603], nil)
end)

test('displayed queued spell cannot bypass inactive body branch', function()
    local w = setup(function(w)
        w.actions[1] = { 'macro', 78, 'spell' }
        w.macros[1][2] = '/cast [mod:shift] Raptor Strike; Melee strike'
        w.ranges[78] = false
    end)

    native(w)
    equal(w.queries[6603], nil)
    equal(w.queries[78], nil)
end)

local function classSetup(class, configure)
    return setup(function(w)
        w.class = class
        w.spells[2974] = { name = 'Wing Clip', minRange = 0, maxRange = 5 }
        w.spells[1715] = { name = 'Hamstring', minRange = 0, maxRange = 5 }
        w.learned[#w.learned + 1] = 2974
        w.learned[#w.learned + 1] = 1715
        w.ranges[6603] = nil
        w.ranges[2974] = false
        w.ranges[1715] = true
        if configure then configure(w) end
    end)
end

test('hunter uses Wing Clip for combined macro with unavailable auto attack', function()
    local w = classSetup('HUNTER')

    tinted(w)
    equal(w.queries[2974], 1)
    equal(w.queries[6603], nil)
    equal(w.queries[1715], nil)
end)

test('warrior uses Hamstring for direct Heroic Strike', function()
    local w = classSetup('WARRIOR', function(w)
        w.actions[1] = { 'spell', 78 }
        w.ranges[1715] = false
        w.ranges[2974] = true
    end)

    tinted(w)
    equal(w.queries[1715], 1)
    equal(w.queries[2974], nil)
    equal(w.queries[6603], nil)
end)

test('warrior combined macro uses Hamstring', function()
    local w = classSetup('WARRIOR', function(w)
        w.macros[1][2] = '/cast Heroic Strike\n/cast Melee strike'
        w.ranges[1715] = false
    end)

    tinted(w)
    equal(w.queries[1715], 1)
end)

test('hunter reference becoming in range clears tint', function()
    local w = classSetup('HUNTER')
    tinted(w)
    w.ranges[2974] = true

    w:tick(0.1)

    native(w)
end)

test('restricted class reference does not fall back to auto attack', function()
    local w = classSetup('HUNTER', function(w)
        w.ranges[2974] = w.secret
        w.ranges[6603] = false
    end)

    native(w)
    equal(w.queries[6603], nil)
end)

test('unlearned class reference does not fall back to auto attack', function()
    local w = classSetup('HUNTER', function(w)
        w.learned = { 2973, 6603, 40 }
        w.ranges[6603] = false
    end)

    native(w)
    equal(w.queries[6603], nil)
end)

test('localized higher reference rank is discovered in spellbook', function()
    local w = classSetup('HUNTER', function(w)
        w.spells[2974].name = 'Couper les ailes'
        w.spells[14267] = { name = 'Couper les ailes', minRange = 0, maxRange = 5 }
        w.learned[9] = 14267
        w.ranges[14267] = false
    end)

    tinted(w)
    equal(w.queries[14267], 1)
    equal(w.queries[2974], nil)
end)

test('class reference remains spellbook first', function()
    local w = classSetup('HUNTER', function(w)
        w.ranges[2974] = true
        w.env.C_SpellBook.IsSpellBookItemInRange = function(slot, bank, unit)
            equal(slot, 9)
            equal(bank, 0)
            equal(unit, 'target')
            return false
        end
    end)

    tinted(w)
    equal(w.queries[2974], nil)
end)

test('diagnostics name class reference instead of auto attack', function()
    local w = classSetup('HUNTER')

    w.env.SlashCmdList.UTILSASSISTFOREVER('')

    local output = table.concat(w.messages, '\n')
    assert(output:find('Wing Clip reference', 1, true))
    assert(not output:find('Auto Attack reference', 1, true))
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
