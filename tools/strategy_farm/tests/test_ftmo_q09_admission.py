from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import q09_news_contract as contract
from tools.strategy_farm.portfolio import ftmo_q09_admission as admission


def _database(tmp_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(tmp_path / "farm.sqlite")
    conn.row_factory = sqlite3.Row
    conn.executescript(
        """
        CREATE TABLE work_items (
            id TEXT, phase TEXT, ea_id TEXT, symbol TEXT, status TEXT,
            verdict TEXT, evidence_path TEXT, created_at TEXT, updated_at TEXT
        );
        CREATE TABLE q09_news_tests (
            work_item_id TEXT, verdict TEXT, target_compliance TEXT,
            matrix_scope TEXT, chosen_temporal TEXT, chosen_compliance TEXT,
            aggregate_path TEXT, aggregate_sha256 TEXT
        );
        CREATE TABLE q09_news_cells (
            q09_news_work_item_id TEXT, arm TEXT, temporal_mode TEXT,
            compliance_mode TEXT, seed INTEGER, selection_metrics_json TEXT,
            q07_seed_stability_pass INTEGER,
            flat_at_event_receipt_sha256 TEXT
        );
        """
    )
    return conn


def _locked(
    conn: sqlite3.Connection,
    tmp_path: Path,
    *,
    target: str,
    scope: str,
    chosen_temporal: str = "PRE60",
    chosen_compliance: str | None = None,
) -> None:
    chosen_compliance = chosen_compliance or target
    document = {
        "schema_version": contract.ADJUDICATION_SCHEMA_VERSION,
        "verdict": "CONFIG_LOCKED",
        "reason_codes": ["robust_policy_selected"],
        "work_item_id": "q09-1",
        "deployment_target": target,
        "target_compliance": target,
        "chosen_config": {
            "temporal_mode": chosen_temporal,
            "temporal_mode_id": contract.TEMPORAL_MODE_IDS[chosen_temporal],
            "compliance_mode": chosen_compliance,
            "setfile_sha256s": ["a" * 64],
        },
        "locked_arms": [],
        "ranking": [],
        "matrix_scope": scope,
    }
    document["adjudication_sha256"] = contract.sha256_bytes(
        contract.canonical_json_bytes(document)
    )
    aggregate = tmp_path / "aggregate.json"
    aggregate.write_bytes(contract.canonical_json_bytes(document))
    aggregate_sha = contract.sha256_file(aggregate)
    conn.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?)",
        (
            "q09-1", "Q09_NEWS", "QM5_42", "EURUSD.DWX", "done",
            "CONFIG_LOCKED", str(aggregate), "2026-08-04", "2026-08-04",
        ),
    )
    conn.execute(
        "INSERT INTO q09_news_tests VALUES (?,?,?,?,?,?,?,?)",
        (
            "q09-1", "CONFIG_LOCKED", target, scope, chosen_temporal,
            chosen_compliance, str(aggregate), aggregate_sha,
        ),
    )
    metrics = json.dumps(
        {"trades": 30, "profit_factor": 1.2, "drawdown_pct": 4.0}
    )
    temporals = contract.TEMPORAL_MODES if scope == "7x4" else (chosen_temporal,)
    for temporal in temporals:
        for seed in contract.SEEDS:
            conn.execute(
                "INSERT INTO q09_news_cells VALUES (?,?,?,?,?,?,?,?)",
                ("q09-1", "POLICY_ON", temporal, "FTMO", seed, metrics, 1, None),
            )
    conn.commit()


def test_no_q09_evidence_is_fail_closed(tmp_path: Path) -> None:
    conn = _database(tmp_path)
    try:
        result = admission.evaluate_ftmo_q09_admission(conn, "QM5_42", "EURUSD.DWX")
    finally:
        conn.close()
    assert result["admitted"] is False
    assert result["reason_code"] == admission.EVIDENCE_MISSING


def test_direct_ftmo_7x1_lock_is_admitted_and_binds_inputs(tmp_path: Path) -> None:
    conn = _database(tmp_path)
    _locked(conn, tmp_path, target="FTMO", scope="7x1_target_compliance")
    try:
        result = admission.evaluate_ftmo_q09_admission(conn, 42, "EURUSD.DWX")
    finally:
        conn.close()
    assert result["admitted"] is True
    assert result["reason_code"] == admission.ADMITTED_REASON
    assert admission.deployment_news_inputs(result) == {
        "qm_news_temporal": "2",
        "qm_news_compliance": "2",
    }


def test_dxz_7x4_lock_admits_only_with_complete_viable_ftmo_cells(tmp_path: Path) -> None:
    conn = _database(tmp_path)
    _locked(
        conn,
        tmp_path,
        target="DXZ",
        scope="7x4",
        chosen_compliance="DXZ",
    )
    try:
        result = admission.evaluate_ftmo_q09_admission(conn, 42, "EURUSD.DWX")
    finally:
        conn.close()
    assert result["admitted"] is True
    assert result["source_target_compliance"] == "DXZ"
    assert result["deployment_compliance"] == "FTMO"


def test_nonviable_ftmo_cell_excludes_candidate(tmp_path: Path) -> None:
    conn = _database(tmp_path)
    _locked(conn, tmp_path, target="DXZ", scope="7x4", chosen_compliance="DXZ")
    conn.execute(
        """
        UPDATE q09_news_cells SET q07_seed_stability_pass=0
        WHERE compliance_mode='FTMO' AND temporal_mode='PRE60' AND seed=?
        """,
        (contract.SEEDS[0],),
    )
    conn.commit()
    try:
        result = admission.evaluate_ftmo_q09_admission(conn, 42, "EURUSD.DWX")
    finally:
        conn.close()
    assert result["admitted"] is False
    assert result["reason_code"] == admission.FTMO_CONFIG_NOT_VIABLE


def test_dxz_7x1_does_not_cover_ftmo(tmp_path: Path) -> None:
    conn = _database(tmp_path)
    _locked(
        conn,
        tmp_path,
        target="DXZ",
        scope="7x1_target_compliance",
        chosen_compliance="DXZ",
    )
    try:
        result = admission.evaluate_ftmo_q09_admission(conn, 42, "EURUSD.DWX")
    finally:
        conn.close()
    assert result["admitted"] is False
    assert result["reason_code"] == admission.SCOPE_NOT_FTMO
