"""Classify and drain recovery backlogs through existing bounded mechanisms.

Default mode is read-only.  Mutating waves require an exact defect class and a
positive limit, then delegate to agent_router.reconcile_task_exits,
sweep_enqueue_built_eas.py, or requeue_stranded_infra.py.  This module does not
invent a fourth queue transition and never synthesizes a gate verdict.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import sqlite3
import subprocess
import sys
from collections import Counter
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import agent_router
except ModuleNotFoundError:  # pragma: no cover
    from tools.strategy_farm import agent_router


SCHEMA = "qm.drain_backlog.v1"
APPLY_CLASSES = (
    "RECYCLE_BUILD_NEEDS_REBUILD",
    "RECYCLE_REVIEW",
    "RECYCLE_BUILD_BUILT_NEVER_GATED",
    "ACTIVE_EA_BUILT_NEVER_GATED",
    "INFRA_STRANDED_RETRY",
)
TERMINAL_AGENT_STATES = {"PASSED", "FAILED"}
RECYCLE_REVIEW_TYPES = {"review_ea", "codex_review"}


@dataclass(frozen=True)
class Config:
    farm_root: Path
    repo_root: Path
    db: Path
    eas_root: Path
    registry: Path
    receipt_dir: Path

    @classmethod
    def build(
        cls,
        *,
        farm_root: Path,
        repo_root: Path,
        db: Path | None = None,
        receipt_dir: Path | None = None,
    ) -> "Config":
        return cls(
            farm_root=farm_root,
            repo_root=repo_root,
            db=db or farm_root / "state" / "farm_state.sqlite",
            eas_root=repo_root / "framework" / "EAs",
            registry=repo_root / "framework" / "registry" / "ea_id_registry.csv",
            receipt_dir=receipt_dir or repo_root / "docs" / "ops" / "evidence",
        )


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _connect_ro(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True, timeout=10)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA query_only=ON")
    return con


def _table_exists(con: sqlite3.Connection, table: str) -> bool:
    return con.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)
    ).fetchone() is not None


def _task_ea_id(row: sqlite3.Row) -> str | None:
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except (TypeError, json.JSONDecodeError):
        payload = {}
    raw = payload.get("ea_id") or payload.get("card_id")
    match = re.search(r"(?:QM5_)?(\d{3,6})", str(raw or ""), re.IGNORECASE)
    if not match:
        return None
    return f"QM5_{int(match.group(1))}"


def _canonical_q_phase(value: object) -> str:
    phase = str(value or "").strip().upper()
    match = re.fullmatch(r"[PQ](\d+)", phase)
    return f"Q{int(match.group(1)):02d}" if match else phase


def _registry(cfg: Config) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    with cfg.registry.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            match = re.search(r"(\d+)", str(row.get("ea_id") or ""))
            if not match:
                continue
            out[f"QM5_{int(match.group(1))}"] = {
                "status": str(row.get("status") or "").strip().lower(),
                "slug": str(row.get("slug") or "").strip(),
            }
    return out


def _ea_dirs(cfg: Config) -> dict[str, list[Path]]:
    out: dict[str, list[Path]] = {}
    if not cfg.eas_root.exists():
        return out
    for path in cfg.eas_root.iterdir():
        if not path.is_dir() or "_obsolete_" in path.name.lower():
            continue
        match = re.match(r"QM5_(\d+)", path.name, re.IGNORECASE)
        if match:
            out.setdefault(f"QM5_{int(match.group(1))}", []).append(path)
    return out


def _artifact_state(
    ea_id: str,
    *,
    registry: dict[str, dict[str, str]],
    dirs: dict[str, list[Path]],
) -> dict[str, Any]:
    choices = dirs.get(ea_id, [])
    reg = registry.get(ea_id, {})
    wanted = f"{ea_id}_{reg.get('slug', '')}"
    chosen = next((path for path in choices if path.name == wanted), choices[0] if choices else None)
    return {
        "ea_dir": str(chosen) if chosen else None,
        "has_mq5": bool(chosen and any(chosen.glob("*.mq5"))),
        "has_ex5": bool(chosen and any(chosen.glob("*.ex5"))),
        "has_setfiles": bool(chosen and (chosen / "sets").is_dir() and any((chosen / "sets").glob("*_backtest.set"))),
        "registry_status": reg.get("status"),
    }


def _classify_recycle(
    row: sqlite3.Row,
    *,
    artifact: dict[str, Any],
    work_state: dict[str, dict[str, int]],
) -> str:
    if row["task_type"] in RECYCLE_REVIEW_TYPES:
        return "RECYCLE_REVIEW"
    if row["task_type"] != "build_ea":
        return "RECYCLE_OTHER"
    ea_id = _task_ea_id(row)
    state = work_state.get(ea_id or "", {})
    # Mandatory filter: compiled + any done row is already gated, regardless of
    # what the stale agent-task state suggests.
    if artifact["has_ex5"] and state.get("done", 0) > 0:
        return "RECYCLE_BUILD_ALREADY_GATED"
    if str(row["assigned_agent"] or "").lower() == "gemini":
        return "RECYCLE_BUILD_GEMINI_REVIEW_REQUIRED"
    if state.get("open", 0) > 0:
        return "RECYCLE_BUILD_PIPELINE_IN_FLIGHT"
    if artifact["has_ex5"] and artifact["has_setfiles"]:
        return "RECYCLE_BUILD_BUILT_NEVER_GATED"
    if artifact["has_mq5"] and not artifact["has_ex5"]:
        return "RECYCLE_BUILD_NEEDS_REBUILD"
    return "RECYCLE_BUILD_INCOMPLETE"


def classify(cfg: Config, *, include_rows: bool = True) -> dict[str, Any]:
    registry = _registry(cfg)
    dirs = _ea_dirs(cfg)
    records: list[dict[str, Any]] = []
    with closing(_connect_ro(cfg.db)) as con:
        work_state: dict[str, dict[str, int]] = {}
        work_eas: set[str] = set()
        if _table_exists(con, "work_items"):
            for row in con.execute(
                "SELECT ea_id, status, COUNT(*) n FROM work_items GROUP BY ea_id, status"
            ):
                ea_id = str(row["ea_id"])
                work_eas.add(ea_id)
                bucket = work_state.setdefault(ea_id, {})
                status = str(row["status"])
                bucket[status] = int(row["n"])
                if status in {"pending", "active"}:
                    bucket["open"] = bucket.get("open", 0) + int(row["n"])

            for row in con.execute(
                "SELECT id, phase, ea_id, symbol, status, created_at FROM work_items "
                "WHERE status IN ('pending','active') ORDER BY created_at,id"
            ):
                records.append({
                    "class": "WORK_ITEM_IN_FLIGHT",
                    "entity_kind": "work_item",
                    "id": str(row["id"]),
                    "ea_id": str(row["ea_id"]),
                    "phase": _canonical_q_phase(row["phase"]),
                    "symbol": str(row["symbol"]),
                    "state": str(row["status"]),
                    "sort_at": str(row["created_at"] or ""),
                })

        if _table_exists(con, "agent_tasks"):
            for row in con.execute(
                "SELECT * FROM agent_tasks ORDER BY updated_at,id"
            ):
                state = str(row["state"])
                if state in TERMINAL_AGENT_STATES:
                    continue
                ea_id = _task_ea_id(row)
                artifact = _artifact_state(ea_id, registry=registry, dirs=dirs) if ea_id else {
                    "ea_dir": None, "has_mq5": False, "has_ex5": False,
                    "has_setfiles": False, "registry_status": None,
                }
                if state == "RECYCLE":
                    defect = _classify_recycle(
                        row, artifact=artifact, work_state=work_state
                    )
                elif state in {"APPROVED", "PIPELINE", "BLOCKED"}:
                    defect = f"AGENT_{state}_LIMBO"
                else:
                    defect = "AGENT_ROUTER_ACTIVE"
                records.append({
                    "class": defect,
                    "entity_kind": "agent_task",
                    "id": str(row["id"]),
                    "ea_id": ea_id,
                    "task_type": str(row["task_type"]),
                    "assigned_agent": str(row["assigned_agent"] or ""),
                    "state": state,
                    "sort_at": str(row["updated_at"] or ""),
                    **artifact,
                })

        # Active registry rows with no work-item history are the true never-gated
        # EA population.  Artifact prerequisites are classified, not bypassed.
        for ea_id, reg in registry.items():
            if reg["status"] != "active" or ea_id in work_eas:
                continue
            artifact = _artifact_state(ea_id, registry=registry, dirs=dirs)
            if artifact["has_ex5"] and artifact["has_setfiles"]:
                defect = "ACTIVE_EA_BUILT_NEVER_GATED"
            elif not artifact["has_ex5"]:
                defect = "ACTIVE_EA_MISSING_EX5"
            else:
                defect = "ACTIVE_EA_MISSING_SETFILES"
            records.append({
                "class": defect,
                "entity_kind": "ea",
                "id": ea_id,
                "ea_id": ea_id,
                "state": "active",
                "sort_at": ea_id,
                **artifact,
            })

    # Reuse MNT-007's read-only classifier for terminal INFRA rows that are
    # logically stranded.  It owns progression, poison, and retirement rules.
    try:
        try:
            import requeue_stranded_infra as stranded
        except ModuleNotFoundError:  # pragma: no cover
            from tools.strategy_farm import requeue_stranded_infra as stranded
        scfg = stranded.Config.build(
            db=cfg.db,
            eas_root=cfg.eas_root,
            registry_path=cfg.registry,
            wi_reports_root=cfg.farm_root.parent / "reports" / "work_items",
        )
        census = stranded._health_census(scfg)
        for case in census.get("current_cases", []):
            records.append({
                "class": f"INFRA_STRANDED_{case.get('disposition', 'UNKNOWN')}",
                "entity_kind": "infra_group",
                "id": str(case.get("work_item_id") or case.get("id") or ""),
                "ea_id": str(case.get("ea_id") or ""),
                "phase": str(case.get("phase") or ""),
                "symbol": str(case.get("symbol") or ""),
                "state": str(case.get("disposition") or "UNKNOWN"),
                "reason": str(case.get("reason") or ""),
                "sort_at": str(case.get("updated_at") or ""),
            })
        infra_summary = {
            "invariant": census.get("invariant"),
            "disposition_totals": census.get("disposition_totals"),
            "current_infra_only_total": census.get("current_infra_only_total"),
        }
    except (OSError, sqlite3.Error, RuntimeError, ValueError) as exc:
        infra_summary = {"error": repr(exc), "status": "UNKNOWN"}

    records.sort(key=lambda row: (str(row["class"]), str(row.get("sort_at") or ""), str(row["id"])))
    counts = dict(sorted(Counter(row["class"] for row in records).items()))
    result = {
        "schema": SCHEMA,
        "generated_at_utc": _utc_now(),
        "read_only": True,
        "counts": counts,
        "total_classified": len(records),
        "infra_census": infra_summary,
        "samples": {
            name: [row for row in records if row["class"] == name][:5]
            for name in counts
        },
    }
    if include_rows:
        result["rows"] = records
    return result


def _queue_counts(db: Path) -> dict[str, int]:
    with closing(_connect_ro(db)) as con:
        return {
            str(row["status"]): int(row["n"])
            for row in con.execute(
                "SELECT status,COUNT(*) n FROM work_items GROUP BY status"
            )
        }


def _receipt_path(cfg: Config, defect_class: str, wave_id: str) -> Path:
    if not re.fullmatch(r"[A-Za-z0-9._-]+", wave_id):
        raise ValueError("--wave-id must contain only letters, digits, dot, underscore, or hyphen")
    return cfg.receipt_dir / f"drain_wave_{defect_class.lower()}_{wave_id}.json"


def _write_receipt(cfg: Config, receipt: dict[str, Any], target: Path) -> Path:
    cfg.receipt_dir.mkdir(parents=True, exist_ok=True)
    temp = target.with_suffix(target.suffix + ".tmp")
    temp.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temp, target)
    return target


def _selected(snapshot: dict[str, Any], defect_class: str, limit: int) -> list[dict[str, Any]]:
    return [row for row in snapshot["rows"] if row["class"] == defect_class][:limit]


def _apply_recycle(cfg: Config, defect_class: str, rows: list[dict[str, Any]], limit: int) -> dict[str, Any]:
    task_ids = [row["id"] for row in rows]
    if not task_ids:
        return {
            "mechanism": "agent_router.reconcile_task_exits",
            "result": {
                "apply": True,
                "limit": limit,
                "states": ["RECYCLE"],
                "task_ids": [],
                "would_move": {},
                "left_in_place": {},
                "moved_count": 0,
                "moved": [],
            },
        }
    result = agent_router.reconcile_task_exits(
        cfg.farm_root,
        apply=True,
        limit=limit,
        states=["RECYCLE"],
        task_ids=task_ids,
    )
    return {"mechanism": "agent_router.reconcile_task_exits", "result": result}


def _run_sweep(cfg: Config, rows: list[dict[str, Any]], limit: int) -> dict[str, Any]:
    ea_ids = list(dict.fromkeys(str(row["ea_id"]) for row in rows if row.get("ea_id")))
    if not ea_ids:
        return {"mechanism": "sweep_enqueue_built_eas.py", "result": {"moved_count": 0}}
    before_ids: set[str]
    with closing(_connect_ro(cfg.db)) as con:
        placeholders = ",".join("?" for _ in ea_ids)
        before_ids = {
            str(row[0]) for row in con.execute(
                f"SELECT id FROM work_items WHERE ea_id IN ({placeholders})", ea_ids
            )
        }
        pending = int(con.execute(
            "SELECT COUNT(*) FROM work_items WHERE status='pending'"
        ).fetchone()[0])
    env = os.environ.copy()
    env["QM_STRATEGY_FARM_ROOT"] = str(cfg.farm_root)
    env["QM_CANONICAL_REPO_ROOT"] = str(cfg.repo_root)
    command = [
        sys.executable,
        str(cfg.repo_root / "tools" / "strategy_farm" / "sweep_enqueue_built_eas.py"),
        "--apply",
        "--ea", ",".join(ea_ids),
        "--queue-ceiling", str(pending + limit),
        "--max-part2-per-run", "0",
    ]
    run = subprocess.run(command, cwd=cfg.repo_root, env=env, capture_output=True, text=True)
    with closing(_connect_ro(cfg.db)) as con:
        placeholders = ",".join("?" for _ in ea_ids)
        after = [dict(row) for row in con.execute(
            f"SELECT id,ea_id,symbol,phase,status,verdict,created_at FROM work_items "
            f"WHERE ea_id IN ({placeholders}) ORDER BY created_at,id", ea_ids
        )]
    moved = [row for row in after if str(row["id"]) not in before_ids]
    return {
        "mechanism": "sweep_enqueue_built_eas.py",
        "command": command,
        "exit_code": run.returncode,
        "moved_count": len(moved),
        "moved": moved,
        "stdout_tail": run.stdout[-4000:],
        "stderr_tail": run.stderr[-4000:],
    }


def _run_stranded(cfg: Config, limit: int, receipt_target: Path) -> dict[str, Any]:
    if limit not in {5, 25}:
        raise ValueError("INFRA_STRANDED preserves MNT-007 exact waves: --limit must be 5 or 25")
    wave = 1 if limit == 5 else 2
    journal = receipt_target.with_name(receipt_target.stem + "_journal.json")
    command = [
        sys.executable,
        str(cfg.repo_root / "tools" / "strategy_farm" / "requeue_stranded_infra.py"),
        "--wave", str(wave), "--apply", "--snapshot-out", str(journal),
    ]
    if wave == 2:
        raise ValueError("INFRA_STRANDED Wave 2 requires its MNT-007 Wave-1 PASS receipt; invoke that mechanism directly")
    run = subprocess.run(command, cwd=cfg.repo_root, capture_output=True, text=True)
    result = {
        "mechanism": "requeue_stranded_infra.py",
        "command": command,
        "exit_code": run.returncode,
        "journal": str(journal),
        "stdout_tail": run.stdout[-4000:],
        "stderr_tail": run.stderr[-4000:],
    }
    if journal.exists():
        try:
            journal_payload = json.loads(journal.read_text(encoding="utf-8-sig"))
            result["selected"] = journal_payload.get("canary") or []
            result["journal_state"] = journal_payload.get("journal_state")
        except (OSError, json.JSONDecodeError):
            result["journal_read_error"] = True
    return result


def apply_wave(
    cfg: Config, *, defect_class: str, limit: int, wave_id: str
) -> dict[str, Any]:
    if defect_class not in APPLY_CLASSES:
        raise ValueError(f"--class must be one of {', '.join(APPLY_CLASSES)}")
    if limit <= 0:
        raise ValueError("--limit must be positive")
    receipt_target = _receipt_path(cfg, defect_class, wave_id)
    if receipt_target.exists():
        prior = json.loads(receipt_target.read_text(encoding="utf-8-sig"))
        if prior.get("class") != defect_class or int(prior.get("limit", -1)) != limit:
            raise ValueError("existing --wave-id receipt has different class or limit")
        if prior.get("journal_state") != "COMMITTED":
            raise ValueError(
                "existing --wave-id receipt is not COMMITTED; reconcile its recorded selection before retry"
            )
        prior["receipt_path"] = str(receipt_target)
        prior["replayed"] = True
        prior["moved_count_this_invocation"] = 0
        return prior
    before = classify(cfg)
    rows = _selected(before, defect_class, limit)
    # Selecting nothing is a successful idempotent no-op and still gets a receipt.
    queue_before = _queue_counts(cfg.db)
    receipt_stub = receipt_target
    planned = {
        "schema": "qm.drain_backlog.wave_receipt.v1",
        "generated_at_utc": _utc_now(),
        "class": defect_class,
        "wave_id": wave_id,
        "limit": limit,
        "selected": rows,
        "selected_count": len(rows),
        "before_class_count": int(before["counts"].get(defect_class, 0)),
        "queue_before": queue_before,
        "journal_state": "PLANNED",
        "verdicts_synthesized": 0,
        "agent_task_verdicts_overwritten": 0,
    }
    # Durable intent precedes every delegated mutation.  A crash therefore
    # leaves an exact selection to reconcile and the same wave-id fails closed.
    _write_receipt(cfg, planned, receipt_target)
    if defect_class in {"RECYCLE_BUILD_NEEDS_REBUILD", "RECYCLE_REVIEW"}:
        delegated = _apply_recycle(cfg, defect_class, rows, limit)
    elif defect_class in {"RECYCLE_BUILD_BUILT_NEVER_GATED", "ACTIVE_EA_BUILT_NEVER_GATED"}:
        delegated = _run_sweep(cfg, rows, limit)
    else:
        delegated = _run_stranded(cfg, limit, receipt_stub)
    after = classify(cfg)
    selected_for_receipt = delegated.get("selected", rows)
    receipt = {
        "schema": "qm.drain_backlog.wave_receipt.v1",
        "generated_at_utc": _utc_now(),
        "class": defect_class,
        "wave_id": wave_id,
        "limit": limit,
        "selected": selected_for_receipt,
        "selected_count": len(selected_for_receipt),
        "before_class_count": int(before["counts"].get(defect_class, 0)),
        "after_class_count": int(after["counts"].get(defect_class, 0)),
        "queue_before": queue_before,
        "queue_after": _queue_counts(cfg.db),
        "delegated": delegated,
        "verdicts_synthesized": 0,
        "agent_task_verdicts_overwritten": 0,
        "replayed": False,
        "journal_state": (
            "COMMITTED" if delegated.get("exit_code", 0) == 0 else "FAILED"
        ),
    }
    target = _write_receipt(cfg, receipt, receipt_target)
    receipt["receipt_path"] = str(target)
    return receipt


def _summary(snapshot: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": snapshot["schema"],
        "generated_at_utc": snapshot["generated_at_utc"],
        "read_only": snapshot["read_only"],
        "total_classified": snapshot["total_classified"],
        "counts": snapshot["counts"],
        "infra_census": snapshot["infra_census"],
        "samples": snapshot["samples"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--farm-root", type=Path, default=Path(r"D:/QM/strategy_farm"))
    parser.add_argument("--repo-root", type=Path, default=Path(r"C:/QM/repo"))
    parser.add_argument("--db", type=Path)
    parser.add_argument("--receipt-dir", type=Path)
    parser.add_argument("--class", dest="defect_class", choices=APPLY_CLASSES)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--wave-id", help="stable idempotency key for this bounded wave")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(argv)
    cfg = Config.build(
        farm_root=args.farm_root,
        repo_root=args.repo_root,
        db=args.db,
        receipt_dir=args.receipt_dir,
    )
    if args.apply:
        if not args.defect_class or args.limit is None or not args.wave_id:
            parser.error("--apply requires --class, --limit, and --wave-id")
        try:
            result = apply_wave(
                cfg,
                defect_class=args.defect_class,
                limit=args.limit,
                wave_id=args.wave_id,
            )
        except (OSError, sqlite3.Error, RuntimeError, ValueError) as exc:
            print(json.dumps({"applied": False, "error": str(exc)}, indent=2))
            return 2
        print(json.dumps(result, indent=2, sort_keys=True))
        delegated = result.get("delegated") or {}
        return 0 if delegated.get("exit_code", 0) == 0 else 1
    if args.limit is not None or args.wave_id is not None:
        parser.error("--limit and --wave-id are valid only with --apply")
    snapshot = classify(cfg)
    summary = _summary(snapshot)
    if args.defect_class:
        summary["selected_class"] = args.defect_class
        summary["selected_rows"] = [
            row for row in snapshot["rows"] if row["class"] == args.defect_class
        ]
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
