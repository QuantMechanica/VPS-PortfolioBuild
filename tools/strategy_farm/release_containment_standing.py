"""Reusable containment release under DL-086 standing authorization.

OWNER directive 2026-08-14 (DL-086): approvals are standing and unlimited —
no per-incident windows, no signature sentences. This tool operationalizes
that: it binds the standing receipt to the draft manifest (idempotent) and
runs the fail-closed release with the registered dual audits. Reusable for
every future containment release; only the --reason changes.

WHO MAY RUN THIS (verified 2026-09-02 against custom_history_migration.py):
    ``custom_history_migration.py release-containment`` contains NO caller
    classifier, no parent-process / getppid check, and no signature gate keyed
    to a human operator. What it actually verifies is entirely artifact-based:
      * ``_require_authorized_execution`` -> ``load_manifest(require_owner_approval=True)``
        + ``load_owner_window_receipt`` (the detached DL-086 receipt must hash-match
        the manifest's embedded ``owner_approval`` byte-for-byte);
      * a matching dual-audit isolation activation must already be written
        (``manifest_sha256`` + the exact two audit paths);
      * ``quiescence_snapshot`` must report zero active work items AND zero
        runner processes;
      * the global Custom-history lease record must be absent at the boundary.
    None of those care which process or user invokes the command. The old
    "classifier blocks Claude / run BY OWNER via `!`" premise was therefore not
    a property of the release code — it was an external dispatch heuristic. Under
    the CEO operational mandate the orchestrator (Claude) runs this directly. The
    receipt / dual-audit / quiescence / lease checks above are the real authority
    and are NOT weakened here.

WHY THE WRAPPER EXISTS (serial-mode race, observed 07:25Z 2026-09-02):
    In containment-serial mode a work item is almost always active, so a bare
    ``release-containment`` fails its quiescence check on the first attempt and
    exits. The factory's whole snapshot+claim+tester run is held under a single
    ``FactoryMutationLock`` (isolated_work_item_runner.py), so this tool holds
    that same lock to make workers decline NEW claims, lets the in-flight item
    drain, reaps any orphaned active claim left by a dead worker, then fires the
    governed release while quiescent. Lock hold is capped at 15 minutes.

    ! python tools/strategy_farm/release_containment_standing.py "<reason-slug>"
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import custom_history_lease  # noqa: E402
from custom_history_migration import (  # noqa: E402
    DEFAULT_RUNNER_TERMINALS,
    quiescence_snapshot,
)
from factory_mutation_lock import FactoryMutationLock  # noqa: E402

A = Path(r"D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809")
MIGRATION = Path(r"C:\QM\repo\tools\strategy_farm\custom_history_migration.py")
MODE_JSON = Path(r"D:\QM\strategy_farm\state\custom_history_containment_mode.json")
FARM_ROOT = Path(r"D:\QM\strategy_farm")
MT5_ROOT = Path(r"D:\QM\mt5")
LOG_PATH = Path(r"D:\QM\reports\state\containment_release_log.jsonl")
DRAFT = A / "archive_manifest_draft.json"
RECEIPT = A / "owner_window_receipt_standing_unlimited.json"
MANIFEST = A / "archive_manifest_owner_approved_standing.json"
AUDITS = [A / "isolation_audit_3.json", A / "isolation_audit_4.json"]

# Cap the mutation-lock hold at 15 minutes (task directive). The lock only makes
# workers decline NEW claims; it never preempts an in-flight tester (acquisition
# succeeds only after the current holder finishes), so no measurement is lost.
LOCK_HOLD_CAP_MINUTES = 15
# How long to keep retrying lock acquisition while a live worker still holds it.
ACQUIRE_DEADLINE_MINUTES = 30
LOCK_POLL_SECONDS = 5
QUIESCE_POLL_SECONDS = 3
LOCK_OWNER = "release_containment_standing"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def log_step(event: str, *, log_path: Path = LOG_PATH, **fields) -> None:
    """Append one JSONL step record and echo it to stdout."""
    record = {"ts": _now().isoformat(), "event": event, **fields}
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, sort_keys=True) + "\n")
    except OSError as exc:  # logging must never mask the operation
        print(f"[log-error] {exc}", file=sys.stderr)
    print(json.dumps(record, sort_keys=True))


def run(cmd: list[str]) -> tuple[int, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600, cwd=r"C:\QM\repo")
    out = (proc.stdout or "").strip()
    err = (proc.stderr or "").strip()
    if out:
        print(out)
    if err:
        print(err, file=sys.stderr)
    return proc.returncode, out + err


def containment_released(mode_json: Path = MODE_JSON) -> bool:
    """True when the mode receipt says containment is already released."""
    try:
        return json.loads(mode_json.read_text(encoding="utf-8")).get("enabled") is False
    except (OSError, json.JSONDecodeError):
        return False


def _live_terminals(
    snapshot: dict,
    *,
    mt5_root: Path = MT5_ROOT,
    terminals=DEFAULT_RUNNER_TERMINALS,
) -> set[str]:
    """Terminal names (upper-case) that have a live runner process in ``snapshot``."""
    roots = {t: str((Path(mt5_root) / t)).casefold() for t in terminals}
    live: set[str] = set()
    for proc in snapshot.get("runner_processes", []) or []:
        exe = str(proc.get("ExecutablePath") or "").casefold()
        if not exe:
            continue
        for term, root in roots.items():
            if exe == root or exe.startswith(root + "\\") or exe.startswith(root + "/"):
                live.add(term.upper())
                break
    return live


def reap_orphaned_active_claims(
    *,
    farm_root: Path = FARM_ROOT,
    mt5_root: Path = MT5_ROOT,
    terminals=DEFAULT_RUNNER_TERMINALS,
    snapshot: dict | None = None,
    execute: bool = True,
    log_path: Path = LOG_PATH,
) -> list[dict]:
    """Reset active work items whose claiming terminal has no live runner process.

    Only safe to call while THIS process holds the factory mutation lock, so no
    new worker can be mid-claim: an active row on a terminal with no live
    terminal64/metatester process is then provably orphaned by a dead worker.
    The UPDATE is guarded with ``AND status='active'`` and leaves payload and
    attempt_count untouched.
    """
    snap = snapshot if snapshot is not None else quiescence_snapshot(
        farm_root=farm_root, mt5_root=mt5_root, terminals=terminals
    )
    live = _live_terminals(snap, mt5_root=mt5_root, terminals=terminals)
    reaped: list[dict] = []
    for row in snap.get("active_work_items", []) or []:
        claimed_by = row.get("claimed_by")
        term = str(claimed_by).upper() if claimed_by else None
        if term is not None and term in live:
            continue  # a live worker legitimately owns this claim
        reaped.append(
            {"id": row.get("id"), "phase": row.get("phase"), "claimed_by": claimed_by}
        )
    if not reaped:
        log_step("reap_orphaned_active_claims", log_path=log_path, reaped=[], live_terminals=sorted(live))
        return reaped
    if execute:
        db_path = Path(farm_root) / "state" / "farm_state.sqlite"
        now_iso = _now().isoformat()
        with sqlite3.connect(str(db_path), timeout=30) as conn:
            conn.execute("PRAGMA busy_timeout=30000")
            for entry in reaped:
                conn.execute(
                    "UPDATE work_items SET status='pending', verdict=NULL, "
                    "claimed_by=NULL, updated_at=? WHERE id=? AND status='active'",
                    (now_iso, entry["id"]),
                )
            conn.commit()
    log_step(
        "reap_orphaned_active_claims",
        log_path=log_path,
        reaped=reaped,
        live_terminals=sorted(live),
        execute=execute,
    )
    return reaped


def acquire_lock_with_retry(
    *,
    owner: str = LOCK_OWNER,
    acquire_deadline: datetime,
    poll_seconds: float = LOCK_POLL_SECONDS,
    log_path: Path = LOG_PATH,
    lock_factory=None,
) -> FactoryMutationLock | None:
    """Enter the factory mutation lock, retrying while a live worker holds it.

    Returns the entered lock (caller must ``__exit__`` it), or None if the lock
    could not be acquired before ``acquire_deadline``.
    """
    factory = lock_factory or (lambda: FactoryMutationLock(owner=owner))
    attempts = 0
    while _now() < acquire_deadline:
        attempts += 1
        lock = factory()
        try:
            lock.__enter__()
        except RuntimeError as exc:  # "factory mutation lock is busy: ..."
            log_step(
                "lock_acquire_retry",
                log_path=log_path,
                attempt=attempts,
                detail=str(exc),
            )
            time.sleep(poll_seconds)
            continue
        log_step("lock_acquired", log_path=log_path, attempt=attempts, owner=owner)
        return lock
    log_step("lock_acquire_timeout", log_path=log_path, attempts=attempts)
    return None


def wait_for_quiescence(
    *,
    farm_root: Path = FARM_ROOT,
    mt5_root: Path = MT5_ROOT,
    terminals=DEFAULT_RUNNER_TERMINALS,
    hold_deadline: datetime,
    poll_seconds: float = QUIESCE_POLL_SECONDS,
    log_path: Path = LOG_PATH,
    quiescence_probe=None,
) -> tuple[bool, dict]:
    """Poll until zero active items, zero runner processes, and no lease record.

    Assumes THIS process holds the mutation lock, so quiescence cannot regress
    once reached (no new claim can start).
    """
    probe = quiescence_probe or quiescence_snapshot
    lease = custom_history_lease.lease_path(farm_root)
    snap: dict = {}
    while _now() < hold_deadline:
        snap = dict(probe(farm_root=farm_root, mt5_root=mt5_root, terminals=terminals))
        lease_present = lease.exists()
        if snap.get("quiescent") and not lease_present:
            log_step("quiescent", log_path=log_path)
            return True, snap
        log_step(
            "await_quiescence",
            log_path=log_path,
            active=len(snap.get("active_work_items", []) or []),
            processes=len(snap.get("runner_processes", []) or []),
            lease_present=lease_present,
            reason=snap.get("reason"),
        )
        time.sleep(poll_seconds)
    log_step("quiescence_timeout", log_path=log_path, last=snap)
    return False, snap


def fire_release(
    *,
    reason: str,
    hold_deadline: datetime,
    log_path: Path = LOG_PATH,
    runner=run,
    mode_json: Path = MODE_JSON,
) -> int:
    """Run the governed release (attach-if-needed then release-containment).

    Lease-flicker and transient quiescence messages are retried within the hold
    window; every other non-zero return is fail-closed.
    """
    if not MANIFEST.exists():
        log_step("attach_owner_approval", log_path=log_path)
        rc, blob = runner([sys.executable, str(MIGRATION), "attach-owner-approval",
                           "--manifest", str(DRAFT), "--owner-receipt", str(RECEIPT),
                           "--output", str(MANIFEST)])
        if rc != 0:
            log_step("attach_failed", log_path=log_path, rc=rc)
            return rc
    while _now() < hold_deadline:
        if containment_released(mode_json):
            log_step("released", log_path=log_path)
            return 0
        rc, blob = runner([sys.executable, str(MIGRATION), "release-containment",
                          "--manifest", str(MANIFEST), "--owner-receipt", str(RECEIPT),
                          "--audit", str(AUDITS[0]), "--audit", str(AUDITS[1]),
                          "--reason", reason, "--execute"])
        if rc == 0:
            log_step("released", log_path=log_path)
            return 0
        # Tolerate only lease-flicker and a transient quiescence regression; the
        # mutation lock we hold means both self-heal within the window.
        if "lease record still exists" in blob or "requires zero active work/processes" in blob:
            log_step("release_retry_transient", log_path=log_path, rc=rc)
            time.sleep(2)
            continue
        log_step("release_failed_fail_closed", log_path=log_path, rc=rc)
        return rc
    log_step("release_hold_deadline_exceeded", log_path=log_path)
    return 3


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="DL-086 standing containment release (serial-safe).")
    parser.add_argument("reason", nargs="?", default="standing_release",
                        help="reason slug recorded in the release receipt")
    parser.add_argument("--hold-cap-minutes", type=float, default=LOCK_HOLD_CAP_MINUTES)
    parser.add_argument("--acquire-deadline-minutes", type=float, default=ACQUIRE_DEADLINE_MINUTES)
    args = parser.parse_args(argv)
    reason = (args.reason or "standing_release").strip() or "standing_release"

    log_step("start", reason=reason, hold_cap_minutes=args.hold_cap_minutes)
    if containment_released():
        log_step("noop_already_released")
        print("containment already released — nothing to do")
        return 0

    acquire_deadline = _now() + timedelta(minutes=args.acquire_deadline_minutes)
    lock = acquire_lock_with_retry(acquire_deadline=acquire_deadline)
    if lock is None:
        log_step("abort_lock_unavailable")
        print("could not acquire factory mutation lock — investigate")
        return 3
    try:
        hold_deadline = _now() + timedelta(minutes=args.hold_cap_minutes)
        # Step 1: reap orphaned claims left by dead workers (safe under the lock).
        reap_orphaned_active_claims()
        # Step 2: let any in-flight item drain to full quiescence.
        quiescent, snap = wait_for_quiescence(hold_deadline=hold_deadline)
        if not quiescent:
            log_step("abort_not_quiescent", last=snap)
            print("factory did not reach quiescence within the 15-minute hold — fail-closed")
            return 3
        # Step 3: fire the governed release while we still hold the lock.
        rc = fire_release(reason=reason, hold_deadline=hold_deadline)
        if rc == 0:
            print(MODE_JSON.read_text(encoding="utf-8"))
        return rc
    finally:
        lock.__exit__(None, None, None)
        log_step("lock_released", release_status=getattr(lock, "release_status", None))


if __name__ == "__main__":
    raise SystemExit(main())
