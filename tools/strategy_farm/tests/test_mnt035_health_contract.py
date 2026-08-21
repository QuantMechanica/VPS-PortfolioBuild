from __future__ import annotations

import json
import sqlite3
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


def test_unwrap_escalation_condition_peels_nested_echo_layers() -> None:
    assert health._unwrap_escalation_condition(
        "FAIL:mt5_worker_saturation:4/10 alive"
    ) == "mt5_worker_saturation"
    assert health._unwrap_escalation_condition(
        "FAIL:task_monitor_escalation:FAIL:task_monitor_escalation:"
        "FAIL:mt5_worker_saturation:4/10 alive"
    ) == "mt5_worker_saturation"
    assert health._unwrap_escalation_condition("not an escalation string") is None
    assert health._unwrap_escalation_condition(None) is None


def test_run_all_dedupes_task_monitor_echo_of_still_native_fail(monkeypatch, tmp_path: Path) -> None:
    """MNT-035: hourly_monitor.ps1's sidecar re-emits farm_health FAILs as
    task_monitor_escalation rows; _external_health_checks folds that sidecar
    back into the next farm_health run. Before the fix, a condition that is
    still natively FAILing (mt5_worker_saturation) was counted twice in
    summary.fail -- once as the native check, once as the echoed sidecar row
    (itself growing one FAIL:task_monitor_escalation: wrapper layer deeper
    every cycle). After the fix only the live native check survives."""
    monkeypatch.setattr(
        health,
        "ALL_CHECKS",
        [("mt5_worker_saturation",
          lambda: health._check("mt5_worker_saturation", "FAIL", 4, 7, "4/10 alive", ""),
          False)],
    )

    def _no_db():
        raise sqlite3.Error("no db in this test")

    monkeypatch.setattr(health, "_connect", _no_db)
    monkeypatch.setattr(
        health,
        "_external_health_checks",
        lambda now=None: [
            contract.check(
                "task_monitor_escalation", "FAIL",
                value="FAIL:task_monitor_escalation:FAIL:mt5_worker_saturation:4/10 alive",
                detail="FAIL:task_monitor_escalation:FAIL:mt5_worker_saturation:4/10 alive",
                source="task_monitor",
            ),
        ],
    )
    monkeypatch.setattr(health, "HEALTH_FILE", tmp_path / "health.json")

    result = health.run_all()
    names = [c["name"] for c in result["checks"]]
    assert names.count("mt5_worker_saturation") == 1
    assert "task_monitor_escalation" not in names
    assert result["summary"]["fail"] == 1
