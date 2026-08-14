from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from framework.scripts import emit_dev_sweep as emitter
from framework.scripts import q15_freeze_check as q15


def _write(path: Path, value: str | bytes | dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, bytes):
        path.write_bytes(value)
    elif isinstance(value, dict):
        path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    else:
        path.write_text(value, encoding="utf-8", newline="\n")
    return path


def _bound(path: Path) -> dict[str, object]:
    return {
        "path": str(path.resolve()),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size_bytes": path.stat().st_size,
    }


CARD_ID = "OPT-13213-USDJPY-PREDICATE-ABLATION-fixture01"


def _card() -> dict[str, object]:
    return {
        "schema": q15.OPT_CARD_SCHEMA,
        "card_id": CARD_ID,
        "parent": {"ea_id": "QM5_13213", "symbol": "USDJPY.DWX"},
        "lever": q15.PREDICATE_ABLATION_LEVER,
        "parameter_surface": {
            "surface_type": q15.CATEGORICAL_SURFACE_TYPE,
            "fixed_parameters": {"strategy_opt_enabled": True},
            "parameters": [],
            "minimum_dev_fire_count": 20,
            "predicate_trials": [
                {"predicate_id": "QM_PP_DOJI", "direction": "BUY"},
                {"predicate_id": "QM_PP_HAMMER", "direction": "SELL"},
            ],
        },
        "success_metric": {
            "primary": "annual_return_pct",
            "direction": "MAXIMIZE",
            "minimum_improvement": 0.1,
        },
        "comparison_windows": [
            {"id": "F1", "kind": "Q04_ANCHORED_OOS", "start": "2023-01-01", "end": "2023-12-31"},
        ],
    }


def _ledger() -> dict[str, object]:
    return {
        "schema": q15.TRIAL_LEDGER_SCHEMA,
        "card_id": CARD_ID,
        "status": "OPENED",
        "declared_trial_count": 2,
        "planned_trials": [
            {"trial_id": "T001", "predicate_id": "QM_PP_DOJI", "direction": "BUY"},
            {"trial_id": "T002", "predicate_id": "QM_PP_HAMMER", "direction": "SELL"},
        ],
        "trials": [],
    }


def _fixture(tmp_path: Path) -> dict[str, Path | str]:
    card_path = _write(tmp_path / "opt_card.json", _card())
    ledger_path = _write(tmp_path / "trial_ledger.json", _ledger())
    results_dir = tmp_path / "results"
    incumbent_path = _write(results_dir / "incumbent.json", {
        "metric_value": 1.0,
        "time_thirds": [
            {"id": "DEV_1", "start": "2019-01-01", "end": "2019-12-31", "metric_value": 1.0},
            {"id": "DEV_2", "start": "2020-01-01", "end": "2020-12-31", "metric_value": 1.0},
            {"id": "DEV_3", "start": "2021-01-01", "end": "2021-12-31", "metric_value": 1.0},
        ],
    })
    _write(results_dir / "T001.json", {
        "trial_id": "T001", "predicate_id": "QM_PP_DOJI", "direction": "BUY",
        "metric_value": 1.2, "fire_count": 20,
        "time_thirds": [
            {"id": "DEV_1", "metric_value": 1.1},
            {"id": "DEV_2", "metric_value": 0.9},
            {"id": "DEV_3", "metric_value": 1.1},
        ],
    })
    _write(results_dir / "T002.json", {
        "trial_id": "T002", "predicate_id": "QM_PP_HAMMER", "direction": "SELL",
        "metric_value": 1.05, "fire_count": 25,
        "time_thirds": [
            {"id": "DEV_1", "metric_value": 1.0},
            {"id": "DEV_2", "metric_value": 1.0},
            {"id": "DEV_3", "metric_value": 1.0},
        ],
    })
    return {
        "card_path": card_path,
        "ledger_path": ledger_path,
        "results_dir": results_dir,
        "incumbent_path": incumbent_path,
        "window_start": "2019-01-01",
        "window_end": "2021-12-31",
        "chosen_trial_id": "T001",
    }


