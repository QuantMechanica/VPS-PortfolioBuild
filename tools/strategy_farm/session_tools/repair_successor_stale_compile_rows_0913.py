"""Governed repair-successor path for the compile rows the rollout re-issue skipped.

Sibling of ``reissue_stale_compile_rows_0913.py``.  That tool handles held rollout
rows via ``enqueue_compile_eas`` + the rollout-reconciliation authority.  This tool
handles the ROWS THAT PATH SKIPPED -- non-held orphans, double-superseded rows, and
a freshly-failed row -- via the OTHER governed library function,
``compile_work_items.enqueue_repair_successor``: it appends an append-only,
activation-held successor for a TERMINAL ``COMPILE_FAIL`` / ``BUILD_CHECK_FAIL`` row
once the source has been repaired (current SHA != the failed row's pinned SHA),
bound to an OPEN ``build_ea`` task, with a ``work_item_supersedes`` edge back to the
failed predecessor.  It never mutates the failed row.

RE-RUNNABLE BY DESIGN.  Sources are being re-patched right now (framework-input-pin
repair -> the winsweep template pins qm_rng_seed / qm_news_* / qm_friday_close_* in
Strategy_InputsValid; evidence docs/ops/evidence/2026-09-13_framework_input_pin_repair.md),
so the SHAs of 41179/41189/41113/41123/41374/41389/41397/41399 will change again.
Every disposition is recomputed from the LIVE db + LIVE source on each run; no hash
is baked into the tool or its tests.  The plan is a snapshot -- re-run it after each
upstream source change.

``enqueue_repair_successor`` requires an OPEN, identity-matching ``build_ea`` task
(the predecessor's ``bound_build_task_id`` when still open, else exactly one open
task for the EA).  When none exists the row is NOT re-issued here; it is flagged
``NEEDS_BUILD_TASK`` / ``NEEDS_FRESH_BUILD_EA`` (with whether an approved card of
record exists) so the Orchestrator can commission a build -- this tool never
fabricates a build task or a card.

Dry-run is default and writes nothing.  ``--apply`` requires ``--plan-sha256 <sha>``
matching the reviewed plan, takes the factory mutation lock, writes a verified state
backup, calls the library with ``apply=True``, then writes a receipt.

    python -X utf8 tools/strategy_farm/session_tools/repair_successor_stale_compile_rows_0913.py            # dry-run
    python -X utf8 tools/strategy_farm/session_tools/repair_successor_stale_compile_rows_0913.py --apply --plan-sha256 <sha>
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import subprocess
import sys
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
DEFAULT_PLAN = EVID / "plan_repair_successors.json"
DEFAULT_RECEIPT = EVID / "receipt_repair_successors.json"
CARD_DIRS = (
    FARM_ROOT / "artifacts" / "cards_approved",
    REPO / "artifacts" / "cards_approved",
)

SCHEMA = "qm.compile-ea-repair-successor-batch/v1"
FAILURE_VERDICTS = ("COMPILE_FAIL", "BUILD_CHECK_FAIL")

# Rows the rollout re-issue skipped (orphans + double-superseded) + the fresh
# COMPILE_FAIL from the first wave (41179 EA_FRAMEWORK_INPUT_PINNED).
TARGET_EAS = [
    "QM5_41113", "QM5_41123", "QM5_13128", "QM5_9730",
    "QM5_41142", "QM5_41356", "QM5_41179",
]

# --- disposition reason codes -------------------------------------------------
R_REPAIR = "REPAIR_SUCCESSOR"
R_ALREADY_COMPILED = "SKIP_ALREADY_COMPILED_AT_CURRENT"
R_ALREADY_PENDING = "SKIP_ALREADY_PENDING_AT_CURRENT"
R_UNCOMMITTED = "SKIP_SOURCE_UNCOMMITTED_EXCLUDED"
R_SOURCE_NOT_REPAIRED = "SKIP_SOURCE_NOT_REPAIRED"
R_NEEDS_BUILD_TASK = "FLAG_NEEDS_OPEN_BUILD_TASK"
R_NEEDS_FRESH_BUILD = "FLAG_NEEDS_FRESH_BUILD_EA"


# ---------------------------------------------------------------------------
# helpers
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


def _numeric(ea_id: str) -> str:
    parts = str(ea_id).split("_")
    return parts[1] if len(parts) > 1 else str(ea_id)


def _resolve_label(conn: sqlite3.Connection, repo_root: Path, ea_id: str) -> str | None:
    row = conn.execute(
        "SELECT payload_json FROM work_items WHERE ea_id=? AND phase=? "
        "AND json_extract(payload_json,'$.ea_label') IS NOT NULL ORDER BY created_at DESC LIMIT 1",
        (ea_id, cwi.COMPILE_EA_PHASE),
    ).fetchone()
    if row:
        label = json.loads(row["payload_json"] or "{}").get("ea_label")
        if label:
            return str(label)
    matches = sorted((repo_root / "framework" / "EAs").glob(f"{ea_id}_*"))
    return matches[0].name if matches else None


def _source_path(repo_root: Path, label: str) -> Path:
    return repo_root / "framework" / "EAs" / label / f"{label}.mq5"


def _git_clean(repo_root: Path, label: str) -> bool:
    rel = f"framework/EAs/{label}/{label}.mq5"
    out = subprocess.run(["git", "status", "--porcelain", "--", rel],
                         cwd=str(repo_root), capture_output=True, text=True)
    return out.returncode == 0 and out.stdout.strip() == ""


def _commit_info(repo_root: Path, label: str) -> dict[str, str] | None:
    rel = f"framework/EAs/{label}/{label}.mq5"
    out = subprocess.run(["git", "log", "-1", "--format=%H%x1f%h%x1f%ci%x1f%s", "--", rel],
                         cwd=str(repo_root), capture_output=True, text=True)
    if out.returncode != 0 or not out.stdout.strip():
        return None
    full, short, when, subject = out.stdout.strip().split("\x1f", 3)
    return {"commit": full, "short": short, "date": when, "subject": subject}


def _has_approved_card(label: str, ea_id: str) -> bool:
    for d in CARD_DIRS:
        if list(Path(d).glob(f"{ea_id}_*.md")) or (Path(d) / f"{label}.md").is_file():
            return True
    return False


def _lone_open_build_task(conn: sqlite3.Connection, ea_id: str) -> str | None:
    """The single open build_ea task naming this EA, else None (never guesses)."""
    try:
        rows = conn.execute(
            "SELECT id,card_id FROM tasks WHERE kind='build_ea' AND status IN ('pending','active')"
        ).fetchall()
    except sqlite3.Error:
        return None
    num = _numeric(ea_id)
    matching = [r["id"] for r in rows if cwi._numeric_ea_reference(r["card_id"]) == num]
    return matching[0] if len(matching) == 1 else None


def _governed_repair(farm_root: Path, repo_root: Path, db_path: Path,
                     predecessor_id: str, ea_id: str) -> dict[str, Any]:
    """Governed dry-run of enqueue_repair_successor for one failed predecessor.

    Tries the predecessor's own bound build task first; if the only blocker is the
    build-task binding, retries with the lone open build_ea task for the EA (if
    exactly one exists).  Pure read: enqueue_repair_successor(apply=False) writes
    nothing.
    """
    res = cwi.enqueue_repair_successor(farm_root, repo_root, predecessor_id, apply=False)
    if not res.get("eligible"):
        reasons = set(res.get("reasons") or [])
        binding_reasons = {
            "BUILD_TASK_BINDING_NOT_REQUESTED", "BUILD_TASK_BINDING_NOT_OPEN",
            "BUILD_TASK_BINDING_NOT_FOUND", "BUILD_TASK_BINDING_AMBIGUOUS",
        }
        if reasons & binding_reasons and reasons <= binding_reasons:
            with _connect_ro(db_path) as conn:
                task_id = _lone_open_build_task(conn, ea_id)
            if task_id:
                alt = cwi.enqueue_repair_successor(
                    farm_root, repo_root, predecessor_id, build_task_id=task_id, apply=False)
                if alt.get("eligible"):
                    res = alt
    return {
        "eligible": bool(res.get("eligible")),
        "reasons": list(res.get("reasons") or []),
        "old_sha": (res.get("old_mq5_sha256") or None),
        "new_sha": (res.get("current_mq5_sha256") or None),
        "build_task_id": res.get("build_task_id"),
    }


# ---------------------------------------------------------------------------
# pure decision (unit-testable)
# ---------------------------------------------------------------------------
def decide_ea_action(
    *,
    has_done_ok_at_current: bool,
    has_fresh_pending_at_current: bool,
    repairable: bool,
    is_clean: bool,
    has_terminal_failure: bool,
    source_repaired: bool,
) -> tuple[str, str]:
    """Decide one EA's disposition. Order: already-handled, then act, then blockers."""
    if has_done_ok_at_current:
        return "skip", R_ALREADY_COMPILED
    if has_fresh_pending_at_current:
        return "skip", R_ALREADY_PENDING
    if repairable and is_clean:
        return "repair_successor", R_REPAIR
    if not is_clean:
        return "skip", R_UNCOMMITTED
    if not has_terminal_failure:
        return "skip", R_NEEDS_FRESH_BUILD
    if not source_repaired:
        return "skip", R_SOURCE_NOT_REPAIRED
    return "skip", R_NEEDS_BUILD_TASK  # source repaired + failed row present, but no open build task


