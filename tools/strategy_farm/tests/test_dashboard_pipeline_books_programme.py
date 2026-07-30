from __future__ import annotations

from pathlib import Path

from tools.strategy_farm.dashboards import render_dashboards as dashboard


SHA_A = "a" * 64
SHA_B = "b" * 64
SHA_C = "c" * 64


def _fresh_snapshot() -> dict:
    return {
        "state": "FRESH",
        "valid": True,
        "error": "",
        "config_as_of_utc": "2026-07-29T18:00:00Z",
        "age_hours": 1.5,
        "safety": {
            "factory_state": "INTENTIONALLY_OFF",
            "statement": "Source status only; no runtime authority.",
        },
        "bindings": {
            "plan": {"file_sha256": SHA_A},
            "evidence": {"file_sha256": SHA_B},
            "test_lanes": {"file_sha256": SHA_C},
            "q08_policy": {"canonical_sha256": SHA_A},
        },
        "work_packages": [
            {
                "id": "W1",
                "title": "Canonical contracts and execution identity",
                "source_status": "FOUNDATION_SOURCE_IMPLEMENTED",
                "runtime_status": "NOT_WIRED",
                "next_action": "Wire the transactional execution bundle.",
            },
            {
                "id": "W2",
                "title": "Strategy Card V3 and experiment ledger",
                "source_status": "FOUNDATION_SOURCE_IMPLEMENTED",
                "runtime_status": "NOT_PERSISTED",
                "next_action": "Persist append-only governance records.",
            },
        ],
        "q08_v3": {
            "lifecycle": "SHADOW_ONLY",
            "promotion_state": "NOT_OWNER_APPROVED",
            "canonical_q08_unchanged": True,
            "policy_canonical_sha256": SHA_A,
            "verdict_states": [
                "SUPPORTED",
                "CONDITIONAL",
                "INSUFFICIENT",
                "CONTRADICTED",
                "INVALID",
            ],
            "evidence_semantics": "Missing evidence cannot become a clean pass.",
        },
        "target_lanes": [
            {
                "lane_id": "DXZ_BETTER_BOOK",
                "label": "Darwinex Zero better book",
                "state": "RESEARCH_RULEPACK_ONLY",
                "rulepack_id": "DXZ_BETTER_BOOK_V1",
                "rulepack_canonical_sha256": SHA_B,
                "eligibility": "NOT_EVALUATED",
                "deployment_authority": "NONE",
                "next_action": "Build a frozen challenger dossier.",
            },
            {
                "lane_id": "FTMO_2S_100K_SWING",
                "label": "FTMO two-step swing",
                "state": "RESEARCH_RULEPACK_ONLY",
                "rulepack_id": "FTMO_2S_100K_SWING_V1",
                "rulepack_canonical_sha256": SHA_C,
                "eligibility": "NOT_EVALUATED",
                "deployment_authority": "NONE",
                "next_action": "Run a prospective free-trial shadow.",
            },
        ],
        "ftmo_book3_runtime_evaluation": {
            "evidence_class": "RESEARCH_ONLY_RUNTIME_PROJECTION",
            "book_id": "FTMO_BOOK3_STANDALONE_R0_R1_R2",
            "status": "RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED",
            "source_manifest_sha256": SHA_A,
            "source_receipt_sha256": SHA_B,
            "readiness": {
                "input_integrity": "PASS",
                "native_stream_reconciliation": "PASS",
                "shared_account_model": "COMPLETE_RESEARCH_ONLY",
                "strict_qualification": "UNVERIFIED",
                "money_gate": "SETUP_DATA_MISSING",
                "paid_challenge": "NO_GO",
            },
            "native_runs": [
                {
                    "rung": "R0",
                    "ea_id": 9936,
                    "symbol": "USDJPY.DWX",
                    "trades": 1143,
                    "lifecycle_mismatches": 0,
                    "reconciliation": "PASS",
                },
                {
                    "rung": "R1",
                    "ea_id": 10145,
                    "symbol": "XAUUSD.DWX",
                    "trades": 291,
                    "lifecycle_mismatches": 0,
                    "reconciliation": "PASS",
                },
                {
                    "rung": "R2",
                    "ea_id": 13108,
                    "symbol": "XTIUSD.DWX",
                    "trades": 548,
                    "lifecycle_mismatches": 0,
                    "reconciliation": "PASS",
                },
            ],
            "policy_bootstrap": {
                "paths": 25000,
                "phase1_pass_percent": "67.240%",
                "two_phase_pass_percent": "44.896%",
                "official_breach_percent": "33.456%",
            },
            "temporal_holdout_diagnostic": {
                "starts": 102,
                "phase1_pass_percent": "84.31%",
                "two_phase_pass_percent": "81.37%",
                "official_breach_percent": "3.92%",
            },
        },
        "verification_lanes": {
            "green": {
                "state": "PASS",
                "passed": 2834,
                "skipped": 1,
                "deselected": 5,
                "subtests_passed": 34,
            },
            "external_residual": {
                "state": "EXPECTED_FAIL_CLOSED",
                "expected_count": 1,
                "items": [
                    {
                        "node_id": "tests/test_external.py::test_dxz10939",
                        "label": "DXZ10939 binding",
                        "owner_items": ["MNT-021"],
                    }
                ],
                "exit_condition": "OWNER amendment plus exact hashes.",
            },
        },
        "owner_blockers": [
            {
                "id": "OWNER-DXZ-AMENDMENT",
                "title": "DXZ binding amendments",
                "safe_default": "Keep the residual red.",
                "blocks": ["W7", "W8"],
            }
        ],
    }


