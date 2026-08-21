"""DL-089 walk-forward selection + pilot advance driver (plan v3 §2, exact).

This module is the *evaluation* half of the pattern-filter optimisation census.
``opt_census.py`` plans/enqueues/measures the 1,085-cell matrix; this module reads
the measured matrix and drives the sealed pilot chain:

    census -> 4 walk-forward combo test-year runs -> stability check
           -> 2 full-window runs (combo + baseline)
           -> S5 numeric optimisation (per sealed grid, plateau median)
           -> final confirmation run -> READY_FOR_Q15 (STOP; Q15 is never automatic)

The selection rule is ROT and implemented EXACTLY as sealed in the ledger header
(``sealed_rule_text``, DL-089 §2):

  * success measure = return_to_maxdd, each year vs the SAME-YEAR baseline;
  * activity floor >= 10 distinct ENTRY days in EVERY selection year, evaluated
    BEFORE any return consideration — one breach makes the arm inadmissible;
  * qualification = >= +5% RELATIVE improvement in >= 2/3 of the selection years;
  * ranking = consistency count, then mean relative improvement (predicate id as
    the deterministic final tie-break);
  * <= 3 filters per direction; "no filter" (baseline) is always the control.

WORDING NOTE (flagged, not silently resolved): the F2 task brief paraphrases the
stability sub-criterion as "final selection identical-or-SUPERSET"; the sealed plan
§2 text (the ROT authority whose sha this driver hashes) says "identisch oder
**Teilmenge**" (identical-or-SUBSET). The sealed text governs, so ``stability_check``
implements SUBSET: every filter in the final (step-4) selection must also have been
selected by the earlier, smaller-window steps. See the evidence doc for the escalation.

The pure functions take hand-computable dicts and hold no I/O; the driver adds a
thin, idempotent DB adapter around them.
"""
from __future__ import annotations

import datetime as dt
import json
import math
import sqlite3
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Iterable, Optional

from tools.strategy_farm import opt_census as census
from tools.strategy_farm.opt_census import CensusError

DRIVER_SCHEMA = "qm.opt-census-driver.v1"
GRID_SCHEMA = "qm.opt-param-grid.v1"
MAX_INFRA_ATTEMPTS = 2
FULL_WINDOW_FROM = "2019.01.01"
FULL_WINDOW_TO = "2026.12.31"
# The S5 levers are the parent EA's already-wired numeric inputs, named by the
# sha-sealed opt_param_grid.json — there is deliberately NO hardcoded name
# whitelist here.  The three invented opt_* placeholder inputs this constant
# originally listed were removed from the EA by review R1 (unwired, no
# mechanical effect); duplicating the sealed grid's contents in code would
# only let the two artifacts drift apart again.  Name validity is enforced by
# the seal: the grid's sha256 is pinned in the ledger at plan time, and the
# grid itself is reviewed against the EA source before sealing.

# Ordered pilot states.  Terminal states stop the machine.
STATE_ENQUEUED = "ENQUEUED"
STATE_WF_COMBO = "WF_COMBO_MEASURING"
STATE_FULLWINDOW = "FULLWINDOW_MEASURING"
STATE_S5 = "S5_MEASURING"
STATE_CONFIRM = "CONFIRM_MEASURING"
STATE_READY = "READY_FOR_Q15"
STATE_UNSTABLE = "WF_UNSTABLE"
TERMINAL_STATES = frozenset({STATE_READY, STATE_UNSTABLE})


# ===========================================================================
# Pure selection primitives (hand-computable; no I/O).
# ===========================================================================
@dataclass(frozen=True)
class YearCell:
    """One measured (arm, year) cell of the census matrix."""
    year: int
    entry_days: int
    return_to_maxdd: Optional[float]


@dataclass(frozen=True)
class ArmEval:
    admissible: bool
    breach_year: Optional[int]
    consistency: int
    mean_rel_improve: Optional[float]
    qualifies: bool
    per_year_rel: dict[int, Optional[float]] = field(default_factory=dict)


def required_quorum(n_years: int) -> int:
    """Smallest integer >= 2/3 of ``n_years`` (the sealed '2/3' quorum)."""
    if n_years <= 0:
        raise CensusError("selection window must contain at least one year")
    return (2 * n_years + 2) // 3  # == ceil(2*n/3), integer-exact


def relative_improvement(arm: Optional[float], baseline: Optional[float]) -> Optional[float]:
    """(arm - baseline) / baseline, defined only over a strictly positive baseline.

    return_to_maxdd is a ratio; a '+X% relative' claim is only well-defined against a
    positive base.  A non-positive or missing baseline (or missing arm) yields ``None``
    (the year is not creditable) — the conservative, deterministic sealed reading.
    """
    if arm is None or baseline is None or baseline <= 0:
        return None
    return (arm - baseline) / baseline


def year_improves(arm: Optional[float], baseline: Optional[float], min_rel: float) -> bool:
    ri = relative_improvement(arm, baseline)
    return ri is not None and ri >= min_rel  # exact edge (ri == min_rel) qualifies


