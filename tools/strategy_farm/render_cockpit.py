"""QM strategy_farm cockpit — visual "what's happening NOW" dashboard.

Renders D:/QM/strategy_farm/dashboards/cockpit.html every 2 min.
Layout designed for OWNER's three primary questions (OWNER rework call 2026-07-07):
  1. Is real money OK?          → LIVE MONEY row (DXZ book pulse + FTMO trial pulse)
  2. What must I (OWNER) decide? → OWNER DECISIONS (curated feed + Q12 pool;
                                    agent work queues are NOT owner decisions)
  3. Is the factory running?     → AGENT STATUS + health pill (CRITICAL only
                                    when the factory itself is down)

Visual hierarchy:
  TOPBAR  — health pill; message names the failing factory check when not NOMINAL
  MONEY   — DXZ live book / FTMO trial / next OWNER gate / mission target
  DECIDE  — OWNER DECISIONS (left) + AGENT STATUS incl. T1-T10 fleet (right)
  COMPANY — frontier tiles, per-phase pipeline progress, funnel, daily controlling

Removed 2026-07-07 (OWNER): Recent Events tail (all-red noise), Q08 Portfolio
Rescue table, Heureka leader + Next Actions (stale task-table derivations that
contradicted the Q12 frontier).

QM brand tokens from branding/brand_tokens.json.
"""

from __future__ import annotations

import csv
import datetime as dt
import glob
import html
import json
import math
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

try:  # package import in tests and module consumers
    from tools.strategy_farm.pipeline_books_dashboard_status import program_status_snapshot
except ModuleNotFoundError:  # direct ``python tools/strategy_farm/render_cockpit.py``
    from pipeline_books_dashboard_status import program_status_snapshot

try:  # package import in tests and module consumers
    from tools.strategy_farm.optimization_dashboard_status import (
        optimization_track_snapshot,
        successful_phase_counts,
    )
except ModuleNotFoundError:  # direct ``python tools/strategy_farm/render_cockpit.py``
    from optimization_dashboard_status import (
        optimization_track_snapshot,
        successful_phase_counts,
    )

try:  # package import in tests and module consumers
    from tools.strategy_farm.phase_ids import (
        PHASE_ORDER as Q_DISPLAY_ORDER,
        Q_TO_LEGACY_ALIASES,
        phase_label,
    )
except ModuleNotFoundError:  # direct ``python tools/strategy_farm/render_cockpit.py``
    from phase_ids import PHASE_ORDER as Q_DISPLAY_ORDER, Q_TO_LEGACY_ALIASES, phase_label

ROOT = Path(r"D:\QM\strategy_farm")
REPO = Path(r"C:\QM\repo")
DB = ROOT / "state" / "farm_state.sqlite"
DASH = ROOT / "dashboards"
COCKPIT = DASH / "cockpit.html"
LOG_DIR = ROOT / "logs"
CARDS_DRAFT = ROOT / "artifacts" / "cards_draft"
CARDS_APPROVED = ROOT / "artifacts" / "cards_approved"
QUOTA_SNAPSHOT = ROOT / "state" / "quota_snapshot.json"
REPORTS_STATE = Path(r"D:\QM\reports\state")
PORTFOLIO_REPORT_ROOT = Path(r"D:\QM\reports\portfolio")
LIVE_BOOK_PULSE = REPORTS_STATE / "live_book_pulse.json"
FTMO_TRIAL_PULSE = REPORTS_STATE / "ftmo_trial_pulse.json"
OWNER_DECISIONS_FILE = REPORTS_STATE / "owner_decisions.json"
PROGRAM_REPO = Path(__file__).resolve().parents[2]
PROGRAM_STATUS_FILE = (
    PROGRAM_REPO
    / "tools"
    / "strategy_farm"
    / "config"
    / "pipeline_books_program_status.v1.json"
)

# Cockpit v7 additions (2026-07-19)
# FACTORY_OFF.flag distinguishes an intentional maintenance stop from a genuine
# outage — the top-bar status must never scream CRITICAL for an intentional OFF.
FACTORY_OFF_FLAG = ROOT / "state" / "FACTORY_OFF.flag"
# T_Live is READ-ONLY for the cockpit (never write here). The portable data
# folder is MT5_Base; the terminal journal and the EA-emitted JSON logs live
# under it.
TLIVE_ROOT = Path(r"C:\QM\mt5\T_Live")
TLIVE_JOURNAL_DIR = TLIVE_ROOT / "MT5_Base" / "logs"
TLIVE_EA_LOG_DIR = TLIVE_ROOT / "MT5_Base" / "MQL5" / "Files" / "QM"
# Broker deal history exported read-only by the AccountMonitor EA (~60s after
# new deals). Σ(profit+swap+commission+fee) over all rows incl. the BALANCE
# deposit row = account balance after the last recorded deal — equals true
# equity whenever the book is flat. Commission AND swap are broker-booked per
# deal on the DXZ account (verified 2026-07-25: 52/55 deals commission,
# both sides charged; Σ comm −$44.30, Σ swap −$48.36).
TLIVE_MONITOR_DIR = TLIVE_EA_LOG_DIR / "journal"
TLIVE_DEALS_CSV = TLIVE_MONITOR_DIR / "live_deals_normalized.csv"
# FTMO terminal (non-portable install): AccountMonitor deployed 2026-07-25
# (OWNER "ja, deploy es!"), chart13 in the contract-verified Default profile.
FTMO_MONITOR_DIR = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM\journal"
)
FTMO_DEALS_CSV = FTMO_MONITOR_DIR / "live_deals_normalized.csv"
LIVE_BOOK_SLEEVES = 24  # current live book size (label denominator only)

LIFETIME_PASS_CHIP_LABEL = "Q00-Q16 // PIPELINE OCCUPANCY (LIFETIME, MIXED ERAS)"
PIPELINE_COHORT_SCHEMA_VERSION = "qm.cockpit-adjacent-cohort/v1"
PIPELINE_COHORT_BUCKETS = ("NO_ROW", "OPEN", "INFRA", "SOFT", "HARD", "PASS")
PIPELINE_COHORT_TRANSITIONS = (
    ("Q02 -> Q03", "Q02", "Q03", 2),
    ("Q03 -> Q04", "Q03", "Q04", 3),
    ("Q04 -> Q05", "Q04", "Q05", 4),
    ("Q05 -> Q06", "Q05", "Q06", 5),
    ("Q06 -> Q07", "Q06", "Q07", 6),
    ("Q07 -> Q08", "Q07", "Q08", 7),
)




def e(s) -> str:
    """HTML-escape with str() coercion; None -> "". Matches dashboards/render_dashboards.py:e()."""
    return html.escape(str(s)) if s is not None else ""


def _parse_codex_text(text: str) -> dict:
    """Extract usage from chatgpt.com codex analytics page text.

    DOM is German (e.g. '5 Stunden Nutzungsgrenze 96 % verbleibend
    Zuruecksetzungen 17.05.2026 2:23'). Codex reports REMAINING %, not used.
    We invert to %used so cockpit traffic-lighting stays consistent.
    """
    out = {}
    # 5h: tolerate both German ('5 Stunden') and English ('5-hour' / '5 hour')
    m = re.search(
        r"(?:5\s*Stunden|5[-\s]?hour|hourly)[^%]{0,80}?(\d+(?:\.\d+)?)\s*%\s*(verbleibend|remaining)",
        text, re.IGNORECASE,
    )
    if m:
        out["hour_pct"] = 100.0 - float(m.group(1))
    else:
        m = re.search(
            r"(?:5\s*Stunden|5[-\s]?hour|hourly)[^%]{0,80}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
            text, re.IGNORECASE,
        )
        if m:
            out["hour_pct"] = float(m.group(1))
    # Weekly
    m = re.search(
        r"(?:W(?:o|ö)chentlich|weekly|week)[^%]{0,80}?(\d+(?:\.\d+)?)\s*%\s*(verbleibend|remaining)",
        text, re.IGNORECASE,
    )
    if m:
        out["week_pct"] = 100.0 - float(m.group(1))
    else:
        m = re.search(
            r"(?:W(?:o|ö)chentlich|weekly|week)[^%]{0,80}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
            text, re.IGNORECASE,
        )
        if m:
            out["week_pct"] = float(m.group(1))
    # Reset timestamps (e.g. '17.05.2026 2:23')
    m = re.search(
        r"5\s*Stunden\s*Nutzungsgrenze\s*\d+\s*%\s*verbleibend\s*Zur(?:u|ü)cksetzungen?\s*([\d.]+\s*[\d:]+)",
        text, re.IGNORECASE,
    )
    if m:
        out["hour_reset"] = m.group(1).strip()
    m = re.search(
        r"W(?:o|ö)chentlich(?:e)?\s*Nutzungsgrenze\s*\d+\s*%\s*verbleibend\s*Zur(?:u|ü)cksetzungen?\s*([\d.]+\s*[\d:]+)",
        text, re.IGNORECASE,
    )
    if m:
        out["week_reset"] = m.group(1).strip()
    return out


def _parse_claude_text(text: str) -> dict:
    """Extract usage from claude.ai/settings/usage page text.

    DOM is German (e.g. 'Aktuelle Sitzung Zuruecksetzung in 3 Std. 2 Min.
    12 % verwendet Woechentliche Limits ... Alle Modelle ... 16 % verwendet').
    Claude reports USED %, no inversion needed.
    """
    out = {}
    # Plan label
    m = re.search(r"Plan-?Nutzungslimits\s+(Max\s*\([\d]+x\)|Max|Pro|Team|Enterprise|Free)", text, re.IGNORECASE)
    if m:
        out["plan"] = m.group(1).strip()
    # 5-hour: "Aktuelle Sitzung ... XX % verwendet" (German) or "Current session ... XX % used"
    m = re.search(
        r"(?:Aktuelle\s+Sitzung|Current\s+session)[^%]{0,200}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
        text, re.IGNORECASE,
    )
    if m:
        out["hour_pct"] = float(m.group(1))
    # Weekly all models: "Alle Modelle ... XX % verwendet"
    m = re.search(
        r"(?:Alle\s+Modelle|All\s+models)[^%]{0,200}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
        text, re.IGNORECASE,
    )
    if m:
        out["week_pct"] = float(m.group(1))
    # Sonnet-only weekly (informational)
    m = re.search(
        r"(?:Nur\s+Sonnet|Sonnet\s+only)[^%]{0,200}?(\d+(?:\.\d+)?)\s*%\s*(verwendet|used)",
        text, re.IGNORECASE,
    )
    if m:
        out["sonnet_pct"] = float(m.group(1))
    # 5h reset (e.g. "Zuruecksetzung in 3 Std. 2 Min.")
    m = re.search(
        r"(?:Aktuelle\s+Sitzung|Current\s+session)\s*Zur(?:u|ü)cksetzung\s+in\s+([^.\n]+?)\s*(\d+\s*%|\.)",
        text, re.IGNORECASE,
    )
    if m:
        out["hour_reset"] = m.group(1).strip().rstrip(",")
    # Weekly reset (e.g. "Zuruecksetzung Fr., 00:00")
    m = re.search(
        r"(?:Alle\s+Modelle|All\s+models)\s*Zur(?:u|ü)cksetzung\s+([^\d]+\d{1,2}:\d{2})",
        text, re.IGNORECASE,
    )
    if m:
        out["week_reset"] = m.group(1).strip()
    return out


def quota_snapshot() -> dict:
    """Read the merged quota snapshot from D:/QM/.../quota_snapshot.json.

    The normal producer is quota_pull.py, which stores shape-normalized API
    values in ``data.structured``. Legacy browser userscripts may still POST DOM
    text to quota_receiver.py; that text remains a supported fallback.

    Structured values are already USED percentages with their matching reset
    timestamps. DOM parsing happens here only for fields the structured block
    does not provide.

    Returns per-source dicts: {fresh, age_sec, hour_pct, week_pct, plan,
    hour_reset, week_reset, meters, matches, url}.
    """
    out: dict = {}
    try:
        if not QUOTA_SNAPSHOT.exists():
            return out
        snap = json.loads(QUOTA_SNAPSHOT.read_text(encoding="utf-8"))
    except Exception:
        return out
    now = dt.datetime.now(dt.timezone.utc)
    for src in ("codex", "claude"):
        s = snap.get(src) or {}
        if not s:
            continue
        received_at = s.get("received_at") or s.get("scraped_at")
        age_sec = None
        if received_at:
            try:
                t = dt.datetime.fromisoformat(received_at.replace("Z", "+00:00"))
                age_sec = int((now - t).total_seconds())
            except Exception:
                age_sec = None
        data = s.get("data") or {}
        matches = data.get("matches") or {}
        # quota_pull.py (headless API pull) writes a structured block with USED %
        # already extracted — prefer it over the legacy DOM text-parse path.
        structured = data.get("structured") or {}
        text = data.get("full_text_head") or ""
        parsed = _parse_codex_text(text) if src == "codex" else _parse_claude_text(text)

        def _pick(key):
            v = structured.get(key)
            return v if v is not None else parsed.get(key)

        out[src] = {
            "fresh": age_sec is not None and age_sec <= 300,
            "age_sec": age_sec,
            "hour_pct": _pick("hour_pct"),
            "week_pct": _pick("week_pct"),
            "hour_reset": _pick("hour_reset"),
            "week_reset": _pick("week_reset"),
            "sonnet_pct": _pick("sonnet_pct"),
            "plan": structured.get("plan") or parsed.get("plan") or matches.get("plan_label"),
            "meters": data.get("meters") or [],
            "matches": matches,
            "url": data.get("url"),
        }
    return out


# === Data collection ===

def db_rows(query: str, params: tuple = ()) -> list[dict]:
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    try:
        con.execute("PRAGMA query_only=ON")
        return [dict(r) for r in con.execute(query, params).fetchall()]
    finally:
        con.close()


def db_rows_ro(query: str, params: tuple = ()) -> list[dict]:
    """Read-only DB query via the sqlite ``mode=ro`` URI.

    Used by the cockpit-v7 additions (LIVE BOOK / FRONTIER). The connection is
    opened strictly read-only so a query can never mutate farm_state.sqlite.
    """
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    try:
        con.execute("PRAGMA query_only=ON")
        return [dict(r) for r in con.execute(query, params).fetchall()]
    finally:
        con.close()


def pipeline_cohort_snapshot() -> dict:
    """Return the versioned, read-only adjacent-gate cohort projection.

    The historical phase chips intentionally retain lifetime distinct-PASS
    semantics. This projection supplies the missing denominator: each row begins
    with the upstream phase's strict-PASS pair set and assigns every pair to one
    exclusive next-gate bucket. Canonical Q rows are used so legacy aliases do
    not silently change this v1 contract.
    """

    out = {
        "schema_version": PIPELINE_COHORT_SCHEMA_VERSION,
        "available": False,
        "buckets": list(PIPELINE_COHORT_BUCKETS),
        "transitions": [],
        "q09_arms": [],
        "q09_both_authenticated": 0,
        "q09_upstream_pass": 0,
        "q10_historical_visible": 0,
        "q10_current_contract_bound": 0,
    }
    try:
        adjacent_rows = db_rows(
            """
            WITH transitions(label, upstream_phase, next_phase, ordinal) AS (
              VALUES
                ('Q02 -> Q03','Q02','Q03',2),
                ('Q03 -> Q04','Q03','Q04',3),
                ('Q04 -> Q05','Q04','Q05',4),
                ('Q05 -> Q06','Q05','Q06',5),
                ('Q06 -> Q07','Q06','Q07',6),
                ('Q07 -> Q08','Q07','Q08',7)
            ), upstream AS (
              SELECT t.label,t.upstream_phase,t.next_phase,t.ordinal,w.ea_id,w.symbol
              FROM transitions t
              JOIN work_items w
                ON UPPER(w.phase)=t.upstream_phase AND UPPER(w.verdict)='PASS'
              GROUP BY t.label,t.upstream_phase,t.next_phase,t.ordinal,w.ea_id,w.symbol
            ), flags AS (
              SELECT u.label,u.upstream_phase,u.next_phase,u.ordinal,u.ea_id,u.symbol,
                     COUNT(w.id) AS row_count,
                     MAX(CASE WHEN UPPER(COALESCE(w.verdict,''))='PASS'
                              THEN 1 ELSE 0 END) AS is_pass,
                     MAX(CASE WHEN UPPER(COALESCE(w.verdict,'')) IN
                                      ('FAIL','FAIL_HARD','RETIRE','RETIRED_LOW_FREQ')
                              THEN 1 ELSE 0 END) AS is_hard,
                     MAX(CASE WHEN UPPER(COALESCE(w.verdict,'')) IN
                                      ('FAIL_SOFT','PASS_SOFT','PASS_LOWFREQ',
                                       'FAIL_DD_PORTFOLIO_REVIEW','NEED_MORE_DATA')
                              THEN 1 ELSE 0 END) AS is_soft,
                     MAX(CASE WHEN UPPER(COALESCE(w.verdict,'')) IN
                                      ('INFRA_FAIL','INVALID','INVALID_EVIDENCE',
                                       'ZERO_TRADES','WAITING_INPUT')
                                   OR LOWER(COALESCE(w.status,''))='failed'
                              THEN 1 ELSE 0 END) AS is_infra
              FROM upstream u
              LEFT JOIN work_items w
                ON UPPER(w.phase)=u.next_phase
               AND w.ea_id=u.ea_id AND w.symbol=u.symbol
              GROUP BY u.label,u.upstream_phase,u.next_phase,u.ordinal,u.ea_id,u.symbol
            ), classified AS (
              SELECT label,upstream_phase,next_phase,ordinal,
                     CASE WHEN row_count=0 THEN 'NO_ROW'
                          WHEN is_pass=1 THEN 'PASS'
                          WHEN is_hard=1 THEN 'HARD'
                          WHEN is_soft=1 THEN 'SOFT'
                          WHEN is_infra=1 THEN 'INFRA'
                          ELSE 'OPEN' END AS bucket
              FROM flags
            )
            SELECT label,upstream_phase,next_phase,ordinal,bucket,COUNT(*) AS pairs
            FROM classified
            GROUP BY label,upstream_phase,next_phase,ordinal,bucket
            ORDER BY ordinal,bucket
            """
        )

        by_transition: dict[str, dict[str, int]] = {}
        for row in adjacent_rows:
            label = str(row.get("label") or "")
            by_transition.setdefault(label, {})[str(row.get("bucket") or "")] = int(
                row.get("pairs") or 0
            )
        for label, upstream_phase, next_phase, ordinal in PIPELINE_COHORT_TRANSITIONS:
            counts = {
                bucket: by_transition.get(label, {}).get(bucket, 0)
                for bucket in PIPELINE_COHORT_BUCKETS
            }
            out["transitions"].append(
                {
                    "label": label,
                    "upstream_phase": upstream_phase,
                    "next_phase": next_phase,
                    "ordinal": ordinal,
                    "upstream_pass": sum(counts.values()),
                    "counts": counts,
                }
            )

        q09_rows = db_rows(
            """
            WITH source AS (
              SELECT DISTINCT ea_id,symbol
              FROM work_items
              WHERE UPPER(phase)='Q08' AND UPPER(verdict)='PASS'
            ), arms(arm) AS (
              VALUES ('Q09_NEWS'),('Q09_PORTFOLIO')
            ), flags AS (
              SELECT a.arm,s.ea_id,s.symbol,COUNT(w.id) AS row_count,
                     MAX(CASE WHEN
                           (a.arm='Q09_NEWS' AND UPPER(COALESCE(w.verdict,''))='CONFIG_LOCKED')
                           OR (a.arm='Q09_PORTFOLIO' AND UPPER(COALESCE(w.verdict,''))='PASS_PORTFOLIO')
                         THEN 1 ELSE 0 END) AS is_pass,
                     MAX(CASE WHEN UPPER(COALESCE(w.verdict,'')) IN
                                      ('FAIL_PORTFOLIO','FAIL','FAIL_HARD')
                              THEN 1 ELSE 0 END) AS is_hard,
                     MAX(CASE WHEN UPPER(COALESCE(w.verdict,'')) IN
                                      ('NEED_MORE_DATA','FAIL_SOFT',
                                       'FAIL_DD_PORTFOLIO_REVIEW')
                              THEN 1 ELSE 0 END) AS is_soft,
                     MAX(CASE WHEN UPPER(COALESCE(w.verdict,'')) IN
                                      ('INFRA_FAIL','INVALID','INVALID_EVIDENCE',
                                       'ZERO_TRADES','WAITING_INPUT')
                                   OR LOWER(COALESCE(w.status,''))='failed'
                              THEN 1 ELSE 0 END) AS is_infra,
                     MAX(CASE WHEN UPPER(COALESCE(w.verdict,'')) IN
                                      ('REVIEW_REQUIRED','PENDING_RUNNER')
                                   OR LOWER(COALESCE(w.status,'')) IN ('pending','active')
                                   OR w.verdict IS NULL
                              THEN 1 ELSE 0 END) AS is_open
              FROM source s CROSS JOIN arms a
              LEFT JOIN work_items w
                ON UPPER(w.phase)=a.arm
               AND w.ea_id=s.ea_id AND w.symbol=s.symbol
              GROUP BY a.arm,s.ea_id,s.symbol
            ), classified AS (
              SELECT arm,ea_id,symbol,
                     CASE WHEN row_count=0 THEN 'NO_ROW'
                          WHEN is_pass=1 THEN 'PASS'
                          WHEN is_hard=1 THEN 'HARD'
                          WHEN is_soft=1 THEN 'SOFT'
                          WHEN is_open=1 THEN 'OPEN'
                          WHEN is_infra=1 THEN 'INFRA'
                          ELSE 'OPEN' END AS bucket
              FROM flags
            ), news_authenticated AS (
              SELECT DISTINCT s.ea_id,s.symbol
              FROM source s JOIN work_items w USING(ea_id,symbol)
              WHERE UPPER(w.phase)='Q09_NEWS' AND UPPER(w.verdict)='CONFIG_LOCKED'
            ), portfolio_authenticated AS (
              SELECT DISTINCT s.ea_id,s.symbol
              FROM source s JOIN work_items w USING(ea_id,symbol)
              WHERE UPPER(w.phase)='Q09_PORTFOLIO' AND UPPER(w.verdict)='PASS_PORTFOLIO'
            )
            SELECT 'ARM' AS row_type,arm AS label,bucket,COUNT(*) AS pairs
            FROM classified GROUP BY arm,bucket
            UNION ALL
            SELECT 'BOTH_AUTHENTICATED' AS row_type,'Q09' AS label,'PASS' AS bucket,
                   COUNT(*) AS pairs
            FROM news_authenticated n
            JOIN portfolio_authenticated p USING(ea_id,symbol)
            """
        )
        arm_counts: dict[str, dict[str, int]] = {}
        for row in q09_rows:
            if row.get("row_type") == "BOTH_AUTHENTICATED":
                out["q09_both_authenticated"] = int(row.get("pairs") or 0)
                continue
            label = str(row.get("label") or "")
            arm_counts.setdefault(label, {})[str(row.get("bucket") or "")] = int(
                row.get("pairs") or 0
            )
        for arm in ("Q09_NEWS", "Q09_PORTFOLIO"):
            counts = {
                bucket: arm_counts.get(arm, {}).get(bucket, 0)
                for bucket in PIPELINE_COHORT_BUCKETS
            }
            upstream_pass = sum(counts.values())
            out["q09_arms"].append(
                {
                    "label": arm,
                    "upstream_phase": "Q08",
                    "upstream_pass": upstream_pass,
                    "counts": counts,
                }
            )
            out["q09_upstream_pass"] = max(out["q09_upstream_pass"], upstream_pass)

        q10_rows = db_rows(
            """
            SELECT
              COUNT(DISTINCT CASE
                WHEN UPPER(phase)='Q10' AND UPPER(COALESCE(verdict,''))='PASS'
                THEN ea_id || '|' || symbol END) AS historical_visible,
              COUNT(DISTINCT CASE
                WHEN UPPER(phase)='Q10' AND UPPER(COALESCE(verdict,''))='PASS'
                 AND EXISTS (
                   SELECT 1 FROM work_item_dependencies d
                   WHERE d.child_work_item_id=work_items.id
                     AND d.dependency_role='Q09_NEWS'
                 )
                 AND EXISTS (
                   SELECT 1 FROM work_item_dependencies d
                   WHERE d.child_work_item_id=work_items.id
                     AND d.dependency_role='Q09_PORTFOLIO'
                 )
                THEN ea_id || '|' || symbol END) AS current_contract_bound
            FROM work_items
            """
        )
        if q10_rows:
            out["q10_historical_visible"] = int(q10_rows[0].get("historical_visible") or 0)
            out["q10_current_contract_bound"] = int(
                q10_rows[0].get("current_contract_bound") or 0
            )
        out["available"] = True
    except sqlite3.Error as exc:
        out["error"] = str(exc)
    return out


