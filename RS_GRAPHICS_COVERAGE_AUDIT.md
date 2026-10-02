# RenderSet — WoW Forever Graphics Coverage Audit

Date: 2026-10-02 (Europe/Amsterdam)
Task: research/discovery only; no runtime allowlist or production behavior change

## Executive conclusion

RenderSet 0.1.0 should continue to profile only its four already accepted CVars
until targeted in-game validation expands the evidence boundary. This audit
identified 64 user-facing or plausibly user-facing graphics controls/control
families in the current Forever client and mapped 63 of them to a CVar or CVar
pair/family. The unresolved mapping is a dedicated refresh-rate control on this
macOS client; the active refresh rate is visible in `gx.log`, but no separate
user CVar was established.

The classification across the 66 audit rows below is:

- **VERIFIED SAFE:** 4
- **SAFE CANDIDATE:** 15
- **NEEDS RUNTIME VALIDATION:** 36
- **EXCLUDE:** 11

The two rows beyond the 64 user-facing/plausibly user-facing controls are the
hardware-detection state and the derived low-level CVar family. They are included
to make the intentional RenderSet boundary explicit.

## 1. Current state

- Checkout: `/Users/burakalev/Documents/GitHub/RenderSet`
- Branch: `main`
- Starting HEAD: `f27c0025bf0a9f805de0f61d8c261c36a5cc6ab9`
- Starting status: `main...origin/main` plus unrelated untracked `.DS_Store`
- Addon version: `0.1.0`
- TOC interface: `16001`
- SavedVariables schema: `schemaVersion = 1`
- Runtime allowlist in `Profiles.lua`:
  - `graphicsShadowQuality`
  - `graphicsProjectedTextures`
  - `graphicsParticleDensity`
  - `graphicsViewDistance`

No production file, schema, or allowlist was changed by this audit.

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
`graphicsShadowQuality`. The four current RenderSet CVars are nevertheless
VERIFIED SAFE because Burak later completed the full set/readback/Blizzard UI/
restore acceptance path for all four. No equivalent runtime evidence exists for
additional CVars.

## 3. Complete practical inventory

`Config` below means the current build-70170 `_classic_beta_/WTF/Config.wtf`.
`Binary map` means the current executable directly groups a high-level graphics
CVar with one or more lower-level engine CVars. Raw integer dropdown meanings
are intentionally left unknown unless current evidence states them.

