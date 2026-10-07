local _, addon = ...
local NextSwing = { ids = {}, names = {} }
addon.NextSwing = NextSwing
local Client = addon.Client
-- Base ranks identify localized spell families; learned ranks are discovered
-- from the spellbook. Never classify by icon, English spell text or queue state.
local families = { 78, 845, 2973, 6807 } -- Heroic Strike, Cleave, Raptor Strike, Maul
local classReferences = {
    HUNTER = { id = 2974, name = 'Wing Clip' },
    WARRIOR = { id = 1715, name = 'Hamstring' },
}

function NextSwing:Rebuild(entries)
    self.ids, self.names, self.reference = {}, {}, nil
    self.referenceLabel = 'Melee reference'
    local ok, _, class = pcall(UnitClass, 'player')
    local classReadable = ok and Client.String(class)
    local preferred = classReadable and classReferences[class]
    local referenceName
    if preferred then
        local info = Client.Read(C_Spell and C_Spell.GetSpellInfo, preferred.id)
        referenceName = Client.Table(info) and Client.String(info.name) and info.name or nil
        self.referenceLabel = (referenceName or preferred.name):gsub('|', '||'):gsub('[\r\n]', ' ') .. ' reference'
    elseif classReadable then
        self.referenceLabel = 'Auto Attack reference'
    end

    local familyNames = {}
    for _, id in ipairs(families) do
        local info = Client.Read(C_Spell and C_Spell.GetSpellInfo, id)
        if Client.Table(info) and Client.String(info.name) then
            familyNames[info.name] = true
        end
    end

    for _, entry in ipairs(entries) do
        local info = Client.Read(C_Spell and C_Spell.GetSpellInfo, entry.id)
        local isReference = false
        if preferred then
            isReference = entry.id == preferred.id or (referenceName ~= nil
                and Client.Table(info) and Client.String(info.name) and info.name == referenceName)
        elseif classReadable then
            isReference = Client.Boolean(Client.Read(C_Spell and C_Spell.IsAutoAttackSpell, entry.id)) == true
        end

        if isReference then
            self.reference = { id = entry.id, slot = entry.slot, bank = entry.bank,
                name = self.referenceLabel, reference = true }
        end

        if Client.Table(info) and Client.String(info.name) and familyNames[info.name] then
            self.ids[entry.id] = true
            self.names[info.name] = entry.id
            if Client.Number(entry.baseID) then
                self.ids[entry.baseID] = true
            end

            local rank = Client.Read(C_Spell and C_Spell.GetSpellSubtext, entry.id)
            if Client.String(rank) and rank ~= '' then
                self.names[info.name .. '(' .. rank .. ')'] = entry.id
                self.names[info.name .. ' (' .. rank .. ')'] = entry.id
            end
        end
    end

    addon.Macros:Rebuild()
end

function NextSwing:ForAction(slot, unit, kind, id, subtype)
    if kind == 'macro' then
        local queued, inspected = addon.Macros:NextSwing(slot, unit, self.names)
        if queued then
            return queued, 'macro body'
        elseif inspected and Client.Number(id) and self.ids[id] then
            -- A readable supported body is authoritative over its tooltip.
            -- Do not bypass an inactive branch or a different explicit unit.
            return nil, nil, true
        end
    end

    if Client.Number(id) and self.ids[id]
        and (kind == 'spell' or (kind == 'macro' and subtype == 'spell')) then
        return id, kind == 'macro' and 'displayed macro spell' or 'direct spell'
    end
end
