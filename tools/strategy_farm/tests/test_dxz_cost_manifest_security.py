from __future__ import annotations

import dataclasses
import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_as_live_requal as subject
from tools.strategy_farm import dxz_requal_adjudicator as adjudicator


WINDOW = {
    "requested_from_date": "2020-01-01",
    "requested_to_date": "2025-12-31",
    "effective_from_date": "2020-01-01",
    "effective_to_date": "2025-12-31",
}
AS_OF = dt.datetime(2026, 7, 16, 12, tzinfo=dt.UTC)


def _write_bound_json(path: Path, payload: dict, hash_field: str) -> None:
    unsigned = dict(payload)
    unsigned.pop(hash_field, None)
    payload[hash_field] = subject.canonical_json_sha(unsigned)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (path.with_name(path.name + ".sha256")).write_text(
        f"{subject.sha256_file(path)}  {path.name}\n", encoding="ascii"
    )


def _axis_payload(
    axis: str,
    *,
    source_sha: str,
    sleeves: list[dict],
) -> dict:
    covered = [
        (subject._cost_sleeve_key(sleeve), sleeve["symbol"])
        for sleeve in sleeves
    ]
    common = {
        "schema_version": 1,
        "artifact_type": subject.EXECUTION_COST_AXIS_ARTIFACT_TYPE,
        "axis": axis,
        "evidence_type": next(iter(subject.EXECUTION_COST_EVIDENCE_TYPES[axis])),
        "status": "PASS",
        "source_manifest_sha256": source_sha,
        "covered_sleeves": sleeves,
        "evaluation_window": dict(WINDOW),
        "valid_from_utc": "2026-07-15T00:00:00+00:00",
        "valid_until_utc": "2026-07-20T00:00:00+00:00",
        "assertion": f"conservative {axis} evidence",
        "methodology": f"measured and replayed {axis}",
    }
    if axis == "commission":
        common.update(
            {
                "parameters": {
                    "conservative": True,
                    "charge_basis": "ROUND_TRIP_NOTIONAL_BPS",
                    "rate": 5.0,
                    "currency": "EUR",
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "name": "five-bps-round-trip",
                        "applied_rate": 5.0,
                        "status": "PASS",
                    }
                    for key, _symbol in covered
                ],
                "results": {
                    "all_trades_costed": True,
                    "unknown_symbols": [],
                    "degraded_symbols": [],
                },
            }
        )
    elif axis == "historical_tester_spread":
        common.update(
            {
                "parameters": {
                    "conservative": True,
                    "tester_model": "EVERY_TICK_BASED_ON_REAL_TICKS",
                    "history_quality": "100% real ticks",
                    "spread_embedded": True,
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "spread_multiplier": 1.0,
                        "observed_spread_points": 1.0,
                        "applied_spread_points": 1.0,
                        "status": "PASS",
                    }
                    for key, _symbol in covered
                ],
                "results": {"all_reports_bound": True, "missing_reports": []},
            }
        )
    elif axis == "current_broker_spread_parity":
        common.update(
            {
                "parameters": {
                    "minimum_samples_per_symbol": 100,
                    "quantile": 0.95,
                    "minimum_applied_to_observed_multiplier": 1.0,
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "symbol": symbol,
                        "samples": 100,
                        "observed_quantile_points": 1.0,
                        "applied_spread_points": 1.0,
                        "status": "PASS",
                    }
                    for key, symbol in covered
                ],
                "results": {"all_symbols_pass": True},
            }
        )
    elif axis == "current_broker_swap_rate_parity":
        common.update(
            {
                "parameters": {
                    "minimum_observation_days": 5,
                    "maximum_rate_age_days": 7,
                    "include_long_and_short": True,
                    "include_triple_swap": True,
                    "minimum_adverse_multiplier": 1.0,
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "symbol": symbol,
                        "side": side,
                        "observation_days": 5,
                        "rollover_multiplier": rollover,
                        "observed_cost_account_ccy": 1.0,
                        "applied_cost_account_ccy": 1.0,
                        "status": "PASS",
                    }
                    for key, symbol in covered
                    for side, rollover in (("LONG", 1.0), ("SHORT", 3.0))
                ],
                "results": {"all_symbols_sides_pass": True},
            }
        )
    else:
        common.update(
            {
                "parameters": {
                    "minimum_samples_per_symbol": 30,
                    "quantile": 0.95,
                    "minimum_adverse_multiplier": 1.0,
                    "include_gap_stress": True,
                },
                "scenarios": [
                    {
                        "covered_key": key,
                        "symbol": symbol,
                        "scenario": scenario,
                        "samples": 30,
                        "observed_adverse_points": 1.0,
                        "applied_adverse_points": 1.0,
                        "status": "PASS",
                    }
                    for key, symbol in covered
                    for scenario in ("ADVERSE_QUANTILE", "GAP_STRESS")
                ],
                "results": {"all_symbols_scenarios_pass": True},
            }
        )
    return common


