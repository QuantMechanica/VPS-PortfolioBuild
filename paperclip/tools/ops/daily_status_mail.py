"""Daily QuantMechanica status email to OWNER.

Pure Python: aggregates from local Paperclip API (loopback, no auth in local_trusted)
and sends via Gmail SMTP using the app password in .private/secrets/.

HTML body uses brand tokens from branding/brand_tokens.json (inline CSS for Gmail
compatibility); plain-text fallback included as multipart/alternative.

Designed to be run by Windows Task Scheduler at 23:00 Europe/Vienna daily.
"""
import json
import smtplib
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from html import escape
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# --- Config ---
REPO_ROOT = Path(r"C:/QM/repo")
SECRETS_DIR = REPO_ROOT / ".private" / "secrets"
APP_PASSWORD_FILE = SECRETS_DIR / "gmail_app_password.txt"
SENDER_FILE = SECRETS_DIR / "gmail_sender.txt"
RECIPIENT = "fabian.grabner@gmail.com"
LOG_DIR = REPO_ROOT / "docs" / "ops"

API = "http://127.0.0.1:3100/api"
COMPANY = "03d4dcc8-4cea-4133-9f68-90c0d99628fb"

SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587

# --- Brand palette (from branding/brand_tokens.json) ---
PALETTE = {
    "bg":           "#020617",
    "surface_0":    "#060b18",
    "surface_1":    "#0f172a",
    "surface_2":    "#1e293b",
    "border":       "rgba(148,163,184,0.18)",
    "text":         "#f8fafc",
    "text_dim":     "#cbd5e1",
    "text_muted":   "#94a3b8",
    "text_subtle":  "#64748b",
    "emerald":      "#10b981",
    "emerald_dark": "#059669",
    "warn":         "#f59e0b",
    "fail":         "#ef4444",
    "info":         "#3b82f6",
    "live":         "#06b6d4",
}
FONT_STACK = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, sans-serif"
MONO_STACK = "'Source Code Pro', ui-monospace, 'SF Mono', Menlo, monospace"

# Status → color mapping
STATUS_COLOR = {
    "todo":         PALETTE["info"],
    "in_progress":  PALETTE["live"],
    "in_review":    PALETTE["warn"],
    "blocked":      PALETTE["fail"],
    "done":         PALETTE["emerald"],
    "cancelled":    PALETTE["text_subtle"],
    "backlog":      PALETTE["text_muted"],
}

PRIORITY_COLOR = {
    "critical": PALETTE["fail"],
    "high":     PALETTE["warn"],
    "medium":   PALETTE["info"],
    "low":      PALETTE["text_subtle"],
}


# --- Helpers ---

def load_secret(path: Path, what: str) -> str:
    if not path.exists():
        raise SystemExit(f"missing {what}: {path}")
    return path.read_text(encoding="utf-8").strip()


def safe_fetch(url: str, default=None):
    try:
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError) as e:
        return default if default is not None else {"_error": str(e)}


def quota_color(pct):
    if pct is None:
        return PALETTE["text_muted"]
    if pct < 60:
        return PALETTE["emerald"]
    if pct < 85:
        return PALETTE["warn"]
    return PALETTE["fail"]


def fmt_resets(resets_at: str | None) -> str:
    if not resets_at:
        return "—"
    if "T" in resets_at:
        date_part, time_part = resets_at.split("T", 1)
        time_short = time_part[:5]
        return f"{date_part} {time_short}"
    return resets_at


# --- Status aggregation ---

def gather_quota() -> dict:
    data = safe_fetch(f"{API}/companies/{COMPANY}/costs/quota-windows", default=[])
    if isinstance(data, dict) and "_error" in data:
        return {"error": data["_error"]}
    out = {"anthropic": [], "openai": []}
    for block in data:
        provider = block.get("provider")
        if provider not in out:
            continue
        for w in block.get("windows") or []:
            out[provider].append({
                "label": w.get("label"),
                "used": w.get("usedPercent"),
                "resets": w.get("resetsAt"),
                "value_label": w.get("valueLabel"),
            })
    return out


def gather_phase_state() -> dict:
    candidates = [
        Path(r"C:/QM/paperclip/governance/PHASE_STATE.md"),
        REPO_ROOT.parent / "paperclip" / "governance" / "PHASE_STATE.md",
    ]
    for c in candidates:
        if c.exists():
            text = c.read_text(encoding="utf-8", errors="ignore")
            entry = {}
            if "## Live Entry" in text:
                section = text.split("## Live Entry", 1)[1].split("\n## ", 1)[0]
                # Parse the markdown table
                for line in section.splitlines():
                    if line.startswith("| **") and "** |" in line:
                        parts = line.split("|")
                        if len(parts) >= 3:
                            key = parts[1].strip().strip("*").strip()
                            val = parts[2].strip()
                            entry[key] = val
            return entry
    return {}


