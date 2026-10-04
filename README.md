# RenderSet

Reliable graphics profile manager for World of Warcraft: Forever.

## Supported client

- World of Warcraft: Forever `1.60.1`
- Interface `16001`
- MVP acceptance completed in-game by the project owner on build `70170`

The earlier RS-1 discovery session used build `70124`. Forever is a beta/test
client, so later builds should receive a short smoke test before being treated
as compatible. Retail compatibility has not been evaluated.

## Installation

1. Copy the `RenderSet` folder into the Forever client's
   `Interface/AddOns` directory.
2. Confirm that `RenderSet.toc` is directly inside that folder.
3. Start or reload the client and enable RenderSet in the addon list if needed.

## Usage

1. Configure graphics in Blizzard Settings.
2. Open RenderSet from the minimap button or with `/rset`.
3. Save the current settings as a profile, for example `Quality`.
4. Change the supported graphics settings.
5. Save another profile, for example `Performance`.
6. Select and apply either profile as needed.

Built-in presets are also available above saved profiles in the UI:

- **MacBook Pro Internal — Balanced**
- **1440p External — Balanced**

These are immutable, code-defined templates. Applying one does not create or
overwrite a saved user profile. To customize one, apply it, adjust Blizzard
Graphics Settings, then use **Save Current** with a new profile name. Presets
are selected and applied manually; RenderSet does not switch them based on the
connected display.

For the MacBook preset, configure macOS Display to **Default** and use WoW in
**Windowed** mode. For the external preset, configure **2560×1440 at 75 Hz**
outside RenderSet. Monitor selection, display mode, physical resolution, and
refresh rate remain manual and are never changed by these presets.

## Features

- Save current supported graphics settings as named profiles.
- Apply, rename, and delete saved profiles.
- Reject duplicate or invalid profile names without overwriting profiles.
- Persist profiles across `/reload`, logout, and login.
- Open the standalone profile UI from the minimap button or slash commands.
- Capture and apply graphics values through a fixed safe allowlist.
- Apply two built-in balanced templates without adding them to SavedVariables.

Slash commands:

```text
/renderset
/rset
/rset list
/rset save <profile name>
/rset apply <profile name>
/rset help
```

## Profile scope

Version 0.1.0 stores only these allowlisted CVars:

- `graphicsShadowQuality`
- `graphicsProjectedTextures`
- `graphicsParticleDensity`
- `graphicsViewDistance`

Current development builds after 0.1.0 expand the verified allowlist to 25 raw
CVars:

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
- `maxFPS` and `useMaxFPS`
- `targetFPS` and `useTargetFPS`

Foreground and target FPS values are applied and verified before their enable
gates. A legacy profile containing only a gate skips that gate safely. Stored
`graphicsOutlineMode` values from earlier development builds are preserved but
ignored because the current Forever Graphics UI has no user-facing Outline Mode
control.

This development expansion is not part of the published
`RenderSet-0.1.0.zip` artifact.

Saved profiles persist through `/reload`, logout, and login. Built-in presets
remain in code and are never seeded into `RenderSetDB.profiles`. The current UI
selection is intentionally session-local and is not stored in `RenderSetDB`.

## Known limitations

- RenderSet does not manage display mode, resolution, graphics backend,
  GPU/device settings, or other restart-sensitive options.
- Automatic context switching, import/export, and Retail support are not part
  of version 0.1.0.
- The minimap button has a fixed position and is not configurable or persisted.
- RenderSet does not replace Blizzard Graphics Settings; it captures and applies
  the allowlisted CVar values selected by the user.
- Duplicate profile names are rejected instead of overwriting an existing
  profile.
- Profile names are case-sensitive.
- WoW Forever API and CVar behavior must be rechecked when the client interface
  or build changes materially.

## Validation

The 0.1.0 release candidate passed 46 mock-based Lua regression tests. Current
development tests additionally cover the expanded allowlist, linked FPS pair
ordering and failure isolation, and legacy four/eleven-CVar profiles. The
project owner separately completed individual build-70170 validation for the
promoted CVars and the integrated 25-CVar A → B → A engine round-trip. The new
built-in preset selection and application flow still requires real-client
acceptance.

The automated tests do not emulate the embedded WoW Lua runtime or prove
compatibility with future Forever builds.

## Packaging

Run:

```sh
./scripts/package.sh
```

The script creates `dist/RenderSet-0.1.0.zip` with one top-level `RenderSet`
folder. Test files, discovery notes, repository metadata, and temporary files
are excluded.
