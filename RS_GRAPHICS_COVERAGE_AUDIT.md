# RenderSet — WoW Forever Graphics Coverage Audit

Date: 2026-10-04 (Europe/Amsterdam)
Task: graphics coverage audit, updated with completed build-70170 validation

## Executive conclusion

RenderSet 0.1.0 shipped with four accepted CVars. Burak subsequently completed
targeted in-game validation that now supports 25 production raw CVars across 23
user-facing controls/control families. This audit identified 64 user-facing or
plausibly user-facing graphics controls/control families in the current Forever
client and mapped 63 of them to a CVar or CVar pair/family. The unresolved mapping
is a dedicated refresh-rate control on this macOS client; the active refresh rate
is visible in `gx.log`, but no separate user CVar was established.

The classification across the 66 audit rows below is:

- **VERIFIED SAFE:** 23
- **SAFE CANDIDATE:** 4
- **NEEDS RUNTIME VALIDATION:** 27
- **EXCLUDE:** 12

The two rows beyond the 64 user-facing/plausibly user-facing controls are the
hardware-detection state and the derived low-level CVar family. They are included
to make the intentional RenderSet boundary explicit.

## 1. Current state

- Checkout: `/Users/burakalev/Documents/GitHub/RenderSet`
- Branch: `main`
- Starting HEAD: `753db4d9c5504cd06393dce911c62a4bdc3493b8`
- Starting status: `main...origin/main` plus unrelated untracked `.DS_Store`
- Addon version: `0.1.0`
- TOC interface: `16001`
- SavedVariables schema: `schemaVersion = 1`
- Runtime allowlist in `Profiles.lua`:
  - `graphicsShadowQuality`
  - `graphicsProjectedTextures`
  - `graphicsParticleDensity`
  - `graphicsLiquidDetail`
  - `graphicsSSAO`
  - `graphicsDepthEffects`
  - `graphicsComputeEffects`
  - `graphicsGroundClutter`
  - `graphicsEnvironmentDetail`
  - `graphicsViewDistance`
  - `graphicsTextureResolution`
  - `graphicsSpellDensity`
  - `ResampleAlwaysSharpen`
  - `vsync`
  - `RenderScale`
  - `ResampleQuality`
  - `textureFilteringMode`
  - `ffxAntiAliasingMode`
  - `graphicsLightMode`
  - `graphicsPBRLiquidDetail`
  - `graphicsBloomUserMult`
  - `maxFPS`
  - `useMaxFPS`
  - `targetFPS`
  - `useTargetFPS`

The 25-CVar development allowlist retains the existing profile format and schema
version 1. `graphicsOutlineMode` is no longer allowlisted because the current
Forever Graphics UI has no user-facing Outline Mode control. Historical stored
keys are preserved and ignored during apply.

## 2. Client and evidence baseline

### Current local client

- Flavor: `_classic_beta_`; `.flavor.info` contains `wow_classic_beta`.
- Application: `World of Warcraft Beta.app`.
- `Info.plist`: version `1.60.1`, bundle build `1.60.1.70170`.
- Latest `Logs/gx.log`: `World of Warcraft Beta ARM64 1.60.1.70170`.
- Latest log/config timestamps inspected: 2026-10-02.
- Interface baseline: `16001`.
- Renderer observed in `gx.log`: Apple M4 Pro / Metal, one 2056x1329
  monitor at 120 Hz.

### Evidence levels used here

1. **Accepted in-game evidence** — Burak's RS-8 validation on build 70170.
2. **Current-client static evidence** — binary CVar names/descriptions,
   `Config.wtf`, `gx.log`, application metadata.
3. **Local add-on source evidence** — installed third-party add-ons that read,
   write, back up, and restore current-client CVars. This proves local code usage,
   not Blizzard support or successful execution.
4. **Prior discovery evidence** — `RS-1_DISCOVERY.md`, reinterpreted under the
   stricter classifications in this document.

