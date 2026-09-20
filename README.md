# SimsForever Exporter

A small character-export addon for the WoW Forever Beta, targeting interface 16001. Export a snapshot with /sfexport and paste its JSON into [SimsForever](https://simsforever.com).

This first release has passed Lua 5.1 syntax and mocked API checks. It still needs an in-game check on the Forever Beta client. Beta API changes may leave fields missing; the export includes warnings instead of guessing.

## Install on the WoW computer

Download the ZIP from this repository's Releases page and extract the SimsForeverExporter folder into:

    D:\Games\Blizzard\World of Warcraft\_classic_beta_\Interface\AddOns\

The final file path must be:

    D:\Games\Blizzard\World of Warcraft\_classic_beta_\Interface\AddOns\SimsForeverExporter\SimsForeverExporter.toc

Restart WoW if it was running during the first install. Enable SimsForever Exporter in the AddOns list.

If you cloned or downloaded this source repository, the addon is the inner SimsForeverExporter folder. You can also run:

    powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1

Pass -WoWPath to install in a different Beta directory. The installer copies only this addon's three runtime files, without deleting folders, other addons, or saved data. Close WoW before updating.

## Export your level 17 Warlock

1. Log into Forever Beta, equip the gear you want to compare, and summon your usual pet if you want to capture it.
2. Open your character and spellbook panels once so item and spell data can load. Apply the buffs you want represented.
3. Leave combat and type /sfexport or /simsforever.
4. Press Ctrl+C in the selected text, then paste into SimsForever's character import.
5. Check the warnings. Repeat the export if spell names, costs, or equipment links were not cached.

Normal exports stay in the copy window only. /sfexport save also stores the latest JSON in this addon's SavedVariables, which WoW writes on logout or /reload. /sfexport clear removes that saved copy on the next save. Neither command uploads anything.

For the first simulator comparison, record your wand tooltip's damage school and Shadow Bolt tooltip's damage range separately. The addon exports structured wand damage and speed when available, spell costs and cast times, and raw spell tooltip text. It deliberately does not turn localized tooltip prose into certain numerical spell damage.

## What is captured

- Game build, interface version, locale, class, race, level, current/max health and mana, primary stats, spell damage and critical chance by school, and mana regeneration.
- Equipped item IDs and links, including the enchant/gem fields already present in links.
- Confirmed wand damage range and speed from UnitRangedDamage. Damage school remains unavailable in this API and is flagged.
- Learned player spells with IDs, ranks, structured costs, cast times, and raw localized tooltip lines. Future spells, inactive specializations, and pet command buttons are excluded.
- Purchased active talent nodes from C_Traits, with a classic talent API fallback.
- Pet family/type, level, resources, damage, attack speed, and learned spells when readable. Player buffs without caster information.

No player name, realm, GUID, Battle.net identity, chat, friends list, target information, pet name, or talent-loadout name is exported. Item tooltip text is not collected because it can contain a crafter's name. Exports may still reveal your build and capture time; keep real exports out of public issues and this repository.

The addon performs no combat actions, spell casts, network requests, addon messages, or automatic collection. Exporting is blocked in combat and the copy window closes when combat starts. Restricted/secret API values are omitted before inspection.

## Development

The versioned contract is in [docs/schema-v1.md](docs/schema-v1.md). The [synthetic fixture](examples/synthetic-warlock-17.json) is invented test data, not an actual character or a statement of Beta spell balance.

Build an installable ZIP with Python 3:

    python scripts/package.py

Run the focused checks with Python 3 and the optional test-only lupa package:

    python -m pip install lupa
    python tests/smoke.py

The addon itself has no dependencies. The smoke script uses Lua 5.1, checks JSON output, rejects future spells, exercises trait and classic talent APIs, and verifies combat rejection and restricted/missing-data behavior.

## API basis and limits

Implementation was checked against the public [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e), particularly the generated SpellBook, Spell, SpellShared, Unit, Item, TooltipInfo, SharedTraits, and SimpleEditBox documentation. This source mirror is API evidence, not confirmation of runtime behavior on your client.

Talents must be applied before capture. API-reported spell cost, cast time, and stats reflect the current character/buffs and may already include modifiers; a simulator must avoid applying the same modifiers twice. No formulas for talent budgets, regeneration, spell damage, or pet scaling are embedded here.

Licensed under MIT. This project is not affiliated with Blizzard Entertainment.