def gather_pipeline_status() -> dict:
    """EA inventory + phase distribution + Strategy Card counts."""
    eas_dir = Path(r"C:/QM/repo/framework/EAs")
    reports_dir = Path(r"D:/QM/reports/pipeline")

    if not eas_dir.exists():
        return {"error": "framework/EAs not found"}

    eas = sorted([d.name for d in eas_dir.iterdir() if d.is_dir()])
    # Map EA dir name → reports dir name (reports use short IDs like QM5_1003 vs full QM5_1003_davey_baseline_3bar)
    report_dirs = []
    if reports_dir.exists():
        report_dirs = [d.name for d in reports_dir.iterdir() if d.is_dir()]

    def find_report_dir(ea_name: str) -> Path | None:
        # Try full name first
        if ea_name in report_dirs:
            return reports_dir / ea_name
        # Try prefix matching against known report dirs (e.g., QM5_1003 matches QM5_1003_davey_baseline_3bar)
        for rd in report_dirs:
            if ea_name.startswith(rd) or rd.startswith(ea_name.split("_lien")[0].split("_davey")[0].split("_chan")[0]):
                if reports_dir.joinpath(rd).is_dir():
                    return reports_dir / rd
        return None

    ea_phases = {}
    for ea in eas:
        ea_report = find_report_dir(ea)
        max_phase = 0
        has_ex5 = (eas_dir / ea / f"{ea}.ex5").exists()
        if ea_report and ea_report.exists():
            for p in ea_report.iterdir():
                if p.is_dir() and p.name.startswith("P"):
                    try:
                        phase_num_str = p.name[1:].split("_")[0]
                        # Handle P3.5 etc — take integer part
                        phase_num = int(phase_num_str.split(".")[0])
                        if phase_num > max_phase:
                            max_phase = phase_num
                    except (ValueError, IndexError):
                        pass
        ea_phases[ea] = {"max_phase": max_phase, "compiled": has_ex5}

    # Phase distribution
    phase_dist = {}
    for ea, info in ea_phases.items():
        p = info["max_phase"]
        phase_dist[p] = phase_dist.get(p, 0) + 1

    # Strategy Card metrics from issues + filesystem
    cards_g0_done = 0
    cards_research_open = 0
    issues = safe_fetch(f"{API}/companies/{COMPANY}/issues?limit=600", default=[])
    if isinstance(issues, dict):
        issues = issues.get("data", [])
    g0_keywords = ("g0", "strategy card", "src0")
    for i in issues:
        title = (i.get("title") or "").lower()
        if not any(k in title for k in g0_keywords):
            continue
        if i.get("status") == "done":
            cards_g0_done += 1
        elif i.get("status") in ("todo", "in_progress", "in_review"):
            cards_research_open += 1

    # G1 approved = EAs that have a REVIEW_INPUT.json (= graduated from card to scaffold)
    cards_g1_approved = sum(1 for ea in eas if (eas_dir / ea / "REVIEW_INPUT.json").exists())

    return {
        "eas_total": len(eas),
        "ea_phases": ea_phases,
        "phase_distribution": phase_dist,
        "strategy_cards_g0_done": cards_g0_done,
        "strategy_cards_research_open": cards_research_open,
        "cards_g1_approved": cards_g1_approved,
    }


def gather_mt5_status() -> dict:
    """Count active MT5 terminals via tasklist. Active = mem > 500MB (running backtest)."""
    import subprocess
    try:
        result = subprocess.run(
            "tasklist /FI \"IMAGENAME eq terminal64.exe\" /FO CSV /NH",
            capture_output=True, text=True, timeout=30, shell=True
        )
        terminals = []
        for line in result.stdout.splitlines():
            if "terminal64" not in line.lower():
                continue
            parts = [p.strip('"').strip() for p in line.split(",")]
            if len(parts) < 5:
                continue
            mem_str = parts[4].replace(" K", "").replace(",", "").replace(".", "").strip()
            try:
                mem_kb = int(mem_str)
            except ValueError:
                continue
            terminals.append({"pid": parts[1], "mem_kb": mem_kb, "active": mem_kb > 500_000})
        active = sum(1 for t in terminals if t["active"])
        return {"active": active, "total": len(terminals), "terminals": terminals}
    except Exception as e:
        return {"error": str(e), "active": 0, "total": 0}


