local _, addon = ...
local feature = { buttons = {}, greyed = 0 }
addon.CooldownGrey = feature

function feature:Enabled()
    return addon.Config.Get("greyOnCooldown")
end

function feature:Refresh(discover)
    if discover then
        self.buttons = addon.Buttons.CooldownAll()
        for _, entry in ipairs(self.buttons) do
            addon.IconTint.Prepare(entry.button)
        end
    end

    self.greyed = 0
    for _, entry in ipairs(self.buttons) do
        local button = entry.button
        local visible = addon.Client.Boolean(button:IsVisible()) == true
        local grey = false
        if visible then
            if entry.kind == "pet" then
                local index = button.index or button.id
                if not addon.Client.Number(index) and type(button.GetID) == "function" then
                    index = button:GetID()
                end
                grey = addon.Cooldown.Pet(index)
            elseif entry.kind == "lab" then
                if addon.Client.String(button._state_type) and button._state_type == "action" then
                    grey = addon.Cooldown.Action(button._state_action)
                elseif addon.Client.String(button._state_type) and button._state_type == "spell" then
                    grey = addon.Cooldown.Action(nil, button._state_action)
                end
            else
                grey = addon.Cooldown.Action(button.action, button.spellID)
            end
        end

        addon.IconTint.SetCooldown(button, grey)
        if addon.Client.Readable(grey) and (grey == true or type(grey) == "number" and grey > 0) then
            self.greyed = self.greyed + 1
        end
    end
end

function feature:Stop()
    addon.IconTint.ClearCooldown()
    self.greyed = 0
end

addon:RegisterFeature(feature)
