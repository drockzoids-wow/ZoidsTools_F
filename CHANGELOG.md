# Changelog

## Unreleased

## 0.2.9-beta

- Automatically remove screen-edge clamping from the minimap cluster and map frames, allowing corner placement through Edit Mode without a toggle. Defer changes during combat.
- Correct the Forever daytime indicator to target `MinimapCluster.DielFrame`. Hide the separate calendar icon with the compact header; left-click the clock for calendar and right-click for stopwatch.
- Rebalance the compact minimap header with a smaller clock and more room for readable location text. Anchor the daytime indicator at the map's top-right corner and move mail to the bottom-left while the header is enabled.
- Port retail minimap options: square mask with class-colored border, compact zone/clock/tracking header, addon-compartment hiding, mouseover addon buttons, and an expandable button collector. Configure with `/ztf minimap` or Minimap options in settings. Options default off, restore the previous layout when disabled, and defer layout changes during combat; skip unavailable widgets and protected addon buttons.
- Add a per-character buff bar lock that prevents dragging and hides the movement hint, including in preview.
- Add a per-character missing-buff bar size slider (50–200%), scaling the icons and heading together.
- Center each row of missing-buff icons beneath the heading, including single buffs and partially filled rows.
- Add quiet missing-buff reminders with per-character class choices, optional Thorns and situational buffs, custom spell IDs, rank/group-equivalent detection, and a movable preview. Hide in combat, while dead, or mounted; recheck after resurrection. Configure with `/ztf buffs` or Unit Frames settings. Unreadable aura data never becomes a false missing-buff warning.
- Fix quest-item mouse handling: explicitly enable the button's mouse input and prevent the cooldown from intercepting clicks/drags. Move mode accepts left- or right-drag and displays a MOVE label; locking restores item use. Proximity refreshes leave an active drag alone. Keep right-drag available outside Move mode and preserve saved positioning.
- Replace the quest-item button's mismatched quickslot artwork with a fitted border and inset icon/cooldown.

## 0.2.8-beta

- Add a movable nearby quest-item button, enabled by default under Quests. Select active quest-log items inside the quest area, within 250 yards, or in confirmed item range; show charges and cooldowns, preserve the bound item during combat, and defer selection/visibility changes until combat ends. Saved positioning and a move preview match the retail tool's workflow.
- Expand Completionist from 5,332 to 6,090 bundled quests: add 748 Wowhead Forever IDs and 10 additional Forever-client-listed IDs from 60.tools, update 229 existing records, and retain 884 earlier records absent from the current Wowhead index with an availability note. Include all 17 saved character discoveries in the shared inventory without changing character completion.
- Show matching and total quest counts separately; preserve saved character observation tooltips when a discovered quest enters the bundled database. Add repeatable data collection/import tools and a source/coverage manifest, including the three-record discrepancy between Wowhead's headline and filtered lists.
- Add a permanent leftmost SIT button to the campfire bar that runs /sit. Keep the bar available near campfires even with no usable campfire items; retain item cooldowns, saved positioning, and combat hiding.

## 0.2.7-beta

- Remove the temporary beta settings recovery system: companion addon, automatic backup snapshots, fixed-preset helper, restore commands, and reminder/save/restore UI. Releases now contain only the main addon.
- Preserve existing main-addon settings and normal bag/window position and scale saving, shared Completionist layout, and active-drag saving on reload/logout. Old beta backups no longer override current settings.

## 0.2.6-beta

- Reduce Completionist quest-record memory with compact records while preserving all quest fields and discoveries. Reuse the class filter lookup instead of allocating it once per quest.
- Keep only the most recent inventory tooltip lookup instead of indexing every stored item; preserve character, equipment, and bank totals.
- Remove per-frame temporary tables from the native tracker minimization check.
- Add repeatable Lua memory checks for quest data, filtering, and inventory caches.
- Add `/ztf memory` for an on-demand client memory reading without forcing garbage collection.
- Add an explicit, out-of-combat `/ztf memory collect` diagnostic to compare startup memory before and after a single cleanup request; never collect automatically.