| # | UI Setting | CVar/API | Current Evidence | Value Shape | Classification | Risk / Notes | Runtime Test Needed |
|---:|---|---|---|---|---|---|---|
| 1 | Graphics Quality (master) | `graphicsQuality` | Binary: “save for Graphics Quality Selection”; Config `7` | Integer preset; labels/range unknown | EXCLUDE | Derived preset writes groups of individual settings; would create a second source of truth | No direct-write test; observe only |
| 2 | Texture Resolution | `graphicsTextureResolution` → `terrainMipLevel`, `worldBaseMip` | Binary map; Config `2`; local optimizer writes `2` | Integer quality enum; labels/range unknown | SAFE CANDIDATE | High-level wrapper is preferable to derived children | Metadata, alternate value, UI/readback/restore |
| 3 | Spell Density | `graphicsSpellDensity` → `spellClutter` | Binary map; Config `0`; raid value `1`; local optimizer writes `0` | Integer enum; exact labels unknown | SAFE CANDIDATE | Base wrapper appears independent; alternate value needs proof | Metadata first; then UI-selected alternate |
| 4 | Projected Textures | `graphicsProjectedTextures` → `projectedTextures` | RS-8 set/readback/UI/restore; Config `1` | Boolean-like `0/1` | VERIFIED SAFE | Accepted RenderSet 0.1.0 behavior | None for current build |
| 5 | View Distance | `graphicsViewDistance` → multiple distance/LOD CVars | RS-8 set/readback/UI/restore; Config `7` | Integer quality enum; mapping unknown | VERIFIED SAFE | High-level wrapper fans out to derived values | None for current build |
| 6 | Ground Clutter | `graphicsGroundClutter` → `groundEffectDist`, `groundEffectDensity` | Binary map; Config `4`; local optimizer writes `0` | Integer quality enum | SAFE CANDIDATE | One UI control writes multiple derived children | Test wrapper/UI/readback/restore |
| 7 | Environment Detail | `graphicsEnvironmentDetail` → object LOD CVars | Binary map; Config `6`; local optimizer writes `0` | Integer quality enum | SAFE CANDIDATE | One UI control writes multiple derived children | Test wrapper/UI/readback/restore |
| 8 | Shadow Quality | `graphicsShadowQuality` → shadow family | RS-8 set/readback/UI/restore; Config `3`; prior live metadata unrestricted | Integer quality enum; low-level `shadowMode` says `0-3` but wrapper range not proven | VERIFIED SAFE | Store wrapper, never low-level children | None for current build |
| 9 | Liquid Detail | `graphicsLiquidDetail` → water/reflection/ripple family | Binary map; Config `2`; local optimizer writes `0` | Integer quality enum | SAFE CANDIDATE | Immediate render/UI behavior still needs acceptance | Batch 1 |
| 10 | PBR Liquid Detail | `graphicsPBRLiquidDetail` → `pbrLiquidDetail` | Binary says PBR water quality; Config `2` | Integer quality enum; range unknown | NEEDS RUNTIME VALIDATION | Forever-specific/newer path; relationship to Liquid Detail unclear | Metadata and UI dependency first |
| 11 | Particle Density | `graphicsParticleDensity` → particle density family | RS-8 set/readback/UI/restore; Config `5` | Integer quality enum | VERIFIED SAFE | Accepted RenderSet 0.1.0 behavior | None for current build |
| 12 | SSAO | `graphicsSSAO` → `SSAO` | Binary map; Config `1`; local optimizer writes `0` | Integer mode; `0` is used as disabled locally | SAFE CANDIDATE | Enum labels beyond off are unknown | Batch 1 |
| 13 | Depth Effects | `graphicsDepthEffects` → sun shafts/refraction/depth opacity | Binary map; Config `1`; local optimizer writes `0` | Integer quality enum | SAFE CANDIDATE | One wrapper fans out to several effects | Batch 1 |
| 14 | Compute Effects | `graphicsComputeEffects` → volume fog/particulates/clustered shading | Binary map; Config `2`; local optimizer writes `0` | Integer quality enum | SAFE CANDIDATE | Potential multi-effect refresh cost; no device restart evidence | Batch 1 |
| 15 | Outline Mode | `graphicsOutlineMode` → `OutlineEngineMode` | Binary map; Config `1`; local optimizer and DialogueUI use wrapper | Integer mode; local code uses `0` as disabled | SAFE CANDIDATE | Other add-ons may temporarily own this CVar | Batch 1 plus add-on-interaction observation |
| 16 | Light Mode | `graphicsLightMode` | Binary name; Config `0` | Integer enum; meaning/range unknown | NEEDS RUNTIME VALIDATION | Exact UI label and visual semantics not recovered | Metadata/UI inspection before write |
| 17 | Bloom Intensity | `graphicsBloomUserMult` → `bloomUserMult` | Binary description; Config `1` | Numeric multiplier; valid range unknown | NEEDS RUNTIME VALIDATION | Exact slider range and color pipeline behavior unknown | Metadata/UI inspection before write |
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
| 38 | Render Scale / Resolution Scale | `RenderScale` | Binary description; Config `0.75`; `gx.log` reports world render size | Numeric ratio; accepted range not exposed | NEEDS RUNTIME VALIDATION | Changes render-target size; coupled to resampling; not a display-mode CVar but side effects matter | Dedicated reversible test later |
| 39 | Resample Quality | `ResampleQuality` | Binary description and change log strings | Integer enum; labels/range unknown | NEEDS RUNTIME VALIDATION | Coupled to RenderScale; invalid values can be rejected | UI-selected values only |
| 40 | Resample Sharpness | `ResampleSharpness` | Binary range `0.0-2.0`, `0` full strength, `-1` disabled; Config `0` | Numeric | NEEDS RUNTIME VALIDATION | Semantics are inverted/non-obvious and may depend on resampler | UI/RenderScale dependency test |
| 41 | Always Sharpen | `ResampleAlwaysSharpen` | Binary `[0,1]`; Config `1`; local UI exposes toggle | Boolean `0/1` | SAFE CANDIDATE | Independent-looking but visual effect depends on render pipeline | Metadata/UI/readback/restore |
| 42 | Dynamic Render Scale | `DynamicRenderScale` + `DynamicRenderScaleMin` | Binary says beta; warns of hitching and poor VSync interaction | Boolean plus numeric minimum | NEEDS RUNTIME VALIDATION | Dynamic runtime state, linked CVars, explicit beta warning | Do not write in first batch |
| 43 | Target Frame Rate | `useTargetFPS` + `targetFPS` | Binary descriptions; Config gate `0` | Boolean gate plus numeric target | NEEDS RUNTIME VALIDATION | May trigger dynamic actions; coupled to dynamic render scale | Metadata and UI-selected target later |
| 44 | Maximum Foreground FPS | `useMaxFPS` + `maxFPS` | Binary descriptions, min `8`; Config `1`/`60` | Boolean gate plus integer FPS | SAFE CANDIDATE | Two-CVar logical setting; capture/apply order must preserve intent | Pair/UI/readback/restore test |
| 45 | Maximum Background FPS | `useMaxFPSBk` + `maxFPSBk` | Binary descriptions, min `8`; local performance UI uses pair | Boolean gate plus integer FPS | SAFE CANDIDATE | Two-CVar logical setting; current values absent when defaults | Pair/UI/readback/restore test |
| 46 | Loading Screen Max FPS | `maxFPSLoading` | Binary description; local performance UI uses `30` | Integer FPS | NEEDS RUNTIME VALIDATION | Blizzard panel visibility and persistence are unconfirmed | Metadata/UI presence first |
| 47 | Vertical Sync | `vsync` | Binary on/off; Config `0` | Boolean `0/1` | NEEDS RUNTIME VALIDATION | Presentation timing; interaction with dynamic scaling; may recreate swap behavior | Dedicated test later |
| 48 | Max Frame Latency / Triple Buffering | `GxMaxFrameLatency` | Binary: CPU frames ahead of GPU; Config `2`; third-party label says Triple Buffering | Integer; valid range/UI inversion unknown | NEEDS RUNTIME VALIDATION | UI label-to-raw mapping is not established | Metadata/UI-selected values only |
| 49 | Anti-Aliasing Mode | `ffxAntiAliasingMode` | Binary: Anti Aliasing Mode; local performance UI writes `4` | Integer enum | NEEDS RUNTIME VALIDATION | Enum names/range and renderer dependencies unknown | Metadata/UI-selected values only |
| 50 | Multisampling | `MSAAQuality` | Binary description; local performance UI writes `0` for none | Integer enum | NEEDS RUNTIME VALIDATION | May allocate/recreate render resources | Metadata/UI-selected values only |
| 51 | MSAA Alpha Test | `MSAAAlphaTest` | Binary: enable MSAA for alpha-tested geometry | Boolean-like | NEEDS RUNTIME VALIDATION | Whether independently user-visible is unclear | UI presence and metadata first |
| 52 | Texture Filtering | `textureFilteringMode` | Binary description and range-check/update strings | Integer enum; maximum not recovered | NEEDS RUNTIME VALIDATION | Exact dropdown values unknown; capitalization differs in third-party code | Metadata/UI-selected values only |
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

