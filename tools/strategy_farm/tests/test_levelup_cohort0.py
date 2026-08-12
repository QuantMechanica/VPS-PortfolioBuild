from __future__ import annotations

import csv
import json
import sqlite3
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import farmctl  # noqa: E402


def _insert_parent(conn: sqlite3.Connection, parent_id: str, ea_id: str) -> None:
    now = farmctl.utc_now()
    conn.execute(
        """
        INSERT INTO tasks(
            id, kind, status, source_id, card_id, payload_json, created_at, updated_at
        ) VALUES (?, 'backtest_q02', 'active', NULL, ?, ?, ?, ?)
        """,
        (
            parent_id,
            ea_id,
            json.dumps({"ea_id": ea_id, "phase": "Q02"}),
            now,
            now,
        ),
    )


def _insert_q02_row(
    conn: sqlite3.Connection,
    *,
    item_id: str,
    parent_id: str,
    ea_id: str,
    symbol: str,
    verdict: str,
) -> None:
    now = farmctl.utc_now()
    conn.execute(
        """
        INSERT INTO work_items(
            id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
            attempt_count, parent_task_id, payload_json, created_at, updated_at
        ) VALUES (?, 'backtest', 'Q02', ?, ?, ?, 'done', ?, 0, ?, '{}', ?, ?)
        """,
        (item_id, ea_id, symbol, f"{item_id}.set", verdict, parent_id, now, now),
    )


def test_strategy_entry_gate_rejects_skeletons_and_accepts_real_logic(
    tmp_path: Path,
) -> None:
    marker_dir = tmp_path / "marker"
    marker_dir.mkdir()
    (marker_dir / "marker.mq5").write_text(
        "// TODO: Auto-generated skeleton.\n"
        "bool Strategy_EntrySignal(QM_EntryRequest &req) { return false; }\n",
        encoding="utf-8",
    )
    marker = farmctl._validate_ea_strategy_entry({"ea_dir": str(marker_dir)})
    assert marker["ok"] is False
    assert marker["failures"] == ["strategy_entry_skeleton_marker:marker.mq5"]

    stub_dir = tmp_path / "stub"
    stub_dir.mkdir()
    (stub_dir / "stub.mq5").write_text(
        "bool Strategy_EntrySignal(QM_EntryRequest &req)\n"
        "{\n  /* generated placeholder */\n  return (false); // still a stub\n}\n",
        encoding="utf-8",
    )
    stub = farmctl._validate_ea_strategy_entry({"mq5_path": str(stub_dir / "stub.mq5")})
    assert stub["ok"] is False
    assert stub["failures"] == ["strategy_entry_constant_false:stub.mq5"]

    real_dir = tmp_path / "real"
    real_dir.mkdir()
    (real_dir / "real.mq5").write_text(
        "bool Strategy_EntrySignal(QM_EntryRequest &req)\n"
        "{\n  if(Close[1] > Open[1]) return true;\n  return false;\n}\n",
        encoding="utf-8",
    )
    real = farmctl._validate_ea_strategy_entry({"ea_dir": str(real_dir)})
    assert real["ok"] is True
    assert real["failures"] == []


