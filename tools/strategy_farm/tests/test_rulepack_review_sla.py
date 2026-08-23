import json
import sys
from datetime import date
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm import rulepack_review_sla as sla  # noqa: E402
from tools.strategy_farm import target_rulepacks as rulepacks  # noqa: E402


def _rulepack_dir(tmp_path: Path) -> Path:
    directory = tmp_path / "rulepacks"
    directory.mkdir()
    (directory / "DXZ_TEST_V1.json").write_text("{}", encoding="utf-8")
    (directory / "FTMO_TEST_V1.json").write_text("{}", encoding="utf-8")
    return directory


def test_unreviewed_rulepack_is_overdue_fail_closed(tmp_path: Path) -> None:
    rulepack_dir = _rulepack_dir(tmp_path)
    state_path = tmp_path / "state.json"

    # list_rulepack_ids requires a valid rulepack_id-shaped filename; our two
    # fixture files satisfy the naming pattern without needing full schema
    # validation (status() never loads/validates rulepack content).
    rows = sla.status(today=date(2026, 8, 23), rulepack_dir=rulepack_dir, state_path=state_path)

    assert {row["rulepack_id"] for row in rows} == {"DXZ_TEST_V1", "FTMO_TEST_V1"}
    for row in rows:
        assert row["reviewed"] is False
        assert row["overdue"] is True
        assert row["days_overdue"] is None


def test_record_review_then_status_reports_current(tmp_path: Path) -> None:
    rulepack_dir = _rulepack_dir(tmp_path)
    state_path = tmp_path / "state.json"

    entry = sla.record_review(
        "DXZ_TEST_V1",
        checked_on="2026-08-23",
        result="CONFIRMED_UNCHANGED",
        note="Compared VaR range and D-Leverage caps against the live risk-engine page; unchanged.",
        interval_days=90,
        state_path=state_path,
    )
    assert entry.next_review_due_on == "2026-11-21"

    rows = sla.status(today=date(2026, 9, 1), rulepack_dir=rulepack_dir, state_path=state_path)
    dxz = next(row for row in rows if row["rulepack_id"] == "DXZ_TEST_V1")
    ftmo = next(row for row in rows if row["rulepack_id"] == "FTMO_TEST_V1")

    assert dxz["reviewed"] is True
    assert dxz["overdue"] is False
    assert dxz["days_overdue"] == 0
    assert dxz["last_check_result"] == "CONFIRMED_UNCHANGED"
    assert ftmo["reviewed"] is False  # never touched


def test_status_flags_expired_review_as_overdue_with_day_count(tmp_path: Path) -> None:
    rulepack_dir = _rulepack_dir(tmp_path)
    state_path = tmp_path / "state.json"
    sla.record_review(
        "DXZ_TEST_V1",
        checked_on="2026-01-01",
        result="CONFIRMED_UNCHANGED",
        note="Initial check.",
        interval_days=90,
        state_path=state_path,
    )

    rows = sla.status(today=date(2026, 8, 23), rulepack_dir=rulepack_dir, state_path=state_path)
    dxz = next(row for row in rows if row["rulepack_id"] == "DXZ_TEST_V1")

    assert dxz["overdue"] is True
    assert dxz["days_overdue"] > 0


def test_record_review_rejects_invalid_result_and_empty_note(tmp_path: Path) -> None:
    state_path = tmp_path / "state.json"
    with pytest.raises(sla.ReviewSlaError, match="result must be"):
        sla.record_review(
            "DXZ_TEST_V1",
            checked_on="2026-08-23",
            result="LOOKS_FINE",
            note="whatever",
            state_path=state_path,
        )
    with pytest.raises(sla.ReviewSlaError, match="note must describe"):
        sla.record_review(
            "DXZ_TEST_V1",
            checked_on="2026-08-23",
            result="CONFIRMED_UNCHANGED",
            note="   ",
            state_path=state_path,
        )


def test_real_rulepacks_are_tracked_and_currently_confirmed() -> None:
    """The two production rulepacks must have a live tracker entry -- this
    guards against the SLA silently going stale without anyone noticing."""
    today = date(2026, 8, 23)
    rows = sla.status(today=today)
    by_id = {row["rulepack_id"]: row for row in rows}

    for rulepack_id in rulepacks.list_rulepack_ids():
        assert rulepack_id in by_id, f"{rulepack_id} has no review-SLA tracker entry"
        row = by_id[rulepack_id]
        assert row["reviewed"] is True, f"{rulepack_id} was never reviewed"
        assert not row["overdue"], f"{rulepack_id} review is overdue: {row}"