def render_pipeline_cohorts(snapshot: dict) -> str:
    """Render the compact adjacent-cohort contract panel."""

    schema_version = str(snapshot.get("schema_version") or PIPELINE_COHORT_SCHEMA_VERSION)
    if not snapshot.get("available"):
        return (
            '<div class="section cohort-section">'
            '<div class="section-head"><span class="section-glyph"></span>'
            '<span class="section-title">Contract Cohorts // Adjacent Gates</span>'
            f'<span class="section-aux">{e(schema_version)}</span></div>'
            '<div class="cohort-unavailable">QUERY UNAVAILABLE // '
            f'{e(snapshot.get("error") or "unknown database error")}</div></div>'
        )

    def cohort_row(label: str, upstream_pass: int, counts: dict) -> str:
        cells = "".join(
            f'<td class="cohort-{bucket.lower()}">{int(counts.get(bucket, 0)):,}</td>'
            for bucket in PIPELINE_COHORT_BUCKETS
        )
        return (
            f'<tr><th scope="row">{e(label)}</th>'
            f'<td class="cohort-up">{int(upstream_pass):,}</td>{cells}</tr>'
        )

    transition_rows = "".join(
        cohort_row(
            str(row.get("label") or ""),
            int(row.get("upstream_pass") or 0),
            row.get("counts") or {},
        )
        for row in snapshot.get("transitions") or []
    )
    q09_rows = "".join(
        cohort_row(
            f"Q08 -> {str(row.get('label') or '').replace('_', ' ')}",
            int(row.get("upstream_pass") or 0),
            row.get("counts") or {},
        )
        for row in snapshot.get("q09_arms") or []
    )
    headers = "".join(f"<th>{e(bucket)}</th>" for bucket in PIPELINE_COHORT_BUCKETS)
    return f"""
  <div class="section cohort-section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Contract Cohorts // Adjacent Gates</span>
      <span class="section-aux">{e(schema_version)} // CANONICAL Q ROWS</span>
    </div>
    <div class="cohort-table-wrap">
      <table class="cohort-table">
        <thead><tr><th>TRANSITION</th><th>UP PASS</th>{headers}</tr></thead>
        <tbody>{transition_rows}{q09_rows}</tbody>
      </table>
    </div>
    <div class="cohort-tail">
      <div class="cohort-tail-card">
        <span>Q09 BOTH AUTHENTICATED</span>
        <b>{int(snapshot.get("q09_both_authenticated") or 0):,}</b>
        <small>/ {int(snapshot.get("q09_upstream_pass") or 0):,} Q08 PASS pairs</small>
      </div>
      <div class="cohort-tail-card">
        <span>Q10 HISTORICAL VISIBLE</span>
        <b>{int(snapshot.get("q10_historical_visible") or 0):,}</b>
        <small>distinct lifetime PASS pairs</small>
      </div>
      <div class="cohort-tail-card contract-bound">
        <span>Q10 CURRENT CONTRACT BOUND</span>
        <b>{int(snapshot.get("q10_current_contract_bound") or 0):,}</b>
        <small>PASS rows with both Q09 dependency roles</small>
      </div>
    </div>
    <div class="cohort-foot">
      Strict upstream PASS pairs; lifetime canonical-row evidence. Adjacent precedence:
      PASS &gt; HARD &gt; SOFT/PORTFOLIO &gt; INFRA/RETRY &gt; OPEN &gt; NO_ROW;
      Q09 OPEN decision/runner tokens take precedence over prior infra rows.
      Q09 authenticated = CONFIG_LOCKED + PASS_PORTFOLIO for the same Q08 PASS pair.
      Q10 binding is database dependency presence; execution-time hash verification remains
      authoritative. This panel is not a claim of one historical lineage or gate era.
    </div>
  </div>
"""


def render_optimization_track(snapshot: dict) -> str:
    """Render read-only Q14--Q16 outcomes and parked Q11 lane manifests."""

    phase_names = {
        "Q14": "Optimization Admission",
        "Q15": "Challenger Build & Freeze",
        "Q16": "Head-to-Head Requalification",
    }
    phases = snapshot.get("phases") or {}
    phase_cards = []
    for phase in ("Q14", "Q15", "Q16"):
        row = phases.get(phase) or {}
        outcomes = row.get("outcomes") or {}
        outcome_html = "".join(
            f'<span><b>{e(verdict)}</b> {int(count or 0):,}</span>'
            for verdict, count in outcomes.items()
        )
        phase_cards.append(
            '<div class="opt-phase-card">'
            f'<div class="opt-phase-id">{phase}</div>'
            f'<div class="opt-phase-name">{e(phase_names[phase])}</div>'
            f'<div class="opt-phase-total">{int(row.get("total") or 0):,}</div>'
            f'<div class="opt-phase-outcomes">{outcome_html}'
            f'<span><b>OPEN / OTHER</b> {int(row.get("open") or 0):,}</span></div>'
            '</div>'
        )

    book_chips = []
    books = snapshot.get("books") or {}
    for lane in ("Q11_DXZ", "Q11_FTMO"):
        book = books.get(lane) or {"validation": "MISSING", "book_status": "MISSING"}
        validation = str(book.get("validation") or "INVALID").upper()
        css_state = (
            validation.lower()
            if validation in {"VALID", "MISSING", "INVALID"}
            else "invalid"
        )
        details = []
        if book.get("as_of"):
            details.append(str(book["as_of"]))
        if book.get("sleeve_count") is not None:
            details.append(f'{int(book["sleeve_count"]):,} sleeves')
        if book.get("error"):
            details.append(str(book["error"]))
        book_chips.append(
            f'<div class="opt-book-chip {css_state}">'
            f'<span>{e(lane)} // {e(validation)}</span>'
            f'<b>{e(book.get("book_status") or "MISSING")}</b>'
            f'<small>{e(" // ".join(details) or "no parked manifest")}</small>'
            '</div>'
        )

    availability = (
        "READ MODEL AVAILABLE"
        if snapshot.get("available")
        else "READ MODEL UNAVAILABLE"
    )
    error = snapshot.get("error")
    error_html = f'<div class="opt-track-error">{e(error)}</div>' if error else ""
    return f"""
  <div class="section opt-track-section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Optimization Track // Q10 Fork</span>
      <span class="section-aux">{e(snapshot.get("schema_version") or "unknown")} // {availability}</span>
    </div>
    {error_html}
    <div class="opt-track-grid">{''.join(phase_cards)}</div>
    <div class="opt-book-row">{''.join(book_chips)}</div>
    <div class="opt-track-foot">
      Explicit branch only: Q10 &rarr; Q14 &rarr; Q15 &rarr; challenger Q02&ndash;Q10
      &rarr; Q16 &rarr; Q11. Q11_DXZ and Q11_FTMO are storage lanes, not top-level
      phases. This surface is read-only and grants no worker, deployment, terminal,
      money, or AutoTrading authority.
    </div>
  </div>
"""


