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
COLD_CACHE_SIGNATURES = (
    "BARS_ZERO",
    "M0_1970_PERIOD",
    "NO_HISTORY",
    "INCOMPLETE_RUNS",
    "EMPTY_EXPERT",
    "EMPTY_SYMBOL",
    "RUN_STATUS_INVALID",
    "HISTORY_CONTEXT_INVALID",
)
_NON_RETRYABLE_RUN_SMOKE_REASONS = {
    "ACCOUNT_NOT_SPECIFIED",
    "EXECUTION_IDENTITY_DRIFT",
    "LOG_BOMB",
    "MIN_TRADES_NOT_MET",
    "NON_DETERMINISTIC",
    "ONINIT_FAILED",
    "SETUP_DATA_MISSING",
    "TIMEOUT",
}
_RUN_SMOKE_SUMMARY_RE = re.compile(r"(?im)^\s*run_smoke\.summary=(.+?)\s*$")
_HISTORY_SYNC_RE = re.compile(
    r"(?im)(?<![A-Z0-9_.#-])[A-Z0-9_.#-]+\s*:\s*history synchronization error\b"
)


def is_launch_fault_exit_code(returncode: int | None) -> bool:
    return returncode in LAUNCH_FAULT_EXIT_CODES


def _format_exit_code(returncode: int | None) -> str:
    if returncode is None:
        return "None"
    if returncode < 0:
        return str(returncode)
    return f"0x{returncode:08X}"


def _as_text(value: Any) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value or "")


def _sink_snapshot(sink: Any) -> tuple[str, Any] | None:
    """Record enough state to read only the next child's additions to a log."""
    if not hasattr(sink, "write"):
        return None
    try:
        if hasattr(sink, "getvalue"):
            return ("memory", len(_as_text(sink.getvalue())))
        sink.flush()
        name = getattr(sink, "name", None)
        if name and Path(name).is_file():
            return ("file", (Path(name), Path(name).stat().st_size))
    except (OSError, ValueError):
        pass
    return None


def _sink_text_since(sink: Any, snapshot: tuple[str, Any] | None) -> str:
    if snapshot is None:
        return ""
    kind, state = snapshot
    try:
        if kind == "memory":
            return _as_text(sink.getvalue())[int(state):]
        path, offset = state
        sink.flush()
        with Path(path).open("rb") as handle:
            handle.seek(int(offset))
            return handle.read().decode("utf-8", errors="replace")
    except (OSError, ValueError):
        return ""
    return ""


def _reason_tokens(value: Any) -> set[str]:
    if isinstance(value, str):
        values = re.split(r"[,;|\s]+", value)
    elif isinstance(value, (list, tuple, set)):
        values = value
    else:
        values = []
    return {str(item).strip().upper() for item in values if str(item).strip()}


def _cold_signature_in_tokens(tokens: set[str]) -> str | None:
    for signature in COLD_CACHE_SIGNATURES:
        if signature in tokens:
            return signature
        if signature == "NO_HISTORY" and "NO_HISTORY_LOG" in tokens:
            return signature
    return None


def _cold_signature_from_summary(summary: dict[str, Any]) -> str | None:
    """Classify an authoritative run_smoke summary without retrying real FAILs.

    run_smoke may retain invalid warm-up attempts in ``runs`` even after it gets
    a valid report. Once any run is status OK, its non-zero exit is a completed
    strategy/test contract failure (for example MIN_TRADES_NOT_MET), not a
    cold-cache launch, so nested warm-up markers must not trigger this wrapper.
    """
    if str(summary.get("result") or "").strip().upper() == "PASS":
        return None
    reasons = _reason_tokens(summary.get("reason_classes"))
    if reasons & _NON_RETRYABLE_RUN_SMOKE_REASONS:
        return None
    runs = summary.get("runs")
    run_rows = [row for row in runs if isinstance(row, dict)] if isinstance(runs, list) else []
    if any(str(row.get("status") or "").strip().upper() == "OK" for row in run_rows):
        return None
    signature = _cold_signature_in_tokens(reasons)
    if signature:
        return signature
    nested_tokens: set[str] = set()
    for row in run_rows:
        nested_tokens.update(_reason_tokens(row.get("failure")))
        nested_tokens.update(_reason_tokens(row.get("failure_hints")))
        nested_tokens.update(_reason_tokens(row.get("invalid_report_reasons")))
    signature = _cold_signature_in_tokens(nested_tokens)
    if signature:
        return signature
    if any(str(row.get("status") or "").strip().upper() == "INVALID" for row in run_rows):
        return "RUN_STATUS_INVALID"
    return None


def cold_cache_summary_signature(summary: dict[str, Any]) -> str | None:
    """Public structured-summary classifier for detached Q02/Q03 workers."""
    return _cold_signature_from_summary(summary)


def _marked_summary_signature(text: str) -> tuple[bool, str | None]:
    """Return whether a readable marker existed and its authoritative class."""
    matches = list(_RUN_SMOKE_SUMMARY_RE.finditer(text))
    for match in reversed(matches):
        raw_path = match.group(1).strip().strip("\"'")
        try:
            path = Path(raw_path)
            if not path.is_file() or path.stat().st_size > 16 * 1024 * 1024:
                continue
            data = json.loads(path.read_text(encoding="utf-8-sig"))
            if isinstance(data, dict):
                return True, _cold_signature_from_summary(data)
        except (OSError, UnicodeError, json.JSONDecodeError):
            continue
    return False, None


