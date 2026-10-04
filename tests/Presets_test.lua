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

local DISPLAY_DEVICE_CVARS = {
    GxMaximize = true,
    GxWindowedResolution = true,
    GxNewResolution = true,
    GxMonitor = true,
    GxApi = true,
    GxAdapter = true,
}

local EXPECTED_COMMON_VALUES = {
    graphicsShadowQuality = "1",
    graphicsProjectedTextures = "1",
    graphicsParticleDensity = "4",
    graphicsLiquidDetail = "2",
    graphicsSSAO = "1",
    graphicsDepthEffects = "2",
    graphicsComputeEffects = "2",
    graphicsGroundClutter = "4",
    graphicsEnvironmentDetail = "6",
    graphicsViewDistance = "6",
    graphicsTextureResolution = "2",
    graphicsSpellDensity = "0",
    vsync = "0",
    ResampleQuality = "3",
    textureFilteringMode = "5",
    ffxAntiAliasingMode = "4",
    graphicsLightMode = "0",
    graphicsPBRLiquidDetail = "2",
    graphicsBloomUserMult = "1",
    useMaxFPS = "1",
    targetFPS = "60",
    useTargetFPS = "0",
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

local function copyValues(values)
    local copy = {}
    for key, value in pairs(values) do
        copy[key] = value
    end
    return copy
end

local function writeIndex(calls, cvarName)
    for index, write in ipairs(calls.writes) do
        if write[1] == cvarName then
            return index
        end
    end
end

local function loadPresets(profiles, getCVar, setCVar)
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
    assert(loadfile("Profiles.lua"))("RenderSet", addon)
    assert(loadfile("Presets.lua"))("RenderSet", addon)
    return addon, calls
end

local tests = {}

function tests.definitions_are_exact_ordered_and_allowlisted()
    local addon = loadPresets({}, function() return "0" end, function() return true end)
    local presets = addon.BuiltinPresets

    assertEqual(#presets, 2)
    assertEqual(presets[1].id, "macbook_internal_balanced")
    assertEqual(presets[1].name, "MacBook Pro Internal — Balanced")
    assertEqual(presets[1].shortName, "MacBook Pro — Balanced")
    assertEqual(presets[2].id, "external_1440p_balanced")
    assertEqual(presets[2].name, "1440p External — Balanced")
    assertEqual(presets[2].shortName, "1440p External — Balanced")

    for _, preset in ipairs(presets) do
        assertEqual(countKeys(preset.values), 25)
        for cvarName, value in pairs(preset.values) do
            assertTrue(EXPECTED_CVARS[cvarName], "unexpected preset CVar " .. cvarName)
            assertTrue(addon.ProfileEngine.IsSupportedCVar(cvarName))
            assertEqual(type(value), "string")
            assertFalse(DISPLAY_DEVICE_CVARS[cvarName] == true)
        end
        assertEqual(preset.values.graphicsOutlineMode, nil)
    end
end

function tests.all_raw_values_are_exact()
    local addon = loadPresets({}, function() return "0" end, function() return true end)
    local mac = addon.GetBuiltInPreset("macbook_internal_balanced").values
    local external = addon.GetBuiltInPreset("external_1440p_balanced").values

    for cvarName, expected in pairs(EXPECTED_COMMON_VALUES) do
        assertEqual(mac[cvarName], expected, "Mac value mismatch for " .. cvarName)
        assertEqual(external[cvarName], expected, "external value mismatch for " .. cvarName)
    end

    assertEqual(mac.RenderScale, "0.75")
    assertEqual(mac.maxFPS, "60")
    assertEqual(mac.ResampleAlwaysSharpen, "1")
    assertEqual(mac.useTargetFPS, "0")
    assertEqual(external.RenderScale, "1.0")
    assertEqual(external.maxFPS, "75")
    assertEqual(external.ResampleAlwaysSharpen, "0")
    assertEqual(external.useTargetFPS, "0")
end

function tests.apply_uses_shared_engine_and_writes_all_values_in_pair_order()
    local current = {}
    local addon, calls = loadPresets({}, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)
    local sharedApply = addon.ProfileEngine.ApplyValues
    local sharedCalls = 0
    addon.ProfileEngine.ApplyValues = function(values)
        sharedCalls = sharedCalls + 1
        return sharedApply(values)
    end

    local result = addon.ApplyBuiltInPreset("macbook_internal_balanced")
    assertTrue(result.success)
    assertEqual(sharedCalls, 1)
    assertEqual(#calls.writes, 25)
    assertEqual(countKeys(result.applied), 25)
    assertTrue(writeIndex(calls, "maxFPS") < writeIndex(calls, "useMaxFPS"))
    assertTrue(writeIndex(calls, "targetFPS") < writeIndex(calls, "useTargetFPS"))
end

function tests.write_failure_is_isolated_and_gate_dependency_is_preserved()
    local current = {}
    local addon = loadPresets({}, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        if cvarName == "maxFPS" then
            return false
        end
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyBuiltInPreset("external_1440p_balanced")
    assertFalse(result.success)
    assertEqual(result.errors.maxFPS, "write was rejected")
    assertEqual(result.skipped.useMaxFPS, "paired value was not applied")
    assertEqual(result.applied.RenderScale, "1.0")
    assertEqual(result.applied.useTargetFPS, "0")
end

function tests.readback_mismatch_is_reported_and_other_values_continue()
    local current = {}
    local addon = loadPresets({}, function(cvarName)
        if cvarName == "graphicsSSAO" then
            return "9"
        end
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)

    local result = addon.ApplyBuiltInPreset("macbook_internal_balanced")
    assertFalse(result.success)
    assertEqual(result.errors.graphicsSSAO, "readback did not match stored value")
    assertEqual(result.applied.graphicsDepthEffects, "2")
end

function tests.apply_does_not_mutate_definition_or_saved_variables()
    local current = {}
    local existingProfiles = { Quality = { graphicsShadowQuality = "3" } }
    local addon = loadPresets(existingProfiles, function(cvarName)
        return current[cvarName]
    end, function(cvarName, value)
        current[cvarName] = value
        return true
    end)
    local preset = addon.GetBuiltInPreset("macbook_internal_balanced")
    local before = copyValues(preset.values)

    addon.ApplyBuiltInPreset(preset.id)

    assertEqual(RenderSetDB.schemaVersion, 1)
    assertEqual(RenderSetDB.profiles, existingProfiles)
    assertEqual(RenderSetDB.profiles[preset.id], nil)
    assertEqual(RenderSetDB.builtinPresets, nil)
    assertEqual(RenderSetDB.selectedPreset, nil)
    for cvarName, value in pairs(before) do
        assertEqual(preset.values[cvarName], value)
    end
    assertEqual(countKeys(preset.values), 25)
end

function tests.reload_loads_code_definitions_without_seeding_profiles()
    local existingProfiles = { Custom = { RenderScale = "0.9" } }
    local addon = loadPresets(existingProfiles, function() return "0" end, function() return true end)
    assertEqual(#addon.BuiltinPresets, 2)
    assertEqual(RenderSetDB.profiles, existingProfiles)

    local reloadedAddon = {}
    assert(loadfile("Profiles.lua"))("RenderSet", reloadedAddon)
    assert(loadfile("Presets.lua"))("RenderSet", reloadedAddon)
    assertEqual(#reloadedAddon.BuiltinPresets, 2)
    assertEqual(RenderSetDB.profiles, existingProfiles)
    assertEqual(countKeys(RenderSetDB.profiles), 1)
end

function tests.unknown_preset_fails_without_writes()
    local addon, calls = loadPresets({}, function() return "0" end, function() return true end)
    local result = addon.ApplyBuiltInPreset("missing")
    assertFalse(result.success)
    assertEqual(result.errors.preset, "built-in preset does not exist")
    assertEqual(#calls.writes, 0)
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

print("PASS: " .. passed .. " built-in preset tests")
