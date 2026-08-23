from __future__ import annotations

import datetime as dt
import json
import sqlite3
import tempfile
from pathlib import Path

import pytest

from framework.scripts import q16_head_to_head as q16
from framework.scripts.q16_head_to_head import (
    _is_mutable_mt5_storage,
    evaluate_q16,
    sha256_file,
)
from tools.strategy_farm import farmctl


def _write(path: Path, value: object | str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, str):
        path.write_text(value, encoding="utf-8")
    else:
        path.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")
    return path


def _bound(path: Path, **extra: object) -> dict[str, object]:
    return {"path": str(path), "sha256": sha256_file(path), **extra}


def _epoch(day: str, hour: int = 12) -> int:
    stamp = dt.datetime.fromisoformat(day).replace(hour=hour, tzinfo=dt.UTC)
    return int(stamp.timestamp())


def _stream(path: Path, profits: list[float], *, ea: int, outside: bool = False) -> Path:
    days = ["2023-01-03", "2024-01-03", "2025-01-03", "2026-01-03"]
    rows = []
    for day, profit in zip(days, profits):
        rows.append({
            "event": "TRADE_CLOSED", "entry_time": _epoch(day, 10), "time": _epoch(day, 12),
            "profit": profit, "swap": 0.0, "commission": 0.0, "net": profit,
            "volume": 1.0, "notional": 100_000.0, "symbol": "GBPUSD.DWX", "ea_id": ea,
        })
    if outside:
        rows.append({
            "event": "TRADE_CLOSED", "entry_time": _epoch("2022-01-03", 10),
            "time": _epoch("2022-01-03", 12), "profit": 99_999.0, "swap": 0.0,
            "commission": 0.0, "net": 99_999.0, "volume": 1.0,
            "notional": 100_000.0, "symbol": "GBPUSD.DWX", "ea_id": ea,
        })
    path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")
    return path


