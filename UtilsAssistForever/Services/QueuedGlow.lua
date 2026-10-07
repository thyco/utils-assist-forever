local _, addon = ...
local QueuedGlow = {}
addon.QueuedGlow = QueuedGlow

local library
if type(LibStub) == 'table' and type(LibStub.GetLibrary) == 'function' then
    local ok, found = pcall(LibStub.GetLibrary, LibStub, 'LibCustomGlow-1.0', true)
    if ok then library = found end
elseif type(LibStub) == 'function' then
    local ok, found = pcall(LibStub, 'LibCustomGlow-1.0', true)
    if ok then library = found end
end
if type(library) ~= 'table' or type(library.PixelGlow_Start) ~= 'function' then
    library = nil
end
local glowKey = 'UtilsAssistForeverQueued'
local entries = {}

local function selectedColor()
    if not addon.Config.Get('queuedGlowNativeColor') then
        return addon.Config.GetColor('queuedGlowColor')
    end
end

local function recolor(entry, color)
    color = color or entry.nativeColor
    for _, texture in ipairs(entry.effect.textures or {}) do
        texture:SetVertexColor(color[1], color[2], color[3], color[4])
    end
end

function QueuedGlow.Prepare(button)
    if entries[button] or not library or InCombatLockdown() then
        return entries[button]
    end

    local frame = CreateFrame('Frame', nil, button)
    frame:SetAllPoints(button)
    frame:SetFrameLevel(button:GetFrameLevel() + 6)
    frame:EnableMouse(false)
    frame:Hide()

    -- Reserve the effect before combat. Hidden effects have no active animation.
    library.PixelGlow_Start(frame, nil, 4, 0.4, nil, 2, 0, 0, true, glowKey)
    local effect = frame['_PixelGlow' .. glowKey]
    effect:Hide()

    local nativeColor = effect.textures and effect.textures[1]
        and { effect.textures[1]:GetVertexColor() } or { 0.95, 0.95, 0.32, 1 }
    local entry = { frame = frame, effect = effect, nativeColor = nativeColor, active = false }
    entries[button] = entry
    recolor(entry, selectedColor())
    return entry
end

function QueuedGlow.SetColor()
    local color = selectedColor()
    for _, entry in pairs(entries) do
        recolor(entry, color)
    end
end

function QueuedGlow.Set(button, active)
    local entry = entries[button]
    if not entry and active then
        entry = QueuedGlow.Prepare(button)
    end

    if not entry or entry.active == active then
        return
    end

    entry.active = active
    if active then
        entry.frame:Show()
        entry.effect:Show()
    else
        entry.effect:Hide()
        entry.frame:Hide()
    end
end

function QueuedGlow.Clear()
    for button in pairs(entries) do
        QueuedGlow.Set(button, false)
    end
end
