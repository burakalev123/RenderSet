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

## Features

- Save current supported graphics settings as named profiles.
- Apply, rename, and delete saved profiles.
- Reject duplicate or invalid profile names without overwriting profiles.
- Persist profiles across `/reload`, logout, and login.
- Open the standalone profile UI from the minimap button or slash commands.
- Capture and apply graphics values through a fixed safe allowlist.

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

Saved profiles persist through `/reload`, logout, and login. The current UI
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
promoted CVars; the expanded engine still requires an integrated profile
round-trip in the real client.

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
