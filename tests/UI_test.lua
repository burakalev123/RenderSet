RenderSetDB = {
    schemaVersion = 1,
    profiles = {},
}

RenderSetTest = {}
UIParent = {}
UISpecialFrames = {}

local function newWidget(name, parent)
    local widget = {
        name = name,
        parent = parent,
        shown = true,
        enabled = true,
        scripts = {},
        text = "",
        alpha = 1,
    }

    function widget:SetSize(width, height)
        self.width = width
        self.height = height
    end

    function widget:SetWidth(width)
        self.width = width
    end

    function widget:SetHeight(height)
        self.height = height
    end

    function widget:SetPoint(...)
        self.point = { ... }
    end

    function widget:ClearAllPoints()
        self.point = nil
    end

    function widget:SetAllPoints()
        self.allPoints = true
    end

    function widget:SetColorTexture(...)
        self.color = { ... }
    end

    function widget:SetText(text)
        self.text = text
        if self.scripts.OnTextChanged then
            self.scripts.OnTextChanged(self)
        end
    end

    function widget:GetText()
        return self.text
    end

    function widget:SetTextColor(...)
        self.textColor = { ... }
    end

    function widget:SetJustifyH(justification)
        self.justification = justification
    end

    function widget:SetJustifyV(justification)
        self.verticalJustification = justification
    end

    function widget:SetWordWrap(wordWrap)
        self.wordWrap = wordWrap
    end

    function widget:SetFontString(fontString)
        self.fontString = fontString
    end

    function widget:SetFontObject(fontObject)
        self.fontObject = fontObject
    end

    function widget:SetFont(path, size, flags)
        self.font = { path, size, flags }
        return true
    end

    function widget:SetTextInsets(...)
        self.textInsets = { ... }
    end

    function widget:SetAlpha(alpha)
        self.alpha = alpha
    end

    function widget:SetScript(scriptName, callback)
        self.scripts[scriptName] = callback
    end

    function widget:GetScript(scriptName)
        return self.scripts[scriptName]
    end

    function widget:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end

    function widget:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then
            self.scripts.OnHide(self)
        end
    end

    function widget:SetShown(shown)
        if shown then
            self:Show()
        else
            self:Hide()
        end
    end

    function widget:IsShown()
        return self.shown
    end

    function widget:Enable()
        self.enabled = true
    end

    function widget:Disable()
        self.enabled = false
    end

    function widget:IsEnabled()
        return self.enabled
    end

    function widget:Click()
        if self.enabled and self.scripts.OnClick then
            self.scripts.OnClick(self)
        end
    end

    function widget:CreateTexture(textureName)
        return newWidget(textureName, self)
    end

    function widget:CreateFontString(fontName)
        return newWidget(fontName, self)
    end

    function widget:SetFrameStrata() end
    function widget:SetClampedToScreen() end
    function widget:EnableMouse() end
    function widget:EnableMouseWheel() end
    function widget:SetMovable() end
    function widget:RegisterForDrag() end
    function widget:StartMoving() end
    function widget:StopMovingOrSizing() end
    function widget:SetAutoFocus() end
    function widget:SetMaxLetters() end
    function widget:ClearFocus() end
    function widget:SetScrollChild(child)
        self.scrollChild = child
    end
    function widget:SetVerticalScroll(value)
        self.verticalScroll = value
        if self.scripts.OnVerticalScroll and not self.updatingVerticalScroll then
            self.updatingVerticalScroll = true
            self.scripts.OnVerticalScroll(self, value)
            self.updatingVerticalScroll = false
        end
    end
    function widget:GetVerticalScroll()
        return self.verticalScroll or 0
    end
    function widget:Raise() end
    function widget:GetName()
        return self.name
    end

    return widget
end

function CreateFrame(_, name, parent, template)
    local widget = newWidget(name, parent)
    widget.template = template
    return widget
end

local captureCalls = {}
local applyCalls = {}
local presetApplyCalls = {}
local renameCalls = {}
local deleteCalls = {}
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
    applied = {
        a = "1", b = "2", c = "3", d = "4", e = "5", f = "6",
        g = "7", h = "8", i = "9", j = "10", k = "11",
        l = "12", m = "13", n = "14", o = "15", p = "16", q = "17",
        r = "18", s = "19", t = "20", u = "21", v = "22", w = "23",
        x = "24", y = "25",
    },
    skipped = {},
    errors = {},
}
local presetApplyResult = {
    success = true,
    saved = false,
    captured = {},
    applied = {
        a = "1", b = "2", c = "3", d = "4", e = "5", f = "6",
        g = "7", h = "8", i = "9", j = "10", k = "11",
        l = "12", m = "13", n = "14", o = "15", p = "16", q = "17",
        r = "18", s = "19", t = "20", u = "21", v = "22", w = "23",
        x = "24",
    },
    skipped = {},
    errors = {},
}

