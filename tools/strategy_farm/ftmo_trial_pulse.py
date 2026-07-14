"""FTMO trial/challenge pulse — read-only health monitor for the FTMO terminal book.

Mirrors the intent of live_book_pulse.py (T_Live) for the FTMO Round25 deployment
(decisions/2026-07-05_ftmo_round25_phase1_deploy.md). Read-only: terminal journal +
QM EA logs only; never touches the terminal.

Checks:
  1. FTMO terminal64 process up (path-anchored to the FTMO install dir).
  2. Today's journal: disconnects / errors.
  3. QM EA logs: all 12 expected magics seen, ERROR-level events.
  4. Latest EQUITY_SNAPSHOT: equity + day_pnl vs FTMO limits
     (daily 5% / total 10% of 100k) with early-warning margins.

Output: D:\\QM\\reports\\state\\ftmo_trial_pulse.json (+ appended .log line).
Scheduled: QM_FTMO_TrialPulse (30 min). Exit 0 = OK/WARN, 1 = ALARM.
"""
from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

DATA_DIR = Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850")
QM_DIR = DATA_DIR / "MQL5" / "Files" / "QM"
STATE_JSON = Path(r"D:\QM\reports\state\ftmo_trial_pulse.json")
STATE_LOG = Path(r"D:\QM\reports\state\ftmo_trial_pulse.log")

BASE_EQUITY = 100_000.0
DAILY_LIMIT_PCT = 5.0     # FTMO daily loss limit
TOTAL_LIMIT_PCT = 10.0    # FTMO max loss limit
DAILY_WARN_PCT = 2.5      # half-budget early warning thresholds
TOTAL_WARN_PCT = 5.0
SERVER_REQUEST_WARN = 1_500
SERVER_REQUEST_LIMIT = 2_000
EQUITY_SNAPSHOT_STALE_MINUTES = 180
DD_FLOOR_PCT = 8.0        # H2 book floor: write book-scoped halt signal (gated by flag)
BOOK_DD_SIGNAL = Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
                      r"\Common\Files\QM\halt\book_ftmo_r25\portfolio_dd.signal")

EXPECTED_MAGICS = {
    114760002, 109110003, 129580000, 106920005, 108480002, 107000003,
    102860036, 104400003, 101630000, 108470001, 129900001, 124750003,
}
SERVER_REQUEST_EVENTS = {"TM_OPEN", "TM_CLOSE", "TM_MODIFY", "TM_REMOVE_PENDING"}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def terminal_running() -> bool:
    try:
        import subprocess
        out = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "@(Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | "
             "Where-Object { $_.ExecutablePath -like 'C:\\Program Files\\FTMO*' }).Count"],
            capture_output=True, text=True, timeout=60,
            creationflags=0x08000000,  # CREATE_NO_WINDOW
        )
        return int((out.stdout or "0").strip() or 0) > 0
    except Exception:
        return False


def journal_issues() -> list[str]:
    issues: list[str] = []
    day = utc_now().astimezone().strftime("%Y%m%d")
    jp = DATA_DIR / "logs" / f"{day}.log"
    if not jp.exists():
        return [f"journal_missing:{jp.name}"]
    txt = jp.read_bytes().decode("utf-16-le", errors="ignore")
    for line in txt.splitlines()[-400:]:
        low = line.lower()
        if "disconnect" in low or "connection lost" in low:
            issues.append("journal:" + line.strip()[-140:])
        elif re.search(r"\berror\b|failed to|cannot", low) and "history" not in low:
            issues.append("journal:" + line.strip()[-140:])
    return issues[-10:]


