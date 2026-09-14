#!/usr/bin/env python
"""Governed DRY-RUN planner for stale artifact bindings on PENDING work_items.

Context (docs/ops/evidence/2026-09-13_artifact_binding_drift/): the
``pending_artifact_binding_drift`` health check flags pending rows whose pinned
``expected_ex5/mq5/setfile_sha256`` no longer match the on-disk artifact.  Most
of the noise (cluster C1) is a path-derivation false positive already fixed in
``health.py``.  The genuine drift is cluster **C2A**: real EAs whose mq5 / set /
ex5 were regenerated **and committed** after the row bound its SHAs.  Those rows
span Q02..Q14, so ``farmctl requalify-q02`` / ``rebind-q02`` (Q02-only, terminal
sources) refuse them with ``source_not_eligible_q02_pending_or_terminal``.

This tool does NOT mutate anything.  It reads ``plan.json`` (the C2A row list),
reads the live DB read-only, hashes the current on-disk artifacts, and emits a
content-addressed DRY-RUN rebind plan: per row, per binding role, the bound SHA
vs the current SHA, a classification (OK / DRIFT / MISSING), the committed
provenance of the current file, and the exact governed successor command that a
*separately blessed* apply mechanism would run.  ``--apply`` is intentionally
NOT implemented: rebinding a pending row's pinned SHA is a mutation that requires
orchestrator REVIEW and an established, backed-up, receipted apply path.  This
planner never claims that authority.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any

SCHEMA = "qm.pending-binding-rebind-plan.v1"
C2A_CLUSTER = "C2A_COMMITTED_REGENERATION_STALE_BINDING"

# binding role -> payload key carrying the pinned SHA
ROLE_SHA_KEY = {
    "ex5": "expected_ex5_sha256",
    "mq5": "expected_mq5_sha256",
    "setfile": "expected_setfile_sha256",
}


def _sha256_file(path: Path) -> "str | None":
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def _ea_dir_name(payload: dict, setfile_path: "str | None") -> "str | None":
    name = payload.get("ea_dir_name")
    if name:
        return str(name)
    if setfile_path:
        # framework/EAs/<ea_dir>/sets/<file>.set -> parent.parent.name
        try:
            return Path(setfile_path).parent.parent.name
        except (OSError, ValueError):
            return None
    return None


def _role_paths(repo_root: Path, ea_dir: "str | None", setfile_path: "str | None") -> "dict[str, Path | None]":
    paths: "dict[str, Path | None]" = {"ex5": None, "mq5": None, "setfile": None}
    if ea_dir:
        base = repo_root / "framework" / "EAs" / ea_dir / ea_dir
        paths["ex5"] = base.with_suffix(".ex5")
        paths["mq5"] = base.with_suffix(".mq5")
    if setfile_path:
        paths["setfile"] = Path(setfile_path)
    return paths


def _git_last_commit(repo_root: Path, path: Path) -> "dict[str, str] | None":
    """Best-effort provenance of the current on-disk artifact (HEAD commit)."""
    try:
        rel = path.resolve()
        out = subprocess.run(
            ["git", "-C", str(repo_root), "log", "-1",
             "--format=%h\t%cI\t%s", "--", str(rel)],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    line = (out.stdout or "").strip()
    if out.returncode != 0 or not line:
        return None
    parts = line.split("\t", 2)
    if len(parts) < 3:
        return None
    return {"commit": parts[0], "committed_at": parts[1], "subject": parts[2]}


def _classify_role(bound_sha: "str | None", current_sha: "str | None") -> str:
    if bound_sha is None:
        return "NOT_BOUND"
    if current_sha is None:
        return "MISSING"
    return "OK" if bound_sha == current_sha else "DRIFT"


def build_plan_row(
    row_meta: dict,
    db_row: "sqlite3.Row | None",
    repo_root: Path,
    *,
    with_git: bool = True,
) -> dict:
    """One dry-run plan entry for one C2A work_item row (pure, no mutation)."""
    wi_id = row_meta.get("id")
    result: dict[str, Any] = {
        "work_item_id": wi_id,
        "ea": row_meta.get("ea"),
        "phase": row_meta.get("phase"),
        "symbol": row_meta.get("symbol"),
        "hold_code": row_meta.get("hold_code"),
        "held": row_meta.get("held"),
    }
    if db_row is None:
        result["status"] = "ROW_NOT_FOUND_IN_DB"
        result["rebind_eligible"] = False
        return result

    result["db_status"] = db_row["status"]
    payload = json.loads(db_row["payload_json"] or "{}")
    setfile_path = db_row["setfile_path"]
    ea_dir = _ea_dir_name(payload, setfile_path)
    result["ea_dir_name"] = ea_dir
    paths = _role_paths(repo_root, ea_dir, setfile_path)

    bindings: dict[str, Any] = {}
    any_drift = False
    any_missing = False
    for role, sha_key in ROLE_SHA_KEY.items():
        bound = payload.get(sha_key)
        if bound is None:
            continue  # role not bound on this row
        path = paths.get(role)
        current = _sha256_file(path) if path is not None else None
        cls = _classify_role(bound, current)
        entry: dict[str, Any] = {
            "path": str(path) if path else None,
            "bound_sha256": bound,
            "current_sha256": current,
            "classification": cls,
        }
        if cls == "DRIFT":
            any_drift = True
            if with_git and path is not None:
                entry["current_provenance"] = _git_last_commit(repo_root, path)
        elif cls == "MISSING":
            any_missing = True
        bindings[role] = entry

    result["bindings"] = bindings
    # A row is a rebind candidate only when it is still pending, drifts on at
    # least one bound role, and no bound role is MISSING (a MISSING artifact is
    # a lost-file problem, not a stale-binding one -> route elsewhere).
    is_pending = db_row["status"] == "pending"
    result["rebind_eligible"] = bool(is_pending and any_drift and not any_missing)
    if any_missing:
        result["blocked_reason"] = "artifact_missing_on_disk"
    elif not any_drift:
        result["blocked_reason"] = "no_drift_already_current"
    elif not is_pending:
        result["blocked_reason"] = f"row_not_pending:{db_row['status']}"
    else:
        # exact governed successor the blessed apply path would run per role.
        cmds = []
        for role, entry in bindings.items():
            if entry["classification"] != "DRIFT":
                continue
            cmds.append(
                "python -X utf8 tools/strategy_farm/farmctl.py requalify-q02 "
                f"--old-work-item-id {wi_id} "
                f"--expected-current-{'ex5' if role=='ex5' else role}-sha256 {entry['current_sha256']} "
                "--reason \"C2A committed-regen stale binding rebind\" --dry-run  # then blessed --apply"
                if role in ("ex5",)
                else
                "# setfile/mq5 rebind: farmctl requeue-false-invalid-setfile "
                f"(--old-work-item-id {wi_id}) or phase-specific governed successor; dry-run first"
            )
        result["proposed_successor_commands"] = cmds
        result["note"] = (
            "Rebind is a mutation of a pinned SHA on a live pending row: requires "
            "orchestrator REVIEW + an established backed-up/receipted apply path. "
            "This planner does NOT apply. If the on-disk binary is a recompile "
            "(not a faithful rebuild), rebinding is ROT -> OWNER."
        )
    return result


def build_plan(plan_path: Path, db_path: Path, repo_root: Path, *, with_git: bool = True) -> dict:
    data = json.loads(plan_path.read_text(encoding="utf-8"))
    c2a_rows = [r for r in data.get("rows", []) if r.get("cause_cluster") == C2A_CLUSTER]
    con = sqlite3.connect(f"file:{db_path}?mode=ro&immutable=1", uri=True)
    con.row_factory = sqlite3.Row
    try:
        entries = []
        for meta in c2a_rows:
            db_row = con.execute(
                "SELECT * FROM work_items WHERE id=?", (meta.get("id"),)
            ).fetchone()
            entries.append(build_plan_row(meta, db_row, repo_root, with_git=with_git))
    finally:
        con.close()

    eligible = [e for e in entries if e.get("rebind_eligible")]
    body = {
        "schema": SCHEMA,
        "mode": "DRY_RUN_ONLY_NOT_APPLIED",
        "source_plan": str(plan_path),
        "database": str(db_path),
        "cluster": C2A_CLUSTER,
        "c2a_rows_total": len(c2a_rows),
        "rebind_eligible_count": len(eligible),
        "entries": entries,
    }
    body_json = json.dumps(body, sort_keys=True, ensure_ascii=False)
    body["plan_sha256"] = hashlib.sha256(body_json.encode("utf-8")).hexdigest()
    return body


def main(argv: "list[str] | None" = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--plan", required=True, type=Path,
                    help="artifact-binding-drift plan.json (carries the C2A rows)")
    ap.add_argument("--db", required=True, type=Path, help="farm_state.sqlite (read-only)")
    ap.add_argument("--repo-root", type=Path, default=Path("C:/QM/repo"))
    ap.add_argument("--out", type=Path, help="write the dry-run plan JSON here")
    ap.add_argument("--no-git", action="store_true", help="skip git provenance lookups")
    ap.add_argument("--apply", action="store_true",
                    help="REFUSED: apply requires orchestrator REVIEW + a blessed apply path")
    args = ap.parse_args(argv)

    if args.apply:
        sys.stderr.write(
            "REFUSED: pending-binding rebind is a mutation of a pinned SHA on a live "
            "row. This planner is dry-run only. Route apply through the reviewed, "
            "backed-up, receipted governed mechanism after orchestrator REVIEW.\n"
        )
        return 2

    plan = build_plan(args.plan, args.db, args.repo_root, with_git=not args.no_git)
    text = json.dumps(plan, indent=2, ensure_ascii=False)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
    sys.stdout.write(
        f"C2A rows: {plan['c2a_rows_total']}  rebind-eligible: "
        f"{plan['rebind_eligible_count']}  plan_sha256: {plan['plan_sha256']}\n"
    )
    if not args.out:
        sys.stdout.write(text + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
