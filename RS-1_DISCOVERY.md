# RS-1 — Current repository and WoW Forever graphics API/CVar inventory

Date: 2026-10-01 (Europe/Amsterdam)
Scope: discovery only; no addon implementation or in-game mutation

## Evidence labels

- **CONFIRMED FROM CURRENT CLIENT/FILES** — directly observed in the current checkout or installed `_classic_beta_` client files.
- **USER-PERFORMED IN-GAME VALIDATION** — result reported from the running WoW Forever client by the user; limited to the exact call and returned values recorded here.
- **SUPPORTED BY DOCUMENTATION OR CODE** — supported by current-client binary strings or cited API documentation, but not exercised by this investigation.
- **LIKELY BUT UNVERIFIED** — reasonable interpretation that still needs a Forever-client test.
- **REQUIRES IN-GAME TEST** — cannot be established safely from static files.

## A. Current repository state

The task-provided working path `/burakalev123/RenderSet` was not present on the machine. A read-only filesystem search found one RenderSet checkout, which was used as authoritative.

Historical RS-1 starting state, preserved as evidence:

- Checkout: `/Users/burakalev/Documents/GitHub/RenderSet`
- Repository/remote: `burakalev123/RenderSet` / `https://github.com/burakalev123/RenderSet.git`
- Branch: `main`
- Commit: `69a92d56d733c7f220a57f2e49e9bc6ec86c84c8` (`Initial commit`)
- Status at inspection: clean; `main...origin/main`
- Tracked file tree: `README.md` only
- README content: title `RenderSet` and “Reliable graphics profile manager for World of Warcraft: Forever”

Later review state before this correction:

- Checkout: `/Users/burakalev/Documents/GitHub/RenderSet`
- Branch: `main`
- Commit: `358a2a2ebfc5dc20831049befffd18294c86e267` (`first commit`)
- Status: clean; `main...origin/main`
- Tracked file tree: `README.md`, `RS-1_DISCOVERY.md`

No archive, ZIP, prior task output, or other addon repository was used.

## B. Forever client/build evidence

### CONFIRMED FROM CURRENT CLIENT/FILES

- Installed flavor: `_classic_beta_`; `.flavor.info` says `wow_classic_beta`.
- Installed application: `World of Warcraft Beta.app`.
- Application metadata: version `1.60.1`, bundle build `1.60.1.70124`.
- The latest local `Logs/gx.log`, opened 2026-10-01, records `World of Warcraft Beta ARM64 1.60.1.70124`. This proves that this installed executable was launched, not merely staged.
- Client binary contains the product name `World of Warcraft: Forever`.
- `WTF/Config.wtf` contains `agentUID "wow_classic_beta"` and `engineSurveyPatch "16001"`.

### USER-PERFORMED IN-GAME VALIDATION — 2026-10-01

`GetBuildInfo()` returned:

- version: `"1.60.1"`
- build: `"70124"`
- build date: `"Sep 29 2026"`
- interface: `16001`
- remaining returned string fields: empty

This confirms the live Forever build/interface tuple `1.60.1.70124` / `16001` for the tested client session.

### SUPPORTED BY DOCUMENTATION OR CODE

- The client is a beta/test flavor. Findings may change in later Forever builds.

Exact installed, last-launched, and user-validated live build **can** be established as `1.60.1.70124`, with interface `16001`. This does not independently establish a server-side build.

## C. Available CVar/API surface

The current client executable contains generated usage text for:

| API | Current-client evidence | Practical consequence |
|---|---|---|
| `C_CVar.AreCVarsLoaded()` | Symbol present | Later code can defer capture/apply until CVars are loaded. Exact startup timing still needs testing. |
| `C_CVar.GetCVar(name)` | Usage says it returns `value` | Canonical read path; values are strings or nil. |
| `C_CVar.GetCVarBool(name)` | Usage present | Available for boolean interpretation, although profiles should preserve canonical raw strings. |
| `C_CVar.GetCVarDefault(name)` | Usage present | Useful for diagnostics/reset UI, not required for profile capture. |
| `C_CVar.GetCVarInfo(name)` | Usage returns current/default values plus account/character storage, locked, secure, and read-only flags | Preferred capability probe before admitting a CVar to an allowlist. It does **not** expose numeric min/max. |
| `C_CVar.SetCVar(name[, value])` | Usage says it returns `success` | Canonical write path; success plus immediate readback should be checked. |
| `C_CVar.SetTempCVar`, `RegisterCVar`, bitfield APIs | Usage present | Not needed for RenderSet MVP profiles. |
| `CVAR_UPDATE` | Event name present in binary | Potential refresh/verification signal; exact event arguments and Settings UI synchronization require an in-game test. |

