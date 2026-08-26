"""Append-only automation for the mandatory optimization/requalification fork.

The driver owns *routing*, not gate adjudication.  It creates one immutable,
hash-bound work item for the next manifest role and waits for the governed
runner for that role to publish a terminal row/evidence.  Re-running the driver
is idempotent.  It never launches MT5 and never updates an existing verdict.

Runtime role mapping is resolved from the supplied gate manifest:

* v3: Q10 -> Q14 -> Q15 -> Q16
* v4: Q11 -> Q12 -> Q13 -> Q14

The DL-089 pattern gate is fail-closed on the fixture harness.  The historical
83b89730 row is the commissioning root; a later HARNESS_OK rerun of the same
harness identity may satisfy the prerequisite, while the failed root remains
preserved as evidence.  Every newly routed pattern row also carries the exact
154-candidate / 1,085-annual-cell / four-step anchored-WF declaration.  The
declaration revision participates in the pattern-row UUID so correcting an old
zero-search row creates an append-only successor rather than mutating history.
"""
from __future__ import annotations

import datetime as dt
import gzip
import hashlib
import json
import re
import sqlite3
import subprocess
import uuid
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from gate_manifest import GateManifest
    from phase_ids import ACTIVE_GATE_MANIFEST
    from throughput_telemetry import EXECUTION_VERDICT_EXCLUSION_SQL
except ModuleNotFoundError:
    from tools.strategy_farm.gate_manifest import GateManifest
    from tools.strategy_farm.phase_ids import ACTIVE_GATE_MANIFEST
    from tools.strategy_farm.throughput_telemetry import EXECUTION_VERDICT_EXCLUSION_SQL


SCHEMA = "qm.opt-fork-routing/v1"
PATTERN_DECLARATION_SCHEMA = "qm.dl089-pattern-candidate-declaration/v1"
PATTERN_DECLARATION_REVISION = "dl089-annual-wf-cells-v1"
PATTERN_INPUT_KEYS = (
    "opt_pp_buy1",
    "opt_pp_buy2",
    "opt_pp_buy3",
    "opt_pp_sell1",
    "opt_pp_sell2",
    "opt_pp_sell3",
)
HARNESS_ROOT_WORK_ITEM_ID = "83b89730-bb86-4c18-955a-efefe3039cc5"
HARNESS_EA_ID = "QM_PP_FIXTURE_HARNESS"
HARNESS_PHASE = "HARNESS_PP_FIXTURE"
HARNESS_GREEN_VERDICTS = frozenset({"HARNESS_OK", "PASS"})
PATTERN_SUCCESS_VERDICTS = frozenset(
    {"PASS", "PASS_SOFT", "KEEP_INCUMBENT", "OPT_ELIGIBLE", "NO_FILTER_CHANGE"}
)
PARAM_SUCCESS_VERDICTS = frozenset(
    {"PASS", "PASS_SOFT", "KEEP_INCUMBENT", "CHALLENGER_SPAWNED", "NO_PARAMETER_CHANGE"}
)
TERMINAL_REQUALIFICATION_VERDICTS = frozenset(
    {"PROMOTE_CHALLENGER", "CHALLENGER_PROMOTED", "KEEP_INCUMBENT", "ADMIT_BOTH"}
)
ROW_NAMESPACE = uuid.UUID("ee66f777-f906-4d5e-a302-a46e44af5b7a")
REPO_ROOT = Path(__file__).resolve().parents[2]


class OptimizationForkError(RuntimeError):
    """A fail-closed routing or binding error."""


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _materialized_text(binding: Mapping[str, Any]) -> str | None:
    """Read currently materialized bound text without restoring archived bytes."""

    inline = binding.get("text")
    if isinstance(inline, str):
        return inline
    path = Path(str(binding.get("path") or ""))
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8-sig", errors="replace")


def _setfile_values(text: str | None) -> dict[str, str]:
    values: dict[str, str] = {}
    if text is None:
        return values
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def _float_or_none(value: Any) -> float | None:
    try:
        return float(str(value))
    except (TypeError, ValueError):
        return None