def scan_ea_logs() -> dict:
    seen_magics: set[int] = set()
    errors: list[str] = []
    latest_snap: dict | None = None
    latest_ts = ""
    day_anchor_magics: set[int] = set()
    book_tag_magics: set[int] = set()
    request_counts: dict[str, int] = {}
    request_event_counts: dict[str, dict[str, int]] = {}
    for lf in QM_DIR.glob("QM5_*.log"):
        try:
            rows = lf.read_text(encoding="utf-8", errors="ignore").splitlines()
        except OSError:
            continue
        for line in rows:
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            m = int(r.get("magic") or 0)
            if m in EXPECTED_MAGICS:
                seen_magics.add(m)
                event = str(r.get("event") or "")
                if event == "KS_DAY_ANCHOR_SET":
                    day_anchor_magics.add(m)
                elif event == "KS_BOOK_TAG_SET":
                    book_tag_magics.add(m)
                if event in SERVER_REQUEST_EVENTS:
                    broker_day = str(r.get("ts_broker") or r.get("ts_utc") or "")[:10]
                    if broker_day:
                        request_counts[broker_day] = request_counts.get(broker_day, 0) + 1
                        by_event = request_event_counts.setdefault(broker_day, {})
                        by_event[event] = by_event.get(event, 0) + 1
            if r.get("level") in ("ERROR", "FATAL"):
                errors.append(f"{lf.name}:{r.get('event')}")
            if r.get("event") == "EQUITY_SNAPSHOT":
                ts = str(r.get("ts_utc") or "")
                if ts > latest_ts:
                    latest_ts = ts
                    latest_snap = r.get("payload") or {}
    latest_request_day = max(request_counts, default=None)
    return {
        "magics_seen": len(seen_magics),
        "magics_missing": sorted(EXPECTED_MAGICS - seen_magics),
        "ea_errors": errors[-10:],
        "equity_snapshot": latest_snap,
        "equity_snapshot_ts": latest_ts or None,
        "kill_switch_day_anchor_magics": len(day_anchor_magics),
        "kill_switch_book_tag_magics": len(book_tag_magics),
        # Lower bound: only framework TradeManager requests are observable in
        # the JSONL logs; terminal/broker-internal requests are not included.
        "server_requests_lower_bound": (
            request_counts.get(latest_request_day, 0) if latest_request_day else 0
        ),
        "server_request_day_broker": latest_request_day,
        "server_request_events": (
            request_event_counts.get(latest_request_day, {}) if latest_request_day else {}
        ),
    }


def snapshot_age_minutes(timestamp: str | None, now: datetime | None = None) -> float | None:
    if not timestamp:
        return None
    try:
        parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    reference = now or utc_now()
    return max(0.0, (reference - parsed.astimezone(timezone.utc)).total_seconds() / 60.0)


def assess_loss_limits(equity: float, day_pnl: float) -> tuple[float, float, list[str], list[str]]:
    total_dd_pct = max(0.0, (BASE_EQUITY - equity) / BASE_EQUITY * 100.0)
    day_loss_pct = max(0.0, -day_pnl / BASE_EQUITY * 100.0)
    alarms: list[str] = []
    warns: list[str] = []
    if total_dd_pct >= TOTAL_LIMIT_PCT:
        alarms.append(f"total_dd_limit_breached:{total_dd_pct:.2f}pct")
    elif total_dd_pct >= TOTAL_WARN_PCT:
        warns.append(f"total_dd_warning:{total_dd_pct:.2f}pct_vs_limit_{TOTAL_LIMIT_PCT}")
    if day_loss_pct >= DAILY_LIMIT_PCT:
        alarms.append(f"daily_loss_limit_breached:{day_loss_pct:.2f}pct")
    elif day_loss_pct >= DAILY_WARN_PCT:
        warns.append(f"daily_loss_warning:{day_loss_pct:.2f}pct_vs_limit_{DAILY_LIMIT_PCT}")
    return total_dd_pct, day_loss_pct, alarms, warns


