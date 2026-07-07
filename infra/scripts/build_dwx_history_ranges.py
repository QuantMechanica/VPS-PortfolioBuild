#!/usr/bin/env python3
"""Build the DWX custom-symbol history range registry from MT5 .hcc files."""
from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Any

SUPPORTED_DERIVED_PERIODS = (
    "D1",
    "H12",
    "H8",
    "H6",
    "H4",
    "H3",
    "H2",
    "H1",
    "M30",
    "M20",
    "M15",
    "M12",
    "M10",
    "M6",
    "M5",
    "M4",
    "M3",
    "M2",
    "M1",
)
EXCLUDED_PERIODS = ("W1", "MN1")
DEFAULT_MIN_HCC_BYTES = 1_000_000
TERMINAL_RE = re.compile(r"^T(\d+)$", re.IGNORECASE)


def _terminal_sort_key(name: str) -> tuple[int, str]:
    match = TERMINAL_RE.match(name)
    if match:
        return int(match.group(1)), name.upper()
    return 999, name.upper()


def _read_symbols(matrix_path: Path) -> list[str]:
    symbols: list[str] = []
    with matrix_path.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            symbol = (row.get("symbol") or "").strip()
            if not symbol:
                continue
            if symbol.upper() not in {s.upper() for s in symbols}:
                symbols.append(symbol)
    return symbols


def _contiguous_ranges(years: set[int]) -> list[tuple[int, int]]:
    ordered = sorted(years)
    if not ordered:
        return []
    ranges: list[tuple[int, int]] = []
    start = prev = ordered[0]
    for year in ordered[1:]:
        if year == prev + 1:
            prev = year
            continue
        ranges.append((start, prev))
        start = prev = year
    ranges.append((start, prev))
    return ranges


def _select_range(years_by_terminal: dict[str, set[int]]) -> tuple[int, int, list[str]] | None:
    candidates: set[tuple[int, int]] = set()
    for years in years_by_terminal.values():
        candidates.update(_contiguous_ranges(years))
    if not candidates:
        return None

    def score(span: tuple[int, int]) -> tuple[int, int, int, int]:
        start, end = span
        required = set(range(start, end + 1))
        terminals = sum(1 for years in years_by_terminal.values() if required.issubset(years))
        return end - start + 1, terminals, end, -start

    start, end = max(candidates, key=score)
    required = set(range(start, end + 1))
    terminals = sorted(
        (terminal for terminal, years in years_by_terminal.items() if required.issubset(years)),
        key=_terminal_sort_key,
    )
    return start, end, terminals


def _collect_symbol_years(mt5_root: Path, symbol: str, min_hcc_bytes: int) -> dict[str, set[int]]:
    years_by_terminal: dict[str, set[int]] = {}
    for hcc in mt5_root.glob(f"T*/Bases/Custom/history/{symbol}/*.hcc"):
        if not hcc.stem.isdigit():
            continue
        try:
            size = hcc.stat().st_size
        except OSError:
            continue
        if size < min_hcc_bytes:
            continue
        terminal = hcc.parts[len(mt5_root.parts)]
        if not TERMINAL_RE.match(terminal):
            continue
        years_by_terminal.setdefault(terminal, set()).add(int(hcc.stem))
    return years_by_terminal


def build_rows(
    *,
    mt5_root: Path,
    matrix_path: Path,
    periods: tuple[str, ...] = SUPPORTED_DERIVED_PERIODS,
    min_hcc_bytes: int = DEFAULT_MIN_HCC_BYTES,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    symbols = _read_symbols(matrix_path)
    for symbol in symbols:
        years_by_terminal = _collect_symbol_years(mt5_root, symbol, min_hcc_bytes)
        selected = _select_range(years_by_terminal)
        if not selected:
            skipped.append({"symbol": symbol, "reason": "no_hcc_years_at_or_above_min_bytes"})
            continue
        first_year, last_year, source_terminals = selected
        for period in periods:
            period_key = period.upper()
            if period_key in EXCLUDED_PERIODS:
                continue
            rows.append(
                {
                    "symbol": symbol,
                    "period": period_key,
                    "first_year": first_year,
                    "last_year": last_year,
                    "source_terminals": ",".join(source_terminals),
                }
            )
    summary = {
        "mt5_root": str(mt5_root),
        "matrix_path": str(matrix_path),
        "min_hcc_bytes": min_hcc_bytes,
        "periods": list(periods),
        "excluded_periods": list(EXCLUDED_PERIODS),
        "symbol_count": len(symbols),
        "rows_written": len(rows),
        "skipped_symbols": skipped,
    }
    return rows, summary


def write_csv(rows: list[dict[str, Any]], out_csv: Path) -> None:
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["symbol", "period", "first_year", "last_year", "source_terminals"],
        )
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mt5-root", type=Path, default=Path(r"D:/QM/mt5"))
    parser.add_argument("--symbol-matrix", type=Path, default=Path("framework/registry/dwx_symbol_matrix.csv"))
    parser.add_argument("--out-csv", type=Path, default=Path("framework/registry/dwx_symbol_history_ranges.csv"))
    parser.add_argument("--out-summary", type=Path)
    parser.add_argument("--min-hcc-bytes", type=int, default=DEFAULT_MIN_HCC_BYTES)
    args = parser.parse_args()

    rows, summary = build_rows(
        mt5_root=args.mt5_root,
        matrix_path=args.symbol_matrix,
        min_hcc_bytes=args.min_hcc_bytes,
    )
    write_csv(rows, args.out_csv)
    if args.out_summary:
        args.out_summary.parent.mkdir(parents=True, exist_ok=True)
        args.out_summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
