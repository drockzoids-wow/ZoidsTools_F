# ZoidsTools Forever

**A separate addon for WoW: Forever beta.** Install as `ZoidsTools_F`; this does not replace the retail `ZoidsTools` addon. Saved settings use `ZoidsTools_FDB` and releases contain a `ZoidsTools_F` folder. This project has its own Git repository and does not use the retail CurseForge project.

For the first GitHub upload, follow [GITHUB_SETUP.md](GITHUB_SETUP.md). For development and releases, see [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

Forever beta port of ZoidsTools, focused on damage meters, movable windows and bags, and the basic settings UI.
Targets the installed **1.60.1.69893** client with interface **160001** (derived from the client version; confirm with `/ztf status` in game).

## Included

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

Place this folder (named `ZoidsTools_F`) in `C:\Games\World of Warcraft\_classic_beta_\Interface\AddOns` or link it there.
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
