"""Static/unit guards for the QM5_20009 Freeze-v5 research fence.

These tests never launch MT5.  In particular, they must not generate the real
bundle or hash the multi-gigabyte Model-4 tree during ordinary collection.
"""

from __future__ import annotations

import copy
import csv
import hashlib
import json
import sys
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[1]
TOOLS = EA_ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import generate_research_sets as freeze  # noqa: E402
import validate_research_run as fence  # noqa: E402


EXPECTED_INPUTS = {
    "qm_ea_id",
    "qm_magic_slot_offset",
    "qm_rng_seed",
    "RISK_PERCENT",
    "RISK_FIXED",
    "PORTFOLIO_WEIGHT",
    "InpQMSimCommissionPerLot",
    "qm_news_temporal",
    "qm_news_compliance",
    "qm_news_stale_max_hours",
    "qm_news_min_impact",
    "qm_news_mode_legacy",
    "qm_friday_close_enabled",
    "qm_friday_close_hour_broker",
    "qm_stress_reject_probability",
    "qm_chartui_enabled",
    "qm_chartui_corner",
    "strategy_mode",
    "strategy_replay_bars_index",
    "strategy_replay_bars_fx",
    "strategy_a_pivot_wing",
    "strategy_a_reclaim_bars",
    "strategy_a_max_bars_to_mss",
    "strategy_a_min_fvg_atr",
    "strategy_a_sl_buffer_atr",
    "strategy_a_min_rr",
    "strategy_b_pivot_wing",
    "strategy_b_reclaim_bars",
    "strategy_b_max_bars_to_mss",
    "strategy_b_min_fvg_atr",
    "strategy_b_sl_buffer_atr",
    "strategy_b_min_rr",
    "strategy_governor_policy_id",
    "strategy_challenge_instance_id",
    "strategy_governor_heartbeat_max_age_seconds",
}


def protocol() -> dict[str, object]:
    return json.loads(freeze.PROTOCOL.read_text(encoding="utf-8"))


def test_v5_identity_and_v4_protocol_remains_an_immutable_audit_artifact() -> None:
    payload = protocol()
    assert freeze.PROTOCOL.name == "research_protocol_v5.json"
    assert payload["protocol_id"] == "QM5_20009_RESEARCH_FREEZE_V5"
    assert payload["contract_version"] == "v5"
    v4 = EA_ROOT / "docs" / "research_protocol_v4.json"
    assert freeze.sha256_file(v4) == (
        "3fbc28c5c5cf95c7563794fafe5c9eba01e3e8df6c5b39a2f27296da1c31e5a2"
    )


def test_visible_input_closure_is_exact_and_framework_overrides_are_explicit() -> None:
    payload = protocol()
    assert set(freeze.visible_input_names()) == EXPECTED_INPUTS
    assert len(EXPECTED_INPUTS) == payload["tester"]["visible_input_count"] == 35
    values = freeze.parameter_map(slot=0, mode=0)
    assert set(values) == EXPECTED_INPUTS
    assert values["InpQMSimCommissionPerLot"] == "0.0"
    assert values["qm_chartui_enabled"] == "false"
    assert values["qm_chartui_corner"] == "0"
    assert payload["tester"]["commission_injection"] == (
        "RAW_TESTER_COMMISSION_ZERO; RUNNER_COMMISSION_OVERRIDES_ZERO; "
        "EA_SIM_COMMISSION_ZERO; AUTHORITATIVE_EXTERNAL_DEAL_AUDIT"
    )
    assert payload["tester"]["chartui_override_reason"] == (
        "DISABLED_IN_NONVISUAL_TESTER_FOR_PERFORMANCE; "
        "NO_SIGNAL_OR_EXECUTION_SEMANTICS"
    )


