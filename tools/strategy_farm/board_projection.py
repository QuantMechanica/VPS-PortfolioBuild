"""Action-guiding board projection of ``agent_tasks`` (M15).

Read-only projection of the ``agent_tasks`` state machine into the five
operator-facing classes the CEO audit (finding M15, task
``8db1d722-ee86-48a0-8271-fb197eb39ab4``) asks for:

    actionable / waiting / parked / superseded / complete

plus a per-lane split (claude, codex, agy/gemini, owner, unassigned), the
single next action for every actionable row, and a net-KPI strip whose six
values come from the M07 cash-ledger and M01 release-status outputs — and,
until those land, are rendered ``UNKNOWN`` (never zero).

Design discipline (matches ``heartbeat_snapshot.py`` / ``render_cockpit_v2.py``):

  * strictly read-only — opens the farm DB with ``mode=ro``; never writes to it;
  * makes zero gate decisions and surfaces no storage P-keys — it reports the
    lifecycle *state* of a task, not a Qxx gate phase;
  * deterministic — every list is sorted by a total order (``-priority``,
    ``-age_days``, ``id``) so two runs over the same snapshot are byte-identical;
  * additive — emits a self-contained JSON contract (``qm.board_projection.v1``)
    that a renderer binds verbatim; unknown fields are ``UNKNOWN``, never 0.

CLI::

    python tools/strategy_farm/board_projection.py            # build + write JSON
    python tools/strategy_farm/board_projection.py --dry-run  # print JSON, no write
    python tools/strategy_farm/board_projection.py --markdown # compact human board
    python tools/strategy_farm/board_projection.py --db-path <db> --out <path>
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA = "qm.board_projection.v1"

# Live runtime paths (overridable on the CLI; tests always pass their own).
DB_PATH = Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")
OUT_PATH = Path(r"D:/QM/reports/state/board_projection.json")

# ---------------------------------------------------------------------------
# lane vocabulary
# ---------------------------------------------------------------------------
LANES = ["claude", "codex", "agy/gemini", "owner", "unassigned"]
CLASSES = ["actionable", "waiting", "parked", "superseded", "complete"]
WAITING_REASONS = [
    "awaiting_owner_receipt",
    "awaiting_review",
    "awaiting_dependency",
    "awaiting_pipeline",
    "awaiting_codex_lane",
    "decision-bound",
]

# The six net KPIs the audit wants "in front". Their values are produced by
# other measures (M07 cash ledger, M01 release status); until those outputs
# exist on disk this projection reports them UNKNOWN — never zero.
KPI_SOURCES: dict[str, str] = {
    "received_payouts": "M07 cash_ledger_v1 (D:/QM/reports/state/cash_ledger_v1.json)",
    "monthly_opex": "M07 cash_ledger_v1 (D:/QM/reports/state/cash_ledger_v1.json)",
    "darwin_status": "M07 provider status / M01 release status",
    "decidable_release_candidates": "M01 release_status projection",
    "days_to_next_decisive_test": "M13 economic-test contract / M01 release status",
    "open_release_blocking_defects": "M01 release_status projection / M05 evidence adjudication",
}


# ---------------------------------------------------------------------------
# db access (read-only)
# ---------------------------------------------------------------------------
def open_ro(db_path: str | Path) -> sqlite3.Connection:
    """Open ``db_path`` strictly read-only."""
    uri = f"file:{Path(db_path).as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    return conn


def fetch_rows(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    """Load every ``agent_tasks`` row, parsing ``payload_json`` defensively."""
    rows: list[dict[str, Any]] = []
    cur = conn.execute(
        "SELECT id, task_type, state, priority, assigned_agent, "
        "payload_json, created_at, updated_at FROM agent_tasks"
    )
    for r in cur:
        try:
            payload = json.loads(r["payload_json"] or "{}")
        except (ValueError, TypeError):
            payload = {}
        if not isinstance(payload, dict):
            payload = {}
        rows.append(
            {
                "id": r["id"],
                "task_type": r["task_type"],
                "state": (r["state"] or "").upper(),
                "priority": r["priority"] if r["priority"] is not None else 0,
                "assigned_agent": r["assigned_agent"],
                "payload": payload,
                "created_at": r["created_at"],
                "updated_at": r["updated_at"],
            }
        )
    return rows


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def _parse_ts(value: Any) -> datetime | None:
    """Parse an ISO timestamp; tolerate space/'T' separators and naive strings."""
    if not value:
        return None
    s = str(value).strip().replace(" ", "T", 1)
    try:
        dtv = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dtv.tzinfo is None:
        dtv = dtv.replace(tzinfo=timezone.utc)
    return dtv


def age_days(row: dict[str, Any], now: datetime) -> float:
    """Age of a task in days from ``created_at`` to ``now`` (>= 0.0)."""
    created = _parse_ts(row.get("created_at"))
    if created is None:
        return 0.0
    delta = now - created
    return round(max(delta.total_seconds(), 0.0) / 86400.0, 2)


def lane_of(row: dict[str, Any]) -> str:
    """Normalise a row's assignee to a board lane."""
    agent = (row.get("assigned_agent") or "").strip().lower()
    if agent.startswith("codex"):
        return "codex"
    if agent == "claude":
        return "claude"
    if agent in ("gemini", "agy"):
        return "agy/gemini"
    if agent == "owner":
        return "owner"
    # Unassigned rows that structurally require the human video lane are OWNER's.
    hold = row["payload"].get("router_human_lane_hold")
    if isinstance(hold, dict) and (hold.get("lane") or "").lower() == "owner":
        return "owner"
    return "unassigned"