def _json_from_path(path_value: str | None) -> dict:
    if not path_value:
        return {}
    try:
        path = Path(path_value)
        if not path.exists():
            return {}
        data = json.loads(path.read_text(encoding="utf-8-sig", errors="ignore"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _json_payload(row: dict) -> dict:
    try:
        data = json.loads(row.get("payload_json") or "{}")
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _num(value, digits: int = 2) -> str:
    if isinstance(value, (int, float)):
        return f"{value:,.{digits}f}"
    return "--"


def _q08_tier(verdict: str, payload: dict) -> str:
    verdict = str(verdict or "").upper()
    if verdict in {"FAIL_SOFT", "FAIL_HARD", "INVALID"}:
        return verdict
    classification = payload.get("q08_verdict_classification") or payload.get("verdict_classification")
    if isinstance(classification, dict):
        vals = {str(v).upper() for v in classification.values()}
        if "EDGE_HARD" in vals:
            return "FAIL_HARD"
        if vals & {"EDGE_SOFT", "LOW_SAMPLE"}:
            return "FAIL_SOFT"
    return verdict or "--"


def _q08_reason(payload: dict) -> str:
    classification = payload.get("q08_verdict_classification") or payload.get("verdict_classification")
    if not isinstance(classification, dict):
        return str(payload.get("verdict_reason") or payload.get("reason") or "--")
    ranked = {"EDGE_HARD": 0, "EDGE_SOFT": 1, "LOW_SAMPLE": 2}
    items = [
        (ranked.get(str(tier).upper(), 9), str(gate), str(tier))
        for gate, tier in classification.items()
        if str(tier).upper() not in {"PASS", ""}
    ]
    if not items:
        return str(payload.get("verdict_reason") or "--")
    items.sort()
    return ", ".join(f"{gate}:{tier}" for _, gate, tier in items[:3])


def _q09_priority(row: dict | None) -> int:
    if not row:
        return 99
    verdict = str(row.get("verdict") or "").upper()
    status = str(row.get("status") or "").lower()
    if verdict == "PASS_PORTFOLIO":
        return 0
    if verdict == "FAIL_PORTFOLIO":
        return 1
    if verdict == "NEED_MORE_DATA":
        return 2
    if status == "pending":
        return 3
    return 9


def q08_portfolio_rescue_snapshot(limit: int = 8) -> dict:
    """Read-only Q08 portfolio-rescue state for the cockpit."""
    out = {
        "soft": 0,
        "hard": 0,
        "need_more_data": 0,
        "pending": 0,
        "pass_portfolio": 0,
        "fail_portfolio": 0,
        "candidates": 0,
        "rows": [],
    }
    try:
        q08_rows = db_rows(
            """
            SELECT ea_id, symbol, verdict, payload_json, evidence_path, updated_at
            FROM work_items
            WHERE phase='Q08' AND status='done'
              AND verdict IN ('FAIL_SOFT','FAIL_HARD','FAIL','INVALID')
            ORDER BY updated_at DESC
            """
        )
        q09_rows = db_rows(
            """
            SELECT ea_id, symbol, status, verdict, payload_json, evidence_path, updated_at
            FROM work_items
            WHERE phase='Q09_PORTFOLIO'
            ORDER BY updated_at DESC
            """
        )
    except sqlite3.Error:
        return out
    try:
        pc_rows = db_rows(
            """
            SELECT ea_id, symbol, state, evidence_path, updated_at
            FROM portfolio_candidates
            WHERE state='Q12_REVIEW_READY'
            ORDER BY updated_at DESC
            """
        )
    except sqlite3.Error:
        pc_rows = []

    latest_q08: dict[tuple[str, str], dict] = {}
    for row in q08_rows:
        key = (str(row.get("ea_id") or ""), str(row.get("symbol") or ""))
        if key not in latest_q08:
            latest_q08[key] = row

    latest_q09: dict[tuple[str, str], dict] = {}
    for row in q09_rows:
        key = (str(row.get("ea_id") or ""), str(row.get("symbol") or ""))
        if key not in latest_q09 or _q09_priority(row) < _q09_priority(latest_q09[key]):
            latest_q09[key] = row
        verdict = str(row.get("verdict") or "").upper()
        status = str(row.get("status") or "").lower()
        if status == "pending":
            out["pending"] += 1
        elif verdict == "NEED_MORE_DATA":
            out["need_more_data"] += 1
        elif verdict == "PASS_PORTFOLIO":
            out["pass_portfolio"] += 1
        elif verdict == "FAIL_PORTFOLIO":
            out["fail_portfolio"] += 1

    candidates = {(str(r.get("ea_id") or ""), str(r.get("symbol") or "")): r for r in pc_rows}
    out["candidates"] = len(candidates)

    display_rows = []
    for key, q08 in latest_q08.items():
        payload = {**_json_from_path(q08.get("evidence_path")), **_json_payload(q08)}
        tier = _q08_tier(str(q08.get("verdict") or ""), payload)
        if tier == "FAIL_SOFT":
            out["soft"] += 1
        elif tier == "FAIL_HARD":
            out["hard"] += 1
        q09 = latest_q09.get(key)
        q09_payload = _json_payload(q09) if q09 else {}
        q09_artifact = _json_from_path(q09.get("evidence_path") if q09 else None)
        display_rows.append({
            "ea_id": key[0],
            "symbol": key[1],
            "tier": tier,
            "reason": _q08_reason(payload),
            "q08_trades": payload.get("q08_n_trades") or q09_payload.get("q08_trade_count"),
            "q09_verdict": (q09.get("verdict") if q09 else None) or ("PENDING" if q09 else "--"),
            "portfolio_only": bool(q09_payload.get("portfolio_only") or key in candidates),
            "candidate_state": (candidates.get(key) or {}).get("state") or q09_payload.get("portfolio_candidate_state") or "",
            "corr": q09_artifact.get("max_corr_to_book"),
            "sharpe_delta": (
                q09_artifact.get("sharpe_with") - q09_artifact.get("sharpe_without")
                if isinstance(q09_artifact.get("sharpe_with"), (int, float))
                and isinstance(q09_artifact.get("sharpe_without"), (int, float))
                else None
            ),
            "maxdd_delta": (
                q09_artifact.get("maxdd_with") - q09_artifact.get("maxdd_without")
                if isinstance(q09_artifact.get("maxdd_with"), (int, float))
                and isinstance(q09_artifact.get("maxdd_without"), (int, float))
                else None
            ),
            "pf": q09_artifact.get("standalone_pf"),
            "updated_at": q09.get("updated_at") if q09 else q08.get("updated_at"),
        })
    display_rows.sort(key=lambda r: (r.get("portfolio_only") is not True, r.get("updated_at") or ""), reverse=False)
    out["rows"] = sorted(display_rows, key=lambda r: r.get("updated_at") or "", reverse=True)[:limit]
    return out


def _age_minutes(iso_ts: str | None) -> int | None:
    if not iso_ts:
        return None
    try:
        t = dt.datetime.fromisoformat(str(iso_ts).replace("Z", "+00:00"))
        if t.tzinfo is None:
            t = t.replace(tzinfo=dt.timezone.utc)
        return max(0, int((dt.datetime.now(dt.timezone.utc) - t).total_seconds() // 60))
    except Exception:
        return None


def monitor_account_snapshot(journal_dir: Path) -> dict:
    """READ-ONLY account_snapshot.json from the QM_AccountMonitor EA.

    Timer-driven (60s, fires on weekends too): terminal-truth equity
    INCLUDING floating P&L, plus position count. The freshest per-account
    figure available — callers must gate on age_min before trusting it.
    """
    out: dict = {"equity": None, "balance": None, "positions": None,
                 "floating": None, "age_min": None}
    try:
        d = json.loads(
            (journal_dir / "account_snapshot.json").read_text(encoding="utf-8")
        )
        eq = d.get("equity")
        if isinstance(eq, (int, float)) and math.isfinite(eq):
            out["equity"] = eq
        bal = d.get("balance")
        if isinstance(bal, (int, float)) and math.isfinite(bal):
            out["balance"] = bal
        out["positions"] = d.get("open_positions")
        out["floating"] = d.get("floating_pnl")
        out["age_min"] = _age_minutes(d.get("time_utc"))
    except Exception:
        pass
    return out


def deal_history_balance(deals_csv: Path) -> dict:
    """READ-ONLY account balance from an AccountMonitor deal export.

    balance = Σ(profit+swap+commission+fee) over ALL rows including the
    BALANCE deposit row. This is exact realized truth (costs included) and
    equals current equity whenever the book is flat — fresher than the
    EA day-close EQUITY_SNAPSHOT, which can lag a full weekend.
    """
    out: dict = {"balance": None, "last_deal_ts": None, "age_min": None}
    fields = ("profit", "swap", "commission", "fee")
    try:
        with deals_csv.open(encoding="utf-8-sig", newline="") as fh:
            reader = csv.DictReader(fh)
            headers = set(reader.fieldnames or ())
            # STRICT (Codex review 2026-07-25): a missing header or a single
            # unparsable/non-finite monetary field voids the WHOLE figure —
            # a partial sum shown as primary equity is an invented number.
            if not headers.issuperset(fields) or "time_utc" not in headers:
                return out
            bal = 0.0
            last_ts = ""
            n_rows = 0
            for r in reader:
                n_rows += 1
                for k in fields:
                    try:
                        v = float((r.get(k) or "").strip())
                    except (TypeError, ValueError):
                        return out
                    if not math.isfinite(v):
                        return out
                    bal += v
                ts = str(r.get("time_utc") or "")
                if ts > last_ts:
                    last_ts = ts
        if not n_rows:
            return out
        out["balance"] = round(bal, 2)
        out["last_deal_ts"] = last_ts or None
        out["age_min"] = _age_minutes(last_ts) if last_ts else None
    except Exception:
        pass
    return out


def live_money_snapshot() -> dict:
    """Read-only DXZ live-book + FTMO trial pulse state for the LIVE MONEY row.

    Sources are the pulse artifacts (evidence chain: T_Live terminal logs →
    live_book_pulse.py, FTMO terminal → ftmo_trial_pulse), never manifests
    (manifest DRAFT/NONE is default output, OWNER rule 2026-07-01).
    """
    out: dict = {"dxz": None, "ftmo": None}
    try:
        lb = json.loads(LIVE_BOOK_PULSE.read_text(encoding="utf-8"))
        hb = lb.get("heartbeat") or {}
        tj = lb.get("terminal_journals") or {}
        at = tj.get("autotrading_transitions") or []
        be = (lb.get("ea_logs") or {}).get("book_equity") or {}
        out["dxz"] = {
            "verdict": str(lb.get("verdict") or "?").upper(),
            "alarms": len(lb.get("alarms") or []),
            "sleeves": tj.get("loaded_sleeve_count"),
            "equity": be.get("equity"),
            "day_pnl": be.get("day_pnl"),
            "positions": hb.get("current_position_count"),
            "autotrading": str((at[-1] or {}).get("state") or "?") if at else "?",
            "account": str(tj.get("account_id") or ""),
            "age_min": _age_minutes(lb.get("generated_at_utc")),
            # Age of the equity NUMBER itself (day-close snapshot), not of the
            # pulse file — the tile must never sell a stale figure as fresh.
            "equity_age_min": _age_minutes(be.get("ts_utc")),
        }
        _deals = deal_history_balance(TLIVE_DEALS_CSV)
        out["dxz"]["deal_balance"] = _deals.get("balance")
        out["dxz"]["deal_last_ts"] = _deals.get("last_deal_ts")
        out["dxz"]["deal_age_min"] = _deals.get("age_min")
        _mon = monitor_account_snapshot(TLIVE_MONITOR_DIR)
        out["dxz"]["mon_equity"] = _mon.get("equity")
        out["dxz"]["mon_positions"] = _mon.get("positions")
        out["dxz"]["mon_floating"] = _mon.get("floating")
        out["dxz"]["mon_age_min"] = _mon.get("age_min")
    except Exception:
        pass
    try:
        ft = json.loads(FTMO_TRIAL_PULSE.read_text(encoding="utf-8"))
        out["ftmo"] = {
            "verdict": str(ft.get("verdict") or "?").upper(),
            "alarms": len(ft.get("alarms") or []) + len(ft.get("warns") or []),
            "equity": ft.get("equity"),
            "day_pnl": ft.get("day_pnl"),
            "day_loss_pct": ft.get("day_loss_pct"),
            "total_dd_pct": ft.get("total_dd_pct"),
            "magics_seen": ft.get("magics_seen"),
            "expected_magics": ft.get("expected_magics"),
            "terminal_up": bool(ft.get("terminal_up")),
            "age_min": _age_minutes(ft.get("checked_at_utc")),
            # Age of the equity snapshot the numbers come from (pulse age alone
            # hides a dead terminal serving day-old figures).
            "eq_age_min": (
                int(ft["equity_snapshot_age_minutes"])
                if isinstance(ft.get("equity_snapshot_age_minutes"), (int, float))
                else _age_minutes(ft.get("equity_snapshot_ts"))
            ),
        }
        _fmon = monitor_account_snapshot(FTMO_MONITOR_DIR)
        out["ftmo"]["mon_equity"] = _fmon.get("equity")
        out["ftmo"]["mon_positions"] = _fmon.get("positions")
        out["ftmo"]["mon_age_min"] = _fmon.get("age_min")
    except Exception:
        pass
    return out


def live_book_snapshot() -> dict:
    """READ-ONLY T_Live pulse from the terminal journal + EA-emitted logs.

    Sources (never written by the cockpit):
      journal  C:/QM/mt5/T_Live/MT5_Base/logs/<YYYYMMDD>.log   (UTF-16, terminal)
      ea logs  C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/*.log    (UTF-8 JSON lines)

    Every field is honestly labelled; an unreadable/absent source stays None so
    the surface renders 'n/a' rather than a guess. The equity value is the
    NEWEST EA-emitted EQUITY_SNAPSHOT (a day-close figure) — it is explicitly
    NOT real-time account equity.
    """
    out = {
        "journal_date": None,
        "journal_age_sec": None,
        "deals_today": None,
        "equity": None,
        "equity_ts": None,
        "equity_day_pnl": None,
        "ea_logs_today": None,
        "ea_logs_total": None,
    }
    # --- terminal journal: today's <YYYYMMDD>.log ---
    today_name = dt.date.today().strftime("%Y%m%d")
    journal = TLIVE_JOURNAL_DIR / f"{today_name}.log"
    try:
        if journal.exists():
            out["journal_date"] = today_name
            out["journal_age_sec"] = int(
                dt.datetime.now().timestamp() - journal.stat().st_mtime
            )
            # MT5 logs live fills as 'deal #<n> ... done' under Trades.
            text = journal.read_text(encoding="utf-16", errors="ignore")
            out["deals_today"] = sum(1 for ln in text.splitlines() if "deal #" in ln.lower())
    except Exception:
        pass
    # --- EA logs: newest EQUITY_SNAPSHOT + today-active sleeve count ---
    try:
        logs = list(TLIVE_EA_LOG_DIR.glob("QM5_*_ea-*.log"))
        out["ea_logs_total"] = len(logs)
        today = dt.date.today()
        active = 0
        newest_ts = None
        for f in logs:
            try:
                st = f.stat()
            except OSError:
                continue
            if dt.date.fromtimestamp(st.st_mtime) == today:
                active += 1
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for line in content.splitlines():
                if '"EQUITY_SNAPSHOT"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                ts = str(rec.get("ts_utc") or "")
                if newest_ts is None or ts > newest_ts:
                    newest_ts = ts
                    pay = rec.get("payload") or {}
                    out["equity"] = pay.get("equity")
                    out["equity_ts"] = ts
                    out["equity_day_pnl"] = pay.get("day_pnl")
        out["ea_logs_today"] = active
    except Exception:
        pass
    return out


def frontier_next_book_snapshot(since_iso: str = "2026-07-19T18:00", limit: int = 8) -> dict:
    """READ-ONLY work_items view for the ~26.07 next-book frontier.

    (a) fresh PASS at Q08/Q09/Q10 since ``since_iso``.
    (b) Q07-PASS (ea, symbol) pairs whose latest Q08 is still pending/running.
    Both are deduped per (ea_id, symbol); Qxx labels only.
    """
    out = {"fresh_pass": [], "in_flight": [], "fresh_count": 0, "inflight_count": 0}
    # (a) fresh Q08+ PASS
    try:
        fresh = db_rows_ro(
            """
            SELECT ea_id, symbol, phase, MAX(updated_at) AS updated_at
            FROM work_items
            WHERE verdict='PASS' AND phase IN ('Q08','Q09','Q10','P5c','P6','P7')
              AND updated_at >= ?
            GROUP BY ea_id, symbol, phase
            ORDER BY updated_at DESC
            """,
            (since_iso,),
        )
    except sqlite3.Error:
        fresh = []
    seen: set = set()
    for r in fresh:
        key = (r.get("ea_id"), r.get("symbol"))
        if key in seen:
            continue
        seen.add(key)
        out["fresh_pass"].append({
            "ea_id": r.get("ea_id"),
            "symbol": str(r.get("symbol") or "").replace(".DWX", ""),
            "phase": phase_label(r.get("phase")),
            "when": str(r.get("updated_at") or "")[:16].replace("T", " "),
        })
    out["fresh_count"] = len(out["fresh_pass"])

    # (b) Q07-PASS with Q08 still in flight
    try:
        q07 = db_rows_ro(
            """
            SELECT ea_id, symbol, MAX(updated_at) AS updated_at
            FROM work_items
            WHERE phase IN ('Q07','P5b') AND verdict='PASS'
            GROUP BY ea_id, symbol
            ORDER BY updated_at DESC
            """
        )
        q08_rows = db_rows_ro(
            "SELECT ea_id, symbol, status FROM work_items "
            "WHERE phase IN ('Q08','P5c') ORDER BY updated_at ASC"
        )
    except sqlite3.Error:
        q07, q08_rows = [], []
    latest_q08: dict = {}
    for r in q08_rows:  # ascending → last write wins
        latest_q08[(r.get("ea_id"), r.get("symbol"))] = str(r.get("status") or "")
    inflight = []
    for r in q07:
        key = (r.get("ea_id"), r.get("symbol"))
        status = latest_q08.get(key)
        if status in ("pending", "active"):
            inflight.append({
                "ea_id": r.get("ea_id"),
                "symbol": str(r.get("symbol") or "").replace(".DWX", ""),
                "status": status,
                "when": str(r.get("updated_at") or "")[:16].replace("T", " "),
            })
    out["inflight_count"] = len(inflight)
    # Combined display cap: fresh PASS first (more important), then in-flight.
    out["in_flight"] = inflight[: max(0, limit - out["fresh_count"])]
    return out


def ops_heartbeats_snapshot() -> list[dict]:
    """File-age heartbeats for the scheduled ops jobs (read-only stat)."""
    specs = [
        ("BACKUP NIGHTLY", REPORTS_STATE / "backup_nightly.log", 26 * 3600),
        ("QUOTA GOVERNOR", REPORTS_STATE / "quota_governor.log", 20 * 60),
        ("CACHE PURGE", REPORTS_STATE / "tester_cache_purge.log", 10 * 60),
        ("HEALTH.JSON", ROOT / "state" / "health.json", 20 * 60),
        # Resident live-terminal supervisor writes its state every ~10s cycle.
        # It died silently Fri 2026-07-24 ~15:00 and nothing noticed for ~23h
        # (FTMO terminal stayed dead) — this tile makes that class visible.
        ("LIVE SUPERVISOR", REPORTS_STATE / "live_session_supervisor.json", 5 * 60),
    ]
    out = []
    for label, path, warn_sec in specs:
        age = None
        try:
            if path.exists():
                age = int(dt.datetime.now().timestamp() - path.stat().st_mtime)
        except OSError:
            age = None
        if age is None:
            status = "miss"
        elif age <= warn_sec:
            status = "ok"
        elif age <= warn_sec * 2:
            status = "warn"
        else:
            status = "crit"
        out.append({"label": label, "age_sec": age, "warn_sec": warn_sec, "status": status})
    return out


def q12_review_ready_count() -> int:
    try:
        rows = db_rows(
            "SELECT COUNT(*) AS c FROM portfolio_candidates WHERE state='Q12_REVIEW_READY'"
        )
        return int(rows[0]["c"]) if rows else 0
    except Exception:
        return 0


def _ell(s: str, n: int) -> str:
    """Truncate with a visible ellipsis — a hard cut mid-word reads as a bug."""
    s = str(s)
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


def pipeline_books_program_snapshot(
    *, now_utc: dt.datetime | None = None
) -> dict:
    """Read the hash-bound programme projection without mutating farm state."""

    return program_status_snapshot(
        PROGRAM_STATUS_FILE,
        repo_root=PROGRAM_REPO,
        now_utc=now_utc,
    )


def render_pipeline_books_program(snapshot: dict) -> str:
    """Render the fail-closed W0--W8 programme panel.

    Missing and invalid sources deliberately render a red, non-empty panel.
    A stale but hash-valid source retains its detail for diagnosis while its
    headline remains non-valid and visually blocked.
    """

    state = str(snapshot.get("state") or "INVALID").upper()
    state_cls = "fresh" if state == "FRESH" else ("stale" if state == "STALE" else "invalid")
    as_of = snapshot.get("config_as_of_utc") or "n/a"
    age = snapshot.get("age_hours")
    age_text = f"{age:.1f}h old" if isinstance(age, (int, float)) else "age unavailable"
    error = str(snapshot.get("error") or "")
    source_detail = f"as of {as_of} // {age_text}"
    if error:
        source_detail += f" // {error}"

    work_packages = snapshot.get("work_packages") or []
    if state in {"MISSING", "INVALID"} or not work_packages:
        return (
            f'<div class="pb-program pb-program-{state_cls}">'
            '<div class="pb-source">'
            f'<span class="pb-source-state">PROGRAM SOURCE {e(state)}</span>'
            f'<span class="pb-source-detail">{e(source_detail)}</span>'
            '</div>'
            '<div class="pb-invalid-body">'
            '<b>NO TRUSTED W0–W8 STATUS AVAILABLE.</b> '
            'The dashboard refuses to replace a missing or invalid source with CLEAR, PASS, or zero blockers.'
            '</div></div>'
        )

    bindings = snapshot.get("bindings") or {}
    plan_hash = str((bindings.get("plan") or {}).get("file_sha256") or "")
    evidence_hash = str((bindings.get("evidence") or {}).get("file_sha256") or "")
    source_detail += f" // plan {plan_hash[:12]} // evidence {evidence_hash[:12]}"

    wave_rows: list[str] = []
    for row in work_packages:
        status = str(row.get("status") or "UNKNOWN")
        if "BLOCKED" in status:
            row_cls = "blocked"
        elif status == "PLANNED" or "NOT_IMPLEMENTED" in str(row.get("source_status") or ""):
            row_cls = "planned"
        elif "SHADOW" in status or "RULEPACK" in status or "FOUNDATION" in status:
            row_cls = "shadow"
        else:
            row_cls = "implemented"
        wave_rows.append(
            f'<div class="pb-wave pb-wave-{row_cls}">'
            f'<div class="pb-wave-id">{e(row.get("id"))}</div>'
            f'<div class="pb-wave-title">{e(row.get("title"))}</div>'
            f'<div class="pb-wave-status">{e(status)}</div>'
            f'<div class="pb-wave-axes">SRC {e(row.get("source_status"))} · '
            f'RUN {e(row.get("runtime_status"))}</div>'
            f'<div class="pb-wave-next">NEXT // {e(row.get("next_action"))}</div>'
            '</div>'
        )

    # The programme snapshot is a hash-bound projection that can be days old;
    # its factory_state claim must never contradict the live flag (a stale
    # INTENTIONALLY_OFF rendered while the fleet was running, 2026-08-10).
    live_factory = "OFF (INTENTIONAL)" if FACTORY_OFF_FLAG.exists() else "ON"
    safety_html = (
        '<div class="pb-safety">'
        f'<span><b>FACTORY</b> {e(live_factory)}</span>'
        '<span><b>PROGRAMME RUNTIME AUTHORITY</b> NONE</span>'
        '<span><b>SCHEDULER / MT5 / AUTOTRADING / DEPLOY</b> NO ACTION AUTHORIZED</span>'
        '</div>'
    )

    q08 = snapshot.get("q08_v3") or {}
    verdicts = " · ".join(str(item) for item in (q08.get("verdict_states") or []))
    policy_hash = str(q08.get("policy_canonical_sha256") or "")
    q08_html = (
        '<div class="pb-contract">'
        '<div class="pb-contract-lbl">Q08 V3 // EVIDENCE</div>'
        f'<div class="pb-contract-val">{e(q08.get("lifecycle", "UNKNOWN"))}</div>'
        f'<div class="pb-contract-sub">promotion {e(q08.get("promotion_state", "UNKNOWN"))} '
        f'// policy {e(policy_hash[:12])}</div>'
        f'<div class="pb-verdicts">{e(verdicts)}</div>'
        f'<div class="pb-contract-note">{e(q08.get("evidence_semantics", ""))}</div>'
        '</div>'
    )

    lane_cards: list[str] = []
    for lane in snapshot.get("target_lanes") or []:
        lane_hash = str(lane.get("rulepack_canonical_sha256") or "")
        lane_cards.append(
            '<div class="pb-contract">'
            f'<div class="pb-contract-lbl">{e(lane.get("label"))}</div>'
            f'<div class="pb-contract-val">{e(lane.get("state"))}</div>'
            f'<div class="pb-contract-sub">{e(lane.get("rulepack_id"))} '
            f'// {e(lane_hash[:12])} // eligibility {e(lane.get("eligibility"))}</div>'
            f'<div class="pb-contract-note">NEXT // {e(lane.get("next_action"))}</div>'
            '</div>'
        )

    ftmo = snapshot.get("ftmo_book3_runtime_evaluation") or {}
    readiness = ftmo.get("readiness") or {}
    native_rows = ftmo.get("native_runs") or []
    native_text = " · ".join(
        f'{row.get("rung", "?")} QM5_{row.get("ea_id", "?")} '
        f'{row.get("symbol", "?")} {row.get("trades", "?")} trades / '
        f'{row.get("lifecycle_mismatches", "?")} lifecycle mismatches'
        for row in native_rows
        if isinstance(row, dict)
    )
    policy = ftmo.get("policy_bootstrap") or {}
    holdout = ftmo.get("temporal_holdout_diagnostic") or {}
    manifest_hash = str(ftmo.get("source_manifest_sha256") or "")
    receipt_hash = str(ftmo.get("source_receipt_sha256") or "")
    projection_hash = str(
        (bindings.get("ftmo_book3_runtime_projection") or {}).get("file_sha256") or ""
    )
    ftmo_runtime_html = (
        '<div class="pb-contract pb-ftmo-runtime">'
        '<div class="pb-contract-lbl">FTMO BOOK 3 // HASH-BOUND RECORDED RESEARCH PROJECTION</div>'
        f'<div class="pb-contract-val">{e(ftmo.get("status", "MISSING"))}</div>'
        '<div class="pb-lane-line pass"><b>INPUT / NATIVE</b> '
        f'{e(readiness.get("input_integrity", "MISSING"))} / '
        f'{e(readiness.get("native_stream_reconciliation", "MISSING"))}</div>'
        '<div class="pb-lane-line residual"><b>STRICT / MONEY / PAID</b> '
        f'{e(readiness.get("strict_qualification", "MISSING"))} / '
        f'{e(readiness.get("money_gate", "MISSING"))} / '
        f'{e(readiness.get("paid_challenge", "MISSING"))}</div>'
        f'<div class="pb-contract-note">{e(native_text)}</div>'
        '<div class="pb-contract-note"><b>POLICY BOOTSTRAP · NON-GATE-ELIGIBLE</b> '
        f'P1 {e(policy.get("phase1_pass_percent", "?"))} · two-phase '
        f'{e(policy.get("two_phase_pass_percent", "?"))} · breach '
        f'{e(policy.get("official_breach_percent", "?"))}</div>'
        '<div class="pb-contract-note"><b>TEMPORAL HOLDOUT DIAGNOSTIC · '
        'NOT SELECTION-SEALED · NON-GATE-ELIGIBLE</b> '
        f'P1 {e(holdout.get("phase1_pass_percent", "?"))} · two-phase '
        f'{e(holdout.get("two_phase_pass_percent", "?"))} · breach '
        f'{e(holdout.get("official_breach_percent", "?"))}</div>'
        '<div class="pb-contract-note"><b>AUTHORITY</b> FACTORY / RESTART / MONEY / '
        'PURCHASE / DEPLOY = FALSE</div>'
        '<div class="pb-contract-note"><b>PROVENANCE</b> External artifact hashes are '
        'recorded evidence; this dashboard does not revalidate D: runtime files.</div>'
        f'<div class="pb-contract-sub">manifest {e(manifest_hash[:12])} // '
        f'receipt {e(receipt_hash[:12])} // projection {e(projection_hash[:12])}</div>'
        '</div>'
    )

    verification = snapshot.get("verification_lanes") or {}
    green = verification.get("green") or {}
    residual = verification.get("external_residual") or {}
    residual_state = str(residual.get("state") or "UNKNOWN")
    residual_resolved = residual_state == "RESOLVED_PASS"
    residual_line_class = "pass" if residual_resolved else "residual"
    residual_expected = residual.get("expected_count", 0)
    residual_count = (
        f'{residual.get("pass_count", 0)}/{residual_expected} sentinels passed'
        if residual_resolved
        else f"{residual_expected} exact fail-closed sentinels"
    )
    exit_receipt_hash = str(
        (bindings.get("external_residual_exit_receipt") or {}).get("file_sha256")
        or ""
    )
    exit_receipt_note = (
        f'<div class="pb-contract-sub">exit receipt {e(exit_receipt_hash[:12])}</div>'
        if residual_resolved
        else ""
    )
    residual_labels = " // ".join(
        str(item.get("label") or "") for item in (residual.get("items") or [])
    )
    verification_html = (
        '<div class="pb-contract pb-verification">'
        '<div class="pb-contract-lbl">VERIFICATION LANES</div>'
        f'<div class="pb-lane-line pass"><b>GREEN {e(green.get("state", "UNKNOWN"))}</b> '
        f'{e(green.get("passed", 0))} passed · {e(green.get("skipped", 0))} skipped · '
        f'{e(green.get("deselected", 0))} exact deselected · '
        f'{e(green.get("subtests_passed", 0))} subtests</div>'
        f'<div class="pb-lane-line {residual_line_class}"><b>EXTERNAL RESIDUAL '
        f'{e(residual_state)}</b> · {e(residual_count)}</div>'
        f'<div class="pb-contract-note">{e(residual_labels)}</div>'
        f'{exit_receipt_note}'
        '</div>'
    )

    blockers = snapshot.get("owner_blockers") or []
    blocker_rows = "".join(
        '<div class="pb-blocker">'
        f'<span class="pb-blocker-id">{e(row.get("id"))}</span>'
        f'<span class="pb-blocker-title">{e(row.get("title"))}'
        f'<small>SAFE DEFAULT // {e(row.get("safe_default"))}</small></span>'
        f'<span class="pb-blocker-blocks">BLOCKS {e(" · ".join(row.get("blocks") or []))}</span>'
        '</div>'
        for row in blockers
    )

    return (
        f'<div class="pb-program pb-program-{state_cls}">'
        '<div class="pb-source">'
        f'<span class="pb-source-state">PROGRAM SOURCE {e(state)}</span>'
        f'<span class="pb-source-detail">{e(source_detail)}</span>'
        '</div>'
        f'{safety_html}'
        f'<div class="pb-waves">{"".join(wave_rows)}</div>'
        f'<div class="pb-contracts">{q08_html}{"".join(lane_cards)}{ftmo_runtime_html}{verification_html}</div>'
        '<div class="pb-blockers-head">'
        f'<span>OWNER BLOCKERS</span><b>{len(blockers):02d} OPEN</b>'
        '</div>'
        f'<div class="pb-blockers">{blocker_rows}</div>'
        '</div>'
    )


def pipeline_books_owner_decision_rows(snapshot: dict) -> list[dict]:
    """Project verified programme blockers into the primary OWNER surface."""

    state = str(snapshot.get("state") or "INVALID").upper()
    blockers = snapshot.get("owner_blockers") or []
    if not blockers:
        error = _ell(str(snapshot.get("error") or "trusted status unavailable"), 78)
        return [
            {
                "cat": "PROGRAM STATUS",
                "title": f"Pipeline Books source {state}",
                "detail": error,
                "due": "",
                "alert": True,
            }
        ]
    rows: list[dict] = []
    for blocker in blockers:
        rows.append(
            {
                "cat": "PROGRAM",
                "title": _ell(str(blocker.get("title") or blocker.get("id") or "OWNER decision"), 64),
                "detail": _ell(
                    f"{blocker.get('id', '')} // safe: {blocker.get('safe_default', '')}",
                    96,
                ),
                "due": "",
                "alert": True,
            }
        )
    return rows


def owner_decision_rows(q12_count: int) -> list[dict]:
    """Genuine OWNER decisions only (OWNER call 2026-07-07).

    Sources, in order:
      1. Curated feed D:/QM/reports/state/owner_decisions.json (maintained by
         Claude; supports a literal "{q12_count}" placeholder).
      2. BLOCKED agent_tasks whose unblock condition names OWNER.
    Agent work queues (Claude reviews, ops-blocked tasks, router SLAs) are
    agent status — they never belong in this panel.
    """
    rows: list[dict] = []
    try:
        data = json.loads(OWNER_DECISIONS_FILE.read_text(encoding="utf-8"))
        for item in data.get("items") or []:
            detail = str(item.get("detail") or "").replace("{q12_count}", str(q12_count))
            rows.append({
                "cat": _ell(str(item.get("cat") or "DECISION"), 16),
                "title": _ell(str(item.get("title") or "?"), 64),
                "detail": _ell(detail, 96),
                "due": str(item.get("due") or ""),
                "alert": str(item.get("severity") or "").lower() in ("alert", "action"),
            })
    except Exception:
        pass
    if not any(r["cat"] == "ADMISSION" for r in rows) and q12_count:
        rows.append({
            "cat": "ADMISSION",
            "title": f"{q12_count} candidates Q12_REVIEW_READY",
            "detail": "portfolio admission is an OWNER gate",
            "due": "",
            "alert": False,
        })
    try:
        blocked = db_rows(
            "SELECT id, task_type, verdict, updated_at FROM agent_tasks "
            "WHERE state='BLOCKED' AND verdict LIKE '%OWNER%' "
            "ORDER BY updated_at DESC LIMIT 6"
        )
    except Exception:
        blocked = []
    # A superseded/obsolete BLOCKED row is a closed matter that merely
    # mentions OWNER in its epitaph — not an open OWNER decision.
    blocked = [
        b for b in blocked
        if not re.search(r"supersed|obsolete", str(b.get("verdict") or ""), re.IGNORECASE)
    ][:3]
    for b in blocked:
        rows.append({
            "cat": "UNBLOCK",
            "title": f"{str(b.get('task_type') or 'task')} {str(b.get('id') or '')[:8]}",
            "detail": _ell(str(b.get("verdict") or ""), 96),
            "due": "",
            "alert": False,
        })

    # OWNER-actionable rows (severity action/alert) sort ahead of informational
    # ones, then due-date ascending within each group; items whose due date is
    # more than 2 days past are dropped as stale so they cannot crowd current
    # items out of the decisions[:8] panel cutoff (the 07-26 TOTAL_RISK review
    # was hidden behind expired 07-12 entries in raw file order).
    today = dt.date.today()

    def _due_date(r: dict) -> dt.date | None:
        try:
            return dt.date.fromisoformat(str(r.get("due") or ""))
        except ValueError:
            return None

    def _is_stale(r: dict) -> bool:
        d = _due_date(r)
        return d is not None and (today - d).days > 2

    rows = [r for r in rows if not _is_stale(r)]
    rows.sort(key=lambda r: (0 if r["alert"] else 1, _due_date(r) or dt.date.max))
    return rows


def list_files(p: Path, pattern: str = "*.md") -> list[str]:
    if not p.is_dir():
        return []
    return sorted(f.name for f in p.glob(pattern))


def proc_with_age() -> dict[str, list[dict]]:
    """Returns {name: [{Id, Age (sec)}, ...]} for each process name."""
    names = ("terminal64", "codex", "node", "python", "pwsh", "claude")
    out: dict[str, list[dict]] = {n: [] for n in names}
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "Get-Process | Where-Object {$_.Name -match 'terminal64|codex|node|python|pwsh|claude'} | "
             "Select-Object Id, Name, @{N='AgeSec';E={[int]((Get-Date) - $_.StartTime).TotalSeconds}} | "
             "ConvertTo-Json -Compress"],
            capture_output=True, text=True, timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0),
        )
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout)
            if isinstance(data, dict):
                data = [data]
            for entry in data:
                n = (entry.get("Name") or "").lower()
                if n in out:
                    out[n].append({"id": entry.get("Id"), "age": entry.get("AgeSec") or 0})
    except Exception:
        pass
    return out


