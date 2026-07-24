#!/usr/bin/env python
"""Read-only live-book pulse monitor for the QM T_Live terminal.

The script reads MT5 terminal journals, MQL logs, and QM EA JSONL logs, then
writes its own state under D:/QM reports/state. It must never write into the
live terminal tree.
"""

from __future__ import annotations

import argparse
import configparser
import csv
import hashlib
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_LIVE_ROOT = Path(r"C:\QM\mt5\T_Live")
DEFAULT_OUTPUT_JSON = Path(r"D:\QM\reports\state\live_book_pulse.json")
DEFAULT_APPEND_LOG = Path(r"D:\QM\reports\state\live_book_pulse.log")
DEFAULT_ALARM_LOG = Path(r"D:\QM\strategy_farm\state\health_alarms.log")
DEFAULT_BOOK_MANIFEST = Path(
    os.environ.get(
        "QM_DXZ_BOOK_MANIFEST",
        # 24-sleeve as-deployed manifest, audit 2026-07-24 (ESC-02); replaced the
        # stale 23-sleeve DRAFT 20260711 (3 ghosts, 4 unlisted live sleeves).
        r"D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json",
    )
)
DEFAULT_TAIL_BYTES = 4 * 1024 * 1024
OPEN_POSITION_JOURNAL_STALE_MINUTES = 120
FLAT_JOURNAL_STALE_MINUTES = 450
SCAN_HEARTBEAT_STALE_MINUTES = 390
FIRST_SCAN_DUE_MINUTE_LOCAL = 1 * 60 + 50

ACCOUNT_RE = re.compile(r"'(?P<account>\d{6,})'")
DATE_FILE_RE = re.compile(r"(?P<date>\d{8})\.log$", re.IGNORECASE)
SCAN_FINISHED_RE = re.compile(r"\bscanning network finished\b", re.IGNORECASE)
EXPERT_LOADED_RE = re.compile(
    r"expert\s+(?P<name>QM5_(?P<ea_id>\d+)_[^(]+)\s+\((?P<symbol>[^,]+),(?P<tf>[^)]+)\)\s+loaded successfully",
    re.IGNORECASE,
)
EXPERT_REMOVED_RE = re.compile(
    r"expert\s+(?P<name>QM5_(?P<ea_id>\d+)_[^(]+)\s+\((?P<symbol>[^,]+),(?P<tf>[^)]+)\)\s+removed",
    re.IGNORECASE,
)
# Safety fallback only.  Production expectation is loaded from --book-manifest.
EXPECTED_LIVE_SLEEVES = 24
PRESET_FILE_RE = re.compile(
    r"^slot(?P<slot>\d+)_(?P<symbol>[^_]+)_(?P<tf>[^_]+)_QM5_(?P<ea_id>\d+)_.*_magic(?P<magic>\d+)(?:_[^.]+)?\.set$",
    re.IGNORECASE,
)
# Deployed naming since the 2026-07 rename: NN_SYMBOL_TF_QM5_<id>_<slug>.set.
# The filename carries no slot/magic; slot comes from the qm_magic_slot_offset
# input inside the set (all 24 deployed presets carry it, audit 2026-07-24)
# and magic is reconstructed as ea_id*10000+slot.
NUMBERED_PRESET_FILE_RE = re.compile(
    r"^(?P<order>\d+)_(?P<symbol>[^_]+)_(?P<tf>[^_]+)_QM5_(?P<ea_id>\d+)_(?P<slug>[^.]+)\.set$",
    re.IGNORECASE,
)
SYNC_RE = re.compile(
    r"terminal synchronized with .*?: (?P<positions>\d+) positions, (?P<orders>\d+) orders",
    re.IGNORECASE,
)
AUTOTRADING_RE = re.compile(
    r"\b(auto[\s-]?trading|automated trading|algo(?:rithmic)? trading)\b",
    re.IGNORECASE,
)
DISCONNECT_RE = re.compile(
    r"\b(connection .* lost|disconnect(?:ed)?|no connection|network .* lost)\b",
    re.IGNORECASE,
)
TRADE_REJECT_RE = re.compile(
    r"\b(reject(?:ed)?|requote|invalid (?:price|stops|volume)|market closed|trade disabled|off quotes|not enough money)\b",
    re.IGNORECASE,
)
MARGIN_RE = re.compile(r"\b(margin|not enough money|no money)\b", re.IGNORECASE)
ERROR_RE = re.compile(r"\b(error|failed|exception|critical|retcode=(?!10009)\d+)\b", re.IGNORECASE)

POSITION_EVENT_NAMES = {
    "ENTRY_ACCEPTED",
    "ENTRY_REJECTED",
    "ORDER_ACCEPTED",
    "ORDER_REJECTED",
    "TM_OPEN",
    "TM_CLOSE",
    "TM_REMOVE_PENDING",
    "TRADE_OPEN",
    "TRADE_CLOSED",
    "POSITION_OPEN",
    "POSITION_CLOSE",
    "POSITION_CLOSED",
}
OPEN_EVENTS = {"TM_OPEN", "TRADE_OPEN", "POSITION_OPEN"}
CLOSE_EVENTS = {"TM_CLOSE", "TM_REMOVE_PENDING", "TRADE_CLOSED", "POSITION_CLOSE", "POSITION_CLOSED"}

TIMEFRAME_ALIASES = {
    "PERIOD_M1": "M1",
    "PERIOD_M5": "M5",
    "PERIOD_M15": "M15",
    "PERIOD_M30": "M30",
    "PERIOD_H1": "H1",
    "PERIOD_H4": "H4",
    "PERIOD_D1": "D1",
    "PERIOD_W1": "W1",
    "PERIOD_MN1": "MN1",
    "1 MINUTE": "M1",
    "5 MINUTES": "M5",
    "15 MINUTES": "M15",
    "30 MINUTES": "M30",
    "1 HOUR": "H1",
    "4 HOURS": "H4",
    "DAILY": "D1",
    "WEEKLY": "W1",
    "MONTHLY": "MN1",
}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def path_is_under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False
    except FileNotFoundError:
        try:
            path.parent.resolve().relative_to(root.resolve())
            return True
        except Exception:
            return False


def assert_not_under_live_root(path: Path, live_roots: list[Path]) -> None:
    for root in live_roots:
        if path_is_under(path, root):
            raise SystemExit(f"refusing to write inside live terminal tree: {path}")