def test_local_rules_include_and_its_inputs_are_in_the_transitive_closure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    paths, _external = freeze.repo_include_closure()
    assert freeze.RULES_SOURCE.resolve() in paths
    original_reader = freeze._read_source

    def with_synthetic_rules_input(path: Path) -> str:
        text = original_reader(path)
        if path.resolve() == freeze.RULES_SOURCE.resolve():
            return text + "\ninput int synthetic_rules_input = 1;\n"
        return text

    try:
        monkeypatch.setattr(freeze, "_read_source", with_synthetic_rules_input)
        freeze.repo_include_closure.cache_clear()
        freeze.framework_include_closure.cache_clear()
        freeze.local_strategy_include_closure.cache_clear()
        freeze.visible_input_names.cache_clear()
        assert "synthetic_rules_input" in freeze.visible_input_names()
    finally:
        freeze.repo_include_closure.cache_clear()
        freeze.framework_include_closure.cache_clear()
        freeze.local_strategy_include_closure.cache_clear()
        freeze.visible_input_names.cache_clear()


def test_oaat_star_is_13_per_market_and_changes_only_one_axis() -> None:
    for kind, center in (("index", freeze.A_CENTER), ("fx", freeze.B_CENTER)):
        variants = freeze.variants(kind)
        assert len(variants) == 13
        assert variants[0] == ("center", None, None)
        assert len({name for name, _parameter, _value in variants}) == 13
        for name, parameter, value in variants[1:]:
            assert name != "center"
            assert parameter in center
            changed = dict(center)
            changed[parameter] = value
            assert sum(changed[key] != center[key] for key in center) == 1
    assert sum(len(freeze.variants(kind)) for *_rest, kind in freeze.MARKETS) == 52


def test_sleeve_b_is_pooled_london_only_with_one_symbol_day_budget() -> None:
    payload = protocol()
    oaat = payload["oaat"]
    assert oaat["sleeve_b_binding_aggregation"] == (
        "EURUSD_GBPUSD_POOLED_LONDON_LONG_SHORT"
    )
    assert oaat["sleeve_b_budget_policy"] == (
        "MAX_ONE_CONSUMED_ATTEMPT_AND_ONE_FILL_PER_SYMBOL_NY_DAY_SHARED_ACROSS_DIRECTIONS"
    )
    assert oaat["mandatory_report_cells"]["B"] == [
        "EURUSD_LONDON_LONG",
        "EURUSD_LONDON_SHORT",
        "GBPUSD_LONDON_LONG",
        "GBPUSD_LONDON_SHORT",
    ]
    assert all("_NY_" not in cell for cell in oaat["mandatory_report_cells"]["B"])
    freeze.validate_protocol(payload)
    drifted = copy.deepcopy(payload)
    drifted["oaat"]["mandatory_report_cells"]["B"].append("EURUSD_NY_LONG")
    with pytest.raises(freeze.FreezeError, match="daily-budget contract drifted"):
        freeze.validate_protocol(drifted)


def test_dev_smoke_is_separately_fenced_and_cannot_count_as_dev() -> None:
    payload = protocol()
    smoke = next(row for row in payload["phases"] if row["id"] == "DEV_SMOKE_2022")
    assert smoke["nonbinding"] is True
    assert smoke["may_satisfy_phase_verdict_gate"] is False
    assert smoke["minimum_trades"] == 0
    assert smoke["allowed_symbols"] == ["NDX.DWX", "GBPUSD.DWX", "EURUSD.DWX"]
    fence.validate_request(
        payload,
        phase_id="DEV_SMOKE_2022",
        symbol="NDX.DWX",
        timeframe="M1",
        variant="center",
        from_date="2022-01-01",
        to_date="2022-12-31",
    )
    with pytest.raises(fence.FenceError, match="not allowed"):
        fence.validate_request(
            payload,
            phase_id="DEV_SMOKE_2022",
            symbol="GDAXI.DWX",
            timeframe="M1",
            variant="center",
            from_date="2022-01-01",
            to_date="2022-12-31",
        )
    fence.validate_request(
        payload,
        phase_id="DEV_SMOKE_2022",
        symbol="EURUSD.DWX",
        timeframe="M5",
        variant="center",
        from_date="2022-01-01",
        to_date="2022-12-31",
    )
    with pytest.raises(fence.FenceError, match="partition mismatch"):
        fence.validate_request(
            payload,
            phase_id="DEV_SMOKE_2022",
            symbol="NDX.DWX",
            timeframe="M1",
            variant="center",
            from_date="2021-01-01",
            to_date="2022-12-31",
        )


