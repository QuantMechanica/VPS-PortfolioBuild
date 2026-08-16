"""A corrupt repeat-suppression cache must never silence the live alarm channel.

Regression cover for 2026-08-17: live_alarm_mailer_state.json held 643 NUL bytes
(size committed, data never flushed). Every mailer run since 2026-08-15T02:45Z
aborted on it, so T_Live traded for ~45 h with no alarm path -- and the error
named the healthy alarm file as its source, which is what made it survive.
"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import live_alarm_mailer as mailer  # noqa: E402


def test_corrupt_consumer_state_degrades_to_empty(tmp_path):
    path = tmp_path / "consumer.json"
    path.write_bytes(b"\x00" * 643)
    value, degraded = mailer._load_consumer_state(path)
    assert value == {}
    assert degraded is not None
    assert "JSONDecodeError" in degraded or "UnicodeDecodeError" in degraded


def test_missing_consumer_state_is_not_an_error(tmp_path):
    value, degraded = mailer._load_consumer_state(tmp_path / "absent.json")
    assert value == {}
    assert degraded is None


def test_healthy_consumer_state_round_trips(tmp_path):
    path = tmp_path / "consumer.json"
    path.write_text(json.dumps({"last_fingerprint": "abc"}), encoding="utf-8")
    value, degraded = mailer._load_consumer_state(path)
    assert value == {"last_fingerprint": "abc"}
    assert degraded is None


def test_alarm_source_corruption_still_raises(tmp_path):
    """The INPUT must stay strict: a corrupt alarm file is not 'no alarms'."""
    path = tmp_path / "live_alarm_state.json"
    path.write_bytes(b"\x00" * 16)
    with pytest.raises(mailer.JsonLoadError):
        mailer._load_json(path, required=True)


def test_json_load_error_carries_the_failing_path(tmp_path):
    path = tmp_path / "broken.json"
    path.write_text("{ not json", encoding="utf-8")
    with pytest.raises(mailer.JsonLoadError) as excinfo:
        mailer._load_json(path)
    assert excinfo.value.path == path
    assert str(path) in str(excinfo.value)


def test_non_object_root_is_reported_against_its_own_path(tmp_path):
    path = tmp_path / "list.json"
    path.write_text("[1, 2, 3]", encoding="utf-8")
    with pytest.raises(mailer.JsonLoadError) as excinfo:
        mailer._load_json(path)
    assert excinfo.value.path == path