# ---------------------------------------------------------------------------
# plan
# ---------------------------------------------------------------------------
def _ea_state(conn: sqlite3.Connection, ea_id: str, ondisk: str) -> dict[str, Any]:
    rows = conn.execute(
        "SELECT id,status,verdict,claimed_by,payload_json,created_at FROM work_items "
        "WHERE ea_id=? AND phase=? ORDER BY created_at,id",
        (ea_id, cwi.COMPILE_EA_PHASE),
    ).fetchall()
    done_ok_at_current = False
    fresh_pending_at_current = False
    failures: list[dict[str, Any]] = []
    for r in rows:
        p = json.loads(r["payload_json"] or "{}")
        pinned = str(p.get("mq5_sha256") or "").lower()
        superseded = conn.execute(
            "SELECT 1 FROM work_item_supersedes WHERE work_item_id=?", (r["id"],)
        ).fetchone() is not None
        if r["status"] == "done" and r["verdict"] == "COMPILE_OK" and pinned == ondisk:
            done_ok_at_current = True
        if r["status"] == "pending" and pinned == ondisk and not superseded:
            fresh_pending_at_current = True
        if r["status"] == "failed" and r["verdict"] in FAILURE_VERDICTS and not superseded:
            failures.append({"id": r["id"], "pinned": pinned, "created_at": r["created_at"]})
    failures.sort(key=lambda f: (f["created_at"] or "", f["id"]), reverse=True)  # newest first
    return {
        "done_ok_at_current": done_ok_at_current,
        "fresh_pending_at_current": fresh_pending_at_current,
        "failures": failures,
    }


