from __future__ import annotations

import csv
import datetime as dt
import json
from pathlib import Path

import numpy as np
import pytest

from tools.strategy_farm import shadow_null_factory as nf
from tools.strategy_farm import shadow_search_world_census as swc


def _write_panel(
    path: Path,
    matrix: np.ndarray,
    trial_ids: list[str] | None = None,
) -> Path:
    ids = trial_ids or [f"trial_{index:02d}" for index in range(matrix.shape[1])]
    start = dt.date(2025, 1, 1)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["date", "trial_id", "return"])
        writer.writeheader()
        for day in range(matrix.shape[0]):
            for column, trial_id in enumerate(ids):
                writer.writerow({
                    "date": (start + dt.timedelta(days=day)).isoformat(),
                    "trial_id": trial_id,
                    "return": f"{matrix[day, column]:.12f}",
                })
    return path


def _experiment(seed: int = 77) -> nf.Experiment:
    return nf.Experiment(
        annualization=252,
        block_length=10,
        replications=399,
        seed=seed,
        alpha=0.05,
        batch_size=37,
    )


def test_strong_signal_survives_joint_max_null_and_is_reproducible(tmp_path: Path) -> None:
    rng = np.random.default_rng(1234)
    matrix = rng.normal(0.0, 0.01, size=(360, 20))
    matrix[:, 7] += 0.004
    panel = nf.load_panel(_write_panel(tmp_path / "returns.csv", matrix))

    first = nf.analyze_panel(panel, _experiment())
    second = nf.analyze_panel(panel, _experiment())

    assert first == second
    assert first["selected"]["trial_id"] == "trial_07"
    assert first["selected"]["maxT_fwer_p"] <= 0.05
    assert first["decision"] == "SELECTION_SURVIVES_JOINT_NULL"
    assert first["gate_eligible"] is False


def test_full_search_world_expansion_overrides_survivor_only_pass(tmp_path: Path) -> None:
    rng = np.random.default_rng(1234)
    matrix = rng.normal(0.0, 0.01, size=(360, 20))
    matrix[:, 7] += 0.004
    panel = nf.load_panel(_write_panel(tmp_path / "returns.csv", matrix))
    pairs = [
        {"ea_id": f"QM5_{index:05d}", "symbol": "XAUUSD.DWX"}
        for index in range(1000)
    ]
    search_world = swc.build_payload(
        pairs,
        generated_at_utc="2026-08-24T10:00:00+00:00",
        database_path="fixture.sqlite",
        database_observation={
            "work_item_count": 1000,
            "query_only": True,
            "snapshot_transaction": True,
        },
    )

    report = nf.analyze_panel(panel, _experiment(), search_world=search_world)

    assert report["template_cohort_decision"] == "SELECTION_SURVIVES_JOINT_NULL"
    assert report["decision"] == "SELECTION_NOT_PROVEN_ACROSS_DECLARED_SEARCH_WORLD"
    world = report["search_world"]
    assert world["declared_search_trials"] == 1000
    assert world["observed_return_trials"] == 20
    assert world["return_panel_coverage"] == 0.02
    assert world["return_panel_complete"] is False
    assert world["monte_carlo_resolution_sufficient"] is False
    assert world["minimum_replications_for_resolution"] == 19999
    assert world["global_null_rejected"] is False
    assert report["gate_eligible"] is False


def test_full_world_refuses_false_all_trials_attestation(tmp_path: Path) -> None:
    rng = np.random.default_rng(91)
    panel = nf.load_panel(
        _write_panel(tmp_path / "returns.csv", rng.normal(size=(120, 4)))
    )
    experiment = _experiment()
    ledger = {
        **nf._ledger_expected(panel, experiment),
        "attestation": "SPEC_FROZEN_BEFORE_SHADOW_EVALUATION",
        "cohort_attestation": "ALL_DECLARED_SEARCH_TRIALS_INCLUDED",
        "cohort_definition": "the four supplied fixture trials",
        "frozen_at_utc": "2026-08-24T10:00:00+00:00",
    }
    ledger_path = tmp_path / "ledger.json"
    ledger_path.write_text(json.dumps(ledger), encoding="utf-8")
    search_world = swc.build_payload(
        [
            {"ea_id": f"QM5_{index:05d}", "symbol": "EURUSD.DWX"}
            for index in range(10)
        ],
        generated_at_utc="2026-08-24T10:00:00+00:00",
        database_path="fixture.sqlite",
        database_observation={
            "work_item_count": 10,
            "query_only": True,
            "snapshot_transaction": True,
        },
    )

    with pytest.raises(nf.NullFactoryError, match="falsely attests"):
        nf.analyze_panel(
            panel,
            experiment,
            ledger_path=ledger_path,
            search_world=search_world,
        )


