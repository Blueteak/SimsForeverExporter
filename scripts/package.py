"""Build an installable archive using only Python's standard library."""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parents[1]
addon = root / "SimsForeverExporter"
version = re.search(r"^## Version: (.+)$", (addon / "SimsForeverExporter.toc").read_text(), re.M).group(1)
output = root / "dist" / f"SimsForeverExporter-{version}.zip"
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    # An explicit allowlist keeps local exports and unrelated files out of releases.
    for name in ("SimsForeverExporter.toc", "Core.lua", "UI.lua"):
        archive.write(addon / name, f"SimsForeverExporter/{name}")
    for name in ("LICENSE", "README.md"):
        archive.write(root / name, f"SimsForeverExporter/{name}")
print(output)
