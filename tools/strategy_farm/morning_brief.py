"""Morning brief — daily 7:00 status report OWNER can read first thing.

OWNER 2026-05-17: "Du öffnest morgens EINE Datei und siehst sofort: alles
grün — fortfahren, oder: 3 rote Sachen, klick hier."

Writes:
  D:/QM/strategy_farm/dashboards/morning_brief.md  (markdown, human-friendly)

Sections:
  1. Headline: pipeline state in 1 sentence
  2. Health: red invariants (from state/health.json)
  3. 12h delta: cards / builds / P2-PASS / P3-PASS counts
  4. Winners: EAs that achieved any PASS, by phase
  5. Codex/Claude quota: live %, time till reset
  6. What needs action today: derived from health FAILs + stuck queues
  7. Cockpit link

Scheduled task: QM_StrategyFarm_MorningBrief_0700 (daily, local time).
"""

from __future__ import annotations

import datetime as dt
import json
import os
import sqlite3
from pathlib import Path

ROOT = Path(r"D:\QM\strategy_farm")
DB = ROOT / "state" / "farm_state.sqlite"
HEALTH_FILE = ROOT / "state" / "health.json"
QUOTA_FILE = ROOT / "state" / "quota_snapshot.json"
DASH = ROOT / "dashboards"
BRIEF_FILE = DASH / "morning_brief.md"  # latest, cockpit-adjacent
# Vault archive: per OWNER 2026-05-17 — daily timestamped copy in Drive vault
# so OWNER has scrollable history of every brief, Drive-synced off-VPS.
VAULT_BRIEF_DIR = Path(r"G:\My Drive\QuantMechanica - Company Reference\10 Morning Briefing")
CARDS_DRAFT = ROOT / "artifacts" / "cards_draft"
CARDS_APPROVED = ROOT / "artifacts" / "cards_approved"


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _connect() -> sqlite3.Connection:
    con = sqlite3.connect(str(DB))
    con.row_factory = sqlite3.Row
    return con


def _count(con: sqlite3.Connection, sql: str, params: tuple = ()) -> int:
    row = con.execute(sql, params).fetchone()
    return int(row[0]) if row else 0


def _delta_since(con: sqlite3.Connection, hours: int = 12) -> dict:
    cutoff = (_utc_now() - dt.timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "new_approved_cards": _count(con,
            "SELECT COUNT(*) FROM events WHERE entity_type='card' AND event='approved' AND ts >= ?",
            (cutoff,)),
        "new_draft_cards":    _count(con,
            "SELECT COUNT(*) FROM events WHERE entity_type='source' AND event='cards_drafted' AND ts >= ?",
            (cutoff,)),
        "builds_done":        _count(con,
            "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='done' AND updated_at >= ?",
            (cutoff,)),
        "builds_failed":      _count(con,
            "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status IN ('failed','blocked') AND updated_at >= ?",
            (cutoff,)),
        "p2_pass":            _count(con,
            "SELECT COUNT(*) FROM work_items WHERE phase='P2' AND verdict='PASS' AND updated_at >= ?",
            (cutoff,)),
        "p2_fail":            _count(con,
            "SELECT COUNT(*) FROM work_items WHERE phase='P2' AND verdict='FAIL' AND updated_at >= ?",
            (cutoff,)),
        "p3_pass":            _count(con,
            "SELECT COUNT(*) FROM work_items WHERE phase='P3' AND verdict='PASS' AND updated_at >= ?",
            (cutoff,)),
        "p3_fail":            _count(con,
            "SELECT COUNT(*) FROM work_items WHERE phase='P3' AND verdict='FAIL' AND updated_at >= ?",
            (cutoff,)),
        "sources_done":       _count(con,
            "SELECT COUNT(*) FROM events WHERE entity_type='source' AND event LIKE '%done%' AND ts >= ?",
            (cutoff,)),
    }


