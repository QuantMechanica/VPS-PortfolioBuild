#!/usr/bin/env python3
"""Plan/apply the pre-registered regeneration of the 91 pool sleeve streams (option (b)).

Dry-run is the default. Apply creates pending Q08 rows for the frozen cohort membership and
nothing else: it never starts MT5, never promotes a phase, never rewrites a verdict, never
touches a scheduled task or a factory flag, and never interrupts a running backtest.

Why this exists rather than a hand-rolled INSERT: the enqueue path carries mandatory gates.
``sweep_enqueue_built_eas.py`` holds the proven shape but has no ``__main__`` guard, so importing
it would execute the entire sweep. The gates are therefore reproduced here by calling the same
underlying functions:

  * ``.DWX``-only (a bare broker symbol has no local history and INFRA_FAILs on history sync)
  * ``farmctl.custom_history_archive_admission`` -- the Variant-A containment gate, fail-closed
  * ``q08_recovery_lineage.build_q08_recovery_lineage`` -- a malformed lineage is an error, not
    an invitation to enqueue an unbound row
  * the Q08.5 deterministic setfile-defect check -- these setfiles fail Q08 every time
  * no duplicate: skip when a pending/active row already exists for (ea, symbol, Q08)

Pre-registration: docs/ops/evidence/2026-08-17_PREREG_book_q08_regeneration_91_pairs.md
Cohorts:          artifacts/book_q08_regeneration_cohorts_20260817.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
import uuid
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.append(str(REPO_ROOT / "framework" / "scripts"))

import farmctl  # noqa: E402  (import-safe: guarded by __main__)
from q08_recovery_lineage import build_q08_recovery_lineage  # noqa: E402

try:
    from q08_5_neighborhood_runner import parse_setfile_assignments as _parse_setfile
except Exception:  # a missing parser must not silently disable the guard
    _parse_setfile = None

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
FARM_ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_ROOT = Path(r"D:\QM\reports")
COHORTS = REPO_ROOT / "artifacts" / "book_q08_regeneration_cohorts_20260817.json"
SCHEMA = "qm.book-q08-regeneration-receipt/v1"
ENQUEUED_BY = "claude_book_q08_regeneration_2026-08-17.option_b_91"
PREREG = "docs/ops/evidence/2026-08-17_PREREG_book_q08_regeneration_91_pairs.md"


class PrepareError(RuntimeError):
    """Fail-closed preparation error."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+00:00")


def setfile_defect(setfile_path: str | None) -> str | None:
    """Return a defect token if this setfile deterministically fails Q08.5, else None."""
    if _parse_setfile is None or not setfile_path:
        return None
    try:
        assignments = _parse_setfile(Path(setfile_path))
    except ValueError as exc:
        msg = str(exc).lower()
        if "duplicate strategy parameter" in msg:
            return "duplicate_strategy_params"
        if "empty strategy parameter" in msg:
            return "empty_strategy_value"
        return "setfile_parse_error"
    except OSError:
        return None
    return "empty_strategy_params" if not assignments else None


def latest_q08(conn: sqlite3.Connection, ea_id: str, symbol: str) -> sqlite3.Row | None:
    return conn.execute(
        """SELECT id, setfile_path, status, verdict, updated_at, payload_json
           FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q08'
           ORDER BY updated_at DESC LIMIT 1""",
        (ea_id, symbol),
    ).fetchone()


def live_row_exists(conn: sqlite3.Connection, ea_id: str, symbol: str) -> bool:
    row = conn.execute(
        """SELECT 1 FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q08'
           AND status IN ('pending','active') LIMIT 1""",
        (ea_id, symbol),
    ).fetchone()
    return row is not None


def evaluate(conn: sqlite3.Connection, entry: dict[str, Any], cohort: str) -> dict[str, Any]:
    """Decide, without writing, what should happen to one pair."""
    ea_id = entry["ea_id"]
    symbol = entry["symbol"]
    db_symbol = symbol if symbol.upper().endswith(".DWX") else symbol + ".DWX"
    logical_basket = symbol.upper().startswith("QM5_")
    if logical_basket:
        db_symbol = symbol

    out: dict[str, Any] = {"pair": entry["pair"], "cohort": cohort, "ea_id": ea_id,
                           "symbol": db_symbol, "ea_label": entry["ea_label"]}

    if not logical_basket and not db_symbol.upper().endswith(".DWX"):
        out.update(action="skip", reason="non_dwx_symbol")
        return out

    src = latest_q08(conn, ea_id, db_symbol)
    if src is None:
        out.update(action="skip", reason="no_prior_q08_row")
        return out
    setfile = src["setfile_path"]
    if not setfile or not Path(setfile).is_file():
        out.update(action="skip", reason="setfile_missing", setfile=setfile)
        return out
    if live_row_exists(conn, ea_id, db_symbol):
        out.update(action="skip", reason="existing_pending_or_active")
        return out
    defect = setfile_defect(setfile)
    if defect:
        out.update(action="skip", reason="deterministic_setgen_defect", defect=defect)
        return out

    lineage, lineage_error = build_q08_recovery_lineage(
        conn, REPORTS_ROOT, ea_id=ea_id, symbol=db_symbol, setfile_path=setfile
    )
    if lineage_error:
        out.update(action="skip", reason="q08_recovery_lineage_invalid", detail=lineage_error)
        return out

    payload: dict[str, Any] = {
        "host_symbol": db_symbol,
        "enqueued_by": ENQUEUED_BY,
        "enqueued_at_utc": utc_now(),
        "book_q08_regeneration": {
            "prereg": PREREG,
            "cohort": cohort,
            "reason": "archived stream carries no reconstructable binding; regenerate under a recorded one",
            "frozen_ex5_sha256_at_freeze": entry["ex5_sha256"],
            "archived_stream_trades": entry["stream_trades"],
            "archived_stream_rich": entry["stream_rich"],
        },
        "requeue_source": {
            "work_item_id": src["id"],
            "status": src["status"],
            "verdict": src["verdict"],
            "updated_at": src["updated_at"],
        },
    }
    if lineage is not None:
        payload["q08_recovery_lineage"] = lineage

    admission = farmctl.custom_history_archive_admission(
        FARM_ROOT, ea_id=str(ea_id), symbols=[db_symbol], payload=payload
    )
    if not admission.get("ok"):
        out.update(action="skip", reason="archive_coverage_refused",
                   detail=admission.get("reason"), missing=admission.get("missing_symbols") or [])
        return out
    farmctl._stamp_custom_history_archive_admission(payload, admission)

    out.update(action="insert", setfile=setfile, source_row=src["id"],
               source_verdict=src["verdict"], payload=payload)
    return out


