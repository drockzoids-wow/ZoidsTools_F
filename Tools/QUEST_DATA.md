# Refreshing the Forever quest inventory

Run these tools outside WoW. They read public pages as data; the addon itself does not contact websites. Use a fresh cache directory for each snapshot, or `-Resume` to resume interrupted downloads from the same snapshot.

```powershell
./Tools/collect_forever_quests.ps1 -OutputDirectory build/quest-refresh
./Tools/collect_secondary_quests.ps1 -OutputDirectory build/quest-refresh
python Tools/import_forever_quests.py --cache build/quest-refresh
# Inspect build/quest-refresh/import-report.json before writing:
python Tools/import_forever_quests.py --cache build/quest-refresh --write
```

Wowhead lists are recursively partitioned by quest level and then required level. Truncated terminal partitions, ignored filters, malformed lists and missing unfiltered-page IDs are errors. The collector caches HTML plus parsed records and a request ledger. Root-count discrepancies stop collection after writing diagnostic data; review them before using the importer's explicit `--allow-count-mismatch` option. Do not assume a headline total proves complete coverage.

The September 25 snapshot supplied 5,196 unique IDs from untruncated partitions, versus 5,193 in the root headline. A repeat root fetch still reported 5,193; every ID shown on that root page is included. This discrepancy remains unresolved and is recorded in `Completionist/Sources.json`, rather than claiming a perfect inventory of all playable quests.

The 60.tools accessible index contains 4,597 ID/name links. Its table pagination has overlapping/missing boundaries, so the full linked index is the coverage authority; detail pages supply extra records. Only extra quests explicitly marked as listed in the Forever client are added. Ten qualified in this snapshot; 34 Classic-only extras were excluded. Those ten retain a tooltip identifying their inherited Classic details. The Forever wiki's 1,578-record coverage ledger was also reviewed; it describes mixed client/observation snapshots and was not used as an additional bulk import.

The merge keeps earlier absent IDs with a tooltip note, preserves the three bundled beta observations, and never writes character SavedVariables. All 17 character discoveries checked on September 25 occur in the new Wowhead data. Saved NPC observations remain available in tooltips after those IDs become bundled. Completion always comes from the current character's game APIs.

`Sources.json` records added, updated, retained and excluded IDs, secondary evidence links, counts and collection URLs. Cached HTML stays in ignored `build/`; it is not packaged. Refresh changelog/docs and run `Tests/completionist.py`, `Tests/quest_data.py`, `Tests/memory.py`, and packaging with `--validate-only`. Do not run archive-building tests for routine data refreshes.
