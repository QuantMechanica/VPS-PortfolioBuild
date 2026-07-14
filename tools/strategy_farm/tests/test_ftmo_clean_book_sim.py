import datetime as dt
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

from portfolio import ftmo_clean_book_sim  # noqa: E402


def test_conservative_ftmo_mae_only_applies_adverse_cost_delta() -> None:
    assert ftmo_clean_book_sim.conservative_ftmo_mae(-100.0, 50.0, 40.0) == -110.0
    assert ftmo_clean_book_sim.conservative_ftmo_mae(-100.0, 40.0, 50.0) == -100.0
    assert ftmo_clean_book_sim.conservative_ftmo_mae(-100.0, -80.0, -120.0) == -140.0


def test_build_daily_uses_continuous_calendar_and_preserves_idle_days() -> None:
    sleeve = ftmo_clean_book_sim.LoadedSleeve(
        key="1:EURUSD.DWX",
        ea_id=1,
        symbol="EURUSD.DWX",
        base_risk_fixed=1000.0,
        trades=(
            ftmo_clean_book_sim.CostedTrade(
                entry_day=dt.date(2026, 7, 1),
                close_day=dt.date(2026, 7, 3),
                net=200.0,
                mae=-100.0,
            ),
        ),
        native_net=210.0,
        ftmo_net=200.0,
        ftmo_commission=5.0,
        ftmo_swap=-5.0,
    )

    days, pairs = ftmo_clean_book_sim.build_daily(
        [sleeve], {sleeve.key: 1.0}, multiplier=2.0
    )

    assert days == [dt.date(2026, 7, 1), dt.date(2026, 7, 2), dt.date(2026, 7, 3)]
    assert pairs == [
        (0.0, -200.0, 1),
        (0.0, -200.0, 0),
        (400.0, -200.0, 0),
    ]


def test_count_windows_is_calendar_based() -> None:
    pairs = [(0.0, 0.0, 0)] * 31

    counts = ftmo_clean_book_sim.count_windows(pairs, 30)

    assert counts["not_reached"] == 2