## 0.2.5-beta

- Keep inventory snapshots private when generating a fixed settings fallback, so loading a preset cannot overwrite current item tracking.

- Add Back up & reload and Restore preset buttons to Windows & Bags, with saved bag-anchor status. Explicit backups capture the visible bag layout; reload/logout finishes active drags. Immediately snapshot layout edits and recover newer positions/scales from recovery saves or presets even when the main save is nonempty but stale; newer intentional resets remain respected.

- Add default-on item tooltip totals and class-colored character rows with bag, bank, and equipped counts, adapted from ZoidsTools. Record each character on login and banks on visits; support legacy banks and modern shared banks without double-counting. Keep inventory snapshots separate from settings presets. Toggle under Tooltips; new text falls back to English.

## 0.2.4-beta

- Add a Windows Save-BetaPreset.ps1 helper for the confirmed beta failure to load either SavedVariables file. It creates a private fixed-file companion from an explicitly saved preset, backs up previous fallback files, and never modifies WTF files. Release packages include the helper, never generated personal settings.

- Detect older Recovery companions that cannot save personal presets; explain the required update and stop Save & reload before reloading.

- Mirror explicitly saved presets into the bundled Recovery addon's separate SavedVariables file. Restore and the reminder button can use that copy when the beta fails to load the main file, without a private Preset addon. Automatic snapshots preserve the chosen restore point; missing-preset messages now explain saving and recovery.

- Show a dismissible beta settings reminder on login and UI reload with Save & reload, Restore preset, and Later buttons. Restore requires an existing preset; save/restore controls pause during combat. No settings are restored automatically by the reminder.

- Added a persistent beta settings reminder banner to every settings section: save a preset after setup, reload to write it to disk, and restore it after login if settings reset. The banner explains that restoring replaces later changes.

- Added selectable bag anchor corners (bottom-right by default). Carried bags share the saved solo origin, while native multi-bag stacking is retained; existing backpack/combined positions migrate when opened. Bank windows retain independent positions.

- Retain the separate recovery companion after live testing showed that same-file backups did not replace the beta fallback. Explicit preset restoration prefers an installed fixed local preset over the in-file copy.

- Built settings recovery into the main addon, with automatic backup snapshots and `/ztf savepreset` personal restore points. Existing recovery/preset companions import automatically and remain optional for stronger separate-file protection. Release packaging retains the separate recovery companion for beta reliability and contains no personal presets.

- Profession bags opened without the combined backpack now borrow its saved anchor; reopening the backpack restores Blizzard's adjacent layout without overwriting either saved position. Works with the existing combat movement rules.
- Fixed combat bag-position restoration incorrectly deferring screen-relative anchors when UIParent reports protected. Individual and combined bags now use the same saved position through combat transitions.
- Keep unprotected bag windows draggable and restore their saved positions during combat, including bags first opened in combat. Protected frames still defer movement until combat ends.
- Store Completionist position, lock, and minimized state globally in the main addon save, with immediate recovery snapshots and revision-based restoration from newer backups. Character save failures no longer reset the shared layout; quest discoveries remain per-character.
- Fixed Completionist position restoration so startup does not overwrite the saved anchor, minimized windows restore at their saved size, and reload/logout finishes an active drag before saving.

- Snapshot macro option changes immediately through the recovery companion. Revisioned macro settings recover from a newer backup or versioned local preset even when the main save is nonempty but stale; newer explicit disable choices remain respected, and unrelated settings are preserved.

- Fixed shared settings checkboxes treating a numeric checked state (`1`) as disabled. Macro enable switches now save a boolean correctly for both checkbox API forms; regression tests click the real controls and preserve their values across three reloads.

- Integrated the Guide as Completionist (`/ztf completionist`, tracker shortcut `/ztfc`), with a 360px compact tracker, shorter controls and status labels, per-character discoveries, area grouping, and NPC details. Existing standalone Guide settings/discoveries import once; a reload retires the old addon for that character. Includes the three verified Zephras Isle quests.
- Removed the Guide map exclamation markers and their toggle; Completionist does not load map-provider code.
- Added packaging validation without creating an archive (`--validate-only`).

