"""Q14 deterministic optimization-card admission gate.

Q14 is an analytic fork after a completed Q10 PASS.  It never launches MT5 and
never changes the ordinary Q02--Q10 cascade.  The default mode is a read-only
dry run; ``--apply`` writes immutable opt cards/open trial ledgers and appends
terminal Q14 admission rows to the farm database.

The same database snapshot, program-config bytes, repository files, and output
root produce byte-identical opt-card bodies.  Deliberately, hashed card bodies
contain no wall-clock timestamp.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import itertools
import json
import math
import os
import re
import sqlite3
import tempfile
import uuid
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


OPT_PROGRAM_SCHEMA = "qm.opt-program/v1"
OPT_CARD_SCHEMA = "qm.opt-card/v1"
TRIAL_LEDGER_SCHEMA = "qm.opt-trial-ledger/v1"
PLAN_SCHEMA = "qm.q14-admission-plan/v1"
Q14_PAYLOAD_SCHEMA = "qm.q14-opt-admission/v1"
RISK_FIXED = 1000.0
RISK_PERCENT = 0.0
PREDICATE_ABLATION_LEVER = "PREDICATE_ABLATION"
CATEGORICAL_SURFACE_TYPE = "CATEGORICAL"
PREDICATE_DIRECTIONS = {"BUY", "SELL"}

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm")) / "state" / "farm_state.sqlite"
DEFAULT_CONFIG = REPO_ROOT / "tools" / "strategy_farm" / "config" / "opt_program.v1.json"
DEFAULT_REPORT_ROOT = Path(r"D:\QM\reports\opt_track")


class Q14Error(RuntimeError):
    """A fail-closed Q14 admission or artifact error."""


@dataclass(frozen=True)
class Q10Row:
    work_item_id: str
    ea_id: str
    ea_number: int
    symbol: str
    setfile_path: str
    evidence_path: str | None
    trades: int | None
    drawdown_pct: float | None

    @property
    def key(self) -> tuple[int, str]:
        return self.ea_number, self.symbol


def _canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _binding(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise Q14Error(f"bound file is missing: {resolved}")
    return {
        "path": str(resolved),
        "sha256": _sha256_file(resolved),
        "size_bytes": resolved.stat().st_size,
    }


def _ea_number(value: Any) -> int:
    match = re.fullmatch(r"(?:QM5[_-]?)?(\d+)", str(value or "").strip(), re.IGNORECASE)
    if not match:
        raise Q14Error(f"invalid EA id: {value!r}")
    return int(match.group(1))


def _ea_label(value: Any) -> str:
    return f"QM5_{_ea_number(value)}"


def _symbol(value: Any) -> str:
    token = str(value or "").strip().upper()
    if not token:
        raise Q14Error("symbol is empty")
    if "." not in token:
        token += ".DWX"
    if not re.fullmatch(r"[A-Z0-9_]+\.DWX", token):
        raise Q14Error(f"invalid DWX symbol: {value!r}")
    return token


def _read_json(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise Q14Error(f"{label} is missing or invalid: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise Q14Error(f"{label} must be a JSON object")
    return value, raw


def _iso_day(value: Any, label: str) -> dt.date:
    try:
        return dt.date.fromisoformat(str(value))
    except ValueError as exc:
        raise Q14Error(f"{label} must be an ISO date") from exc


def _validate_windows(raw: Any) -> list[dict[str, str]]:
    if not isinstance(raw, list) or not raw:
        raise Q14Error("comparison_windows must be a non-empty list")
    result: list[dict[str, str]] = []
    ids: set[str] = set()
    for index, item in enumerate(raw):
        if not isinstance(item, Mapping):
            raise Q14Error(f"comparison_windows[{index}] must be an object")
        window_id = str(item.get("id") or "").strip()
        kind = str(item.get("kind") or "").strip().upper()
        if not window_id or window_id in ids:
            raise Q14Error("comparison-window ids must be non-empty and unique")
        if kind not in {"Q04_ANCHORED_OOS", "POST_DEV_HOLDOUT"}:
            raise Q14Error(f"unsupported comparison-window kind: {kind!r}")
        start = _iso_day(item.get("start"), f"window {window_id}.start")
        end = _iso_day(item.get("end"), f"window {window_id}.end")
        if start > end:
            raise Q14Error(f"comparison window {window_id} starts after it ends")
        ids.add(window_id)
        result.append({"id": window_id, "kind": kind, "start": start.isoformat(), "end": end.isoformat()})
    if sum(row["kind"] == "Q04_ANCHORED_OOS" for row in result) < 3:
        raise Q14Error("at least three Q04_ANCHORED_OOS windows are required")
    if not any(row["kind"] == "POST_DEV_HOLDOUT" for row in result):
        raise Q14Error("a POST_DEV_HOLDOUT window is required")
    ordered = sorted(result, key=lambda row: (row["start"], row["end"], row["id"]))
    for left, right in zip(ordered, ordered[1:]):
        if right["start"] <= left["end"]:
            raise Q14Error(f"comparison windows overlap: {left['id']} and {right['id']}")
    return result


def _validate_success_metric(raw: Any, lever: str) -> dict[str, Any]:
    if not isinstance(raw, Mapping):
        raise Q14Error(f"lever {lever} success_metric must be an object")
    result = dict(raw)
    if result.get("primary") not in {"return_to_maxdd", "annual_return_pct", "sharpe", "profit_factor"}:
        raise Q14Error(f"lever {lever} has an unsupported Q16 success metric")
    if str(result.get("direction") or "").upper() != "MAXIMIZE":
        raise Q14Error(f"lever {lever} success metric must use direction=MAXIMIZE")
    result["direction"] = "MAXIMIZE"
    if lever == PREDICATE_ABLATION_LEVER and "minimum_improvement" not in result:
        raise Q14Error(f"lever {lever} minimum_improvement must be declared")
    try:
        result["minimum_improvement"] = float(result.get("minimum_improvement", 0.0))
    except (TypeError, ValueError) as exc:
        raise Q14Error(f"lever {lever} minimum_improvement must be numeric") from exc
    if lever == PREDICATE_ABLATION_LEVER and (
        not math.isfinite(result["minimum_improvement"])
        or result["minimum_improvement"] < 0
    ):
        raise Q14Error(
            f"lever {lever} minimum_improvement must be finite and non-negative"
        )
    return result


def validate_program(config: Mapping[str, Any]) -> dict[str, Any]:
    if config.get("schema") != OPT_PROGRAM_SCHEMA:
        raise Q14Error(f"program schema must be {OPT_PROGRAM_SCHEMA}")
    if not str(config.get("program_id") or "").strip():
        raise Q14Error("program_id is required")
    risk = config.get("risk_contract")
    if not isinstance(risk, Mapping):
        raise Q14Error("risk_contract is required")
    try:
        risk_pair = (float(risk.get("RISK_FIXED")), float(risk.get("RISK_PERCENT")))
    except (TypeError, ValueError) as exc:
        raise Q14Error("risk_contract values must be numeric") from exc
    if risk_pair != (RISK_FIXED, RISK_PERCENT):
        raise Q14Error("Q14 requires RISK_FIXED=1000 and RISK_PERCENT=0")
    caps = config.get("caps")
    if not isinstance(caps, Mapping):
        raise Q14Error("caps are required")
    try:
        max_concurrent = int(caps.get("max_concurrent_opt_cards"))
        max_parent = int(caps.get("max_cards_per_parent"))
    except (TypeError, ValueError) as exc:
        raise Q14Error("card caps must be integers") from exc
    if max_concurrent <= 0 or max_parent <= 0 or max_parent > max_concurrent:
        raise Q14Error("card caps must be positive and parent cap cannot exceed global cap")
    windows = _validate_windows(config.get("comparison_windows"))
    levers_raw = config.get("levers")
    if not isinstance(levers_raw, Mapping) or not levers_raw:
        raise Q14Error("levers must be a non-empty object")
    supported = {
        "EXIT_SURGERY",
        "VOL_REGIME_FILTER",
        "LOCKED_PORT",
        "MTF_ENTRY",
        PREDICATE_ABLATION_LEVER,
    }
    levers: dict[str, dict[str, Any]] = {}
    for name, raw in levers_raw.items():
        lever = str(name).upper()
        if lever not in supported or not isinstance(raw, Mapping):
            raise Q14Error(f"unsupported or invalid lever: {name!r}")
        definition = dict(raw)
        definition["enabled"] = bool(definition.get("enabled", False))
        definition["order"] = int(definition.get("order", 100))
        definition["success_metric"] = _validate_success_metric(definition.get("success_metric"), lever)
        if lever == "EXIT_SURGERY" and int(definition.get("min_trades", -1)) != 60:
            raise Q14Error("EXIT_SURGERY min_trades must be exactly 60")
        if lever == "VOL_REGIME_FILTER":
            if int(definition.get("min_trades", -1)) != 150:
                raise Q14Error("VOL_REGIME_FILTER min_trades must be exactly 150")
            if float(definition.get("min_max_drawdown_pct", -1)) != 12.0:
                raise Q14Error("VOL_REGIME_FILTER min_max_drawdown_pct must be exactly 12")
        if lever == "LOCKED_PORT" and definition.get("carrier_list_required") is not True:
            raise Q14Error("LOCKED_PORT must require an ex-ante carrier list")
        if lever == "MTF_ENTRY" and definition.get("backlog_only") is not True:
            raise Q14Error("MTF_ENTRY must remain backlog_only")
        levers[lever] = definition
    profiles_raw = config.get("surface_profiles")
    if not isinstance(profiles_raw, Mapping):
        raise Q14Error("surface_profiles must be an object")
    profiles = {str(name): dict(value) for name, value in profiles_raw.items() if isinstance(value, Mapping)}
    if len(profiles) != len(profiles_raw):
        raise Q14Error("every surface profile must be an object")
    cohort_raw = config.get("cohort_freeze")
    if not isinstance(cohort_raw, list):
        raise Q14Error("cohort_freeze must be a list")
    cohort: list[dict[str, Any]] = []
    seen: set[tuple[int, str]] = set()
    for index, raw in enumerate(cohort_raw):
        if not isinstance(raw, Mapping):
            raise Q14Error(f"cohort_freeze[{index}] must be an object")
        ea_number = _ea_number(raw.get("ea_id"))
        symbol = _symbol(raw.get("symbol"))
        key = (ea_number, symbol)
        if key in seen:
            raise Q14Error(f"duplicate frozen cohort identity: QM5_{ea_number}/{symbol}")
        candidate_levers = raw.get("levers")
        if not isinstance(candidate_levers, Mapping) or not candidate_levers:
            raise Q14Error(f"frozen cohort identity QM5_{ea_number}/{symbol} has no levers")
        normalized_levers: dict[str, dict[str, Any]] = {}
        for name, settings in candidate_levers.items():
            lever = str(name).upper()
            if lever not in levers or not isinstance(settings, Mapping):
                raise Q14Error(f"invalid cohort lever {name!r} for QM5_{ea_number}/{symbol}")
            entry = dict(settings)
            profile_name = entry.get("surface_profile")
            if profile_name is not None:
                if profile_name not in profiles:
                    raise Q14Error(f"unknown surface profile: {profile_name!r}")
                if "parameter_surface" in entry:
                    raise Q14Error("cohort lever cannot set both surface_profile and parameter_surface")
                entry["parameter_surface"] = profiles[str(profile_name)]
            if not isinstance(entry.get("parameter_surface"), Mapping):
                raise Q14Error(f"cohort lever {lever} requires an exact parameter surface")
            if not str(entry.get("hypothesis") or "").strip():
                raise Q14Error(f"cohort lever {lever} requires a falsifiable hypothesis")
            normalized_levers[lever] = entry
        seen.add(key)
        cohort.append({
            "ea_id": f"QM5_{ea_number}",
            "ea_number": ea_number,
            "symbol": symbol,
            "priority": int(raw.get("priority", index + 1)),
            "levers": normalized_levers,
        })
    result = dict(config)
    result["risk_contract"] = {"RISK_FIXED": RISK_FIXED, "RISK_PERCENT": RISK_PERCENT}
    result["caps"] = {"max_concurrent_opt_cards": max_concurrent, "max_cards_per_parent": max_parent}
    result["comparison_windows"] = windows
    result["levers"] = levers
    result["surface_profiles"] = profiles
    result["cohort_freeze"] = cohort
    return result


def _read_risk_contract(path: Path) -> tuple[float, float]:
    text = path.read_text(encoding="utf-8-sig")
    values: dict[str, float] = {}
    for name in ("RISK_FIXED", "RISK_PERCENT"):
        match = re.search(rf"(?mi)^\s*{name}\s*=\s*([-+0-9.eE]+)\s*$", text)
        if not match:
            raise Q14Error(f"parent setfile lacks {name}: {path}")
        values[name] = float(match.group(1))
    return values["RISK_FIXED"], values["RISK_PERCENT"]


def _resolve_parent(row: Q10Row, repo_root: Path) -> dict[str, Any]:
    setfile = Path(row.setfile_path)
    if not setfile.is_absolute():
        setfile = repo_root / setfile
    setfile = setfile.resolve()
    if not setfile.is_file():
        raise Q14Error(f"parent setfile is missing: {setfile}")
    if _read_risk_contract(setfile) != (RISK_FIXED, RISK_PERCENT):
        raise Q14Error(f"parent setfile must use RISK_FIXED=1000 and RISK_PERCENT=0: {setfile}")
    ea_dir = setfile.parent.parent if setfile.parent.name.lower() == "sets" else None
    expected_prefix = f"QM5_{row.ea_number}_"
    if ea_dir is None or not ea_dir.name.upper().startswith(expected_prefix.upper()):
        matches = sorted((repo_root / "framework" / "EAs").glob(f"QM5_{row.ea_number}_*"))
        if len(matches) != 1:
            raise Q14Error(f"cannot resolve one EA directory for {row.ea_id}: {len(matches)} matches")
        ea_dir = matches[0]
    binary = ea_dir / f"{ea_dir.name}.ex5"
    evidence: dict[str, Any] | None = None
    if row.evidence_path:
        evidence_path = Path(row.evidence_path)
        if not evidence_path.is_absolute():
            evidence_path = repo_root / evidence_path
        if not evidence_path.is_file():
            raise Q14Error(f"Q10 PASS evidence is missing: {evidence_path}")
        evidence = _binding(evidence_path)
    else:
        raise Q14Error(f"Q10 PASS row has no evidence path: {row.work_item_id}")
    return {
        "ea_id": row.ea_id,
        "symbol": row.symbol,
        "binary": _binding(binary),
        "setfile": _binding(setfile),
        "q10": {
            "work_item_id": row.work_item_id,
            "verdict": "PASS",
            "evidence": evidence,
            "metrics": {"trades": row.trades, "max_drawdown_pct": row.drawdown_pct},
        },
    }


def load_q10_population(conn: sqlite3.Connection) -> list[Q10Row]:
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT w.id,w.ea_id,w.symbol,w.setfile_path,w.evidence_path,w.updated_at,
               m.trades,m.drawdown_pct
        FROM work_items AS w
        LEFT JOIN ea_metrics AS m ON m.work_item_id=w.id
        WHERE upper(w.phase)='Q10'
          AND lower(w.status)='done'
          AND upper(coalesce(w.verdict,''))='PASS'
        ORDER BY w.updated_at DESC,w.id DESC
        """
    ).fetchall()
    distinct: dict[tuple[int, str], Q10Row] = {}
    for raw in rows:
        ea_number = _ea_number(raw["ea_id"])
        symbol = _symbol(raw["symbol"])
        key = (ea_number, symbol)
        if key in distinct:
            continue
        trades = int(raw["trades"]) if raw["trades"] is not None else None
        drawdown = float(raw["drawdown_pct"]) if raw["drawdown_pct"] is not None else None
        distinct[key] = Q10Row(
            work_item_id=str(raw["id"]),
            ea_id=f"QM5_{ea_number}",
            ea_number=ea_number,
            symbol=symbol,
            setfile_path=str(raw["setfile_path"]),
            evidence_path=str(raw["evidence_path"]) if raw["evidence_path"] else None,
            trades=trades,
            drawdown_pct=drawdown,
        )
    return [distinct[key] for key in sorted(distinct)]