def evaluate_arm(arm_cells: dict[int, YearCell], baseline_cells: dict[int, YearCell],
                 years: Iterable[int], *, activity_floor: int, min_rel: float) -> ArmEval:
    """Evaluate one arm over ``years`` against the same-year baseline.

    Activity floor is checked FIRST across every year; one breach => inadmissible,
    before any return is considered (plan §2 / DL-089 §3, Goodhart-resistant).
    """
    years = list(years)
    for year in years:
        cell = arm_cells.get(year)
        if cell is None:
            return ArmEval(False, year, 0, None, False)
        if cell.entry_days < activity_floor:
            return ArmEval(False, year, 0, None, False)
    rels: dict[int, Optional[float]] = {}
    improvements: list[float] = []
    consistency = 0
    for year in years:
        ri = relative_improvement(arm_cells[year].return_to_maxdd,
                                  baseline_cells[year].return_to_maxdd)
        rels[year] = ri
        if ri is not None:
            improvements.append(ri)
            if ri >= min_rel:
                consistency += 1
    mean_rel = sum(improvements) / len(improvements) if improvements else None
    qualifies = consistency >= required_quorum(len(years))
    return ArmEval(True, None, consistency, mean_rel, qualifies, rels)


def select_direction(evaluations: dict[int, ArmEval], *, cap: int = 3) -> list[int]:
    """Rank qualifying arms and return <= cap predicate ids.

    Order: consistency desc, mean relative improvement desc, predicate id asc
    (the last is the deterministic tie-break so runs are reproducible).
    """
    qualifying = [(pid, ev) for pid, ev in evaluations.items()
                  if ev.admissible and ev.qualifies]
    qualifying.sort(key=lambda item: (
        -item[1].consistency,
        -(item[1].mean_rel_improve if item[1].mean_rel_improve is not None else -math.inf),
        item[0],
    ))
    return [pid for pid, _ in qualifying[:cap]]


def wf_step_selection(matrix: dict[str, dict[int, dict[int, YearCell]]],
                      baseline: dict[int, YearCell], select_years: Iterable[int], *,
                      activity_floor: int, min_rel: float, cap: int = 3) -> dict[str, Any]:
    """Apply rule #1/#6 to one anchored window; return <=3 buy and <=3 sell ids."""
    select_years = list(select_years)
    out: dict[str, Any] = {"select_years": select_years, "detail": {}}
    for direction in ("BUY", "SELL"):
        evals: dict[int, ArmEval] = {}
        for pid, cells in matrix.get(direction, {}).items():
            evals[pid] = evaluate_arm(cells, baseline, select_years,
                                      activity_floor=activity_floor, min_rel=min_rel)
        chosen = select_direction(evals, cap=cap)
        out[direction] = chosen
        out["detail"][direction] = {
            pid: {
                "admissible": ev.admissible, "breach_year": ev.breach_year,
                "consistency": ev.consistency, "mean_rel_improve": ev.mean_rel_improve,
                "qualifies": ev.qualifies,
            } for pid, ev in evals.items()
        }
    return out


def selection_pairs(step_selection: dict[str, Any]) -> frozenset[tuple[str, int]]:
    """Directional (dir, predicate_id) set for a step selection."""
    pairs: set[tuple[str, int]] = set()
    for direction in ("BUY", "SELL"):
        for pid in step_selection.get(direction, []):
            pairs.add((direction, pid))
    return frozenset(pairs)


def stability_check(step_selections: dict[int, dict[str, Any]],
                    combo_test_r2dd: dict[int, Optional[float]],
                    baseline_test_r2dd: dict[int, Optional[float]]) -> dict[str, Any]:
    """Sealed walk-forward stability (plan §2).

    Confirmed iff the per-step combo does NOT worsen return_to_maxdd in >= 3 of the
    4 test years AND the final (step 4) selection was identical-or-SUBSET of the
    selection in >= 2 of the 3 earlier steps.
    """
    test_years = [w["test_year"] for w in census.WF_WINDOWS]
    not_worse = 0
    per_year: dict[int, Any] = {}
    for year in test_years:
        combo = combo_test_r2dd.get(year)
        base = baseline_test_r2dd.get(year)
        ok = combo is not None and base is not None and combo >= base
        per_year[year] = {"combo": combo, "baseline": base, "not_worse": ok}
        if ok:
            not_worse += 1

    final = selection_pairs(step_selections[4])
    subset_count = 0
    subset_detail: dict[int, bool] = {}
    for step in (1, 2, 3):
        earlier = selection_pairs(step_selections[step])
        is_sub = final <= earlier  # identical or subset (Teilmenge)
        subset_detail[step] = is_sub
        if is_sub:
            subset_count += 1

    stable = not_worse >= 3 and subset_count >= 2
    return {
        "stable": stable,
        "not_worse_count": not_worse,
        "not_worse_required": 3,
        "subset_count": subset_count,
        "subset_required": 2,
        "final_selection": sorted(tuple(p) for p in final),
        "per_test_year": per_year,
        "final_subset_of_earlier": subset_detail,
    }


