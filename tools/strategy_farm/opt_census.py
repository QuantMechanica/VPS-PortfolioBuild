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

# ---------------------------------------------------------------------------
# Sealed selection rule (DL-089 §2 / plan v3) — ROT.  The verbatim rule text is
# NOT retyped here (unicode transcription risk); it is extracted live from the
# authority document between two ASCII anchors and pinned by SHA-256.  Any edit
# to the plan's §2 walk-forward protocol changes the extracted SHA and makes the
# seal fail closed — which is exactly the tamper-detection the ROT zone requires.
# ---------------------------------------------------------------------------
PLAN_DOC = REPO_ROOT / "docs" / "research" / "PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md"
SEALED_RULE_START_ANCHOR = "Je Schritt: Regel"
SEALED_RULE_END_ANCHOR = "erzeugen neue L"  # ASCII prefix of "erzeugen neue Laufe."
SEALED_RULE_SHA256 = "4cc2bbd108bf500f33ef5eee30536c9a4afe58dc2684116a972c0bfb65f3d383"
ACTIVITY_FLOOR = 10
RELATIVE_IMPROVE_MIN = 0.05
SELECTION_YEAR_QUORUM = "2/3"
# Anchored/expanding walk-forward, minimum window 3 (plan §2 table).
WF_WINDOWS = (
    {"step": 1, "select_years": [2019, 2020, 2021], "test_year": 2022},
    {"step": 2, "select_years": [2019, 2020, 2021, 2022], "test_year": 2023},
    {"step": 3, "select_years": [2019, 2020, 2021, 2022, 2023], "test_year": 2024},
    {"step": 4, "select_years": [2019, 2020, 2021, 2022, 2023, 2024], "test_year": 2025},
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


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def extract_sealed_rule_text(plan_doc: Path = PLAN_DOC) -> str:
    """Return the verbatim DL-089 §2 walk-forward selection rule, SHA-pinned.

    Fails closed if the authority document no longer contains the sealed block
    or if its SHA-256 drifts from ``SEALED_RULE_SHA256`` (ROT tamper guard).
    """
    if not plan_doc.is_file():
        raise CensusError(f"sealed-rule authority missing: {plan_doc}")
    text = plan_doc.read_text(encoding="utf-8")
    try:
        start = text.index(SEALED_RULE_START_ANCHOR)
        end = text.index(".", text.index(SEALED_RULE_END_ANCHOR, start)) + 1
    except ValueError as exc:
        raise CensusError(f"sealed-rule anchors not found in {plan_doc}: {exc}") from exc
    block = text[start:end]
    actual = _sha256_bytes(block.encode("utf-8"))
    if actual != SEALED_RULE_SHA256:
        raise CensusError(
            "sealed selection rule drifted (ROT): "
            f"expected sha256 {SEALED_RULE_SHA256}, extracted {actual}"
        )
    return block


def sealed_header(*, param_grid: Path | None, plan_doc: Path = PLAN_DOC) -> dict[str, Any]:
    """The frozen selection contract written into every census ledger header.

    All fields bind the *evaluation* before any data is seen (DL-089 §2, DL-088).
    ``param_grid_sha256`` seals the S5 numeric grid so the driver can later verify
    it never changed between planning and numeric optimisation.
    """
    rule_text = extract_sealed_rule_text(plan_doc)
    header: dict[str, Any] = {
        "sealed_rule_text": rule_text,
        "sealed_rule_sha256": SEALED_RULE_SHA256,
        "sealed_rule_source": f"{plan_doc.name}#2",
        "activity_floor": ACTIVITY_FLOOR,
        "relative_improve_min": RELATIVE_IMPROVE_MIN,
        "selection_year_quorum": SELECTION_YEAR_QUORUM,
        "wf_windows": [dict(window) for window in WF_WINDOWS],
        "param_grid_path": None,
        "param_grid_sha256": None,
    }
    if param_grid is not None:
        if not param_grid.is_file():
            raise CensusError(f"opt_param_grid.json missing: {param_grid}")
        header["param_grid_path"] = str(param_grid.resolve())
        header["param_grid_sha256"] = _sha256(param_grid)
    return header


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
               base_setfile: Path, output_dir: Path,
               param_grid: Path | None = None,
               plan_doc: Path = PLAN_DOC) -> dict[str, Any]:
    validate_base_setfile(base_setfile, ea_id)
    seal = sealed_header(param_grid=param_grid, plan_doc=plan_doc)
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
    plan: dict[str, Any] = {
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
    }
    plan.update(seal)  # sealed selection contract (verbatim rule, floors, quorum, WF, grid sha)
    plan["cells"] = cells
    return plan


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
    # The harness completion path lands verdict='HARNESS_OK' (its canonical
    # measurement token, e.g. row 93338948 on 2026-08-22), not the gate token
    # 'PASS' this check originally demanded — that mismatch would have held the
    # census closed forever after a successful harness run.
    if result["status"] != "done" or result["verdict"] not in ("HARNESS_OK", "PASS"):
        raise CensusError(
            f"fixture harness is not green: status={result['status']} verdict={result['verdict']}"
        )
    return result


