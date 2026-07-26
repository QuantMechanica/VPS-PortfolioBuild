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
import hashlib
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
RECIPIENT = ga.RECIPIENT

# ── Live-truth status-lamp sources (Operating Rule 20: read-only state files
#    ONLY — this block NEVER probes a live MT5 process nor touches T_Live). Every
#    lamp is derived exclusively from atomic state JSONs written by the producers:
#    WS-E1 transition-dedup alarm state, the shipped uptime-watchdog + resident
#    supervisor, the FTMO account monitor, the DXZ DD-guard, the WS-E3 deployment
#    contract verifier, the news-calendar file age, and the config-driven, signed
#    deploy-stamp. The reader schemas MATCH what those producers actually emit
#    (see docs/ops/evidence/2026-07-26_wse22/state_contracts_v1.md). Missing /
#    stale / malformed sources become explicit UNKNOWN / RED — never
#    green-by-absence — but a FRESH VALID producer file renders GREEN/RED by its
#    own content. ─────────────────────────────────────────────────────────────
LIVE_ALARM_STATE = REPORTS_STATE / "live_alarm_state.json"              # WS-E1 alarm state (author: T_Live_Watchdog)
LIVE_WATCHDOG_STATE = REPORTS_STATE / "live_uptime_watchdog.json"       # shipped uptime-watchdog atomic state (fallback)
LIVE_SUPERVISOR_STATE = REPORTS_STATE / "live_session_supervisor.json"  # resident supervisor atomic state (fallback cross-read)
LIVE_MAINTENANCE_FLAG = REPORTS_STATE / "LIVE_UPTIME_MAINTENANCE.flag"
FTMO_PULSE_STATE = REPORTS_STATE / "ftmo_trial_pulse.json"             # FTMO account-monitor state (shipped)
DDGUARD_STATE = REPORTS_STATE / "live_book_dd_guard_state.json"         # DXZ live-book DD-guard state (shipped)
LIVE_DEPLOY_CONTRACT_STATE = REPORTS_STATE / "live_deployment_contract_state.json"  # WS-E3 verifier --json-out (deployment contract)
NEWS_CALENDAR_FILE = Path(r"D:\QM\data\news_calendar\forex_factory_calendar_clean.csv")
# Config-driven pointer to the CURRENTLY DEPLOYED signed book manifest, plus the
# authenticated deploy-stamp. Ops repoints/re-stamps the RUNTIME override after
# each Sunday deploy; the repo-committed default is an UNauthenticated fallback
# used only to derive the expected sleeve-count. Expected sleeve-count + account
# are read from the manifest — NEVER a hard-coded constant.
DEPLOY_POINTER = REPORTS_STATE / "live_deployment_pointer.json"         # runtime authenticated deploy-stamp (ops-maintained)
DEPLOY_DEFAULT = Path(__file__).resolve().parent / "config" / "live_deployment.json"  # repo default (unauthenticated fallback)

# Status-lamp levels, worst-first severity rank (RED dominates; UNKNOWN outranks
# AMBER because "cannot confirm the live money book" is worse than a known minor
# warning; both UNKNOWN and RED are non-green and must reach the subject line).
L_GREEN, L_AMBER, L_UNKNOWN, L_RED = "GRÜN", "GELB", "UNBEKANNT", "ROT"
_LEVEL_RANK = {L_GREEN: 0, L_AMBER: 1, L_UNKNOWN: 2, L_RED: 3}

# Per-source freshness SLAs (seconds). A source older than its RED bound is
# treated as a failed/dead producer, never as healthy.
_SLA = {
    "watchdog_amber": 300, "watchdog_red": 900,       # runs ~1/min; 5m warn / 15m dead
    "ddguard_amber": 1800, "ddguard_red": 7200,       # 30m warn / 2h dead
    "ftmo_amber": 1800, "ftmo_red": 7200,             # 30m warn / 2h dead
    "contract_amber": 129600, "contract_red": 604800,  # 36h warn / 7d dead (post-recovery + periodic)
    "news_green": 129600, "news_amber": 691200,       # <=36h ok / <=8d warn / else dead
}

# WS-E1 alarm-state per-session conditions that mean the live money-book terminal
# is confidently BROKEN/DOWN (→ RED) vs merely unconfirmable (→ UNKNOWN/AMBER).
_E1_COND_RED = {"missing", "duplicate", "launch_failed"}
_E1_COND_UNKNOWN = {"probe_unknown"}
_E1_COND_AMBER = {"stale"}
# WS-E1 watchdog_status → base level.
_E1_STATUS = {"healthy": L_GREEN, "degraded": L_AMBER, "critical": L_RED,
              "maintenance": L_AMBER}
# WS-E1 REQUIRED producer schema: the alarm state must carry a parseable
# generated_utc freshness anchor AND both money-book/trial session blocks
# (T_LIVE, FTMO), each with a condition field, before its status may be
# interpreted. A parseable JSON object missing any of these is a BROKEN producer,
# not a healthy live book, and renders UNKNOWN (never green-by-schema-absence).
# See state_contracts_v1.md §1.
_E1_REQUIRED_SESSIONS = ("T_LIVE", "FTMO")


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


# ═══════════════════ live status lamp (state-file only) ═════════════════
#
# Everything below reads ONLY the atomic state JSONs / file ages listed in the
# Paths section. It NEVER probes an MT5 process and NEVER opens a file under
# C:\QM\mt5\T_Live (Operating Rule 20). Reading a producer's *recorded* facts is
# not a live probe — the producer probed and wrote them; the brief only reads
# the file. Every reader is pure w.r.t. an injected `paths` dict + `now`, so the
# fixtures drive it deterministically with no live access.
#
# CONTRACT (state_contracts_v1.md): the readers below consume the schemas the
# producers ACTUALLY emit. A source that is missing, unparseable, or older than
# its RED freshness bound yields UNKNOWN or RED — never GREEN. A FRESH VALID
# producer file renders GREEN/RED strictly by its own content.