def test_fresh_programme_renders_orthogonal_status_without_promotion_claim() -> None:
    page = dashboard.render_pipeline_books_program_status(_fresh_snapshot())

    for dimension in (
        "Execution status",
        "Evidence strength",
        "Economic merit",
        "Target eligibility",
        "Promotion decision",
    ):
        assert dimension in page
    for verdict in (
        "SUPPORTED",
        "CONDITIONAL",
        "INSUFFICIENT",
        "CONTRADICTED",
        "INVALID",
    ):
        assert verdict in page
    assert "DXZ_BETTER_BOOK_V1" in page
    assert "FTMO_2S_100K_SWING_V1" in page
    assert "eligibility NOT_EVALUATED" in page
    assert "deploy NONE" in page
    assert "Canonical contracts and execution identity" in page
    assert "Strategy Card V3 and experiment ledger" in page
    assert "FTMO Book 3 · hash-bound recorded research projection" in page
    assert "RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED" in page
    assert "QM5_9936" in page and "1143 native trades" in page
    assert "QM5_10145" in page and "291 native trades" in page
    assert "QM5_13108" in page and "548 native trades" in page
    assert page.count("0 lifecycle mismatches") == 3
    assert "Policy bootstrap · NON-GATE-ELIGIBLE" in page
    assert "67.240%" in page and "44.896%" in page and "33.456%" in page
    assert "Temporal holdout diagnostic · NON-GATE-ELIGIBLE" in page
    assert "84.31%" in page and "81.37%" in page and "3.92%" in page
    assert "Research results are not purchase- or deploy-eligible" in page
    assert "this dashboard does not revalidate D: runtime files" in page
    assert "external residual EXPECTED_FAIL_CLOSED" in page
    assert "DXZ10939 binding" in page
    assert "Legacy Q08" in page


def test_invalid_programme_fails_closed_and_suppresses_untrusted_claims() -> None:
    page = dashboard.render_pipeline_books_program_status(
        {
            **_fresh_snapshot(),
            "state": "INVALID",
            "valid": False,
            "error": "hash mismatch <unsafe>",
        }
    )

    assert "INVALID" in page
    assert "hash mismatch &lt;unsafe&gt;" in page
    assert "No Q08-v3 evidence" in page
    assert "SUPPORTED" not in page
    assert "DXZ_BETTER_BOOK_V1" not in page
    assert "2834 passed" not in page


def test_stale_programme_keeps_last_validated_values_with_warning() -> None:
    snapshot = _fresh_snapshot()
    snapshot.update(
        {
            "state": "STALE",
            "valid": False,
            "error": "programme status is 49.0h old; maximum is 48h",
        }
    )
    page = dashboard.render_pipeline_books_program_status(snapshot)

    assert "STALE SOURCE" in page
    assert "last strictly validated source snapshot" in page
    assert "DXZ_BETTER_BOOK_V1" in page


def test_renderer_source_uses_canonical_gate_range_and_marks_rescue_legacy() -> None:
    source = Path(dashboard.__file__).read_text(encoding="utf-8")

    assert "14-gate evidence pipeline (Q00-Q13" in source
    assert "15-gate evidence pipeline" not in source
    assert "Q00-Q14" not in source
    assert "Historical portfolio admission · legacy Q08" in source
    assert "highest_pass == \"Q13\"" in source
    assert "highest_pass == \"P8\"" not in source


def test_strategies_only_cli_precedes_all_ancillary_refreshes() -> None:
    source = Path(dashboard.__file__).read_text(encoding="utf-8")
    branch = source.index("if args.strategies_only:")
    metric_refresh = source.index("_refresh_ea_metrics_for_render(root)", branch)
    assert branch < metric_refresh
    body = source[branch:metric_refresh]
    assert 'dashboards_dir / "strategies.html"' in body
    assert "render_strategies(state, root)" in body
    assert "return 0" in body


def test_hourly_renderer_skips_db_refresh_during_factory_off_and_reads_query_only() -> None:
    source = Path(dashboard.__file__).read_text(encoding="utf-8")

    off_check = source.index("if _factory_off_asserted(root):")
    metric_writer = source.index("with sqlite3.connect(db_for_metrics)", off_check)

    assert off_check < metric_writer
    assert "FACTORY_OFF asserted; ea_metrics DB refresh skipped" in source
    assert source.count("sqlite3.connect(db_for_metrics)") == 1
    assert source.count("with _connect_readonly(") >= 9
    assert 'connection.execute("PRAGMA query_only=ON")' in source


def test_factory_off_probe_is_true_for_present_flag(tmp_path: Path) -> None:
    state = tmp_path / "state"
    state.mkdir()
    (state / "FACTORY_OFF.flag").write_text("OFF\n", encoding="utf-8")

    assert dashboard._factory_off_asserted(tmp_path) is True


def test_factory_off_metric_refresh_never_opens_sqlite(tmp_path: Path, monkeypatch) -> None:
    state = tmp_path / "state"
    state.mkdir()
    (state / "FACTORY_OFF.flag").write_text("OFF\n", encoding="utf-8")

    def forbidden_connect(*_args, **_kwargs):
        raise AssertionError("SQLite writer must not open while Factory is OFF")

    monkeypatch.setattr(dashboard.sqlite3, "connect", forbidden_connect)

    assert dashboard._refresh_ea_metrics_for_render(tmp_path) == {
        "refreshed": False,
        "reason": "FACTORY_OFF",
    }


def test_archive_q08_work_item_verdicts_stay_distinct_from_v3_evidence() -> None:
    assert dashboard._archive_verdict_text("Q08", "PASS") == "LEGACY PASS"
    assert dashboard._archive_verdict_text("Q08", "FAIL_SOFT") == "LEGACY FAIL_SOFT"
    assert dashboard._archive_verdict_text("Q07", "PASS") == "PASS"
