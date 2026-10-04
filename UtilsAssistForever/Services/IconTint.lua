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

    local color = record.color
    if record.rangeActive then
        record.icon:SetDesaturated(true)
        record.icon:SetVertexColor(1, 0.25, 0.25, color[4])
    elseif record.cooldownActive then
        record.icon:SetVertexColor(color[1], color[2], color[3], color[4])
        if record.icon.SetDesaturation then
            record.icon:SetDesaturation(record.cooldownAmount)
        else
            record.icon:SetDesaturated(true)
        end
    else
        record.icon:SetVertexColor(color[1], color[2], color[3], color[4])
        record.icon[record.desaturationMethod](record.icon, record.desaturation)
    end

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

    local record = { icon = icon, rangeActive = false, cooldownActive = false, writing = false }
    snapshot(record)
    records[button] = record

    -- Observe native writes instead of replacing Blizzard handlers. Keep the
    -- latest native appearance so mana/lock shading is restored accurately.
    hooksecurefunc(icon, "SetVertexColor", function(_, r, g, b, a)
        if record.writing or not (record.rangeActive or record.cooldownActive) then
            return
        end

        record.color = { r, g, b, a }
        apply(record)
    end)

    local function watchDesaturation(method)
        hooksecurefunc(icon, method, function(_, value)
            if record.writing or not (record.rangeActive or record.cooldownActive) then
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

local function setLayer(button, layer, active)
    local record = records[button]
    if not record or record[layer] == active then
        return
    end

    if active and not (record.rangeActive or record.cooldownActive) then
        snapshot(record)
    end

    record[layer] = active
    apply(record)
end

function IconTint.Set(button, active)
    setLayer(button, "rangeActive", active)
end

function IconTint.SetCooldown(button, active)
    local record = records[button]
    if not record then
        return
    end

    local amount, enabled = nil, false
    if issecretvalue and issecretvalue(active) then
        amount = active
        enabled = true
    elseif active == true or (type(active) == "number" and active > 0) then
        amount = active == true and 1 or active
        enabled = true
    end

    if record.cooldownActive == enabled and (not enabled
        or addon.Client.Readable(amount) and addon.Client.Readable(record.cooldownAmount)
        and record.cooldownAmount == amount) then
        return
    end

    if enabled and not (record.rangeActive or record.cooldownActive) then
        snapshot(record)
    end

    record.cooldownActive = enabled
    record.cooldownAmount = amount
    apply(record)
end

function IconTint.Clear()
    for button in pairs(records) do
        IconTint.Set(button, false)
    end
end

function IconTint.ClearCooldown()
    for button in pairs(records) do
        IconTint.SetCooldown(button, false)
    end
end
