local _, addon = ...
local Client = {}
addon.Client = Client

function Client.Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function Client.Number(value)
    return Client.Readable(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

function Client.Table(value)
    return Client.Readable(value) and type(value) == "table"
end

function Client.Boolean(value)
    if not Client.Readable(value) then
        return nil
    end

    if value == true or value == 1 then
        return true
    elseif value == false or value == 0 then
        return false
    end
end

local function read(api, ...)
    if type(api) ~= "function" then
        return nil
    end

    local ok, value = pcall(api, ...)
    if ok and Client.Readable(value) then
        return value
    end
end

Client.Read = read

function Client.String(value)
    return Client.Readable(value) and type(value) == "string"
end

function Client.CanAttack(unit)
    return Client.Boolean(read(UnitExists, unit)) == true
        and Client.Boolean(read(UnitCanAttack, "player", unit)) == true
        and Client.Boolean(read(UnitIsDeadOrGhost, unit)) == false
end

function Client.RangeUnit()
    local hasTarget = Client.Boolean(read(UnitExists, "target"))
    if hasTarget == true then
        if Client.CanAttack("target") then
            return "target"
        end
    elseif hasTarget == false and Client.CanAttack("mouseover") then
        return "mouseover"
    end
end

function Client.SpellInfo(id)
    if not Client.Number(id) or not C_Spell then
        return nil
    end

    local info = read(C_Spell.GetSpellInfo, id)
    if not Client.Table(info) or not Client.Number(info.minRange) or not Client.Number(info.maxRange)
        or info.minRange < 0 or info.maxRange < info.minRange
        or Client.Boolean(read(C_Spell.IsSpellHarmful, id)) ~= true then
        return nil
    end

    -- Range categories, not weapon/damage schools. Zero/zero may be melee;
    -- it is never evidence of distance. Only an explicit API false can tint it.
    local category = info.minRange == 0 and info.maxRange <= 5 and "melee" or "ranged"
    local name = "spell " .. id
    if Client.Readable(info.name) and type(info.name) == "string" then
        name = info.name:gsub("|", "||"):gsub("[\r\n]", " ")
    end

    return { id = id, name = name, minRange = info.minRange, maxRange = info.maxRange, category = category }
end

function Client.PlayerSpells()
    local spells = {}
    if not C_SpellBook or not Enum or not Enum.SpellBookSpellBank or not Enum.SpellBookItemType then
        return spells
    end

    local bank = Enum.SpellBookSpellBank.Player
    local count = read(C_SpellBook.GetNumSpellBookSkillLines)
    if not Client.Number(count) then
        return spells
    end

    for lineIndex = 1, count do
        local line = read(C_SpellBook.GetSpellBookSkillLineInfo, lineIndex)
        if Client.Table(line) and Client.Number(line.itemIndexOffset) and Client.Number(line.numSpellBookItems) then
            for index = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local item = read(C_SpellBook.GetSpellBookItemInfo, index, bank)
                if Client.Table(item) and Client.Readable(item.itemType) and item.itemType == Enum.SpellBookItemType.Spell
                    and Client.Boolean(item.isPassive) == false and Client.Boolean(item.isOffSpec) == false
                    and Client.Number(item.spellID) then
                    spells[#spells + 1] = { id = item.spellID, baseID = item.actionID, slot = index, bank = bank }
                end
            end
        end
    end

    return spells
end

local function rangeCheck(api, ...)
    if type(api) ~= "function" then
        return nil, "missing API"
    end

    local ok, value = pcall(api, ...)
    if not ok then
        return nil, "error"
    elseif not Client.Readable(value) then
        return nil, "restricted"
    end

    local result = Client.Boolean(value)
    if result == nil then
        return nil, "unavailable"
    end

    return result, result and "in range" or "out of range"
end

function Client.InRange(id, slot, bank, unit)
    local result, bookStatus
    if Client.Number(slot) and Client.Number(bank) then
        result, bookStatus = rangeCheck(C_SpellBook and C_SpellBook.IsSpellBookItemInRange,
            slot, bank, unit)
    else
        bookStatus = "no spellbook slot"
    end

    if result ~= nil then
        return result, "spellbook", bookStatus, "not checked"
    end

    local idStatus
    result, idStatus = rangeCheck(C_Spell and C_Spell.IsSpellInRange, id, unit)

    return result, result ~= nil and "spell ID" or "none", bookStatus, idStatus
end

function Client.ActionInfo(slot)
    if not Client.Number(slot) or slot < 1 or slot ~= math.floor(slot) or not GetActionInfo then
        return nil
    end

    local ok, kind, id, subtype = pcall(GetActionInfo, slot)
    if not ok or not Client.String(kind) or not Client.Readable(id) or not Client.Readable(subtype) then
        return nil
    end

    return kind, id, subtype
end

function Client.ActionSpell(slot)
    local kind, id, subtype = Client.ActionInfo(slot)
    if Client.Number(id) and (kind == "spell" or (kind == "macro" and subtype == "spell")) then
        return id
    end
end
