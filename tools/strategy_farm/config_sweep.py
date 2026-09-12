"""Declared, append-only configuration sweeps for approved non-live siblings.

Unlike ``window_sweep``, this module has no sealed, program-specific grid.  A
declaration is the authority: it binds an approved card commit, source/binary
and base-set hashes, and every per-arm override before a factory row exists.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import math
import os
import sqlite3
import sys
import uuid
from pathlib import Path
from typing import Any, Mapping

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.strategy_farm import window_sweep as ws

SCHEMA = "qm.window-sweep.v1"
ENGINE = "config_sweep"
DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
NAMESPACE = uuid.UUID("a7c1e8bd-3024-5f9d-8bc9-cd7b5c21b312")
PRESCREEN_MODEL = 1
PRESCREEN_EVIDENCE_CLASS = "PRESCREEN"
PRESCREEN_VERDICT = "PRESCREEN_MEASURED"
REAL_EVIDENCE_CLASS = "REAL_TICKS"
PRESCREEN_ENABLE_ENV = "QM_OPT_CENSUS_PRESCREEN_ENABLED"


class ConfigSweepError(ValueError):
    pass


def _hash(path: Path | str) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _seal(value: Mapping[str, Any]) -> str:
    return hashlib.sha256((json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()).hexdigest()


def _write(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_document_bytes(value))


def _write_immutable(path: Path, value: Mapping[str, Any]) -> None:
    content = _document_bytes(value)
    if path.exists():
        if path.read_bytes() != content:
            raise ConfigSweepError(f"immutable artifact differs: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def _document_bytes(value: Mapping[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def _document_sha(value: Mapping[str, Any]) -> str:
    return hashlib.sha256(_document_bytes(value)).hexdigest()


def _prescreen(declaration: Mapping[str, Any]) -> bool:
    return declaration.get("prescreen_model") is not None


def _read(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ConfigSweepError(f"invalid JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ConfigSweepError("JSON root must be an object")
    return value


def _approved_card_commit(card: Path, expected: str) -> None:
    import subprocess
    actual = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", f"{expected}^{{commit}}"], text=True).strip()
    if actual != expected:
        raise ConfigSweepError("card authority must be a full resolved commit")
    committed = subprocess.check_output(["git", "-C", str(ROOT), "show", f"{actual}:{card.relative_to(ROOT).as_posix()}"], stderr=subprocess.DEVNULL)
    if committed.replace(b"\r\n", b"\n") != card.read_bytes().replace(b"\r\n", b"\n"):
        raise ConfigSweepError("approved card working copy differs from declared commit")


def _arms(declaration: Mapping[str, Any]) -> list[dict[str, Any]]:
    """Read literal arms, or a hash-bound review CSV, without inventing cells."""
    literal = declaration.get("arms")
    if isinstance(literal, list) and literal:
        return [dict(value) for value in literal]
    matrix = declaration.get("matrix_csv_path")
    expected = declaration.get("matrix_csv_sha256")
    if not matrix or not expected or _hash(Path(str(matrix))) != expected:
        raise ConfigSweepError("matrix CSV binding changed")
    with Path(str(matrix)).open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    fields = ("config_id", "clock_mode", "outside_rule", "buffer_points", "range_band_enabled", "range_end_hour", "range_end_minute", "range_bar_period", "exit_hour")
    grouped: dict[int, dict[str, str]] = {}
    for row in rows:
        if any(key not in row for key in fields):
            raise ConfigSweepError("matrix CSV schema drift")
        config = int(row["config_id"])
        old = grouped.setdefault(config, row)
        if any(old[key] != row[key] for key in fields):
            raise ConfigSweepError("matrix CSV configuration is not annual-invariant")
    if sorted(grouped) != list(range(50)):
        raise ConfigSweepError("matrix CSV must contain configurations 0..49")
    return [{"arm": f"c{config:02d}", "overrides": {
        "strategy_clock_mode": int(row["clock_mode"]), "strategy_outside_range_rule": int(row["outside_rule"]),
        "strategy_entry_buffer_points": int(row["buffer_points"]), "strategy_range_band_enabled": row["range_band_enabled"].lower(),
        "strategy_range_end_hour": int(row["range_end_hour"]), "strategy_range_end_minute": int(row["range_end_minute"]),
        "strategy_range_bar_period": int(row["range_bar_period"]), "strategy_exit_hour": int(row["exit_hour"]),
    }} for config, row in sorted(grouped.items())]


def validate_declaration(declaration: Mapping[str, Any]) -> None:
    unsigned = dict(declaration)
    stated = unsigned.pop("declaration_sha256", None)
    if stated != _seal(unsigned):
        raise ConfigSweepError("declaration hash mismatch")
    required = ("program_id", "ea_id", "ea_label", "symbol", "timeframe", "years", "base_setfile_path", "base_setfile_sha256", "artifact_identity", "approved_card_path", "approved_card_commit", "declared_trial_count")
    if declaration.get("schema") != SCHEMA or declaration.get("engine") != ENGINE or any(not declaration.get(k) for k in required):
        raise ConfigSweepError("incomplete config-sweep declaration")
    program = str(declaration["program_id"])
    if not program.startswith("WINSWEEP_"):
        raise ConfigSweepError("program_id must start WINSWEEP_")
    years = declaration["years"]
    arms = _arms(declaration)
    if years != list(range(2019, 2026)) or not isinstance(arms, list) or len(arms) * len(years) != int(declaration["declared_trial_count"]):
        raise ConfigSweepError("declared trial count/grid mismatch")
    if _prescreen(declaration):
        if declaration.get("prescreen_model") != PRESCREEN_MODEL:
            raise ConfigSweepError("OHLC-M1 PRESCREEN requires native MT5 Model=1")
        if declaration.get("prescreen_evidence_class") != PRESCREEN_EVIDENCE_CLASS:
            raise ConfigSweepError("prescreen evidence class must be PRESCREEN")
        try:
            keep = float(declaration["prescreen_keep_fraction"])
            control = float(declaration["prescreen_control_fraction"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ConfigSweepError("prescreen fractions are required") from exc
        if not 0 < keep <= 1 or not 0 <= control <= 1 or not str(declaration.get("prescreen_control_seed") or ""):
            raise ConfigSweepError("invalid prescreen keep/control declaration")
    card, base = Path(str(declaration["approved_card_path"])), Path(str(declaration["base_setfile_path"]))
    if not card.is_file() or not base.is_file() or _hash(base) != declaration["base_setfile_sha256"]:
        raise ConfigSweepError("bound card or base setfile changed")
    _approved_card_commit(card, str(declaration["approved_card_commit"]))
    values = ws.inputs(ws.text(base))
    if float(values.get("RISK_FIXED", 0)) <= 0 or float(values.get("RISK_PERCENT", 1)) != 0:
        raise ConfigSweepError("backtest risk contract drift")
    if int(values.get("qm_news_stale_max_hours", 999)) > 336:
        raise ConfigSweepError("news staleness exceeds 336-hour ceiling")
    identity = declaration["artifact_identity"]
    for key in ("mq5", "ex5"):
        path, digest = Path(str(identity.get(f"{key}_path", ""))), identity.get(f"{key}_sha256")
        if not path.is_file() or _hash(path) != digest:
            raise ConfigSweepError(f"bound {key} changed")
    seen: set[str] = set()
    for arm in arms:
        name, overrides = str(arm.get("arm", "")), arm.get("overrides")
        if not name or name in seen or not isinstance(overrides, dict):
            raise ConfigSweepError("invalid or duplicate arm")
        seen.add(name)
        for key in overrides:
            if key not in values:
                raise ConfigSweepError(f"override not present in base setfile: {key}")


def _render(base: str, overrides: Mapping[str, Any]) -> str:
    cell = {"start": 0, "length": 8, "exit": 18}
    # The shared renderer deliberately has a fixed three-key contract; generic
    # sweeps retain all line/comment formatting while replacing only declared keys.
    import re
    result = base
    for key, value in overrides.items():
        result, count = re.subn(rf"(?m)^\s*{re.escape(str(key))}\s*=.*$", f"{key}={value}", result)
        if count != 1:
            raise ConfigSweepError(f"setfile key is not unique: {key}")
    before, after = ws.inputs(base), ws.inputs(result)
    if set(before) != set(after) or any(before[k] != after[k] for k in before if k not in overrides):
        raise ConfigSweepError("undeclared setfile change")
    return result.replace("\r\n", "\n")


def cells(declaration: Mapping[str, Any], artifact: Path) -> list[dict[str, Any]]:
    result = []
    for config, arm in enumerate(_arms(declaration)):
        for year in declaration["years"]:
            key = f"{declaration['program_id']}:{year}:{arm['arm']}"
            prescreen = _prescreen(declaration)
            item_key = key + ":PRESCREEN" if prescreen else key
            result.append({"cell_key": item_key, "real_cell_key": key,
                           "work_item_id": str(uuid.uuid5(NAMESPACE, item_key)),
                           "real_work_item_id": str(uuid.uuid5(NAMESPACE, key)), "year": year,
                           "arm": arm["arm"], "config": config, "direction": "NONE", "predicate_id": 0, "overrides": arm["overrides"],
                           "evidence_class": PRESCREEN_EVIDENCE_CLASS if prescreen else REAL_EVIDENCE_CLASS,
                           "from_date": f"{year}.01.01", "to_date": f"{year}.12.31",
                           "setfile_path": str(artifact / "setfiles" / f"{declaration['ea_label']}_{declaration['symbol']}_{declaration['timeframe']}_{year}_{arm['arm']}.set")})
    return result


def _load_declaration(path: Path) -> dict[str, Any]:
    value = _read(path)
    validate_declaration(value)
    return value


def plan(declaration_path: Path, artifact: Path, *, controls_only: bool = False) -> dict[str, Any]:
    declaration = _load_declaration(declaration_path)
    all_cells = cells(declaration, artifact)
    selected = [cell for cell in all_cells if cell["config"] == 0] if controls_only else all_cells
    return {"schema": SCHEMA, "engine": ENGINE, "program_id": declaration["program_id"], "declaration": declaration,
            "declaration_path": str(declaration_path), "artifact": str(artifact), "controls_only": controls_only,
            "cells": selected, "planned_trials": len(selected)}


def _ledger(plan_value: Mapping[str, Any], rendered: Mapping[str, str]) -> dict[str, Any]:
    declaration = plan_value["declaration"]
    cells_value = []
    for cell in plan_value["cells"]:
        item = dict(cell)
        item["setfile_sha256"] = hashlib.sha256(rendered[cell["work_item_id"]].encode()).hexdigest()
        cells_value.append(item)
    value = {"schema": SCHEMA, "engine": ENGINE, "program_id": declaration["program_id"], "ea_id": declaration["ea_id"], "symbol": declaration.get("symbol") or declaration.get("host_symbol"),
             "declaration_sha256": declaration["declaration_sha256"], "years": declaration["years"],
             "evidence_class": PRESCREEN_EVIDENCE_CLASS if _prescreen(declaration) else REAL_EVIDENCE_CLASS,
             "cells": cells_value}
    value["ledger_sha256"] = _seal(value)
    return value


def authenticate_ledger(payload: Mapping[str, Any]) -> tuple[Path, dict[str, Any]]:
    if payload.get("schema") != SCHEMA or payload.get("sweep_engine") != ENGINE:
        raise ConfigSweepError("unregistered config sweep")
    declaration = _load_declaration(Path(str(payload.get("declaration_path", ""))))
    if declaration["declaration_sha256"] != payload.get("declaration_sha256"):
        raise ConfigSweepError("payload declaration mismatch")
    ledger_path = Path(str(payload.get("ledger_path", "")))
    ledger = _read(ledger_path)
    unsigned = dict(ledger); stated = unsigned.pop("ledger_sha256", None)
    if stated != _seal(unsigned) or ledger.get("declaration_sha256") != declaration["declaration_sha256"]:
        raise ConfigSweepError("ledger binding mismatch")
    cells_value = list(ledger.get("cells", []))
    amendment_path_raw = payload.get("promotion_amendment_path")
    if amendment_path_raw:
        amendment_path = Path(str(amendment_path_raw))
        amendment = _read(amendment_path)
        unsigned_amendment = dict(amendment); amendment_sha = unsigned_amendment.pop("amendment_sha256", None)
        if (
            amendment.get("schema") != "qm.config-sweep-prescreen-promotion/v1"
            or amendment.get("prescreen_verdict_created") is not False
            or amendment_sha != _seal(unsigned_amendment)
            or _hash(amendment_path) != payload.get("promotion_amendment_file_sha256")
            or amendment.get("ledger_sha256") != ledger.get("ledger_sha256")
            or amendment.get("declaration_sha256") != declaration["declaration_sha256"]
        ):
            raise ConfigSweepError("promotion amendment binding mismatch")
        snapshot_path = Path(str(amendment.get("ranking_snapshot_path") or ""))
        if not snapshot_path.is_file() or _hash(snapshot_path) != amendment.get("ranking_snapshot_sha256"):
            raise ConfigSweepError("ranking snapshot binding mismatch")
        snapshot = _read(snapshot_path)
        unsigned_snapshot = dict(snapshot); content_sha = unsigned_snapshot.pop("ranking_snapshot_content_sha256", None)
        if snapshot.get("schema") != "qm.config-sweep-prescreen-ranking/v1" or content_sha != _seal(unsigned_snapshot):
            raise ConfigSweepError("ranking snapshot envelope mismatch")
        cells_value.extend(amendment.get("real_cells") or [])
    target = next((item for item in cells_value if item.get("cell_key") == payload.get("cell_key")), None)
    if target is None:
        raise ConfigSweepError("candidate absent from ledger")
    for key in ("year", "arm", "direction", "predicate_id", "from_date", "to_date"):
        if target.get(key) != payload.get(key):
            raise ConfigSweepError(f"payload {key} mismatch")
    expected_class = target.get("evidence_class") or REAL_EVIDENCE_CLASS
    if payload.get("evidence_class", REAL_EVIDENCE_CLASS) != expected_class:
        raise ConfigSweepError("payload evidence class mismatch")
    if expected_class == PRESCREEN_EVIDENCE_CLASS and payload.get("prescreen_model") != PRESCREEN_MODEL:
        raise ConfigSweepError("payload prescreen model mismatch")
    expected = hashlib.sha256(_render(ws.text(declaration["base_setfile_path"]), target["overrides"]).encode()).hexdigest()
    if target.get("setfile_sha256") != expected or payload.get("expected_setfile_sha256") != expected or _hash(target["setfile_path"]) != expected:
        raise ConfigSweepError("candidate setfile binding mismatch")
    return ledger_path, {**ledger, "cells": cells_value}


def enqueue(plan_value: Mapping[str, Any], *, db: Path = DB, apply: bool = False) -> dict[str, Any]:
    declaration, artifact = plan_value["declaration"], Path(str(plan_value["artifact"]))
    validate_declaration(declaration)
    if apply and _prescreen(declaration) and os.environ.get(PRESCREEN_ENABLE_ENV, "").strip() != "1":
        raise ConfigSweepError(f"PRESCREEN is default-off; enable only during governed reload with {PRESCREEN_ENABLE_ENV}=1")
    if apply and db.resolve() == DB.resolve():
        ws.require_current_workers()
    base = ws.text(declaration["base_setfile_path"])
    rendered = {cell["work_item_id"]: _render(base, cell["overrides"]) for cell in plan_value["cells"]}
    ledger_path = artifact / ("controls_ledger.json" if plan_value["controls_only"] else "ledger.json")
    ledger = _ledger(plan_value, rendered)
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode={'rw' if apply else 'ro'}", uri=True, timeout=60); conn.row_factory = sqlite3.Row
    try:
        priority_ea = str(declaration.get("priority_reference_ea_id") or declaration["ea_id"])
        reference = conn.execute("SELECT id,payload_json FROM work_items WHERE ea_id=? AND phase='OPT_CENSUS' AND status='pending' AND json_extract(payload_json,'$.opt_census_frontier_priority')=1 LIMIT 1", (priority_ea,)).fetchone()
        if reference is None:
            raise ConfigSweepError("no declared priority-reference frontier row; no priority invented")
        reference_payload = json.loads(reference["payload_json"] or "{}")
        payloads: dict[str, dict[str, Any]] = {}
        for cell in plan_value["cells"]:
            h = hashlib.sha256(rendered[cell["work_item_id"]].encode()).hexdigest()
            payloads[cell["work_item_id"]] = {"priority_track": True, "opt_census_pool": True, "schema": SCHEMA, "sweep_engine": ENGINE, "program_id": declaration["program_id"], "cell_key": cell["cell_key"], "year": cell["year"], "arm": cell["arm"], "direction": cell["direction"], "predicate_id": cell["predicate_id"], "from_date": cell["from_date"], "to_date": cell["to_date"], "ledger_path": str(ledger_path), "declaration_path": plan_value["declaration_path"], "declaration_sha256": declaration["declaration_sha256"], "expected_setfile_sha256": h, "expected_ex5_sha256": declaration["artifact_identity"]["ex5_sha256"], "expected_mq5_sha256": declaration["artifact_identity"]["mq5_sha256"], "expected_expert": "QM\\" + declaration["ea_label"], "expected_symbol": declaration["symbol"], "expected_period": declaration["timeframe"], "expected_from_date": cell["from_date"], "expected_to_date": cell["to_date"], "evidence_binding_required": True, "opt_census_pool": True, "opt_census_frontier_priority": reference_payload.get("opt_census_frontier_priority") is True, "priority_source_work_item": reference["id"]}
            payloads[cell["work_item_id"]]["evidence_class"] = cell["evidence_class"]
            if cell["evidence_class"] == PRESCREEN_EVIDENCE_CLASS:
                payloads[cell["work_item_id"]].update({
                    "prescreen_model": PRESCREEN_MODEL,
                    "prescreen_real_work_item_id": cell["real_work_item_id"],
                    "prescreen_real_cell_key": cell["real_cell_key"],
                })
        existing = 0
        for cell in plan_value["cells"]:
            row = conn.execute("SELECT phase,ea_id,symbol,setfile_path,payload_json FROM work_items WHERE id=?", (cell["work_item_id"],)).fetchone()
            if row:
                old = json.loads(row["payload_json"] or "{}")
                if row["phase"] != "OPT_CENSUS" or row["ea_id"] != declaration["ea_id"] or row["symbol"] != declaration["symbol"] or row["setfile_path"] != cell["setfile_path"] or old.get("expected_setfile_sha256") != payloads[cell["work_item_id"]]["expected_setfile_sha256"]:
                    raise ConfigSweepError("idempotency collision")
                existing += 1
        result = {"apply": apply, "program_id": declaration["program_id"], "planned": len(plan_value["cells"]), "existing": existing, "new_rows": len(plan_value["cells"]) - existing}
        if not apply:
            return result
        artifact.mkdir(parents=True, exist_ok=True)
        declaration_target = artifact / "declaration.json"
        if declaration_target.exists() and _read(declaration_target) != declaration:
            raise ConfigSweepError("existing declaration differs")
        _write(declaration_target, declaration)
        if ledger_path.exists() and _read(ledger_path) != ledger:
            raise ConfigSweepError("existing ledger differs")
        _write(ledger_path, ledger)
        for cell in plan_value["cells"]:
            path = Path(cell["setfile_path"]); path.parent.mkdir(parents=True, exist_ok=True)
            wanted = rendered[cell["work_item_id"]].encode()
            if path.exists() and path.read_bytes() != wanted:
                raise ConfigSweepError("setfile drift")
            path.write_bytes(wanted)
        now = dt.datetime.now(dt.timezone.utc).isoformat(); conn.execute("BEGIN IMMEDIATE"); inserted = 0
        for cell in plan_value["cells"]:
            inserted += conn.execute("INSERT OR IGNORE INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,created_at,updated_at) VALUES (?,'backtest','OPT_CENSUS',?,?,?,'pending',0,?,?,?)", (cell["work_item_id"], declaration["ea_id"], declaration["symbol"], cell["setfile_path"], json.dumps(payloads[cell["work_item_id"]], sort_keys=True), now, now)).rowcount
        conn.commit(); result["inserted"] = inserted; return result
    except Exception:
        conn.rollback(); raise
    finally:
        conn.close()


def _measurement_score(evidence_path: Path, *, evidence_class: str) -> tuple[float, dict[str, Any]]:
    summary = _read(evidence_path)
    expected_model = PRESCREEN_MODEL if evidence_class == PRESCREEN_EVIDENCE_CLASS else 4
    if (
        summary.get("evidence_class", REAL_EVIDENCE_CLASS) != evidence_class
        or summary.get("model") != expected_model
        or not isinstance(summary.get("runs"), list)
        or not summary["runs"]
    ):
        raise ConfigSweepError("measurement evidence class/model mismatch")
    scores = []
    for run in summary["runs"]:
        try:
            net = float(run["net_profit"])
            drawdown = abs(float(run["drawdown"]))
        except (KeyError, TypeError, ValueError) as exc:
            raise ConfigSweepError("measurement evidence lacks ranking metrics") from exc
        score = net / max(drawdown, 1.0)
        if not math.isfinite(score):
            raise ConfigSweepError("non-finite measurement score")
        scores.append(score)
    return sum(scores) / len(scores), summary


def _promotion_documents(
    plan_value: Mapping[str, Any], *, db: Path, keep: float, control: float
) -> tuple[dict[str, Any], dict[str, Any], dict[str, dict[str, Any]]]:
    declaration = plan_value["declaration"]
    if not _prescreen(declaration):
        raise ConfigSweepError("promotion requires a PRESCREEN declaration")
    if abs(float(declaration["prescreen_keep_fraction"]) - keep) > 1e-12 or abs(float(declaration["prescreen_control_fraction"]) - control) > 1e-12:
        raise ConfigSweepError("promote fractions differ from the sealed declaration")
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True); conn.row_factory = sqlite3.Row
    try:
        observations = []
        source_payloads: dict[str, dict[str, Any]] = {}
        arm_scores: dict[str, list[float]] = {}
        for cell in plan_value["cells"]:
            row = conn.execute("SELECT * FROM work_items WHERE id=?", (cell["work_item_id"],)).fetchone()
            if row is None or row["status"] != "done" or row["verdict"] != PRESCREEN_VERDICT or not row["evidence_path"]:
                raise ConfigSweepError(f"PRESCREEN matrix incomplete: {cell['work_item_id']}")
            payload = json.loads(row["payload_json"] or "{}")
            if payload.get("evidence_class") != PRESCREEN_EVIDENCE_CLASS or payload.get("prescreen_model") != PRESCREEN_MODEL:
                raise ConfigSweepError("PRESCREEN row identity mismatch")
            evidence = Path(str(row["evidence_path"]))
            score, _summary = _measurement_score(evidence, evidence_class=PRESCREEN_EVIDENCE_CLASS)
            observations.append({
                "arm": cell["arm"], "year": cell["year"], "cell_key": cell["cell_key"],
                "work_item_id": cell["work_item_id"], "evidence_path": str(evidence),
                "evidence_sha256": _hash(evidence), "return_to_maxdd": score,
            })
            source_payloads[cell["work_item_id"]] = payload
            arm_scores.setdefault(str(cell["arm"]), []).append(score)
    finally:
        conn.close()
    years = list(declaration["years"])
    if any(len(values) != len(years) for values in arm_scores.values()):
        raise ConfigSweepError("PRESCREEN arm year-bundle is incomplete")
    ranking = sorted(
        ({"arm": arm, "mean_return_to_maxdd": sum(values) / len(values)} for arm, values in arm_scores.items()),
        key=lambda item: (-item["mean_return_to_maxdd"], item["arm"]),
    )
    keep_count = math.ceil(len(ranking) * keep)
    keep_arms = {item["arm"] for item in ranking[:keep_count]}
    control_arm = str(plan_value["cells"][0]["arm"])
    keep_arms.add(control_arm)
    dropped = [item["arm"] for item in ranking if item["arm"] not in keep_arms]
    control_count = math.ceil(len(dropped) * control) if dropped else 0
    seed = str(declaration["prescreen_control_seed"])
    control_arms = set(sorted(dropped, key=lambda arm: hashlib.sha256(f"{seed}:{arm}".encode()).hexdigest())[:control_count])
    snapshot_unsigned = {
        "schema": "qm.config-sweep-prescreen-ranking/v1", "program_id": declaration["program_id"],
        "declaration_sha256": declaration["declaration_sha256"], "metric": "mean_annual_return_to_maxdd",
        "keep_fraction": keep, "control_fraction_of_drops": control, "control_seed": seed,
        "mandatory_control_arm": control_arm, "ranking": ranking,
        "keep_arms": sorted(keep_arms), "dropped_arms": sorted(dropped), "control_arms": sorted(control_arms),
        "observations": observations,
    }
    snapshot = {**snapshot_unsigned, "ranking_snapshot_content_sha256": _seal(snapshot_unsigned)}
    snapshot_file_sha = _document_sha(snapshot)
    artifact = Path(str(plan_value["artifact"]))
    snapshot_path = artifact / "prescreen_promotions" / snapshot["ranking_snapshot_content_sha256"] / "ranking_snapshot.json"
    real_cells = []
    selected = keep_arms | control_arms
    for cell in plan_value["cells"]:
        if cell["arm"] not in selected:
            continue
        real = dict(cell)
        real.update({
            "cell_key": cell["real_cell_key"], "work_item_id": cell["real_work_item_id"],
            "evidence_class": REAL_EVIDENCE_CLASS,
            "setfile_sha256": _hash(Path(str(cell["setfile_path"]))),
            "promotion_role": "KEEP" if cell["arm"] in keep_arms else "CONTROL",
            "source_prescreen_work_item_id": cell["work_item_id"],
        })
        real_cells.append(real)
    ledger_path = artifact / ("controls_ledger.json" if plan_value["controls_only"] else "ledger.json")
    ledger = _read(ledger_path)
    amendment_unsigned = {
        "schema": "qm.config-sweep-prescreen-promotion/v1", "program_id": declaration["program_id"],
        "declaration_sha256": declaration["declaration_sha256"], "ledger_path": str(ledger_path),
        "ledger_sha256": ledger.get("ledger_sha256"), "ranking_snapshot_path": str(snapshot_path),
        "ranking_snapshot_sha256": snapshot_file_sha, "keep_fraction": keep,
        "control_fraction_of_drops": control, "real_cells": real_cells,
        "prescreen_verdict_created": False,
    }
    amendment = {**amendment_unsigned, "amendment_sha256": _seal(amendment_unsigned)}
    return snapshot, amendment, source_payloads


def promote(plan_value: Mapping[str, Any], *, db: Path = DB, keep: float,
            control: float = 0.10, apply: bool = False) -> dict[str, Any]:
    if not 0 < keep <= 1 or not 0 <= control <= 1:
        raise ConfigSweepError("keep/control fractions must be within (0,1] / [0,1]")
    snapshot, amendment, source_payloads = _promotion_documents(
        plan_value, db=db, keep=keep, control=control
    )
    snapshot_path = Path(str(amendment["ranking_snapshot_path"]))
    amendment_path = snapshot_path.parent / "promotion_amendment.json"
    amendment_file_sha = _document_sha(amendment)
    result = {
        "apply": apply, "program_id": plan_value["program_id"],
        "prescreen_cells": len(plan_value["cells"]),
        "keep_arms": len(snapshot["keep_arms"]), "control_arms": len(snapshot["control_arms"]),
        "dropped_arms": len(snapshot["dropped_arms"]), "real_cells": len(amendment["real_cells"]),
        "ranking_snapshot_path": str(snapshot_path), "ranking_snapshot_sha256": amendment["ranking_snapshot_sha256"],
        "promotion_amendment_path": str(amendment_path), "promotion_amendment_file_sha256": amendment_file_sha,
    }
    if not apply:
        return result
    if os.environ.get(PRESCREEN_ENABLE_ENV, "").strip() != "1":
        raise ConfigSweepError(f"PRESCREEN promotion is default-off; missing {PRESCREEN_ENABLE_ENV}=1")
    if db.resolve() == DB.resolve():
        ws.require_current_workers()
    _write_immutable(snapshot_path, snapshot)
    _write_immutable(amendment_path, amendment)
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=rw", uri=True, timeout=60); conn.row_factory = sqlite3.Row
    try:
        declaration = plan_value["declaration"]
        conn.execute("BEGIN IMMEDIATE"); inserted = 0; existing = 0
        for cell in amendment["real_cells"]:
            source_payload = source_payloads[cell["source_prescreen_work_item_id"]]
            declaration_fields = (
                "priority_track", "opt_census_pool", "schema", "sweep_engine",
                "program_id", "year", "arm", "direction", "predicate_id",
                "from_date", "to_date", "ledger_path", "declaration_path",
                "declaration_sha256", "expected_setfile_sha256", "expected_ex5_sha256",
                "expected_mq5_sha256", "expected_expert", "expected_symbol",
                "expected_period", "expected_from_date", "expected_to_date",
                "evidence_binding_required", "opt_census_frontier_priority",
                "priority_source_work_item",
            )
            payload = {key: source_payload[key] for key in declaration_fields if key in source_payload}
            payload.update({
                "cell_key": cell["cell_key"], "evidence_class": REAL_EVIDENCE_CLASS,
                "promotion_role": cell["promotion_role"],
                "source_prescreen_work_item_id": cell["source_prescreen_work_item_id"],
                "promotion_amendment_path": str(amendment_path),
                "promotion_amendment_file_sha256": amendment_file_sha,
                "ranking_snapshot_path": str(snapshot_path),
                "ranking_snapshot_sha256": amendment["ranking_snapshot_sha256"],
            })
            old = conn.execute("SELECT * FROM work_items WHERE id=?", (cell["work_item_id"],)).fetchone()
            if old is not None:
                old_payload = json.loads(old["payload_json"] or "{}")
                immutable_fields = (
                    "cell_key", "evidence_class", "promotion_role",
                    "source_prescreen_work_item_id", "promotion_amendment_path",
                    "promotion_amendment_file_sha256", "ranking_snapshot_sha256",
                )
                if (
                    old["phase"] != "OPT_CENSUS"
                    or old["setfile_path"] != cell["setfile_path"]
                    or any(old_payload.get(key) != payload.get(key) for key in immutable_fields)
                ):
                    raise ConfigSweepError("promotion idempotency collision")
                existing += 1; continue
            now = dt.datetime.now(dt.timezone.utc).isoformat()
            inserted += conn.execute(
                "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,created_at,updated_at) VALUES (?,'backtest','OPT_CENSUS',?,?,?,'pending',0,?,?,?)",
                (cell["work_item_id"], declaration["ea_id"], declaration["symbol"], cell["setfile_path"], json.dumps(payload, sort_keys=True), now, now),
            ).rowcount
        conn.commit(); result.update({"inserted": inserted, "existing": existing}); return result
    except Exception:
        conn.rollback(); raise
    finally:
        conn.close()


def prescreen_report(plan_value: Mapping[str, Any], *, promotion_amendment: Path,
                     db: Path = DB, output: Path) -> dict[str, Any]:
    amendment = _read(promotion_amendment)
    unsigned = dict(amendment); stated = unsigned.pop("amendment_sha256", None)
    if stated != _seal(unsigned) or amendment.get("program_id") != plan_value["program_id"]:
        raise ConfigSweepError("invalid promotion amendment")
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True); conn.row_factory = sqlite3.Row
    try:
        rows = []
        by_arm: dict[str, list[float]] = {}
        roles: dict[str, str] = {}
        for cell in amendment.get("real_cells") or []:
            row = conn.execute("SELECT * FROM work_items WHERE id=?", (cell["work_item_id"],)).fetchone()
            score = None
            if row is not None and row["status"] == "done" and row["verdict"] == "MEASURED" and row["evidence_path"]:
                score, _summary = _measurement_score(Path(str(row["evidence_path"])), evidence_class=REAL_EVIDENCE_CLASS)
                by_arm.setdefault(str(cell["arm"]), []).append(score)
            roles[str(cell["arm"])] = str(cell["promotion_role"])
            rows.append({"arm": cell["arm"], "year": cell["year"], "role": cell["promotion_role"],
                         "work_item_id": cell["work_item_id"], "status": row["status"] if row else "NOT_ENQUEUED",
                         "verdict": row["verdict"] if row else "", "real_return_to_maxdd": score})
    finally:
        conn.close()
    expected_years = len(plan_value["declaration"]["years"])
    arm_means = {arm: sum(values) / len(values) for arm, values in by_arm.items() if len(values) == expected_years}
    keep_scores = [score for arm, score in arm_means.items() if roles.get(arm) == "KEEP"]
    cutoff = min(keep_scores) if keep_scores and len(keep_scores) == sum(role == "KEEP" for role in roles.values()) else None
    controls = [arm for arm, role in roles.items() if role == "CONTROL" and arm in arm_means]
    false_negatives = [arm for arm in controls if cutoff is not None and arm_means[arm] > cutoff]
    rate = len(false_negatives) / len(controls) if controls and cutoff is not None else None
    suspended = rate is not None and rate > 0.10
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]) if rows else ["arm"]); writer.writeheader(); writer.writerows(rows)
    value = {"schema": "qm.config-sweep-prescreen-fn-report/v1", "program_id": plan_value["program_id"],
             "promotion_amendment_path": str(promotion_amendment), "rows": len(rows),
             "completed_control_arms": len(controls), "false_negative_arms": false_negatives,
             "false_negative_rate": rate, "suspend_threshold": 0.10,
             "prescreen_suspended": suspended, "report_path": str(output)}
    _write(output.with_suffix(".json"), value); return value


def report(plan_value: Mapping[str, Any], *, db: Path = DB, output: Path) -> dict[str, Any]:
    conn = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True); conn.row_factory = sqlite3.Row
    try:
        rows = []
        for cell in plan_value["cells"]:
            row = conn.execute("SELECT status,verdict,evidence_path FROM work_items WHERE id=?", (cell["work_item_id"],)).fetchone()
            rows.append({**{key: cell[key] for key in ("cell_key", "year", "arm", "config")}, "status": row["status"] if row else "NOT_ENQUEUED", "verdict": row["verdict"] if row else "", "evidence_path": row["evidence_path"] if row else ""})
    finally:
        conn.close()
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]) if rows else ["cell_key"]); writer.writeheader(); writer.writerows(rows)
    value = {"schema": SCHEMA, "engine": ENGINE, "program_id": plan_value["program_id"], "rows": len(rows), "measured": sum(row["verdict"] == "MEASURED" for row in rows), "prescreen_measured": sum(row["verdict"] == PRESCREEN_VERDICT for row in rows), "report_path": str(output)}
    _write(output.with_suffix(".json"), value); return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    for command in ("plan", "enqueue", "report", "promote", "prescreen-report"):
        item = sub.add_parser(command); item.add_argument("--declaration", type=Path, required=True); item.add_argument("--artifact", type=Path, required=True); item.add_argument("--controls-only", action="store_true")
        if command == "enqueue": item.add_argument("--apply", action="store_true")
        if command == "report": item.add_argument("--output", type=Path, required=True)
        if command == "promote":
            item.add_argument("--keep", type=float, required=True); item.add_argument("--control", type=float, default=0.10); item.add_argument("--apply", action="store_true")
        if command == "prescreen-report":
            item.add_argument("--promotion-amendment", type=Path, required=True); item.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(); value = plan(args.declaration, args.artifact, controls_only=args.controls_only)
    if args.command == "plan": result = {key: value[key] for key in ("program_id", "planned_trials", "controls_only")}
    elif args.command == "enqueue": result = enqueue(value, apply=args.apply)
    elif args.command == "report": result = report(value, output=args.output)
    elif args.command == "promote": result = promote(value, keep=args.keep, control=args.control, apply=args.apply)
    else: result = prescreen_report(value, promotion_amendment=args.promotion_amendment, output=args.output)
    print(json.dumps(result, sort_keys=True)); return 0


if __name__ == "__main__":
    raise SystemExit(main())
