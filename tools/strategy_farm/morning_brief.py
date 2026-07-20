"""Morning briefing — the ONE daily 06:00 mail OWNER reads first thing.

Redesigned 2026-07-19 (OWNER directive, Task #19): content AND design reworked.
Restyled 2026-07-20 (OWNER-DL Direction C "Unified Neutral"): paper-light
palette, steel-blue accent, true red/green P&L — inline CSS kept (mail
clients need it). This script IS the morning mail now — it renders a compact,
scannable paper-light HTML digest and sends exactly ONE mail via the proven Gmail
send path (re-used from gmail_alarm.py: same SMTP host, creds in
.private/secrets/, recipient). It also keeps the Drive-vault archive so OWNER
has a scrollable off-VPS history.

Six sections (German content — OWNER-chat is German), Qxx labels only:
  1. LIVE-BUCH · Nachtbilanz   — DXZ Final-24: deals, EA-emittierte Equity + Δ,
                                  Journal-Alter, aktive EA-Logs /24, Fehler-Zeilen,
                                  FTMO-Status (Trial beendet).
  2. FRONTIER · Kandidaten     — frische Q08/Q09/Q10-PASSes seit gestern 18:00 +
                                  Q07-PASS mit Q08 laufend (nächstes Buch ~26.07.).
  3. FACTORY-AMPEL             — Worker, D:-frei, INFRA-Anteil 24h, FACTORY_OFF.flag
                                  → eine Zeile GRÜN/GELB/ROT (ROT nur echtes Down).
  4. OWNER-ENTSCHEIDUNGEN      — severity=action, fällig ≤ 7 Tage, fällig-sortiert
                                  (gleiche Logik wie das Cockpit).
  5. QUOTA (Woche)             — Claude + Codex Wochen-% (kein 5h-Fenster mehr).
  6. OPS-HEARTBEATS            — Backup / Governor / Purge — je ✓ / ⚠ / ✕.

Data logic is re-used from render_cockpit.py (single source of truth) so the
mail never contradicts the cockpit. The HTML rendering lives here.

Send behaviour:
  * scheduled 06:00 run (no flag)  → renders, writes local + vault, SENDS one mail.
  * --dry-run                      → renders + writes local (+ optional --out),
                                     NO vault write, NO send (safe verification).
  * --out PATH                     → also write the rendered HTML to PATH.

Scheduled task: QM_MorningBriefing_Vault (daily 06:00 local) — unchanged.
"""

from __future__ import annotations

import argparse
import datetime as dt
import html as _html
import json
import re
import shutil
import sqlite3
import sys
import time
from pathlib import Path

# Re-use the proven sibling modules (same directory; importable when this file
# is run as a script — sys.path[0] is its own dir). render_cockpit gives the
# data functions (single source of truth); gmail_alarm gives the send path and
# brand palette. Both are stdlib-only at import time with no side effects.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_cockpit as rc          # noqa: E402
import gmail_alarm as ga             # noqa: E402

# ── Brand tokens (PAPER / INK Direction C — paper-light bg, steel-blue
#    accent, green/red = status + P&L only, sharp edges, no glow) ─────────
P = ga.PALETTE
FONT = ga.FONT_STACK
MONO = ga.MONO_STACK
ACCENT = P["accent"]     # brand blue — headers/eyebrows, never status
EMERALD = P["emerald"]   # status-good / profit green (legacy name kept)
ORANGE = P["warn"]
FAIL = P["fail"]
CYAN = P["live"]

# ── Paths ──────────────────────────────────────────────────────────────
ROOT = Path(r"D:\QM\strategy_farm")
DB = ROOT / "state" / "farm_state.sqlite"
DASH = ROOT / "dashboards"
BRIEF_MD = DASH / "morning_brief.md"       # plaintext body (link target preserved)
BRIEF_HTML = DASH / "morning_brief.html"   # rendered mail (local copy)
VAULT_DIR = Path(r"G:\My Drive\QuantMechanica - Company Reference\10 Morning Briefing")
REPORTS_STATE = Path(r"D:\QM\reports\state")
GOV_STATE = REPORTS_STATE / "quota_governor_state.json"
FACTORY_OFF = ROOT / "state" / "FACTORY_OFF.flag"
TLIVE_JOURNAL_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\logs")
TLIVE_EA_LOG_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM")
LIVE_BOOK_SLEEVES = 24
RECIPIENT = ga.RECIPIENT


# ═══════════════════════════ helpers ═══════════════════════════════════

def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _money(v) -> str:
    if not isinstance(v, (int, float)):
        return "n/a"
    # German thousands/decimal: 101.264,89
    return f"{v:,.2f}".replace(",", "§").replace(".", ",").replace("§", ".")


