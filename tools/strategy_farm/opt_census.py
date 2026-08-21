"""Plan, enqueue, and report the DL-089 annual pattern-filter census.

The tool deliberately keeps OPT_CENSUS outside the Q02 phase namespace.  A plan
contains 7 calendar years x (1 baseline + 77 BUY arms + 77 SELL arms) = 1,085
cells.  Work-item UUIDs and cell keys are deterministic, so enqueue is safe to
repeat.  The MQL5 fixture harness must have a PASS verdict before apply mode can
write setfiles or queue rows; dry-run remains available while the harness is
blocked.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
PREDICATE_HEADER = REPO_ROOT / "framework" / "include" / "QM" / "QM_PatternPermission.mqh"
PHASE = "OPT_CENSUS"
SCHEMA = "qm.opt-census.v1"
DECLARED_TRIAL_COUNT = 154
YEARS = tuple(range(2019, 2026))
HARNESS_WORK_ITEM_ID = "83b89730-bb86-4c18-955a-efefe3039cc5"
CELL_NAMESPACE = uuid.UUID("f45f154c-65d5-5e0f-96c8-505bc44bbc39")
SET_KEYS = (
    "opt_pp_buy1", "opt_pp_buy2", "opt_pp_buy3",
    "opt_pp_sell1", "opt_pp_sell2", "opt_pp_sell3",
)


class CensusError(RuntimeError):
    pass


@dataclass(frozen=True)
class Arm:
    key: str
    direction: str
    predicate_id: int


def _atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(text, encoding="utf-8", newline="\n")
    os.replace(tmp, path)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def predicate_ids(path: Path = PREDICATE_HEADER) -> tuple[int, ...]:
    source = path.read_text(encoding="utf-8")
    match = re.search(r"enum\s+QM_PatternId\s*\{(.*?)\};", source, re.S)
    if not match:
        raise CensusError(f"QM_PatternId enum not found: {path}")
    values = sorted({int(value) for name, value in re.findall(
        r"(QM_PP_[A-Z0-9_]+)\s*=\s*(\d+)", match.group(1)
    ) if name != "QM_PP_NONE"})
    if len(values) != 77:
        raise CensusError(f"expected 77 implemented predicates, found {len(values)}")
    return tuple(values)


def arms(ids: Iterable[int]) -> tuple[Arm, ...]:
    ordered = tuple(ids)
    result = [Arm("baseline", "NONE", 0)]
    result.extend(Arm(f"buy_{value:03d}", "BUY", value) for value in ordered)
    result.extend(Arm(f"sell_{value:03d}", "SELL", value) for value in ordered)
    if len(result) != 155 or len({arm.key for arm in result}) != 155:
        raise CensusError("arm construction did not produce 155 unique arms")
    return tuple(result)


def _parse_setfile(path: Path) -> tuple[str, dict[str, str]]:
    text = path.read_text(encoding="utf-8-sig")
    values: dict[str, str] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        if key in values:
            raise CensusError(f"duplicate input {key!r} in {path}")
        values[key] = value.strip()
    return text, values


def validate_base_setfile(path: Path, ea_id: str) -> dict[str, str]:
    if not path.is_file():
        raise CensusError(f"base setfile missing: {path}")
    _, values = _parse_setfile(path)
    required = {"qm_ea_id", "RISK_FIXED", "RISK_PERCENT", *SET_KEYS}
    missing = sorted(required - values.keys())
    if missing:
        raise CensusError(f"base setfile missing inputs: {', '.join(missing)}")
    expected_id = ea_id.removeprefix("QM5_")
    if values["qm_ea_id"] != expected_id:
        raise CensusError(f"qm_ea_id={values['qm_ea_id']} does not match {ea_id}")
    if float(values["RISK_FIXED"]) <= 0 or float(values["RISK_PERCENT"]) != 0:
        raise CensusError("OPT_CENSUS requires RISK_FIXED > 0 and RISK_PERCENT = 0")
    stale = values.get("qm_news_stale_max_hours")
    if stale is not None and int(stale) > 336:
        raise CensusError("qm_news_stale_max_hours must not exceed 336")
    header = path.read_text(encoding="utf-8-sig").lower()
    if "; environment:" not in header or "backtest" not in header:
        raise CensusError("base setfile must declare environment: backtest")
    return values


def _replace_inputs(base_text: str, replacements: dict[str, str]) -> str:
    pending = dict(replacements)
    output: list[str] = []
    for line in base_text.splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith(";") and "=" in stripped:
            key = stripped.split("=", 1)[0]
            if key in pending:
                output.append(f"{key}={pending.pop(key)}")
                continue
        output.append(line)
    if pending:
        raise CensusError(f"cannot replace absent setfile inputs: {sorted(pending)}")
    return "\n".join(output).rstrip() + "\n"


def _arm_inputs(arm: Arm) -> dict[str, str]:
    values = {key: "0" for key in SET_KEYS}
    if arm.direction == "BUY":
        values["opt_pp_buy1"] = str(arm.predicate_id)
    elif arm.direction == "SELL":
        values["opt_pp_sell1"] = str(arm.predicate_id)
    return values


def build_plan(*, ea_id: str, ea_label: str, symbol: str, timeframe: str,
               base_setfile: Path, output_dir: Path) -> dict[str, Any]:
    validate_base_setfile(base_setfile, ea_id)
    predicates = predicate_ids()
    matrix_arms = arms(predicates)
    program_id = f"DL089_{ea_id}_{symbol.replace('.', '_')}_2019_2025"
    cells: list[dict[str, Any]] = []
    for year in YEARS:
        for arm in matrix_arms:
            cell_key = f"{program_id}:{year}:{arm.key}"
            setfile = output_dir / (
                f"{ea_label}_{symbol}_{timeframe}_opt_census_{year}_{arm.key}.set"
            )
            cells.append({
                "cell_key": cell_key,
                "work_item_id": str(uuid.uuid5(CELL_NAMESPACE, cell_key)),
                "year": year,
                "from_date": f"{year}.01.01",
                "to_date": f"{year}.12.31",
                "arm": arm.key,
                "direction": arm.direction,
                "predicate_id": arm.predicate_id,
                "inputs": _arm_inputs(arm),
                "setfile_path": str(setfile.resolve()),
            })
    if len(cells) != 1085 or len({cell["cell_key"] for cell in cells}) != 1085:
        raise CensusError("plan must contain exactly 1085 unique cells")
    return {
        "schema": SCHEMA,
        "program_id": program_id,
        "phase": PHASE,
        "authority": "DL-089",
        "ea_id": ea_id,
        "ea_label": ea_label,
        "symbol": symbol,
        "timeframe": timeframe,
        "years": list(YEARS),
        "predicate_count": len(predicates),
        "arm_count_per_year": len(matrix_arms),
        "declared_trial_count": DECLARED_TRIAL_COUNT,
        "planned_trials": len(cells),
        "base_setfile_path": str(base_setfile.resolve()),
        "base_setfile_sha256": _sha256(base_setfile),
        "output_dir": str(output_dir.resolve()),
        "cells": cells,
    }


def _render_cell_setfile(base_setfile: Path, cell: dict[str, Any]) -> str:
    base_text, _ = _parse_setfile(base_setfile)
    rendered = _replace_inputs(base_text, cell["inputs"])
    stamp = (
        f"; opt_census_schema: {SCHEMA}\n"
        f"; opt_census_cell_key: {cell['cell_key']}\n"
        f"; opt_census_from_date: {cell['from_date']}\n"
        f"; opt_census_to_date: {cell['to_date']}\n"
    )
    return stamp + rendered


def _harness_pass(conn: sqlite3.Connection, harness_id: str) -> dict[str, Any]:
    row = conn.execute(
        "SELECT status,verdict,evidence_path,updated_at FROM work_items WHERE id=?",
        (harness_id,),
    ).fetchone()
    if row is None:
        raise CensusError(f"fixture harness row missing: {harness_id}")
    result = dict(zip(("status", "verdict", "evidence_path", "updated_at"), row))
    if result["status"] != "done" or result["verdict"] != "PASS":
        raise CensusError(
            f"fixture harness is not green: status={result['status']} verdict={result['verdict']}"
        )
    return result


def enqueue(plan: dict[str, Any], *, db_path: Path, ledger_path: Path,
            harness_id: str = HARNESS_WORK_ITEM_ID) -> dict[str, Any]:
    if plan.get("schema") != SCHEMA or plan.get("planned_trials") != 1085:
        raise CensusError("invalid or incomplete census plan")
    conn = sqlite3.connect(db_path, timeout=60)
    try:
        harness = _harness_pass(conn, harness_id)
        ledger = {key: value for key, value in plan.items() if key != "cells"}
        ledger.update({
            "status": "PLANNED",
            "harness_work_item_id": harness_id,
            "harness_evidence": harness,
            "created_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "cells": [{key: cell[key] for key in (
                "cell_key", "work_item_id", "year", "arm", "direction",
                "predicate_id", "setfile_path", "from_date", "to_date"
            )} for cell in plan["cells"]],
        })
        _atomic_write(ledger_path, json.dumps(ledger, indent=2, sort_keys=True) + "\n")

        base_setfile = Path(plan["base_setfile_path"])
        for cell in plan["cells"]:
            _atomic_write(Path(cell["setfile_path"]), _render_cell_setfile(base_setfile, cell))

        inserted = 0
        existing = 0
        now = dt.datetime.now(dt.timezone.utc).isoformat()
        conn.execute("BEGIN IMMEDIATE")
        for cell in plan["cells"]:
            payload = {
                "schema": SCHEMA,
                "program_id": plan["program_id"],
                "cell_key": cell["cell_key"],
                "year": cell["year"],
                "arm": cell["arm"],
                "direction": cell["direction"],
                "predicate_id": cell["predicate_id"],
                "from_date": cell["from_date"],
                "to_date": cell["to_date"],
                "host_timeframe": plan["timeframe"],
                "opt_census_pool": True,
                "declared_trial_count": DECLARED_TRIAL_COUNT,
                "planned_trials": 1085,
                "ledger_path": str(ledger_path.resolve()),
            }
            cur = conn.execute(
                """INSERT OR IGNORE INTO work_items
                   (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,parent_task_id,evidence_path,claimed_by,
                    payload_json,created_at,updated_at)
                   VALUES (?,?,?,?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?)""",
                (cell["work_item_id"], "backtest", PHASE, plan["ea_id"],
                 plan["symbol"], cell["setfile_path"],
                 json.dumps(payload, sort_keys=True), now, now),
            )
            if cur.rowcount == 1:
                inserted += 1
            else:
                row = conn.execute(
                    "SELECT phase,ea_id,symbol,setfile_path,payload_json FROM work_items WHERE id=?",
                    (cell["work_item_id"],),
                ).fetchone()
                if row is None:
                    raise CensusError(f"idempotency lookup failed: {cell['cell_key']}")
                old_payload = json.loads(row[4] or "{}")
                if (row[0], row[1], row[2], row[3], old_payload.get("cell_key")) != (
                    PHASE, plan["ea_id"], plan["symbol"], cell["setfile_path"], cell["cell_key"]
                ):
                    raise CensusError(f"work-item UUID collision: {cell['work_item_id']}")
                existing += 1
        conn.commit()
        ledger["status"] = "ENQUEUED"
        ledger["enqueued_at_utc"] = now
        ledger["inserted"] = inserted
        ledger["existing"] = existing
        _atomic_write(ledger_path, json.dumps(ledger, indent=2, sort_keys=True) + "\n")
        return {"inserted": inserted, "existing": existing, "planned": 1085,
                "ledger_path": str(ledger_path.resolve())}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def cell_report(summary_path: Path) -> dict[str, Any]:
    summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    runs = [run for run in summary.get("runs", []) if run.get("status") == "OK"]
    if len(runs) != 1:
        raise CensusError(f"expected exactly one OK run in {summary_path}, found {len(runs)}")
    run = runs[0]
    report_path = Path(str(run.get("report_canonical_path") or ""))
    if not report_path.is_file():
        raise CensusError(f"native report missing: {report_path}")
    sys.path.insert(0, str(REPO_ROOT))
    from framework.scripts.q10_recency import extract_closed_trades

    trades, native = extract_closed_trades(report_path)
    entry_days = len({trade.entry_time.date() for trade in trades})
    net = float(run["net_profit"])
    max_dd = float(run["drawdown"])
    return {
        "schema": "qm.opt-census-cell-report.v1",
        "summary_path": str(summary_path.resolve()),
        "summary_sha256": _sha256(summary_path),
        "report_path": str(report_path.resolve()),
        "report_sha256": _sha256(report_path),
        "trades": int(run["total_trades"]),
        "entry_trading_days": entry_days,
        "profit_factor": float(run["profit_factor"]),
        "net_profit": net,
        "max_drawdown": max_dd,
        "return_to_maxdd": None if max_dd <= 0 else net / max_dd,
        "report_reconciled": int(native["total_trades"]) == len(trades) == int(run["total_trades"]),
    }


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    plan = sub.add_parser("plan")
    plan.add_argument("--ea-id", required=True)
    plan.add_argument("--ea-label", required=True)
    plan.add_argument("--symbol", required=True)
    plan.add_argument("--timeframe", required=True)
    plan.add_argument("--base-setfile", type=Path, required=True)
    plan.add_argument("--output-dir", type=Path, required=True)
    plan.add_argument("--plan-out", type=Path)

    apply = sub.add_parser("enqueue")
    for action in plan._actions[1:]:
        if action.dest != "plan_out":
            apply._add_action(action)
    apply.add_argument("--db", type=Path, default=DEFAULT_DB)
    apply.add_argument("--ledger", type=Path, required=True)
    apply.add_argument("--harness-work-item-id", default=HARNESS_WORK_ITEM_ID)

    report = sub.add_parser("report-cell")
    report.add_argument("--summary", type=Path, required=True)
    report.add_argument("--out", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        if args.command == "report-cell":
            result = cell_report(args.summary)
            if args.out:
                _atomic_write(args.out, json.dumps(result, indent=2, sort_keys=True) + "\n")
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        plan = build_plan(
            ea_id=args.ea_id, ea_label=args.ea_label, symbol=args.symbol,
            timeframe=args.timeframe, base_setfile=args.base_setfile,
            output_dir=args.output_dir,
        )
        if args.command == "plan":
            if args.plan_out:
                _atomic_write(args.plan_out, json.dumps(plan, indent=2, sort_keys=True) + "\n")
            print(json.dumps({key: value for key, value in plan.items() if key != "cells"},
                             indent=2, sort_keys=True))
            return 0
        result = enqueue(plan, db_path=args.db, ledger_path=args.ledger,
                         harness_id=args.harness_work_item_id)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (CensusError, OSError, ValueError, json.JSONDecodeError, sqlite3.Error) as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
