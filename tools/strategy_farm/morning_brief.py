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


def _utc_now_iso() -> str:
    return _utc_now().strftime("%Y-%m-%dT%H:%M:%SZ")


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


def _trend_series(con: sqlite3.Connection, days_back: int = 7) -> dict:
    """Return last-N-day series for the 4 trend metrics shown in cockpit."""
    out: dict[str, list[int]] = {
        "approved": [], "p2_pass": [], "p3_pass": [], "blocked": [],
    }
    today_local = dt.date.today()
    day_list = [(today_local - dt.timedelta(days=i)).isoformat()
                for i in range(days_back - 1, -1, -1)]
    rows = list(con.execute(
        "SELECT DATE(ts) d, event, COUNT(*) c FROM events "
        "WHERE ts >= date('now', ?) GROUP BY d, event",
        (f"-{days_back} days",),
    ))
    by_day: dict[str, dict[str, int]] = {}
    for r in rows:
        by_day.setdefault(r["d"], {})[r["event"]] = r["c"]
    pp = list(con.execute(
        "SELECT DATE(updated_at) d, COUNT(*) c FROM work_items "
        "WHERE phase='P2' AND status='done' AND verdict='PASS' "
        "AND updated_at >= date('now', ?) GROUP BY d",
        (f"-{days_back} days",),
    ))
    for r in pp:
        by_day.setdefault(r["d"], {})["__p2_pass"] = r["c"]
    p3 = list(con.execute(
        "SELECT DATE(updated_at) d, COUNT(*) c FROM work_items "
        "WHERE phase='P3' AND status='done' AND verdict='PASS' "
        "AND updated_at >= date('now', ?) GROUP BY d",
        (f"-{days_back} days",),
    ))
    for r in p3:
        by_day.setdefault(r["d"], {})["__p3_pass"] = r["c"]
    for d in day_list:
        dd = by_day.get(d) or {}
        out["approved"].append(int(dd.get("approved", 0)))
        out["p2_pass"].append(int(dd.get("__p2_pass", 0)))
        out["p3_pass"].append(int(dd.get("__p3_pass", 0)))
        out["blocked"].append(int(dd.get("build_blocked_by_codex_review", 0)))
    out["_days"] = day_list  # type: ignore[assignment]
    return out


def _ascii_bar(values: list[int], width: int = 8) -> str:
    """Tiny ASCII histogram using Unicode block characters. ▁▂▃▄▅▆▇█."""
    if not values:
        return ""
    max_v = max(values) if values else 0
    if max_v == 0:
        return "─" * len(values)
    blocks = "▁▂▃▄▅▆▇█"
    out = []
    for v in values:
        idx = int(round((v / max_v) * (len(blocks) - 1)))
        out.append(blocks[idx] if v > 0 else "·")
    return "".join(out)