def test_dev_allows_frozen_unresolved_cost_status_but_oos_blocks() -> None:
    payload = protocol()
    fence.validate_request(
        payload,
        phase_id="DEV",
        symbol="NDX.DWX",
        timeframe="M1",
        variant="pivot_low",
        from_date="2021-01-01",
        to_date="2022-12-31",
    )
    with pytest.raises(fence.FenceError, match="unresolved cost axes"):
        fence.validate_request(
            payload,
            phase_id="OOS_2023_H1",
            symbol="NDX.DWX",
            timeframe="M1",
            variant="center",
            from_date="2023-01-01",
            to_date="2023-06-30",
        )
    with pytest.raises(fence.FenceError, match="OAAT_NEIGHBOUR_FORBIDDEN"):
        fence.validate_request(
            payload,
            phase_id="OOS_2023_H1",
            symbol="NDX.DWX",
            timeframe="M1",
            variant="pivot_low",
            from_date="2023-01-01",
            to_date="2023-06-30",
        )


def test_prospective_phase_cannot_be_misused_as_a_retrospective_tester_run() -> None:
    payload = protocol()
    with pytest.raises(fence.FenceError, match="FORWARD_ONLY_PHASE"):
        fence.validate_request(
            payload,
            phase_id="PROSPECTIVE_OPERATIONAL",
            symbol="NDX.DWX",
            timeframe="M1",
            variant="center",
            from_date="2026-07-20",
            to_date="2027-07-17",
        )


def test_retrospective_holdout_stays_blocked_until_missing_tick_months_are_verified() -> None:
    payload = protocol()
    phase = next(row for row in payload["phases"] if row["id"] == "RETRO_HOLDOUT_2026_H1")
    assert phase["data_availability"] == (
        "BLOCKED_MISSING_VERIFIED_MODEL4_TICKS_202605_202606"
    )
    with pytest.raises(fence.FenceError, match="PHASE_DATA_UNAVAILABLE"):
        fence.validate_request(
            payload,
            phase_id="RETRO_HOLDOUT_2026_H1",
            symbol="NDX.DWX",
            timeframe="M1",
            variant="center",
            from_date="2026-01-01",
            to_date="2026-06-30",
        )