def _surface(entry: Mapping[str, Any], lever: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    raw = entry.get("parameter_surface")
    if not isinstance(raw, Mapping):
        raise Q14Error(f"{lever} parameter surface must be an object")
    result = json.loads(json.dumps(raw))
    parameters = result.get("parameters", [])
    fixed = result.get("fixed_parameters", {})
    if not isinstance(parameters, list) or not isinstance(fixed, Mapping):
        raise Q14Error(f"{lever} parameter surface needs parameters list and fixed_parameters object")

    surface_type = str(result.get("surface_type") or "NUMERIC").strip().upper()
    if lever == PREDICATE_ABLATION_LEVER:
        if surface_type != CATEGORICAL_SURFACE_TYPE:
            raise Q14Error(
                f"{PREDICATE_ABLATION_LEVER} requires surface_type={CATEGORICAL_SURFACE_TYPE}"
            )
        if parameters:
            raise Q14Error(f"{PREDICATE_ABLATION_LEVER} categorical surface cannot declare numeric parameters")
        minimum_fire_count = result.get("minimum_dev_fire_count")
        if isinstance(minimum_fire_count, bool) or not isinstance(minimum_fire_count, int) or minimum_fire_count <= 0:
            raise Q14Error(
                f"{PREDICATE_ABLATION_LEVER} requires a positive integer minimum_dev_fire_count"
            )
        raw_trials = result.get("predicate_trials")
        if not isinstance(raw_trials, list) or len(raw_trials) < 2:
            raise Q14Error(f"{PREDICATE_ABLATION_LEVER} requires at least two predicate_trials")
        normalized_trials: list[dict[str, str]] = []
        seen_trials: set[tuple[str, str]] = set()
        for index, raw_trial in enumerate(raw_trials):
            if not isinstance(raw_trial, Mapping):
                raise Q14Error(f"{PREDICATE_ABLATION_LEVER} predicate_trials[{index}] must be an object")
            predicate_id = str(raw_trial.get("predicate_id") or "").strip()
            direction = str(raw_trial.get("direction") or "").strip().upper()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", predicate_id):
                raise Q14Error(
                    f"{PREDICATE_ABLATION_LEVER} predicate_trials[{index}] has an invalid predicate_id"
                )
            if direction not in PREDICATE_DIRECTIONS:
                raise Q14Error(
                    f"{PREDICATE_ABLATION_LEVER} predicate_trials[{index}] direction must be BUY or SELL"
                )
            key = (predicate_id, direction)
            if key in seen_trials:
                raise Q14Error(
                    f"{PREDICATE_ABLATION_LEVER} predicate_trials contains duplicate {predicate_id}/{direction}"
                )
            seen_trials.add(key)
            normalized_trials.append({"predicate_id": predicate_id, "direction": direction})
        result["surface_type"] = CATEGORICAL_SURFACE_TYPE
        result["predicate_trials"] = normalized_trials
        planned = [
            {"trial_id": f"T{index:03d}", **trial}
            for index, trial in enumerate(normalized_trials, 1)
        ]
        if len(planned) > 64:
            raise Q14Error(f"{lever} surface declares too many trials: {len(planned)}")
        return result, planned

    if surface_type != "NUMERIC":
        raise Q14Error(f"{lever} does not support surface_type={surface_type or '<empty>'}")
    names: set[str] = set()
    value_axes: list[tuple[str, list[Any]]] = []
    for index, parameter in enumerate(parameters):
        if not isinstance(parameter, Mapping):
            raise Q14Error(f"{lever} parameter[{index}] must be an object")
        name = str(parameter.get("name") or "").strip()
        values = parameter.get("candidate_values")
        bounds = parameter.get("bounds")
        if not name or name in names or not isinstance(values, list) or not values:
            raise Q14Error(f"{lever} parameter[{index}] needs a unique name and candidate_values")
        if not isinstance(bounds, Mapping) or "minimum" not in bounds or "maximum" not in bounds:
            raise Q14Error(f"{lever} parameter {name} needs explicit minimum/maximum bounds")
        try:
            lower, upper = float(bounds["minimum"]), float(bounds["maximum"])
            if lower > upper or any(not lower <= float(value) <= upper for value in values):
                raise Q14Error(f"{lever} parameter {name} values fall outside its bounds")
        except (TypeError, ValueError) as exc:
            raise Q14Error(f"{lever} parameter {name} bounds/values must be numeric") from exc
        names.add(name)
        value_axes.append((name, list(values)))
    if lever in {"EXIT_SURGERY", "VOL_REGIME_FILTER"} and len(value_axes) != 1:
        raise Q14Error(f"{lever} must declare exactly one tunable parameter")
    planned: list[dict[str, Any]] = []
    if lever == "LOCKED_PORT":
        carriers = entry.get("carrier_list")
        if not isinstance(carriers, list) or not carriers:
            return result, []
        normalized = [_symbol(value) for value in carriers]
        if len(set(normalized)) != len(normalized):
            raise Q14Error("LOCKED_PORT carrier list contains duplicates")
        result["carrier_list"] = normalized
        planned = [{"trial_id": f"T{index:03d}", "carrier": carrier} for index, carrier in enumerate(normalized, 1)]
    else:
        combinations: Iterable[Sequence[Any]] = itertools.product(*(axis for _, axis in value_axes))
        for index, values in enumerate(combinations, 1):
            planned.append({
                "trial_id": f"T{index:03d}",
                "parameters": {name: value for (name, _), value in zip(value_axes, values)},
            })
    if len(planned) > 64:
        raise Q14Error(f"{lever} surface declares too many trials: {len(planned)}")
    return result, planned


def _eligibility(row: Q10Row, lever: str, definition: Mapping[str, Any], entry: Mapping[str, Any]) -> tuple[bool, str]:
    if not definition.get("enabled"):
        return False, "LEVER_DISABLED"
    if lever == "MTF_ENTRY":
        return False, "BACKLOG_ONLY"
    if lever == "LOCKED_PORT":
        carriers = entry.get("carrier_list")
        if not isinstance(carriers, list) or not carriers:
            return False, "CARRIER_LIST_REQUIRED"
        return True, "LOCKED_PORT_CARRIER_LIST_FROZEN"
    if row.trades is None or row.drawdown_pct is None:
        return False, "Q10_METRICS_MISSING"
    if lever == PREDICATE_ABLATION_LEVER:
        return True, "PREDICATE_ABLATION_Q10_PASS"
    if lever == "EXIT_SURGERY":
        minimum = int(definition["min_trades"])
        if row.trades < minimum:
            return False, f"TRADES_BELOW_{minimum}"
        return True, f"TRADES_GTE_{minimum}"
    if lever == "VOL_REGIME_FILTER":
        minimum_trades = int(definition["min_trades"])
        minimum_dd = float(definition["min_max_drawdown_pct"])
        if row.trades < minimum_trades:
            return False, f"TRADES_BELOW_{minimum_trades}"
        if row.drawdown_pct < minimum_dd:
            return False, f"MAX_DRAWDOWN_BELOW_{minimum_dd:g}"
        return True, f"TRADES_GTE_{minimum_trades}_AND_MAX_DRAWDOWN_GTE_{minimum_dd:g}"
    raise Q14Error(f"unsupported lever: {lever}")


def _snapshot_hash(rows: Sequence[Q10Row]) -> str:
    body = [
        {
            "work_item_id": row.work_item_id,
            "ea_id": row.ea_id,
            "symbol": row.symbol,
            "setfile_path": row.setfile_path,
            "evidence_path": row.evidence_path,
            "trades": row.trades,
            "max_drawdown_pct": row.drawdown_pct,
        }
        for row in rows
    ]
    return _sha256_bytes(_canonical_bytes(body))


def _card_id(
    *,
    row: Q10Row,
    lever: str,
    parent: Mapping[str, Any],
    config_sha256: str,
    surface: Mapping[str, Any],
) -> str:
    seed = {
        "schema": OPT_CARD_SCHEMA,
        "ea_id": row.ea_id,
        "symbol": row.symbol,
        "lever": lever,
        "binary_sha256": parent["binary"]["sha256"],
        "setfile_sha256": parent["setfile"]["sha256"],
        "config_sha256": config_sha256,
        "parameter_surface": surface,
    }
    digest = _sha256_bytes(_canonical_bytes(seed))[:16]
    symbol = row.symbol.split(".", 1)[0]
    return f"OPT-{row.ea_number}-{symbol}-{lever.replace('_', '-')}-{digest}"


def _work_item_id(row: Q10Row, lever: str, config_sha256: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"qm:q14:{row.work_item_id}:{lever}:{config_sha256}"))


