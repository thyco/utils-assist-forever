local _, addon = ...
local Range = { spells = {}, samples = {}, checks = {} }
addon.Range = Range
local UNKNOWN = {}

function Range:Rebuild()
    self.spells = {}

    local entries = addon.Client.PlayerSpells()
    if addon.NextSwing then
        addon.NextSwing:Rebuild(entries)
    end

    for _, entry in ipairs(entries) do
        local spell = addon.Client.SpellInfo(entry.id)
        if spell then
            spell.slot, spell.bank = entry.slot, entry.bank
            self.spells[entry.id] = spell
            if addon.Client.Number(entry.baseID) then
                self.spells[entry.baseID] = spell
            end
        end
    end
end

function Range:BeginUpdate()
    self.samples = {}
    self.checks = {}
    self.referenceRequested = false
    self.unit = addon.Client.RangeUnit()
    self.hasTarget = self.unit ~= nil
end

function Range:IsOutOfRange(id)
    if not self.hasTarget or not addon.Client.Number(id) then
        return false
    end

    local spell = self.spells[id]
    if not spell then
        return false
    end

    local setting = spell.category == "melee" and "checkMeleeAbilities" or "checkRangedAbilities"
    if not addon.Config.Get(setting) then
        return false
    end

    return self:Sample(spell) == false
end

function Range:IsMeleeOutOfRange()
    if not self.hasTarget or not addon.Config.Get("checkMeleeAbilities") then
        return false
    end

    self.referenceRequested = true
    local reference = addon.NextSwing.reference
    return reference ~= nil and self:Sample(reference) == false
end

function Range:Sample(spell)
    local value = self.samples[spell.id]
    if value == nil then
        local source, bookStatus, idStatus
        value, source, bookStatus, idStatus = addon.Client.InRange(spell.id, spell.slot, spell.bank, self.unit)
        self.checks[spell.id] = { spell = spell, source = source, book = bookStatus, spellID = idStatus }
        if value == nil then
            value = UNKNOWN
        end
        self.samples[spell.id] = value
    end

    if value ~= UNKNOWN then
        return value
    end
end

function Range:DescribeChecks()
    if not self.hasTarget then
        return { "No eligible unit: use a living attackable target, or mouseover with no target selected." }
    end

    local lines = { "Checking: " .. self.unit .. " (living, attackable)" }
    local ids = {}
    for id in pairs(self.checks) do
        ids[#ids + 1] = id
    end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local check = self.checks[id]
        local spell = check.spell
        local details = spell.reference and "melee reference" or (spell.category .. ", "
            .. spell.minRange .. "-" .. spell.maxRange .. " yd metadata")
        lines[#lines + 1] = spell.name .. " (" .. id .. ", " .. details .. "): spellbook=" .. check.book
            .. "; spell ID=" .. check.spellID .. "; used=" .. check.source
    end

    if self.referenceRequested and not addon.NextSwing.reference then
        lines[#lines + 1] = addon.NextSwing.referenceLabel .. ": unavailable (not found in player spellbook)."
    end

    if #ids == 0 then
        lines[#lines + 1] = "No eligible enabled spell was checked on a visible default button."
    end

    return lines
end
