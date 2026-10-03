# Installed Forever quest-data audit

Audited September 26, 2026, from the active `wow_classic_beta` installation,
build **1.60.1.70009**. Game archives were read with WoW and Battle.net closed.
No game files or SavedVariables were changed. The addon is installed through
the repository junction, so its source changes apply directly.

## Findings

| Source | Result |
| --- | --- |
| QuestV2 | 6,694 records: 6,605 readable, 89 in encrypted sections |
| Readable IDs absent from Completionist | 1,423 candidates; titles and availability unknown |
| Existing Completionist inventory | 6,090 quests, unchanged |
| Addon IDs absent from readable QuestV2 | 908; not evidence that those quests should be removed |
| Saved quest cache after logout | 195 structurally valid records; every ID already in Completionist |
| Local hotfix cache | 39,814 records; zero for the quest/map tables checked |
| QuestLine / QuestLineXQuest | 3 storylines, 22 quest memberships |
| QuestPOIBlob / QuestPOIPoint | 54 blobs, 99 points, 22 quest IDs |
| Completion markers | 23 single-point markers across 22 quests |
| Other markers | 23 with index 32 (unclassified); 8 objective blobs with index 0 or 1 |
| QuestV2CliTask, QuestObjective, QuestHub, CollectableSourceQuest, CollectableSourceQuestSparse | Empty in this build |

The [machine-readable report](client-quests-70009.json) contains all candidate
IDs, encrypted-section IDs, cache record offsets, all 54 map blobs and their
points, storyline evidence, extraction file IDs, and SHA-256 hashes. It does
not contain the game archives or the cache's quest text.

## Added to Completionist

The tooltips for these already-listed quests now show client storyline order
and completion-marker coordinates. Quest names below come from the existing
addon list; the archive tables did not supply these quest titles.

| Quest ID | Existing title | Client completion marker |
| --- | --- | --- |
| 92742 | Testing the Wells | Westfall 52.5, 53.0 |
| 92744 | Murloc Gills | Westfall 52.5, 53.0 |
| 92745 | The State of the Mines | Westfall 52.5, 53.0 |
| 92747 | Moonbrook Espionage | Westfall 52.5, 53.0 |
| 92748 | Explosive Consultation | Stormwind City 61.9, 30.6 |
| 92749 | A Dynamite Plan | Stormwind City 61.9, 30.6 |
| 92750 | Detonation at a Distance | Elwynn Forest 34.8, 37.5 |
| 92751 | Detonation at a Distance | Stormwind City 61.9, 30.6 |
| 92752 | Explosive Consultation | Westfall 52.5, 53.0 |
| 92753 | Destruction in Deadmines | Westfall 38.7, 83.7 |
| 92819 | Destruction in Deadmines | Westfall 38.7, 83.7 |

All 11 belong to the **Toxic Soil** storyline in the order shown. Storyline
order is not a prerequisite graph and does not prove every step is required.

Evidence is also bundled for quest **91564**, in the **To Have Loved and Lost**
storyline (Mount Hyjal 15.6, 50.0), and **96912–96921**, in **PvP Season Journey**
(Tanaris 51.9, 27.2; 96913 also has 51.0, 27.0). Those 11 IDs are not added as
named playable quests. If discovered in game later, their tooltips can use this
evidence. A storyline title is not assumed to be a quest title.

## Interpretation and limits

QuestV2 contains ID, UniqueBitFlag, and UiQuestDetailsThemeID. It does not supply
quest titles, faction restrictions, levels, prerequisites, or current server
availability. The extra 1,423 IDs therefore remain candidates in the report.
The 89 encrypted IDs are listed separately and their payloads are not decoded.

Completion markers use objective index **-1**, the documented completion-POI
convention. They are labeled as client markers, not verified NPC spawn or
pickup locations. Index **32** is preserved without interpreting it as a
pickup marker. The extracted tables contain no verified quest-giver NPC
identity or pickup/turn-in relationship for these points.

World coordinates are converted with the matching UiMapAssignment region and
UI rectangle, reversing and exchanging the world X/Y axes. Each point must
match exactly one non-WMO assignment for its MapID and UiMapID and lie inside
its XYZ region. All 99 points passed that check. Normalized map coordinates
are multiplied by 100 for display. These conversions have not yet been
checked against the map in the running game.

The WDB cache is indexed using its header, record lengths, and repeated quest
ID. Its variable text payload is not imported: its layout cannot safely be
assumed to match a network quest-query packet. This cache is a partial local
history, not an all-characters completion database or a complete quest catalog.
The hotfix audit checks every manifest table with Quest in its name plus
UiMap and UiMapAssignment; none require overlaying on these extracted tables.

## Repeating the audit

Use Python 3 and an official Windows TACTTool executable. Close the game and
launcher, then choose a fresh output directory outside the game installation:

```powershell
python Tools/extract_client_quests.py --game 'C:\Games\World of Warcraft' --tool '<path-to-TACTTool.exe>' --output build/client-audit-70009
python Tools/read_client_quests.py --input build/client-audit-70009 --write-addon --report Tools/reports/client-quests-70009.json
python Tests/client_data.py
```

The extractor selects numeric FileDataIDs, bypassing the filename-list
download that failed in the first attempt. Child crash dialogs are suppressed;
failures are reported in extraction logs. The successful audit used local
archive data. The wrapper stops if the reader reports a download fallback.
The extractor requires this build and the decoder requires the audited layout
hashes; future builds need a fresh layout review before import.

Full decoded research output stays under ignored `build/`. The addon loads
only the small `Completionist/ClientData.lua` evidence table, not the report,
candidate IDs, archive cache, or parser tools.

## Format references

- [TACTSharp / TACTTool](https://github.com/wowdev/TACTSharp), release 0.2.0-alpha1: archive reader.
- [WoWDBDefs definitions and manifest](https://github.com/wowdev/WoWDBDefs): FileDataIDs, table hashes, and DB2 field layouts.
- [DBCD](https://github.com/wowdev/DBCD): WDC5 and hotfix-cache format implementation.
- [TrinityCore quest_poi documentation](https://trinitycore.info/database/335/world/quest_poi): historical objective-index completion convention; not evidence of current quest availability.

These references explain file formats. The imported coordinates and storylines
come from this installed game build, not website quest records.
