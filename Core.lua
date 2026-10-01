local ADDON_NAME = ...
local SCHEMA_VERSION = 1

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, _, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then
        return
    end

    if type(RenderSetDB) ~= "table" then
        RenderSetDB = {}
    end

    if type(RenderSetDB.profiles) ~= "table" then
        RenderSetDB.profiles = {}
    end

    if type(RenderSetDB.schemaVersion) ~= "number" then
        RenderSetDB.schemaVersion = SCHEMA_VERSION
    end

    self:UnregisterEvent("ADDON_LOADED")
end)
