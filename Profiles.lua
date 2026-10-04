local _, addon = ...

local PROFILE_CVARS = {
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

local PROFILE_CVAR_SET = {}
for _, cvarName in ipairs(PROFILE_CVARS) do
    PROFILE_CVAR_SET[cvarName] = true
end

local ProfileEngine = {}
addon.ProfileEngine = ProfileEngine

local GATED_CVARS = {
    useMaxFPS = "maxFPS",
    useTargetFPS = "targetFPS",
}

local function newResult()
    return {
        success = false,
        saved = false,
        captured = {},
        applied = {},
        skipped = {},
        errors = {},
    }
end

local function validateProfileName(name)
    if type(name) ~= "string" or name == "" then
        return false, "Enter a profile name.", "profile name must be a non-empty string"
    end

    if not name:find("%S") then
        return false, "Profile name cannot be only whitespace.", "profile name cannot be only whitespace"
    end

    return true
end

function addon.ValidateProfileName(name)
    local valid, message = validateProfileName(name)
    return valid, message
end

local function getProfiles(result)
    if type(RenderSetDB) ~= "table" or type(RenderSetDB.profiles) ~= "table" then
        result.errors.profile = "database is not initialized"
        return nil
    end

    return RenderSetDB.profiles
end

local function readCVar(cvarName)
    return C_CVar.GetCVar(cvarName)
end

local function writeCVar(cvarName, value)
    return C_CVar.SetCVar(cvarName, value)
end

local function applyCVar(result, cvarName, value)
    local writeSucceeded, accepted = pcall(writeCVar, cvarName, value)

    if not writeSucceeded then
        result.errors[cvarName] = tostring(accepted)
        return false
    elseif accepted ~= true then
        result.errors[cvarName] = "write was rejected"
        return false
    end

    local readSucceeded, readback = pcall(readCVar, cvarName)

    if not readSucceeded then
        result.errors[cvarName] = tostring(readback)
        return false
    elseif readback ~= value then
        result.errors[cvarName] = "readback did not match stored value"
        return false
    end

    result.applied[cvarName] = readback
    return true
end

function addon.CaptureProfile(name)
    local result = newResult()

    local valid, _, errorMessage = validateProfileName(name)
    if not valid then
        result.errors.profile = errorMessage
        return result
    end

    local profiles = getProfiles(result)
    if not profiles then
        return result
    end

    if profiles[name] ~= nil then
        result.errors.profile = "profile already exists"
        return result
    end

    local capturedProfile = {}

    for _, cvarName in ipairs(PROFILE_CVARS) do
        local readSucceeded, value = pcall(readCVar, cvarName)

        if not readSucceeded then
            result.errors[cvarName] = tostring(value)
        elseif type(value) ~= "string" then
            result.errors[cvarName] = "read did not return a string"
        else
            capturedProfile[cvarName] = value
            result.captured[cvarName] = value
        end
    end

    if next(capturedProfile) then
        profiles[name] = capturedProfile
        result.saved = true
    end

    result.success = result.saved and not next(result.errors)
    return result
end

function ProfileEngine.ApplyValues(profile)
    local result = newResult()
    for _, cvarName in ipairs(PROFILE_CVARS) do
        local value = profile[cvarName]
        local pairedValueCVar = GATED_CVARS[cvarName]

        if value == nil then
            result.skipped[cvarName] = "profile value is missing"
        elseif type(value) ~= "string" then
            result.errors[cvarName] = "stored value is not a string"
        elseif pairedValueCVar and profile[pairedValueCVar] == nil then
            result.skipped[cvarName] = "paired value is missing"
        elseif pairedValueCVar and result.applied[pairedValueCVar] == nil then
            result.skipped[cvarName] = "paired value was not applied"
        else
            applyCVar(result, cvarName, value)
        end
    end

    result.success = not next(result.errors)
    return result
end

function ProfileEngine.IsSupportedCVar(cvarName)
    return PROFILE_CVAR_SET[cvarName] == true
end

function ProfileEngine.GetSupportedCVarCount()
    return #PROFILE_CVARS
end

function addon.ApplyProfile(name)
    local result = newResult()

    local valid, _, errorMessage = validateProfileName(name)
    if not valid then
        result.errors.profile = errorMessage
        return result
    end

    local profiles = getProfiles(result)
    if not profiles then
        return result
    end

    local profile = profiles[name]
    if type(profile) ~= "table" then
        result.errors.profile = "profile does not exist"
        return result
    end

    return ProfileEngine.ApplyValues(profile)
end

function addon.RenameProfile(oldName, newName)
    local result = {
        success = false,
        renamed = false,
        unchanged = false,
        errors = {},
    }

    local oldValid, _, oldError = validateProfileName(oldName)
    if not oldValid then
        result.errors.oldName = oldError
        return result
    end

    local newValid, _, newError = validateProfileName(newName)
    if not newValid then
        result.errors.newName = newError
        return result
    end

    local profiles = getProfiles(result)
    if not profiles then
        return result
    end

    local profile = profiles[oldName]
    if type(profile) ~= "table" then
        result.errors.profile = "profile does not exist"
        return result
    end

    if oldName == newName then
        result.success = true
        result.unchanged = true
        return result
    end

    if profiles[newName] ~= nil then
        result.errors.profile = "destination profile already exists"
        return result
    end

    profiles[newName] = profile
    profiles[oldName] = nil
    result.success = true
    result.renamed = true
    return result
end

function addon.DeleteProfile(name)
    local result = {
        success = false,
        deleted = false,
        errors = {},
    }

    local valid, _, errorMessage = validateProfileName(name)
    if not valid then
        result.errors.profile = errorMessage
        return result
    end

    local profiles = getProfiles(result)
    if not profiles then
        return result
    end

    if type(profiles[name]) ~= "table" then
        result.errors.profile = "profile does not exist"
        return result
    end

    profiles[name] = nil
    result.success = true
    result.deleted = true
    return result
end

-- Temporary manual test surface until a user-facing profile interface exists.
_G.RenderSetTest = {
    CaptureProfile = addon.CaptureProfile,
    ApplyProfile = addon.ApplyProfile,
    ValidateProfileName = addon.ValidateProfileName,
    RenameProfile = addon.RenameProfile,
    DeleteProfile = addon.DeleteProfile,
}