def gather_heureka_distance(pipeline: dict) -> dict:
    """Distance to first Heureka: 1 EA P0..P8 PASS + DXZ-compliance + T6 live."""
    if "error" in pipeline:
        return {"error": pipeline["error"]}
    # Best alive EA = highest max_phase among non-cancelled
    best_ea = None
    best_phase = 0
    for ea, info in pipeline.get("ea_phases", {}).items():
        if "1003" in ea:  # killed per QT verdict 2026-05-09
            continue
        if info["max_phase"] > best_phase:
            best_phase = info["max_phase"]
            best_ea = ea
    return {
        "best_ea": best_ea,
        "best_phase": best_phase,
        "phases_remaining": max(0, 8 - best_phase),
        "dxz_gate_built": False,  # tracked via QUA-1082
        "t6_promoted": False,
    }


def gather_today_summary() -> dict:
    """Issues created/closed today, commits today (for narrative tone)."""
    today_iso = datetime.now(timezone.utc).date().isoformat()
    issues = safe_fetch(f"{API}/companies/{COMPANY}/issues?limit=600", default=[])
    if isinstance(issues, dict):
        issues = issues.get("data", [])
    closed_today = sum(1 for i in issues if (i.get("completedAt") or "")[:10] == today_iso)
    created_today = sum(1 for i in issues if (i.get("createdAt") or "")[:10] == today_iso)
    blocked_now = sum(1 for i in issues if i.get("status") == "blocked")
    in_progress_now = sum(1 for i in issues if i.get("status") == "in_progress")
    return {
        "today": today_iso,
        "closed_today": closed_today,
        "created_today": created_today,
        "blocked_now": blocked_now,
        "in_progress_now": in_progress_now,
    }


def render_narrative(pipeline: dict, sprint: dict, today_summary: dict, quota: dict, phase_state: dict) -> str:
    """Generate a 3-5 sentence narrative paragraph based on the day's signals."""
    sprint_pct = int(100 * sprint["done"] / sprint["total"]) if sprint["total"] else 0
    closed = today_summary["closed_today"]
    blocked = today_summary["blocked_now"]

    # Tone classification from signals
    if closed >= 5 and sprint_pct >= 50:
        tone = "produktiv"
    elif closed >= 3:
        tone = "solide"
    elif blocked > 5:
        tone = "von Blockern geprägt"
    elif today_summary["in_progress_now"] >= 5:
        tone = "geschäftig"
    else:
        tone = "ruhig"

    # Codex weekly trajectory
    codex_weekly = next(
        (w["used"] for w in quota.get("openai", []) if "Weekly" in (w.get("label") or "")),
        None,
    )
    codex_note = ""
    if codex_weekly is not None:
        if codex_weekly >= 90:
            codex_note = f" Codex-Weekly bei {codex_weekly}% — kritisch nahe Cap."
        elif codex_weekly >= 75:
            codex_note = f" Codex-Weekly bei {codex_weekly}% — auf der Beobachtungsliste."

    # Phase 3 status fragment
    phase_fragment = ""
    current_phase = phase_state.get("Current phase", "")
    if "Phase 3" in current_phase:
        phase_fragment = f" Phase 3 läuft auf der ersten EA durch die Pipeline."
    elif current_phase:
        phase_fragment = f" Aktuell {current_phase}."

    # Goal context
    eas = pipeline.get("eas_total", 0)
    g1 = pipeline.get("cards_g1_approved", 0)
    g0 = pipeline.get("strategy_cards_g0_done", 0)
    goal_fragment = f"Im Pipeline: {eas} EAs gebaut, {g1} G1-approved, {g0} G0-Karten extrahiert."

    return (
        f"Heute war ein {tone}r Tag: {closed} Issues geschlossen, "
        f"{today_summary['created_today']} eröffnet, {today_summary['in_progress_now']} laufen, "
        f"{blocked} blockiert. Sprint ist auf {sprint['done']}/{sprint['total']} ({sprint_pct}%).{phase_fragment}{codex_note} "
        f"{goal_fragment} Ziel-Distanz: noch ~{max(0, 5 - g1)} EAs bis Portfolio-Basket (Phase 4 Voraussetzung)."
    )