def main() -> int:
    now = utc_now()
    alarms: list[str] = []
    warns: list[str] = []

    up = terminal_running()
    if not up:
        alarms.append("ftmo_terminal_not_running")

    jrn = journal_issues()
    if jrn:
        warns.extend(jrn)

    eas = scan_ea_logs()
    if eas["magics_missing"]:
        # magics only appear in logs once each EA has logged (post-attach/tick);
        # before first market open this is expected — WARN, not ALARM.
        warns.append(f"magics_missing:{eas['magics_missing']}")

    if eas["ea_errors"]:
        alarms.append(f"ea_errors:{eas['ea_errors']}")

    if eas["kill_switch_day_anchor_magics"] < len(EXPECTED_MAGICS):
        warns.append(
            f"ks_day_anchor_missing:{eas['kill_switch_day_anchor_magics']}/{len(EXPECTED_MAGICS)}"
        )
    if eas["kill_switch_book_tag_magics"] < len(EXPECTED_MAGICS):
        warns.append(
            f"ks_book_tag_missing:{eas['kill_switch_book_tag_magics']}/{len(EXPECTED_MAGICS)}"
        )

    snap = eas.get("equity_snapshot") or {}
    equity = float(snap.get("equity") or 0.0)
    day_pnl = float(snap.get("day_pnl") or 0.0)
    if equity:
        total_dd_pct, day_loss_pct, risk_alarms, risk_warns = assess_loss_limits(equity, day_pnl)
        alarms.extend(risk_alarms)
        warns.extend(risk_warns)
    else:
        total_dd_pct = day_loss_pct = None

    equity_snapshot_age = snapshot_age_minutes(eas.get("equity_snapshot_ts"), now)
    if equity_snapshot_age is None:
        warns.append("equity_snapshot_timestamp_missing_or_invalid")
    elif equity_snapshot_age > EQUITY_SNAPSHOT_STALE_MINUTES:
        warns.append(f"equity_snapshot_stale:{equity_snapshot_age:.1f}m")

    request_count = int(eas.get("server_requests_lower_bound") or 0)
    if request_count > SERVER_REQUEST_LIMIT:
        alarms.append(f"server_request_limit_exceeded:{request_count}")
    elif request_count >= SERVER_REQUEST_WARN:
        warns.append(f"server_request_warning:{request_count}_vs_limit_{SERVER_REQUEST_LIMIT}")

    # H2 total-DD floor (KILLSWITCH_HALT_CHANNEL_FIX_2026-07-05): when ARMED and
    # book DD reaches the floor, write the book-scoped portfolio_dd signal. EAs
    # honor it only after the qm_ks_book_tag rollout (challenge rebuild) — until
    # then this is inert by design. Arm via the flag file, never by default.
    floor_flag = Path(r"D:\QM\reports\state\FTMO_DD_FLOOR_ARMED.flag")
    if floor_flag.exists() and total_dd_pct is not None and total_dd_pct >= DD_FLOOR_PCT:
        try:
            BOOK_DD_SIGNAL.parent.mkdir(parents=True, exist_ok=True)
            if not BOOK_DD_SIGNAL.exists():
                BOOK_DD_SIGNAL.write_text(f"{total_dd_pct:.2f}\n", encoding="ascii")
                alarms.append(f"dd_floor_signal_written:{total_dd_pct:.2f}pct")
            else:
                alarms.append("dd_floor_signal_active")
        except OSError as exc:
            alarms.append(f"dd_floor_signal_write_failed:{exc}")

    verdict = "ALARM" if alarms else ("WARN" if warns else "OK")
    out = {
        "checked_at_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "verdict": verdict,
        "terminal_up": up,
        "magics_seen": eas["magics_seen"],
        "expected_magics": len(EXPECTED_MAGICS),
        "equity": equity or None,
        "day_pnl": day_pnl if snap else None,
        "total_dd_pct": total_dd_pct,
        "day_loss_pct": day_loss_pct,
        "equity_snapshot_ts": eas["equity_snapshot_ts"],
        "equity_snapshot_age_minutes": equity_snapshot_age,
        "kill_switch_day_anchor_magics": eas["kill_switch_day_anchor_magics"],
        "kill_switch_book_tag_magics": eas["kill_switch_book_tag_magics"],
        "server_requests_lower_bound": request_count,
        "server_request_day_broker": eas.get("server_request_day_broker"),
        "server_request_events": eas.get("server_request_events"),
        "alarms": alarms,
        "warns": warns[-10:],
    }
    STATE_JSON.parent.mkdir(parents=True, exist_ok=True)
    STATE_JSON.write_text(json.dumps(out, indent=1), encoding="utf-8")
    with STATE_LOG.open("a", encoding="utf-8") as fh:
        fh.write(f"{out['checked_at_utc']} {verdict} eq={equity or '-'} day={day_pnl if snap else '-'} "
                 f"magics={eas['magics_seen']}/{len(EXPECTED_MAGICS)} alarms={len(alarms)}\n")
    print(json.dumps(out, indent=1))
    return 1 if alarms else 0


if __name__ == "__main__":
    sys.exit(main())
