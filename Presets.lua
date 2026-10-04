local _, addon = ...

local BuiltinPresets = {
    {
        id = "macbook_internal_balanced",
        name = "MacBook Pro Internal — Balanced",
        shortName = "MacBook Pro — Balanced",
        manualNote = "Manual: macOS Display Default · WoW Windowed",
        values = {
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
            ResampleAlwaysSharpen = "1",
            vsync = "0",
            RenderScale = "0.75",
            ResampleQuality = "3",
            textureFilteringMode = "5",
            ffxAntiAliasingMode = "4",
            graphicsLightMode = "0",
            graphicsPBRLiquidDetail = "2",
            graphicsBloomUserMult = "1",
            maxFPS = "60",
            useMaxFPS = "1",
            targetFPS = "60",
            useTargetFPS = "0",
        },
    },
    {
        id = "external_1440p_balanced",
        name = "1440p External — Balanced",
        shortName = "1440p External — Balanced",
        manualNote = "Manual: 2560×1440 · 75 Hz display settings are not managed by RenderSet",
        values = {
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
            ResampleAlwaysSharpen = "0",
            vsync = "0",
            RenderScale = "1.0",
            ResampleQuality = "3",
            textureFilteringMode = "5",
            ffxAntiAliasingMode = "4",
            graphicsLightMode = "0",
            graphicsPBRLiquidDetail = "2",
            graphicsBloomUserMult = "1",
            maxFPS = "75",
            useMaxFPS = "1",
            targetFPS = "60",
            useTargetFPS = "0",
        },
    },
}

local presetsById = {}
for _, preset in ipairs(BuiltinPresets) do
    assert(type(preset.id) == "string" and presetsById[preset.id] == nil, "invalid built-in preset id")
    assert(type(preset.values) == "table", "invalid built-in preset values")

    local valueCount = 0
    for cvarName, value in pairs(preset.values) do
        assert(addon.ProfileEngine.IsSupportedCVar(cvarName), "unsupported built-in preset CVar: " .. cvarName)
        assert(type(value) == "string", "built-in preset values must be raw strings")
        valueCount = valueCount + 1
    end

    assert(valueCount == addon.ProfileEngine.GetSupportedCVarCount(), "built-in preset must define every supported CVar")
    presetsById[preset.id] = preset
end

addon.BuiltinPresets = BuiltinPresets

function addon.GetBuiltInPreset(presetId)
    return presetsById[presetId]
end

function addon.ApplyBuiltInPreset(presetId)
    local preset = presetsById[presetId]
    if not preset then
        return {
            success = false,
            saved = false,
            captured = {},
            applied = {},
            skipped = {},
            errors = { preset = "built-in preset does not exist" },
        }
    end

    return addon.ProfileEngine.ApplyValues(preset.values)
end
