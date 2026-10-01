RenderSetDB = {
    schemaVersion = 1,
    profiles = {},
}

RenderSetTest = {
    CaptureProfile = function() end,
    ApplyProfile = function() end,
}

local captureCalls = {}
local applyCalls = {}
local captureResult = {
    success = true,
    saved = true,
    captured = { a = "1" },
    applied = {},
    skipped = {},
    errors = {},
}
local applyResult = {
    success = true,
    saved = false,
    captured = {},
    applied = { a = "1", b = "2", c = "3", d = "4" },
    skipped = {},
    errors = {},
}

local addon = {
    CaptureProfile = function(name)
        captureCalls[#captureCalls + 1] = name
        RenderSetDB.profiles[name] = { graphicsShadowQuality = "2" }
        return captureResult
    end,
    ApplyProfile = function(name)
        applyCalls[#applyCalls + 1] = name
        return applyResult
    end,
}

local chunk = assert(loadfile("UI.lua"))
chunk("RenderSet", addon)

local function fail(message)
    error(message, 2)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertContains(value, expected, message)
    if not string.find(value, expected, 1, true) then
        fail((message or "text not found") .. ": expected " .. expected .. " in " .. value)
    end
end

local tests = {}

function tests.profile_names_are_sorted()
    RenderSetDB.profiles = {
        Zebra = {},
        Alpha = {},
        Middle = {},
    }

    local names = addon.UI.GetSortedProfileNames()
    assertEqual(#names, 3)
    assertEqual(names[1], "Alpha")
    assertEqual(names[2], "Middle")
    assertEqual(names[3], "Zebra")
end

function tests.duplicate_name_does_not_capture()
    RenderSetDB.profiles = { Existing = {} }
    captureCalls = {}

    local result, message, saved = addon.UI.SaveCurrent("Existing")
    assertEqual(result, nil)
    assertEqual(saved, false)
    assertEqual(#captureCalls, 0)
    assertEqual(message, "A profile with that name already exists.")
end

function tests.new_profile_delegates_to_capture()
    RenderSetDB.profiles = {}
    captureCalls = {}

    local result, message, saved = addon.UI.SaveCurrent("New Profile")
    assertEqual(result, captureResult)
    assertEqual(saved, true)
    assertEqual(#captureCalls, 1)
    assertEqual(captureCalls[1], "New Profile")
    assertEqual(message, "Profile saved.")
end

function tests.apply_delegates_to_engine()
    applyCalls = {}

    local result, message = addon.UI.ApplySelection("Quality")
    assertEqual(result, applyResult)
    assertEqual(#applyCalls, 1)
    assertEqual(applyCalls[1], "Quality")
    assertEqual(message, "Applied Quality — 4 settings.")
end

function tests.apply_without_selection_does_not_call_engine()
    applyCalls = {}

    local result, message = addon.UI.ApplySelection(nil)
    assertEqual(result, nil)
    assertEqual(#applyCalls, 0)
    assertEqual(message, "Select a profile first.")
end

function tests.result_summaries_cover_success_skips_and_errors()
    local full = addon.UI.SummarizeApply("A", {
        applied = { a = "1", b = "2", c = "3", d = "4" },
        skipped = {},
        errors = {},
    })
    local skipped = addon.UI.SummarizeApply("A", {
        applied = { a = "1", b = "2", c = "3" },
        skipped = { d = "missing" },
        errors = {},
    })
    local failed = addon.UI.SummarizeApply("A", {
        applied = { a = "1", b = "2", c = "3" },
        skipped = {},
        errors = { d = "failed" },
    })

    assertEqual(full, "Applied A — 4 settings.")
    assertContains(skipped, "3 applied, 1 skipped")
    assertContains(failed, "1 error")
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

print("PASS: " .. passed .. " UI logic tests")
