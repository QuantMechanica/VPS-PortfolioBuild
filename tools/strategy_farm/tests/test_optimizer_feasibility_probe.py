"""Tests for the fail-closed V4b native-optimizer feasibility probe."""
import json
from pathlib import Path

from tools.strategy_farm import optimizer_feasibility_probe as probe


VALID_IDS = list(range(3, 61)) + list(range(77, 85)) + list(range(87, 95)) + list(range(98, 101))


def _fixture(tmp_path: Path) -> tuple[Path, Path]:
    ea_dir = tmp_path / "ea"
    ea_dir.mkdir()
    source = "\n".join(f"input int {name} = 0;" for name in probe.OPT_INPUTS) + "\n"
    (ea_dir / "QM5_41161_tv-mon-ls-opt.mq5").write_text(source, encoding="utf-8")
    (ea_dir / "QM5_41161_tv-mon-ls-opt.ex5").write_bytes(b"sealed-ex5")
    base = tmp_path / "base.set"
    base.write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours=336\n"
        + "\n".join(f"{name}=0" for name in probe.OPT_INPUTS)
        + "\n",
        encoding="utf-8",
    )
    cells = [
        {
            "year": 2019,
            "direction": "NONE",
            "predicate_id": 0,
            "arm": "baseline",
            "cell_key": "p:2019:baseline",
        }
    ]
    for direction in ("BUY", "SELL"):
        for value in VALID_IDS:
            cells.append(
                {
                    "year": 2019,
                    "direction": direction,
                    "predicate_id": value,
                    "arm": f"{direction.lower()}_{value:03d}",
                    "cell_key": f"p:2019:{direction.lower()}_{value:03d}",
                }
            )
    ledger = tmp_path / "ledger.json"
    ledger.write_text(
        json.dumps(
            {
                "schema": probe.EXPECTED_LEDGER_SCHEMA,
                "base_setfile_path": str(base),
                "cells": cells,
            }
        ),
        encoding="utf-8",
    )
    return ledger, ea_dir


def test_contiguous_segments_exposes_sparse_predicate_lattice():
    assert probe.contiguous_segments(VALID_IDS) == [
        (3, 60),
        (77, 84),
        (87, 94),
        (98, 100),
    ]


def test_protocol_refuses_one_input_and_emits_eight_complete_jobs(tmp_path):
    ledger, ea_dir = _fixture(tmp_path)
    protocol = probe.build_protocol(ledger_path=ledger, ea_dir=ea_dir, year=2019)
    assert protocol["launch_performed"] is False
    assert protocol["single_input_154_exact"]["feasible"] is False
    decomposition = protocol["exact_binary_preserving_decomposition"]
    assert decomposition["job_count"] == 8
    assert decomposition["complete_passes"] == 154
    for job in decomposition["jobs"]:
        ini = job["tester_ini_text"]
        assert "Optimization=1" in ini
        assert "Optimization=2" not in ini
        assert "Model=4" in ini
        assert "UseRemote=0" in ini
        assert "UseCloud=0" in ini
        assert "RISK_FIXED=1000" in job["setfile_text"]
        assert "RISK_PERCENT=0" in job["setfile_text"]
        assert "qm_news_stale_max_hours=336" in job["setfile_text"]


def test_optimizer_setfile_rejects_weakened_guardrails():
    text = (
        "RISK_FIXED=1000\nRISK_PERCENT=1\nqm_news_stale_max_hours=337\n"
        + "\n".join(f"{name}=0" for name in probe.OPT_INPUTS)
    )
    try:
        probe.optimizer_setfile(
            text, target_input="opt_pp_buy1", start=3, stop=10
        )
    except ValueError as exc:
        assert "RISK_PERCENT" in str(exc) or "stale" in str(exc)
    else:  # pragma: no cover - explicit fail-closed assertion
        raise AssertionError("weakened optimizer setfile was accepted")


def test_report_states_no_launch_and_never_fabricates_native_comparison(tmp_path):
    ledger, ea_dir = _fixture(tmp_path)
    protocol = probe.build_protocol(ledger_path=ledger, ea_dir=ea_dir, year=2019)
    comparisons = [
        {
            "direction": "BUY",
            "predicate_id": 3,
            "cold_total_trades": 10,
            "cold_profit_factor": 1.2,
            "cold_net_profit": 100.0,
            "cold_max_drawdown": 50.0,
            "cold_ex5_sha256": protocol["ex5_sha256"],
        }
    ]
    report = probe.render_report(protocol, comparisons)
    assert "NOT_REPRODUCIBLE_AS_SPECIFIED" in report
    assert "NO_MT5_LAUNCH" in report
    assert "Native passes: **0**" in report
    assert "entry_trading_days" in report
    assert "T1–T10, T_Live" in report