def _fixture(tmp_path: Path) -> dict[str, Path]:
    set_body = "RISK_FIXED=1000\nRISK_PERCENT=0\n"
    parent_set = _write(tmp_path / "parent.set", set_body)
    challenger_set = _write(tmp_path / "challenger.set", set_body)
    parent_ex5 = _write(tmp_path / "parent.ex5", "parent-binary")
    challenger_ex5 = _write(tmp_path / "challenger.ex5", "challenger-binary")
    # Actual Tier-A exit-surgery precedent identity: QM5_10939/GBPUSD parent ->
    # QM5_12990/GBPUSD challenger (D2C_13SLEEVE_EXIT_SURGERY_AUDIT_2026-07-03).
    parent_stream = _stream(tmp_path / "parent.jsonl", [105, -45, 105, 105], ea=10939, outside=True)
    challenger_stream = _stream(tmp_path / "challenger.jsonl", [145, -15, 145, 145], ea=12990)
    rest_streams = {
        ea: _stream(
            tmp_path / f"rest_{ea}.jsonl",
            [(-1) ** ea * (20 + ea), 40 + ea, (-1) ** (ea + 1) * (15 + ea), 30 + ea],
            ea=ea,
        )
        for ea in range(3, 13)
    }
    incumbent_phase = q16.ACTIVE_GATE_MANIFEST.gate_for_role("INCUMBENT")
    q10_parent = _write(
        tmp_path / "parent_q10.json",
        {"phase": incumbent_phase, "verdict": "PASS"},
    )
    q10_challenger = _write(
        tmp_path / "challenger_q10.json",
        {"phase": incumbent_phase, "verdict": "PASS"},
    )
    q07 = _write(tmp_path / "q07.json", {
        "phase": "Q07", "trial_ledger": {"declared_trial_count": 2, "observed_trial_count": 2}
    })
    q08 = _write(tmp_path / "q08.json", {
        "phase": "Q08", "trial_ledger": {"declared_trial_count": 2, "observed_trial_count": 2}
    })

    parent_lineage = _write(tmp_path / "parent_lineage.json", {
        "schema": "qm.q16-lineage/v1", "role": "PARENT", "ea_id": 10939, "symbol": "GBPUSD.DWX",
        "binary": _bound(parent_ex5), "setfile": _bound(parent_set),
        "stream": _bound(parent_stream, frozen=True, risk_fixed=1000, risk_percent=0, trade_count=5),
        "q10": {"verdict": "PASS", "evidence": _bound(q10_parent)},
    })
    challenger_lineage = _write(tmp_path / "challenger_lineage.json", {
        "schema": "qm.q16-lineage/v1", "role": "CHALLENGER", "ea_id": 12990, "symbol": "GBPUSD.DWX",
        "binary": _bound(challenger_ex5), "setfile": _bound(challenger_set),
        "stream": _bound(challenger_stream, frozen=True, risk_fixed=1000, risk_percent=0, trade_count=4),
        "q10": {"verdict": "PASS", "evidence": _bound(q10_challenger)},
        "q07": {"trial_ledger_declared_count": 2, "observed_trial_count": 2, "evidence": _bound(q07)},
        "q08": {"trial_ledger_declared_count": 2, "observed_trial_count": 2, "evidence": _bound(q08)},
    })
    ledger = _write(tmp_path / "trial_ledger.json", {
        "schema": "qm.opt-trial-ledger/v1", "card_id": "opt-exit-1", "status": "CLOSED",
        "declared_trial_count": 2,
        "trials": [{"trial_id": "t1"}, {"trial_id": "t2"}],
    })
    card = _write(tmp_path / "opt_card.json", {
        "schema": "qm.opt-card/v1", "card_id": "opt-exit-1",
        "parent": {
            "ea_id": 10939, "symbol": "GBPUSD.DWX",
            "binary": _bound(parent_ex5), "setfile": _bound(parent_set),
        },
        "lever": "EXIT_SURGERY",
        "comparison_windows": [
            {"id": "F1", "kind": "Q04_ANCHORED_OOS", "start": "2023-01-01", "end": "2023-01-10"},
            {"id": "F2", "kind": "Q04_ANCHORED_OOS", "start": "2024-01-01", "end": "2024-01-10"},
            {"id": "F3", "kind": "Q04_ANCHORED_OOS", "start": "2025-01-01", "end": "2025-01-10"},
            {"id": "H1", "kind": "POST_DEV_HOLDOUT", "start": "2026-01-01", "end": "2026-01-10"},
        ],
        "success_metric": {
            "primary": "annual_return_pct", "direction": "MAXIMIZE", "minimum_improvement": 0,
            "require_maxdd_not_worse": True, "require_worst_day_not_worse": True,
        },
        "trial_ledger_path": str(ledger),
    })
    book = _write(tmp_path / "book.json", {
        "book": "FIXTURE", "total_risk_pct": 9.75,
        "sleeves": [
            {"ea_id": 10939, "symbol": "GBPUSD.DWX"},
            *[{"ea_id": ea, "symbol": "GBPUSD.DWX"} for ea in sorted(rest_streams)],
        ],
    })
    stream_manifest = _write(tmp_path / "book_streams.json", {
        "schema": "qm.frozen-trade-bundle/v1", "frozen": True,
        "streams": [
            {"ea_id": 10939, "symbol": "GBPUSD.DWX", **_bound(parent_stream, frozen=True, risk_fixed=1000, risk_percent=0, trade_count=5)},
            *[
                {"ea_id": ea, "symbol": "GBPUSD.DWX", **_bound(path, frozen=True, risk_fixed=1000, risk_percent=0, trade_count=4)}
                for ea, path in sorted(rest_streams.items())
            ],
        ],
    })
    cost = _write(tmp_path / "venue_cost_model.json", {
        "canonical_engine": {"class_model": {"forex": {"pct_rate_rt": 0.00005, "flat_per_lot_rt": 5.0}}},
        "symbols": {"GBPUSD": {
            "asset_class": "forex", "dwx_symbol": "GBPUSD.DWX",
            "dxz": {"commission_model": "flat_per_lot_rt", "commission_rt_per_lot_usd": 5.0},
            "ftmo": {"commission_model": "flat_per_lot_rt", "commission_rt_per_lot_usd": 5.0},
        }},
    })
    return {
        "opt_card_path": card, "parent_lineage_path": parent_lineage,
        "challenger_lineage_path": challenger_lineage, "trial_ledger_path": ledger,
        "book_manifest_path": book, "book_stream_manifest_path": stream_manifest,
        "cost_model_path": cost,
    }