No Blizzard Graphics Settings Lua/XML implementation was exposed as ordinary
files in the installed client. The files named
`Blizzard_SettingsDefinitions_Shared.lua` under `WTF` are empty SavedVariables
containers (`NewSettingsSeen = {}`), not Settings definitions. Therefore exact
widget order, dropdown labels, and enum label-to-value mappings that cannot be
recovered from current-client evidence remain unverified. Retail FrameXML was
not used as authority.

### Current Forever CVar API evidence

The current binary exposes these signatures:

```text
C_CVar.GetCVar(name) -> value
C_CVar.GetCVarDefault(name) -> defaultValue
C_CVar.GetCVarInfo(name) -> value, defaultValue,
  isStoredServerAccount, isStoredServerCharacter,
  isLockedFromUser, isSecure, isReadOnly
C_CVar.SetCVar(name[, value]) -> success
```

Forever's `GetCVarInfo` signature does **not** expose help text, category,
numeric range, or enum labels. RS-1 recorded live metadata only for
`graphicsShadowQuality`. The production allowlist contains 25 raw CVars because
Burak completed the required read/write/readback/Blizzard UI/restore validation
on build 70170. No equivalent runtime evidence exists for the remaining
candidates.

## 3. Complete practical inventory

`Config` below means the current build-70170 `_classic_beta_/WTF/Config.wtf`.
`Binary map` means the current executable directly groups a high-level graphics
CVar with one or more lower-level engine CVars. Raw integer dropdown meanings
are intentionally left unknown unless current evidence states them.

