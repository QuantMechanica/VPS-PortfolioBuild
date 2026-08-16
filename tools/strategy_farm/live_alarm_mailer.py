"""Immediate OWNER mail channel for live-terminal alarm transitions.

This is a read-only consumer of ``live_alarm_state.json``.  It is deliberately
separate from the uptime watchdog: failures here cannot delay recovery, launch a
terminal, or mutate watchdog state.  The scheduled task runs this module under
``pythonw.exe`` every minute.

OWNER ratified this narrow exception to the no-ping-email rule on 2026-08-06.
Only alarm transitions, all-clears, and bounded persistent-alarm escalations are
mailed.  SMTP transport and credentials are reused from ``gmail_alarm.py``.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import os
import sys
from pathlib import Path
from typing import Any, Callable

try:
    from gmail_alarm import PALETTE, _send_mail_with_retries
except ModuleNotFoundError:  # importlib-based tests do not add this file's dir
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from gmail_alarm import PALETTE, _send_mail_with_retries


REPORTS_STATE = Path(r"D:\QM\reports\state")
DEFAULT_ALARM_FILE = REPORTS_STATE / "live_alarm_state.json"
DEFAULT_CONSUMER_STATE = REPORTS_STATE / "live_alarm_mailer_state.json"
DEFAULT_LOG_FILE = REPORTS_STATE / "live_alarm_mailer.jsonl"
DEFAULT_MAINTENANCE_FLAG = REPORTS_STATE / "LIVE_UPTIME_MAINTENANCE.flag"
DEFAULT_MORNING_SAFETY_STATE = REPORTS_STATE / "morning_safety_check.json"
DEFAULT_MORNING_SAFETY_MAIL_STATE = REPORTS_STATE / "morning_safety_mail_state.json"

ALARM_CONDITIONS = frozenset(
    {
        "missing",
        "duplicate",
        "launch_failed",
        "probe_unknown",
        "stale",
        "unexpected_running",
        "contract_expired",
    }
)
UTC = dt.timezone.utc
Sender = Callable[[str, str, str | None], dict[str, Any]]


def _utc_stamp(value: dt.datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")


def _parse_utc(value: object) -> dt.datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


class JsonLoadError(Exception):
    """A JSON load that failed, carrying the path that actually failed.

    The top-level handler used to report ``args.alarm_file`` as the source of any
    exception. On 2026-08-17 that misdirection cost about 45 hours of silence: the
    real failure was the consumer-state file, the error named the alarm file, and
    anyone checking the named file found it perfectly healthy.
    """

    def __init__(self, path: Path, cause: Exception) -> None:
        super().__init__(f"{type(cause).__name__}: {cause} ({path})")
        self.path = path
        self.cause = cause


def _load_json(path: Path, *, required: bool = False) -> dict[str, Any]:
    if not path.is_file():
        if required:
            raise FileNotFoundError(path)
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as exc:
        raise JsonLoadError(path, exc) from exc
    if not isinstance(value, dict):
        raise JsonLoadError(path, ValueError("JSON root must be an object"))
    return value


def _load_consumer_state(path: Path) -> tuple[dict[str, Any], str | None]:
    """Load a 'what did I already send' cache, tolerating corruption.

    This file is not an input to the alarm decision -- it only suppresses repeats.
    Losing it can therefore cause at most one duplicate page, while refusing to
    read it takes the whole channel down. Those two failure modes are not
    comparable for a live-trading alarm, so corruption degrades to "nothing sent
    yet" and is reported in the event rather than raised.

    Found 2026-08-17: live_alarm_mailer_state.json held 643 NUL bytes (metadata
    committed, data never flushed). Every run since 2026-08-15T02:45Z had aborted
    on it, so the T_Live alarm channel was dead while the book traded.
    """
    try:
        return _load_json(path), None
    except JsonLoadError as exc:
        return {}, f"{type(exc.cause).__name__}: {exc.cause}"


def _atomic_write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def _append_log(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(value, sort_keys=True, default=str) + "\n")


def _alert_fingerprint(alerts: list[dict[str, Any]]) -> str | None:
    if not alerts:
        return None
    stable = [
        {key: alert.get(key) for key in ("kind", "session", "condition", "expected_state")}
        for alert in alerts
    ]
    raw = json.dumps(stable, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _extract_alerts(source: dict[str, Any]) -> list[dict[str, Any]]:
    """Translate producer facts to stable, transition-oriented alert keys."""
    schema = source.get("schema_version")
    if not isinstance(schema, int) or schema < 2:
        raise ValueError(f"unsupported live alarm schema_version={schema!r}")
    if source.get("author") != "T_Live_Watchdog":
        raise ValueError("live alarm author is not T_Live_Watchdog")

    alerts: list[dict[str, Any]] = []
    sessions = source.get("sessions")
    if not isinstance(sessions, dict):
        raise ValueError("live alarm sessions must be an object")
    for session_name in sorted(sessions):
        entry = sessions[session_name]
        if not isinstance(entry, dict):
            raise ValueError(f"session entry must be an object: {session_name}")
        expected = str(entry.get("expected_state") or "").upper()
        condition = str(entry.get("condition") or "").lower()
        is_alarm = bool(entry.get("alarm")) or condition in ALARM_CONDITIONS
        # A PARKED target is not paged merely for being absent.  An
        # unexpected_running alarm is still surfaced because it is producer-
        # declared contract drift and this consumer never stops it.
        if is_alarm and (expected == "RUNNING" or condition == "unexpected_running"):
            alerts.append(
                {
                    "kind": "terminal",
                    "session": str(session_name),
                    "expected_state": expected or "UNKNOWN",
                    "condition": condition or "unknown",
                    "detail": str(entry.get("detail") or ""),
                    "since_utc": entry.get("since_utc"),
                    "cycles": int(entry.get("identical_failure_cycles") or 0),
                }
            )

    if source.get("recovery_task_contract_ready") is False:
        errors = source.get("recovery_task_contract_errors")
        if not isinstance(errors, list):
            errors = []
        alerts.append(
            {
                "kind": "recovery_contract",
                "session": "SYSTEM",
                "expected_state": "READY",
                "condition": "recovery_blocked",
                "detail": " | ".join(str(item) for item in errors) or "contract_not_ready",
                "since_utc": source.get("generated_utc"),
                "cycles": 0,
            }
        )

    if source.get("reboot_suppressed") is True:
        alerts.append(
            {
                "kind": "reboot",
                "session": "SYSTEM",
                "expected_state": "RECOVERABLE",
                "condition": "reboot_suppressed",
                "detail": "watchdog recovery reboot was suppressed or cancelled",
                "since_utc": source.get("generated_utc"),
                "cycles": 0,
            }
        )
    return alerts


def _summarize(alerts: list[dict[str, Any]]) -> str:
    parts: list[str] = []
    for alert in alerts:
        session = str(alert.get("session") or "SYSTEM")
        condition = str(alert.get("condition") or "unknown")
        parts.append(f"{session} {condition}")
    return "; ".join(parts) if parts else "alarm resolved"


def _build_mail(
    kind: str,
    alerts: list[dict[str, Any]],
    source: dict[str, Any],
    now: dt.datetime,
) -> tuple[str, str, str]:
    summary = _summarize(alerts)
    if kind == "CLEAR":
        subject = "[QM LIVE] ALL CLEAR - live-terminal alarm resolved"
    elif kind == "ESCALATION":
        subject = f"[QM LIVE] STILL CRITICAL - {summary}"
    else:
        subject = f"[QM LIVE] CRITICAL - {summary}"

    lines = [
        "QuantMechanica live-terminal alarm",
        f"Notification: {kind}",
        f"Observed: {_utc_stamp(now)}",
        f"Producer state: {source.get('generated_utc', '?')}",
        f"Watchdog status: {source.get('watchdog_status', '?')}",
        "",
    ]
    if alerts:
        for alert in alerts:
            lines.append(
                f"- {alert.get('session')}: expected={alert.get('expected_state')} "
                f"condition={alert.get('condition')} detail={alert.get('detail', '')}"
            )
    else:
        lines.append("All previously paged live-terminal conditions are clear.")
    lines.extend(
        [
            "",
            "OWNER-ratified immediate live-uptime exception (2026-08-06).",
            "This channel is transition-deduplicated; do not reply to automate recovery.",
        ]
    )
    text_body = "\n".join(lines)

    p = PALETTE
    status_color = p["emerald"] if kind == "CLEAR" else p["fail"]
    rows = "".join(
        "<tr><td style='padding:8px 0;border-top:1px solid {border};'>"
        "<b>{session}</b> &middot; {condition}<br>"
        "<span style='color:{muted}'>{detail}</span></td></tr>".format(
            border=p["border"],
            session=html.escape(str(alert.get("session") or "SYSTEM")),
            condition=html.escape(str(alert.get("condition") or "unknown")),
            muted=p["text_muted"],
            detail=html.escape(str(alert.get("detail") or "")),
        )
        for alert in alerts
    )
    if not rows:
        rows = "<tr><td style='padding:8px 0;'>All previously paged conditions are clear.</td></tr>"
    html_body = f"""<!doctype html><html><body style="background:{p['bg']};font-family:Segoe UI,Arial,sans-serif;color:{p['text']}">