def _worst(levels) -> str:
    """The most-severe level in an iterable (default UNKNOWN if empty)."""
    best = L_GREEN
    seen = False
    for lv in levels:
        seen = True
        if _LEVEL_RANK.get(lv, 2) > _LEVEL_RANK.get(best, 2):
            best = lv
    return best if seen else L_UNKNOWN


def _level_color(level: str) -> str:
    return {L_GREEN: EMERALD, L_AMBER: ORANGE, L_RED: FAIL,
            L_UNKNOWN: P["text_muted"]}.get(level, P["text_muted"])


def _parse_utc(s):
    """Parse an ISO-8601 UTC stamp (trailing Z, offset, or naive) to aware dt."""
    if not isinstance(s, str) or not s.strip():
        return None
    t = s.strip()
    if t.endswith("Z"):
        t = t[:-1] + "+00:00"
    try:
        d = dt.datetime.fromisoformat(t)
    except ValueError:
        return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=dt.timezone.utc)
    return d


def _age_sec_from_ts(obj: dict, keys, now) -> float | None:
    for k in keys:
        d = _parse_utc(obj.get(k)) if isinstance(obj, dict) else None
        if d is not None:
            return (now - d).total_seconds()
    return None


def _read_state_json(path):
    """(obj, status) — status ∈ {ok, missing, malformed}. dict-typed JSON only."""
    if path is None:
        return None, "missing"
    p = Path(path)
    try:
        if not p.exists():
            return None, "missing"
    except OSError:
        return None, "missing"
    try:
        txt = p.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError):
        return None, "malformed"
    try:
        obj = json.loads(txt)
    except Exception:
        return None, "malformed"
    if not isinstance(obj, dict):
        return None, "malformed"
    return obj, "ok"


def _file_age_sec(path, now) -> float | None:
    if path is None:
        return None
    try:
        p = Path(path)
        if not p.exists():
            return None
        return now.timestamp() - p.stat().st_mtime
    except OSError:
        return None


def _sha256_file(path) -> str | None:
    try:
        h = hashlib.sha256()
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return None


def _lamp(key, label, short, level, value, detail="", age_sec=None, prose=None) -> dict:
    return {"key": key, "label": label, "short": short, "level": level,
            "value": value, "detail": detail, "age_sec": age_sec, "prose": prose}


def _resolve_paths(paths):
    """Merge a caller override over the production defaults (fixtures pass their
    own tmp paths so no real/T_Live file is ever touched under test)."""
    base = {
        "alarm": LIVE_ALARM_STATE,
        "watchdog": LIVE_WATCHDOG_STATE,
        "supervisor": LIVE_SUPERVISOR_STATE,
        "maintenance": LIVE_MAINTENANCE_FLAG,
        "ftmo": FTMO_PULSE_STATE,
        "ddguard": DDGUARD_STATE,
        "contract": LIVE_DEPLOY_CONTRACT_STATE,
        "news": NEWS_CALENDAR_FILE,
        "deploy_pointer": DEPLOY_POINTER,
        "deploy_default": DEPLOY_DEFAULT,
        "manifest": None,   # direct manifest override (tests); else resolved from stamp
    }
    if paths:
        base.update(paths)
    return base


# ── individual sub-lamps ────────────────────────────────────────────────


def _e1_schema_ok(alarm) -> tuple:
    """Validate the REQUIRED WS-E1 alarm-state producer schema (state_contracts_
    v1.md §1) BEFORE its status is interpreted. Returns (ok, reason). Requires a
    parseable generated_utc freshness anchor, a non-empty watchdog_status, and
    BOTH required session blocks (T_LIVE, FTMO), each a dict carrying a non-empty
    condition. Anything missing ⇒ the reader renders UNKNOWN (never green). This
    is the guard that stops a semantic-invalid object such as
    {"watchdog_status":"healthy","sessions":{}} (no timestamp, no session blocks)
    from rendering GRÜN."""
    if not isinstance(alarm, dict):
        return False, "kein JSON-Objekt"
    if _parse_utc(alarm.get("generated_utc")) is None:
        return False, "generated_utc fehlt/unparsebar"
    if not str(alarm.get("watchdog_status") or "").strip():
        return False, "watchdog_status fehlt"
    sessions = alarm.get("sessions")
    if not isinstance(sessions, dict):
        return False, "sessions-Block fehlt"
    skeys = {str(k).upper(): v for k, v in sessions.items()}
    for name in _E1_REQUIRED_SESSIONS:
        sess = skeys.get(name)
        if not isinstance(sess, dict):
            return False, f"Pflicht-Session {name} fehlt"
        if not str(sess.get("condition") or "").strip():
            return False, f"Pflicht-Session {name} ohne condition"
    return True, ""


