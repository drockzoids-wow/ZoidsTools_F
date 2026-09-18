# Changelog

## Unreleased

## 0.2.1-beta

- Added an automatic campfire item bar, enabled by default: appears with Welcoming Campfire and carried usable items whose English tooltips require a campfire. Includes item counts, cooldowns, tooltips, saved dragging, and secure combat hiding (`/ztf campfire`).

- Added button-only objective tracker minimization, enabled by default under Quests. Collapsing hides the title/header artwork and background; expanding restores their native appearance without changing tracker layout or controls.

- Bundled a separate recovery companion that snapshots settings at login, every 10 minutes, and on logout/reload, and restores them when the main save is missing or empty. Existing settings take priority. WoW writes snapshots to disk only on reload/logout; this cannot bypass a client failure to load both saves. Legacy local presets remain supported, and personal settings are excluded from packages.

- Added a compact 120-by-90 FPS, world latency, and movement-speed window with aligned numeric values, units in the labels, saved position, drag/lock controls, and per-stat hover tooltips that remain available when locked (`/ztf stats`).

- Synchronized the full-button range overlay with Blizzard's keybind range update, removing the visible polling delay.

- Added full-icon red out-of-range indicators on Blizzard action buttons, enabled by default with an Action Bars toggle (`/ztf range`). Matches the retail overlay, with combat-safe setup and guarded modern/legacy range checks.

- Added opt-in quest auto accept and turn-in with Shift/Ctrl/Alt/None pause controls and manual handling of multiple reward choices (`/ztf quests`).

- Added single-pass Fast Loot with a saved 0–200 ms delay slider, fine 1 ms steps, mouse-wheel adjustment, and Auto Loot modifier support (`/ztf loot`).

- Added retail-style class-colored player tooltip names, enabled by default, with a Tooltips settings page (`/ztf tooltips`) and older-client fallback.

- Release tag pushes now automatically upload to Forever CurseForge project 1700355 and publish the GitHub release.

- Added opt-in native bulk junk selling without opening a confirmation popup, and personal/guild-bank auto repair under Vendor. Includes per-visit limits, delayed-proceeds checks, and Shift-to-skip.

- Centered castbar spell names inside customized bars, with font sizing based on bar dimensions, bounded single-line text, and native text layout restoration when customization is disabled.

- Added player/target/focus castbar size controls with an experimental preview using the actual Blizzard castbar's Edit Mode visibility. Includes cleanup on page close, casts, combat, and full Edit Mode handoff.

- Added optional class-colored player, target, target-of-target, and focus health bars under Unit Frames (`/ztf unitframes`).

- Added GitHub checks, issue/PR templates, dependency updates, and draft release packaging.

## 0.2.0-beta

- Added the Windows & Bags settings page and retail window/bag movement.
- Added saved positions, scaling, move handles, and position/scale resets.
- Added beta event compatibility checks and combat guards for movement resets.

## 0.1.0-beta

- Initial Forever beta foundation with the ZoidsTools damage meters, theme, and minimap launcher.
- Added separate saved settings, meter previews, appearance options, and layout saving.
- Added runtime meter API checks and Lua 5.1 smoke tests.