<table width="100%"><tr><td align="center"><table width="640" style="background:{p['surface_1']};border:1px solid {p['border']};border-radius:10px">
<tr><td style="padding:22px"><div style="font-size:11px;color:{p['accent']};letter-spacing:1.5px">QUANTMECHANICA LIVE OPS</div>
<h2 style="margin:8px 0;color:{status_color}">{html.escape(kind)}</h2>
<div style="color:{p['text_muted']}">{html.escape(summary)}</div></td></tr>
<tr><td style="padding:0 22px 18px"><table width="100%">{rows}</table></td></tr>
<tr><td style="padding:14px 22px;background:{p['surface_0']};font-size:11px;color:{p['text_muted']}">
Producer {html.escape(str(source.get('generated_utc', '?')))} &middot; OWNER-ratified exception 2026-08-06 &middot; transition-deduplicated</td></tr>
</table></td></tr></table></body></html>"""
    return subject, text_body, html_body


def _decide(
    source: dict[str, Any],
    previous: dict[str, Any],
    now: dt.datetime,
    *,
    maintenance_flag_present: bool,
    repeat_minutes: int,
) -> tuple[str, list[dict[str, Any]], dict[str, Any]]:
    alerts = _extract_alerts(source)
    fingerprint = _alert_fingerprint(alerts)
    previous_fingerprint = previous.get("active_fingerprint")
    previous_alerts = previous.get("active_alerts")
    if not isinstance(previous_alerts, list):
        previous_alerts = []
    maintenance = bool(source.get("maintenance")) or maintenance_flag_present
    threshold = int(source.get("escalation_threshold") or 3)
    threshold = max(1, min(threshold, 60))

    next_state = dict(previous)
    next_state.update(
        {
            "schema_version": 1,
            "last_checked_utc": _utc_stamp(now),
            "last_source_generated_utc": source.get("generated_utc"),
            "maintenance_suppressed": maintenance,
        }
    )
    if maintenance:
        # Do not consume an alarm transition while suppressed.  Once the flag is
        # removed, a condition first observed during maintenance is paged.
        next_state["last_decision"] = "SUPPRESSED"
        return "SUPPRESSED", alerts, next_state

    if fingerprint:
        if fingerprint != previous_fingerprint:
            cycles = 1
            decision = "RAISE"
            next_state["last_escalation_utc"] = None
        else:
            cycles = int(previous.get("same_alarm_cycles") or 0) + 1
            decision = "NONE"
            if cycles >= threshold:
                last_escalation = _parse_utc(previous.get("last_escalation_utc"))
                if last_escalation is None or (now - last_escalation) >= dt.timedelta(minutes=repeat_minutes):
                    decision = "ESCALATION"
        next_state.update(
            {
                "active_fingerprint": fingerprint,
                "active_alerts": alerts,
                "same_alarm_cycles": cycles,
            }
        )
    else:
        decision = "CLEAR" if previous_fingerprint or previous_alerts else "NONE"
        next_state.update(
            {
                "active_fingerprint": None,
                "active_alerts": [],
                "same_alarm_cycles": 0,
                "last_escalation_utc": None,
            }
        )
    next_state["last_decision"] = decision
    return decision, alerts, next_state


def process_once(
    *,
    alarm_file: Path,
    consumer_state_file: Path,
    maintenance_flag: Path,
    log_file: Path,
    now: dt.datetime,
    repeat_minutes: int = 30,
    dry_run: bool = False,
    sender: Sender = _send_mail_with_retries,
) -> dict[str, Any]:
    source = _load_json(alarm_file, required=True)
    previous, consumer_state_degraded = _load_consumer_state(consumer_state_file)
    decision, alerts, next_state = _decide(
        source,
        previous,
        now,
        maintenance_flag_present=maintenance_flag.is_file(),
        repeat_minutes=repeat_minutes,
    )
    event: dict[str, Any] = {
        "ts": _utc_stamp(now),
        "decision": decision,
        "source": str(alarm_file),
        "source_generated_utc": source.get("generated_utc"),
        "alert_count": len(alerts),
        "dry_run": dry_run,
    }
    if consumer_state_degraded is not None:
        # visible, but never fatal: a lost repeat-suppression cache can only
        # duplicate a page, and a duplicate page beats a silent channel
        event["consumer_state_reset"] = str(consumer_state_file)
        event["consumer_state_error"] = consumer_state_degraded

    if decision in {"RAISE", "CLEAR", "ESCALATION"}:
        subject, text_body, html_body = _build_mail(decision, alerts, source, now)
        # Reserve the transition before SMTP.  If the process dies after this
        # point, the next cadence skips it instead of producing duplicate mail.
        next_state["last_notification_utc"] = _utc_stamp(now)
        next_state["last_notification_kind"] = decision
        next_state["last_notification_subject"] = subject
        if decision == "ESCALATION":
            next_state["last_escalation_utc"] = _utc_stamp(now)
        next_state["last_send_result"] = {"reserved": True, "dry_run": dry_run}
        _atomic_write_json(consumer_state_file, next_state)
        if dry_run:
            send_result: dict[str, Any] = {"sent": False, "dry_run": True, "subject": subject}
        else:
            send_result = sender(subject, text_body, html_body)
        next_state["last_send_result"] = send_result
        _atomic_write_json(consumer_state_file, next_state)
        event["subject"] = subject
        event["send_result"] = send_result
    else:
        _atomic_write_json(consumer_state_file, next_state)

    _append_log(log_file, event)
    return event


def _build_morning_safety_mail(
    failures: list[dict[str, Any]], state: dict[str, Any]
) -> tuple[str, str, str]:
    subject = f"[QM LIVE] MORNING SAFETY FAILED - {len(failures)} check(s)"
    generated = str(state.get("generated_utc") or "?")
    lines = [
        "QuantMechanica 04:45 morning safety check",
        f"Run: {generated}",
        f"FAILED checks: {len(failures)}",
        "",
    ]
    for check in failures:
        lines.append(f"- {check.get('name')}: {check.get('detail', '')}")
    lines.extend(
        [
            "",
            "No terminal was stopped and no reboot/AutoTrading action is permitted by this sweep.",
            "OWNER-ratified immediate live-uptime exception (2026-08-06).",
        ]
    )
    text_body = "\n".join(lines)
    p = PALETTE
    rows = "".join(
        "<tr><td style='padding:9px 0;border-top:1px solid {border};'>"
        "<b>{name}</b><br><span style='color:{muted}'>{detail}</span></td></tr>".format(
            border=p["border"],
            muted=p["text_muted"],
            name=html.escape(str(check.get("name") or "unknown")),
            detail=html.escape(str(check.get("detail") or "")),
        )
        for check in failures
    )
    html_body = f"""<!doctype html><html><body style="background:{p['bg']};font-family:Segoe UI,Arial,sans-serif;color:{p['text']}">
