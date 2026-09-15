"""Governed T1 wrapper for the read-only 37-symbol DWX M1 overlap export."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from typing import Any, Mapping


REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from framework.scripts.mt5_diagnostics import dwx_tick_tail_probe as governance_guard
from tools.dukascopy import common as dukascopy_common
from tools.dukascopy import reconcile_overlap
from tools.strategy_farm import dwx_m1_overlap_export_work_item
from tools.strategy_farm import farmctl
from tools.strategy_farm import ftmo_m1_bootstrap as boot


ROOT = Path("D:/QM/mt5/T1")
SOURCE = Path(__file__).with_name("QM_DWX_M1_Overlap_Export.mq5")
RAW_HEADER = ["time", "open", "high", "low", "close", "tickvol"]
FINAL_HEADER = list(RAW_HEADER)
RECEIPT_SCHEMA = "qm.dwx-m1-overlap-export-receipt/v2"
EXPORT_MANIFEST_SCHEMA = dwx_m1_overlap_export_work_item.EXPORT_MANIFEST_SCHEMA
FORBIDDEN_CUSTOM_API_TOKENS = (r"\bCustom[A-Za-z0-9_]*\s*\(",)

# Per-chunk tick-copy journal written by QM_DWX_M1_Overlap_Export.mq5's
# CopyChunk/JournalChunk next to each symbol's raw M1 CSV.
CHUNK_JOURNAL_HEADER = [
    "symbol", "chunk_start_epoch", "chunk_end_epoch", "phase", "attempt",
    "copied", "error_code", "status",
]

# Completeness floor source: the P1 manifest's per-symbol downloaded_hours
# (docs/ops/evidence/2026-09-15_dukascopy_p3_completion/p1_window_manifest_receipt.json,
# schema qm.dukascopy-p3-p1-window/v1, sha256-bound download_manifest.jsonl
# provenance) -- not a live Dukascopy-side count, so this classification
# needs no network access and no T1 run to compute. downloaded_hours*60 is a
# per-symbol upper bound on obtainable minutes; the session-closure allowance
# below then converts it into a whole-window floor. Calibrated against the
# 2026-09-13 fixed-window reconciliation, which showed two populations: 27
# FX/index symbols at 83.8%-98.5% dukascopy_coverage (ordinary DWX/Dukascopy
# session-accounting differences, not a defect) and 10 symbols at
# 0.03%-2.3% (catastrophic short reads). The allowances below sit below the
# ordinary population's worst case so a legitimate export still classifies
# COMPLETE.
#
# This whole-window floor is deliberately NOT the AUDCAD-class defect's
# catching mechanism: AUDCAD's real 2026-09-13 failure (dense - 25-day hole -
# dense, 155,802 DWX bars over a 184,920-minute FX ceiling = 84.25% of
# ceiling) sits *inside* the ordinary 83.8%-98.5% legitimate-shortfall band,
# so no whole-window allowance can separate it from a legitimate export
# without also rejecting some legitimate ones. The authoritative closing
# check for that class is reconcile_overlap.longest_weekday_gap at the
# reconciliation stage, since it alone compares against Dukascopy ground
# truth per symbol rather than a static P1 ceiling. The per-chunk floor
# below (chunk_expected_minutes) is a *diagnostic* companion, not a second
# status gate: it surfaces which of a symbol's ~26 chunks are materially
# short in short_chunks even when the whole-window ratio does not trip, but
# does not by itself flip a symbol's status -- there is no production
# evidence yet (the chunk journal is new; the 2026-09-13 raw exports predate
# it) that a per-chunk allowance this tight would not also reject a
# legitimate single-holiday chunk, so it is left informational until a real
# governed rerun's chunk journals can calibrate it the way the 2026-09-13
# reconciliation calibrated the whole-window allowances above.
P1_WINDOW_MANIFEST_RECEIPT = (
    REPO_ROOT
    / "docs/ops/evidence/2026-09-15_dukascopy_p3_completion/p1_window_manifest_receipt.json"
)
INDEX_COMMODITY_SYMBOLS = frozenset({
    "GDAXI.DWX", "UK100.DWX", "NDX.DWX", "SP500.DWX", "WS30.DWX",
    "XAUUSD.DWX", "XAGUSD.DWX", "XNGUSD.DWX", "XTIUSD.DWX",
})
SESSION_CLOSURE_ALLOWANCE_FRACTION = {
    "fx": 0.20,
    "index_commodity": 0.35,
}


def sha256_file(path: Path) -> str:
    return dwx_m1_overlap_export_work_item.sha256_file(Path(path))


def _atomic_write_json(path: Path, value: object) -> None:
    governance_guard._atomic_write_json(Path(path), value)


def _iso_utc(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).isoformat(timespec="seconds").replace(
        "+00:00", "Z"
    )


def broker_epoch_to_utc(value: int) -> dt.datetime:
    parsed = governance_guard.broker_msc_to_utc(int(value) * 1000)
    if parsed.second != 0 or parsed.microsecond != 0:
        raise ValueError("M1 broker timestamp is not minute-aligned")
    return parsed


def validate_mql_source(path: Path = SOURCE) -> dict[str, Any]:
    source = Path(path).read_text(encoding="utf-8-sig")
    forbidden = [
        pattern
        for pattern in (*boot.FORBIDDEN_MQL_TOKENS, *FORBIDDEN_CUSTOM_API_TOKENS)
        if re.search(pattern, source)
    ]
    if forbidden:
        raise ValueError(
            "MQL export contains a trading/custom API: " + ",".join(forbidden)
        )
    compact = re.sub(r"\s+", "", source).lower()
    if 'root!="d:\\\\qm\\\\mt5\\\\t1"' not in compact:
        raise ValueError("exact T1 MQL path guard absent")
    declared = set(re.findall(r'"([A-Z0-9]+\.DWX)"', source))
    if (
        declared != set(dukascopy_common.CANONICAL_SYMBOLS)
        or len(declared) != 37
    ):
        raise ValueError("MQL export universe is not the exact canonical 37")
    for required in (
        "CopyTicksRange(",
        "COPY_TICKS_ALL",
        "DWX_M1_TICK_AGG_PROJECTION",
        "1759287600",
        "1775012400",
        '"time","open","high","low","close","tickvol"',
    ):
        if required not in source:
            raise ValueError(f"MQL export contract token absent: {required}")
    return {
        "path": str(Path(path).resolve()),
        "sha256": sha256_file(Path(path)),
        "symbol_count": len(declared),
        "read_only_api": True,
        "period": "M1",
        "overlap_start_utc": dwx_m1_overlap_export_work_item.OVERLAP_START_TEXT,
        "overlap_end_utc": dwx_m1_overlap_export_work_item.OVERLAP_END_TEXT,
    }


def instrument_class(symbol: str) -> str:
    return "index_commodity" if symbol in INDEX_COMMODITY_SYMBOLS else "fx"


def load_expected_minutes(
    path: Path = P1_WINDOW_MANIFEST_RECEIPT,
) -> dict[str, int]:
    payload = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if (
        payload.get("schema") != "qm.dukascopy-p3-p1-window/v1"
        or payload.get("window_start_utc")
        != dwx_m1_overlap_export_work_item.OVERLAP_START_TEXT
        or payload.get("window_end_utc_exclusive")
        != dwx_m1_overlap_export_work_item.OVERLAP_END_TEXT
    ):
        raise ValueError("P1 window manifest receipt contract mismatch")
    expected: dict[str, int] = {}
    for row in payload.get("symbols") or []:
        symbol = str(row["symbol"]).strip().upper()
        ceiling_minutes = int(row["downloaded_hours"]) * 60
        allowance = SESSION_CLOSURE_ALLOWANCE_FRACTION[instrument_class(symbol)]
        expected[symbol] = int(ceiling_minutes * (1.0 - allowance))
    if set(expected) != set(dukascopy_common.CANONICAL_SYMBOLS):
        raise ValueError("P1 window manifest receipt symbol coverage mismatch")
    return expected


def parse_chunk_journal(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with Path(path).open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != CHUNK_JOURNAL_HEADER:
            raise ValueError(f"chunk journal schema mismatch: {path}")
        for raw in reader:
            rows.append(
                {
                    "symbol": raw["symbol"],
                    "chunk_start_epoch": int(raw["chunk_start_epoch"]),
                    "chunk_end_epoch": int(raw["chunk_end_epoch"]),
                    "phase": raw["phase"],
                    "attempt": int(raw["attempt"]),
                    "copied": int(raw["copied"]),
                    "error_code": int(raw["error_code"]),
                    "status": raw["status"],
                }
            )
    return rows


def chunk_expected_minutes(symbol: str, chunk_start_epoch: int, chunk_end_epoch: int) -> int:
    """Per-chunk floor: weekday-only seconds in the chunk's span (the same
    "inside a trading week" proxy reconcile_overlap.longest_weekday_gap uses
    for the AUDCAD-class defect), minus the symbol's session-closure
    allowance. A 7-day chunk sitting entirely inside a genuine multi-week
    hole starves this floor even when the symbol's whole-window aggregate
    (load_expected_minutes) stays above its own floor."""
    weekday_seconds = reconcile_overlap._weekday_seconds_in_range(
        int(chunk_start_epoch), int(chunk_end_epoch)
    )
    allowance = SESSION_CLOSURE_ALLOWANCE_FRACTION[instrument_class(symbol)]
    return int((weekday_seconds / 60) * (1.0 - allowance))


def short_chunks_from_journal(
    symbol: str, rows: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    zero_chunks = {
        (row["chunk_start_epoch"], row["chunk_end_epoch"])
        for row in rows
        if row["status"] == "ZERO_TICK_CHUNK"
    }
    short: dict[tuple[int, int], dict[str, Any]] = {
        window: {"chunk_start_epoch": window[0], "chunk_end_epoch": window[1]}
        for window in zero_chunks
    }
    for row in rows:
        if row["status"] != "CHUNK_ROWS":
            continue
        window = (row["chunk_start_epoch"], row["chunk_end_epoch"])
        floor = chunk_expected_minutes(symbol, window[0], window[1])
        rows_written = int(row["copied"])
        if floor > 0 and rows_written < floor:
            short[window] = {
                "chunk_start_epoch": window[0],
                "chunk_end_epoch": window[1],
                "chunk_rows_written": rows_written,
                "chunk_expected_minutes": floor,
            }
    return [short[window] for window in sorted(short)]


def classify_completeness(
    symbol: str, rows: int, expected_minutes: Mapping[str, int]
) -> dict[str, Any]:
    floor = int(expected_minutes[symbol])
    ratio = (rows / floor) if floor > 0 else 0.0
    return {
        "expected_minutes": floor,
        "completeness_ratio": ratio,
        "status": "COMPLETE" if rows >= floor else "SHORT_READ",
    }


def canonicalize_raw_symbol(
    raw_path: Path,
    output_path: Path,
    *,
    symbol: str,
) -> dict[str, Any]:
    symbol = str(symbol).strip().upper()
    if symbol not in dukascopy_common.CANONICAL_SYMBOLS:
        raise ValueError(f"symbol is outside the canonical DWX universe: {symbol!r}")
    start = dwx_m1_overlap_export_work_item.OVERLAP_START_UTC
    end = dwx_m1_overlap_export_work_item.OVERLAP_END_UTC
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_name(f".{output_path.name}.{os.getpid()}.tmp")
    rows = 0
    first_utc: dt.datetime | None = None
    last_utc: dt.datetime | None = None
    try:
        with Path(raw_path).open(encoding="utf-8-sig", newline="") as source_handle:
            reader = csv.DictReader(source_handle)
            if reader.fieldnames != RAW_HEADER:
                raise ValueError(f"raw M1 schema mismatch: {symbol}")
            with temporary.open("w", encoding="utf-8", newline="") as output_handle:
                writer = csv.DictWriter(
                    output_handle, fieldnames=FINAL_HEADER, lineterminator="\n"
                )
                writer.writeheader()
                for line_number, raw in enumerate(reader, start=2):
                    try:
                        broker_epoch = int(str(raw["time"]).strip())
                        instant = broker_epoch_to_utc(broker_epoch)
                        open_price = float(raw["open"])
                        high = float(raw["high"])
                        low = float(raw["low"])
                        close = float(raw["close"])
                        tick_volume = int(str(raw["tickvol"]).strip())
                    except (KeyError, TypeError, ValueError) as exc:
                        raise ValueError(
                            f"invalid raw M1 row {symbol}:{line_number}: {exc}"
                        ) from exc
                    prices = (open_price, high, low, close)
                    if (
                        instant < start
                        or instant >= end
                        or (last_utc is not None and instant <= last_utc)
                        or any(not math.isfinite(value) or value <= 0 for value in prices)
                        or high < max(open_price, close)
                        or low > min(open_price, close)
                        or high < low
                        or tick_volume < 0
                    ):
                        raise ValueError(
                            f"invalid raw M1 values {symbol}:{line_number}"
                        )
                    row = {
                        "time": _iso_utc(instant),
                        "open": format(open_price, ".12g"),
                        "high": format(high, ".12g"),
                        "low": format(low, ".12g"),
                        "close": format(close, ".12g"),
                        "tickvol": str(tick_volume),
                    }
                    writer.writerow(row)
                    first_utc = first_utc or instant
                    last_utc = instant
                    rows += 1
                output_handle.flush()
                os.fsync(output_handle.fileno())
        if rows <= 0 or first_utc is None or last_utc is None:
            raise ValueError(f"raw M1 export is empty: {symbol}")
        os.replace(temporary, output_path)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise

    # This is an intentional runtime compatibility check against the exact P3
    # reader. It proves each emitted UTC ISO file normalizes back to the broker
    # epoch used by the existing reconciliation engine.
    parsed = reconcile_overlap.read_m1_csv(output_path)
    expected_first = dukascopy_common.broker_epoch_seconds_for_utc(first_utc)
    expected_last = dukascopy_common.broker_epoch_seconds_for_utc(last_utc)
    if (
        len(parsed) != rows
        or min(parsed) != expected_first
        or max(parsed) != expected_last
    ):
        raise ValueError(f"P3 reader compatibility check failed: {symbol}")
    return {
        "symbol": symbol,
        "path": str(output_path.resolve()),
        "sha256": sha256_file(output_path),
        "rows": rows,
        "schema": FINAL_HEADER,
        "first_utc": _iso_utc(first_utc),
        "last_utc": _iso_utc(last_utc),
    }


def canonicalize_export_set(
    raw_dir: Path,
    output_dir: Path,
) -> dict[str, Any]:
    raw_dir = Path(raw_dir).resolve()
    output_dir = Path(output_dir).resolve()
    symbols = dwx_m1_overlap_export_work_item.load_symbols()
    expected_names = {f"{symbol}_M1.csv" for symbol in symbols}
    # The per-symbol chunk journal (item 1 of the 2026-09-15 export-fix
    # ticket) is written by the mq5 script beside each M1 CSV but is
    # optional here: older exports (and existing fixtures) predate it, and
    # its absence must not turn into a file-set mismatch.
    optional_chunk_names = {f"{symbol}_M1_chunks.csv" for symbol in symbols}
    actual_names = {path.name for path in raw_dir.glob("*.csv") if path.is_file()}
    missing = expected_names - actual_names
    unexpected = actual_names - expected_names - optional_chunk_names
    if missing or unexpected:
        raise ValueError(
            "raw M1 export file set mismatch: "
            f"missing={sorted(missing)} extra={sorted(unexpected)}"
        )
    expected_minutes = load_expected_minutes()
    raw_copy_dir = output_dir / "raw"
    final_dir = output_dir / "dwx_m1"
    raw_copy_dir.mkdir(parents=True, exist_ok=False)
    final_dir.mkdir(parents=True, exist_ok=False)
    bindings: list[dict[str, Any]] = []
    failed_symbols: list[dict[str, str]] = []
    total_rows = 0
    for symbol in symbols:
        filename = f"{symbol}_M1.csv"
        raw_copy = raw_copy_dir / filename
        shutil.copyfile(raw_dir / filename, raw_copy)
        chunk_filename = f"{symbol}_M1_chunks.csv"
        chunk_source = raw_dir / chunk_filename
        chunk_rows: list[dict[str, Any]] = []
        chunk_journal_binding: dict[str, Any] | None = None
        if chunk_source.is_file():
            chunk_copy = raw_copy_dir / chunk_filename
            shutil.copyfile(chunk_source, chunk_copy)
            chunk_rows = parse_chunk_journal(chunk_source)
            chunk_journal_binding = {
                "path": str(chunk_copy.resolve()),
                "sha256": sha256_file(chunk_copy),
                "row_count": len(chunk_rows),
            }
        final_path = final_dir / filename
        try:
            binding = canonicalize_raw_symbol(
                raw_copy,
                final_path,
                symbol=symbol,
            )
        except ValueError as exc:
            # One bad symbol must not hide the outcome for the rest of the
            # governed universe. A compatibility failure can occur after the
            # final file was installed, so also ensure failed outputs are not
            # left beside successful canonical files.
            final_path.unlink(missing_ok=True)
            failed_symbols.append({"symbol": symbol, "reason": str(exc)})
            continue
        binding["raw_path"] = str(raw_copy.resolve())
        binding["raw_sha256"] = sha256_file(raw_copy)
        binding["short_chunks"] = short_chunks_from_journal(symbol, chunk_rows)
        binding["chunk_journal"] = chunk_journal_binding
        binding.update(
            classify_completeness(symbol, int(binding["rows"]), expected_minutes)
        )
        bindings.append(binding)
        total_rows += int(binding["rows"])
    # A symbol is COMPLETE only when exported minutes >= its expected-minutes
    # floor; SHORT_READ never becomes COMPLETE by any downstream aggregation
    # -- canonicalization_status stays PARTIAL/COMPLETE on parse success only,
    # short_read_symbols is the separate, additive completeness gate that
    # run()'s overall status also enforces.
    short_read_symbols = [
        str(binding["symbol"]) for binding in bindings if binding["status"] == "SHORT_READ"
    ]
    canonicalization_status = "COMPLETE" if not failed_symbols else "PARTIAL"
    price_scale = dwx_m1_overlap_export_work_item._price_scale_binding()
    manifest = {
        "schema_version": EXPORT_MANIFEST_SCHEMA,
        "canonicalization_status": canonicalization_status,
        "source_terminal": "T1",
        "read_only": True,
        "period": "M1",
        "overlap_start_utc": dwx_m1_overlap_export_work_item.OVERLAP_START_TEXT,
        "overlap_end_utc": dwx_m1_overlap_export_work_item.OVERLAP_END_TEXT,
        "window_end_inclusive": False,
        "schema": FINAL_HEADER,
        "symbols": symbols,
        "symbol_count": len(symbols),
        "attempted_symbol_count": len(symbols),
        "successful_symbol_count": len(bindings),
        "failed_symbol_count": len(failed_symbols),
        "failed_symbols": failed_symbols,
        "short_read_symbols": short_read_symbols,
        "short_read_symbol_count": len(short_read_symbols),
        "total_rows": total_rows,
        "price_scale_csv": price_scale,
        "reconcile_overlap": {
            "path": str(dwx_m1_overlap_export_work_item.RECONCILE_OVERLAP.resolve()),
            "sha256": sha256_file(
                dwx_m1_overlap_export_work_item.RECONCILE_OVERLAP
            ),
            "reader": "read_m1_csv",
        },
        "files": bindings,
    }
    manifest_path = output_dir / "dwx_m1_manifest.json"
    _atomic_write_json(manifest_path, manifest)
    return {
        "path": str(manifest_path.resolve()),
        "sha256": sha256_file(manifest_path),
        "canonicalization_status": canonicalization_status,
        "symbols": len(bindings),
        "attempted_symbol_count": len(symbols),
        "successful_symbol_count": len(bindings),
        "failed_symbol_count": len(failed_symbols),
        "failed_symbols": failed_symbols,
        "short_read_symbols": short_read_symbols,
        "short_read_symbol_count": len(short_read_symbols),
        "total_rows": total_rows,
        "schema": FINAL_HEADER,
        "overlap_start_utc": dwx_m1_overlap_export_work_item.OVERLAP_START_TEXT,
        "overlap_end_utc": dwx_m1_overlap_export_work_item.OVERLAP_END_TEXT,
    }


def _validate_claim(root: Path, work_item_id: str, out: Path) -> dict[str, Any]:
    if os.environ.get("QM_DWX_M1_OVERLAP_WORK_ITEM_ID") != work_item_id:
        raise ValueError("M1 export wrapper lacks the exact work-item binding")
    if os.environ.get("QM_DWX_M1_OVERLAP_CLAIMED_TERMINAL", "").upper() != "T1":
        raise ValueError("M1 export wrapper lacks the exact T1 claim binding")
    with farmctl.connect(root) as connection:
        row = connection.execute(
            "SELECT * FROM work_items WHERE id=?", (work_item_id,)
        ).fetchone()
    if row is None:
        raise ValueError("M1 export work item is absent")
    payload = json.loads(row["payload_json"] or "{}")
    dwx_m1_overlap_export_work_item.validate_payload(
        payload, terminal="T1", verify_files=True
    )
    if (
        str(row["status"]) != "active"
        or str(row["claimed_by"]).upper() != "T1"
        or str(row["kind"]) != farmctl.DIAGNOSTIC_WORK_ITEM_KIND
        or str(row["phase"]) != farmctl.DWX_M1_OVERLAP_EXPORT_PHASE
        or payload.get("diagnostic_contract")
        != farmctl.DWX_M1_OVERLAP_EXPORT_CONTRACT
        or payload.get("diagnostic_non_admission") is not True
        or payload.get("diagnostic_allowed_terminals") != ["T1"]
        or payload.get("export_stamp") != out.name
        or Path(str(payload.get("output_dir") or "")).resolve() != out
    ):
        raise ValueError("M1 export work-item claim contract mismatch")
    return {"row": dict(row), "payload": payload}


def _owned_match(
    row: dict[str, Any], ini: Path, started: dt.datetime
) -> dict[str, Any] | None:
    return governance_guard._owned_match(row, ini, started)


def _terminate_owned(identity: Mapping[str, Any], ini: Path) -> dict[str, Any]:
    return governance_guard._terminate_owned(identity, ini)


def _summary_path_guard(summary_path: Path, work_item_id: str) -> Path:
    resolved = Path(summary_path).resolve()
    expected = (
        Path("D:/QM/reports/work_items")
        / work_item_id
        / farmctl.DWX_M1_OVERLAP_EXPORT_EA_ID
        / farmctl.DWX_M1_OVERLAP_EXPORT_PHASE
        / "summary.json"
    ).resolve()
    if resolved != expected:
        raise ValueError("summary path must be the exact M1 export work-item summary")
    return resolved


def _compute_receipt_status(
    result: Mapping[str, Any], manifest_binding: Mapping[str, Any]
) -> str:
    return (
        "PASS"
        if (
            "error" not in result
            and "cleanup_error" not in result
            and "post_audit_error" not in result
            and "output_error" not in result
            and str(result.get("completion", "")).startswith(
                "successes=37 failures=0 terminal=T1 "
            )
            and result.get("signed_archive_unchanged") is True
            and result.get("canonicalization_status") == "COMPLETE"
            and result.get("failed_symbol_count") == 0
            and manifest_binding.get("symbols") == 37
            and int(manifest_binding.get("total_rows") or 0) > 0
            # SHORT_READ never becomes COMPLETE by any downstream
            # aggregation: a single short-read symbol fails the receipt
            # even though written_rows>0 and canonicalization succeeded.
            and not manifest_binding.get("short_read_symbol_count")
        )
        else "FAIL"
    )


def _summary_error_text(result: Mapping[str, Any]) -> str | None:
    return (
        result.get("error")
        or result.get("output_error")
        or result.get("post_audit_error")
        or (
            "M1 canonicalization completed with "
            f"{result.get('failed_symbol_count', 0)} failed symbol(s)"
            if result.get("failed_symbol_count", 0)
            else None
        )
        or (
            f"SHORT_READ symbol(s) below the expected-minutes floor: "
            f"{', '.join(result.get('short_read_symbols', []))}"
            if result.get("short_read_symbol_count", 0)
            else None
        )
    )


def run(
    out: Path,
    summary_path: Path,
    work_item_id: str,
    farm_root: Path,
    *,
    timeout: int = 3600,
) -> dict[str, Any]:
    out = Path(out).resolve()
    summary_path = _summary_path_guard(summary_path, work_item_id)
    farm_root = Path(farm_root).resolve()
    boot._safe_tag(out.name)
    if not 300 <= int(timeout) <= 3600:
        raise ValueError("M1 export timeout must be 300..3600 seconds")
    expected_parent = dwx_m1_overlap_export_work_item.EXPORT_ROOT.resolve()
    if out.parent != expected_parent or out.exists():
        raise ValueError("M1 export output must be a new direct child of its root")
    if (farm_root / "state/FACTORY_OFF.flag").exists():
        raise ValueError("factory is administratively OFF; production export refused")
    claim = _validate_claim(farm_root, work_item_id, out)
    source_binding = validate_mql_source(SOURCE)
    terminal = ROOT / "terminal64.exe"
    if boot._exact_process_for_path(boot.scan_terminal_processes(), terminal):
        raise ValueError("T1 is already active; defer without interruption")

    out.mkdir(parents=True)
    result: dict[str, Any] = {
        "schema_version": RECEIPT_SCHEMA,
        "status": "FAIL",
        "canonicalization_status": "NOT_RUN",
        "attempted_symbol_count": 0,
        "successful_symbol_count": 0,
        "failed_symbol_count": 0,
        "failed_symbols": [],
        "no_gate_verdict": True,
        "work_item_id": work_item_id,
        "phase": farmctl.DWX_M1_OVERLAP_EXPORT_PHASE,
        "terminal_claim": "T1",
        "export_stamp": out.name,
        "started_at_utc": boot.utc_now(),
        "source": source_binding,
        "governance_guard": boot.file_binding(
            dwx_m1_overlap_export_work_item.GOVERNANCE_GUARD
        ),
        "reconcile_overlap": boot.file_binding(
            dwx_m1_overlap_export_work_item.RECONCILE_OVERLAP
        ),
        "price_scale_csv": dwx_m1_overlap_export_work_item._price_scale_binding(),
        "work_item_payload_sha256": hashlib.sha256(
            str(claim["row"]["payload_json"]).encode("utf-8")
        ).hexdigest(),
        "config_safety": {
            "Enabled": 0,
            "AllowLiveTrading": 0,
            "AllowDllImport": 0,
            "terminal_path": str(terminal),
            "manual_terminal_start": False,
        },
        "requested_window": {
            "start_utc": dwx_m1_overlap_export_work_item.OVERLAP_START_TEXT,
            "end_utc": dwx_m1_overlap_export_work_item.OVERLAP_END_TEXT,
            "end_inclusive": False,
        },
    }
    process: subprocess.Popen[bytes] | None = None
    identity: dict[str, Any] | None = None
    ini: Path | None = None
    raw_terminal_dir: Path | None = None
    pre_snapshot: dict[str, Any] | None = None
    try:
        pre_audit = governance_guard._compact_isolation_audit(farm_root)
        if (
            pre_audit.get("manifest_sha256") != claim["payload"].get("manifest_sha256")
            or Path(str(pre_audit.get("manifest_path") or "")).resolve()
            != Path(str(claim["payload"].get("manifest_path") or "")).resolve()
        ):
            raise ValueError("active signed archive differs from the claimed manifest")
        pre_snapshot = governance_guard._signed_archive_snapshot(
            Path(pre_audit["manifest_path"])
        )
        result["custom_history_pre_audit"] = pre_audit
        result["signed_archive_before"] = pre_snapshot

        with boot.exclusive_bootstrap_lock(
            farm_root / "state" / "locks" / "t1_dwx_m1_overlap_export.lock"
        ):
            editor = ROOT / "MetaEditor64.exe"
            if any(
                boot._windows_path_key(row.get("ExecutablePath", ""))
                == boot._windows_path_key(editor)
                for row in boot.scan_metaeditor_processes()
            ):
                raise ValueError("T1 MetaEditor is already active")
            staged = ROOT / "MQL5/Scripts/QM/dwx_m1_overlap" / out.name / SOURCE.name
            if staged.exists() or staged.with_suffix(".ex5").exists():
                raise ValueError("M1 export script staging path already exists")
            staged.parent.mkdir(parents=True, exist_ok=False)
            shutil.copyfile(SOURCE, staged)
            compile_log = out / "compile.log"
            compiled = subprocess.run(
                [str(editor), f"/compile:{staged}", f"/log:{compile_log}"],
                cwd=ROOT,
                capture_output=True,
                timeout=180,
                creationflags=subprocess.CREATE_NO_WINDOW,
                check=False,
            )
            counts = re.findall(
                r"(\d+) errors?, (\d+) warnings?", boot._read_text_auto(compile_log)
            )
            ex5 = staged.with_suffix(".ex5")
            if (
                compiled.returncode not in (0, 1)
                or not counts
                or counts[-1] != ("0", "0")
                or not ex5.is_file()
            ):
                raise ValueError("M1 export compile did not pass 0 errors / 0 warnings")
            compiled_dir = out / "compiled"
            compiled_dir.mkdir()
            shutil.copyfile(staged, compiled_dir / staged.name)
            shutil.copyfile(ex5, compiled_dir / ex5.name)
            result["compile"] = {
                "exit_code": compiled.returncode,
                "errors": 0,
                "warnings": 0,
                "log": boot.file_binding(compile_log),
                "source": boot.file_binding(compiled_dir / staged.name),
                "ex5": boot.file_binding(compiled_dir / ex5.name),
            }

            output_rel = f"QM\\dwx_m1_overlap\\{out.name}"
            marker_name = f"QM_DWX_M1_OVERLAP_COMPLETE_{out.name}.txt"
            raw_terminal_dir = ROOT / "MQL5/Files/QM/dwx_m1_overlap" / out.name
            marker = ROOT / "MQL5/Files" / marker_name
            if raw_terminal_dir.exists() or marker.exists():
                raise ValueError("M1 export terminal output path already exists")
            raw_terminal_dir.mkdir(parents=True, exist_ok=False)
            preset = ROOT / "MQL5/Presets" / f"QM_DWX_M1_OVERLAP_{out.name}.set"
            if preset.exists():
                raise ValueError("M1 export preset already exists")
            boot.atomic_write_text(
                preset,
                "\n".join(
                    [
                        f"InpOutputDir={output_rel}",
                        f"InpCompletion={marker_name}",
                        f"InpStartBrokerEpoch={claim['payload']['start_broker_epoch']}",
                        f"InpEndBrokerEpoch={claim['payload']['end_broker_epoch']}",
                        "InpChunkDays=7",
                        "InpSyncAttempts=30",
                        "",
                    ]
                ),
            )
            login, server = boot.load_dxz_factory_login()
            if server.lower() != "darwinex-live":
                raise ValueError(f"refused non-Darwinex-Live server: {server}")
            ini = out / "startup.ini"
            boot.atomic_write_text(
                ini,
                "\n".join(
                    [
                        "[Common]",
                        f"Login={login}",
                        f"Server={server}",
                        "[Experts]",
                        "Enabled=0",
                        "AllowLiveTrading=0",
                        "AllowDllImport=0",
                        "[StartUp]",
                        f"Script=QM\\dwx_m1_overlap\\{out.name}\\QM_DWX_M1_Overlap_Export",
                        f"ScriptParameters={preset.name}",
                        "Symbol=EURUSD.DWX",
                        "Period=M1",
                        "ShutdownTerminal=0",
                        "",
                    ]
                ),
            )
            _validate_claim(farm_root, work_item_id, out)
            if (farm_root / "state/FACTORY_OFF.flag").exists():
                raise ValueError("factory became administratively OFF before launch")
            if boot._exact_process_for_path(boot.scan_terminal_processes(), terminal):
                raise ValueError("T1 ceased being idle before launch")
            started = dt.datetime.now(dt.timezone.utc)
            process = subprocess.Popen(
                [str(terminal), "/portable", f"/config:{ini}"],
                cwd=ROOT,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            result["launched_pid"] = process.pid
            result["startup_ini"] = boot.file_binding(ini)
            deadline = time.monotonic() + int(timeout)
            while time.monotonic() < deadline:
                matches = [
                    value
                    for row in boot.scan_terminal_processes()
                    if (value := _owned_match(row, ini, started))
                ]
                if matches:
                    if len(matches) != 1:
                        raise ValueError("owned T1 M1 export config/path is not unique")
                    identity = matches[0]
                if (
                    process.poll() is not None
                    and identity is None
                    and dt.datetime.now(dt.timezone.utc) - started
                    > dt.timedelta(seconds=20)
                ):
                    raise ValueError("owned M1 export terminal exited before identity binding")
                if marker.is_file() and identity is not None:
                    result["completion"] = marker.read_text(
                        encoding="utf-8-sig"
                    ).strip()
                    break
                time.sleep(1)
            else:
                raise TimeoutError("DWX M1 overlap export timed out")
    except Exception as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        if identity is not None and ini is not None:
            try:
                result["termination"] = _terminate_owned(identity, ini)
                result["terminated_owned_pid"] = identity["pid"]
            except Exception as exc:
                result["cleanup_error"] = f"{type(exc).__name__}: {exc}"
        result["process_identity"] = identity
        try:
            post_audit = governance_guard._compact_isolation_audit(farm_root)
            post_snapshot = governance_guard._signed_archive_snapshot(
                Path(post_audit["manifest_path"])
            )
            result["custom_history_post_audit"] = post_audit
            result["signed_archive_after"] = post_snapshot
            result["signed_archive_unchanged"] = bool(
                pre_snapshot is not None and pre_snapshot == post_snapshot
            )
        except Exception as exc:
            result["post_audit_error"] = f"{type(exc).__name__}: {exc}"
            result["signed_archive_unchanged"] = False

        if raw_terminal_dir is not None and raw_terminal_dir.is_dir():
            try:
                result["m1_export_manifest"] = canonicalize_export_set(
                    raw_terminal_dir, out
                )
                manifest_binding = result["m1_export_manifest"]
                for key in (
                    "canonicalization_status",
                    "attempted_symbol_count",
                    "successful_symbol_count",
                    "failed_symbol_count",
                    "failed_symbols",
                    "short_read_symbols",
                    "short_read_symbol_count",
                ):
                    result[key] = manifest_binding[key]
            except Exception as exc:
                result["output_error"] = f"{type(exc).__name__}: {exc}"

        result["completed_at_utc"] = boot.utc_now()
        manifest_binding = result.get("m1_export_manifest") or {}
        result["status"] = _compute_receipt_status(result, manifest_binding)
        receipt_path = out / "export_receipt.json"
        _atomic_write_json(receipt_path, result)
        summary = {
            "schema_version": dwx_m1_overlap_export_work_item.SUMMARY_SCHEMA,
            "run_tag": dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S"),
            "export_stamp": out.name,
            "status": result["status"],
            "verdict": (
                "REVIEW_REQUIRED" if result["status"] == "PASS" else "INFRA_FAIL"
            ),
            "no_gate_verdict": True,
            "work_item_id": work_item_id,
            "terminal": "T1",
            "export_receipt_path": str(receipt_path),
            "export_receipt_sha256": sha256_file(receipt_path),
            "m1_export_manifest": result.get("m1_export_manifest"),
            "canonicalization_status": result.get("canonicalization_status"),
            "attempted_symbol_count": result.get("attempted_symbol_count", 0),
            "successful_symbol_count": result.get("successful_symbol_count", 0),
            "failed_symbol_count": result.get("failed_symbol_count", 0),
            "failed_symbols": result.get("failed_symbols", []),
            "short_read_symbol_count": result.get("short_read_symbol_count", 0),
            "short_read_symbols": result.get("short_read_symbols", []),
            "signed_archive_unchanged": result.get(
                "signed_archive_unchanged", False
            ),
            "completed_at_utc": result["completed_at_utc"],
            "error": _summary_error_text(result),
        }
        _atomic_write_json(summary_path, summary)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--work-item-id", required=True)
    parser.add_argument("--farm-root", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=3600)
    args = parser.parse_args(argv)
    result = run(
        args.out,
        args.summary,
        args.work_item_id,
        args.farm_root,
        timeout=args.timeout,
    )
    print(
        json.dumps(
            {
                "status": result["status"],
                "receipt": str(Path(args.out) / "export_receipt.json"),
                "m1_export_manifest": (
                    result.get("m1_export_manifest") or {}
                ).get("path"),
            },
            sort_keys=True,
        )
    )
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