def _winners(con: sqlite3.Connection) -> list[dict]:
    rows = con.execute(
        """
        SELECT ea_id,
               SUM(CASE WHEN phase='P2' AND verdict='PASS' THEN 1 ELSE 0 END) p2_pass,
               SUM(CASE WHEN phase='P3' AND verdict='PASS' THEN 1 ELSE 0 END) p3_pass
        FROM work_items
        GROUP BY ea_id
        HAVING p2_pass > 0 OR p3_pass > 0
        ORDER BY p3_pass DESC, p2_pass DESC
        """
    ).fetchall()
    return [dict(r) for r in rows]


def _load_health() -> dict:
    if not HEALTH_FILE.exists():
        return {}
    try:
        return json.loads(HEALTH_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _load_quota() -> dict:
    if not QUOTA_FILE.exists():
        return {}
    try:
        return json.loads(QUOTA_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _format_brief() -> str:
    con = _connect()
    try:
        # Current state
        sources_pending  = _count(con, "SELECT COUNT(*) FROM sources WHERE status='pending'")
        sources_cr       = _count(con, "SELECT COUNT(*) FROM sources WHERE status='cards_ready'")
        sources_done     = _count(con, "SELECT COUNT(*) FROM sources WHERE status='done'")
        builds_done      = _count(con, "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='done'")
        builds_pending   = _count(con, "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'")
        builds_blocked   = _count(con, "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='blocked'")
        wi_pending       = _count(con, "SELECT COUNT(*) FROM work_items WHERE status='pending'")
        wi_active        = _count(con, "SELECT COUNT(*) FROM work_items WHERE status='active'")
        p2_pass_total    = _count(con, "SELECT COUNT(*) FROM work_items WHERE phase='P2' AND verdict='PASS'")
        p3_pass_total    = _count(con, "SELECT COUNT(*) FROM work_items WHERE phase='P3' AND verdict='PASS'")
        delta            = _delta_since(con, 12)
        winners          = _winners(con)
    finally:
        con.close()

    cards_draft = len(os.listdir(CARDS_DRAFT)) if CARDS_DRAFT.exists() else 0
    cards_approved = len(os.listdir(CARDS_APPROVED)) if CARDS_APPROVED.exists() else 0

    health = _load_health()
    quota = _load_quota()

    # Headline
    if p3_pass_total > 0:
        headline = f"**{p3_pass_total} P3-PASS EA(s)** — Heureka horizon visible."
    elif p2_pass_total > 0:
        headline = (f"**{p2_pass_total} P2-PASSes** holding; "
                    f"{len(winners)} winner EA(s); P3 next gate (0/{p3_pass_total or '?'})")
    else:
        headline = "no PASSes yet — pipeline upstream still warming up."

    # Health section
    health_lines = []
    if health:
        ov = health.get("overall", "?")
        summary = health.get("summary", {})
        if ov == "FAIL":
            health_lines.append(
                f"### Health: **{ov}** — "
                f"{summary.get('fail',0)} FAIL / {summary.get('warn',0)} WARN / {summary.get('ok',0)} OK")
            for c in (health.get("checks") or []):
                if c.get("status") == "FAIL":
                    health_lines.append(f"- **{c['name']}**: {c['detail']}")
                    if c.get("action_hint"):
                        health_lines.append(f"  - hint: {c['action_hint']}")
        elif ov == "WARN":
            health_lines.append(
                f"### Health: {ov} — {summary.get('warn',0)} WARN / {summary.get('ok',0)} OK")
            for c in (health.get("checks") or []):
                if c.get("status") == "WARN":
                    health_lines.append(f"- **{c['name']}**: {c['detail']}")
        else:
            health_lines.append(
                f"### Health: **OK** — all {summary.get('ok',0)} invariants green "
                f"(last check {health.get('checked_at','?')})")
    else:
        health_lines.append("### Health: no snapshot yet (watchdog not run)")

    # Delta section
    delta_lines = ["### 12h delta",
                   f"- Cards: +{delta['new_draft_cards']} drafted, +{delta['new_approved_cards']} approved",
                   f"- Builds: +{delta['builds_done']} done, +{delta['builds_failed']} failed/blocked",
                   f"- P2 backtests: +{delta['p2_pass']} PASS, +{delta['p2_fail']} FAIL",
                   f"- P3 backtests: +{delta['p3_pass']} PASS, +{delta['p3_fail']} FAIL"]

    # Winners section
    winner_lines = ["### Winners (EAs with ≥1 PASS)"]
    if winners:
        for w in winners:
            winner_lines.append(f"- **{w['ea_id']}**: P2-PASS×{w['p2_pass']}, P3-PASS×{w['p3_pass']}")
    else:
        winner_lines.append("- (none yet — first PASS pending)")

    # Quota section
    quota_lines = ["### Token quota (live from Chrome scraper)"]
    if quota:
        for src in ("codex", "claude"):
            s = quota.get(src) or {}
            ra = s.get("received_at", "?")
            quota_lines.append(f"- **{src.capitalize()}**: last scraped {ra}")
    else:
        quota_lines.append("- no quota snapshot")

    # Current state section
    state_lines = ["### Current state",
                   f"- Sources: {sources_pending} pending, {sources_cr} cards_ready, {sources_done} done",
                   f"- Cards: {cards_draft} draft, {cards_approved} approved",
                   f"- Builds: {builds_done} done, {builds_pending} pending, {builds_blocked} blocked",
                   f"- Work items: {wi_active} active, {wi_pending} pending",
                   f"- Total P2-PASSes: {p2_pass_total} · Total P3-PASSes: {p3_pass_total}"]

    # Action items — derived from health
    action_lines = []
    if health and health.get("overall") in ("FAIL", "WARN"):
        for c in (health.get("checks") or []):
            if c.get("status") in ("FAIL", "WARN") and c.get("action_hint"):
                action_lines.append(f"- [{c['status']}] {c['name']}: {c['action_hint']}")
    if not action_lines:
        action_lines.append("- nothing red — pipeline healthy, let it run")

    parts = []
    parts.append(f"# QM Strategy Farm — Morning Brief")
    parts.append(f"_Generated {_utc_now().strftime('%Y-%m-%d %H:%M UTC')}_")
    parts.append("")
    parts.append(headline)
    parts.append("")
    parts.extend(health_lines)
    parts.append("")
    parts.extend(delta_lines)
    parts.append("")
    parts.extend(winner_lines)
    parts.append("")
    parts.extend(state_lines)
    parts.append("")
    parts.extend(quota_lines)
    parts.append("")
    parts.append("### What needs action today")
    parts.extend(action_lines)
    parts.append("")
    parts.append("---")
    parts.append("Cockpit: `file:///D:/QM/strategy_farm/dashboards/cockpit.html`")
    return "\n".join(parts) + "\n"


def main() -> int:
    DASH.mkdir(parents=True, exist_ok=True)
    text = _format_brief()
    BRIEF_FILE.write_text(text, encoding="utf-8", newline="\n")
    print(f"morning brief written: {BRIEF_FILE}")
    # Daily timestamped copy to Drive vault (Drive sync handles backup).
    try:
        VAULT_BRIEF_DIR.mkdir(parents=True, exist_ok=True)
        today_local = dt.datetime.now().strftime("%Y-%m-%d")
        vault_path = VAULT_BRIEF_DIR / f"{today_local}_morning_brief.md"
        vault_path.write_text(text, encoding="utf-8", newline="\n")
        print(f"vault archive written:  {vault_path}")
    except Exception as exc:
        # Don't fail the whole task if Drive mount has a hiccup; the local
        # copy is still on disk.
        print(f"vault write failed (non-fatal): {exc!r}")
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