def live_worker_terminals() -> set[str]:
    """{T1, T3, ...} for terminal_worker.py daemons currently alive.

    Cockpit uses this to filter mt5_active_work() down to claims that
    actually have a living worker behind them - prevents stale-claim
    lies after Factory_OFF or unclean crashes (DB row still says
    status=active but the daemon was killed).
    """
    out: set[str] = set()
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "Get-CimInstance Win32_Process -Filter \"Name='pythonw.exe' OR Name='python.exe'\" | "
             "Where-Object {$_.CommandLine -match 'terminal_worker'} | "
             "Select-Object -ExpandProperty CommandLine"],
            capture_output=True, text=True, timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0),
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                m = re.search(r"--terminal\s+(T\d+)", line, re.IGNORECASE)
                if m:
                    out.add(m.group(1).upper())
    except Exception:
        pass
    return out


def factory_terminal_procs() -> set[str]:
    """{T1, T8, ...} — path-anchored terminal64.exe processes under D:\\QM\\mt5.

    The farm DB can report 0 running while ad-hoc harnesses (Q07 rerun) or a
    leaked phase runner still hold terminals; quiescence is only provable by
    process scan (OWNER 2026-07-25). T_Live (C:) never matches this anchor.
    """
    out: set[str] = set()
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\" | "
             "Select-Object -ExpandProperty ExecutablePath"],
            capture_output=True, text=True, timeout=15,
            creationflags=(subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0),
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                m = re.match(r"(?i)^D:\\QM\\mt5\\(T\d{1,2})\\terminal64\.exe\s*$", line.strip())
                if m:
                    out.add(m.group(1).upper())
    except Exception:
        pass
    return out


def fresh_log_files(pattern: str, max_age_sec: int = 600) -> list[dict]:
    """Live logs modified within max_age_sec, ordered by recency."""
    now = dt.datetime.now().timestamp()
    out = []
    for log in LOG_DIR.glob(pattern):
        try:
            mtime = log.stat().st_mtime
            age = now - mtime
            if age <= max_age_sec:
                out.append({
                    "path": log,
                    "name": log.stem,
                    "age": int(age),
                    "size_kb": log.stat().st_size // 1024,
                })
        except OSError:
            pass
    out.sort(key=lambda x: x["age"])
    return out


def last_lines(p: Path, n: int = 5) -> list[str]:
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
        lines = [l.strip() for l in text.splitlines() if l.strip()]
        return lines[-n:]
    except Exception:
        return []


