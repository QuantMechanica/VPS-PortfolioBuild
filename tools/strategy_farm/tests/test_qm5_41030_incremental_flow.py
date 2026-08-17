from __future__ import annotations

import math
import re
from datetime import date, timedelta
from pathlib import Path


EA_SOURCE = (
    Path(__file__).resolve().parents[3]
    / "framework"
    / "EAs"
    / "QM5_41030_xauxag-flowdiv"
    / "QM5_41030_xauxag-flowdiv.mq5"
)


def _flow(xau: list[tuple[float, float]], xag: list[tuple[float, float]]):
    overnight = 0.0
    session = 0.0
    for index in range(5):
        overnight += math.log(xau[index][0] / xau[index + 1][1])
        overnight -= math.log(xag[index][0] / xag[index + 1][1])
        session += math.log(xau[index][1] / xau[index][0])
        session -= math.log(xag[index][1] / xag[index][0])
    direction = 1 if session > 0.0 > overnight else -1 if session < 0.0 < overnight else 0
    return overnight, session, direction


def test_incremental_window_is_decision_identical_to_direct_six_bar_reads():
    trading_days: list[date] = []
    cursor = date(2025, 1, 1)
    while len(trading_days) < 90:
        if cursor.weekday() < 5:
            trading_days.append(cursor)
        cursor += timedelta(days=1)

    xau = [(2000.0 + i * 1.7, 2000.0 + i * 1.7 + (-1) ** i * 4.0) for i in range(90)]
    xag = [(25.0 + i * 0.02, 25.0 + i * 0.02 + (-1) ** (i + 1) * 0.05) for i in range(90)]

    # MQL arrays are series arrays: index zero is the most recently closed bar.
    cached_xau = list(reversed(xau[:6]))
    cached_xag = list(reversed(xag[:6]))
    for current in range(6, len(trading_days)):
        if current > 6:
            cached_xau = [xau[current - 1], *cached_xau[:5]]
            cached_xag = [xag[current - 1], *cached_xag[:5]]
        direct_xau = list(reversed(xau[current - 6 : current]))
        direct_xag = list(reversed(xag[current - 6 : current]))
        if trading_days[current].weekday() != 0:
            continue
        old = _flow(direct_xau, direct_xag)
        new = _flow(cached_xau, cached_xag)
        assert math.isclose(old[0], new[0], rel_tol=0.0, abs_tol=1e-15)
        assert math.isclose(old[1], new[1], rel_tol=0.0, abs_tol=1e-15)
        assert old[2] == new[2]


def test_entry_evaluation_no_longer_performs_six_bar_copyrates():
    source = EA_SOURCE.read_text(encoding="utf-8-sig")
    body = re.search(
        r"bool Strategy_LoadRelativeFlow\(.*?\n  \}\n\nbool Strategy_DecisionClockReady",
        source,
        flags=re.DOTALL,
    )
    assert body is not None
    assert "CopyRates(" not in body.group(0)
    assert "Strategy_RefreshFlowWindow" in source
    assert "Strategy_UpdateFlowWindow" in source
    assert "PERIOD_D1, 1, 1" in source
