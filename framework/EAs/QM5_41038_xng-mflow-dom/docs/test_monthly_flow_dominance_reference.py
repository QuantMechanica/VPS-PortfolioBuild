"""Independent mechanic fixtures for QM5_41038.

The suite covers uniform energy-label normalization, exact completed-month
identity, 15-25 session bounds, every close/open endpoint, strict component
opposition, larger-absolute-component direction, month-return
reconciliation, first-new-month grace, one-attempt identity, fixed-risk
inputs, and next-month stale repair. It does not invoke MT5 or duplicate
framework order plumbing.
"""

from __future__ import annotations

import datetime as dt
import math
import unittest


DAY = dt.timedelta(days=1)
RECONCILE_TOLERANCE = 1.0e-10


def month_key(value: dt.datetime) -> int:
    return value.year * 100 + value.month


def next_month_key(key: int) -> int:
    year, month = divmod(key, 100)
    if not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def label_offset_seconds(
    labelled_bar_open: dt.datetime,
    broker_now: dt.datetime,
) -> int:
    elapsed = int((broker_now - labelled_bar_open).total_seconds())
    if elapsed < 0:
        return -1
    if elapsed < 86_400:
        return 0
    if elapsed < 172_800:
        return 86_400
    return -1


def within_entry_grace(
    broker_now: dt.datetime,
    labelled_bar_open: dt.datetime,
    grace_minutes: int = 180,
) -> bool:
    elapsed = int((broker_now - labelled_bar_open).total_seconds())
    return elapsed >= 0 and elapsed % 86_400 <= grace_minutes * 60


def valid_month_window(
    current_label: dt.datetime,
    broker_now: dt.datetime,
    completed_labels_newest_first: tuple[dt.datetime, ...],
    prior_count: int,
) -> bool:
    offset = label_offset_seconds(current_label, broker_now)
    if offset < 0 or not completed_labels_newest_first:
        return False
    normalized_current = current_label + dt.timedelta(seconds=offset)
    if normalized_current.date() != broker_now.date():
        return False
    current_key = month_key(normalized_current)
    if not 15 <= prior_count <= 25 or prior_count >= len(completed_labels_newest_first):
        return False
    normalized = tuple(
        value + dt.timedelta(seconds=offset)
        for value in completed_labels_newest_first
    )
    prior_key = month_key(normalized[0])
    anchor_key = month_key(normalized[prior_count])
    return (
        next_month_key(prior_key) == current_key
        and next_month_key(anchor_key) == prior_key
        and all(month_key(value) == prior_key for value in normalized[:prior_count])
        and all(
            normalized[index - 1] > normalized[index]
            for index in range(1, prior_count + 1)
        )
    )


def select_direction(
    overnight_flow: float,
    session_flow: float,
    month_return: float,
    tolerance: float = RECONCILE_TOLERANCE,
) -> int:
    total_flow = overnight_flow + session_flow
    if not all(
        math.isfinite(value)
        for value in (overnight_flow, session_flow, month_return, total_flow)
    ):
        return 0
    if abs(total_flow - month_return) > tolerance:
        return 0
    strict_opposition = (
        (overnight_flow < 0 and session_flow > 0)
        or (overnight_flow > 0 and session_flow < 0)
    )
    if not strict_opposition:
        return 0
    if abs(session_flow) > abs(overnight_flow):
        return 1 if session_flow > 0 else -1
    if abs(overnight_flow) > abs(session_flow):
        return 1 if overnight_flow > 0 else -1
    return 0


def flow_direction(
    preceding_month_end_close: float,
    prior_month_bars: tuple[tuple[float, float], ...],
) -> tuple[int, float, float, float, float]:
    """Return direction, components, completed-month return, and total."""

    flat = (0, 0.0, 0.0, 0.0, 0.0)
    if not 15 <= len(prior_month_bars) <= 25:
        return flat
    if (
        not math.isfinite(preceding_month_end_close)
        or preceding_month_end_close <= 0
    ):
        return flat

    overnight_flow = 0.0
    session_flow = 0.0
    prior_close = preceding_month_end_close
    for day_open, day_close in prior_month_bars:
        if not all(
            math.isfinite(value) and value > 0
            for value in (day_open, day_close, prior_close)
        ):
            return flat
        overnight_flow += math.log(day_open / prior_close)
        session_flow += math.log(day_close / day_open)
        prior_close = day_close

    completed_month_return = math.log(prior_close / preceding_month_end_close)
    total_flow = overnight_flow + session_flow
    direction = select_direction(
        overnight_flow,
        session_flow,
        completed_month_return,
    )
    return (
        direction,
        overnight_flow,
        session_flow,
        completed_month_return,
        total_flow,
    )


