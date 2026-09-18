# ZoidsTools Forever

**A separate addon for WoW: Forever beta.** Install both release folders, `ZoidsTools_F` and `ZoidsTools_F_Recovery`, into `Interface/AddOns`; this does not replace the retail `ZoidsTools` addon. Saved settings use `ZoidsTools_FDB`, with a separate recovery save. This project has its own Git repository and does not use the retail CurseForge project.

For the first GitHub upload, follow [GITHUB_SETUP.md](GITHUB_SETUP.md). For development and releases, see [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

Forever beta port of ZoidsTools, focused on damage meters, movable windows and bags, and the basic settings UI.
Targets the installed **1.60.1.69893** client with interface **160001** (derived from the client version; confirm with `/ztf status` in game).

## Included

- Automatic campfire item bar under `/ztf campfire` (Action Bars). Shows only with the exact **Welcoming Campfire** buff and matching usable items in carried bags. Detects **Requires a Campfire nearby** in English tooltips, excludes recipes, combines stacks, and provides secure item clicks, counts, cooldowns, and tooltips. Drag the title to move it. Hidden during combat; deferred changes apply afterward. Buff and item detection currently target the English client. Uncached data is retried while near a campfire. Requires the modern bag/tooltip APIs and secure visibility driver; actual beta item use needs in-game validation.

- Button-only objective tracker minimization: collapsed trackers show the native + button with the title and background hidden. Expansion restores the normal appearance. Enabled by default; toggle under `/ztf quests`. Edit Mode temporarily shows the native appearance.

- A compact stats window with FPS, world latency, and current movement speed. Enabled by default; drag to place it and open `/ztf stats` to lock, hide, or reset. Locked mode stays visible with per-stat tooltips, including home/world latency. Speed is relative to normal running (100%), with 0% while stationary. Position and lock state persist. Locked clicks pass through when the client supports separate click and hover handling.

- Full-icon red out-of-range indicators on Blizzard action bars, enabled by default. Open `/ztf range` or `/ztf actionbars` to toggle. Matches the retail ZoidsTools overlay and clears for in-range or unknown-range actions. Third-party bars and dedicated pet/stance buttons are not covered. Verify target changes, moving in/out of range, paging, combat, and the toggle in game on Forever beta.

- Vendor automation under `/ztf vendor`: native bulk junk selling without opening its confirmation, and personal-gold or guild-bank-only repairs. Both start disabled. Hold Shift when opening a vendor to skip that visit. Uses Blizzard's junk selection rules; bulk-sold junk cannot be bought back. Unsupported bulk APIs/buttons skip auto selling instead of selling slot by slot. Guild mode does not fall back to personal gold.

- Custom castbar width/height for player, target, and focus under `/ztf castbars`. Click **Preview this castbar** to keep the actual native bar visible during adjustments. Target/focus frames must be visible. Size overrides start disabled; turning them off restores captured native dimensions.

- Optional class-colored health bars on the default player, target, target-of-target, and focus frames. Open `/ztf unitframes` and enable **Class-colored health bars**. NPCs and vehicles keep native colors; protected frame updates wait until combat ends. This option starts disabled, matching retail ZoidsTools.

- Original ZoidsTools meter rendering, two windows, type selection, current/overall/recent segments, player details, scrolling, snapping, and resizing.
- Original gold/dark theme, controls, artwork, and minimap launcher.
- A compact meter settings window, text size, opacity, class-colored borders, and one account-wide saved layout.
- Separate `ZoidsTools_FDB` settings, global frame names, and `/ztf` commands.
- Capability and event checks for beta API differences. No combat-log fallback or restricted-data bypass.
- Retail window/bag movement, saved positions, Ctrl-wheel scaling, reset controls, and a Windows & Bags settings page. Detects supported Blizzard panels as they load, including legacy auction, quest log, and crafting windows.

## Install and use

Extract both folders from the release ZIP into `C:\Games\World of Warcraft\_classic_beta_\Interface\AddOns` and enable both addons. For a source checkout, place or link the project as `ZoidsTools_F` and its `Recovery` folder separately as `ZoidsTools_F_Recovery` beside it.
Restart the client if it was open when the addon was first installed.

- `/ztf` (or `/zt`) opens settings; `/zoidsforever` also works.
- `/ztf preview` toggles sample data and movement/resizing.
- `/ztf on` and `/ztf off` control live meters.
- `/ztf status` reports the running client/interface and meter API availability.
- `/ztf windows` or `/ztf bags` opens Windows & Bags. Right-clicking the minimap button also opens this page.
- `/ztf windows on/off` toggles movement; `/ztf bags on/off` toggles bag movement under the main movement switch.

Window and bag movement starts enabled, matching retail ZoidsTools. Drag the **Move** handle at the top of a supported window or bag. Hold **Ctrl + mouse wheel** to scale from 60% to 180%, or **Ctrl + right-click** its handle to reset its position. Settings include bag handles, position saving, scaling, and separate reset-all buttons for positions and scales. Settings and saved positions are account-wide within this addon.

The windowed world map moves by its title bar and uses WoW's native position saving; it is not scaled. The retail exclusions for protected frames (including flight map and guild controls) remain. Action bars, unit frames, and third-party bag replacements are not part of this module. Movement pauses during combat; resets cannot clear saved layouts in combat.

Meters start disabled. Enable them in settings; this hides Blizzard's own meter windows. Turning ZoidsTools meters off does not automatically re-enable Blizzard's windows.
Preview mode displays sample values until you click **Lock meters**.
The retail ZoidsTools addon is not required; its files and saved settings are not modified.

## Validation status

Quest automation is opt-in under `/ztf quests`, with independent Auto Accept and Auto Turn-in toggles. Hold Shift (or select Ctrl, Alt, or None) to pause at each quest stage. Turn-in claims zero/one-choice rewards and leaves multiple choices for manual handling. Supports the modern gossip quest list and classic quest greetings. Test acceptance, a completed quest, a reward-choice quest, and your pause key in game.

Fast Loot is enabled by default and follows Blizzard's Auto Loot setting and modifier. Open `/ztf loot` to disable it or choose 0–200 ms between item requests in 1 ms steps. Drag the slider or use the mouse wheel over it for precise adjustment; the label shows seconds and milliseconds. It attempts each slot once per opening, with no second pass. Actual pickup timing depends on the server and Blizzard's own looting behavior. Test with several items, the Auto Loot modifier, and closing loot mid-pickup.

Player tooltip names use class colors by default, matching retail ZoidsTools. Open `/ztf tooltips` to toggle this. The module supports the retail line-data callback and an older-client tooltip fallback. Verify player and NPC hovers plus item tooltips in game after `/reload`; the automated tests cover color selection and fallback cleanup, but cannot verify the beta's rendering.

Castbar preview is experimental on Forever. It uses `isInEditMode` plus `UpdateShownState`, the visibility mechanism used in Blizzard's [castbar Edit Mode code](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua). It does not enter full Edit Mode or borrow its selection/settings dialogs. Position remains managed by Blizzard. The source reference is the live UI mirror; exact Forever beta behavior requires in-game validation. Missing preview methods produce a message instead of displaying a separate simulated castbar.

Preview ends on leaving the Castbars page, changing the selected bar or target/focus, starting a cast/channel, or entering combat. Visibility cleanup blocked by combat is completed afterward. Full Edit Mode takes ownership of its own previews; addon size changes are paused while it is open. Test normal casts/channels after closing a preview and after combat, and check size persistence after `/reload`.

Lua 5.1 syntax and mocked startup/capability tests are provided in `Tests/smoke.py` (Python with `lupa`).
Movement tests also cover window/bag dragging, saved-position restoration, scale limits, enable/disable controls, protected-frame exclusions, combat guards, and late-loaded windows.
These do not validate Blizzard's actual beta API signatures, secret-value behavior, or visual layout.
In-game compatibility is pending. If the beta does not expose `C_DamageMeter`, live meters remain unavailable; preview and settings still work.

In game, verify `/ztf status` reports interface 160001, open settings, preview and resize both windows, lock them, enable meters, and fight a target. Check damage/healing, current/overall/recent segments, details, a party fight, reset, and persistence after `/reload`. Test with script errors enabled. Report any Lua error and the `/ztf status` output.

For movement, open Character, spellbook, merchant, bank, individual bags and combined bags. Drag and scale them, close/reopen, and `/reload` to check persistence. Toggle movement and bag handles, test individual/global resets, then check the world map title bar. Verify no movement or reset occurs during combat, and open a late-loaded panel such as the auction house after login.

## Source

Adapted from the sibling ZoidsTools project. Retail-only modules are excluded. Upstream libraries and the original license are retained. This first version intentionally has a focused settings window rather than the full retail tool dashboard.

### Automatic settings recovery

Releases include the `ZoidsTools_F_Recovery` companion. Keep both addons enabled and restart WoW after first installing it. It copies the current addon settings at login, every 10 minutes, and on logout/UI reload. This includes toggles, positions, scales, and saved layouts, not live combat data. One latest snapshot is kept in the companion's separate `ZoidsTools_FRecoveryDB` SavedVariable. If the main settings are missing or empty at startup, ZoidsTools restores this snapshot and prints a notice. Successfully loaded main settings always take priority. The main addon also works with the companion disabled.

The 10-minute timer updates the snapshot in memory. WoW writes it to `WTF/Account/<account>/SavedVariables/ZoidsTools_F_Recovery.lua` on `/reload` or logout; addons cannot force a background disk save or rewrite their own Lua files. A crash before that write can lose changes, and a beta bug that fails to load both SavedVariables files cannot be repaired by this companion. After configuring your UI, `/reload` to let the client write both saves. Actual Forever beta disk persistence still needs in-game verification.

Release packages contain only the recovery code, never personal settings. The older fixed `ZoidsTools_FRecovery` preset remains supported when using the old local companion, but installing the bundled companion replaces its `Recovery.lua`. Preserve any custom fixed preset outside the addon folder before upgrading; the new companion captures the settings currently loaded in game and does not import a replaced preset from disk.

Use `/ztf recovery` after a reset to see whether the main save, recovery save, and local preset were available at startup, before defaults or later snapshots changed memory. A populated file on disk alone does not prove the client loaded it.

For a client that fails to load both saves, a separate private addon named `ZoidsTools_F_Preset` can supply `ZoidsTools_FRecovery` as ordinary Lua source. The main addon loads after this optional preset and uses it only if both the main settings and recovery snapshot are missing. Keep that preset folder when updating the two release folders. This is a fixed rescue copy, not an automatic disk backup; later changes require refreshing the preset outside WoW. Never publish a personal preset in the release ZIP.

With a local preset installed, `/ztf restorepreset` explicitly replaces current settings from that preset, updates the recovery snapshot, and reloads the UI. Use it if reset defaults have already become a nonempty main save. It cannot be used during combat; it discards settings changes made since the fixed preset was captured.