def _pattern_measurement_readiness(
    parent_bindings: Mapping[str, Any],
) -> dict[str, Any]:
    """Report whether the bound EA can execute the declared DL-089 cells.

    The declaration is still emitted when this check fails.  That distinction
    prevents a missing `_opt` implementation from being converted into the old
    zero-search/no-change shortcut while leaving a machine-readable build
    blocker for the governed evaluator.
    """

    source_text = _materialized_text(parent_bindings["source"])
    setfile_text = _materialized_text(parent_bindings["setfile"])
    set_values = _setfile_values(setfile_text)
    missing_source_inputs = list(PATTERN_INPUT_KEYS) if source_text is None else [
        key
        for key in PATTERN_INPUT_KEYS
        if re.search(
            rf"(?im)^\s*input\b[^\r\n;]*\b{re.escape(key)}\b",
            source_text,
        )
        is None
    ]
    missing_setfile_inputs = [key for key in PATTERN_INPUT_KEYS if key not in set_values]
    permission_wired = bool(
        source_text
        and "QM_PatternPermission" in source_text
        and "QM_PatternPermissionEvaluate" in source_text
    )
    risk_fixed = _float_or_none(set_values.get("RISK_FIXED"))
    risk_percent = _float_or_none(set_values.get("RISK_PERCENT"))
    news_stale = _float_or_none(set_values.get("qm_news_stale_max_hours"))
    blockers: list[str] = []
    if source_text is None:
        blockers.append("BOUND_SOURCE_NOT_MATERIALIZED")
    if setfile_text is None:
        blockers.append("BOUND_SETFILE_NOT_MATERIALIZED")
    if missing_source_inputs:
        blockers.append("PATTERN_INPUTS_MISSING_FROM_SOURCE")
    if missing_setfile_inputs:
        blockers.append("PATTERN_INPUTS_MISSING_FROM_SETFILE")
    if not permission_wired:
        blockers.append("PATTERN_PERMISSION_NOT_WIRED")
    if risk_fixed is None or risk_fixed <= 0:
        blockers.append("RISK_FIXED_NOT_POSITIVE")
    if risk_percent is None or risk_percent != 0:
        blockers.append("RISK_PERCENT_NOT_ZERO")
    if news_stale is not None and news_stale > 336:
        blockers.append("NEWS_STALE_MAX_EXCEEDS_336")
    if setfile_text is not None and not (
        "; environment:" in setfile_text.lower()
        and "backtest" in setfile_text.lower()
    ):
        blockers.append("BACKTEST_ENVIRONMENT_NOT_DECLARED")
    return {
        "ready": not blockers,
        "status": "READY" if not blockers else "BLOCKED",
        "blocker_code": None if not blockers else "PATTERN_FILTER_INSTRUMENTATION_REQUIRED",
        "blockers": blockers,
        "missing_source_inputs": missing_source_inputs,
        "missing_setfile_inputs": missing_setfile_inputs,
        "pattern_permission_wired": permission_wired,
        "risk_contract": {
            "RISK_FIXED": risk_fixed,
            "RISK_PERCENT": risk_percent,
            "qm_news_stale_max_hours": news_stale,
            "required": "RISK_FIXED > 0; RISK_PERCENT = 0; qm_news_stale_max_hours <= 336",
        },
        "resolution_template": [
            "Build a governed _opt sibling with all six opt_pp_* inputs and symmetric permission vetoes.",
            "Compile and clear its build/Q02 prerequisites without changing this declaration.",
            "Materialize the declared annual matrix through opt_census.py; adjudicate only after all sealed WF cells are measured.",
        ],
    }


