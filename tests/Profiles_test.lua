local EXPECTED_CVAR_NAMES = {
    "graphicsShadowQuality",
    "graphicsProjectedTextures",
    "graphicsParticleDensity",
    "graphicsLiquidDetail",
    "graphicsSSAO",
    "graphicsDepthEffects",
    "graphicsComputeEffects",
    "graphicsGroundClutter",
    "graphicsEnvironmentDetail",
    "graphicsViewDistance",
    "graphicsTextureResolution",
    "graphicsSpellDensity",
    "ResampleAlwaysSharpen",
    "vsync",
    "RenderScale",
    "ResampleQuality",
    "textureFilteringMode",
    "ffxAntiAliasingMode",
    "graphicsLightMode",
    "graphicsPBRLiquidDetail",
    "graphicsBloomUserMult",
    "maxFPS",
    "useMaxFPS",
    "targetFPS",
    "useTargetFPS",
}

local EXPECTED_CVARS = {}
for _, cvarName in ipairs(EXPECTED_CVAR_NAMES) do
    EXPECTED_CVARS[cvarName] = true
end

local function fullProfileValues()
    return {
        graphicsShadowQuality = "3",
        graphicsProjectedTextures = "1",
        graphicsParticleDensity = "5",
        graphicsLiquidDetail = "2",
        graphicsSSAO = "1",
        graphicsDepthEffects = "2",
        graphicsComputeEffects = "2",
        graphicsGroundClutter = "4",
        graphicsEnvironmentDetail = "6",
        graphicsViewDistance = "6",
        graphicsTextureResolution = "2",
        graphicsSpellDensity = "0",
        ResampleAlwaysSharpen = "1",
        vsync = "1",
        RenderScale = "0.75",
        ResampleQuality = "3",
        textureFilteringMode = "5",
        ffxAntiAliasingMode = "4",
        graphicsLightMode = "0",
        graphicsPBRLiquidDetail = "2",
        graphicsBloomUserMult = "1",
        maxFPS = "60",
        useMaxFPS = "1",
        targetFPS = "45",
        useTargetFPS = "1",
    }
end

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

local function writeIndex(calls, cvarName)
    for index, write in ipairs(calls.writes) do
        if write[1] == cvarName then
            return index
        end
    end
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
    local values = fullProfileValues()
    local addon = loadEngine({}, function(cvarName)
        return values[cvarName]
    end, function()
        return true
    end)

    local result = addon.CaptureProfile("Quality")
    assertTrue(result.success)
    assertTrue(result.saved)
    assertEqual(countKeys(RenderSetDB.profiles.Quality), 25)
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
    assertEqual(countKeys(profile), 25)
    for cvarName in pairs(profile) do
        assertTrue(EXPECTED_CVARS[cvarName], "captured unexpected CVar " .. cvarName)
    end
    assertEqual(profile.graphicsOutlineMode, nil)
    assertEqual(profile.ResampleSharpness, nil)
    assertEqual(profile.DynamicRenderScale, nil)
    assertEqual(profile.maxFPSBk, nil)
    assertEqual(profile.Brightness, nil)
    assertEqual(profile.someOldCVar, nil)
end

function tests.capture_continues_after_read_failure()
    local addon = loadEngine({}, function(cvarName)
        if cvarName == "graphicsTextureResolution" then
            error("read failed")
        end
        return "1"
    end, function()
        return true
    end)

    local result = addon.CaptureProfile("Partial")
    assertFalse(result.success)
    assertTrue(result.saved)
    assertEqual(countKeys(RenderSetDB.profiles.Partial), 24)
    assertEqual(RenderSetDB.profiles.Partial.graphicsTextureResolution, nil)
    assertTrue(type(result.errors.graphicsTextureResolution) == "string")
end