def test_mutable_2026_history_is_excluded_without_weakening_tick_or_phase_fences(
    tmp_path: Path,
) -> None:
    payload = protocol()
    model4 = payload["model4_data"]
    assert model4["history_frozen_through_year"] == 2025
    assert model4["frozen_through_month"] == "202604"
    assert model4["history_current_year_policy"] == (
        "EXCLUDE_MUTABLE_2026_HCC_WHILE_ALL_2026_RESEARCH_IS_BLOCKED_OR_FORWARD_ONLY"
    )

    destination = tmp_path / "Bases"
    relative_paths = [
        "symbols.custom.dat",
        "Custom/history/NDX.DWX/2025.hcc",
        *(f"Custom/ticks/NDX.DWX/2026{month:02d}.tkc" for month in range(1, 5)),
        "Custom/ticks/NDX.DWX/202512.tkc",
    ]
    manifest_path = tmp_path / "provisioning.csv"
    rows: list[dict[str, str]] = []
    for index, relative in enumerate(relative_paths):
        artifact = destination / relative
        artifact.parent.mkdir(parents=True, exist_ok=True)
        content = f"frozen-{index}".encode("ascii")
        artifact.write_bytes(content)
        rows.append(
            {
                "relative_path": relative,
                "dest_length": str(len(content)),
                "dest_sha256": hashlib.sha256(content).hexdigest(),
            }
        )
    with manifest_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=["relative_path", "dest_length", "dest_sha256"]
        )
        writer.writeheader()
        writer.writerows(rows)

    scoped_protocol = {
        "model4_data": {
            **model4,
            "destination_root": str(destination),
            "provisioning_manifest_artifact_id": "provisioning",
        },
        "markets": [{"symbol": "NDX.DWX", "dev_from": "2025-12-01"}],
    }
    frozen_rows = freeze.model4_data_files(
        scoped_protocol, {"provisioning": manifest_path}
    )
    frozen_relatives = {str(row["relative_path"]) for row in frozen_rows}
    assert "Custom/history/NDX.DWX/2025.hcc" in frozen_relatives
    assert "Custom/history/NDX.DWX/2026.hcc" not in frozen_relatives
    assert "Custom/ticks/NDX.DWX/202604.tkc" in frozen_relatives

    synthetic_manifest = {"freeze_inputs": {"model4_data_files": frozen_rows}}
    with pytest.raises(fence.FenceError, match=r"2026\.hcc"):
        fence._selected_data_rows(
            scoped_protocol,
            synthetic_manifest,
            "NDX.DWX",
            "2026-01-01",
            "2026-04-30",
        )


def test_history_cutoff_cannot_precede_any_runnable_binding_phase() -> None:
    payload = protocol()
    freeze.validate_protocol(payload)
    drifted = copy.deepcopy(payload)
    drifted["model4_data"]["history_frozen_through_year"] = 2024
    with pytest.raises(freeze.FreezeError, match="Model-4 provisioning/fence contract drifted"):
        freeze.validate_protocol(drifted)


def test_oos_unlock_requires_the_nested_adjudicator_dev_verdict(tmp_path: Path) -> None:
    payload = protocol()
    freeze_root = "a" * 64
    manifest_sha = "b" * 64
    with pytest.raises(fence.FenceError, match="required prior verdict is missing"):
        fence.validate_phase_unlock(
            payload,
            phase_id="OOS_2023_H1",
            freeze_inputs_sha256=freeze_root,
            manifest_sha256=manifest_sha,
            verdict_root=tmp_path,
        )
    fields = set(payload["phase_unlock"]["required_record_fields"])
    assert {"freeze_identity", "inventory_binding", "evidence_binding", "created_utc"} <= fields
    assert {
        "binding",
        "freeze_inputs_sha256",
        "manifest_sha256",
        "evidence_sha256",
        "completed_utc",
    }.isdisjoint(fields)


def test_nonbinding_smoke_is_not_in_any_unlock_prerequisites() -> None:
    unlocks = protocol()["phase_unlock"]["required_prior_verdicts"]
    assert all("DEV_SMOKE_2022" not in prerequisites for prerequisites in unlocks.values())
    assert unlocks["RETRO_HOLDOUT_2026_H1"][-6:] == [
        "OOS_2023_H1",
        "OOS_2023_H2",
        "OOS_2024_H1",
        "OOS_2024_H2",
        "OOS_2025_H1",
        "OOS_2025_H2",
    ]