def plan(
    *,
    farm_root: Path = FARM_ROOT,
    repo_root: Path = REPO,
    db_path: Path | None = None,
    targets: list[str] | None = None,
    governed_repair_fn: Callable[[str, str], dict[str, Any]] | None = None,
    git_clean_fn: Callable[[str], bool] | None = None,
    commit_info_fn: Callable[[str], dict[str, str] | None] | None = None,
    card_fn: Callable[[str, str], bool] | None = None,
) -> dict[str, Any]:
    db_path = Path(db_path) if db_path is not None else (Path(farm_root) / "state" / "farm_state.sqlite")
    targets = list(targets or TARGET_EAS)
    repair_fn = governed_repair_fn or (lambda pid, ea: _governed_repair(farm_root, repo_root, db_path, pid, ea))
    clean_fn = git_clean_fn or (lambda lab: _git_clean(repo_root, lab))
    commit_fn = commit_info_fn or (lambda lab: _commit_info(repo_root, lab))
    card_present_fn = card_fn or (lambda lab, ea: _has_approved_card(lab, ea))

    conn = _connect_ro(db_path)
    try:
        entries: list[dict[str, Any]] = []
        for ea_id in targets:
            label = _resolve_label(conn, repo_root, ea_id)
            if not label:
                entries.append({"ea_id": ea_id, "ea_label": None, "action": "skip",
                                "reason": "EA_LABEL_UNRESOLVED"})
                continue
            ondisk = (sha256_file(_source_path(repo_root, label)) or "").lower()
            state = _ea_state(conn, ea_id, ondisk)

            # Governed repair dry-run of the NEWEST unsuperseded failure only: it is
            # the true current state.  Repairing from an older failure when the
            # newest one is AT the current source would recompile a source we know
            # fails, so an older "source-repaired" failure must never mask it.
            eligible_candidate: dict[str, Any] | None = None
            newest_reasons: list[str] = []
            source_repaired = False
            if state["failures"]:
                primary = state["failures"][0]
                g = repair_fn(primary["id"], ea_id)
                newest_reasons = g["reasons"]
                source_repaired = bool(g["new_sha"] and g["old_sha"] and g["new_sha"] != g["old_sha"])
                if g["eligible"]:
                    eligible_candidate = {**g, "predecessor_id": primary["id"]}
            is_clean = clean_fn(label)
            action, reason = decide_ea_action(
                has_done_ok_at_current=state["done_ok_at_current"],
                has_fresh_pending_at_current=state["fresh_pending_at_current"],
                repairable=eligible_candidate is not None,
                is_clean=is_clean,
                has_terminal_failure=bool(state["failures"]),
                source_repaired=source_repaired,
            )
            entry: dict[str, Any] = {
                "ea_id": ea_id,
                "ea_label": label,
                "ondisk_sha": ondisk or None,
                "clean": is_clean,
                "action": action,
                "reason": reason,
                "predecessor_work_item_id": None,
                "old_sha": None,
                "new_sha": None,
                "build_task_id": None,
                "commit": None,
                "governed_reasons": newest_reasons,
                "has_approved_card": card_present_fn(label, ea_id),
                "needs_commission": reason in (R_NEEDS_BUILD_TASK, R_NEEDS_FRESH_BUILD),
            }
            if action == "repair_successor" and eligible_candidate:
                commit = commit_fn(label)
                entry.update({
                    "predecessor_work_item_id": eligible_candidate["predecessor_id"],
                    "old_sha": eligible_candidate["old_sha"],
                    "new_sha": eligible_candidate["new_sha"],
                    "build_task_id": eligible_candidate["build_task_id"],
                    "commit": commit,
                    "rerun_reason": (
                        f"source refreshed after enqueue: {commit['short']} {commit['subject']}"
                        if commit else "source refreshed after enqueue"
                    ),
                })
            entries.append(entry)

        actionable = [e for e in entries if e["action"] == "repair_successor"]
        counts = {"targets": len(entries), "repair_successor": len(actionable)}
        for e in entries:
            if e["action"] != "repair_successor":
                counts[e["reason"]] = counts.get(e["reason"], 0) + 1
        document = {
            "schema": SCHEMA,
            "mode": "dry_run",
            "generated_at": utc_now(),
            "database": str(db_path),
            "repo": str(repo_root),
            "function": "compile_work_items.enqueue_repair_successor",
            "counts": counts,
            "targets": entries,
        }
        document["plan_sha256"] = _plan_sha256(document)
        return document
    finally:
        conn.close()