function tests.apply_success()
    local values = fullProfileValues()
    local current = {}
    local addon, calls = loadEngine({ Quality = values }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("Quality")
    assertTrue(result.success)
    assertEqual(#calls.writes, 25)
    assertEqual(countKeys(result.applied), 25)
    assertTrue(writeIndex(calls, "maxFPS") < writeIndex(calls, "useMaxFPS"))
    assertTrue(writeIndex(calls, "targetFPS") < writeIndex(calls, "useTargetFPS"))
    for cvarName, expected in pairs(values) do
        assertEqual(result.applied[cvarName], expected)
    end
end

function tests.apply_allowlist_ignores_unknown_stored_key()
    local profile = fullProfileValues()
    profile.someOldCVar = "123"
    local current = {}
    local addon, calls = loadEngine({ OldProfile = profile }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("OldProfile")
    assertTrue(result.success)
    assertEqual(#calls.writes, 25)
    assertEqual(countKeys(result.applied), 25)
    for _, write in ipairs(calls.writes) do
        assertTrue(EXPECTED_CVARS[write[1]], "applied unexpected CVar " .. write[1])
    end
    assertEqual(current.someOldCVar, nil)
end

function tests.apply_continues_after_write_failure()
    local values = fullProfileValues()
    local current = {}
    local addon, calls = loadEngine({ Mixed = values }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        if cvarName == "graphicsBloomUserMult" then
            return false
        end
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("Mixed")
    assertFalse(result.success)
    assertEqual(#calls.writes, 25)
    assertEqual(countKeys(result.applied), 24)
    assertEqual(result.errors.graphicsBloomUserMult, "write was rejected")
    assertEqual(result.applied.useTargetFPS, "1")
end

function tests.apply_reports_readback_mismatch()
    local addon = loadEngine({ Mismatch = { textureFilteringMode = "5" } }, function()
        return "0"
    end, function()
        return true
    end)

    local result = addon.ApplyProfile("Mismatch")
    assertFalse(result.success)
    assertEqual(result.applied.textureFilteringMode, nil)
    assertEqual(result.errors.textureFilteringMode, "readback did not match stored value")
end

function tests.apply_continues_after_single_readback_failure()
    local values = fullProfileValues()
    local current = {}
    local addon, calls = loadEngine({ MixedReadback = values }, function(cvarName)
        if cvarName == "graphicsEnvironmentDetail" then
            error("readback failed")
        end
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("MixedReadback")
    assertFalse(result.success)
    assertEqual(#calls.writes, 25)
    assertEqual(countKeys(result.applied), 24)
    assertTrue(type(result.errors.graphicsEnvironmentDetail) == "string")
    assertEqual(result.applied.useTargetFPS, "1")
end

function tests.apply_old_four_cvar_profile_skips_new_values_without_mutation()
    local profile = {
        graphicsShadowQuality = "2",
        graphicsProjectedTextures = "1",
        graphicsParticleDensity = "4",
        graphicsViewDistance = "6",
    }
    local current = {}
    local addon, calls = loadEngine({ Legacy = profile }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("Legacy")
    assertTrue(result.success)
    assertEqual(#calls.writes, 4)
    assertEqual(countKeys(result.applied), 4)
    assertEqual(countKeys(result.skipped), 21)
    assertEqual(next(result.errors), nil)
    assertEqual(result.skipped.graphicsLiquidDetail, "profile value is missing")
    assertEqual(result.skipped.graphicsSSAO, "profile value is missing")
    assertEqual(result.skipped.graphicsDepthEffects, "profile value is missing")
    assertEqual(result.skipped.graphicsComputeEffects, "profile value is missing")
    assertEqual(result.skipped.graphicsGroundClutter, "profile value is missing")
    assertEqual(result.skipped.graphicsEnvironmentDetail, "profile value is missing")
    assertEqual(RenderSetDB.profiles.Legacy, profile)
    assertEqual(countKeys(profile), 4)
end

function tests.apply_old_eleven_cvar_profile_ignores_outline_without_mutation()
    local profile = {
        graphicsShadowQuality = "3",
        graphicsProjectedTextures = "1",
        graphicsParticleDensity = "4",
        graphicsLiquidDetail = "2",
        graphicsSSAO = "1",
        graphicsDepthEffects = "2",
        graphicsComputeEffects = "2",
        graphicsOutlineMode = "1",
        graphicsGroundClutter = "4",
        graphicsEnvironmentDetail = "6",
        graphicsViewDistance = "6",
    }
    local current = { graphicsOutlineMode = "0" }
    local addon, calls = loadEngine({ Legacy = profile }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("Legacy")
    assertTrue(result.success)
    assertEqual(#calls.writes, 10)
    assertEqual(countKeys(result.applied), 10)
    assertEqual(countKeys(result.skipped), 15)
    assertEqual(current.graphicsOutlineMode, "0")
    assertEqual(result.applied.graphicsOutlineMode, nil)
    assertEqual(result.skipped.graphicsOutlineMode, nil)
    assertEqual(RenderSetDB.profiles.Legacy, profile)
    assertEqual(countKeys(profile), 11)
    assertEqual(profile.graphicsOutlineMode, "1")
end

function tests.apply_ignores_stored_outline_in_otherwise_empty_profile()
    local profile = { graphicsOutlineMode = "1" }
    local addon, calls = loadEngine({ Historical = profile }, function()
        return "0"
    end, function()
        return true
    end)

    local result = addon.ApplyProfile("Historical")
    assertTrue(result.success)
    assertEqual(#calls.writes, 0)
    assertEqual(result.errors.graphicsOutlineMode, nil)
    assertEqual(RenderSetDB.profiles.Historical, profile)
    assertEqual(profile.graphicsOutlineMode, "1")
end

function tests.pair_value_failure_skips_gate_and_continues_unrelated_settings()
    local cases = {
        { value = "maxFPS", gate = "useMaxFPS" },
        { value = "targetFPS", gate = "useTargetFPS" },
    }

    for _, pair in ipairs(cases) do
        local profile = {
            graphicsShadowQuality = "2",
            [pair.value] = "60",
            [pair.gate] = "1",
        }
        local current = {}
        local addon, calls = loadEngine({ Pair = profile }, function(cvarName)
            return current[cvarName]
        end, function(cvarName, value)
            if cvarName == pair.value then
                return false
            end
            current[cvarName] = value
            return true
        end)

        local result = addon.ApplyProfile("Pair")
        assertFalse(result.success)
        assertEqual(result.errors[pair.value], "write was rejected")
        assertEqual(result.skipped[pair.gate], "paired value was not applied")
        assertEqual(writeIndex(calls, pair.gate), nil)
        assertEqual(result.applied.graphicsShadowQuality, "2")
    end
end

function tests.pair_gate_failure_is_reported_and_unrelated_settings_continue()
    local cases = {
        { value = "maxFPS", gate = "useMaxFPS" },
        { value = "targetFPS", gate = "useTargetFPS" },
    }

    for _, pair in ipairs(cases) do
        local profile = {
            graphicsShadowQuality = "2",
            [pair.value] = "60",
            [pair.gate] = "1",
        }
        local current = {}
        local addon, calls = loadEngine({ Pair = profile }, function(cvarName)
            return current[cvarName]
        end, function(cvarName, value)
            if cvarName == pair.gate then
                return false
            end
            current[cvarName] = value
            return true
        end)

        local result = addon.ApplyProfile("Pair")
        assertFalse(result.success)
        assertEqual(result.applied[pair.value], "60")
        assertEqual(result.errors[pair.gate], "write was rejected")
        assertTrue(writeIndex(calls, pair.value) < writeIndex(calls, pair.gate))
        assertEqual(result.applied.graphicsShadowQuality, "2")
    end
end

function tests.partial_pairs_apply_values_without_inventing_missing_gates()
    local profile = { maxFPS = "60", targetFPS = "45" }
    local current = {}
    local addon, calls = loadEngine({ Partial = profile }, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyProfile("Partial")
    assertTrue(result.success)
    assertEqual(#calls.writes, 2)
    assertEqual(result.applied.maxFPS, "60")
    assertEqual(result.applied.targetFPS, "45")
    assertEqual(result.skipped.useMaxFPS, "profile value is missing")
    assertEqual(result.skipped.useTargetFPS, "profile value is missing")
end

function tests.partial_pairs_skip_gates_when_numeric_values_are_missing()
    local profile = { useMaxFPS = "1", useTargetFPS = "1" }
    local addon, calls = loadEngine({ Partial = profile }, function()
        return "0"
    end, function()
        return true
    end)

    local result = addon.ApplyProfile("Partial")
    assertTrue(result.success)
    assertEqual(#calls.writes, 0)
    assertEqual(result.skipped.useMaxFPS, "paired value is missing")
    assertEqual(result.skipped.useTargetFPS, "paired value is missing")
end

function tests.capture_and_apply_leave_schema_and_database_shape_unchanged()
    local values = fullProfileValues()
    local current = {}
    local addon = loadEngine({}, function(cvarName)
        return current[cvarName] or values[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    addon.CaptureProfile("Quality")
    addon.ApplyProfile("Quality")
    assertEqual(RenderSetDB.schemaVersion, 1)
    assertEqual(RenderSetDB.selectedProfile, nil)
    assertEqual(RenderSetDB.activeProfile, nil)
    assertEqual(countKeys(RenderSetDB.profiles.Quality), 25)
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

function tests.capture_duplicate_rejects_without_reads_or_overwrite()
    local existing = {
        graphicsShadowQuality = "3",
        graphicsProjectedTextures = "1",
    }
    local addon, calls = loadEngine({ Quality = existing }, function()
        error("duplicate capture should not read CVars")
    end, function()
        return true
    end)

    local result = addon.CaptureProfile("Quality")
    assertFalse(result.success)
    assertFalse(result.saved)
    assertEqual(result.errors.profile, "profile already exists")
    assertEqual(#calls.reads, 0)
    assertEqual(RenderSetDB.profiles.Quality, existing)
    assertEqual(RenderSetDB.profiles.Quality.graphicsShadowQuality, "3")
    assertEqual(RenderSetDB.profiles.Quality.graphicsProjectedTextures, "1")
end

function tests.capture_invalid_names_do_not_read_or_create_profiles()
    local addon, calls = loadEngine({}, function()
        error("invalid capture should not read CVars")
    end, function()
        return true
    end)

    local emptyResult = addon.CaptureProfile("")
    local whitespaceResult = addon.CaptureProfile("   ")
    local nonStringResult = addon.CaptureProfile(42)

    assertFalse(emptyResult.success)
    assertFalse(whitespaceResult.success)
    assertFalse(nonStringResult.success)
    assertEqual(#calls.reads, 0)
    assertEqual(next(RenderSetDB.profiles), nil)
end

function tests.profile_name_validation_accepts_names_and_rejects_invalid_values()
    local addon = loadEngine({}, function()
        return "1"
    end, function()
        return true
    end)

    local validName, validMessage = addon.ValidateProfileName("My Profile")
    local emptyName, emptyMessage = addon.ValidateProfileName("")
    local whitespaceName, whitespaceMessage = addon.ValidateProfileName(" \t ")
    local numberName, numberMessage = addon.ValidateProfileName(42)

    assertTrue(validName)
    assertEqual(validMessage, nil)
    assertFalse(emptyName)
    assertEqual(emptyMessage, "Enter a profile name.")
    assertFalse(whitespaceName)
    assertEqual(whitespaceMessage, "Profile name cannot be only whitespace.")
    assertFalse(numberName)
    assertEqual(numberMessage, "Enter a profile name.")
end

function tests.rename_preserves_profile_data_and_removes_old_key()
    local profile = { graphicsShadowQuality = "3", custom = "preserved" }
    local addon = loadEngine({ Quality = profile }, function()
        return "1"
    end, function()
        return true
    end)

    local result = addon.RenameProfile("Quality", "My Profile")
    assertTrue(result.success)
    assertTrue(result.renamed)
    assertEqual(RenderSetDB.profiles["My Profile"], profile)
    assertEqual(RenderSetDB.profiles.Quality, nil)
end

function tests.rename_duplicate_preserves_both_profiles()
    local source = { graphicsShadowQuality = "3" }
    local destination = { graphicsShadowQuality = "1" }
    local addon = loadEngine({ Quality = source, Performance = destination }, function()
        return "1"
    end, function()
        return true
    end)

    local result = addon.RenameProfile("Quality", "Performance")
    assertFalse(result.success)
    assertEqual(result.errors.profile, "destination profile already exists")
    assertEqual(RenderSetDB.profiles.Quality, source)
    assertEqual(RenderSetDB.profiles.Performance, destination)
end

function tests.rename_missing_source_fails_safely()
    local addon = loadEngine({}, function()
        return "1"
    end, function()
        return true
    end)

    local result = addon.RenameProfile("Missing", "New")
    assertFalse(result.success)
    assertEqual(result.errors.profile, "profile does not exist")
end

function tests.rename_same_name_is_harmless_noop()
    local profile = { graphicsShadowQuality = "3" }
    local addon = loadEngine({ Quality = profile }, function()
        return "1"
    end, function()
        return true
    end)

    local result = addon.RenameProfile("Quality", "Quality")
    assertTrue(result.success)
    assertTrue(result.unchanged)
    assertEqual(RenderSetDB.profiles.Quality, profile)
end

function tests.delete_removes_only_requested_profile()
    local remaining = { graphicsShadowQuality = "1" }
    local addon = loadEngine({ Quality = { graphicsShadowQuality = "3" }, Performance = remaining }, function()
        return "1"
    end, function()
        return true
    end)

    local result = addon.DeleteProfile("Quality")
    assertTrue(result.success)
    assertTrue(result.deleted)
    assertEqual(RenderSetDB.profiles.Quality, nil)
    assertEqual(RenderSetDB.profiles.Performance, remaining)
end

function tests.delete_missing_profile_fails_safely()
    local addon = loadEngine({}, function()
        return "1"
    end, function()
        return true
    end)

    local result = addon.DeleteProfile("Missing")
    assertFalse(result.success)
    assertEqual(result.errors.profile, "profile does not exist")
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
