"""Gmail alarm when health watchdog hits FAIL — debounced.

OWNER 2026-05-17: "Gmail-Alarm bei FAIL". Reads state/health.json (written
by farmctl health every 15min) and sends a mail when:
  - overall == 'FAIL', AND
  - the set of FAILing check names is different from the last alarm sent

The "set changed" gate prevents spam — same FAIL persisting for hours
sends ONE email, not 16/hour. New FAIL appearing or FAIL clearing also
triggers a notification (transitions matter).

State file: state/gmail_alarm_state.json holds last-alarm fingerprint.

Credentials: re-uses the existing Gmail SMTP setup at
.private/secrets/gmail_{app_password,sender}.txt (same as
paperclip/tools/ops/daily_status_mail.py).

Scheduled: hourly via QM_StrategyFarm_GmailAlarm_Hourly. NOT every 15min
to keep traffic low — if a critical FAIL appears 5min after a check, you
see it within an hour, and the cockpit banner is immediate anyway.
"""

from __future__ import annotations

import datetime as dt
import json
import smtplib
import sys
from email.mime.text import MIMEText
from pathlib import Path

ROOT = Path(r"D:\QM\strategy_farm")
HEALTH_FILE = ROOT / "state" / "health.json"
STATE_FILE = ROOT / "state" / "gmail_alarm_state.json"
SECRETS_DIR = Path(r"C:\QM\repo\.private\secrets")
APP_PASSWORD_FILE = SECRETS_DIR / "gmail_app_password.txt"
SENDER_FILE = SECRETS_DIR / "gmail_sender.txt"
RECIPIENT = "fabian.grabner@gmail.com"
SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587


def _load_health() -> dict:
    if not HEALTH_FILE.exists():
        return {}
    try:
        return json.loads(HEALTH_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _load_state() -> dict:
    if not STATE_FILE.exists():
        return {}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _save_state(state: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")


def _fingerprint(health: dict) -> tuple[str, frozenset[str]]:
    """Reduce health.json to (overall, set_of_failing_check_names).

    Two alarms with the same fingerprint = no need to re-mail."""
    overall = health.get("overall", "?")
    fails = frozenset(
        c["name"] for c in (health.get("checks") or []) if c.get("status") == "FAIL"
    )
    return overall, fails


def _build_mail_body(health: dict) -> tuple[str, str]:
    """Return (subject, body_text)."""
    overall = health.get("overall", "?")
    summary = health.get("summary", {})
    fails = [c for c in (health.get("checks") or []) if c.get("status") == "FAIL"]
    warns = [c for c in (health.get("checks") or []) if c.get("status") == "WARN"]
    checked = health.get("checked_at", "?")

    subject = f"[QM Strategy Farm] PIPELINE {overall} — {len(fails)} FAIL / {len(warns)} WARN"
    lines = [
        f"Pipeline health watchdog flagged overall = {overall}.",
        f"Checked at: {checked}",
        f"Summary: {summary.get('fail', 0)} FAIL · {summary.get('warn', 0)} WARN · {summary.get('ok', 0)} OK",
        "",
    ]
    if fails:
        lines.append("=== FAILing invariants ===")
        for c in fails:
            lines.append(f"  - {c['name']}")
            lines.append(f"      {c.get('detail', '')}")
            if c.get("action_hint"):
                lines.append(f"      hint: {c['action_hint']}")
            lines.append("")
    if warns:
        lines.append("=== WARN invariants ===")
        for c in warns:
            lines.append(f"  - {c['name']}: {c.get('detail', '')}")
        lines.append("")
    lines.append("Cockpit:  file:///D:/QM/strategy_farm/dashboards/cockpit.html")
    lines.append("Brief:    file:///D:/QM/strategy_farm/dashboards/morning_brief.md")
    return subject, "\n".join(lines)


def _send_mail(subject: str, body: str) -> dict:
    """Send via Gmail SMTP. Returns result dict (no exception on failure)."""
    if not APP_PASSWORD_FILE.exists() or not SENDER_FILE.exists():
        return {"sent": False, "reason": "Gmail credentials missing in .private/secrets/"}
    try:
        password = APP_PASSWORD_FILE.read_text(encoding="utf-8").strip()
        sender = SENDER_FILE.read_text(encoding="utf-8").strip()
    except Exception as exc:
        return {"sent": False, "reason": f"reading creds failed: {exc!r}"}
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = RECIPIENT
    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as srv:
            srv.starttls()
            srv.login(sender, password)
            srv.sendmail(sender, [RECIPIENT], msg.as_string())
    except Exception as exc:
        return {"sent": False, "reason": f"smtp failed: {exc!r}"}
    return {"sent": True, "subject": subject}


def main() -> int:
    health = _load_health()
    if not health:
        print("no health.json — skipping (run farmctl health first)")
        return 0

    overall, fail_set = _fingerprint(health)
    state = _load_state()
    last_fingerprint = (state.get("last_overall"), frozenset(state.get("last_fails", [])))

    # No alarm needed when overall is OK (and we already cleared previous)
    if overall == "OK" and state.get("last_overall") in (None, "OK"):
        print("overall OK, no transition — skip")
        return 0

    # Same FAIL fingerprint as last alarm → skip (debounce)
    if overall == last_fingerprint[0] and fail_set == last_fingerprint[1]:
        print(f"unchanged fingerprint ({overall}, {len(fail_set)} fails) — skip")
        return 0

    # Compose + send
    if overall == "OK":
        subject = "[QM Strategy Farm] PIPELINE OK — alarm cleared"
        body = (f"All previously-failing invariants now green.\n"
                f"Checked at: {health.get('checked_at', '?')}\n"
                f"Cockpit: file:///D:/QM/strategy_farm/dashboards/cockpit.html\n")
    else:
        subject, body = _build_mail_body(health)

    result = _send_mail(subject, body)
    print(json.dumps(result, indent=2))

    # Update state regardless of send success — don't re-attempt failed sends
    # in a loop (we'd flood Gmail server with bad auth retries).
    new_state = {
        "last_overall": overall,
        "last_fails": sorted(fail_set),
        "last_alarm_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "last_send_result": result,
    }
    _save_state(new_state)
    return 0 if result.get("sent", overall == "OK") else 1


if __name__ == "__main__":
    sys.exit(main())
