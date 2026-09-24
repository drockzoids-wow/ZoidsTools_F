# ZoidsTools Forever

**A separate addon for WoW: Forever beta.** Install `ZoidsTools_F` into `Interface/AddOns`; this does not replace the retail `ZoidsTools` addon. Saved settings use `ZoidsTools_FDB`, with normal position and scale persistence. This project has its own Git repository and does not use the retail CurseForge project.

For the first GitHub upload, follow [GITHUB_SETUP.md](GITHUB_SETUP.md). For development and releases, see [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

Forever beta port of ZoidsTools, focused on damage meters, movable windows and bags, and the basic settings UI.
Targets the installed **1.60.1.69893** client with interface **160001** (derived from the client version; confirm with `/ztf status` in game).

## Languages

Automatically uses your WoW client language, with English fallback. All 244 display strings have bundled draft translations for German, French, Spanish (Spain and Latin America), Italian, Brazilian Portuguese, Russian, Korean, Simplified Chinese and Traditional Chinese. Translations need native-speaker and in-game review; no external service is used while playing. See [localization notes](Locales/README.md) for maintenance and beta detection limits.

## Included

- Consumable macro building under `/ztf macros` (also `/ztf food` or `/ztf water`), disabled by default. Enable **ZTF Health** and/or **ZTF Mana**, then drag them from the game's Macros window to your action bars. Uses non-buff food/water out of combat; optional combat lines try a carried Healthstone followed by a healing potion, or a mana potion. Healthstone and healing potion can both be consumed on one press if the game permits. Prefers conjured food/drinks, then restoration amount, and skips items above your level. Refreshes on bag changes after combat ends. Disabling leaves macros in place; full macro slots show an error. Macro names are separate from retail ZoidsTools. New labels use English fallback and detection currently relies on English item text. In-game validation on Forever beta is still needed.

- Automatic zone reputation tracking (`/ztf rep`, Quests): enabled by default. Tracks Ironforge in Dun Morogh, Loch Modan, Wetlands and Ironforge; Stormwind in its city and Elwynn/Westfall/Redridge/Duskwood; Darnassus in its city and Teldrassil/Darkshore. Horde home areas map to Orgrimmar, Thunder Bluff or Undercity. Booty Bay, Ratchet, Gadgetzan and Everlook take priority when their town names are reported. Localized area names come from the game; unmapped areas and instances preserve the watched faction. Uses native reputation display without changing XP visibility. Event-driven, with combat deferral and no idle polling. `/ztf rep off` disables it. Forever beta behavior needs in-game validation.

- Automatic campfire item bar under `/ztf campfire` (Action Bars). Shows with either the **Welcoming Campfire** or **Campfire Nearby** buff and matching usable items in carried bags. Detects 36 supported camping items and campfire buffs by ID in every language, retains English tooltip/name matching for new beta content, excludes recipes, combines stacks, and provides secure item clicks, counts, cooldowns, and tooltips. Drag the title to move it. Hidden during combat; deferred changes apply afterward. New beta items may need a catalog update on non-English clients. Uncached data is retried while near a campfire. Requires the modern bag/tooltip APIs and secure visibility driver; actual beta item use needs in-game validation.

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

Install the `ZoidsTools_F` release folder into `Interface/AddOns`. For a source checkout, place or link this project there as `ZoidsTools_F`.
Restart the client if it was open when the addon was first installed.

- `/ztf` (or `/zt`) opens settings; `/zoidsforever` also works.
- `/ztf preview` toggles sample data and movement/resizing.
- `/ztf on` and `/ztf off` control live meters.
- `/ztf status` reports the running client/interface and meter API availability.
- `/ztf windows` or `/ztf bags` opens Windows & Bags. Right-clicking the minimap button also opens this page.
- `/ztf windows on/off` toggles movement; `/ztf bags on/off` toggles bag movement under the main movement switch.

Window and bag movement starts enabled, matching retail ZoidsTools. Drag the **Move** handle at the top of a supported window or bag. Hold **Ctrl + mouse wheel** to scale from 60% to 180%, or **Ctrl + right-click** its handle to reset its position. Settings include bag handles, position saving, scaling, and separate reset-all buttons for positions and scales. Settings and saved positions are account-wide within this addon.

The windowed world map moves by its title bar and uses WoW's native position saving; it is not scaled. The retail exclusions for protected frames (including flight map and guild controls) remain. Action bars, unit frames, and third-party bag replacements are not part of this module. Unprotected bags remain draggable and retain saved positions in combat. Profession bags opened alone use the combined backpack's saved anchor; when the backpack is open, they use Blizzard's adjacent layout. Other windows and protected bags wait until combat ends; scaling and resets also wait.

Meters start disabled. Enable them in settings; this hides Blizzard's own meter windows. Turning ZoidsTools meters off does not automatically re-enable Blizzard's windows.
Preview mode displays sample values until you click **Lock meters**.
The retail ZoidsTools addon is not required; its files and saved settings are not modified.

## Validation status

Quest automation is opt-in under `/ztf quests`, with independent Auto Accept and Auto Turn-in toggles. Hold Shift (or select Ctrl, Alt, or None) to pause at each quest stage. Turn-in claims zero/one-choice rewards and leaves multiple choices for manual handling. Supports the modern gossip quest list and classic quest greetings. Test acceptance, a completed quest, a reward-choice quest, and your pause key in game.

Fast Loot is enabled by default and follows Blizzard's Auto Loot setting and modifier. Open `/ztf loot` to disable it or choose 0â€“200 ms between item requests in 1 ms steps. Drag the slider or use the mouse wheel over it for precise adjustment; the label shows seconds and milliseconds. It attempts each slot once per opening, with no second pass. Actual pickup timing depends on the server and Blizzard's own looting behavior. Test with several items, the Auto Loot modifier, and closing loot mid-pickup.

Player tooltip names use class colors by default, matching retail ZoidsTools. Open `/ztf tooltips` to toggle this. The module supports the retail line-data callback and an older-client tooltip fallback. Verify player and NPC hovers plus item tooltips in game after `/reload`; the automated tests cover color selection and fallback cleanup, but cannot verify the beta's rendering.

Castbar preview is experimental on Forever. It uses `isInEditMode` plus `UpdateShownState`, the visibility mechanism used in Blizzard's [castbar Edit Mode code](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_EditMode/Shared/EditModeManager.lua). It does not enter full Edit Mode or borrow its selection/settings dialogs. Position remains managed by Blizzard. The source reference is the live UI mirror; exact Forever beta behavior requires in-game validation. Missing preview methods produce a message instead of displaying a separate simulated castbar.

Preview ends on leaving the Castbars page, changing the selected bar or target/focus, starting a cast/channel, or entering combat. Visibility cleanup blocked by combat is completed afterward. Full Edit Mode takes ownership of its own previews; addon size changes are paused while it is open. Test normal casts/channels after closing a preview and after combat, and check size persistence after `/reload`.

Item tooltips show totals and per-character bag, bank, and equipped counts by default. Toggle them under Tooltips. Log into each character and visit each bank to record inventory; offline characters and closed banks show their last recorded counts. Shared banks are counted once when supported. Inventory is saved separately from settings presets and is limited to characters on this WoW account/client installation.

Under **Windows & Bags**, keep **Remember window positions** enabled. Positions and scales save normally on reload/logout.

Lua 5.1 syntax and mocked startup/capability tests are provided in `Tests/smoke.py` (Python with `lupa`).
Run `/ztf memory` for a fresh main-addon memory reading. Compare shortly after `/reload`, after opening settings and hovering items, and after a minute idle. This command does not force garbage collection; readings include temporary allocations and are not a CPU/FPS measurement.

To distinguish temporary startup allocations from memory still held after cleanup, run `/ztf memory collect` outside combat. It prints before/after main-addon readings around one Lua cleanup request. The cleanup applies to the whole UI and may briefly pause the game. It runs only when explicitly requested; this is a diagnostic, not an ongoing performance fix. A client or another addon can restrict cleanup, so an unchanged reading alone does not prove a leak.

`python Tests/memory.py` checks retained quest-data memory, inventory cache growth, and quest-filter allocations in Lua 5.1. Add `--compare-ref v0.2.5-beta` to compare with the previous storage format and verify quest fields. These isolated measurements exclude WoW UI objects and your live saved data.

Movement tests also cover window/bag dragging, saved-position restoration, scale limits, enable/disable controls, protected-frame exclusions, combat guards, and late-loaded windows.
These do not validate Blizzard's actual beta API signatures, secret-value behavior, or visual layout.
In-game compatibility is pending. If the beta does not expose `C_DamageMeter`, live meters remain unavailable; preview and settings still work.

In game, verify `/ztf status` reports interface 160001, open settings, preview and resize both windows, lock them, enable meters, and fight a target. Check damage/healing, current/overall/recent segments, details, a party fight, reset, and persistence after `/reload`. Test with script errors enabled. Report any Lua error and the `/ztf status` output.

For movement, open Character, spellbook, merchant, bank, individual bags and combined bags. Drag and scale them, close/reopen, and `/reload` to check persistence. Toggle movement and bag handles, test individual/global resets, then check the world map title bar. In combat, verify unprotected bags retain their positions and can be dragged, while protected bags, other windows, scaling, and resets remain blocked. Open a late-loaded panel such as the auction house after login.

## Source

Adapted from the sibling ZoidsTools project. Retail-only modules are excluded. Upstream libraries and the original license are retained. This first version intentionally has a focused settings window rather than the full retail tool dashboard.

### Saved settings

Settings, bag anchors, window positions/scales, and shared tracker layout use the main addon's normal SavedVariables. No backup commands, recovery timer, or beta reminder is needed. Existing main-addon settings are retained.

The temporary beta Recovery and Personal Preset companions are retired. Leave old companions disabled or remove their separate addon folders; do not delete the main addon's SavedVariables file.

### Completionist

The tracker position, lock, and minimized state are shared across characters and saved with the main addon settings. Quest discoveries remain per-character.

Open **Completionist** in `/ztf` settings or use `/ztf completionist`. `/ztfc` minimizes/expands the compact 360px tracker. Short filters, area lists, search, full quest tooltips, discovery and NPC details are included. Completion is read from this character's game records; missing data remains Unknown. The source inventory and pickup coverage remain provisional.

On a character with the standalone ZoidsForeverGuide enabled, its settings and discovered quests are imported into `ZoidsTools_FCompletionistDB` (per-character). The old Guide stays active until **Finish import** reloads the UI; it is disabled for that character when the game API supports it. If prompted, disable ZoidsForeverGuide manually, then reload. Visit each alt once with the old Guide enabled to import its own data. Original Guide saves are not changed or deleted. New installations need only ZoidsTools_F.

The quest inventory includes the September 18, 2026 Wowhead Forever snapshot and three verified Zephras Isle encounters. Approximate observed NPC positions remain tooltip information, not exact map pins.

Validate release inputs without creating a ZIP: `python Tools/package.py --tag v0.2.7-beta --validate-only`.


### Shared bag anchor

Under Windows & Bags, choose **Bag anchor corner** (bottom-right by default). Open the backpack and drag its Move handle to the desired location. Each carried bag uses that same position when open alone; multiple bags retain Blizzard's relative stacking. The combined bag shares this origin, while bank windows retain separate positions. Change corners with a bag open to preserve its current placement. Existing saved backpack/combined positions migrate when first opened. Keep Remember window positions enabled. Protected bag changes wait until combat ends. Ctrl-right-click or Reset all positions clears the shared bag anchor.
