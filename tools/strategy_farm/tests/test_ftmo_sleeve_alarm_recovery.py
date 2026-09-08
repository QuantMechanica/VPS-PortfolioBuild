import copy
import json
from datetime import datetime, timezone

import pytest

from tools.strategy_farm import ftmo_trial_pulse as pulse


def event(ts, level="INFO", **payload):
    return {"ea_id": 1537, "magic": 15370001, "symbol": "XAGUSD",
            "event": "MONTHLY_SLEEVE_STATE", "ts_utc": ts, "level": level,
            "payload": {"month": 202609, "host": "XAGUSD", "host_rank": 0,
                        "valid_count": 37, "ready": True, "reject_reason": "", **payload}}


def scan(monkeypatch, tmp_path, *rows):
    monkeypatch.setattr(pulse, "QM_DIR", tmp_path)
    monkeypatch.setattr(pulse, "utc_now", lambda: datetime(2026, 9, 8, 13, tzinfo=timezone.utc))
    (tmp_path / "QM5_1537.log").write_text("\n".join(json.dumps(r) for r in rows), encoding="utf-8")
    return pulse.scan_ea_logs()


BAD = event("2026-09-07T01:00:00Z", "ERROR", ready=False, valid_count=0, reject_reason="calendar_stale")
GOOD = event("2026-09-07T22:05:00Z")


def test_explicit_recovery_is_retained_as_evidence(monkeypatch, tmp_path):
    result = scan(monkeypatch, tmp_path, BAD, GOOD)
    assert result["ea_errors"] == []
    assert len(result["ea_errors_resolved"]) == 1
    assert result["ea_errors_resolved"][0]["valid_count"] == 37


@pytest.mark.parametrize("payload", [{"month": 202608}, {"valid_count": 36}, {"ready": False},
                                     {"host_rank": -1}, {"host": "XAUUSD"}, {"reject_reason": "bad"}])
def test_incomplete_or_wrong_recovery_never_clears_alarm(monkeypatch, tmp_path, payload):
    proof = copy.deepcopy(GOOD)
    proof["payload"].update(payload)
    assert scan(monkeypatch, tmp_path, BAD, proof)["ea_errors"]


@pytest.mark.parametrize("change", [{"magic": 7}, {"ea_id": 999}, {"symbol": "XAUUSD"},
                                    {"ts_utc": "2026-10-01T00:00:00Z"}])
def test_recovery_identity_and_time_are_bound(monkeypatch, tmp_path, change):
    assert scan(monkeypatch, tmp_path, BAD, {**GOOD, **change})["ea_errors"]


def test_fatal_and_other_errors_are_not_cleared(monkeypatch, tmp_path):
    result = scan(monkeypatch, tmp_path, {**BAD, "level": "FATAL"},
                  {**BAD, "event": "OTHER_ERROR"}, GOOD)
    assert len(result["ea_errors"]) == 2


def test_later_failure_or_new_instance_invalidates_recovery(monkeypatch, tmp_path):
    later = {**BAD, "ts_utc": "2026-09-08T12:00:00Z"}
    assert len(scan(monkeypatch, tmp_path, BAD, GOOD, later)["ea_errors"]) == 2
    assert scan(monkeypatch, tmp_path, BAD, GOOD, {**later, "event": "INIT_OK", "level": "INFO"})["ea_errors"]