def render_goal_progress(pipeline: dict) -> tuple[str, str]:
    """Render phase progress bar Phase 0 → Phase 5 (live)."""
    P = PALETTE
    # Hard-coded company state per PHASE_STATE.md
    phases = [
        ("Phase 0", "Foundation", "done"),
        ("Phase 1", "Paperclip Bootstrap", "done"),
        ("Phase 2", "V5 Framework", "done"),
        ("Phase 3", "First EA Through Pipeline", "active"),
        ("Phase 4", "Portfolio Build", "pending"),
        ("Phase 5", "Live on T6", "pending"),
    ]
    cells = []
    for label, name, status in phases:
        if status == "done":
            color = P["emerald"]
            bg = "rgba(16,185,129,0.15)"
            icon = "✓"
        elif status == "active":
            color = P["live"]
            bg = "rgba(6,182,212,0.20)"
            icon = "▶"
        else:
            color = P["text_subtle"]
            bg = P["surface_2"]
            icon = "○"
        cells.append(f"""
<td align="center" style="padding:10px 6px;background:{bg};border-radius:6px;border:1px solid {P['border']};">
  <div style="font-size:18px;color:{color};font-weight:600;">{icon}</div>
  <div style="font-size:10px;color:{color};font-weight:700;letter-spacing:1px;margin-top:4px;">{escape(label)}</div>
  <div style="font-size:10px;color:{P['text_muted']};margin-top:2px;">{escape(name)}</div>
</td>""")
    spacer = '<td style="width:6px;font-size:0;line-height:0;">&nbsp;</td>'
    return spacer.join(cells), ""


def gather_active_issues(limit: int = 8) -> list:
    data = safe_fetch(f"{API}/companies/{COMPANY}/issues?limit=200", default=[])
    if isinstance(data, dict):
        data = data.get("data", [])
    open_issues = [
        i for i in data
        if i.get("status") in ("todo", "in_progress", "in_review", "blocked")
    ]
    priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    open_issues.sort(
        key=lambda i: (
            priority_order.get((i.get("priority") or "low").lower(), 99),
            -(int((i.get("updatedAt") or "0").replace("-", "").replace(":", "").replace("T", "").replace("Z", "")[:14] or 0)),
        )
    )
    return open_issues[:limit]


def gather_sprint_progress() -> dict:
    """QUA-1024 sprint children."""
    data = safe_fetch(f"{API}/companies/{COMPANY}/issues?limit=600", default=[])
    if isinstance(data, dict):
        data = data.get("data", [])
    sprint = []
    for ident in ["QUA-1024", "QUA-1026", "QUA-1027", "QUA-1028", "QUA-1029",
                  "QUA-1030", "QUA-1031", "QUA-1032", "QUA-1058", "QUA-1059",
                  "QUA-1060", "QUA-1061", "QUA-1062", "QUA-1063"]:
        i = next((x for x in data if x.get("identifier") == ident), None)
        if i:
            sprint.append({
                "id": ident,
                "status": i.get("status"),
                "title": i.get("title", "")[:60],
            })
    return {
        "items": sprint,
        "done": sum(1 for s in sprint if s["status"] == "done"),
        "total": len(sprint),
    }


def gather_agents() -> dict:
    data = safe_fetch(f"{API}/companies/{COMPANY}/agents", default=[])
    if isinstance(data, dict):
        data = data.get("data", [])
    by_status = {}
    for a in data:
        s = a.get("status") or "unknown"
        by_status[s] = by_status.get(s, 0) + 1
    return {"total": len(data), "by_status": by_status}


# --- HTML rendering ---

def render_quota_bar(used_pct, label: str, resets: str, value_label: str | None) -> str:
    color = quota_color(used_pct)
    pct = used_pct if used_pct is not None else 0
    bar_width = max(0, min(100, pct))
    pct_text = f"{used_pct}%" if used_pct is not None else (value_label or "—")
    resets_text = fmt_resets(resets)
    return f"""
<tr>
  <td style="padding:8px 12px;color:{PALETTE['text_dim']};font-size:13px;width:48%;">{escape(label)}</td>
  <td style="padding:8px 0;width:32%;">
    <table cellpadding="0" cellspacing="0" border="0" width="100%" style="background:{PALETTE['surface_0']};border-radius:4px;height:8px;">
      <tr><td style="background:{color};width:{bar_width}%;height:8px;border-radius:4px;font-size:0;line-height:0;">&nbsp;</td>
          <td style="width:{100-bar_width}%;height:8px;font-size:0;line-height:0;">&nbsp;</td></tr>
    </table>
  </td>
  <td style="padding:8px 12px;text-align:right;font-family:{MONO_STACK};font-size:13px;color:{color};font-weight:600;">{escape(pct_text)}</td>
  <td style="padding:8px 12px;text-align:right;color:{PALETTE['text_subtle']};font-size:11px;font-family:{MONO_STACK};">{escape(resets_text)}</td>
</tr>
"""


def render_status_badge(status: str) -> str:
    color = STATUS_COLOR.get(status, PALETTE["text_muted"])
    return (
        f'<span style="display:inline-block;padding:2px 8px;border-radius:10px;'
        f'background:{color}22;color:{color};font-size:11px;'
        f'font-family:{MONO_STACK};font-weight:600;">{escape(status)}</span>'
    )


