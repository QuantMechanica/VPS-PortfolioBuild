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
.private/secrets/gmail_{app_password,sender}.txt.

Scheduled: hourly via QM_StrategyFarm_GmailAlarm_Hourly. NOT every 15min
to keep traffic low — if a critical FAIL appears 5min after a check, you
see it within an hour, and the cockpit banner is immediate anyway.
"""

from __future__ import annotations

import datetime as dt
import html
import json
import smtplib
import sys
import time
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

# Brand palette — mirrors render_cockpit.py (Direction C "Unified Neutral",
# OWNER-DL 2026-07-20: paper-light bg, white card, ONE steel-blue accent,
# TRUE red/green P&L; key names kept for backwards compatibility —
# "emerald" now holds the status/profit GREEN, "accent" is the brand blue).
PALETTE = {
    "bg":           "#f6f5f2",
    "surface_0":    "#efece3",
    "surface_1":    "#ffffff",
    "surface_2":    "#f1efe8",
    "border":       "#e2ded4",
    "text":         "#1c1a16",
    "text_dim":     "#45403a",
    "text_muted":   "#726b60",
    "text_subtle":  "#9a938a",
    "emerald":      "#1a8f4c",
    "emerald_dark": "#14713c",
    "warn":         "#b8720a",
    "fail":         "#d13438",
    "info":         "#2954d4",
    "live":         "#0e7490",
    "accent":       "#2954d4",
}
FONT_STACK = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, sans-serif"
MONO_STACK = "'Source Code Pro', ui-monospace, 'SF Mono', Menlo, monospace"

ROOT = Path(r"D:\QM\strategy_farm")
HEALTH_FILE = ROOT / "state" / "health.json"
STATE_FILE = ROOT / "state" / "gmail_alarm_state.json"
DASHBOARDS_DIR = ROOT / "dashboards"
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
        health = json.loads(HEALTH_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}
    # Silent-failure meta-monitor (task #11, 2026-07-19): fold its alarm sidecar
    # into the health dict so the existing fingerprint/one-mail-per-change logic
    # covers the silent classes (task deaths, skip-streaks, lane stalls) too.
    # A missing/stale sidecar injects its own staleness FAIL inside the merge.
    try:
        import silent_failure_monitor
        health = silent_failure_monitor.merge_into_health(health)
    except Exception:
        pass
    return health


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
    # Generic by check name, so new resilience categories such as
    # disk_free_gb and p_pass_stagnation automatically produce a new alarm
    # fingerprint when they appear or clear.
    overall = health.get("overall", "?")
    fails = frozenset(
        c["name"] for c in (health.get("checks") or []) if c.get("status") == "FAIL"
    )
    return overall, fails


def _build_mail_body(health: dict) -> tuple[str, str, str]:
    """Return (subject, text_body, html_body) — text is fallback, html is primary."""
    overall = health.get("overall", "?")
    summary = health.get("summary", {})
    fails = [c for c in (health.get("checks") or []) if c.get("status") == "FAIL"]
    warns = [c for c in (health.get("checks") or []) if c.get("status") == "WARN"]
    checked = health.get("checked_at", "?")

    subject = f"[QM Strategy Farm] PIPELINE {overall} — {len(fails)} FAIL · {len(warns)} WARN"

    # ── Plain text fallback (for readers without HTML) ───────
    text_lines = [
        f"QuantMechanica · Strategy Farm",
        f"Pipeline health overall: {overall}",
        f"Checked at: {checked}",
        f"Summary: {summary.get('fail', 0)} FAIL  ·  {summary.get('warn', 0)} WARN  ·  {summary.get('ok', 0)} OK",
        "",
    ]
    if fails:
        text_lines.append("--- FAIL ---")
        for c in fails:
            text_lines.append(f"  • {c['name']}")
            text_lines.append(f"      {c.get('detail', '')}")
            if c.get("action_hint"):
                text_lines.append(f"      → {c['action_hint']}")
            text_lines.append("")
    if warns:
        text_lines.append("--- WARN ---")
        for c in warns:
            text_lines.append(f"  • {c['name']}: {c.get('detail', '')}")
        text_lines.append("")
    text_lines.append("Cockpit: file:///D:/QM/strategy_farm/dashboards/cockpit.html")
    text_lines.append("Brief:   file:///D:/QM/strategy_farm/dashboards/morning_brief.md")
    text_body = "\n".join(text_lines)

    # ── HTML body (QM-branded) ────────────────────────────────
    P = PALETTE
    overall_color = (
        P["fail"] if overall == "FAIL"
        else P["warn"] if overall == "WARN"
        else P["emerald"]
    )
    overall_label = {
        "FAIL": "ATTENTION REQUIRED",
        "WARN": "WATCH",
        "OK":   "ALL GREEN",
    }.get(overall, overall)

    # Stat triplet (red / yellow / green count)
    stat_cells = ""
    for label, value, color in [
        ("RED",    summary.get("fail", 0), P["fail"]),
        ("YELLOW", summary.get("warn", 0), P["warn"]),
        ("GREEN",  summary.get("ok", 0),   P["emerald"]),
    ]:
        stat_cells += (
            f'<td valign="top" align="center" '
            f'style="padding:12px 8px;background:{P["surface_2"]};'
            f'border-radius:6px;border:1px solid {P["border"]};">'
            f'<div style="font-size:10px;color:{P["text_muted"]};'
            f'text-transform:uppercase;letter-spacing:1.5px;font-weight:600;">{label}</div>'
            f'<div style="font-size:28px;color:{color};font-weight:700;'
            f'font-family:{MONO_STACK};margin-top:4px;line-height:1;">{value}</div>'
            f'</td>'
        )

    # FAIL cards
    fail_html = ""
    for c in fails:
        hint_html = ""
        if c.get("action_hint"):
            hint_html = (
                f'<div style="margin-top:8px;padding:8px 10px;'
                f'background:{P["surface_0"]};border-left:3px solid {P["fail"]};'
                f'border-radius:4px;font-size:12px;color:{P["text_dim"]};'
                f'font-family:{MONO_STACK};">'
                f'→ {html.escape(c["action_hint"])}'
                f'</div>'
            )
        fail_html += (
            f'<tr><td style="padding:14px 18px;border-top:1px solid {P["border"]};">'
            f'<div style="font-size:11px;color:{P["fail"]};'
            f'text-transform:uppercase;letter-spacing:1.5px;font-weight:700;">FAIL</div>'
            f'<div style="font-size:14px;color:{P["text"]};font-weight:600;'
            f'font-family:{MONO_STACK};margin-top:3px;">{html.escape(c["name"])}</div>'
            f'<div style="font-size:13px;color:{P["text_dim"]};margin-top:6px;'
            f'line-height:1.5;">{html.escape(c.get("detail", ""))}</div>'
            f'{hint_html}'
            f'</td></tr>'
        )

    warn_html = ""
    for c in warns:
        warn_html += (
            f'<tr><td style="padding:10px 18px;border-top:1px solid {P["border"]};">'
            f'<div style="font-size:11px;color:{P["warn"]};'
            f'text-transform:uppercase;letter-spacing:1.5px;font-weight:600;">WARN</div>'
            f'<div style="font-size:13px;color:{P["text"]};font-weight:500;'
            f'font-family:{MONO_STACK};margin-top:3px;">{html.escape(c["name"])}</div>'
            f'<div style="font-size:12px;color:{P["text_muted"]};margin-top:4px;'
            f'line-height:1.5;">{html.escape(c.get("detail", ""))}</div>'
            f'</td></tr>'
        )

    body_html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:{P['bg']};font-family:{FONT_STACK};color:{P['text']};">
<table cellpadding="0" cellspacing="0" border="0" width="100%" style="background:{P['bg']};">
<tr><td align="center" style="padding:24px 12px;">
<table cellpadding="0" cellspacing="0" border="0" width="640" style="max-width:640px;background:{P['surface_1']};border-radius:12px;border:1px solid {P['border']};">

  <!-- Header -->
  <tr><td style="padding:22px 26px 18px;border-bottom:1px solid {P['border']};">
    <table cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
      <td>
        <div style="font-size:10px;letter-spacing:2px;color:{P['accent']};text-transform:uppercase;font-weight:700;">QuantMechanica · Strategy Farm</div>
        <div style="font-size:22px;color:{P['text']};font-weight:600;margin-top:4px;">Pipeline Health Alert</div>
      </td>
      <td align="right" valign="top">
        <span style="display:inline-block;padding:5px 12px;background:{overall_color};color:{P['surface_0']};border-radius:14px;font-size:11px;font-weight:700;letter-spacing:1.5px;">{overall_label}</span>
      </td>
    </tr></table>
    <div style="font-size:11px;color:{P['text_subtle']};font-family:{MONO_STACK};margin-top:10px;">Checked {html.escape(checked)}</div>
  </td></tr>

  <!-- Stats triplet -->
  <tr><td style="padding:18px 26px;">
    <table cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
      {stat_cells}
    </tr></table>
  </td></tr>

  <!-- FAILs -->
  {('<tr><td style="padding:0 0 0 0;">' + fail_html + '</td></tr>') if fail_html else ''}

  <!-- WARNs -->
  {('<tr><td style="padding:0 0 0 0;">' + warn_html + '</td></tr>') if warn_html else ''}

  <!-- Footer / links -->
  <tr><td style="padding:18px 26px;border-top:1px solid {P['border']};background:{P['surface_0']};border-radius:0 0 12px 12px;">
    <div style="font-size:11px;color:{P['text_muted']};line-height:1.7;">
      <div><span style="color:{P['text_subtle']};">Cockpit:</span> <span style="color:{P['text_dim']};font-family:{MONO_STACK};">file:///D:/QM/strategy_farm/dashboards/cockpit.html</span></div>
      <div><span style="color:{P['text_subtle']};">Brief:</span> <span style="color:{P['text_dim']};font-family:{MONO_STACK};">file:///D:/QM/strategy_farm/dashboards/morning_brief.md</span></div>
      <div style="margin-top:8px;font-size:10px;color:{P['text_subtle']};">Sent by QM_StrategyFarm_GmailAlarm_Hourly · debounced on fingerprint change · <a style="color:{P['emerald']};text-decoration:none;" href="file:///D:/QM/strategy_farm/state/health_alarms.log">alarms log</a></div>
    </div>
  </td></tr>

</table>
</td></tr>
</table>
</body></html>"""
    return subject, text_body, body_html