local function validateProfileName(name)
    if type(name) ~= "string" or name == "" then
        return false, "Enter a profile name."
    end
    if not name:find("%S") then
        return false, "Profile name cannot be only whitespace."
    end
    return true
end

local addon = {
    BuiltinPresets = {
        {
            id = "macbook_internal_balanced",
            name = "MacBook Pro Internal — Balanced",
            shortName = "MacBook Pro — Balanced",
            manualNote = "Manual: macOS Display Default · WoW Windowed",
        },
        {
            id = "external_1440p_balanced",
            name = "1440p External — Balanced",
            shortName = "1440p External — Balanced",
            manualNote = "Manual: 2560×1440 · 75 Hz display settings are not managed by RenderSet",
        },
    },
    ValidateProfileName = validateProfileName,
    CaptureProfile = function(name)
        captureCalls[#captureCalls + 1] = name
        if RenderSetDB.profiles[name] ~= nil then
            return {
                success = false,
                saved = false,
                captured = {},
                applied = {},
                skipped = {},
                errors = { profile = "profile already exists" },
            }
        end
        RenderSetDB.profiles[name] = { graphicsShadowQuality = "2" }
        return captureResult
    end,
    ApplyProfile = function(name)
        applyCalls[#applyCalls + 1] = name
        return applyResult
    end,
    ApplyBuiltInPreset = function(id)
        presetApplyCalls[#presetApplyCalls + 1] = id
        return presetApplyResult
    end,
    RenameProfile = function(oldName, newName)
        renameCalls[#renameCalls + 1] = { oldName, newName }
        if oldName == newName then
            return { success = true, renamed = false, unchanged = true, errors = {} }
        elseif RenderSetDB.profiles[newName] ~= nil then
            return {
                success = false,
                renamed = false,
                unchanged = false,
                errors = { profile = "destination profile already exists" },
            }
        end
        local profile = RenderSetDB.profiles[oldName]
        RenderSetDB.profiles[newName] = profile
        RenderSetDB.profiles[oldName] = nil
        return { success = true, renamed = true, unchanged = false, errors = {} }
    end,
    DeleteProfile = function(name)
        deleteCalls[#deleteCalls + 1] = name
        RenderSetDB.profiles[name] = nil
        return { success = true, deleted = true, errors = {} }
    end,
}

function addon.GetBuiltInPreset(id)
    for _, preset in ipairs(addon.BuiltinPresets) do
        if preset.id == id then
            return preset
        end
    end
end

local chunk = assert(loadfile("UI.lua"))
chunk("RenderSet", addon)

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

local function assertContains(value, expected, message)
    if not string.find(value, expected, 1, true) then
        fail((message or "text not found") .. ": expected " .. expected .. " in " .. value)
    end
end

local function resetProfiles(profiles)
    RenderSetDB = {
        schemaVersion = 1,
        profiles = profiles or {},
    }
    addon.UI.SelectProfile(nil)
end

local function getFrame()
    return RenderSetTest.GetUIFrame()
end

local tests = {}

function tests.profile_names_are_sorted()
    resetProfiles({ Zebra = {}, Alpha = {}, Middle = {} })

    local names = addon.UI.GetSortedProfileNames()
    assertEqual(#names, 3)
    assertEqual(names[1], "Alpha")
    assertEqual(names[2], "Middle")
    assertEqual(names[3], "Zebra")
end

function tests.ui_creation_succeeds()
    resetProfiles({})
    addon.UI.Show()

    local currentFrame = getFrame()
    assertTrue(currentFrame ~= nil)
    assertTrue(currentFrame:IsShown())
    assertEqual(UISpecialFrames[#UISpecialFrames], "RenderSetFrame")
end

function tests.show_hide_and_toggle_work()
    resetProfiles({})
    addon.UI.Show()
    assertTrue(getFrame():IsShown())

    addon.UI.Hide()
    assertFalse(getFrame():IsShown())

    addon.UI.Toggle()
    assertTrue(getFrame():IsShown())

    addon.UI.Toggle()
    assertFalse(getFrame():IsShown())
end

function tests.custom_close_button_hides_frame()
    resetProfiles({})
    addon.UI.Show()

    local currentFrame = getFrame()
    assertEqual(currentFrame.closeButton.template, nil)
    currentFrame.closeButton:Click()
    assertFalse(currentFrame:IsShown())
end

function tests.empty_profile_state_is_visible_and_actions_are_disabled()
    resetProfiles({})
    addon.UI.Show()

    local currentFrame = getFrame()
    assertTrue(currentFrame.emptyText:IsShown())
    assertEqual(currentFrame.profileCountText:GetText(), "0 profiles")
    assertTrue(currentFrame.applyButton:IsEnabled())
    assertFalse(currentFrame.renameButton:IsEnabled())
    assertFalse(currentFrame.deleteButton:IsEnabled())
    assertTrue(currentFrame.saveButton:IsEnabled())
    assertEqual(select(1, addon.UI.GetSelection()), "preset")
end

function tests.built_in_rows_render_above_sorted_user_profiles()
    resetProfiles({ Zebra = {}, Alpha = {} })
    addon.UI.Show()

    local currentFrame = getFrame()
    assertEqual(currentFrame.presetButtons[1].selectionId, "macbook_internal_balanced")
    assertEqual(currentFrame.presetButtons[2].selectionId, "external_1440p_balanced")
    assertEqual(currentFrame.profileButtons[1].profileName, "Alpha")
    assertEqual(currentFrame.profileButtons[2].profileName, "Zebra")
    assertTrue(currentFrame.presetButtons[2].point[3] > currentFrame.profileButtons[1].point[3])
end

function tests.preset_selection_updates_title_note_and_action_states()
    resetProfiles({ Quality = {} })
    addon.UI.Show()

    local currentFrame = getFrame()
    currentFrame.presetButtons[1]:Click()
    local kind, id = addon.UI.GetSelection()
    assertEqual(kind, "preset")
    assertEqual(id, "macbook_internal_balanced")
    assertEqual(currentFrame.selectionLabel:GetText(), "PRESET")
    assertEqual(currentFrame.selectedText:GetText(), "MacBook Pro Internal — Balanced")
    assertContains(currentFrame.manualNote:GetText(), "macOS Display Default")
    assertTrue(currentFrame.manualNote:IsShown())
    assertTrue(currentFrame.applyButton:IsEnabled())
    assertFalse(currentFrame.renameButton:IsEnabled())
    assertFalse(currentFrame.deleteButton:IsEnabled())

    currentFrame.presetButtons[2]:Click()
    assertContains(currentFrame.manualNote:GetText(), "2560×1440")
    assertContains(currentFrame.manualNote:GetText(), "75 Hz")

    currentFrame.profileButtons[1]:Click()
    assertEqual(select(1, addon.UI.GetSelection()), "profile")
    assertEqual(addon.UI.GetSelectedProfile(), "Quality")
    assertFalse(currentFrame.manualNote:IsShown())
    assertTrue(currentFrame.renameButton:IsEnabled())
    assertTrue(currentFrame.deleteButton:IsEnabled())
end

function tests.profile_rows_render_and_selection_updates_immediately()
    resetProfiles({ Beta = {}, Alpha = {} })
    addon.UI.Show()

    local currentFrame = getFrame()
    assertFalse(currentFrame.emptyText:IsShown())
    assertEqual(currentFrame.profileCountText:GetText(), "2 profiles")
    assertEqual(currentFrame.profileButtons[1].profileName, "Alpha")
    assertEqual(currentFrame.profileButtons[2].profileName, "Beta")
    assertEqual(addon.UI.GetSelectedProfile(), "Alpha")
    assertEqual(currentFrame.selectedText:GetText(), "Alpha")
    assertTrue(currentFrame.profileButtons[1].selectedTexture:IsShown())

    currentFrame.profileButtons[2]:Click()
    assertEqual(addon.UI.GetSelectedProfile(), "Beta")
    assertEqual(currentFrame.selectedText:GetText(), "Beta")
    assertFalse(currentFrame.profileButtons[1].selectedTexture:IsShown())
    assertTrue(currentFrame.profileButtons[2].selectedTexture:IsShown())
end

function tests.custom_scroll_structure_handles_overflow_and_wheel_input()
    resetProfiles({
        Alpha = {}, Beta = {}, Charlie = {}, Delta = {}, Echo = {},
        Foxtrot = {}, Golf = {}, Hotel = {}, India = {},
    })
    addon.UI.Show()

    local currentFrame = getFrame()
    assertEqual(currentFrame.profileScroll.template, nil)
    assertTrue(currentFrame.scrollTrack:IsShown())
    assertTrue(currentFrame.profileScroll.maxScroll > 0)
    currentFrame.profileScroll:GetScript("OnMouseWheel")(currentFrame.profileScroll, -1)
    assertTrue(currentFrame.profileScroll:GetVerticalScroll() > 0)

    resetProfiles({ Alpha = {} })
    addon.UI.RefreshProfileList()
    assertFalse(currentFrame.scrollTrack:IsShown())
    assertEqual(currentFrame.profileScroll:GetVerticalScroll(), 0)
end

function tests.action_buttons_follow_selection_state()
    resetProfiles({ Quality = {} })
    addon.UI.Show()

    local currentFrame = getFrame()
    assertTrue(currentFrame.applyButton:IsEnabled())
    assertTrue(currentFrame.renameButton:IsEnabled())
    assertTrue(currentFrame.deleteButton:IsEnabled())

    addon.UI.SelectProfile(nil)
    assertFalse(currentFrame.applyButton:IsEnabled())
    assertFalse(currentFrame.renameButton:IsEnabled())
    assertFalse(currentFrame.deleteButton:IsEnabled())
end

function tests.duplicate_name_delegates_to_engine_protection()
    resetProfiles({ Existing = {} })
    captureCalls = {}

    local result, message, saved = addon.UI.SaveCurrent("Existing")
    assertFalse(result.success)
    assertFalse(saved)
    assertEqual(#captureCalls, 1)
    assertEqual(message, "Profile already exists.")
end

function tests.new_profile_delegates_to_capture()
    resetProfiles({})
    captureCalls = {}

    local result, message, saved = addon.UI.SaveCurrent("New Profile")
    assertEqual(result, captureResult)
    assertTrue(saved)
    assertEqual(#captureCalls, 1)
    assertEqual(captureCalls[1], "New Profile")
    assertEqual(message, "Saved New Profile.")
    assertEqual(addon.UI.SummarizeCapture(captureResult), "Profile saved.")
end

function tests.shared_validation_rejects_whitespace_save_name()
    resetProfiles({})
    captureCalls = {}

    local result, message, saved = addon.UI.SaveCurrent("   ")
    assertEqual(result, nil)
    assertFalse(saved)
    assertEqual(#captureCalls, 0)
    assertEqual(message, "Profile name cannot be only whitespace.")
end

function tests.apply_delegates_to_engine()
    applyCalls = {}

    local result, message = addon.UI.ApplySelection("Quality")
    assertEqual(result, applyResult)
    assertEqual(#applyCalls, 1)
    assertEqual(applyCalls[1], "Quality")
    assertEqual(message, "Applied Quality — 25 settings.")
end

function tests.preset_apply_delegates_to_builtin_engine()
    presetApplyCalls = {}

    local result, message = addon.UI.ApplySelection("external_1440p_balanced", "preset")
    assertEqual(result, presetApplyResult)
    assertEqual(#presetApplyCalls, 1)
    assertEqual(presetApplyCalls[1], "external_1440p_balanced")
    assertEqual(message, "Applied 1440p External — Balanced — 24 settings.")
end

function tests.apply_without_selection_does_not_call_engine()
    applyCalls = {}

    local result, message = addon.UI.ApplySelection(nil)
    assertEqual(result, nil)
    assertEqual(#applyCalls, 0)
    assertEqual(message, "Select a profile first.")
end

function tests.rename_delegates_to_engine_and_updates_selection()
    resetProfiles({ Quality = { graphicsShadowQuality = "3" } })
    renameCalls = {}
    addon.UI.SelectProfile("Quality")

    local result, message, renamed = addon.UI.RenameSelection("Quality", "My Quality")
    assertTrue(result.success)
    assertTrue(renamed)
    assertEqual(message, "Renamed Quality → My Quality.")
    assertEqual(#renameCalls, 1)
    assertEqual(renameCalls[1][1], "Quality")
    assertEqual(renameCalls[1][2], "My Quality")
    assertEqual(addon.UI.GetSelectedProfile(), "My Quality")
    assertEqual(RenderSetDB.selectedProfile, nil)
    assertEqual(RenderSetDB.activeProfile, nil)
end

function tests.delete_requires_confirmation_and_updates_selection()
    resetProfiles({ Alpha = {}, Beta = {} })
    deleteCalls = {}
    addon.UI.Show()
    addon.UI.SelectProfile("Beta")

    local firstResult, firstMessage, firstDeleted = addon.UI.RequestDeleteSelection("Beta")
    assertEqual(firstResult, nil)
    assertContains(firstMessage, "Confirm deletion")
    assertFalse(firstDeleted)
    assertEqual(getFrame().deleteButton:GetText(), "Confirm Delete")
    assertEqual(#deleteCalls, 0)

    local secondResult, secondMessage, secondDeleted = addon.UI.RequestDeleteSelection("Beta")
    assertTrue(secondResult.success)
    assertEqual(secondMessage, "Deleted Beta.")
    assertTrue(secondDeleted)
    assertEqual(#deleteCalls, 1)
    assertEqual(deleteCalls[1], "Beta")
    assertEqual(addon.UI.GetSelectedProfile(), "Alpha")
end

function tests.changing_selection_cancels_pending_delete()
    resetProfiles({ Alpha = {}, Beta = {} })
    deleteCalls = {}
    addon.UI.Show()
    addon.UI.SelectProfile("Beta")
    addon.UI.RequestDeleteSelection("Beta")
    addon.UI.SelectProfile("Alpha")

    assertEqual(getFrame().deleteButton:GetText(), "Delete")
    local result, message = addon.UI.RequestDeleteSelection("Alpha")
    assertEqual(result, nil)
    assertContains(message, "Confirm deletion")
    assertEqual(#deleteCalls, 0)
    assertTrue(RenderSetDB.profiles.Beta ~= nil)
end

function tests.hiding_frame_cancels_pending_delete()
    resetProfiles({ Alpha = {} })
    deleteCalls = {}
    addon.UI.Show()
    addon.UI.SelectProfile("Alpha")
    addon.UI.RequestDeleteSelection("Alpha")
    assertEqual(getFrame().deleteButton:GetText(), "Confirm Delete")

    addon.UI.Hide()
    assertEqual(getFrame().deleteButton:GetText(), "Delete")
    addon.UI.Show()

    local result = addon.UI.RequestDeleteSelection("Alpha")
    assertEqual(result, nil)
    assertEqual(#deleteCalls, 0)
end

function tests.status_area_uses_engine_result_summary()
    resetProfiles({ Quality = {} })
    applyCalls = {}
    addon.UI.Show()
    addon.UI.SelectProfile("Quality")

    getFrame().applyButton:Click()
    assertEqual(getFrame().statusText:GetText(), "Applied Quality — 25 settings.")
    assertEqual(#applyCalls, 1)
end

function tests.profile_list_refreshes_after_save_rename_and_delete()
    resetProfiles({})
    captureCalls = {}
    renameCalls = {}
    deleteCalls = {}
    addon.UI.Show()

    local currentFrame = getFrame()
    assertEqual(select(1, addon.UI.GetSelection()), "preset")
    currentFrame.nameInput:SetText("Quality")
    currentFrame.saveButton:Click()
    assertEqual(currentFrame.profileButtons[1].profileName, "Quality")
    assertFalse(currentFrame.emptyText:IsShown())

    currentFrame.nameInput:SetText("Raid")
    currentFrame.renameButton:Click()
    assertEqual(currentFrame.profileButtons[1].profileName, "Raid")
    assertEqual(addon.UI.GetSelectedProfile(), "Raid")

    currentFrame.deleteButton:Click()
    currentFrame.deleteButton:Click()
    assertTrue(currentFrame.emptyText:IsShown())
    assertEqual(addon.UI.GetSelectedProfile(), nil)
    assertEqual(#captureCalls, 1)
    assertEqual(#renameCalls, 1)
    assertEqual(#deleteCalls, 1)
end

function tests.result_summaries_cover_success_skips_and_errors()
    local full = addon.UI.SummarizeApply("A", {
        applied = {
            a = "1", b = "2", c = "3", d = "4", e = "5", f = "6",
            g = "7", h = "8", i = "9", j = "10", k = "11",
            l = "12", m = "13", n = "14", o = "15", p = "16", q = "17",
            r = "18", s = "19", t = "20", u = "21", v = "22", w = "23",
            x = "24", y = "25",
        },
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

    assertEqual(full, "Applied A — 25 settings.")
    assertContains(skipped, "3 applied, 1 skipped")
    assertContains(failed, "1 error")
end

function tests.toggle_api_is_exposed_for_user_entry_points()
    assertEqual(type(addon.UI.Show), "function")
    assertEqual(type(addon.UI.Hide), "function")
    assertEqual(type(addon.UI.Toggle), "function")
end

function tests.selection_is_transient_and_not_persisted()
    resetProfiles({ Quality = {} })
    addon.UI.SelectProfile("Quality")

    assertEqual(addon.UI.GetSelectedProfile(), "Quality")
    assertEqual(RenderSetDB.selectedProfile, nil)
    assertEqual(RenderSetDB.activeProfile, nil)

    addon.UI.SelectBuiltInPreset("macbook_internal_balanced")
    assertEqual(select(1, addon.UI.GetSelection()), "preset")
    assertEqual(RenderSetDB.selectedPreset, nil)
    assertEqual(RenderSetDB.activePreset, nil)
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
