"""Governed, append-only re-issue of stale COMPILE_EA rows (Orchestrator 2026-09-13).

The whole COMPILE_EA queue is stale: `release_compile_wave.py` defers every held
`COMPILE_EA_WORKER_ROLLOUT_PENDING` row because its pinned payload `mq5_sha256`
no longer equals the on-disk source (sources were patched after the rows were
enqueued -- symbol-input patches d0433c1c1d / 8172b14ba3, the 1538 compile-path
repair, etc.).  A worker that claims such a row raises
``SOURCE_CHANGED_AFTER_ENQUEUE`` (compile_work_items.py:6138-6139); there is no
in-place re-pin.

This tool is a THIN GOVERNED WRAPPER.  It never mutates a stale row.  For every
held rollout row whose source is stale, it lets the canonical library create the
append-only successor via ``compile_work_items.enqueue_compile_eas`` under the
self-expiring ``ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY``.  That path pins
the successor to the CURRENT source SHA, activation-holds it, and records a
``work_item_supersedes`` edge back to each stale predecessor -- so the worker
recheck survives hold closure (compile_work_items.py:5391-5405, 6120-6132).

Fail-closed gates layered on top of the library:
  * A stale row is re-issued ONLY when its source is COMMITTED (working tree
    clean vs HEAD).  A source changed by an uncommitted working-tree edit is
    EXCLUDED and flagged -- we never re-pin to uncommitted content.
  * A label whose held predecessor is ALREADY superseded is skipped: the library
    refuses it at apply (``SOURCE_REPAIR_PREDECESSOR_ALREADY_SUPERSEDED_AT_APPLY``,
    compile_work_items.py:5203-5211); such rows changed source twice and need a
    separate governed path, not this reconciliation.
  * A label already carrying a usable current compile verdict is skipped
    (the library classifies it ``USABLE_CURRENT_COMPILE_VERDICT_EXISTS``).

Dry-run is the default and writes nothing to the DB.  ``--apply`` requires
``--plan-sha256 <sha>`` matching the reviewed plan, takes the factory mutation
lock, writes a fresh verified state backup, calls the library with ``apply=True``,
then writes a receipt.

    python -X utf8 tools/strategy_farm/session_tools/reissue_stale_compile_rows_0913.py            # dry-run (default)
    python -X utf8 tools/strategy_farm/session_tools/reissue_stale_compile_rows_0913.py --apply --plan-sha256 <sha>
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any, Callable

REPO = Path("C:/QM/repo")
sys.path.insert(0, str(REPO))  # make `tools.strategy_farm` importable
from tools.strategy_farm import compile_work_items as cwi  # noqa: E402
from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock  # noqa: E402

FARM_ROOT = Path("D:/QM/strategy_farm")
DEFAULT_DB = FARM_ROOT / "state" / "farm_state.sqlite"
MUTATION_LOCK = FARM_ROOT / "state" / "FACTORY_MUTATION.lock"
BACKUP_DIR = FARM_ROOT / "state" / "backups"
EVID = REPO / "docs/ops/evidence/2026-09-13_compile_reissue"
DEFAULT_RECEIPT = EVID / "receipt.json"

AUTHORITY = cwi.ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY
ROLLOUT_HOLD_CODE = cwi.COMPILE_ACTIVATION_HOLD_CODE  # COMPILE_EA_WORKER_ROLLOUT_PENDING
SCHEMA = "qm.compile-ea-stale-rollout-reissue/v1"

# --- disposition reason codes -------------------------------------------------
R_REISSUE = "REISSUE"
R_NOT_ELIGIBLE = "SKIP_NOT_ELIGIBLE"                       # library classify refused
R_PRED_SUPERSEDED = "SKIP_PREDECESSOR_ALREADY_SUPERSEDED"  # library refuses at apply
R_UNCOMMITTED = "SKIP_SOURCE_UNCOMMITTED_EXCLUDED"         # never re-pin dirty content
R_CLAIMED = "SKIP_ROW_CLAIMED"
R_VESTIGIAL = "SKIP_NON_ROLLOUT_VESTIGIAL_DONE_AT_CURRENT"  # EA already compiled at current
R_ORPHAN = "SKIP_NON_ROLLOUT_ORPHAN_NEEDS_SEPARATE_PATH"    # not compiled at current, non-held


# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------
def utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="microseconds")


def sha256_file(path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _connect_ro(db_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{Path(db_path).as_posix()}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    return conn


def _source_path(repo_root: Path, label: str) -> Path:
    return repo_root / "framework" / "EAs" / label / f"{label}.mq5"


def _git_clean(repo_root: Path, label: str) -> bool:
    """True iff the EA .mq5 working-tree content equals HEAD (no staged/unstaged change)."""
    rel = f"framework/EAs/{label}/{label}.mq5"
    out = subprocess.run(
        ["git", "status", "--porcelain", "--", rel],
        cwd=str(repo_root), capture_output=True, text=True,
    )
    if out.returncode != 0:
        return False  # fail-closed: cannot prove clean -> treat as not committed
    return out.stdout.strip() == ""


def _commit_info(repo_root: Path, label: str) -> dict[str, str] | None:
    rel = f"framework/EAs/{label}/{label}.mq5"
    out = subprocess.run(
        ["git", "log", "-1", "--format=%H%x1f%h%x1f%ci%x1f%s", "--", rel],
        cwd=str(repo_root), capture_output=True, text=True,
    )
    if out.returncode != 0 or not out.stdout.strip():
        return None
    full, short, when, subject = out.stdout.strip().split("\x1f", 3)
    return {"commit": full, "short": short, "date": when, "subject": subject}


def _governed_eligibility(farm_root: Path, repo_root: Path, labels: list[str]) -> dict[str, dict[str, Any]]:
    """Ask the canonical library to classify each label under the rollout authority.

    Uses the batch (from_file) dry-run form so NOTHING is written: explicit-label
    enqueue auto-applies (compile_work_items.py:5097), the file form does not.
    """
    result: dict[str, dict[str, Any]] = {}
    if not labels:
        return result
    tmp = Path(tempfile.gettempdir()) / f"qm_reissue_labels_{uuid.uuid4().hex}.txt"
    try:
        tmp.write_text("\n".join(labels) + "\n", encoding="utf-8")
        res = cwi.enqueue_compile_eas(
            farm_root, repo_root, [], from_file=str(tmp), apply=False,
            source_repair_authority=AUTHORITY,
        )
    finally:
        tmp.unlink(missing_ok=True)
    for cand in res.get("candidate_classification") or []:
        label = str(cand.get("ea_label") or "")
        result[label] = {
            "eligible": bool(cand.get("eligible")),
            "reasons": list(cand.get("reasons") or ([cand.get("reason")] if cand.get("reason") else [])),
            "new_sha": str(cand.get("mq5_sha256") or "").lower() or None,
            "predecessor_ids": sorted(
                str(v) for v in (cand.get("source_repair_stale_open_work_item_ids") or []) if str(v or "")
            ),
        }
    return result


def _ea_has_compile_ok_at(conn: sqlite3.Connection, ea_id: str, source_sha: str) -> bool:
    if not source_sha:
        return False
    rows = conn.execute(
        "SELECT payload_json FROM work_items WHERE ea_id=? AND phase=? "
        "AND status='done' AND verdict='COMPILE_OK'",
        (ea_id, cwi.COMPILE_EA_PHASE),
    ).fetchall()
    return any(
        str(json.loads(r["payload_json"] or "{}").get("mq5_sha256") or "").lower() == source_sha
        for r in rows
    )


# ---------------------------------------------------------------------------
# pure decision (unit-testable)
# ---------------------------------------------------------------------------
def decide_label_action(
    *,
    governed_eligible: bool,
    governed_reasons: list[str],
    any_predecessor_superseded: bool,
    is_clean: bool,
) -> tuple[str, str]:
    """Decide reissue vs skip for one held-rollout label.

    Order matters: library classification first, then the two fail-closed gates
    the library would enforce at apply (predecessor already superseded), then the
    never-re-pin-dirty gate.
    """
    if not governed_eligible:
        detail = ",".join(governed_reasons) if governed_reasons else "UNKNOWN"
        return "skip", f"{R_NOT_ELIGIBLE}:{detail}"
    if any_predecessor_superseded:
        return "skip", R_PRED_SUPERSEDED
    if not is_clean:
        return "skip", R_UNCOMMITTED
    return "reissue", R_REISSUE


# ---------------------------------------------------------------------------
# gather + plan
# ---------------------------------------------------------------------------
def _gather_pending(conn: sqlite3.Connection, repo_root: Path) -> list[dict[str, Any]]:
    rows = conn.execute(
        "SELECT id,ea_id,status,claimed_by,verdict,payload_json,created_at "
        "FROM work_items WHERE phase=? AND status='pending' ORDER BY created_at,id",
        (cwi.COMPILE_EA_PHASE,),
    ).fetchall()
    gathered: list[dict[str, Any]] = []
    for r in rows:
        payload = json.loads(r["payload_json"] or "{}")
        label = str(payload.get("ea_label") or "")
        pinned = str(payload.get("mq5_sha256") or "").lower()
        ondisk = (sha256_file(_source_path(repo_root, label)) or "").lower()
        held = conn.execute(
            "SELECT 1 FROM work_item_holds WHERE work_item_id=? AND hold_code=? AND active=1",
            (r["id"], ROLLOUT_HOLD_CODE),
        ).fetchone() is not None
        superseded = conn.execute(
            "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?",
            (r["id"],),
        ).fetchone() is not None
        gathered.append({
            "work_item_id": r["id"],
            "ea_id": r["ea_id"],
            "ea_label": label,
            "old_sha": pinned or None,
            "new_sha": ondisk or None,
            "stale": bool(pinned and pinned != ondisk),
            "claimed": r["claimed_by"] is not None,
            "held": held,
            "already_superseded": superseded,
        })
    return gathered


def plan(
    *,
    farm_root: Path = FARM_ROOT,
    repo_root: Path = REPO,
    db_path: Path | None = None,
    governed_eligibility_fn: Callable[[list[str]], dict[str, dict[str, Any]]] | None = None,
    git_clean_fn: Callable[[str], bool] | None = None,
    commit_info_fn: Callable[[str], dict[str, str] | None] | None = None,
) -> dict[str, Any]:
    db_path = Path(db_path) if db_path is not None else (Path(farm_root) / "state" / "farm_state.sqlite")
    gov_fn = governed_eligibility_fn or (lambda labs: _governed_eligibility(farm_root, repo_root, labs))
    clean_fn = git_clean_fn or (lambda lab: _git_clean(repo_root, lab))
    commit_fn = commit_info_fn or (lambda lab: _commit_info(repo_root, lab))

    conn = _connect_ro(db_path)
    try:
        gathered = _gather_pending(conn, repo_root)
        stale = [g for g in gathered if g["stale"]]

        # Universe for the rollout authority: held + stale + unclaimed rows.
        rollout_rows = [g for g in stale if g["held"] and not g["claimed"]]
        rollout_labels = sorted({g["ea_label"] for g in rollout_rows})
        governed = gov_fn(rollout_labels)

        label_actions: dict[str, dict[str, Any]] = {}
        reissue_labels: list[dict[str, Any]] = []
        for label in rollout_labels:
            g = governed.get(label, {"eligible": False, "reasons": ["LIBRARY_DID_NOT_CLASSIFY"], "new_sha": None})
            preds = [g2 for g2 in rollout_rows if g2["ea_label"] == label]
            any_pred_superseded = any(p["already_superseded"] for p in preds)
            is_clean = clean_fn(label)
            action, reason = decide_label_action(
                governed_eligible=g["eligible"],
                governed_reasons=g["reasons"],
                any_predecessor_superseded=any_pred_superseded,
                is_clean=is_clean,
            )
            commit = commit_fn(label) if action == "reissue" else None
            new_sha = g.get("new_sha") or (preds[0]["new_sha"] if preds else None)
            entry = {
                "ea_label": label,
                "action": action,
                "reason": reason,
                "new_sha": new_sha,
                "clean": is_clean,
                "predecessor_work_item_ids": sorted(p["work_item_id"] for p in preds),
                "commit": commit,
            }
            if action == "reissue" and commit:
                entry["rerun_reason"] = (
                    f"source refreshed after enqueue: {commit['short']} {commit['subject']}"
                )
            label_actions[label] = entry
            if action == "reissue":
                reissue_labels.append(entry)

        reissue_label_set = {e["ea_label"] for e in reissue_labels}

        # Row-level disposition for every stale pending row.
        row_dispositions: list[dict[str, Any]] = []
        for g in stale:
            label = g["ea_label"]
            commit = None
            if g["held"] and g["claimed"]:
                action, reason = "skip", R_CLAIMED
            elif g["held"]:
                la = label_actions.get(label, {})
                if la.get("action") == "reissue":
                    action, reason = "reissue", R_REISSUE
                    commit = la.get("commit")
                else:
                    action, reason = "skip", str(la.get("reason") or R_NOT_ELIGIBLE)
            else:
                if _ea_has_compile_ok_at(conn, g["ea_id"], g["new_sha"] or ""):
                    action, reason = "skip", R_VESTIGIAL
                else:
                    action, reason = "skip", R_ORPHAN
            row_dispositions.append({
                "work_item_id": g["work_item_id"],
                "ea_id": g["ea_id"],
                "ea_label": label,
                "old_sha": g["old_sha"],
                "new_sha": g["new_sha"],
                "commit": commit["commit"] if commit else None,
                "held": g["held"],
                "already_superseded": g["already_superseded"],
                "action": action,
                "reason": reason,
            })

        reissue_rows = [r for r in row_dispositions if r["action"] == "reissue"]
        counts = {
            "pending_total": len(gathered),
            "stale_total": len(stale),
            "fresh_untouched": len(gathered) - len(stale),
            "rollout_labels_considered": len(rollout_labels),
            "reissue_labels": len(reissue_labels),
            "reissue_rows_superseded": len(reissue_rows),
            "skip_rows": len(row_dispositions) - len(reissue_rows),
        }
        document = {
            "schema": SCHEMA,
            "mode": "dry_run",
            "generated_at": utc_now(),
            "database": str(db_path),
            "repo": str(repo_root),
            "authority": AUTHORITY,
            "counts": counts,
            "reissue_labels": reissue_labels,
            "rows": row_dispositions,
        }
        document["plan_sha256"] = _plan_sha256(document)
        return document
    finally:
        conn.close()


def _plan_sha256(document: dict[str, Any]) -> str:
    """Content hash over the deterministic decision (excludes timestamps)."""
    canonical = {
        "schema": document["schema"],
        "authority": document["authority"],
        "reissue_labels": [
            {
                "ea_label": e["ea_label"],
                "action": e["action"],
                "reason": e["reason"],
                "new_sha": e["new_sha"],
                "commit": (e.get("commit") or {}).get("commit") if isinstance(e.get("commit"), dict) else e.get("commit"),
                "predecessor_work_item_ids": e["predecessor_work_item_ids"],
            }
            for e in document["reissue_labels"]
        ],
        "rows": [
            {
                "work_item_id": r["work_item_id"],
                "old_sha": r["old_sha"],
                "new_sha": r["new_sha"],
                "action": r["action"],
                "reason": r["reason"],
            }
            for r in document["rows"]
        ],
    }
    return sha256_bytes(json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode("utf-8"))


# ---------------------------------------------------------------------------
# apply (GOVERNED; requires --plan-sha256; NOT executed by the author)
# ---------------------------------------------------------------------------
def _backup_database(db_path: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    dest = backup_dir / f"farm_state_before_compile_reissue_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
    with sqlite3.connect(db_path) as src, sqlite3.connect(dest) as tgt:
        src.backup(tgt)
    with sqlite3.connect(dest) as chk:
        quick = str(chk.execute("PRAGMA quick_check").fetchone()[0])
    if quick.casefold() != "ok":
        raise RuntimeError(f"backup quick_check failed: {quick}")
    return dest, sha256_file(dest)


def apply(
    *,
    plan_sha256: str,
    farm_root: Path = FARM_ROOT,
    repo_root: Path = REPO,
    db_path: Path | None = None,
    mutation_lock: Path = MUTATION_LOCK,
    backup_dir: Path = BACKUP_DIR,
    receipt_path: Path = DEFAULT_RECEIPT,
) -> dict[str, Any]:
    db_path = Path(db_path) if db_path is not None else (Path(farm_root) / "state" / "farm_state.sqlite")
    current = plan(farm_root=farm_root, repo_root=repo_root, db_path=db_path)
    if current["plan_sha256"] != plan_sha256:
        raise RuntimeError(
            f"PLAN_DRIFT: reviewed {plan_sha256} != current {current['plan_sha256']}; re-review the dry-run"
        )
    labels = [e["ea_label"] for e in current["reissue_labels"]]
    if not labels:
        return {**current, "mode": "apply", "applied": 0, "backup": None,
                "note": "no actionable labels; nothing to re-issue"}
    # Re-assert cleanliness immediately before writing.
    dirty = [lab for lab in labels if not _git_clean(repo_root, lab)]
    if dirty:
        raise RuntimeError(f"SOURCE_UNCOMMITTED_AT_APPLY: {dirty}")

    lock = FactoryMutationLock(mutation_lock, owner="reissue_stale_compile_rows_0913.apply")
    with lock:
        backup_path, backup_sha = _backup_database(db_path, backup_dir)
        # The library opens its own BEGIN IMMEDIATE transaction and creates the
        # successor row, activation hold, and supersede edges per label.
        result = cwi.enqueue_compile_eas(
            farm_root, repo_root, labels, apply=True, source_repair_authority=AUTHORITY,
        )

    # Independent verification against the live DB.
    verification_errors: list[str] = []
    conn = _connect_ro(db_path)
    try:
        for entry in current["reissue_labels"]:
            label, new_sha = entry["ea_label"], entry["new_sha"]
            fresh = conn.execute(
                "SELECT w.id FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id "
                "WHERE w.phase=? AND w.status='pending' AND w.claimed_by IS NULL "
                "AND h.hold_code=? AND h.active=1 "
                "AND json_extract(w.payload_json,'$.ea_label')=? "
                "AND lower(json_extract(w.payload_json,'$.mq5_sha256'))=?",
                (cwi.COMPILE_EA_PHASE, ROLLOUT_HOLD_CODE, label, (new_sha or "").lower()),
            ).fetchall()
            if not fresh:
                verification_errors.append(f"{label}: no fresh held successor at {new_sha}")
                continue
            for pred in entry["predecessor_work_item_ids"]:
                edge = conn.execute(
                    "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (pred,)
                ).fetchone()
                if edge is None:
                    verification_errors.append(f"{label}: predecessor {pred} not superseded")
    finally:
        conn.close()

    receipt = {
        **current,
        "mode": "apply",
        "applied_at": utc_now(),
        "plan_sha256_verified": plan_sha256,
        "reissued_labels": labels,
        "library_result": {
            "ok": result.get("ok"),
            "enqueued_count": result.get("enqueued_count"),
            "enqueued": result.get("enqueued"),
            "idempotent_open": result.get("idempotent_open"),
            "refused": result.get("refused"),
        },
        "backup": {"path": str(backup_path), "sha256": backup_sha},
        "factory_mutation_lock": {"path": str(mutation_lock), "release_status": lock.release_status},
        "verification_ok": not verification_errors,
        "verification_errors": verification_errors,
    }
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = receipt_path.with_name(f".{receipt_path.name}.{uuid.uuid4().hex}.tmp")
    tmp.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(receipt_path)
    return receipt


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true",
                    help="REQUIRED to write. Without it this is a read-only dry run.")
    ap.add_argument("--plan-sha256", help="the reviewed dry-run plan_sha256; REQUIRED with --apply")
    ap.add_argument("--db", type=Path, default=None, help="override farm_state.sqlite path")
    ap.add_argument("--receipt", type=Path, default=DEFAULT_RECEIPT)
    ap.add_argument("--output", type=Path, help="also write the dry-run plan JSON to this path")
    args = ap.parse_args()

    if not args.apply:
        document = plan(db_path=args.db)
        encoded = json.dumps(document, indent=2, sort_keys=True)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            tmp = args.output.with_name(f".{args.output.name}.{uuid.uuid4().hex}.tmp")
            tmp.write_text(encoded + "\n", encoding="utf-8")
            tmp.replace(args.output)
        print(encoded)
        print(f"\nplan_sha256: {document['plan_sha256']}")
        print("DRY-RUN only (default). Nothing was written to the DB. "
              "Re-run with --apply --plan-sha256 <sha> to write.")
        return 0

    if not args.plan_sha256:
        ap.error("--apply requires --plan-sha256 <sha> (the reviewed dry-run hash)")
    if args.receipt.exists():
        print(f"refusing to overwrite existing receipt: {args.receipt}")
        return 1
    receipt = apply(plan_sha256=args.plan_sha256, db_path=args.db, receipt_path=args.receipt)
    print(json.dumps(receipt, indent=2, sort_keys=True))
    print(f"\nAPPLIED. Receipt: {args.receipt}")
    return 0 if receipt.get("verification_ok", True) else 2


if __name__ == "__main__":
    raise SystemExit(main())