def _delta(v) -> str:
    if not isinstance(v, (int, float)):
        return "n/a"
    sign = "+" if v >= 0 else "−"
    return f"{sign}{_money(abs(v))}"


def _age(sec) -> str:
    if sec is None:
        return "n/a"
    sec = int(sec)
    if sec < 90:
        return f"{sec}s"
    if sec < 5400:
        return f"{sec // 60}m"
    if sec < 172800:
        return f"{sec // 3600}h"
    return f"{sec // 86400}d"


def e(s) -> str:
    return _html.escape(str(s)) if s is not None else ""


# ═══════════════════════════ data collection ═══════════════════════════

def _yesterday_18() -> str:
    """ISO 'YYYY-MM-DDT18:00' for yesterday (the frontier 'since' cut)."""
    return (dt.date.today() - dt.timedelta(days=1)).strftime("%Y-%m-%dT18:00")


def _tlive_journal_stats() -> dict:
    """Deals + error-like line count across the two most recent T_Live journals.

    READ-ONLY. MT5 journals are UTF-16; fills appear as 'deal #<n>'. Error-like
    lines are an honest heuristic (error/failed/reject/disconnect/no connection).
    """
    out = {"deals": None, "err_lines": None, "journal_date": None, "journal_age_sec": None}
    try:
        files = sorted(TLIVE_JOURNAL_DIR.glob("*.log"),
                       key=lambda p: p.stat().st_mtime, reverse=True)[:2]
    except OSError:
        files = []
    if not files:
        return out
    deals = 0
    errs = 0
    err_re = re.compile(r"(?i)\b(error|failed|reject|disconnect|no connection|"
                        r"not enough money|invalid|refused)\b")
    for f in files:
        try:
            txt = f.read_text(encoding="utf-16", errors="ignore")
        except OSError:
            continue
        for ln in txt.splitlines():
            low = ln.lower()
            if "deal #" in low:
                deals += 1
            if err_re.search(ln):
                errs += 1
    newest = files[0]
    try:
        out["journal_age_sec"] = int(dt.datetime.now().timestamp() - newest.stat().st_mtime)
    except OSError:
        pass
    out["journal_date"] = newest.stem
    out["deals"] = deals
    out["err_lines"] = errs
    return out


def _ea_equity_delta() -> dict:
    """Newest EA-emitted account equity + delta vs the previous day's close.

    READ-ONLY. Equity is the account-level figure inside EQUITY_SNAPSHOT events
    (day-boundary emitted) — explicitly NOT real-time. Over a weekend the newest
    snapshot can be days old; the timestamp is surfaced so the label stays honest.
    """
    out = {"equity": None, "equity_ts": None, "delta_prev": None,
           "ea_logs_today": None, "ea_logs_total": None}
    try:
        logs = list(TLIVE_EA_LOG_DIR.glob("QM5_*_ea-*.log"))
    except OSError:
        logs = []
    out["ea_logs_total"] = len(logs)
    today = dt.date.today()
    active = 0
    # newest equity per UTC day (account-level → any EA's newest that day)
    per_day: dict[str, tuple[str, float]] = {}
    for f in logs:
        try:
            st = f.stat()
        except OSError:
            continue
        if dt.date.fromtimestamp(st.st_mtime) == today:
            active += 1
        try:
            txt = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for ln in txt.splitlines():
            if '"EQUITY_SNAPSHOT"' not in ln:
                continue
            try:
                rec = json.loads(ln)
            except Exception:
                continue
            ts = str(rec.get("ts_utc") or "")
            eq = (rec.get("payload") or {}).get("equity")
            if not ts or not isinstance(eq, (int, float)):
                continue
            day = ts[:10]
            if day not in per_day or ts > per_day[day][0]:
                per_day[day] = (ts, float(eq))
    out["ea_logs_today"] = active
    if per_day:
        days = sorted(per_day)
        newest_day = days[-1]
        out["equity_ts"] = per_day[newest_day][0]
        out["equity"] = per_day[newest_day][1]
        if len(days) >= 2:
            out["delta_prev"] = per_day[newest_day][1] - per_day[days[-2]][1]
    return out


def night_balance() -> dict:
    j = _tlive_journal_stats()
    eq = _ea_equity_delta()
    return {**j, **eq}


def frontier() -> dict:
    try:
        return rc.frontier_next_book_snapshot(since_iso=_yesterday_18())
    except Exception:
        return {"fresh_pass": [], "in_flight": [], "fresh_count": 0, "inflight_count": 0}


