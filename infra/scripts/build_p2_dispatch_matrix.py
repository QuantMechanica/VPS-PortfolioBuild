#!/usr/bin/env python3
"""Build a canonical P2 matrix dispatch payload from a symbol source."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def _load_symbols(path: Path) -> list[str]:
    rows = path.read_text(encoding="utf-8", errors="replace").splitlines()
    symbols: list[str] = []
    seen: set[str] = set()
    for raw in rows:
        symbol = raw.strip()
        if not symbol or symbol.startswith("#"):
            continue
        if not symbol.endswith(".DWX"):
            raise ValueError(f"non-DWX symbol in symbols file: {symbol}")
        if symbol in seen:
            raise ValueError(f"duplicate symbol in symbols file: {symbol}")
        seen.add(symbol)
        symbols.append(symbol)
    return symbols


def _load_symbols_from_csv(path: Path) -> list[str]:
    symbols: list[str] = []
    seen: set[str] = set()
    with path.open(encoding="utf-8", newline="") as f:
        rows = csv.DictReader(f)
        required = {"symbol", "canonical_name_verified"}
        missing = required - set(rows.fieldnames or [])
        if missing:
            raise ValueError(f"missing required csv columns: {sorted(missing)}")
        for row in rows:
            symbol = (row.get("symbol") or "").strip()
            verified = (row.get("canonical_name_verified") or "").strip().lower()
            if not symbol:
                continue
            if not symbol.endswith(".DWX"):
                raise ValueError(f"non-DWX symbol in matrix csv: {symbol}")
            if verified != "true":
                raise ValueError(f"symbol not canonical_name_verified=true: {symbol}")
            if symbol in seen:
                raise ValueError(f"duplicate symbol in matrix csv: {symbol}")
            seen.add(symbol)
            symbols.append(symbol)
    return symbols


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbols-file", help="Path to canonical .DWX symbol list (txt)")
    ap.add_argument("--matrix-csv", help="Path to canonical DWX symbol matrix csv")
    ap.add_argument("--out-json", required=True, help="Output matrix job payload path")
    ap.add_argument("--ea-id", default="QM5_1003")
    ap.add_argument("--version", default="v1")
    ap.add_argument("--phase", default="P2")
    ap.add_argument("--sub-gate-config-hash", default="H1-2024")
    ap.add_argument(
        "--setfile-template",
        default="C:/QM/repo/framework/EAs/QM5_1003_davey_baseline_3bar/sets/QM5_1003_davey_baseline_3bar_{symbol}_H1_backtest.set",
        help="Setfile template. Use {symbol} placeholder.",
    )
    ap.add_argument("--expected-count", type=int, default=36)
    args = ap.parse_args()

    default_matrix_csv = Path("framework/registry/dwx_symbol_matrix.csv")
    if not args.symbols_file and not args.matrix_csv:
        args.matrix_csv = str(default_matrix_csv)

    if args.matrix_csv:
        symbols = _load_symbols_from_csv(Path(args.matrix_csv))
    else:
        symbols = _load_symbols(Path(args.symbols_file))

    if len(symbols) != args.expected_count:
        raise ValueError(f"expected {args.expected_count} symbols, got {len(symbols)}")

    payload = {
        "ea_id": args.ea_id,
        "version": args.version,
        "phase": args.phase,
        "sub_gate_config_hash": args.sub_gate_config_hash,
        "setfile_path": args.setfile_template.format(symbol=symbols[0]),
        "symbols": symbols,
    }

    out = Path(args.out_json)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(str(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