- Added opt-in food/water macro building under `/ztf macros`, ported from ZoidsTools. Separate `ZTF Health` and `ZTF Mana` macros select carried non-buff food/drinks and optional combat Healthstones/healing or mana potions. Includes older Healthstone ranks, level filtering, bag-change refresh, combat deferral, macro-slot failure status, and regression coverage. New labels fall back to English; consumable detection currently relies on English item text.

- Added automatic client-language selection and bundled draft translations for all 244 display strings across German, French, Spanish (Spain/Latin America), Italian, Brazilian Portuguese, Russian, Korean, Simplified Chinese and Traditional Chinese. English remains the fallback; no runtime translation service is used. Native-speaker and in-game review are still needed.
- Localized settings, tooltips, meter labels/previews, status messages and chat notices while preserving commands, saved settings and API identifiers. Added wider translated settings pages, wrapped button text, client-selected fonts, and stats sizing based on label width.
- Reputation area matching now resolves localized names from game area IDs. Campfire buffs and 36 supported camping items use numeric identifiers independent of language; English detection remains a fallback for new beta content.
- Added locale completeness, format/command preservation, multilingual settings startup, and localized detection regression checks.

## 0.2.3-beta

- Added automatic watched reputation selection for recognized Alliance/Horde home zones and neutral towns, enabled by default under Quests (`/ztf rep`). Uses English zone/subzone names and zone events, retains the selection in unmapped areas, and defers changes during combat. Unknown factions are retried on reputation updates; manual selections persist until entering an area mapped to a different faction. Legacy clients require the faction to be visible in the reputation list.

- Fixed the campfire item bar to appear with either Campfire Nearby or Welcoming Campfire when matching usable items are carried.
- Enlarged and corrected the campfire bar title to "CAMPFIRE NEARBY". The bar now fits the heading at minimum, grows for additional items, and centers each item row with thin gold item outlines.

## 0.2.2-beta

- Added `/ztf recovery` to report which settings sources were available before startup defaults and snapshots, so a failed login load remains diagnosable after the timer runs.
- Added optional `ZoidsTools_F_Preset` load ordering for a separate, private fixed-preset addon when both SavedVariables files fail to load. Personal presets are not included in releases and do not update automatically.
- Added `/ztf restorepreset` to explicitly replace current settings from an installed local preset, refresh the recovery snapshot, and reload the UI. This is blocked during combat.

## 0.2.1-beta

- Added an automatic campfire item bar, enabled by default: appears with Welcoming Campfire and carried usable items whose English tooltips require a campfire. Includes item counts, cooldowns, tooltips, saved dragging, and secure combat hiding (`/ztf campfire`).

- Added button-only objective tracker minimization, enabled by default under Quests. Collapsing hides the title/header artwork and background; expanding restores their native appearance without changing tracker layout or controls.

- Bundled a separate recovery companion that snapshots settings at login, every 10 minutes, and on logout/reload, and restores them when the main save is missing or empty. Existing settings take priority. WoW writes snapshots to disk only on reload/logout; this cannot bypass a client failure to load both saves. Legacy local presets remain supported, and personal settings are excluded from packages.

- Added a compact 120-by-90 FPS, world latency, and movement-speed window with aligned numeric values, units in the labels, saved position, drag/lock controls, and per-stat hover tooltips that remain available when locked (`/ztf stats`).

- Synchronized the full-button range overlay with Blizzard's keybind range update, removing the visible polling delay.

- Added full-icon red out-of-range indicators on Blizzard action buttons, enabled by default with an Action Bars toggle (`/ztf range`). Matches the retail overlay, with combat-safe setup and guarded modern/legacy range checks.

- Added opt-in quest auto accept and turn-in with Shift/Ctrl/Alt/None pause controls and manual handling of multiple reward choices (`/ztf quests`).

- Added single-pass Fast Loot with a saved 0â€“200 ms delay slider, fine 1 ms steps, mouse-wheel adjustment, and Auto Loot modifier support (`/ztf loot`).

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
