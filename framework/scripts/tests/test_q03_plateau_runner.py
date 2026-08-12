"""Focused contract tests for q03_plateau_runner.py."""

from __future__ import annotations

import json
import math
import os
import time
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

import pytest

from framework.scripts import q03_plateau_runner as q03


@dataclass(frozen=True)
class BoundBundle:
    root: Path
    ea_dir: Path
    card: Path
    mq5: Path
    ex5: Path
    baseline: Path
    spec: Path
    runner: Path
    run_smoke: Path

    @property
    def spec_sha256(self) -> str:
        return q03.sha256_file(self.spec)


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


@pytest.fixture(autouse=True)
def _canonical_test_sandbox(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    repo = tmp_path.resolve()
    scripts = repo / "framework" / "scripts"
    scripts.mkdir(parents=True, exist_ok=True)
    runner = scripts / "q03_plateau_runner.py"
    run_smoke = scripts / "run_smoke.ps1"
    runner.write_text("# test-bound q03 runner\n", encoding="utf-8")
    run_smoke.write_text("# test-bound run_smoke\n", encoding="utf-8")
    monkeypatch.setattr(q03, "CANONICAL_REPO_ROOT", repo)
    monkeypatch.setattr(q03, "CANONICAL_OUT_ROOT", repo / "reports")
    monkeypatch.setattr(q03, "TERMINAL_FACTORY_ROOT", repo / "mt5")
    monkeypatch.setattr(q03, "RUNNER_PATH", runner)


def _make_bundle(tmp_path: Path, *, axis_values: list[int] | None = None) -> BoundBundle:
    root = tmp_path.resolve()
    ea_dir = root / "framework" / "EAs" / "QM5_10163_q03-fixture"
    ea_dir.mkdir(parents=True)
    mq5 = ea_dir / f"{ea_dir.name}.mq5"
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    card = root / "strategy_card.md"
    baseline = root / "baseline.set"
    spec = root / "grid_spec.json"

    mq5.write_text(
        "\n".join(
            [
                "#property strict",
                "input int qm_ea_id = 10163;",
                "input int strategy_atr_period = 14;",
                "input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_H1;",
                "input bool strategy_enabled = true;",
                "input double strategy_threshold = 1.5;",
                "",
            ]
        ),
        encoding="utf-8",
    )
    ex5.write_bytes(b"compiled-q03-fixture")
    card.write_text("ea_id: 10163\ng0_status: APPROVED\n", encoding="utf-8")
    baseline.write_text(
        "\n".join(
            [
                "; ea_id: 10163",
                "; symbol: USDJPY.DWX",
                "; timeframe: H1",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "strategy_atr_period=14",
                "strategy_signal_tf=PERIOD_H1",
                "strategy_enabled=true",
                "strategy_threshold=1.5",
                "",
            ]
        ),
        encoding="utf-8",
    )
    now = time.time()
    os.utime(mq5, (now - 10, now - 10))
    os.utime(ex5, (now, now))

    values = axis_values or list(range(1, 31))
    raw = {
        "schema_version": 1,
        "phase": "Q03",
        "preregistered_at_utc": "2026-01-01T00:00:00Z",
        "ea_id": 10163,
        "ea_dir_name": ea_dir.name,
        "symbol": "USDJPY.DWX",
        "period": "H1",
        "is_window": {"from": "2017.01.01", "to": "2022.12.31"},
        "model": 4,
        "identity": {
            "card": {"path": str(card), "sha256": q03.sha256_file(card)},
            "mq5": {"path": str(mq5), "sha256": q03.sha256_file(mq5)},
            "ex5": {"path": str(ex5), "sha256": q03.sha256_file(ex5)},
            "baseline_setfile": {
                "path": str(baseline),
                "sha256": q03.sha256_file(baseline),
            },
        },
        "axis": {
            "name": "strategy_atr_period",
            "value_type": "int",
            "active": True,
            "values": values,
        },
        "strategy_parameter_names": [
            "strategy_atr_period",
            "strategy_signal_tf",
            "strategy_enabled",
            "strategy_threshold",
        ],
        "locked_parameters": {
            "strategy_signal_tf": "PERIOD_H1",
            "strategy_enabled": True,
            "strategy_threshold": 1.5,
        },
        "profitability": {
            "profit_factor_strictly_greater_than": 1.0,
            "minimum_fraction": 0.5,
            "minimum_trades": 20,
            "maximum_drawdown_money": None,
        },
        "plateau": {
            "minimum_contiguous_width": 3,
            "run_selection": "widest_then_lower_start",
            "cell_selection": "median",
            "even_median": "lower",
        },
        "run_contract": {"runs_per_cell": 2},
    }
    _write_json(spec, raw)
    return BoundBundle(
        root,
        ea_dir,
        card,
        mq5,
        ex5,
        baseline,
        spec,
        root / "framework" / "scripts" / "q03_plateau_runner.py",
        root / "framework" / "scripts" / "run_smoke.ps1",
    )


def _load(bundle: BoundBundle) -> q03.GridContract:
    return q03.load_grid_contract(bundle.spec, bundle.spec_sha256)


def _environment(bundle: BoundBundle, contract: q03.GridContract) -> dict[str, object]:
    return q03.validate_bound_environment(
        contract,
        repo_root=bundle.root,
        ea_dir=bundle.ea_dir,
        card_path=bundle.card,
        baseline_setfile=bundle.baseline,
    )


def _cell(contract: q03.GridContract, index: int, *, profitable: bool = True) -> q03.CellEvidence:
    return q03.CellEvidence(
        cell_id=contract.cell_ids[index],
        index=index,
        axis_value=contract.axis.values[index],
        metrics=q03.CellMetrics(
            profit_factor=1.25 if profitable else 1.0,
            trades=25,
            drawdown_money=100.0,
        ),
        setfile={"path": f"cell_{index:03d}.set", "sha256": f"set-{index}"},
        deployed_setfile={"path": f"deployed_{index:03d}.set", "sha256": f"set-{index}"},
        summary={"path": f"cell_{index:03d}.json", "sha256": f"summary-{index}"},
    )


@dataclass
class CellFiles:
    cell_root: Path
    setfile: Path
    deployed: Path
    summary: Path
    reports: list[Path]
    inis: list[Path]
    logs: list[Path]
    started_at: float
    summary_data: dict[str, Any]


def _make_valid_cell_files(
    tmp_path: Path,
    bundle: BoundBundle,
    contract: q03.GridContract,
) -> CellFiles:
    started_at = time.time() - 2
    setfile = tmp_path / "cell_sets" / q03.cell_setfile_name(contract, "cell_000")
    q03.materialize_setfile(bundle.baseline, setfile, q03.cell_overrides(contract, 0))
    deployed = (
        q03.TERMINAL_FACTORY_ROOT
        / "T1"
        / "MQL5"
        / "Profiles"
        / "Tester"
        / setfile.name
    )
    deployed.parent.mkdir(parents=True, exist_ok=True)
    deployed.write_bytes(setfile.read_bytes())

    cell_root = tmp_path / "cell_evidence"
    reports: list[Path] = []
    inis: list[Path] = []
    logs: list[Path] = []
    runs: list[dict[str, Any]] = []
    expert = f"QM\\{bundle.ea_dir.name}"
    report_html = "\n".join(
        [
            "<html><body><table>",
            f"<tr><td>Expert:</td><td><b>{expert}</b></td></tr>",
            "<tr><td>Symbol:</td><td><b>USDJPY.DWX</b></td></tr>",
            "<tr><td>Period:</td><td><b>H1 (2017.01.01 - 2022.12.31)</b></td></tr>",
            "<tr><td>Bars:</td><td><b>1000</b></td></tr>",
            "<tr><td>Profit Factor:</td><td><b>1.25</b></td></tr>",
            "<tr><td>Total Trades:</td><td><b>25</b></td></tr>",
            "<tr><td>Equity Drawdown Maximal:</td><td><b>100.00 (1.00%)</b></td></tr>",
            "</table></body></html>",
        ]
    )
    for run_index in range(1, contract.runs_per_cell + 1):
        run_dir = cell_root / f"run_{run_index:02d}"
        run_dir.mkdir(parents=True, exist_ok=True)
        report = run_dir / "report.htm"
        ini = run_dir / "tester.ini"
        log = run_dir / "tester.log"
        report.write_text(report_html, encoding="utf-8")
        ini.write_text(
            "\n".join(
                [
                    "[Tester]",
                    f"Expert={expert}",
                    "Symbol=USDJPY.DWX",
                    "Period=H1",
                    "Model=4",
                    "FromDate=2017.01.01",
                    "ToDate=2022.12.31",
                    f"ExpertParameters={setfile.name}",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        log.write_text("generating based on real ticks\n", encoding="utf-8")
        reports.append(report)
        inis.append(ini)
        logs.append(log)
        runs.append(
            {
                "status": "OK",
                "exit_code": 0,
                "real_ticks_marker": True,
                "profit_factor": 1.25,
                "drawdown": 100.0,
                "total_trades": 25,
                "report_canonical_path": str(report),
                "tester_log_path": str(log),
            }
        )
    summary_data = {
        "result": "PASS",
        "reason_classes": ["OK"],
        "ea_id": contract.ea_id,
        "expert": expert,
        "symbol": contract.symbol,
        "period": contract.period,
        "terminal": "T1",
        "model": 4,
        "deterministic": True,
        "model4_log_marker_detected": True,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "requested_runs": contract.runs_per_cell,
        "runs": runs,
    }
    summary = cell_root / "summary.json"
    _write_json(summary, summary_data)
    return CellFiles(
        cell_root,
        setfile,
        deployed,
        summary,
        reports,
        inis,
        logs,
        started_at,
        summary_data,
    )


def _parse_cell(
    files: CellFiles,
    bundle: BoundBundle,
    contract: q03.GridContract,
    *,
    expected_set_sha256: str | None = None,
) -> q03.CellEvidence:
    return q03.parse_cell_summary(
        files.summary,
        contract=contract,
        cell_id="cell_000",
        index=0,
        axis_value=contract.axis.values[0],
        expert=f"QM\\{bundle.ea_dir.name}",
        terminal="T1",
        materialized_setfile=files.setfile,
        deployed_setfile=files.deployed,
        expected_set_sha256=expected_set_sha256 or q03.sha256_file(files.setfile),
        cell_root=files.cell_root,
        invocation_started_at=files.started_at,
    )


def test_valid_grid_spec_and_bound_environment(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)

    environment = _environment(bundle, contract)

    assert contract.model == 4
    assert contract.from_date == "2017.01.01"
    assert contract.to_date == "2022.12.31"
    assert len(contract.cell_ids) == 30
    assert environment["expert"] == f"QM\\{bundle.ea_dir.name}"


def test_q03_is_window_is_fixed(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    raw = json.loads(bundle.spec.read_text(encoding="utf-8"))
    raw["is_window"] = {"from": "2018.01.01", "to": "2022.12.31"}
    _write_json(bundle.spec, raw)

    with pytest.raises(q03.ContractError, match="must be exactly"):
        _load(bundle)


def test_future_preregistration_timestamp_is_rejected(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    raw = json.loads(bundle.spec.read_text(encoding="utf-8"))
    raw["preregistered_at_utc"] = "2999-01-01T00:00:00Z"
    _write_json(bundle.spec, raw)

    with pytest.raises(q03.ContractError, match="must not be in the future"):
        _load(bundle)


def test_execution_requires_canonical_repo_and_ea_directory(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    shadow_repo = tmp_path / "shadow_repo"
    shadow_repo.mkdir()
    with pytest.raises(q03.ContractError, match="repo root must be canonical"):
        q03.validate_bound_environment(
            contract,
            repo_root=shadow_repo,
            ea_dir=bundle.ea_dir,
            card_path=bundle.card,
            baseline_setfile=bundle.baseline,
        )

    shadow_ea = tmp_path / bundle.ea_dir.name
    shadow_ea.mkdir()
    with pytest.raises(q03.ContractError, match="EA directory must be canonical"):
        q03.validate_bound_environment(
            contract,
            repo_root=bundle.root,
            ea_dir=shadow_ea,
            card_path=bundle.card,
            baseline_setfile=bundle.baseline,
        )


def test_unprefixed_mq5_input_requires_preregistered_inventory(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    bundle.mq5.write_text(
        bundle.mq5.read_text(encoding="utf-8") + "input int CorePeriod = 9;\n",
        encoding="utf-8",
    )
    now = time.time()
    os.utime(bundle.mq5, (now, now))
    os.utime(bundle.ex5, (now + 1, now + 1))
    raw = json.loads(bundle.spec.read_text(encoding="utf-8"))
    raw["identity"]["mq5"]["sha256"] = q03.sha256_file(bundle.mq5)
    _write_json(bundle.spec, raw)
    contract = _load(bundle)

    with pytest.raises(q03.ContractError, match="inventory every non-framework"):
        _environment(bundle, contract)


def test_all_strategy_inventory_supports_integer_hhmm_inputs(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    bundle.mq5.write_text(
        "\n".join(
            [
                "#property strict",
                "input int qm_ea_id = 10163;",
                "input int strategy_entry_jst_hhmm = 930;",
                "input int strategy_exit_jst_hhmm = 1500;",
                "input bool strategy_holiday_volume_proxy_enabled = true;",
                "input int strategy_risk_stop_pips = 30;",
                "input int strategy_max_spread_points = 25;",
                "",
            ]
        ),
        encoding="utf-8",
    )
    bundle.baseline.write_text(
        "\n".join(
            [
                "; ea_id: 10163",
                "; symbol: USDJPY.DWX",
                "; timeframe: H1",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "strategy_entry_jst_hhmm=930",
                "strategy_exit_jst_hhmm=1500",
                "strategy_holiday_volume_proxy_enabled=true",
                "strategy_risk_stop_pips=30",
                "strategy_max_spread_points=25",
                "",
            ]
        ),
        encoding="utf-8",
    )
    now = time.time()
    os.utime(bundle.mq5, (now, now))
    os.utime(bundle.ex5, (now + 1, now + 1))
    raw = json.loads(bundle.spec.read_text(encoding="utf-8"))
    inventory = [
        "strategy_entry_jst_hhmm",
        "strategy_exit_jst_hhmm",
        "strategy_holiday_volume_proxy_enabled",
        "strategy_risk_stop_pips",
        "strategy_max_spread_points",
    ]
    raw["strategy_parameter_names"] = inventory
    raw["axis"] = {
        "name": "strategy_entry_jst_hhmm",
        "value_type": "int",
        "active": True,
        "values": [900, 930, 1000, 1030, 1100, 1130, 1200],
    }
    raw["locked_parameters"] = {
        "strategy_exit_jst_hhmm": 1500,
        "strategy_holiday_volume_proxy_enabled": True,
        "strategy_risk_stop_pips": 30,
        "strategy_max_spread_points": 25,
    }
    raw["identity"]["mq5"]["sha256"] = q03.sha256_file(bundle.mq5)
    raw["identity"]["baseline_setfile"]["sha256"] = q03.sha256_file(bundle.baseline)
    _write_json(bundle.spec, raw)

    contract = _load(bundle)
    environment = _environment(bundle, contract)

    assert list(contract.strategy_parameter_names) == inventory
    assert environment["strategy_inputs"] == inventory
    assert contract.axis.values[1] == 930


def test_optimizer_style_values_use_scalar_prefix(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    text = bundle.baseline.read_text(encoding="utf-8")
    text = text.replace("RISK_FIXED=1000", "RISK_FIXED=1000||1000||100||2000||N")
    text = text.replace("RISK_PERCENT=0", "RISK_PERCENT=0||0||0.1||1||N")
    text = text.replace("strategy_atr_period=14", "strategy_atr_period=14||7||1||30||Y")
    text = text.replace("strategy_threshold=1.5", "strategy_threshold=1.5||1||0.1||2||N")
    bundle.baseline.write_text(text, encoding="utf-8")
    raw = json.loads(bundle.spec.read_text(encoding="utf-8"))
    raw["identity"]["baseline_setfile"]["sha256"] = q03.sha256_file(bundle.baseline)
    _write_json(bundle.spec, raw)

    _environment(bundle, _load(bundle))
    assert q03.setfile_scalar("14||7||1||30||Y") == "14"


@pytest.mark.parametrize(
    ("mutate", "message"),
    [
        (lambda raw: raw["axis"]["values"].__setitem__(1, 1), "strictly increasing"),
        (lambda raw: raw.__setitem__("model", 2), "model must be exactly 4"),
        (lambda raw: raw.__setitem__("unexpected", True), "unknown keys"),
        (lambda raw: raw["axis"].__setitem__("active", False), "active must be true"),
        (lambda raw: raw["axis"].__setitem__("values", list(range(6))), "7-100 cells"),
    ],
)
def test_grid_spec_rejects_invalid_contract(
    tmp_path: Path, mutate: object, message: str
) -> None:
    bundle = _make_bundle(tmp_path)
    raw = json.loads(bundle.spec.read_text(encoding="utf-8"))
    mutate(raw)  # type: ignore[operator]
    _write_json(bundle.spec, raw)

    with pytest.raises(q03.ContractError, match=message):
        _load(bundle)


def test_materialization_replaces_duplicate_keys_exactly_once(tmp_path: Path) -> None:
    source = tmp_path / "source.set"
    target = tmp_path / "generated" / "cell.set"
    source.write_text(
        "\n".join(
            [
                "; fixture",
                "strategy_atr_period=7||7||1||30||Y",
                "RISK_FIXED=1000",
                "strategy_threshold=0.5",
                "strategy_atr_period=22",
                "strategy_threshold=2.0||0.5||0.1||2.0||N",
                "strategy_enabled=false",
                "",
            ]
        ),
        encoding="utf-8",
    )

    q03.materialize_setfile(
        source,
        target,
        {"strategy_atr_period": 14, "strategy_threshold": 1.5, "strategy_enabled": True},
    )

    assignments = q03.parse_setfile_assignments(target)
    assert assignments["strategy_atr_period"] == ["14"]
    assert assignments["strategy_threshold"] == ["1.5"]
    assert assignments["strategy_enabled"] == ["true"]
    assert assignments["RISK_FIXED"] == ["1000"]


def test_materialization_is_replace_only(tmp_path: Path) -> None:
    source = tmp_path / "source.set"
    source.write_text("strategy_atr_period=14\n", encoding="utf-8")

    with pytest.raises(q03.ContractError, match="replace-only"):
        q03.materialize_setfile(
            source,
            tmp_path / "target.set",
            {"strategy_atr_period": 15, "strategy_missing": 1},
        )
    assert not (tmp_path / "target.set").exists()


def test_baseline_requires_each_strategy_input_exactly_once(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    duplicate = bundle.baseline.read_text(encoding="utf-8") + "strategy_atr_period=15\n"
    bundle.baseline.write_text(duplicate, encoding="utf-8")
    raw = json.loads(bundle.spec.read_text(encoding="utf-8"))
    raw["identity"]["baseline_setfile"]["sha256"] = q03.sha256_file(bundle.baseline)
    _write_json(bundle.spec, raw)
    contract = _load(bundle)

    with pytest.raises(q03.ContractError, match="exactly once"):
        _environment(bundle, contract)


def test_grid_evaluation_rejects_one_missing_cell(tmp_path: Path) -> None:
    contract = _load(_make_bundle(tmp_path))
    incomplete = [_cell(contract, index) for index in range(len(contract.cell_ids) - 1)]

    with pytest.raises(q03.ContractError, match=r"missing=.*cell_029"):
        q03.evaluate_grid(contract, incomplete)


def test_contiguous_runs_do_not_bridge_unprofitable_cells() -> None:
    runs = q03.profitable_runs([False, True, True, False, True, True, True, False])

    assert runs == ((1, 2), (4, 6))
    assert q03.select_plateau_run(
        runs, minimum_width=3, run_selection="widest_then_lower_start"
    ) == (4, 6)
    with pytest.raises(q03.GateFailure, match="reaches width 4"):
        q03.select_plateau_run(
            runs, minimum_width=4, run_selection="widest_then_lower_start"
        )


def test_preregistered_tie_break_and_even_median_selection() -> None:
    tied = ((2, 7), (12, 17))

    assert q03.select_plateau_run(
        tied, minimum_width=3, run_selection="widest_then_lower_start"
    ) == (2, 7)
    assert q03.select_plateau_run(
        tied, minimum_width=3, run_selection="widest_then_higher_start"
    ) == (12, 17)
    assert q03.median_index((2, 7), "lower") == 4
    assert q03.median_index((2, 7), "upper") == 5


def test_evaluation_selects_median_of_widest_profitable_run(tmp_path: Path) -> None:
    contract = _load(_make_bundle(tmp_path))
    profitable = set(range(0, 3)) | set(range(5, 14)) | set(range(17, 23))
    evidence = [
        _cell(contract, index, profitable=index in profitable)
        for index in range(len(contract.cell_ids))
    ]

    evaluation = q03.evaluate_grid(contract, evidence)

    assert evaluation.profitable_count == 18
    assert evaluation.selected_run == (5, 13)
    assert evaluation.selected_index == 9
    assert evaluation.selected.axis_value == 10


def test_profitable_fraction_threshold_has_no_epsilon(tmp_path: Path) -> None:
    contract = _load(_make_bundle(tmp_path, axis_values=list(range(1, 8))))
    exact_fraction = 4 / 7
    stricter_rule = replace(
        contract.profitability,
        minimum_fraction=math.nextafter(exact_fraction, 1.0),
    )
    contract = replace(contract, profitability=stricter_rule)
    evidence = [
        _cell(contract, index, profitable=index < 4)
        for index in range(len(contract.cell_ids))
    ]

    with pytest.raises(q03.GateFailure, match="below required"):
        q03.evaluate_grid(contract, evidence)


def test_hash_provenance_is_carried_into_plateau_payload(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    environment = _environment(bundle, contract)
    evaluation = q03.evaluate_grid(
        contract, [_cell(contract, index) for index in range(len(contract.cell_ids))]
    )
    selected_set = tmp_path / "plateau_selected.set"
    q03.materialize_setfile(
        bundle.baseline,
        selected_set,
        q03.cell_overrides(contract, evaluation.selected_index),
    )
    claim = tmp_path / "q03_claim.json"
    claim.write_text("{}\n", encoding="utf-8")

    payload = q03.build_plateau_payload(
        contract,
        evaluation,
        environment=environment,
        terminal="T3",
        terminal_allowlist=("T2", "T3"),
        selected_set_record=q03.file_record(selected_set),
        claim_record=q03.file_record(claim),
    )

    assert payload["grid_spec"]["sha256"] == bundle.spec_sha256
    assert payload["identity"]["mq5"]["sha256"] == q03.sha256_file(bundle.mq5)
    assert payload["identity"]["ex5"]["sha256"] == q03.sha256_file(bundle.ex5)
    assert payload["selected_set"]["sha256"] == q03.sha256_file(selected_set)
    assert payload["evaluation"]["selected_cell_id"] == "cell_014"
    assert payload["params"] == {"strategy_atr_period": 15}


def test_hash_mismatch_fails_before_evidence_execution(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    bundle.card.write_text("g0_status: APPROVED\nchanged: true\n", encoding="utf-8")

    with pytest.raises(q03.ContractError, match="card hash mismatch"):
        _environment(bundle, contract)
    with pytest.raises(q03.ContractError, match="grid spec hash mismatch"):
        q03.load_grid_contract(bundle.spec, "0" * 64)


def test_nondeterministic_summary_is_invalid(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    cell_root = tmp_path / "cell"
    cell_root.mkdir()
    summary = cell_root / "summary.json"
    summary.write_text(
        json.dumps(
            {
                "result": "PASS",
                "reason_classes": ["OK"],
                "ea_id": contract.ea_id,
                "expert": f"QM\\{bundle.ea_dir.name}",
                "symbol": contract.symbol,
                "period": contract.period,
                "terminal": "T1",
                "model": 4,
                "deterministic": False,
            }
        ),
        encoding="utf-8",
    )

    with pytest.raises(q03.ContractError, match="nondeterministic cell summary"):
        q03.parse_cell_summary(
            summary,
            contract=contract,
            cell_id="cell_000",
            index=0,
            axis_value=contract.axis.values[0],
            expert=f"QM\\{bundle.ea_dir.name}",
            terminal="T1",
            materialized_setfile=bundle.baseline,
            deployed_setfile=bundle.baseline,
            expected_set_sha256=q03.sha256_file(bundle.baseline),
            cell_root=cell_root,
            invocation_started_at=time.time() - 1,
        )


def test_valid_cell_summary_reconciles_native_reports(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    files = _make_valid_cell_files(tmp_path, bundle, contract)

    evidence = _parse_cell(files, bundle, contract)

    assert evidence.metrics == q03.CellMetrics(1.25, 25, 100.0)
    assert evidence.deployed_setfile["sha256"] == evidence.setfile["sha256"]


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("result", "FAIL", "result must be PASS"),
        ("reason_classes", ["OK", "EXTRA"], "reason_classes must be exactly"),
    ],
)
def test_summary_requires_explicit_pass_and_only_ok_reason(
    tmp_path: Path, field: str, value: object, message: str
) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    files = _make_valid_cell_files(tmp_path, bundle, contract)
    files.summary_data[field] = value
    _write_json(files.summary, files.summary_data)

    with pytest.raises(q03.ContractError, match=message):
        _parse_cell(files, bundle, contract)


@pytest.mark.parametrize("artifact", ["summary", "report", "log"])
def test_cell_evidence_cannot_escape_current_cell_root(
    tmp_path: Path, artifact: str
) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    files = _make_valid_cell_files(tmp_path, bundle, contract)
    outside = tmp_path / "outside"
    outside.mkdir()
    if artifact == "summary":
        escaped = outside / "summary.json"
        escaped.write_bytes(files.summary.read_bytes())
        files.summary = escaped
    elif artifact == "report":
        escaped = outside / "report.htm"
        escaped.write_bytes(files.reports[0].read_bytes())
        files.summary_data["runs"][0]["report_canonical_path"] = str(escaped)
        _write_json(files.summary, files.summary_data)
    else:
        escaped = outside / "tester.log"
        escaped.write_bytes(files.logs[0].read_bytes())
        files.summary_data["runs"][0]["tester_log_path"] = str(escaped)
        _write_json(files.summary, files.summary_data)

    with pytest.raises(q03.ContractError, match="escapes current cell root"):
        _parse_cell(files, bundle, contract)


@pytest.mark.parametrize("artifact", ["summary", "report", "ini", "log"])
def test_every_cell_artifact_must_be_fresh_after_invocation(
    tmp_path: Path, artifact: str
) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    files = _make_valid_cell_files(tmp_path, bundle, contract)
    path = {
        "summary": files.summary,
        "report": files.reports[0],
        "ini": files.inis[0],
        "log": files.logs[0],
    }[artifact]
    stale = files.started_at - 10
    os.utime(path, (stale, stale))

    with pytest.raises(q03.ContractError, match="predates current cell invocation"):
        _parse_cell(files, bundle, contract)


def test_summary_metrics_must_match_native_report(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    files = _make_valid_cell_files(tmp_path, bundle, contract)
    files.summary_data["runs"][0]["profit_factor"] = 9.0
    _write_json(files.summary, files.summary_data)

    with pytest.raises(q03.ContractError, match="summary/native report metrics mismatch"):
        _parse_cell(files, bundle, contract)


def test_native_report_identity_must_match_cell(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    files = _make_valid_cell_files(tmp_path, bundle, contract)
    text = files.reports[0].read_text(encoding="utf-8").replace(
        "USDJPY.DWX", "EURUSD.DWX"
    )
    files.reports[0].write_text(text, encoding="utf-8")

    with pytest.raises(q03.ContractError, match="native report identity mismatch"):
        _parse_cell(files, bundle, contract)


def test_materialized_set_hash_is_immutable_across_invocation(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    files = _make_valid_cell_files(tmp_path, bundle, contract)
    prelaunch_hash = q03.sha256_file(files.setfile)
    files.setfile.write_text(
        files.setfile.read_text(encoding="utf-8") + "; changed\n",
        encoding="utf-8",
    )

    with pytest.raises(q03.ContractError, match="changed during invocation"):
        _parse_cell(
            files,
            bundle,
            contract,
            expected_set_sha256=prelaunch_hash,
        )


def test_tester_deployed_set_copy_must_match_hash_and_path(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    files = _make_valid_cell_files(tmp_path, bundle, contract)
    files.deployed.write_text("tampered\n", encoding="utf-8")

    with pytest.raises(q03.ContractError, match="tester-deployed setfile hash mismatch"):
        _parse_cell(files, bundle, contract)


def test_cell_set_basename_binds_ea_spec_cell_and_is_unique(tmp_path: Path) -> None:
    contract = _load(_make_bundle(tmp_path))
    first = q03.cell_setfile_name(contract, "cell_007")
    second = q03.cell_setfile_name(contract, "cell_007")

    assert first != second
    assert f"QM5_{contract.ea_id}_Q03_{contract.spec_sha256[:20]}_cell_007_" in first


def test_plan_mode_validates_but_writes_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    bundle = _make_bundle(tmp_path)
    out_root = q03.CANONICAL_OUT_ROOT

    result = q03.main(
        [
            "--grid-spec",
            str(bundle.spec),
            "--grid-spec-sha256",
            bundle.spec_sha256,
            "--repo-root",
            str(bundle.root),
            "--ea-dir",
            str(bundle.ea_dir),
            "--card",
            str(bundle.card),
            "--baseline-setfile",
            str(bundle.baseline),
            "--terminal",
            "T1",
            "--terminal-allowlist",
            "T1,T4",
            "--out-root",
            str(out_root),
            "--plan",
        ]
    )

    plan = json.loads(capsys.readouterr().out)
    assert result == 0
    assert plan["writes_performed"] is False
    assert plan["mt5_launched"] is False
    assert plan["would_write"]["selected_set"].endswith("plateau_median.set")
    assert not out_root.exists()


def test_terminal_allowlist_is_explicit_and_t1_to_t5_only() -> None:
    assert q03.validate_terminal_contract("t3", "T1,T3") == ("T3", ("T1", "T3"))
    with pytest.raises(q03.ContractError, match="unsupported terminals"):
        q03.validate_terminal_contract("T1", "T1,T6")
    with pytest.raises(q03.ContractError, match="not in the explicit caller allowlist"):
        q03.validate_terminal_contract("T2", "T1,T3")


def _claim_out_dir(contract: q03.GridContract) -> Path:
    return (
        q03.CANONICAL_OUT_ROOT
        / f"QM5_{contract.ea_id}"
        / "Q03"
        / contract.symbol.replace(".", "_")
    )


def test_immutable_claim_is_exclusive_and_binds_execution_logic(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    environment = _environment(bundle, contract)
    out_dir = _claim_out_dir(contract)

    with q03.prospective_execution_claim(
        contract, out_dir=out_dir, environment=environment
    ) as claim_record:
        claim = json.loads(Path(claim_record["path"]).read_text(encoding="utf-8"))
        assert claim["spec_sha256"] == contract.spec_sha256
        assert claim["execution_logic"]["q03_plateau_runner"]["sha256"] == q03.sha256_file(bundle.runner)
        assert claim["execution_logic"]["run_smoke"]["sha256"] == q03.sha256_file(bundle.run_smoke)
        with pytest.raises(q03.ContractError, match="already held"):
            with q03.prospective_execution_claim(
                contract, out_dir=out_dir, environment=environment
            ):
                pass

    assert (out_dir / q03.CLAIM_FILENAME).is_file()
    assert not (out_dir / q03.LOCK_FILENAME).exists()


def test_claim_survives_gate_failure_for_same_spec_retry(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    environment = _environment(bundle, contract)
    out_dir = _claim_out_dir(contract)

    with pytest.raises(q03.GateFailure):
        with q03.prospective_execution_claim(
            contract, out_dir=out_dir, environment=environment
        ):
            raise q03.GateFailure("preregistered gate failed")

    assert (out_dir / q03.CLAIM_FILENAME).is_file()
    assert not (out_dir / q03.LOCK_FILENAME).exists()


def test_same_spec_retry_recovers_only_uncommitted_partials(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    environment = _environment(bundle, contract)
    out_dir = _claim_out_dir(contract)
    with q03.prospective_execution_claim(
        contract, out_dir=out_dir, environment=environment
    ):
        pass
    median = out_dir / "plateau_median.set"
    sidecar = out_dir / "plateau_pick.json.sha256"
    median.write_text("partial\n", encoding="utf-8")
    sidecar.write_text("partial\n", encoding="utf-8")

    with q03.prospective_execution_claim(
        contract, out_dir=out_dir, environment=environment
    ):
        assert not median.exists()
        assert not sidecar.exists()


def test_different_spec_cannot_reuse_existing_claim(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    original = _load(bundle)
    environment = _environment(bundle, original)
    out_dir = _claim_out_dir(original)
    with q03.prospective_execution_claim(
        original, out_dir=out_dir, environment=environment
    ):
        pass
    raw = json.loads(bundle.spec.read_text(encoding="utf-8"))
    raw["axis"]["values"][-1] = 31
    _write_json(bundle.spec, raw)
    changed = _load(bundle)
    changed_environment = _environment(bundle, changed)

    with pytest.raises(q03.ContractError, match="immutable Q03 claim mismatch"):
        with q03.prospective_execution_claim(
            changed, out_dir=out_dir, environment=changed_environment
        ):
            pass


def test_unclaimed_partial_is_not_silently_recovered(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    environment = _environment(bundle, contract)
    out_dir = _claim_out_dir(contract)
    out_dir.mkdir(parents=True)
    (out_dir / "plateau_median.set").write_text("unknown partial\n", encoding="utf-8")

    with pytest.raises(q03.ContractError, match="unclaimed Q03 publication partials"):
        with q03.prospective_execution_claim(
            contract, out_dir=out_dir, environment=environment
        ):
            pass


def test_dead_same_spec_lock_can_be_recovered_without_commit(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    environment = _environment(bundle, contract)
    out_dir = _claim_out_dir(contract)
    out_dir.mkdir(parents=True)
    _write_json(
        out_dir / q03.LOCK_FILENAME,
        {
            "schema_version": 1,
            "phase": "Q03",
            "spec_sha256": contract.spec_sha256,
            "pid": 999999,
            "hostname": q03.socket.gethostname(),
            "token": "stale",
            "created_at_utc": "2026-01-01T00:00:00Z",
        },
    )
    monkeypatch.setattr(q03, "_pid_is_alive", lambda _pid: False)

    with q03.prospective_execution_claim(
        contract, out_dir=out_dir, environment=environment
    ):
        assert (out_dir / q03.CLAIM_FILENAME).is_file()


def test_claim_rejects_preregistration_after_claim_timestamp(tmp_path: Path) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    environment = _environment(bundle, contract)
    out_dir = _claim_out_dir(contract)
    out_dir.mkdir(parents=True)
    invalid_claim = q03._claim_payload(
        contract,
        out_dir=out_dir,
        environment=environment,
        claimed_at="2025-01-01T00:00:00Z",
    )
    q03._write_json_exclusive(out_dir / q03.CLAIM_FILENAME, invalid_claim)

    with pytest.raises(q03.ContractError, match="after its immutable claim"):
        with q03.prospective_execution_claim(
            contract, out_dir=out_dir, environment=environment
        ):
            pass


@pytest.mark.parametrize("logic_file", ["runner", "run_smoke"])
def test_execute_rejects_execution_logic_changed_after_claim(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    logic_file: str,
) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)
    changed = False

    def fake_run_cell(**kwargs: object) -> q03.CellEvidence:
        nonlocal changed
        index = kwargs["index"]
        assert isinstance(index, int)
        if not changed:
            path = getattr(bundle, logic_file)
            path.write_text(path.read_text(encoding="utf-8") + "# changed\n", encoding="utf-8")
            changed = True
        return _cell(contract, index)

    monkeypatch.setattr(q03, "run_cell", fake_run_cell)

    with pytest.raises(q03.ContractError, match="runner or run_smoke changed"):
        q03.execute(
            contract,
            repo_root=bundle.root,
            ea_dir=bundle.ea_dir,
            card_path=bundle.card,
            baseline_setfile=bundle.baseline,
            terminal="T1",
            terminal_allowlist=("T1",),
            out_root=q03.CANONICAL_OUT_ROOT,
            timeout_sec=60,
        )
    assert (_claim_out_dir(contract) / q03.CLAIM_FILENAME).is_file()
    assert not (_claim_out_dir(contract) / "plateau_pick.json").exists()


def test_execute_publishes_pick_and_plateau_median_without_mt5(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    bundle = _make_bundle(tmp_path)
    contract = _load(bundle)

    def fake_run_cell(**kwargs: object) -> q03.CellEvidence:
        active_contract = kwargs["contract"]
        index = kwargs["index"]
        run_dir = kwargs["run_dir"]
        environment = kwargs["environment"]
        assert isinstance(active_contract, q03.GridContract)
        assert isinstance(index, int)
        assert isinstance(run_dir, Path)
        assert isinstance(environment, dict)
        cell_id = active_contract.cell_ids[index]
        value = active_contract.axis.values[index]
        setfile = run_dir / "setfiles" / f"{cell_id}_{value}.set"
        q03.materialize_setfile(
            Path(environment["files"]["baseline_setfile"]["path"]),
            setfile,
            q03.cell_overrides(active_contract, index),
        )
        deployed = (
            q03.TERMINAL_FACTORY_ROOT
            / "T1"
            / "MQL5"
            / "Profiles"
            / "Tester"
            / setfile.name
        )
        deployed.parent.mkdir(parents=True, exist_ok=True)
        deployed.write_bytes(setfile.read_bytes())
        evidence_dir = run_dir / "mock_evidence" / cell_id
        evidence_dir.mkdir(parents=True, exist_ok=True)
        summary = evidence_dir / "summary.json"
        report = evidence_dir / "report.htm"
        ini = evidence_dir / "tester.ini"
        log = evidence_dir / "tester.log"
        summary.write_text("{}\n", encoding="utf-8")
        report.write_text("<html>mock</html>\n", encoding="utf-8")
        ini.write_text("[Tester]\n", encoding="utf-8")
        log.write_text("mock\n", encoding="utf-8")
        return q03.CellEvidence(
            cell_id=cell_id,
            index=index,
            axis_value=value,
            metrics=q03.CellMetrics(1.25, 25, 100.0),
            setfile=q03.file_record(setfile),
            deployed_setfile=q03.file_record(deployed),
            summary=q03.file_record(summary),
            reports=(q03.file_record(report),),
            tester_inis=(q03.file_record(ini),),
            tester_logs=(q03.file_record(log),),
        )

    monkeypatch.setattr(q03, "run_cell", fake_run_cell)
    out_root = tmp_path / "reports"

    result = q03.execute(
        contract,
        repo_root=bundle.root,
        ea_dir=bundle.ea_dir,
        card_path=bundle.card,
        baseline_setfile=bundle.baseline,
        terminal="T1",
        terminal_allowlist=("T1",),
        out_root=q03.CANONICAL_OUT_ROOT,
        timeout_sec=60,
    )

    pick = Path(result["plateau_pick"])
    median_set = Path(result["selected_set"]["path"])
    assert pick.name == "plateau_pick.json"
    assert median_set.name == "plateau_median.set"
    assert pick.is_file()
    assert median_set.is_file()
    assert q03.sha256_file(median_set) == result["selected_set"]["sha256"]
    assert json.loads(pick.read_text(encoding="utf-8"))["selected_set"]["sha256"] == result["selected_set"]["sha256"]
