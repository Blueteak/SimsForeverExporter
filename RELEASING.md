# Publishing to CurseForge

This repository uses CurseForge's built-in packager, like ShardSource.

- GitHub: https://github.com/Blueteak/SimsForeverExporter
- CurseForge: https://www.curseforge.com/wow/addons/sims-forever
- Source settings: https://authors.curseforge.com/#/projects/1706857/source

## Setup

In CurseForge's Source tab, select GitHub, use this repository's public URL, and select packaging for new tagged commits only.

The GitHub push webhook calls `https://www.curseforge.com/api/projects/1706857/package?token=YOUR_TOKEN`. Keep the token only in the webhook configuration. Use push events, keep the webhook active, and leave SSL verification enabled. Reuse an existing working webhook instead of adding a duplicate.

## Publish an update

1. Update `CHANGELOG.md`.
2. Commit and push the release changes to `main`.
3. Create and push a new version tag on that commit:

   ```sh
   git tag -a v0.1.3 -m "SimsForever Exporter 0.1.3"
   git push origin v0.1.3
   ```

Use a new version for each upload. Never move an already published tag. Tags containing `alpha` or `beta` produce that file type on CurseForge. Plain version tags produce Release files. Untagged pushes do not publish files.

## Package contents

`.pkgmeta` keeps the addon folder named `SimsForeverExporter`, matching its TOC. CurseForge replaces the version tokens in the TOC and `Core.lua` with the tag. An unpackaged checkout reports `development` in exports.

The package includes `Core.lua`, `UI.lua`, `SimsForeverExporter.toc`, `CHANGELOG.md`, and the existing `LICENSE`. Keep interface `16001` for WoW Forever 1.60.1 until the client requires a change.

Check the webhook delivery and CurseForge packaging result after publishing. Confirm the ZIP has the correct folder, substituted version, and Forever game version. A new CurseForge project may wait for moderator approval before downloads appear publicly.

References: [Automatic Packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging), [PackageMeta](https://support.curseforge.com/support/solutions/articles/9000197952-preparing-the-packagemeta-file).
