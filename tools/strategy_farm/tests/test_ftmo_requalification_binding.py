import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_requalification_binding as binding  # noqa: E402


def _iso(epoch: float) -> str:
    return datetime.fromtimestamp(epoch, timezone.utc).isoformat().replace("+00:00", "Z")


def _native_report(
    *,
    expert: str = "QM5_1_test",
    symbol: str = "USDJPY.DWX",
    period: str = "M30",
    from_date: str = "2017.01.01",
    to_date: str = "2022.12.31",
    trades: int = 201,
    pf: str = "1.31",
    drawdown_money: str = "11 990.00",
    drawdown_pct: str = "11.99",
    net_profit: str = "5 000.00",
    inputs: dict[str, str] | None = None,
) -> str:
    input_rows = []
    for index, (key, value) in enumerate(
        (inputs or {"qm_ea_id": "1", "RISK_FIXED": "1000", "strategy_period": "14"}).items()
    ):
        label = "Inputs:" if index == 0 else ""
        input_rows.append(f"<tr><td>{label}</td><td><b>{key}={value}</b></td></tr>")
    return """<!DOCTYPE html><html><body><table>
<tr><td>Expert:</td><td><b>{expert}</b></td></tr>
<tr><td>Symbol:</td><td><b>{symbol}</b></td></tr>
<tr><td>Period:</td><td><b>{period} ({from_date} - {to_date})</b></td></tr>
{input_rows}
<tr><td>Total Net Profit:</td><td><b>{net_profit}</b></td></tr>
<tr><td>Equity Drawdown Maximal:</td><td><b>{drawdown_money} ({drawdown_pct}%)</b></td></tr>
<tr><td>Profit Factor:</td><td><b>{pf}</b></td></tr>
<tr><td>Total Trades:</td><td><b>{trades}</b></td></tr>
</table></body></html>""".format(
        expert=expert,
        symbol=symbol,
        period=period,
        from_date=from_date,
        to_date=to_date,
        input_rows="\n".join(input_rows),
        net_profit=net_profit,
        drawdown_money=drawdown_money,
        drawdown_pct=drawdown_pct,
        pf=pf,
        trades=trades,
    )


def _tester_ini(
    *,
    expert: str = r"QM\QM5_1_test",
    symbol: str = "USDJPY.DWX",
    period: str = "M30",
    model: str = "4",
    from_date: str = "2017.01.01",
    to_date: str = "2022.12.31",
    optimization: str = "0",
    setfile_name: str = "QM5_1_test_USDJPY.DWX_M30_backtest.set",
) -> str:
    return (
        "[Tester]\n"
        f"Expert={expert}\n"
        f"Symbol={symbol}\n"
        f"Period={period}\n"
        f"Model={model}\n"
        f"Optimization={optimization}\n"
        f"FromDate={from_date}\n"
        f"ToDate={to_date}\n"
        f"ExpertParameters={setfile_name}\n"
    )