def _existing_card_state(
    conn: sqlite3.Connection, *, program_id: str
) -> tuple[set[str], Counter[tuple[int, str]]]:
    """Open-card pool for cap enforcement, scoped to a single program's own cards.

    A census program and the live wave-1 opt-cards must never share a counter
    (plan v2 A6): each program's ``max_concurrent_opt_cards``/``max_cards_per_parent``
    cap is checked only against cards admitted under that same ``program_id``.
    A row admitted before ``program_id`` was recorded (no key present) is
    conservatively counted toward every program's pool rather than silently
    dropped from cap enforcement.
    """
    open_cards: dict[str, tuple[int, str]] = {}
    q14_rows = conn.execute(
        "SELECT ea_id,symbol,payload_json FROM work_items WHERE upper(phase)='Q14' AND upper(coalesce(verdict,''))='OPT_ELIGIBLE'"
    ).fetchall()
    for row in q14_rows:
        try:
            payload = json.loads(row["payload_json"])
            card_id = str(payload["card_id"])
            key = (_ea_number(row["ea_id"]), _symbol(row["symbol"]))
        except (KeyError, TypeError, ValueError, json.JSONDecodeError, Q14Error):
            continue
        row_program_id = payload.get("program_id")
        if row_program_id is not None and str(row_program_id) != program_id:
            continue
        open_cards[card_id] = key
    q16_rows = conn.execute(
        "SELECT payload_json FROM work_items WHERE upper(phase)='Q16' AND lower(status) IN ('done','failed')"
    ).fetchall()
    for row in q16_rows:
        try:
            card_id = str(json.loads(row["payload_json"])["card_id"])
        except (KeyError, TypeError, json.JSONDecodeError):
            continue
        open_cards.pop(card_id, None)
    return set(open_cards), Counter(open_cards.values())


