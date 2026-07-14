from __future__ import annotations

import numpy as np
import pandas as pd

from tools.strategy_farm.portfolio import ftmo_m15_causal_strategy_screen as m15
from tools.strategy_farm.portfolio import ftmo_ws30_friday_session_joint_screen as screen


def test_flat_friday_path_charges_declared_four_point_cost() -> None:
    m15._ARRAY_CACHE.clear()
    m15._SESSION_CACHE.clear()
    utc = pd.date_range("2023-01-06T14:30:00Z", periods=26, freq="15min")
    local = utc.tz_convert("America/New_York")
    frame = pd.DataFrame(
        {
            "open": np.full(26, 100.0),
            "high": np.full(26, 100.0),
            "low": np.full(26, 100.0),
            "close": np.full(26, 100.0),
            "atr56": np.full(26, 10.0),
            "utc": utc,
            "local_date": local.date,
            "year": local.year,
            "weekday": local.weekday,
            "minute": local.hour * 60 + local.minute,
        }
    )
    instrument = m15.Instrument(
        "WS30.DWX", None, "America/New_York", 570, 960, 4.0  # type: ignore[arg-type]
    )
    paths = screen.build_candidate_paths(frame, instrument, grid=utc, excluded_years=set())
    assert len(paths) == 1
    path = paths[0]
    assert path.start_idx == 16
    assert path.end_idx == 25
    assert path.entry_commission == 200.0
    assert path.exit_commission == 200.0
    assert path.exit_balance_delta == -200.0
    assert path.nominal_risk == 1000.0


def test_targeted_transfer_changes_only_donor_and_candidate() -> None:
    weights = screen.targeted_transfer_weights(
        {"a": 0.6, "b": 0.4}, donor_key="b", candidate_weight=0.1
    )
    assert weights["a"] == 0.6
    assert abs(weights["b"] - 0.3) < 1e-12
    assert weights[screen.CANDIDATE_KEY] == 0.1
