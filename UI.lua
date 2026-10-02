local _, addon = ...

local UI = {}
addon.UI = UI

local frame
local selectedProfile
local pendingDeleteProfile
local profileButtons = {}
local applyButton
local renameButton
local deleteButton

local LAYOUT = {
    width = 392,
    height = 366,
    margin = 16,
    gap = 7,
    headerHeight = 50,
    listHeight = 140,
    rowHeight = 26,
    statusHeight = 30,
    buttonHeight = 27,
}

local function countEntries(entries)
    local count = 0
    for _ in pairs(entries or {}) do
        count = count + 1
    end
    return count
end

local function setButtonEnabled(button, enabled)
    if not button then
        return
    end

    if enabled then
        button:Enable()
        button:SetAlpha(1)
    else
        button:Disable()
        button:SetAlpha(0.45)
    end

    if button.Paint then
        button:Paint()
    end
end

local function cancelDeleteConfirmation()
    pendingDeleteProfile = nil
    if deleteButton then
        deleteButton.confirming = false
        deleteButton:SetText("Delete")
        if deleteButton.Paint then
            deleteButton:Paint()
        end
    end
end

local function setStatus(message)
    if frame then
        local text = message or "Ready"
        frame.statusText:SetText(text)

        if text:find("^Could not") or text:find("exists", 1, true) then
            frame.statusText:SetTextColor(0.95, 0.52, 0.42)
            frame.statusAccent:SetColorTexture(0.62, 0.18, 0.12, 1)
        elseif text:find("^Confirm") then
            frame.statusText:SetTextColor(1, 0.72, 0.36)
            frame.statusAccent:SetColorTexture(0.72, 0.36, 0.08, 1)
        elseif text:find("^Saved") or text:find("^Applied") or text:find("^Renamed") or text:find("^Deleted") then
            frame.statusText:SetTextColor(0.82, 0.82, 0.68)
            frame.statusAccent:SetColorTexture(0.58, 0.46, 0.15, 1)
        else
            frame.statusText:SetTextColor(0.62, 0.62, 0.65)
            frame.statusAccent:SetColorTexture(0.26, 0.26, 0.29, 1)
        end
    end
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

function UI.SummarizeCapture(profileName, result)
    if result and result.errors and result.errors.profile == "profile already exists" then
        return "Profile already exists."
    elseif not result or not result.saved then
        return "Could not save profile."
    end

    local warningCount = countEntries(result.errors)
    if warningCount == 1 then
        return "Saved " .. profileName .. " with 1 warning."
    elseif warningCount > 1 then
        return "Saved " .. profileName .. " with " .. warningCount .. " warnings."
    end

    return "Saved " .. profileName .. "."
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

function UI.SummarizeRename(oldName, newName, result)
    if result and result.unchanged then
        return "Profile name unchanged."
    elseif result and result.renamed then
        return "Renamed " .. oldName .. " → " .. newName .. "."
    elseif result and result.errors and result.errors.profile == "destination profile already exists" then
        return "Profile already exists."
    end

    return "Could not rename profile."
end

function UI.SummarizeDelete(profileName, result)
    if result and result.deleted then
        return "Deleted " .. profileName .. "."
    end

    return "Could not delete profile."
end

function UI.SaveCurrent(name)
    local valid, validationMessage = addon.ValidateProfileName(name)
    if not valid then
        return nil, validationMessage, false
    end

    local result = addon.CaptureProfile(name)
    return result, UI.SummarizeCapture(name, result), result.saved == true
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

    return result, UI.SummarizeRename(profileName, newName, result), result.renamed or result.unchanged
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

    return result, UI.SummarizeDelete(profileName, result), result.deleted == true
end

function UI.RequestDeleteSelection(profileName)
    if type(profileName) ~= "string" or profileName == "" then
        return nil, "Select a profile first.", false
    end

    if pendingDeleteProfile ~= profileName then
        pendingDeleteProfile = profileName
        if deleteButton then
            deleteButton.confirming = true
            deleteButton:SetText("Confirm Delete")
            if deleteButton.Paint then
                deleteButton:Paint()
            end
        end
        return nil, "Confirm deletion of " .. profileName .. ".", false
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

