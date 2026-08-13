"""FTMO trial/challenge pulse — read-only health monitor for the FTMO terminal book.

Mirrors the intent of live_book_pulse.py (T_Live) for the FTMO Round25 deployment
(decisions/2026-07-05_ftmo_round25_phase1_deploy.md). Read-only: terminal journal +
QM EA logs only; never touches the terminal.

Checks:
  1. FTMO terminal64 process and broker-confirmed QM activity match the baked
     RUNNING/PARKED/MAINTENANCE state. PARKED permits a warm terminal but no
     open QM positions.
  2. Today's journal: disconnects / errors.
  3. QM EA logs: all 12 expected magics seen, ERROR-level events.
  4. Latest EQUITY_SNAPSHOT: equity + day_pnl vs FTMO limits
     (daily 5% / total 10% of 100k) with early-warning margins.

Output: D:\\QM\\reports\\state\\ftmo_trial_pulse.json (+ appended .log line).
Scheduled: QM_FTMO_TrialPulse (30 min). Exit 0 = OK/WARN, 1 = ALARM.
"""
from __future__ import annotations

import csv
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

DATA_DIR = Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850")
QM_DIR = DATA_DIR / "MQL5" / "Files" / "QM"
STATE_JSON = Path(r"D:\QM\reports\state\ftmo_trial_pulse.json")
STATE_LOG = Path(r"D:\QM\reports\state\ftmo_trial_pulse.log")
MAINTENANCE_FLAG = Path(r"D:\QM\reports\state\LIVE_UPTIME_MAINTENANCE.flag")

# OWNER state contract. Deliberately baked into the existing pulse rather than
# hidden in a second, potentially stale flag file.
#
# 2026-08-13 (OWNER, chat): "da haben wir ja am Wochenende ein Demokonto
# gestartet, das lassen wir einfach laufen" -- supersedes the 2026-07-26 PARKED
# contract. The demo runs; the terminal being up with QM trading is the
# expected state, not an alarm. Review date kept at 2026-08-25 so the contract
# forces a fresh OWNER decision then. NOTE: no signed deploy manifest exists
# for the demo book; EXPECTED_MAGICS below pins the single magic OWNER
# ratified by keeping it running. Anything else appearing is still an anomaly.
EXPECTED_STATE = "RUNNING"
EXPECTED_STATE_REVIEW_EXPIRES_UTC = "2026-08-25T00:00:00Z"

BASE_EQUITY = 100_000.0
DAILY_LIMIT_PCT = 5.0     # FTMO daily loss limit
TOTAL_LIMIT_PCT = 10.0    # FTMO max loss limit
DAILY_WARN_PCT = 2.5      # half-budget early warning thresholds
TOTAL_WARN_PCT = 5.0
SERVER_REQUEST_WARN = 1_500
SERVER_REQUEST_LIMIT = 2_000
EQUITY_SNAPSHOT_STALE_MINUTES = 180

# --- ONE-AUTHORITY TOMBSTONE (permanent; WS-G' round 2, 2026-07-26) ----------
# This pulse is a CODE-LEVEL OBSERVER ONLY. It never writes a halt, kill, or
# liquidation signal of any kind. The single armed FTMO money-control authority
# is the account-governor EA QM5_13206
# (framework/EAs/QM5_13206_ftmo-account-governor), armed only against an
# OWNER-signed deploy manifest.
#
# HISTORY: a prior revision could write the book-scoped `portfolio_dd.signal`
# (Common\Files\QM\halt\book_ftmo_r25\portfolio_dd.signal) when
# `FTMO_DD_FLOOR_ARMED.flag` was present and book DD reached an 8% floor
# (KILLSWITCH_HALT_CHANNEL_FIX_2026-07-05). That halt-emission path is
# PERMANENTLY REMOVED. Two competing halt authorities on one account is a
# fail-open hazard: a lagging/torn observer racing the governor can flatten on
# stale equity or mask the governor's own decision. Do NOT reintroduce any
# signal-writing path in this monitor — arming belongs to the governor + a
# signed manifest, never to this read-only pulse. The legacy arm flag is now
# inert: if present it is reported as an ignored no-op (see main()).
LEGACY_ARM_FLAG = Path(r"D:\QM\reports\state\FTMO_DD_FLOOR_ARMED.flag")