def render_priority_badge(priority: str) -> str:
    color = PRIORITY_COLOR.get((priority or "low").lower(), PALETTE["text_muted"])
    return (
        f'<span style="display:inline-block;padding:1px 6px;border-radius:3px;'
        f'background:{color}22;color:{color};font-size:10px;'
        f'font-family:{MONO_STACK};font-weight:700;text-transform:uppercase;">{escape(priority)}</span>'
    )


def render_html() -> tuple[str, str]:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    today_h = datetime.now().strftime("%A, %d. %B %Y")
    quota = gather_quota()
    issues = gather_active_issues(limit=8)
    sprint = gather_sprint_progress()
    agents = gather_agents()
    phase = gather_phase_state()
    pipeline = gather_pipeline_status()
    today_summary = gather_today_summary()
    mt5 = gather_mt5_status()
    heureka = gather_heureka_distance(pipeline)
    narrative = render_narrative(pipeline, sprint, today_summary, quota, phase)
    goal_cells, _ = render_goal_progress(pipeline)

    subject = f"📊 QuantMechanica — Status {today}"

    P = PALETTE

    # Header
    html_parts = [f"""
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:{P['bg']};font-family:{FONT_STACK};color:{P['text']};">
<table cellpadding="0" cellspacing="0" border="0" width="100%" style="background:{P['bg']};">
<tr><td align="center" style="padding:24px 12px;">
<table cellpadding="0" cellspacing="0" border="0" width="640" style="max-width:640px;background:{P['surface_1']};border-radius:12px;border:1px solid {P['border']};">
<tr><td style="padding:24px 28px 20px;border-bottom:1px solid {P['border']};">
  <table cellpadding="0" cellspacing="0" border="0" width="100%">
  <tr>
    <td>
      <div style="font-size:11px;letter-spacing:2px;color:{P['emerald']};text-transform:uppercase;font-weight:700;">QuantMechanica V5</div>
      <div style="font-size:24px;color:{P['text']};font-weight:600;margin-top:4px;">Daily Status</div>
      <div style="font-size:13px;color:{P['text_muted']};margin-top:4px;">{escape(today_h)}</div>
    </td>
    <td align="right" valign="top">
      <div style="font-size:11px;color:{P['text_subtle']};font-family:{MONO_STACK};">{escape(today)}</div>
    </td>
  </tr>
  </table>
</td></tr>
"""]

    # Narrative opening
    html_parts.append(f"""
<tr><td style="padding:20px 28px;">
  <div style="font-size:11px;color:{P['emerald']};text-transform:uppercase;letter-spacing:1px;font-weight:700;margin-bottom:8px;">Tageszusammenfassung</div>
  <div style="font-size:14px;color:{P['text_dim']};line-height:1.6;">{escape(narrative)}</div>
</td></tr>
""")

    # Goal progress (Phase 0 → Phase 5)
    html_parts.append(f"""
<tr><td style="padding:0 28px 20px 28px;">
  <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-bottom:10px;">Pfad zum Ziel — Portfolio Live</div>
  <table cellpadding="0" cellspacing="0" border="0" width="100%">
    <tr>{goal_cells}</tr>
  </table>
</td></tr>
""")

    # Mission Progress: MT5 saturation + Heureka distance
    mt5_active = mt5.get("active", 0)
    mt5_total = mt5.get("total", 0)
    sat_color = (
        P["emerald"] if mt5_active >= 4
        else P["warn"] if mt5_active >= 2
        else P["fail"]
    )
    sat_pct = int(100 * mt5_active / max(1, mt5_total))
    best_ea = heureka.get("best_ea") or "—"
    best_phase = heureka.get("best_phase", 0)
    phase_label = f"P{best_phase}" if best_phase > 0 else "—"
    phases_remaining = heureka.get("phases_remaining", 8)
    html_parts.append(f"""
<tr><td style="padding:20px 28px;border-top:1px solid {P['border']};">
  <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-bottom:12px;">Mission Progress</div>
  <table cellpadding="0" cellspacing="0" border="0" width="100%">
    <tr>
      <td valign="top" style="padding:12px;background:{P['surface_2']};border-radius:6px;border:1px solid {P['border']};width:33%;">
        <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;">MT5 Saturation</div>
        <div style="font-size:32px;font-weight:600;color:{sat_color};font-family:{MONO_STACK};margin-top:4px;">
          {mt5_active}<span style="color:{P['text_subtle']};font-size:18px;font-weight:400;"> / {mt5_total}</span>
        </div>
        <div style="font-size:11px;color:{P['text_muted']};margin-top:2px;">
          {'aktiv backtesting' if mt5_active >= 1 else '🔴 idle (Mission alarm)'}
        </div>
      </td>
      <td style="width:8px;font-size:0;">&nbsp;</td>
      <td valign="top" style="padding:12px;background:{P['surface_2']};border-radius:6px;border:1px solid {P['border']};width:33%;">
        <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;">Best alive EA</div>
        <div style="font-size:13px;font-weight:600;color:{P['text']};font-family:{MONO_STACK};margin-top:6px;">{escape(best_ea[:24])}</div>
        <div style="font-size:11px;color:{P['text_muted']};margin-top:6px;">
          aktuell <span style="color:{P['live']};font-family:{MONO_STACK};font-weight:600;">{phase_label}</span> · noch <span style="color:{P['warn']};font-family:{MONO_STACK};">{phases_remaining}</span> Phasen bis P8 PASS
        </div>
      </td>
      <td style="width:8px;font-size:0;">&nbsp;</td>
      <td valign="top" style="padding:12px;background:{P['surface_2']};border-radius:6px;border:1px solid {P['border']};width:33%;">
        <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;">Heureka Distance</div>
        <div style="font-size:11px;color:{P['text_dim']};margin-top:8px;line-height:1.7;">
          {('✓' if best_phase >= 8 else '○')} 1 EA P0..P8 PASS<br/>
          {'✓' if heureka.get('dxz_gate_built') else '○'} Portfolio-DXZ gate<br/>
          {'✓' if heureka.get('t6_promoted') else '○'} T6 Live-Toggle
        </div>
      </td>
    </tr>
  </table>
</td></tr>
""")

    # Pipeline metrics
    if "error" not in pipeline:
        html_parts.append(f"""
<tr><td style="padding:20px 28px;border-top:1px solid {P['border']};">
  <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-bottom:12px;">Strategie-Pipeline</div>
  <table cellpadding="0" cellspacing="0" border="0" width="100%">
    <tr>
      <td align="center" style="padding:12px;background:{P['surface_2']};border-radius:6px;border:1px solid {P['border']};width:25%;">
        <div style="font-size:28px;font-weight:600;color:{P['emerald']};font-family:{MONO_STACK};">{pipeline['eas_total']}</div>
        <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;margin-top:4px;">EAs gebaut</div>
      </td>
      <td style="width:6px;font-size:0;">&nbsp;</td>
      <td align="center" style="padding:12px;background:{P['surface_2']};border-radius:6px;border:1px solid {P['border']};width:25%;">
        <div style="font-size:28px;font-weight:600;color:{P['live']};font-family:{MONO_STACK};">{pipeline['cards_g1_approved']}</div>
        <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;margin-top:4px;">G1 approved</div>
      </td>
      <td style="width:6px;font-size:0;">&nbsp;</td>
      <td align="center" style="padding:12px;background:{P['surface_2']};border-radius:6px;border:1px solid {P['border']};width:25%;">
        <div style="font-size:28px;font-weight:600;color:{P['warn']};font-family:{MONO_STACK};">{pipeline['strategy_cards_g0_done']}</div>
        <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;margin-top:4px;">G0 Karten done</div>
      </td>
      <td style="width:6px;font-size:0;">&nbsp;</td>
      <td align="center" style="padding:12px;background:{P['surface_2']};border-radius:6px;border:1px solid {P['border']};width:25%;">
        <div style="font-size:28px;font-weight:600;color:{P['info']};font-family:{MONO_STACK};">{pipeline['strategy_cards_research_open']}</div>
        <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;margin-top:4px;">In Research</div>
      </td>
    </tr>
  </table>
""")
        # EA-per-phase table
        html_parts.append(f"""
  <table cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-top:14px;font-size:13px;">
    <tr style="border-bottom:1px solid {P['border']};">
      <td style="padding:6px 0;font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;">EA</td>
      <td style="padding:6px 0;font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;text-align:center;">Compiled</td>
      <td style="padding:6px 0;font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;text-align:right;">Höchste Phase</td>
    </tr>
""")
        for ea, info in pipeline["ea_phases"].items():
            phase_label = f"P{info['max_phase']}" if info["max_phase"] > 0 else "—"
            phase_color = (
                P["emerald"] if info["max_phase"] >= 6
                else P["warn"] if info["max_phase"] >= 3
                else P["info"] if info["max_phase"] >= 1
                else P["text_subtle"]
            )
            compiled_icon = "✓" if info["compiled"] else "—"
            compiled_color = P["emerald"] if info["compiled"] else P["text_subtle"]
            html_parts.append(f"""
    <tr style="border-bottom:1px solid {P['border']};">
      <td style="padding:8px 0;color:{P['text_dim']};font-family:{MONO_STACK};font-size:12px;">{escape(ea[:50])}</td>
      <td style="padding:8px 0;text-align:center;color:{compiled_color};">{compiled_icon}</td>
      <td style="padding:8px 0;text-align:right;font-family:{MONO_STACK};font-size:13px;color:{phase_color};font-weight:600;">{phase_label}</td>
    </tr>
""")
        html_parts.append("</table></td></tr>")

    # Sprint progress (most important — show first)
    if sprint["total"] > 0:
        progress_pct = int(100 * sprint["done"] / sprint["total"]) if sprint["total"] else 0
        html_parts.append(f"""
<tr><td style="padding:20px 28px;">
  <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-bottom:10px;">QUA-1024 Sprint Progress</div>
  <table cellpadding="0" cellspacing="0" border="0" width="100%">
    <tr>
      <td style="font-size:32px;font-weight:600;color:{P['emerald']};font-family:{MONO_STACK};">{sprint['done']}<span style="color:{P['text_subtle']};font-size:18px;font-weight:400;"> / {sprint['total']}</span></td>
      <td align="right" style="font-size:13px;color:{P['text_muted']};">{progress_pct}% closed</td>
    </tr>
  </table>
  <table cellpadding="0" cellspacing="0" border="0" width="100%" style="background:{P['surface_0']};border-radius:4px;height:6px;margin-top:8px;">
    <tr>
      <td style="background:{P['emerald']};width:{progress_pct}%;height:6px;border-radius:4px;font-size:0;line-height:0;">&nbsp;</td>
      <td style="width:{100-progress_pct}%;height:6px;font-size:0;line-height:0;">&nbsp;</td>
    </tr>
  </table>
</td></tr>
""")

    # Quota windows
    html_parts.append(f"""
<tr><td style="padding:20px 28px;border-top:1px solid {P['border']};">
  <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-bottom:12px;">Token-Burn — Subscription Limits</div>
""")

    if "error" in quota:
        html_parts.append(f'<div style="color:{P["fail"]};font-size:13px;">Error fetching quota: {escape(quota["error"])}</div>')
    else:
        for provider_label, provider_key, accent in [
            ("Codex (OpenAI)", "openai", P["info"]),
            ("Claude (Anthropic)", "anthropic", P["emerald"]),
        ]:
            windows = quota.get(provider_key, [])
            if not windows:
                continue
            html_parts.append(f"""
  <div style="margin-bottom:16px;">
  <div style="font-size:13px;color:{P['text_dim']};font-weight:600;margin-bottom:6px;">
    <span style="display:inline-block;width:8px;height:8px;background:{accent};border-radius:50%;margin-right:8px;"></span>{escape(provider_label)}
  </div>
  <table cellpadding="0" cellspacing="0" border="0" width="100%" style="background:{P['surface_2']};border-radius:6px;">
""")
            for w in windows:
                html_parts.append(render_quota_bar(w["used"], w["label"], w["resets"], w["value_label"]))
            html_parts.append("</table></div>")

    html_parts.append("</td></tr>")

    # Active issues table
    html_parts.append(f"""
<tr><td style="padding:20px 28px;border-top:1px solid {P['border']};">
  <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-bottom:12px;">Active Issues — Top {len(issues)}</div>
  <table cellpadding="0" cellspacing="0" border="0" width="100%" style="font-size:13px;">
""")
    for i in issues:
        ident = escape(i.get("identifier", "?"))
        status = i.get("status", "?")
        prio = i.get("priority", "low")
        title = escape((i.get("title") or "")[:80])
        asg = i.get("assigneeAgentId", "")[:8] if i.get("assigneeAgentId") else (i.get("assigneeUserId") or "—")
        html_parts.append(f"""
<tr style="border-top:1px solid {P['border']};">
  <td style="padding:10px 0;width:90px;font-family:{MONO_STACK};font-size:12px;color:{P['text']};font-weight:600;">{ident}</td>
  <td style="padding:10px 8px;width:90px;">{render_status_badge(status)}</td>
  <td style="padding:10px 8px;width:62px;">{render_priority_badge(prio)}</td>
  <td style="padding:10px 0;color:{P['text_dim']};">{title}</td>
  <td style="padding:10px 0;text-align:right;font-family:{MONO_STACK};font-size:11px;color:{P['text_subtle']};">{escape(asg)}</td>
</tr>
""")
    html_parts.append("</table></td></tr>")

    # Agent fleet stats
    html_parts.append(f"""
<tr><td style="padding:20px 28px;border-top:1px solid {P['border']};">
  <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-bottom:12px;">Agent Fleet — {agents['total']} total</div>
  <table cellpadding="0" cellspacing="0" border="0" width="100%">
  <tr>
""")
    status_color_map = {
        "running": P["live"], "idle": P["emerald"], "error": P["fail"],
        "paused": P["warn"], "unknown": P["text_subtle"],
    }
    for status, count in sorted(agents["by_status"].items(), key=lambda x: -x[1]):
        color = status_color_map.get(status, P["text_muted"])
        html_parts.append(f"""
    <td align="center" style="padding:8px;background:{P['surface_2']};border-radius:6px;border:1px solid {P['border']};margin:4px;">
      <div style="font-size:24px;font-weight:600;color:{color};font-family:{MONO_STACK};">{count}</div>
      <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;margin-top:2px;">{escape(status)}</div>
    </td>
""")
    html_parts.append("</tr></table></td></tr>")

    # Phase state
    if phase:
        html_parts.append(f"""
<tr><td style="padding:20px 28px;border-top:1px solid {P['border']};">
  <div style="font-size:11px;color:{P['text_muted']};text-transform:uppercase;letter-spacing:1px;font-weight:600;margin-bottom:12px;">Phase State</div>
  <table cellpadding="0" cellspacing="0" border="0" width="100%" style="font-size:13px;">
""")
        for key in ["Current phase", "Closure criterion", "Current blocker", "ETA"]:
            val = phase.get(key, "")
            if not val:
                continue
            html_parts.append(f"""
<tr>
  <td valign="top" style="padding:6px 0;width:140px;color:{P['text_muted']};font-size:12px;">{escape(key)}</td>
  <td style="padding:6px 0;color:{P['text_dim']};font-size:13px;">{escape(val[:240])}</td>
</tr>
""")
        html_parts.append("</table></td></tr>")

    # Footer
    html_parts.append(f"""
<tr><td style="padding:16px 28px;border-top:1px solid {P['border']};font-size:11px;color:{P['text_subtle']};font-family:{MONO_STACK};">
  Generated by paperclip/tools/ops/daily_status_mail.py · Sent at {datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")} from info@quantmechanica.com via Windows Task Scheduler @ 23:00 Europe/Vienna
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>
""")

    html = "".join(html_parts)

    # Plain-text fallback
    text_lines = [f"QuantMechanica V5 — Daily Status {today}", "=" * 60, ""]
    text_lines.append(f"SPRINT QUA-1024: {sprint['done']}/{sprint['total']} children closed")
    text_lines.append("")
    text_lines.append("TOKEN-BURN SNAPSHOT")
    text_lines.append("-" * 60)
    if "error" not in quota:
        for provider_key, provider_label in [("openai", "Codex"), ("anthropic", "Claude")]:
            for w in quota.get(provider_key, []):
                pct = f"{w['used']}%" if w["used"] is not None else (w["value_label"] or "—")
                text_lines.append(f"  {provider_label:8s} | {w['label']:32s} | {pct}")
    text_lines.append("")
    text_lines.append("ACTIVE ISSUES")
    text_lines.append("-" * 60)
    for i in issues:
        text_lines.append(f"  {i.get('identifier','?'):10s} [{i.get('status'):11}] {i.get('priority'):8} {(i.get('title') or '')[:60]}")
    text_lines.append("")
    text_lines.append("AGENT FLEET")
    text_lines.append("-" * 60)
    text_lines.append(f"  Total: {agents['total']}")
    for status, count in sorted(agents["by_status"].items(), key=lambda x: -x[1]):
        text_lines.append(f"    {status}: {count}")

    return subject, html, "\n".join(text_lines)