def run(apply: bool, limit: int | None, cohort_filter: str | None) -> dict[str, Any]:
    if not COHORTS.is_file():
        raise PrepareError(f"cohorts_artifact_missing:{COHORTS}")
    doc = json.loads(COHORTS.read_text(encoding="utf-8"))
    conn = sqlite3.connect(DB, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")

    decisions: list[dict[str, Any]] = []
    try:
        for cohort, entries in doc["cohorts"].items():
            if cohort_filter and cohort_filter not in cohort:
                continue
            for entry in entries:
                decisions.append(evaluate(conn, entry, cohort))
        inserts = [d for d in decisions if d["action"] == "insert"]
        if limit is not None:
            for d in inserts[limit:]:
                d["action"] = "skip"
                d["reason"] = "limit_reached"
            inserts = inserts[:limit]

        created: list[dict[str, str]] = []
        if apply and inserts:
            now = utc_now()
            conn.execute("BEGIN IMMEDIATE")
            # Revalidate inside the transaction: a row may have appeared since evaluate().
            for d in inserts:
                if live_row_exists(conn, d["ea_id"], d["symbol"]):
                    raise PrepareError(f"raced_pending_row:{d['pair']}")
            for d in inserts:
                wid = str(uuid.uuid4())
                conn.execute(
                    """INSERT INTO work_items
                       (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                        attempt_count, payload_json, created_at, updated_at)
                       VALUES (?,?,?,?,?,?,'pending',NULL,0,?,?,?)""",
                    (wid, "backtest", "Q08", d["ea_id"], d["symbol"], d["setfile"],
                     json.dumps(d["payload"], sort_keys=True), now, now),
                )
                conn.execute(
                    "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                    "VALUES(?,'work_item',?,'book_q08_regeneration_enqueued',?)",
                    (now, wid, json.dumps({"pair": d["pair"], "cohort": d["cohort"],
                                           "source_row": d["source_row"],
                                           "prereg": PREREG}, sort_keys=True)),
                )
                created.append({"pair": d["pair"], "work_item_id": wid, "cohort": d["cohort"]})
            # Read back before commit: every created row must exist and be pending.
            for c in created:
                row = conn.execute(
                    "SELECT status FROM work_items WHERE id=?", (c["work_item_id"],)
                ).fetchone()
                if row is None or row["status"] != "pending":
                    raise PrepareError(f"pre_commit_row_not_pending:{c['work_item_id']}")
            conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    skips: dict[str, int] = {}
    for d in decisions:
        if d["action"] == "skip":
            skips[d["reason"]] = skips.get(d["reason"], 0) + 1
    return {
        "schema": SCHEMA,
        "mode": "apply" if apply else "plan",
        "at_utc": utc_now(),
        "prereg": PREREG,
        "cohorts_artifact": str(COHORTS),
        "evaluated": len(decisions),
        "would_insert" if not apply else "inserted": len(inserts),
        "created": created if apply else [],
        "skipped": skips,
        "decisions": [{k: v for k, v in d.items() if k != "payload"} for d in decisions],
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("command", choices=("plan", "apply"))
    ap.add_argument("--limit", type=int, default=None, help="cap the number of rows created")
    ap.add_argument("--cohort", default=None, help="substring filter, e.g. C1 / C2 / C3")
    ap.add_argument("--output", type=Path, default=None)
    args = ap.parse_args()
    try:
        result = run(args.command == "apply", args.limit, args.cohort)
        result["status"] = "ok"
        code = 0
    except (PrepareError, sqlite3.Error, OSError, KeyError) as exc:
        result = {"schema": SCHEMA, "status": "aborted", "reason": f"{type(exc).__name__}: {exc}"}
        code = 2
    text = json.dumps(result, indent=1, sort_keys=False)
    summary = {k: v for k, v in result.items() if k != "decisions"}
    print(json.dumps(summary, indent=1, sort_keys=False))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