def plateau_median(qualifying_values: list[float]) -> Optional[float]:
    """Median VALUE of the qualifying plateau; lower-middle on an even count.

    Never the single best value (DL-088 §3): the center of the robustly-good region
    is chosen, not its peak.  Returns None on an empty plateau (keep the parent).
    """
    if not qualifying_values:
        return None
    ordered = sorted(set(qualifying_values))
    return ordered[(len(ordered) - 1) // 2]


def select_numeric_parameter(parent_value: float, candidate_values: list[float],
                             per_value_cells: dict[float, dict[int, YearCell]],
                             baseline_cells: dict[int, YearCell], years: Iterable[int], *,
                             activity_floor: int, min_rel: float) -> dict[str, Any]:
    """One AI_PARAM lever: qualify each candidate by the sealed rule, pick the plateau median."""
    years = list(years)
    qualifying: list[float] = []
    detail: dict[str, Any] = {}
    for value in candidate_values:
        ev = evaluate_arm(per_value_cells[value], baseline_cells, years,
                          activity_floor=activity_floor, min_rel=min_rel)
        detail[str(value)] = {
            "admissible": ev.admissible, "breach_year": ev.breach_year,
            "consistency": ev.consistency, "mean_rel_improve": ev.mean_rel_improve,
            "qualifies": ev.qualifies,
        }
        if ev.admissible and ev.qualifies:
            qualifying.append(value)
    chosen = plateau_median(qualifying)
    if chosen is None:
        chosen = parent_value
    return {
        "parent_value": parent_value,
        "candidate_values": candidate_values,
        "qualifying_values": qualifying,
        "chosen_value": chosen,
        "chosen_is_parent": chosen == parent_value,
        "detail": detail,
    }


# ===========================================================================
# Sealed numeric grid (S5) — read via the recorded sha.
# ===========================================================================
def load_param_grid(path: Path, *, expected_sha256: Optional[str]) -> dict[str, Any]:
    """Load and validate opt_param_grid.json, verifying it matches the sealed sha."""
    if not path.is_file():
        raise CensusError(f"opt_param_grid.json missing: {path}")
    raw = path.read_bytes()
    actual = census._sha256_bytes(raw)
    if expected_sha256 is not None and actual != expected_sha256:
        raise CensusError(
            "opt_param_grid.json sha256 does not match the sealed value "
            f"(sealed {expected_sha256}, on-disk {actual}); the grid changed after planning"
        )
    grid = json.loads(raw.decode("utf-8"))
    if grid.get("schema") != GRID_SCHEMA:
        raise CensusError(f"param grid schema must be {GRID_SCHEMA!r}")
    params = grid.get("parameters")
    if not isinstance(params, list) or not params:
        raise CensusError("param grid must list at least one parameter")
    seen: set[str] = set()
    for entry in params:
        name = entry.get("name")
        if not isinstance(name, str) or not name.strip():
            raise CensusError("every grid parameter needs a non-empty name")
        if name in seen:
            raise CensusError(f"duplicate parameter {name!r} in grid")
        seen.add(name)
        values = entry.get("candidate_values")
        if not isinstance(values, list) or not (1 <= len(values) <= 5):
            raise CensusError(f"{name}: candidate_values must hold 1..5 values (DL-088 AI_PARAM)")
        if len(set(values)) != len(values):
            raise CensusError(f"{name}: candidate_values must be distinct")
        if "parent_value" not in entry:
            raise CensusError(f"{name}: parent_value (mandatory control cell) is required")
        if entry["parent_value"] not in values:
            raise CensusError(
                f"{name}: parent_value must be AMONG the candidate_values — DL-088 "
                "defines the ladder as <=5 candidate values INCLUDING the unmodified "
                "parent value as the mandatory control cell"
            )
    grid["_sha256"] = actual
    return grid


def numeric_trial_increment(grid: dict[str, Any]) -> int:
    """DSR trial increment = sum over parameters of the NON-PARENT candidates.

    Years are a repeated measurement of the same hypothesis (OWNER entscheid #7),
    so they do NOT multiply the trial count.  The parent value sits AMONG the
    candidate_values as DL-088's mandatory control cell — it is the incumbent,
    not a new hypothesis, so it is excluded from the deflation count.
    """
    return sum(
        len(p["candidate_values"]) - 1 for p in grid["parameters"]
    )


def register_numeric_stage(ledger: dict[str, Any], grid: dict[str, Any]) -> dict[str, Any]:
    """Increment ``declared_trial_count_effective`` and register S5 cells — idempotent.

    This MUST run (and the ledger MUST be persisted) BEFORE any numeric cell is
    enqueued so the DSR deflation can never under-count the search (plan §S5).
    """
    driver = ledger.setdefault("driver", init_driver())
    s5 = driver.setdefault("s5", {})
    if s5.get("registered"):
        return ledger
    increment = numeric_trial_increment(grid)
    base = ledger.get("declared_trial_count_effective", ledger["declared_trial_count"])
    ledger["declared_trial_count_effective"] = base + increment
    s5["registered"] = True
    s5["registered_at_utc"] = _now()
    s5["param_grid_sha256"] = grid["_sha256"]
    s5["numeric_trial_increment"] = increment
    s5["declared_trial_count_before"] = base
    s5["declared_trial_count_after"] = ledger["declared_trial_count_effective"]
    s5["parameters"] = [
        {"name": p["name"], "parent_value": p["parent_value"],
         "candidate_values": p["candidate_values"]}
        for p in grid["parameters"]
    ]
    return ledger


# ===========================================================================
# Driver — idempotent state machine over the farm DB (read-only for status;
# derived runs inserted append-only into the OPT_CENSUS measurement pool).
# ===========================================================================
def _now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def init_driver() -> dict[str, Any]:
    return {"schema": DRIVER_SCHEMA, "state": STATE_ENQUEUED, "transitions": [],
            "infra_reattempts": {}}


def _digest(payload: Any) -> str:
    return census._sha256_bytes(json.dumps(payload, sort_keys=True, default=str).encode("utf-8"))


def _load_ledger(ledger_path: Path) -> dict[str, Any]:
    if not ledger_path.is_file():
        raise CensusError(f"census ledger missing: {ledger_path}")
    ledger = json.loads(ledger_path.read_text(encoding="utf-8-sig"))
    if ledger.get("schema") != census.SCHEMA:
        raise CensusError(f"not an OPT_CENSUS ledger: {ledger_path}")
    ledger.setdefault("driver", init_driver())
    return ledger


def _persist(ledger_path: Path, ledger: dict[str, Any]) -> None:
    census._atomic_write(ledger_path, json.dumps(ledger, indent=2, sort_keys=True) + "\n")


def _default_metric_reader(conn: sqlite3.Connection) -> Callable[[str], tuple[str, Optional[dict]]]:
    def read(work_item_id: str) -> tuple[str, Optional[dict]]:
        row = conn.execute(
            "SELECT status,verdict,evidence_path FROM work_items WHERE id=?",
            (work_item_id,),
        ).fetchone()
        if row is None:
            return ("MISSING", None)
        status, verdict, evidence = row
        if verdict == "INFRA_FAIL":
            return ("INFRA", None)
        if status != "done" or verdict != census_measured_verdict():
            return ("PENDING", None)
        if not evidence:
            return ("PENDING", None)
        report = census.cell_report(Path(evidence))
        return ("OK", {"entry_days": report["entry_trading_days"],
                       "return_to_maxdd": report["return_to_maxdd"],
                       "trades": report["trades"]})
    return read


def census_measured_verdict() -> str:
    # OPT_CENSUS rows terminate as MEASURED (farmctl measurement remap).
    return "MEASURED"


def _resolve(reader: Callable[[str], tuple[str, Optional[dict]]], driver: dict[str, Any],
             cell_key: str, base_id: str) -> tuple[str, Optional[dict]]:
    """Prefer a measured result across the base row and any append-only reruns."""
    ids = [base_id] + list(driver.get("reruns", {}).get(cell_key, []))
    statuses = []
    for wid in ids:
        status, metric = reader(wid)
        if status == "OK":
            return ("OK", metric)
        statuses.append(status)
    if statuses and all(s == "INFRA" for s in statuses):
        return ("INFRA", None)
    return ("PENDING", None)


def _render_setfile(ledger: dict[str, Any], cell_key: str, inputs: dict[str, str],
                    from_date: str, to_date: str, output_name: str) -> Path:
    base_setfile = Path(ledger["base_setfile_path"])
    base_text, _ = census._parse_setfile(base_setfile)
    rendered = census._replace_inputs(base_text, inputs)
    stamp = (f"; opt_census_schema: {census.SCHEMA}\n"
             f"; opt_census_cell_key: {cell_key}\n"
             f"; opt_census_from_date: {from_date}\n"
             f"; opt_census_to_date: {to_date}\n")
    out_dir = Path(ledger["output_dir"])
    path = out_dir / output_name
    census._atomic_write(path, stamp + rendered)
    return path


def _run_uuid(cell_key: str) -> str:
    return str(uuid.uuid5(census.CELL_NAMESPACE, cell_key))


def _insert_run(conn: sqlite3.Connection, ledger: dict[str, Any], *, work_item_id: str,
                cell_key: str, setfile_path: str, from_date: str, to_date: str,
                stage: str, extra: dict[str, Any]) -> bool:
    now = _now()
    payload = {
        "schema": census.SCHEMA, "program_id": ledger["program_id"],
        "cell_key": cell_key, "opt_census_pool": True, "opt_census_stage": stage,
        "opt_from_date": from_date, "opt_to_date": to_date,
        "from_date": from_date, "to_date": to_date,
        "host_timeframe": ledger["timeframe"],
        "declared_trial_count": ledger["declared_trial_count"],
        "ledger_path": ledger.get("_ledger_path"),
        **extra,
    }
    cur = conn.execute(
        """INSERT OR IGNORE INTO work_items
             (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at)
           VALUES (?,?,?,?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?)""",
        (work_item_id, "backtest", census.PHASE, ledger["ea_id"], ledger["symbol"],
         setfile_path, json.dumps(payload, sort_keys=True), now, now),
    )
    return cur.rowcount == 1


def _combo_inputs(selection: dict[str, Any]) -> dict[str, str]:
    buys = list(selection.get("BUY", []))[:3] + [0, 0, 0]
    sells = list(selection.get("SELL", []))[:3] + [0, 0, 0]
    return {
        "opt_pp_buy1": str(buys[0]), "opt_pp_buy2": str(buys[1]), "opt_pp_buy3": str(buys[2]),
        "opt_pp_sell1": str(sells[0]), "opt_pp_sell2": str(sells[1]), "opt_pp_sell3": str(sells[2]),
    }


_BASELINE_INPUTS = {k: "0" for k in census.SET_KEYS}


def _maybe_reenqueue_infra(conn: sqlite3.Connection, ledger: dict[str, Any], driver: dict[str, Any],
                           run_specs: list[dict[str, Any]],
                           reader: Callable[[str], tuple[str, Optional[dict]]]) -> int:
    """Append-only rerun of INFRA cells, bounded to MAX_INFRA_ATTEMPTS. Returns count re-enqueued."""
    reattempts = driver.setdefault("infra_reattempts", {})
    reruns = driver.setdefault("reruns", {})
    count = 0
    for spec in run_specs:
        cell_key = spec["cell_key"]
        status, _ = _resolve(reader, driver, cell_key, spec["work_item_id"])
        if status != "INFRA":
            continue
        attempts = reattempts.get(cell_key, 0)
        if attempts >= MAX_INFRA_ATTEMPTS:
            continue
        attempts += 1
        rerun_key = f"{cell_key}:rerun:{attempts}"
        rerun_id = _run_uuid(rerun_key)
        inserted = _insert_run(
            conn, ledger, work_item_id=rerun_id, cell_key=cell_key,
            setfile_path=spec["setfile_path"], from_date=spec["from_date"],
            to_date=spec["to_date"], stage=spec.get("stage", "RERUN"),
            extra={"append_only_rerun_of": spec["work_item_id"], "rerun_attempt": attempts},
        )
        if inserted:
            reattempts[cell_key] = attempts
            reruns.setdefault(cell_key, []).append(rerun_id)
            count += 1
    return count


def _census_specs(ledger: dict[str, Any]) -> list[dict[str, Any]]:
    specs = []
    for cell in ledger["cells"]:
        specs.append({"cell_key": cell["cell_key"], "work_item_id": cell["work_item_id"],
                      "setfile_path": cell["setfile_path"], "from_date": cell["from_date"],
                      "to_date": cell["to_date"], "stage": "CENSUS",
                      "year": cell["year"], "direction": cell["direction"],
                      "predicate_id": cell["predicate_id"], "arm": cell["arm"]})
    return specs


def _build_matrix(ledger: dict[str, Any], driver: dict[str, Any],
                  reader: Callable[[str], tuple[str, Optional[dict]]]) -> dict[str, Any]:
    matrix: dict[str, dict[int, dict[int, YearCell]]] = {"BUY": {}, "SELL": {}}
    baseline: dict[int, YearCell] = {}
    pending = 0
    infra = 0
    for spec in _census_specs(ledger):
        status, metric = _resolve(reader, driver, spec["cell_key"], spec["work_item_id"])
        if status == "PENDING" or status == "MISSING":
            pending += 1
            continue
        if status == "INFRA":
            infra += 1
            continue
        cell = YearCell(spec["year"], int(metric["entry_days"]), metric["return_to_maxdd"])
        if spec["arm"] == "baseline":
            baseline[spec["year"]] = cell
        else:
            matrix.setdefault(spec["direction"], {}).setdefault(spec["predicate_id"], {})[spec["year"]] = cell
    return {"matrix": matrix, "baseline": baseline, "pending": pending, "infra": infra}


def _all_measured(reader: Callable[[str], tuple[str, Optional[dict]]], driver: dict[str, Any],
                  specs: list[dict[str, Any]]) -> dict[str, Any]:
    ok = 0
    pending = 0
    infra = 0
    metrics: dict[str, Optional[dict]] = {}
    for spec in specs:
        status, metric = _resolve(reader, driver, spec["cell_key"], spec["work_item_id"])
        metrics[spec["cell_key"]] = metric
        if status == "OK":
            ok += 1
        elif status == "INFRA":
            infra += 1
        else:
            pending += 1
    return {"ok": ok, "pending": pending, "infra": infra, "total": len(specs), "metrics": metrics}


def _transition(driver: dict[str, Any], to_state: str, note: str, inputs: Any) -> None:
    driver["transitions"].append({
        "from": driver["state"], "to": to_state, "at": _now(),
        "note": note, "inputs_digest": _digest(inputs),
    })
    driver["state"] = to_state


# --- stage handlers --------------------------------------------------------
def _handle_enqueued(conn, ledger, driver, reader) -> dict[str, Any]:
    specs = _census_specs(ledger)
    reenq = _maybe_reenqueue_infra(conn, ledger, driver, specs, reader)
    built = _build_matrix(ledger, driver, reader)
    ok = len(built["baseline"]) + sum(len(v) for d in built["matrix"].values() for v in d.values())
    if built["pending"] or built["infra"]:
        return {"changed": reenq > 0, "state": driver["state"], "waiting": True,
                "pending": built["pending"], "infra": built["infra"],
                "reenqueued": reenq, "measured": ok}

    floor = ledger["activity_floor"]
    min_rel = ledger["relative_improve_min"]
    step_selections: dict[int, dict[str, Any]] = {}
    combo_runs: list[dict[str, Any]] = []
    for window in census.WF_WINDOWS:
        step = window["step"]
        sel = wf_step_selection(built["matrix"], built["baseline"], window["select_years"],
                                activity_floor=floor, min_rel=min_rel)
        step_selections[step] = sel
        test_year = window["test_year"]
        cell_key = f"{ledger['program_id']}:wf{step}:combo:{test_year}"
        setfile = _render_setfile(
            ledger, cell_key, _combo_inputs(sel),
            f"{test_year}.01.01", f"{test_year}.12.31",
            f"{ledger['ea_label']}_{ledger['symbol']}_{ledger['timeframe']}_wf{step}_combo_{test_year}.set",
        )
        wid = _run_uuid(cell_key)
        _insert_run(conn, ledger, work_item_id=wid, cell_key=cell_key,
                    setfile_path=str(setfile), from_date=f"{test_year}.01.01",
                    to_date=f"{test_year}.12.31", stage="WF_COMBO",
                    extra={"wf_step": step, "test_year": test_year})
        combo_runs.append({"cell_key": cell_key, "work_item_id": wid,
                           "setfile_path": str(setfile), "from_date": f"{test_year}.01.01",
                           "to_date": f"{test_year}.12.31", "stage": "WF_COMBO",
                           "wf_step": step, "test_year": test_year})

    driver["census"] = {
        "step_selections": {str(k): v for k, v in step_selections.items()},
        "baseline_r2dd": {str(y): built["baseline"][y].return_to_maxdd for y in built["baseline"]},
    }
    driver["wf"] = {"combo_runs": combo_runs}
    _transition(driver, STATE_WF_COMBO, "census complete; 4 WF combo runs enqueued",
                {"selections": {str(k): sorted(list(p) for p in selection_pairs(v))
                                for k, v in step_selections.items()}})
    return {"changed": True, "state": driver["state"], "waiting": False,
            "measured": ok, "combo_runs": len(combo_runs)}


def _handle_wf_combo(conn, ledger, driver, reader) -> dict[str, Any]:
    combo_runs = driver["wf"]["combo_runs"]
    reenq = _maybe_reenqueue_infra(conn, ledger, driver, combo_runs, reader)
    status = _all_measured(reader, driver, combo_runs)
    if status["pending"] or status["infra"]:
        return {"changed": reenq > 0, "state": driver["state"], "waiting": True, **_counts(status),
                "reenqueued": reenq}

    combo_test_r2dd: dict[int, Optional[float]] = {}
    for run in combo_runs:
        metric = status["metrics"][run["cell_key"]]
        combo_test_r2dd[run["test_year"]] = metric["return_to_maxdd"] if metric else None
    baseline_test_r2dd = {int(y): v for y, v in driver["census"]["baseline_r2dd"].items()
                          if int(y) in {w["test_year"] for w in census.WF_WINDOWS}}
    step_selections = {int(k): v for k, v in driver["census"]["step_selections"].items()}
    verdict = stability_check(step_selections, combo_test_r2dd, baseline_test_r2dd)
    driver["wf"]["stability"] = verdict
    driver["wf"]["combo_test_r2dd"] = {str(k): v for k, v in combo_test_r2dd.items()}

    if not verdict["stable"]:
        _transition(driver, STATE_UNSTABLE,
                    "walk-forward stability failed; escalate to OWNER (no auto-advance)", verdict)
        return {"changed": True, "state": driver["state"], "waiting": False, "stability": verdict}

    final = step_selections[4]
    driver["wf"]["final_selection"] = {"BUY": final.get("BUY", []), "SELL": final.get("SELL", [])}
    full_runs: list[dict[str, Any]] = []
    for role, inputs in (("combo", _combo_inputs(final)), ("baseline", dict(_BASELINE_INPUTS))):
        cell_key = f"{ledger['program_id']}:fullwindow:{role}"
        setfile = _render_setfile(
            ledger, cell_key, inputs, FULL_WINDOW_FROM, FULL_WINDOW_TO,
            f"{ledger['ea_label']}_{ledger['symbol']}_{ledger['timeframe']}_fullwindow_{role}.set",
        )
        wid = _run_uuid(cell_key)
        _insert_run(conn, ledger, work_item_id=wid, cell_key=cell_key, setfile_path=str(setfile),
                    from_date=FULL_WINDOW_FROM, to_date=FULL_WINDOW_TO, stage="FULLWINDOW",
                    extra={"role": role})
        full_runs.append({"cell_key": cell_key, "work_item_id": wid, "setfile_path": str(setfile),
                          "from_date": FULL_WINDOW_FROM, "to_date": FULL_WINDOW_TO,
                          "stage": "FULLWINDOW", "role": role})
    driver["fullwindow"] = {"runs": full_runs}
    _transition(driver, STATE_FULLWINDOW, "WF stability confirmed; 2 full-window runs enqueued", verdict)
    return {"changed": True, "state": driver["state"], "waiting": False, "stability": verdict}


def _handle_fullwindow(conn, ledger, driver, reader, param_grid: Optional[Path]) -> dict[str, Any]:
    runs = driver["fullwindow"]["runs"]
    reenq = _maybe_reenqueue_infra(conn, ledger, driver, runs, reader)
    status = _all_measured(reader, driver, runs)
    if status["pending"] or status["infra"]:
        return {"changed": reenq > 0, "state": driver["state"], "waiting": True, **_counts(status),
                "reenqueued": reenq}
    driver["fullwindow"]["results"] = {
        run["role"]: (status["metrics"][run["cell_key"]] or {}) for run in runs
    }
    if param_grid is None:
        return {"changed": reenq > 0, "state": driver["state"], "waiting": True,
                "blocked": "s5_requires_param_grid",
                "hint": "re-run advance with --param-grid matching the sealed param_grid_sha256"}

    grid = load_param_grid(param_grid, expected_sha256=ledger.get("param_grid_sha256"))
    register_numeric_stage(ledger, grid)  # increments declared_trial_count_effective BEFORE enqueue

    final = driver["wf"]["final_selection"]
    numeric_runs: list[dict[str, Any]] = []
    # Per-year combo baseline (frozen filter, parent numerics) — the S5 same-year baseline.
    for year in census.YEARS:
        cell_key = f"{ledger['program_id']}:s5:baseline:{year}"
        setfile = _render_setfile(
            ledger, cell_key, _combo_inputs(final), f"{year}.01.01", f"{year}.12.31",
            f"{ledger['ea_label']}_{ledger['symbol']}_{ledger['timeframe']}_s5_baseline_{year}.set",
        )
        wid = _run_uuid(cell_key)
        _insert_run(conn, ledger, work_item_id=wid, cell_key=cell_key, setfile_path=str(setfile),
                    from_date=f"{year}.01.01", to_date=f"{year}.12.31", stage="S5_BASELINE",
                    extra={"year": year})
        numeric_runs.append({"cell_key": cell_key, "work_item_id": wid, "setfile_path": str(setfile),
                             "from_date": f"{year}.01.01", "to_date": f"{year}.12.31",
                             "stage": "S5_BASELINE", "year": year, "role": "baseline"})
    # One trial per (parameter, candidate value), each measured in every year.
    for param in grid["parameters"]:
        name = param["name"]
        for value in param["candidate_values"]:
            for year in census.YEARS:
                inputs = _combo_inputs(final)
                inputs[name] = _fmt_value(value)
                cell_key = f"{ledger['program_id']}:s5:{name}:{value}:{year}"
                setfile = _render_setfile(
                    ledger, cell_key, inputs, f"{year}.01.01", f"{year}.12.31",
                    f"{ledger['ea_label']}_{ledger['symbol']}_{ledger['timeframe']}_s5_{name}_{value}_{year}.set",
                )
                wid = _run_uuid(cell_key)
                _insert_run(conn, ledger, work_item_id=wid, cell_key=cell_key, setfile_path=str(setfile),
                            from_date=f"{year}.01.01", to_date=f"{year}.12.31", stage="S5_NUMERIC",
                            extra={"param": name, "value": value, "year": year})
                numeric_runs.append({"cell_key": cell_key, "work_item_id": wid,
                                     "setfile_path": str(setfile), "from_date": f"{year}.01.01",
                                     "to_date": f"{year}.12.31", "stage": "S5_NUMERIC",
                                     "param": name, "value": value, "year": year, "role": "numeric"})
    driver["s5"]["runs"] = numeric_runs
    _transition(driver, STATE_S5,
                "full-window complete; S5 numeric trials registered and enqueued",
                {"increment": driver["s5"]["numeric_trial_increment"],
                 "effective": ledger["declared_trial_count_effective"]})
    return {"changed": True, "state": driver["state"], "waiting": False,
            "numeric_runs": len(numeric_runs),
            "declared_trial_count_effective": ledger["declared_trial_count_effective"]}


def _handle_s5(conn, ledger, driver, reader) -> dict[str, Any]:
    runs = driver["s5"]["runs"]
    reenq = _maybe_reenqueue_infra(conn, ledger, driver, runs, reader)
    status = _all_measured(reader, driver, runs)
    if status["pending"] or status["infra"]:
        return {"changed": reenq > 0, "state": driver["state"], "waiting": True, **_counts(status),
                "reenqueued": reenq}

    floor = ledger["activity_floor"]
    min_rel = ledger["relative_improve_min"]
    baseline_cells: dict[int, YearCell] = {}
    per_param: dict[str, dict[float, dict[int, YearCell]]] = {}
    for run in runs:
        metric = status["metrics"][run["cell_key"]] or {}
        cell = YearCell(run["year"], int(metric.get("entry_days", 0)), metric.get("return_to_maxdd"))
        if run["role"] == "baseline":
            baseline_cells[run["year"]] = cell
        else:
            per_param.setdefault(run["param"], {}).setdefault(run["value"], {})[run["year"]] = cell

    selections: dict[str, Any] = {}
    chosen_numeric: dict[str, Any] = {}
    for param in driver["s5"]["parameters"]:
        name = param["name"]
        result = select_numeric_parameter(
            param["parent_value"], param["candidate_values"],
            per_param.get(name, {}), baseline_cells, census.YEARS,
            activity_floor=floor, min_rel=min_rel,
        )
        selections[name] = result
        chosen_numeric[name] = result["chosen_value"]
    driver["s5"]["selection"] = selections
    driver["s5"]["chosen_numeric"] = chosen_numeric

    final = driver["wf"]["final_selection"]
    inputs = _combo_inputs(final)
    for name, value in chosen_numeric.items():
        inputs[name] = _fmt_value(value)
    cell_key = f"{ledger['program_id']}:confirm"
    setfile = _render_setfile(
        ledger, cell_key, inputs, FULL_WINDOW_FROM, FULL_WINDOW_TO,
        f"{ledger['ea_label']}_{ledger['symbol']}_{ledger['timeframe']}_confirm.set",
    )
    wid = _run_uuid(cell_key)
    _insert_run(conn, ledger, work_item_id=wid, cell_key=cell_key, setfile_path=str(setfile),
                from_date=FULL_WINDOW_FROM, to_date=FULL_WINDOW_TO, stage="CONFIRM", extra={})
    driver["confirm"] = {"run": {"cell_key": cell_key, "work_item_id": wid,
                                 "setfile_path": str(setfile), "from_date": FULL_WINDOW_FROM,
                                 "to_date": FULL_WINDOW_TO, "stage": "CONFIRM"},
                         "chosen_numeric": chosen_numeric}
    _transition(driver, STATE_CONFIRM, "S5 numeric selection frozen; confirmation run enqueued",
                chosen_numeric)
    return {"changed": True, "state": driver["state"], "waiting": False,
            "chosen_numeric": chosen_numeric}


def _handle_confirm(conn, ledger, driver, reader) -> dict[str, Any]:
    run = driver["confirm"]["run"]
    reenq = _maybe_reenqueue_infra(conn, ledger, driver, [run], reader)
    status, metric = _resolve(reader, driver, run["cell_key"], run["work_item_id"])
    if status != "OK":
        return {"changed": reenq > 0, "state": driver["state"], "waiting": True,
                "confirm_status": status, "reenqueued": reenq}
    driver["confirm"]["result"] = metric
    _transition(driver, STATE_READY,
                "confirmation run measured; frozen for Q15 (Q15 is never automatic)", metric)
    return {"changed": True, "state": driver["state"], "waiting": False,
            "final_selection": driver["wf"]["final_selection"],
            "chosen_numeric": driver["confirm"]["chosen_numeric"], "confirm_result": metric}


def _counts(status: dict[str, Any]) -> dict[str, Any]:
    return {"measured": status["ok"], "pending": status["pending"],
            "infra": status["infra"], "total": status["total"]}


def _fmt_value(value: Any) -> str:
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def advance(*, ledger_path: Path, db_path: Path, param_grid: Optional[Path] = None,
            dry_run: bool = False,
            metric_reader: Optional[Callable[[str], tuple[str, Optional[dict]]]] = None,
            conn: Optional[sqlite3.Connection] = None) -> dict[str, Any]:
    """Advance the pilot one deterministic, idempotent step.

    Calling twice against an unchanged DB produces no new transition and no new
    rows (derived runs use deterministic UUIDs + INSERT OR IGNORE; transitions are
    appended only when the state actually changes).
    """
    ledger = _load_ledger(ledger_path)
    ledger["_ledger_path"] = str(ledger_path.resolve())
    driver = ledger["driver"]
    state = driver["state"]

    if state in TERMINAL_STATES:
        return {"state": state, "waiting": False, "terminal": True, "changed": False}

    owns_conn = conn is None
    if owns_conn:
        conn = sqlite3.connect(db_path, timeout=60)
        conn.execute("PRAGMA busy_timeout=30000")
    reader = metric_reader or _default_metric_reader(conn)
    try:
        conn.execute("BEGIN")
        if state == STATE_ENQUEUED:
            result = _handle_enqueued(conn, ledger, driver, reader)
        elif state == STATE_WF_COMBO:
            result = _handle_wf_combo(conn, ledger, driver, reader)
        elif state == STATE_FULLWINDOW:
            result = _handle_fullwindow(conn, ledger, driver, reader, param_grid)
        elif state == STATE_S5:
            result = _handle_s5(conn, ledger, driver, reader)
        elif state == STATE_CONFIRM:
            result = _handle_confirm(conn, ledger, driver, reader)
        else:
            raise CensusError(f"unknown driver state: {state}")

        if dry_run:
            conn.rollback()
            result["dry_run"] = True
            return result
        if result.get("changed"):
            conn.commit()
            ledger.pop("_ledger_path", None)
            _persist(ledger_path, ledger)
        else:
            conn.rollback()
        return result
    except Exception:
        conn.rollback()
        raise
    finally:
        if owns_conn:
            conn.close()


def report(*, ledger_path: Path, db_path: Path,
           metric_reader: Optional[Callable[[str], tuple[str, Optional[dict]]]] = None,
           conn: Optional[sqlite3.Connection] = None) -> dict[str, Any]:
    """Human-readable state snapshot for the monitoring loop (read-only)."""
    ledger = _load_ledger(ledger_path)
    driver = ledger["driver"]
    owns_conn = conn is None
    if owns_conn:
        conn = sqlite3.connect(db_path, timeout=60)
    reader = metric_reader or _default_metric_reader(conn)
    try:
        state = driver["state"]
        out: dict[str, Any] = {
            "program_id": ledger["program_id"], "state": state,
            "declared_trial_count": ledger["declared_trial_count"],
            "declared_trial_count_effective": ledger.get("declared_trial_count_effective",
                                                          ledger["declared_trial_count"]),
            "transitions": len(driver.get("transitions", [])),
            "terminal": state in TERMINAL_STATES,
        }
        if state == STATE_ENQUEUED:
            built = _all_measured(reader, driver, _census_specs(ledger))
            out["census"] = _counts(built)
        elif state == STATE_WF_COMBO:
            out["wf_combo"] = _counts(_all_measured(reader, driver, driver["wf"]["combo_runs"]))
        elif state == STATE_FULLWINDOW:
            out["fullwindow"] = _counts(_all_measured(reader, driver, driver["fullwindow"]["runs"]))
        elif state == STATE_S5:
            out["s5"] = _counts(_all_measured(reader, driver, driver["s5"]["runs"]))
            out["numeric_trial_increment"] = driver["s5"].get("numeric_trial_increment")
        elif state == STATE_CONFIRM:
            st, _ = _resolve(reader, driver, driver["confirm"]["run"]["cell_key"],
                             driver["confirm"]["run"]["work_item_id"])
            out["confirm_status"] = st
        elif state == STATE_READY:
            out["final_selection"] = driver["wf"]["final_selection"]
            out["chosen_numeric"] = driver.get("confirm", {}).get("chosen_numeric")
            out["next"] = "freeze as Q15 challenger (manual; Q15 is never automatic)"
        elif state == STATE_UNSTABLE:
            out["stability"] = driver["wf"].get("stability")
            out["next"] = "OWNER review — walk-forward selection did not stabilise"
        return out
    finally:
        if owns_conn:
            conn.close()
