#!/usr/bin/env python3
"""Validate QM registry CSVs before builds or commits.

The registry files are source-of-truth inputs for EA identity and magic-number
resolution. This validator is intentionally strict for structural issues that
can produce wrong builds: duplicate EA IDs, duplicate slugs, invalid IDs,
duplicate magic values, duplicate slots per EA, and magic formula drift.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
EA_ROOT = REPO_ROOT / "framework" / "EAs"

REQUIRED_EA_COLUMNS = ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"]
REQUIRED_MAGIC_COLUMNS = ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "reserved_at", "reserved_by", "status"]
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$")


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    if not path.exists():
        return [], []
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), [dict(row) for row in reader]


def duplicates(rows: Iterable[dict[str, str]], key_fn) -> dict[str, list[int]]:
    seen: dict[str, list[int]] = defaultdict(list)
    for offset, row in enumerate(rows, start=2):
        key = key_fn(row)
        if key:
            seen[str(key)].append(offset)
    return {key: lines for key, lines in seen.items() if len(lines) > 1}


def add_column_issues(name: str, columns: list[str], required: list[str], issues: list[str]) -> None:
    missing = [col for col in required if col not in columns]
    if missing:
        issues.append(f"{name}:missing_columns:{','.join(missing)}")


def validate_ea_registry(rows: list[dict[str, str]], issues: list[str], warnings: list[str]) -> dict[str, dict[str, str]]:
    by_id: dict[str, dict[str, str]] = {}
    for line, row in enumerate(rows, start=2):
        ea_id = (row.get("ea_id") or "").strip()
        slug = (row.get("slug") or "").strip()
        status = (row.get("status") or "").strip()
        if not ea_id.isdigit():
            issues.append(f"ea_id_registry:line_{line}:invalid_ea_id:{ea_id!r}")
            continue
        if not slug:
            issues.append(f"ea_id_registry:line_{line}:missing_slug")
        elif not SLUG_RE.match(slug):
            issues.append(f"ea_id_registry:line_{line}:invalid_slug:{slug!r}")
        if not status:
            issues.append(f"ea_id_registry:line_{line}:missing_status")
        by_id[ea_id] = row

    for ea_id, lines in duplicates(rows, lambda r: (r.get("ea_id") or "").strip()).items():
        issues.append(f"ea_id_registry:duplicate_ea_id:{ea_id}:lines={','.join(map(str, lines))}")
    for slug, lines in duplicates(rows, lambda r: (r.get("slug") or "").strip().lower()).items():
        issues.append(f"ea_id_registry:duplicate_slug:{slug}:lines={','.join(map(str, lines))}")

    for row in rows:
        ea_id = (row.get("ea_id") or "").strip()
        slug = (row.get("slug") or "").strip()
        if ea_id.isdigit() and slug:
            expected = EA_ROOT / f"QM5_{ea_id}_{slug}"
            if not expected.exists():
                warnings.append(f"ea_id_registry:ea_dir_missing:{ea_id}:{slug}")
    return by_id


def validate_magic_registry(
    rows: list[dict[str, str]],
    ea_by_id: dict[str, dict[str, str]],
    issues: list[str],
    warnings: list[str],
) -> None:
    for line, row in enumerate(rows, start=2):
        ea_id = (row.get("ea_id") or "").strip()
        slug = (row.get("ea_slug") or "").strip()
        slot_raw = (row.get("symbol_slot") or row.get("slot") or "").strip()
        magic_raw = (row.get("magic") or "").strip()
        symbol = (row.get("symbol") or "").strip()
        if not ea_id.isdigit():
            issues.append(f"magic_numbers:line_{line}:invalid_ea_id:{ea_id!r}")
            continue
        if ea_id not in ea_by_id:
            issues.append(f"magic_numbers:line_{line}:ea_id_not_in_registry:{ea_id}:{slug}")
        elif slug and (ea_by_id[ea_id].get("slug") or "").strip() != slug:
            expected_slug = (ea_by_id[ea_id].get("slug") or "").strip()
            if slug.startswith(f"{expected_slug}_v"):
                warnings.append(f"magic_numbers:line_{line}:variant_slug:{ea_id}:magic={slug}:ea_registry={expected_slug}")
            else:
                issues.append(
                    f"magic_numbers:line_{line}:slug_mismatch:{ea_id}:magic={slug}:ea_registry={expected_slug}"
                )
        if not slot_raw.isdigit():
            issues.append(f"magic_numbers:line_{line}:invalid_symbol_slot:{slot_raw!r}")
            continue
        if not magic_raw.isdigit():
            issues.append(f"magic_numbers:line_{line}:invalid_magic:{magic_raw!r}")
            continue
        slot = int(slot_raw)
        magic = int(magic_raw)
        expected_magic = int(ea_id) * 10000 + slot
        if magic != expected_magic:
            issues.append(f"magic_numbers:line_{line}:magic_formula_mismatch:got={magic}:expected={expected_magic}")
        if not symbol.endswith(".DWX"):
            issues.append(f"magic_numbers:line_{line}:symbol_without_dwx_suffix:{symbol!r}")

    for magic, lines in duplicates(rows, lambda r: (r.get("magic") or "").strip()).items():
        issues.append(f"magic_numbers:duplicate_magic:{magic}:lines={','.join(map(str, lines))}")
    for key, lines in duplicates(rows, lambda r: f"{(r.get('ea_id') or '').strip()}:{(r.get('symbol_slot') or '').strip()}").items():
        issues.append(f"magic_numbers:duplicate_ea_slot:{key}:lines={','.join(map(str, lines))}")
    for key, lines in duplicates(rows, lambda r: f"{(r.get('ea_id') or '').strip()}:{(r.get('symbol') or '').strip()}").items():
        warnings.append(f"magic_numbers:duplicate_ea_symbol:{key}:lines={','.join(map(str, lines))}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate QM EA and magic registries.")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    parser.add_argument("--show-warnings", action="store_true", help="Print non-fatal inventory warnings in text mode.")
    parser.add_argument("--strict-warnings", action="store_true", help="Treat warnings as failures.")
    args = parser.parse_args()

    issues: list[str] = []
    warnings: list[str] = []
    ea_cols, ea_rows = read_csv(EA_REGISTRY)
    magic_cols, magic_rows = read_csv(MAGIC_REGISTRY)
    add_column_issues("ea_id_registry", ea_cols, REQUIRED_EA_COLUMNS, issues)
    add_column_issues("magic_numbers", magic_cols, REQUIRED_MAGIC_COLUMNS, issues)
    if not ea_rows:
        issues.append("ea_id_registry:empty_or_missing")
    if not magic_rows:
        issues.append("magic_numbers:empty_or_missing")

    ea_by_id = validate_ea_registry(ea_rows, issues, warnings)
    validate_magic_registry(magic_rows, ea_by_id, issues, warnings)

    result = {
        "status": "fail" if issues or (args.strict_warnings and warnings) else "ok",
        "ea_registry_rows": len(ea_rows),
        "magic_registry_rows": len(magic_rows),
        "issues": issues,
        "warnings": warnings,
    }
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"status={result['status']} ea_rows={len(ea_rows)} magic_rows={len(magic_rows)}")
        for issue in issues:
            print(f"ISSUE {issue}")
        if args.show_warnings or args.strict_warnings:
            for warning in warnings:
                print(f"WARN {warning}")
        elif warnings:
            print(f"warnings={len(warnings)} hidden_nonfatal_use_--show-warnings")
    return 1 if result["status"] != "ok" else 0


if __name__ == "__main__":
    raise SystemExit(main())
