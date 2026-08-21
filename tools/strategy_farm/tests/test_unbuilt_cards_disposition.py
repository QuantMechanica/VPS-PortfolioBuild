import sys
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import unbuilt_cards_disposition as ucd  # noqa: E402


def test_classify_data_blocked_when_archive_admission_fails():
    with mock.patch.object(
        ucd.farmctl,
        "custom_history_archive_admission",
        return_value={"ok": False, "reason": "custom_history_archive_coverage_missing"},
    ):
        bucket, reason = ucd._classify("QM5_99999", Path("dummy.md"), {"source_id": "x", "r1_track_record": "PASS"})
    assert bucket == "DATA_BLOCKED"
    assert "coverage_missing" in reason


def test_classify_needs_source_when_source_id_missing():
    with mock.patch.object(
        ucd.farmctl, "custom_history_archive_admission", return_value={"ok": True}
    ):
        bucket, reason = ucd._classify("QM5_99999", Path("dummy.md"), {"source_id": "", "r1_track_record": "PASS"})
    assert bucket == "NEEDS_SOURCE"
    assert reason == "source_id_missing"


def test_classify_needs_source_when_track_record_unknown():
    with mock.patch.object(
        ucd.farmctl, "custom_history_archive_admission", return_value={"ok": True}
    ):
        bucket, reason = ucd._classify(
            "QM5_99999", Path("dummy.md"), {"source_id": "some-source", "r1_track_record": "UNKNOWN"}
        )
    assert bucket == "NEEDS_SOURCE"


def test_classify_ready_when_archive_ok_and_source_solid():
    with mock.patch.object(
        ucd.farmctl, "custom_history_archive_admission", return_value={"ok": True}
    ):
        bucket, reason = ucd._classify(
            "QM5_99999", Path("dummy.md"), {"source_id": "some-source", "r1_track_record": "PASS"}
        )
    assert bucket == "READY"


def test_classify_error_is_not_silently_data_blocked():
    with mock.patch.object(
        ucd.farmctl, "custom_history_archive_admission", side_effect=RuntimeError("boom")
    ):
        bucket, reason = ucd._classify("QM5_99999", Path("dummy.md"), {"source_id": "x"})
    assert bucket == "CLASSIFY_ERROR"
    assert "boom" in reason
