local _, addon = ...

local Commands = {}
addon.Commands = Commands

local function printMessage(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("RenderSet: " .. message)
    end
end

local function trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

function Commands.Parse(message)
    local text = trim(message)
    local keyword, argument = text:match("^(%S+)%s*(.-)%s*$")

    if not keyword then
        return "", ""
    end

    return keyword:lower(), argument or ""
end

function Commands.Help()
    printMessage("commands:")
    printMessage("  /rset — Open/close RenderSet")
    printMessage("  /rset list — List profiles")
    printMessage("  /rset save <name> — Save current graphics settings")
    printMessage("  /rset apply <name> — Apply a saved profile")
    printMessage("  /rset help — Show this help")
end

local function handleSave(name)
    if name == "" then
        printMessage("Usage: /rset save <profile name>")
        return
    end

    local valid, validationMessage = addon.ValidateProfileName(name)
    if not valid then
        printMessage(validationMessage)
        return
    end

    local result = addon.CaptureProfile(name)
    if result.errors and result.errors.profile == "profile already exists" then
        printMessage("A profile with that name already exists.")
    elseif result.saved then
        printMessage(addon.UI.SummarizeCapture(result))
    else
        printMessage("Could not save " .. name .. ".")
    end
end

local function handleApply(name)
    if name == "" then
        printMessage("Usage: /rset apply <profile name>")
        return
    end

    local valid, validationMessage = addon.ValidateProfileName(name)
    if not valid then
        printMessage(validationMessage)
        return
    end

    local result = addon.ApplyProfile(name)
    if result.errors and result.errors.profile == "profile does not exist" then
        printMessage("Profile not found: " .. name .. ".")
    else
        printMessage(addon.UI.SummarizeApply(name, result))
    end
end

function Commands.List()
    local names = addon.UI.GetSortedProfileNames()
    if #names == 0 then
        printMessage("No profiles saved.")
        return
    end

    printMessage("profiles:")
    for _, name in ipairs(names) do
        printMessage("- " .. name)
    end
end

function Commands.Dispatch(message)
    local command, argument = Commands.Parse(message)

    if command == "" then
        addon.UI.Toggle()
    elseif command == "help" then
        Commands.Help()
    elseif command == "list" then
        Commands.List()
    elseif command == "save" then
        handleSave(argument)
    elseif command == "apply" then
        handleApply(argument)
    else
        printMessage("Unknown command. Use /rset help.")
    end
end

SLASH_RENDERSET1 = "/renderset"
SLASH_RENDERSET2 = "/rset"
SlashCmdList.RENDERSET = Commands.Dispatch