# 2026-08-13: replaced the stale r25-book set (12 magics, never deployed to
# this terminal) with the demo state OWNER ratified today. 107060001 =
# QM5_10706 / GBPUSD slot 1, the position observed open when OWNER confirmed
# the demo keeps running. A magic outside this set is still reported missing/
# unexpected -- the guard against silent scope growth stays armed.
EXPECTED_MAGICS = {
    107060001,
}
SERVER_REQUEST_EVENTS = {"TM_OPEN", "TM_CLOSE", "TM_MODIFY", "TM_REMOVE_PENDING"}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def assess_expected_state(
    *,
    terminal_up: bool | None,
    now: datetime,
    magics_seen: int | None = None,
    maintenance: bool = False,
    expected_state: str = EXPECTED_STATE,
    review_expires_utc: str = EXPECTED_STATE_REVIEW_EXPIRES_UTC,
) -> dict:
    """Pure tri-state contract assessment; never starts or stops a process."""
    expected = str(expected_state or "").upper()
    if expected not in {"RUNNING", "PARKED", "MAINTENANCE"}:
        expected = "MAINTENANCE"
        invalid = True
    else:
        invalid = False
    try:
        expiry = datetime.fromisoformat(review_expires_utc.replace("Z", "+00:00"))
        if expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        review_expired = now.astimezone(timezone.utc) >= expiry.astimezone(timezone.utc)
    except (TypeError, ValueError):
        review_expired = True

    effective = "MAINTENANCE" if maintenance or expected == "MAINTENANCE" else expected
    if invalid:
        condition, alarm = "contract_invalid", "expected_state_contract_invalid"
    elif review_expired:
        condition, alarm = "contract_expired", "expected_state_review_expired"
    elif effective == "MAINTENANCE":
        condition, alarm = "maintenance", None
    elif terminal_up is None:
        condition, alarm = "probe_unknown", "ftmo_terminal_process_probe_unknown"
    elif expected == "PARKED":
        if not terminal_up:
            condition, alarm = "parked_terminal_stopped", None
        elif magics_seen is None:
            condition, alarm = "parked_magic_probe_unknown", "ftmo_parked_magic_probe_unknown"
        elif magics_seen > 0:
            condition = "parked_qm_trading_active"
            alarm = f"ftmo_qm_magics_active_while_parked:{magics_seen}"
        else:
            condition, alarm = "parked_terminal_running_no_qm_trading", None
    elif not terminal_up:
        condition, alarm = "missing", "ftmo_terminal_not_running"
    else:
        condition, alarm = "ok", None
    return {
        "expected_state": expected,
        "effective_state": effective,
        "review_expires_utc": review_expires_utc,
        "review_expired": review_expired,
        "condition": condition,
        "alarm": alarm,
    }


MONITOR_DEALS_CSV = QM_DIR / "journal" / "live_deals_normalized.csv"
_CLOSING_DEAL_ENTRIES = {"OUT", "OUT_BY", "INOUT"}


def read_open_qm_positions(path: Path = MONITOR_DEALS_CSV) -> dict:
    """Resolve currently open QM positions from the broker deal export.

    The AccountMonitor export is broker history keyed by position_id, so it is
    authoritative for successful fills and closes. EA log presence is not an
    activity signal: PARKED profiles may retain attached instrumentation EAs,
    and historical logs persist after positions close.
    """
    required = {"deal_id", "position_id", "entry", "deal_magic", "logical_magic", "magic", "type"}
    positions: dict[int, dict] = {}
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as fh:
            reader = csv.DictReader(fh)
            fields = set(reader.fieldnames or [])
            missing = sorted(required - fields)
            if missing:
                return {
                    "ok": False,
                    "reason": "deal_export_header_missing:" + ",".join(missing),
                    "positions": [],
                    "magics": [],
                }
            for row in reader:
                try:
                    position_id = int(str(row.get("position_id") or "0"))
                except ValueError:
                    return {
                        "ok": False,
                        "reason": "deal_export_position_id_invalid",
                        "positions": [],
                        "magics": [],
                    }
                if position_id <= 0 or str(row.get("type") or "").upper() == "BALANCE":
                    continue
                magic = 0
                for column in ("logical_magic", "deal_magic", "magic"):
                    try:
                        candidate = int(str(row.get(column) or "0"))
                    except ValueError:
                        return {
                            "ok": False,
                            "reason": f"deal_export_{column}_invalid",
                            "positions": [],
                            "magics": [],
                        }
                    if candidate:
                        magic = candidate
                        break
                state = positions.setdefault(
                    position_id,
                    {"position_id": position_id, "magic": 0, "closed": False},
                )
                if magic and state["magic"] and state["magic"] != magic:
                    return {
                        "ok": False,
                        "reason": f"position_magic_mismatch:{position_id}",
                        "positions": [],
                        "magics": [],
                    }
                if magic and not state["magic"]:
                    state["magic"] = magic
                if str(row.get("entry") or "").strip().upper() in _CLOSING_DEAL_ENTRIES:
                    state["closed"] = True
    except (OSError, UnicodeDecodeError, csv.Error) as exc:
        return {
            "ok": False,
            "reason": f"deal_export_unreadable:{exc.__class__.__name__}",
            "positions": [],
            "magics": [],
        }

    active = [row for row in positions.values() if not row["closed"]]
    unattributed = [row["position_id"] for row in active if not row["magic"]]
    if unattributed:
        return {
            "ok": False,
            "reason": "open_position_magic_unattributed:" + ",".join(map(str, sorted(unattributed))),
            "positions": active,
            "magics": [],
        }
    magics = sorted({int(row["magic"]) for row in active})
    return {"ok": True, "reason": "ok", "positions": active, "magics": magics}


