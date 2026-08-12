"""Staged, provenance-gated requeue of terminal Q09_PORTFOLIO NEED_MORE_DATA sleeves.

Gate-repair WP-6 defect-2 (2026-07-25, Codex review wp2346). A stranded sleeve is a
``work_items`` row with ``phase='Q09_PORTFOLIO'``, ``status='done'``,
``verdict='NEED_MORE_DATA'`` and reason ``portfolio_trade_count_below_min``. Because the
Q08->Q09 promotion uses ``NOT EXISTS`` on any Q09 row, a terminal row permanently blocks
re-promotion; a fresh evaluation therefore requires flipping the row back to a re-gradeable
state (``status='pending'``, ``verdict=NULL``).

But a requeue must NOT grade a mutable, unprovenanced stream. Codex WP-6: "It must bind each
requeue to validated current Q08 evidence or refuse it." A row is REQUEUE-eligible ONLY when
all of the following hold — otherwise it is REFUSED with a precise reason and left terminal:

  1. an authoritative Q08 trade count is known and >= the portfolio floor;
  2. the Q08 aggregate (``payload.q08_evidence_path``) still exists AND its own
     ``portfolio_stream.n`` equals that authoritative count (the run graded and persisted the
     same trades);
  3. the durable admission stream currently reads back EXACTLY that many volume-bearing
     TRADE_CLOSED rows (grading will grade the provenance-bound authoritative set); and
  4. when the aggregate is a ``q08_portfolio_stream/v2`` (it carries ``content_sha256``, the
     hash of the exact graded bytes), the durable stream's bytes MUST hash to it. A
     same-count FOREIGN stream is REFUSED (``durable_stream_sha256_mismatch``). Count parity
     is not identity; the hash is the identity (WP-6 defect-2, round 3, 2026-07-25).

A v1 aggregate carries no ``content_sha256`` and can only be validated by count
(``lineage_basis=count_only``) — the accepted and only-possible limitation for legacy
evidence; the ``lineage_basis`` marker recorded on every classification is that basis's
evidence trail.

A row whose Q08 aggregate is purged, whose recorded/persisted counts disagree, whose durable
stream has diverged, or whose durable bytes fail the bound hash is REFUSED. Such a sleeve
cannot be honestly recovered by a code fix alone; it needs a fresh, sealed Q08 re-run (a
separate, factory-ON action), not a requeue that would launder a divergent stream into a real
verdict.

Modes (default = dry-run, read-only, mutates nothing):

    # enumerate + classify + write a reversible snapshot; NO DB writes
    python -m tools.strategy_farm.portfolio.requeue_q09_stranded_sleeves \
        --snapshot-out D:/QM/reports/portfolio/q09_requeue_snapshot.json

    # execute the requeue for REQUEUE-classified rows (factory OFF, DB quiescent)
    python -m tools.strategy_farm.portfolio.requeue_q09_stranded_sleeves \
        --apply --snapshot-out D:/QM/reports/portfolio/q09_requeue_snapshot.json

    # undo, guarded on the exact post-apply state
    python -m tools.strategy_farm.portfolio.requeue_q09_stranded_sleeves \
        --revert D:/QM/reports/portfolio/q09_requeue_snapshot.json
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

try:
    from .portfolio_admission import DEFAULT_ADMISSION_COMMON_DIR
    from .portfolio_q08_contribution import (
        DEFAULT_MIN_PORTFOLIO_TRADES,
        _sleeve_stream_file,
        _volume_bearing_trade_count,
    )
except ImportError:  # pragma: no cover - direct script execution
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from portfolio_admission import DEFAULT_ADMISSION_COMMON_DIR  # type: ignore
    from portfolio_q08_contribution import (  # type: ignore
        DEFAULT_MIN_PORTFOLIO_TRADES,
        _sleeve_stream_file,
        _volume_bearing_trade_count,
    )

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
TARGET_REASON = "portfolio_trade_count_below_min"


def _utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def _ea_int(ea_id: str) -> int | None:
    text = str(ea_id).strip()
    if text.startswith("QM5_"):
        text = text.split("_", 2)[1]
    try:
        return int(text)
    except (TypeError, ValueError):
        return None


def _n_trades_from_aggregate(path: str | None) -> int | None:
    if not path:
        return None
    p = Path(path)
    if not p.exists():
        return None
    try:
        data = json.loads(p.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    try:
        return int(data.get("n_trades"))
    except (TypeError, ValueError):
        return None


def _classify(row: sqlite3.Row, common_dir: Path,
              default_floor: int) -> dict[str, Any]:
    payload = json.loads(row["payload_json"] or "{}")
    ea_id = str(row["ea_id"])
    symbol = str(row["symbol"])
    ea_i = _ea_int(ea_id)
    floor = payload.get("min_portfolio_trades") or default_floor
    try:
        floor = int(floor)
    except (TypeError, ValueError):
        floor = default_floor

    q08_evidence_path = payload.get("q08_evidence_path")
    authoritative = payload.get("q08_trade_count")
    if authoritative is None:
        authoritative = _n_trades_from_aggregate(q08_evidence_path)
    try:
        authoritative = int(authoritative) if authoritative is not None else None
    except (TypeError, ValueError):
        authoritative = None

    dur_path = _sleeve_stream_file(common_dir, (ea_i or 0, symbol)) if ea_i is not None else None
    dur_count = _volume_bearing_trade_count(dur_path) if dur_path is not None else None

    info: dict[str, Any] = {
        "work_item_id": row["id"],
        "ea_id": ea_id,
        "symbol": symbol,
        "floor": floor,
        "authoritative_q08_trade_count": authoritative,
        "q08_evidence_path": q08_evidence_path,
        "q08_evidence_exists": bool(q08_evidence_path) and Path(q08_evidence_path).exists(),
        "durable_stream_path": str(dur_path) if dur_path else None,
        "durable_stream_volume_rows": dur_count,
        # Exact prior mutable state, captured for a byte-faithful guarded revert.
        "prior_updated_at": row["updated_at"],
        "decision": "REFUSE",
        "reason": None,
    }

    if authoritative is None:
        info["reason"] = "authoritative_q08_count_unknown"
        return info
    if authoritative < floor:
        info["reason"] = "authoritative_below_floor"
        return info
    if not info["q08_evidence_exists"]:
        info["reason"] = "q08_evidence_purged"
        return info

    try:
        agg = json.loads(Path(q08_evidence_path).read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        info["reason"] = "q08_evidence_unreadable"
        return info
    pstream = agg.get("portfolio_stream")
    recorded_n = pstream.get("n") if isinstance(pstream, dict) else None
    info["aggregate_stream_recorded_n"] = recorded_n
    try:
        recorded_n = int(recorded_n)
    except (TypeError, ValueError):
        recorded_n = None
    if recorded_n != authoritative:
        info["reason"] = "aggregate_stream_count_mismatch"
        return info
    if dur_count != authoritative:
        info["reason"] = "durable_stream_count_diverged"
        return info

    # WP-6 defect-2 (round 3, 2026-07-25): count parity is not identity. When the aggregate
    # binds the graded bytes via content_sha256 (a v2 aggregate), the durable stream's bytes
    # MUST hash to it — a same-count foreign stream is REFUSED. A v1 aggregate has no such
    # hash and can only be validated by count (lineage_basis=count_only), the accepted and
    # only-possible limitation for legacy evidence. Reaching here, dur_count == authoritative
    # (a non-None int), so the durable stream file exists and is readable.
    content_sha256 = (
        str(pstream.get("content_sha256") or "").strip().lower()
        if isinstance(pstream, dict)
        else ""
    )
    info["aggregate_content_sha256"] = content_sha256 or None
    info["lineage_basis"] = "sha256" if content_sha256 else "count_only"
    if content_sha256:
        try:
            dur_sha: str | None = hashlib.sha256(dur_path.read_bytes()).hexdigest()
        except OSError:
            dur_sha = None
        info["durable_stream_sha256"] = dur_sha
        if dur_sha != content_sha256:
            info["reason"] = "durable_stream_sha256_mismatch"
            return info

    info["decision"] = "REQUEUE"
    info["reason"] = "provenance_validated"
    return info


def _open_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


def _fetch_stranded(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute(
        """
        SELECT id, ea_id, symbol, phase, status, verdict, evidence_path,
               setfile_path, payload_json, created_at, updated_at
        FROM work_items
        WHERE phase='Q09_PORTFOLIO' AND status='done' AND verdict='NEED_MORE_DATA'
        ORDER BY updated_at
        """
    ).fetchall()


def _plan(db: Path, common_dir: Path, default_floor: int) -> dict[str, Any]:
    conn = _open_ro(db)
    try:
        rows = _fetch_stranded(conn)
    finally:
        conn.close()
    classified = [_classify(r, common_dir, default_floor) for r in rows]
    filtered = [c for c in classified if True]
    requeue = [c for c in filtered if c["decision"] == "REQUEUE"]
    refuse = [c for c in filtered if c["decision"] == "REFUSE"]
    # Snapshot only the exact prior mutable state of REQUEUE rows, for a guarded revert.
    # updated_at is captured so revert restores the ORIGINAL timestamp, not a fresh one.
    prior = {
        c["work_item_id"]: {
            "status": "done",
            "verdict": "NEED_MORE_DATA",
            "updated_at": c.get("prior_updated_at"),
        }
        for c in requeue
    }
    return {
        "generated_at_utc": _utc_now(),
        "db": str(db),
        "common_dir": str(common_dir),
        "default_floor": default_floor,
        "target_reason": TARGET_REASON,
        "total_stranded": len(classified),
        "requeue_count": len(requeue),
        "refuse_count": len(refuse),
        "requeue": requeue,
        "refuse": refuse,
        "prior_state": prior,
    }


def _print_plan(plan: dict[str, Any]) -> None:
    print(f"stranded Q09_PORTFOLIO NEED_MORE_DATA rows: {plan['total_stranded']}")
    print(f"  REQUEUE (provenance validated): {plan['requeue_count']}")
    print(f"  REFUSE  (unrecoverable/low-freq): {plan['refuse_count']}")
    print("")
    hdr = f"{'decision':8} {'ea_id':10} {'symbol':12} {'auth':>5} {'dur':>5}  reason"
    print(hdr)
    print("-" * len(hdr))
    for c in plan["requeue"] + plan["refuse"]:
        print(f"{c['decision']:8} {c['ea_id']:10} {c['symbol']:12} "
              f"{str(c['authoritative_q08_trade_count']):>5} "
              f"{str(c['durable_stream_volume_rows']):>5}  {c['reason']}")
    if plan["requeue"]:
        print("\nWould set status='pending', verdict=NULL for the REQUEUE rows above:")
        for c in plan["requeue"]:
            print(f"  UPDATE work_items SET status='pending', verdict=NULL, updated_at=<now> "
                  f"WHERE id='{c['work_item_id']}' AND status='done' AND verdict='NEED_MORE_DATA';")
    else:
        print("\nNo rows are provenance-eligible for requeue. "
              "REFUSED rows need a fresh, sealed Q08 re-run (factory-ON), not a requeue.")


def _apply(db: Path, plan: dict[str, Any]) -> int:
    if not plan["requeue"]:
        print("nothing to apply: no REQUEUE-eligible rows")
        return 0
    # Revalidate transaction-locally against the SAME parameters the plan used, so apply
    # cannot silently grade a row on looser criteria than it was classified under.
    common_dir = Path(plan["common_dir"])
    default_floor = int(plan["default_floor"])
    now = _utc_now()
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    changed = 0
    try:
        conn.execute("BEGIN IMMEDIATE")
        for c in plan["requeue"]:
            wid = c["work_item_id"]
            # Re-read the FULL row under the write reservation and re-run the complete
            # provenance classification transaction-locally (Codex re-review defect-2/3,
            # 2026-07-25). Evidence (Q08 aggregate, stream, counts, hashes) can be purged
            # or diverge between plan and apply; a status/verdict check alone would still
            # requeue a row whose qualifying aggregate was deleted after planning.
            row = conn.execute(
                """
                SELECT id, ea_id, symbol, phase, status, verdict, evidence_path,
                       setfile_path, payload_json, created_at, updated_at
                FROM work_items WHERE id=?
                """,
                (wid,),
            ).fetchone()
            if row is None or row["status"] != "done" or row["verdict"] != "NEED_MORE_DATA":
                raise RuntimeError(
                    f"row {wid} changed since plan (status={row['status'] if row else None},"
                    f" verdict={row['verdict'] if row else None}); aborting, no writes committed"
                )
            recheck = _classify(row, common_dir, default_floor)
            if recheck["decision"] != "REQUEUE":
                raise RuntimeError(
                    f"row {wid} no longer provenance-eligible at apply "
                    f"(reason={recheck['reason']}); aborting, no writes committed"
                )
            conn.execute(
                "UPDATE work_items SET status='pending', verdict=NULL, updated_at=? "
                "WHERE id=? AND status='done' AND verdict='NEED_MORE_DATA'",
                (now, wid),
            )
            changed += 1
        conn.commit()
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()
    print(f"requeued {changed} row(s) to status='pending', verdict=NULL at {now}")
    return changed


def _revert(db: Path, snapshot_path: Path) -> int:
    plan = json.loads(snapshot_path.read_text(encoding="utf-8"))
    prior = plan.get("prior_state") or {}
    if not prior:
        print("snapshot has no prior_state; nothing to revert")
        return 0
    now = _utc_now()
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    restored = 0
    try:
        conn.execute("BEGIN IMMEDIATE")
        for wid, prior_state in prior.items():
            cur = conn.execute(
                "SELECT status, verdict FROM work_items WHERE id=?", (wid,)
            ).fetchone()
            # Guard: only revert rows still in the post-apply (pending / no-verdict) state.
            if cur is None or cur["status"] != "pending" or cur["verdict"] is not None:
                raise RuntimeError(
                    f"row {wid} is not in the expected post-apply state; aborting revert"
                )
            # Restore the EXACT original updated_at when the snapshot recorded it, so revert
            # is a byte-faithful restoration and not just a state flip with a fresh stamp
            # (Codex re-review defect-4). Fall back to now only for legacy snapshots.
            restored_updated_at = prior_state.get("updated_at") or now
            conn.execute(
                "UPDATE work_items SET status=?, verdict=?, updated_at=? "
                "WHERE id=? AND status='pending' AND verdict IS NULL",
                (prior_state["status"], prior_state["verdict"], restored_updated_at, wid),
            )
            restored += 1
        conn.commit()
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()
    print(f"reverted {restored} row(s) to status='done', verdict='NEED_MORE_DATA'")
    return restored


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--common-dir", type=Path, default=DEFAULT_ADMISSION_COMMON_DIR)
    ap.add_argument("--floor", type=int, default=DEFAULT_MIN_PORTFOLIO_TRADES,
                    help="portfolio trade floor used when a row payload has no min_portfolio_trades")
    ap.add_argument("--apply", action="store_true",
                    help="execute the requeue (factory OFF + DB quiescent). Default is dry-run.")
    ap.add_argument("--revert", type=Path, help="revert using a snapshot written by a prior run")
    ap.add_argument("--snapshot-out", type=Path,
                    help="write the reversible plan/snapshot JSON here (dry-run and --apply)")
    args = ap.parse_args(argv)

    if args.revert is not None:
        return 0 if _revert(args.db, args.revert) >= 0 else 1

    # A durable, reversible snapshot is MANDATORY and UNCONDITIONAL for any mutation
    # (Codex re-review defect-1). There is no code path that applies without first writing
    # the revert record — refuse before touching the DB rather than mutate un-revertably.
    if args.apply and args.snapshot_out is None:
        print(
            "--apply requires --snapshot-out: a durable revert snapshot must be written "
            "before any DB mutation. Aborting, no writes performed.",
            file=sys.stderr,
        )
        return 2

    plan = _plan(args.db, args.common_dir, args.floor)
    _print_plan(plan)
    if args.snapshot_out is not None:
        args.snapshot_out.parent.mkdir(parents=True, exist_ok=True)
        args.snapshot_out.write_text(json.dumps(plan, indent=2, sort_keys=True), encoding="utf-8")
        print(f"\nsnapshot written: {args.snapshot_out}")
    if args.apply:
        # Snapshot is guaranteed written above (mandatory precondition enforced).
        _apply(args.db, plan)
    else:
        print("\n[dry-run] no DB writes performed. Re-run with --apply after Factory OFF to execute.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