def _e1_session_escalation(sessions: dict):
    """Given the WS-E1 sessions{T_LIVE,FTMO} block, return (level, notes[]).

    T_LIVE is the DXZ live money-book terminal: a confidently-broken condition
    (missing/duplicate/launch_failed) is RED because live trading is not running;
    probe_unknown is UNKNOWN; stale is AMBER. FTMO is the trial terminal — any of
    its alarm conditions escalates to at most AMBER (surface, but it is not the
    money book)."""
    level = L_GREEN
    notes = []
    if not isinstance(sessions, dict):
        return L_UNKNOWN, ["sessions-Block fehlt"]
    for name, sess in sessions.items():
        if not isinstance(sess, dict):
            continue
        cond = str(sess.get("condition") or "").lower()
        if cond in ("ok", "maintenance", ""):
            continue
        detail = str(sess.get("detail") or cond)
        disp = "DXZ" if name.upper() == "T_LIVE" else name.upper()
        notes.append(f"{disp}: {cond} ({detail})")
        if name.upper() == "T_LIVE":
            if cond in _E1_COND_RED:
                level = _worst([level, L_RED])
            elif cond in _E1_COND_UNKNOWN:
                level = _worst([level, L_UNKNOWN])
            elif cond in _E1_COND_AMBER:
                level = _worst([level, L_AMBER])
            else:
                level = _worst([level, L_AMBER])
        else:  # FTMO session — cap at AMBER
            level = _worst([level, L_AMBER])
    return level, notes


def _lamp_watchdog(P_, now) -> dict:
    """WS-E1 live-terminal recovery state. Prefers the transition-dedup alarm
    file (WS-E1 producer: author T_Live_Watchdog); falls back to the shipped
    uptime-watchdog + supervisor atomic states."""
    # (1) WS-E1 alarm-state contract — the schema the producer ACTUALLY emits:
    #     {schema_version, generated_utc, author, watchdog_status, maintenance,
    #      reboot_suppressed, any_alarm, sessions{T_LIVE,FTMO}}.
    alarm, ast = _read_state_json(P_["alarm"])
    if ast == "ok":
        # Fail-closed: a present, parseable alarm file IS the WS-E1 producer, so
        # its REQUIRED schema (generated_utc + both sessions with a condition)
        # must validate BEFORE the status is interpreted. A schema-incomplete
        # object (e.g. {"watchdog_status":"healthy","sessions":{}} — no timestamp,
        # no session blocks) is a broken producer → UNKNOWN, NEVER green. It does
        # NOT fall through to the pre-E1 uptime-watchdog fallback (that path is
        # only for an ABSENT alarm file); silently downgrading a broken primary to
        # a healthy fallback would re-hide exactly this failure.
        ok_schema, why = _e1_schema_ok(alarm)
        if not ok_schema:
            return _lamp("watchdog", "Live-MT5 (E1-Alarm)", "Live-MT5", L_UNKNOWN,
                         "SCHEMA?",
                         f"E1-Alarm-State Schema unvollständig ({why}) — "
                         f"Live-Status nicht bestätigbar",
                         _age_sec_from_ts(alarm, ("generated_utc",), now))
        age = _age_sec_from_ts(alarm, ("generated_utc",), now)
        raw = str(alarm.get("watchdog_status") or "").lower()
        base = _E1_STATUS.get(raw, L_UNKNOWN)
        sessions = alarm.get("sessions") or {}
        sess_lvl, notes = _e1_session_escalation(sessions)
        any_alarm = bool(alarm.get("any_alarm"))
        reboot_supp = bool(alarm.get("reboot_suppressed"))
        maint = bool(alarm.get("maintenance"))
        # stale producer ⇒ RED (recovery loop dead), regardless of last status.
        if age is not None and age > _SLA["watchdog_red"]:
            return _lamp("watchdog", "Live-MT5 (E1-Alarm)", "Live-MT5", L_RED,
                         "STALE", f"E1-Alarm-State {_age(age)} alt — Watchdog/Recovery-Loop tot?", age)
        lvl = _worst([base, sess_lvl])
        if any_alarm:
            lvl = _worst([lvl, L_AMBER])
        if age is not None and age > _SLA["watchdog_amber"] and lvl == L_GREEN:
            lvl = L_AMBER
        # per-session compact value (DXZ = T_LIVE).
        def _cond(nm):
            s = (sessions.get(nm) or {}) if isinstance(sessions, dict) else {}
            c = str(s.get("condition") or "?").lower()
            return "✓" if c == "ok" else (c if c else "?")
        val = f"DXZ {_cond('T_LIVE')} · FTMO {_cond('FTMO')}"
        detail_bits = []
        if maint:
            detail_bits.append("Wartung")
        if reboot_supp:
            detail_bits.append("Reboot unterdrückt")
        detail_bits.extend(notes)
        detail = "; ".join(detail_bits) if detail_bits else f"watchdog_status={raw or '?'}"
        return _lamp("watchdog", "Live-MT5 (E1-Alarm)", "Live-MT5", lvl, val, detail, age)

    # (2) shipped uptime-watchdog atomic state (with supervisor cross-read).
    wd, wst = _read_state_json(P_["watchdog"])
    if wst != "ok":
        return _lamp("watchdog", "Live-MT5 Watchdog", "Live-MT5", L_UNKNOWN,
                     wst.upper(),
                     f"Watchdog-State {wst} ({P_['watchdog']}) — Live-Status nicht bestätigbar")
    age = _age_sec_from_ts(wd, ("ts", "last_checked_utc"), now)
    if age is not None and age > _SLA["watchdog_red"]:
        return _lamp("watchdog", "Live-MT5 Watchdog", "Live-MT5", L_RED, "STALE",
                     f"Watchdog {_age(age)} alt — Recovery-Loop läuft nicht?", age)
    dxz = bool(wd.get("dxz_running"))
    ftmo = bool(wd.get("ftmo_running"))
    probe_ok = wd.get("process_probe_ok")
    status = str(wd.get("status") or "").lower()
    val = f"DXZ {'✓' if dxz else '✕'} · FTMO {'✓' if ftmo else '✕'}"
    if wd.get("maintenance"):
        return _lamp("watchdog", "Live-MT5 Watchdog", "Live-MT5", L_AMBER, "WARTUNG",
                     "Wartungs-Flag gesetzt — Recovery pausiert.", age)
    if probe_ok is False:
        return _lamp("watchdog", "Live-MT5 Watchdog", "Live-MT5", L_UNKNOWN, "PROBE?",
                     "Prozess-Inventar unklar (fail-closed) — Live-Status nicht bestätigbar.", age)
    if status == "critical" or (not dxz and not ftmo):
        return _lamp("watchdog", "Live-MT5 Watchdog", "Live-MT5", L_RED, val,
                     (f"Watchdog: {status}" if status else "Beide Terminals down."), age)
    lvl = _E1_STATUS.get(status, L_UNKNOWN)
    if not dxz or not ftmo:
        lvl = _worst([lvl, L_AMBER])
    if age is not None and age > _SLA["watchdog_amber"]:
        lvl = _worst([lvl, L_AMBER])
    errs = wd.get("errors") or []
    detail = "; ".join(str(x) for x in errs[:2]) if errs else (status or "healthy")
    return _lamp("watchdog", "Live-MT5 Watchdog", "Live-MT5", lvl, val, detail, age)