def codex_active_tasks() -> list[dict]:
    """Active codex builds: live log fresh + task_id mappable to EA."""
    logs = fresh_log_files("codex_build_*.live.log", max_age_sec=300)
    out = []
    if not logs:
        return out
    # Pull task → ea_id mapping
    rows = db_rows("SELECT id, payload_json FROM tasks WHERE kind='build_ea'")
    task_to_ea = {}
    for r in rows:
        p = json.loads(r["payload_json"]) if r["payload_json"] else {}
        task_to_ea[r["id"]] = (p.get("ea_id"), p.get("slug"))
    for log in logs[:5]:
        # log name = codex_build_<task_id>.live
        m = re.match(r"codex_build_(.+)\.live$", log["name"])
        if not m:
            continue
        tid = m.group(1)
        ea_id, slug = task_to_ea.get(tid, (None, None))
        out.append({
            "task_id": tid,
            "ea_id": ea_id or "?",
            "slug": slug or "",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    return out


def claude_active_tasks() -> list[dict]:
    """Active claude sessions: research / review live logs fresh."""
    out = []
    research_logs = fresh_log_files("claude_research_*.live.log", max_age_sec=600)
    review_logs = fresh_log_files("claude_review_*.live.log", max_age_sec=600)
    autowake_logs = fresh_log_files("autonomous_wake_*.log", max_age_sec=600)
    observe_logs = fresh_log_files("observe_wake_*.log", max_age_sec=600)
    for log in research_logs[:3]:
        m = re.match(r"claude_research_(.+)\.live$", log["name"])
        sid = m.group(1) if m else "?"
        out.append({
            "kind": "research",
            "subject": f"source {sid[:8]}",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    for log in review_logs[:3]:
        m = re.match(r"claude_review_(.+)\.live$", log["name"])
        rid = m.group(1) if m else "?"
        # Try map review_task_id → ea_id
        rows = db_rows("SELECT payload_json FROM tasks WHERE id=?", (rid,))
        ea = "?"
        if rows:
            p = json.loads(rows[0]["payload_json"]) if rows[0]["payload_json"] else {}
            ea = p.get("ea_id") or "?"
        out.append({
            "kind": "review",
            "subject": f"{ea}",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    for log in autowake_logs[:2]:
        out.append({
            "kind": "autonomous_wake",
            "subject": "decision tree",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    for log in observe_logs[:1]:
        out.append({
            "kind": "observe_wake",
            "subject": "board-advisor",
            "age": log["age"],
            "size_kb": log["size_kb"],
            "tail": last_lines(log["path"], 3),
        })
    return out


def mt5_active_work() -> list[dict]:
    """Per-MT5-terminal current work (from work_items active)."""
    rows = db_rows(
        "SELECT ea_id, phase, symbol, claimed_by, payload_json, updated_at "
        "FROM work_items WHERE status='active' ORDER BY updated_at"
    )
    out = []
    for r in rows:
        out.append({
            "ea_id": r["ea_id"],
            "phase": r["phase"],
            "symbol": r["symbol"],
            "terminal": r.get("claimed_by") or "?",
            "since": (r.get("updated_at") or "")[:19],
        })
    return out


def queue_snapshot() -> dict:
    """All FIFO queues + counts."""
    out = {}
    tc = db_rows("SELECT kind, status, COUNT(*) AS c FROM tasks GROUP BY kind, status")
    bd = {f"{r['kind']}_{r['status']}": r["c"] for r in tc}
    out["builds_pending"] = bd.get("build_ea_pending", 0)
    out["builds_active"] = bd.get("build_ea_active", 0)
    out["builds_blocked"] = bd.get("build_ea_blocked", 0)
    out["reviews_pending"] = bd.get("ea_review_pending", 0)
    out["reviews_done"] = bd.get("ea_review_done", 0)
    out["backtest_p2_pending"] = bd.get("backtest_p2_pending", 0)
    out["backtest_p2_active"] = bd.get("backtest_p2_active", 0)
    out["backtest_p2_done"] = bd.get("backtest_p2_done", 0)
    out["backtest_p3_pending"] = bd.get("backtest_p3_pending", 0)
    out["backtest_p3_active"] = bd.get("backtest_p3_active", 0)
    out["backtest_p3_done"] = bd.get("backtest_p3_done", 0)

    # Work items per status
    wi = db_rows("SELECT phase, status, verdict, COUNT(*) AS c FROM work_items "
                 "GROUP BY phase, status, verdict")
    out["work_items"] = wi
    out["work_items_pending"] = sum(int(r.get("c") or 0) for r in wi if r.get("status") == "pending")
    out["work_items_active"] = sum(int(r.get("c") or 0) for r in wi if r.get("status") == "active")

    # Card backlog
    out["cards_draft"] = len(list_files(CARDS_DRAFT))
    out["cards_approved"] = len(list_files(CARDS_APPROVED))

    # Pending builds detail (FIFO)
    pending = db_rows(
        "SELECT payload_json, updated_at FROM tasks "
        "WHERE kind='build_ea' AND status='pending' ORDER BY updated_at ASC LIMIT 10"
    )
    pending_list = []
    for r in pending:
        p = json.loads(r["payload_json"]) if r["payload_json"] else {}
        pending_list.append({
            "ea_id": p.get("ea_id") or "?",
            "slug": p.get("slug") or "",
            "since": (r.get("updated_at") or "")[:19],
        })
    out["pending_builds_list"] = pending_list

    # Pending backtests detail
    pending_bt = db_rows(
        "SELECT kind, payload_json, updated_at FROM tasks "
        "WHERE kind LIKE 'backtest_%' AND status='pending' ORDER BY updated_at ASC LIMIT 10"
    )
    pending_bt_list = []
    for r in pending_bt:
        p = json.loads(r["payload_json"]) if r["payload_json"] else {}
        phase = (p.get("phase") or r["kind"].replace("backtest_", "").upper())
        pending_bt_list.append({
            "ea_id": p.get("ea_id") or "?",
            "phase": phase,
            "since": (r.get("updated_at") or "")[:19],
        })
    out["pending_backtests_list"] = pending_bt_list

    out["agent_router"] = agent_router_snapshot()
    return out


def agent_router_snapshot() -> dict:
    """Read-only view of the autonomous Claude/Gemini/Codex router."""
    empty = {
        "open_count": 0,
        "agents": [],
        "task_counts": [],
        "recent_tasks": [],
        "available": False,
    }
    try:
        agents = db_rows(
            "SELECT agent_id, enabled, max_parallel, capabilities_json "
            "FROM agent_registry ORDER BY agent_id"
        )
        task_counts = db_rows(
            """
            SELECT task_type, state, COALESCE(assigned_agent, '') AS assigned_agent, COUNT(*) AS c
            FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO', 'IN_PROGRESS', 'REVIEW', 'BLOCKED', 'OPS_FIX_REQUIRED')
            GROUP BY task_type, state, assigned_agent
            ORDER BY state, task_type, assigned_agent
            """
        )
        recent_rows = db_rows(
            """
            SELECT id, task_type, state, assigned_agent, artifact_path, verdict, payload_json, updated_at
            FROM agent_tasks
            WHERE state IN ('BACKLOG', 'TODO', 'IN_PROGRESS', 'REVIEW', 'BLOCKED', 'OPS_FIX_REQUIRED')
            ORDER BY priority ASC, updated_at DESC
            LIMIT 8
            """
        )
    except sqlite3.Error:
        return empty

    now_utc = dt.datetime.now(dt.timezone.utc)

    def age_hours(value: str) -> float:
        if not value:
            return 0.0
        try:
            parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return max(0.0, (now_utc - parsed.astimezone(dt.timezone.utc)).total_seconds() / 3600)
        except ValueError:
            return 0.0

    sla_hours = {
        "TODO": 2,
        "BACKLOG": 4,
        "IN_PROGRESS": 4,
        "REVIEW": 12,
        "BLOCKED": 24,
        "OPS_FIX_REQUIRED": 12,
    }
    recent_tasks = []
    for row in recent_rows:
        try:
            payload = json.loads(row.get("payload_json") or "{}")
        except json.JSONDecodeError:
            payload = {}
        age_h = age_hours(row.get("updated_at") or "")
        limit_h = sla_hours.get(str(row.get("state") or ""), 24)
        recent_tasks.append({
            "id": str(row.get("id") or "")[:8],
            "type": row.get("task_type") or "?",
            "state": row.get("state") or "?",
            "agent": row.get("assigned_agent") or payload.get("target_agent_profile") or "?",
            "artifact": row.get("artifact_path") or payload.get("expected_artifact") or "",
            "verdict": row.get("verdict") or "",
            "age_h": round(age_h, 1),
            "sla": "late" if age_h > limit_h else "ok",
        })

    return {
        "open_count": sum(int(row.get("c") or 0) for row in task_counts),
        "agents": agents,
        "task_counts": task_counts,
        "recent_tasks": recent_tasks,
        "available": True,
    }


def pipeline_backlog_snapshot() -> dict:
    """Read-only backlog counters for the cockpit."""
    out = {
        "sources": {"pending": 0, "cards_ready": 0, "done": 0},
        "pass_by_phase": [],
        "pass_total": 0,
        "p4plus_pass_total": 0,
        "p8_pass_total": 0,
        "portfolio_candidates_total": 0,
        "p4_pending_implementation": 0,
        "work_active_by_phase": [],
        "work_active_total": 0,
        "top_sources": [],
        "estimated_todo": 0,
    }
    try:
        for r in db_rows("SELECT status, COUNT(*) AS c FROM sources GROUP BY status"):
            out["sources"][r["status"]] = r["c"]
        out["pass_by_phase"] = db_rows(
            """
            SELECT phase, COUNT(DISTINCT ea_id) AS c, COUNT(*) AS c_items
            FROM work_items
            WHERE verdict='PASS'
            GROUP BY phase
            ORDER BY CASE phase
              WHEN 'Q01' THEN 10 WHEN 'Q02' THEN 20 WHEN 'Q03' THEN 30
              WHEN 'Q04' THEN 40 WHEN 'Q05' THEN 50 WHEN 'Q06' THEN 60
              WHEN 'Q07' THEN 70 WHEN 'Q08' THEN 80 WHEN 'Q09' THEN 90
              WHEN 'Q10' THEN 100 WHEN 'Q11' THEN 110
              WHEN 'P2' THEN 20 WHEN 'P3' THEN 30 WHEN 'P3.5' THEN 40
              WHEN 'P4' THEN 50 WHEN 'P5' THEN 60 WHEN 'P5b' THEN 70
              WHEN 'P5c' THEN 80 WHEN 'P6' THEN 90 WHEN 'P7' THEN 100
              WHEN 'P8' THEN 110 ELSE 0 END
            """
        )
        pass_total = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items WHERE verdict='PASS'"
        )
        out["pass_total"] = pass_total[0]["c"] if pass_total else 0
        p4plus = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items "
            "WHERE verdict='PASS' AND phase IN ('Q05','Q06','Q07','Q08','Q09','Q10','Q11','P4','P5','P5b','P5c','P6','P7','P8')"
        )
        out["p4plus_pass_total"] = p4plus[0]["c"] if p4plus else 0
        p8 = db_rows(
            "SELECT COUNT(DISTINCT ea_id) AS c FROM work_items WHERE verdict='PASS' AND phase IN ('Q11','P8')"
        )
        out["p8_pass_total"] = p8[0]["c"] if p8 else 0
        try:
            pc = db_rows("SELECT COUNT(DISTINCT ea_id) AS c FROM portfolio_candidates WHERE state='Q12_REVIEW_READY'")
            out["portfolio_candidates_total"] = pc[0]["c"] if pc else 0
        except sqlite3.Error:
            out["portfolio_candidates_total"] = 0
        p4_pending = db_rows(
            "SELECT COUNT(*) AS c FROM work_items WHERE phase IN ('Q05','P4') AND verdict='PENDING_IMPLEMENTATION'"
        )
        out["p4_pending_implementation"] = p4_pending[0]["c"] if p4_pending else 0
        out["work_active_by_phase"] = db_rows(
            "SELECT phase, COUNT(*) AS c FROM work_items "
            """
            WHERE status IN ('active','pending','claimed') GROUP BY phase
            ORDER BY CASE phase
              WHEN 'Q01' THEN 10 WHEN 'Q02' THEN 20 WHEN 'Q03' THEN 30
              WHEN 'Q04' THEN 40 WHEN 'Q05' THEN 50 WHEN 'Q06' THEN 60
              WHEN 'Q07' THEN 70 WHEN 'Q08' THEN 80 WHEN 'Q09' THEN 90
              WHEN 'Q10' THEN 100 WHEN 'Q11' THEN 110
              WHEN 'P2' THEN 20 WHEN 'P3' THEN 30 WHEN 'P3.5' THEN 40
              WHEN 'P4' THEN 50 WHEN 'P5' THEN 60 WHEN 'P5b' THEN 70
              WHEN 'P5c' THEN 80 WHEN 'P6' THEN 90 WHEN 'P7' THEN 100
              WHEN 'P8' THEN 110 ELSE 0 END
            """
        )
        out["work_active_total"] = sum(r["c"] for r in out["work_active_by_phase"])
        out["top_sources"] = db_rows(
            "SELECT priority, title FROM sources "
            "WHERE status='pending' ORDER BY priority DESC LIMIT 5"
        )
        out["estimated_todo"] = out["sources"].get("pending", 0) * 3
    except Exception as exc:
        out["error"] = str(exc)
    return out


def diagnose_bottleneck(procs: dict, q: dict, claude_workers: list, codex_workers: list) -> tuple[str, str]:
    mt5_backpressure = q.get("work_items_pending", 0) >= 1000 or q.get("work_items_active", 0) >= 10
    if q["builds_pending"] > 0 and len(codex_workers) == 0 and mt5_backpressure:
        return "ok", (
            f"{q['builds_pending']} build(s) queued; coding intentionally paused while MT5 drains "
            f"{q.get('work_items_pending', 0)} pending / {q.get('work_items_active', 0)} active work_items."
        )
    if q["builds_pending"] > 3 and len(codex_workers) < 3:
        return "warn", (f"{q['builds_pending']} builds queued, only {len(codex_workers)} codex running. "
                        "Next pump (≤5 min) fills the budget to 3.")
    if q["builds_pending"] > 0 and len(codex_workers) == 0:
        return "block", f"{q['builds_pending']} builds pending and NO codex running — pump stalled?"
    awaiting_review = sum(1 for r in db_rows(
        "SELECT b.id FROM tasks b WHERE b.kind='build_ea' AND b.status='done' "
        "AND NOT EXISTS (SELECT 1 FROM tasks r WHERE r.kind='ea_review' AND r.payload_json LIKE '%\"build_task_id\": \"' || b.id || '\"%')"
    ))
    if awaiting_review > 0 and not any(c["kind"] == "review" for c in claude_workers):
        return "warn", f"{awaiting_review} EA(s) built and awaiting Claude review. Next pump spawns review."
    if q["backtest_p2_pending"] > 0 and procs["terminal64"][0]["age"] < 60 if procs.get("terminal64") else procs.get("terminal64", []):
        # MT5 just started — wait
        return "ok", "MT5 backtest running."
    if q["backtest_p2_pending"] == 0 and q["backtest_p2_active"] == 0 and q["builds_pending"] == 0:
        if q["cards_approved"] == 0 and q["cards_draft"] == 0:
            return "warn", "Pipeline idle — no approved/drafted cards. Research is the input bottleneck."
        return "ok", "Pipeline idle between cycles. Next pump ≤5 min."
    return "ok", "Pipeline flowing."


def main() -> int:
    DASH.mkdir(parents=True, exist_ok=True)

    procs = proc_with_age()
    codex_workers = codex_active_tasks()
    claude_workers = claude_active_tasks()
    mt5_work = mt5_active_work()
    # Filter DB-claims down to those with a living worker (process exists).
    # Prevents lying when Factory_OFF + farmctl repair has not run: DB rows
    # may say status=active but the daemon was killed. OWNER call 2026-05-23.
    _live = live_worker_terminals()
    mt5_work = [w for w in mt5_work if str(w.get("terminal") or "").upper() in _live]
    q = queue_snapshot()
    backlog = pipeline_backlog_snapshot()
    q08_rescue = q08_portfolio_rescue_snapshot()
    qsnap = quota_snapshot()
    money = live_money_snapshot()
    live_book = live_book_snapshot()
    heartbeats = ops_heartbeats_snapshot()
    q12_count = q12_review_ready_count()
    programme = pipeline_books_program_snapshot()
    programme_html = render_pipeline_books_program(programme)
    cohort_html = render_pipeline_cohorts(pipeline_cohort_snapshot())
    optimization_snapshot = optimization_track_snapshot(DB, PORTFOLIO_REPORT_ROOT)
    optimization_html = render_optimization_track(optimization_snapshot)

    # Pipeline health (written by `farmctl health`, scheduled every 15 min)
    health_file = ROOT / "state" / "health.json"
    health = {}
    try:
        if health_file.exists():
            health = json.loads(health_file.read_text(encoding="utf-8"))
    except Exception:
        health = {}

    # 7-day trend chart data — counts per day of key events
    def _trend_data() -> dict:
        try:
            con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
            con.row_factory = sqlite3.Row
            con.execute("PRAGMA query_only=ON")
            rows = list(con.execute("""
                SELECT DATE(ts) day, event, COUNT(*) c FROM events
                WHERE ts >= date('now', '-7 days')
                GROUP BY day, event
            """))
            con.close()
        except Exception:
            return {}
        days: dict[str, dict[str, int]] = {}
        for r in rows:
            days.setdefault(r["day"], {})[r["event"]] = r["c"]
        # P2-PASS counts per day from work_items (more reliable signal)
        try:
            con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
            con.row_factory = sqlite3.Row
            con.execute("PRAGMA query_only=ON")
            for r in con.execute("""
                SELECT DATE(updated_at) day, COUNT(*) c FROM work_items
                WHERE phase IN ('Q02','P2') AND status='done' AND verdict='PASS'
                  AND updated_at >= date('now', '-7 days')
                GROUP BY day
            """):
                days.setdefault(r["day"], {})["_q02_pass"] = r["c"]
            for r in con.execute("""
                SELECT DATE(updated_at) day, COUNT(*) c FROM work_items
                WHERE phase IN ('Q03','P3') AND status='done' AND verdict='PASS'
                  AND updated_at >= date('now', '-7 days')
                GROUP BY day
            """):
                days.setdefault(r["day"], {})["_q03_pass"] = r["c"]
            con.close()
        except Exception:
            pass
        return days
    trend = _trend_data()

    def _daily_controlling_data() -> dict:
        mt5_phases = {
            "P2", "P3", "P4", "P5", "P5b", "P5c", "P6", "P8",
            "Q02", "Q03", "Q04", "Q05", "Q06", "Q08", "Q10", "Q11",
        }
        analysis_phases = {"P3.5", "P7", "Q07"}
        rows = db_rows(
            """
            SELECT phase, status, verdict, ea_id, symbol, payload_json, updated_at
            FROM work_items
            WHERE updated_at >= date('now', '-30 days')
            """
        )
        windows = {
            "today": 0,
            "yesterday": 1,
            "7d": 7,
            "30d": 30,
        }
        today = dt.date.today()
        stats = {
            key: {
                "mt5_items": 0,
                "mt5_eas": set(),
                "analysis_items": 0,
                "analysis_eas": set(),
                "done_items": 0,
                "fail_invalid": 0,
                "zero_trade_like": 0,
                "invalid": 0,
                "waiting_input": 0,
            }
            for key in windows
        }
        by_phase: dict[str, dict[str, int]] = {}
        by_terminal: dict[str, int] = {}
        anomalies = {"zero_trade_like": 0, "invalid": 0, "waiting_input": 0}

        def in_window(day: dt.date, key: str, days: int) -> bool:
            delta = (today - day).days
            if key == "today":
                return delta == 0
            if key == "yesterday":
                return delta == 1
            return 0 <= delta < days

        for row in rows:
            updated = str(row.get("updated_at") or "")[:10]
            try:
                day = dt.date.fromisoformat(updated)
            except Exception:
                continue
            phase = str(row.get("phase") or "")
            status = str(row.get("status") or "")
            verdict = str(row.get("verdict") or "")
            payload = {}
            if row.get("payload_json"):
                try:
                    payload = json.loads(row["payload_json"])
                except Exception:
                    payload = {}
            reason = str(payload.get("verdict_reason") or "")
            zero_trade_like = "MIN_TRADES_NOT_MET" in reason or "zero" in reason.lower()
            is_mt5 = phase in mt5_phases
            is_analysis = phase in analysis_phases
            for key, days in windows.items():
                if not in_window(day, key, days):
                    continue
                bucket = stats[key]
                if status in {"done", "failed"}:
                    bucket["done_items"] += 1
                    if is_mt5:
                        bucket["mt5_items"] += 1
                        if row.get("ea_id"):
                            bucket["mt5_eas"].add(row["ea_id"])
                    elif is_analysis:
                        bucket["analysis_items"] += 1
                        if row.get("ea_id"):
                            bucket["analysis_eas"].add(row["ea_id"])
                if verdict in {"FAIL", "INVALID"}:
                    bucket["fail_invalid"] += 1
                if zero_trade_like:
                    bucket["zero_trade_like"] += 1
                if verdict == "INVALID":
                    bucket["invalid"] += 1
                if verdict == "WAITING_INPUT":
                    bucket["waiting_input"] += 1
            if status in {"done", "failed"}:
                key = f"{phase_label(phase)} {verdict or status}"
                by_phase[key] = by_phase.get(key, {"count": 0})
                by_phase[key]["count"] += 1
            terminal = payload.get("terminal") or row.get("claimed_by")
            if terminal and is_mt5:
                by_terminal[str(terminal)] = by_terminal.get(str(terminal), 0) + 1
            if zero_trade_like:
                anomalies["zero_trade_like"] += 1
            if verdict == "INVALID":
                anomalies["invalid"] += 1
            if verdict == "WAITING_INPUT":
                anomalies["waiting_input"] += 1

        for bucket in stats.values():
            bucket["mt5_eas"] = len(bucket["mt5_eas"])
            bucket["analysis_eas"] = len(bucket["analysis_eas"])
        return {
            "windows": stats,
            "by_phase": sorted(
                [{"label": k, "count": v["count"]} for k, v in by_phase.items()],
                key=lambda r: r["count"],
                reverse=True,
            )[:12],
            "by_terminal": sorted(
                [{"terminal": k, "count": v} for k, v in by_terminal.items()],
                key=lambda r: r["terminal"],
            ),
            "anomalies": anomalies,
        }

    controlling = _daily_controlling_data()

    severity, msg = diagnose_bottleneck(procs, q, claude_workers, codex_workers)

    # === HTML — PAPER / INK (Direction C) ===
    now_utc_full = dt.datetime.now(dt.UTC).replace(tzinfo=None).strftime("%Y-%m-%d %H:%M:%SZ")
    now_local = dt.datetime.now().strftime("%H:%M:%S")
    # v7 freshness: embed the render epoch (ms) so a small client-side script can
    # show a live 'Xs/Xm ago' age even when the page is viewed as a stale file://
    # snapshot — the 2026-07-19 stale-CRITICAL confusion came from a file with no
    # visible age.
    render_epoch_ms = int(dt.datetime.now().timestamp() * 1000)
    # Top-bar health pill — map bottleneck severity to NOMINAL/WARN/CRITICAL.
    # OWNER call 2026-05-23: CRITICAL fires only when the Edge Lab itself is
    # down — never on output dryness ("no EA further along" = the actual work,
    # not a fault). Output-flow checks degrade the pill at most to WARN.
    _FACTORY_DOWN_CHECKS = {
        "mt5_worker_saturation",   # T1-T10 daemons dead
        "codex_auth_broken",       # cannot build EAs
        "disk_free_gb",            # storage blocker
        "pump_task_lastresult",    # orchestrator failing
        "ablation_grandchildren",  # state-integrity violation
        "active_row_age",          # rows stuck past phase timeout
    }
    pill_label = {"ok": "NOMINAL", "warn": "WARN", "block": "CRITICAL"}[severity]
    pill_class = {"ok": "", "warn": "warn", "block": "crit"}[severity]
    _checks = health.get("checks") or []
    _fail_checks = [c for c in _checks if (c.get("status") or "").upper() == "FAIL"]
    _factory_fail_checks = [c for c in _fail_checks if c.get("name") in _FACTORY_DOWN_CHECKS]
    _factory_fail = bool(_factory_fail_checks)
    _any_fail = bool(_fail_checks)
    # v7 status hardening (2026-07-19): CRITICAL only when the factory is
    # GENUINELY down — worker/orchestrator checks FAIL *and* no intentional
    # FACTORY_OFF.flag present. If the flag exists the stop is deliberate, so
    # the pill degrades to amber MAINTENANCE, never CRITICAL. Worker liveness
    # comes from health.json's live-process-scan checks (mt5_worker_saturation)
    # and live_worker_terminals() — never from pipeline_state.json, whose
    # content contradicted the DB in the 2026-07-19 audit.
    factory_off = False
    try:
        factory_off = FACTORY_OFF_FLAG.exists()
    except OSError:
        factory_off = False
    if factory_off:
        pill_label = "MAINTENANCE"; pill_class = "warn"
        # Pump/worker/orchestrator FAILs are implied by an intentional OFF —
        # narrating a dead pump's exit code next to "intentional" reads as a
        # contradiction (OWNER 2026-07-25). Non-factory FAILs still surface
        # through the WARN branch below and the heartbeat panel.
        msg = "FACTORY OFF (intentional) — workers paused by FACTORY_OFF.flag"
    elif _factory_fail:
        pill_label = "CRITICAL"; pill_class = "crit"
        # Topbar must explain the CRITICAL, not narrate the build queue —
        # a red pill next to "coding intentionally paused" is incoherent
        # (OWNER 2026-07-07).
        msg = " // ".join(
            f"{c.get('name')}: {str(c.get('detail'))[:90]}" for c in _factory_fail_checks[:2]
        )
    elif _any_fail and pill_class == "":
        pill_label = "WARN"; pill_class = "warn"
        msg = f"{_fail_checks[0].get('name')}: {str(_fail_checks[0].get('detail'))[:80]} // {msg}"
    elif (health.get("overall") or "").upper() == "WARN" and pill_class == "":
        pill_label = "WARN"; pill_class = "warn"

    def sparkline_str(values: list[int]) -> str:
        """7-char unicode bar sparkline from a list of ints."""
        glyphs = "▁▂▃▄▅▆▇█"
        if not values:
            return "▁▁▁▁▁▁▁"
        max_v = max(values) or 1
        out = []
        for v in values:
            idx = int(round((v / max_v) * (len(glyphs) - 1)))
            out.append(glyphs[max(0, min(len(glyphs) - 1, idx))])
        return "".join(out)

    # ---------- 2. LIVE MONEY ROW (OWNER rework 2026-07-07) ----------
    decisions = owner_decision_rows(q12_count)
    decisions.extend(pipeline_books_owner_decision_rows(programme))
    decisions.sort(key=lambda row: (0 if row.get("alert") else 1, str(row.get("due") or "9999-12-31")))

    dxz = money.get("dxz") or {}
    ftmo = money.get("ftmo") or {}

    def _tile_cls(verdict: str, alarms: int, warn: bool = False) -> str:
        if not verdict or verdict == "?":
            return ""
        if verdict != "OK" or alarms:
            return "alert"
        return "warn" if warn else "ok"

    def _fmt_age_min(m) -> str:
        if not isinstance(m, (int, float)):
            return "?"
        m = int(m)
        if m < 90:
            return f"{m}m"
        if m < 48 * 60:
            return f"{m / 60:.0f}h"
        return f"{m / 1440:.1f}d"

    def _fmt_pnl(v) -> str:
        return f"{'+' if v >= 0 else '-'}${abs(v):,.0f}"

    if dxz:
        _sleeves = dxz.get("sleeves")
        _eq = dxz.get("equity")
        _pos = dxz.get("positions")
        _dbal = dxz.get("deal_balance")
        _dbal_age = dxz.get("deal_age_min")
        _mon_eq = dxz.get("mon_equity")
        _mon_pos = dxz.get("mon_positions")
        _mon_flt = dxz.get("mon_floating")
        _mon_age = dxz.get("mon_age_min")
        # Source priority (OWNER 2026-07-25): (1) AccountMonitor snapshot —
        # terminal-truth equity incl. floating, 60s timer — when fresh;
        # (2) flat book → deal-history balance (realized truth, costs
        # broker-booked); (3) EA day-close snapshot, honestly aged.
        _use_monitor = (
            isinstance(_mon_eq, (int, float))
            and isinstance(_mon_age, int) and _mon_age <= 5
        )
        _use_balance = (
            not _use_monitor and _pos == 0 and isinstance(_dbal, (int, float))
        )
        if _use_monitor:
            dxz_val = f"${_mon_eq:,.0f}"
        elif _use_balance:
            dxz_val = f"${_dbal:,.0f}"
        elif isinstance(_eq, (int, float)):
            dxz_val = f"${_eq:,.0f}"
        else:
            dxz_val = f"{_sleeves} SLEEVES" if _sleeves is not None else "PULSE?"
        dxz_cls = _tile_cls(dxz.get("verdict", "?"), dxz.get("alarms", 0))
        _at = str(dxz.get("autotrading") or "?").upper()
        _age = dxz.get("age_min")
        _dp = dxz.get("day_pnl")
        _eqa = dxz.get("equity_age_min")
        # Day-close cadence is ~24h; >78h covers the weekend gap. Older than
        # that with an OK verdict still deserves amber — the figure is stale.
        if (not _use_monitor and not _use_balance and isinstance(_eqa, int)
                and _eqa > 78 * 60 and dxz_cls == "ok"):
            dxz_cls = "warn"
        bits: list[str] = [f"acct {dxz.get('account') or '?'}"]
        if _sleeves is not None:
            bits.append(f"{_sleeves} sleeves")
        bits.append(f"AT {_at}")
        if _use_monitor:
            bits.append(f"monitor eq {_fmt_age_min(_mon_age)} ago")
            if _mon_pos is not None:
                bits.append(f"{_mon_pos} open pos")
            if isinstance(_mon_flt, (int, float)) and _mon_flt != 0:
                bits.append(f"floating {_fmt_pnl(_mon_flt)}")
        elif _use_balance:
            bits.append(f"balance, flat book, last deal {_fmt_age_min(_dbal_age)} ago")
            if isinstance(_eq, (int, float)):
                bits.append(f"day-close snap ${_eq:,.0f} ({_fmt_age_min(_eqa)} old)")
        else:
            if isinstance(_dp, (int, float)):
                bits.append(f"day P&L {_fmt_pnl(_dp)}")
            if _eqa is not None:
                bits.append(f"eq close {_fmt_age_min(_eqa)} old")
            if isinstance(_dbal, (int, float)):
                bits.append(f"bal after deals ${_dbal:,.0f} ({_fmt_age_min(_dbal_age)} ago)")
            if _pos is not None:
                bits.append(f"{_pos} open pos")
        bits.append(f"verdict {dxz.get('verdict', '?')}")
        if _age is not None:
            bits.append(f"pulse {_age}m ago")
        dxz_sub = " // ".join(bits)
    else:
        dxz_val, dxz_cls, dxz_sub = "NO PULSE", "alert", "live_book_pulse.json unreadable"

    if ftmo:
        _eq = ftmo.get("equity")
        _mon_eq = ftmo.get("mon_equity")
        _mon_pos = ftmo.get("mon_positions")
        _mon_age = ftmo.get("mon_age_min")
        _use_monitor = (
            isinstance(_mon_eq, (int, float))
            and isinstance(_mon_age, int) and _mon_age <= 5
        )
        if _use_monitor:
            ftmo_val = f"${_mon_eq:,.0f}"
            # Live DD against the 100k base — the pulse's figure derives from
            # the EA day-close snapshot, which can lag days (it hid 2.3% of
            # drawdown on 2026-07-25).
            _dd = max(0.0, (100_000.0 - _mon_eq) / 100_000.0 * 100.0)
        else:
            ftmo_val = f"${_eq:,.0f}" if isinstance(_eq, (int, float)) else "PULSE?"
            _dd = ftmo.get("total_dd_pct")
        _dl = ftmo.get("day_loss_pct")
        _soft_warn = (isinstance(_dl, (int, float)) and _dl >= 3.5) or (
            isinstance(_dd, (int, float)) and _dd >= 6.0)
        ftmo_cls = _tile_cls(ftmo.get("verdict", "?"), ftmo.get("alarms", 0), warn=_soft_warn)
        _dp = ftmo.get("day_pnl")
        _age = ftmo.get("age_min")
        _eqa = ftmo.get("eq_age_min")
        bits = []
        if not ftmo.get("terminal_up"):
            bits.append("TERMINAL DOWN")
        if _use_monitor:
            bits.append(f"monitor eq {_fmt_age_min(_mon_age)} ago")
            if _mon_pos is not None:
                bits.append(f"{_mon_pos} open pos")
        elif isinstance(_dp, (int, float)):
            _dlf = f" ({_dl:.1f}% of 5%)" if isinstance(_dl, (int, float)) else ""
            bits.append(f"day P&L {_fmt_pnl(_dp)}{_dlf}")
        if isinstance(_dd, (int, float)):
            bits.append(f"total DD {_dd:.2f}% of 10%")
        if not _use_monitor and _eqa is not None:
            bits.append(f"eq snap {_fmt_age_min(_eqa)} old")
        if ftmo.get("magics_seen") is not None:
            bits.append(f"{ftmo.get('magics_seen')}/{ftmo.get('expected_magics')} magics")
        bits.append(f"verdict {ftmo.get('verdict', '?')}")
        if _age is not None:
            bits.append(f"pulse {_age}m ago")
        ftmo_sub = " // ".join(bits)
        # A book 0.03% above the hard 10% floor is red regardless of what the
        # (possibly stale) pulse verdict says.
        if isinstance(_dd, (int, float)) and _dd >= 9.0:
            ftmo_cls = "alert"
    else:
        ftmo_val, ftmo_cls, ftmo_sub = "NO PULSE", "alert", "ftmo_trial_pulse.json unreadable"

    if decisions:
        gate_val = decisions[0].get("due") or decisions[0].get("cat") or "—"
        gate_sub = f"{decisions[0].get('title', '')} // {len(decisions)} decision(s) open"
    else:
        gate_val, gate_sub = "NONE", "no OWNER decisions pending"

    money_html = f'''
  <div class="frontier">
    <a class="frontier-tile" href="dxz_journal.html" title="Open the DXZ Trading Journal">
      <div class="f-lbl">DXZ Live Book // Darwinex Zero</div>
      <div class="f-val {dxz_cls}">{e(dxz_val)}</div>
      <div class="f-sub">{e(dxz_sub)}</div>
    </a>
    <div class="frontier-tile">
      <div class="f-lbl">FTMO Trial // 100K</div>
      <div class="f-val {ftmo_cls}">{e(ftmo_val)}</div>
      <div class="f-sub">{e(ftmo_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Next OWNER Gate</div>
      <div class="f-val hot">{e(gate_val)}</div>
      <div class="f-sub">{e(gate_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Mission Target</div>
      <div class="f-val">+20% P.A.</div>
      <div class="f-sub">DXZ &euro;100k mandate // DD guard 5% / 20% // no ML // evidence over claims</div>
    </div>
  </div>
'''

    # ---------- 3. OWNER DECISIONS ----------
    # Only genuine OWNER decisions (OWNER call 2026-07-07: "was muss ich da
    # alles entscheiden?" — the old panel listed Claude review tasks and
    # zombie BLOCKED rows, none of which OWNER can act on).
    # Uncapped COUNT — the old LIMIT-8 row fetch silently capped both the
    # Claude QUE readout and the funnel BUILT stage at 8 (audit 2026-07-25).
    # json_extract join instead of correlated NOT-EXISTS-LIKE: same result,
    # ~0.2s vs ~20s in the 2-min render loop (Codex review 2026-07-25).
    _review_rows = db_rows(
        "SELECT COUNT(*) AS c FROM tasks b "
        "LEFT JOIN (SELECT DISTINCT json_extract(payload_json, '$.build_task_id') AS id "
        "           FROM tasks WHERE kind='ea_review' AND json_valid(payload_json)) r "
        "  ON r.id = b.id "
        "WHERE b.kind='build_ea' AND b.status='done' AND r.id IS NULL"
    )
    review_pending_count = int(_review_rows[0]["c"] or 0) if _review_rows else 0
    attention_rows: list[str] = []
    for d in decisions[:8]:
        row_cls = "attention-row alert" if d.get("alert") else "attention-row"
        due = d.get("due") or ""
        attention_rows.append(
            f'<div class="{row_cls}">'
            f'<span class="glyph">▸</span>'
            f'<span class="cat">{e(d.get("cat", "DECISION"))}</span>'
            f'<span class="ent">{e(d.get("title", ""))}<span class="slug">{e(d.get("detail", ""))}</span></span>'
            f'<span class="status">{e(("DUE " + due) if due else "OWNER")}</span>'
            f'</div>'
        )
    if not attention_rows:
        attention_rows.append(
            '<div class="attention-row">'
            '<span class="glyph">·</span>'
            '<span class="cat">CLEAR</span>'
            '<span class="ent">no OWNER decisions pending<span class="slug">agents are working autonomously</span></span>'
            '<span class="status">OK</span>'
            '</div>'
        )
    attention_html_inner = "\n".join(attention_rows)
    attention_aux = f"{len(decisions):02d} Decisions Open"

    # ---------- 3. AGENT STATUS ----------
    claude_act = len(claude_workers)
    codex_act = len(codex_workers)
    mt5_act = len(mt5_work)
    review_q_count = review_pending_count

    # Today's completed work_items counts as "DONE TODAY" for MT5
    cw_today = controlling["windows"]["today"]
    mt5_done_today = cw_today.get("mt5_items", 0)

    # Claude/Codex closed-today: agent_tasks transitioned in the last 24h
    try:
        claude_closed_today = (db_rows(
            "SELECT COUNT(*) AS c FROM agent_tasks "
            "WHERE assigned_agent='claude' AND state IN ('APPROVED','PASSED','FAILED','RECYCLE') "
            "AND DATE(updated_at) = DATE('now')"
        ) or [{"c": 0}])[0]["c"]
        codex_closed_today = (db_rows(
            "SELECT COUNT(*) AS c FROM agent_tasks "
            "WHERE assigned_agent='codex' AND state IN ('APPROVED','PASSED','FAILED','RECYCLE') "
            "AND DATE(updated_at) = DATE('now')"
        ) or [{"c": 0}])[0]["c"]
    except Exception:
        claude_closed_today = 0
        codex_closed_today = 0

    # Full limits readout per agent (OWNER "Update?" standard: 5h + weekly % + resets).
    # Source: quota_pull.py headless API snapshot via quota_snapshot().
    def _limits_html(src: str) -> str:
        s = qsnap.get(src, {}) if qsnap else {}

        def _pct_span(label: str, val, reset) -> str:
            if not isinstance(val, (int, float)):
                return f'<span class="k">{label}</span> <span class="v">—</span>'
            cls = "lim-crit" if val >= 90 else ("lim-warn" if val >= 70 else "lim-ok")
            r = f' <span class="lim-reset">&rarr;{e(str(reset))}</span>' if reset else ""
            return f'<span class="k">{label}</span> <span class="v {cls}">{int(val)}%</span>{r}'

        # Post-2026-07-12 API change: Codex no longer exposes a 5-hour window —
        # the weekly limit is now the primary window. Only render the 5H cell
        # when real 5h data exists (Claude still reports it); otherwise drop it
        # and mark weekly as PRIMARY rather than showing a mislabeled "5H —".
        parts = []
        if isinstance(s.get("hour_pct"), (int, float)):
            parts.append(_pct_span("5H", s.get("hour_pct"), s.get("hour_reset")))
        wk_label = "WK" if isinstance(s.get("hour_pct"), (int, float)) else "WK (PRIMARY)"
        parts.append(_pct_span(wk_label, s.get("week_pct"), s.get("week_reset")))
        if src == "claude" and isinstance(s.get("sonnet_pct"), (int, float)):
            parts.append(_pct_span("WK-SONNET", s.get("sonnet_pct"), None))
        stale = not s.get("fresh")
        age = s.get("age_sec")
        if stale and isinstance(age, int):
            parts.append(f'<span class="lim-stale">stale {age // 60}m</span>')
        return '<span class="sep">&middot;</span>'.join(parts)

    claude_limits_html = _limits_html("claude")
    codex_limits_html = _limits_html("codex")

    # Total backtests pending across all phases (combine builds + p2 + p3 + work_items pending)
    mt5_pend = (
        q.get("backtest_p2_pending", 0)
        + q.get("backtest_p3_pending", 0)
        + len(q.get("pending_backtests_list", []) or [])
        + q.get("work_items_pending", 0)
    )
    # T1..T10 fleet — farm-active when an mt5_work entry's terminal matches;
    # amber when a terminal64 process is alive without a farm claim (ad-hoc
    # harness or leaked runner — visible instead of lying "idle").
    active_terms = {str(w.get("terminal") or "").upper() for w in mt5_work}
    proc_terms = factory_terminal_procs()
    try:
        import farmctl
        reserved_terms = farmctl.terminal_reservations(ROOT)
    except Exception:
        reserved_terms = {}
    term_cells = []
    for i in range(1, 11):
        tname = f"T{i}"
        is_active = any(tname in t or t == tname for t in active_terms)
        is_proc = tname in proc_terms
        reservation = reserved_terms.get(tname)
        cls = "active" if is_active else ("reserved" if reservation else ("proc" if is_proc else "idle"))
        dot = "■" if (is_active or is_proc) else ("R" if reservation else "□")
        title = ""
        if reservation:
            title = (
                f' title="reserved by {e(reservation["reserved_by"])} '
                f'until {e(reservation["until_utc"])}: {e(reservation["reason"])}"'
            )
        term_cells.append(
            f'<div class="term {cls}"{title}><div class="id">{tname}</div><div class="dot">{dot}</div></div>'
        )
    term_row_html = "".join(term_cells)
    fleet_label = (
        f"T1–T10 Workers // {len(active_terms)} of 10 farm-active // "
        f"{len(proc_terms)} terminal proc{'s' if len(proc_terms) != 1 else ''} up // "
        f"{len(reserved_terms)} reserved"
        + (" — R = smoke/maintenance hold, blocks new claims" if reserved_terms else "")
    )

    # Watchdog pulse: last self-heal action + interactive-session state. Answers
    # OWNER's recurring "ist die Factory eigentlich gelaufen?" without log-digging.
    # Heartbeat records (action="heartbeat") are emitted after every run; the last
    # heartbeat ts determines freshness.  The last operational record (non-heartbeat)
    # carries the meaningful action + session state.
    # STALE rule: if the last heartbeat is >30 min old, the watchdog itself has stopped
    # cycling — override the display with "WATCHDOG-STALE since <ts>" (wd-crit).
    watchdog_str = "no watchdog telemetry"
    watchdog_cls = "wd-warn"
    try:
        wd_log = Path(r"D:\QM\reports\state\factory_watchdog.jsonl")
        if wd_log.exists():
            tail = wd_log.read_text(encoding="utf-8", errors="ignore").strip().splitlines()
            if tail:
                # Parse lines in reverse to find the last heartbeat and last operational record
                last_hb_ts = None
                last_op: dict = {}
                for raw in reversed(tail):
                    try:
                        rec = json.loads(raw)
                    except Exception:
                        continue
                    if rec.get("action") == "heartbeat":
                        if last_hb_ts is None:
                            last_hb_ts = str(rec.get("ts") or "")
                    else:
                        if not last_op:
                            last_op = rec
                    if last_hb_ts and last_op:
                        break

                # Freshness: use the last heartbeat if available, else last operational ts
                freshness_ts = last_hb_ts or str(last_op.get("ts") or "")
                age_min = None
                try:
                    t = dt.datetime.fromisoformat(freshness_ts.replace("Z", "+00:00"))
                    age_min = int((dt.datetime.now(dt.timezone.utc) - t).total_seconds() // 60)
                except Exception:
                    pass

                if age_min is not None and age_min > 30:
                    if factory_off:
                        # Watchdog task is disabled together with the factory —
                        # expected during MAINTENANCE, never CRIT (OWNER rule:
                        # CRITICAL is reserved for a genuinely down factory).
                        watchdog_str = (
                            f"paused with factory (MAINTENANCE) // last beat {age_min}m ago"
                        )
                        watchdog_cls = "wd-warn"
                    else:
                        # Watchdog stopped cycling — show explicit STALE label
                        watchdog_str = f"WATCHDOG-STALE since {freshness_ts} // {age_min}m ago"
                        watchdog_cls = "wd-crit"
                elif last_op:
                    act = str(last_op.get("action") or "?")
                    sess = "SESSION LOST" if last_op.get("session_lost") else "session ok"
                    age_txt = f" // {age_min}m ago" if age_min is not None else ""
                    watchdog_str = (f"{act} // {last_op.get('workers', '?')}/"
                                    f"{last_op.get('expect', '?')} workers // {sess}{age_txt}")
                    if last_op.get("session_lost") or act in ("heal_failed", "session_lost_no_autologon"):
                        watchdog_cls = "wd-crit"
                    elif act.startswith("healed"):
                        watchdog_cls = "wd-warn"
                    else:
                        watchdog_cls = "wd-ok"
    except Exception:
        pass

    # ---------- 5. PIPELINE FUNNEL ----------
    # One basis across the whole row (numeric audit 2026-07-25): every stage
    # shows the CUMULATIVE count that reached it, and backtest phases use the
    # same unit as the prog-strip — distinct (ea_id, symbol) PASS pairs.
    # Reservoir stocks (pending sources, in-flight builds) live in the meta
    # lines; the old row mixed stocks (1, 11) with lifetime totals (73203,
    # dominated 68% by INFRA_FAIL requeues) under flow-implying arrows.
    src_pending = backlog["sources"].get("pending", 0)
    src_done = backlog["sources"].get("done", 0)
    cards_ready = backlog["sources"].get("cards_ready", 0)

    # Cards total + EAs built (filesystem truth) — also feed section 5b.
    cards_dir = ROOT / "artifacts" / "cards_approved"
    cards_total = (sum(1 for p in cards_dir.iterdir()
                       if p.is_file() and p.suffix == ".md")
                   if cards_dir.exists() else 0)
    ea_dir_root = Path(r"C:\QM\repo\framework\EAs")
    eas_built = 0
    if ea_dir_root.exists():
        for d in ea_dir_root.iterdir():
            if d.is_dir() and d.name.startswith("QM5_"):
                # Counted as "built" only if the .ex5 exists
                if any(p.suffix == ".ex5" for p in d.iterdir()):
                    eas_built += 1
    eas_to_build = max(0, cards_total - eas_built)
    builds_inflight = (
        q.get("builds_pending", 0) + q.get("builds_active", 0) + review_q_count
    )

    def _pass_pairs(phases: tuple[str, ...]) -> int:
        ph = ",".join(f"'{p}'" for p in phases)
        rows_ = db_rows(
            "SELECT COUNT(DISTINCT ea_id || '|' || symbol) AS c FROM work_items "
            f"WHERE verdict='PASS' AND UPPER(phase) IN ({ph})"
        )
        return int(rows_[0]["c"] or 0) if rows_ else 0

    def _phase_read_keys(qid: str) -> tuple[str, ...]:
        """Canonical key plus every manifest-declared legacy read alias."""

        return (qid, *Q_TO_LEGACY_ALIASES.get(qid, ()))

    q02_pass_pairs = _pass_pairs(("Q02", "P2"))
    # ROBUST Q05-Q07: deduped across the band (an EA that reached Q07 also has
    # Q05+Q06 PASS rows — summing per-phase counts triple-counts it).
    robust_phase_keys = tuple(
        key for qid in ("Q05", "Q06", "Q07") for key in _phase_read_keys(qid)
    )
    robust_phase_sql = ",".join(f"'{phase}'" for phase in robust_phase_keys)
    robust_by_q: dict[str, int] = {}
    for r in db_rows(
        "SELECT phase, COUNT(DISTINCT ea_id || '|' || symbol) AS c FROM work_items "
        f"WHERE verdict='PASS' AND UPPER(phase) IN ({robust_phase_sql}) GROUP BY phase"
    ):
        qk = phase_label(r.get("phase"))
        robust_by_q[qk] = robust_by_q.get(qk, 0) + int(r.get("c") or 0)
    robust_pairs = _pass_pairs(robust_phase_keys)
    q05_pairs = robust_by_q.get("Q05", 0)
    robust_meta = " // ".join(
        f"{k}:{robust_by_q[k]}" for k in ("Q05", "Q06", "Q07") if k in robust_by_q
    ) or "0 PASS"
    portfolio_count = backlog.get("p8_pass_total", 0)
    portfolio_meta = f"TARGET 5 // {portfolio_count}/5"

    # 7D sparklines from trend dict (keys per day)
    def _last7(metric_key: str) -> list[int]:
        today_d = dt.date.today()
        return [int((trend.get((today_d - dt.timedelta(days=i)).isoformat()) or {}).get(metric_key, 0))
                for i in range(6, -1, -1)]

    src_spark = sparkline_str(_last7("source_intake")) if trend else "▁▁▁▁▁▁▁"
    cards_spark = sparkline_str(_last7("approved")) if trend else "▁▁▁▁▁▁▁"
    build_spark = sparkline_str(_last7("build_ok") or _last7("build_done")) if trend else "▁▁▁▁▁▁▁"
    q02_spark = sparkline_str(_last7("_q02_pass")) if trend else "▁▁▁▁▁▁▁"
    q03_spark = sparkline_str(_last7("_q03_pass")) if trend else "▁▁▁▁▁▁▁"
    q11_spark = "▁▁▁▁▁▁▁"

    # Funnel drop-off labels — same unit on both ends of every ratio.
    built_meta = f"{eas_to_build} TO BUILD // {builds_inflight} IN FLIGHT"
    q02_drop = ""
    if q02_pass_pairs:
        q02_drop = f"▼ {int(100 - 100 * q05_pairs / max(1, q02_pass_pairs))}% TO Q05"

    funnel_html_inner = (
        '<div class="funnel-stage{src_empty}">'
        '<div class="stg-lbl">SRC DONE</div>'
        f'<div class="stg-num">{src_done}</div>'
        f'<div class="stg-meta">{src_pending} PEND</div>'
        '<span class="stg-spark-lbl">7D INTAKE</span>'
        f'<div class="stg-spark">{src_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{cards_empty}">'
        '<div class="stg-lbl">CARDS APPROVED</div>'
        f'<div class="stg-num">{cards_total:,}</div>'
        f'<div class="stg-meta">{cards_ready} SRC CARDS-READY</div>'
        '<span class="stg-spark-lbl">7D APPROVED</span>'
        f'<div class="stg-spark">{cards_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{built_empty}">'
        '<div class="stg-lbl">EAS BUILT</div>'
        f'<div class="stg-num">{eas_built:,}</div>'
        f'<div class="stg-meta drop">{e(built_meta)}</div>'
        '<span class="stg-spark-lbl">7D BUILD</span>'
        f'<div class="stg-spark">{build_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{p2_empty}">'
        '<div class="stg-lbl">Q02 PASS PAIRS</div>'
        f'<div class="stg-num">{q02_pass_pairs:,}</div>'
        f'<div class="stg-meta drop">{e(q02_drop) or "—"}</div>'
        '<span class="stg-spark-lbl">7D Q02 PASS</span>'
        f'<div class="stg-spark">{q02_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{robust_empty}">'
        '<div class="stg-lbl">ROBUST Q05-Q07</div>'
        f'<div class="stg-num">{robust_pairs}</div>'
        f'<div class="stg-meta">{e(robust_meta)}</div>'
        '<span class="stg-spark-lbl">7D Q03 PASS</span>'
        f'<div class="stg-spark">{q03_spark}</div>'
        '</div>'
        '<div class="funnel-arrow">→</div>'
        '<div class="funnel-stage{portfolio_empty}">'
        '<div class="stg-lbl">PORTFOLIO Q11</div>'
        f'<div class="stg-num">{portfolio_count}</div>'
        f'<div class="stg-meta">{e(portfolio_meta)}</div>'
        '<span class="stg-spark-lbl">7D Q11 PASS</span>'
        f'<div class="stg-spark">{q11_spark}</div>'
        '</div>'
    )
    funnel_html_inner = funnel_html_inner.format(
        src_empty=" empty" if src_done == 0 else "",
        cards_empty=" empty" if cards_total == 0 else "",
        built_empty=" empty" if eas_built == 0 else "",
        p2_empty=" empty" if q02_pass_pairs == 0 else "",
        robust_empty=" empty" if robust_pairs == 0 else "",
        portfolio_empty=" empty" if portfolio_count == 0 else "",
    )

    # Q08 Portfolio Rescue table removed 2026-07-07 (OWNER call) — the
    # snapshot counts still feed the COMPANY FRONTIER Q08-cohort tile.

    # ---------- 5b. PIPELINE PROGRESS (per-Q breakdown — OWNER call) ----------
    # cards_total / eas_built / eas_to_build come from the funnel section
    # above (single filesystem walk, shared basis).

    # Backtest queue totals
    bt_done = 0
    bt_open = 0
    for r in db_rows(
        "SELECT status, COUNT(*) AS c FROM work_items GROUP BY status"
    ):
        if r.get("status") == "done":
            bt_done += int(r.get("c") or 0)
        elif r.get("status") in ("pending", "active"):
            bt_open += int(r.get("c") or 0)

    # Per-phase progress: distinct (ea_id, symbol) pairs that reached each Qxx
    # with a PASS verdict (or — for phases that don't write per-symbol PASS
    # rows — distinct ea_id count). Reads Qxx-keyed rows directly; legacy
    # P-keys map via the complete manifest alias inverse for any orphan rows.
    q_counts: dict[str, int] = {q: 0 for q in Q_DISPLAY_ORDER}
    # Optional parenthesised sub-line under a chip number (e.g. Q08 strict passes).
    q_chip_subnote: dict[str, str] = {}
    # Q00 = cards admitted to research intake.
    q_counts["Q00"] = cards_total
    # Q01 = EAs built (registry intersection w/ disk)
    q_counts["Q01"] = eas_built
    # Q02..Q10 = distinct (ea_id, symbol) PASS pairs at each Qxx. Each Q is
    # counted over the UNION of its Qxx + every declared legacy P key — summing
    # spaces double-counts pairs that exist under both (audit 2026-07-25).
    for qid in Q_DISPLAY_ORDER[2:11]:
        q_counts[qid] = _pass_pairs(_phase_read_keys(qid))
    # Q09 stores per-lane sub-keys (Q09_NEWS / Q09_PORTFOLIO) whose PASS
    # verdicts are lane-specific (CONFIG_LOCKED / PASS_PORTFOLIO) — the generic
    # PASS-pair filter above never matches them (audit 2026-08-03: chip showed
    # 0 against 33 real portfolio passes). PENDING_RUNNER placeholders are
    # sealed plans, not passes, and stay excluded.
    q09_rows = db_rows(
        "SELECT COUNT(DISTINCT ea_id || '|' || symbol) AS c FROM work_items "
        "WHERE (UPPER(phase)='Q09_PORTFOLIO' AND verdict='PASS_PORTFOLIO') "
        "   OR (UPPER(phase)='Q09_NEWS' AND verdict='CONFIG_LOCKED') "
        "   OR (UPPER(phase)='Q09' AND verdict='PASS')"
    )
    q_counts["Q09"] = int(q09_rows[0]["c"] or 0) if q09_rows else 0
    # Q08 advances more than it strictly passes: FAIL_SOFT is routed onward to the
    # Q09 portfolio track (framework/scripts/q08_davey/aggregate.py), so a chip
    # showing only strict PASS understates what actually reaches the next gate
    # (OWNER call 2026-08-13). The chip therefore counts PASS + FAIL_SOFT and
    # carries the strict-PASS subset as a parenthesised sub-line.
    q08_strict_pass = q_counts.get("Q08", 0)
    q08_adv_rows = db_rows(
        "SELECT COUNT(DISTINCT ea_id || '|' || symbol) AS c FROM work_items "
        "WHERE UPPER(phase) IN ('Q08','P7','P8') "
        "  AND verdict IN ('PASS','FAIL_SOFT')"
    )
    q08_advancing = int(q08_adv_rows[0]["c"] or 0) if q08_adv_rows else 0
    # Never let the display invent advancement: strict PASS is a subset of
    # advancing by construction, so a smaller union means a read defect.
    if q08_advancing >= q08_strict_pass:
        q_counts["Q08"] = q08_advancing
        q_chip_subnote["Q08"] = f"({q08_strict_pass:,} pass)"
    # Q11 has no tracked rows yet (truthfully 0). Q12 = EAs sitting in the
    # OWNER review pool; Q13 = sleeves live on T_Live, from the read-only
    # pulse projection (evidence chain: terminal logs → live_book_pulse.py).
    # A missing/unchecked pulse leaves the chip at 0 — never invent a live count.
    q12_rows = db_rows(
        "SELECT COUNT(DISTINCT ea_id) AS c FROM portfolio_candidates "
        "WHERE state='Q12_REVIEW_READY'"
    )
    q_counts["Q12"] = int(q12_rows[0]["c"] or 0) if q12_rows else 0
    try:
        _pulse_reconcile = (
            json.loads(LIVE_BOOK_PULSE.read_text(encoding="utf-8"))
            .get("manifest_reconcile") or {}
        )
        if _pulse_reconcile.get("checked"):
            q_counts["Q13"] = max(
                0,
                int(_pulse_reconcile.get("expected_count") or 0)
                - int(_pulse_reconcile.get("missing_loaded") or 0),
            )
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        pass
    # Q14--Q16 are an explicit Q10 optimization fork, not ordinal successors
    # of Q13.  Only recorded success outcomes enter the compact chip counts.
    q_counts.update(successful_phase_counts(optimization_snapshot))

    # Build the progress HTML — top-line counters + per-Q chip strip.
    progress_html = f"""
  <!-- 5b. PIPELINE PROGRESS -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Pipeline Progress // Per-Phase Count</span>
      <span class="section-aux">Cards &rarr; EAs &rarr; Backtests &rarr; Q-Survivors</span>
    </div>
    <div class="prog-counters">
      <div class="prog-counter"><div class="prog-lbl">Strategy Cards</div><div class="prog-val">{cards_total:,}</div></div>
      <div class="prog-counter"><div class="prog-lbl">EAs Built</div><div class="prog-val">{eas_built:,}<span class="prog-of"> / {cards_total:,}</span></div></div>
      <div class="prog-counter"><div class="prog-lbl">EAs To Build</div><div class="prog-val">{eas_to_build:,}</div></div>
      <div class="prog-counter"><div class="prog-lbl">Backtests Done</div><div class="prog-val">{bt_done:,}</div></div>
      <div class="prog-counter"><div class="prog-lbl">Backtests Open</div><div class="prog-val">{bt_open:,}</div></div>
    </div>
    <div class="prog-strip-label">{e(LIFETIME_PASS_CHIP_LABEL)}</div>
    <div class="prog-strip">
      {''.join(
          f'<div class="prog-chip{" empty" if q_counts[q] == 0 else ""}">'
          f'<div class="prog-chip-q">{q}</div>'
          f'<div class="prog-chip-n">{q_counts[q]:,}</div>'
          + (f'<div class="prog-chip-sub">{e(q_chip_subnote[q])}</div>'
             if q_chip_subnote.get(q) else '')
          + f'</div>'
          for q in Q_DISPLAY_ORDER
      )}
    </div>
    <div class="prog-foot">
      Q00 = strategy cards &middot; Q01 = EAs with .ex5 on disk &middot;
      Q02..Q10 = distinct (EA, symbol) PASS pairs, cumulative across gate-regime
      eras (Q03/Q08 entered mid-history &mdash; adjacent chips are not one
      regime's funnel) &middot; Q09 = union of news/portfolio sub-gate passes &middot;
      Q10 = historical-visible PASS pairs, not current-contract binding &middot;
      Q12 = EAs in OWNER review pool &middot; Q13 = sleeves live on T_Live (pulse) &middot;
      Q14 = OPT_ELIGIBLE &middot; Q15 = CHALLENGER_SPAWNED &middot;
      Q16 = PROMOTE_CHALLENGER + KEEP_INCUMBENT + ADMIT_BOTH on the explicit Q10 fork
    </div>
  </div>
"""

    # Recent Events telemetry tail removed 2026-07-07 (OWNER call — all-red
    # zero-trade noise with no decision value).

    # ---------- 7. DAILY CONTROLLING ----------
    cw = controlling["windows"]
    today_date = dt.date.today().isoformat()
    yesterday_date = (dt.date.today() - dt.timedelta(days=1)).isoformat()
    # 7-day avg
    mt5_7d_total = cw["7d"]["mt5_items"]
    mt5_7d_avg = mt5_7d_total // 7 if mt5_7d_total else 0
    analysis_7d_total = cw["7d"]["analysis_items"]
    analysis_7d_avg = analysis_7d_total // 7 if analysis_7d_total else 0
    fail_7d_total = cw["7d"]["fail_invalid"]
    fail_7d_avg = fail_7d_total // 7 if fail_7d_total else 0
    mt5_30d = cw["30d"]["mt5_items"]
    # Q02 PASS cum from controlling.by_phase if available
    q02_pass_30d = 0
    for r in controlling.get("by_phase") or []:
        if (r.get("label") or "").startswith("Q02 PASS"):
            q02_pass_30d += int(r.get("count") or 0)
    anom = controlling["anomalies"]
    anom_today_total = (
        cw["today"]["zero_trade_like"]
        + cw["today"]["invalid"]
        + cw["today"]["waiting_input"]
    )
    anom_yesterday_total = (
        cw["yesterday"]["zero_trade_like"]
        + cw["yesterday"]["invalid"]
        + cw["yesterday"]["waiting_input"]
    )
    anom_30d_total = anom["zero_trade_like"] + anom["invalid"] + anom["waiting_input"]

    # ---------- 1. TOP BAR message ----------
    topbar_msg = e(msg)[:140]

    # ---------- BOTTOM BAR ----------
    try:
        sha_out = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=str(REPO), capture_output=True, text=True, timeout=5,
            creationflags=(subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0),
        )
        build_sha = (sha_out.stdout or "").strip() or "—"
    except Exception:
        build_sha = "—"

    # ---------- v7. FRESHNESS BADGE ----------
    freshness_html = (
        '<div class="freshness" id="freshness">'
        '<span class="lbl">Rendered</span>'
        f'<span class="rtime">{e(now_local)}</span>'
        '<span class="age" id="fresh-age">&middot;</span>'
        '</div>'
    )

    # ---------- v7. LIVE BOOK (T_Live) ----------
    def _age_short(sec) -> str:
        if sec is None:
            return "n/a"
        sec = int(sec)
        if sec < 90:
            return f"{sec}s"
        if sec < 5400:
            return f"{sec // 60}m"
        if sec < 172800:
            return f"{sec / 3600:.1f}h"
        return f"{sec // 86400}d"

    _jage = live_book.get("journal_age_sec")
    _deals = live_book.get("deals_today")
    lb_deals_val = f"{_deals} DEALS" if isinstance(_deals, int) else "n/a"
    lb_deals_cls = "hot" if isinstance(_deals, int) and _deals > 0 else ""
    if _jage is not None:
        _fills = (
            "fills logged today" if isinstance(_deals, int) and _deals > 0
            else "no fills logged today"
        )
        lb_deals_sub = (
            f"journal {live_book.get('journal_date') or '?'} // last write "
            f"{_age_short(_jage)} ago // {_fills}"
        )
    else:
        lb_deals_sub = "today journal not found (pre-open / rollover) — n/a"

    _eq = live_book.get("equity")
    lb_eq_val = f"${_eq:,.2f}" if isinstance(_eq, (int, float)) else "n/a"
    _edp = live_book.get("equity_day_pnl")
    _ets = str(live_book.get("equity_ts") or "")[:16].replace("T", " ")
    if isinstance(_eq, (int, float)):
        _dp_txt = (
            f" // day P&L {'+' if _edp >= 0 else '-'}${abs(_edp):,.2f}"
            if isinstance(_edp, (int, float)) else ""
        )
        _dxz_bal = (money.get("dxz") or {}).get("deal_balance")
        _bal_txt = (
            f" // bal after deals ${_dxz_bal:,.2f}"
            if isinstance(_dxz_bal, (int, float)) else ""
        )
        lb_eq_sub = (
            f"last day-close equity (EA-emitted) // {_ets}Z{_dp_txt}{_bal_txt} // NOT real-time"
        )
    else:
        lb_eq_sub = "no EQUITY_SNAPSHOT in EA logs — n/a"

    _at = live_book.get("ea_logs_today")
    _tot = live_book.get("ea_logs_total")
    lb_sleeves_val = f"{_at if _at is not None else 'n/a'}/{LIVE_BOOK_SLEEVES}"
    lb_sleeves_cls = "" if (isinstance(_at, int) and _at >= LIVE_BOOK_SLEEVES) else (
        "warn" if isinstance(_at, int) else "alert")
    lb_sleeves_sub = (
        f"EA logs written today // {_tot if _tot is not None else '?'} log files on disk"
    )
    live_book_html = f'''
  <div class="frontier">
    <div class="frontier-tile">
      <div class="f-lbl">Journal // T_Live Terminal</div>
      <div class="f-val {lb_deals_cls}">{e(lb_deals_val)}</div>
      <div class="f-sub">{e(lb_deals_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Book Equity // Day-Close</div>
      <div class="f-val">{e(lb_eq_val)}</div>
      <div class="f-sub">{e(lb_eq_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Active Sleeves // EA Logs Today</div>
      <div class="f-val {lb_sleeves_cls}">{e(lb_sleeves_val)}</div>
      <div class="f-sub">{e(lb_sleeves_sub)}</div>
    </div>
  </div>
'''

    # ---------- v7. OPS HEARTBEATS ----------
    def _dur_short(sec: int) -> str:
        if sec >= 3600 and sec % 3600 == 0:
            return f"{sec // 3600}h"
        if sec >= 3600:
            return f"{sec / 3600:.0f}h"
        return f"{sec // 60}m"

    hb_tiles: list[str] = []
    for hb in heartbeats:
        hb_tiles.append(
            f'<div class="hb-tile hb-{e(hb["status"])}">'
            f'<div class="hb-lbl">{e(hb["label"])}</div>'
            f'<div class="hb-age">{e(_age_short(hb.get("age_sec")))}</div>'
            f'<div class="hb-exp">expect &lt; {e(_dur_short(hb["warn_sec"]))}</div>'
            '</div>'
        )
    hb_tiles_html = "".join(hb_tiles)
    health_warns = [c for c in (health.get("checks") or []) if str(c.get("status") or "").upper() == "WARN"]
    hb_warn_rows: list[str] = []
    for c in health_warns:
        hb_warn_rows.append(
            '<div class="hb-warn-row">'
            f'<span class="hb-warn-name">{e(c.get("name"))}</span>'
            f'<span class="hb-warn-detail">{e(str(c.get("detail") or "")[:150])}</span>'
            '</div>'
        )
    if not hb_warn_rows:
        hb_warn_rows.append(
            '<div class="hb-warn-row">'
            '<span class="hb-warn-name" style="color:var(--pass)">NONE</span>'
            '<span class="hb-warn-detail">no health.json WARN checks</span>'
            '</div>'
        )
    hb_warns_html = "".join(hb_warn_rows)

# ==== HTML assembly (PAPER/INK Direction C · OWNER-DL 2026-07-20) ====

    # CSS lives outside the f-string to avoid brace-escaping.
    CSS = r"""
:root {
  --bg:            #f6f5f2;
  --surface-1:     #ffffff;
  --surface-2:     #f1efe8;
  --surface-3:     #e8e4d9;
  --text:          #1c1a16;
  --text-2:        #45403a;
  --text-3:        #726b60;
  --text-4:        #9a938a;
  --border:        #e2ded4;
  --border-2:      #cfc9bc;
  --signal:        #2954d4;
  --signal-bright: #1e42b8;
  --signal-dim:    #5b7ade;
  --pass:          #1a8f4c;
  --fail:          #d13438;
  --warn:          #b8720a;
  --info:          #45403a;
  --promising:     #8f6e06;
  --dead:          #98918a;
  --live:          #0e7490;
  --profit:        #1a8f4c;
  --loss:          #d13438;
}
* { box-sizing: border-box; margin: 0; padding: 0; border-radius: 0 !important; }
html, body {
  background: var(--bg);
  color: var(--text);
  font-family: 'General Sans', system-ui, sans-serif;
  font-size: 14px;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
body { padding: 32px; min-height: 100vh; }
.mono, .num, code, kbd {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
}
.page { display: grid; grid-template-columns: repeat(12, 1fr); gap: 24px; }

/* TOP BAR */
.topbar {
  grid-column: span 12;
  display: grid;
  grid-template-columns: auto 1fr auto auto auto;
  align-items: center;
  gap: 24px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--border);
}
/* v7 freshness badge — live 'age' computed client-side vs render epoch */
.freshness {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase;
  color: var(--text-3); white-space: nowrap; text-align: right;
  border: 1px solid var(--border-2); padding: 7px 12px;
}
.freshness .lbl { color: var(--text-4); margin-right: 8px; font-size: 10px; letter-spacing: 0.16em; }
.freshness .rtime { color: var(--text); font-weight: 700; }
.freshness .age { color: var(--text-3); margin-left: 8px; }
.freshness.age-warn { border-color: var(--warn); color: var(--warn); }
.freshness.age-warn .lbl, .freshness.age-warn .age { color: var(--warn); }
.freshness.age-crit { border-color: var(--fail); color: var(--fail); }
.freshness.age-crit .lbl, .freshness.age-crit .age { color: var(--fail); }
.brand {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-weight: 700; font-size: 14px;
  letter-spacing: 0.18em; color: var(--text); text-transform: uppercase;
}
.brand .slash { color: var(--text-4); margin: 0 10px; font-weight: 400; }
.brand .sub { color: var(--text-3); font-weight: 500; }
.topbar-msg {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; letter-spacing: 0.08em;
  color: var(--text-3); text-transform: uppercase;
}
.topbar-msg .tag { color: var(--warn); font-weight: 700; letter-spacing: 0.16em; margin-right: 10px; }
.topbar-msg .dot { color: var(--text-4); margin: 0 8px; }
.utc-clock {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 18px; font-weight: 500;
  color: var(--text); text-align: right; letter-spacing: 0.02em;
}
.utc-clock .lbl {
  display: block; font-size: 10px; font-weight: 400;
  letter-spacing: 0.22em; color: var(--text-3);
  margin-bottom: 4px; text-transform: uppercase;
}
.health-pill {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; font-weight: 700; letter-spacing: 0.22em;
  padding: 8px 14px; border: 1px solid var(--border-2);
  text-transform: uppercase; color: var(--text-3); background: transparent;
}
.health-pill.warn { color: var(--bg); background: var(--warn); border-color: var(--warn); }
.health-pill.crit { color: var(--bg); background: var(--fail); border-color: var(--fail);
                    animation: blink 1s steps(2) infinite; }
@keyframes blink { 50% { opacity: 0.35; } }

/* SECTION */
.section { grid-column: span 12; }
.col-left  { grid-column: span 7; min-width: 0; }
.col-right { grid-column: span 5; min-width: 0; }
.section-head {
  display: flex; align-items: center; gap: 12px;
  padding-bottom: 8px; margin-bottom: 14px;
  border-bottom: 1px solid var(--border);
}
.section-glyph { display: inline-block; width: 8px; height: 8px; background: var(--signal); flex-shrink: 0; }
.section-title {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 12px; font-weight: 600; letter-spacing: 0.12em;
  color: var(--text-3); text-transform: uppercase;
}
.section-aux {
  margin-left: auto;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; letter-spacing: 0.14em; color: var(--text-4); text-transform: uppercase;
}
.panel { background: var(--surface-1); border: 1px solid var(--border); box-shadow: 0 0 0 1px var(--border) inset; }

/* OWNER ATTENTION */
.attention { background: var(--surface-1); border: 1px solid var(--border); }
.attention-row {
  display: grid; grid-template-columns: 18px 150px 1fr 130px;
  gap: 14px; padding: 12px 18px; align-items: baseline;
  border-bottom: 1px solid var(--border);
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 12px;
}
.attention-row:last-child { border-bottom: none; }
.attention-row .glyph { color: var(--text-3); font-weight: 700; }
.attention-row .cat {
  font-size: 10px; font-weight: 700; letter-spacing: 0.18em;
  text-transform: uppercase; color: var(--text-2);
}
.attention-row .ent { color: var(--text); font-weight: 500; }
.attention-row .ent .slug { color: var(--text-3); margin-left: 8px; font-weight: 400; }
.attention-row .status {
  font-size: 10px; letter-spacing: 0.16em; text-transform: uppercase;
  color: var(--text-3); text-align: right;
}
.attention-row.alert .glyph { color: var(--fail); }
.attention-row.alert .cat   { color: var(--fail); }
.attention-row.alert .ent   { color: var(--text); }
.attention-row.alert .status { color: var(--fail); }

/* AGENT STATUS */
.agent-status { background: var(--surface-1); border: 1px solid var(--border); }
.agent-row {
  display: grid; grid-template-columns: 80px 1fr;
  gap: 16px; padding: 14px 20px; align-items: baseline;
  border-bottom: 1px solid var(--border);
}
.agent-row .name {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 12px; font-weight: 700; letter-spacing: 0.2em;
  color: var(--text); text-transform: uppercase;
}
.agent-readout {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 12px; letter-spacing: 0.02em; color: var(--text-2);
}
.agent-readout .v { color: var(--text); font-weight: 600; }
.agent-readout .sep { color: var(--text-4); margin: 0 8px; }
.agent-readout .k {
  color: var(--text-3); font-size: 10px;
  letter-spacing: 0.18em; text-transform: uppercase; margin-left: 4px;
}
.agent-limits {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 11px; letter-spacing: 0.02em; color: var(--text-3);
  padding: 0 20px 12px 116px; margin-top: -8px;
  border-bottom: 1px solid var(--border);
}
.agent-limits .k { color: var(--text-3); font-size: 10px; letter-spacing: 0.12em; }
.agent-limits .v { font-weight: 700; }
.agent-limits .lim-ok { color: var(--pass); }
.agent-limits .lim-warn { color: var(--warn); }
.agent-limits .lim-crit { color: var(--fail); }
.agent-limits .lim-reset { color: var(--text-3); font-size: 10px; }
.agent-limits .lim-stale { color: var(--warn); font-size: 10px; letter-spacing: 0.1em; text-transform: uppercase; }
.agent-limits .sep { margin: 0 8px; color: var(--border); }
/* A row followed by its limits line must not draw a bottom border — the
   limits block is pulled up (-8px) and the border would strike through it. */
.agent-row.with-limits { border-bottom: none; }
.watchdog-row {
  display: grid; grid-template-columns: 80px 1fr; gap: 16px;
  padding: 12px 20px; align-items: baseline;
  border-top: 1px solid var(--border);
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px;
}
.watchdog-row .wlbl {
  font-weight: 700; letter-spacing: 0.2em; font-size: 10px;
  text-transform: uppercase; color: var(--text-3);
}
.watchdog-row .wval { color: var(--text-2); }
.watchdog-row.wd-ok .wval { color: var(--pass); }
.watchdog-row.wd-warn .wval { color: var(--warn); }
.watchdog-row.wd-crit .wval { color: var(--fail); font-weight: 700; }
.agent-fleet { padding: 16px 20px 18px; border-bottom: none; }
.agent-fleet .flbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 600; letter-spacing: 0.22em;
  color: var(--text-3); text-transform: uppercase; margin-bottom: 12px;
}
.fleet-row { display: grid; grid-template-columns: repeat(10, 1fr); gap: 6px; }
.term {
  text-align: center; padding: 10px 0 8px;
  border: 1px solid var(--border); background: var(--surface-2);
}
.term .id {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 500; letter-spacing: 0.14em;
  color: var(--text-3); text-transform: uppercase;
}
.term .dot {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 14px; line-height: 1; margin-top: 5px;
}
.term.active .dot { color: var(--text); }
.term.idle   .dot { color: var(--text-3); }
.term.active .id  { color: var(--text-2); }
.term.reserved .dot { color: var(--warn); font-size: 9px; }
.term.reserved .id  { color: var(--warn); }
.term.proc .dot { color: var(--warn); }
.term.proc .id  { color: var(--text-2); }

/* PIPELINE PROGRESS — top-line counters + per-Q chip strip (OWNER call) */
.prog-counters {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 12px;
  background: var(--surface-1); border: 1px solid var(--border);
  padding: 16px 20px;
  margin-bottom: 12px;
}
.prog-counter {
  padding: 6px 14px;
  border-right: 1px solid var(--border);
}
.prog-counter:last-child { border-right: none; }
.prog-counter .prog-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; font-weight: 700; letter-spacing: 0.2em;
  color: var(--text-3); text-transform: uppercase;
  margin-bottom: 6px;
}
.prog-counter .prog-val {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 26px; font-weight: 500; line-height: 1;
  color: var(--text); letter-spacing: -0.02em;
}
.prog-counter .prog-of {
  font-size: 14px; color: var(--text-3); font-weight: 400;
}
.prog-strip {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(84px, 1fr));
  gap: 6px;
  background: var(--surface-1); border: 1px solid var(--border);
  padding: 14px 20px;
}
.prog-chip {
  padding: 10px 8px;
  text-align: center;
  background: var(--surface-2);
  border: 1px solid var(--border);
}
.prog-chip.empty .prog-chip-n { color: var(--text-4); }
.prog-chip-q {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; font-weight: 700; letter-spacing: 0.14em;
  color: var(--text-3); text-transform: uppercase;
  margin-bottom: 4px;
}
.prog-chip-n {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 18px; font-weight: 500; line-height: 1;
  color: var(--signal); letter-spacing: -0.02em;
}
.prog-chip-sub {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 9px; font-weight: 500; line-height: 1;
  color: var(--text-3); letter-spacing: 0.02em;
  margin-top: 3px;
}
.prog-foot {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; color: var(--text-4); letter-spacing: 0.06em;
  padding: 8px 4px 0;
}
.prog-strip-label {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 700; letter-spacing: 0.12em;
  color: var(--warn); text-transform: uppercase; padding: 0 4px 8px;
}

/* CONTRACT-VERSIONED ADJACENT COHORTS */
.cohort-table-wrap { overflow-x: auto; border: 1px solid var(--border); }
.cohort-table {
  width: 100%; border-collapse: collapse; background: var(--surface-1);
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 10px;
  font-variant-numeric: tabular-nums;
}
.cohort-table th, .cohort-table td {
  padding: 8px 10px; border-right: 1px solid var(--border);
  border-bottom: 1px solid var(--border); text-align: right;
}
.cohort-table th:first-child { min-width: 180px; text-align: left; }
.cohort-table thead th {
  color: var(--text-3); background: var(--surface-2); font-size: 9px;
  letter-spacing: 0.1em; text-transform: uppercase;
}
.cohort-table tbody th { color: var(--text-2); font-weight: 600; }
.cohort-table tr:last-child th, .cohort-table tr:last-child td { border-bottom: none; }
.cohort-table th:last-child, .cohort-table td:last-child { border-right: none; }
.cohort-up { color: var(--text); font-weight: 700; }
.cohort-no_row, .cohort-open { color: var(--text-3); }
.cohort-infra { color: var(--warn); }
.cohort-soft { color: var(--signal); }
.cohort-hard { color: var(--fail); }
.cohort-pass { color: var(--pass); font-weight: 700; }
.cohort-tail {
  display: grid; grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1px; background: var(--border); border: 1px solid var(--border); border-top: none;
}
.cohort-tail-card { background: var(--surface-1); padding: 11px 14px; }
.cohort-tail-card span, .cohort-tail-card small {
  display: block; font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; color: var(--text-3); letter-spacing: 0.08em;
}
.cohort-tail-card b {
  display: inline-block; margin-top: 5px; font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 20px; color: var(--pass); font-variant-numeric: tabular-nums;
}
.cohort-tail-card small { display: inline; margin-left: 6px; letter-spacing: 0; }
.cohort-tail-card.contract-bound b { color: var(--signal); }
.cohort-foot, .cohort-unavailable {
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 9px;
  line-height: 1.45; color: var(--text-4); padding: 9px 4px 0;
}
.cohort-unavailable { padding: 14px 18px; border: 1px solid var(--border); color: var(--fail); }
@media (max-width: 900px) { .cohort-tail { grid-template-columns: 1fr; } }

/* READ-ONLY Q14--Q16 OPTIMIZATION EXTENSION */
.opt-track-grid {
  display: grid; grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1px; background: var(--border); border: 1px solid var(--border);
}
.opt-phase-card { background: var(--surface-1); padding: 14px; min-width: 0; }
.opt-phase-id, .opt-phase-name, .opt-phase-outcomes, .opt-book-chip {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
}
.opt-phase-id { color: var(--signal); font-size: 11px; font-weight: 700; letter-spacing: 0.15em; }
.opt-phase-name { color: var(--text-3); font-size: 9px; margin-top: 3px; text-transform: uppercase; }
.opt-phase-total {
  color: var(--text); font-size: 24px; font-weight: 600; margin: 10px 0 8px;
  font-variant-numeric: tabular-nums;
}
.opt-phase-outcomes { display: grid; gap: 4px; color: var(--text-3); font-size: 9px; }
.opt-phase-outcomes b { color: var(--text-2); font-weight: 600; }
.opt-book-row {
  display: grid; grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px; margin-top: 8px;
}
.opt-book-chip { border: 1px solid var(--border); background: var(--surface-1); padding: 11px 14px; }
.opt-book-chip span, .opt-book-chip small { display: block; color: var(--text-3); font-size: 9px; }
.opt-book-chip b { display: block; color: var(--text-2); font-size: 13px; margin: 5px 0; }
.opt-book-chip.valid { border-left: 3px solid var(--pass); }
.opt-book-chip.invalid { border-left: 3px solid var(--fail); }
.opt-book-chip.missing { border-left: 3px solid var(--warn); }
.opt-track-foot, .opt-track-error {
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 9px;
  line-height: 1.45; color: var(--text-4); padding: 9px 4px 0;
}
.opt-track-error { color: var(--fail); padding: 10px 14px; border: 1px solid var(--fail); margin-bottom: 8px; }
@media (max-width: 900px) {
  .opt-track-grid, .opt-book-row { grid-template-columns: 1fr; }
}

/* PIPELINE FUNNEL */
.funnel {
  display: grid;
  grid-template-columns: 1fr 14px 1fr 14px 1fr 14px 1fr 14px 1fr 14px 1fr;
  align-items: stretch; gap: 0;
  background: var(--surface-1); border: 1px solid var(--border); padding: 20px;
}
.funnel-stage {
  border: 1px solid var(--border); background: var(--surface-2);
  padding: 14px 12px 12px; text-align: left; min-width: 0;
  display: flex; flex-direction: column; gap: 6px;
}
.funnel-stage .stg-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 700; letter-spacing: 0.2em;
  color: var(--text-3); text-transform: uppercase;
}
.funnel-stage .stg-num {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 36px; font-weight: 500; line-height: 1;
  margin: 2px 0; color: var(--text); letter-spacing: -0.02em;
}
.funnel-stage.empty .stg-num { color: var(--text-3); }
.funnel-stage .stg-meta {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; color: var(--text-3);
  letter-spacing: 0.04em; text-transform: uppercase;
}
.funnel-stage .stg-meta.drop { color: var(--text-2); }
.funnel-arrow {
  align-self: center; color: var(--text-4); text-align: center;
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 14px;
}
.funnel-stage .stg-spark-lbl {
  display: block;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; font-weight: 600; letter-spacing: 0.22em;
  color: var(--text-4); margin-top: 6px; text-transform: uppercase;
}
.funnel-stage .stg-spark {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 14px; line-height: 1; letter-spacing: 0.04em;
  color: var(--text-2); margin-top: 2px;
}
.funnel-stage.empty .stg-spark { color: var(--text-4); }

/* DAILY CONTROLLING */
.control {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 0;
  background: var(--surface-1); border: 1px solid var(--border);
}
.control-col {
  padding: 18px 22px 20px; border-right: 1px solid var(--border);
  display: flex; flex-direction: column; gap: 16px;
}
.control-col:last-child { border-right: none; }
.control-col .col-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 700; letter-spacing: 0.24em;
  text-transform: uppercase; color: var(--text-3);
  border-bottom: 1px solid var(--border); padding-bottom: 8px;
}
.control-stat .s-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 500; letter-spacing: 0.18em;
  text-transform: uppercase; color: var(--text-3);
}
.control-stat .s-val {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 28px; font-weight: 500; line-height: 1;
  margin-top: 6px; color: var(--text); letter-spacing: -0.02em;
}
.control-stat .s-val.dim { color: var(--text-3); }
.control-stat .s-sub {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 11px; color: var(--text-3);
  letter-spacing: 0.04em; margin-top: 5px; text-transform: uppercase;
}

/* COMPANY FRONTIER */
.frontier {
  grid-column: span 12;
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 1px;
  background: var(--border); border: 1px solid var(--border);
}
.frontier-tile { background: var(--surface-1); padding: 16px 20px; }
a.frontier-tile { display: block; text-decoration: none; color: inherit; }
a.frontier-tile:hover { background: var(--surface-2); }
.frontier-tile .f-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 600; letter-spacing: 0.22em;
  color: var(--text-3); text-transform: uppercase; margin-bottom: 10px;
}
.frontier-tile .f-val {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 22px; font-weight: 500; color: var(--text); line-height: 1.05;
}
.frontier-tile .f-val.hot { color: var(--live); }
.frontier-tile .f-val.ok { color: var(--pass); }
.frontier-tile .f-val.warn { color: var(--warn); }
.frontier-tile .f-val.alert { color: var(--fail); }
.frontier-tile .f-sub {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; color: var(--text-3); margin-top: 7px;
  letter-spacing: 0.05em; line-height: 1.5;
}

/* PIPELINE BOOKS PROGRAMME — hash-bound W0..W8 source projection */
.pb-program { background: var(--surface-1); border: 1px solid var(--border); }
.pb-program-fresh { border-top: 3px solid var(--pass); }
.pb-program-stale { border-top: 3px solid var(--warn); }
.pb-program-invalid { border-top: 3px solid var(--fail); }
.pb-source {
  display: flex; justify-content: space-between; gap: 24px; align-items: baseline;
  padding: 11px 16px; border-bottom: 1px solid var(--border);
  background: var(--surface-2); font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; letter-spacing: 0.08em; text-transform: uppercase;
}
.pb-source-state { font-weight: 700; color: var(--pass); white-space: nowrap; }
.pb-program-stale .pb-source-state { color: var(--warn); }
.pb-program-invalid .pb-source-state { color: var(--fail); }
.pb-source-detail { color: var(--text-3); text-align: right; overflow-wrap: anywhere; }
.pb-invalid-body {
  padding: 24px; color: var(--fail); font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 12px; line-height: 1.6;
}
.pb-safety {
  display: flex; flex-wrap: wrap; gap: 12px 30px; padding: 10px 16px;
  border-bottom: 1px solid var(--border); color: var(--warn);
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 10px;
  letter-spacing: 0.08em; text-transform: uppercase;
}
.pb-safety b { color: var(--text-2); margin-right: 5px; }
.pb-waves {
  display: grid; grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1px; background: var(--border); border-bottom: 1px solid var(--border);
}
.pb-wave { background: var(--surface-1); padding: 13px 15px; min-height: 142px; }
.pb-wave-id {
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 20px;
  font-weight: 700; color: var(--signal); float: left; margin-right: 11px;
}
.pb-wave-title { font-size: 12px; font-weight: 600; min-height: 37px; color: var(--text); }
.pb-wave-status, .pb-wave-axes {
  clear: both; padding-top: 7px; font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 9px; font-weight: 700; letter-spacing: 0.06em; color: var(--pass);
  overflow-wrap: anywhere;
}
.pb-wave-axes { clear: none; padding-top: 3px; color: var(--text-3); font-weight: 400; }
.pb-wave-next { margin-top: 8px; font-size: 10px; color: var(--text-3); line-height: 1.35; }
.pb-wave-shadow .pb-wave-status, .pb-wave-planned .pb-wave-status { color: var(--warn); }
.pb-wave-blocked .pb-wave-id, .pb-wave-blocked .pb-wave-status { color: var(--fail); }
.pb-contracts {
  display: grid; grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1px; background: var(--border); border-bottom: 1px solid var(--border);
}
.pb-contract { background: var(--surface-1); padding: 14px 16px; min-height: 124px; }
.pb-ftmo-runtime { grid-column: 1 / -1; border-left: 3px solid var(--warn); }
.pb-contract-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 10px;
  font-weight: 700; letter-spacing: 0.13em; color: var(--text-3); text-transform: uppercase;
}
.pb-contract-val {
  margin-top: 7px; font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 15px; font-weight: 700; color: var(--warn); overflow-wrap: anywhere;
}
.pb-contract-sub, .pb-verdicts, .pb-lane-line {
  margin-top: 4px; font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; color: var(--text-3); overflow-wrap: anywhere;
}
.pb-verdicts { color: var(--signal); }
.pb-contract-note { margin-top: 7px; color: var(--text-3); font-size: 10px; line-height: 1.4; }
.pb-lane-line.pass { color: var(--pass); margin-top: 9px; }
.pb-lane-line.residual { color: var(--fail); }
.pb-blockers-head {
  display: flex; justify-content: space-between; padding: 10px 16px;
  background: var(--surface-2); border-bottom: 1px solid var(--border);
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 10px;
  letter-spacing: 0.14em; color: var(--text-3);
}
.pb-blockers-head b { color: var(--fail); }
.pb-blocker {
  display: grid; grid-template-columns: 205px 1fr 210px; gap: 14px;
  padding: 9px 16px; border-bottom: 1px solid var(--border); align-items: baseline;
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 10px;
}
.pb-blocker:last-child { border-bottom: none; }
.pb-blocker-id { color: var(--fail); font-weight: 700; overflow-wrap: anywhere; }
.pb-blocker-title { color: var(--text-2); }
.pb-blocker-title small { display: block; color: var(--text-3); margin-top: 3px; }
.pb-blocker-blocks { color: var(--warn); text-align: right; overflow-wrap: anywhere; }
@media (max-width: 1050px) {
  .pb-waves, .pb-contracts { grid-template-columns: 1fr; }
  .pb-blocker { grid-template-columns: 1fr; gap: 4px; }
  .pb-blocker-blocks { text-align: left; }
}

/* BOTTOM BAR */
.botbar {
  grid-column: span 12;
  display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 24px;
  padding-top: 16px; border-top: 1px solid var(--border); margin-top: 4px;
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; letter-spacing: 0.2em;
  text-transform: uppercase; color: var(--text-3);
}
.botbar .center { text-align: center; }
.botbar .right  { text-align: right; }
.botbar .key    { color: var(--text-4); margin-right: 8px; }
.botbar .val    { color: var(--text-2); }

/* v7 OPS HEARTBEATS */
.hb-grid {
  display: grid; grid-template-columns: repeat(5, 1fr); gap: 1px;
  background: var(--border); border: 1px solid var(--border);
}
.hb-tile { background: var(--surface-1); padding: 14px 18px; }
.hb-lbl {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; font-weight: 600; letter-spacing: 0.18em;
  color: var(--text-3); text-transform: uppercase; margin-bottom: 8px;
}
.hb-age {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  font-size: 24px; font-weight: 500; line-height: 1; color: var(--text); letter-spacing: -0.02em;
}
.hb-exp {
  font-family: 'JetBrains Mono', ui-monospace, monospace;
  font-size: 10px; color: var(--text-4); margin-top: 6px;
  letter-spacing: 0.06em; text-transform: uppercase;
}
.hb-tile.hb-ok .hb-age   { color: var(--pass); }
.hb-tile.hb-warn .hb-age { color: var(--warn); }
.hb-tile.hb-crit .hb-age { color: var(--fail); }
.hb-tile.hb-miss .hb-age { color: var(--text-4); }
.hb-warns { background: var(--surface-1); border: 1px solid var(--border); border-top: none; }
.hb-warn-row {
  display: grid; grid-template-columns: 230px 1fr; gap: 14px;
  padding: 9px 20px; align-items: baseline; border-bottom: 1px solid var(--border);
  font-family: 'JetBrains Mono', ui-monospace, monospace; font-size: 11px;
}
.hb-warn-row:last-child { border-bottom: none; }
.hb-warn-name {
  color: var(--warn); font-weight: 700; letter-spacing: 0.1em;
  text-transform: uppercase; font-size: 10px;
}
.hb-warn-detail { color: var(--text-3); line-height: 1.4; }
"""

    # ---------- COMPANY FRONTIER (OWNER 2026-06-11: cockpit = company progress) ----------
    # The four numbers that say how far the COMPANY is, not how busy the factory is:
    # furthest candidate, Q08 cohort shape, inventory conversion, 30d throughput.
    try:
        pc_rows = db_rows("SELECT ea_id, symbol, state FROM portfolio_candidates ORDER BY updated_at DESC")
    except Exception:
        pc_rows = []
    q12_ready = [r for r in pc_rows if "Q12" in str(r.get("state") or "").upper()]
    if q12_ready:
        frontier_val = f"{len(q12_ready)} @ Q12"
        frontier_sub = " // ".join(
            f"{r['ea_id']} {str(r.get('symbol') or '').replace('.DWX', '')}" for r in q12_ready[:3]
        ) + " // waiting OWNER review"
    elif pc_rows:
        frontier_val = f"{len(pc_rows)} candidates"
        frontier_sub = "portfolio candidates pre-Q12"
    else:
        frontier_val = "Q08"
        frontier_sub = "no portfolio candidate yet — frontier is the Q08 cost-cushion gate"
    frontier_html = f'''
  <div class="frontier">
    <div class="frontier-tile">
      <div class="f-lbl">Frontier // Furthest Candidate</div>
      <div class="f-val hot">{e(frontier_val)}</div>
      <div class="f-sub">{e(frontier_sub)}</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Q08 Cohort</div>
      <div class="f-val">{q08_rescue.get("pass_portfolio", 0)}<span style="color:var(--text-3)">/{q08_rescue.get("soft", 0) + q08_rescue.get("hard", 0)}</span></div>
      <div class="f-sub">portfolio-pass / standalone-fails ({q08_rescue.get("soft", 0)} soft // {q08_rescue.get("hard", 0)} hard)</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Inventory Conversion</div>
      <div class="f-val">{eas_built:,}<span style="color:var(--text-3)">/{cards_total:,}</span></div>
      <div class="f-sub">EAs built / cards approved // {bt_done:,} backtests graded</div>
    </div>
    <div class="frontier-tile">
      <div class="f-lbl">Throughput // 30D</div>
      <div class="f-val">{mt5_30d:,}</div>
      <div class="f-sub">MT5 items done // {q02_pass_30d:,} Q02 PASS cumulative</div>
    </div>
  </div>
'''

    # === Final HTML ===
    html_doc = (
        '<!DOCTYPE html>\n'
        '<html lang="en"><head>\n'
        '<meta charset="utf-8">\n'
        '<title>QuantMechanica // COCKPIT</title>\n'
        '<meta http-equiv="refresh" content="120">\n'
        '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
        '<link rel="preconnect" href="https://api.fontshare.com" crossorigin>\n'
        '<link href="https://api.fontshare.com/v2/css?f[]=general-sans@200,400,500,600,700&display=swap" rel="stylesheet">\n'
        '<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">\n'
        '<style>' + CSS + '</style>\n'
        '</head>\n<body>\n'
        + f'''
<div class="page">

  <!-- 1. TOP BAR -->
  <div class="topbar">
    <div class="brand">QUANTMECHANICA<span class="slash">//</span><span class="sub">COCKPIT</span></div>
    <div class="topbar-msg">
      <span class="tag">{e(pill_label)}</span>
      {topbar_msg}
    </div>
    <div class="utc-clock">
      <span class="lbl">UTC // MISSION TIME</span>
      {e(now_utc_full)}
    </div>
    {freshness_html}
    <div class="health-pill {pill_class}">{e(pill_label)}</div>
  </div>

  <!-- 2. LIVE MONEY -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Live Money // Real Accounts</span>
      <span class="section-aux">DXZ Book // FTMO Trial // Pulse Evidence</span>
    </div>
    {money_html}
  </div>

  <!-- 2b. LIVE BOOK (T_Live) -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Live Book // T_Live Terminal</span>
      <span class="section-aux">Journal + EA Logs (read-only) // day-close, NOT real-time</span>
    </div>
    {live_book_html}
  </div>

  <!-- 3. OWNER DECISIONS + AGENT STATUS -->
  <div class="col-left">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Owner Decisions</span>
      <span class="section-aux">{attention_aux}</span>
    </div>
    <div class="attention">
      {attention_html_inner}
    </div>
  </div>

  <div class="col-right">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Agent Status</span>
      <span class="section-aux">Claude // Codex // MT5</span>
    </div>
    <div class="agent-status">
      <div class="agent-row with-limits">
        <span class="name">CLAUDE</span>
        <span class="agent-readout">
          <span class="v">{claude_act}</span><span class="k">ACT</span><span class="sep">&middot;</span>
          <span class="v">{review_q_count}</span><span class="k">QUE</span><span class="sep">&middot;</span>
          <span class="v">{claude_closed_today}</span><span class="k">CLOSED</span>
        </span>
      </div>
      <div class="agent-limits">{claude_limits_html}</div>
      <div class="agent-row with-limits">
        <span class="name">CODEX</span>
        <span class="agent-readout">
          <span class="v">{codex_act}</span><span class="k">ACT</span><span class="sep">&middot;</span>
          <span class="v">{q.get("builds_pending", 0)}</span><span class="k">QUE</span><span class="sep">&middot;</span>
          <span class="v">{codex_closed_today}</span><span class="k">CLOSED</span>
        </span>
      </div>
      <div class="agent-limits">{codex_limits_html}</div>
      <div class="agent-row">
        <span class="name">MT5</span>
        <span class="agent-readout">
          <span class="v">{mt5_act}</span><span class="k">/10 RUN</span><span class="sep">&middot;</span>
          <span class="v">{mt5_pend}</span><span class="k">PEND</span><span class="sep">&middot;</span>
          <span class="v">{mt5_done_today}</span><span class="k">DONE TODAY</span>
        </span>
      </div>
      <div class="agent-fleet">
        <div class="flbl">{e(fleet_label)}</div>
        <div class="fleet-row">{term_row_html}</div>
      </div>
      <div class="watchdog-row {watchdog_cls}">
        <span class="wlbl">WATCHDOG</span>
        <span class="wval">{e(watchdog_str)}</span>
      </div>
    </div>
  </div>

  <!-- 4. COMPANY FRONTIER -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Company Frontier // Pipeline Edge</span>
      <span class="section-aux">Furthest Candidate // Q08 Cohort // Conversion // Throughput</span>
    </div>
    {frontier_html}
  </div>

  {progress_html}

  {cohort_html}

  {optimization_html}

  <!-- 5. PIPELINE FUNNEL -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Pipeline Funnel // SRC &rarr; Portfolio</span>
      <span class="section-aux">Drop-Off Rates Per Stage</span>
    </div>
    <div class="funnel">
      {funnel_html_inner}
    </div>
  </div>

  <!-- 6. DAILY CONTROLLING -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Daily Controlling // Throughput &amp; Test Exceptions</span>
      <span class="section-aux">Today // Yesterday // 7D // 30D</span>
    </div>
    <div class="control">
      <div class="control-col">
        <div class="col-lbl">TODAY // {e(today_date)}</div>
        <div class="control-stat">
          <div class="s-lbl">MT5 Items Done</div>
          <div class="s-val">{cw["today"]["mt5_items"]}</div>
          <div class="s-sub">{cw["today"]["mt5_eas"]} EAs touched</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Analysis Gates</div>
          <div class="s-val">{cw["today"]["analysis_items"]}</div>
          <div class="s-sub">{cw["today"]["analysis_eas"]} EAs reviewed</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Test Exceptions</div>
          <div class="s-val">{anom_today_total}</div>
          <div class="s-sub">{cw["today"]["zero_trade_like"]} min-trade // {cw["today"]["invalid"]} invalid // {cw["today"]["waiting_input"]} waiting</div>
        </div>
      </div>
      <div class="control-col">
        <div class="col-lbl">YESTERDAY // {e(yesterday_date)}</div>
        <div class="control-stat">
          <div class="s-lbl">MT5 Items Done</div>
          <div class="s-val dim">{cw["yesterday"]["mt5_items"]}</div>
          <div class="s-sub">{cw["yesterday"]["mt5_eas"]} EAs touched</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Analysis Gates</div>
          <div class="s-val dim">{cw["yesterday"]["analysis_items"]}</div>
          <div class="s-sub">{cw["yesterday"]["analysis_eas"]} EAs reviewed</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Test Exceptions</div>
          <div class="s-val dim">{anom_yesterday_total}</div>
          <div class="s-sub">{cw["yesterday"]["zero_trade_like"]} min-trade // {cw["yesterday"]["invalid"]} invalid // {cw["yesterday"]["waiting_input"]} waiting</div>
        </div>
      </div>
      <div class="control-col">
        <div class="col-lbl">7-DAY AVG // PER DAY</div>
        <div class="control-stat">
          <div class="s-lbl">MT5 Items / day</div>
          <div class="s-val">{mt5_7d_avg}</div>
          <div class="s-sub">{mt5_7d_total} 7d total</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Analysis Gates / day</div>
          <div class="s-val">{analysis_7d_avg}</div>
          <div class="s-sub">{analysis_7d_total} 7d total</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Fail/Invalid / day</div>
          <div class="s-val">{fail_7d_avg}</div>
          <div class="s-sub">{fail_7d_total} 7d // pre-screen</div>
        </div>
      </div>
      <div class="control-col">
        <div class="col-lbl">30-DAY TOTAL</div>
        <div class="control-stat">
          <div class="s-lbl">MT5 Items Done</div>
          <div class="s-val">{mt5_30d}</div>
          <div class="s-sub">{cw["30d"]["mt5_eas"]} distinct EAs</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Q02 PASS Cum</div>
          <div class="s-val">{q02_pass_30d}</div>
          <div class="s-sub">{int(100 * q02_pass_30d / max(1, mt5_30d))}% of {mt5_30d} backtests</div>
        </div>
        <div class="control-stat">
          <div class="s-lbl">Test Exceptions</div>
          <div class="s-val">{anom_30d_total}</div>
          <div class="s-sub">{anom["zero_trade_like"]} min-trade // {anom["invalid"]} invalid // {anom["waiting_input"]} waiting</div>
        </div>
      </div>
    </div>
  </div>

  <!-- 7a. PIPELINE BOOKS PROGRAMME — hash-bound projection whose source
       snapshots go stale between programme runs; lives below the live
       sections so stale SOURCE states never crowd mission control. -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Pipeline Books // DXZ + FTMO Programme</span>
      <span class="section-aux">W0–W8 // Hash-Bound Source // No Runtime Authority</span>
    </div>
    {programme_html}
  </div>

  <!-- 7b. OPS HEARTBEATS -->
  <div class="section">
    <div class="section-head">
      <span class="section-glyph"></span>
      <span class="section-title">Ops Heartbeats // Scheduled Jobs</span>
      <span class="section-aux">File Ages // health.json WARNs</span>
    </div>
    <div class="hb-grid">
      {hb_tiles_html}
    </div>
    <div class="hb-warns">
      {hb_warns_html}
    </div>
  </div>

  <!-- 8. BOTTOM BAR -->
  <div class="botbar">
    <div><span class="key">Next Refresh</span><span class="val">120S</span></div>
    <div class="center"><span class="key">Renderer</span><span class="val">v7.0 // STEEL-EMERALD</span></div>
    <div class="right"><span class="key">Build</span><span class="val">SHA {e(build_sha)}</span></div>
  </div>

</div>
<script>
(function() {{
  var RENDER_EPOCH = {render_epoch_ms};
  var ageEl = document.getElementById('fresh-age');
  var badge = document.getElementById('freshness');
  if (!ageEl || !badge) return;
  function fmt(s) {{
    s = Math.max(0, Math.floor(s));
    if (s < 60) return s + 's ago';
    var m = Math.floor(s / 60);
    if (m < 60) return m + 'm ago';
    var h = Math.floor(m / 60);
    return h + 'h ' + (m % 60) + 'm ago';
  }}
  function tick() {{
    var age = (Date.now() - RENDER_EPOCH) / 1000;
    ageEl.textContent = fmt(age);
    badge.classList.remove('age-warn', 'age-crit');
    if (age > 900) badge.classList.add('age-crit');
    else if (age > 300) badge.classList.add('age-warn');
  }}
  tick();
  setInterval(tick, 1000);
}})();
</script>
'''
        + '\n</body></html>\n'
    )
    COCKPIT.write_text(html_doc, encoding="utf-8")
    print(f"cockpit written: {COCKPIT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