def _human_lane_hold(payload: dict[str, Any]) -> bool:
    hold = payload.get("router_human_lane_hold")
    return isinstance(hold, dict) and bool(hold)


def _decision_pending(payload: dict[str, Any]) -> bool:
    """True when the task is blocked on an OWNER decision that is not yet made.

    An ``owner_decision`` *dict* without a resolved ``choice`` is a still-open
    question. A string ``owner_decision`` (a decision id) or ``decision_bound:
    true`` means the decision already exists and the task *implements* it —
    that is execution work, not a wait.
    """
    od = payload.get("owner_decision")
    if isinstance(od, dict):
        choice = od.get("choice")
        return not (isinstance(choice, str) and choice.strip())
    return bool(payload.get("awaiting_owner_decision"))


def _park_reason(payload: dict[str, Any]) -> str:
    dep = payload.get("orchestrator_deprioritised")
    if isinstance(dep, dict) and dep.get("reason"):
        return f"deprioritised: {dep['reason']}"
    if isinstance(dep, dict):
        return "deprioritised"
    br = payload.get("blocked_reason")
    if isinstance(br, str) and br.strip():
        return br.strip()
    return "UNKNOWN"


def next_action_for(row: dict[str, Any]) -> str:
    """The single next action for an actionable row, keyed by lifecycle state."""
    state = row["state"]
    lane = lane_of(row)
    if state in ("TODO", "BACKLOG"):
        if lane == "unassigned":
            return "Route to a lane and execute"
        return f"Execute (lane: {lane})"
    if state == "IN_PROGRESS":
        return "In flight — verify progress; re-route if stalled"
    if state == "RECYCLE":
        return "Rework against the review verdict and resubmit for review"
    if state == "OPS_FIX_REQUIRED":
        return "Apply the ops fix, then re-run the gate/build"
    if state == "FAILED":
        return "Re-triage: diagnose the failure, then re-enqueue (append-only) or retire"
    return "Review and dispatch"


# ---------------------------------------------------------------------------
# classification
# ---------------------------------------------------------------------------
COMPLETE_STATES = {"PASSED", "APPROVED"}
LIVE_STATES = {
    "TODO",
    "BACKLOG",
    "IN_PROGRESS",
    "RECYCLE",
    "OPS_FIX_REQUIRED",
    "FAILED",
}


def compute_superseded_ids(rows: list[dict[str, Any]]) -> set[str]:
    """Ids referenced by another row's ``payload.supersedes`` are superseded."""
    out: set[str] = set()
    for row in rows:
        sup = row["payload"].get("supersedes")
        if isinstance(sup, str) and sup.strip():
            out.add(sup.strip())
        elif isinstance(sup, list):
            out.update(s.strip() for s in sup if isinstance(s, str) and s.strip())
    return out