| # | UI Setting | CVar/API | Current Evidence | Value Shape | Classification | Risk / Notes | Runtime Test Needed |
|---:|---|---|---|---|---|---|---|
| 1 | Graphics Quality (master) | `graphicsQuality` | Binary: “save for Graphics Quality Selection”; Config `7` | Integer preset; labels/range unknown | EXCLUDE | Derived preset writes groups of individual settings; would create a second source of truth | No direct-write test; observe only |
| 2 | Texture Resolution | `graphicsTextureResolution` → `terrainMipLevel`, `worldBaseMip` | Burak build-70170 set/readback/UI/restore; `2` = High | Integer quality enum | VERIFIED SAFE | High-level wrapper is preferable to derived children | None for current build |
| 3 | Spell Density | `graphicsSpellDensity` → `spellClutter` | Burak build-70170 set/readback/UI/restore; `0` = Essential | Integer enum | VERIFIED SAFE | Base wrapper passed the full profile-safety path | None for current build |
| 4 | Projected Textures | `graphicsProjectedTextures` → `projectedTextures` | RS-8 set/readback/UI/restore; Config `1` | Boolean-like `0/1` | VERIFIED SAFE | Accepted RenderSet 0.1.0 behavior | None for current build |
| 5 | View Distance | `graphicsViewDistance` → multiple distance/LOD CVars | Burak build-70170 set/readback/UI/restore; `6` = UI 7 | Integer quality enum | VERIFIED SAFE | High-level wrapper fans out to derived values | None for current build |
| 6 | Ground Clutter | `graphicsGroundClutter` → `groundEffectDist`, `groundEffectDensity` | Burak build-70170 set/readback/UI/restore; `4` = UI 5 | Integer quality enum | VERIFIED SAFE | One UI control writes multiple derived children | None for current build |
| 7 | Environment Detail | `graphicsEnvironmentDetail` → object LOD CVars | Burak build-70170 set/readback/UI/restore; `6` = UI 7 | Integer quality enum | VERIFIED SAFE | One UI control writes multiple derived children | None for current build |
| 8 | Shadow Quality | `graphicsShadowQuality` → shadow family | RS-8 set/readback/UI/restore; Config `3`; prior live metadata unrestricted | Integer quality enum; low-level `shadowMode` says `0-3` but wrapper range not proven | VERIFIED SAFE | Store wrapper, never low-level children | None for current build |
| 9 | Liquid Detail | `graphicsLiquidDetail` → water/reflection/ripple family | Burak build-70170 set/readback/UI/restore; `2` = Good | Integer quality enum | VERIFIED SAFE | High-level wrapper passed the full profile-safety path | None for current build |
| 10 | PBR Liquid Detail | `graphicsPBRLiquidDetail` → `pbrLiquidDetail` | Burak build-70170 set/readback/UI/restore; `2` = Ultra | Integer quality enum | VERIFIED SAFE | Forever-specific wrapper passed the full profile-safety path | None for current build |
| 11 | Particle Density | `graphicsParticleDensity` → particle density family | Burak build-70170 set/readback/UI/restore; `4` = High | Integer quality enum | VERIFIED SAFE | Accepted RenderSet 0.1.0 behavior | None for current build |
| 12 | SSAO | `graphicsSSAO` → `SSAO` | Burak build-70170 set/readback/UI/restore; `1` = Low, `2` = Good | Integer mode | VERIFIED SAFE | Validated current-client enum values | None for current build |
| 13 | Depth Effects | `graphicsDepthEffects` → sun shafts/refraction/depth opacity | Burak build-70170 set/readback/UI/restore; `2` = Good | Integer quality enum | VERIFIED SAFE | One wrapper fans out to several effects | None for current build |
| 14 | Compute Effects | `graphicsComputeEffects` → volume fog/particulates/clustered shading | Burak build-70170 set/readback/UI/restore; `2` = Good | Integer quality enum | VERIFIED SAFE | Multi-effect wrapper passed the full profile-safety path | None for current build |
| 15 | Outline Mode | `graphicsOutlineMode` → `OutlineEngineMode` | Raw CVar passed write/readback/restore, but the current Forever Graphics UI has no user-facing control | Integer mode | EXCLUDE | Hidden/internal/legacy state; historical profile keys are preserved but ignored | No production write |
| 16 | Light Mode | `graphicsLightMode` | Burak build-70170 set/readback/UI/restore; `0` = Secondary Lighting: Fair | Integer enum | VERIFIED SAFE | User-facing wrapper passed the full profile-safety path | None for current build |
| 17 | Bloom Intensity | `graphicsBloomUserMult` → `bloomUserMult` | Burak build-70170 set/readback/UI/restore; `1` = High | Numeric multiplier | VERIFIED SAFE | User-facing wrapper passed the full profile-safety path | None for current build |
| 18 | Global Illumination Quality | `giQuality` | Binary description; Config `1` | Integer quality enum | NEEDS RUNTIME VALIDATION | No `graphicsGIQuality` wrapper observed; performance/feature dependency unknown | Metadata/UI inspection before write |
| 19 | Use Raid/Battleground Settings | `RAIDsettingsEnabled` | Binary: raid settings available; local optimizer writes `0` | Boolean-like gate | NEEDS RUNTIME VALIDATION | Governs whether the independent RAID family is active; must be tested with context transition | Metadata, UI gate, instance behavior |
| 20 | Raid Graphics Quality (master) | `RAIDgraphicsQuality` | Binary: “save for Raid Graphics Quality Selection”; Config `5` | Integer preset | EXCLUDE | Derived raid preset; profile individual raid wrappers instead if validated | Observe only |
| 21 | Raid Texture Resolution | `raidGraphicsTextureResolution` → RAID texture children | Binary map; Config `2` | Integer quality enum | NEEDS RUNTIME VALIDATION | Independent persisted raid wrapper; effective only when raid settings gate is active | Metadata/UI/context/readback |
| 22 | Raid Spell Density | `raidGraphicsSpellDensity` → `RAIDspellClutter` | Binary map; Config `1` | Integer enum | NEEDS RUNTIME VALIDATION | Context/gate and label mapping unverified | Metadata/UI/context/readback |
| 23 | Raid Projected Textures | `raidGraphicsProjectedTextures` → `RAIDprojectedTextures` | Binary map; Config `1` | Boolean-like | NEEDS RUNTIME VALIDATION | Base equivalent is verified, raid variant is not | Metadata/UI/context/readback |
| 24 | Raid View Distance | `raidGraphicsViewDistance` → RAID distance/LOD family | Binary map; Config `5` | Integer quality enum | NEEDS RUNTIME VALIDATION | Multiple derived children and instance gate | Metadata/UI/context/readback |
| 25 | Raid Ground Clutter | `raidGraphicsGroundClutter` → RAID ground family | Binary map; Config `5` | Integer quality enum | NEEDS RUNTIME VALIDATION | Context/gate behavior unverified | Metadata/UI/context/readback |
| 26 | Raid Environment Detail | `raidGraphicsEnvironmentDetail` → RAID object LOD family | Binary map; Config `5` | Integer quality enum | NEEDS RUNTIME VALIDATION | Context/gate behavior unverified | Metadata/UI/context/readback |
| 27 | Raid Shadow Quality | `raidGraphicsShadowQuality` → RAID shadow family | Binary map; Config `3` | Integer quality enum | NEEDS RUNTIME VALIDATION | Base equivalent is verified, raid variant is not | Metadata/UI/context/readback |
| 28 | Raid Liquid Detail | `raidGraphicsLiquidDetail` → RAID water family | Binary map; Config `2` | Integer quality enum | NEEDS RUNTIME VALIDATION | Context/gate behavior unverified | Metadata/UI/context/readback |
| 29 | Raid PBR Liquid Detail | `raidGraphicsPBRLiquidDetail` → `RAIDpbrLiquidDetail` | Binary map; Config `1` | Integer quality enum | NEEDS RUNTIME VALIDATION | Relationship to raid Liquid Detail unclear | Metadata/UI dependency/context |
| 30 | Raid Particle Density | `raidGraphicsParticleDensity` → RAID particle family | Binary map; Config `4` | Integer quality enum | NEEDS RUNTIME VALIDATION | Base equivalent is verified, raid variant is not | Metadata/UI/context/readback |
| 31 | Raid SSAO | `raidGraphicsSSAO` → `RAIDSSAO` | Binary map; Config `3` | Integer mode | NEEDS RUNTIME VALIDATION | Context/gate behavior unverified | Metadata/UI/context/readback |
| 32 | Raid Depth Effects | `raidGraphicsDepthEffects` → RAID depth family | Binary map; Config `3` | Integer quality enum | NEEDS RUNTIME VALIDATION | Context/gate behavior unverified | Metadata/UI/context/readback |
| 33 | Raid Compute Effects | `raidGraphicsComputeEffects` → RAID compute family | Binary map; Config `2` | Integer quality enum | NEEDS RUNTIME VALIDATION | Context/gate behavior unverified | Metadata/UI/context/readback |
| 34 | Raid Outline Mode | `raidGraphicsOutlineMode` → `RAIDOutlineEngineMode` | Binary map; Config `1` | Integer mode | NEEDS RUNTIME VALIDATION | Add-on interactions and context behavior possible | Metadata/UI/context/readback |
| 35 | Raid Light Mode | `raidGraphicsLightMode` | Binary name; Config `2` | Integer enum; meaning unknown | NEEDS RUNTIME VALIDATION | Exact UI label and behavior not recovered | Metadata/UI inspection first |
| 36 | Raid Bloom Intensity | `raidGraphicsBloomUserMult` → `RAIDbloomUserMult` | Binary map; Config `1` | Numeric multiplier; range unknown | NEEDS RUNTIME VALIDATION | Exact slider and context behavior unknown | Metadata/UI inspection first |
| 37 | Raid Global Illumination | `RAIDgiQuality` | Binary description; Config `3` | Integer quality enum | NEEDS RUNTIME VALIDATION | Naming differs from other raid wrappers; visibility unknown | Metadata/UI inspection first |
| 38 | Render Scale / Resolution Scale | `RenderScale` | Burak build-70170 set/readback/UI/restore; `0.75` = 75% | Numeric ratio | VERIFIED SAFE | Profile-worthy render-target scale; display mode remains excluded | None for current build |
| 39 | Resample Quality | `ResampleQuality` | Burak build-70170 set/readback/UI/restore; `3` = FSR1 | Integer enum | VERIFIED SAFE | Validated together with the current render-scaling UI | None for current build |
| 40 | Resample Sharpness | `ResampleSharpness` | Binary range `0.0-2.0`, `0` full strength, `-1` disabled; Config `0` | Numeric | NEEDS RUNTIME VALIDATION | Semantics are inverted/non-obvious and may depend on resampler | UI/RenderScale dependency test |
| 41 | Always Sharpen | `ResampleAlwaysSharpen` | Burak build-70170 set/readback/UI/restore | Boolean `0/1` | VERIFIED SAFE | User-facing toggle passed the full profile-safety path | None for current build |
| 42 | Dynamic Render Scale | `DynamicRenderScale` + `DynamicRenderScaleMin` | Binary says beta; warns of hitching and poor VSync interaction | Boolean plus numeric minimum | NEEDS RUNTIME VALIDATION | Dynamic runtime state, linked CVars, explicit beta warning | Do not write in first batch |
| 43 | Target Frame Rate | `useTargetFPS` + `targetFPS` | Burak build-70170 pair/readback/UI/restore validation | Boolean gate plus numeric target | VERIFIED SAFE | Apply numeric target and verify it before changing the gate | None for current build |
| 44 | Maximum Foreground FPS | `useMaxFPS` + `maxFPS` | Burak build-70170 pair/readback/UI/restore validation | Boolean gate plus integer FPS | VERIFIED SAFE | Apply numeric cap and verify it before changing the gate | None for current build |
| 45 | Maximum Background FPS | `useMaxFPSBk` + `maxFPSBk` | Binary descriptions, min `8`; local performance UI uses pair | Boolean gate plus integer FPS | SAFE CANDIDATE | Two-CVar logical setting; current values absent when defaults | Pair/UI/readback/restore test |
| 46 | Loading Screen Max FPS | `maxFPSLoading` | Binary description; local performance UI uses `30` | Integer FPS | NEEDS RUNTIME VALIDATION | Blizzard panel visibility and persistence are unconfirmed | Metadata/UI presence first |
| 47 | Vertical Sync | `vsync` | Burak build-70170 set/readback/UI/restore | Boolean `0/1` | VERIFIED SAFE | User-facing toggle passed the full profile-safety path | None for current build |
| 48 | Max Frame Latency / Triple Buffering | `GxMaxFrameLatency` | Binary: CPU frames ahead of GPU; Config `2`; third-party label says Triple Buffering | Integer; valid range/UI inversion unknown | NEEDS RUNTIME VALIDATION | UI label-to-raw mapping is not established | Metadata/UI-selected values only |
| 49 | Anti-Aliasing Mode | `ffxAntiAliasingMode` | Burak build-70170 set/readback/UI/restore; `4` = CMAA2 | Integer enum | VERIFIED SAFE | Validated current-client enum value | None for current build |
| 50 | Multisampling | `MSAAQuality` | Binary description; local performance UI writes `0` for none | Integer enum | NEEDS RUNTIME VALIDATION | May allocate/recreate render resources | Metadata/UI-selected values only |
| 51 | MSAA Alpha Test | `MSAAAlphaTest` | Binary: enable MSAA for alpha-tested geometry | Boolean-like | NEEDS RUNTIME VALIDATION | Whether independently user-visible is unclear | UI presence and metadata first |
| 52 | Texture Filtering | `textureFilteringMode` | Burak build-70170 set/readback/UI/restore; `5` = 16x Anisotropic | Integer enum | VERIFIED SAFE | Validated current-client enum value | None for current build |
| 53 | Low Latency Mode | `LowLatencyMode` | Binary enum: `0` auto, `1` none, `2` built-in, `3` Reflex, `4` Reflex+Boost, `5` XeLL | Integer enum | NEEDS RUNTIME VALIDATION | Hardware/vendor dependent; some values inapplicable on Metal | Metadata/UI visibility; no arbitrary write |
| 54 | Physics Interaction | `physicsLevel` | Binary description; local performance UI writes `1` | Integer enum | NEEDS RUNTIME VALIDATION | Exact UI labels and gameplay/CPU side effects unknown | Metadata/UI-selected values only |
| 55 | Brightness | `Brightness` | Binary range `0-100`; Config `47` | Numeric slider | SAFE CANDIDATE | User-visible and reversible; profiles may intentionally include color calibration | Metadata/UI/readback/restore |
| 56 | Contrast | `Contrast` | Binary range `0-100`; Config `60`; local optimizer backs up/restores | Numeric slider | SAFE CANDIDATE | User-visible and reversible | Metadata/UI/readback/restore |
| 57 | Gamma | `Gamma` | Binary range `0.3-2.8`; Config `1` | Numeric slider | SAFE CANDIDATE | Display perception/calibration; still not device selection | Metadata/UI/readback/restore |
| 58 | Display Mode / Window Mode | `GxMaximize` plus window-system state | Binary: toggle fullscreen/window; Config `1` | Boolean-like plus platform behavior | EXCLUDE | Display transition risk; not a normal quality profile setting | No write test |
| 59 | Resolution | `GxWindowedResolution` / `GxNewResolution` | Binary descriptions; Config `2050x1324` | Resolution string | EXCLUDE | Display/device recreation and recovery risk | No write test |
| 60 | Refresh Rate | No dedicated current macOS CVar established; `gx.log` reports 120 Hz | Current log only | Platform/display mode | EXCLUDE | Important UI/display boundary; mapping unresolved and unsafe to probe by write | No write test |
| 61 | Monitor / Display Selection | `GxMonitor` | Binary: monitor index, `0` primary | Integer device index | EXCLUDE | Device/display selection and recovery risk | No write test |
| 62 | Graphics API / Backend | `GxApi` | Binary description; current renderer is Metal | String/enum; platform dependent | EXCLUDE | Restart/device-sensitive; unsupported values can prevent normal launch | No write test |
| 63 | Graphics Card / GPU | `GxAdapter` | Binary: GPU name selection; current log shows Apple M4 Pro | Device-name string | EXCLUDE | Hardware/device selection | No write test |
| 64 | Notched Display Mode | `NotchedDisplayMode` | Binary name; Config `0` | Boolean-like/platform-specific | EXCLUDE | Hardware-specific layout compatibility, not profile quality | No write test |
| 65 | Hardware Detection / Compatibility State | `hwDetect`, `videoOptionsVersion`, `engineSurvey*`, compatibility flags | Config and binary | Internal/versioned state | EXCLUDE | Engine ownership; may rewrite settings or encode hardware survey state | Never profile |
| 66 | Derived low-level graphics children | `shadowMode`, `farclip`, `waterDetail`, `SSAO`, RAID-prefixed children, etc. | Binary high-level wrapper map; many persisted in Config | Mixed | EXCLUDE | Derived from high-level wrappers; storing both creates conflicting sources of truth | Never profile directly |