def test_q16_fixture_is_deterministic_and_sealed(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    first = evaluate_q16(**paths)
    second = evaluate_q16(**paths)
    assert first == second
    assert first["verdict"] in {"PROMOTE_CHALLENGER", "ADMIT_BOTH"}
    assert first["challenger_comparison"]["success"]["passed"] is True
    assert first["risk_contract"] == {"RISK_FIXED": 1000.0, "RISK_PERCENT": 0.0}
    # The huge 2022 trade is outside all registered windows and cannot affect the parent.
    assert first["no_change_control"]["parent_stream"]["excluded_trade_count"] == 1
    assert len(first["sealed_windows"]) == 4
    challenger = json.loads(paths["challenger_lineage_path"].read_text(encoding="utf-8"))
    assert first["artifact_identity"] == {
        "ex5_sha256": challenger["binary"]["sha256"],
        "setfile_sha256": challenger["setfile"]["sha256"],
        "data_window_start": "2023-01-01",
        "data_window_end": "2026-01-10",
    }
    if first["verdict"] == "ADMIT_BOTH":
        checks = first["book_marginal"]["admit_both_checks"]
        assert checks == {"both_contribute": True, "max_abs_pair_regime_corr_below_0p15": True}


def test_q16_accepts_operator_staged_evidence_under_appdata_temp(
    tmp_path: Path, monkeypatch,
) -> None:
    appdata_temp = tmp_path / "Users" / "Operator" / "AppData" / "Local" / "Temp"
    appdata_temp.mkdir(parents=True)
    monkeypatch.setenv("TMP", str(appdata_temp))
    monkeypatch.setenv("TEMP", str(appdata_temp))
    previous_tempdir = tempfile.tempdir
    tempfile.tempdir = None
    try:
        generated = Path(tempfile.mkdtemp(prefix="q16_operator_stage_"))
        assert appdata_temp.resolve() in generated.resolve().parents
        result = evaluate_q16(**_fixture(generated))
    finally:
        tempfile.tempdir = previous_tempdir

    assert result["verdict"] in {"PROMOTE_CHALLENGER", "ADMIT_BOTH"}


def test_mutable_storage_classifier_is_mt5_specific(tmp_path: Path) -> None:
    assert not _is_mutable_mt5_storage(
        tmp_path / "Users" / "Operator" / "AppData" / "Local" / "Temp" / "frozen.jsonl"
    )
    assert _is_mutable_mt5_storage(
        tmp_path / "Users" / "Operator" / "AppData" / "Roaming" / "MetaQuotes" /
        "Terminal" / "ABC123" / "Common" / "Files" / "live.jsonl"
    )
    assert _is_mutable_mt5_storage(
        tmp_path / "portable-terminal" / "MQL5" / "Files" / "live.jsonl"
    )


def test_q16_trial_ledger_undercount_is_hard_fail(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    ledger = json.loads(paths["trial_ledger_path"].read_text())
    ledger["declared_trial_count"] = 1
    _write(paths["trial_ledger_path"], ledger)
    result = evaluate_q16(**paths)
    assert result["verdict"] == "FAIL"
    assert "trial ledger undercount" in result["error"]


def test_q16_requires_challenger_q10_pass(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    lineage = json.loads(paths["challenger_lineage_path"].read_text())
    lineage["q10"]["verdict"] = "FAIL"
    _write(paths["challenger_lineage_path"], lineage)
    result = evaluate_q16(**paths)
    assert result["verdict"] == "FAIL"
    assert "does not hold Q10 PASS" in result["error"]


def test_q16_parent_hash_must_match_opt_card(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    card = json.loads(paths["opt_card_path"].read_text())
    card["parent"]["binary"]["sha256"] = "0" * 64
    _write(paths["opt_card_path"], card)
    result = evaluate_q16(**paths)
    assert result["verdict"] == "FAIL"
    assert "does not match opt-card frozen hash" in result["error"]


def test_q16_requires_three_anchored_folds_and_holdout(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    card = json.loads(paths["opt_card_path"].read_text())
    card["comparison_windows"] = card["comparison_windows"][:2] + card["comparison_windows"][-1:]
    _write(paths["opt_card_path"], card)
    result = evaluate_q16(**paths)
    assert result["verdict"] == "FAIL"
    assert "three anchored" in result["error"]


def test_farmctl_head_to_head_is_dry_run_default_and_apply_is_idempotent(tmp_path: Path) -> None:
    paths = _fixture(tmp_path / "inputs")
    root = tmp_path / "farm"
    kwargs = {
        "opt_card_path": str(paths["opt_card_path"]),
        "parent_lineage_path": str(paths["parent_lineage_path"]),
        "challenger_lineage_path": str(paths["challenger_lineage_path"]),
        "trial_ledger_path": str(paths["trial_ledger_path"]),
        "book_manifest_path": str(paths["book_manifest_path"]),
        "book_stream_manifest_path": str(paths["book_stream_manifest_path"]),
        "parent_q10_work_item_id": "parent-q10",
        "challenger_q10_work_item_id": "challenger-q10",
    }
    preview = farmctl.enqueue_head_to_head(root, apply=False, **kwargs)
    assert preview["dry_run"] is True
    assert preview["enqueued"] is False
    assert not (root / farmctl.DB_REL).exists()

    farmctl.init_db(root)
    now = "2026-08-12T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        incumbent_phase = q16.ACTIVE_GATE_MANIFEST.gate_for_role("INCUMBENT")
        for item_id, ea_id, evidence_path in (
            ("parent-q10", "QM5_10939", paths["parent_lineage_path"].parent / "parent_q10.json"),
            ("challenger-q10", "QM5_12990", paths["challenger_lineage_path"].parent / "challenger_q10.json"),
        ):
            conn.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                    parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
                ) VALUES(?, 'backtest', ?, ?, 'GBPUSD.DWX', ?, 'done', 'PASS', 0,
                         NULL, ?, NULL, '{}', ?, ?)
                """,
                (
                    item_id, incumbent_phase, ea_id, str(paths["challenger_lineage_path"]),
                    str(evidence_path), now, now,
                ),
            )
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
            ) VALUES('baseline-q08', 'backtest', 'Q08', 'QM5_10939', 'GBPUSD.DWX', ?,
                     'done', 'PASS', 0, NULL, ?, NULL, '{}', ?, ?)
            """,
            (
                str(paths["parent_lineage_path"]),
                str(paths["opt_card_path"].parent / "q08.json"),
                now,
                now,
            ),
        )
        conn.commit()
    applied = farmctl.enqueue_head_to_head(root, apply=True, **kwargs)
    repeated = farmctl.enqueue_head_to_head(root, apply=True, **kwargs)
    assert applied["enqueued"] is True and applied["idempotent"] is False
    assert repeated["enqueued"] is True and repeated["idempotent"] is True
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT kind,phase,status FROM work_items WHERE id=?",
            (applied["would_create_work_item_id"],),
        ).fetchone()
        dependencies = conn.execute(
            """
            SELECT dependency_role,parent_work_item_id,required_verdicts_json
            FROM work_item_dependencies WHERE child_work_item_id=?
            ORDER BY dependency_role
            """,
            (applied["would_create_work_item_id"],),
        ).fetchall()
    assert tuple(row) == (
        "analytic",
        q16.ACTIVE_GATE_MANIFEST.gate_for_role("HEAD_TO_HEAD"),
        "pending",
    )
    assert [tuple(row) for row in dependencies] == [
        ("BASELINE_Q09", "baseline-q08", '["PASS","FAIL_SOFT"]'),
        ("CHALLENGER_Q11", "challenger-q10", '["PASS"]'),
        ("INCUMBENT_Q11", "parent-q10", '["PASS"]'),
    ]

    # A later DB/path substitution cannot ride the deterministic idempotent
    # path: both sidecar dependencies are rebound to their sealed Q10 evidence.
    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE work_items SET evidence_path=? WHERE id='parent-q10'",
            (str(paths["challenger_lineage_path"].parent / "challenger_q10.json"),),
        )
        conn.commit()
    with pytest.raises(ValueError, match="DB evidence does not match"):
        farmctl.enqueue_head_to_head(root, apply=True, **kwargs)


def _insert_wi(
    conn: sqlite3.Connection,
    *,
    item_id: str,
    phase: str,
    verdict: str | None,
    status: str = "done",
    kind: str = "backtest",
) -> None:
    now = "2026-08-23T00:00:00+00:00"
    conn.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
            parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
        ) VALUES(?, ?, ?, 'QM5_12990', 'GBPUSD.DWX', 'x.set', ?, ?, 0,
                 NULL, 'e.json', NULL, '{}', ?, ?)
        """,
        (item_id, kind, phase, status, verdict, now, now),
    )


def test_baseline_q09_dependency_records_fail_soft_verdict_set(tmp_path: Path) -> None:
    """The v4 BASELINE_Q09 lane binds ['PASS','FAIL_SOFT'] so a FAIL_SOFT
    baseline parent is accepted by the append-only insert trigger, and the
    stored ``required_verdicts_json`` matches the accepted verdicts."""
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        # v4 head-to-head child lives at Q14; the baseline parent is a FAIL_SOFT Q08 row.
        _insert_wi(conn, item_id="h2h", phase="Q14", verdict=None,
                   status="pending", kind="analytic")
        _insert_wi(conn, item_id="baseline", phase="Q08", verdict="FAIL_SOFT")
        conn.commit()

        spec = {
            "dependency_role": "BASELINE_Q09",
            "parent_work_item_id": "baseline",
            "parent_evidence_sha256": "a" * 64,
            "required_verdicts": ["PASS", "FAIL_SOFT"],
        }
        assert farmctl._ensure_q16_dependency(conn, child_work_item_id="h2h", spec=spec) is True
        # Re-appending the identical spec verifies without a second insert.
        assert farmctl._ensure_q16_dependency(conn, child_work_item_id="h2h", spec=spec) is False
        conn.commit()
        stored = conn.execute(
            "SELECT required_verdicts_json FROM work_item_dependencies "
            "WHERE child_work_item_id='h2h' AND dependency_role='BASELINE_Q09'"
        ).fetchone()
    assert json.loads(stored["required_verdicts_json"]) == ["PASS", "FAIL_SOFT"]


def test_baseline_q09_pass_only_binding_is_rejected_for_fail_soft_parent(tmp_path: Path) -> None:
    """Regression guard for the P2 finding: binding a FAIL_SOFT baseline with
    the old hardcoded ['PASS'] set is rejected by the schema insert trigger
    (parent verdict not in required set), proving the fix is load-bearing."""
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_wi(conn, item_id="h2h", phase="Q14", verdict=None,
                   status="pending", kind="analytic")
        _insert_wi(conn, item_id="baseline", phase="Q08", verdict="FAIL_SOFT")
        conn.commit()
        bad_spec = {
            "dependency_role": "BASELINE_Q09",
            "parent_work_item_id": "baseline",
            "parent_evidence_sha256": "a" * 64,
            "required_verdicts": ["PASS"],
        }
        with pytest.raises(sqlite3.Error):
            farmctl._ensure_q16_dependency(conn, child_work_item_id="h2h", spec=bad_spec)


def test_default_dependency_spec_stays_pass_only(tmp_path: Path) -> None:
    """The confirmation/incumbent/challenger lanes keep the PASS-only default
    when ``required_verdicts`` is not supplied."""
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_wi(conn, item_id="h2h", phase="Q16", verdict=None,
                   status="pending", kind="analytic")
        _insert_wi(conn, item_id="parent", phase="Q10", verdict="PASS")
        conn.commit()
        spec = {
            "dependency_role": "PARENT_LINEAGE",
            "parent_work_item_id": "parent",
            "parent_evidence_sha256": "b" * 64,
        }
        assert farmctl._ensure_q16_dependency(conn, child_work_item_id="h2h", spec=spec) is True
        conn.commit()
        stored = conn.execute(
            "SELECT required_verdicts_json FROM work_item_dependencies "
            "WHERE child_work_item_id='h2h' AND dependency_role='PARENT_LINEAGE'"
        ).fetchone()
    assert json.loads(stored["required_verdicts_json"]) == ["PASS"]
