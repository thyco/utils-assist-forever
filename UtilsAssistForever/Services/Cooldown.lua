local _, addon = ...
-- Adapted for WoW Forever from GreyOnCooldown 2.0.2 by Millán - Sanguino.
-- The original addon is distributed under GPL-3.0; see LICENSE.txt.
local Cooldown = {}
addon.Cooldown = Cooldown
local Client = addon.Client
local curves = {}

local function curve(threshold)
    if curves[threshold] then
        return curves[threshold]
    end

    if not C_CurveUtil or type(C_CurveUtil.CreateCurve) ~= "function"
        or not Enum or not Enum.LuaCurveType then
        return nil
    end

    local ok, value = pcall(C_CurveUtil.CreateCurve)
    if not ok or not value then
        return nil
    end

    local built = pcall(function()
        value:SetType(Enum.LuaCurveType.Step)
        value:AddPoint(0, 0)
        value:AddPoint(threshold, 1)
    end)
    if built then
        curves[threshold] = value
        return value
    end
end

local function call(api, ...)
    if type(api) ~= "function" then
        return nil
    end

    local ok, first, second, third = pcall(api, ...)
    if not ok or not Client.Readable(first) or not Client.Readable(second)
        or not Client.Readable(third) then
        return nil
    end

    return first, second, third
end

local function remaining(start, duration, enabled, isOnGCD)
    if Client.Boolean(isOnGCD) == true or Client.Boolean(enabled) == false
        or not Client.Number(start) or not Client.Number(duration) then
        return false
    end

    local now = call(GetTime)
    if not Client.Number(now) or start <= 0 or duration <= 0 or start + duration <= now then
        return false
    end

    return true
end

local function cooldownInfo(api, slot)
    local first, duration, enabled = call(api, slot)
    if Client.Table(first) then
        return first
    end

    if Client.Number(first) then
        return { startTime = first, duration = duration, isEnabled = enabled }
    end
end

local function onGlobalCooldown(info)
    local flag = Client.Boolean(info.isOnGCD)
    if flag ~= nil then
        return flag
    end

    if Client.Number(info.activeCategory) and info.activeCategory == 2316 then
        return true
    end

    -- Older clients have no isOnGCD field. Match the active global cooldown
    -- by start and duration; otherwise only long cooldowns are conclusive.
    local global = cooldownInfo(C_Spell and C_Spell.GetSpellCooldown, 61304)
        or cooldownInfo(GetSpellCooldown, 61304)
    if global and Client.Number(global.startTime) and Client.Number(global.duration)
        and Client.Number(info.startTime) and Client.Number(info.duration)
        and math.abs(global.startTime - info.startTime) < 0.05
        and math.abs(global.duration - info.duration) < 0.05 then
        return true
    end

    if Client.Number(info.duration) and info.duration <= 1.88 then
        return true
    end

    return false
end

local function active(info)
    if not Client.Table(info) or not Client.Readable(info.isOnGCD) then
        return false
    end

    return remaining(info.startTime, info.duration, info.isEnabled, onGlobalCooldown(info))
end

local function durationActive(api, id, info)
    local duration = call(api, id, true)
    if not duration or not Client.Readable(duration)
        or type(duration.HasSecretValues) ~= "function" then
        return nil
    end

    if info and Client.Boolean(info.isOnGCD) == true then
        return false
    end

    local secret = call(duration.HasSecretValues, duration)
    if Client.Boolean(secret) == false then
        local remainingValue = call(duration.GetRemainingDuration, duration)
        local total = call(duration.GetTotalDuration, duration)
        if not Client.Number(remainingValue) then
            return nil
        end

        if not info or Client.Boolean(info.isOnGCD) == nil then
            if not Client.Number(total) or total <= 1.88 then
                return false
            end
        end

        return remainingValue > 0
    end

    if Client.Boolean(secret) == true and type(duration.EvaluateRemainingDuration) == "function" then
        -- The duration API was called with ignoreGCD=true, so a real cooldown
        -- can stay grey until it expires even without readable GCD metadata.
        local step = curve(0.001)
        if step then
            local ok, value = pcall(duration.EvaluateRemainingDuration, duration, step)
            if ok then
                return value
            end
        end
    end
end

local function unusable(usable, lackingResources)
    local usableValue = Client.Boolean(usable)
    local resourceValue = Client.Boolean(lackingResources)
    if usableValue ~= false or resourceValue == nil then
        return false
    end

    if resourceValue then
        return addon.Config.Get("greyWithoutResources")
    end

    return addon.Config.Get("greyUnusableActions")
end

function Cooldown.Action(slot, spellID)
    if Client.Number(slot) then
        local kind = addon.Client.ActionInfo(slot)
        if not kind then
            return false
        end

        local usable, resources = call(C_ActionBar and C_ActionBar.IsUsableAction, slot)
        if usable == nil then
            usable, resources = call(IsUsableAction, slot)
        end
        if unusable(usable, resources) then
            return true
        end

        local info = cooldownInfo(C_ActionBar and C_ActionBar.GetActionCooldown, slot)
            or cooldownInfo(GetActionCooldown, slot)
        local duration = durationActive(C_ActionBar and C_ActionBar.GetActionCooldownDuration, slot, info)
        if duration ~= nil then
            return duration
        end

        return active(info)
    end

    if Client.Number(spellID) then
        local usable, resources = call(C_Spell and C_Spell.IsSpellUsable, spellID)
        if usable == nil then
            usable, resources = call(IsUsableSpell, spellID)
        end
        if unusable(usable, resources) then
            return true
        end

        local info = cooldownInfo(C_Spell and C_Spell.GetSpellCooldown, spellID)
            or cooldownInfo(GetSpellCooldown, spellID)
        local duration = durationActive(C_Spell and C_Spell.GetSpellCooldownDuration, spellID, info)
        if duration ~= nil then
            return duration
        end

        return active(info)
    end

    return false
end

function Cooldown.Pet(index)
    if not addon.Config.Get("greyPetActions") or not Client.Number(index)
        or not GetPetActionInfo or not Client.String(call(GetPetActionInfo, index)) then
        return false
    end

    if addon.Config.Get("greyUnusableActions")
        and Client.Boolean(call(GetPetActionSlotUsable, index)) == false then
        return true
    end

    local start, duration, enabled = call(GetPetActionCooldown, index)
    if not Client.Number(duration) or duration <= 1.88 then
        return false
    end

    return remaining(start, duration, enabled, false)
end