## 4. Classification groups

### VERIFIED SAFE

The following 25 raw CVars have accepted build-70170 evidence for the full
RenderSet contract: write, immediate readback, Blizzard Graphics UI reflection,
and restore of the original value. The two FPS controls are logical pairs.

- `graphicsShadowQuality`
- `graphicsProjectedTextures`
- `graphicsParticleDensity`
- `graphicsLiquidDetail`
- `graphicsSSAO`
- `graphicsDepthEffects`
- `graphicsComputeEffects`
- `graphicsGroundClutter`
- `graphicsEnvironmentDetail`
- `graphicsViewDistance`
- `graphicsTextureResolution`
- `graphicsSpellDensity`
- `ResampleAlwaysSharpen`
- `vsync`
- `RenderScale`
- `ResampleQuality`
- `textureFilteringMode`
- `ffxAntiAliasingMode`
- `graphicsLightMode`
- `graphicsPBRLiquidDetail`
- `graphicsBloomUserMult`
- `maxFPS` + `useMaxFPS`
- `targetFPS` + `useTargetFPS`

### SAFE CANDIDATES

These have strong current-client evidence as reversible, user-controlled,
non-device settings, but are not yet eligible for the production allowlist:

- Background frame cap: `useMaxFPSBk` + `maxFPSBk`
- Calibration: `Brightness`, `Contrast`, `Gamma`

