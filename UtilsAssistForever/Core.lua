local addonName, addon = ...
addon.name = addonName
addon.version = "0.4.4"
addon.features = {}
addon.started = false
addon.running = false

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end

function addon:Start()
    if self.started then
        return
    end

    self.started = true
    self.Config.Subscribe(function()
        self:ApplySettings()
    end)
    self:ApplySettings()
end

function addon:ApplySettings()
    self.running = false
    for _, feature in ipairs(self.features) do
        if feature:Enabled() then
            self.running = true
        else
            feature:Stop()
        end
    end

    self:SetPolling(self.running)
    if self.running then
        self:Refresh(true, true)
    end
end

function addon:Refresh(discover, rebuild, refreshCooldown)
    if not self.started or not self.running then
        return
    end

    for _, feature in ipairs(self.features) do
        if feature:Enabled() and (feature ~= self.CooldownGrey or refreshCooldown ~= false) then
            feature:Refresh(discover, rebuild)
        end
    end
end
