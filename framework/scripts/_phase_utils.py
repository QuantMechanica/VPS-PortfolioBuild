#!/usr/bin/env python3
"""Shared helpers for V5 pipeline phase runners."""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Phase runners are spawned by terminal_worker with stdout/stderr redirected to
# a per-work-item log file; on Windows that handle defaults to cp1252 and a
# single non-ASCII character in a diagnostic print() (e.g. the "->" arrow in
# Q04 fold descriptions) raises UnicodeEncodeError and aborts the runner BEFORE
# it writes summary.json -> summary_missing -> INFRA_FAIL. Every Q-runner
# imports this module, so force UTF-8 here once: a cosmetic log line can never
# kill a gate run again.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

PASS_TOKENS = {"pass", "green", "true", "1", "yes", "auto_pass", "multi_seed_pass", "multi_seed_mixed"}
WINDOWS_DLL_INIT_FAILED = 0xC0000142
WINDOWS_DLL_INIT_FAILED_SIGNED = -1073741502
LAUNCH_FAULT_EXIT_CODES = {WINDOWS_DLL_INIT_FAILED, WINDOWS_DLL_INIT_FAILED_SIGNED}
DEFAULT_LAUNCH_FAULT_ATTEMPTS = 2
DEFAULT_LAUNCH_FAULT_BACKOFF_SEC = 30.0


def is_launch_fault_exit_code(returncode: int | None) -> bool:
    return returncode in LAUNCH_FAULT_EXIT_CODES


def _format_exit_code(returncode: int | None) -> str:
    if returncode is None:
        return "None"
    if returncode < 0:
        return str(returncode)
    return f"0x{returncode:08X}"


def run_with_launch_fault_retry(
    args: list[str],
    *,
    runner=subprocess.run,
    attempts: int = DEFAULT_LAUNCH_FAULT_ATTEMPTS,
    backoff_sec: float = DEFAULT_LAUNCH_FAULT_BACKOFF_SEC,
    sleep_func=None,
    **kwargs,
) -> subprocess.CompletedProcess:
    """Retry transient Windows process launch failures before grading evidence.

    Exit code 0xC0000142 means the child process failed during DLL/process
    initialization. In the farm this can kill pwsh.exe before run_smoke writes
    any summary, producing a misleading summary_missing INFRA_FAIL.
    """
    max_attempts = max(1, int(attempts))
    sleeper = time.sleep if sleep_func is None else sleep_func
    proc = None
    for attempt in range(1, max_attempts + 1):
        proc = runner(args, **kwargs)
        if not is_launch_fault_exit_code(getattr(proc, "returncode", None)):
            return proc
        if attempt >= max_attempts:
            return proc
        stdout = kwargs.get("stdout")
        if hasattr(stdout, "write"):
            stdout.write(
                "launch_fault_retry "
                f"attempt={attempt} "
                f"exit_code={_format_exit_code(getattr(proc, 'returncode', None))} "
                f"backoff_sec={backoff_sec}\n"
            )
            stdout.flush()
        sleeper(backoff_sec)
    return proc


def resolve_ea_expert_path(repo_root: Path, ea_label: str) -> str | None:
    """Canonical MT5 expert path 'QM\\<ea_dir>' for run_smoke / the tester.
    run_smoke deploys framework/EAs/<dir>/<dir>.ex5 to Experts/QM/<dir>.ex5; a bare
    label (e.g. 'QM5_1056') hits deploy_skip -> REPORT_MISSING. Shared by q04-q10."""
    eas = Path(repo_root) / "framework" / "EAs"
    matches = sorted(p for p in eas.glob(f"{ea_label}_*") if p.is_dir())
    if not matches and (eas / ea_label).is_dir():
        matches = [eas / ea_label]
    return f"QM\\{matches[0].name}" if matches else None


def period_from_setfile(setfile, default: str = "H1") -> str:
    """Detect the EA's timeframe from the setfile name, e.g. '..._M15_backtest.set'.
    The Q-rewrite runners hardcoded -Period H1, so M15/D1/etc. EAs traded 0. Shared."""
    m = re.search(r"_(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)_backtest", Path(setfile).name)
    return m.group(1) if m else default


def find_latest_summary(report_root):
    """Most-recent run_smoke summary.json under report_root. run_smoke writes it at
    <report_root>/<eaLabel>/<timestamp>/summary.json, NOT the <ea>/<phase>/<sym> path the
    Q-rewrite stress runners assumed — so rglob for the freshest one instead. Shared."""
    root = Path(report_root)
    if not root.is_dir():
        return None
    cands = sorted(root.rglob("summary.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    return cands[0] if cands else None


# Full available history window for the stress/confirmation gates (Q05/Q06/Q07/Q10).
# run_smoke's -Year is [ValidateRange(2000,2100)] Mandatory, so '-Year 0' (the old
# "full history" sentinel) was REJECTED at param binding -> instant abort. Pass a valid
# year plus explicit FromDate/ToDate (which run_smoke prefers) instead.
FULL_HISTORY_FROM = "2017.01.01"
FULL_HISTORY_TO = "2025.12.31"
FULL_HISTORY_YEAR = "2025"


def full_history_window(latest_full_year: int | str | None = None) -> tuple[str, str, str]:
    """Return run_smoke Year/FromDate/ToDate for full-history phase runners.

    Some custom-symbol cohorts have validated history only through 2024. The
    phase runners still need a valid -Year argument, so cap both -Year and
    -ToDate when an upstream gate records latest_full_year/q04_latest_full_year.
    """
    if latest_full_year is None or str(latest_full_year).strip() == "":
        return FULL_HISTORY_YEAR, FULL_HISTORY_FROM, FULL_HISTORY_TO
    year = int(str(latest_full_year).strip())
    default_year = int(FULL_HISTORY_YEAR)
    if year >= default_year:
        return FULL_HISTORY_YEAR, FULL_HISTORY_FROM, FULL_HISTORY_TO
    from_year = int(FULL_HISTORY_FROM.split(".", 1)[0])
    if year < from_year:
        raise ValueError(f"latest_full_year {year} predates full-history start {from_year}")
    return str(year), FULL_HISTORY_FROM, f"{year}.12.31"

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
    summary_path = out_dir / "summary.json"
    log_path = out_dir / "phase_runner_log.jsonl"
    write_json(result_path, result)
    write_json(summary_path, result)
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
