"""Tests for the Default-OFF V4a warm-cell runner contract."""
from __future__ import annotations

from copy import deepcopy

import pytest

from tools.strategy_farm import warm_cell_runner as runner


def _result(index: int) -> dict:
    return {
        "cell_key": f"cell-{index:02d}",
        "ea_id": "QM5_41161",
        "symbol": "GBPUSD.DWX",
        "period": "H1",
        "model": 4,
        "seed": 42,
        "from_date": "2019.01.01",
        "to_date": "2019.12.31",
        "ex5_sha256": "a" * 64,
        "mq5_sha256": "b" * 64,
        "setfile_sha256": f"{index:064x}",
        "history_manifest_sha256": "c" * 64,
        "report_metrics": {
            "total_trades": index + 5,
            "profit_factor_raw": "1.20",
            "net_profit_raw": "100.00",
            "drawdown_raw": "50.00 (0.05%)",
        },
        "trades": [
            {
                "entry_time": f"2019-01-{index + 1:02d}T10:00:00Z",
                "exit_time": f"2019-01-{index + 1:02d}T12:00:00Z",
                "symbol": "GBPUSD.DWX",
                "side": "buy",
                "net": float(index),
            }
        ],
    }


def _validation_authorization() -> dict:
    return {
        "schema": "qm.warm-cell-validation-run/v1",
        "purpose": "OFFLINE_PARITY_VALIDATION",
        "task_id": runner.TASK_ID,
        "authorized_by": "OWNER_COMMISSION",
        "execution_backend": "SUPPORTED_RESIDENT_TESTER_CONTROL",
        "profile_mode": "DISPOSABLE",
        "production_wiring": False,
        "active_terminal_allowed": False,
        "minimum_comparisons": 20,
    }


class FakeBackend:
    def __init__(self, results: dict[str, dict]):
        self.results = results
        self.opened = 0
        self.closed = 0
        self.executed: list[str] = []

    def open_session(self, pair_contract):
        self.opened += 1
        return {"pair_contract": pair_contract}

    def run_cell(self, session, cell):
        key = cell["cell_key"]
        self.executed.append(key)
        return deepcopy(self.results[key])

    def close_session(self, session):
        self.closed += 1


@pytest.mark.parametrize("value", [None, "", "0", "false", "no", "off"])
def test_flag_is_default_off(value):
    environ = {} if value is None else {runner.FLAG_NAME: value}
    assert runner.feature_flag_enabled(environ) is False


@pytest.mark.parametrize("value", ["1", "true", "yes", "on", " TRUE "])
def test_flag_requires_explicit_on_value(value):
    assert runner.feature_flag_enabled({runner.FLAG_NAME: value}) is True


def test_invalid_flag_fails_closed():
    with pytest.raises(runner.FlagValueError):
        runner.feature_flag_enabled({runner.FLAG_NAME: "maybe"})


def test_default_off_never_touches_backend():
    backend = FakeBackend({})
    result = runner.WarmCellRunner(backend).run(
        cells=[], cold_references={}, environ={}, activation_manifest=None
    )
    assert result == {
        "status": "COLD_PATH_UNCHANGED",
        "flag": runner.FLAG_NAME,
        "flag_enabled": False,
        "cells_executed": 0,
    }
    assert backend.opened == backend.closed == 0


def test_enabled_flag_without_owner_seal_is_refused_before_backend():
    backend = FakeBackend({})
    with pytest.raises(runner.ActivationRefused, match="ACTIVATION_MANIFEST_MISSING"):
        runner.WarmCellRunner(backend).run(
            cells=[],
            cold_references={},
            environ={runner.FLAG_NAME: "1"},
            activation_manifest=None,
        )
    assert backend.opened == 0


def test_twenty_exact_cells_use_one_session():
    references = {f"cell-{i:02d}": _result(i) for i in range(20)}
    backend = FakeBackend(references)
    cells = [{"cell_key": key} for key in references]
    result = runner.WarmCellRunner(backend).run(
        cells=cells,
        cold_references=references,
        environ={runner.FLAG_NAME: "1"},
        activation_manifest=_validation_authorization(),
    )
    assert result["status"] == "EXACT_PARITY"
    assert result["cells_executed"] == 20
    assert result["session_count"] == 1
    assert result["authorization_mode"] == "VALIDATION"
    assert result["parity"]["all_exact"] is True
    assert backend.opened == backend.closed == 1
    assert backend.executed == list(references)


def test_metric_or_trade_deviation_stops_immediately_and_closes_session():
    references = {f"cell-{i:02d}": _result(i) for i in range(20)}
    warm = deepcopy(references)
    warm["cell-03"]["report_metrics"]["net_profit_raw"] = "100.01"
    warm["cell-04"]["trades"][0]["net"] = 999.0
    backend = FakeBackend(warm)
    with pytest.raises(runner.ParityDeviation, match="cell-03"):
        runner.WarmCellRunner(backend).run(
            cells=[{"cell_key": key} for key in references],
            cold_references=references,
            environ={runner.FLAG_NAME: "on"},
            activation_manifest=_validation_authorization(),
        )
    assert backend.executed == [f"cell-{i:02d}" for i in range(4)]
    assert backend.opened == backend.closed == 1


def test_comparator_detects_identity_and_canonical_trade_byte_changes():
    cold = _result(1)
    warm = deepcopy(cold)
    warm["seed"] = 43
    warm["trades"][0]["side"] = "sell"
    comparison = runner.compare_cell_results(cold, warm)
    assert comparison["all_exact"] is False
    assert comparison["identity_mismatch_fields"] == ["seed"]
    assert comparison["report_metrics_field_exact_match"] is True
    assert comparison["trade_list_byte_exact_match"] is False


def test_parity_floor_rejects_nineteen_exact_rows():
    rows = [
        {"cell_key": f"cell-{index:02d}", "all_exact": True}
        for index in range(19)
    ]
    summary = runner.parity_summary(rows)
    assert summary["all_exact"] is False
    assert summary["problems"] == ["PARITY_SAMPLE_BELOW_MINIMUM"]
