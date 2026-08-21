#!/usr/bin/env python3
"""Inventory and apply reviewed dispositions for BLOCKED agent-task campaigns.

The inventory is read-only.  Apply mode consumes an explicit JSON decision
manifest and uses task state plus the original ``updated_at`` and verdict hash
as a compare-and-swap boundary.  It never infers a gate verdict.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import re
import shutil
import sqlite3
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


DEFAULT_FARM_ROOT = Path(r"D:\QM\strategy_farm")
DEFAULT_REPO_ROOT = Path(r"C:\QM\repo")
DB_REL = Path("state") / "farm_state.sqlite"
CARD_POOLS = (
    "cards_approved",
    "cards_review",
    "cards_rejected",
    "cards_recovery",
    "cards_blocked_r3_data",
    "cards_draft",
)
TERMINAL_STATES = {"PASSED", "FAILED"}


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def normalized_ea_id(value: Any) -> str | None:
    if value in (None, ""):
        return None
    match = re.fullmatch(r"(?:QM5_)?(\d+)", str(value).strip(), re.IGNORECASE)
    return match.group(1) if match else None


def task_ea_id(row: sqlite3.Row) -> str | None:
    payload = json.loads(row["payload_json"] or "{}")
    direct = normalized_ea_id(payload.get("ea_id"))
    if direct:
        return direct
    # Legacy review rows sometimes carried only a source artifact path.
    source_path = str(payload.get("source_artifact_path") or "")
    match = re.search(r"(?:^|[\\/])QM5_(\d+)(?:_|[\\/])", source_path, re.IGNORECASE)
    return match.group(1) if match else None


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def registry_maps(repo_root: Path) -> tuple[dict[str, list[dict[str, str]]], dict[str, list[dict[str, str]]]]:
    registry: dict[str, list[dict[str, str]]] = defaultdict(list)
    magic: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in read_csv_rows(repo_root / "framework" / "registry" / "ea_id_registry.csv"):
        ea_id = normalized_ea_id(row.get("ea_id"))
        if ea_id:
            registry[ea_id].append(row)
    for row in read_csv_rows(repo_root / "framework" / "registry" / "magic_numbers.csv"):
        ea_id = normalized_ea_id(row.get("ea_id"))
        if ea_id:
            magic[ea_id].append(row)
    return registry, magic


def card_map(farm_root: Path) -> dict[str, list[dict[str, str]]]:
    result: dict[str, list[dict[str, str]]] = defaultdict(list)
    artifacts = farm_root / "artifacts"
    for pool in CARD_POOLS:
        for path in sorted((artifacts / pool).glob("QM5_*.md")):
            match = re.match(r"QM5_(\d+)(?:_|\.)", path.name, re.IGNORECASE)
            if match:
                result[match.group(1)].append({"pool": pool, "path": str(path)})
    return result


def work_item_map(conn: sqlite3.Connection) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in conn.execute(
        "SELECT id, phase, ea_id, symbol, status, verdict, created_at, updated_at "
        "FROM work_items ORDER BY updated_at, id"
    ):
        ea_id = normalized_ea_id(row["ea_id"])
        if ea_id:
            result[ea_id].append(dict(row))
    return result


def ea_artifacts(repo_root: Path, ea_id: str) -> dict[str, Any]:
    roots = sorted((repo_root / "framework" / "EAs").glob(f"QM5_{ea_id}_*"))
    sources: list[str] = []
    binaries: list[str] = []
    specs: list[str] = []
    setfiles: list[str] = []
    for root in roots:
        sources.extend(str(path) for path in sorted(root.glob("*.mq5")))
        binaries.extend(str(path) for path in sorted(root.glob("*.ex5")))
        specs.extend(str(path) for path in sorted(root.glob("SPEC.md")))
        setfiles.extend(str(path) for path in sorted((root / "sets").glob("*_backtest.set")))
    return {
        "directories": [str(path) for path in roots],
        "mq5_paths": sources,
        "ex5_paths": binaries,
        "spec_paths": specs,
        "setfile_paths": setfiles,
    }


def inventory(
    *,
    farm_root: Path,
    repo_root: Path,
    task_ids: Iterable[str],
) -> dict[str, Any]:
    task_id_set = set(task_ids)
    db_path = farm_root / DB_REL
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    registry, magic = registry_maps(repo_root)
    cards = card_map(farm_root)
    work_items = work_item_map(conn)
    rows = conn.execute(
        "SELECT * FROM agent_tasks WHERE id IN ({}) ORDER BY updated_at, id".format(
            ",".join("?" for _ in task_id_set)
        ),
        sorted(task_id_set),
    ).fetchall()
    found = {row["id"] for row in rows}
    if found != task_id_set:
        raise SystemExit(f"task id mismatch: missing={sorted(task_id_set - found)}")

    items: list[dict[str, Any]] = []
    for row in rows:
        ea_id = task_ea_id(row)
        if not ea_id:
            raise SystemExit(f"task has no single resolvable ea_id: {row['id']}")
        blocked_at = row["updated_at"]
        ea_work = work_items.get(ea_id, [])
        later_done = [
            item
            for item in ea_work
            if item["status"] == "done" and item["updated_at"] > blocked_at
        ]
        open_items = [item for item in ea_work if item["status"] in {"pending", "running"}]
        registry_rows = registry.get(ea_id, [])
        magic_rows = magic.get(ea_id, [])
        item = {
            "task_id": row["id"],
            "task_type": row["task_type"],
            "assigned_agent": row["assigned_agent"],
            "priority": row["priority"],
            "state": row["state"],
            "blocked_at": blocked_at,
            "verdict_sha256": sha256_text(row["verdict"] or ""),
            "original_verdict": row["verdict"],
            "ea_id": f"QM5_{ea_id}",
            "registry": {
                "rows": registry_rows,
                "statuses": dict(Counter(entry.get("status", "") for entry in registry_rows)),
            },
            "magic": {
                "row_count": len(magic_rows),
                "active_count": sum(entry.get("status") == "active" for entry in magic_rows),
                "retired_count": sum(entry.get("status") == "retired" for entry in magic_rows),
                "symbols": sorted({entry.get("symbol", "") for entry in magic_rows}),
            },
            "cards": cards.get(ea_id, []),
            "artifacts": ea_artifacts(repo_root, ea_id),
            "work_items": {
                "total": len(ea_work),
                "done": sum(entry["status"] == "done" for entry in ea_work),
                "failed": sum(entry["status"] == "failed" for entry in ea_work),
                "open": len(open_items),
                "later_done": len(later_done),
                "deepest_phases": sorted({entry["phase"] for entry in ea_work}),
                "open_rows": open_items,
                "latest_rows": ea_work[-5:],
            },
        }
        items.append(item)
    conn.close()
    return {
        "schema": "qm.blocked-agent-task-retest-inventory.v1",
        "generated_at": utc_now(),
        "farm_db": str(db_path),
        "repo_root": str(repo_root),
        "task_count": len(items),
        "later_done_count": sum(item["work_items"]["later_done"] for item in items),
        "items": items,
    }


def load_task_ids(path: Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    values = data.get("task_ids") if isinstance(data, dict) else data
    if not isinstance(values, list) or not values:
        raise SystemExit("task-id file must be a non-empty JSON list or contain task_ids")
    return [str(value) for value in values]


def build_manifest(*, inventory_path: Path, policy_path: Path) -> dict[str, Any]:
    snapshot = json.loads(inventory_path.read_text(encoding="utf-8"))
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    items = {item["task_id"]: item for item in snapshot.get("items", [])}
    groups = policy.get("groups")
    if not isinstance(groups, list) or not groups:
        raise SystemExit("policy groups must be a non-empty list")
    assigned: dict[str, dict[str, Any]] = {}
    for group in groups:
        for task_id_value in group.get("task_ids", []):
            task_id = str(task_id_value)
            if task_id not in items:
                raise SystemExit(f"policy task is outside inventory: {task_id}")
            if task_id in assigned:
                raise SystemExit(f"policy task assigned more than once: {task_id}")
            assigned[task_id] = group
    missing = sorted(set(items) - set(assigned))
    if missing:
        raise SystemExit(f"policy does not cover inventory tasks: {missing}")

    decisions: list[dict[str, Any]] = []
    for item in snapshot["items"]:
        group = assigned[item["task_id"]]
        target_state = str(group["target_state"])
        still_true = bool(group["blocking_condition_still_true"])
        decision = {
            "task_id": item["task_id"],
            "ea_id": item["ea_id"],
            "expected_updated_at": item["blocked_at"],
            "expected_verdict_sha256": item["verdict_sha256"],
            "target_state": target_state,
            "blocking_condition_still_true": still_true,
            "reason": str(group["reason"]),
            "owner": group.get("owner"),
            "unblock_action": group.get("unblock_action"),
            "evidence": {
                "registry_statuses": item["registry"]["statuses"],
                "active_magic_rows": item["magic"]["active_count"],
                "card_pools": [entry["pool"] for entry in item["cards"]],
                "ea_directories": len(item["artifacts"]["directories"]),
                "mq5_files": len(item["artifacts"]["mq5_paths"]),
                "ex5_files": len(item["artifacts"]["ex5_paths"]),
                "spec_files": len(item["artifacts"]["spec_paths"]),
                "setfiles": len(item["artifacts"]["setfile_paths"]),
                "work_items_total": item["work_items"]["total"],
                "work_items_open": item["work_items"]["open"],
                "work_items_later_done": item["work_items"]["later_done"],
            },
        }
        if target_state == "BLOCKED" and not (
            str(decision.get("owner") or "").strip()
            and str(decision.get("unblock_action") or "").strip()
        ):
            raise SystemExit(f"BLOCKED policy lacks owner/action: {item['task_id']}")
        decisions.append(decision)
    return {
        "schema": "qm.blocked-agent-task-retest-manifest.v1",
        "campaign": str(policy["campaign"]),
        "generated_at": utc_now(),
        "source_inventory": str(inventory_path),
        "source_policy": str(policy_path),
        "decision_count": len(decisions),
        "states": dict(Counter(item["target_state"] for item in decisions)),
        "decisions": decisions,
    }


def apply_manifest(*, farm_root: Path, manifest_path: Path) -> dict[str, Any]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    decisions = manifest.get("decisions")
    if not isinstance(decisions, list) or not decisions:
        raise SystemExit("manifest decisions must be a non-empty list")
    db_path = farm_root / DB_REL
    backup_dir = farm_root / "state" / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_path = backup_dir / f"farm_state_before_blocked_retest_{stamp}.sqlite"
    shutil.copy2(db_path, backup_path)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    now = utc_now()
    applied: list[dict[str, str]] = []
    try:
        conn.execute("BEGIN IMMEDIATE")
        for decision in decisions:
            task_id = str(decision["task_id"])
            target_state = str(decision["target_state"])
            if target_state not in TERMINAL_STATES | {"BLOCKED"}:
                raise ValueError(f"unsupported target state for {task_id}: {target_state}")
            reason = str(decision["reason"]).strip()
            owner = str(decision.get("owner") or "").strip()
            action = str(decision.get("unblock_action") or "").strip()
            if target_state == "BLOCKED" and (not owner or not action):
                raise ValueError(f"BLOCKED decision lacks owner/action: {task_id}")
            row = conn.execute("SELECT * FROM agent_tasks WHERE id=?", (task_id,)).fetchone()
            if row is None:
                raise ValueError(f"task not found: {task_id}")
            expected_updated_at = str(decision["expected_updated_at"])
            expected_hash = str(decision["expected_verdict_sha256"])
            if row["state"] != "BLOCKED":
                raise ValueError(f"state changed for {task_id}: {row['state']}")
            if row["updated_at"] != expected_updated_at:
                raise ValueError(f"updated_at changed for {task_id}: {row['updated_at']}")
            if sha256_text(row["verdict"] or "") != expected_hash:
                raise ValueError(f"verdict changed for {task_id}")
            payload = json.loads(row["payload_json"] or "{}")
            payload["blocked_retest"] = {
                "campaign": str(manifest.get("campaign") or ""),
                "tested_at": now,
                "blocking_condition_still_true": bool(decision["blocking_condition_still_true"]),
                "reason": reason,
                "owner": owner or None,
                "unblock_action": action or None,
                "evidence": decision.get("evidence", {}),
            }
            if target_state == "BLOCKED":
                verdict = f"RETEST {now}: {reason} OWNER={owner}; UNBLOCK_ACTION={action}"
            else:
                verdict = f"RETEST {now}: TERMINAL_{target_state}; {reason}"
            conn.execute(
                "UPDATE agent_tasks SET state=?, verdict=?, payload_json=?, updated_at=? WHERE id=?",
                (target_state, verdict, json.dumps(payload, sort_keys=True, separators=(",", ":")), now, task_id),
            )
            idempotency_key = f"blocked-retest:{manifest.get('campaign')}:{task_id}:{expected_hash}"
            conn.execute(
                """
                INSERT INTO agent_task_transition_ledger
                    (idempotency_key, ts, task_id, action, from_state, to_state, reason, detail_json)
                VALUES (?, ?, ?, 'blocked_retest', 'BLOCKED', ?, ?, ?)
                """,
                (
                    idempotency_key,
                    now,
                    task_id,
                    target_state,
                    reason,
                    json.dumps(
                        {"owner": owner or None, "unblock_action": action or None},
                        sort_keys=True,
                        separators=(",", ":"),
                    ),
                ),
            )
            applied.append({"task_id": task_id, "state": target_state})
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    return {
        "schema": "qm.blocked-agent-task-retest-apply.v1",
        "applied_at": now,
        "backup_path": str(backup_path),
        "applied_count": len(applied),
        "states": dict(Counter(item["state"] for item in applied)),
        "items": applied,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO_ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    inv = sub.add_parser("inventory")
    inv.add_argument("--task-ids", type=Path, required=True)
    inv.add_argument("--output", type=Path)
    manifest = sub.add_parser("manifest")
    manifest.add_argument("--inventory", type=Path, required=True)
    manifest.add_argument("--policy", type=Path, required=True)
    manifest.add_argument("--output", type=Path)
    apply_cmd = sub.add_parser("apply")
    apply_cmd.add_argument("--manifest", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.command == "inventory":
        result = inventory(
            farm_root=args.farm_root,
            repo_root=args.repo_root,
            task_ids=load_task_ids(args.task_ids),
        )
    elif args.command == "manifest":
        result = build_manifest(inventory_path=args.inventory, policy_path=args.policy)
    else:
        result = apply_manifest(farm_root=args.farm_root, manifest_path=args.manifest)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    output = getattr(args, "output", None)
    if output:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