### NEEDS RUNTIME VALIDATION

- Global illumination quality.
- Raid gate and all 17 independent raid variants.
- Resample sharpness and dynamic render scale.
- Frame latency, MSAA, low-latency mode, and physics.
- Loading-screen FPS limit.

These remain outside the allowlist until the uncertainty recorded in the table
is resolved. “Advanced” alone is not the reason; linked state, unknown enums,
hardware dependence, or render-subsystem effects are.

### EXCLUDED

- `graphicsQuality` and `RAIDgraphicsQuality`: derived master preset selectors.
- `graphicsOutlineMode`: current runtime CVar without a user-facing Forever
  Graphics control; old stored keys are retained but never applied.
- Display mode, resolution, refresh rate, monitor, API/backend, GPU adapter.
- Notched-display, hardware detection, survey/compatibility state.
- All derived low-level children beneath the high-level graphics wrappers.

### UNKNOWN / UNMAPPED UI CONTROLS

- A dedicated refresh-rate CVar was not established on this macOS build. The
  120 Hz active rate is log evidence only.
- Exact Blizzard panel visibility/labels remain unconfirmed for PBR Liquid,
  Light Mode, Bloom, GI, Loading Screen FPS, MSAA Alpha Test, Low Latency, and
  Physics Interaction.