### USER-PERFORMED IN-GAME VALIDATION — 2026-10-01

The following runtime types were observed:

```text
type(C_CVar) == "table"
type(C_CVar.GetCVar) == "function"
type(C_CVar.SetCVar) == "function"
type(C_CVar.GetCVarInfo) == "function"
```

This confirms runtime presence of the namespaced table and these three methods. `C_CVar.SetCVar` was **not called**, so its existence must not be presented as successful write/apply evidence.

For `graphicsShadowQuality` only:

- `C_CVar.GetCVar("graphicsShadowQuality")` returned `"2"`.
- `C_CVar.GetCVarInfo("graphicsShadowQuality")` returned current `"2"`, default `"3"`, `isStoredServerAccount=false`, `isStoredServerCharacter=false`, `isLockedFromUser=false`, `isSecure=false`, and `isReadOnly=false`.

This confirms live read and metadata behavior only for `graphicsShadowQuality`. It does not confirm write, readback-after-write, `CVAR_UPDATE`, Settings UI synchronization, persistence, combat behavior, reload behavior, or restart behavior.

[Warcraft Wiki's Forever 1.60.1 pages](https://warcraft.wiki.gg/wiki/API_C_CVar.GetCVar) also document global `GetCVar`/`SetCVar` wrappers around `C_CVar`. A stored user macro names global `SetCVar`, but the macro's existence is static text evidence only: it was not executed or used to establish API availability or behavior. Therefore:

- Use `C_CVar.GetCVar`, `C_CVar.SetCVar`, and `C_CVar.GetCVarInfo` as the provisional canonical API.
- Treat global `GetCVar` and `SetCVar` as compatibility wrappers that still require a one-time Forever test.
- Do **not** assume global `GetCVarInfo` exists. Documentation describes the legacy alias as deprecated/removed on some branches; the namespaced form is directly evidenced here.
- Do not assume Retail-only helpers. In particular, `C_CVar.DoesCVarExist` was not found in the current binary's exposed `C_CVar` method list.

Documentation says secure CVars cannot be changed through `SetCVar` in combat and read-only CVars cannot be changed at all. Live flags were captured only for `graphicsShadowQuality`; although all its reported restriction flags were false, no write or combat test was performed. Every other candidate remains a per-CVar test item.

## D/E. Graphics CVar inventory and classification

“Current” below means the value persisted in `_classic_beta_/WTF/Config.wtf` after the latest observed client session, except where a live result is explicitly identified. “R/W” is provisional: the APIs exist, but only read and metadata retrieval for `graphicsShadowQuality` were exercised. No write was performed.

### Candidate UI-level settings

| Class | CVar | Appears to control | Persisted value | Type/range evidence | R/W | Apply/reload evidence | Confidence/source |
|---|---|---|---:|---|---|---|---|
| SAFE | `graphicsTextureResolution` | Texture resolution | `2` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Current config + client binary groups it with `terrainMipLevel`/`worldBaseMip` |
| SAFE | `graphicsSpellDensity` | Spell effect density | `0` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Current config + binary mapping to `spellClutter` |
| SAFE | `graphicsProjectedTextures` | Projected textures | `1` | Boolean-like; raw `projectedTextures=1` | Expected / test | Likely immediate; test | Config + binary mapping; console log says projected textures enabled |
| SAFE | `graphicsViewDistance` | View distance | `7` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping to far/horizon/LOD CVars |
| SAFE | `graphicsGroundClutter` | Ground clutter | `4` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping to ground-effect distance/density |
| SAFE | `graphicsEnvironmentDetail` | Environment/object detail | `6` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping to object LOD CVars |
| SAFE | `graphicsShadowQuality` | Shadow quality | `2` persisted and live; default `3` | Integer UI level; raw binary says `shadowMode` is `0-3` but wrapper range is unknown | Read confirmed; write untested; live flags all false | Apply/reload behavior untested | Config + user-performed `GetCVar`/`GetCVarInfo`; console reports shadow mode changes |
| SAFE | `graphicsLiquidDetail` | Legacy/non-PBR liquid detail | `2` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping to water/reflection/ripple CVars |
| SAFE | `graphicsParticleDensity` | Particle density | `5` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping to particle density |
| SAFE | `graphicsSSAO` | Screen-space ambient occlusion | `1` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping to `SSAO`; console reports mode `1` |
| SAFE | `graphicsDepthEffects` | Sun shafts/refraction/depth opacity | `1` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping |
| SAFE | `graphicsComputeEffects` | Volumetric fog/particulates/clustered shading group | `2` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping |
| SAFE | `graphicsOutlineMode` | Outline mode | `1` | Integer UI level; exact range unknown | Expected / test | Likely immediate; test | Config + binary mapping to `OutlineEngineMode`; console reports mode `1` |
| SAFE | `graphicsPBRLiquidDetail` | PBR water quality | `2` | Integer quality level; binary description confirms purpose | Expected / test | Unknown; test | Config + binary description |
| UNCERTAIN | `graphicsLightMode` | Lighting mode | `0` | Integer UI level; exact meaning/range unknown | Expected / test | Unknown | Present in config and wrapper group only |
| UNCERTAIN | `graphicsBloomUserMult` | Bloom intensity UI multiplier | `1` | Numeric; range unknown | Expected / test | Unknown | Config + binary description |
| UNCERTAIN | `giQuality` | Global-illumination quality | `1` | Integer quality level; range unknown | Expected / test | Unknown | Config + binary description; no `graphicsGIQuality` wrapper observed |
| UNCERTAIN | `graphicsQuality` | Overall graphics preset selector | `7` | Integer preset; exact range unknown | Expected / test | May rewrite many individual settings | Binary calls it “save for Graphics Quality Selection”; current individual values are not proof of preset mapping |

`SAFE` means **provisional safe candidate** for a future allowlist because the current evidence identifies it as a UI graphics setting. It does not mean runtime-validated write safety. Even for `graphicsShadowQuality`, only reading and metadata retrieval were validated.

### Rendering, frame-rate, filtering, and anti-aliasing

| Class | CVar(s) | Appears to control | Persisted value | Type/range evidence | R/W | Apply/reload evidence | Confidence/source |
|---|---|---|---|---|---|---|---|
| SAFE | `RenderScale` | Resolution/render scale | `1` | Numeric ratio; exact accepted range unknown | Expected / test | `gx.log` proves render-target size changes during a session, but not that `RenderScale` caused them; apply/restart behavior unknown | Config + binary description + `gx.log` |
| SAFE | `vsync` | Vertical sync | `0` | Boolean-like; binary says on/off | Expected / test | Unknown; interaction with target FPS noted by client | Config + binary description |
| SAFE | `useMaxFPS`, `maxFPS` | Enable/limit foreground FPS | `1`, `75` | Boolean + numeric; binary documents minimum `8` for limit | Expected / test | Likely immediate; test | Config + binary descriptions |
| UNCERTAIN | `useMaxFPSBk`, `maxFPSBk` | Enable/limit background FPS | Not persisted | Boolean + numeric; binary documents minimum `8` | Expected / test | Unknown | Names/descriptions in current binary only |
| UNCERTAIN | `useTargetFPS`, `targetFPS` | Enable target FPS and set target | `0`, not persisted | Boolean + numeric; range unknown | Expected / test | May trigger dynamic actions | Config + binary descriptions |
| UNCERTAIN | `DynamicRenderScale`, `DynamicRenderScaleMin` | Lower render scale when GPU-bound to meet target FPS | Not persisted | Boolean-like + numeric minimum scale; exact range unknown | Expected / test | Client labels feature beta and warns it may hitch or behave poorly with VSync | Current binary descriptions |
| UNCERTAIN | `ffxAntiAliasingMode` | Post-process anti-aliasing mode | Not persisted | Integer enum; values/labels unknown | Expected / test | Unknown | Name/description in current binary |
| UNCERTAIN | `MSAAQuality`, `MSAAAlphaTest` | Multisample anti-aliasing | Not persisted | Integer quality + boolean-like; ranges unknown | Expected / test | Could affect device resources; restart need unknown | Current binary descriptions |
| UNCERTAIN | `textureFilteringMode` | Texture filtering mode | Not persisted | Integer enum; values unknown | Expected / test | Console says filtering mode updated; test | Current binary; no current high-level `graphicsTextureFiltering` wrapper was established |
| UNCERTAIN | `ResampleQuality`, `ResampleAlwaysSharpen`, `ResampleSharpness` | Upscaling/resampling quality and sharpening | absent, `1`, `0.19999992847443` | Enum/boolean/numeric; exact ranges unknown | Expected / test | Likely coupled to render scale | Current config + binary descriptions |
| EXCLUDE | `GxMaxFrameLatency` | CPU frames queued ahead of GPU | `2` | Numeric; range/platform semantics unknown | Expected / test | Hardware/backend-sensitive | Current config + binary description |

No `gxTripleBuffer`/`tripleBuffering` candidate was established from the current config or exact binary-string search. Do not invent or include one until the live client proves it exists.

### Raid-specific mirrors

The client contains a complete parallel family such as `raidGraphicsShadowQuality`, `raidGraphicsLiquidDetail`, `raidGraphicsParticleDensity`, `raidGraphicsSSAO`, `raidGraphicsDepthEffects`, `raidGraphicsComputeEffects`, `raidGraphicsOutlineMode`, `raidGraphicsTextureResolution`, `raidGraphicsProjectedTextures`, `raidGraphicsViewDistance`, `raidGraphicsEnvironmentDetail`, `raidGraphicsGroundClutter`, `raidGraphicsSpellDensity`, `raidGraphicsPBRLiquidDetail`, `raidGraphicsLightMode`, and `raidGraphicsBloomUserMult`.

Current persisted wrapper values are respectively `3, 2, 4, 3, 3, 2, 1, 2, 1, 5, 5, 5, 1, 1, 2, 1`. The binary also contains `RAIDsettingsEnabled`, described as “Raid graphic settings are available,” but it is not persisted in the current config.

Classification: **UNCERTAIN as a family**. They are genuine current-client graphics settings, but RS-3 must establish whether raid settings are enabled, when they take effect, and whether normal-profile switching should intentionally include them. If supported, capture the high-level `raidGraphics*` wrappers, not the raw uppercase `RAID*` derivatives.

### Raw/derived engine settings

The binary directly maps high-level wrappers to groups including `shadowMode`, `shadowTextureSize`, `waterDetail`, `reflectionMode`, `rippleDetail`, `particleDensity`, `SSAO`, `sunShafts`, `refraction`, `DepthBasedOpacity`, `volumeFog`, `volumeFogLevel`, `projectedTextures`, `farclip`, `horizonClip`, `groundEffectDist`, `groundEffectDensity`, and many LOD values. The current config contains several of these derived values.

Classification: **EXCLUDE from normal profiles**. Capturing both wrapper and raw values creates ordering conflicts and makes profiles dependent on Blizzard's internal preset expansion. Raw values may be useful only for diagnostics after explicit validation.

## F. Settings that should remain outside normal profiles

Keep these excluded or in a future explicitly separate, device-specific profile type:

- Monitor/display: `GxMonitor`, `GxWindowedResolution` (current `2049x1324`), `GxFullscreenResolution`, `GxNewResolution`, refresh-rate settings.
- Window state/mode: `GxMaximize` (current `1`), fullscreen/window toggles and related update commands.
- Adapter/backend: `GxAdapter`, `GxApi`, low-latency backend settings.
- Hardware detection/compatibility: `hwDetect`, `videoOptionsVersion`, `GxCompat*`, `engineSurvey*`.
- Debug/developer controls: `GxDebugLevel`, `GxDebugBreakLevel` and graphics diagnostic commands.
- Render-thread internals: `gxMT*` controls.
- Raw derived normal and `RAID*` engine CVars described above.

Reason: these are hardware-, monitor-, OS-, driver-, or backend-specific; some are pending operations rather than portable visual preferences; and invalid values can prevent a clean display/device transition. The binary explicitly says resolution is pending until `UpdateWindow`, and some device changes are pending `GxRestart`.

## G. Known apply/reload/restart implications

### CONFIRMED FROM CURRENT CLIENT/FILES

- The binary reports that resolution changes are pending until `UpdateWindow`.
- `GxApi` and some device settings are pending `GxRestart`.
- `gx.log` records actual `GxRestart` operations with reason `UserAction`; the log does not identify which specific UI field caused each restart.
- `gx.log` records render-target size changes during a client session. It does not identify the initiating CVar, so it does not prove that `RenderScale` changed or applies immediately.
- Proper logout saved the observed values to `Config.wtf`; static inspection cannot prove when each value became effective.

### SUPPORTED BY DOCUMENTATION OR CODE

- `C_CVar.SetCVar` returns success; some settings can still require reload/relog.
- Secure CVars can reject changes in combat; read-only CVars reject writes. Per-CVar status must come from `C_CVar.GetCVarInfo` in the actual client.
- CVars are string-valued. Store canonical strings, not coerced booleans/numbers, unless a setting-specific validator deliberately normalizes them.

### LIKELY BUT UNVERIFIED

- High-level `graphics*` setters probably update their raw groups immediately, but this was only observed during client initialization, not through addon calls.
- Applying `graphicsQuality` probably overwrites multiple individual graphics values. If it is ever supported, apply it before individual overrides and read everything back; safer initial behavior is not to apply it.
- Settings UI controls may not redraw immediately after an external `SetCVar`; `CVAR_UPDATE` exists, but Settings-frame refresh behavior was not tested.

## H. Unknowns requiring actual in-game validation

The live build tuple, namespaced API presence, and read/metadata behavior for `graphicsShadowQuality` are now confirmed. Before RS-3 implements capture/apply, the remaining validation is:

1. For every other proposed CVar, call `C_CVar.GetCVar` and `C_CVar.GetCVarInfo` out of combat and record existence, current/default value, storage scope, locked, secure, and read-only flags.
2. For every proposed CVar, including `graphicsShadowQuality`, write a safe alternate value with `C_CVar.SetCVar`, record its return, immediately read back, then restore the original value.
3. Observe whether `CVAR_UPDATE` fires and whether the Blizzard Graphics UI reflects the write.
4. Test combat restrictions only where safe, without inferring behavior from metadata alone.
5. Observe whether the world changes immediately and whether graphics reload, UI reload, relog, client restart, or `GxRestart` is required.
6. Check persistence across `/reload`, logout/login, and full client restart.
7. Establish accepted enums/ranges for each integer wrapper, anti-aliasing, filtering, render scale, resampling, target FPS, and raid settings.
8. Test ordering: preset then individual; individual then preset; target FPS with VSync/render scale; normal versus raid settings.

No claim in this report should be read as an in-game `SetCVar` validation. All write/apply checks remain gated for RS-3.

## I. Recommended initial CVar scope for RS-3 — provisional

Start with an explicit allowlist, not enumeration of all CVars.

**Provisional first cohort after the test above passes:**

```text
graphicsTextureResolution
graphicsSpellDensity
graphicsProjectedTextures
graphicsViewDistance
graphicsGroundClutter
graphicsEnvironmentDetail
graphicsShadowQuality
graphicsLiquidDetail
graphicsParticleDensity
graphicsSSAO
graphicsDepthEffects
graphicsComputeEffects
graphicsOutlineMode
graphicsPBRLiquidDetail
RenderScale
vsync
useMaxFPS
maxFPS
```

Apply only the high-level names, check `C_CVar.SetCVar` success, read back every value, and report partial failure rather than claiming the whole profile applied.

**Second cohort only after targeted validation:** raid mirrors; `useMaxFPSBk`/`maxFPSBk`; lighting/bloom/GI; anti-aliasing; texture filtering; resampling; target-FPS/dynamic-render-scale controls.

**Do not put in the initial apply allowlist:** `graphicsQuality`, raw/derived CVars, display/window/resolution/refresh/GPU/backend controls, compatibility/debug/multithreading settings, or any unknown CVar discovered by enumeration.

## J. Can RS-2 safely begin?

**Yes.** RS-2 — minimal addon skeleton plus SavedVariables — can begin because its structure and persistence schema do not require a finalized CVar allowlist. There is no RS-2 blocker provided that RS-2 does not silently turn the provisional inventory into active profile/apply logic.

RS-3 remains gated on the in-game validation matrix in section H.

## Source notes

Local evidence inspected:

- `/Users/burakalev/Documents/GitHub/RenderSet/README.md`
- `/Applications/World of Warcraft/_classic_beta_/.flavor.info`
- `/Applications/World of Warcraft/_classic_beta_/World of Warcraft Beta.app/Contents/Info.plist`
- `/Applications/World of Warcraft/_classic_beta_/World of Warcraft Beta.app/Contents/MacOS/World of Warcraft` (static strings only)
- `/Applications/World of Warcraft/_classic_beta_/WTF/Config.wtf`
- `/Applications/World of Warcraft/_classic_beta_/WTF/SavedVariables/Blizzard_Console.lua`
- `/Applications/World of Warcraft/_classic_beta_/WTF/Account/50823565#1/macros-cache.txt` (stored macro text only; not execution evidence)
- `/Applications/World of Warcraft/_classic_beta_/Logs/gx.log`
- `/Applications/World of Warcraft/_classic_beta_/Logs/Client.log`

Documentation used:

- [C_CVar.GetCVar](https://warcraft.wiki.gg/wiki/API_C_CVar.GetCVar)
- [C_CVar.SetCVar](https://warcraft.wiki.gg/wiki/API_C_CVar.SetCVar)
- [C_CVar.GetCVarInfo](https://warcraft.wiki.gg/wiki/API%3AC_CVar.GetCVarInfo)
- [GetBuildInfo](https://warcraft.wiki.gg/wiki/API%3AGetBuildInfo)

## CHANGES MADE

- Originally added this discovery report only; this correction updates `RS-1_DISCOVERY.md` with the 2026-10-01 user-performed in-game read-only validation and review clarifications.
- No addon/runtime files or behavior were created or changed.

## AUTOMATED/STATIC VALIDATION

- Verified repository root, remote, branch, commit, status, tracked tree, and README.
- Read installed flavor and application metadata.
- Inspected the current persisted client config and relevant Blizzard-owned logs.
- Searched the current client executable's static strings for the CVar API surface, graphics CVar names/descriptions, and restart/update semantics.
- Distinguished the historical RS-1 starting state from the later committed review state.
- Re-checked repository status and diff after updating this report.

## IN-GAME VALIDATION

User-performed read-only validation dated 2026-10-01 confirmed:

- `GetBuildInfo()` returned version `1.60.1`, build `70124`, build date `Sep 29 2026`, interface `16001`, and empty remaining string fields.
- `C_CVar` was a table; `GetCVar`, `SetCVar`, and `GetCVarInfo` were functions.
- `GetCVar("graphicsShadowQuality")` returned `"2"`.
- `GetCVarInfo("graphicsShadowQuality")` returned current `"2"`, default `"3"`, and false for both storage flags plus locked, secure, and read-only.

No CVar write was performed. Write success/readback, events, UI synchronization, persistence, combat, reload, and restart behavior remain untested.

## NEXT STEP

RS-2 can begin. Its only guardrail is to keep the SavedVariables/profile schema independent from the provisional CVar list. Before RS-3 capture/apply logic, complete the in-game tests in section H.