def _cost_manifest(tmp_path: Path) -> tuple[Path, str, list[dict]]:
    tmp_path.mkdir(parents=True, exist_ok=True)
    source_sha = "a" * 64
    sleeves = [{"ea_id": 1, "symbol": "EURUSD.DWX", "timeframe": "H1"}]
    axes: dict[str, dict] = {}
    for axis in subject.EXECUTION_COST_AXES:
        artifact = tmp_path / f"{axis}.json"
        payload = _axis_payload(axis, source_sha=source_sha, sleeves=sleeves)
        _write_bound_json(artifact, payload, "artifact_payload_sha256")
        axes[axis] = {
            "status": "PASS",
            "evidence": {
                "path": artifact.name,
                "sha256": subject.sha256_file(artifact),
                "evidence_type": payload["evidence_type"],
            },
        }
    manifest = tmp_path / "cost_manifest.json"
    payload = {
        "schema_version": 1,
        "artifact_type": subject.EXECUTION_COST_MANIFEST_TYPE,
        "status": "PASS",
        "source_manifest_sha256": source_sha,
        "valid_from_utc": "2026-07-01T00:00:00+00:00",
        "valid_until_utc": "2026-07-31T00:00:00+00:00",
        "scope": "GLOBAL",
        "covered_keys": ["1:EURUSD.DWX"],
        "covered_sleeves": sleeves,
        "evaluation_window": dict(WINDOW),
        "axes": axes,
    }
    _write_bound_json(manifest, payload, "manifest_payload_sha256")
    return manifest, source_sha, sleeves


def _load(path: Path, source_sha: str, sleeves: list[dict]):
    return subject.load_execution_cost_evidence_manifest(
        path,
        source_manifest_sha256=source_sha,
        as_of_utc=AS_OF,
        required_sleeves=sleeves,
        window_contract=WINDOW,
    )


def test_semantic_five_axis_manifest_is_bound_per_axis(tmp_path: Path) -> None:
    manifest, source_sha, sleeves = _cost_manifest(tmp_path)
    metadata, contracts = _load(manifest, source_sha, sleeves)

    assert set(metadata["axes"]) == set(subject.EXECUTION_COST_AXES)
    assert all(metadata["axes"][axis] for axis in subject.EXECUTION_COST_AXES)
    assert set(contracts["1:EURUSD.DWX"]["axes"]) == set(subject.EXECUTION_COST_AXES)
    metadata["axis_hashes_start"] = subject.execution_cost_axis_hash_snapshot(metadata)
    assert subject.verify_execution_cost_evidence_unchanged(metadata) == (True, [])


def test_target_cost_contract_requires_exact_variant_identity(tmp_path: Path) -> None:
    manifest, source_sha, _legacy_sleeves = _cost_manifest(tmp_path)
    exact_sleeves = [
        {
            "ea_id": 1,
            "symbol": "EURUSD.DWX",
            "timeframe": "H1",
            "variant_id": "C_POLICY_REPAIR",
        }
    ]
    exact_key = "1:EURUSD.DWX:H1:C_POLICY_REPAIR"
    manifest_payload = json.loads(manifest.read_text(encoding="utf-8"))
    for axis in subject.EXECUTION_COST_AXES:
        artifact = tmp_path / f"{axis}.json"
        payload = json.loads(artifact.read_text(encoding="utf-8"))
        payload["covered_sleeves"] = exact_sleeves
        for scenario in payload["scenarios"]:
            scenario["covered_key"] = exact_key
        _write_bound_json(artifact, payload, "artifact_payload_sha256")
        manifest_payload["axes"][axis]["evidence"]["sha256"] = (
            subject.sha256_file(artifact)
        )
    manifest_payload["covered_sleeves"] = exact_sleeves
    manifest_payload["covered_keys"] = [exact_key]
    _write_bound_json(manifest, manifest_payload, "manifest_payload_sha256")

    metadata, contracts = _load(manifest, source_sha, exact_sleeves)

    assert metadata["covered_keys"] == [exact_key]
    assert contracts[exact_key]["variant_id"] == "C_POLICY_REPAIR"
    with pytest.raises(subject.RequalError, match="four-part sleeve coverage"):
        _load(
            manifest,
            source_sha,
            [
                {
                    "ea_id": 1,
                    "symbol": "EURUSD.DWX",
                    "timeframe": "H1",
                    "variant_id": "OTHER_VARIANT",
                }
            ],
        )