def reconcile_parked_activity(activity: dict, monitor: dict | None) -> dict:
    """Bind deal-derived QM positions to a fresh account-level position count."""
    if not activity.get("ok"):
        return {"ok": False, "reason": activity.get("reason") or "deal_activity_unknown", "magics_seen": None}
    if not monitor or not monitor.get("fresh"):
        return {"ok": False, "reason": "account_snapshot_missing_or_stale", "magics_seen": None}
    open_positions = monitor.get("open_positions")
    if isinstance(open_positions, bool) or not isinstance(open_positions, int) or open_positions < 0:
        return {"ok": False, "reason": "account_open_positions_invalid", "magics_seen": None}
    activity_count = len(activity.get("positions") or [])
    if open_positions != activity_count:
        return {
            "ok": False,
            "reason": f"account_position_count_mismatch:{open_positions}!={activity_count}",
            "magics_seen": None,
        }
    return {
        "ok": True,
        "reason": "ok",
        "magics_seen": len(activity.get("magics") or []),
    }


def terminal_running() -> bool | None:
    try:
        import subprocess
        out = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "@(Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | "
             "Where-Object { $_.ExecutablePath -like 'C:\\Program Files\\FTMO*' }).Count"],
            capture_output=True, text=True, timeout=60,
            creationflags=0x08000000,  # CREATE_NO_WINDOW
        )
        if out.returncode != 0:
            return None
        value = (out.stdout or "").strip()
        return int(value) > 0
    except (OSError, ValueError, subprocess.SubprocessError):
        # UNKNOWN is not equivalent to confidently stopped. In particular, a
        # PARKED target must not go green when the process inventory failed.
        return None


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


MONITOR_SNAPSHOT = QM_DIR / "journal" / "account_snapshot.json"
MONITOR_FRESH_MINUTES = 10


def read_monitor_snapshot(now: datetime) -> dict | None:
    """AccountMonitor account_snapshot.json (deployed 2026-07-25): terminal-
    truth equity incl. floating on a 60s timer. Preferred over the EA
    day-close EQUITY_SNAPSHOT, which lags days across weekends — on
    2026-07-25 the day-close figure hid 2.3% of real drawdown ($92,315
    shown vs $90,002 actual).
    """
    try:
        d = json.loads(MONITOR_SNAPSHOT.read_text(encoding="utf-8"))
        eq = d.get("equity")
        if not isinstance(eq, (int, float)) or eq <= 0:
            return None
        ts = datetime.strptime(
            str(d.get("time_utc") or ""), "%Y-%m-%dT%H:%M:%SZ"
        ).replace(tzinfo=timezone.utc)
        age = (now - ts).total_seconds() / 60.0
        return {
            "equity": float(eq),
            "daily_pnl": float(d.get("daily_pnl") or 0.0),
            "open_positions": d.get("open_positions"),
            "age_minutes": age,
            "fresh": 0 <= age <= MONITOR_FRESH_MINUTES,
        }
    except Exception:
        return None


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


def publish_pulse(out: dict) -> int:
    """Write only this observer's state/log artifacts; never touch MT5."""
    STATE_JSON.parent.mkdir(parents=True, exist_ok=True)
    STATE_JSON.write_text(json.dumps(out, indent=1), encoding="utf-8")
    with STATE_LOG.open("a", encoding="utf-8") as fh:
        fh.write(
            f"{out['checked_at_utc']} {out['verdict']} "
            f"state={out.get('expected_state_condition')} "
            f"eq={out.get('equity') or '-'} day={out.get('day_pnl') if out.get('equity') else '-'} "
            f"magics={out.get('magics_seen', 0)}/{out.get('expected_magics', len(EXPECTED_MAGICS))} "
            f"alarms={len(out.get('alarms') or [])}\n"
        )
    print(json.dumps(out, indent=1))
    return 1 if out.get("alarms") else 0