def _lamp_ddguard(P_, now) -> dict:
    g, st = _read_state_json(P_["ddguard"])
    if st != "ok":
        return _lamp("ddguard", "DXZ DD-Guard", "DD-Guard", L_UNKNOWN, st.upper(),
                     f"DD-Guard-State {st} — Live-Buch-Risiko nicht bestätigbar")
    age = _age_sec_from_ts(g, ("last_run_utc",), now)
    dd = g.get("last_dd_pct")
    halt = g.get("halt_dd_pct")
    dd_txt = f"{dd:.2f}%" if isinstance(dd, (int, float)) else "n/a"
    halt_txt = f"{halt:.1f}%" if isinstance(halt, (int, float)) else "n/a"
    if g.get("breached"):
        return _lamp("ddguard", "DXZ DD-Guard", "DD-Guard", L_RED, "AUSGELÖST",
                     f"DD-Guard ausgelöst — DD {dd_txt} ≥ Halt {halt_txt}.", age)
    if age is not None and age > _SLA["ddguard_red"]:
        return _lamp("ddguard", "DXZ DD-Guard", "DD-Guard", L_RED, "STALE",
                     f"DD-Guard {_age(age)} alt — Guard läuft nicht?", age)
    lvl = L_GREEN
    if age is not None and age > _SLA["ddguard_amber"]:
        lvl = L_AMBER
    return _lamp("ddguard", "DXZ DD-Guard", "DD-Guard", lvl, dd_txt,
                 f"DD {dd_txt} / Halt {halt_txt}", age)


def _lamp_ftmo(P_, now) -> dict:
    """FTMO account lamp + trial-dead/alive prose generated from account state
    (never retained text). Schema: ftmo_trial_pulse.json {checked_at_utc, verdict,
    terminal_up, total_dd_pct, day_loss_pct, equity, ...}."""
    g, st = _read_state_json(P_["ftmo"])
    if st != "ok":
        prose = ("FTMO: kein lesbarer Account-State — Status UNBEKANNT."
                 if st == "malformed" else
                 "FTMO: kein Account-State (Datei fehlt) — Status UNBEKANNT.")
        return _lamp("ftmo", "FTMO-Konto", "FTMO", L_UNKNOWN, st.upper(),
                     f"FTMO-State {st} ({P_['ftmo']})", None, prose)
    age = _age_sec_from_ts(g, ("checked_at_utc",), now)
    verdict = str(g.get("verdict") or "").upper()
    terminal_up = g.get("terminal_up")
    total_dd = g.get("total_dd_pct")
    day_loss = g.get("day_loss_pct")
    equity = g.get("equity")
    dd_txt = f"{total_dd:.2f}%" if isinstance(total_dd, (int, float)) else "n/a"
    dl_txt = f"{day_loss:.2f}%" if isinstance(day_loss, (int, float)) else "n/a"
    at_limit = isinstance(total_dd, (int, float)) and total_dd >= 9.9
    over_limit = isinstance(total_dd, (int, float)) and total_dd >= 10.0

    if terminal_up is False:
        lvl, val = L_RED, "TERMINAL DOWN"
    elif verdict == "ALARM" or over_limit:
        lvl, val = L_RED, dd_txt
    elif verdict == "WARN" or at_limit:
        lvl, val = L_AMBER, dd_txt
    elif verdict == "OK":
        lvl, val = L_GREEN, dd_txt
    else:
        lvl, val = L_UNKNOWN, verdict or "?"
    if age is not None and age > _SLA["ftmo_red"]:
        lvl, val = _worst([lvl, L_AMBER]), val + " (stale)"
    elif age is not None and age > _SLA["ftmo_amber"]:
        lvl = _worst([lvl, L_AMBER])

    # trial-dead/alive prose from the numbers, not retained "Trial beendet".
    if terminal_up is False:
        prose = "FTMO: Terminal offline — Account-Status nicht überwachbar."
    elif over_limit:
        prose = (f"FTMO: Gesamt-DD {dd_txt} ≥ Limit (10%) — Trial ausgeschöpft/TOT; "
                 f"Reset bzw. neues Konto = Money-Gate (OWNER).")
    elif at_limit:
        prose = (f"FTMO: Gesamt-DD {dd_txt} ≈ Limit (10%), equity {_money(equity)} — "
                 f"Trial praktisch ausgeschöpft; neues Konto = Money-Gate (OWNER).")
    elif verdict == "OK":
        prose = (f"FTMO: aktiv · equity {_money(equity)} · Gesamt-DD {dd_txt} · "
                 f"Tages-Verlust {dl_txt} (Limits 10%/5%).")
    else:
        prose = (f"FTMO: {verdict or 'Status unklar'} · equity {_money(equity)} · "
                 f"Gesamt-DD {dd_txt} · Tages-Verlust {dl_txt}.")
    detail = f"equity {_money(equity)} · Tages-Verlust {dl_txt}"
    return _lamp("ftmo", "FTMO-Konto", "FTMO", lvl, val, detail, age, prose)