def test_freeze_bundle_is_deterministic_and_manifest_never_hashes_itself(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    payload = protocol()
    frozen_inputs = {
        "schema_version": 2,
        "protocol_id": payload["protocol_id"],
        "contract_freeze": payload["contract_freeze"],
        "source_hashes": {
            "ea_sha256": "1" * 64,
            "rules_sha256": "2" * 64,
            "contract_sha256": "3" * 64,
            "spec_sha256": "4" * 64,
            "protocol_sha256": "5" * 64,
            "generator_sha256": "6" * 64,
            "validator_sha256": "7" * 64,
        },
        "evidence_artifacts": [{"id": "ea_binary", "sha256": "8" * 64}],
        "framework_includes": [],
        "framework_include_tree_sha256": "9" * 64,
        "local_strategy_includes": [],
        "local_strategy_include_tree_sha256": "a" * 64,
        "external_compiler_includes": [],
        "model4_data_files": [],
        "model4_data_tree_sha256": "b" * 64,
        "cost_axis_status": {"slippage": "UNRESOLVED", "overnight_swap_proof": "UNRESOLVED"},
    }
    monkeypatch.setattr(freeze, "build_freeze_inputs", lambda *_args, **_kwargs: frozen_inputs)
    files_a, manifest_a = freeze.expected_files(payload)
    files_b, manifest_b = freeze.expected_files(payload)
    assert files_a == files_b
    assert manifest_a == manifest_b
    assert len(files_a) == 52
    parsed = json.loads(manifest_a)
    assert "manifest_sha256" not in parsed
    detached = freeze.detached_manifest_sha256(manifest_a).decode("ascii").strip().split()
    assert detached == [hashlib.sha256(manifest_a).hexdigest(), "manifest.json"]
    changed = copy.deepcopy(frozen_inputs)
    changed["source_hashes"]["validator_sha256"] = "c" * 64
    monkeypatch.setattr(freeze, "build_freeze_inputs", lambda *_args, **_kwargs: changed)
    _files_c, manifest_c = freeze.expected_files(payload)
    assert manifest_c != manifest_a


def test_missing_evidence_fails_before_generation() -> None:
    payload = protocol()
    payload["evidence_artifacts"].append(
        {"id": "aaa_mandatory_missing", "path": "missing/freeze/evidence.bin", "validation": "NONEMPTY"}
    )
    with pytest.raises(freeze.FreezeError, match="mandatory evidence artifact missing"):
        freeze.evidence_hashes(payload)


def test_final_compile_provisioning_and_slippage_evidence_hashes_are_pinned() -> None:
    artifacts = {row["id"]: row for row in protocol()["evidence_artifacts"]}
    assert artifacts["ea_binary"]["expected_sha256"] == (
        "2b1d663fb032bd516a007dd5eee1973d9a53cb2f80d0d5cb875ed342a247fcb0"
    )
    assert artifacts["ea_binary_repo"]["expected_sha256"] == artifacts["ea_binary"][
        "expected_sha256"
    ]
    assert artifacts["compile_evidence"]["expected_sha256"] == (
        "c04d7ee5f5c6aad1e0a8df524b0c578393f5022ff6897221e8a43437ad293cb1"
    )
    assert artifacts["provisioning_tick_hash_manifest"]["expected_sha256"] == (
        "65cb423348fbe1e5f04d99d9594bef80ed303ec52f6d8ad0d225fa86e4d1235c"
    )
    assert artifacts["slippage_livefill_ledger"]["expected_sha256"] == (
        "722db3646826dd793d905bad1ae4efe9ed859286255ae2907837a18da329fa90"
    )
    assert artifacts["report_cost_auditor"]["path"].endswith("/tools/audit_mt5_report.py")


def test_commission_is_external_dealwise_and_double_counting_fails_closed() -> None:
    commission = protocol()["costs"]["commission"]
    assert commission["status"] == "RESOLVED"
    assert commission["execution_model"] == (
        "RAW_TESTER_ZERO_PLUS_AUTHORITATIVE_EXTERNAL_POSTPROCESSOR"
    )
    assert commission["raw_tester_commission_required"] == 0.0
    assert commission["runner_commission_per_lot_required"] == 0.0
    assert commission["runner_commission_per_side_native_required"] == 0.0
    assert commission["ea_sim_commission_required"] == 0.0
    assert commission["double_count_guard"] == "REJECT_ANY_NONZERO_NATIVE_REPORT_COMMISSION"
    assert commission["symbols"]["NDX.DWX"]["per_side_usd"] == 2.75
    assert commission["symbols"]["GDAXI.DWX"]["per_side_usd"] == 3.5
    assert commission["symbols"]["GBPUSD.DWX"]["conversion"] == "DEAL_PRICE_BASE_TO_USD"


def test_compiled_magic_resolver_is_a_fixed_blob_with_only_foreign_append_drift() -> None:
    payload = protocol()
    assert payload["compiled_source_snapshot_exceptions"] == [
        freeze.EXPECTED_MAGIC_EXCEPTION
    ]
    blob = freeze._git_blob_bytes(freeze.EXPECTED_MAGIC_EXCEPTION["compiled_git_blob_sha1"])
    assert hashlib.sha256(blob).hexdigest() == freeze.EXPECTED_MAGIC_EXCEPTION["compiled_sha256"]
    compiled_rows, compiled_skeleton = freeze._magic_resolver_rows_and_skeleton(blob)
    active = (freeze.REPO_ROOT / freeze.MAGIC_RESOLVER_PATH).read_bytes()
    active_rows, active_skeleton = freeze._magic_resolver_rows_and_skeleton(active)
    assert active_skeleton == compiled_skeleton
    assert active_rows[: len(compiled_rows)] == compiled_rows
    assert tuple(row for row in compiled_rows if row[0] == 20009) == freeze.TARGET_MAGIC_ROWS


def test_selected_model4_data_is_rehashed_by_content_pre_and_post(tmp_path: Path) -> None:
    payload = protocol()
    payload["model4_data"]["destination_root"] = str(tmp_path)
    relative = "Custom/ticks/NDX.DWX/202201.tkc"
    path = tmp_path / relative
    path.parent.mkdir(parents=True)
    path.write_bytes(b"abcd")
    row = {"relative_path": relative, "size": 4, "sha256": hashlib.sha256(b"abcd").hexdigest()}
    assert fence.rehash_selected_data(payload, [row])[0]["sha256"] == row["sha256"]
    path.write_bytes(b"abce")
    with pytest.raises(fence.FenceError, match="hash drift"):
        fence.rehash_selected_data(payload, [row])


def test_runner_chain_is_frozen_and_commission_groups_restore_in_finally() -> None:
    payload = protocol()
    artifacts = {row["id"]: row["path"] for row in payload["evidence_artifacts"]}
    assert artifacts["runner_run_smoke"] == "framework/scripts/run_smoke.ps1"
    assert artifacts["runner_run_dev1_smoke"] == "framework/scripts/run_dev1_smoke.ps1"
    assert artifacts["runner_invoke_dev1_smoke_task"] == (
        "framework/scripts/invoke_dev1_smoke_task.ps1"
    )
    runner = (freeze.REPO_ROOT / artifacts["runner_run_smoke"]).read_text(encoding="utf-8-sig")
    assert "injected_sha256=" in runner
    assert "} finally {" in runner
    assert "commissionGroupRestoreEvidence = Set-TesterGroupsCommission" in runner
    assert "restored_to_canonical" in runner


def test_only_hash_bound_research_launcher_receipts_are_admissible_run_evidence() -> None:
    payload = protocol()
    launcher = payload["research_launcher"]
    assert launcher["accepted_receipt_artifact_type"] == (
        "QM5_20009_FAIL_CLOSED_RESEARCH_LAUNCHER_RECEIPT"
    )
    assert launcher["direct_runner_output_is_verdict_evidence"] is False
    assert launcher["fixed_model"] == 4
    assert launcher["fixed_deposit"] == 100000
    assert launcher["fixed_currency"] == "USD"
    assert launcher["commission_per_lot"] == 0.0
    assert launcher["commission_per_side_native"] == 0.0
    assert launcher["binding_duplicate_count"] == 2
    assert launcher["diagnostic_smoke_duplicate_count"] == 1
    artifacts = {row["id"]: row["path"] for row in payload["evidence_artifacts"]}
    assert artifacts["research_launcher"] == launcher["entrypoint"]
    assert artifacts["research_launcher_support"] == launcher["support_module"]