def factory_light() -> dict:
    """GRÜN / GELB / ROT with reason. ROT only on a genuine factory-down."""
    try:
        workers = len(rc.live_worker_terminals())
    except Exception:
        workers = 0
    try:
        d_free = round(shutil.disk_usage("D:\\").free / 1e9, 1)
    except Exception:
        d_free = None
    # INFRA_FAIL share, last 24h
    infra = None
    try:
        cut = (_utc_now() - dt.timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ")
        con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        row = con.execute(
            "SELECT SUM(CASE WHEN verdict='INFRA_FAIL' THEN 1 ELSE 0 END) infra, "
            "COUNT(*) tot FROM work_items "
            "WHERE updated_at>=? AND verdict IS NOT NULL AND verdict!=''",
            (cut,),
        ).fetchone()
        con.close()
        if row and row[1]:
            infra = row[0] / row[1]
    except Exception:
        infra = None
    try:
        off = FACTORY_OFF.exists()
    except OSError:
        off = False

    infra_txt = f"{infra:.0%}" if infra is not None else "n/a"
    free_txt = f"{d_free} GB" if d_free is not None else "n/a"
    if off:
        return {"color": ORANGE, "label": "GELB", "workers": workers, "d_free": d_free,
                "infra": infra, "reason": "Factory bewusst OFF (Wartung) — Worker pausiert."}
    if workers == 0:
        return {"color": FAIL, "label": "ROT", "workers": workers, "d_free": d_free,
                "infra": infra, "reason": "Factory DOWN — 0 Worker aktiv."}
    if d_free is not None and d_free < 10:
        return {"color": FAIL, "label": "ROT", "workers": workers, "d_free": d_free,
                "infra": infra, "reason": f"D: nur {free_txt} frei — Storage-Blocker."}
    warns = []
    if workers < 8:
        warns.append(f"nur {workers}/10 Worker")
    if d_free is not None and d_free < 40:
        warns.append(f"D: {free_txt} frei")
    if infra is not None and infra >= 0.30:
        warns.append(f"INFRA {infra_txt} 24h")
    if warns:
        return {"color": ORANGE, "label": "GELB", "workers": workers, "d_free": d_free,
                "infra": infra, "reason": "; ".join(warns) + "."}
    return {"color": EMERALD, "label": "GRÜN", "workers": workers, "d_free": d_free,
            "infra": infra,
            "reason": f"{workers}/10 Worker · D: {free_txt} frei · INFRA {infra_txt} 24h."}


def owner_actions() -> list[dict]:
    """severity=action, fällig ≤ 7 Tage, fällig-sortiert (cockpit logic re-used)."""
    try:
        q12 = rc.q12_review_ready_count()
    except Exception:
        q12 = 0
    try:
        rows = rc.owner_decision_rows(q12)  # already action-first + stale-dropped
    except Exception:
        rows = []
    today = dt.date.today()
    out = []
    for r in rows:
        if not r.get("alert"):
            continue
        due = r.get("due") or ""
        try:
            dd = dt.date.fromisoformat(due)
            if (dd - today).days > 7:
                continue
        except ValueError:
            dd = None
        out.append({**r, "_dd": dd})
    out.sort(key=lambda r: r["_dd"] or dt.date.max)
    return out[:7]


def quota() -> dict:
    """Claude + Codex weekly used-% from the governor state (no 5h window)."""
    out: dict = {}
    try:
        gov = json.loads(GOV_STATE.read_text(encoding="utf-8"))
        for a in ("claude", "codex"):
            s = (gov.get("agents") or {}).get(a) or {}
            out[a] = {
                "week_pct": s.get("used_pct"),
                "proj_eow": s.get("projected_eow_pct"),
                "throttled": bool(s.get("flag_exists")),
                "reset": s.get("week_reset"),
            }
    except Exception:
        pass
    if out:
        return out
    # fallback: quota_snapshot (browser/API scrape)
    try:
        snap = rc.quota_snapshot()
        for a in ("claude", "codex"):
            s = snap.get(a) or {}
            out[a] = {"week_pct": s.get("week_pct"), "proj_eow": None,
                      "throttled": False, "reset": s.get("week_reset")}
    except Exception:
        pass
    return out


def heartbeats() -> list[dict]:
    try:
        hb = rc.ops_heartbeats_snapshot()
    except Exception:
        return []
    keep = {"BACKUP NIGHTLY", "QUOTA GOVERNOR", "CACHE PURGE"}
    return [h for h in hb if h.get("label") in keep]


# ═══════════════════════════ HTML rendering ════════════════════════════

def _tile(label: str, value: str, color: str, sub: str = "") -> str:
    sub_html = (f'<div style="font-size:10px;color:{P["text_subtle"]};margin-top:3px;'
                f'line-height:1.3;">{e(sub)}</div>') if sub else ""
    return (
        f'<td valign="top" align="left" width="25%" '
        f'style="padding:10px 12px;background:{P["surface_2"]};'
        f'border:1px solid {P["border"]};">'
        f'<div style="font-size:9px;color:{P["text_muted"]};text-transform:uppercase;'
        f'letter-spacing:1.5px;font-weight:700;">{e(label)}</div>'
        f'<div style="font-size:20px;color:{color};font-weight:700;font-family:{MONO};'
        f'margin-top:5px;line-height:1;white-space:nowrap;">{value}</div>'
        f'{sub_html}</td>'
    )


def _section_open(title: str, accent: str, right: str = "") -> str:
    right_html = (f'<td align="right" valign="bottom" '
                  f'style="font-size:10px;color:{P["text_subtle"]};font-family:{MONO};">'
                  f'{e(right)}</td>') if right else ""
    return (
        f'<tr><td style="padding:20px 26px 8px;">'
        f'<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
        f'<td><span style="display:inline-block;width:4px;height:13px;background:{accent};'
        f'vertical-align:middle;margin-right:8px;"></span>'
        f'<span style="font-size:12px;color:{P["text"]};font-weight:700;'
        f'letter-spacing:1.5px;text-transform:uppercase;vertical-align:middle;">{e(title)}</span></td>'
        f'{right_html}</tr></table></td></tr>'
    )


def _row(inner: str) -> str:
    return f'<tr><td style="padding:0 26px;">{inner}</td></tr>'


def _list_line(left: str, right: str = "", color: str = None) -> str:
    color = color or P["text_dim"]
    right_html = (f'<td align="right" style="font-size:11px;color:{P["text_muted"]};'
                  f'font-family:{MONO};white-space:nowrap;padding-left:10px;">{right}</td>') if right else ""
    return (
        f'<table width="100%" cellpadding="0" cellspacing="0" border="0" '
        f'style="border-top:1px solid {P["border"]};"><tr>'
        f'<td style="padding:7px 0;font-size:12px;color:{color};line-height:1.4;">{left}</td>'
        f'{right_html}</tr></table>'
    )


def _bar(pct, color: str) -> str:
    try:
        w = max(0, min(100, float(pct)))
    except (TypeError, ValueError):
        w = 0
    return (
        f'<table width="100%" cellpadding="0" cellspacing="0" border="0" '
        f'style="background:{P["surface_0"]};border:1px solid {P["border"]};height:8px;">'
        f'<tr><td width="{w:.0f}%" style="background:{color};height:8px;line-height:8px;font-size:0;">&nbsp;</td>'
        f'<td style="height:8px;line-height:8px;font-size:0;">&nbsp;</td></tr></table>'
    )


def render_html(data: dict) -> str:
    nb = data["night"]
    fr = data["frontier"]
    fl = data["factory"]
    acts = data["actions"]
    qt = data["quota"]
    hb = data["heartbeats"]
    now_local = data["now_local"]
    tz = data["tz"]
    date_h = data["date_h"]

    # ── Section 1: LIVE-BUCH ────────────────────────────────────────────
    eq_sub = ""
    if nb.get("equity_ts"):
        eq_sub = "Stand " + str(nb["equity_ts"])[:16].replace("T", " ") + " UTC"
    delta_color = EMERALD if (isinstance(nb.get("delta_prev"), (int, float))
                              and nb["delta_prev"] >= 0) else FAIL
    logs_today = nb.get("ea_logs_today")
    logs_val = f'{logs_today if logs_today is not None else "n/a"}<span style="font-size:13px;color:{P["text_muted"]};">/{LIVE_BOOK_SLEEVES}</span>'
    tiles = (
        _tile("Equity (EA)", _money(nb.get("equity")), P["text"], eq_sub)
        + _tile("Δ Vortag-Schluss", _delta(nb.get("delta_prev")), delta_color, "EA-emittiert")
        + _tile("Deals Nacht", str(nb.get("deals") if nb.get("deals") is not None else "n/a"), CYAN,
                "letzte 2 Journaltage")
        + _tile("EA-Logs aktiv", logs_val, EMERALD if logs_today else P["text_muted"], "heute modifiziert")
    )
    err_n = nb.get("err_lines")
    err_color = EMERALD if (err_n == 0) else (ORANGE if err_n else P["text_muted"])
    meta1 = (
        f'<table width="100%" cellpadding="0" cellspacing="0" border="0" '
        f'style="margin-top:8px;"><tr>'
        f'<td style="font-size:11px;color:{P["text_muted"]};font-family:{MONO};">'
        f'Journal {e(nb.get("journal_date") or "n/a")} · Alter {_age(nb.get("journal_age_sec"))} · '
        f'<span style="color:{err_color};">Fehler-Zeilen {err_n if err_n is not None else "n/a"}</span></td></tr></table>'
    )
    honest = (
        f'<div style="font-size:10px;color:{P["text_subtle"]};margin-top:5px;line-height:1.4;">'
        f'Equity ist die letzte EA-emittierte Tages-Snapshot-Zahl (Account-Ebene) — '
        f'<b style="color:{P["text_muted"]};">nicht realtime</b>. Über das Wochenende bleibt sie stehen.</div>'
    )
    ftmo = (
        f'<div style="margin-top:10px;padding:8px 11px;background:{P["surface_0"]};'
        f'border-left:3px solid {P["text_subtle"]};font-size:11px;color:{P["text_muted"]};">'
        f'<b style="color:{P["text_dim"]};">FTMO:</b> Trial beendet · kein aktiver Nachfolger — '
        f'Kauf der bezahlten Challenge = Money-Gate (OWNER).</div>'
    )
    sec1 = (
        _section_open("Live-Buch · Nachtbilanz", EMERALD, "DXZ Final-24")
        + _row(f'<table width="100%" cellpadding="0" cellspacing="0" border="0" '
               f'style="border-spacing:0;"><tr>{tiles}</tr></table>{meta1}{honest}{ftmo}')
    )

    # ── Section 2: FRONTIER ─────────────────────────────────────────────
    fresh = fr.get("fresh_pass") or []
    inflight = fr.get("in_flight") or []
    body2 = ""
    if fresh:
        body2 += (f'<div style="font-size:11px;color:{EMERALD};font-weight:700;'
                  f'margin:4px 0 2px;">FRISCHE PASSES seit {e(data["since"][:16].replace("T"," "))}</div>')
        for r in fresh:
            body2 += _list_line(
                f'<b style="color:{P["text"]};">{e(r["ea_id"])}</b> '
                f'<span style="color:{P["text_muted"]};">{e(r["symbol"])}</span>',
                f'<span style="color:{EMERALD};">{e(r["phase"])} PASS</span> · {e(r["when"])}')
    else:
        body2 += (f'<div style="font-size:12px;color:{P["text_muted"]};padding:6px 0;">'
                  f'Keine frischen Q08/Q09/Q10-PASSes seit {e(data["since"][:16].replace("T"," "))}.</div>')
    if inflight:
        body2 += (f'<div style="font-size:11px;color:{ORANGE};font-weight:700;'
                  f'margin:10px 0 2px;">Q07-PASS · Q08 LÄUFT ({len(inflight)})</div>')
        for r in inflight:
            body2 += _list_line(
                f'<b style="color:{P["text"]};">{e(r["ea_id"])}</b> '
                f'<span style="color:{P["text_muted"]};">{e(r["symbol"])}</span>',
                f'<span style="color:{ORANGE};">Q08 {e(r["status"])}</span>')
    sec2 = (
        _section_open("Frontier · Kandidaten", ORANGE, "nächstes Buch ~26.07.")
        + _row(body2)
    )

    # ── Section 3: FACTORY-AMPEL ────────────────────────────────────────
    sec3 = (
        _section_open("Factory-Ampel", fl["color"])
        + _row(
            f'<table width="100%" cellpadding="0" cellspacing="0" border="0" '
            f'style="background:{P["surface_2"]};border:1px solid {P["border"]};"><tr>'
            f'<td width="66" align="center" style="padding:12px 6px;background:{fl["color"]};">'
            f'<span style="font-size:15px;font-weight:800;color:{P["surface_0"]};'
            f'letter-spacing:1px;">{e(fl["label"])}</span></td>'
            f'<td style="padding:10px 14px;font-size:12px;color:{P["text_dim"]};line-height:1.4;">'
            f'{e(fl["reason"])}</td></tr></table>')
    )

    # ── Section 4: OWNER-ENTSCHEIDUNGEN ─────────────────────────────────
    if acts:
        body4 = ""
        today = dt.date.today()
        for r in acts:
            dd = r.get("_dd")
            if dd is not None:
                days = (dd - today).days
                if days < 0:
                    due_txt, due_col = f"fällig {r['due']} (überfällig)", FAIL
                elif days == 0:
                    due_txt, due_col = f"fällig heute", ORANGE
                elif days <= 2:
                    due_txt, due_col = f"fällig {r['due']} ({days}T)", ORANGE
                else:
                    due_txt, due_col = f"fällig {r['due']}", P["text_muted"]
            else:
                due_txt, due_col = "offen", P["text_muted"]
            body4 += _list_line(
                f'<span style="color:{ORANGE};font-size:10px;font-weight:700;'
                f'letter-spacing:0.5px;">{e(r["cat"])}</span> '
                f'<b style="color:{P["text"]};">{e(r["title"])}</b>',
                f'<span style="color:{due_col};">{e(due_txt)}</span>')
    else:
        body4 = (f'<div style="font-size:12px;color:{P["text_muted"]};padding:6px 0;">'
                 f'Keine Aktions-Entscheidungen fällig in den nächsten 7 Tagen.</div>')
    sec4 = (
        _section_open("Owner-Entscheidungen", ORANGE, "Aktion · fällig ≤ 7 T")
        + _row(body4)
    )

    # ── Section 5: QUOTA ────────────────────────────────────────────────
    body5 = ""
    for a, nice in (("claude", "Claude"), ("codex", "Codex")):
        s = qt.get(a) or {}
        pct = s.get("week_pct")
        proj = s.get("proj_eow")
        col = EMERALD
        if isinstance(pct, (int, float)):
            col = FAIL if pct >= 90 else (ORANGE if pct >= 70 else EMERALD)
        pct_txt = f"{pct:.0f}%" if isinstance(pct, (int, float)) else "n/a"
        chip = ""
        if s.get("throttled"):
            chip = (f' <span style="display:inline-block;padding:1px 6px;background:{ORANGE};'
                    f'color:{P["surface_0"]};font-size:9px;font-weight:700;'
                    f'letter-spacing:0.5px;vertical-align:middle;">GEDROSSELT</span>')
        proj_txt = (f' · Prognose EoW {proj:.0f}%' if isinstance(proj, (int, float)) else "")
        body5 += (
            f'<table width="100%" cellpadding="0" cellspacing="0" border="0" '
            f'style="margin:8px 0 2px;"><tr>'
            f'<td style="font-size:12px;color:{P["text_dim"]};font-weight:600;">{nice}{chip}</td>'
            f'<td align="right" style="font-size:13px;color:{col};font-weight:700;'
            f'font-family:{MONO};">{pct_txt}<span style="font-size:10px;color:{P["text_subtle"]};">'
            f' WK{proj_txt}</span></td></tr></table>{_bar(pct, col)}'
        )
    sec5 = _section_open("Quota · Woche", CYAN) + _row(body5)

    # ── Section 6: OPS-HEARTBEATS ───────────────────────────────────────
    cells = ""
    glyph = {"ok": ("✓", EMERALD), "warn": ("⚠", ORANGE),
             "crit": ("✕", FAIL), "miss": ("✕", FAIL)}
    for h in hb:
        g, c = glyph.get(h.get("status"), ("?", P["text_muted"]))
        cells += (
            f'<td width="33%" align="center" style="padding:8px 6px;background:{P["surface_2"]};'
            f'border:1px solid {P["border"]};">'
            f'<div style="font-size:9px;color:{P["text_muted"]};text-transform:uppercase;'
            f'letter-spacing:1px;font-weight:700;">{e(h["label"])}</div>'
            f'<div style="font-size:15px;color:{c};font-weight:700;margin-top:3px;">{g} '
            f'<span style="font-size:10px;color:{P["text_subtle"]};font-family:{MONO};">'
            f'{_age(h.get("age_sec"))}</span></div></td>'
        )
    sec6 = (
        _section_open("Ops-Heartbeats", EMERALD)
        + _row(f'<table width="100%" cellpadding="0" cellspacing="0" border="0" '
               f'style="border-spacing:0;"><tr>{cells}</tr></table>')
    )

    # ── Header + shell ──────────────────────────────────────────────────
    header = (
        f'<tr><td style="padding:22px 26px 16px;border-bottom:2px solid {ACCENT};">'
        f'<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
        f'<td valign="top">'
        f'<div style="font-size:10px;letter-spacing:2px;color:{ACCENT};'
        f'text-transform:uppercase;font-weight:700;">QuantMechanica · Strategy Farm</div>'
        f'<div style="font-size:23px;color:{P["text"]};font-weight:700;margin-top:4px;'
        f'letter-spacing:0.5px;">QM MORGENBRIEFING <span style="color:{ORANGE};">{e(date_h)}</span></div>'
        f'</td>'
        f'<td align="right" valign="top" style="font-size:10px;color:{P["text_subtle"]};'
        f'font-family:{MONO};line-height:1.5;">GERENDERT<br>{e(now_local)}<br>{e(tz)}</td>'
        f'</tr></table></td></tr>'
    )
    footer = (
        f'<tr><td style="padding:16px 26px;border-top:1px solid {P["border"]};'
        f'background:{P["surface_0"]};">'
        f'<div style="font-size:10px;color:{P["text_muted"]};line-height:1.7;">'
        f'<span style="color:{P["text_subtle"]};">Cockpit:</span> '
        f'<span style="color:{P["text_dim"]};font-family:{MONO};">'
        f'file:///D:/QM/strategy_farm/dashboards/cockpit.html</span><br>'
        f'<span style="color:{P["text_subtle"]};">Archiv:</span> '
        f'<span style="color:{P["text_dim"]};font-family:{MONO};">'
        f'G:/…/10 Morning Briefing/</span>'
        f'<div style="margin-top:6px;font-size:9px;color:{P["text_subtle"]};">'
        f'Ein Digest pro Tag (06:00) · gesendet von QM_MorningBriefing_Vault · '
        f'Evidenz statt Behauptung</div></div></td></tr>'
    )
    return (
        f'<!DOCTYPE html><html><head><meta charset="utf-8">'
        f'<meta name="viewport" content="width=device-width,initial-scale=1"></head>'
        f'<body style="margin:0;padding:0;background:{P["bg"]};font-family:{FONT};color:{P["text"]};">'
        f'<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:{P["bg"]};">'
        f'<tr><td align="center" style="padding:20px 10px;">'
        f'<table width="640" cellpadding="0" cellspacing="0" border="0" '
        f'style="max-width:640px;width:100%;background:{P["surface_1"]};border:1px solid {P["border"]};">'
        f'{header}{sec1}{sec2}{sec3}{sec4}{sec5}{sec6}{footer}'
        f'</table></td></tr></table></body></html>'
    )


def render_text(data: dict) -> str:
    """Concise German plaintext fallback (multipart/alternative)."""
    nb, fr, fl = data["night"], data["frontier"], data["factory"]
    qt, hb = data["quota"], data["heartbeats"]
    L = []
    L.append(f"QM MORGENBRIEFING {data['date_h']}  (gerendert {data['now_local']} {data['tz']})")
    L.append("=" * 60)
    L.append("")
    L.append("1) LIVE-BUCH · NACHTBILANZ (DXZ Final-24)")
    L.append(f"   Equity (EA-emittiert, nicht realtime): {_money(nb.get('equity'))}"
             f"  [Stand {str(nb.get('equity_ts') or 'n/a')[:16].replace('T',' ')} UTC]")
    L.append(f"   Delta vs Vortag-Schluss: {_delta(nb.get('delta_prev'))}")
    L.append(f"   Deals (letzte 2 Journaltage): {nb.get('deals')}"
             f"  | Journal {nb.get('journal_date')} Alter {_age(nb.get('journal_age_sec'))}"
             f"  | Fehler-Zeilen {nb.get('err_lines')}")
    L.append(f"   EA-Logs aktiv heute: {nb.get('ea_logs_today')}/{LIVE_BOOK_SLEEVES}")
    L.append("   FTMO: Trial beendet · kein aktiver Nachfolger (Money-Gate OWNER).")
    L.append("")
    L.append("2) FRONTIER · KANDIDATEN (naechstes Buch ~26.07.)")
    fresh, inflight = fr.get("fresh_pass") or [], fr.get("in_flight") or []
    if fresh:
        for r in fresh:
            L.append(f"   [frisch] {r['ea_id']} {r['symbol']} — {r['phase']} PASS ({r['when']})")
    else:
        L.append(f"   Keine frischen Q08/Q09/Q10-PASSes seit {data['since'][:16].replace('T',' ')}.")
    for r in inflight:
        L.append(f"   [Q08 laeuft] {r['ea_id']} {r['symbol']} — {r['status']}")
    L.append("")
    L.append(f"3) FACTORY-AMPEL: {fl['label']} — {fl['reason']}")
    L.append("")
    L.append("4) OWNER-ENTSCHEIDUNGEN (Aktion, faellig <= 7 T)")
    if data["actions"]:
        for r in data["actions"]:
            L.append(f"   [{r['cat']}] {r['title']} — faellig {r.get('due') or 'offen'}")
    else:
        L.append("   Keine Aktions-Entscheidungen faellig.")
    L.append("")
    L.append("5) QUOTA (Woche)")
    for a, nice in (("claude", "Claude"), ("codex", "Codex")):
        s = qt.get(a) or {}
        pct = s.get("week_pct")
        pct_txt = f"{pct:.0f}%" if isinstance(pct, (int, float)) else "n/a"
        thr = " [GEDROSSELT]" if s.get("throttled") else ""
        proj = s.get("proj_eow")
        proj_txt = f" (Prognose EoW {proj:.0f}%)" if isinstance(proj, (int, float)) else ""
        L.append(f"   {nice}: {pct_txt} WK{proj_txt}{thr}")
    L.append("")
    L.append("6) OPS-HEARTBEATS")
    for h in hb:
        mark = {"ok": "OK", "warn": "WARN", "crit": "CRIT", "miss": "MISS"}.get(h.get("status"), "?")
        L.append(f"   {h['label']}: {mark} (Alter {_age(h.get('age_sec'))})")
    L.append("")
    L.append("Cockpit: file:///D:/QM/strategy_farm/dashboards/cockpit.html")
    L.append("Ein Digest pro Tag (06:00).")
    return "\n".join(L) + "\n"


def build_subject(data: dict) -> str:
    fl = data["factory"]
    fr = data["frontier"]
    fresh = len(fr.get("fresh_pass") or [])
    kand = f"{fresh} neue Kand." if fresh else "0 neue Kand."
    return f"[QM] Morgenbriefing {data['date_iso']} — Factory {fl['label']} · {kand}"


# ═══════════════════════════ send ══════════════════════════════════════

def send_mail(subject: str, text_body: str, html_body: str,
              attempts: int = 3) -> dict:
    """Send exactly ONE mail via the proven gmail_alarm SMTP path."""
    last = {"sent": False, "reason": "not attempted"}
    for i in range(1, attempts + 1):
        last = ga._send_mail(subject, text_body, html_body)
        last["attempt"] = i
        if last.get("sent"):
            return last
        if i < attempts:
            time.sleep(2.0 * i)
    # durable fail-flag so a silent SMTP outage is visible next morning
    try:
        DASH.mkdir(parents=True, exist_ok=True)
        flag = DASH / f"MORNING_MAIL_SEND_FAILED_{_utc_now().strftime('%Y%m%dT%H%M%SZ')}.md"
        flag.write_text(f"# Morning mail send failed\n\nSubject: {subject}\n\n"
                        f"Last: `{json.dumps(last, sort_keys=True)}`\n", encoding="utf-8")
        last["fail_flag"] = str(flag)
    except Exception:
        pass
    return last


# ═══════════════════════════ main ══════════════════════════════════════

_DE_WD = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]


