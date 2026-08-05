"""Fail-closed OWNER Q09_NEWS admission contract for FTMO composition.

This module is deliberately additive to the DXZ qualification chain.  It reads
the immutable Q09_NEWS sidecar tables and authenticates the aggregate artifact;
it never mutates the farm database or changes a Q-pipeline verdict.

An ``(EA, symbol)`` is FTMO-admissible only when its latest completed Q09_NEWS
row is ``CONFIG_LOCKED`` and either:

* the locked 7x1 matrix directly targets FTMO, or
* a complete 7x4 matrix contains a viable FTMO configuration for the locked
  temporal recommendation.

The returned deployment inputs intentionally force FTMO compliance while
preserving Q09's ``chosen_temporal`` recommendation.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Any, Mapping

try:
    from .. import q09_news_contract as q09_contract
except ImportError:  # pragma: no cover - direct script/import execution
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import q09_news_contract as q09_contract  # type: ignore


ADMITTED_REASON = "FTMO_Q09_ADMITTED"
EVIDENCE_MISSING = "FTMO_Q09_EVIDENCE_MISSING"
NOT_CONFIG_LOCKED = "FTMO_Q09_NOT_CONFIG_LOCKED"
EVIDENCE_PATH_MISMATCH = "FTMO_Q09_EVIDENCE_PATH_MISMATCH"
EVIDENCE_UNAUTHENTICATED = "FTMO_Q09_EVIDENCE_UNAUTHENTICATED"
ADJUDICATION_MISMATCH = "FTMO_Q09_ADJUDICATION_MISMATCH"
SCOPE_NOT_FTMO = "FTMO_Q09_SCOPE_NOT_FTMO"
FTMO_CELLS_INCOMPLETE = "FTMO_Q09_FTMO_CELLS_INCOMPLETE"
FTMO_CONFIG_NOT_VIABLE = "FTMO_Q09_FTMO_CONFIG_NOT_VIABLE"

FTMO_COMPLIANCE_MODE_ID = 2


def _normalize_ea(value: Any) -> str:
    token = str(value or "").strip().upper().removeprefix("QM5_")
    try:
        return f"QM5_{int(token)}"
    except (TypeError, ValueError) as exc:
        raise ValueError(f"invalid EA id: {value!r}") from exc


def _base_result(ea_id: Any, symbol: Any, reason_code: str) -> dict[str, Any]:
    return {
        "admitted": False,
        "reason_code": reason_code,
        "ea_id": _normalize_ea(ea_id),
        "symbol": str(symbol or "").strip().upper(),
        "q09_news_work_item_id": None,
        "matrix_scope": None,
        "source_target_compliance": None,
        "chosen_temporal": None,
        "deployment_compliance": None,
        "aggregate_path": None,
        "aggregate_sha256": None,
        "details": [],
    }


def _tables_present(conn: sqlite3.Connection, names: set[str]) -> bool:
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN (%s)"
        % ",".join("?" for _ in names),
        tuple(sorted(names)),
    ).fetchall()
    return {str(row[0]) for row in rows} == names


def _cell_relation(conn: sqlite3.Connection) -> str:
    occurrence_view = conn.execute(
        """
        SELECT 1 FROM sqlite_master
        WHERE type='view' AND name='q09_news_cells_by_work_item'
        """
    ).fetchone()
    return "q09_news_cells_by_work_item" if occurrence_view else "q09_news_cells"


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _authenticated_adjudication(row: sqlite3.Row) -> tuple[Mapping[str, Any] | None, str | None]:
    aggregate_path = Path(str(row["aggregate_path"] or ""))
    evidence_path = Path(str(row["work_item_evidence_path"] or ""))
    try:
        if not aggregate_path.is_file() or not evidence_path.is_file():
            return None, EVIDENCE_UNAUTHENTICATED
        if aggregate_path.resolve() != evidence_path.resolve():
            return None, EVIDENCE_PATH_MISMATCH
        expected_sha = str(row["aggregate_sha256"] or "").strip().lower()
        if _sha256_file(aggregate_path) != expected_sha:
            return None, EVIDENCE_UNAUTHENTICATED
        document = json.loads(aggregate_path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None, EVIDENCE_UNAUTHENTICATED
    if not isinstance(document, Mapping):
        return None, EVIDENCE_UNAUTHENTICATED
    embedded = document.get("adjudication_sha256")
    unsigned = dict(document)
    unsigned.pop("adjudication_sha256", None)
    actual = hashlib.sha256(q09_contract.canonical_json_bytes(unsigned)).hexdigest()
    if embedded != actual:
        return None, EVIDENCE_UNAUTHENTICATED
    chosen = document.get("chosen_config")
    if not isinstance(chosen, Mapping):
        return None, ADJUDICATION_MISMATCH
    expected = {
        "work_item_id": row["work_item_id"],
        "verdict": row["test_verdict"],
        "target_compliance": row["target_compliance"],
        "matrix_scope": row["matrix_scope"],
    }
    observed = {key: document.get(key) for key in expected}
    if observed != expected:
        return None, ADJUDICATION_MISMATCH
    if (
        chosen.get("temporal_mode") != row["chosen_temporal"]
        or chosen.get("compliance_mode") != row["chosen_compliance"]
    ):
        return None, ADJUDICATION_MISMATCH
    return document, None


def _selection_viability(raw_rows: list[sqlite3.Row], chosen_temporal: str) -> list[str]:
    reasons: list[str] = []
    if len(raw_rows) != len(q09_contract.SEEDS):
        reasons.append("five_authenticated_ftmo_seeds_required")
    observed_seeds = {int(row["seed"]) for row in raw_rows}
    if observed_seeds != set(q09_contract.SEEDS):
        reasons.append("canonical_ftmo_seed_set_mismatch")
    for row in raw_rows:
        seed = int(row["seed"])
        try:
            metrics = json.loads(str(row["selection_metrics_json"]))
            trades = int(metrics["trades"])
            profit_factor = float(metrics["profit_factor"])
            drawdown_pct = float(metrics["drawdown_pct"])
        except (TypeError, ValueError, KeyError, json.JSONDecodeError):
            reasons.append(f"seed_{seed}_selection_metrics_invalid")
            continue
        if trades < 20:
            reasons.append(f"seed_{seed}_selection_trades_below_20")
        if profit_factor <= 1.0:
            reasons.append(f"seed_{seed}_selection_pf_not_above_1")
        if drawdown_pct > 25.0:
            reasons.append(f"seed_{seed}_selection_dd_above_25pct")
        if int(row["q07_seed_stability_pass"]) != 1:
            reasons.append(f"seed_{seed}_q07_stability_failed")
        if chosen_temporal == "CLOSE_ALL_PRE" and not row["flat_at_event_receipt_sha256"]:
            reasons.append(f"seed_{seed}_flat_at_event_receipt_missing")
    return list(dict.fromkeys(reasons))


def evaluate_ftmo_q09_admission(
    conn: sqlite3.Connection,
    ea_id: Any,
    symbol: Any,
) -> dict[str, Any]:
    """Return an explicit, JSON-serializable FTMO admission decision."""

    result = _base_result(ea_id, symbol, EVIDENCE_MISSING)
    required_tables = {"work_items", "q09_news_tests", "q09_news_cells"}
    try:
        if not _tables_present(conn, required_tables):
            return result
        row = conn.execute(
            """
            SELECT
                w.id AS work_item_id,
                w.verdict AS work_item_verdict,
                w.evidence_path AS work_item_evidence_path,
                w.updated_at AS work_item_updated_at,
                t.verdict AS test_verdict,
                t.target_compliance,
                t.matrix_scope,
                t.chosen_temporal,
                t.chosen_compliance,
                t.aggregate_path,
                t.aggregate_sha256
            FROM work_items w
            LEFT JOIN q09_news_tests t ON t.work_item_id=w.id
            WHERE w.ea_id=? AND upper(w.symbol)=? AND w.phase='Q09_NEWS'
              AND w.status='done'
            ORDER BY w.updated_at DESC, w.created_at DESC, w.id DESC
            LIMIT 1
            """,
            (result["ea_id"], result["symbol"]),
        ).fetchone()
    except sqlite3.DatabaseError as exc:
        result["details"] = [f"database_error:{type(exc).__name__}"]
        return result
    if row is None or row["test_verdict"] is None:
        return result

    cell_relation = _cell_relation(conn)

    result.update(
        {
            "q09_news_work_item_id": row["work_item_id"],
            "matrix_scope": row["matrix_scope"],
            "source_target_compliance": row["target_compliance"],
            "chosen_temporal": row["chosen_temporal"],
            "aggregate_path": row["aggregate_path"],
            "aggregate_sha256": row["aggregate_sha256"],
        }
    )
    if row["work_item_verdict"] != "CONFIG_LOCKED" or row["test_verdict"] != "CONFIG_LOCKED":
        result["reason_code"] = NOT_CONFIG_LOCKED
        return result
    chosen_temporal = str(row["chosen_temporal"] or "")
    if chosen_temporal not in q09_contract.TEMPORAL_MODE_IDS:
        result["reason_code"] = ADJUDICATION_MISMATCH
        return result
    document, error = _authenticated_adjudication(row)
    if error:
        result["reason_code"] = error
        return result
    assert document is not None

    scope = str(row["matrix_scope"] or "")
    target = str(row["target_compliance"] or "")
    if scope == "7x1_target_compliance":
        if target != "FTMO" or row["chosen_compliance"] != "FTMO":
            result["reason_code"] = SCOPE_NOT_FTMO
            return result
    elif scope == "7x4":
        try:
            coverage = conn.execute(
                f"""
                SELECT temporal_mode,seed FROM {cell_relation}
                WHERE q09_news_work_item_id=? AND arm='POLICY_ON'
                  AND compliance_mode='FTMO'
                """,
                (row["work_item_id"],),
            ).fetchall()
        except sqlite3.DatabaseError:
            result["reason_code"] = FTMO_CELLS_INCOMPLETE
            return result
        expected_coverage = {
            (temporal, seed)
            for temporal in q09_contract.TEMPORAL_MODES
            for seed in q09_contract.SEEDS
        }
        if {(str(cell[0]), int(cell[1])) for cell in coverage} != expected_coverage:
            result["reason_code"] = FTMO_CELLS_INCOMPLETE
            return result
    else:
        result["reason_code"] = SCOPE_NOT_FTMO
        return result

    try:
        chosen_cells = conn.execute(
            f"""
            SELECT seed,selection_metrics_json,q07_seed_stability_pass,
                   flat_at_event_receipt_sha256
            FROM {cell_relation}
            WHERE q09_news_work_item_id=? AND arm='POLICY_ON'
              AND compliance_mode='FTMO' AND temporal_mode=?
            ORDER BY seed
            """,
            (row["work_item_id"], chosen_temporal),
        ).fetchall()
    except sqlite3.DatabaseError:
        result["reason_code"] = FTMO_CELLS_INCOMPLETE
        return result
    viability_reasons = _selection_viability(list(chosen_cells), chosen_temporal)
    if viability_reasons:
        result["reason_code"] = FTMO_CONFIG_NOT_VIABLE
        result["details"] = viability_reasons
        return result

    result.update(
        {
            "admitted": True,
            "reason_code": ADMITTED_REASON,
            "deployment_compliance": "FTMO",
            "chosen_temporal_id": q09_contract.TEMPORAL_MODE_IDS[chosen_temporal],
            "deployment_compliance_id": FTMO_COMPLIANCE_MODE_ID,
        }
    )
    return result


def admission_from_inventory(
    inventory: Mapping[str, Any], ea_id: Any, symbol: Any
) -> dict[str, Any]:
    """Resolve one admission decision from a frozen qualification inventory."""

    normalized_ea = _normalize_ea(ea_id)
    normalized_symbol = str(symbol or "").strip().upper()
    for row in inventory.get("candidates") or []:
        if not isinstance(row, Mapping):
            continue
        try:
            row_ea = _normalize_ea(row.get("ea_id"))
        except ValueError:
            continue
        if row_ea == normalized_ea and str(row.get("symbol") or "").strip().upper() == normalized_symbol:
            admission = row.get("ftmo_q09_admission")
            if isinstance(admission, Mapping):
                return dict(admission)
            break
    return _base_result(normalized_ea, normalized_symbol, EVIDENCE_MISSING)


def deployment_news_inputs(admission: Mapping[str, Any]) -> dict[str, str]:
    """Translate an admitted Q09 decision into the two EA set-file inputs."""

    if admission.get("admitted") is not True or admission.get("reason_code") != ADMITTED_REASON:
        raise ValueError(str(admission.get("reason_code") or EVIDENCE_MISSING))
    temporal = str(admission.get("chosen_temporal") or "")
    if temporal not in q09_contract.TEMPORAL_MODE_IDS:
        raise ValueError(ADJUDICATION_MISMATCH)
    if admission.get("deployment_compliance") != "FTMO":
        raise ValueError(SCOPE_NOT_FTMO)
    return {
        "qm_news_temporal": str(q09_contract.TEMPORAL_MODE_IDS[temporal]),
        "qm_news_compliance": str(FTMO_COMPLIANCE_MODE_ID),
    }


__all__ = [
    "ADMITTED_REASON",
    "EVIDENCE_MISSING",
    "evaluate_ftmo_q09_admission",
    "admission_from_inventory",
    "deployment_news_inputs",
]
