RenderSetDB = {
    schemaVersion = 1,
    profiles = { Quality = {}, ["Raid Performance"] = {}, Alpha = {} },
}

DEFAULT_CHAT_FRAME = {
    messages = {},
    AddMessage = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
}

SlashCmdList = {}
local toggleCalls = 0
local captureCalls = {}
local applyCalls = {}

local addon = {
    ValidateProfileName = function(name)
        return type(name) == "string" and name ~= "", "invalid name"
    end,
    CaptureProfile = function(name)
        captureCalls[#captureCalls + 1] = name
        return { saved = true, errors = {}, captured = {} }
    end,
    ApplyProfile = function(name)
        applyCalls[#applyCalls + 1] = name
        return { errors = {}, applied = { a = "1" }, skipped = {} }
    end,
    UI = {
        Toggle = function() toggleCalls = toggleCalls + 1 end,
        GetSortedProfileNames = function() return { "Alpha", "Quality", "Raid Performance" } end,
        SummarizeCapture = function() return "Profile saved." end,
        SummarizeApply = function(name) return "Applied " .. name .. " — 1 settings." end,
    },
}

local chunk = assert(loadfile("Commands.lua"))
chunk("RenderSet", addon)

local function fail(message)
    error(message, 2)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertContains(message, expected)
    if not string.find(message, expected, 1, true) then
        fail("expected " .. expected .. " in " .. message)
    end
end

local tests = {}

function tests.empty_input_toggles_ui()
    addon.Commands.Dispatch("")
    assertEqual(toggleCalls, 1)
end

function tests.commands_are_case_insensitive()
    DEFAULT_CHAT_FRAME.messages = {}
    addon.Commands.Dispatch("HeLp")
    assertContains(DEFAULT_CHAT_FRAME.messages[1], "commands:")
end

function tests.save_preserves_multi_word_name_and_delegates()
    addon.Commands.Dispatch("save Raid Performance")
    assertEqual(captureCalls[1], "Raid Performance")
end

function tests.apply_preserves_multi_word_name_and_delegates()
    addon.Commands.Dispatch("APPLY Raid Performance")
    assertEqual(applyCalls[1], "Raid Performance")
end

function tests.list_is_sorted()
    DEFAULT_CHAT_FRAME.messages = {}
    addon.Commands.Dispatch("list")
    assertEqual(DEFAULT_CHAT_FRAME.messages[2], "RenderSet: - Alpha")
    assertEqual(DEFAULT_CHAT_FRAME.messages[4], "RenderSet: - Raid Performance")
end

function tests.missing_name_does_not_call_engine()
    local captureCount = #captureCalls
    local applyCount = #applyCalls
    addon.Commands.Dispatch("save")
    addon.Commands.Dispatch("apply")
    assertEqual(#captureCalls, captureCount)
    assertEqual(#applyCalls, applyCount)
end

function tests.unknown_command_guides_to_help()
    DEFAULT_CHAT_FRAME.messages = {}
    addon.Commands.Dispatch("banana")
    assertEqual(DEFAULT_CHAT_FRAME.messages[1], "RenderSet: Unknown command. Use /rset help.")
end

function tests.aliases_register_same_dispatcher()
    assertEqual(SLASH_RENDERSET1, "/renderset")
    assertEqual(SLASH_RENDERSET2, "/rset")
    assertEqual(SlashCmdList.RENDERSET, addon.Commands.Dispatch)
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

print("PASS: " .. passed .. " command tests")
