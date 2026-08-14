"""Independent reference checks for QM5_21523's locked signal contract."""

from __future__ import annotations

from datetime import datetime, timezone
import math
import unittest


TREND_MONTHS = 12
SIGN_DEADBAND = 1.0e-12
RETURN_TOLERANCE = 1.0e-10


def month_key(timestamp: int) -> int:
    value = datetime.fromtimestamp(timestamp, tz=timezone.utc)
    return value.year * 100 + value.month


def next_month(key: int) -> int:
    year, month = divmod(key, 100)
    if not 1 <= month <= 12:
        raise ValueError("invalid month key")
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def intersect_exact(
    wti: list[tuple[int, float]],
    xau: list[tuple[int, float]],
    decision_time: int,
) -> list[tuple[int, float, float]]:
    wti_map = {time: close for time, close in wti if time < decision_time}
    xau_map = {time: close for time, close in xau if time < decision_time}
    common = sorted(set(wti_map).intersection(xau_map))
    return [(time, wti_map[time], xau_map[time]) for time in common]


def synchronized_month_ends(
    common: list[tuple[int, float, float]],
) -> list[tuple[int, float, float]]:
    by_month: dict[int, tuple[int, float, float]] = {}
    for row in common:
        key = month_key(row[0])
        by_month[key] = row
    keys = sorted(by_month)
    if len(keys) < TREND_MONTHS + 1:
        raise ValueError("at least thirteen synchronized month ends are required")
    keys = keys[-(TREND_MONTHS + 1) :]
    if any(observed != next_month(prior) for prior, observed in zip(keys, keys[1:])):
        raise ValueError("month keys must be consecutive")
    return [(key, by_month[key][1], by_month[key][2]) for key in keys]


def twelve_month_return(month_end_closes: list[float]) -> float:
    if len(month_end_closes) != TREND_MONTHS + 1:
        raise ValueError("exactly thirteen month-end closes are required")
    if any(not math.isfinite(value) or value <= 0.0 for value in month_end_closes):
        raise ValueError("month-end closes must be positive and finite")
    endpoint = math.log(month_end_closes[-1] / month_end_closes[0])
    chained = math.fsum(
        math.log(next_value / prior_value)
        for prior_value, next_value in zip(month_end_closes, month_end_closes[1:])
    )
    if not math.isclose(endpoint, chained, rel_tol=0.0, abs_tol=RETURN_TOLERANCE):
        raise AssertionError("endpoint and chained log returns disagree")
    return endpoint


def divergence_signal(wti_return: float, xau_return: float) -> int:
    if not math.isfinite(wti_return) or not math.isfinite(xau_return):
        raise ValueError("returns must be finite")
    if wti_return > SIGN_DEADBAND and xau_return < -SIGN_DEADBAND:
        return 1
    if wti_return < -SIGN_DEADBAND and xau_return > SIGN_DEADBAND:
        return -1
    return 0


class WtiXauDivergenceReferenceTest(unittest.TestCase):
    def test_opposite_sign_matrix_is_strict(self) -> None:
        self.assertEqual(divergence_signal(0.2, -0.1), 1)
        self.assertEqual(divergence_signal(-0.2, 0.1), -1)
        self.assertEqual(divergence_signal(0.2, 0.1), 0)
        self.assertEqual(divergence_signal(-0.2, -0.1), 0)

    def test_deadband_consumes_state_flat(self) -> None:
        self.assertEqual(divergence_signal(SIGN_DEADBAND, -0.2), 0)
        self.assertEqual(divergence_signal(0.2, -SIGN_DEADBAND), 0)
        self.assertEqual(divergence_signal(0.0, 0.0), 0)

    def test_exact_return_and_chain_identity(self) -> None:
        rising = [100.0, 98.0, 103.0, 101.0, 106.0, 104.0, 109.0, 108.0, 112.0, 111.0, 116.0, 115.0, 120.0]
        falling = list(reversed(rising))
        self.assertEqual(
            divergence_signal(twelve_month_return(rising), twelve_month_return(falling)),
            1,
        )
        self.assertEqual(
            divergence_signal(twelve_month_return(falling), twelve_month_return(rising)),
            -1,
        )

    def test_exact_timestamp_intersection_excludes_near_matches(self) -> None:
        decision = int(datetime(2026, 3, 2, tzinfo=timezone.utc).timestamp())
        jan = int(datetime(2026, 1, 30, tzinfo=timezone.utc).timestamp())
        feb = int(datetime(2026, 2, 27, tzinfo=timezone.utc).timestamp())
        wti = [(jan, 70.0), (feb, 72.0)]
        xau = [(jan + 1, 2000.0), (feb, 1950.0)]
        self.assertEqual(intersect_exact(wti, xau, decision), [(feb, 72.0, 1950.0)])

    def test_month_ends_are_last_common_close_and_consecutive(self) -> None:
        common: list[tuple[int, float, float]] = []
        for offset in range(13):
            year = 2025 + (11 + offset) // 12
            month = (11 + offset) % 12 + 1
            early = int(datetime(year, month, 5, tzinfo=timezone.utc).timestamp())
            late = int(datetime(year, month, 25, tzinfo=timezone.utc).timestamp())
            common.extend([(early, 50.0 + offset, 2100.0 - offset), (late, 60.0 + offset, 2000.0 - offset)])
        ends = synchronized_month_ends(common)
        self.assertEqual(len(ends), 13)
        self.assertEqual(ends[0][0], 202512)
        self.assertEqual(ends[-1][0], 202612)
        self.assertEqual(ends[-1][1:], (72.0, 1988.0))

    def test_missing_month_and_invalid_price_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "thirteen"):
            twelve_month_return([100.0] * 12)
        with self.assertRaisesRegex(ValueError, "positive"):
            twelve_month_return([100.0] * 12 + [0.0])
        common = []
        for month in range(1, 14):
            normalized_month = ((month - 1) % 12) + 1
            year = 2025 + (month - 1) // 12
            if normalized_month == 7:
                continue
            stamp = int(datetime(year, normalized_month, 25, tzinfo=timezone.utc).timestamp())
            common.append((stamp, 70.0, 2000.0))
        with self.assertRaisesRegex(ValueError, "thirteen|consecutive"):
            synchronized_month_ends(common)

    def test_gold_magnitude_never_sizes_or_inverts_wti(self) -> None:
        self.assertEqual(divergence_signal(0.01, -0.50), 1)
        self.assertEqual(divergence_signal(-0.01, 0.50), -1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
