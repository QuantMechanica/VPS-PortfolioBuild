import json
import sqlite3
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _predecessor(evidence_path: Path) -> sqlite3.Row:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        "CREATE TABLE predecessor(id TEXT,evidence_path TEXT,ea_id TEXT,symbol TEXT,setfile_path TEXT)"
    )
    conn.execute(
        "INSERT INTO predecessor VALUES(?,?,?,?,?)",
        ("q08-anchor", str(evidence_path), "QM5_99999", "EURUSD.DWX", "demo.set"),
    )
    return conn.execute("SELECT * FROM predecessor").fetchone()


def _binding(evidence_path: Path, audit_path: Path) -> dict[str, str]:
    return {
        "schema": farmctl.Q09_AUDIT_ANCHOR_BINDING_SCHEMA,
        "anchor_work_item_id": "q08-anchor",
        "anchor_evidence_path": str(evidence_path),
        "anchor_evidence_sha256": farmctl._sha256_file(evidence_path),
        "audit_path": str(audit_path),
        "audit_sha256": farmctl._sha256_file(audit_path),
        "router_task_id": "task-exact",
        "owner_decision_id": "OWNER-DEC-EXACT",
        "scope": "EXACT_Q08_TO_Q09_APPEND_ONLY_REENTRY",
    }


def test_exact_q09_anchor_binding_is_stamped(tmp_path: Path) -> None:
    evidence = tmp_path / "aggregate.json"
    evidence.write_text(json.dumps({"verdict": "FAIL_SOFT"}), encoding="utf-8")
    audit = tmp_path / "audit.md"
    audit.write_text("sealed", encoding="utf-8")

    payload = farmctl._validated_q09_anchor_payload(
        _predecessor(evidence), phase="Q09", binding=_binding(evidence, audit)
    )

    assert payload["legacy_reentry_anchor_work_item_id"] == "q08-anchor"
    assert payload["legacy_reentry_anchor_evidence_sha256"] == farmctl._sha256_file(evidence)
    assert payload["legacy_reentry_audit_sha256"] == farmctl._sha256_file(audit)
    assert payload["legacy_reentry_router_task_id"] == "task-exact"


def test_q09_anchor_binding_rejects_hash_or_scope_expansion(tmp_path: Path) -> None:
    evidence = tmp_path / "aggregate.json"
    evidence.write_text("evidence", encoding="utf-8")
    audit = tmp_path / "audit.md"
    audit.write_text("sealed", encoding="utf-8")
    predecessor = _predecessor(evidence)

    wrong_hash = _binding(evidence, audit)
    wrong_hash["anchor_evidence_sha256"] = "0" * 64
    with pytest.raises(ValueError, match="evidence SHA-256 mismatch"):
        farmctl._validated_q09_anchor_payload(
            predecessor, phase="Q09", binding=wrong_hash
        )

    expanded = _binding(evidence, audit)
    expanded["another_pair"] = "not authorized"
    with pytest.raises(ValueError, match="keys mismatch"):
        farmctl._validated_q09_anchor_payload(
            predecessor, phase="Q09", binding=expanded
        )


def test_q09_anchor_binding_requires_append_only_exact_path(tmp_path: Path) -> None:
    result = farmctl.enqueue_cascade_backtest_for_ea(
        tmp_path,
        "QM5_99999",
        "Q09",
        predecessor_work_item_id="q08-anchor",
        q09_anchor_binding={"schema": "unused"},
    )
    assert not result["enqueued"]
    assert result["reason"] == (
        "q09_anchor_binding_requires_Q09_exact_predecessor_and_append_only_rerun_target"
    )