def _q02_pass(conn: sqlite3.Connection, ea_id: str) -> dict[str, Any]:
    """Fail-closed precondition: the census EA must own a done/PASS Q02 work item.

    Spending 1,085 census backtests is only justified once the ``_opt`` EA's own
    six-zero baseline has proven economically alive through the funnel.  Storage
    keeps the legacy ``P2`` phase key alongside ``Q02`` (CLAUDE.md compatibility),
    so both are accepted.  Any absence / non-done / non-PASS row refuses the batch.
    """
    row = conn.execute(
        """SELECT id,phase,status,verdict,evidence_path,updated_at
             FROM work_items
            WHERE ea_id=? AND phase IN ('Q02','P2')
              AND status='done' AND verdict='PASS'
         ORDER BY updated_at DESC LIMIT 1""",
        (ea_id,),
    ).fetchone()
    if row is None:
        raise CensusError(
            f"census precondition unmet: no done/PASS Q02 work item for EA {ea_id!r} "
            "(the _opt baseline must clear Q02 before the census is enqueued)"
        )
    return dict(zip(("id", "phase", "status", "verdict", "evidence_path", "updated_at"), row))


def enqueue(plan: dict[str, Any], *, db_path: Path, ledger_path: Path,
            harness_id: str = HARNESS_WORK_ITEM_ID,
            q02_ea_id: str | None = None) -> dict[str, Any]:
    if plan.get("schema") != SCHEMA or plan.get("planned_trials") != 1085:
        raise CensusError("invalid or incomplete census plan")
    conn = sqlite3.connect(db_path, timeout=60)
    try:
        harness = _harness_pass(conn, harness_id)
        q02 = _q02_pass(conn, q02_ea_id or plan["ea_id"])
        ledger = {key: value for key, value in plan.items() if key != "cells"}
        ledger.update({
            "status": "PLANNED",
            "harness_work_item_id": harness_id,
            "harness_evidence": harness,
            "q02_precondition": q02,
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


def boost(*, ledger_path: Path, db_path: Path, window: int) -> dict[str, Any]:
    """Maintain a rolling priority window over this program's pending cells.

    Measured 2026-08-22: at the deliberate tier-6 rank a census cell ties with
    fresh Q04 rows and loses every tie on ``updated_at`` — ~1 580 runnable rows
    stood ahead of the first cell, i.e. the census would not START for ~9 days.
    That is tail-sequencing, not the interleave the rank comment promises.  A
    bounded window keeps the interleave honest in both directions: at most
    ``window`` cells carry ``priority_track`` at any moment (census can never
    take more than that many slots), while the funnel keeps every remaining
    slot.  Priority-tracked downstream rows (Q05–Q10, effective 0–5) still
    outrank a boosted cell (effective 6).  Queue-priority-only change: pending
    rows, payload flag; verdicts, active rows and cell windows untouched.
    """
    if window < 1 or window > 16:
        raise CensusError(f"boost window out of range 1..16: {window}")
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    ids = [cell["work_item_id"] for cell in ledger.get("cells", [])]
    if not ids:
        raise CensusError("ledger has no cells")
    conn = sqlite3.connect(db_path, timeout=60)
    try:
        conn.row_factory = sqlite3.Row
        conn.execute("BEGIN IMMEDIATE")
        marks = ",".join("?" for _ in ids)
        rows = conn.execute(
            f"SELECT id, status, payload_json FROM work_items WHERE id IN ({marks})",
            ids).fetchall()
        by_id = {row["id"]: row for row in rows}
        active = flagged = done = 0
        candidates: list[str] = []
        for cell in ledger["cells"]:  # ledger order: year ASC within arm plan
            row = by_id.get(cell["work_item_id"])
            if row is None:
                continue
            if row["status"] == "active":
                active += 1
            elif row["status"] == "pending":
                payload = json.loads(row["payload_json"] or "{}")
                if payload.get("priority_track") is True:
                    flagged += 1
                else:
                    candidates.append(row["id"])
            elif row["status"] == "done":
                done += 1
        deficit = max(0, window - active - flagged)
        boosted: list[str] = []
        now = dt.datetime.now(dt.timezone.utc).isoformat()
        for work_item_id in candidates[:deficit]:
            payload = json.loads(by_id[work_item_id]["payload_json"] or "{}")
            payload["priority_track"] = True
            payload["boost_authority"] = "opt_census.boost rolling window (queue-priority-only)"
            payload["boosted_at_utc"] = now
            conn.execute(
                "UPDATE work_items SET payload_json=?, updated_at=? "
                "WHERE id=? AND status='pending'",
                (json.dumps(payload, sort_keys=True), now, work_item_id))
            boosted.append(work_item_id)
        conn.commit()
        return {
            "schema": "qm.opt-census-boost.v1",
            "window": window, "active": active, "flagged_before": flagged,
            "boosted_now": len(boosted), "boosted_ids": boosted,
            "done": done, "pending_unflagged": len(candidates) - len(boosted),
        }
    finally:
        conn.close()


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
    plan.add_argument("--param-grid", type=Path,
                      help="EA opt_param_grid.json; its sha256 is sealed into the ledger for the numeric stage")
    plan.add_argument("--plan-out", type=Path)

    apply = sub.add_parser("enqueue")
    for action in plan._actions[1:]:
        if action.dest != "plan_out":
            apply._add_action(action)
    apply.add_argument("--db", type=Path, default=DEFAULT_DB)
    apply.add_argument("--ledger", type=Path, required=True)
    apply.add_argument("--harness-work-item-id", default=HARNESS_WORK_ITEM_ID)
    apply.add_argument("--q02-ea-id", default=None,
                       help="override the EA whose done/PASS Q02 gates the census (default: --ea-id)")

    report = sub.add_parser("report-cell")
    report.add_argument("--summary", type=Path, required=True)
    report.add_argument("--out", type=Path)

    # WF-selection + advance driver (delegates to opt_census_select).
    drive = sub.add_parser("advance", help="advance the DL-089 pilot state machine one step")
    drive.add_argument("--ledger", type=Path, required=True)
    drive.add_argument("--db", type=Path, default=DEFAULT_DB)
    drive.add_argument("--param-grid", type=Path,
                       help="opt_param_grid.json for the numeric stage (must match the sealed sha256)")
    drive.add_argument("--dry-run", action="store_true",
                       help="evaluate and print the next transition without writing")

    status = sub.add_parser("report", help="human-readable state of the DL-089 pilot")
    status.add_argument("--ledger", type=Path, required=True)
    status.add_argument("--db", type=Path, default=DEFAULT_DB)
    status.add_argument("--out", type=Path)

    boost_p = sub.add_parser(
        "boost", help="top up the rolling priority window over pending census cells")
    boost_p.add_argument("--ledger", type=Path, required=True)
    boost_p.add_argument("--db", type=Path, default=DEFAULT_DB)
    boost_p.add_argument("--window", type=int, default=8)
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
        if args.command == "boost":
            result = boost(ledger_path=args.ledger, db_path=args.db, window=args.window)
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        if args.command in ("advance", "report"):
            from tools.strategy_farm import opt_census_select as driver
            if args.command == "advance":
                result = driver.advance(
                    ledger_path=args.ledger, db_path=args.db,
                    param_grid=args.param_grid, dry_run=args.dry_run,
                )
            else:
                result = driver.report(ledger_path=args.ledger, db_path=args.db)
                if args.out:
                    _atomic_write(args.out, json.dumps(result, indent=2, sort_keys=True) + "\n")
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0
        plan = build_plan(
            ea_id=args.ea_id, ea_label=args.ea_label, symbol=args.symbol,
            timeframe=args.timeframe, base_setfile=args.base_setfile,
            output_dir=args.output_dir, param_grid=args.param_grid,
        )
        if args.command == "plan":
            if args.plan_out:
                _atomic_write(args.plan_out, json.dumps(plan, indent=2, sort_keys=True) + "\n")
            print(json.dumps({key: value for key, value in plan.items() if key != "cells"},
                             indent=2, sort_keys=True))
            return 0
        result = enqueue(plan, db_path=args.db, ledger_path=args.ledger,
                         harness_id=args.harness_work_item_id, q02_ea_id=args.q02_ea_id)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (CensusError, OSError, ValueError, json.JSONDecodeError, sqlite3.Error) as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
