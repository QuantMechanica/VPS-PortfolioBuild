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
DEFAULT_TAIL_BYTES = 4 * 1024 * 1024
OPEN_POSITION_JOURNAL_STALE_MINUTES = 120
NETWORK_SCAN_HEARTBEAT_STALE_MINUTES = 390
TODAY_LOG_FIRST_SCAN_GRACE_HOUR = 2
TODAY_LOG_FIRST_SCAN_GRACE_MINUTE = 15

ACCOUNT_RE = re.compile(r"'(?P<account>\d{6,})'")
DATE_FILE_RE = re.compile(r"(?P<date>\d{8})\.log$", re.IGNORECASE)
EXPERT_LOADED_RE = re.compile(
    r"expert\s+(?P<name>QM5_(?P<ea_id>\d+)_[^(]+)\s+\((?P<symbol>[^,]+),(?P<tf>[^)]+)\)\s+loaded successfully",
    re.IGNORECASE,
)
PRESET_FILE_RE = re.compile(
    r"^slot(?P<slot>\d+)_(?P<symbol>[^_]+)_(?P<tf>[^_]+)_QM5_(?P<ea_id>\d+)_.*_magic(?P<magic>\d+)\.set$",
    re.IGNORECASE,
)
SYNC_RE = re.compile(
    r"terminal synchronized with .*?: (?P<positions>\d+) positions, (?P<orders>\d+) orders",
    re.IGNORECASE,
)
NETWORK_SCAN_RE = re.compile(r"\bscanning network finished\b", re.IGNORECASE)
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
        for path in sorted(preset_dir.glob("slot*.set")):
            match = PRESET_FILE_RE.match(path.name)
            if not match:
                continue
            values = _read_setfile_values(path)
            symbol = match.group("symbol")
            tf = match.group("tf")
            presets.append(
                {
                    "slot": int(match.group("slot")),
                    "ea_id": int(match.group("ea_id")),
                    "symbol": symbol,
                    "symbol_norm": normalize_symbol(symbol),
                    "preset_tf": tf,
                    "preset_tf_norm": normalize_timeframe(tf),
                    "magic": int(match.group("magic")),
                    "qm_magic_slot_offset": values.get("qm_magic_slot_offset"),
                    "risk_percent": values.get("RISK_PERCENT"),
                    "risk_fixed": values.get("RISK_FIXED"),
                    "portfolio_weight": values.get("PORTFOLIO_WEIGHT"),
                    "path": str(path),
                    "terminal_root": str(root),
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


def latest_network_scan(journal_files: list[Path], tail_bytes: int) -> dict[str, Any] | None:
    latest: dict[str, Any] | None = None
    for path in sorted(journal_files):
        try:
            text = read_tail(path, tail_bytes)
        except OSError:
            continue
        for line in text.splitlines():
            if not NETWORK_SCAN_RE.search(line):
                continue
            terminal_ts = terminal_timestamp_from_line(path, line)
            file_write = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)
            row = {
                "file": str(path),
                "ts_terminal": terminal_ts,
                "file_write_utc": iso_utc(file_write),
                "line": line_excerpt(line),
            }
            if latest is None:
                latest = row
                continue
            latest_key = (str(latest.get("ts_terminal") or ""), str(latest.get("file_write_utc") or ""))
            row_key = (str(row.get("ts_terminal") or ""), str(row.get("file_write_utc") or ""))
            if row_key > latest_key:
                latest = row
    return latest


def coerce_int(value: Any) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def open_exposure_count(terminal: dict[str, Any] | None, ea_logs: dict[str, Any] | None) -> int:
    sync_positions = coerce_int(((terminal or {}).get("last_terminal_sync") or {}).get("positions"))
    tm_positions = coerce_int((ea_logs or {}).get("active_trade_manager_entry_count"))
    return max(sync_positions, tm_positions)


def broker_date_yyyymmdd(now: datetime) -> str:
    return datetime.fromtimestamp(now.timestamp()).strftime("%Y%m%d")


def after_first_broker_scan(now: datetime) -> bool:
    local_now = datetime.fromtimestamp(now.timestamp())
    return (local_now.hour, local_now.minute) >= (
        TODAY_LOG_FIRST_SCAN_GRACE_HOUR,
        TODAY_LOG_FIRST_SCAN_GRACE_MINUTE,
    )


def minutes_since_terminal_timestamp(ts_terminal: Any, now: datetime) -> float | None:
    if not ts_terminal:
        return None
    try:
        terminal_time = datetime.fromisoformat(str(ts_terminal))
    except ValueError:
        return None
    local_now = datetime.fromtimestamp(now.timestamp())
    age_seconds = (local_now - terminal_time).total_seconds()
    if age_seconds < -300:
        return None
    return round(max(age_seconds, 0) / 60.0, 2)


def heartbeat(
    terminal_roots: list[Path],
    now: datetime,
    terminal: dict[str, Any] | None = None,
    ea_logs: dict[str, Any] | None = None,
    tail_bytes: int = DEFAULT_TAIL_BYTES,
) -> dict[str, Any]:
    journal_files: list[Path] = []
    for root in terminal_roots:
        journal_files.extend((root / "logs").glob("*.log"))
    journal_files = [p for p in journal_files if p.is_file() and DATE_FILE_RE.search(p.name)]
    market_hours = is_market_hours(now)
    exposure_count = open_exposure_count(terminal, ea_logs)
    today_log_name = f"{broker_date_yyyymmdd(now)}.log"
    today_log_exists = any(p.name.lower() == today_log_name.lower() for p in journal_files)
    after_first_scan = after_first_broker_scan(now)
    if not journal_files:
        return {
            "latest_journal_file": None,
            "latest_journal_write_utc": None,
            "minutes_since_last_journal_write": None,
            "latest_network_scan": None,
            "minutes_since_last_network_scan_write": None,
            "market_hours_mon_fri": market_hours,
            "open_exposure_count": exposure_count,
            "today_broker_log": today_log_name,
            "today_broker_log_exists": False,
            "after_first_broker_scan": after_first_scan,
            "alarm": True,
            "alarm_reason": "no_terminal_journal_files",
            "alarm_reasons": ["no_terminal_journal_files"],
        }

    latest = max(journal_files, key=lambda p: p.stat().st_mtime)
    latest_write = datetime.fromtimestamp(latest.stat().st_mtime, tz=timezone.utc)
    age_minutes = round((now - latest_write).total_seconds() / 60.0, 2)
    latest_scan = latest_network_scan(journal_files, tail_bytes)
    scan_age_minutes = None
    scan_age_source = None
    if latest_scan and latest_scan.get("file_write_utc"):
        scan_age_minutes = minutes_since_terminal_timestamp(latest_scan.get("ts_terminal"), now)
        scan_age_source = "terminal_ts" if scan_age_minutes is not None else None
        if scan_age_minutes is None:
            scan_write = datetime.fromisoformat(str(latest_scan["file_write_utc"]).replace("Z", "+00:00"))
            scan_age_minutes = round((now - scan_write).total_seconds() / 60.0, 2)
            scan_age_source = "file_write_utc"

    alarm_reasons: list[str] = []
    if exposure_count > 0 and age_minutes > OPEN_POSITION_JOURNAL_STALE_MINUTES:
        alarm_reasons.append("journal_stale_gt_120m_open_position")
    if latest_scan is None:
        alarm_reasons.append("network_scan_heartbeat_missing")
    elif scan_age_minutes is not None and scan_age_minutes > NETWORK_SCAN_HEARTBEAT_STALE_MINUTES:
        alarm_reasons.append("network_scan_stale_gt_390m")
    if after_first_scan and not today_log_exists:
        alarm_reasons.append("today_broker_journal_missing_after_first_scan")

    return {
        "latest_journal_file": str(latest),
        "latest_journal_write_utc": iso_utc(latest_write),
        "minutes_since_last_journal_write": age_minutes,
        "latest_network_scan": latest_scan,
        "minutes_since_last_network_scan_write": scan_age_minutes,
        "network_scan_age_source": scan_age_source,
        "market_hours_mon_fri": market_hours,
        "open_exposure_count": exposure_count,
        "today_broker_log": today_log_name,
        "today_broker_log_exists": today_log_exists,
        "after_first_broker_scan": after_first_scan,
        "alarm": bool(alarm_reasons),
        "alarm_reason": ";".join(alarm_reasons) if alarm_reasons else None,
        "alarm_reasons": alarm_reasons,
    }


def is_market_hours(now: datetime) -> bool:
    # Deliberately broad for the live heartbeat SLA: Monday-Friday UTC.
    return now.astimezone(timezone.utc).weekday() < 5


def build_alarms(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    alarms: list[dict[str, Any]] = []
    hb = snapshot.get("heartbeat", {})
    if hb.get("alarm"):
        reasons = hb.get("alarm_reasons") or [hb.get("alarm_reason")]
        for reason in reasons:
            metric = "journal_age_minutes"
            value = hb.get("minutes_since_last_journal_write")
            if reason == "no_terminal_journal_files":
                metric = "terminal_journal_files"
                value = 0
            elif reason == "network_scan_heartbeat_missing":
                metric = "network_scan_heartbeat"
                value = None
            elif reason == "network_scan_stale_gt_390m":
                metric = "network_scan_age_minutes"
                value = hb.get("minutes_since_last_network_scan_write")
            elif reason == "today_broker_journal_missing_after_first_scan":
                metric = "today_broker_log"
                value = hb.get("today_broker_log")
            alarms.append(
                {
                    "class": "live_book",
                    "severity": "WARN",
                    "metric": metric,
                    "value": value,
                    "detail": reason,
                }
            )
    terminal = snapshot.get("terminal_journals", {})
    if terminal.get("loaded_sleeve_count") != 13:
        alarms.append(
            {
                "class": "live_book",
                "severity": "WARN",
                "metric": "loaded_sleeve_count",
                "value": terminal.get("loaded_sleeve_count"),
                "detail": "expected_13_loaded_chart_sleeves",
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
    live_presets = load_live_presets(terminal_roots)
    preset_consistency = compare_loaded_charts_to_presets(live_presets, terminal.get("loaded_sleeves", []))
    config_files = [parse_common_ini(root / "Config" / "common.ini") for root in terminal_roots]

    snapshot = {
        "schema_version": 1,
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
        "heartbeat": heartbeat(terminal_roots, now, terminal, ea_logs, args.max_tail_bytes),
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
            "presets": live_presets,
        },
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
            "heartbeat_minutes_since_last_journal_write": snapshot["heartbeat"].get(
                "minutes_since_last_journal_write"
            ),
            "alarm_count": len(snapshot["alarms"]),
        },
    )
    if not args.no_alarm_log:
        append_alarms(alarm_log, datetime.fromisoformat(snapshot["generated_at_utc"].replace("Z", "+00:00")), snapshot["alarms"])

    print(json.dumps(snapshot, indent=2, sort_keys=True))
    return 0 if snapshot["verdict"] in {"OK", "ALARM"} else 2


if __name__ == "__main__":
    raise SystemExit(main())
