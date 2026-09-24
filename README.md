# SimsForever Exporter

Exports WoW Forever character data for [SimsForever](https://simsforever.com).

Run `/simf`, `/sfexport`, or `/simsforever` to open the export. Press Ctrl+C to copy and close the window, then paste at SimsForever. Cmd+C and Ctrl+Insert also close after copying. Add `save` to save the export locally, or `clear` to remove the saved copy.

Exports equipped gear plus equippable gear in carried bags. Bank contents are included only while the bank window is open. Maximum health and, for mana classes, maximum mana are required for simulation. Current resources, spell costs, and pet spell details are optional diagnostics; SimsForever selects starting resources and uses internal spell and pet data. Unreadable optional fields are omitted without warnings.

CurseForge packages version tags automatically. See [RELEASING.md](RELEASING.md) for publishing instructions.
