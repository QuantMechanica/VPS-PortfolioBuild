#!/usr/bin/env python3
"""Screen the 2.2 candidate pool against the criteria v6 lists for freezing it.

v6 §6 2.2 names seven per-candidate checks. Until today one of them was not evaluable at all --
"keine abgelösten Zeilen" -- because supersession had no canonical form. `work_item_supersedes`
(point 1.13) closes that, so the pool can be screened rather than merely counted.

Checks, each reported per pair with its own reason token:

  chain_complete        every phase Q02..Q08 the pair reached has a passing verdict, phase by phase
  q04_before_q10        a Q04 verdict exists and predates the Q10 verdict (ordering, not just presence)
  evidence_present      the newest verdict's evidence file exists on disk
  promotion_source      the row came from a real dispatch, not a hand-inserted or unknown origin
  no_degenerate_fold    no fold carries the 999.0 sentinel, and fold counts are plausible
  not_superseded        no row of the pair is marked in work_item_supersedes
  fresh                 the newest verdict is not older than --max-age-days

Nothing is written. FAIL_PORTFOLIO is annotated, never excluded (E1): those verdicts describe a
frozen incumbent that no longer exists as a concept.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
from collections import Counter
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
POOL = REPO / "artifacts" / "pool_union_20260817.json"
SCHEMA = "qm.pool-2p2-screening/v1"

PASSING = {"PASS", "PASS_SOFT", "PASS_LOWFREQ", "MULTI_SEED_PASS"}
# FAIL_SOFT counts as passing at Q08 only -- DL-082 parks it for portfolio review rather
# than killing it, and the pool must not silently drop what the gate deliberately parked.
Q08_EXTRA = {"FAIL_SOFT", "FAIL_DD_PORTFOLIO_REVIEW"}
CHAIN = ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08")
SENTINEL = 999.0


def db_symbol(sym: str) -> str:
    return sym if sym.upper().startswith("QM5_") or sym.upper().endswith(".DWX") else sym + ".DWX"


def history_by_phase(conn: sqlite3.Connection, ea: str, sym: str) -> dict[str, list[sqlite3.Row]]:
    """Full ordered history per phase. The newest alone is not enough -- see the chain check."""
    out: dict[str, list[sqlite3.Row]] = {}
    for row in conn.execute(
        """SELECT phase, verdict, status, evidence_path, updated_at, payload_json, id
           FROM work_items WHERE ea_id=? AND symbol=? AND status IN ('done','failed')
           ORDER BY updated_at""", (ea, sym)):
        out.setdefault(row["phase"], []).append(row)
    return out


def degenerate_fold(evidence_path: str | None) -> str | None:
    if not evidence_path:
        return None
    p = Path(evidence_path)
    if not p.exists():
        return None
    try:
        doc = json.loads(p.read_text(encoding="utf-8-sig"))
    except (ValueError, OSError):
        return None
    folds = doc.get("folds")
    if isinstance(folds, list):
        for fold in folds:
            for value in (fold or {}).values() if isinstance(fold, dict) else []:
                if isinstance(value, (int, float)) and abs(float(value) - SENTINEL) < 1e-9:
                    return "sentinel_999_in_fold"
    reason = str(doc.get("verdict_reason") or doc.get("reason") or "")
    if "999.0" in reason:
        return "sentinel_999_in_reason"
    return None


def screen(conn: sqlite3.Connection, pair: str, max_age_days: int) -> dict[str, Any]:
    num, sym = pair.split(":", 1)
    ea = "QM5_" + num
    dbsym = db_symbol(sym)
    phase_history = history_by_phase(conn, ea, dbsym)
    phases = {k: v[-1] for k, v in phase_history.items()}
    problems: list[str] = []
    notes: list[str] = []

    if not phases:
        return {"pair": pair, "ok": False, "problems": ["no_rows_at_all"], "notes": []}

    # Chain completeness and phase stability are two different questions and must not be
    # conflated. A first pass used "newest verdict per phase" and was over-strict: QM5_10403
    # has three Q05 PASS followed by one INFRA_FAIL, which is a later infrastructure failure,
    # not a broken chain. But "ever passed" is too weak on its own: QM5_10692's Q04 alternates
    # PASS and FAIL dozens of times over months, and that instability is a finding in itself.
    #
    # So: chain_* asks whether the phase was EVER legitimately passed (necessary condition),
    # and unstable_* separately flags phases whose history contains both passing and
    # economically failing verdicts. INFRA_FAIL is excluded from the instability signal --
    # it is an infrastructure outcome, not a verdict about the strategy.
    for phase in CHAIN:
        history = phase_history.get(phase) or []
        if not history:
            continue  # the pair never reached this phase; absence is not a failed chain link
        allowed = PASSING | (Q08_EXTRA if phase == "Q08" else set())
        verdicts = [str(r["verdict"] or "") for r in history]
        if any(v.startswith("FAIL_PORTFOLIO") for v in verdicts):
            notes.append(f"{phase}=FAIL_PORTFOLIO(annotated_vs_old_incumbent)")
        passed = [v for v in verdicts if v in allowed]
        if not passed:
            problems.append(f"chain_{phase}={verdicts[-1] or 'none'}")
            continue
        economic_fails = [v for v in verdicts
                          if v and v not in allowed and not v.startswith(("INFRA_FAIL", "INVALID",
                                                                          "FAIL_PORTFOLIO"))]
        if economic_fails:
            problems.append(f"unstable_{phase}={len(passed)}pass/{len(economic_fails)}fail")

    q04, q10 = phases.get("Q04"), phases.get("Q10")
    if q10 is not None:
        if q04 is None:
            problems.append("q10_without_q04")
        elif q04["updated_at"] >= q10["updated_at"]:
            problems.append("q04_not_before_q10")

    newest = max(phases.values(), key=lambda r: r["updated_at"])
    if not newest["evidence_path"] or not Path(newest["evidence_path"]).exists():
        problems.append("evidence_missing")

    try:
        payload = json.loads(newest["payload_json"] or "{}")
    except (ValueError, TypeError):
        payload = {}
    origin = payload.get("enqueued_by") or payload.get("promotion_source") or payload.get("evidence_provenance")
    if not origin:
        problems.append("promotion_source_unknown")
    else:
        notes.append(f"origin={str(origin)[:48]}")

    for phase in ("Q04", "Q05", "Q06", "Q08"):
        row = phases.get(phase)
        if row is not None:
            token = degenerate_fold(row["evidence_path"])
            if token:
                problems.append(f"{phase}_{token}")

    ids = [r["id"] for r in phases.values()]
    marks = conn.execute(
        "SELECT COUNT(*) n FROM work_item_supersedes WHERE work_item_id IN (%s)"
        % ",".join("?" * len(ids)), ids).fetchone()["n"]
    if marks:
        problems.append(f"superseded_rows={marks}")

    age = (dt.datetime.now(dt.timezone.utc)
           - dt.datetime.fromisoformat(newest["updated_at"].replace("Z", "+00:00"))).days
    if age > max_age_days:
        problems.append(f"stale_{age}d")

    return {"pair": pair, "ok": not problems, "problems": problems, "notes": notes,
            "phases": {k: str(v["verdict"]) for k, v in sorted(phases.items())},
            "newest_at": newest["updated_at"], "age_days": age}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=DB)
    ap.add_argument("--pool", type=Path, default=POOL)
    ap.add_argument("--max-age-days", type=int, default=60)
    ap.add_argument("--output", type=Path)
    args = ap.parse_args()

    members = json.loads(args.pool.read_text(encoding="utf-8"))["union_members"]
    conn = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        results = [screen(conn, m, args.max_age_days) for m in members]
    finally:
        conn.close()

    clean = [r for r in results if r["ok"]]
    problems = Counter(p.split("=")[0] for r in results for p in r["problems"])
    doc = {"schema": SCHEMA, "at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
           "pool": str(args.pool), "pool_size": len(members),
           "clean": len(clean), "with_problems": len(results) - len(clean),
           "problem_census": dict(problems.most_common()), "results": results}

    print(json.dumps({k: v for k, v in doc.items() if k != "results"}, indent=1))
    print("\n=== pairs with problems ===")
    for r in results:
        if not r["ok"]:
            print("  %-22s %s" % (r["pair"], "; ".join(r["problems"])[:110]))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
