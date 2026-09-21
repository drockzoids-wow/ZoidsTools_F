# Localization

The addon automatically follows `GetLocale()`. English (`enUS`/`enGB`) is the fallback. Bundled translations cover German, French, Italian, Brazilian Portuguese, Russian, Korean, Simplified Chinese, Traditional Chinese, and the Spanish (`esES`/`esMX`) client locales. Spanish variants currently share most wording.

All 244 addon display strings are in the locale catalog, including settings, tooltips, chat notices, preview labels, and status messages. Item, spell, character, and faction names supplied by WoW are displayed as supplied by the client. Slash commands, saved-variable keys, frame names, and API identifiers are deliberately never translated.

The initial non-English text was drafted with Google's translation service with the project owner's approval, then checked for formatting and corrected for some recurring game terminology. It is **not native-speaker reviewed**. In-game layout and actual localized beta-client behavior remain to be verified. A missing or unknown translation falls back to English; no service is contacted by the installed addon.

## Editing a translation

- Edit only values in the relevant locale Lua file. Keep the English key unchanged.
- Preserve every `string.format` argument (`%s`, `%d`, `%.3f`, etc.) in the same order. Lua 5.1 does not support numbered argument reordering.
- Keep slash commands and addon names intact. Preserve paragraph breaks where practical.
- Add new keys to `enUS.lua`, reference them with `L["English source text"]`, and add each locale's translation. The source keys themselves are the English fallback.
- Run `python Tests/smoke.py` with the project's Lupa dependency. It validates all locale files, format strings, commands, API identifiers, and builds every settings page under each locale in the mocked UI.

Test in-game on the actual language client: inspect every settings page and tooltip, open dropdowns, preview the damage meters, check long labels, and verify Cyrillic/CJK glyphs. Wider non-English settings, wrapped button labels, client-selected fonts, and measured stats/campfire widths help accommodate translated text. Mocked tests do not establish pixel-perfect layout or translation fluency.

## Language-independent feature detection

Reputation matching resolves AreaTable IDs with `C_Map.GetAreaInfo` (or `GetAreaInfo` on legacy clients). These are area IDs, not UI map IDs. Original English aliases remain a fallback for missing beta data. Lookup results are cached; unavailable names retry on subsequent zone events.

Campfire detection uses aura spell IDs `1229739`, `1283391`, and `1289723`, verified against the [Forever campfire search data](https://www.wowhead.com/forever/search?q=campfire). The 36 supported camping item IDs are recorded from the [S'more Skills developer's camping catalog](https://github.com/Henrik8210/smore-skills/blob/main/CAMPING.md), which links to the [Forever item database](https://www.wowhead.com/forever/item=279956/mana-well#shared-cooldown). Only factual identifiers are used; no external addon code is bundled.

Known items require no translated tooltip matching. The English tooltip/name fallback remains for new items or aura variants on English clients. Unknown new beta items on other locales may require a catalog update: verify IDs against client data before adding them. Recipes remain excluded. No guessed machine translations are used as game-detection rules.
