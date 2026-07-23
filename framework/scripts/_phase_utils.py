#!/usr/bin/env python3
"""Shared helpers for V5 pipeline phase runners."""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

PASS_TOKENS = {"pass", "green", "true", "1", "yes", "auto_pass", "multi_seed_pass", "multi_seed_mixed"}

FX_MAJOR = {
    "EURUSD",
    "GBPUSD",
    "USDJPY",
    "USDCHF",
    "USDCAD",
    "AUDUSD",
    "NZDUSD",
}
INDEX = {"UK100", "US30", "WS30", "NAS100", "GER40", "SPX500", "NDX", "GDAXI"}
COMMODITY = {"XAUUSD", "XAGUSD", "XTIUSD", "XBRUSD"}
CRYPTO = {"BTCUSD", "ETHUSD"}


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def add_common_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--ea", required=True, help="EA identifier, e.g. QM5_1001")
    parser.add_argument("--out-prefix", default="D:/QM/reports/pipeline", help="Output directory root")


def ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def load_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        return [dict(row) for row in reader]


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    text = str(value).strip()
    if text == "":
        return default
    return float(text)


def parse_int(value: Any, default: int = 0) -> int:
    if value is None:
        return default
    text = str(value).strip()
    if text == "":
        return default
    return int(float(text))


def parse_bool_like(value: Any) -> bool:
    text = str(value or "").strip().lower()
    return text in PASS_TOKENS


def normalize_symbol(raw_symbol: str) -> str:
    symbol = (raw_symbol or "").strip().upper()
    if symbol.endswith(".DWX"):
        symbol = symbol[:-4]
    return symbol


def classify_symbol(raw_symbol: str) -> str:
    symbol = normalize_symbol(raw_symbol)
    if symbol in FX_MAJOR:
        return "FX_MAJOR"
    if symbol in INDEX:
        return "INDEX"
    if symbol in COMMODITY:
        return "COMMODITY"
    if symbol in CRYPTO:
        return "CRYPTO"
    if len(symbol) == 6 and symbol.isalpha():
        return "FX_CROSS"
    return "UNKNOWN"


def row_symbol(row: dict[str, str]) -> str:
    for key in ("symbol", "Symbol", "SYMBOL"):
        if key in row:
            return row[key]
    return ""


def row_passes(row: dict[str, str]) -> bool:
    for key in ("verdict", "status", "result", "pass", "PASS"):
        if key in row and parse_bool_like(row[key]):
            return True
    return False


def write_json(path: Path, data: dict[str, Any]) -> None:
    ensure_dir(path.parent)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent=2, sort_keys=True)
        handle.write("\n")


def append_jsonl(path: Path, record: dict[str, Any]) -> None:
    ensure_dir(path.parent)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def build_result(
    *,
    phase: str,
    ea_id: str,
    verdict: str,
    criterion: str,
    evidence_path: str,
    details: dict[str, Any],
) -> dict[str, Any]:
    return {
        "criterion": criterion,
        "details": details,
        "ea_id": ea_id,
        "evidence_path": evidence_path,
        "generated_at_utc": utc_now_iso(),
        "phase": phase,
        "verdict": verdict,
    }


def write_phase_artifacts(
    *,
    out_dir: Path,
    phase: str,
    ea_id: str,
    result: dict[str, Any],
) -> tuple[Path, Path]:
    phase_safe = phase.replace(".", "_")
    result_path = out_dir / f"{phase_safe}_{ea_id}_result.json"
    log_path = out_dir / "phase_runner_log.jsonl"
    write_json(result_path, result)
    append_jsonl(
        log_path,
        {
            "criterion": result["criterion"],
            "ea_id": ea_id,
            "evidence_path": str(result_path),
            "phase": phase,
            "ts_utc": utc_now_iso(),
            "verdict": result["verdict"],
        },
    )
    return result_path, log_path


def update_result_with_evidence_path(result_path: Path, result: dict[str, Any]) -> None:
    result["evidence_path"] = str(result_path)
    write_json(result_path, result)