def send_mail(subject: str, html: str, text: str, sender: str, password: str, recipient: str) -> None:
    msg = MIMEMultipart("alternative")
    msg["From"] = sender
    msg["To"] = recipient
    msg["Subject"] = subject
    msg.attach(MIMEText(text, "plain", "utf-8"))
    msg.attach(MIMEText(html, "html", "utf-8"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as srv:
        srv.starttls()
        srv.login(sender, password)
        srv.sendmail(sender, [recipient], msg.as_string())


def log_failure(reason: str, exc: Exception | None = None) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    log_path = LOG_DIR / f"gmail_send_failures_{today}.json"
    rec = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "reason": reason,
        "exception": repr(exc) if exc else None,
    }
    existing = []
    if log_path.exists():
        try:
            existing = json.loads(log_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            existing = []
    existing.append(rec)
    log_path.write_text(json.dumps(existing, indent=2), encoding="utf-8")


def main() -> int:
    try:
        password = load_secret(APP_PASSWORD_FILE, "Gmail app password")
        sender = load_secret(SENDER_FILE, "Gmail sender address")
    except SystemExit as e:
        print(f"CONFIG ERROR: {e}", file=sys.stderr)
        log_failure(f"config: {e}")
        return 2

    subject, html, text = render_html()
    try:
        send_mail(subject, html, text, sender, password, RECIPIENT)
    except Exception as e:
        print(f"SMTP ERROR: {e!r}", file=sys.stderr)
        log_failure("smtp", e)
        return 1

    print(f"Mail sent: '{subject}' → {RECIPIENT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