def _pattern_candidate_declaration(
    *,
    parent: sqlite3.Row,
    parent_bindings: Mapping[str, Any],
) -> dict[str, Any]:
    """Build the exact, pre-measurement DL-089 Q12 candidate declaration."""

    try:
        import opt_census as census
    except ModuleNotFoundError:
        from tools.strategy_farm import opt_census as census

    ea_id = str(parent["ea_id"])
    symbol = str(parent["symbol"])
    program_id = f"DL089_{ea_id}_{symbol.replace('.', '_')}_2019_2025"
    matrix_arms = census.arms(census.predicate_ids())
    candidates = [
        {
            "candidate_key": arm.key,
            "direction": arm.direction,
            "predicate_id": arm.predicate_id,
            "declared_parameter_count": 1,
            "annual_measurement_cell_count": len(census.YEARS),
            "frequency_metric": "entry_trading_days",
            "frequency_floor_per_scored_year": census.ACTIVITY_FLOOR,
            "frequency_floor_semantics": "FAIL_CLOSED_IF_ANY_SCORED_YEAR_BREAKS",
        }
        for arm in matrix_arms
        if arm.direction in {"BUY", "SELL"}
    ]
    annual_cells: list[dict[str, Any]] = []
    for year in census.YEARS:
        for arm in matrix_arms:
            cell_key = f"{program_id}:{year}:{arm.key}"
            annual_cells.append(
                {
                    "cell_key": cell_key,
                    "work_item_id": str(uuid.uuid5(census.CELL_NAMESPACE, cell_key)),
                    "year": year,
                    "from_date": f"{year}.01.01",
                    "to_date": f"{year}.12.31",
                    "arm": arm.key,
                    "direction": arm.direction,
                    "predicate_id": arm.predicate_id,
                }
            )
    wf_cells: list[dict[str, Any]] = []
    for window in census.WF_WINDOWS:
        cell_key = (
            f"{program_id}:wf{window['step']}:combo:{window['test_year']}"
        )
        wf_cells.append(
            {
                "cell_key": cell_key,
                "work_item_id": str(uuid.uuid5(census.CELL_NAMESPACE, cell_key)),
                "wf_step": window["step"],
                "select_years": list(window["select_years"]),
                "test_year": window["test_year"],
                "from_date": f"{window['test_year']}.01.01",
                "to_date": f"{window['test_year']}.12.31",
                "configuration": "DERIVED_BY_SEALED_SELECTION_AFTER_ANNUAL_MATRIX",
            }
        )
    if len(candidates) != census.DECLARED_TRIAL_COUNT:
        raise OptimizationForkError(
            f"DL-089 candidate declaration expected 154 candidates, found {len(candidates)}"
        )
    if len(annual_cells) != 1085 or len(wf_cells) != 4:
        raise OptimizationForkError(
            "DL-089 candidate declaration must contain 1085 annual cells and 4 WF cells"
        )
    selection_contract = census.sealed_header(param_grid=None)
    selection_contract.update(
        {
            "metric": "return_to_maxdd",
            "combination_semantics": "OR_BLACKLIST",
            "max_selected_buy": 3,
            "max_selected_sell": 3,
            "no_filter_control_required": True,
        }
    )
    declaration: dict[str, Any] = {
        "schema": PATTERN_DECLARATION_SCHEMA,
        "revision": PATTERN_DECLARATION_REVISION,
        "authority": "DL-089",
        "program_id": program_id,
        "ea_id": ea_id,
        "symbol": symbol,
        "declared_parameter_count": len(candidates),
        "declared_trial_count": census.DECLARED_TRIAL_COUNT,
        "candidate_count": len(candidates),
        "candidate_parameter_count_each": 1,
        "annual_measurement_repeats_per_candidate": len(census.YEARS),
        "annual_cell_count": len(annual_cells),
        "wf_cell_count": len(wf_cells),
        "q12_backtest_budget": len(annual_cells) + len(wf_cells),
        "full_pattern_chain_backtest_budget_before_numeric": len(annual_cells)
        + len(wf_cells)
        + 2,
        "scheduling_contract": {
            "pair_mode": "SERIAL",
            "priority_window_cap": 8,
            "measurement_pool": census.PHASE,
            "q02_metrics_excluded": True,
        },
        "selection_contract": selection_contract,
        "candidates": candidates,
        "annual_cells": annual_cells,
        "wf_cells": wf_cells,
        "measurement_readiness": _pattern_measurement_readiness(parent_bindings),
        "measured_candidate_adjudicated": False,
    }
    declaration["candidate_manifest_sha256"] = hashlib.sha256(
        _canonical_bytes(candidates)
    ).hexdigest()
    declaration["annual_cells_sha256"] = hashlib.sha256(
        _canonical_bytes(annual_cells)
    ).hexdigest()
    declaration["wf_cells_sha256"] = hashlib.sha256(
        _canonical_bytes(wf_cells)
    ).hexdigest()
    declaration["declaration_sha256"] = hashlib.sha256(
        _canonical_bytes(declaration)
    ).hexdigest()
    return declaration