def make_case(tmp_path: Path):
    ea_dir = tmp_path / "QM5_1_test"
    ea_dir.mkdir()
    mq5 = ea_dir / "QM5_1_test.mq5"
    ex5 = ea_dir / "QM5_1_test.ex5"
    spec = ea_dir / "SPEC.md"
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir()
    setfile = sets_dir / "QM5_1_test_USDJPY.DWX_M30_backtest.set"
    docs_dir = ea_dir / "docs"
    docs_dir.mkdir()
    card = docs_dir / "strategy_card.md"
    report_dir = tmp_path / "reports" / "QM5_1" / "20260713_050000"

    mq5.write_text("input int qm_ea_id = 1;\n", encoding="utf-8")
    ex5.write_bytes(b"compiled-ex5")
    spec.write_text("# Spec\n", encoding="utf-8")
    setfile.write_text("qm_ea_id=1\nRISK_FIXED=1000\nstrategy_period=14\n", encoding="utf-8")
    card.write_text("---\nea_id: QM5_1\ng0_status: APPROVED\n---\n", encoding="utf-8")

    base = time.time() - 120.0
    for path in (mq5, spec, setfile, card):
        os.utime(path, (base, base))
    os.utime(ex5, (base + 1.0, base + 1.0))

    reports = []
    logs = []
    for index in (1, 2):
        run_dir = report_dir / "raw" / f"run_{index:02d}"
        run_dir.mkdir(parents=True)
        report = run_dir / "report.htm"
        report.write_text(_native_report(), encoding="utf-16")
        tester_ini = run_dir / "tester.ini"
        tester_ini.write_text(_tester_ini(), encoding="utf-8")
        log = run_dir / "20260713.log"
        log.write_text("tester generating based on real ticks\n", encoding="utf-8")
        os.utime(tester_ini, (base + 10 + index, base + 10 + index))
        os.utime(log, (base + 12 + index, base + 12 + index))
        os.utime(report, (base + 13 + index, base + 13 + index))
        reports.append(report)
        logs.append(log)

    summary = {
        "timestamp_utc": _iso(base + 30.0),
        "result": "PASS",
        "ea_id": 1,
        "expert": r"QM\QM5_1_test",
        "symbol": "USDJPY.DWX",
        "period": "M30",
        "terminal": "T1",
        "model": 4,
        "requested_runs": 2,
        "deterministic": True,
        "model4_log_marker_detected": True,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "report_dir": str(report_dir),
        "runs": [
            {
                "run": "run_01",
                "status": "OK",
                "exit_code": 0,
                "real_ticks_marker": True,
                "total_trades": 201,
                "profit_factor": 1.31,
                "drawdown": 11990.0,
                "drawdown_raw": "11 990.00 (11.99%)",
                "net_profit": 5000.0,
                "report_canonical_path": str(reports[0]),
                "tester_log_path": str(logs[0]),
            },
            {
                "run": "run_02",
                "status": "OK",
                "exit_code": 0,
                "real_ticks_marker": True,
                "total_trades": 201,
                "profit_factor": 1.31,
                "drawdown": 11990.0,
                "drawdown_raw": "11 990.00 (11.99%)",
                "net_profit": 5000.0,
                "report_canonical_path": str(reports[1]),
                "tester_log_path": str(logs[1]),
            },
        ],
    }
    summary_path = report_dir / "summary.json"
    summary_path.write_text(json.dumps(summary), encoding="utf-8")
    os.utime(summary_path, (base + 30.0, base + 30.0))
    return summary_path, ea_dir, setfile, card


def make_q07_aggregate_case(tmp_path: Path):
    _summary_path, ea_dir, setfile, card = make_case(tmp_path)
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir(exist_ok=True)
    seeds = [42, 17, 99, 7, 2026]
    details = []
    generated = datetime.now(timezone.utc)
    for index, seed in enumerate(seeds):
        run_dir = tmp_path / f"seed_{seed}" / "raw" / "run_01"
        run_dir.mkdir(parents=True)
        report = run_dir / "report.htm"
        report.write_text(f"report-{seed}", encoding="utf-8")
        seed_set = sets_dir / f"QM5_1_test_USDJPY.DWX_M30_q06_stress_harsh_seed{seed}.set"
        seed_set.write_text(f"qm_rng_seed={seed}\n", encoding="utf-8")
        (run_dir / "tester.ini").write_text(
            "[Tester]\n"
            f"ExpertParameters={seed_set.name}\n",
            encoding="utf-8",
        )
        pf = 1.40 + index * 0.02
        trades = 90 + index
        child = {
            "timestamp_utc": (generated.replace(microsecond=0)).isoformat().replace("+00:00", "Z"),
            "result": "PASS",
            "ea_id": 1,
            "expert": r"QM\QM5_1_test",
            "symbol": "USDJPY.DWX",
            "period": "M30",
            "terminal": "T1",
            "model": 4,
            "runs": [{
                "status": "OK",
                "total_trades": trades,
                "profit_factor": pf,
                "drawdown": 1000.0 + index,
                "net_profit": 4000.0 + index,
                "report_canonical_path": str(report),
            }],
        }
        child_path = tmp_path / f"seed_{seed}" / "summary.json"
        child_path.write_text(json.dumps(child), encoding="utf-8")
        details.append({
            "seed": seed,
            "pf": pf,
            "trades": trades,
            "summary_path": str(child_path),
        })
    aggregate = {
        "generated_at_utc": generated.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "phase": "Q07",
        "verdict": "PASS",
        "ea_id": 1,
        "symbol": "USDJPY.DWX",
        "runner_symbol": "USDJPY.DWX",
        "seeds": seeds,
        "metrics": {"variance_pct": 10.0, "min_pf": 1.4},
        "per_seed_detail": details,
    }
    aggregate_path = tmp_path / "q07_aggregate.json"
    aggregate_path.write_text(json.dumps(aggregate), encoding="utf-8")
    return aggregate_path, ea_dir, setfile, card


def test_binding_passes_complete_deterministic_current_case(tmp_path: Path) -> None:
    args = make_case(tmp_path)

    result = binding.build_binding(*args)

    assert result["status"] == "BOUND_PASS"
    assert result["blockers"] == []
    assert result["phase"] == "Q02"
    assert result["deterministic"] is True
    assert result["run_contract"]["minimum_runs"] == 2
    assert result["metrics"]["trades"] == 201
    assert len(result["files"]["ex5"]["sha256"]) == 64


