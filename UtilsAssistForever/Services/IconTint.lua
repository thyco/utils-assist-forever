local _, addon = ...
local IconTint = {}
addon.IconTint = IconTint
local records = {}

local function snapshot(record)
    local icon = record.icon
    record.color = { icon:GetVertexColor() }
    if icon.GetDesaturation then
        record.desaturationMethod = "SetDesaturation"
        record.desaturation = icon:GetDesaturation()
    else
        record.desaturationMethod = "SetDesaturated"
        record.desaturation = icon:IsDesaturated()
    end
end

local function apply(record)
    record.writing = true
    record.icon:SetDesaturated(true)
    record.icon:SetVertexColor(1, 0.25, 0.25, record.color[4])
    record.writing = false
end

function IconTint.Prepare(button)
    if records[button] then
        return true
    end

    if InCombatLockdown() or not hooksecurefunc then
        return false
    end

    local icon = button.icon
    if not icon or not icon.GetVertexColor or not icon.SetVertexColor
        or not icon.SetDesaturated or not icon.IsDesaturated then
        return false
    end

    local record = { icon = icon, active = false, writing = false }
    snapshot(record)
    records[button] = record

    -- Observe native writes instead of replacing Blizzard handlers. Keep the
    -- latest native appearance so mana/lock shading is restored accurately.
    hooksecurefunc(icon, "SetVertexColor", function(_, r, g, b, a)
        if record.writing or not record.active then
            return
        end

        record.color = { r, g, b, a }
        apply(record)
    end)

    local function watchDesaturation(method)
        hooksecurefunc(icon, method, function(_, value)
            if record.writing or not record.active then
                return
            end

            record.desaturationMethod = method
            record.desaturation = value
            apply(record)
        end)
    end

    watchDesaturation("SetDesaturated")
    if icon.SetDesaturation then
        watchDesaturation("SetDesaturation")
    end

    return true
end

function IconTint.Set(button, active)
    local record = records[button]
    if not record or record.active == active then
        return
    end

    if active then
        snapshot(record)
        record.active = true
        apply(record)
        return
    end

    record.active = false
    record.writing = true
    local color = record.color
    record.icon:SetVertexColor(color[1], color[2], color[3], color[4])
    record.icon[record.desaturationMethod](record.icon, record.desaturation)
    record.writing = false
end

function IconTint.Clear()
    for button in pairs(records) do
        IconTint.Set(button, false)
    end
end