The following four CVars alone have accepted build-70170 evidence for the full
RenderSet contract: write, immediate readback, Blizzard Graphics UI reflection,
and restore of the original value.

- `graphicsShadowQuality`
- `graphicsProjectedTextures`
- `graphicsParticleDensity`
- `graphicsViewDistance`

### SAFE CANDIDATES

These have strong current-client evidence as reversible, user-controlled,
non-device settings, but are not yet eligible for the production allowlist:

- Quality wrappers: `graphicsTextureResolution`, `graphicsSpellDensity`,
  `graphicsGroundClutter`, `graphicsEnvironmentDetail`,
  `graphicsLiquidDetail`, `graphicsSSAO`, `graphicsDepthEffects`,
  `graphicsComputeEffects`, `graphicsOutlineMode`
- Image processing: `ResampleAlwaysSharpen`
- Frame caps: `useMaxFPS` + `maxFPS`, `useMaxFPSBk` + `maxFPSBk`
- Calibration: `Brightness`, `Contrast`, `Gamma`

### NEEDS RUNTIME VALIDATION

- Forever/new quality controls: PBR liquid, light mode, bloom, GI.
- Raid gate and all 17 independent raid variants.
- Render scaling, resampling, target/dynamic FPS.
- VSync, frame latency, AA/MSAA, texture filtering, low-latency mode, physics.
- Loading-screen FPS limit.

