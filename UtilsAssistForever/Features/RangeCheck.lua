local _, addon = ...
local feature = { buttons = {}, colored = 0, references = {} }
addon.RangeCheck = feature

function feature:Refresh(discover, rebuild)
    if rebuild then
        addon.Range:Rebuild()
    end

    if discover then
        self.buttons = addon.Buttons.All()
        for _, button in ipairs(self.buttons) do
            addon.IconTint.Prepare(button)
        end
    end

    addon.Range:BeginUpdate()
    self.colored = 0
    self.references = {}
    for _, button in ipairs(self.buttons) do
        local outOfRange = false
        if addon.Range.hasTarget and addon.Client.Boolean(button:IsVisible()) == true then
            -- Live slots handle paging; displayed spell IDs handle macro changes.
            local queued, source, suppress = addon.NextSwing:ForAction(button.action, addon.Range.unit)
            if queued then
                outOfRange = addon.Range:IsMeleeOutOfRange()
                self.references[#self.references + 1] = "Action slot " .. button.action
                    .. ": " .. source .. " -> next-swing spell " .. queued .. " -> " .. addon.NextSwing.referenceLabel
            elseif not suppress then
                local id = addon.Client.ActionSpell(button.action)
                outOfRange = addon.Range:IsOutOfRange(id)
            end
        end

        addon.IconTint.Set(button, outOfRange)
        if outOfRange then
            self.colored = self.colored + 1
        end
    end
end

function feature:Stop()
    self.references = {}
    addon.IconTint.Clear()
    self.colored = 0
end

addon:RegisterFeature(feature)
