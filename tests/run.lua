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
    if configure then configure(world) end

    local addon = world:load('Services/Client', 'Services/Config', 'Services/Range')
    addon.Config.Initialize()
    addon.Range:Rebuild()
    addon.Range:BeginUpdate()

    return world, addon
end

test('positive minimum range is ranged', function()
    local _, addon = setup()

    equal(addon.Range.spells[10].category, 'ranged')
end)

test('zero minimum ranged caster spell is ranged', function()
    local _, addon = setup()

    equal(addon.Range.spells[20].category, 'ranged')
end)

test('five yard spell is melee', function()
    local _, addon = setup()

    equal(addon.Range.spells[40].category, 'melee')
end)

test('zero metadata melee remains eligible with explicit negative range', function()
    local _, addon = setup(function(w) w.spells[40].maxRange = 0 end)

    equal(addon.Range.spells[40].category, 'melee')
    equal(addon.Range:IsOutOfRange(40), true)
end)

test('zero metadata alone never implies out of range', function()
    local _, addon = setup(function(w)
        w.spells[40].maxRange = 0
        w.ranges[40] = nil
    end)

    equal(addon.Range:IsOutOfRange(40), false)
end)

test('short ranged spell with minimum range is not melee', function()
    local _, addon = setup(function(w)
        w.spells[40].minRange = 2
        w.spells[40].maxRange = 5
    end)

    equal(addon.Range.spells[40].category, 'ranged')
end)

test('missing bounds do not invent a classification', function()
    local _, addon = setup(function(w) w.spells[10].maxRange = nil end)

    equal(addon.Range.spells[10], nil)
    equal(addon.Range:IsOutOfRange(10), false)
end)

test('restricted bounds are ignored', function()
    local _, addon = setup(function(w) w.spells[10].maxRange = w.secret end)

    equal(addon.Range.spells[10], nil)
end)

test('invalid bounds are ignored', function()
    local _, addon = setup(function(w) w.spells[10].maxRange = 2 end)

    equal(addon.Range.spells[10], nil)
end)

test('helpful spells are ignored', function()
    local _, addon = setup(function(w) w.helpful = { [10] = true } end)

    equal(addon.Range.spells[10], nil)
end)

test('spellbook false is authoritative over spell ID true', function()
    local world, addon = setup(function(w)
        w.ranges[10] = true
        w.env.C_SpellBook.IsSpellBookItemInRange = function(slot, bank, unit)
            equal(slot, 1)
            equal(bank, 0)
            equal(unit, 'target')
            return false
        end
    end)

    equal(addon.Range:IsOutOfRange(10), true)
    equal(world.queries[10], nil)
end)

test('spellbook true is authoritative over spell ID false', function()
    local world, addon = setup(function(w)
        w.env.C_SpellBook.IsSpellBookItemInRange = function() return true end
    end)

    equal(addon.Range:IsOutOfRange(10), false)
    equal(world.queries[10], nil)
end)

test('nil spellbook check falls back to ID', function()
    local world, addon = setup(function(w)
        w.env.C_SpellBook.IsSpellBookItemInRange = function() return nil end
    end)

    equal(addon.Range:IsOutOfRange(10), true)
    equal(world.queries[10], 1)
end)

test('restricted spellbook check falls back to readable ID', function()
    local _, addon = setup(function(w)
        w.env.C_SpellBook.IsSpellBookItemInRange = function() return w.secret end
    end)

    equal(addon.Range:IsOutOfRange(10), true)
end)

test('failed spellbook check falls back to ID', function()
    local _, addon = setup(function(w)
        w.env.C_SpellBook.IsSpellBookItemInRange = function() error('unavailable') end
    end)

    equal(addon.Range:IsOutOfRange(10), true)
end)

test('both APIs failing leaves appearance unchanged', function()
    local _, addon = setup(function(w)
        w.env.C_SpellBook.IsSpellBookItemInRange = function() error('unavailable') end
        w.env.C_Spell.IsSpellInRange = function() error('unavailable') end
    end)

    equal(addon.Range:IsOutOfRange(10), false)
end)

test('restricted range is unknown and cached', function()
    local world, addon = setup(function(w) w.ranges[10] = w.secret end)

    equal(addon.Range:IsOutOfRange(10), false)
    equal(addon.Range:IsOutOfRange(10), false)
    equal(world.queries[10], 1)
end)

test('numeric zero is an explicit negative range', function()
    local _, addon = setup(function(w) w.ranges[10] = 0 end)

    equal(addon.Range:IsOutOfRange(10), true)
end)

test('numeric one is an explicit positive range', function()
    local _, addon = setup(function(w) w.ranges[10] = 1 end)

    equal(addon.Range:IsOutOfRange(10), false)
end)

test('string zero is unknown', function()
    local _, addon = setup(function(w) w.ranges[10] = '0' end)

    equal(addon.Range:IsOutOfRange(10), false)
end)

test('restricted target existence blocks mouseover and API calls', function()
    local world, addon = setup(function(w)
        w.exists = w.secret
        w.mouseover = { exists = true, attackable = true, dead = false, ranges = { [10] = false } }
    end)

    equal(addon.Range:IsOutOfRange(10), false)
    equal(next(world.queries), nil)
end)

test('base spell aliases share range samples', function()
    local world, addon = setup(function(w)
        local original = w.env.C_SpellBook.GetSpellBookItemInfo
        w.env.C_SpellBook.GetSpellBookItemInfo = function(index, bank)
            local info = original(index, bank)
            if index == 1 then info.actionID = 11 end
            return info
        end
    end)

    equal(addon.Range:IsOutOfRange(10), true)
    equal(addon.Range:IsOutOfRange(11), true)
    equal(world.queries[10], 1)
end)

test('disabled category skips range API', function()
    local world, addon = setup()
    addon.Config.Set('checkMeleeAbilities', false)

    equal(addon.Range:IsOutOfRange(40), false)
    equal(next(world.queries), nil)
end)

test('restricted metadata table does not get inspected', function()
    local _, addon = setup(function(w) w.spells[10] = w.secret end)

    equal(addon.Range.spells[10], nil)
end)

test('metadata API error is ignored', function()
    local _, addon = setup(function(w)
        w.env.C_Spell.GetSpellInfo = function() error('not available') end
    end)

    equal(next(addon.Range.spells), nil)
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
