# Export schema v1

The clipboard format is one UTF-8 JSON object, with no compression or prefix. Read schemaVersion before importing. Unknown optional fields may be ignored. A missing value means unavailable, never zero.

The root fields are:

| Field | Type | Meaning |
| --- | --- | --- |
| schemaVersion | integer | Exactly 1 |
| addonVersion | string | Exporter version |
| capturedAt | string or null | UTC ISO 8601 timestamp; null only if unavailable, with warning |
| build | object | version and build strings, interface integer; each nullable if API unavailable |
| locale | string, optional | Client locale such as enUS |
| character | object | Character data described below |
| equipment | array | Occupied equipment slots with readable item IDs or links |
| wand | object or null | Confirmed wand; null means no confirmed readable wand |
| spells | array | Learned player spells |
| talents | array | Active ranked talent entries |
| pet | object or null | Summoned pet data when accessible |
| buffs | array | Readable player buffs, without caster identities |
| warnings | array of strings | Missing/restricted data, unsupported APIs, cache misses |

All collection fields are JSON arrays even when empty. Stat school maps and other objects stay JSON objects even when empty. Required character identity/classification fields may be null when unavailable; consumers must reject incomplete inputs when needed, instead of filling defaults.

## Character

character contains class, classId, race, level, health, mana, and stats. class is the stable class token, e.g. WARLOCK. race is the stable race token, e.g. Human. classId and level are integers. health and mana contain numeric current and max values when readable.

stats may contain strength, agility, stamina, intellect, spirit, armor; spellDamageBySchool and spellCritBySchool maps; and manaRegen with base and casting. Regen values are mana per second, cast times are milliseconds, weapon speeds are seconds, and critical chance is a percentage. School map keys are "1" physical, "2" holy, "3" fire, "4" nature, "5" frost, "6" shadow, "7" arcane.

API values are a snapshot with active modifiers included as reported. Do not add the same gear/talent/buff bonuses again.

## Equipment and wand

Equipment entries contain slot plus any available itemId, link, equipLoc, classId, and subClassId. Slot IDs use WoW inventory slot numbers, including 18 for the ranged slot. Item links preserve enhancements in their existing item payload; the exporter does not decode every build's item-link format.

A confirmed wand has some or all of slot, itemId, link, minDamage, maxDamage, speed, positiveBonus, negativeBonus, damageMultiplier, and source. source is UnitRangedDamage in v0.1.0. The three bonus fields preserve the API tuple for diagnosis and must not automatically be added to minDamage/maxDamage again.

school is reserved as an optional integer with the 1..7 school mapping. v0.1.0 cannot populate it because UnitRangedDamage has no school return. Omission is accompanied by a warning. A readable equipped item whose type cannot be confirmed is kept in equipment, with wand:null and a warning.

## Spells

Each learned spell contains id and name, and may contain rank, castTimeMs, costs, and tooltip. rank is localized display text. IDs are the stable matching key. tooltip is an array of raw localized left/right text in display order, including any WoW text markup. It is evidence for manual review, not a structured numerical damage formula.

costs is an array with a numeric type per entry. Other fields are optional: name, cost, minCost, costPercent, costPerSec, requiredAuraID, hasRequiredAura. Fields retain API semantics. type 0 is mana. cost is the full flat resource cost including optional spend. minCost is the minimum required flat spend. costPercent is a percentage of base maximum resource. costPerSec is a percentage of base maximum resource per second as documented by the Forever API. requiredAuraID and hasRequiredAura determine whether that cost applies. Do not assume every returned cost entry applies, or that a missing costs array means a free spell.

Only learned spellbook entries from the player's active/general/class books are included. Known flyout spells are included when readable. FutureSpell entries and inactive specialization books are excluded. Lower learned ranks stay present when the client exposes them. Zero learned spells plus a warning means enumeration failed or data is unavailable.

## Talents

C_Traits entries contain system:"traits", treeId, nodeId, rank, and optional entryId, maxRank, spellId. rank uses the active rank, not a proposed uncommitted choice. Loadout names and character-specific config IDs are not exported. Nodes with no active rank are omitted.

Legacy entries contain system:"classic", tab, index, name, tier, column, rank, and maxRank. Only positive ranks are included. An empty array with an unavailable warning does not confirm that no talent points were spent.

## Pet and buffs

pet contains readable family, creatureType, level, health, mana, minDamage, maxDamage, attackSpeed, and spells in the same spell format. No pet name or GUID is included.

Buff entries contain any readable spellId, name, applications, duration, expirationTime. Duration is seconds; expirationTime uses the client's session clock and is not an absolute timestamp. Source units and caster identities are excluded.

## Fixture

examples/synthetic-warlock-17.json is hand-written invented data. Its spell ID and wand ID are identifiers for testing, while the displayed values, names, rank, and tooltip damage must not be treated as verified Forever balance.