def _decision_payload(
    *,
    row: Q10Row,
    lever: str,
    verdict: str,
    reason: str,
    config_sha256: str,
    snapshot_sha256: str,
    card_id: str | None,
    card_path: Path | None,
    card_sha256: str | None,
    program_id: str,
) -> dict[str, Any]:
    return {
        "schema": Q14_PAYLOAD_SCHEMA,
        "phase": "Q14",
        "source_q10_work_item_id": row.work_item_id,
        "program_id": program_id,
        "program_config_sha256": config_sha256,
        "q10_snapshot_sha256": snapshot_sha256,
        "lever": lever,
        "admission_verdict": verdict,
        "reason": reason,
        "card_id": card_id,
        "opt_card_path": str(card_path) if card_path else None,
        "opt_card_sha256": card_sha256,
        "execution_lane": "ANALYTIC_NO_TERMINAL",
    }


def build_plan(
    conn: sqlite3.Connection,
    *,
    config: Mapping[str, Any],
    config_sha256: str,
    repo_root: Path,
    report_root: Path,
) -> dict[str, Any]:
    conn.row_factory = sqlite3.Row
    q10_rows = load_q10_population(conn)
    q10_by_key = {row.key: row for row in q10_rows}
    snapshot_sha256 = _snapshot_hash(q10_rows)
    open_cards, open_by_parent = _existing_card_state(conn, program_id=str(config["program_id"]))
    max_concurrent = int(config["caps"]["max_concurrent_opt_cards"])
    max_parent = int(config["caps"]["max_cards_per_parent"])
    decisions: list[dict[str, Any]] = []
    candidates: list[
        tuple[int, int, int, str, str, Mapping[str, Any], Mapping[str, Any], Q10Row]
    ] = []
    missing_frozen_q10: list[dict[str, str]] = []
    for frozen in config["cohort_freeze"]:
        key = (int(frozen["ea_number"]), str(frozen["symbol"]))
        row = q10_by_key.get(key)
        if row is None:
            missing_frozen_q10.append({"ea_id": frozen["ea_id"], "symbol": frozen["symbol"]})
            continue
        for lever, entry in frozen["levers"].items():
            definition = config["levers"][lever]
            candidates.append((
                int(frozen["priority"]), int(definition["order"]), row.ea_number,
                row.symbol, lever, definition, entry, row,
            ))
    candidates.sort(key=lambda item: (item[0], item[1], item[2], item[3]))
    global_count = len(open_cards)
    parent_counts = Counter(open_by_parent)
    for _, _, _, _, lever, definition, entry, row in candidates:
        work_item_id = _work_item_id(row, lever, config_sha256)
        eligible, reason = _eligibility(row, lever, definition, entry)
        parent: dict[str, Any] | None = None
        surface: dict[str, Any] | None = None
        planned_trials: list[dict[str, Any]] = []
        card: dict[str, Any] | None = None
        ledger: dict[str, Any] | None = None
        card_id: str | None = None
        card_path: Path | None = None
        ledger_path: Path | None = None
        card_sha256: str | None = None
        if eligible:
            try:
                parent = _resolve_parent(row, repo_root)
                surface, planned_trials = _surface(entry, lever)
                if not planned_trials:
                    eligible, reason = False, "NO_DECLARED_TRIALS"
            except Q14Error as exc:
                eligible, reason = False, f"PARENT_OR_SURFACE_INVALID:{exc}"
        if eligible and parent is not None and surface is not None:
            card_id = _card_id(
                row=row, lever=lever, parent=parent,
                config_sha256=config_sha256, surface=surface,
            )
            already_open = card_id in open_cards
            if not already_open and global_count >= max_concurrent:
                eligible, reason = False, f"MAX_CONCURRENT_OPT_CARDS_{max_concurrent}"
            elif not already_open and parent_counts[row.key] >= max_parent:
                eligible, reason = False, f"MAX_CARDS_PER_PARENT_{max_parent}"
            else:
                card_path = (report_root / card_id / "opt_card.json").resolve()
                ledger_path = (report_root / card_id / "trial_ledger.json").resolve()
                card = {
                    "schema": OPT_CARD_SCHEMA,
                    "card_id": card_id,
                    "program": {
                        "program_id": config["program_id"],
                        "config_sha256": config_sha256,
                        "q10_snapshot_sha256": snapshot_sha256,
                    },
                    "parent": parent,
                    "lever": lever,
                    "hypothesis": str(entry["hypothesis"]),
                    "parameter_surface": surface,
                    "comparison_windows": list(config["comparison_windows"]),
                    "success_metric": dict(definition["success_metric"]),
                    "trial_ledger_path": str(ledger_path),
                }
                ledger = {
                    "schema": TRIAL_LEDGER_SCHEMA,
                    "card_id": card_id,
                    "status": "OPENED",
                    "declared_trial_count": len(planned_trials),
                    "planned_trials": planned_trials,
                    "trials": [],
                }
                card_sha256 = _sha256_bytes(_canonical_bytes(card))
                if not already_open:
                    global_count += 1
                    parent_counts[row.key] += 1
        verdict = "OPT_ELIGIBLE" if eligible else "OPT_REJECTED"
        if not eligible:
            card_id = card_path = ledger_path = card_sha256 = card = ledger = None
        payload = _decision_payload(
            row=row, lever=lever, verdict=verdict, reason=reason,
            config_sha256=config_sha256, snapshot_sha256=snapshot_sha256,
            card_id=card_id, card_path=card_path, card_sha256=card_sha256,
            program_id=str(config["program_id"]),
        )
        decisions.append({
            "work_item_id": work_item_id,
            "ea_id": row.ea_id,
            "symbol": row.symbol,
            "lever": lever,
            "verdict": verdict,
            "reason": reason,
            "source_q10_work_item_id": row.work_item_id,
            "card_id": card_id,
            "opt_card_path": str(card_path) if card_path else None,
            "opt_card_sha256": card_sha256,
            "trial_ledger_path": str(ledger_path) if ledger_path else None,
            "opt_card_body": card,
            "trial_ledger_body": ledger,
            "work_item_payload": payload,
            "setfile_path": row.setfile_path,
        })
    counts = Counter(decision["verdict"] for decision in decisions)
    return {
        "schema": PLAN_SCHEMA,
        "program_id": config["program_id"],
        "program_config_sha256": config_sha256,
        "q10_snapshot_sha256": snapshot_sha256,
        "source_q10_pass_pairs": len(q10_rows),
        "frozen_cohort_pairs": len(config["cohort_freeze"]),
        "frozen_pairs_without_q10_pass": missing_frozen_q10,
        "open_opt_cards_before": len(open_cards),
        "caps": dict(config["caps"]),
        "counts": {"OPT_ELIGIBLE": counts["OPT_ELIGIBLE"], "OPT_REJECTED": counts["OPT_REJECTED"]},
        "decisions": decisions,
    }


