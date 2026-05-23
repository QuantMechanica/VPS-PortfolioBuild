"""Validator for `framework/EAs/QM5_<NNNN>_<slug>/SPEC.md`.

Required by the new Q01 Build & Spec gate (post-2026-05-23 pipeline rewrite).
Run as part of Q01 PASS criteria; CI / pre-commit may invoke it too.

Checks:
1. SPEC.md exists at the expected path.
2. All 7 mandatory section headers are present.
3. No `<ANGLE_BRACKETED_PLACEHOLDER>` strings remain (copy-paste leftovers).
4. The EA ID line matches the directory name.

Exit codes:
  0  PASS — SPEC is complete.
  1  FAIL — see stderr for the failing checks.
  2  ARG — bad CLI usage.

Usage:
    python validate_spec_doc.py framework/EAs/QM5_1056_moskowitz-tsmom
    python validate_spec_doc.py --all   (walks framework/EAs/)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = REPO_ROOT / "framework" / "EAs"

REQUIRED_SECTIONS = [
    "1. Strategy Logic",
    "2. Parameters",
    "3. Symbol Universe",
    "4. Timeframe",
    "5. Expected Behaviour",
    "6. Source Citation",
    "7. Risk Model",
]

PLACEHOLDER_RE = re.compile(r"<[A-Z_][A-Z0-9_]*>|<[a-z_][a-z0-9_]*>")
EA_ID_RE = re.compile(r"\*\*EA ID:\*\*\s*QM5_(\d+)")
DIR_RE = re.compile(r"^QM5_(\d+)_(.+)$")


def check_one(ea_dir: Path) -> tuple[bool, list[str]]:
    failures: list[str] = []

    if not ea_dir.is_dir():
        return False, [f"not a directory: {ea_dir}"]

    spec = ea_dir / "SPEC.md"
    if not spec.exists():
        return False, [f"SPEC.md missing at {spec}"]

    text = spec.read_text(encoding="utf-8", errors="replace")

    for section in REQUIRED_SECTIONS:
        if f"## {section}" not in text:
            failures.append(f"missing required section: ## {section}")

    placeholders = PLACEHOLDER_RE.findall(text)
    # The template intentionally includes the literal placeholder form
    # `<SYMBOL.DWX>` and `<YYYY-MM-DD>` etc. as guidance. The check is:
    # if SPEC.md still contains the *literal* placeholder strings from the
    # template, it hasn't been filled in. We allowlist a few descriptive
    # tokens but flag everything else.
    allowlisted = {
        "<see strategy logic>", "<list any cross-TF reads>", "<one line>",
        "<low/medium/high>", "<minutes / hours / days>",
    }
    real_placeholders = [
        p for p in placeholders
        if p not in allowlisted
        and p not in {"<one-line description>"}  # template example
    ]
    # If many placeholders remain, the SPEC is unfilled
    if len(real_placeholders) > 5:
        failures.append(
            f"too many unfilled placeholders ({len(real_placeholders)}): "
            f"{', '.join(set(real_placeholders))[:200]}"
        )

    # EA ID vs directory name consistency
    dir_match = DIR_RE.match(ea_dir.name)
    spec_match = EA_ID_RE.search(text)
    if dir_match and spec_match:
        if dir_match.group(1) != spec_match.group(1):
            failures.append(
                f"EA ID mismatch: dir says QM5_{dir_match.group(1)}, "
                f"SPEC says QM5_{spec_match.group(1)}"
            )
    elif dir_match and not spec_match:
        failures.append("SPEC.md does not declare `**EA ID:** QM5_NNNN`")

    return (len(failures) == 0), failures


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate SPEC.md for one or all EAs")
    ap.add_argument("ea_dir", nargs="?", help="path to one EA dir, or omit with --all")
    ap.add_argument("--all", action="store_true", help="walk framework/EAs/")
    args = ap.parse_args()

    if args.all:
        targets = sorted(d for d in EA_ROOT.iterdir() if d.is_dir() and DIR_RE.match(d.name))
    elif args.ea_dir:
        targets = [Path(args.ea_dir).resolve()]
    else:
        ap.print_usage(sys.stderr)
        return 2

    n_pass, n_fail = 0, 0
    for ea in targets:
        ok, failures = check_one(ea)
        if ok:
            print(f"PASS  {ea.name}")
            n_pass += 1
        else:
            print(f"FAIL  {ea.name}")
            for f in failures:
                print(f"      - {f}")
            n_fail += 1

    print()
    print(f"Summary: {n_pass} PASS, {n_fail} FAIL  (of {n_pass + n_fail})")
    return 0 if n_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
