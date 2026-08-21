from __future__ import annotations

import json
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
STRATEGY_FARM = HERE.parent
if str(STRATEGY_FARM) not in sys.path:
    sys.path.insert(0, str(STRATEGY_FARM))

import health_contract as contract  # noqa: E402
import health  # noqa: E402


def test_historical_intent_contradictions_are_fixed_fixtures() -> None:
    cases = json.loads(
        (HERE / "fixtures" / "mnt035_health_contradictions.json").read_text(encoding="utf-8")
    )
    for case in cases:
        op_intent, result = contract.assess_runtime_intent(
            case["name"],
            expected_state=case["expected_state"],
            running=case["running"],
            maintenance=case["maintenance"],
            probe_ok=case["probe_ok"],
            review_expired=case["review_expired"],
            review_expires_utc="2026-08-20T00:00:00Z",
            source="fixture",
        )
        assert result["status"] == case["expected_status"], case["name"]
        assert op_intent["condition"] == case["expected_condition"], case["name"]
        assert result["intent"] == op_intent


def test_worst_severity_wins_across_disagreeing_surfaces() -> None:
    base = contract.build(
        "farm_health",
        [contract.check("factory", "GREEN", detail="base surface green")],
        checked_at="2026-08-21T10:00:00Z",
    )
    live = contract.build(
        "live_pulse",
        [contract.check("terminal", "ALARM", detail="pulse sees terminal missing")],
    )
    merged = contract.merge(base, live)
    assert merged["overall"] == "FAIL"
    assert merged["summary"] == {"ok": 1, "warn": 0, "fail": 1}
    assert {row["source"] for row in merged["checks"]} == {"farm_health", "live_pulse"}


def test_unknown_status_fails_closed_and_schema_is_exact() -> None:
    payload = contract.build("task_monitor", [{"name": "task", "status": "MYSTERY"}])
    assert payload["schema"] == "qm.health.contract.v1"
    assert payload["overall"] == "FAIL"
    assert payload["checks"][0]["status"] == "FAIL"
    assert set(("name", "status", "value", "threshold", "detail", "action_hint")) <= set(
        payload["checks"][0]
    )


def test_farm_health_reads_registered_contract_sidecar(tmp_path: Path, monkeypatch) -> None:
    sidecar = tmp_path / "pulse.json"
    sidecar.write_text(
        json.dumps(contract.build(
            "fixture_pulse",
            [contract.check("fixture_alarm", "ALARM", detail="historical pulse alarm")],
        )),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        health,
        "EXTERNAL_HEALTH_SURFACES",
        (("fixture_pulse", sidecar, 30, 60, "WARN"),),
    )
    rows = health._external_health_checks()
    assert [row["name"] for row in rows] == ["fixture_pulse_surface", "fixture_alarm"]
    assert rows[0]["status"] == "OK"
    assert rows[1]["status"] == "FAIL"
    assert rows[1]["source"] == "fixture_pulse"
