#!/usr/bin/env python3
"""Create per-EA P5 calibration JSON from measured VPS calibration evidence."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

from _phase_utils import ensure_dir, normalize_symbol, write_json


def _symbol_candidates(symbol: str) -> list[str]:
    norm = normalize_symbol(symbol)
    return [symbol, symbol.upper(), norm, f"{norm}.DWX"]


def extract_calibration(source: dict, symbols: list[str]) -> dict:
    source_symbols = source.get("symbols") or {}
    if not isinstance(source_symbols, dict) or not source_symbols:
        raise ValueError("source calibration has no symbols block")

    first_key = next(iter(source_symbols.keys()))
    first_block = source_symbols[first_key]
    if not isinstance(first_block, dict):
        raise ValueError(f"source calibration symbol block is not an object: {first_key}")

    out_symbols: dict[str, dict] = {}
    for raw_symbol in symbols:
        selected_key = ""
        for candidate in _symbol_candidates(raw_symbol):
            if candidate in source_symbols and isinstance(source_symbols[candidate], dict):
                selected_key = candidate
                break
        target_key = f"{normalize_symbol(raw_symbol)}.DWX"
        block = copy.deepcopy(source_symbols[selected_key] if selected_key else first_block)
        block["source_symbol"] = selected_key or first_key
        block["target_symbol"] = target_key
        out_symbols[target_key] = block

    return {
        "measurement_status": source.get("measurement_status", "MEASURED"),
        "source": "p5_calibration_extractor",
        "source_note": "Derived from measured VPS calibration evidence; missing symbols inherit first measured symbol block with source_symbol recorded.",
        "symbols": out_symbols,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbols", required=True)
    ap.add_argument("--source-calibration", required=True)
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    args = ap.parse_args()

    source = json.loads(Path(args.source_calibration).read_text(encoding="utf-8-sig"))
    symbols = [s.strip() for s in args.symbols.split(",") if s.strip()]
    if not symbols:
        raise ValueError("--symbols must contain at least one symbol")

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P4")
    out_path = out_dir / "calibration.json"
    write_json(out_path, extract_calibration(source, symbols))
    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
