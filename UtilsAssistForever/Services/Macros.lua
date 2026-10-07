local _, addon = ...
local Macros = { byName = {} }
addon.Macros = Macros
local Client = addon.Client

local function trim(text)
    return text:match('^%s*(.-)%s*$')
end

local function commands(group, defaults)
    local result = {}
    for _, command in ipairs(defaults) do
        result[command] = true
    end
    for index = 1, 20 do
        local command = _G['SLASH_' .. group .. index]
        if Client.String(command) then
            result[command:lower()] = true
        end
    end

    return result
end

local function parse(body)
    local casts = commands('CAST', { '/cast', '/spell' })
    local uses = commands('USE', { '/use' })
    local starts = commands('STARTATTACK', { '/startattack' })
    local stops = commands('STOPCASTING', { '/stopcasting' })
    local lines = {}

    for rawLine in body:gmatch('[^\r\n]+') do
        local line = trim(rawLine)
        if line ~= '' and line:sub(1, 1) ~= '#' then
            local command, args = line:match('^(%S+)%s*(.-)$')
            command = command:lower()
            if casts[command] or uses[command] then
                lines[#lines + 1] = args
            elseif not starts[command] and not stops[command] then
                -- Do not infer execution through scripts, target changes,
                -- /stopmacro, /click, or sequences with hidden state.
                return nil
            end
        end
    end

    return lines
end

function Macros:Rebuild()
    self.byName = {}
    if type(GetNumMacros) ~= 'function' or type(GetMacroInfo) ~= 'function' then
        return
    end

    local ok, accountCount, characterCount = pcall(GetNumMacros)
    local constants = Constants and Constants.MacroConsts
    local offset = constants and constants.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS
    if not ok or not Client.Number(accountCount) or not Client.Number(characterCount)
        or not Client.Number(offset) then
        return
    end

    local function add(index)
        local success, name, _, body = pcall(GetMacroInfo, index)
        if not success or not Client.String(name) then
            return false
        end

        -- A duplicate name cannot be mapped to a unique action slot. Even an
        -- unreadable body must participate in duplicate-name detection.
        if self.byName[name] ~= nil then
            self.byName[name] = false
        else
            self.byName[name] = Client.String(body) and parse(body) or false
        end
        return true
    end

    for index = 1, accountCount do
        if not add(index) then
            self.byName = {}
            return
        end
    end
    for index = 1, characterCount do
        if not add(offset + index) then
            self.byName = {}
            return
        end
    end
end

function Macros:NextSwing(slot, unit, names)
    local name = Client.Read(C_ActionBar and C_ActionBar.GetActionText or GetActionText, slot)
    local lines = Client.String(name) and self.byName[name]
    if not lines then
        return nil
    end

    for _, args in ipairs(lines) do
        local selected, target = args, nil
        if args:find('[', 1, true) or args:find(';', 1, true) then
            if type(SecureCmdOptionParse) == 'function' then
                local ok
                ok, selected, target = pcall(SecureCmdOptionParse, args)
                if not ok then
                    selected = nil
                end
            else
                selected = nil
            end
        end

        if Client.String(selected) and Client.Readable(target)
            and (target == nil or unit == nil or target == unit) then
            selected = trim(selected):gsub('^!', '')
            local id = names[trim(selected)]
            if id then
                return id, true
            end
        end
    end

    return nil, true
end