def _e3_schema_ok(g) -> tuple:
    """Validate the REQUIRED WS-E3 deployment-contract producer schema (state_
    contracts_v1.md §2) BEFORE overall_status is interpreted. Returns (ok,
    reason). Requires a parseable generated_utc, a non-empty overall_status, the
    summary / disk_profile / runtime blocks (all dicts), and a findings list. A
    schema-incomplete object (e.g. {"overall_status":"GREEN","disk_profile":{…}}
    with no timestamp/summary/runtime/findings) ⇒ UNKNOWN (never a green 24/24)."""
    if not isinstance(g, dict):
        return False, "kein JSON-Objekt"
    if _parse_utc(g.get("generated_utc")) is None:
        return False, "generated_utc fehlt/unparsebar"
    if not str(g.get("overall_status") or "").strip():
        return False, "overall_status fehlt"
    for blk in ("summary", "disk_profile", "runtime"):
        if not isinstance(g.get(blk), dict):
            return False, f"{blk}-Block fehlt"
    if not isinstance(g.get("findings"), list):
        return False, "findings-Block fehlt"
    return True, ""


def _lamp_contract(P_, now) -> dict:
    """WS-E3 deployment-contract verifier state. Schema (verify_live_deployment_
    contract.py --json-out): {overall_status ∈ GREEN|AMBER|RED|UNKNOWN,
    generated_utc, summary{critical,warn,info,headline}, disk_profile{...},
    runtime{...}, findings[...]}. Absent → UNKNOWN advisory (E3 not scheduled)
    — never GREEN; overall_status is consumed DIRECTLY, but ONLY after the
    REQUIRED schema validates (fail-closed against schema-incomplete green)."""
    g, st = _read_state_json(P_["contract"])
    if st == "missing":
        return _lamp("contract", "Deployment-Contract (E3)", "Deploy-Contract", L_UNKNOWN, "N/A",
                     "WS-E3 Deployment-Verifier noch nicht geplant — Profil/Runtime unbestätigt.")
    if st == "malformed":
        return _lamp("contract", "Deployment-Contract (E3)", "Deploy-Contract", L_UNKNOWN, "MALFORMED",
                     f"Deployment-Contract-State unlesbar ({P_['contract']}).")
    # Fail-closed: a present, parseable state must satisfy the REQUIRED producer
    # schema BEFORE overall_status is trusted. A schema-incomplete object (no
    # generated_utc / summary / runtime / findings) → UNKNOWN, never green.
    ok_schema, why = _e3_schema_ok(g)
    if not ok_schema:
        return _lamp("contract", "Deployment-Contract (E3)", "Deploy-Contract", L_UNKNOWN, "SCHEMA?",
                     f"Deployment-Contract-State Schema unvollständig ({why}) — Profil/Runtime unbestätigt.")
    age = _age_sec_from_ts(g, ("generated_utc",), now)
    if age is not None and age > _SLA["contract_red"]:
        return _lamp("contract", "Deployment-Contract (E3)", "Deploy-Contract", L_RED, "STALE",
                     f"Deployment-Contract {_age(age)} alt — Verifier läuft nicht?", age)
    raw = str(g.get("overall_status") or "").upper()
    lvl = {"GREEN": L_GREEN, "AMBER": L_AMBER, "RED": L_RED,
           "UNKNOWN": L_UNKNOWN}.get(raw, L_UNKNOWN)
    if age is not None and age > _SLA["contract_amber"]:
        lvl = _worst([lvl, L_AMBER])
    disk = g.get("disk_profile") or {}
    ok_n = disk.get("expected_present_ok")
    miss_n = disk.get("expected_missing")
    if isinstance(ok_n, int) and isinstance(miss_n, int):
        val = f"{ok_n}/{ok_n + miss_n}"
    else:
        val = raw or "?"
    summary = g.get("summary") or {}
    detail = str(summary.get("headline") or raw or "n/a")
    return _lamp("contract", "Deployment-Contract (E3)", "Deploy-Contract", lvl, val, detail, age)


def _lamp_news(P_, now) -> dict:
    age = _file_age_sec(P_["news"], now)
    if age is None:
        return _lamp("news", "News-Kalender", "News", L_RED, "FEHLT",
                     f"News-Kalender fehlt ({P_['news']}) — Live-News-Filter ohne Daten.")
    if age <= _SLA["news_green"]:
        lvl = L_GREEN
    elif age <= _SLA["news_amber"]:
        lvl = L_AMBER
    else:
        lvl = L_RED
    return _lamp("news", "News-Kalender", "News", lvl, _age(age),
                 f"Kalender-Datei Alter {_age(age)} (Refresh täglich 05:30).", age)