def classify(
    row: dict[str, Any], superseded_ids: set[str], now: datetime
) -> tuple[str, str, str]:
    """Return ``(cls, reason, next_action)`` for a single row (first match wins).

    ``reason`` is empty for actionable/complete; ``next_action`` is set only for
    actionable rows. The precedence is deliberate: a replaced row is superseded
    before anything else; a finished row is complete; then the various waiting
    and parked gates; everything else that is still live is actionable.
    """
    state = row["state"]
    payload = row["payload"]

    # 1. superseded — a newer task explicitly replaced this one.
    if row["id"] in superseded_ids:
        return "superseded", "superseded_by_successor", ""

    # 2. complete — terminal-success / handed off, no agent action pending.
    if state == "PASSED":
        return "complete", "passed", ""
    if state == "APPROVED":
        return "complete", "approved", ""

    # 3. BLOCKED — resolve to a wait (owner/decision) or an explicit park.
    if state == "BLOCKED":
        if _human_lane_hold(payload):
            return "waiting", "awaiting_owner_receipt", ""
        if _decision_pending(payload):
            return "waiting", "decision-bound", ""
        return "parked", _park_reason(payload), ""

    # 4. deterministic automated / review waits keyed by state.
    if state == "PIPELINE":
        return "waiting", "awaiting_pipeline", ""
    if state == "REVIEW":
        return "waiting", "awaiting_review", ""

    # 5. live pre-execution states: check external gates before actionable.
    if state in LIVE_STATES:
        if _human_lane_hold(payload):
            return "waiting", "awaiting_owner_receipt", ""
        if _decision_pending(payload):
            return "waiting", "decision-bound", ""
        if payload.get("depends_on"):
            return "waiting", "awaiting_dependency", ""
        if isinstance(payload.get("orchestrator_deprioritised"), dict):
            return "parked", _park_reason(payload), ""
        if state in ("TODO", "BACKLOG") and lane_of(row) == "codex":
            # Commissioned to Codex and queued — waiting on the Codex lane.
            return "waiting", "awaiting_codex_lane", ""
        return "actionable", "", next_action_for(row)

    # 6. unknown state — never silently drop; surface as parked/UNKNOWN.
    return "parked", f"unknown_state:{state or 'UNKNOWN'}", ""


# ---------------------------------------------------------------------------
# projection
# ---------------------------------------------------------------------------
def _row_view(
    row: dict[str, Any], cls: str, reason: str, action: str, now: datetime
) -> dict[str, Any]:
    title = row["payload"].get("title")
    if not (isinstance(title, str) and title.strip()):
        title = f"[{row['task_type']}] {row['id'][:8]}"
    title = title.strip()
    if len(title) > 160:
        title = title[:157] + "..."
    view = {
        "id": row["id"],
        "lane": lane_of(row),
        "task_type": row["task_type"],
        "state": row["state"],
        "priority": row["priority"],
        "age_days": age_days(row, now),
        "title": title,
        "class": cls,
    }
    if cls == "actionable":
        view["next_action"] = action
    else:
        view["reason"] = reason
    return view


def _sort_key(view: dict[str, Any]):
    return (-int(view["priority"]), -float(view["age_days"]), view["id"])


def _empty_lane_counts() -> dict[str, int]:
    return {c: 0 for c in CLASSES}


def build_projection(
    rows: list[dict[str, Any]], now: datetime | None = None
) -> dict[str, Any]:
    """Build the ``qm.board_projection.v1`` contract from raw task rows."""
    if now is None:
        now = datetime.now(timezone.utc)
    superseded_ids = compute_superseded_ids(rows)

    counts = {c: 0 for c in CLASSES}
    waiting_reasons = {r: 0 for r in WAITING_REASONS}
    by_lane = {lane: _empty_lane_counts() for lane in LANES}
    by_state: dict[str, int] = {}
    # Full row detail for the needs-attention classes; complete is count-only.
    detail: dict[str, list[dict[str, Any]]] = {
        "actionable": [],
        "waiting": [],
        "parked": [],
        "superseded": [],
    }

    for row in rows:
        cls, reason, action = classify(row, superseded_ids, now)
        lane = lane_of(row)
        counts[cls] += 1
        by_lane.setdefault(lane, _empty_lane_counts())[cls] += 1
        by_state[row["state"]] = by_state.get(row["state"], 0) + 1
        if cls == "waiting" and reason in waiting_reasons:
            waiting_reasons[reason] += 1
        if cls in detail:
            detail[cls].append(_row_view(row, cls, reason, action, now))

    for lst in detail.values():
        lst.sort(key=_sort_key)

    company_kpis = {
        name: {"value": "UNKNOWN", "source": src, "as_of": None}
        for name, src in KPI_SOURCES.items()
    }

    return {
        "schema": SCHEMA,
        "generated_at": now.astimezone(timezone.utc).isoformat(),
        "task_projection": {
            "total_tasks": len(rows),
            "counts": counts,
            "waiting_reasons": waiting_reasons,
            "by_lane": by_lane,
            "rows": detail,
        },
        "company_kpis": company_kpis,
        "diagnostics": {
            "total_tasks": len(rows),
            "by_state": dict(sorted(by_state.items())),
            "by_lane": {
                lane: sum(by_lane[lane].values()) for lane in by_lane
            },
            "tester_utilisation": {
                "value": "UNKNOWN",
                "source": "farmctl mt5-slots / heartbeat_state.json (not joined here)",
            },
        },
    }