<table width="100%"><tr><td align="center"><table width="640" style="background:{p['surface_1']};border:1px solid {p['border']};border-radius:10px">
<tr><td style="padding:22px"><div style="font-size:11px;color:{p['accent']};letter-spacing:1.5px">QUANTMECHANICA LIVE OPS</div>
<h2 style="margin:8px 0;color:{p['fail']}">04:45 SAFETY FAILED</h2>
<div style="color:{p['text_muted']}">{len(failures)} check(s) need attention &middot; {html.escape(generated)}</div></td></tr>
<tr><td style="padding:0 22px 18px"><table width="100%">{rows}</table></td></tr>
<tr><td style="padding:14px 22px;background:{p['surface_0']};font-size:11px;color:{p['text_muted']}">
Start-only sweep &middot; no reboot &middot; no AutoTrading mutation &middot; OWNER-ratified exception 2026-08-06</td></tr>
</table></td></tr></table></body></html>"""
    return subject, text_body, html_body


def process_morning_safety_once(
    *,
    safety_state_file: Path,
    mail_state_file: Path,
    log_file: Path,
    now: dt.datetime,
    dry_run: bool = False,
    sender: Sender = _send_mail_with_retries,
) -> dict[str, Any]:
    """Page once for a morning-safety run that contains any FAILED check."""
    safety = _load_json(safety_state_file, required=True)
    checks = safety.get("checks")
    if not isinstance(checks, list):
        raise ValueError("morning safety checks must be an array")
    failures = [
        item for item in checks
        if isinstance(item, dict) and str(item.get("status") or "").upper() == "FAILED"
    ]
    run_id = str(safety.get("generated_utc") or "")
    if not run_id:
        raise ValueError("morning safety state is missing generated_utc")
    previous, mail_state_degraded = _load_consumer_state(mail_state_file)
    event: dict[str, Any] = {
        "ts": _utc_stamp(now),
        "decision": "NONE",
        "channel": "morning_safety",
        "run_id": run_id,
        "failure_count": len(failures),
        "dry_run": dry_run,
    }
    if mail_state_degraded is not None:
        event["consumer_state_reset"] = str(mail_state_file)
        event["consumer_state_error"] = mail_state_degraded
    if not failures:
        _append_log(log_file, event)
        return event
    if previous.get("last_run_id") == run_id:
        event["decision"] = "DUPLICATE_SUPPRESSED"
        _append_log(log_file, event)
        return event

    subject, text_body, html_body = _build_morning_safety_mail(failures, safety)
    reserved = {
        "schema_version": 1,
        "last_run_id": run_id,
        "last_reserved_utc": _utc_stamp(now),
        "last_subject": subject,
        "last_send_result": {"reserved": True, "dry_run": dry_run},
    }
    _atomic_write_json(mail_state_file, reserved)
    if dry_run:
        send_result: dict[str, Any] = {"sent": False, "dry_run": True, "subject": subject}
    else:
        send_result = sender(subject, text_body, html_body)
    reserved["last_send_result"] = send_result
    _atomic_write_json(mail_state_file, reserved)
    event.update({"decision": "FAILED_PAGE", "subject": subject, "send_result": send_result})
    _append_log(log_file, event)
    return event


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alarm-file", type=Path, default=DEFAULT_ALARM_FILE)
    parser.add_argument("--consumer-state-file", type=Path, default=DEFAULT_CONSUMER_STATE)
    parser.add_argument("--maintenance-flag", type=Path, default=DEFAULT_MAINTENANCE_FLAG)
    parser.add_argument("--log-file", type=Path, default=DEFAULT_LOG_FILE)
    parser.add_argument("--repeat-minutes", type=int, default=30)
    parser.add_argument("--now-utc", help="Deterministic UTC timestamp for fixture evidence")
    parser.add_argument("--dry-run", action="store_true", help="Render/reserve without SMTP")
    parser.add_argument(
        "--morning-safety-file",
        type=Path,
        help="Send the FAILED checks from one morning_safety_check.json run",
    )
    parser.add_argument(
        "--morning-safety-mail-state-file",
        type=Path,
        default=DEFAULT_MORNING_SAFETY_MAIL_STATE,
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.repeat_minutes < 30:
        raise SystemExit("--repeat-minutes must be at least 30")
    now = _parse_utc(args.now_utc) if args.now_utc else dt.datetime.now(UTC)
    if now is None:
        raise SystemExit("--now-utc must be an ISO-8601 UTC timestamp")
    try:
        if args.morning_safety_file:
            event = process_morning_safety_once(
                safety_state_file=args.morning_safety_file,
                mail_state_file=args.morning_safety_mail_state_file,
                log_file=args.log_file,
                now=now,
                dry_run=args.dry_run,
            )
        else:
            event = process_once(
                alarm_file=args.alarm_file,
                consumer_state_file=args.consumer_state_file,
                maintenance_flag=args.maintenance_flag,
                log_file=args.log_file,
                now=now,
                repeat_minutes=args.repeat_minutes,
                dry_run=args.dry_run,
            )
    except Exception as exc:
        # name the file that ACTUALLY failed. Reporting args.alarm_file for every
        # exception sent the 2026-08-17 investigation to a healthy file and let a
        # dead alarm channel look like a puzzling but localised error for ~45 h.
        failed_path = getattr(exc, "path", None)
        error = {
            "ts": _utc_stamp(now),
            "decision": "ERROR",
            "error": f"{type(exc).__name__}: {exc}",
            "source": str(failed_path if failed_path is not None else args.alarm_file),
        }
        if failed_path is not None and Path(failed_path) != args.alarm_file:
            error["alarm_file"] = str(args.alarm_file)
        try:
            _append_log(args.log_file, error)
        except Exception:
            pass
        print(json.dumps(error, sort_keys=True))
        return 1
    print(json.dumps(event, indent=2, sort_keys=True))
    result = event.get("send_result")
    if isinstance(result, dict) and not args.dry_run and result.get("sent") is not True:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