def cold_cache_retry_signature(text: str) -> str | None:
    """Return the cold-cache signature in one failed attempt, if any.

    A readable run_smoke summary is authoritative. This prevents an invalid
    warm-up row retained inside a completed strategy FAIL from causing a retry.
    Raw output is used only when no readable summary was emitted.
    """
    summary_found, signature = _marked_summary_signature(text)
    if summary_found:
        return signature
    upper_text = text.upper()
    result_matches = re.findall(r"(?im)^\s*run_smoke\.result=(\S+)", upper_text)
    if result_matches and result_matches[-1] == "PASS":
        return None
    reason_matches = re.findall(r"(?im)^\s*run_smoke\.reason_classes=(.*?)\s*$", upper_text)
    if reason_matches:
        reasons = _reason_tokens(reason_matches[-1])
        if reasons & _NON_RETRYABLE_RUN_SMOKE_REASONS:
            return None
        signature = _cold_signature_in_tokens(reasons)
        if signature:
            return signature
    for signature in COLD_CACHE_SIGNATURES:
        suffix = r"(?:_LOG)?" if signature == "NO_HISTORY" else ""
        pattern = (
            rf"(?<![A-Z0-9_]){re.escape(signature)}{suffix}(?![A-Z0-9_])"
        )
        if re.search(pattern, upper_text):
            return signature
    if _HISTORY_SYNC_RE.search(text):
        return "HISTORY_SYNCHRONIZATION_ERROR"
    return None


def _write_retry_log(sink: Any, message: str) -> None:
    target = sink if hasattr(sink, "write") else sys.stderr
    try:
        target.write(message + "\n")
        target.flush()
    except (AttributeError, OSError, ValueError):
        print(message, file=sys.stderr, flush=True)


def run_with_launch_fault_retry(
    args: list[str],
    *,
    runner=None,
    attempts: int = DEFAULT_LAUNCH_FAULT_ATTEMPTS,
    backoff_sec: float = DEFAULT_LAUNCH_FAULT_BACKOFF_SEC,
    sleep_func=None,
    retry_log=None,
    **kwargs,
) -> subprocess.CompletedProcess:
    """Retry bounded, evidenced launch/cold-cache failures before grading.

    Exit code 0xC0000142 means the child process failed during DLL/process
    initialization. In the farm this can kill pwsh.exe before run_smoke writes
    any summary. A non-zero run_smoke exit is also retryable when its *current
    attempt* carries one of the known cold-cache signatures. Completed strategy
    failures are deliberately not retryable.
    """
    max_attempts = max(1, int(attempts))
    sleeper = time.sleep if sleep_func is None else sleep_func
    run_once = subprocess.run if runner is None else runner
    proc = None
    for attempt in range(1, max_attempts + 1):
        stdout_sink = kwargs.get("stdout")
        sink_snapshot = _sink_snapshot(stdout_sink)
        proc = run_once(args, **kwargs)
        returncode = getattr(proc, "returncode", None)
        matched_signature = None
        if is_launch_fault_exit_code(returncode):
            matched_signature = "0xC0000142"
        elif returncode not in (None, 0):
            attempt_text = "\n".join(
                part
                for part in (
                    _as_text(getattr(proc, "stdout", "")),
                    _as_text(getattr(proc, "stderr", "")),
                    _sink_text_since(stdout_sink, sink_snapshot),
                )
                if part
            )
            matched_signature = cold_cache_retry_signature(attempt_text)
        if matched_signature is None:
            return proc
        log_sink = retry_log if retry_log is not None else stdout_sink
        if attempt >= max_attempts:
            _write_retry_log(
                log_sink,
                "launch_fault_retry "
                f"attempt={attempt}/{max_attempts} "
                f"matched_signature={matched_signature} "
                f"exit_code={_format_exit_code(returncode)} "
                "action=exhausted",
            )
            return proc
        _write_retry_log(
            log_sink,
            "launch_fault_retry "
            f"attempt={attempt}/{max_attempts} "
            f"matched_signature={matched_signature} "
            f"exit_code={_format_exit_code(returncode)} "
            f"backoff_sec={backoff_sec} "
            f"next_attempt={attempt + 1}/{max_attempts}",
        )
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


def full_history_window(
    latest_full_year: int | str | None = None,
    full_history_from: str | None = None,
) -> tuple[str, str, str]:
    """Return run_smoke Year/FromDate/ToDate for full-history phase runners.

    Some custom-symbol cohorts have validated history only through 2024. The
    phase runners still need a valid -Year argument, so cap both -Year and
    -ToDate when an upstream gate records latest_full_year/q04_latest_full_year.
    """
    history_from = str(full_history_from or FULL_HISTORY_FROM).strip() or FULL_HISTORY_FROM
    if not re.fullmatch(r"\d{4}\.\d{2}\.\d{2}", history_from):
        raise ValueError(f"full_history_from must use YYYY.MM.DD, got {history_from!r}")
    if latest_full_year is None or str(latest_full_year).strip() == "":
        return FULL_HISTORY_YEAR, history_from, FULL_HISTORY_TO
    year = int(str(latest_full_year).strip())
    default_year = int(FULL_HISTORY_YEAR)
    if year >= default_year:
        return FULL_HISTORY_YEAR, history_from, FULL_HISTORY_TO
    from_year = int(history_from.split(".", 1)[0])
    if year < from_year:
        raise ValueError(f"latest_full_year {year} predates full-history start {from_year}")
    return str(year), history_from, f"{year}.12.31"

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
