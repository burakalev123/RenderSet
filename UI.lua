local _, addon = ...

local UI = {}
addon.UI = UI

local frame
local selectedKind
local selectedId
local pendingDeleteProfile
local profileButtons = {}
local presetButtons = {}
local applyButton
local renameButton
local deleteButton

local LAYOUT = {
    width = 568,
    height = 328,
    margin = 16,
    gap = 12,
    headerHeight = 48,
    bodyTop = 58,
    bodyHeight = 208,
    leftWidth = 202,
    rightWidth = 322,
    profileRowWidth = 164,
    profileViewportHeight = 177,
    rowHeight = 29,
    buttonHeight = 28,
    footerHeight = 49,
}

local COLORS = {
    window = { 0.022, 0.025, 0.03, 0.99 },
    header = { 0.045, 0.05, 0.058, 1 },
    panel = { 0.036, 0.041, 0.048, 1 },
    panelDeep = { 0.024, 0.028, 0.033, 1 },
    input = { 0.03, 0.035, 0.041, 1 },
    border = { 0.12, 0.14, 0.16, 1 },
    divider = { 0.1, 0.12, 0.14, 1 },
    text = { 0.92, 0.94, 0.96 },
    muted = { 0.62, 0.66, 0.71 },
    accent = { 0.12, 0.62, 0.82, 1 },
    accentBorder = { 0.08, 0.43, 0.58, 1 },
    accentSoft = { 0.045, 0.13, 0.18, 1 },
    hover = { 0.075, 0.085, 0.098, 1 },
    error = { 0.56, 0.16, 0.16, 1 },
    errorSoft = { 0.2, 0.055, 0.055, 1 },
}

local function setTextureColor(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

local function setTextColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3])
end

local function applyFont(fontRegion, size, fallback)
    local loaded, result = pcall(fontRegion.SetFont, fontRegion, STANDARD_TEXT_FONT, size, "")
    if loaded and result ~= false then
        return
    end

    if fallback then
        fontRegion:SetFontObject(fallback)
    end
end

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
            frame.statusText:SetTextColor(0.92, 0.55, 0.55)
            setTextureColor(frame.statusAccent, COLORS.error)
        elseif text:find("^Confirm") then
            frame.statusText:SetTextColor(0.92, 0.55, 0.55)
            setTextureColor(frame.statusAccent, COLORS.error)
        elseif text:find("^Saved") or text:find("^Applied") or text:find("^Renamed") or text:find("^Deleted") then
            frame.statusText:SetTextColor(0.72, 0.84, 0.9)
            setTextureColor(frame.statusAccent, COLORS.accent)
        else
            setTextColor(frame.statusText, COLORS.muted)
            setTextureColor(frame.statusAccent, COLORS.divider)
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
    if type(profileName) == "table" and result == nil then
        result = profileName
        profileName = nil
    end

    if result and result.errors and result.errors.profile == "profile already exists" then
        return "Profile already exists."
    elseif not result or not result.saved then
        return "Could not save profile."
    end

    local warningCount = countEntries(result.errors)
    if warningCount == 1 then
        return profileName and ("Saved " .. profileName .. " with 1 warning.") or "Profile saved with 1 warning."
    elseif warningCount > 1 then
        return profileName and ("Saved " .. profileName .. " with " .. warningCount .. " warnings.")
            or ("Profile saved with " .. warningCount .. " warnings.")
    end

    return profileName and ("Saved " .. profileName .. ".") or "Profile saved."
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
        selectedKind = "profile"
        selectedId = newName
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
        selectedKind = nil
        selectedId = nil
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

function UI.ApplySelection(selectionId, selectionKind)
    if type(selectionId) ~= "string" or selectionId == "" then
        return nil, "Select a profile first."
    end

    if selectionKind == "preset" then
        local preset = addon.GetBuiltInPreset(selectionId)
        if not preset then
            return nil, "Select a profile first."
        end

        local result = addon.ApplyBuiltInPreset(selectionId)
        return result, UI.SummarizeApply(preset.shortName, result)
    end

    local result = addon.ApplyProfile(selectionId)
    return result, UI.SummarizeApply(selectionId, result)