def test_rectangular_panel_is_mandatory(tmp_path: Path) -> None:
    rng = np.random.default_rng(5)
    path = _write_panel(tmp_path / "returns.csv", rng.normal(size=(80, 3)))
    rows = path.read_text(encoding="utf-8").splitlines()
    path.write_text("\n".join(rows[:-1]) + "\n", encoding="utf-8")

    with pytest.raises(nf.NullFactoryError, match="not rectangular"):
        nf.load_panel(path)


def test_verified_ledger_binds_all_experiment_choices(tmp_path: Path) -> None:
    rng = np.random.default_rng(9)
    panel = nf.load_panel(
        _write_panel(tmp_path / "returns.csv", rng.normal(size=(120, 4)))
    )
    experiment = _experiment()
    ledger = {
        **nf._ledger_expected(panel, experiment),
        "attestation": "SPEC_FROZEN_BEFORE_SHADOW_EVALUATION",
        "cohort_attestation": "ALL_DECLARED_SEARCH_TRIALS_INCLUDED",
        "cohort_definition": "all trial IDs launched in frozen batch test-001",
        "frozen_at_utc": "2026-08-24T12:00:00+00:00",
    }
    ledger_path = tmp_path / "ledger.json"
    ledger_path.write_text(json.dumps(ledger), encoding="utf-8")

    report = nf.analyze_panel(panel, experiment, ledger_path=ledger_path)

    assert report["ledger"]["status"] == "VERIFIED"
    assert report["input"]["loser_inclusion_attestation"] == (
        "LEDGER_ATTESTED_ALL_DECLARED_SEARCH_TRIALS_INCLUDED"
    )

    ledger["replications"] += 1
    ledger_path.write_text(json.dumps(ledger), encoding="utf-8")
    with pytest.raises(nf.NullFactoryError, match="ledger validation failed"):
        nf.analyze_panel(panel, experiment, ledger_path=ledger_path)


def test_ledger_cannot_imply_loser_inclusion_without_cohort_attestation(
    tmp_path: Path,
) -> None:
    rng = np.random.default_rng(18)
    panel = nf.load_panel(
        _write_panel(tmp_path / "returns.csv", rng.normal(size=(120, 4)))
    )
    experiment = _experiment()
    ledger = {
        **nf._ledger_expected(panel, experiment),
        "attestation": "SPEC_FROZEN_BEFORE_SHADOW_EVALUATION",
        "frozen_at_utc": "2026-08-24T12:00:00+00:00",
    }
    ledger_path = tmp_path / "ledger.json"
    ledger_path.write_text(json.dumps(ledger), encoding="utf-8")

    with pytest.raises(nf.NullFactoryError, match="cohort_attestation_valid"):
        nf.analyze_panel(panel, experiment, ledger_path=ledger_path)


def test_ledger_requires_timezone_aware_freeze_timestamp(tmp_path: Path) -> None:
    rng = np.random.default_rng(19)
    panel = nf.load_panel(
        _write_panel(tmp_path / "returns.csv", rng.normal(size=(120, 4)))
    )
    experiment = _experiment()
    ledger = {
        **nf._ledger_expected(panel, experiment),
        "attestation": "SPEC_FROZEN_BEFORE_SHADOW_EVALUATION",
        "cohort_attestation": "ALL_DECLARED_SEARCH_TRIALS_INCLUDED",
        "cohort_definition": "fixture batch",
        "frozen_at_utc": "2026-08-24T12:00:00",
    }
    ledger_path = tmp_path / "ledger.json"
    ledger_path.write_text(json.dumps(ledger), encoding="utf-8")

    with pytest.raises(nf.NullFactoryError, match="frozen_at_valid"):
        nf.analyze_panel(panel, experiment, ledger_path=ledger_path)


def test_bh_qvalues_are_monotone_in_p_rank() -> None:
    p = np.asarray([0.04, 0.001, 0.03, 0.2, 0.9])
    q = nf._bh_qvalues(p)
    order = np.argsort(p)

    assert np.all(np.diff(q[order]) >= -1e-15)
    assert np.all(q >= p)


def test_build_report_requires_exactly_one_input(tmp_path: Path) -> None:
    with pytest.raises(nf.NullFactoryError, match="exactly one"):
        nf.build_report(None, _experiment())


def test_programmatic_panel_shape_is_validated() -> None:
    panel = nf.Panel(
        dates=tuple(f"2025-01-{day:02d}" for day in range(1, 31)),
        trial_ids=("left", "right"),
        returns=np.ones((60, 2)),
        source_path="fixture",
        source_sha256="0" * 64,
        source_context={"kind": "fixture"},
    )

    with pytest.raises(nf.NullFactoryError, match="shape"):
        nf.analyze_panel(panel, _experiment())
