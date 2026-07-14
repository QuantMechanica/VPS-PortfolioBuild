import datetime as dt
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

from portfolio import ftmo_phase1_mae  # noqa: E402


def test_ftmo_calendar_day_uses_cest_midnight() -> None:
    timestamp = int(dt.datetime(2026, 7, 8, 22, 30, tzinfo=dt.UTC).timestamp())

    assert ftmo_phase1_mae.ftmo_calendar_day(timestamp) == dt.date(2026, 7, 9)


def test_phase1_requires_four_actual_trading_days() -> None:
    rows = [
        (5_000.0, 0.0, 1),
        (5_000.0, 0.0, 1),
        (0.0, 0.0, 0),
        (0.0, 0.0, 0),
    ]

    assert ftmo_phase1_mae.evaluate_window(rows) == "not_reached"


def test_phase1_passes_when_target_and_four_trading_days_hold() -> None:
    rows = [
        (5_000.0, 0.0, 1),
        (5_000.0, 0.0, 1),
        (100.0, 0.0, 1),
        (-100.0, 0.0, 1),
    ]

    assert ftmo_phase1_mae.evaluate_window(rows) == "passed"


def test_phase1_target_must_still_be_met_on_fourth_trading_day() -> None:
    rows = [
        (10_000.0, 0.0, 1),
        (-1_000.0, 0.0, 1),
        (100.0, 0.0, 1),
        (100.0, 0.0, 1),
    ]

    assert ftmo_phase1_mae.evaluate_window(rows) == "not_reached"


def test_verification_five_percent_target() -> None:
    rows = [
        (2_000.0, 0.0, 1),
        (1_000.0, 0.0, 1),
        (1_000.0, 0.0, 1),
        (1_000.0, 0.0, 1),
    ]

    assert ftmo_phase1_mae.evaluate_window(rows, target=105_000.0) == "passed"


def test_number_list_parser_rejects_non_positive_values() -> None:
    try:
        ftmo_phase1_mae.parse_number_list("30,0", int, "horizons")
    except Exception as exc:
        assert "positive" in str(exc)
    else:
        raise AssertionError("expected invalid list to fail")


def test_number_list_parser_allows_zero_seed() -> None:
    assert ftmo_phase1_mae.parse_number_list("0,7", int, "seeds", allow_zero=True) == [0, 7]


def test_two_phase_bootstrap_requires_both_targets() -> None:
    pairs = [(2_500.0, 0.0, 1), (2_500.0, 0.0, 1), (2_500.0, 0.0, 1), (2_500.0, 0.0, 1)]

    counts = ftmo_phase1_mae.bootstrap_two_phase(
        pairs, 4, 1, 10, 0, phase1_target=110_000.0, phase2_target=105_000.0
    )

    assert counts["passed"] == 10
    assert sum(counts.values()) == 10


def test_q08_round_trip_values_add_missing_entry_commission() -> None:
    net, mae = ftmo_phase1_mae.q08_round_trip_values(
        {"net": 100.0, "mae_acct": -40.0, "commission": -5.0}
    )

    assert net == 95.0
    assert mae == -45.0


def test_continuous_calendar_days_include_idle_days() -> None:
    days = ftmo_phase1_mae.continuous_calendar_days(
        [dt.date(2026, 7, 1), dt.date(2026, 7, 4)]
    )

    assert days == [
        dt.date(2026, 7, 1),
        dt.date(2026, 7, 2),
        dt.date(2026, 7, 3),
        dt.date(2026, 7, 4),
    ]