end

local function updateSelection()
    if not frame then
        return
    end

    for _, button in ipairs(presetButtons) do
        local isSelected = selectedKind == "preset" and button.selectionId == selectedId
        button.isSelected = isSelected
        if isSelected then
            button.selectedTexture:Show()
            button.hoverTexture:Hide()
            button.accent:Show()
            setTextColor(button.nameText, COLORS.text)
        else
            button.selectedTexture:Hide()
            button.hoverTexture:Hide()
            button.accent:Hide()
            button.nameText:SetTextColor(0.84, 0.87, 0.9)
        end
    end

    for _, button in ipairs(profileButtons) do
        local isSelected = selectedKind == "profile" and button.profileName == selectedId
        button.isSelected = isSelected
        if isSelected then
            button.selectedTexture:Show()
            button.hoverTexture:Hide()
            button.accent:Show()
            setTextColor(button.nameText, COLORS.text)
        else
            button.selectedTexture:Hide()
            button.hoverTexture:Hide()
            button.accent:Hide()
            button.nameText:SetTextColor(0.84, 0.87, 0.9)
        end
    end

    local selectedPreset = selectedKind == "preset" and addon.GetBuiltInPreset(selectedId) or nil
    local selectedTitle = selectedPreset and selectedPreset.name or selectedId
    if frame.selectedText then
        frame.selectedText:SetText(selectedTitle or "No profile selected")
        if selectedTitle then
            frame.selectedText:SetTextColor(0.84, 0.9, 0.94)
        else
            setTextColor(frame.selectedText, COLORS.muted)
        end
    end

    if frame.selectionLabel then
        frame.selectionLabel:SetText(selectedPreset and "PRESET" or "PROFILE")
    end
    if frame.manualNote then
        frame.manualNote:SetText(selectedPreset and selectedPreset.manualNote or "")
        frame.manualNote:SetShown(selectedPreset ~= nil)
    end

    local hasSelection = selectedId ~= nil
    setButtonEnabled(applyButton, hasSelection)
    setButtonEnabled(renameButton, hasSelection and selectedKind == "profile")
    setButtonEnabled(deleteButton, hasSelection and selectedKind == "profile")
end

function UI.SelectProfile(profileName)
    selectedKind = profileName and "profile" or nil
    selectedId = profileName
    cancelDeleteConfirmation()
    updateSelection()
    setStatus(profileName and ("Selected " .. profileName .. ".") or "Ready")
end

function UI.GetSelectedProfile()
    return selectedKind == "profile" and selectedId or nil
end

function UI.SelectBuiltInPreset(presetId)
    local preset = addon.GetBuiltInPreset(presetId)
    selectedKind = preset and "preset" or nil
    selectedId = preset and presetId or nil
    cancelDeleteConfirmation()
    updateSelection()
    setStatus(preset and ("Selected " .. preset.shortName .. ".") or "Ready")
end

function UI.GetSelection()
    return selectedKind, selectedId
end