def collect() -> dict:
    now_local_dt = dt.datetime.now()
    date_h = f"{_DE_WD[now_local_dt.weekday()]} {now_local_dt.strftime('%d.%m.%Y')}"
    return {
        "night": night_balance(),
        "since": _yesterday_18(),
        "frontier": frontier(),
        "factory": factory_light(),
        "actions": owner_actions(),
        "quota": quota(),
        "heartbeats": heartbeats(),
        "now_local": now_local_dt.strftime("%Y-%m-%d %H:%M"),
        "tz": "W. Europe",
        "date_h": date_h,
        "date_iso": now_local_dt.strftime("%Y-%m-%d"),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="QM morning briefing mail")
    ap.add_argument("--dry-run", action="store_true",
                    help="render + write local files but do NOT send and do NOT write the vault")
    ap.add_argument("--out", metavar="PATH", default=None,
                    help="also write the rendered HTML to PATH (preview)")
    args = ap.parse_args()

    data = collect()
    html_body = render_html(data)
    text_body = render_text(data)
    subject = build_subject(data)

    # Local copies (always) — the .md keeps the gmail_alarm footer link valid.
    try:
        DASH.mkdir(parents=True, exist_ok=True)
        BRIEF_HTML.write_text(html_body, encoding="utf-8", newline="\n")
        BRIEF_MD.write_text(text_body, encoding="utf-8", newline="\n")
    except Exception as exc:
        print(f"local write failed (non-fatal): {exc!r}")
    if args.out:
        try:
            Path(args.out).parent.mkdir(parents=True, exist_ok=True)
            Path(args.out).write_text(html_body, encoding="utf-8", newline="\n")
            print(f"preview written: {args.out}")
        except Exception as exc:
            print(f"--out write failed: {exc!r}")

    if args.dry_run:
        print(f"[dry-run] rendered subject: {subject}")
        print(f"[dry-run] HTML {len(html_body)} bytes · NO mail sent · NO vault write")
        return 0

    # Vault archive (timestamped HTML — scrollable off-VPS history).
    try:
        VAULT_DIR.mkdir(parents=True, exist_ok=True)
        (VAULT_DIR / f"{data['date_iso']}_morning_brief.html").write_text(
            html_body, encoding="utf-8", newline="\n")
        (VAULT_DIR / f"{data['date_iso']}_morning_brief.md").write_text(
            text_body, encoding="utf-8", newline="\n")
        print(f"vault archive written: {VAULT_DIR}")
    except Exception as exc:
        print(f"vault write failed (non-fatal): {exc!r}")

    result = send_mail(subject, text_body, html_body)
    print(json.dumps({"subject": subject, **result}, indent=2))
    return 0 if result.get("sent") else 1


if __name__ == "__main__":
    sys.exit(main())