def _format_brief() -> str:
    con = _connect()
    try:
        sources_pending  = _count(con, "SELECT COUNT(*) FROM sources WHERE status='pending'")
        sources_cr       = _count(con, "SELECT COUNT(*) FROM sources WHERE status='cards_ready'")
        sources_done     = _count(con, "SELECT COUNT(*) FROM sources WHERE status='done'")
        builds_done      = _count(con, "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='done'")
        builds_pending   = _count(con, "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'")
        builds_blocked   = _count(con, "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='blocked'")
        wi_pending       = _count(con, "SELECT COUNT(*) FROM work_items WHERE status='pending'")
        wi_active        = _count(con, "SELECT COUNT(*) FROM work_items WHERE status='active'")
        p2_pass_total    = _count(con, "SELECT COUNT(*) FROM work_items WHERE phase='P2' AND verdict='PASS'")
        p2_fail_total    = _count(con, "SELECT COUNT(*) FROM work_items WHERE phase='P2' AND verdict='FAIL'")
        p3_pass_total    = _count(con, "SELECT COUNT(*) FROM work_items WHERE phase='P3' AND verdict='PASS'")
        p3_fail_total    = _count(con, "SELECT COUNT(*) FROM work_items WHERE phase='P3' AND verdict='FAIL'")
        delta            = _delta_since(con, 12)
        winners          = _winners(con)
        trend            = _trend_series(con, days_back=7)
    finally:
        con.close()

    cards_draft = len(os.listdir(CARDS_DRAFT)) if CARDS_DRAFT.exists() else 0
    cards_approved = len(os.listdir(CARDS_APPROVED)) if CARDS_APPROVED.exists() else 0
    health = _load_health()
    quota = _load_quota()

    p2_pass_rate = (100.0 * p2_pass_total / max(1, p2_pass_total + p2_fail_total))
    p3_pass_rate = (100.0 * p3_pass_total / max(1, p3_pass_total + p3_fail_total))
    today_h = dt.datetime.now().strftime("%A · %d %B %Y")
    today_iso = dt.datetime.now().strftime("%Y-%m-%d")

    # ── Headline tier ────────────────────────────────────────────
    if p3_pass_total > 0:
        status_word = "HEUREKA HORIZON"
        headline_body = (
            f"**{p3_pass_total} EA(s) made it through P3** — "
            f"P4 walk-forward OOS is the next gate. "
            f"Live-deployment within reach if any survives the OOS window."
        )
    elif p2_pass_total >= 10:
        status_word = "MOMENTUM BUILDING"
        headline_body = (
            f"**{p2_pass_total} P2-PASSes** across **{len(winners)} winner EA(s)**. "
            f"P3 gate still 0/0 — synthetic variants + ablations are the engine "
            f"to push something over the line."
        )
    elif p2_pass_total > 0:
        status_word = "EARLY SIGNAL"
        headline_body = (
            f"**{p2_pass_total} P2-PASSes** from {len(winners)} EA(s). "
            f"Need more depth before any candidate reaches P3."
        )
    else:
        status_word = "WARMING UP"
        headline_body = (
            "No PASSes yet — research + build pipeline is filling the funnel. "
            "First gate (P2) won't fire until we have testable EAs."
        )

    # ── Health status word ───────────────────────────────────────
    health_word = "?"
    health_color_label = "?"
    if health:
        ov = health.get("overall", "?")
        health_word = {"OK": "ALL GREEN", "WARN": "WATCH", "FAIL": "ATTENTION"}.get(ov, ov)
        health_color_label = ov

    # ── 12h delta table ──────────────────────────────────────────
    delta_table = [
        "| metric | last 12h |",
        "| --- | ---: |",
        f"| cards drafted | +{delta['new_draft_cards']} |",
        f"| cards approved | +{delta['new_approved_cards']} |",
        f"| builds done | +{delta['builds_done']} |",
        f"| builds failed/blocked | +{delta['builds_failed']} |",
        f"| P2 PASS / FAIL | +{delta['p2_pass']} / +{delta['p2_fail']} |",
        f"| P3 PASS / FAIL | +{delta['p3_pass']} / +{delta['p3_fail']} |",
    ]

    # ── Funnel table ─────────────────────────────────────────────
    funnel_table = [
        "| stage | active | pending | done |",
        "| --- | ---: | ---: | ---: |",
        f"| Sources | — | {sources_pending} | {sources_done} |",
        f"| Cards (draft → approved) | {cards_draft} | — | {cards_approved} |",
        f"| Builds | — | {builds_pending} | {builds_done} |",
        f"| Backtest work_items | {wi_active} | {wi_pending} | {p2_pass_total + p2_fail_total + p3_pass_total + p3_fail_total} |",
    ]

    # ── PASS rates ───────────────────────────────────────────────
    pass_table = [
        "| phase | PASS | FAIL | PASS-rate |",
        "| --- | ---: | ---: | ---: |",
        f"| P2 (in-sample) | **{p2_pass_total}** | {p2_fail_total} | {p2_pass_rate:.0f}% |",
        f"| P3 (param sweep) | **{p3_pass_total}** | {p3_fail_total} | {p3_pass_rate:.0f}% |",
    ]

    # ── 7-day mini histograms ────────────────────────────────────
    trend_table = [
        "```",
        f"  Cards approved   {_ascii_bar(trend['approved'])}   ({sum(trend['approved'])})",
        f"  P2 PASS          {_ascii_bar(trend['p2_pass'])}   ({sum(trend['p2_pass'])})",
        f"  P3 PASS          {_ascii_bar(trend['p3_pass'])}   ({sum(trend['p3_pass'])})",
        f"  Codex pre-blocks {_ascii_bar(trend['blocked'])}   ({sum(trend['blocked'])})",
        "  " + " " * 17 + "←7d──────today",
        "```",
    ]

    # ── Winners ──────────────────────────────────────────────────
    if winners:
        winner_table = [
            "| EA | P2-PASS | P3-PASS | status |",
            "| --- | ---: | ---: | --- |",
        ]
        for w in winners:
            if w["p3_pass"] > 0:
                stat = "**P3 cleared — P3.5 next**"
            elif w["p2_pass"] >= 5:
                stat = "**strong edge — synth burst eligible**"
            elif w["p2_pass"] >= 3:
                stat = "candidate"
            else:
                stat = "early"
            winner_table.append(f"| **{w['ea_id']}** | {w['p2_pass']} | {w['p3_pass']} | {stat} |")
    else:
        winner_table = ["_no winners yet — first P2-PASS will appear here._"]

    # ── Health detail ────────────────────────────────────────────
    health_detail = []
    if health:
        fails = [c for c in (health.get("checks") or []) if c.get("status") == "FAIL"]
        warns = [c for c in (health.get("checks") or []) if c.get("status") == "WARN"]
        if fails:
            health_detail.append("**Red invariants:**")
            for c in fails:
                health_detail.append(f"- `{c['name']}` — {c['detail']}")
                if c.get("action_hint"):
                    health_detail.append(f"  > {c['action_hint']}")
        if warns:
            health_detail.append("")
            health_detail.append("**Yellow invariants:**")
            for c in warns:
                health_detail.append(f"- `{c['name']}` — {c['detail']}")
        if not fails and not warns:
            health_detail.append("_All 10 invariants green._")
    else:
        health_detail.append("_Watchdog has not run yet._")

    # ── Quota ────────────────────────────────────────────────────
    quota_lines = []
    if quota:
        for src in ("codex", "claude"):
            s = quota.get(src) or {}
            ra = s.get("received_at")
            age_str = "?"
            if ra:
                try:
                    t = dt.datetime.fromisoformat(ra.replace("Z", "+00:00"))
                    delta_sec = (_utc_now() - t).total_seconds()
                    age_str = (f"{int(delta_sec)}s ago" if delta_sec < 90
                               else f"{int(delta_sec / 60)}m ago")
                except Exception:
                    age_str = ra
            quota_lines.append(f"- **{src.capitalize()}** scraper last reported {age_str}")
    else:
        quota_lines.append("_No quota snapshot — Tampermonkey tabs likely closed._")

    # ── Action items ─────────────────────────────────────────────
    action_lines = []
    if health and health.get("overall") in ("FAIL", "WARN"):
        for c in (health.get("checks") or []):
            if c.get("status") in ("FAIL", "WARN") and c.get("action_hint"):
                tag = c["status"]
                action_lines.append(f"- **[{tag}]** `{c['name']}` → {c['action_hint']}")
    if not action_lines:
        action_lines.append("_Nothing red. Pipeline can keep running unattended._")

    # ── Assemble ─────────────────────────────────────────────────
    parts = [
        f"# QuantMechanica · Morning Brief",
        f"### {today_h}",
        "",
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"## ▶ {status_word}",
        "",
        headline_body,
        "",
        f"**Pipeline health: {health_word}**" + (
            f" · {len([c for c in (health.get('checks') or []) if c.get('status') == 'FAIL'])} red · "
            f"{len([c for c in (health.get('checks') or []) if c.get('status') == 'WARN'])} yellow · "
            f"{len([c for c in (health.get('checks') or []) if c.get('status') == 'OK'])} green"
            if health else ""
        ),
        "",
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "",
        "## Funnel (current)",
        "",
        *funnel_table,
        "",
        "## PASS rates",
        "",
        *pass_table,
        "",
        "## Winners",
        "",
        *winner_table,
        "",
        "## Last 12h",
        "",
        *delta_table,
        "",
        "## 7-day trend",
        "",
        *trend_table,
        "",
        "## Pipeline health detail",
        "",
        *health_detail,
        "",
        "## Token quota",
        "",
        *quota_lines,
        "",
        "## What needs action today",
        "",
        *action_lines,
        "",
        f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "",
        "**Quick links**",
        "",
        f"- Cockpit: `file:///D:/QM/strategy_farm/dashboards/cockpit.html`",
        f"- Vault archive: `G:/My Drive/QuantMechanica - Company Reference/10 Morning Briefing/`",
        "",
        f"_Generated {_utc_now().strftime('%Y-%m-%d %H:%M UTC')} · "
        f"checked watchdog state at {health.get('checked_at', '?') if health else '?'}_",
    ]
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