local function createProfileButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(LAYOUT.profileRowWidth, LAYOUT.rowHeight)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    setTextureColor(background, COLORS.panelDeep)

    local hoverTexture = button:CreateTexture(nil, "BORDER")
    hoverTexture:SetAllPoints()
    setTextureColor(hoverTexture, COLORS.hover)
    hoverTexture:Hide()
    button.hoverTexture = hoverTexture

    local selectedTexture = button:CreateTexture(nil, "ARTWORK")
    selectedTexture:SetAllPoints()
    setTextureColor(selectedTexture, COLORS.accentSoft)
    selectedTexture:Hide()
    button.selectedTexture = selectedTexture

    local accent = button:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(2)
    setTextureColor(accent, COLORS.accent)
    accent:Hide()
    button.accent = accent

    local separator = button:CreateTexture(nil, "OVERLAY")
    separator:SetPoint("BOTTOMLEFT", 8, 0)
    separator:SetPoint("BOTTOMRIGHT", -8, 0)
    separator:SetHeight(1)
    separator:SetColorTexture(0.1, 0.12, 0.14, 0.65)

    local nameText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", 10, 0)
    nameText:SetPoint("RIGHT", -8, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("MIDDLE")
    nameText:SetWordWrap(false)
    applyFont(nameText, 14, GameFontHighlight)
    button.nameText = nameText

    button:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self.hoverTexture:Show()
            setTextColor(self.nameText, COLORS.text)
        end
    end)
    button:SetScript("OnLeave", function(self)
        self.hoverTexture:Hide()
        if not self.isSelected then
            self.nameText:SetTextColor(0.84, 0.87, 0.9)
        end
    end)
    button:SetScript("OnClick", function(self)
        if self.selectionKind == "preset" then
            UI.SelectBuiltInPreset(self.selectionId)
        else
            UI.SelectProfile(self.profileName)
        end
    end)

    return button
end

