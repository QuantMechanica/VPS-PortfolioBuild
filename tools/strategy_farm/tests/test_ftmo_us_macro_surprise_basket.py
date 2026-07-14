from pathlib import Path

import pandas as pd
import pytest

from tools.strategy_farm.portfolio import ftmo_us_macro_surprise_basket as macro


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("241K", 241.0), ("-0.9%", -0.9), ("1.2M", 1200.0), ("2B", 2_000_000.0)],
)
def test_parse_calendar_number(raw: str, expected: float) -> None:
    assert macro.parse_calendar_number(raw) == expected


def test_timestamp_normalization_uses_release_date_and_eastern_dst() -> None:
    assert macro.normalize_release_timestamp("2015.02.05 20:30") == pd.Timestamp(
        "2015-02-06T13:30:00Z"
    )
    assert macro.normalize_release_timestamp("2015.04.03 12:30") == pd.Timestamp(
        "2015-04-03T12:30:00Z"
    )
    assert macro.normalize_release_timestamp("2024.07.11 11:30") == pd.Timestamp(
        "2024-07-11T12:30:00Z"
    )


def test_load_event_packages_groups_components_after_normalization(tmp_path: Path) -> None:
    calendar = tmp_path / "calendar.csv"
    pd.DataFrame(
        [
            {
                "DateTime_UTC": "2015.01.13 20:30",
                "Currency": "USD",
                "Event": "Retail Sales m/m",
                "Actual": "-0.9%",
                "Forecast": "0.2%",
            },
            {
                "DateTime_UTC": "2015.01.14 13:30",
                "Currency": "USD",
                "Event": "Core Retail Sales m/m",
                "Actual": "-1.0%",
                "Forecast": "0.1%",
            },
        ]
    ).to_csv(calendar, index=False)
    packages = macro.load_event_packages(calendar)
    assert len(packages) == 1
    assert packages[0]["timestamp"] == pd.Timestamp("2015-01-14T13:30:00Z")
    assert packages[0]["score"] == pytest.approx(-4.4)
    assert len(packages[0]["components"]) == 2


def test_duplicate_resolution_prefers_already_canonical_utc_row(tmp_path: Path) -> None:
    calendar = tmp_path / "calendar.csv"
    pd.DataFrame(
        [
            {
                "DateTime_UTC": "2019.04.28 19:30",
                "Currency": "USD",
                "Event": "Core PCE Price Index m/m",
                "Actual": "0.1%",
                "Forecast": "0.2%",
            },
            {
                "DateTime_UTC": "2019.04.29 12:30",
                "Currency": "USD",
                "Event": "Core PCE Price Index m/m",
                "Actual": "0.0%",
                "Forecast": "0.1%",
            },
        ]
    ).to_csv(calendar, index=False)
    packages = macro.load_event_packages(calendar)
    assert len(packages) == 1
    assert packages[0]["score"] == pytest.approx(-1.0)
    assert packages[0]["components"][0]["raw_timestamp_is_canonical"] is True


def test_grid_and_frozen_density_gates() -> None:
    assert len(macro.parameter_grid()) == 324
    metrics = {
        "dev_2018_2022": {"trades": 99, "net_r": 10.0, "profit_factor": 2.0},
        "validation_2023": {"trades": 17, "net_r": 5.0, "profit_factor": 2.0},
        "annual": {str(year): {"net_r": 1.0} for year in range(2018, 2023)},
    }
    assert not macro.preholdout_pass(metrics)
