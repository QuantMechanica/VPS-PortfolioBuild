import numpy as np

from tools.strategy_farm.portfolio.ftmo_usdjpy_range_clock_screen import (
    _exact_slice,
    _exit_price,
    _slice_half_open,
    _side_result,
    load_native_bars,
    wilder_average,
)


def test_wilder_average_uses_simple_seed_then_recursive_updates() -> None:
    result = wilder_average([1.0, 2.0, 3.0, 7.0], 3)
    assert np.isnan(result[0])
    assert np.isnan(result[1])
    assert result[2] == 2.0
    assert result[3] == (2.0 * 2.0 + 7.0) / 3.0


def test_side_result_charges_cost_and_resolves_stop_pessimistically() -> None:
    import pandas as pd

    holding = pd.DataFrame(
        {"high": [101.5], "low": [98.5]},
        index=pd.DatetimeIndex([pd.Timestamp("2024-01-01T00:00:00")]),
    )
    result, reason = _side_result(
        holding,
        side=1,
        entry=100.0,
        stop_distance=1.0,
        exit_price=101.0,
        cost_bps=2.0,
    )
    assert reason == "stop"
    assert result == -1.02


def test_load_native_bars_seeds_atr_from_first_bar_range(tmp_path) -> None:
    import pandas as pd

    rows = []
    start = pd.Timestamp("2024-01-01T00:00:00", tz="UTC")
    for index in range(14 * 6):
        timestamp = start + pd.Timedelta(minutes=5 * index)
        rows.append(
            {
                "time": int(timestamp.timestamp()),
                "open": 100.0,
                "high": 101.0,
                "low": 99.0,
                "close": 100.0,
            }
        )
    path = tmp_path / "USDJPY.DWX_M5.csv"
    pd.DataFrame(rows).to_csv(path, index=False)

    _, m30 = load_native_bars(path)

    assert len(m30) == 14
    assert np.isnan(m30["atr14"].iloc[-2])
    assert m30["atr14"].iloc[-1] == 2.0


def test_index_slices_and_exit_fallback_are_half_open() -> None:
    import pandas as pd

    index = pd.date_range("2024-01-01T00:00:00", periods=4, freq="5min")
    frame = pd.DataFrame(
        {
            "open": [10.0, 11.0, 12.0, 13.0],
            "close": [10.5, 11.5, 12.5, 13.5],
        },
        index=index,
    )

    selected = _slice_half_open(frame, index[1], index[3])

    assert list(selected.index) == [index[1], index[2]]
    assert _exit_price(frame, index[2]) == 12.0
    assert _exit_price(frame, index[2] + pd.Timedelta(minutes=3)) == 12.5
    assert _exit_price(frame, index[-1] + pd.Timedelta(minutes=11)) is None


def test_exact_slice_rejects_a_missing_bar() -> None:
    import pandas as pd

    index = pd.date_range("2024-01-01T00:00:00", periods=4, freq="5min")
    frame = pd.DataFrame({"close": [1.0, 2.0, 3.0, 4.0]}, index=index)

    assert _exact_slice(frame, index[0], index[-1] + pd.Timedelta(minutes=5)) is not None
    assert _exact_slice(frame.drop(index[1]), index[0], index[-1] + pd.Timedelta(minutes=5)) is None