- Exact enum label-to-value mappings remain unknown for most integer quality
  wrappers, AA, MSAA, texture filtering, resampling, and frame latency.
- The installed client does not expose Blizzard Settings definition source, so
  UI order and conditional visibility must be captured in-game.

## 5. Master quality and derived-setting decision

The current binary labels `graphicsQuality` and `RAIDgraphicsQuality` as saved
values for the corresponding quality selections. Separately, it maps each
`graphics*` wrapper to one or more low-level engine CVars. Current Config values
also show a non-uniform combination of individual settings under master quality
`7`.

RenderSet should therefore treat both master quality selectors as derived UI
presets and exclude them. A profile should store validated high-level individual
wrappers, not the master selector and not their low-level children. This avoids
apply-order conflicts and two competing sources of truth.

## 6. Raid and battleground findings

The current client has a real independent raid family:

- `RAIDsettingsEnabled` gates availability/use.
- `RAIDgraphicsQuality` stores the derived raid master preset.
- Seventeen independently persisted raid settings map to base equivalents:
  texture, spell density, projected textures, view distance, ground clutter,
  environment detail, shadows, liquid, PBR liquid, particles, SSAO, depth,
  compute, outline, light, bloom, and GI.

They are not promoted to SAFE CANDIDATE yet. Their storage is strong evidence,
but reliable profiling also requires confirming the gate, Blizzard UI reflection,
and whether the effective value switches only in raid/battleground contexts.
The base and raid wrappers must remain distinct if later admitted.