def test_record_build_result_blocks_skeleton_before_q02(
    tmp_path: Path,
    monkeypatch,
) -> None:
    root = tmp_path / "farm"
    ea_dir = tmp_path / "QM5_9003_stub"
    ea_dir.mkdir()
    (ea_dir / "QM5_9003_stub.mq5").write_text(
        "// Auto-generated skeleton\n"
        "bool Strategy_EntrySignal(QM_EntryRequest &req) { return false; }\n",
        encoding="utf-8",
    )
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO tasks(
                id, kind, status, source_id, card_id, payload_json, created_at, updated_at
            ) VALUES ('build-stub', 'build_ea', 'active', NULL, 'QM5_9003', '{}', ?, ?)
            """,
            (now, now),
        )
        conn.commit()

    result_file = tmp_path / "build-result.json"
    result_file.write_text(
        json.dumps(
            {
                "ea_id": "QM5_9003",
                "slug": "stub",
                "ea_dir": str(ea_dir),
                "compile_succeeded": True,
                "build_check_passed": True,
                "smoke_result": "passed",
                "setfiles_generated": [],
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        farmctl,
        "_validate_ea_spec_md",
        lambda _result, _root: {"ok": True, "failures": []},
    )

    recorded = farmctl.record_build_result(root, "build-stub", str(result_file))

    assert recorded["new_status"] == "blocked"
    assert recorded["blocked_reason"] == "strategy_entry_stub"
    assert recorded["fail_code"] == "strategy_entry_stub"
    assert recorded["auto_q02_enqueued"] is None
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status, payload_json FROM tasks WHERE id='build-stub'"
        ).fetchone()
    payload = json.loads(row["payload_json"])
    assert row["status"] == "blocked"
    assert payload["strategy_entry_validation"]["ok"] is False
    assert payload["codex_result"]["blocked_reason"] == "strategy_entry_stub"


def test_q02_exact_zero_is_distinct_from_low_positive_and_missing_metrics() -> None:
    base = {"result": "PASS", "model4_log_marker_detected": True}
    zero = farmctl._derive_verdict_from_summary(
        {**base, "runs": [{"total_trades": 0}]},
        min_trades=5,
        phase="Q02",
    )
    low = farmctl._derive_verdict_from_summary(
        {**base, "runs": [{"total_trades": 1}]},
        min_trades=5,
        phase="Q02",
    )
    missing = farmctl._derive_verdict_from_summary(
        {**base, "runs": [{"net_profit": 0.0}]},
        min_trades=5,
        phase="Q02",
    )
    infra = farmctl._derive_verdict_from_summary(
        {
            "result": "FAIL",
            "reason_classes": ["NO_HISTORY"],
            "runs": [{"total_trades": 0}],
        },
        min_trades=5,
        phase="Q02",
    )

    assert zero == ("ZERO_TRADES", "Q02_ZERO_TRADES")
    assert low == ("FAIL", "MIN_TRADES_NOT_MET")
    assert missing == ("FAIL", "MIN_TRADES_NOT_MET")
    assert infra[0] == "INFRA_FAIL"


def test_all_finished_q02_zero_rows_promote_to_draft_defect(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_parent(conn, "parent-zero", "QM5_9004")
        _insert_q02_row(
            conn,
            item_id="zero-a",
            parent_id="parent-zero",
            ea_id="QM5_9004",
            symbol="EURUSD.DWX",
            verdict="ZERO_TRADES",
        )
        _insert_q02_row(
            conn,
            item_id="zero-b",
            parent_id="parent-zero",
            ea_id="QM5_9004",
            symbol="GBPUSD.DWX",
            verdict="ZERO_TRADES",
        )
        conn.commit()
        completed = conn.execute("SELECT * FROM work_items WHERE id='zero-b'").fetchone()
        promoted = farmctl._promote_zero_trade_q02_cohort_to_draft_defect(
            conn, completed
        )
        conn.commit()
        rows = conn.execute(
            "SELECT * FROM work_items WHERE parent_task_id='parent-zero' ORDER BY id"
        ).fetchall()

    assert promoted == ["zero-a", "zero-b"]
    assert {row["verdict"] for row in rows} == {"DRAFT_DEFECT"}
    assert farmctl._aggregate_work_item_verdict("Q02", list(rows), []) == "DRAFT_DEFECT"
    for row in rows:
        payload = json.loads(row["payload_json"])
        assert payload["verdict_route"] == "RE_DRAFT"
        assert payload["verdict_taxonomy"] == "draft_defect"


def test_mixed_q02_cohort_remains_strategy_fail(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_parent(conn, "parent-mixed", "QM5_9005")
        _insert_q02_row(
            conn,
            item_id="mixed-zero",
            parent_id="parent-mixed",
            ea_id="QM5_9005",
            symbol="EURUSD.DWX",
            verdict="ZERO_TRADES",
        )
        _insert_q02_row(
            conn,
            item_id="mixed-fail",
            parent_id="parent-mixed",
            ea_id="QM5_9005",
            symbol="GBPUSD.DWX",
            verdict="FAIL",
        )
        conn.commit()
        completed = conn.execute("SELECT * FROM work_items WHERE id='mixed-fail'").fetchone()
        promoted = farmctl._promote_zero_trade_q02_cohort_to_draft_defect(
            conn, completed
        )
        rows = conn.execute(
            "SELECT * FROM work_items WHERE parent_task_id='parent-mixed' ORDER BY id"
        ).fetchall()

    assert promoted == []
    assert farmctl._aggregate_work_item_verdict("Q02", list(rows), []) == "STRATEGY_FAIL"


def test_staged_q02_waits_for_the_full_build_cohort(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = farmctl.utc_now()
    payload = json.dumps({"build_task_id": "build-9007", "q02_cohort_size": 2})
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                attempt_count, payload_json, created_at, updated_at
            ) VALUES ('stage-a', 'backtest', 'Q02', 'QM5_9007', 'EURUSD.DWX',
                      'a.set', 'done', 'ZERO_TRADES', 0, ?, ?, ?)
            """,
            (payload, now, now),
        )
        conn.commit()
        first = conn.execute("SELECT * FROM work_items WHERE id='stage-a'").fetchone()
        assert farmctl._promote_zero_trade_q02_cohort_to_draft_defect(conn, first) == []
        conn.execute(
            """
            INSERT INTO work_items(
                id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                attempt_count, payload_json, created_at, updated_at
            ) VALUES ('stage-b', 'backtest', 'Q02', 'QM5_9007', 'GBPUSD.DWX',
                      'b.set', 'done', 'ZERO_TRADES', 0, ?, ?, ?)
            """,
            (payload, now, now),
        )
        conn.commit()
        second = conn.execute("SELECT * FROM work_items WHERE id='stage-b'").fetchone()
        promoted = farmctl._promote_zero_trade_q02_cohort_to_draft_defect(conn, second)

    assert promoted == ["stage-a", "stage-b"]