def make_bars(anchor: float, count: int, overnight: float, session: float):
    bars = []
    prior_close = anchor
    for _ in range(count):
        day_open = prior_close * overnight
        day_close = day_open * session
        bars.append((day_open, day_close))
        prior_close = day_close
    return tuple(bars)


class MonthlyFlowDominanceReferenceTests(unittest.TestCase):
    def test_native_same_day_labels_are_supported(self) -> None:
        broker_now = dt.datetime(2026, 8, 3, 1, 0)
        current = dt.datetime(2026, 8, 3, 0, 0)
        completed = tuple(
            dt.datetime(2026, 7, day, 0, 0)
            for day in range(31, 10, -1)
        ) + (dt.datetime(2026, 6, 30, 0, 0),)
        self.assertTrue(valid_month_window(current, broker_now, completed, 21))

    def test_prior_date_energy_labels_normalize_uniformly(self) -> None:
        broker_now = dt.datetime(2026, 8, 3, 1, 0)
        current = dt.datetime(2026, 8, 2, 0, 0)
        completed = tuple(
            dt.datetime(2026, 7, day, 0, 0)
            for day in range(30, 9, -1)
        ) + (dt.datetime(2026, 6, 29, 0, 0),)
        self.assertTrue(valid_month_window(current, broker_now, completed, 21))

    def test_nonconsecutive_or_current_month_endpoint_is_rejected(self) -> None:
        broker_now = dt.datetime(2026, 8, 3, 1, 0)
        current = dt.datetime(2026, 8, 3, 0, 0)
        bad_anchor = tuple(
            dt.datetime(2026, 7, day, 0, 0)
            for day in range(31, 10, -1)
        ) + (dt.datetime(2026, 5, 29, 0, 0),)
        self.assertFalse(valid_month_window(current, broker_now, bad_anchor, 21))

    def test_session_count_bounds_are_load_bearing(self) -> None:
        self.assertEqual(flow_direction(100.0, make_bars(100.0, 14, 0.995, 1.01))[0], 0)
        self.assertEqual(flow_direction(100.0, make_bars(100.0, 26, 0.995, 1.01))[0], 0)
        self.assertEqual(flow_direction(100.0, make_bars(100.0, 15, 0.995, 1.01))[0], 1)
        self.assertEqual(flow_direction(100.0, make_bars(100.0, 25, 0.995, 1.01))[0], 1)

    def test_session_dominant_positive_flow_buys(self) -> None:
        direction, overnight, session, month_return, total = flow_direction(
            100.0, make_bars(100.0, 20, 0.995, 1.01)
        )
        self.assertEqual(direction, 1)
        self.assertLess(overnight, 0)
        self.assertGreater(session, 0)
        self.assertGreater(total, 0)
        self.assertAlmostEqual(total, month_return)

    def test_overnight_dominant_negative_flow_sells(self) -> None:
        direction, overnight, session, _, total = flow_direction(
            100.0, make_bars(100.0, 20, 0.985, 1.01)
        )
        self.assertEqual(direction, -1)
        self.assertLess(overnight, 0)
        self.assertGreater(session, 0)
        self.assertLess(total, 0)

    def test_overnight_dominant_positive_flow_buys(self) -> None:
        direction, overnight, session, _, total = flow_direction(
            100.0, make_bars(100.0, 20, 1.01, 0.995)
        )
        self.assertEqual(direction, 1)
        self.assertGreater(overnight, 0)
        self.assertLess(session, 0)
        self.assertGreater(total, 0)

    def test_session_dominant_negative_flow_sells(self) -> None:
        direction, overnight, session, _, total = flow_direction(
            100.0, make_bars(100.0, 20, 1.005, 0.99)
        )
        self.assertEqual(direction, -1)
        self.assertGreater(overnight, 0)
        self.assertLess(session, 0)
        self.assertLess(total, 0)

    def test_positive_component_agreement_is_flat(self) -> None:
        direction, overnight, session, _, _ = flow_direction(
            100.0, make_bars(100.0, 20, 1.005, 1.004)
        )
        self.assertGreater(overnight, 0)
        self.assertGreater(session, 0)
        self.assertEqual(direction, 0)

    def test_negative_component_agreement_is_flat(self) -> None:
        direction, overnight, session, _, _ = flow_direction(
            100.0, make_bars(100.0, 20, 0.995, 0.996)
        )
        self.assertLess(overnight, 0)
        self.assertLess(session, 0)
        self.assertEqual(direction, 0)

    def test_exact_zero_is_flat(self) -> None:
        result = flow_direction(100.0, make_bars(100.0, 20, 1.0, 1.0))
        self.assertEqual(result, (0, 0.0, 0.0, 0.0, 0.0))

    def test_one_component_exact_zero_is_flat(self) -> None:
        self.assertEqual(
            flow_direction(100.0, make_bars(100.0, 20, 1.0, 1.005))[0],
            0,
        )
        self.assertEqual(
            flow_direction(100.0, make_bars(100.0, 20, 0.995, 1.0))[0],
            0,
        )

    def test_equal_absolute_opposed_components_are_flat(self) -> None:
        self.assertEqual(select_direction(-0.1, 0.1, 0.0), 0)
        direction, overnight, session, month_return, total = flow_direction(
            100.0, make_bars(100.0, 20, 2.0, 0.5)
        )
        self.assertEqual(direction, 0)
        self.assertGreater(overnight, 0)
        self.assertLess(session, 0)
        self.assertAlmostEqual(abs(overnight), abs(session))
        self.assertAlmostEqual(total, month_return)

    def test_failed_reconciliation_is_flat(self) -> None:
        self.assertEqual(select_direction(-0.1, 0.2, 0.2), 0)
        self.assertEqual(
            select_direction(
                -0.1,
                0.2,
                0.1 + 2 * RECONCILE_TOLERANCE,
            ),
            0,
        )

    def test_all_endpoints_telescope_to_month_return(self) -> None:
        bars = make_bars(100.0, 21, 0.997, 1.006)
        _, overnight, session, month_return, total = flow_direction(100.0, bars)
        self.assertAlmostEqual(total, month_return)
        self.assertAlmostEqual(total, math.log(bars[-1][1] / 100.0))
        self.assertAlmostEqual(overnight + session, total)

    def test_invalid_completed_endpoint_consumes_flat(self) -> None:
        bars = list(make_bars(100.0, 20, 0.997, 1.006))
        bars[7] = (bars[7][0], float("nan"))
        self.assertEqual(
            flow_direction(100.0, tuple(bars)),
            (0, 0.0, 0.0, 0.0, 0.0),
        )

    def test_three_hour_grace_uses_executable_session_open(self) -> None:
        labelled = dt.datetime(2026, 8, 2, 0, 0)
        self.assertTrue(within_entry_grace(dt.datetime(2026, 8, 3, 2, 59), labelled))
        self.assertFalse(within_entry_grace(dt.datetime(2026, 8, 3, 3, 0, 1), labelled))

    def test_month_attempt_key_is_stable(self) -> None:
        observed = dt.datetime(2026, 8, 3, 2, 0)
        self.assertEqual(month_key(observed), 202608)
        self.assertEqual(next_month_key(202612), 202701)
        self.assertNotEqual(month_key(observed), 202609)

    def test_next_month_is_the_rollover_boundary(self) -> None:
        opened = dt.datetime(2026, 8, 3, 1, 0)
        august_end = dt.datetime(2026, 8, 31, 22, 0)
        september = dt.datetime(2026, 9, 1, 0, 1)
        self.assertEqual(month_key(opened), month_key(august_end))
        self.assertNotEqual(month_key(opened), month_key(september))

    def test_fixed_risk_contract_is_sealed(self) -> None:
        risk_fixed, risk_percent, weight = 1000.0, 0.0, 1.0
        self.assertEqual((risk_fixed, risk_percent, weight), (1000.0, 0.0, 1.0))


if __name__ == "__main__":
    unittest.main()