## 7. Display/device boundary

RenderSet should intentionally never manage these in its ordinary profile
engine without a later architectural decision and dedicated recovery UX:

- display/window mode
- resolution
- refresh rate
- monitor selection
- graphics API/backend
- GPU/adapter selection
- hardware detection/compatibility state

These can recreate devices, require restart, be hardware-specific, or leave the
client in a difficult-to-recover state. Completeness does not justify write
testing them.

Render scaling is kept separate from display/device controls: it may eventually
be profile-worthy, but only after a dedicated reversible test covering resampler
coupling and Blizzard UI synchronization.

## 8. Completed runtime validation

Burak completed individual real-client validation on build 70170 for every raw
CVar now in the 25-CVar production allowlist. The evidence covered appropriate
combinations of `GetCVar`, `SetCVar`, immediate readback, Blizzard Graphics UI
reflection, and restoration of the original value.

The verified raw mappings recorded for later preset design are:

- `ResampleQuality = "3"` → FSR1
- `textureFilteringMode = "5"` → 16x Anisotropic
- `ffxAntiAliasingMode = "4"` → CMAA2
- `graphicsLightMode = "0"` → Secondary Lighting: Fair
- `graphicsPBRLiquidDetail = "2"` → PBR Liquid Detail: Ultra
- `graphicsBloomUserMult = "1"` → Bloom Intensity: High
- `graphicsTextureResolution = "2"` → Texture Resolution: High
- `graphicsSpellDensity = "0"` → Spell Density: Essential
- `graphicsParticleDensity = "4"` → Particle Density: High
- `graphicsComputeEffects = "2"` → Compute Effects: Good
- `graphicsSSAO = "1"` → SSAO: Low
- `graphicsSSAO = "2"` → SSAO: Good
- `graphicsDepthEffects = "2"` → Depth Effects: Good
- `graphicsViewDistance = "6"` → UI View Distance 7
- `graphicsEnvironmentDetail = "6"` → UI Environment Detail 7
- `graphicsGroundClutter = "4"` → UI Ground Clutter 5
- `graphicsProjectedTextures = "1"` → Enabled
- `RenderScale = "0.75"` → 75%
- `graphicsLiquidDetail = "2"` → Good