def _atomic_create_or_match(path: Path, body: Mapping[str, Any], *, immutable: bool) -> bool:
    expected = _canonical_bytes(body)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if immutable and path.read_bytes() != expected:
            raise Q14Error(f"immutable artifact differs from deterministic body: {path}")
        if not immutable:
            existing, _ = _read_json(path, "existing trial ledger")
            if existing.get("schema") != TRIAL_LEDGER_SCHEMA or existing.get("card_id") != body.get("card_id"):
                raise Q14Error(f"existing trial ledger has wrong identity: {path}")
        return False
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(expected)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
    return True


def apply_plan(conn: sqlite3.Connection, plan: Mapping[str, Any]) -> dict[str, Any]:
    created_cards = 0
    created_ledgers = 0
    created_rows = 0
    idempotent_rows = 0
    for decision in plan["decisions"]:
        card = decision["opt_card_body"]
        ledger = decision["trial_ledger_body"]
        if card is not None:
            created_cards += int(_atomic_create_or_match(Path(decision["opt_card_path"]), card, immutable=True))
            created_ledgers += int(_atomic_create_or_match(Path(decision["trial_ledger_path"]), ledger, immutable=False))
        payload_json = json.dumps(decision["work_item_payload"], sort_keys=True)
        existing = conn.execute("SELECT * FROM work_items WHERE id=?", (decision["work_item_id"],)).fetchone()
        if existing is not None:
            if (
                str(existing["payload_json"]) != payload_json
                or str(existing["verdict"]) != decision["verdict"]
                or str(existing["status"]).lower() != "done"
            ):
                raise Q14Error(f"deterministic Q14 work-item id collides with different state: {decision['work_item_id']}")
            idempotent_rows += 1
            continue
        now = dt.datetime.now(dt.timezone.utc).isoformat()
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                created_at,updated_at
            ) VALUES(?,?,?,?,?,?,'done',?,0,NULL,?,NULL,?,?,?)
            """,
            (
                decision["work_item_id"], "analytic", "Q14", decision["ea_id"],
                decision["symbol"], decision["setfile_path"], decision["verdict"],
                decision["opt_card_path"], payload_json, now, now,
            ),
        )
        created_rows += 1
    return {
        "created_opt_cards": created_cards,
        "created_trial_ledgers": created_ledgers,
        "created_q14_rows": created_rows,
        "idempotent_q14_rows": idempotent_rows,
    }


def _public_plan(plan: Mapping[str, Any], *, dry_run: bool, apply_result: Mapping[str, Any] | None = None) -> dict[str, Any]:
    decisions = []
    for raw in plan["decisions"]:
        decisions.append({key: value for key, value in raw.items() if key not in {
            "opt_card_body", "trial_ledger_body", "work_item_payload", "setfile_path",
        }})
    result = {key: value for key, value in plan.items() if key != "decisions"}
    result["dry_run"] = dry_run
    result["applied"] = not dry_run
    result["decisions"] = decisions
    if apply_result is not None:
        result["apply_result"] = dict(apply_result)
    return result


def run_admission(
    *,
    db_path: Path = DEFAULT_DB,
    config_path: Path = DEFAULT_CONFIG,
    repo_root: Path = REPO_ROOT,
    report_root: Path = DEFAULT_REPORT_ROOT,
    apply: bool = False,
) -> dict[str, Any]:
    config_path = Path(config_path).resolve()
    config_raw, config_bytes = _read_json(config_path, "optimization program")
    config = validate_program(config_raw)
    config_sha256 = _sha256_bytes(config_bytes)
    database = Path(db_path).resolve()
    if not database.is_file():
        raise Q14Error(f"farm database is missing: {database}")
    conn = sqlite3.connect(str(database), timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        if apply:
            conn.execute("BEGIN IMMEDIATE")
        plan = build_plan(
            conn, config=config, config_sha256=config_sha256,
            repo_root=Path(repo_root).resolve(), report_root=Path(report_root),
        )
        if not apply:
            return _public_plan(plan, dry_run=True)
        applied = apply_plan(conn, plan)
        conn.commit()
        return _public_plan(plan, dry_run=False, apply_result=applied)
    except Exception:
        if apply:
            conn.rollback()
        raise
    finally:
        conn.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Q14 deterministic optimization-card admission")
    parser.add_argument("--db", default=str(DEFAULT_DB))
    parser.add_argument("--config", default=str(DEFAULT_CONFIG))
    parser.add_argument("--repo-root", default=str(REPO_ROOT))
    parser.add_argument("--report-root", default=str(DEFAULT_REPORT_ROOT))
    parser.add_argument("--apply", action="store_true", help="write cards/ledgers and append Q14 rows")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = run_admission(
            db_path=Path(args.db), config_path=Path(args.config),
            repo_root=Path(args.repo_root), report_root=Path(args.report_root),
            apply=bool(args.apply),
        )
    except Q14Error as exc:
        print(json.dumps({"schema": PLAN_SCHEMA, "error": str(exc)}, indent=2, sort_keys=True))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
