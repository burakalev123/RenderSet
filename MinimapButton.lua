local _, addon = ...

local button = CreateFrame("Button", "RenderSetMinimapButton", Minimap)
button:SetSize(32, 32)
button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52, -18)
button:SetFrameStrata("MEDIUM")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")
icon:SetTexture("Interface\\Minimap\\Tracking\\Repair")

local border = button:CreateTexture(nil, "OVERLAY")
border:SetAllPoints()
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

button:SetScript("OnClick", function()
    addon.UI.Toggle()
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("RenderSet")
    GameTooltip:AddLine("Left-click: Open/close", 1, 1, 1)
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

addon.MinimapButton = button
