from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

from tools.strategy_farm import live_book_pulse
from tools.strategy_farm import live_observability_contract as obs
from tools.strategy_farm import mission_control_v2_data as mission_control

# morning_brief imports sibling modules by direct name; importing after the
# package modules mirrors its production script environment.
from tools.strategy_farm import morning_brief


NOW = dt.datetime(2026, 8, 22, 12, 0, tzinfo=dt.timezone.utc)


def _iso(value: dt.datetime) -> str:
    return value.isoformat().replace("+00:00", "Z")


def _write(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")


def _producer_fixture(tmp_path: Path, *, dd_age_sec: int = 30) -> tuple[dict, Path, Path, Path]:
    manifest_path = tmp_path / "manifest.json"
    manifest = {
        "book": "DXZ_4000090541",
        "status": "LIVE",
        "generated_at": _iso(NOW - dt.timedelta(minutes=2)),
        "n_sleeves": 1,
        "sleeves": [
            {"ea_id": 10001, "symbol": "EURUSD.DWX", "magic_number": 100010000}
        ],
    }
    _write(manifest_path, manifest)
    manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()

    roster = [{"ea_id": 10001, "symbol": "EURUSD.DWX", "magic_number": 100010000}]
    sleeve_sha = hashlib.sha256(
        json.dumps(roster, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    pointer_path = tmp_path / "pointer.json"
    _write(pointer_path, {
        "schema_version": "qm.live_deployment_pointer.v1",
        "written_at_utc": _iso(NOW - dt.timedelta(seconds=15)),
        "manifest_path": str(manifest_path),
        "manifest_sha256": manifest_sha,
        "expected_account": "4000090541",
        "expected_server": "Darwinex-Live",
        "expected_phase": "DXZ_LIVE",
        "expected_sleeves": {"count": 1, "identity_sha256": sleeve_sha, "roster": roster},
    })

    dd_generated = NOW - dt.timedelta(seconds=dd_age_sec)
    dd_guard_path = tmp_path / "dd_guard.json"
    _write(dd_guard_path, {
        "account_login": 4000090541,
        "equity_source": "account_snapshot",
        "equity_observed_at_utc": _iso(dd_generated - dt.timedelta(seconds=5)),
        "last_run_utc": _iso(dd_generated),
        "last_equity": 99_000.0,
        "last_balance": 99_000.0,
        "last_free_margin": 99_000.0,
        "last_dd_pct": 2.8,
        "halt_dd_pct": 10.0,
        "breached": False,
    })

    pulse = {
        "schema_version": 2,
        "generated_at_utc": _iso(NOW),
        "verdict": "OK",
        "alarms": [],
        "book_manifest": {
            "path": str(manifest_path),
            "sha256": manifest_sha,
            "book": "DXZ_4000090541",
            "status": "LIVE",
            "expected_sleeve_count": 1,
        },
        "deploy_pointer_reconciliation": {"match": True},
        "manifest_reconcile": {"expected_count": 1, "mismatch_count": 0},
        "preset_consistency": {"mismatch_count": 0, "missing_loaded_count": 0},
        "terminal_journals": {
            "account_id": "4000090541",
            "loaded_sleeve_count": 1,
            "last_terminal_sync": {"positions": 0, "orders": 0},
        },
        "heartbeat": {
            "last_journal_write_utc": _iso(NOW),
            "latest_scan_finished": {"at_utc": _iso(NOW)},
            "position_exposed": False,
            "alarm": False,
        },
    }
    return pulse, pointer_path, dd_guard_path, manifest_path


def _attach_and_write(
    tmp_path: Path,
    *,
    dd_age_sec: int = 30,
) -> tuple[dict, Path]:
    pulse, pointer, dd_guard, manifest = _producer_fixture(
        tmp_path,
        dd_age_sec=dd_age_sec,
    )
    original_verdict = pulse["verdict"]
    live_book_pulse.attach_observability_contract(
        pulse,
        observed_at=NOW,
        pointer_path=pointer,
        dd_guard_path=dd_guard,
        manifest_path=manifest,
    )
    assert pulse["verdict"] == original_verdict
    pulse_path = tmp_path / "pulse.json"
    live_book_pulse.write_json_atomic(pulse_path, pulse)
    return pulse, pulse_path


def test_fresh_wrapper_cannot_turn_stale_subsource_green(tmp_path: Path) -> None:
    pulse, pulse_path = _attach_and_write(tmp_path, dd_age_sec=901)
    # Hostile wrapper claim: a consumer rewrites only the aggregate status while
    # retaining the producer timestamps.  The reader must ignore that claim.
    pulse["observability_contract"]["status"] = "GREEN"
    live_book_pulse.write_json_atomic(pulse_path, pulse)

    refreshed = obs.load_from_pulse(pulse_path, observed_at=NOW + dt.timedelta(seconds=1))

    assert refreshed["status"] == "STALE"
    assert refreshed["sources"]["dd_guard"]["freshness"] == "STALE"
    assert refreshed["sources"]["account_snapshot"]["freshness"] == "STALE"
    for component in refreshed["sources"].values():
        assert set((
            "source_generated_at_utc", "observed_at_utc", "max_age_sec"
        )).issubset(component)


def test_cross_surface_fingerprints_are_identical_and_dd_gap_visible(tmp_path: Path) -> None:
    pulse, pulse_path = _attach_and_write(tmp_path)

    pulse_contract = pulse["observability_contract"]
    _, morning_contract = morning_brief._lamp_observability(
        {"pulse": pulse_path}, NOW
    )
    mission_contract = mission_control._load_live_observability(
        now=NOW,
        pulse_path=pulse_path,
    )

    assert pulse_contract["status"] == "GREEN"
    assert morning_contract["status"] == "GREEN"
    assert mission_contract["status"] == "GREEN"
    assert (
        pulse_contract["fingerprints"]
        == morning_contract["fingerprints"]
        == mission_contract["fingerprints"]
    )
    assert set(pulse_contract["fingerprints"]) == set(obs.FINGERPRINT_NAMES)
    assert pulse_contract["latency"] == {
        "dd_guard_to_account_snapshot_sec": 5,
        "surface_to_dd_guard_sec": 30,
        "dd_guard_gap_visible": True,
    }


def test_mission_control_atomic_writer_leaves_complete_document(tmp_path: Path) -> None:
    output = tmp_path / "mission.json"
    output.write_text('{"old":true}', encoding="utf-8")
    rendered = json.dumps({"schema_version": "fixture", "complete": True}) + "\n"

    mission_control.write_text_atomic(output, rendered)

    assert json.loads(output.read_text(encoding="utf-8"))["complete"] is True
    assert list(tmp_path.glob(".mission.json.*.tmp")) == []

