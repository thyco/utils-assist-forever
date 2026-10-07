local _, addon = ...
local feature = { buttons = {}, dirty = true, active = 0 }
addon.QueuedAttackGlow = feature

function feature:Enabled()
    return addon.Config.Get('highlightQueuedAttacks')
end

function feature:MarkDirty()
    self.dirty = true
end

function feature:Refresh(discover, rebuild)
    if rebuild then
        self.dirty = true
    end

    if rebuild and not addon.RangeCheck:Enabled() then
        addon.NextSwing:Rebuild(addon.Client.PlayerSpells())
    end

    if discover then
        self.buttons = addon.Buttons.All()
        for _, button in ipairs(self.buttons) do
            addon.QueuedGlow.Prepare(button)
        end
        self.dirty = true
    end

    if not self.dirty then
        return
    end

    self.dirty = false
    self.active = 0
    for _, button in ipairs(self.buttons) do
        local queued = false
        if addon.Client.Boolean(addon.Client.Read(button.IsVisible, button)) == true then
            local kind, id, subtype = addon.Client.ActionInfo(button.action)
            queued = addon.NextSwing:ForAction(button.action, nil, kind, id, subtype) ~= nil
                and addon.Client.Boolean(addon.Client.Read(button.GetChecked, button)) == true
        end

        addon.QueuedGlow.Set(button, queued)
        if queued then
            self.active = self.active + 1
        end
    end
end

function feature:Stop()
    addon.QueuedGlow.Clear()
    self.active = 0
end

addon:RegisterFeature(feature)