def main() -> int:
    now = utc_now()
    alarms: list[str] = []
    warns: list[str] = []

    up = terminal_running()
    parked_activity = {
        "ok": True,
        "reason": "terminal_stopped",
        "positions": [],
        "magics": [],
    }
    parked_monitor: dict | None = None
    parked_magics_seen: int | None = None
    if EXPECTED_STATE == "PARKED" and up:
        parked_activity = read_open_qm_positions()
        parked_monitor = read_monitor_snapshot(now)
        reconciliation = reconcile_parked_activity(parked_activity, parked_monitor)
        parked_activity["ok"] = reconciliation["ok"]
        parked_activity["reason"] = reconciliation["reason"]
        parked_magics_seen = reconciliation["magics_seen"]
    elif EXPECTED_STATE == "PARKED" and up is False:
        parked_magics_seen = 0
    contract = assess_expected_state(
        terminal_up=up,
        now=now,
        magics_seen=parked_magics_seen,
        maintenance=MAINTENANCE_FLAG.exists(),
    )
    # PARKED has no journal/equity SLA, but it does retain a fail-closed
    # broker-deal activity contract. Short-circuiting avoids RUNNING-only
    # checks after that bounded PARKED assessment.
    if contract["effective_state"] != "RUNNING" or contract["alarm"]:
        if contract["alarm"]:
            alarms.append(contract["alarm"])
        verdict = "ALARM" if alarms else "OK"
        return publish_pulse({
            "checked_at_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "verdict": verdict,
            "role": "observer_only",
            "halt_authority": "governor_QM5_13206",
            "terminal_up": up,
            "expected_state": contract["expected_state"],
            "effective_state": contract["effective_state"],
            "expected_state_condition": contract["condition"],
            "expected_state_review_expires_utc": contract["review_expires_utc"],
            "expected_state_review_expired": contract["review_expired"],
            "magics_seen": parked_magics_seen,
            "expected_magics": 0 if contract["expected_state"] == "PARKED" else len(EXPECTED_MAGICS),
            "active_qm_magics": parked_activity["magics"],
            "active_qm_position_ids": [
                row["position_id"] for row in parked_activity["positions"]
            ],
            "parked_activity_evidence_ok": parked_activity["ok"],
            "parked_activity_evidence_reason": parked_activity["reason"],
            "equity": None,
            "day_pnl": None,
            "equity_source": None,
            "monitor_age_minutes": (parked_monitor or {}).get("age_minutes"),
            "open_positions": (parked_monitor or {}).get("open_positions"),
            "total_dd_pct": None,
            "day_loss_pct": None,
            "equity_snapshot_ts": None,
            "equity_snapshot_age_minutes": None,
            "kill_switch_day_anchor_magics": 0,
            "kill_switch_book_tag_magics": 0,
            "server_requests_lower_bound": 0,
            "server_request_day_broker": None,
            "server_request_events": {},
            "alarms": alarms,
            "warns": [],
        })

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
    equity_source = "ea_day_close_snapshot" if equity else None
    mon = read_monitor_snapshot(now)
    if mon and mon.get("fresh"):
        equity = mon["equity"]
        day_pnl = mon["daily_pnl"]
        equity_source = "account_monitor"
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

    # ONE-AUTHORITY (see tombstone near the top): this observer NEVER emits a
    # halt/liquidation signal. Even if the retired arm flag is still on disk, we
    # refuse to write anything and instead surface the stale flag as a WARN so an
    # operator who set it learns it is now a no-op and that the account-governor
    # EA (QM5_13206) is the sole armed halt authority.
    if LEGACY_ARM_FLAG.exists():
        warns.append(
            "ftmo_dd_floor_arm_flag_present_but_ignored:"
            "pulse_is_observer_only_governor_QM5_13206_is_sole_halt_authority"
        )

    verdict = "ALARM" if alarms else ("WARN" if warns else "OK")
    out = {
        "checked_at_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "verdict": verdict,
        # Code-level one-authority: this pulse observes and never halts. The
        # armed FTMO halt authority is the account-governor EA QM5_13206.
        "role": "observer_only",
        "halt_authority": "governor_QM5_13206",
        "terminal_up": up,
        "expected_state": contract["expected_state"],
        "effective_state": contract["effective_state"],
        "expected_state_condition": contract["condition"],
        "expected_state_review_expires_utc": contract["review_expires_utc"],
        "expected_state_review_expired": contract["review_expired"],
        "magics_seen": eas["magics_seen"],
        "expected_magics": len(EXPECTED_MAGICS),
        "equity": equity or None,
        "day_pnl": day_pnl if equity_source else None,
        "equity_source": equity_source,
        "monitor_age_minutes": (mon or {}).get("age_minutes"),
        "open_positions": (mon or {}).get("open_positions"),
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
    return publish_pulse(out)


if __name__ == "__main__":
    sys.exit(main())