def _resolve_deploy_stamp(P_):
    """Config-driven resolution of the deploy-stamp + manifest path.

    Order: direct manifest override (tests) → runtime authenticated stamp
    (D:/QM/reports/state/live_deployment_pointer.json) → repo default
    (config/live_deployment.json, UNauthenticated fallback). Returns
    (stamp_dict_or_None, manifest_path_or_None, src)."""
    if P_.get("manifest"):
        return {}, Path(P_["manifest"]), "override"
    ptr, st = _read_state_json(P_["deploy_pointer"])
    if st == "ok" and ptr.get("manifest_path"):
        return ptr, Path(ptr["manifest_path"]), "runtime_stamp"
    dft, st2 = _read_state_json(P_["deploy_default"])
    if st2 == "ok" and dft.get("manifest_path"):
        return dft, Path(dft["manifest_path"]), "repo_default"
    src = ("pointer_malformed" if st == "malformed"
           else "default_malformed" if st2 == "malformed" else "no_pointer")
    return None, None, src


def _authenticate_deploy(stamp, src, manifest_path, man) -> tuple:
    """Authenticate the SIGNED deploy-stamp against the manifest. `status==LIVE`
    alone is INSUFFICIENT. Returns (level, notes[]).

    GREEN requires ALL of: an authenticated runtime stamp (not the repo default),
    signed==true, a non-empty approver, a manifest_sha256 that MATCHES the
    recomputed file hash, a parseable deployment_epoch, a BINDABLE account derived
    from the manifest book that MATCHES the stamp's expected_account, a non-empty
    expected_phase, and the manifest's own status==LIVE. A SHA or account MISMATCH
    is RED (tamper / wrong file); a manifest with no bindable account is UNKNOWN
    (cannot authenticate — never green). Any missing authentication field degrades
    to AMBER — 'manifest-derived' is not 'derived from the signed manifest'."""
    notes = []
    # A stamp only from the repo default is an explicit unauthenticated fallback.
    if src == "repo_default":
        notes.append("nur Repo-Default (kein signierter Runtime-Stamp)")
        return L_AMBER, notes
    if src == "override":
        # Direct manifest override (tests / ad-hoc) carries no signed stamp.
        notes.append("Manifest-Override ohne signierten Deploy-Stamp")
        base = L_AMBER
    else:
        base = L_GREEN
    stamp = stamp or {}

    # (a) signed flag
    if stamp.get("signed") is not True:
        notes.append("signed≠true")
        base = _worst([base, L_AMBER])
    # (b) approver present
    if not str(stamp.get("approved_by") or "").strip():
        notes.append("approved_by fehlt")
        base = _worst([base, L_AMBER])
    # (c) manifest SHA-256 present + matches the actual file
    claimed = str(stamp.get("manifest_sha256") or "").strip().lower()
    if not claimed:
        notes.append("manifest_sha256 fehlt")
        base = _worst([base, L_AMBER])
    else:
        actual = (_sha256_file(manifest_path) or "").lower()
        if not actual:
            notes.append("Manifest-Datei nicht hashbar")
            base = _worst([base, L_AMBER])
        elif actual != claimed:
            notes.append("manifest_sha256 MISMATCH (Tamper/falsches Manifest)")
            base = _worst([base, L_RED])
    # (d) deployment epoch parseable
    epoch = _parse_utc(stamp.get("deployment_epoch_utc") or stamp.get("deployment_epoch"))
    if epoch is None:
        notes.append("deployment_epoch fehlt/unparsebar")
        base = _worst([base, L_AMBER])
    # (e) expected_account: a BINDABLE account must be derivable FROM THE MANIFEST
    #     and the stamp must present a matching expected_account. A manifest whose
    #     book is just "DXZ" (no account digits) is UNBINDABLE — the stamp's
    #     expected_account cannot be corroborated, so authentication is impossible
    #     ⇒ NEVER green. Fail-closed: unbindable manifest ⇒ UNKNOWN (cannot confirm
    #     the live money book's account identity); a present-but-mismatched account
    #     ⇒ RED (tamper / wrong file). This is the guard that stops a signed stamp
    #     over a bookless manifest from authenticating green.
    exp_acct = str(stamp.get("expected_account") or "").strip()
    book = str((man or {}).get("book") or "")
    acct_m = re.search(r"(\d{6,})", book)
    man_acct = acct_m.group(1) if acct_m else None
    if man_acct is None:
        notes.append(f"Manifest-Buch '{book or '?'}' ohne bindbaren Account — "
                     f"expected_account nicht verifizierbar")
        base = _worst([base, L_UNKNOWN])
    if not exp_acct:
        notes.append("expected_account fehlt")
        base = _worst([base, L_AMBER])
    elif man_acct is not None and exp_acct != man_acct:
        notes.append(f"expected_account≠Manifest ({exp_acct}≠{man_acct})")
        base = _worst([base, L_RED])
    # (f) expected_phase present
    if not str(stamp.get("expected_phase") or "").strip():
        notes.append("expected_phase fehlt")
        base = _worst([base, L_AMBER])
    # (g) manifest own status LIVE
    if str((man or {}).get("status") or "").upper() != "LIVE":
        notes.append(f"Manifest-Status={((man or {}).get('status') or '?')} (nicht LIVE)")
        base = _worst([base, L_AMBER])
    return base, notes