def _send_mail(subject: str, text_body: str, html_body: str | None = None) -> dict:
    """Send via Gmail SMTP. Multipart/alternative with text fallback + HTML."""
    if not APP_PASSWORD_FILE.exists() or not SENDER_FILE.exists():
        return {"sent": False, "reason": "Gmail credentials missing in .private/secrets/"}
    try:
        password = APP_PASSWORD_FILE.read_text(encoding="utf-8").strip()
        sender = SENDER_FILE.read_text(encoding="utf-8").strip()
    except Exception as exc:
        return {"sent": False, "reason": f"reading creds failed: {exc!r}"}
    if html_body:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = sender
        msg["To"] = RECIPIENT
        msg.attach(MIMEText(text_body, "plain", "utf-8"))
        msg.attach(MIMEText(html_body, "html", "utf-8"))
    else:
        msg = MIMEText(text_body, "plain", "utf-8")
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
    return {"sent": True, "subject": subject, "html": bool(html_body)}


def _send_mail_with_retries(subject: str, text_body: str, html_body: str | None = None,
                            attempts: int = 3, base_delay_sec: float = 2.0) -> dict:
    last: dict = {"sent": False, "reason": "not attempted"}
    for attempt in range(1, attempts + 1):
        last = _send_mail(subject, text_body, html_body)
        last["attempt"] = attempt
        if last.get("sent"):
            return last
        if attempt < attempts:
            time.sleep(base_delay_sec * (2 ** (attempt - 1)))
    DASHBOARDS_DIR.mkdir(parents=True, exist_ok=True)
    fail_flag = DASHBOARDS_DIR / f"HEUREKA_PIPELINE_GMAIL_FAILED_{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.md"
    fail_flag.write_text(
        "# Gmail Alarm Failed\n\n"
        f"Subject: {subject}\n\n"
        f"Last result: `{json.dumps(last, sort_keys=True)}`\n",
        encoding="utf-8",
    )
    return {**last, "sent": False, "attempts": attempts, "fail_flag": str(fail_flag)}


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
        text_body = (
            f"All previously-failing invariants now green.\n"
            f"Checked at: {health.get('checked_at', '?')}\n"
            f"Cockpit: file:///D:/QM/strategy_farm/dashboards/cockpit.html\n"
        )
        P = PALETTE
        html_body = (
            f'<!DOCTYPE html><html><body style="margin:0;padding:0;background:{P["bg"]};'
            f'font-family:{FONT_STACK};color:{P["text"]};">'
            f'<table cellpadding="0" cellspacing="0" border="0" width="100%" '
            f'style="background:{P["bg"]};"><tr><td align="center" style="padding:24px 12px;">'
            f'<table cellpadding="0" cellspacing="0" border="0" width="640" '
            f'style="max-width:640px;background:{P["surface_1"]};border-radius:12px;'
            f'border:1px solid {P["border"]};">'
            f'<tr><td style="padding:28px 28px;text-align:center;">'
            f'<div style="font-size:10px;letter-spacing:2px;color:{P["accent"]};'
            f'text-transform:uppercase;font-weight:700;">QuantMechanica · Strategy Farm</div>'
            f'<div style="font-size:36px;color:{P["emerald"]};font-weight:700;'
            f'margin-top:14px;letter-spacing:1px;">ALL GREEN</div>'
            f'<div style="font-size:14px;color:{P["text_dim"]};margin-top:10px;'
            f'line-height:1.5;">All previously-failing invariants are now green. '
            f'Pipeline is healthy — no action required.</div>'
            f'<div style="font-size:11px;color:{P["text_subtle"]};margin-top:18px;'
            f'font-family:{MONO_STACK};">Checked {html.escape(health.get("checked_at","?"))}</div>'
            f'</td></tr></table></td></tr></table></body></html>'
        )
    else:
        subject, text_body, html_body = _build_mail_body(health)

    result = _send_mail_with_retries(subject, text_body, html_body)
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
