"""dwx_hourly_check.py — runs once per hour via Windows Task Scheduler.

Idempotent. Each invocation does whatever is currently possible:

  Phase A — WAIT FOR WS30
      Sentinel: ``WS30_GMT+2_US-DST.csv`` and ``..._M1.csv`` must exist
      in the staging folder, both with mtime >= STABILITY_MIN minutes
      ago (TDM creates the file first then fills it for up to 30 min;
      we treat 'no writes for 30 min' as the all-downloaded signal).
      If WS30 not stable, log status and exit. Cron will retry next hour.

  Phase B — STAGE EVERYTHING
      Once WS30 is confirmed stable, list every other CSV pair in the
      staging folder, drop the ones already in MT5 / queued / done /
      not-yet-stable, and stage the rest by invoking prepare_import.py.

  Phase C — VERIFY + READINESS
      If MQL5\\Files\\imports\\ has no pending sidecars and the service
      heartbeat is fresh, run verify_import.py and write
      ``D:\\QM\\reports\\setup\\T1_READINESS_REPORT.md`` summarising
      every imported symbol's status. Once that report shows
      ``OVERALL=READY`` we don't need to run again.

All status output goes to ``D:\\QM\\mt5\\T1\\dwx_import\\logs\\hourly_<date>.log``.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

import MetaTrader5 as mt5

T1_TERMINAL = r"D:\QM\mt5\T1\terminal64.exe"
STAGING = Path(r"D:\QM\reports\setup\tick-data-timezone")
IMPORTS = Path(r"D:\QM\mt5\T1\MQL5\Files\imports")
DONE = IMPORTS / "done"
HEARTBEAT = IMPORTS / "service_heartbeat.txt"
LOGS = Path(r"D:\QM\mt5\T1\dwx_import\logs")
PREPARE_SCRIPT = Path(r"D:\QM\mt5\T1\dwx_import\prepare_import.py")
VERIFY_SCRIPT = Path(r"D:\QM\mt5\T1\dwx_import\verify_import.py")
READINESS = Path(r"D:\QM\reports\setup\T1_READINESS_REPORT.md")
DESKTOP_NUDGE = Path(r"C:\Users\Administrator\Desktop\SERVICE_NOT_RUNNING.txt")

WS30_TICK = "WS30_GMT+2_US-DST.csv"
WS30_M1 = "WS30_GMT+2_US-DST_M1.csv"

STABILITY_MIN = 30      # mtime must be at least this many minutes old
SERVICE_STALE_MIN = 60  # heartbeat older than this = service considered stalled
                        # service writes heartbeat at end of each PollOnce, which
                        # can take 20+ min when several big jobs are queued, so
                        # this needs to be generous to avoid false "service down" alerts

CSV_PATTERN = re.compile(
    r"^(?P<symbol>.+?)_GMT[+\-]\d+_(?:US|EU)-DST\.csv$",
    re.IGNORECASE,
)

# TDS sometimes exports a symbol under a name that differs from the broker's.
# Map CSV-root -> broker source symbol to use when cloning.
# Target name still follows the CSV root + ".DWX" convention.
SOURCE_OVERRIDES = {
    "GDAXIm": "GDAXI",   # broker has Indices\Index DAX\GDAXI (Germany 40)
    "NDXm":   "NDX",     # broker has Indices\Index 3\NDX     (US Tech 100)
}

PYTHON = sys.executable


def now_iso() -> str:
    return dt.datetime.now().isoformat(timespec="seconds")


def open_log() -> Path:
    LOGS.mkdir(parents=True, exist_ok=True)
    return LOGS / f"hourly_{dt.date.today().isoformat()}.log"


def log(msg: str, fp=None) -> None:
    line = f"[{now_iso()}] {msg}"
    print(line)
    if fp is not None:
        fp.write(line + "\n"); fp.flush()


def is_stable(p: Path, now: float) -> tuple[bool, str]:
    if not p.exists():
        return False, "missing"
    age_min = (now - p.stat().st_mtime) / 60
    if age_min < STABILITY_MIN:
        return False, f"too fresh ({age_min:.1f} min < {STABILITY_MIN} min)"
    if p.stat().st_size == 0:
        return False, "zero-byte"
    return True, f"stable ({age_min:.0f} min old)"


def find_csv_pairs() -> list[tuple[str, Path, Path]]:
    """Return list of (symbol_root, tick_csv, m1_csv) tuples found in staging."""
    pairs = []
    for p in sorted(STAGING.glob("*.csv")):
        m = CSV_PATTERN.match(p.name)
        if not m:
            continue
        m1 = p.with_name(p.stem + "_M1.csv")
        if not m1.exists():
            continue
        pairs.append((m.group("symbol"), p, m1))
    return pairs


def heartbeat_age_min() -> float | None:
    if not HEARTBEAT.exists():
        return None
    return (time.time() - HEARTBEAT.stat().st_mtime) / 60


def already_imported(target: str) -> bool:
    si = mt5.symbol_info(target)
    return si is not None


def already_queued(target: str) -> bool:
    return (IMPORTS / f"{target}.import.txt").exists()


def already_done(target: str) -> bool:
    if not DONE.exists():
        return False
    for p in DONE.glob("*.import.txt"):
        if p.name.endswith(f"_{target}.import.txt"):
            return True
        if target in p.name:
            return True
    return False

def source_symbol_ready(source: str) -> tuple[bool, str]:
    """Pre-flight source symbol contract specs before expensive CSV conversion."""
    si = mt5.symbol_info(source)
    if si is None:
        return False, "source symbol missing in MT5"
    tv = float(si.trade_tick_value or 0.0)
    if tv <= 0:
        return False, f"tick_value={tv} (must be > 0)"
    if not si.currency_base or not si.currency_profit:
        return False, "currency_base/currency_profit missing"
    return True, "ok"


def stage_one(tick_csv: Path, fp, source_override: str | None = None) -> tuple[bool, str]:
    """Run prepare_import.py for one CSV pair. Return (ok, message)."""
    cmd = [PYTHON, str(PREPARE_SCRIPT), str(tick_csv)]
    if source_override:
        cmd.extend(["--source", source_override])
        log(f"  staging {tick_csv.name} (source override: {source_override}) ...", fp)
    else:
        log(f"  staging {tick_csv.name} ...", fp)
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=4 * 3600)
    except subprocess.TimeoutExpired:
        return False, "prepare_import.py timed out (>4h)"
    out = (proc.stdout or "") + (proc.stderr or "")
    for line in out.splitlines()[-12:]:
        log(f"    | {line}", fp)
    return proc.returncode == 0, f"exit={proc.returncode}"


def write_readiness_report(fp) -> bool:
    """Write the readiness report. Return True if T1 looks fully ready."""
    if not mt5.initialize(path=T1_TERMINAL, portable=True):
        log(f"  ERROR: mt5.initialize failed: {mt5.last_error()}", fp)
        return False
    try:
        # collect every .DWX custom symbol in MT5
        dwx_symbols = []
        for s in mt5.symbols_get() or []:
            if s.custom and s.name.endswith(".DWX"):
                dwx_symbols.append(s)

        # collect expected symbols from the staging CSVs
        expected = []
        for p in sorted(STAGING.glob("*_GMT+*_US-DST.csv")):
            m = CSV_PATTERN.match(p.name)
            if m and not p.name.endswith("_M1.csv"):
                expected.append(m.group("symbol") + ".DWX")

        # cross-check
        in_mt5 = {s.name for s in dwx_symbols}
        missing = sorted(set(expected) - in_mt5)
        unexpected = sorted(in_mt5 - set(expected))

        # service health
        hb_age = heartbeat_age_min()
        hb_status = (
            f"{hb_age:.1f} min old" if hb_age is not None
            else "missing -- service may not be running"
        )
        service_ok = hb_age is not None and hb_age <= SERVICE_STALE_MIN

        # queue health
        pending = sorted(IMPORTS.glob("*.import.txt"))

        # tester groups file present?
        groups_file = Path(r"D:\QM\mt5\T1\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt")
        groups_ok = groups_file.exists() and groups_file.stat().st_size > 1000

        spec_bad = []
        for s in dwx_symbols:
            si = mt5.symbol_info(s.name)
            if si is None:
                spec_bad.append(s.name)
                continue
            tv = float(si.trade_tick_value or 0.0)
            tvp = float(si.trade_tick_value_profit or 0.0)
            tvl = float(si.trade_tick_value_loss or 0.0)
            spec_ok = (
                tv > 0
                and tvp > 0
                and tvl > 0
                and tvp == tv
                and tvl == tv
                and si.currency_base != ""
                and si.currency_profit != ""
            )
            if not spec_ok:
                spec_bad.append(s.name)

        ready = (
            not missing
            and not pending
            and groups_ok
            and service_ok
            and not spec_bad
        )
        verdict = "READY" if ready else "NOT_READY"

        lines = []
        lines.append(f"# T1 Readiness Report\n")
        lines.append(f"Generated: {now_iso()}")
        if pending and not service_ok:
            lines.append("> **ACTION REQUIRED:** drag `Import_DWX_Queue_Service` onto the Services pane in T1 (Navigator → Services) and click Start. Once.")
        lines.append(f"OVERALL={verdict}\n")
        lines.append(f"## Symbols\n")
        lines.append(f"- expected: {len(expected)}")
        lines.append(f"- in MT5  : {len(in_mt5)}")
        if missing:
            lines.append(f"- MISSING : {missing}")
        if spec_bad:
            lines.append(f"- BAD_SPEC: {spec_bad}")
        if unexpected:
            lines.append(f"- unexpected (in MT5 but no CSV): {unexpected}\n")
        lines.append("\n## Per-symbol detail\n")
        lines.append("| symbol | path | spec_ok | tick_value | tvp | tvl |")
        lines.append("|---|---|---|---|---|---|")
        for s in dwx_symbols:
            si = mt5.symbol_info(s.name)
            tv = si.trade_tick_value
            tvp = si.trade_tick_value_profit
            tvl = si.trade_tick_value_loss
            spec_ok = (tvp > 0 and tvl > 0 and tvp == tv and tvl == tv
                       and si.currency_base != "" and si.currency_profit != "")
            lines.append(f"| {s.name} | {s.path} | {'OK' if spec_ok else 'BAD'} "
                         f"| {tv} | {tvp} | {tvl} |")
        lines.append(f"\n## Queue\n")
        lines.append(f"- pending sidecars in imports\\: {len(pending)}")
        if pending:
            for p in pending:
                lines.append(f"  - {p.name}")
        lines.append(f"\n## Service heartbeat\n")
        lines.append(f"- {hb_status}  ({'OK' if service_ok else 'STALE OR MISSING'})")
        lines.append(f"\n## Tester commission file\n")
        lines.append(f"- {groups_file}")
        lines.append(f"- size = {groups_file.stat().st_size if groups_file.exists() else 0} bytes  ({'OK' if groups_ok else 'MISSING/EMPTY'})")
        lines.append(f"\n## Verdict\n")
        if ready:
            lines.append("All `.DWX` symbols present, no pending jobs, commission file populated. **T1 is ready for backtesting.**")
        else:
            reasons = []
            if missing:    reasons.append(f"missing symbols: {missing}")
            if pending:    reasons.append(f"{len(pending)} job(s) still in queue")
            if spec_bad:   reasons.append(f"bad symbol spec(s): {spec_bad}")
            if not groups_ok: reasons.append("commission file missing or empty")
            if not service_ok: reasons.append(f"service heartbeat: {hb_status}")
            lines.append(f"NOT READY -- " + "; ".join(reasons))

        READINESS.parent.mkdir(parents=True, exist_ok=True)
        READINESS.write_text("\n".join(lines), encoding="utf-8")
        log(f"  readiness report -> {READINESS}  verdict={verdict}", fp)
        return ready
    finally:
        mt5.shutdown()


def main() -> int:
    log_path = open_log()
    fp = log_path.open("a", encoding="utf-8")
    try:
        log("=" * 70, fp)
        log("hourly check start", fp)
        now = time.time()

        # Phase A: WS30 stability gate
        ws30_tick = STAGING / WS30_TICK
        ws30_m1 = STAGING / WS30_M1
        ok_t, why_t = is_stable(ws30_tick, now)
        ok_m, why_m = is_stable(ws30_m1, now)
        log(f"WS30 tick CSV: {why_t}", fp)
        log(f"WS30 m1   CSV: {why_m}", fp)
        if not (ok_t and ok_m):
            log("Phase A: WS30 not stable yet -- exiting, will retry next hour.", fp)
            return 0
        log("Phase A: WS30 stable -- proceeding to Phase B (stage everything).", fp)

        # Phase B: stage every pair that is stable, not already imported,
        # and not already queued/done. Always need a fresh MT5 query for "imported".
        pairs = find_csv_pairs()
        log(f"Phase B: {len(pairs)} CSV pair(s) found in staging.", fp)
        if not mt5.initialize(path=T1_TERMINAL, portable=True):
            log(f"  ERROR: mt5.initialize failed: {mt5.last_error()}", fp); return 3
        try:
            staged = 0
            skipped = 0
            for root, tick, m1 in pairs:
                target = root + ".DWX"
                if already_imported(target):
                    log(f"  skip {root}: already in MT5 as {target}", fp); skipped += 1; continue
                if already_queued(target):
                    log(f"  skip {root}: already queued (sidecar present)", fp); skipped += 1; continue
                if already_done(target):
                    log(f"  skip {root}: already in done\\", fp); skipped += 1; continue
                ok_t, why_t = is_stable(tick, now)
                ok_m, why_m = is_stable(m1, now)
                if not (ok_t and ok_m):
                    log(f"  defer {root}: tick={why_t} m1={why_m}", fp); continue
                source = SOURCE_OVERRIDES.get(root) or root
                src_ok, src_why = source_symbol_ready(source)
                if not src_ok:
                    log(f"  defer {root}: source pre-flight failed ({src_why})", fp)
                    continue
                # ok to stage
                source_override = SOURCE_OVERRIDES.get(root)
                ok, msg = stage_one(tick, fp, source_override=source_override)
                if ok:
                    staged += 1
                    log(f"  staged {root} ({msg})", fp)
                else:
                    log(f"  FAILED to stage {root}: {msg}", fp)
            log(f"Phase B done: {staged} staged, {skipped} skipped, "
                f"{len(pairs) - staged - skipped} deferred.", fp)
        finally:
            mt5.shutdown()

        # Phase C: verify + readiness
        pending = list(IMPORTS.glob("*.import.txt"))
        hb_age = heartbeat_age_min()
        log(f"Phase C: pending={len(pending)} heartbeat_age_min={hb_age}", fp)

        # If we have pending work but the service isn't draining it,
        # nudge OWNER on the desktop. Self-clear when service comes back.
        service_alive = hb_age is not None and hb_age <= SERVICE_STALE_MIN
        if pending and not service_alive:
            DESKTOP_NUDGE.write_text(
                "ACTION REQUIRED — DWX import is queued but the MT5 Service is not running.\n\n"
                "Open T1 (the desktop shortcut 'T1 MT5 (portable)'), then:\n"
                "  Navigator (Ctrl+N) -> Services -> drag Import_DWX_Queue_Service onto the Services pane\n"
                "  -> right-click -> Start.  The service icon should turn green.\n\n"
                "After this one-time action the service auto-resumes on every terminal restart.\n"
                f"Pending jobs in imports\\: {len(pending)}\n"
                f"Last heartbeat: {'never' if hb_age is None else f'{hb_age:.1f} min ago'}\n"
                f"Generated by dwx_hourly_check.py at {now_iso()}\n",
                encoding="utf-8")
            log(f"  wrote desktop nudge to {DESKTOP_NUDGE}", fp)
        elif DESKTOP_NUDGE.exists() and service_alive:
            DESKTOP_NUDGE.unlink()
            log("  service is alive -- removed desktop nudge.", fp)

        if pending:
            log("  service still has jobs to drain -- skip readiness this hour.", fp)
            return 0
        if hb_age is None:
            log("  no service heartbeat yet -- service may not have been started by OWNER.", fp)
        elif hb_age > SERVICE_STALE_MIN:
            log(f"  service heartbeat stale ({hb_age:.1f} min) -- service may be down.", fp)

        # run verify_import.py
        try:
            proc = subprocess.run(
                [PYTHON, str(VERIFY_SCRIPT)],
                capture_output=True, text=True, timeout=600,
            )
            for line in (proc.stdout + proc.stderr).splitlines()[-30:]:
                log(f"  verify | {line}", fp)
        except Exception as e:
            log(f"  verify FAILED to run: {e}", fp)

        ready = write_readiness_report(fp)
        log(f"hourly check end (ready={ready})", fp)
        return 0 if ready else 0  # always return 0; failing loud only on programmer errors
    finally:
        fp.close()


if __name__ == "__main__":
    raise SystemExit(main())