def _lamp_deployment(P_, now):
    """Deployed-manifest binding → expected sleeve-count + account, PLUS
    authentication of the signed deploy-stamp. Returns a dict carrying the lamp
    plus the derived expectations. NEVER a hard-coded sleeve count."""
    stamp, mpath, src = _resolve_deploy_stamp(P_)
    if mpath is None:
        lamp = _lamp("deploy", "Deployed-Manifest", "Manifest", L_UNKNOWN, "KEIN STAMP",
                     f"Kein Deploy-Stamp/Pointer ({src}) — erwartete Sleeve-Zahl UNBEKANNT.")
        return {"lamp": lamp, "expected_sleeves": None, "account": None,
                "manifest_status": None, "manifest_path": None, "authenticated": False}
    man, mst = _read_state_json(mpath)
    if mst != "ok":
        lamp = _lamp("deploy", "Deployed-Manifest", "Manifest", L_RED, mst.upper(),
                     f"Deployed-Manifest {mst} ({mpath}).")
        return {"lamp": lamp, "expected_sleeves": None, "account": None,
                "manifest_status": None, "manifest_path": str(mpath), "authenticated": False}
    # Derive expectations from the manifest (shown even when unauthenticated).
    sleeves = man.get("sleeves") or man.get("legs") or man.get("members") or []
    n = man.get("n_sleeves")
    if not isinstance(n, int):
        n = len(sleeves) if sleeves else None
    book = str(man.get("book") or "")
    status = str(man.get("status") or "")
    acct_m = re.search(r"(\d{6,})", book)
    account = acct_m.group(1) if acct_m else None
    val = f"{n} Sleeves" if isinstance(n, int) else "?"

    level, notes = _authenticate_deploy(stamp, src, mpath, man)
    authed = (level == L_GREEN)
    if authed:
        detail = f"{book or mpath.name} · signiert & authentifiziert · src={src}"
    else:
        detail = (f"{book or mpath.name} · NICHT authentifiziert ({'; '.join(notes)}) · src={src}")
    lamp = _lamp("deploy", "Deployed-Manifest", "Manifest", level, val, detail)
    return {"lamp": lamp, "expected_sleeves": n, "account": account,
            "manifest_status": status, "manifest_path": str(mpath), "authenticated": authed}


def live_status(paths=None, now=None) -> dict:
    """Aggregate the state-file-only live status lamp. Pure over (paths, now):
    no process probe, no T_Live access. Overall = worst sub-lamp; a non-green
    (RED or UNKNOWN) overall is surfaced to the subject and the top summary."""
    P_ = _resolve_paths(paths)
    now = now or _utc_now()
    dep = _lamp_deployment(P_, now)
    lamps = [
        _lamp_watchdog(P_, now),
        _lamp_ddguard(P_, now),
        _lamp_ftmo(P_, now),
        _lamp_contract(P_, now),
        _lamp_news(P_, now),
        dep["lamp"],
    ]
    overall = _worst([l["level"] for l in lamps])
    nongreen = [l for l in lamps if l["level"] != L_GREEN]
    nongreen.sort(key=lambda l: -_LEVEL_RANK.get(l["level"], 2))
    ftmo_lamp = next((l for l in lamps if l["key"] == "ftmo"), None)
    ftmo_prose = (ftmo_lamp or {}).get("prose") or "FTMO: Status unbekannt."

    if overall == L_GREEN:
        subject_reason = ""
        summary = "Alle Live-Quellen frisch & im grünen Bereich."
    else:
        lead = nongreen[0]
        subject_reason = f"{lead['short']} {lead['level']}"
        parts = [f"{l['short']} {l['level']}" for l in nongreen]
        summary = "Nicht-grün: " + " · ".join(parts)

    return {
        "overall": overall,
        "color": _level_color(overall),
        "lamps": lamps,
        "nongreen": nongreen,
        "expected_sleeves": dep["expected_sleeves"],
        "account": dep["account"],
        "manifest_status": dep["manifest_status"],
        "manifest_path": dep["manifest_path"],
        "deploy_authenticated": dep["authenticated"],
        "ftmo_prose": ftmo_prose,
        "subject_reason": subject_reason,
        "summary": summary,
    }


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


def render_live_section(live: dict) -> str:
    """Section 0 — the live-truth status lamp (state-file only). First block of
    the mail: big overall lamp + one line per source. Non-green sources are
    never hidden; absence renders UNBEKANNT, never green."""
    overall = live["overall"]
    color = live["color"]
    rows = ""
    for l in live["lamps"]:
        lc = _level_color(l["level"])
        age_txt = _age(l["age_sec"]) if l.get("age_sec") is not None else ""
        right = (f'<span style="color:{lc};font-weight:700;">{e(l["level"])}</span>'
                 f'<span style="color:{P["text_subtle"]};"> · {e(l["value"])}</span>'
                 + (f'<span style="color:{P["text_subtle"]};"> · {e(age_txt)}</span>' if age_txt else ""))
        rows += _list_line(
            f'<b style="color:{P["text"]};">{e(l["label"])}</b>'
            f'<span style="display:block;font-size:10px;color:{P["text_subtle"]};'
            f'line-height:1.3;margin-top:1px;">{e(l["detail"])}</span>',
            right)
    lamp_block = (
        f'<table width="100%" cellpadding="0" cellspacing="0" border="0" '
        f'style="background:{P["surface_2"]};border:1px solid {P["border"]};"><tr>'
        f'<td width="96" align="center" style="padding:12px 6px;background:{color};">'
        f'<span style="font-size:15px;font-weight:800;color:{P["surface_1"]};'
        f'letter-spacing:1px;">{e(overall)}</span></td>'
        f'<td style="padding:10px 14px;font-size:12px;color:{P["text_dim"]};line-height:1.4;">'
        f'{e(live["summary"])}</td></tr></table>'
    )
    return (
        _section_open("Live-Ampel · Status", color, "state-file · kein Prozess-Probe")
        + _row(lamp_block + rows)
    )