def _archive_binding(
    path: Path,
    *,
    label: str,
    expected_sha256: str,
    expected_size: int | None,
) -> dict[str, Any] | None:
    """Resolve exact historical bytes without restoring or weakening a bind."""
    gzip_path = Path(str(path) + ".gz")
    if gzip_path.is_file():
        digest = hashlib.sha256()
        content_size = 0
        try:
            with gzip.open(gzip_path, "rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
                    content_size += len(chunk)
        except OSError as exc:
            raise OptimizationForkError(f"{label} gzip archive invalid: {gzip_path}") from exc
        if digest.hexdigest() == expected_sha256 and (
            expected_size is None or content_size == expected_size
        ):
            return {
                "path": str(path),
                "sha256": expected_sha256,
                "size_bytes": content_size,
                "archive_type": "gzip_sibling",
                "archive_path": str(gzip_path.resolve()),
                "archive_sha256": _sha256(gzip_path),
                "archive_size_bytes": gzip_path.stat().st_size,
            }
    try:
        relative = path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError:
        return None
    try:
        commits = subprocess.check_output(
            ["git", "-C", str(REPO_ROOT), "log", "--all", "--format=%H", "--", relative],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=30,
        ).split()
    except (OSError, subprocess.SubprocessError):
        return None
    for commit in commits:
        try:
            raw = subprocess.check_output(
                ["git", "-C", str(REPO_ROOT), "show", f"{commit}:{relative}"],
                stderr=subprocess.DEVNULL,
                timeout=30,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        lf = raw.replace(b"\r\n", b"\n")
        for variant, content in (
            ("git_blob", raw),
            ("lf_checkout", lf),
            ("crlf_checkout", lf.replace(b"\n", b"\r\n")),
        ):
            if hashlib.sha256(content).hexdigest() != expected_sha256 or (
                expected_size is not None and len(content) != expected_size
            ):
                continue
            try:
                blob = subprocess.check_output(
                    ["git", "-C", str(REPO_ROOT), "rev-parse", f"{commit}:{relative}"],
                    text=True,
                    stderr=subprocess.DEVNULL,
                    timeout=30,
                ).strip()
            except (OSError, subprocess.SubprocessError):
                blob = None
            return {
                "path": str(path),
                "sha256": expected_sha256,
                "size_bytes": len(content),
                "archive_type": "git_history",
                "archive_commit": commit,
                "archive_blob": blob,
                "archive_path": relative,
                "archive_bytes_variant": variant,
            }
    return None


def _binding(
    path_value: Any,
    label: str,
    *,
    expected_sha256: str | None = None,
    expected_size: int | None = None,
) -> dict[str, Any]:
    path = Path(str(path_value or "")).resolve()
    if path.is_file():
        observed = {
            "path": str(path),
            "sha256": _sha256(path),
            "size_bytes": path.stat().st_size,
        }
        if not expected_sha256 or (
            observed["sha256"] == expected_sha256
            and (expected_size is None or observed["size_bytes"] == expected_size)
        ):
            return observed
        current_detail = (
            f"current_sha256={observed['sha256']},current_size={observed['size_bytes']}"
        )
    else:
        current_detail = "current_path_missing"
    if expected_sha256:
        archived = _archive_binding(
            path,
            label=label,
            expected_sha256=expected_sha256,
            expected_size=expected_size,
        )
        if archived is not None:
            return archived
    if not path.is_file():
        raise OptimizationForkError(f"{label} missing: {path}")
    raise OptimizationForkError(
        f"{label} binding drift: expected_sha256={expected_sha256},"
        f"expected_size={expected_size},{current_detail}"
    )


def _contract_version(manifest: GateManifest) -> str:
    match = re.search(r"/v(\d+)$", manifest.schema_version)
    if not match:
        raise OptimizationForkError(
            f"unsupported gate manifest schema version: {manifest.schema_version}"
        )
    return f"v{match.group(1)}"


def _decode_payload(row: sqlite3.Row | Mapping[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(str(row["payload_json"] or "{}"))
    except (json.JSONDecodeError, TypeError) as exc:
        raise OptimizationForkError(f"work item {row['id']} has invalid payload JSON") from exc
    return value if isinstance(value, dict) else {}


def _artifact_bindings(row: sqlite3.Row | Mapping[str, Any]) -> dict[str, Any]:
    """Bind the row evidence plus current source/binary/setfile bytes."""

    evidence = _binding(row["evidence_path"], "parent evidence")
    payload = _decode_payload(row)
    prior_bindings = payload.get("parent_bindings")
    prior_bindings = prior_bindings if isinstance(prior_bindings, Mapping) else {}

    def _expected_size(label: str) -> int | None:
        binding = prior_bindings.get(label)
        if not isinstance(binding, Mapping) or binding.get("size_bytes") is None:
            return None
        return int(binding["size_bytes"])

    setfile = _binding(
        row["setfile_path"],
        "parent setfile",
        expected_sha256=str(payload.get("expected_setfile_sha256") or "").lower() or None,
        expected_size=_expected_size("setfile"),
    )
    set_path = Path(setfile["path"])
    ea_dir = set_path.parent.parent
    ea_dir_name = str(payload.get("ea_dir_name") or ea_dir.name).strip()
    ex5_path = Path(str(payload.get("expected_ex5_path") or ea_dir / f"{ea_dir_name}.ex5"))
    mq5_path = Path(str(payload.get("expected_mq5_path") or ea_dir / f"{ea_dir_name}.mq5"))
    binary = _binding(
        ex5_path,
        "parent binary",
        expected_sha256=str(payload.get("expected_ex5_sha256") or "").lower() or None,
        expected_size=_expected_size("binary"),
    )
    source = _binding(
        mq5_path,
        "parent source",
        expected_sha256=str(payload.get("expected_mq5_sha256") or "").lower() or None,
        expected_size=_expected_size("source"),
    )
    for key, observed in (
        ("expected_ex5_sha256", binary["sha256"]),
        ("expected_mq5_sha256", source["sha256"]),
        ("expected_setfile_sha256", setfile["sha256"]),
    ):
        expected = str(payload.get(key) or "").strip().lower()
        if expected and expected != observed:
            raise OptimizationForkError(
                f"parent {key} mismatch for {row['id']}: expected {expected}, observed {observed}"
            )
    return {"evidence": evidence, "binary": binary, "source": source, "setfile": setfile}


def _revalidate_parent_bindings(raw: Any) -> dict[str, Any]:
    """Revalidate an immutable predecessor's exact recorded artifact bindings."""

    if not isinstance(raw, Mapping):
        raise OptimizationForkError("legacy Q12 parent_bindings missing")
    verified: dict[str, Any] = {}
    for label in ("evidence", "binary", "source", "setfile"):
        binding = raw.get(label)
        if not isinstance(binding, Mapping):
            raise OptimizationForkError(f"legacy Q12 parent {label} binding missing")
        expected_hash = str(binding.get("sha256") or "").strip().lower()
        try:
            expected_size = int(binding.get("size_bytes"))
        except (TypeError, ValueError) as exc:
            raise OptimizationForkError(
                f"legacy Q12 parent {label} size binding invalid"
            ) from exc
        if len(expected_hash) != 64:
            raise OptimizationForkError(
                f"legacy Q12 parent {label} sha256 binding invalid"
            )
        verified[label] = _binding(
            binding.get("path"),
            f"legacy Q12 parent {label}",
            expected_sha256=expected_hash,
            expected_size=expected_size,
        )
    return verified


def _harness_state(conn: sqlite3.Connection) -> dict[str, Any]:
    root = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (HARNESS_ROOT_WORK_ITEM_ID,)
    ).fetchone()
    green = conn.execute(
        """
        SELECT * FROM work_items
        WHERE ea_id=? AND phase=? AND lower(status)='done'
          AND upper(coalesce(verdict,'')) IN ('HARNESS_OK','PASS')
        ORDER BY updated_at DESC,created_at DESC,id DESC LIMIT 1
        """,
        (HARNESS_EA_ID, HARNESS_PHASE),
    ).fetchone()
    state: dict[str, Any] = {
        "root_work_item_id": HARNESS_ROOT_WORK_ITEM_ID,
        "root_present": root is not None,
        "root_status": None if root is None else root["status"],
        "root_verdict": None if root is None else root["verdict"],
        "green": green is not None,
        "selected_work_item_id": None if green is None else green["id"],
        "machine_reason": "FIXTURE_HARNESS_GREEN" if green is not None else (
            "FIXTURE_HARNESS_ROOT_MISSING" if root is None else "FIXTURE_HARNESS_NOT_GREEN"
        ),
    }
    if green is not None:
        state["evidence"] = _binding(green["evidence_path"], "fixture harness evidence")
        state["selected_status"] = green["status"]
        state["selected_verdict"] = green["verdict"]
    return state


def _row_id(
    *,
    manifest: GateManifest,
    role: str,
    parent_id: str,
    prerequisite_id: str,
    routing_revision: str | None = None,
) -> str:
    seed = f"{SCHEMA}:{manifest.sha256}:{role}:{parent_id}:{prerequisite_id}"
    if routing_revision:
        seed = f"{seed}:{routing_revision}"
    return str(uuid.uuid5(ROW_NAMESPACE, seed))


def _target_set(target_pairs: Iterable[tuple[str, str]] | None) -> set[tuple[str, str]] | None:
    if target_pairs is None:
        return None
    return {(str(ea).strip().upper(), str(symbol).strip().upper()) for ea, symbol in target_pairs}


def _latest_incumbents(
    conn: sqlite3.Connection,
    *,
    manifest: GateManifest,
    target_pairs: Iterable[tuple[str, str]] | None,
) -> list[sqlite3.Row]:
    phase = manifest.gate_for_role("INCUMBENT")
    targets = _target_set(target_pairs)
    rows = conn.execute(
        """
        SELECT * FROM work_items
        WHERE upper(phase)=? AND lower(status)='done' AND upper(coalesce(verdict,''))='PASS'
        ORDER BY updated_at DESC,created_at DESC,id DESC
        """,
        (phase,),
    ).fetchall()
    latest: dict[tuple[str, str], sqlite3.Row] = {}
    for row in rows:
        key = (str(row["ea_id"]).upper(), str(row["symbol"]).upper())
        if targets is not None and key not in targets:
            continue
        latest.setdefault(key, row)
    return list(latest.values())


def _managed_terminal_rows(
    conn: sqlite3.Connection, *, phase: str, manifest: GateManifest
) -> list[sqlite3.Row]:
    rows = conn.execute(
        """
        SELECT * FROM work_items
        WHERE upper(phase)=? AND lower(status) IN ('done','failed')
          AND json_valid(payload_json)=1
          AND json_extract(payload_json,'$.schema')=?
          AND json_extract(payload_json,'$.gate_manifest_sha256')=?
        ORDER BY updated_at,created_at,id
        """,
        (phase, SCHEMA, manifest.sha256),
    ).fetchall()
    return list(rows)


def _legacy_zero_search_pattern_parents(
    conn: sqlite3.Connection,
    *,
    phase: str,
    manifest: GateManifest,
    target_pairs: Iterable[tuple[str, str]] | None,
) -> list[tuple[sqlite3.Row, sqlite3.Row]]:
    """Return old no-search Q12 rows and their bound incumbent parents.

    Gate-manifest v4 activation left three append-only Q12 receipts whose
    parent storage phase is Q10 even though the active incumbent role now maps
    to Q11.  They cannot be rediscovered by ``_latest_incumbents``.  Reissuing
    from their authenticated parent preserves the original evidence binding
    while the declaration revision gives the corrected Q12 row a new UUID.
    """

    targets = _target_set(target_pairs)
    rows = conn.execute(
        """
        SELECT * FROM work_items
        WHERE upper(phase)=? AND lower(status)='done'
          AND upper(coalesce(verdict,''))='NO_FILTER_CHANGE'
          AND json_valid(payload_json)=1
          AND json_extract(payload_json,'$.schema')=?
          AND json_extract(payload_json,'$.gate_manifest_sha256')=?
        ORDER BY updated_at,created_at,id
        """,
        (phase, SCHEMA, manifest.sha256),
    ).fetchall()
    result: list[tuple[sqlite3.Row, sqlite3.Row]] = []
    for legacy in rows:
        key = (str(legacy["ea_id"]).upper(), str(legacy["symbol"]).upper())
        if targets is not None and key not in targets:
            continue
        payload = _decode_payload(legacy)
        if payload.get("pattern_filter_sweep") not in (None, {}, []):
            continue
        parent_id = str(payload.get("parent_work_item_id") or "")
        parent = conn.execute("SELECT * FROM work_items WHERE id=?", (parent_id,)).fetchone()
        if parent is None:
            continue
        result.append((legacy, parent))
    return result


def _stage_payload(
    *,
    manifest: GateManifest,
    role: str,
    phase: str,
    parent: sqlite3.Row,
    parent_bindings: Mapping[str, Any],
    harness: Mapping[str, Any],
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "schema": SCHEMA,
        "role": role,
        "phase": phase,
        "gate_contract_version": _contract_version(manifest),
        "gate_manifest_sha256": manifest.sha256,
        "parent_work_item_id": str(parent["id"]),
        "parent_phase": str(parent["phase"]),
        "parent_verdict": str(parent["verdict"]),
        "parent_bindings": dict(parent_bindings),
        "expected_ex5_sha256": parent_bindings["binary"]["sha256"],
        "expected_mq5_sha256": parent_bindings["source"]["sha256"],
        "expected_setfile_sha256": parent_bindings["setfile"]["sha256"],
        "expected_symbol": str(parent["symbol"]),
        "dl089_contract": {
            "decision": "decisions/DL-089_pattern_filter_wf_census_v3.md",
            "plan": "docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md",
            "zero_pattern_filter_valid": True,
            "frequency_check": "DL-089_ACTIVITY_FLOOR_FAIL_CLOSED",
        },
        "numeric_parameter_sweep": {
            "mode": "NO_NEW_PARAMETER_SWEEP",
            "declared_parameter_count": 0,
            "declared_trial_count_increment": 0,
            "no_parameter_change_valid": True,
        },
        "execution_lane": "GOVERNED_ANALYTIC_DISPATCH",
        "activation_state": "READY",
        "machine_reason": "PREREQUISITES_GREEN",
    }
    if role == "PATTERN":
        payload["fixture_harness"] = dict(harness)
        payload["routing_revision"] = PATTERN_DECLARATION_REVISION
        payload["dl089_contract"]["declared_pattern_search_required"] = True
        payload["pattern_filter_sweep"] = _pattern_candidate_declaration(
            parent=parent,
            parent_bindings=parent_bindings,
        )
        if not harness["green"]:
            payload["activation_state"] = "FAIL_CLOSED"
            payload["machine_reason"] = harness["machine_reason"]
    return payload


def _append_stage(
    conn: sqlite3.Connection,
    *,
    manifest: GateManifest,
    role: str,
    phase: str,
    parent: sqlite3.Row,
    harness: Mapping[str, Any],
    apply: bool,
    parent_bindings_override: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    try:
        bindings = (
            _revalidate_parent_bindings(parent_bindings_override)
            if parent_bindings_override is not None
            else _artifact_bindings(parent)
        )
    except OptimizationForkError as exc:
        return {
            "created": False,
            "role": role,
            "phase": phase,
            "parent_work_item_id": str(parent["id"]),
            "ea_id": str(parent["ea_id"]),
            "symbol": str(parent["symbol"]),
            "machine_reason": f"PARENT_BINDING_INVALID:{exc}",
        }
    prerequisite_id = (
        str(harness.get("selected_work_item_id") or harness["machine_reason"])
        if role == "PATTERN"
        else str(parent["id"])
    )
    work_item_id = _row_id(
        manifest=manifest,
        role=role,
        parent_id=str(parent["id"]),
        prerequisite_id=prerequisite_id,
        routing_revision=(PATTERN_DECLARATION_REVISION if role == "PATTERN" else None),
    )
    payload = _stage_payload(
        manifest=manifest, role=role, phase=phase, parent=parent,
        parent_bindings=bindings, harness=harness,
    )
    payload["routing_identity_sha256"] = hashlib.sha256(_canonical_bytes(payload)).hexdigest()
    terminal_fail = role == "PATTERN" and not bool(harness["green"])
    status = "failed" if terminal_fail else "pending"
    verdict = "INFRA_FAIL" if terminal_fail else None
    existing = conn.execute("SELECT * FROM work_items WHERE id=?", (work_item_id,)).fetchone()
    if existing is not None:
        if (
            str(existing["payload_json"]) != json.dumps(payload, sort_keys=True)
            or str(existing["phase"]).upper() != phase
        ):
            raise OptimizationForkError(
                f"deterministic optimization work-item collision: {work_item_id}"
            )
        return {
            "created": False, "idempotent": True, "work_item_id": work_item_id,
            "role": role, "phase": phase, "ea_id": parent["ea_id"],
            "symbol": parent["symbol"], "status": existing["status"],
            "verdict": existing["verdict"],
            "machine_reason": payload["machine_reason"],
        }
    result = {
        "created": bool(apply), "idempotent": False, "work_item_id": work_item_id,
        "role": role, "phase": phase, "ea_id": parent["ea_id"],
        "symbol": parent["symbol"], "status": status, "verdict": verdict,
        "machine_reason": payload["machine_reason"],
    }
    if not apply:
        result["would_create"] = True
        return result
    now = _utc_now()
    conn.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
            parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
            gate_contract_version
        ) VALUES(?,?,?,?,?,?,?,?,0,NULL,NULL,NULL,?,?,?,?)
        """,
        (
            work_item_id, "analytic", phase, parent["ea_id"], parent["symbol"],
            parent["setfile_path"], status, verdict, json.dumps(payload, sort_keys=True),
            now, now, _contract_version(manifest),
        ),
    )
    return result


def advance_optimization_fork(
    conn: sqlite3.Connection,
    *,
    manifest: GateManifest = ACTIVE_GATE_MANIFEST,
    target_pairs: Iterable[tuple[str, str]] | None = None,
    apply: bool = False,
) -> dict[str, Any]:
    """Plan or append every currently licensed optimization-fork successor."""

    conn.row_factory = sqlite3.Row
    pattern_phase = manifest.gate_for_role("PATTERN")
    param_phase = manifest.gate_for_role("PARAM_OPT")
    head_phase = manifest.gate_for_role("HEAD_TO_HEAD")
    harness = _harness_state(conn)
    actions: list[dict[str, Any]] = []

    if apply:
        conn.execute("BEGIN IMMEDIATE")
    try:
        routed_pattern_parent_ids: set[str] = set()
        for parent in _latest_incumbents(conn, manifest=manifest, target_pairs=target_pairs):
            actions.append(_append_stage(
                conn, manifest=manifest, role="PATTERN", phase=pattern_phase,
                parent=parent, harness=harness, apply=apply,
            ))
            routed_pattern_parent_ids.add(str(parent["id"]))

        for legacy, parent in _legacy_zero_search_pattern_parents(
            conn,
            phase=pattern_phase,
            manifest=manifest,
            target_pairs=target_pairs,
        ):
            if str(parent["id"]) in routed_pattern_parent_ids:
                continue
            action = _append_stage(
                conn,
                manifest=manifest,
                role="PATTERN",
                phase=pattern_phase,
                parent=parent,
                harness=harness,
                apply=apply,
                parent_bindings_override=_decode_payload(legacy).get("parent_bindings"),
            )
            action["append_only_correction_of_work_item_id"] = str(legacy["id"])
            actions.append(action)
            routed_pattern_parent_ids.add(str(parent["id"]))

        targets = _target_set(target_pairs)
        for parent in _managed_terminal_rows(conn, phase=pattern_phase, manifest=manifest):
            key = (str(parent["ea_id"]).upper(), str(parent["symbol"]).upper())
            if targets is not None and key not in targets:
                continue
            if str(parent["verdict"] or "").upper() not in PATTERN_SUCCESS_VERDICTS:
                continue
            actions.append(_append_stage(
                conn, manifest=manifest, role="PARAM_OPT", phase=param_phase,
                parent=parent, harness=harness, apply=apply,
            ))

        for parent in _managed_terminal_rows(conn, phase=param_phase, manifest=manifest):
            key = (str(parent["ea_id"]).upper(), str(parent["symbol"]).upper())
            if targets is not None and key not in targets:
                continue
            if str(parent["verdict"] or "").upper() not in PARAM_SUCCESS_VERDICTS:
                continue
            actions.append(_append_stage(
                conn, manifest=manifest, role="HEAD_TO_HEAD", phase=head_phase,
                parent=parent, harness=harness, apply=apply,
            ))
        if apply:
            conn.commit()
    except Exception:
        if apply:
            conn.rollback()
        raise
    return {
        "schema": SCHEMA,
        "dry_run": not apply,
        "applied": apply,
        "gate_contract_version": _contract_version(manifest),
        "gate_manifest_sha256": manifest.sha256,
        "phases": {
            "incumbent": manifest.gate_for_role("INCUMBENT"),
            "pattern": pattern_phase,
            "param_opt": param_phase,
            "head_to_head": head_phase,
        },
        "fixture_harness": harness,
        "actions": actions,
        "created_work_item_ids": [row["work_item_id"] for row in actions if row.get("created")],
    }


def service_metrics(
    conn: sqlite3.Connection,
    *,
    manifests: Iterable[GateManifest],
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Return 24h completed rates and lifetime terminal requalification count."""

    observed = now or dt.datetime.now(dt.timezone.utc)
    cutoff = (observed - dt.timedelta(days=1)).isoformat()
    per_gate: dict[str, int] = {}
    terminal_clauses: list[tuple[str, str]] = []
    for manifest in manifests:
        version = _contract_version(manifest)
        for role in ("PATTERN", "PARAM_OPT", "HEAD_TO_HEAD"):
            phase = manifest.gate_for_role(role)
            key = f"{version}:{phase}:{role}"
            accepted_versions = (version, "legacy") if version == "v3" else (version,)
            version_placeholders = ",".join("?" for _ in accepted_versions)
            per_gate[key] = int(conn.execute(
                f"""
                SELECT count(*) FROM work_items
                WHERE upper(phase)=? AND lower(status) IN ('done','failed')
                  AND coalesce(gate_contract_version,?) IN ({version_placeholders})
                  AND updated_at>=?
                  AND {EXECUTION_VERDICT_EXCLUSION_SQL}
                """,
                (
                    phase, "legacy" if version == "v3" else version,
                    *accepted_versions, cutoff,
                ),
            ).fetchone()[0])
        terminal_clauses.append((manifest.terminal_requalification_gate, version))
    terminal_ids: set[str] = set()
    for phase, version in terminal_clauses:
        accepted_versions = (version, "legacy") if version == "v3" else (version,)
        version_placeholders = ",".join("?" for _ in accepted_versions)
        rows = conn.execute(
            f"""
            SELECT id FROM work_items
            WHERE upper(phase)=? AND lower(status)='done'
              AND upper(coalesce(verdict,'')) IN (?,?,?,?)
              AND coalesce(gate_contract_version,?) IN ({version_placeholders})
            """,
            (
                phase, *sorted(TERMINAL_REQUALIFICATION_VERDICTS),
                "legacy" if version == "v3" else version, *accepted_versions,
            ),
        ).fetchall()
        terminal_ids.update(str(row[0]) for row in rows)
    return {
        "window_hours": 24,
        "completed_per_day_by_gate": per_gate,
        "terminal_requalification_verdicts_count": len(terminal_ids),
    }