# ---------------------------------------------------------------------------
# markdown rendering (compact human board)
# ---------------------------------------------------------------------------
def _kpi_line(name: str, kpi: dict[str, Any]) -> str:
    label = name.replace("_", " ")
    return f"- {label}: **{kpi['value']}**  _(from {kpi['source']})_"


def render_markdown(projection: dict[str, Any], top: int = 10) -> str:
    tp = projection["task_projection"]
    counts = tp["counts"]
    lines: list[str] = []
    lines.append("# Action-guiding board")
    lines.append("")
    lines.append(f"_generated {projection['generated_at']} · schema {projection['schema']}_")
    lines.append("")
    lines.append("## Net KPIs (in front)")
    for name in KPI_SOURCES:
        lines.append(_kpi_line(name, projection["company_kpis"][name]))
    lines.append("")
    lines.append("## Task projection")
    lines.append(
        "| class | count |  | lane | actionable | waiting | parked | superseded | complete |"
    )
    lines.append("|---|---:|---|---|---:|---:|---:|---:|---:|")
    lane_rows = list(projection["task_projection"]["by_lane"].items())
    for i, cls in enumerate(CLASSES):
        if i < len(lane_rows):
            lane, lc = lane_rows[i]
            lane_cells = (
                f"{lane} | {lc['actionable']} | {lc['waiting']} | "
                f"{lc['parked']} | {lc['superseded']} | {lc['complete']}"
            )
        else:
            lane_cells = " |  |  |  |  | "
        lines.append(f"| {cls} | {counts[cls]} |  | {lane_cells} |")
    lines.append("")
    wr = tp["waiting_reasons"]
    lines.append("**waiting reasons:** " + ", ".join(f"{k}={v}" for k, v in wr.items()))
    lines.append("")
    lines.append(f"## Top {top} actionable")
    lines.append("| pri | age(d) | lane | title | next action |")
    lines.append("|---:|---:|---|---|---|")
    for v in tp["rows"]["actionable"][:top]:
        lines.append(
            f"| {v['priority']} | {v['age_days']:.0f} | {v['lane']} | "
            f"{v['title']} | {v['next_action']} |"
        )
    lines.append("")
    lines.append(
        f"_diagnostics: {projection['diagnostics']['total_tasks']} tasks · "
        f"tester utilisation {projection['diagnostics']['tester_utilisation']['value']}_"
    )
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# io + CLI
# ---------------------------------------------------------------------------
def _atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=1, ensure_ascii=False, sort_keys=False)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def build_from_db(db_path: str | Path, now: datetime | None = None) -> dict[str, Any]:
    conn = open_ro(db_path)
    try:
        rows = fetch_rows(conn)
    finally:
        conn.close()
    return build_projection(rows, now=now)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db-path", type=Path, default=DB_PATH,
                        help="farm_state.sqlite (opened read-only)")
    parser.add_argument("--out", type=Path, default=OUT_PATH,
                        help="output JSON path (production default under D:/QM/reports/state)")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the JSON contract to stdout; write nothing")
    parser.add_argument("--markdown", action="store_true",
                        help="render the compact human board to stdout")
    args = parser.parse_args(argv)

    projection = build_from_db(args.db_path)

    if args.markdown:
        sys.stdout.write(render_markdown(projection))
        return 0
    if args.dry_run:
        sys.stdout.write(json.dumps(projection, indent=1, ensure_ascii=False) + "\n")
        return 0

    _atomic_write_json(args.out, projection)
    counts = projection["task_projection"]["counts"]
    sys.stdout.write(
        f"wrote {args.out} — " + ", ".join(f"{k}={v}" for k, v in counts.items()) + "\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