def _write_p2_report(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["symbol", "verdict", "invalidation_reason", "evidence"],
        )
        writer.writeheader()
        writer.writerows(rows)


def test_legacy_p2_classifier_requires_exact_zero_on_every_row(tmp_path: Path) -> None:
    zero_a = tmp_path / "zero-a.json"
    zero_b = tmp_path / "zero-b.json"
    low = tmp_path / "low.json"
    zero_a.write_text(json.dumps({"runs": [{"total_trades": 0}]}), encoding="utf-8")
    zero_b.write_text(json.dumps({"runs": [{"total_trades": 0}]}), encoding="utf-8")
    low.write_text(json.dumps({"runs": [{"total_trades": 1}]}), encoding="utf-8")
    report = tmp_path / "report.csv"
    rows = [
        {
            "symbol": "EURUSD.DWX",
            "verdict": "FAIL",
            "invalidation_reason": "trade_count_below_min",
            "evidence": str(zero_a),
        },
        {
            "symbol": "GBPUSD.DWX",
            "verdict": "FAIL",
            "invalidation_reason": "trade_count_below_min",
            "evidence": str(zero_b),
        },
    ]
    _write_p2_report(report, rows)
    all_zero = farmctl.classify_p2(report)
    assert all_zero["verdict"] == "DRAFT_DEFECT"
    assert all_zero["route"] == "RE_DRAFT"
    assert all_zero["retire_strategy"] is False

    rows[1]["evidence"] = str(low)
    _write_p2_report(report, rows)
    mixed = farmctl.classify_p2(report)
    assert mixed["verdict"] == "STRATEGY_FAIL"


def test_approve_card_requires_targets_and_literal_timeframe_in_body(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    card = tmp_path / "QM5_9006_contract.md"
    card.write_text(
        "---\n"
        "ea_id: QM5_9006\n"
        "slug: contract\n"
        "g0_status: PENDING\n"
        "r1_track_record: PASS\n"
        "r2_mechanical: PASS\n"
        "r3_data_available: PASS\n"
        "r4_ml_forbidden: PASS\n"
        "expected_trades_per_year_per_symbol: 20\n"
        "target_symbols: [ ]\n"
        "timeframe: H1\n"
        "---\n\n"
        "## Entry\nSignal enters the market.\n\n"
        "## Exit\nClose at stop.\n\n"
        "## Risk\nFixed position sizing.\n",
        encoding="utf-8",
    )

    result = farmctl.approve_card(root, str(card), "mechanical source-backed card")
    assert result["approved"] is False
    assert result["reason"] == "card_contract_invalid"
    assert result["issues"] == [
        "schema_missing_frontmatter:target_symbols",
        "schema_missing_body:timeframe_literal",
    ]
    issues = farmctl.strategy_card_schema_issues(card)
    assert "schema_missing_frontmatter:target_symbols" in issues
    assert "schema_missing_body:timeframe" in issues

    card.write_text(
        card.read_text(encoding="utf-8")
        .replace("target_symbols: [ ]", "target_symbols: [EURUSD.DWX]")
        .replace("## Entry", "## Timeframe\nSignals use the h1 close.\n\n## Entry"),
        encoding="utf-8",
    )
    assert farmctl._approval_card_contract_issues(card) == []
    issues = farmctl.strategy_card_schema_issues(card)
    assert "schema_missing_frontmatter:target_symbols" not in issues
    assert "schema_missing_body:timeframe" not in issues
