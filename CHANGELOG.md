# Changelog

All notable changes to Memory Forever, by Jacob Rozell. Releases follow [semver](https://semver.org/). History from Adriano Castro's Memory, through 1.6.0, is in the `upstream-1.6.0` tag and earlier tags.

## [2.0.0-beta.1] - unreleased

### Changed
- The current moment belongs to the character. Existing characters keep the moment that was current for the whole account. `/mem moment off` clears it.
- The journal uses a flat dark panel, in the same style as Questie's tracker, instead of the stock dialog frame.

### Added
- Returning to a place also says how long you have spent there, how many quests you turned in, and your level on the first visit.
- Dying after 5 minutes without a death says how long that stretch lasted.
- Leaving a dungeon or raid records the run: how long it was, how many times you died, and who was with you.
- The first time you equip an item. Gear you were already wearing is not counted.
- Campfires, from the Camping buff, with the place and how many times.
- Pop-ups wrap onto extra lines and stay up long enough to read. Journal tabs sit on two rows. Dates, tooltips, and reminder sentences are punctuated.
- Campfires also remember the camp feature you sat by (a Sharpening Wheel, a Mana Well, and the other Forever camp objects) and who was at the fire with you. `/mem buffs` lists your current buffs when a feature name needs checking.
- The first visit to Zephras Isle, the Riverglades, Shen'Dralas, and Mount Hyjal is named. So is the first run of each new Forever dungeon, Barrow Deeps, Hyjal Summit, and Onyxia's Lair.
- Level 25, 45, and 60, and crafting skill 150, 225, and 300, are called out as Legacy milestones. The skill you already have at login is not.
- The first Skyborne you group with, and the first human hunter, dwarf shaman, gnome priest, orc mage, troll warlock, or undead paladin.
- Each area the client announces as discovered. Coming back to a zone says how many areas you have found there.
- The first login after a Forever build or interface change says the old build, the new build, and that this version was checked on build 70009. `/mem status` shows the client build.
- A second saved copy, `MemoryForeverDB_Backup`. A missing character or a missing count is restored from it. A schema update runs on a copy and is kept only when it finishes.
- Saved data is loaded before the addon (`LoadSavedVariablesFirst`), so a late load cannot replace the file with an empty database.

### Fixed
- The first time a level is stored is kept when `PLAYER_LEVEL_UP` fires again.
- A memory slot that already holds something else is left alone. A broken count on a real memory is repaired.
- A value the client cannot save is removed before writing, so one bad value cannot discard the saved file.

### Waiting on a client check
- A Hardcore death as one quiet line, once the ruleset is visible to addons.

### Tested
- Checked on Forever build 70009.
- Stub suite: 150 passed.

## [2.0.0-alpha.1] - 2026-11-17

First Memory Forever release, by Jacob Rozell, based on Memory 1.6.0 by Adriano Castro. Checked on the live client for load, reload, logout, zones, return pop-ups, open-world loot, item tooltips, vendors, fights, deaths, and the options panel. Dungeons, grouping, level-up screenshots, and quest turn-ins are not confirmed yet.

### Changed
- Renamed to **Memory Forever**. The folder is `MemoryForever`, the slash command is `/mem` (or `/memoryforever`) and the SavedVariable is `MemoryForeverDB`.
- Targets WoW: Forever only (`MemoryForever_Camelot.toc`, `## Interface: 16001`).
- Removed the Stormwind Library dependency. Its client detection treats Forever as Classic Era, and it hooks tooltip scripts that don't exist on the modern engine.
- Fights are recorded from target and focus during combat. The combat log is closed to addons.
- NPC interactions use the `npc` unit instead of matching frame titles.
- Tooltips use `TooltipDataProcessor`, and the unit is read from the tooltip.
- Loot is read from chat in the open world and from the loot window plus bag counts in instances.
- Group members are read out of combat only.
- Sentences say "yesterday" and "3 days ago" instead of "3 day(s) ago".

### Added
- A secret-value guard (`Safe`). Hidden unit and chat data skips a memory instead of raising Lua errors.
- Memory types are gated on the client's APIs and events and disabled quietly when something is missing (`/mem status`).
- Quest turn-in memories. Fixes the upstream known issue that quest NPCs weren't recorded.
- Per-place death counts.
- Return pop-ups ("You've been here 7 times... You died here 2 times") and repeat-death pop-ups, with throttling.
- Reminder style setting: chat (default), pop-up, both or off.
- Journal window with Zones, NPCs, Items, Players, Deaths, Levels, Moments, Here and Stats, plus search and sort.
- `/mem here` (per-place timeline) and `/mem stats`.
- Options panel under Options > AddOns, a minimap button and an AddOns compartment entry.
- `schemaVersion` with migrations, defensive SavedVariables init, and a one-time import of the original Memory data.
- A stubbed-client test suite under Lua 5.1, plus CI.

### Fixed (upstream bugs)
- Zone-level visits were never stored (`not zoneName == lastZone` was always false).
- Reading a memory created empty records as a side effect.
- Day differences could be fractional across DST changes.
- Localized loot strings with magic characters failed to match.
- Some helper variables leaked as globals.