local function updateSelection()
    if not frame then
        return
    end

    for _, button in ipairs(profileButtons) do
        local isSelected = button.profileName == selectedProfile
        button.isSelected = isSelected
        if isSelected then
            button.selectedTexture:Show()
            button.hoverTexture:Hide()
            button.accent:Show()
            button.nameText:SetTextColor(1, 0.82, 0.25)
        else
            button.selectedTexture:Hide()
            button.hoverTexture:Hide()
            button.accent:Hide()
            button.nameText:SetTextColor(0.9, 0.9, 0.9)
        end
    end

    local hasSelection = selectedProfile ~= nil
    setButtonEnabled(applyButton, hasSelection)
    setButtonEnabled(renameButton, hasSelection)
    setButtonEnabled(deleteButton, hasSelection)
end

function UI.SelectProfile(profileName)
    selectedProfile = profileName
    cancelDeleteConfirmation()
    updateSelection()
    setStatus(profileName and ("Selected " .. profileName .. ".") or "Ready")
end

function UI.GetSelectedProfile()
    return selectedProfile
end

local function createProfileButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(320, LAYOUT.rowHeight)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.065, 0.065, 0.075, 0.96)

    local hoverTexture = button:CreateTexture(nil, "BORDER")
    hoverTexture:SetAllPoints()
    hoverTexture:SetColorTexture(0.14, 0.14, 0.16, 0.96)
    hoverTexture:Hide()
    button.hoverTexture = hoverTexture

    local selectedTexture = button:CreateTexture(nil, "ARTWORK")
    selectedTexture:SetAllPoints()
    selectedTexture:SetColorTexture(0.17, 0.14, 0.075, 0.98)
    selectedTexture:Hide()
    button.selectedTexture = selectedTexture

    local accent = button:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(2)
    accent:SetColorTexture(0.76, 0.56, 0.14, 1)
    accent:Hide()
    button.accent = accent

    local separator = button:CreateTexture(nil, "OVERLAY")
    separator:SetPoint("BOTTOMLEFT", 8, 0)
    separator:SetPoint("BOTTOMRIGHT", -8, 0)
    separator:SetHeight(1)
    separator:SetColorTexture(0.14, 0.14, 0.15, 0.6)

    local nameText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", 10, 0)
    nameText:SetPoint("RIGHT", -8, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("MIDDLE")
    nameText:SetWordWrap(false)
    button.nameText = nameText

    button:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self.hoverTexture:Show()
            self.nameText:SetTextColor(1, 1, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        self.hoverTexture:Hide()
        if not self.isSelected then
            self.nameText:SetTextColor(0.9, 0.9, 0.9)
        end
    end)
    button:SetScript("OnClick", function(self)
        UI.SelectProfile(self.profileName)
    end)

    return button
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
        return names
    end

    for index, profileName in ipairs(names) do
        local button = profileButtons[index]
        if not button then
            button = createProfileButton(frame.profileContent)
            profileButtons[index] = button
        end

        button.profileName = profileName
        button.nameText:SetText(profileName)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, -((index - 1) * (LAYOUT.rowHeight + 2)))
        button:Show()
    end

    for index = #names + 1, #profileButtons do
        profileButtons[index]:Hide()
        profileButtons[index].profileName = nil
    end

    frame.profileContent:SetHeight(math.max(1, #names * (LAYOUT.rowHeight + 2)))
    frame.emptyText:SetShown(#names == 0)
    if #names == 1 then
        frame.profileCountText:SetText("1 profile")
    else
        frame.profileCountText:SetText(#names .. " profiles")
    end
    updateSelection()
    return names
end

local function addBorder(target, red, green, blue, alpha)
    local edges = {}
    local top = target:CreateTexture(nil, "BORDER")
    top:SetColorTexture(red, green, blue, alpha)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    edges[#edges + 1] = top

    local bottom = target:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(red, green, blue, alpha)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    edges[#edges + 1] = bottom

    local left = target:CreateTexture(nil, "BORDER")
    left:SetColorTexture(red, green, blue, alpha)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)
    edges[#edges + 1] = left

    local right = target:CreateTexture(nil, "BORDER")
    right:SetColorTexture(red, green, blue, alpha)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
    edges[#edges + 1] = right

    return edges
end


local function setBorderColor(edges, red, green, blue, alpha)
    for _, edge in ipairs(edges) do
        edge:SetColorTexture(red, green, blue, alpha)
    end
end

local function createActionButton(parent, text, kind)
    local button = CreateFrame("Button", nil, parent)
    button.kind = kind or "secondary"
    button:SetHeight(LAYOUT.buttonHeight)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    button.background = background
    button.borderEdges = addBorder(button, 0.28, 0.28, 0.3, 1)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    button:SetFontString(label)
    button.label = label
    button:SetText(text)

    function button:Paint()
        if not self:IsEnabled() then
            self.background:SetColorTexture(0.055, 0.055, 0.062, 1)
            setBorderColor(self.borderEdges, 0.16, 0.16, 0.18, 1)
            self.label:SetTextColor(0.38, 0.38, 0.4)
        elseif self.confirming then
            self.background:SetColorTexture(0.22, 0.055, 0.045, 1)
            setBorderColor(self.borderEdges, 0.58, 0.17, 0.12, 1)
            self.label:SetTextColor(1, 0.72, 0.62)
        elseif self.kind == "primary" then
            local lift = self.mouseDown and 0.02 or (self.mouseOver and 0.07 or 0)
            self.background:SetColorTexture(0.14 + lift, 0.105 + lift * 0.7, 0.035, 1)
            setBorderColor(self.borderEdges, 0.52 + lift, 0.38 + lift * 0.7, 0.1, 1)
            self.label:SetTextColor(1, 0.82, 0.28)
        else
            local lift = self.mouseDown and 0.01 or (self.mouseOver and 0.045 or 0)
            self.background:SetColorTexture(0.085 + lift, 0.085 + lift, 0.095 + lift, 1)
            setBorderColor(self.borderEdges, 0.25 + lift, 0.25 + lift, 0.27 + lift, 1)
            self.label:SetTextColor(0.86, 0.86, 0.88)
        end
    end

    button:SetScript("OnEnter", function(self)
        self.mouseOver = true
        self:Paint()
    end)
    button:SetScript("OnLeave", function(self)
        self.mouseOver = false
        self.mouseDown = false
        self:Paint()
    end)
    button:SetScript("OnMouseDown", function(self)
        self.mouseDown = true
        self:Paint()
    end)
    button:SetScript("OnMouseUp", function(self)
        self.mouseDown = false
        self:Paint()
    end)
    button:Paint()
    return button
end

local function createFrame()
    frame = CreateFrame("Frame", "RenderSetFrame", UIParent)
    frame:SetSize(LAYOUT.width, LAYOUT.height)
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
    background:SetColorTexture(0.028, 0.028, 0.036, 0.985)
    addBorder(frame, 0.27, 0.27, 0.3, 1)

    local header = frame:CreateTexture(nil, "BORDER")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(LAYOUT.headerHeight - 2)
    header:SetColorTexture(0.065, 0.065, 0.078, 1)

    local headerLine = frame:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", 1, -(LAYOUT.headerHeight - 2))
    headerLine:SetPoint("TOPRIGHT", -1, -(LAYOUT.headerHeight - 2))
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.55, 0.4, 0.1, 0.85)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -9)
    title:SetText("RenderSet")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
    subtitle:SetText("Graphics Profiles")
    subtitle:SetTextColor(0.65, 0.65, 0.67)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -3, -3)

    local listPanel = CreateFrame("Frame", nil, frame)
    listPanel:SetSize(LAYOUT.width - (LAYOUT.margin * 2), LAYOUT.listHeight)
    listPanel:SetPoint("TOPLEFT", LAYOUT.margin, -(LAYOUT.headerHeight + 10))
    local listBackground = listPanel:CreateTexture(nil, "BACKGROUND")
    listBackground:SetAllPoints()
    listBackground:SetColorTexture(0.018, 0.018, 0.023, 0.94)
    addBorder(listPanel, 0.17, 0.17, 0.19, 1)

    local profilesLabel = listPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    profilesLabel:SetPoint("TOPLEFT", 9, -7)
    profilesLabel:SetText("PROFILES")

    local profileCountText = listPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    profileCountText:SetPoint("TOPRIGHT", -9, -7)
    profileCountText:SetText("0 profiles")
    frame.profileCountText = profileCountText

    local scrollFrame = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 9, -24)
    scrollFrame:SetPoint("BOTTOMRIGHT", -27, 7)

    local profileContent = CreateFrame("Frame", nil, scrollFrame)
    profileContent:SetWidth(320)
    profileContent:SetHeight(1)
    scrollFrame:SetScrollChild(profileContent)
    frame.profileContent = profileContent

    local emptyText = listPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("CENTER", 0, -10)
    emptyText:SetText("No profiles saved.")
    frame.emptyText = emptyText

    local statusPanel = CreateFrame("Frame", nil, frame)
    statusPanel:SetSize(LAYOUT.width - (LAYOUT.margin * 2), LAYOUT.statusHeight)
    statusPanel:SetPoint("TOPLEFT", LAYOUT.margin, -208)
    local statusBackground = statusPanel:CreateTexture(nil, "BACKGROUND")
    statusBackground:SetAllPoints()
    statusBackground:SetColorTexture(0.045, 0.045, 0.054, 0.96)
    addBorder(statusPanel, 0.15, 0.15, 0.17, 1)

    local statusAccent = statusPanel:CreateTexture(nil, "ARTWORK")
    statusAccent:SetPoint("TOPLEFT", 1, -1)
    statusAccent:SetPoint("BOTTOMLEFT", 1, 1)
    statusAccent:SetWidth(2)
    statusAccent:SetColorTexture(0.26, 0.26, 0.29, 1)
    frame.statusAccent = statusAccent

    local statusText = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("LEFT", 10, 0)
    statusText:SetPoint("RIGHT", -8, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("MIDDLE")
    statusText:SetWordWrap(false)
    statusText:SetText("Ready")
    statusText:SetTextColor(0.62, 0.62, 0.65)
    frame.statusText = statusText

    local nameInput = CreateFrame("EditBox", nil, frame)
    nameInput:SetSize(LAYOUT.width - (LAYOUT.margin * 2), 28)
    nameInput:SetPoint("TOPLEFT", LAYOUT.margin, -247)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(80)
    nameInput:SetFontObject(ChatFontNormal)
    nameInput:SetTextInsets(10, 10, 0, 0)
    nameInput:SetJustifyV("MIDDLE")

    local inputBackground = nameInput:CreateTexture(nil, "BACKGROUND")
    inputBackground:SetAllPoints()
    inputBackground:SetColorTexture(0.035, 0.035, 0.043, 1)
    local inputEdges = addBorder(nameInput, 0.22, 0.22, 0.25, 1)

    local inputPlaceholder = nameInput:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    inputPlaceholder:SetPoint("LEFT", 10, 0)
    inputPlaceholder:SetText("Profile name")
    nameInput:SetScript("OnTextChanged", function(self)
        inputPlaceholder:SetShown(self:GetText() == "")
    end)
    nameInput:SetScript("OnEditFocusGained", function()
        setBorderColor(inputEdges, 0.5, 0.38, 0.12, 1)
    end)
    nameInput:SetScript("OnEditFocusLost", function()
        setBorderColor(inputEdges, 0.22, 0.22, 0.25, 1)
    end)
    nameInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    frame.nameInput = nameInput

    local saveButton = createActionButton(frame, "Save Current", "secondary")
    saveButton:SetSize(115, LAYOUT.buttonHeight)
    saveButton:SetPoint("TOPLEFT", LAYOUT.margin, -283)
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
    frame.saveButton = saveButton

    nameInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        saveButton:Click()
    end)

    renameButton = createActionButton(frame, "Rename", "secondary")
    renameButton:SetSize(115, LAYOUT.buttonHeight)
    renameButton:SetPoint("TOPLEFT", LAYOUT.margin + 115 + LAYOUT.gap, -283)
    renameButton:SetScript("OnClick", function()
        local _, message, renamed = UI.RenameSelection(selectedProfile, nameInput:GetText())
        setStatus(message)

        if renamed then
            nameInput:SetText("")
        end
    end)
    frame.renameButton = renameButton

    deleteButton = createActionButton(frame, "Delete", "secondary")
    deleteButton:SetSize(116, LAYOUT.buttonHeight)
    deleteButton:SetPoint("TOPRIGHT", -LAYOUT.margin, -283)
    deleteButton:SetScript("OnClick", function()
        local _, message = UI.RequestDeleteSelection(selectedProfile)
        setStatus(message)
    end)
    frame.deleteButton = deleteButton

    applyButton = createActionButton(frame, "Apply Profile", "primary")
    applyButton:SetSize(LAYOUT.width - (LAYOUT.margin * 2), 30)
    applyButton:SetPoint("TOPLEFT", LAYOUT.margin, -320)
    applyButton:SetScript("OnClick", function()
        local _, message = UI.ApplySelection(selectedProfile)
        setStatus(message)
    end)
    frame.applyButton = applyButton

    frame.profileButtons = profileButtons

    updateSelection()
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

function UI.Hide()
    if frame then
        frame:Hide()
    end
end

function UI.Toggle()
    if not frame then
        UI.Show()
    elseif frame:IsShown() then
        UI.Hide()
    else
        UI.Show()
    end
end

_G.RenderSetTest.ShowUI = UI.Show
_G.RenderSetTest.ToggleUI = UI.Toggle
_G.RenderSetTest.GetUIFrame = function()
    return frame
end