def _plan_sha256(document: dict[str, Any]) -> str:
    canonical = {
        "schema": document["schema"],
        "function": document["function"],
        "targets": [
            {
                "ea_id": e["ea_id"],
                "action": e["action"],
                "reason": e["reason"],
                "predecessor_work_item_id": e.get("predecessor_work_item_id"),
                "old_sha": e.get("old_sha"),
                "new_sha": e.get("new_sha"),
                "build_task_id": e.get("build_task_id"),
            }
            for e in document["targets"]
        ],
    }
    return sha256_bytes(json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode("utf-8"))


# ---------------------------------------------------------------------------
# apply (GOVERNED; requires --plan-sha256; NOT executed by the author)
# ---------------------------------------------------------------------------
def _backup_database(db_path: Path, backup_dir: Path) -> tuple[Path, str]:
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    dest = backup_dir / f"farm_state_before_repair_successor_{stamp}_{uuid.uuid4().hex[:8]}.sqlite"
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
    actionable = [e for e in current["targets"] if e["action"] == "repair_successor"]
    if not actionable:
        return {**current, "mode": "apply", "applied": 0, "backup": None,
                "note": "no eligible repair-successor targets; nothing to append"}
    dirty = [e["ea_label"] for e in actionable if not _git_clean(repo_root, e["ea_label"])]
    if dirty:
        raise RuntimeError(f"SOURCE_UNCOMMITTED_AT_APPLY: {dirty}")

    lock = FactoryMutationLock(mutation_lock, owner="repair_successor_stale_compile_rows_0913.apply")
    results: list[dict[str, Any]] = []
    with lock:
        backup_path, backup_sha = _backup_database(db_path, backup_dir)
        for e in actionable:
            res = cwi.enqueue_repair_successor(
                farm_root, repo_root, e["predecessor_work_item_id"],
                build_task_id=e.get("build_task_id") or None, apply=True,
            )
            results.append({
                "ea_id": e["ea_id"],
                "predecessor_work_item_id": e["predecessor_work_item_id"],
                "successor_work_item_id": res.get("successor_work_item_id"),
                "ok": res.get("ok"),
                "eligible": res.get("eligible"),
                "reasons": res.get("reasons"),
            })

    verification_errors = [
        f"{r['ea_id']}: repair-successor not created ({r.get('reasons')})"
        for r in results if not r.get("successor_work_item_id")
    ]
    receipt = {
        **current,
        "mode": "apply",
        "applied_at": utc_now(),
        "plan_sha256_verified": plan_sha256,
        "results": results,
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
    ap.add_argument("--apply", action="store_true", help="REQUIRED to write; else read-only dry run")
    ap.add_argument("--plan-sha256", help="the reviewed dry-run plan_sha256; REQUIRED with --apply")
    ap.add_argument("--ea", action="append", dest="targets", default=None,
                    help="override target EA id (repeatable); default = the skipped rows + 41179")
    ap.add_argument("--db", type=Path, default=None)
    ap.add_argument("--receipt", type=Path, default=DEFAULT_RECEIPT)
    ap.add_argument("--output", type=Path, help="also write the dry-run plan JSON here")
    args = ap.parse_args()

    if not args.apply:
        document = plan(db_path=args.db, targets=args.targets)
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
    if args.targets:
        ap.error("--ea overrides are dry-run only; --apply always uses the canonical target set")
    if args.receipt.exists():
        print(f"refusing to overwrite existing receipt: {args.receipt}")
        return 1
    receipt = apply(plan_sha256=args.plan_sha256, db_path=args.db, receipt_path=args.receipt)
    print(json.dumps(receipt, indent=2, sort_keys=True))
    print(f"\nAPPLIED. Receipt: {args.receipt}")
    return 0 if receipt.get("verification_ok", True) else 2


if __name__ == "__main__":
    raise SystemExit(main())
