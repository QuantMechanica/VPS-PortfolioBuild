"""Find repo->vault references that point at files which no longer exist.

The vault linter only checks vault-internal wikilinks; a prompt in the repo that
names a vault page is invisible to it. MNT-025 is exactly that blind spot.
"""
import pathlib
import re

REPO = pathlib.Path(r"C:\QM\repo")
PAT = re.compile(r"G:[\\/]My Drive[\\/]QuantMechanica - Company Reference[\\/][^\"'`\n]*?\.md")
SEARCH_DIRS = ["tools", "scripts", "processes", "skills", "framework/scripts"]

missing, checked = [], 0
for d in SEARCH_DIRS:
    base = REPO / d
    if not base.exists():
        continue
    for f in base.rglob("*"):
        if f.suffix.lower() not in (".md", ".py", ".ps1", ".txt") or "__pycache__" in str(f):
            continue
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for hit in PAT.findall(text):
            checked += 1
            if not pathlib.Path(hit.replace("\\", "/")).exists():
                missing.append((str(f.relative_to(REPO)), hit))

print(f"vault refs checked: {checked}   broken: {len(missing)}")
for rel, hit in missing:
    print(f"  {rel} -> {hit}")