def render_html(data: dict) -> str:
    live = data["live"]
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
    exp_sleeves = live.get("expected_sleeves")
    exp_txt = exp_sleeves if isinstance(exp_sleeves, int) else "?"
    logs_val = f'{logs_today if logs_today is not None else "n/a"}<span style="font-size:13px;color:{P["text_muted"]};">/{exp_txt}</span>'
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
    # FTMO prose is generated from the account state (never retained text). The
    # left-border colour tracks the FTMO lamp so a red account is visible here too.
    ftmo_lamp = next((l for l in live["lamps"] if l["key"] == "ftmo"), None)
    ftmo_col = _level_color((ftmo_lamp or {}).get("level", L_UNKNOWN))
    ftmo = (
        f'<div style="margin-top:10px;padding:8px 11px;background:{P["surface_0"]};'
        f'border-left:3px solid {ftmo_col};font-size:11px;color:{P["text_muted"]};">'
        f'<b style="color:{P["text_dim"]};">FTMO:</b> {e(live["ftmo_prose"])}</div>'
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

    # ── Section 0: LIVE-AMPEL (first block — live-truth first) ───────────
    sec0 = render_live_section(live)

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
        f'{header}{sec0}{sec1}{sec2}{sec3}{sec4}{sec5}{sec6}{footer}'
        f'</table></td></tr></table></body></html>'
    )


def render_text(data: dict) -> str:
    """Concise German plaintext fallback (multipart/alternative)."""
    nb, fr, fl = data["night"], data["frontier"], data["factory"]
    qt, hb = data["quota"], data["heartbeats"]
    live = data["live"]
    L = []
    L.append(f"QM MORGENBRIEFING {data['date_h']}  (gerendert {data['now_local']} {data['tz']})")
    L.append("=" * 60)
    L.append("")
    L.append(f"0) LIVE-AMPEL: {live['overall']} — {live['summary']}")
    for l in live["lamps"]:
        age_txt = f" (Alter {_age(l['age_sec'])})" if l.get("age_sec") is not None else ""
        L.append(f"   - {l['label']}: {l['level']} · {l['value']}{age_txt} — {l['detail']}")
    L.append("")
    exp_sleeves = live.get("expected_sleeves")
    exp_txt = exp_sleeves if isinstance(exp_sleeves, int) else "?"
    L.append("1) LIVE-BUCH · NACHTBILANZ (DXZ Final-24)")
    L.append(f"   Equity (EA-emittiert, nicht realtime): {_money(nb.get('equity'))}"
             f"  [Stand {str(nb.get('equity_ts') or 'n/a')[:16].replace('T',' ')} UTC]")
    L.append(f"   Delta vs Vortag-Schluss: {_delta(nb.get('delta_prev'))}")
    L.append(f"   Deals (letzte 2 Journaltage): {nb.get('deals')}"
             f"  | Journal {nb.get('journal_date')} Alter {_age(nb.get('journal_age_sec'))}"
             f"  | Fehler-Zeilen {nb.get('err_lines')}")
    L.append(f"   EA-Logs aktiv heute: {nb.get('ea_logs_today')}/{exp_txt}")
    L.append(f"   {live['ftmo_prose']}")
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
    live = data["live"]
    fl = data["factory"]
    fr = data["frontier"]
    fresh = len(fr.get("fresh_pass") or [])
    kand = f"{fresh} neue Kand." if fresh else "0 neue Kand."
    # Live-truth first: a red/unknown live condition MUST reach the subject line.
    reason = live.get("subject_reason") or ""
    live_frag = f"LIVE {live['overall']}" + (f" ({reason})" if reason else "")
    return (f"[QM] Morgenbriefing {data['date_iso']} — {live_frag} · "
            f"Factory {fl['label']} · {kand}")


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
        "live": live_status(),
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

    # Mail first — the 06:00 delivery must never wait on the Drive mount.
    result = send_mail(subject, text_body, html_body)
    print(json.dumps({"subject": subject, **result}, indent=2))

    # Vault archive (timestamped — scrollable off-VPS history). The per-user
    # GoogleDriveFS mount can lag or drop in the non-interactive session
    # (2026-07-20: the 04:45 backup and this 06:00 write hit the same outage
    # window), and the scheduled task discards stdout — so wait for the mount
    # and leave an on-disk trace either way instead of failing silently.
    def _trace(msg: str) -> None:
        line = f"{_utc_now().strftime('%Y-%m-%dT%H:%M:%SZ')} {msg}"
        print(line)
        try:
            REPORTS_STATE.mkdir(parents=True, exist_ok=True)
            with (REPORTS_STATE / "morning_brief.log").open("a", encoding="utf-8") as fh:
                fh.write(line + "\n")
        except Exception:
            pass

    deadline = time.monotonic() + 360.0
    while not VAULT_DIR.parent.exists() and time.monotonic() < deadline:
        time.sleep(20.0)
    try:
        VAULT_DIR.mkdir(parents=True, exist_ok=True)
        (VAULT_DIR / f"{data['date_iso']}_morning_brief.html").write_text(
            html_body, encoding="utf-8", newline="\n")
        (VAULT_DIR / f"{data['date_iso']}_morning_brief.md").write_text(
            text_body, encoding="utf-8", newline="\n")
        _trace(f"vault archive written: {VAULT_DIR}")
    except Exception as exc:
        _trace(f"VAULT_WRITE_FAILED (mail unaffected): {exc!r}")

    return 0 if result.get("sent") else 1


if __name__ == "__main__":
    sys.exit(main())
