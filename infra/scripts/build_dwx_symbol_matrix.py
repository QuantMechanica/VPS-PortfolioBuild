#!/usr/bin/env python3
"""Build DWX symbol matrix CSV from canonical hourly import log evidence."""
from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

SKIP_PATTERN = re.compile(
    r"\[(?P<ts>[^\]]+)\].*?\bskip\s+[^:]+:\s+already in MT5 as\s+(?P<symbol>[A-Za-z0-9_.-]+\.DWX)\b",
    re.IGNORECASE,
)
PATH_PATTERN = re.compile(
    r"\[(?P<ts>[^\]]+)\].*?path=(?P<path>Custom\\.*?\\(?P<symbol>[A-Za-z0-9_.-]+\.DWX))(?:\s|$)",
    re.IGNORECASE,
)

INDICES = {"GDAXIm.DWX", "NDXm.DWX", "UK100.DWX", "WS30.DWX"}
COMMODITIES = {"XAGUSD.DWX", "XAUUSD.DWX", "XNGUSD.DWX", "XTIUSD.DWX"}


def asset_class_for(symbol: str) -> str:
    if symbol in INDICES:
        return "indices"
    if symbol in COMMODITIES:
        return "commodities"
    return "forex"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True)
    ap.add_argument("--out-csv", required=True)
    ap.add_argument("--out-md", required=True)
    ap.add_argument("--expected-count", type=int, default=36)
    args = ap.parse_args()

    lines = Path(args.log).read_text(encoding="utf-8", errors="replace").splitlines()

    symbols: list[str] = []
    first_seen: dict[str, str] = {}
    skip_line: dict[str, str] = {}
    for line in lines:
        m = SKIP_PATTERN.search(line)
        if not m:
            continue
        s = m.group("symbol").strip()
        if s not in first_seen:
            first_seen[s] = m.group("ts")
            skip_line[s] = line.strip()
            symbols.append(s)

    path_by_symbol: dict[str, str] = {}
    path_line: dict[str, str] = {}
    path_seen_ts: dict[str, str] = {}
    for line in lines:
        m = PATH_PATTERN.search(line)
        if not m:
            continue
        s = m.group("symbol").strip()
        path = m.group("path").strip().replace("\\", "/")
        if s not in path_by_symbol:
            path_by_symbol[s] = path
            path_line[s] = line.strip()
            path_seen_ts[s] = m.group("ts")

    out_csv = Path(args.out_csv)
    out_csv.parent.mkdir(parents=True, exist_ok=True)

    rows = []
    for s in symbols:
        evidence_source = "path" if s in path_by_symbol else "skip_as"
        evidence_line = path_line.get(s) or skip_line.get(s, "")
        rows.append(
            {
                "symbol": s,
                "asset_class": asset_class_for(s),
                "import_log_path": path_by_symbol.get(s, ""),
                "first_imported_at": first_seen.get(s, ""),
                "canonical_name_verified": "true",
                "evidence_source": evidence_source,
                "evidence_line": evidence_line,
            }
        )

    with out_csv.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "symbol",
                "asset_class",
                "import_log_path",
                "first_imported_at",
                "canonical_name_verified",
                "evidence_source",
                "evidence_line",
            ],
        )
        w.writeheader()
        w.writerows(rows)

    count = len(rows)
    missing_path = [r["symbol"] for r in rows if not r["import_log_path"]]
    out_md = Path(args.out_md)
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text(
        "\n".join(
            [
                "# D4 Matrix Build Summary",
                "",
                f"- source_log: `{args.log}`",
                f"- symbol_count: `{count}` (expected `{args.expected_count}`)",
                f"- count_match: `{str(count == args.expected_count).lower()}`",
                f"- entries_with_custom_path: `{count - len(missing_path)}`",
                f"- entries_missing_custom_path: `{len(missing_path)}`",
                "- missing_custom_path_symbols: "
                + (", ".join(missing_path) if missing_path else "none"),
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"symbol_count={count} expected={args.expected_count}")
    print(f"entries_with_custom_path={count - len(missing_path)}")
    print(f"entries_missing_custom_path={len(missing_path)}")
    if missing_path:
        print("missing_custom_path_symbols=" + ",".join(missing_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