def test_hash_bound_dummy_and_wrong_axis_are_rejected(tmp_path: Path) -> None:
    manifest, source_sha, sleeves = _cost_manifest(tmp_path)
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    dummy = tmp_path / "dummy.json"
    dummy.write_text('{"status":"PASS"}\n', encoding="utf-8")
    (tmp_path / "dummy.json.sha256").write_text(
        f"{subject.sha256_file(dummy)}  dummy.json\n", encoding="ascii"
    )
    payload["axes"]["commission"]["evidence"].update(
        {"path": dummy.name, "sha256": subject.sha256_file(dummy)}
    )
    _write_bound_json(manifest, payload, "manifest_payload_sha256")
    with pytest.raises(subject.RequalError, match="schema_version"):
        _load(manifest, source_sha, sleeves)

    manifest, source_sha, sleeves = _cost_manifest(tmp_path / "wrong_axis")
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    payload["axes"]["commission"]["evidence"]["evidence_type"] = next(
        iter(subject.EXECUTION_COST_EVIDENCE_TYPES["slippage_stress"])
    )
    _write_bound_json(manifest, payload, "manifest_payload_sha256")
    with pytest.raises(subject.RequalError, match="evidence_type is not allowed"):
        _load(manifest, source_sha, sleeves)


@pytest.mark.parametrize(
    ("axis", "mutate", "message"),
    [
        (
            "historical_tester_spread",
            lambda row: row["scenarios"][0].update({"observed_spread_points": 0}),
            "strictly positive",
        ),
        (
            "current_broker_spread_parity",
            lambda row: row["parameters"].update({"minimum_samples_per_symbol": 1}),
            "minimum_samples_per_symbol",
        ),
        (
            "current_broker_swap_rate_parity",
            lambda row: row["scenarios"][0].update({"observed_cost_account_ccy": 0}),
            "strictly positive",
        ),
        (
            "slippage_stress",
            lambda row: row["scenarios"][0].update({"applied_adverse_points": 0}),
            "strictly positive",
        ),
    ],
)
def test_self_declared_pass_cannot_lower_fixed_thresholds(
    tmp_path: Path, axis: str, mutate, message: str
) -> None:
    manifest, source_sha, sleeves = _cost_manifest(tmp_path)
    manifest_payload = json.loads(manifest.read_text(encoding="utf-8"))
    artifact = tmp_path / f"{axis}.json"
    payload = json.loads(artifact.read_text(encoding="utf-8"))
    mutate(payload)
    _write_bound_json(artifact, payload, "artifact_payload_sha256")
    manifest_payload["axes"][axis]["evidence"]["sha256"] = subject.sha256_file(artifact)
    _write_bound_json(manifest, manifest_payload, "manifest_payload_sha256")

    with pytest.raises(subject.RequalError, match=message):
        _load(manifest, source_sha, sleeves)


def test_wrong_window_expiry_and_overlong_current_validity_fail(tmp_path: Path) -> None:
    manifest, source_sha, sleeves = _cost_manifest(tmp_path)
    with pytest.raises(subject.RequalError, match="evaluation window mismatch"):
        subject.load_execution_cost_evidence_manifest(
            manifest,
            source_manifest_sha256=source_sha,
            as_of_utc=AS_OF,
            required_sleeves=sleeves,
            window_contract={**WINDOW, "effective_from_date": "2021-01-01"},
        )

    with pytest.raises(subject.RequalError, match="does not cover the selected book"):
        subject.load_execution_cost_evidence_manifest(
            manifest,
            source_manifest_sha256=source_sha,
            as_of_utc=AS_OF,
            required_sleeves=[
                {"ea_id": 1, "symbol": "GBPUSD.DWX", "timeframe": "H1"}
            ],
            window_contract=WINDOW,
        )

    with pytest.raises(subject.RequalError, match="validity window"):
        subject.load_execution_cost_evidence_manifest(
            manifest,
            source_manifest_sha256=source_sha,
            as_of_utc=dt.datetime(2027, 1, 1, tzinfo=dt.UTC),
            required_sleeves=sleeves,
            window_contract=WINDOW,
        )

    axis = "current_broker_spread_parity"
    artifact = tmp_path / f"{axis}.json"
    artifact_payload = json.loads(artifact.read_text(encoding="utf-8"))
    artifact_payload["valid_until_utc"] = "2026-07-30T00:00:00+00:00"
    _write_bound_json(artifact, artifact_payload, "artifact_payload_sha256")
    manifest_payload = json.loads(manifest.read_text(encoding="utf-8"))
    manifest_payload["axes"][axis]["evidence"]["sha256"] = subject.sha256_file(artifact)
    _write_bound_json(manifest, manifest_payload, "manifest_payload_sha256")
    with pytest.raises(subject.RequalError, match="seven-day freshness"):
        _load(manifest, source_sha, sleeves)


