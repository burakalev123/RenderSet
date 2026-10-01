local EXPECTED_CVARS = {
    graphicsShadowQuality = true,
    graphicsProjectedTextures = true,
    graphicsParticleDensity = true,
    graphicsViewDistance = true,
}

local function fail(message)
    error(message, 2)
end

local function assertTrue(value, message)
    if value ~= true then
        fail(message or "expected true")
    end
end

local function assertFalse(value, message)
    if value ~= false then
        fail(message or "expected false")
    end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function countKeys(value)
    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end
    return count
end

local function loadEngine(profiles, getCVar, setCVar)
    RenderSetDB = {
        schemaVersion = 1,
        profiles = profiles or {},
    }

    local calls = {
        reads = {},
        writes = {},
    }

    C_CVar = {
        GetCVar = function(cvarName)
            calls.reads[#calls.reads + 1] = cvarName
            return getCVar(cvarName)
        end,
        SetCVar = function(cvarName, value)
            calls.writes[#calls.writes + 1] = { cvarName, value }
            return setCVar(cvarName, value)
        end,
    }

    local addon = {}
    local chunk = assert(loadfile("Profiles.lua"))
    chunk("RenderSet", addon)
    return addon, calls
end

local tests = {}

function tests.capture_success()
    local values = {
        graphicsShadowQuality = "3",
        graphicsProjectedTextures = "1",
        graphicsParticleDensity = "5",
        graphicsViewDistance = "7",
    }
    local addon = loadEngine({}, function(cvarName)
        return values[cvarName]
    end, function()
        return true
    end)

    local result = addon.CaptureProfile("Quality")
    assertTrue(result.success)
    assertTrue(result.saved)
    assertEqual(countKeys(RenderSetDB.profiles.Quality), 4)
    for cvarName, expected in pairs(values) do
        assertEqual(RenderSetDB.profiles.Quality[cvarName], expected)
    end
end

function tests.capture_allowlist_only()
    local addon = loadEngine({}, function()
        return "1"
    end, function()
        return true
    end)

    addon.CaptureProfile("OnlyAllowed")
    local profile = RenderSetDB.profiles.OnlyAllowed
    assertEqual(countKeys(profile), 4)
    for cvarName in pairs(profile) do
        assertTrue(EXPECTED_CVARS[cvarName], "captured unexpected CVar " .. cvarName)
    end
    assertEqual(profile.someOldCVar, nil)
end

function tests.capture_continues_after_read_failure()
    local addon = loadEngine({}, function(cvarName)
        if cvarName == "graphicsProjectedTextures" then
            error("read failed")
        end
        return "1"
    end, function()
        return true
    end)

    local result = addon.CaptureProfile("Partial")
    assertFalse(result.success)
    assertTrue(result.saved)
    assertEqual(countKeys(RenderSetDB.profiles.Partial), 3)
    assertEqual(RenderSetDB.profiles.Partial.graphicsProjectedTextures, nil)
    assertTrue(type(result.errors.graphicsProjectedTextures) == "string")
end

function tests.apply_success()
    local values = {
        graphicsShadowQuality = "2",
        graphicsProjectedTextures = "1",
        graphicsParticleDensity = "4",
        graphicsViewDistance = "6",
    }
    local current = {}
    local addon, calls = loadEngine({ Quality = values }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("Quality")
    assertTrue(result.success)
    assertEqual(#calls.writes, 4)
    assertEqual(countKeys(result.applied), 4)
    for cvarName, expected in pairs(values) do
        assertEqual(result.applied[cvarName], expected)
    end
end

function tests.apply_ignores_unknown_key()
    local profile = {
        graphicsShadowQuality = "2",
        someOldCVar = "123",
    }
    local current = {}
    local addon, calls = loadEngine({ OldProfile = profile }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    addon.ApplyProfile("OldProfile")
    assertEqual(#calls.writes, 1)
    assertEqual(calls.writes[1][1], "graphicsShadowQuality")
end

function tests.apply_continues_after_write_failure()
    local values = {
        graphicsShadowQuality = "2",
        graphicsProjectedTextures = "1",
        graphicsParticleDensity = "4",
        graphicsViewDistance = "6",
    }
    local current = {}
    local addon, calls = loadEngine({ Mixed = values }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        if cvarName == "graphicsProjectedTextures" then
            return false
        end
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("Mixed")
    assertFalse(result.success)
    assertEqual(#calls.writes, 4)
    assertEqual(countKeys(result.applied), 3)
    assertEqual(result.errors.graphicsProjectedTextures, "write was rejected")
    assertEqual(result.applied.graphicsViewDistance, "6")
end

function tests.apply_reports_readback_mismatch()
    local addon = loadEngine({ Mismatch = { graphicsParticleDensity = "5" } }, function()
        return "4"
    end, function()
        return true
    end)

    local result = addon.ApplyProfile("Mismatch")
    assertFalse(result.success)
    assertEqual(result.applied.graphicsParticleDensity, nil)
    assertEqual(result.errors.graphicsParticleDensity, "readback did not match stored value")
end

function tests.apply_skips_missing_value()
    local current = {}
    local addon, calls = loadEngine({ Partial = { graphicsShadowQuality = "2" } }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("Partial")
    assertTrue(result.success)
    assertEqual(#calls.writes, 1)
    assertEqual(result.skipped.graphicsProjectedTextures, "profile value is missing")
    assertEqual(result.skipped.graphicsParticleDensity, "profile value is missing")
    assertEqual(result.skipped.graphicsViewDistance, "profile value is missing")
end

function tests.apply_rejects_invalid_or_missing_profile()
    local addon, calls = loadEngine({}, function()
        return "1"
    end, function()
        return true
    end)

    local missingResult = addon.ApplyProfile("Missing")
    local invalidResult = addon.ApplyProfile(42)
    local emptyResult = addon.ApplyProfile("")
    assertFalse(missingResult.success)
    assertFalse(invalidResult.success)
    assertFalse(emptyResult.success)
    assertEqual(missingResult.errors.profile, "profile does not exist")
    assertEqual(invalidResult.errors.profile, "profile name must be a non-empty string")
    assertEqual(emptyResult.errors.profile, "profile name must be a non-empty string")
    assertEqual(#calls.writes, 0)
end

function tests.capture_complete_failure_preserves_existing_profile()
    local existing = { graphicsShadowQuality = "3" }
    local addon = loadEngine({ Quality = existing }, function()
        error("read failed")
    end, function()
        return true
    end)

    local result = addon.CaptureProfile("Quality")
    assertFalse(result.success)
    assertFalse(result.saved)
    assertEqual(RenderSetDB.profiles.Quality, existing)
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

print("PASS: " .. passed .. " profile engine tests")
