from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm.artifact_identity import (
    extract_identity,
    identity_update_clause,
    prepare_completion,
)


FIXTURE_PATH = Path(__file__).with_name("fixtures") / "artifact_identity_live_payloads_20260823.json"


@pytest.fixture(scope="module")
def live_payloads() -> dict[str, dict]:
    return json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))


@pytest.mark.parametrize("phase", ["Q02", "Q03", "Q04", "Q07", "Q09"])
def test_live_phase_payload_shapes_have_a_real_binding(
    live_payloads: dict[str, dict], phase: str
) -> None:
    case = live_payloads[phase]
    identity = extract_identity(case["summary"], case["payload"])
    assert case["source_work_item_id"]
    assert identity["ex5_sha256"] is not None
    assert identity["data_window_start"] is not None
    assert identity["data_window_end"] is not None


def test_q04_aggregate_top_level_hashes_are_materialised(live_payloads: dict[str, dict]) -> None:
    case = live_payloads["Q04"]
    identity = extract_identity(case["summary"], case["payload"])
    assert identity["ex5_sha256"] == case["summary"]["ex5_sha256"]
    assert identity["setfile_sha256"] == case["summary"]["setfile_sha256"]


def test_q10_news_input_manifest_shape_is_materialised(live_payloads: dict[str, dict]) -> None:
    manifest = live_payloads["Q10_NEWS"]["input_manifest"]
    identity = extract_identity(manifest)
    assert identity == {
        "ex5_sha256": manifest["identities"]["ex5_sha256"],
        "setfile_sha256": manifest["identities"]["baseline_setfile_sha256"],
        "mq5_sha256": None,
        "include_closure_sha256": manifest["identities"]["include_closure_sha256"],
        "build_id": None,
        "data_window_start": manifest["windows"]["selection_from_utc"],
        "data_window_end": manifest["windows"]["selection_to_utc"],
        "news_calendar_sha256": manifest["calendar_bundle"]["content_sha256"],
    }


def test_q10_news_hash_pinned_plan_sidecar_is_followed(
    live_payloads: dict[str, dict], tmp_path: Path
) -> None:
    case = live_payloads["Q10_NEWS"]
    manifest_path = tmp_path / "input_manifest.json"
    manifest_path.write_text(
        json.dumps(case["input_manifest"], sort_keys=True), encoding="utf-8"
    )
    manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    plan = {
        "input_manifest_path": str(manifest_path),
        "input_manifest_sha256": manifest_sha,
    }
    plan_path = tmp_path / "run_plan.json"
    plan_path.write_text(json.dumps(plan, sort_keys=True), encoding="utf-8")
    payload = {
        "q09_run_plan_path": str(plan_path),
        "q09_run_plan_file_sha256": hashlib.sha256(plan_path.read_bytes()).hexdigest(),
    }

    verdict, taxonomy, identity, missing = prepare_completion(
        phase="Q10_NEWS",
        kind="backtest",
        payload=payload,
        summary=case["summary"],
        verdict="REVIEW_REQUIRED",
        taxonomy="strategy",
    )

    assert (verdict, taxonomy, missing) == ("REVIEW_REQUIRED", "strategy", ())
    assert identity["include_closure_sha256"] == case["input_manifest"]["identities"][
        "include_closure_sha256"
    ]
    assert identity["news_calendar_sha256"] == case["input_manifest"]["calendar_bundle"][
        "content_sha256"
    ]


def test_28e0bc81_regression_keeps_economic_verdict_and_stamps_identity(
    live_payloads: dict[str, dict]
) -> None:
    case = live_payloads["Q09"]
    payload = dict(case["payload"])
    verdict, taxonomy, identity, missing = prepare_completion(
        phase="Q09",
        kind="backtest",
        payload=payload,
        summary=case["summary"],
        verdict="PASS",
        taxonomy="strategy",
    )
    assert case["source_work_item_id"] == "28e0bc81-ed4e-4bfa-918f-3c66d3c890a0"
    assert (verdict, taxonomy, missing) == ("PASS", "strategy", ())
    assert identity["ex5_sha256"] == case["summary"]["evidence_identity"]["ex5_sha256"]
    assert identity["setfile_sha256"] == case["summary"]["evidence_identity"][
        "setfile_sha256"
    ]
    assert identity["data_window_start"] == "2017.01.01"
    assert identity["data_window_end"] == "2025.12.31"
    assert payload.get("verdict_reason") != "ARTIFACT_IDENTITY_MISSING"


def test_partial_identity_keeps_economic_verdict(live_payloads: dict[str, dict]) -> None:
    case = live_payloads["Q07"]
    payload = dict(case["payload"])
    verdict, taxonomy, identity, missing = prepare_completion(
        phase="Q07",
        kind="backtest",
        payload=payload,
        summary=case["summary"],
        verdict="PASS",
        taxonomy="strategy",
    )
    assert (verdict, taxonomy, missing) == ("PASS", "strategy", ())
    assert identity["ex5_sha256"] is not None
    assert identity["setfile_sha256"] is None
    assert "setfile_sha256" in payload["artifact_identity_partial_missing_fields"]


def test_nested_spawn_binding_and_build_hash_alias_are_copied() -> None:
    identity = extract_identity({
        "spawn_binding": {
            "expected_ex5_sha256": "a" * 64,
            "expected_setfile_sha256": "b" * 64,
            "expected_from_date": "2017.01.01",
            "expected_to_date": "2022.12.31",
            "build_hash": "build-42",
        }
    })
    assert identity["ex5_sha256"] == "a" * 64
    assert identity["setfile_sha256"] == "b" * 64
    assert identity["build_id"] == "build-42"


def test_identity_update_clause_does_not_null_unresolved_columns() -> None:
    con = sqlite3.connect(":memory:")
    con.execute(
        "CREATE TABLE work_items(ex5_sha256 TEXT,setfile_sha256 TEXT,"
        "verdict_taxonomy TEXT)"
    )
    clause, values = identity_update_clause(
        con,
        {"ex5_sha256": "a" * 64, "setfile_sha256": None},
        "strategy",
    )
    assert clause == "ex5_sha256=?, verdict_taxonomy=?"
    assert values == ["a" * 64, "strategy"]
    con.close()