function UI.RefreshProfileList()
    local names = UI.GetSortedProfileNames()
    local profiles = type(RenderSetDB) == "table" and RenderSetDB.profiles or nil
    local presets = addon.BuiltinPresets or {}

    if selectedKind == "profile" and selectedId
        and (type(profiles) ~= "table" or type(profiles[selectedId]) ~= "table") then
        selectedKind = nil
        selectedId = nil
        cancelDeleteConfirmation()
    end
    if selectedKind == "preset" and not addon.GetBuiltInPreset(selectedId) then
        selectedKind = nil
        selectedId = nil
    end
    if not selectedId and #names > 0 then
        selectedKind = "profile"
        selectedId = names[1]
    elseif not selectedId and #presets > 0 then
        selectedKind = "preset"
        selectedId = presets[1].id
    end

    if not frame then
        return names
    end

    local rowStep = LAYOUT.rowHeight + 2
    local sectionHeight = 18

    for index, preset in ipairs(presets) do
        local button = presetButtons[index]
        if not button then
            button = createProfileButton(frame.profileContent)
            presetButtons[index] = button
        end

        button.selectionKind = "preset"
        button.selectionId = preset.id
        button.profileName = nil
        button.nameText:SetText(preset.shortName)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, -(sectionHeight + ((index - 1) * rowStep)))
        button:Show()
    end

    for index = #presets + 1, #presetButtons do
        presetButtons[index]:Hide()
        presetButtons[index].selectionId = nil
    end

    local profilesHeaderOffset = sectionHeight + (#presets * rowStep)
    frame.presetsSectionLabel:ClearAllPoints()
    frame.presetsSectionLabel:SetPoint("TOPLEFT", 2, -2)
    frame.profilesSectionLabel:ClearAllPoints()
    frame.profilesSectionLabel:SetPoint("TOPLEFT", 2, -(profilesHeaderOffset + 2))

    for index, profileName in ipairs(names) do
        local button = profileButtons[index]
        if not button then
            button = createProfileButton(frame.profileContent)
            profileButtons[index] = button
        end

        button.selectionKind = "profile"
        button.selectionId = profileName
        button.profileName = profileName
        button.nameText:SetText(profileName)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, -(profilesHeaderOffset + sectionHeight + ((index - 1) * rowStep)))
        button:Show()
    end

    for index = #names + 1, #profileButtons do
        profileButtons[index]:Hide()
        profileButtons[index].profileName = nil
    end

    local contentHeight = math.max(1, profilesHeaderOffset + sectionHeight + (#names * rowStep))
    frame.profileContent:SetHeight(contentHeight)
    frame.profileScroll.maxScroll = math.max(0, contentHeight - LAYOUT.profileViewportHeight)
    if frame.profileScroll:GetVerticalScroll() > frame.profileScroll.maxScroll then
        frame.profileScroll:SetVerticalScroll(frame.profileScroll.maxScroll)
    end
    frame.UpdateScrollbar()
    frame.emptyText:SetShown(#names == 0)
    frame.emptyText:ClearAllPoints()
    frame.emptyText:SetPoint("TOPLEFT", frame.profileContent, "TOPLEFT", 10, -(profilesHeaderOffset + sectionHeight + 7))
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
    applyFont(label, 13, GameFontHighlightSmall)
    button:SetFontString(label)
    button.label = label
    button:SetText(text)

    function button:Paint()
        if not self:IsEnabled() then
            self.background:SetColorTexture(0.035, 0.04, 0.046, 1)
            setBorderColor(self.borderEdges, 0.1, 0.115, 0.13, 1)
            self.label:SetTextColor(0.32, 0.35, 0.38)
        elseif self.confirming then
            setTextureColor(self.background, COLORS.errorSoft)
            setBorderColor(self.borderEdges, COLORS.error[1], COLORS.error[2], COLORS.error[3], 1)
            self.label:SetTextColor(0.94, 0.62, 0.62)
        elseif self.kind == "primary" then
            local lift = self.mouseDown and -0.01 or (self.mouseOver and 0.035 or 0)
            self.background:SetColorTexture(0.045 + lift, 0.19 + lift, 0.26 + lift, 1)
            setBorderColor(self.borderEdges, 0.08, 0.5 + lift, 0.68 + lift, 1)
            setTextColor(self.label, COLORS.text)
        else
            local lift = self.mouseDown and -0.005 or (self.mouseOver and 0.03 or 0)
            self.background:SetColorTexture(0.055 + lift, 0.062 + lift, 0.071 + lift, 1)
            setBorderColor(self.borderEdges, 0.16 + lift, 0.18 + lift, 0.21 + lift, 1)
            self.label:SetTextColor(0.88, 0.9, 0.93)
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
    setTextureColor(background, COLORS.window)
    addBorder(frame, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)

    local header = frame:CreateTexture(nil, "BORDER")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(LAYOUT.headerHeight - 2)
    setTextureColor(header, COLORS.header)

    local headerLine = frame:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", 1, -(LAYOUT.headerHeight - 2))
    headerLine:SetPoint("TOPRIGHT", -1, -(LAYOUT.headerHeight - 2))
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(0.08, 0.42, 0.56, 0.7)

    local headerAccent = frame:CreateTexture(nil, "ARTWORK")
    headerAccent:SetPoint("TOPLEFT", 1, -1)
    headerAccent:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 1, 0)
    headerAccent:SetWidth(3)
    setTextureColor(headerAccent, COLORS.accent)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -7)
    title:SetText("RenderSet")
    applyFont(title, 18, GameFontNormalLarge)
    setTextColor(title, COLORS.text)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
    subtitle:SetText("Graphics Profiles")
    applyFont(subtitle, 12, GameFontHighlightSmall)
    setTextColor(subtitle, COLORS.muted)

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(26, 26)
    closeButton:SetPoint("TOPRIGHT", -10, -10)
    local closeBackground = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBackground:SetAllPoints()
    setTextureColor(closeBackground, COLORS.panelDeep)
    local closeEdges = addBorder(closeButton, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)
    local closeText = closeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    closeText:SetPoint("CENTER", 0, 1)
    closeText:SetText("×")
    applyFont(closeText, 17, GameFontHighlight)
    closeText:SetTextColor(0.58, 0.62, 0.66)
    closeButton:SetScript("OnEnter", function()
        setTextureColor(closeBackground, COLORS.hover)
        setBorderColor(closeEdges, COLORS.accentBorder[1], COLORS.accentBorder[2], COLORS.accentBorder[3], 1)
        setTextColor(closeText, COLORS.text)
    end)
    closeButton:SetScript("OnLeave", function()
        setTextureColor(closeBackground, COLORS.panelDeep)
        setBorderColor(closeEdges, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)
        closeText:SetTextColor(0.58, 0.62, 0.66)
    end)
    closeButton:SetScript("OnMouseDown", function()
        setTextureColor(closeBackground, COLORS.errorSoft)
    end)
    closeButton:SetScript("OnMouseUp", function(self)
        if self:GetScript("OnEnter") then
            self:GetScript("OnEnter")()
        end
    end)
    closeButton:SetScript("OnClick", UI.Hide)
    frame.closeButton = closeButton

    local listPanel = CreateFrame("Frame", nil, frame)
    listPanel:SetSize(LAYOUT.leftWidth, LAYOUT.bodyHeight)
    listPanel:SetPoint("TOPLEFT", LAYOUT.margin, -LAYOUT.bodyTop)
    local listBackground = listPanel:CreateTexture(nil, "BACKGROUND")
    listBackground:SetAllPoints()
    setTextureColor(listBackground, COLORS.panel)
    addBorder(listPanel, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)

    local profilesLabel = listPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    profilesLabel:SetPoint("TOPLEFT", 9, -7)
    profilesLabel:SetText("GRAPHICS SETS")
    applyFont(profilesLabel, 12, GameFontNormalSmall)
    profilesLabel:SetTextColor(0.78, 0.82, 0.86)

    local profileCountText = listPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    profileCountText:SetPoint("TOPRIGHT", -9, -7)
    profileCountText:SetText("0 profiles")
    applyFont(profileCountText, 11, GameFontDisableSmall)
    frame.profileCountText = profileCountText

    local scrollFrame = CreateFrame("ScrollFrame", nil, listPanel)
    scrollFrame:SetPoint("TOPLEFT", 9, -24)
    scrollFrame:SetPoint("BOTTOMRIGHT", -29, 7)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame.maxScroll = 0

    local profileContent = CreateFrame("Frame", nil, scrollFrame)
    profileContent:SetWidth(LAYOUT.profileRowWidth)
    profileContent:SetHeight(1)
    scrollFrame:SetScrollChild(profileContent)
    frame.profileScroll = scrollFrame
    frame.profileContent = profileContent

    local presetsSectionLabel = profileContent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    presetsSectionLabel:SetText("PRESETS")
    applyFont(presetsSectionLabel, 10, GameFontDisableSmall)
    presetsSectionLabel:SetTextColor(0.52, 0.58, 0.63)
    frame.presetsSectionLabel = presetsSectionLabel

    local profilesSectionLabel = profileContent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    profilesSectionLabel:SetText("PROFILES")
    applyFont(profilesSectionLabel, 10, GameFontDisableSmall)
    profilesSectionLabel:SetTextColor(0.52, 0.58, 0.63)
    frame.profilesSectionLabel = profilesSectionLabel

    local scrollTrack = CreateFrame("Frame", nil, listPanel)
    scrollTrack:SetWidth(4)
    scrollTrack:SetPoint("TOPRIGHT", -10, -24)
    scrollTrack:SetPoint("BOTTOMRIGHT", -10, 7)
    local trackTexture = scrollTrack:CreateTexture(nil, "BACKGROUND")
    trackTexture:SetAllPoints()
    trackTexture:SetColorTexture(0.055, 0.062, 0.071, 1)

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack)
    scrollThumb:SetWidth(4)
    local thumbTexture = scrollThumb:CreateTexture(nil, "ARTWORK")
    thumbTexture:SetAllPoints()
    thumbTexture:SetColorTexture(0.24, 0.29, 0.33, 1)

    function frame.UpdateScrollbar()
        local maxScroll = scrollFrame.maxScroll or 0
        if maxScroll <= 0 then
            scrollFrame:SetVerticalScroll(0)
            scrollTrack:Hide()
            return
        end

        scrollTrack:Show()
        local trackHeight = LAYOUT.profileViewportHeight
        local contentHeight = trackHeight + maxScroll
        local thumbHeight = math.max(24, math.floor(trackHeight * trackHeight / contentHeight))
        local travel = trackHeight - thumbHeight
        local offset = travel * (scrollFrame:GetVerticalScroll() / maxScroll)
        scrollThumb:SetHeight(thumbHeight)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -offset)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local nextScroll = self:GetVerticalScroll() - (delta * (LAYOUT.rowHeight + 2))
        self:SetVerticalScroll(math.max(0, math.min(self.maxScroll or 0, nextScroll)))
        frame.UpdateScrollbar()
    end)
    frame.scrollTrack = scrollTrack
    frame.scrollThumb = scrollThumb

    local emptyText = listPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("CENTER", 0, -10)
    emptyText:SetText("No profiles saved.")
    applyFont(emptyText, 13, GameFontDisable)
    frame.emptyText = emptyText

    local rightPanel = CreateFrame("Frame", nil, frame)
    rightPanel:SetSize(LAYOUT.rightWidth, LAYOUT.bodyHeight)
    rightPanel:SetPoint("TOPLEFT", LAYOUT.margin + LAYOUT.leftWidth + LAYOUT.gap, -LAYOUT.bodyTop)
    local rightBackground = rightPanel:CreateTexture(nil, "BACKGROUND")
    rightBackground:SetAllPoints()
    setTextureColor(rightBackground, COLORS.panel)
    addBorder(rightPanel, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)

    local profileLabel = rightPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    profileLabel:SetPoint("TOPLEFT", 12, -10)
    profileLabel:SetText("PROFILE")
    applyFont(profileLabel, 12, GameFontNormalSmall)
    profileLabel:SetTextColor(0.78, 0.82, 0.86)
    frame.selectionLabel = profileLabel

    local selectedText = rightPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    selectedText:SetPoint("TOPRIGHT", -12, -10)
    selectedText:SetPoint("LEFT", profileLabel, "RIGHT", 12, 0)
    selectedText:SetJustifyH("RIGHT")
    selectedText:SetWordWrap(false)
    selectedText:SetText("No profile selected")
    applyFont(selectedText, 14, GameFontHighlightSmall)
    setTextColor(selectedText, COLORS.muted)
    frame.selectedText = selectedText

    local manualNote = rightPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    manualNote:SetPoint("TOPLEFT", 12, -31)
    manualNote:SetPoint("RIGHT", -12, 0)
    manualNote:SetHeight(24)
    manualNote:SetJustifyH("LEFT")
    manualNote:SetJustifyV("TOP")
    manualNote:SetWordWrap(true)
    applyFont(manualNote, 11, GameFontDisableSmall)
    setTextColor(manualNote, COLORS.muted)
    manualNote:Hide()
    frame.manualNote = manualNote

    local nameInput = CreateFrame("EditBox", nil, rightPanel)
    nameInput:SetSize(LAYOUT.rightWidth - 24, 28)
    nameInput:SetPoint("TOPLEFT", 12, -55)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(80)
    applyFont(nameInput, 13, ChatFontNormal)
    nameInput:SetTextInsets(10, 10, 0, 0)
    nameInput:SetJustifyV("MIDDLE")

    local inputBackground = nameInput:CreateTexture(nil, "BACKGROUND")
    inputBackground:SetAllPoints()
    setTextureColor(inputBackground, COLORS.input)
    local inputEdges = addBorder(nameInput, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)

    local inputPlaceholder = nameInput:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    inputPlaceholder:SetPoint("LEFT", 10, 0)
    inputPlaceholder:SetText("Profile name")
    applyFont(inputPlaceholder, 12, GameFontDisableSmall)
    nameInput:SetScript("OnTextChanged", function(self)
        inputPlaceholder:SetShown(self:GetText() == "")
    end)
    nameInput:SetScript("OnEditFocusGained", function()
        setBorderColor(inputEdges, COLORS.accentBorder[1], COLORS.accentBorder[2], COLORS.accentBorder[3], 1)
    end)
    nameInput:SetScript("OnEditFocusLost", function()
        setBorderColor(inputEdges, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)
    end)
    nameInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    frame.nameInput = nameInput

    renameButton = createActionButton(rightPanel, "Rename", "secondary")
    renameButton:SetSize(143, LAYOUT.buttonHeight)
    renameButton:SetPoint("TOPLEFT", 12, -89)
    renameButton:SetScript("OnClick", function()
        local profileName = selectedKind == "profile" and selectedId or nil
        local _, message, renamed = UI.RenameSelection(profileName, nameInput:GetText())
        setStatus(message)

        if renamed then
            nameInput:SetText("")
        end
    end)
    frame.renameButton = renameButton

    deleteButton = createActionButton(rightPanel, "Delete", "secondary")
    deleteButton:SetSize(143, LAYOUT.buttonHeight)
    deleteButton:SetPoint("TOPRIGHT", -12, -89)
    deleteButton:SetScript("OnClick", function()
        local profileName = selectedKind == "profile" and selectedId or nil
        local _, message = UI.RequestDeleteSelection(profileName)
        setStatus(message)
    end)
    frame.deleteButton = deleteButton

    local statusLabel = rightPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusLabel:SetPoint("TOPLEFT", 12, -126)
    statusLabel:SetText("STATUS")
    applyFont(statusLabel, 12, GameFontNormalSmall)
    statusLabel:SetTextColor(0.78, 0.82, 0.86)

    local statusPanel = CreateFrame("Frame", nil, rightPanel)
    statusPanel:SetSize(LAYOUT.rightWidth - 24, 42)
    statusPanel:SetPoint("TOPLEFT", 12, -143)
    local statusBackground = statusPanel:CreateTexture(nil, "BACKGROUND")
    statusBackground:SetAllPoints()
    setTextureColor(statusBackground, COLORS.panelDeep)
    addBorder(statusPanel, COLORS.border[1], COLORS.border[2], COLORS.border[3], 1)

    local statusAccent = statusPanel:CreateTexture(nil, "ARTWORK")
    statusAccent:SetPoint("TOPLEFT", 1, -1)
    statusAccent:SetPoint("BOTTOMLEFT", 1, 1)
    statusAccent:SetWidth(2)
    setTextureColor(statusAccent, COLORS.divider)
    frame.statusAccent = statusAccent

    local statusText = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 11, -7)
    statusText:SetPoint("BOTTOMRIGHT", -9, 7)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("TOP")
    statusText:SetWordWrap(true)
    statusText:SetText("Ready")
    applyFont(statusText, 13, GameFontHighlightSmall)
    setTextColor(statusText, COLORS.muted)
    frame.statusText = statusText

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(LAYOUT.footerHeight)
    local footerBackground = footer:CreateTexture(nil, "BACKGROUND")
    footerBackground:SetAllPoints()
    setTextureColor(footerBackground, COLORS.header)
    local footerLine = footer:CreateTexture(nil, "BORDER")
    footerLine:SetPoint("TOPLEFT")
    footerLine:SetPoint("TOPRIGHT")
    footerLine:SetHeight(1)
    setTextureColor(footerLine, COLORS.divider)

    local saveButton = createActionButton(footer, "Save Current", "secondary")
    saveButton:SetSize(154, 29)
    saveButton:SetPoint("LEFT", 15, 0)
    saveButton:SetScript("OnClick", function()
        local name = nameInput:GetText()
        local _, message, saved = UI.SaveCurrent(name)
        setStatus(message)

        if saved then
            selectedKind = "profile"
            selectedId = name
            nameInput:SetText("")
            UI.RefreshProfileList()
        end
    end)
    frame.saveButton = saveButton

    nameInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        saveButton:Click()
    end)

    applyButton = createActionButton(footer, "Apply Profile", "primary")
    applyButton:SetSize(190, 29)
    applyButton:SetPoint("RIGHT", -15, 0)
    applyButton:SetScript("OnClick", function()
        local _, message = UI.ApplySelection(selectedId, selectedKind)
        setStatus(message)
    end)
    frame.applyButton = applyButton

    frame.profileButtons = profileButtons
    frame.presetButtons = presetButtons

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