def test_adjudicator_revalidates_original_semantics_and_axis_end_hashes(tmp_path: Path) -> None:
    manifest, source_sha, sleeves = _cost_manifest(tmp_path)
    metadata, _contracts = _load(manifest, source_sha, sleeves)
    metadata["axis_hashes_start"] = subject.execution_cost_axis_hash_snapshot(metadata)
    metadata.update(
        {
            "sha256_end": metadata["sha256"],
            "axis_hashes_end": metadata["axis_hashes_start"],
            "unchanged": True,
            "end_errors": [],
        }
    )
    assert adjudicator._execution_cost_manifest_issues(
        metadata,
        manifest_sha256=source_sha,
        required_keys={"1:EURUSD.DWX"},
        required_sleeves=sleeves,
        window_contract=WINDOW,
        repo_root=tmp_path,
        as_of=AS_OF.date(),
    ) == []

    metadata["axis_hashes_end"] = {**metadata["axis_hashes_end"], "commission": []}
    assert "EXECUTION_COST_AXIS_SWEEP_BINDING_INVALID" in adjudicator._execution_cost_manifest_issues(
        metadata,
        manifest_sha256=source_sha,
        required_keys={"1:EURUSD.DWX"},
        required_sleeves=sleeves,
        window_contract=WINDOW,
        repo_root=tmp_path,
        as_of=AS_OF.date(),
    )


def _preset_job(tmp_path: Path, *, expectation: dict | None, risk: float = 0.5) -> subject.Job:
    live = tmp_path / "live"
    live.mkdir(parents=True, exist_ok=True)
    ex5 = live / "QM5_1_test.ex5"
    preset = live / "QM5_1_EURUSD.DWX_H1_live.set"
    ex5.write_bytes(b"ex5")
    preset.write_text(
        "; environment: live\nRISK_FIXED=0\nRISK_PERCENT=0.5\nPORTFOLIO_WEIGHT=1\n",
        encoding="utf-8",
    )
    return subject.Job(
        ordinal=1,
        ea_id=1,
        symbol="EURUSD.DWX",
        ea_label="QM5_1_test",
        timeframe="H1",
        live_ex5=ex5,
        live_preset=preset,
        manifest_trades=1,
        reference_stream=None,
        set_file_expectation=expectation,
        manifest_risk_percent=risk,
    )


def test_live_preset_exact_contract_passes_and_double_scaling_fails(tmp_path: Path) -> None:
    exact = {"ENV": "live", "RISK_FIXED": 0, "RISK_PERCENT": 0.5, "PORTFOLIO_WEIGHT": 1}
    assert subject.live_preset_contract(_preset_job(tmp_path / "pass", expectation=exact))[
        "status"
    ] == "PASS"

    scaled = {**exact, "PORTFOLIO_WEIGHT": 0.25}
    contract = subject.live_preset_contract(
        _preset_job(tmp_path / "fail", expectation=scaled)
    )
    assert contract["status"] == "FAIL"
    assert "MANIFEST_SET_FILE_DOUBLE_SCALING_RISK" in contract["blockers"]
    assert "LIVE_PRESET_VALUE_MISMATCH:PORTFOLIO_WEIGHT" in contract["blockers"]


def test_missing_set_expectation_is_fail_closed_before_mt5(tmp_path: Path) -> None:
    job = _preset_job(tmp_path, expectation=None)
    blockers = subject.reference_preflight_blockers(
        job,
        snapshot={"errors": []},
        snapshot_rows={},
        require_reference=False,
    )
    assert "MANIFEST_SET_FILE_EXPECTATION_MISSING_OR_INVALID" in blockers
    receipt = subject.preflight_blocked_receipt(job, blockers)
    assert receipt["technical_status"] == "FAIL"
    assert receipt["live_preset_contract"]["status"] == "FAIL"
