import sqlite3
import sys
import textwrap
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import health  # noqa: E402
import unbuilt_cards_disposition as ucd  # noqa: E402


def test_enumerate_unbuilt_is_the_shared_health_helper():
    """MNT-013: this script must not carry its own hand-synced copy of the
    enumeration -- it existed once, with a comment promising to mirror
    health.chk_unbuilt_cards_count by hand, which is exactly the kind of
    silent-drift risk a shared helper removes structurally."""
    import inspect
    source = inspect.getsource(ucd._enumerate_unbuilt)
    assert "health.enumerate_unbuilt_cards" in source


def test_enumerate_unbuilt_matches_health_chk_count_on_same_fixture(tmp_path: Path, monkeypatch):
    """Build a tiny fixture cards_approved/ + framework/EAs/ tree and confirm
    the disposition script's total and health.chk_unbuilt_cards_count's `n`
    agree exactly -- they now run the identical enumeration function."""
    cards_dir = tmp_path / "artifacts" / "cards_approved"
    cards_dir.mkdir(parents=True)
    eas_dir = tmp_path / "framework" / "EAs"
    eas_dir.mkdir(parents=True)

    # One buildable (R-gate ready, no .ex5 yet), one already built (.ex5 exists,
    # must be excluded from both), one R-gate-not-ready (excluded from both).
    (cards_dir / "QM5_90001_fixture-buildable.md").write_text(textwrap.dedent("""\
        ---
        source_id: fixture-source
        r1_track_record: PASS
        r2_entry_rule: PASS
        r3_data_available: PASS
        r4_mechanical: PASS
        ---
        body
        """), encoding="utf-8")
    (cards_dir / "QM5_90002_fixture-built.md").write_text(textwrap.dedent("""\
        ---
        source_id: fixture-source
        r1_track_record: PASS
        r2_entry_rule: PASS
        r3_data_available: PASS
        r4_mechanical: PASS
        ---
        body
        """), encoding="utf-8")
    built_dir = eas_dir / "QM5_90002_fixture-built"
    built_dir.mkdir(parents=True)
    (built_dir / "QM5_90002_fixture-built.ex5").write_bytes(b"stub")
    (cards_dir / "QM5_90003_fixture-not-ready.md").write_text(textwrap.dedent("""\
        ---
        source_id: fixture-source
        r1_track_record: UNKNOWN
        ---
        body
        """), encoding="utf-8")

    monkeypatch.setattr(health, "ROOT", tmp_path)
    monkeypatch.setattr(health, "FRAMEWORK_EAS_DIR", eas_dir)
    monkeypatch.setattr(health, "_has_auto_build_task_file", lambda ea_id: False)
    monkeypatch.setattr(health, "_has_auto_build_task", lambda con, ea_id: False)
    monkeypatch.setattr(
        health.farmctl, "_card_r_gate_ready",
        lambda fm: str(fm.get("r1_track_record") or "").strip().upper() == "PASS",
    )

    con = sqlite3.connect(":memory:")
    try:
        rows, not_ready = health.enumerate_unbuilt_cards(con)
        disposition_rows = ucd._enumerate_unbuilt(con)
    finally:
        con.close()

    assert [r[0] for r in rows] == ["QM5_90001"]
    assert not_ready == 1
    assert rows == disposition_rows


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
