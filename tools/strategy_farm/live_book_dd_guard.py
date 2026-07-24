"""Live book max-drawdown guard — the missing KS_PORTFOLIO_DD feeder (ESC-01).

Audit 2026-07-24 finding: every live sleeve runs KS_PORTFOLIO_DD in
existence-trip mode (halt_pct=0.0 => the mere existence of the signal file
halts the EA, QM_KillSwitch.mqh:435-436), but NOTHING ever wrote the signal
file — the max-DD kill was dead in practice. This guard is the producer:

  read book equity from live_book_pulse.json (EQUITY_SNAPSHOT-based)
  -> maintain a persisted high-water mark
  -> on drawdown >= threshold write portfolio_dd.signal to the paths the
     deployed post-fix binaries poll (T_Live sandbox QM\\halt + FILE_COMMON).

Design constraints (Hard Rules):
- This script NEVER touches AutoTrading, never starts terminals, and writes
  under C:\\QM\\mt5\\T_Live ONLY the single signal file on breach — that write
  IS the safety feature (the EAs flatten + halt themselves on seeing it).
- The signal is never cleared automatically. Clearing a breach is an OWNER
  decision: delete the signal files and reset the state JSON (see --help).
- Fails safe on stale input: if the pulse snapshot is older than
  --max-pulse-age-min the guard logs itself BLIND instead of acting on stale
  equity (a stale pulse must not mask a live drawdown — the alarm line makes
  the blindness visible in health surfaces).

Threshold: --halt-dd-pct / env QM_BOOK_DD_HALT_PCT, default 10.0 (Edge-Lab
charter total-DD bound). OWNER may retune; recorded in
decisions/2026-07-24_live_book_dd_guard.md.

Cadence: scheduled task QM_StrategyFarm_LiveBookDDGuard (5 min). Equity
granularity is bounded by the pulse cadence (30 min) — this is a book-level
backstop behind the per-EA 3% daily-loss kill, not a tick-level stop.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

PULSE_JSON = Path(r"D:\QM\reports\state\live_book_pulse.json")
PULSE_APPEND_LOG = Path(r"D:\QM\reports\state\live_book_pulse.log")
STATE_JSON = Path(r"D:\QM\reports\state\live_book_dd_guard_state.json")
GUARD_LOG = Path(r"D:\QM\reports\state\live_book_dd_guard.log")
ALARM_LOG = Path(r"D:\QM\strategy_farm\state\health_alarms.log")
# Paths polled by the deployed post-fix binaries (QM_KillSwitch.mqh:486-496:
# sandbox-relative default + FILE_COMMON fallback). The sandbox halt dir is the
# live channel (it already carries the ks_state_*.state files).
SIGNAL_TARGETS = (
    Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\halt\portfolio_dd.signal"),
    Path(os.environ.get("APPDATA", r"C:\Users\Administrator\AppData\Roaming"))
    / "MetaQuotes" / "Terminal" / "Common" / "Files" / "QM" / "halt" / "portfolio_dd.signal",
)
DEFAULT_HALT_DD_PCT = float(os.environ.get("QM_BOOK_DD_HALT_PCT", "10.0"))
STARTING_CAPITAL_FLOOR = 100000.0  # DXZ book inception equity; HWM never below this


def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def _log(msg: str) -> None:
    GUARD_LOG.parent.mkdir(parents=True, exist_ok=True)
    with GUARD_LOG.open("a", encoding="utf-8") as fh:
        fh.write(f"{_now_utc().replace(microsecond=0).isoformat()} {msg}\n")


def _alarm(severity: str, detail: str) -> None:
    try:
        ALARM_LOG.parent.mkdir(parents=True, exist_ok=True)
        with ALARM_LOG.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps({
                "ts_utc": _now_utc().replace(microsecond=0).isoformat(),
                "source": "live_book_dd_guard",
                "severity": severity,
                "detail": detail,
            }) + "\n")
    except OSError:
        pass


def _read_pulse() -> tuple[float | None, dt.datetime | None, str]:
    try:
        payload = json.loads(PULSE_JSON.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, None, f"pulse_unreadable:{exc!r}"
    equity = None
    try:
        equity = float(payload["ea_logs"]["book_equity"]["equity"])
    except (KeyError, TypeError, ValueError):
        return None, None, "pulse_missing_book_equity"
    generated = None
    raw = str(payload.get("generated_at_utc") or "")
    try:
        generated = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if generated.tzinfo is None:
            generated = generated.replace(tzinfo=dt.UTC)
    except ValueError:
        pass
    return equity, generated, ""


QM_LOG_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM")
_EQUITY_RE = None  # compiled lazily


def _seed_hwm(current_equity: float) -> float:
    """One-time historical HWM seed from EQUITY_SNAPSHOT events in the T_Live
    QM event logs (account-scope equity; READ-ONLY scan), floored at inception
    capital and current equity. The pulse append log carries no equity history."""
    global _EQUITY_RE
    import re
    if _EQUITY_RE is None:
        _EQUITY_RE = re.compile(r'"equity"\s*:\s*([0-9]+(?:\.[0-9]+)?)')
    hwm = max(STARTING_CAPITAL_FLOOR, current_equity)
    try:
        log_files = sorted(QM_LOG_DIR.glob("QM5_*_ea-*.log"))
    except OSError:
        return hwm
    for path in log_files:
        text = ""
        for enc in ("utf-16", "utf-8-sig", "utf-8", "cp1252"):
            try:
                text = path.read_text(encoding=enc)
                break
            except (OSError, UnicodeError):
                continue
        for line in text.splitlines():
            if "EQUITY_SNAPSHOT" not in line:
                continue
            m = _EQUITY_RE.search(line)
            if m:
                try:
                    hwm = max(hwm, float(m.group(1)))
                except ValueError:
                    continue
    return hwm


def _load_state() -> dict:
    try:
        return json.loads(STATE_JSON.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _save_state(state: dict) -> None:
    STATE_JSON.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_JSON.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=1, sort_keys=True), encoding="utf-8")
    tmp.replace(STATE_JSON)


def _write_signals(payload: dict, dry_run: bool) -> list[str]:
    written: list[str] = []
    body = json.dumps(payload, indent=1, sort_keys=True)
    for target in SIGNAL_TARGETS:
        if dry_run:
            written.append(f"DRY_RUN:{target}")
            continue
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(body, encoding="utf-8")
            written.append(str(target))
        except OSError as exc:
            _alarm("CRITICAL", f"dd_guard_signal_write_failed:{target}:{exc!r}")
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--halt-dd-pct", type=float, default=DEFAULT_HALT_DD_PCT)
    parser.add_argument("--max-pulse-age-min", type=float, default=120.0)
    parser.add_argument("--dry-run", action="store_true",
                        help="Compute and log; never write signal files.")
    parser.add_argument("--status", action="store_true", help="Print state and exit.")
    args = parser.parse_args()

    state = _load_state()
    if args.status:
        print(json.dumps(state, indent=1, sort_keys=True))
        return 0

    equity, generated, err = _read_pulse()
    if equity is None:
        _log(f"BLIND pulse_error={err}")
        _alarm("WARN", f"dd_guard_blind:{err}")
        return 0
    age_min = None
    if generated is not None:
        age_min = (_now_utc() - generated).total_seconds() / 60.0
        if age_min > args.max_pulse_age_min:
            _log(f"BLIND stale_pulse age_min={age_min:.1f} equity={equity:.2f}")
            _alarm("WARN", f"dd_guard_blind_stale_pulse:age_min={age_min:.1f}")
            return 0

    hwm = float(state.get("hwm_equity") or 0.0)
    if hwm <= 0.0:
        hwm = _seed_hwm(equity)
        _log(f"HWM_SEEDED hwm={hwm:.2f} (qm-log EQUITY_SNAPSHOT scan, floor {STARTING_CAPITAL_FLOOR:.0f})")
    hwm = max(hwm, equity)
    dd_pct = 0.0 if hwm <= 0 else (hwm - equity) / hwm * 100.0
    breached_now = dd_pct >= args.halt_dd_pct
    previously_breached = bool(state.get("breached"))

    if breached_now or previously_breached:
        payload = {
            "source": "live_book_dd_guard",
            "reason": "book_max_drawdown_halt" if breached_now else "breach_latched",
            "dd_pct": round(dd_pct, 4),
            "halt_dd_pct": args.halt_dd_pct,
            "hwm_equity": round(hwm, 2),
            "equity": round(equity, 2),
            "ts_utc": _now_utc().replace(microsecond=0).isoformat(),
        }
        written = _write_signals(payload, args.dry_run)
        if breached_now and not previously_breached:
            _alarm("CRITICAL",
                   f"BOOK_DD_HALT dd={dd_pct:.2f}% >= {args.halt_dd_pct:.2f}% "
                   f"equity={equity:.2f} hwm={hwm:.2f} signals={written}")
        _log(f"BREACH dd={dd_pct:.4f}% equity={equity:.2f} hwm={hwm:.2f} signals={written}")
    else:
        _log(f"OK dd={dd_pct:.4f}% equity={equity:.2f} hwm={hwm:.2f} "
             f"threshold={args.halt_dd_pct:.2f}% pulse_age_min={-1 if age_min is None else round(age_min, 1)}")

    state.update({
        "hwm_equity": round(hwm, 2),
        "last_equity": round(equity, 2),
        "last_dd_pct": round(dd_pct, 4),
        "halt_dd_pct": args.halt_dd_pct,
        "breached": bool(breached_now or previously_breached),
        "last_run_utc": _now_utc().replace(microsecond=0).isoformat(),
    })
    if not args.dry_run:
        _save_state(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