These remain outside the allowlist until the uncertainty recorded in the table
is resolved. “Advanced” alone is not the reason; linked state, unknown enums,
hardware dependence, or render-subsystem effects are.

### EXCLUDED

- `graphicsQuality` and `RAIDgraphicsQuality`: derived master preset selectors.
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

## 8. High-value first runtime validation batch

The first pass is intentionally limited to seven base quality wrappers whose
current values are nonzero and whose alternate `0` value is used by the installed
EllesmereUI optimizer with backup/restore logic. That source is static third-party
evidence, so Burak's test is still required.

Test out of combat, one CVar at a time. Keep Blizzard Graphics Settings open or
reopen it after each write. Restore each original value before moving on.

| Batch | CVar | Current Config | Safe alternate | Expected Blizzard UI observation |
|---|---|---:|---:|---|
| Effects A | `graphicsLiquidDetail` | `2` | `0` | Liquid Detail moves to disabled/lowest; exact label must be recorded |
| Effects A | `graphicsSSAO` | `1` | `0` | SSAO moves to disabled |
| Effects A | `graphicsDepthEffects` | `1` | `0` | Depth Effects moves to disabled |
| Effects A | `graphicsComputeEffects` | `2` | `0` | Compute Effects moves to disabled |
| Effects A | `graphicsOutlineMode` | `1` | `0` | Outline Mode moves to disabled; note DialogueUI interaction if active |
| Distance B | `graphicsGroundClutter` | `4` | `0` | Ground Clutter moves to the lowest position |
| Distance B | `graphicsEnvironmentDetail` | `6` | `0` | Environment Detail moves to the lowest position |

### Commands for each row

Replace `<CVAR>` with the exact name from the table. These commands keep the
original raw string in a temporary global table for the current UI session.

1. Read metadata and save the original:

```text
/run _G.RSAudit=_G.RSAudit or {}; local n="<CVAR>"; RSAudit[n]=C_CVar.GetCVar(n); print(n,"original",RSAudit[n],C_CVar.GetCVarInfo(n))
```

2. Write the audited alternate and read it back:

```text
/run local n="<CVAR>"; local ok=C_CVar.SetCVar(n,"0"); print(n,"set",ok,"readback",C_CVar.GetCVar(n))
```

3. Observe the Blizzard Graphics widget. Record whether it updates immediately,
   only after closing/reopening Settings, or not at all.

4. Restore the exact original and read back:

```text
/run local n="<CVAR>"; local v=RSAudit and RSAudit[n]; if v then local ok=C_CVar.SetCVar(n,v); print(n,"restore",ok,C_CVar.GetCVar(n)) else print("no backup",n) end
```

5. Confirm the Blizzard widget and visible effect returned to the original state.

For each CVar, capture: original value, default value, five metadata flags,
`SetCVar` result, immediate readback, UI refresh behavior, visible effect, and
restore result. Stop the batch on a rejected write, mismatch, Lua error, client
instability, or failure to restore.

Do not test display/device controls, render scale, dynamic resolution, AA/MSAA,
raid variants, or unknown enums in this first pass.

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

This audit does not authorize an allowlist change. The next task must use Burak's
recorded runtime results and admit only settings that cross this gate.

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
