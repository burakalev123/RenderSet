local function fail(message)
    error(message, 2)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertTrue(value, message)
    if value ~= true then
        fail(message or "expected true")
    end
end

local function loadCore(initialDatabase)
    RenderSetDB = initialDatabase

    local frame = {
        registeredEvent = nil,
        unregisteredEvent = nil,
        scripts = {},
    }

    function frame:RegisterEvent(eventName)
        self.registeredEvent = eventName
    end

    function frame:UnregisterEvent(eventName)
        self.unregisteredEvent = eventName
    end

    function frame:SetScript(scriptName, handler)
        self.scripts[scriptName] = handler
    end

    CreateFrame = function(frameType)
        assertEqual(frameType, "Frame")
        return frame
    end

    local chunk = assert(loadfile("Core.lua"))
    chunk("RenderSet")
    return frame
end

local function fireAddonLoaded(frame, addonName)
    frame.scripts.OnEvent(frame, "ADDON_LOADED", addonName)
end

local tests = {}

function tests.first_run_initializes_minimum_database()
    local frame = loadCore(nil)
    assertEqual(frame.registeredEvent, "ADDON_LOADED")

    fireAddonLoaded(frame, "RenderSet")

    assertEqual(type(RenderSetDB), "table")
    assertEqual(RenderSetDB.schemaVersion, 1)
    assertEqual(type(RenderSetDB.profiles), "table")
    assertEqual(RenderSetDB.selectedProfile, nil)
    assertEqual(RenderSetDB.activeProfile, nil)
    assertEqual(frame.unregisteredEvent, "ADDON_LOADED")
end

function tests.unrelated_addon_event_does_not_initialize_database()
    local frame = loadCore(nil)

    fireAddonLoaded(frame, "AnotherAddon")

    assertEqual(RenderSetDB, nil)
    assertEqual(frame.unregisteredEvent, nil)
end

function tests.partial_database_normalizes_only_invalid_required_fields()
    local database = {
        schemaVersion = "invalid",
        profiles = "invalid",
        preservedField = "keep",
    }
    local frame = loadCore(database)

    fireAddonLoaded(frame, "RenderSet")

    assertEqual(RenderSetDB, database)
    assertEqual(RenderSetDB.schemaVersion, 1)
    assertEqual(type(RenderSetDB.profiles), "table")
    assertEqual(RenderSetDB.preservedField, "keep")
    assertEqual(RenderSetDB.selectedProfile, nil)
    assertEqual(RenderSetDB.activeProfile, nil)
end

function tests.partial_database_adds_missing_schema_and_preserves_profiles()
    local profiles = { Quality = { graphicsShadowQuality = "3" } }
    local database = { profiles = profiles }
    local frame = loadCore(database)

    fireAddonLoaded(frame, "RenderSet")

    assertEqual(RenderSetDB.schemaVersion, 1)
    assertEqual(RenderSetDB.profiles, profiles)
end

function tests.partial_database_adds_missing_profiles_and_preserves_schema()
    local database = { schemaVersion = 1 }
    local frame = loadCore(database)

    fireAddonLoaded(frame, "RenderSet")

    assertEqual(RenderSetDB.schemaVersion, 1)
    assertEqual(type(RenderSetDB.profiles), "table")
    assertEqual(next(RenderSetDB.profiles), nil)
end

function tests.valid_existing_database_and_profiles_are_preserved()
    local profiles = { Quality = { graphicsShadowQuality = "3" } }
    local database = {
        schemaVersion = 1,
        profiles = profiles,
    }
    local frame = loadCore(database)

    fireAddonLoaded(frame, "RenderSet")

    assertEqual(RenderSetDB, database)
    assertEqual(RenderSetDB.profiles, profiles)
    assertEqual(RenderSetDB.profiles.Quality.graphicsShadowQuality, "3")
    assertTrue(next(RenderSetDB.profiles) ~= nil)
end

local passed = 0
for name, test in pairs(tests) do
    local succeeded, message = pcall(test)
    if not succeeded then
        io.stderr:write("FAIL ", name, ": ", tostring(message), "\n")
        os.exit(1)
    end
    passed = passed + 1
end

print("PASS: " .. passed .. " core initialization tests")