def decode_bytes(data: bytes) -> str:
    if data.startswith(b"\xff\xfe") or data.startswith(b"\xfe\xff"):
        return data.decode("utf-16", errors="replace")
    if data.count(b"\x00") > max(10, len(data) // 20):
        return data.decode("utf-16-le", errors="replace")
    for encoding in ("utf-8-sig", "cp1252"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def read_tail(path: Path, max_bytes: int) -> str:
    size = path.stat().st_size
    with path.open("rb") as handle:
        if size > max_bytes:
            handle.seek(-max_bytes, os.SEEK_END)
            data = handle.read()
            newline = data.find(b"\n")
            if newline >= 0:
                data = data[newline + 1 :]
        else:
            data = handle.read()
    return decode_bytes(data)


def discover_terminal_roots(live_root: Path) -> list[Path]:
    candidates: list[Path] = []
    if (live_root / "logs").is_dir() or (live_root / "MQL5").is_dir():
        candidates.append(live_root)
    if live_root.is_dir():
        for child in sorted(live_root.iterdir()):
            if child.is_dir() and ((child / "logs").is_dir() or (child / "MQL5").is_dir()):
                candidates.append(child)
    seen: set[str] = set()
    roots: list[Path] = []
    for candidate in candidates:
        key = str(candidate.resolve()).lower()
        if key not in seen:
            seen.add(key)
            roots.append(candidate)
    return roots


def latest_files(paths: list[Path], limit: int) -> list[Path]:
    return sorted(paths, key=lambda p: (p.stat().st_mtime, p.name), reverse=True)[:limit]


def load_magic_registry(path: Path) -> dict[int, dict[str, Any]]:
    if not path.exists():
        return {}
    registry: dict[int, dict[str, Any]] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            try:
                magic = int(row.get("magic", ""))
            except ValueError:
                continue
            registry[magic] = dict(row)
    return registry


def default_magic_csv() -> Path:
    canonical = Path(r"C:\QM\repo\framework\registry\magic_numbers.csv")
    if canonical.exists():
        return canonical
    return Path(__file__).resolve().parents[2] / "framework" / "registry" / "magic_numbers.csv"


def parse_common_ini(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"path": str(path), "exists": False, "experts_enabled": None}
    parser = configparser.ConfigParser()
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-16")
        if not parser.sections():
            parser.read(path, encoding="utf-8-sig")
    except Exception:
        try:
            parser.read(path, encoding="utf-8-sig")
        except Exception as exc:
            return {"path": str(path), "exists": True, "experts_enabled": None, "error": str(exc)}
    value = None
    if parser.has_section("Experts") and parser.has_option("Experts", "Enabled"):
        raw = parser.get("Experts", "Enabled", fallback="")
        value = raw.strip() in {"1", "true", "True", "yes", "on"}
    return {"path": str(path), "exists": True, "experts_enabled": value}


def terminal_timestamp_from_line(path: Path, line: str) -> str | None:
    match = DATE_FILE_RE.search(path.name)
    if not match:
        return None
    parts = line.split("\t")
    if len(parts) < 3:
        return None
    try:
        date_part = datetime.strptime(match.group("date"), "%Y%m%d").date()
        time_part = datetime.strptime(parts[2], "%H:%M:%S.%f").time()
        return datetime.combine(date_part, time_part).isoformat()
    except ValueError:
        return None


def terminal_datetime_from_line(path: Path, line: str) -> datetime | None:
    timestamp = terminal_timestamp_from_line(path, line)
    if not timestamp:
        return None
    try:
        return datetime.fromisoformat(timestamp)
    except ValueError:
        return None


def decode_magic(magic: int) -> dict[str, int]:
    return {"ea_id": magic // 10000, "symbol_slot": magic % 10000}


def classify_line(line: str) -> str | None:
    text = line.lower()
    if DISCONNECT_RE.search(text):
        return "disconnect"
    if MARGIN_RE.search(text):
        return "margin"
    if TRADE_REJECT_RE.search(text):
        return "trade_reject"
    if ERROR_RE.search(text):
        return "error"
    parts = line.split("\t")
    if len(parts) > 1 and parts[1].strip() not in {"", "0"}:
        return "warning"
    return None


def line_excerpt(line: str, limit: int = 360) -> str:
    compact = " ".join(line.strip().split())
    return compact if len(compact) <= limit else compact[: limit - 3] + "..."


def normalize_symbol(symbol: Any) -> str:
    text = str(symbol or "").strip().upper()
    if text.endswith(".DWX"):
        text = text[:-4]
    return text


def normalize_timeframe(tf: Any) -> str:
    text = str(tf or "").strip().upper()
    if not text:
        return ""
    text = re.sub(r"\s+", " ", text)
    if text in TIMEFRAME_ALIASES:
        return TIMEFRAME_ALIASES[text]
    return text.removeprefix("PERIOD_")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def _manifest_timeframe(row: dict[str, Any]) -> str:
    for name in ("timeframe", "tf", "preset_tf"):
        value = normalize_timeframe(row.get(name))
        if value:
            return value
    set_path = str(row.get("backtest_set") or row.get("set_path") or "")
    match = re.search(r"_([A-Z0-9]+)_backtest\.set$", set_path, re.IGNORECASE)
    return normalize_timeframe(match.group(1)) if match else ""


def load_book_manifest(path_value: str | Path | None) -> dict[str, Any]:
    if path_value is None or not str(path_value).strip():
        return {
            "enabled": False,
            "path": None,
            "exists": False,
            "loaded": False,
            "expected_sleeve_count": EXPECTED_LIVE_SLEEVES,
            "sleeves": [],
            "error": None,
        }
    path = Path(path_value)
    result: dict[str, Any] = {
        "enabled": True,
        "path": str(path),
        "exists": path.is_file(),
        "loaded": False,
        "sha256": None,
        "book": None,
        "status": None,
        "declared_sleeve_count": None,
        "expected_sleeve_count": EXPECTED_LIVE_SLEEVES,
        "actual_manifest_sleeve_count": 0,
        "duplicate_key_count": 0,
        "duplicate_keys": [],
        "sleeves": [],
        "error": None,
    }
    if not path.is_file():
        result["error"] = "manifest_not_found"
        return result
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        result["error"] = f"manifest_unreadable:{exc}"
        return result
    if not isinstance(payload, dict) or not isinstance(payload.get("sleeves"), list):
        result["error"] = "manifest_missing_sleeves_array"
        return result

    sleeves: list[dict[str, Any]] = []
    counts: Counter[str] = Counter()
    for raw in payload["sleeves"]:
        if not isinstance(raw, dict):
            continue
        try:
            ea_id = int(raw.get("ea_id"))
        except (TypeError, ValueError):
            continue
        symbol = str(raw.get("symbol") or "").strip()
        symbol_norm = normalize_symbol(symbol)
        key = f"{ea_id}|{symbol_norm}"
        counts[key] += 1
        try:
            magic = int(raw["magic_number"]) if raw.get("magic_number") is not None else None
        except (TypeError, ValueError):
            magic = None
        sleeves.append(
            {
                "key": key,
                "ea_id": ea_id,
                "ea_label": raw.get("ea_label"),
                "symbol": symbol,
                "symbol_norm": symbol_norm,
                "magic": magic,
                "timeframe_norm": _manifest_timeframe(raw),
                "live_preset_path": raw.get("live_preset_path"),
            }
        )
    duplicate_keys = sorted(key for key, count in counts.items() if count > 1)
    declared = payload.get("n_sleeves")
    try:
        expected = int(declared)
    except (TypeError, ValueError):
        expected = len(sleeves)
    result.update(
        {
            "loaded": True,
            "sha256": file_sha256(path),
            "book": payload.get("book"),
            "status": payload.get("status"),
            "declared_sleeve_count": declared,
            "expected_sleeve_count": expected,
            "actual_manifest_sleeve_count": len(sleeves),
            "duplicate_key_count": len(duplicate_keys),
            "duplicate_keys": duplicate_keys,
            "sleeves": sleeves,
        }
    )
    return result


def select_manifest_presets(
    manifest: dict[str, Any],
    presets: list[dict[str, Any]],
) -> dict[str, Any]:
    if not manifest.get("loaded"):
        return {
            "selection_basis": "manifest_unavailable_all_discovered_presets",
            "selected": presets,
            "selected_count": len(presets),
            "discovered_count": len(presets),
            "ambiguous": [],
        }
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for preset in presets:
        key = f"{int(preset.get('ea_id') or 0)}|{normalize_symbol(preset.get('symbol'))}"
        grouped[key].append(preset)
    selected: list[dict[str, Any]] = []
    ambiguous: list[dict[str, Any]] = []
    for expected in manifest.get("sleeves", []):
        key = str(expected["key"])
        candidates = list(grouped.get(key, []))
        explicit = str(expected.get("live_preset_path") or "").strip()
        if explicit:
            explicit_name = Path(explicit).name.casefold()
            exact = [row for row in candidates if Path(str(row.get("path"))).name.casefold() == explicit_name]
            if exact:
                candidates = exact
        expected_magic = expected.get("magic")
        if expected_magic is not None:
            magic_matches = [row for row in candidates if int(row.get("magic") or 0) == int(expected_magic)]
            if magic_matches:
                candidates = magic_matches
        if not candidates:
            continue
        candidates = sorted(
            candidates,
            key=lambda row: (int(row.get("modified_time_ns") or 0), str(row.get("path") or "")),
        )
        chosen = candidates[-1]
        selected.append(chosen)
        if len(candidates) > 1:
            ambiguous.append(
                {
                    "key": key,
                    "chosen": chosen.get("path"),
                    "candidates": [row.get("path") for row in candidates],
                    "selection_basis": "newest_matching_magic",
                }
            )
    return {
        "selection_basis": "manifest_key_then_explicit_path_then_magic_then_newest",
        "selected": sorted(
            selected,
            key=lambda row: (int(row.get("slot") or 0), int(row.get("ea_id") or 0), str(row.get("symbol"))),
        ),
        "selected_count": len(selected),
        "discovered_count": len(presets),
        "ambiguous": ambiguous,
    }


def reconcile_manifest_to_live(
    manifest: dict[str, Any],
    presets: list[dict[str, Any]],
    loaded_sleeves: list[dict[str, Any]],
) -> dict[str, Any]:
    if not manifest.get("loaded"):
        return {
            "enabled": bool(manifest.get("enabled")),
            "checked": False,
            "expected_count": int(manifest.get("expected_sleeve_count") or EXPECTED_LIVE_SLEEVES),
            "missing_loaded": [],
            "unexpected_loaded": [],
            "missing_presets": [],
            "unexpected_presets": [],
            "magic_mismatches": [],
            "timeframe_mismatches": [],
            "mismatch_count": 0,
        }

    expected = {str(row["key"]): row for row in manifest.get("sleeves", [])}
    loaded = {
        f"{int(row.get('ea_id') or 0)}|{normalize_symbol(row.get('symbol'))}": row
        for row in loaded_sleeves
    }
    preset_map = {
        f"{int(row.get('ea_id') or 0)}|{normalize_symbol(row.get('symbol'))}": row
        for row in presets
    }
    expected_keys = set(expected)
    loaded_keys = set(loaded)
    preset_keys = set(preset_map)
    missing_loaded = [expected[key] for key in sorted(expected_keys - loaded_keys)]
    unexpected_loaded = [loaded[key] for key in sorted(loaded_keys - expected_keys)]
    missing_presets = [expected[key] for key in sorted(expected_keys - preset_keys)]
    unexpected_presets = [preset_map[key] for key in sorted(preset_keys - expected_keys)]
    magic_mismatches: list[dict[str, Any]] = []
    timeframe_mismatches: list[dict[str, Any]] = []
    for key in sorted(expected_keys & preset_keys):
        expected_row = expected[key]
        preset = preset_map[key]
        expected_magic = expected_row.get("magic")
        actual_magic = preset.get("magic")
        if expected_magic is not None and int(expected_magic) != int(actual_magic or 0):
            magic_mismatches.append(
                {
                    "key": key,
                    "expected_magic": expected_magic,
                    "actual_magic": actual_magic,
                    "preset_path": preset.get("path"),
                }
            )
        expected_tf = str(expected_row.get("timeframe_norm") or "")
        actual_tf = normalize_timeframe(preset.get("preset_tf"))
        if expected_tf and expected_tf != actual_tf:
            timeframe_mismatches.append(
                {
                    "key": key,
                    "expected_tf": expected_tf,
                    "actual_tf": actual_tf,
                    "preset_path": preset.get("path"),
                }
            )
    mismatch_count = sum(
        len(rows)
        for rows in (
            missing_loaded,
            unexpected_loaded,
            missing_presets,
            unexpected_presets,
            magic_mismatches,
            timeframe_mismatches,
        )
    )
    return {
        "enabled": True,
        "checked": True,
        "expected_count": int(manifest.get("expected_sleeve_count") or len(expected)),
        "missing_loaded": missing_loaded,
        "unexpected_loaded": unexpected_loaded,
        "missing_presets": missing_presets,
        "unexpected_presets": unexpected_presets,
        "magic_mismatches": magic_mismatches,
        "timeframe_mismatches": timeframe_mismatches,
        "mismatch_count": mismatch_count,
    }


def _read_setfile_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:
        text = path.read_text(encoding="cp1252", errors="replace")
    except OSError:
        return values
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def load_live_presets(terminal_roots: list[Path]) -> list[dict[str, Any]]:
    presets: list[dict[str, Any]] = []
    for root in terminal_roots:
        preset_dir = root / "MQL5" / "Presets"
        if not preset_dir.is_dir():
            continue
        for path in sorted(preset_dir.glob("*.set")):
            match = PRESET_FILE_RE.match(path.name)
            numbered = None if match else NUMBERED_PRESET_FILE_RE.match(path.name)
            if not match and not numbered:
                continue
            values = _read_setfile_values(path)
            if match:
                slot = int(match.group("slot"))
                magic = int(match.group("magic"))
                ea_id = int(match.group("ea_id"))
                symbol = match.group("symbol")
                tf = match.group("tf")
            else:
                slot_raw = str(values.get("qm_magic_slot_offset") or "").strip()
                if not slot_raw.isdigit():
                    continue
                slot = int(slot_raw)
                ea_id = int(numbered.group("ea_id"))
                magic = ea_id * 10000 + slot
                symbol = numbered.group("symbol")
                tf = numbered.group("tf")
            presets.append(
                {
                    "slot": slot,
                    "ea_id": ea_id,
                    "symbol": symbol,
                    "symbol_norm": normalize_symbol(symbol),
                    "preset_tf": tf,
                    "preset_tf_norm": normalize_timeframe(tf),
                    "magic": magic,
                    "qm_magic_slot_offset": values.get("qm_magic_slot_offset"),
                    "risk_percent": values.get("RISK_PERCENT"),
                    "risk_fixed": values.get("RISK_FIXED"),
                    "portfolio_weight": values.get("PORTFOLIO_WEIGHT"),
                    "path": str(path),
                    "terminal_root": str(root),
                    "modified_time_ns": path.stat().st_mtime_ns,
                }
            )
    return sorted(presets, key=lambda row: (int(row["slot"]), int(row["ea_id"]), str(row["symbol"])))


def compare_loaded_charts_to_presets(
    presets: list[dict[str, Any]],
    loaded_sleeves: list[dict[str, Any]],
) -> dict[str, Any]:
    loaded_by_key: dict[tuple[int, str], dict[str, Any]] = {}
    for row in loaded_sleeves:
        key = (int(row.get("ea_id") or 0), normalize_symbol(row.get("symbol")))
        previous = loaded_by_key.get(key)
        if previous and str(previous.get("ts_terminal") or "") > str(row.get("ts_terminal") or ""):
            continue
        loaded_by_key[key] = row

    rows: list[dict[str, Any]] = []
    mismatches: list[dict[str, Any]] = []
    missing_loaded: list[dict[str, Any]] = []
    for preset in presets:
        key = (int(preset["ea_id"]), str(preset["symbol_norm"]))
        loaded = loaded_by_key.get(key)
        actual_tf = None if loaded is None else str(loaded.get("tf") or "")
        actual_tf_norm = normalize_timeframe(actual_tf)
        expected_tf_norm = str(preset["preset_tf_norm"])
        status = "MISSING_LOADED_CHART"
        if loaded is not None:
            status = "OK" if actual_tf_norm == expected_tf_norm else "TF_MISMATCH"
        row = {
            "status": status,
            "slot": preset["slot"],
            "ea_id": preset["ea_id"],
            "symbol": preset["symbol"],
            "symbol_norm": preset["symbol_norm"],
            "magic": preset["magic"],
            "preset_tf": preset["preset_tf"],
            "preset_tf_norm": expected_tf_norm,
            "loaded_tf": actual_tf,
            "loaded_tf_norm": actual_tf_norm,
            "preset_path": preset["path"],
            "loaded_source_file": None if loaded is None else loaded.get("source_file"),
            "loaded_ts_terminal": None if loaded is None else loaded.get("ts_terminal"),
        }
        rows.append(row)
        if status == "TF_MISMATCH":
            mismatches.append(row)
        elif status == "MISSING_LOADED_CHART":
            missing_loaded.append(row)

    preset_keys = {(int(row["ea_id"]), str(row["symbol_norm"])) for row in presets}
    extra_loaded = [
        {
            "ea_id": int(row.get("ea_id") or 0),
            "symbol": row.get("symbol"),
            "symbol_norm": normalize_symbol(row.get("symbol")),
            "loaded_tf": row.get("tf"),
            "loaded_tf_norm": normalize_timeframe(row.get("tf")),
            "loaded_source_file": row.get("source_file"),
            "loaded_ts_terminal": row.get("ts_terminal"),
        }
        for key, row in sorted(loaded_by_key.items())
        if key not in preset_keys
    ]
    return {
        "preset_count": len(presets),
        "checked_count": len(rows),
        "ok_count": sum(1 for row in rows if row["status"] == "OK"),
        "mismatch_count": len(mismatches),
        "missing_loaded_count": len(missing_loaded),
        "extra_loaded_count": len(extra_loaded),
        "rows": rows,
        "mismatches": mismatches,
        "missing_loaded": missing_loaded,
        "extra_loaded": extra_loaded,
    }


def parse_terminal_journals(
    terminal_roots: list[Path], lookback_files: int, tail_bytes: int
) -> dict[str, Any]:
    terminal_journal_files: list[Path] = []
    mql_log_files: list[Path] = []
    for root in terminal_roots:
        terminal_journal_files.extend((root / "logs").glob("*.log"))
        mql_log_files.extend((root / "MQL5" / "logs").glob("*.log"))
    terminal_journal_files = latest_files(
        [p for p in terminal_journal_files if p.is_file() and DATE_FILE_RE.search(p.name)], lookback_files
    )
    mql_log_files = latest_files([p for p in mql_log_files if p.is_file() and DATE_FILE_RE.search(p.name)], lookback_files)
    journal_files = terminal_journal_files + mql_log_files

    accounts: Counter[str] = Counter()
    loaded_candidates: list[dict[str, Any]] = []
    removed_candidates: list[dict[str, Any]] = []
    transitions: list[dict[str, Any]] = []
    warning_samples: list[dict[str, Any]] = []
    warning_counts: Counter[str] = Counter()
    latest_terminal_start: str | None = None
    latest_sync: dict[str, Any] | None = None

    for path in sorted(journal_files):
        try:
            text = read_tail(path, tail_bytes)
        except OSError as exc:
            warning_counts["read_error"] += 1
            warning_samples.append({"class": "read_error", "file": str(path), "line": str(exc)})
            continue
        for line in text.splitlines():
            if not line.strip():
                continue
            ts_terminal = terminal_timestamp_from_line(path, line)
            if "metatrader 5" in line.lower() and "started" in line.lower() and "\tTerminal\t" in line:
                if ts_terminal and (latest_terminal_start is None or ts_terminal > latest_terminal_start):
                    latest_terminal_start = ts_terminal
            if account_match := ACCOUNT_RE.search(line):
                accounts[account_match.group("account")] += 1
            if sync_match := SYNC_RE.search(line):
                if ts_terminal and (latest_sync is None or ts_terminal >= str(latest_sync.get("ts_terminal"))):
                    latest_sync = {
                        "positions": int(sync_match.group("positions")),
                        "orders": int(sync_match.group("orders")),
                        "file": str(path),
                        "ts_terminal": ts_terminal,
                        "line": line_excerpt(line),
                    }
            if expert_match := EXPERT_LOADED_RE.search(line):
                name = expert_match.group("name")
                symbol = expert_match.group("symbol")
                tf = expert_match.group("tf")
                loaded_candidates.append(
                    {
                        "ea_id": int(expert_match.group("ea_id")),
                        "name": name,
                        "symbol": symbol,
                        "tf": tf,
                        "source_file": str(path),
                        "ts_terminal": ts_terminal,
                    }
                )
            elif removed_match := EXPERT_REMOVED_RE.search(line):
                removed_candidates.append(
                    {
                        "ea_id": int(removed_match.group("ea_id")),
                        "symbol": removed_match.group("symbol"),
                        "ts_terminal": ts_terminal,
                    }
                )
            if AUTOTRADING_RE.search(line):
                lowered = line.lower()
                state = "unknown"
                if any(word in lowered for word in ("enabled", "allowed", " on", "started")):
                    state = "enabled"
                if any(word in lowered for word in ("disabled", "disallowed", " off", "stopped")):
                    state = "disabled"
                transitions.append(
                    {
                        "state": state,
                        "file": str(path),
                        "ts_terminal": ts_terminal,
                        "line": line_excerpt(line),
                    }
                )
            if warning_class := classify_line(line):
                warning_counts[warning_class] += 1
                warning_samples.append(
                    {
                        "class": warning_class,
                        "file": str(path),
                        "ts_terminal": ts_terminal,
                        "line": line_excerpt(line),
                    }
                )

    warning_samples = warning_samples[-50:]
    if latest_terminal_start:
        loaded_candidates = [
            row for row in loaded_candidates if row.get("ts_terminal") and str(row["ts_terminal"]) >= latest_terminal_start
        ]
        removed_candidates = [
            row for row in removed_candidates if row.get("ts_terminal") and str(row["ts_terminal"]) >= latest_terminal_start
        ]
    loaded_sleeves: dict[str, dict[str, Any]] = {}
    for row in loaded_candidates:
        # Keep the newest loaded chart per EA+symbol. A live sleeve can be
        # reloaded on a corrected timeframe, and counting both the stale and
        # current load inflates the current live-book count.
        key = f"{row['ea_id']}|{row['symbol']}"
        previous = loaded_sleeves.get(key)
        if previous and str(previous.get("ts_terminal") or "") > str(row.get("ts_terminal") or ""):
            continue
        loaded_sleeves[key] = row
    for row in removed_candidates:
        # A sleeve detached AFTER its last load is no longer part of the live
        # book (e.g. the 10940 removal in the D2-d S3 swap). Only a removal
        # newer than the load counts - a reload after removal re-adds it.
        key = f"{row['ea_id']}|{row['symbol']}"
        current = loaded_sleeves.get(key)
        if current and str(row.get("ts_terminal") or "") >= str(current.get("ts_terminal") or ""):
            del loaded_sleeves[key]
    loaded = sorted(loaded_sleeves.values(), key=lambda row: (row["ea_id"], row["symbol"], row["tf"]))
    return {
        "journal_files": [str(p) for p in journal_files],
        "terminal_journal_files": [str(p) for p in terminal_journal_files],
        "mql_log_files": [str(p) for p in mql_log_files],
        "account_id": accounts.most_common(1)[0][0] if accounts else None,
        "accounts_seen": dict(sorted(accounts.items())),
        "latest_terminal_start": latest_terminal_start,
        "last_terminal_sync": latest_sync,
        "loaded_sleeve_count": len(loaded),
        "loaded_sleeves": loaded,
        "autotrading_transitions": transitions[-25:],
        "journal_warning_counts": dict(sorted(warning_counts.items())),
        "journal_warning_samples": warning_samples,
    }


def parse_ea_logs(
    terminal_roots: list[Path], magic_registry: dict[int, dict[str, Any]], tail_bytes: int
) -> dict[str, Any]:
    ea_log_files: list[Path] = []
    for root in terminal_roots:
        ea_log_files.extend((root / "MQL5" / "Files" / "QM").glob("QM5_*_ea-*.log"))
    ea_log_files = sorted([p for p in ea_log_files if p.is_file()])

    sleeves: dict[int, dict[str, Any]] = {}
    recent_position_events: dict[int, list[dict[str, Any]]] = defaultdict(list)
    open_positions: dict[str, dict[str, Any]] = {}
    event_counts: Counter[str] = Counter()
    warning_counts: Counter[str] = Counter()
    warning_samples: list[dict[str, Any]] = []
    parse_errors = 0
    latest_equity: dict[str, Any] | None = None

    for path in ea_log_files:
        try:
            text = read_tail(path, tail_bytes)
        except OSError as exc:
            warning_counts["read_error"] += 1
            warning_samples.append({"class": "read_error", "file": str(path), "line": str(exc)})
            continue
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                parse_errors += 1
                continue

            event_name = str(event.get("event") or "")
            event_counts[event_name] += 1
            payload = event.get("payload") if isinstance(event.get("payload"), dict) else {}
            if event_name == "EQUITY_SNAPSHOT":
                # Account-level equity is the same across all sleeve EAs; keep the
                # newest snapshot so the cockpit can show the DXZ book's live value.
                ts = event.get("ts_utc")
                if latest_equity is None or (ts and ts > (latest_equity.get("ts_utc") or "")):
                    latest_equity = {
                        "equity": payload.get("equity"),
                        "day_pnl": payload.get("day_pnl"),
                        "month_pnl": payload.get("month_pnl"),
                        "ts_utc": ts,
                        "ts_broker": event.get("ts_broker"),
                    }
            try:
                magic = int(event.get("magic") or payload.get("magic") or 0)
            except (TypeError, ValueError):
                magic = 0
            if magic:
                registry_row = magic_registry.get(magic, {})
                decoded_magic = decode_magic(magic)
                sleeve = sleeves.setdefault(
                    magic,
                    {
                        "magic": magic,
                        "ea_id": event.get("ea_id") or registry_row.get("ea_id") or decoded_magic["ea_id"],
                        "symbol_slot": registry_row.get("symbol_slot") or decoded_magic["symbol_slot"],
                        "slug": event.get("slug") or registry_row.get("ea_slug"),
                        "symbol": event.get("symbol") or payload.get("symbol") or registry_row.get("symbol"),
                        "tf": event.get("tf"),
                        "registry": registry_row or None,
                        "source_file": str(path),
                        "last_event_ts_utc": None,
                    },
                )
                sleeve["last_event_ts_utc"] = event.get("ts_utc") or sleeve.get("last_event_ts_utc")
                if event.get("symbol"):
                    sleeve["symbol"] = event.get("symbol")
                if event.get("tf"):
                    sleeve["tf"] = event.get("tf")

            level = str(event.get("level") or "").upper()
            if level in {"WARN", "WARNING", "ERROR", "CRITICAL"}:
                warning_counts[level.lower()] += 1
                warning_samples.append(
                    {
                        "class": level.lower(),
                        "file": str(path),
                        "ts_utc": event.get("ts_utc"),
                        "event": event_name,
                        "magic": magic or None,
                        "line": line_excerpt(line),
                    }
                )
            if event_name and (
                "ERROR" in event_name
                or "REJECT" in event_name
                or event_name.endswith("_FAIL")
                or event_name.endswith("_FAILED")
            ):
                warning_counts["ea_event_alert"] += 1
                warning_samples.append(
                    {
                        "class": "ea_event_alert",
                        "file": str(path),
                        "ts_utc": event.get("ts_utc"),
                        "event": event_name,
                        "magic": magic or None,
                        "line": line_excerpt(line),
                    }
                )

            if magic and event_name in POSITION_EVENT_NAMES:
                ticket = payload.get("ticket") or payload.get("position") or payload.get("order")
                position_event = {
                    "ts_utc": event.get("ts_utc"),
                    "ts_broker": event.get("ts_broker"),
                    "event": event_name,
                    "magic": magic,
                    "ticket": ticket,
                    "symbol": event.get("symbol") or payload.get("symbol"),
                    "lots": payload.get("lots") or payload.get("volume"),
                    "ok": payload.get("ok"),
                    "retcode": payload.get("retcode"),
                    "reason": payload.get("reason") or payload.get("entry_result"),
                    "source_file": str(path),
                }
                recent_position_events[magic].append(position_event)
                if ticket is not None:
                    position_key = f"{magic}:{ticket}"
                    if event_name in OPEN_EVENTS:
                        open_positions[position_key] = {
                            **position_event,
                            "registry": magic_registry.get(magic) or None,
                        }
                    elif event_name in CLOSE_EVENTS and payload.get("ok") is not False:
                        open_positions.pop(position_key, None)

    position_events_by_magic: dict[str, list[dict[str, Any]]] = {}
    for magic, rows in recent_position_events.items():
        position_events_by_magic[str(magic)] = rows[-20:]

    return {
        "ea_log_files": [str(p) for p in ea_log_files],
        "ea_log_file_count": len(ea_log_files),
        "sleeve_count_from_ea_logs": len(sleeves),
        "book_equity": latest_equity,
        "sleeves_from_ea_logs": sorted(sleeves.values(), key=lambda row: int(row["magic"])),
        "event_counts": dict(sorted(event_counts.items())),
        "position_events_by_magic": position_events_by_magic,
        "active_trade_manager_entry_count": len(open_positions),
        "active_trade_manager_entries": sorted(
            open_positions.values(), key=lambda row: (str(row.get("symbol")), str(row.get("ticket")))
        ),
        "ea_warning_counts": dict(sorted(warning_counts.items())),
        "ea_warning_samples": warning_samples[-50:],
        "json_parse_errors": parse_errors,
    }


def _latest_scan_heartbeat(journal_files: list[Path], now: datetime) -> dict[str, Any] | None:
    latest_scan: dict[str, Any] | None = None
    now_local_naive = now.astimezone().replace(tzinfo=None)
    for path in sorted(journal_files):
        try:
            text = read_tail(path, DEFAULT_TAIL_BYTES)
        except OSError:
            continue
        for line in text.splitlines():
            if not SCAN_FINISHED_RE.search(line):
                continue
            ts_local = terminal_datetime_from_line(path, line)
            if ts_local is None:
                continue
            if latest_scan and ts_local <= latest_scan["ts_local"]:
                continue
            age_minutes = round((now_local_naive - ts_local).total_seconds() / 60.0, 2)
            latest_scan = {
                "file": str(path),
                "ts_local": ts_local,
                "ts_terminal": ts_local.isoformat(),
                "minutes_since": age_minutes,
                "line": line_excerpt(line),
            }
    return latest_scan


def _current_position_count(terminal: dict[str, Any] | None, ea_logs: dict[str, Any] | None) -> tuple[int | None, str]:
    latest_sync = (terminal or {}).get("last_terminal_sync") or {}
    if latest_sync.get("positions") is not None:
        try:
            return int(latest_sync.get("positions")), "terminal_sync"
        except (TypeError, ValueError):
            pass
    active_entries = (ea_logs or {}).get("active_trade_manager_entry_count")
    if active_entries is not None:
        try:
            return int(active_entries), "ea_log_open_entries"
        except (TypeError, ValueError):
            pass
    return None, "unknown"


def _today_broker_log_status(terminal_roots: list[Path], now: datetime) -> dict[str, Any]:
    local_now = now.astimezone()
    today_name = f"{local_now:%Y%m%d}.log"
    expected_paths = [root / "logs" / today_name for root in terminal_roots]
    existing_paths = [path for path in expected_paths if path.is_file()]
    minute_of_day = local_now.hour * 60 + local_now.minute
    check_due = minute_of_day >= FIRST_SCAN_DUE_MINUTE_LOCAL
    return {
        "today_broker_date": f"{local_now:%Y%m%d}",
        "today_broker_journal_file": str(existing_paths[0] if existing_paths else expected_paths[0]),
        "today_broker_journal_file_exists": bool(existing_paths),
        "today_broker_journal_check_due": check_due,
        "first_scan_due_local": "01:50",
    }


def heartbeat(
    terminal_roots: list[Path],
    now: datetime,
    terminal: dict[str, Any] | None = None,
    ea_logs: dict[str, Any] | None = None,
) -> dict[str, Any]:
    journal_files: list[Path] = []
    for root in terminal_roots:
        journal_files.extend((root / "logs").glob("*.log"))
    journal_files = [p for p in journal_files if p.is_file() and DATE_FILE_RE.search(p.name)]
    if not journal_files:
        return {
            "latest_journal_file": None,
            "latest_journal_write_utc": None,
            "minutes_since_last_journal_write": None,
            "market_hours_mon_fri": is_market_hours(now),
            "alarm": True,
            "alarm_reason": "no_terminal_journal_files",
            "alarm_details": [
                {
                    "metric": "terminal_journal_files",
                    "value": 0,
                    "detail": "no_terminal_journal_files",
                }
            ],
        }

    latest = max(journal_files, key=lambda p: p.stat().st_mtime)
    latest_write = datetime.fromtimestamp(latest.stat().st_mtime, tz=timezone.utc)
    age_minutes = round((now - latest_write).total_seconds() / 60.0, 2)
    market_hours = is_market_hours(now)
    position_count, position_source = _current_position_count(terminal, ea_logs)
    position_exposed = bool(position_count and position_count > 0)
    journal_threshold = (
        OPEN_POSITION_JOURNAL_STALE_MINUTES if position_exposed else FLAT_JOURNAL_STALE_MINUTES
    )
    latest_scan = _latest_scan_heartbeat(journal_files, now)
    today_log = _today_broker_log_status(terminal_roots, now)

    alarm_details: list[dict[str, Any]] = []
    if market_hours and position_exposed and age_minutes > OPEN_POSITION_JOURNAL_STALE_MINUTES:
        alarm_details.append(
            {
                "metric": "journal_age_minutes",
                "value": age_minutes,
                "detail": "journal_stale_gt_120m_open_position",
            }
        )
    elif market_hours and latest_scan is None and age_minutes > FLAT_JOURNAL_STALE_MINUTES:
        alarm_details.append(
            {
                "metric": "journal_age_minutes",
                "value": age_minutes,
                "detail": "journal_stale_gt_450m_no_scan_heartbeat",
            }
        )

    if latest_scan is None:
        alarm_details.append(
            {
                "metric": "scan_heartbeat_age_minutes",
                "value": None,
                "detail": "scan_heartbeat_missing",
            }
        )
    elif latest_scan["minutes_since"] > SCAN_HEARTBEAT_STALE_MINUTES:
        alarm_details.append(
            {
                "metric": "scan_heartbeat_age_minutes",
                "value": latest_scan["minutes_since"],
                "detail": "scan_heartbeat_stale_gt_390m",
            }
        )

    if today_log["today_broker_journal_check_due"] and not today_log["today_broker_journal_file_exists"]:
        alarm_details.append(
            {
                "metric": "today_broker_journal_file",
                "value": today_log["today_broker_date"],
                "detail": "today_broker_date_journal_missing_after_first_scan",
            }
        )

    return {
        "latest_journal_file": str(latest),
        "latest_journal_write_utc": iso_utc(latest_write),
        "minutes_since_last_journal_write": age_minutes,
        "market_hours_mon_fri": market_hours,
        "position_exposed": position_exposed,
        "current_position_count": position_count,
        "current_position_source": position_source,
        "journal_stale_threshold_minutes": journal_threshold,
        "scan_heartbeat_stale_threshold_minutes": SCAN_HEARTBEAT_STALE_MINUTES,
        "latest_scan_finished": None
        if latest_scan is None
        else {
            key: value for key, value in latest_scan.items() if key != "ts_local"
        },
        **today_log,
        "alarm": bool(alarm_details),
        "alarm_reason": ";".join(str(row["detail"]) for row in alarm_details) if alarm_details else None,
        "alarm_details": alarm_details,
    }


def is_market_hours(now: datetime) -> bool:
    # Deliberately broad for the live heartbeat SLA: Monday-Friday UTC.
    return now.astimezone(timezone.utc).weekday() < 5


def build_alarms(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    alarms: list[dict[str, Any]] = []
    hb = snapshot.get("heartbeat", {})
    heartbeat_alarm_details = hb.get("alarm_details") or []
    if heartbeat_alarm_details:
        for detail in heartbeat_alarm_details:
            alarms.append(
                {
                    "class": "live_book",
                    "severity": "WARN",
                    "metric": detail.get("metric"),
                    "value": detail.get("value"),
                    "detail": detail.get("detail"),
                }
            )
    elif hb.get("alarm"):
        alarms.append(
            {
                "class": "live_book",
                "severity": "WARN",
                "metric": "journal_age_minutes",
                "value": hb.get("minutes_since_last_journal_write"),
                "detail": hb.get("alarm_reason"),
            }
        )
    terminal = snapshot.get("terminal_journals", {})
    manifest = snapshot.get("book_manifest", {})
    manifest_reconcile = snapshot.get("manifest_reconcile", {})
    expected_sleeves = int(
        manifest_reconcile.get("expected_count")
        or manifest.get("expected_sleeve_count")
        or EXPECTED_LIVE_SLEEVES
    )
    if terminal.get("loaded_sleeve_count") != expected_sleeves:
        alarms.append(
            {
                "class": "live_book",
                "severity": "WARN",
                "metric": "loaded_sleeve_count",
                "value": terminal.get("loaded_sleeve_count"),
                "detail": f"expected_{expected_sleeves}_loaded_chart_sleeves_from_manifest",
            }
        )
    if manifest.get("enabled") and not manifest.get("loaded"):
        alarms.append(
            {
                "class": "live_book",
                "severity": "WARN",
                "metric": "book_manifest",
                "value": manifest.get("path"),
                "detail": manifest.get("error") or "book_manifest_not_loaded",
            }
        )
    if manifest.get("loaded"):
        declared = manifest.get("declared_sleeve_count")
        actual = manifest.get("actual_manifest_sleeve_count")
        try:
            declared_mismatch = declared is not None and int(declared) != int(actual)
        except (TypeError, ValueError):
            declared_mismatch = True
        if declared_mismatch:
            alarms.append(
                {
                    "class": "live_book",
                    "severity": "WARN",
                    "metric": "manifest_sleeve_count",
                    "value": actual,
                    "detail": f"manifest_declares_{declared}_but_contains_{actual}",
                }
            )
        if manifest.get("duplicate_key_count"):
            alarms.append(
                {
                    "class": "live_book",
                    "severity": "WARN",
                    "metric": "manifest_duplicate_keys",
                    "value": manifest.get("duplicate_key_count"),
                    "detail": ",".join(str(value) for value in manifest.get("duplicate_keys", [])),
                }
            )
        manifest_status = str(manifest.get("status") or "").upper()
        if manifest_status not in {"APPROVED", "FROZEN", "LIVE"}:
            alarms.append(
                {
                    "class": "live_book",
                    "severity": "WARN",
                    "metric": "manifest_status",
                    "value": manifest.get("status"),
                    "detail": "live_book_manifest_not_approved_frozen_or_live",
                }
            )
    for category, metric in (
        ("missing_loaded", "manifest_missing_loaded_sleeve"),
        ("unexpected_loaded", "manifest_unexpected_loaded_sleeve"),
        ("missing_presets", "manifest_missing_live_preset"),
        ("unexpected_presets", "manifest_unexpected_live_preset"),
        ("magic_mismatches", "manifest_magic_mismatch"),
        ("timeframe_mismatches", "manifest_timeframe_mismatch"),
    ):
        for row in manifest_reconcile.get(category, []):
            key = row.get("key") or f"{row.get('ea_id')}|{normalize_symbol(row.get('symbol'))}"
            alarms.append(
                {
                    "class": "live_book",
                    "severity": "WARN",
                    "metric": metric,
                    "value": key,
                    "detail": json.dumps(row, sort_keys=True, default=str),
                }
            )
    for row in (snapshot.get("live_presets", {}) or {}).get("ambiguous_selections", []):
        alarms.append(
            {
                "class": "live_book",
                "severity": "WARN",
                "metric": "manifest_preset_selection_ambiguous",
                "value": row.get("key"),
                "detail": json.dumps(row, sort_keys=True, default=str),
            }
        )
    if not terminal.get("account_id"):
        alarms.append(
            {
                "class": "live_book",
                "severity": "WARN",
                "metric": "account_id",
                "value": None,
                "detail": "account_id_not_seen_in_terminal_journal",
            }
        )
    consistency = snapshot.get("preset_consistency", {})
    for row in consistency.get("mismatches", []):
        alarms.append(
            {
                "class": "live_book",
                "severity": "WARN",
                "metric": "chart_tf_mismatch",
                "value": f"{row.get('loaded_tf_norm')}!={row.get('preset_tf_norm')}",
                "detail": (
                    f"slot{row.get('slot')}:QM5_{row.get('ea_id')}:{row.get('symbol')} "
                    f"loaded={row.get('loaded_tf')} preset={row.get('preset_tf')}"
                ),
            }
        )
    return alarms


def write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temp_path.replace(path)


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")


def append_alarms(path: Path, now: datetime, alarms: list[dict[str, Any]]) -> None:
    if not alarms:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    ts = iso_utc(now)
    with path.open("a", encoding="utf-8") as handle:
        for alarm in alarms:
            value = "" if alarm.get("value") is None else str(alarm.get("value"))
            detail = str(alarm.get("detail") or "")
            metric = str(alarm.get("metric") or "")
            severity = str(alarm.get("severity") or "WARN")
            handle.write(
                f"{ts}\tclass=live_book\tseverity={severity}\tmetric={metric}\tvalue={value}\tdetail={detail}\n"
            )


def build_snapshot(args: argparse.Namespace) -> dict[str, Any]:
    now = utc_now()
    live_root = Path(args.live_root)
    terminal_roots = discover_terminal_roots(live_root)
    if not terminal_roots:
        raise SystemExit(f"no MT5 terminal roots found under {live_root}")

    magic_csv = Path(args.magic_csv) if args.magic_csv else default_magic_csv()
    magic_registry = load_magic_registry(magic_csv)
    terminal = parse_terminal_journals(terminal_roots, args.lookback_files, args.max_tail_bytes)
    ea_logs = parse_ea_logs(terminal_roots, magic_registry, args.max_tail_bytes)
    book_manifest = load_book_manifest(getattr(args, "book_manifest", None))
    discovered_presets = load_live_presets(terminal_roots)
    preset_selection = select_manifest_presets(book_manifest, discovered_presets)
    live_presets = preset_selection["selected"]
    preset_consistency = compare_loaded_charts_to_presets(live_presets, terminal.get("loaded_sleeves", []))
    manifest_reconcile = reconcile_manifest_to_live(
        book_manifest,
        live_presets,
        terminal.get("loaded_sleeves", []),
    )
    config_files = [parse_common_ini(root / "Config" / "common.ini") for root in terminal_roots]

    snapshot = {
        "schema_version": 2,
        "generated_at_utc": iso_utc(now),
        "read_only_contract": {
            "live_root": str(live_root),
            "terminal_roots": [str(root) for root in terminal_roots],
            "writes_under_live_root": False,
        },
        "magic_registry": {
            "path": str(magic_csv),
            "rows_loaded": len(magic_registry),
        },
        "heartbeat": heartbeat(terminal_roots, now, terminal, ea_logs),
        "terminal_config": {
            "common_ini": config_files,
            "experts_enabled_config": next(
                (row.get("experts_enabled") for row in config_files if row.get("experts_enabled") is not None),
                None,
            ),
        },
        "terminal_journals": terminal,
        "live_presets": {
            "preset_count": len(live_presets),
            "discovered_preset_count": len(discovered_presets),
            "selection_basis": preset_selection["selection_basis"],
            "ambiguous_selections": preset_selection["ambiguous"],
            "presets": live_presets,
        },
        "book_manifest": book_manifest,
        "manifest_reconcile": manifest_reconcile,
        "preset_consistency": preset_consistency,
        "ea_logs": ea_logs,
    }
    snapshot["alarms"] = build_alarms(snapshot)
    snapshot["verdict"] = "ALARM" if snapshot["alarms"] else "OK"
    return snapshot


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-root", default=str(DEFAULT_LIVE_ROOT))
    parser.add_argument("--output-json", default=str(DEFAULT_OUTPUT_JSON))
    parser.add_argument("--append-log", default=str(DEFAULT_APPEND_LOG))
    parser.add_argument("--alarm-log", default=str(DEFAULT_ALARM_LOG))
    parser.add_argument("--magic-csv", default=None)
    parser.add_argument(
        "--book-manifest",
        default=str(DEFAULT_BOOK_MANIFEST),
        help="DXZ live-book manifest; empty disables manifest reconciliation",
    )
    parser.add_argument("--lookback-files", type=int, default=10)
    parser.add_argument("--max-tail-bytes", type=int, default=DEFAULT_TAIL_BYTES)
    parser.add_argument("--no-alarm-log", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    live_root = Path(args.live_root)
    terminal_roots = discover_terminal_roots(live_root)
    protected_roots = [live_root, *terminal_roots]
    output_json = Path(args.output_json)
    append_log = Path(args.append_log)
    alarm_log = Path(args.alarm_log)
    for output_path in (output_json, append_log, alarm_log):
        assert_not_under_live_root(output_path, protected_roots)

    snapshot = build_snapshot(args)
    write_json_atomic(output_json, snapshot)
    append_jsonl(
        append_log,
        {
            "generated_at_utc": snapshot["generated_at_utc"],
            "verdict": snapshot["verdict"],
            "account_id": snapshot["terminal_journals"].get("account_id"),
            "loaded_sleeve_count": snapshot["terminal_journals"].get("loaded_sleeve_count"),
            "terminal_position_count": (snapshot["terminal_journals"].get("last_terminal_sync") or {}).get("positions"),
            "terminal_order_count": (snapshot["terminal_journals"].get("last_terminal_sync") or {}).get("orders"),
            "active_trade_manager_entry_count": snapshot["ea_logs"].get("active_trade_manager_entry_count"),
            "chart_tf_mismatch_count": snapshot["preset_consistency"].get("mismatch_count"),
            "chart_missing_loaded_count": snapshot["preset_consistency"].get("missing_loaded_count"),
            "manifest_path": snapshot["book_manifest"].get("path"),
            "manifest_sha256": snapshot["book_manifest"].get("sha256"),
            "manifest_expected_sleeve_count": snapshot["manifest_reconcile"].get("expected_count"),
            "manifest_reconcile_mismatch_count": snapshot["manifest_reconcile"].get("mismatch_count"),
            "heartbeat_minutes_since_last_journal_write": snapshot["heartbeat"].get(
                "minutes_since_last_journal_write"
            ),
            "heartbeat_minutes_since_last_scan_finished": (
                snapshot["heartbeat"].get("latest_scan_finished") or {}
            ).get("minutes_since"),
            "heartbeat_position_exposed": snapshot["heartbeat"].get("position_exposed"),
            "alarm_count": len(snapshot["alarms"]),
        },
    )
    if not args.no_alarm_log:
        append_alarms(alarm_log, datetime.fromisoformat(snapshot["generated_at_utc"].replace("Z", "+00:00")), snapshot["alarms"])

    print(json.dumps(snapshot, indent=2, sort_keys=True))
    return 0 if snapshot["verdict"] in {"OK", "ALARM"} else 2


if __name__ == "__main__":
    raise SystemExit(main())