These are evidence references, not engine defaults. Capture continues to store
the client's current raw strings.

`graphicsOutlineMode` remains a readable/writeable runtime CVar, but later UI
inspection confirmed that the current Forever Graphics panel does not expose a
user-facing Outline Mode control. It is therefore excluded from production
coverage. Existing profile data is not migrated or deleted.

## 9. Decision gate for the next implementation task

A new CVar or logical CVar pair may enter the production allowlist only after it
has evidence for all of the following on the target Forever build:

1. `GetCVar` returns a stable raw string.
2. `GetCVarInfo` shows it is not locked, secure, or read-only.
3. A known-valid alternate is accepted by `SetCVar`.
4. Immediate `GetCVar` readback matches.
5. Blizzard Graphics UI reflects the value predictably.
6. The original value restores successfully.
7. No reload/restart/device recovery is required unless explicitly designed.
8. Linked/gated CVars have a defined atomic capture/apply contract.

The 25 production raw CVars crossed this gate. Remaining candidates still
require their own recorded runtime results before any later allowlist change.

## 10. Sources inspected

- Current RenderSet checkout: TOC, runtime Lua, README, tests,
  `RS-1_DISCOVERY.md`, packaging/release files.
- Current application metadata and flavor marker.
- Current `WTF/Config.wtf`.
- Current `Logs/gx.log`.
- Current client executable strings for CVar API signatures, high-level/derived
  graphics mapping, descriptions, ranges, warnings, and device controls.
- Installed `EllesmereUIOptions/EUI__General_Options.lua` optimizer backup/write/
  restore table (static third-party evidence).
- Installed `NaowhForever/QoL/NaowhForever_Performance.lua` advanced CVar list
  (static third-party evidence; its own UI marks relevant settings untested).
- Installed `DialogueUI/Code/Camera.lua` use of `graphicsOutlineMode` (static
  add-on interaction evidence).

No public Retail CVar list was used as authority, no client was launched or
controlled, and no CVar was changed by Codex during this audit.