def test_binding_fails_stale_binary_and_metric_drift(tmp_path: Path) -> None:
    summary_path, ea_dir, setfile, card = make_case(tmp_path)
    payload = json.loads(summary_path.read_text(encoding="utf-8"))
    payload["timestamp_utc"] = "2020-01-01T00:00:00Z"
    payload["runs"][1]["profit_factor"] = 1.4
    summary_path.write_text(json.dumps(payload), encoding="utf-8")

    result = binding.build_binding(summary_path, ea_dir, setfile, card)

    assert result["status"] == "NO_GO"
    assert "summary_predates_binary" in result["blockers"]
    assert "run_metrics_not_identical" in result["blockers"]


@pytest.mark.parametrize("phase", ["Q05", "Q06", "Q08"])
def test_stress_single_run_binds_without_claiming_determinism(
    tmp_path: Path,
    phase: str,
) -> None:
    summary_path, ea_dir, setfile, card = make_case(tmp_path)
    payload = json.loads(summary_path.read_text(encoding="utf-8"))
    payload["runs"] = payload["runs"][:1]
    payload["deterministic"] = True
    summary_path.write_text(json.dumps(payload), encoding="utf-8")

    result = binding.build_binding(
        summary_path,
        ea_dir,
        setfile,
        card,
        phase=phase,
    )

    assert result["status"] == "BOUND_PASS"
    assert result["phase"] == phase
    assert result["deterministic"] == "not_applicable"
    assert result["source_summary_deterministic"] is True
    assert result["run_contract"]["minimum_runs"] == 1
    assert result["run_contract"]["observed_runs"] == 1
    assert result["run_contract"]["require_identical_metrics"] is False


def test_single_run_does_not_satisfy_default_q02_contract(tmp_path: Path) -> None:
    summary_path, ea_dir, setfile, card = make_case(tmp_path)
    payload = json.loads(summary_path.read_text(encoding="utf-8"))
    payload["runs"] = payload["runs"][:1]
    summary_path.write_text(json.dumps(payload), encoding="utf-8")

    result = binding.build_binding(summary_path, ea_dir, setfile, card)

    assert result["status"] == "NO_GO"
    assert "fewer_than_2_runs" in result["blockers"]


def test_q07_requires_full_five_run_cohort(tmp_path: Path) -> None:
    summary_path, ea_dir, setfile, card = make_case(tmp_path)

    result = binding.build_binding(
        summary_path,
        ea_dir,
        setfile,
        card,
        phase="Q07",
    )

    assert result["status"] == "NO_GO"
    assert "fewer_than_5_runs" in result["blockers"]


def test_q07_real_aggregate_binds_all_seed_evidence(tmp_path: Path) -> None:
    result = binding.build_binding(
        *make_q07_aggregate_case(tmp_path),
        phase="Q07",
    )

    assert result["status"] == "BOUND_PASS"
    assert result["blockers"] == []
    assert result["run_contract"]["observed_runs"] == 5
    assert result["cohort_metrics"]["variance_pct"] == 10.0
    assert len(result["reports"]) == 5
    assert len(result["seed_evidence"]) == 5
    assert all("tester_ini" in item and "setfile" in item for item in result["seed_evidence"])


def test_q07_real_aggregate_rejects_unproven_seed_setfile(tmp_path: Path) -> None:
    args = make_q07_aggregate_case(tmp_path)
    aggregate = json.loads(args[0].read_text(encoding="utf-8"))
    seed_path = Path(aggregate["per_seed_detail"][2]["summary_path"])
    child = json.loads(seed_path.read_text(encoding="utf-8"))
    tester_ini = Path(child["runs"][0]["report_canonical_path"]).parent / "tester.ini"
    tester_ini.write_text("[Tester]\nExpertParameters=generic_seed99.set\n", encoding="utf-8")

    result = binding.build_binding(*args, phase="Q07")

    assert result["status"] == "NO_GO"
    assert "q07_seed_99_setfile_not_proven" in result["blockers"]


def test_rejects_unknown_phase(tmp_path: Path) -> None:
    summary_path, ea_dir, setfile, card = make_case(tmp_path)

    try:
        binding.build_binding(
            summary_path,
            ea_dir,
            setfile,
            card,
            phase="Q99",
        )
    except ValueError as exc:
        assert "unsupported phase" in str(exc)
    else:
        raise AssertionError("unknown phase was accepted")
