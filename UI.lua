local _, addon = ...

local UI = {}
addon.UI = UI

local frame
local selectedProfile
local pendingDeleteProfile
local profileButtons = {}
local deleteButton

local function cancelDeleteConfirmation()
    pendingDeleteProfile = nil
    if deleteButton then
        deleteButton:SetText("Delete Selected")
    end
end

local function countEntries(entries)
    local count = 0
    for _ in pairs(entries or {}) do
        count = count + 1
    end
    return count
end

function UI.GetSortedProfileNames()
    local names = {}
    local profiles = type(RenderSetDB) == "table" and RenderSetDB.profiles or nil

    if type(profiles) == "table" then
        for name, profile in pairs(profiles) do
            if type(name) == "string" and type(profile) == "table" then
                names[#names + 1] = name
            end
        end
    end

    table.sort(names)
    return names
end

function UI.SummarizeCapture(result)
    if not result or not result.saved then
        return "Could not save profile."
    end

    local warningCount = countEntries(result.errors)
    if warningCount == 1 then
        return "Profile saved with 1 warning."
    elseif warningCount > 1 then
        return "Profile saved with " .. warningCount .. " warnings."
    end

    return "Profile saved."
end

function UI.SummarizeApply(profileName, result)
    local appliedCount = countEntries(result and result.applied)
    local skippedCount = countEntries(result and result.skipped)
    local errorCount = countEntries(result and result.errors)

    if errorCount > 0 then
        local suffix = errorCount == 1 and " error." or " errors."
        return "Could not fully apply " .. profileName .. " — " .. errorCount .. suffix
    elseif skippedCount > 0 then
        return "Applied " .. profileName .. " — " .. appliedCount .. " applied, " .. skippedCount .. " skipped."
    end

    return "Applied " .. profileName .. " — " .. appliedCount .. " settings."
end

function UI.SummarizeRename(result)
    if result and result.unchanged then
        return "Profile name unchanged."
    elseif result and result.renamed then
        return "Profile renamed."
    elseif result and result.errors and result.errors.profile == "destination profile already exists" then
        return "A profile with that name already exists."
    end

    return "Could not rename profile."
end

function UI.SummarizeDelete(result)
    if result and result.deleted then
        return "Profile deleted."
    end

    return "Could not delete profile."
end

function UI.SaveCurrent(name)
    local valid, validationMessage = addon.ValidateProfileName(name)
    if not valid then
        return nil, validationMessage, false
    end

    local profiles = type(RenderSetDB) == "table" and RenderSetDB.profiles or nil
    if type(profiles) == "table" and profiles[name] ~= nil then
        return nil, "A profile with that name already exists.", false
    end

    local result = addon.CaptureProfile(name)
    return result, UI.SummarizeCapture(result), result.saved == true
end

function UI.RenameSelection(profileName, newName)
    if type(profileName) ~= "string" or profileName == "" then
        return nil, "Select a profile first.", false
    end

    local valid, validationMessage = addon.ValidateProfileName(newName)
    if not valid then
        return nil, validationMessage, false
    end

    local result = addon.RenameProfile(profileName, newName)
    if result.success then
        selectedProfile = newName
        cancelDeleteConfirmation()
        UI.RefreshProfileList()
    end

    return result, UI.SummarizeRename(result), result.renamed or result.unchanged
end

function UI.DeleteSelection(profileName)
    if type(profileName) ~= "string" or profileName == "" then
        return nil, "Select a profile first.", false
    end

    local result = addon.DeleteProfile(profileName)
    if result.success then
        selectedProfile = nil
        cancelDeleteConfirmation()
        UI.RefreshProfileList()
    end

    return result, UI.SummarizeDelete(result), result.deleted == true
end

function UI.RequestDeleteSelection(profileName)
    if type(profileName) ~= "string" or profileName == "" then
        return nil, "Select a profile first.", false
    end

    if pendingDeleteProfile ~= profileName then
        pendingDeleteProfile = profileName
        if deleteButton then
            deleteButton:SetText("Confirm Delete")
        end
        return nil, "Click Confirm Delete to remove " .. profileName .. ".", false
    end

    return UI.DeleteSelection(profileName)
end

function UI.ApplySelection(profileName)
    if type(profileName) ~= "string" or profileName == "" then
        return nil, "Select a profile first."
    end

    local result = addon.ApplyProfile(profileName)
    return result, UI.SummarizeApply(profileName, result)
end

local function setStatus(message)
    if frame then
        frame.statusText:SetText("Status: " .. message)
    end
end

local function updateSelection()
    if not frame then
        return
    end

    frame.selectedText:SetText("Selected: " .. (selectedProfile or "None"))

    for _, button in ipairs(profileButtons) do
        if button.profileName == selectedProfile then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

function UI.SelectProfile(profileName)
    selectedProfile = profileName
    cancelDeleteConfirmation()
    updateSelection()
end

function UI.GetSelectedProfile()
    return selectedProfile
end

function UI.RefreshProfileList()
    local names = UI.GetSortedProfileNames()
    local profiles = type(RenderSetDB) == "table" and RenderSetDB.profiles or nil

    if selectedProfile and (type(profiles) ~= "table" or type(profiles[selectedProfile]) ~= "table") then
        selectedProfile = nil
        cancelDeleteConfirmation()
    end
    if not selectedProfile and #names > 0 then
        selectedProfile = names[1]
    end

    if not frame then
        return
    end

    for index, profileName in ipairs(names) do
        local button = profileButtons[index]
        if not button then
            button = CreateFrame("Button", nil, frame.profileContent, "UIPanelButtonTemplate")
            button:SetSize(300, 24)
            button:SetScript("OnClick", function(self)
                UI.SelectProfile(self.profileName)
            end)
            profileButtons[index] = button
        end

        button.profileName = profileName
        button:SetText(profileName)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, -((index - 1) * 27))
        button:Show()
    end

    for index = #names + 1, #profileButtons do
        profileButtons[index]:Hide()
        profileButtons[index].profileName = nil
    end

    frame.profileContent:SetHeight(math.max(1, #names * 27))
    updateSelection()
end

local function addBorder(target)
    local top = target:CreateTexture(nil, "BORDER")
    top:SetColorTexture(0.35, 0.35, 0.35, 1)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)

    local bottom = target:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(0.35, 0.35, 0.35, 1)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    local left = target:CreateTexture(nil, "BORDER")
    left:SetColorTexture(0.35, 0.35, 0.35, 1)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = target:CreateTexture(nil, "BORDER")
    right:SetColorTexture(0.35, 0.35, 0.35, 1)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
end

local function createFrame()
    frame = CreateFrame("Frame", "RenderSetFrame", UIParent)
    frame:SetSize(420, 440)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", UI.RefreshProfileList)
    frame:SetScript("OnHide", cancelDeleteConfirmation)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.06, 0.06, 0.96)
    addBorder(frame)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("RenderSet")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    local profilesLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profilesLabel:SetPoint("TOPLEFT", 24, -50)
    profilesLabel:SetText("Profiles")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 24, -70)
    scrollFrame:SetPoint("TOPRIGHT", -48, -70)
    scrollFrame:SetHeight(130)

    local profileContent = CreateFrame("Frame", nil, scrollFrame)
    profileContent:SetWidth(300)
    profileContent:SetHeight(1)
    scrollFrame:SetScrollChild(profileContent)
    frame.profileContent = profileContent

    local selectedText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    selectedText:SetPoint("TOPLEFT", 24, -210)
    selectedText:SetText("Selected: None")
    frame.selectedText = selectedText

    local newProfileLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    newProfileLabel:SetPoint("TOPLEFT", 24, -240)
    newProfileLabel:SetText("New profile")

    local nameInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameInput:SetSize(210, 30)
    nameInput:SetPoint("TOPLEFT", 30, -258)
    nameInput:SetAutoFocus(false)
    nameInput:SetScript("OnEscapePressed", nameInput.ClearFocus)
    frame.nameInput = nameInput

    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetSize(120, 24)
    saveButton:SetPoint("LEFT", nameInput, "RIGHT", 10, 0)
    saveButton:SetText("Save Current")
    saveButton:SetScript("OnClick", function()
        local name = nameInput:GetText()
        local _, message, saved = UI.SaveCurrent(name)
        setStatus(message)

        if saved then
            selectedProfile = name
            nameInput:SetText("")
            UI.RefreshProfileList()
        end
    end)

    nameInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        saveButton:Click()
    end)

    local renameLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    renameLabel:SetPoint("TOPLEFT", 24, -298)
    renameLabel:SetText("Rename selected")

    local renameInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    renameInput:SetSize(210, 30)
    renameInput:SetPoint("TOPLEFT", 30, -316)
    renameInput:SetAutoFocus(false)
    renameInput:SetScript("OnEscapePressed", renameInput.ClearFocus)
    frame.renameInput = renameInput

    local renameButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    renameButton:SetSize(120, 24)
    renameButton:SetPoint("LEFT", renameInput, "RIGHT", 10, 0)
    renameButton:SetText("Rename")
    renameButton:SetScript("OnClick", function()
        local _, message, renamed = UI.RenameSelection(selectedProfile, renameInput:GetText())
        setStatus(message)

        if renamed then
            renameInput:SetText("")
        end
    end)
    renameInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        renameButton:Click()
    end)

    local applyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyButton:SetSize(150, 26)
    applyButton:SetPoint("TOP", -80, -360)
    applyButton:SetText("Apply Selected")
    applyButton:SetScript("OnClick", function()
        local _, message = UI.ApplySelection(selectedProfile)
        setStatus(message)
    end)

    deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    deleteButton:SetSize(150, 26)
    deleteButton:SetPoint("TOP", 80, -360)
    deleteButton:SetText("Delete Selected")
    deleteButton:SetScript("OnClick", function()
        local _, message = UI.RequestDeleteSelection(selectedProfile)
        setStatus(message)
    end)

    local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 24, -402)
    statusText:SetPoint("TOPRIGHT", -24, -402)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("Status: Ready.")
    frame.statusText = statusText

    frame:Hide()
    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
    end
end

function UI.Show()
    if not frame then
        createFrame()
    end

    UI.RefreshProfileList()
    frame:Show()
    frame:Raise()
end

_G.RenderSetTest.ShowUI = UI.Show