def _run(paths: dict[str, Path | str], tmp_path: Path, *, apply: bool = True, out_name: str = "dev_sweep.json") -> dict:
    return emitter.run_emit_dev_sweep(
        card_path=Path(paths["card_path"]),
        ledger_path=Path(paths["ledger_path"]),
        results_dir=Path(paths["results_dir"]),
        incumbent_result_path=Path(paths["incumbent_path"]),
        window_start=str(paths["window_start"]),
        window_end=str(paths["window_end"]),
        chosen_trial_id=str(paths["chosen_trial_id"]),
        out_path=tmp_path / out_name,
        apply=apply,
    )


def test_emitted_sweep_is_schema_valid_and_accepted_by_q15(tmp_path):
    paths = _fixture(tmp_path)
    result = _run(paths, tmp_path)
    out_path = Path(result["out_path"])
    sweep = json.loads(out_path.read_text(encoding="utf-8"))
    emitter.assert_matches_schema(sweep)

    card_info = q15._validate_card(_card(), CARD_ID)
    ledger_info = q15._validate_ledger(_ledger(), card_id=CARD_ID, expected_path=Path(paths["ledger_path"]))
    validated = q15._validate_sweep(out_path, card_info=card_info, ledger_info=ledger_info, card_id=CARD_ID)
    assert validated["chosen_trial_id"] == "T001"
    assert validated["selection_contract"]["observed_improvement"] == pytest.approx(0.2)


def test_byte_exact_planned_observed_binding_mismatch_rejected(tmp_path):
    paths = _fixture(tmp_path)
    _write(Path(paths["results_dir"]) / "T001.json", {
        "trial_id": "T001", "predicate_id": "QM_PP_ENGULFING", "direction": "BUY",
        "metric_value": 1.2, "fire_count": 20,
        "time_thirds": [
            {"id": "DEV_1", "metric_value": 1.1},
            {"id": "DEV_2", "metric_value": 0.9},
            {"id": "DEV_3", "metric_value": 1.1},
        ],
    })
    with pytest.raises(emitter.EmitDevSweepError, match="byte-exactly"):
        _run(paths, tmp_path)


def test_missing_fire_count_is_hard_error_never_defaulted(tmp_path):
    paths = _fixture(tmp_path)
    _write(Path(paths["results_dir"]) / "T001.json", {
        "trial_id": "T001", "predicate_id": "QM_PP_DOJI", "direction": "BUY",
        "metric_value": 1.2,
        "time_thirds": [
            {"id": "DEV_1", "metric_value": 1.1},
            {"id": "DEV_2", "metric_value": 0.9},
            {"id": "DEV_3", "metric_value": 1.1},
        ],
    })
    with pytest.raises(emitter.EmitDevSweepError, match="fire_count"):
        _run(paths, tmp_path)


def test_dev_window_overlapping_oos_rejected(tmp_path):
    paths = _fixture(tmp_path)
    paths["window_end"] = "2023-06-30"  # inside the Q04_ANCHORED_OOS fold F1
    with pytest.raises(emitter.EmitDevSweepError, match="first sealed OOS window"):
        _run(paths, tmp_path)


def test_two_runs_are_byte_identical(tmp_path):
    paths = _fixture(tmp_path)
    first = _run(paths, tmp_path, out_name="run1.json")
    second = _run(paths, tmp_path, out_name="run2.json")
    assert first["body_sha256"] == second["body_sha256"]
    assert Path(first["out_path"]).read_bytes() == Path(second["out_path"]).read_bytes()


def test_incomplete_trial_set_rejected(tmp_path):
    paths = _fixture(tmp_path)
    (Path(paths["results_dir"]) / "T002.json").unlink()
    with pytest.raises(emitter.EmitDevSweepError, match="is missing for planned trial"):
        _run(paths, tmp_path)


def test_dry_run_does_not_write(tmp_path):
    paths = _fixture(tmp_path)
    out_path = tmp_path / "dev_sweep.json"
    result = _run(paths, tmp_path, apply=False, out_name="dev_sweep.json")
    assert result["applied"] is False
    assert not out_path.exists()
    assert "sweep" in result
