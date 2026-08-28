"""Independent deterministic fixtures for QM5_41190's monthly ratio basket."""

from __future__ import annotations

import json
import math
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
MONTH_COUNT = 13
HISTORY_BARS = 900
MAX_ENDPOINT_GAP_DAYS = 10


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class TheilSenResult:
    valid: bool = False
    direction: int = 0
    slope_count: int = 0
    median_left_index: int = -1
    median_right_index: int = -1
    center_low: float = 0.0
    center_high: float = 0.0
    slope: float = 0.0
    endpoint_displacement: float = 0.0
    ratios: tuple[float, ...] = ()
    selected_times: tuple[datetime, ...] = ()


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def previous_month_key(value: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year - 1) * 100 + 12 if month == 1 else year * 100 + month - 1


def previous_months(current: int, count: int = MONTH_COUNT) -> list[int]:
    result: list[int] = []
    key = current
    for _ in range(count):
        key = previous_month_key(key)
        result.append(key)
    return result


def _series_valid(bars: list[CloseBar]) -> bool:
    return (
        len(bars) == HISTORY_BARS
        and all(math.isfinite(bar.close) and bar.close > 0.0 for bar in bars)
        and all(bars[index - 1].opened > bars[index].opened for index in range(1, len(bars)))
    )


def make_fixture(
    chronological_ratios: list[float],
    *,
    missing_month: int = 0,
) -> tuple[datetime, list[CloseBar], list[CloseBar]]:
    """Make 900-bar newest-first series with deliberate unmatched days."""

    if len(chronological_ratios) != MONTH_COUNT:
        raise ValueError("exactly thirteen ratios are required")
    current_bar = datetime(2026, 8, 3, tzinfo=UTC)
    newest_first_keys = previous_months(month_key(current_bar))
    ratio_by_key = dict(zip(reversed(newest_first_keys), chronological_ratios))
    xti = [CloseBar(datetime(2026, 8, 1, tzinfo=UTC), math.exp(9.0))]
    xng = [CloseBar(datetime(2026, 8, 1, tzinfo=UTC), 1.0)]

    for key in newest_first_keys:
        year, month = divmod(key, 100)
        ratio = ratio_by_key[key]
        # Day 27 exists only in XTI and day 26 only in XNG. Day 25 is the
        # latest exact pair and day 20 proves that the first match is used.
        xti.extend(
            (
                CloseBar(datetime(year, month, 27, tzinfo=UTC), math.exp(ratio + 4.0)),
                CloseBar(datetime(year, month, 25, tzinfo=UTC), math.exp(ratio)),
                CloseBar(datetime(year, month, 20, tzinfo=UTC), math.exp(ratio - 0.5)),
            )
        )
        offset = timedelta(hours=1) if key == missing_month else timedelta(0)
        xng.extend(
            (
                CloseBar(datetime(year, month, 26, tzinfo=UTC), 1.0),
                CloseBar(datetime(year, month, 25, tzinfo=UTC) + offset, 1.0),
                CloseBar(datetime(year, month, 20, tzinfo=UTC) + offset, 1.0),
            )
        )

    filler_start = datetime(2025, 6, 30, tzinfo=UTC)
    filler_index = 0
    while len(xti) < HISTORY_BARS:
        opened = filler_start - timedelta(days=filler_index)
        xti.append(CloseBar(opened, math.exp(-0.25)))
        filler_index += 1
    filler_index = 0
    while len(xng) < HISTORY_BARS:
        opened = filler_start - timedelta(days=filler_index)
        xng.append(CloseBar(opened, 1.0))
        filler_index += 1
    return current_bar, sorted(xti, key=lambda bar: bar.opened, reverse=True), sorted(
        xng, key=lambda bar: bar.opened, reverse=True
    )


def select_month_ends(
    current_bar: datetime,
    xti_bars: list[CloseBar],
    xng_bars: list[CloseBar],
) -> tuple[list[float], list[datetime]] | None:
    """Mirror the exact-timestamp, latest-match, consecutive-month scan."""

    if not _series_valid(xti_bars) or not _series_valid(xng_bars):
        return None
    current_key = month_key(current_bar)
    expected = previous_month_key(current_key)
    xti_index = 0
    xng_index = 0
    newest_ratios: list[float] = []
    newest_times: list[datetime] = []
    while len(newest_ratios) < MONTH_COUNT:
        found = False
        while xti_index < len(xti_bars) and xng_index < len(xng_bars):
            xti = xti_bars[xti_index]
            xng = xng_bars[xng_index]
            if xti.opened > xng.opened:
                xti_index += 1
                continue
            if xng.opened > xti.opened:
                xng_index += 1
                continue
            matched_key = month_key(xti.opened)
            if xti.opened >= current_bar:
                return None
            if matched_key > expected:
                xti_index += 1
                xng_index += 1
                continue
            if matched_key < expected:
                return None
            ratio = math.log(xti.close) - math.log(xng.close)
            if not math.isfinite(ratio):
                return None
            newest_ratios.append(ratio)
            newest_times.append(xti.opened)
            xti_index += 1
            xng_index += 1
            found = True
            break
        if not found:
            return None
        expected = previous_month_key(expected)

    if current_bar - newest_times[0] > timedelta(days=MAX_ENDPOINT_GAP_DAYS):
        return None
    return list(reversed(newest_ratios)), list(reversed(newest_times))


def classify_ratios(ratios: list[float], times: list[datetime] | None = None) -> TheilSenResult:
    if len(ratios) != MONTH_COUNT or not all(math.isfinite(value) for value in ratios):
        return TheilSenResult()
    slopes = sorted(
        (ratios[j] - ratios[i]) / (j - i)
        for i in range(MONTH_COUNT - 1)
        for j in range(i + 1, MONTH_COUNT)
    )
    if len(slopes) != 78:
        return TheilSenResult()
    left = len(slopes) // 2 - 1
    right = len(slopes) // 2
    slope = slopes[left] / 2.0 + slopes[right] / 2.0
    direction = 1 if slope < 0.0 else -1 if slope > 0.0 else 0
    return TheilSenResult(
        valid=True,
        direction=direction,
        slope_count=len(slopes),
        median_left_index=left,
        median_right_index=right,
        center_low=slopes[left],
        center_high=slopes[right],
        slope=slope,
        endpoint_displacement=ratios[-1] - ratios[0],
        ratios=tuple(ratios),
        selected_times=tuple(times or ()),
    )


def monthly_theilsen(
    current_bar: datetime,
    xti_bars: list[CloseBar],
    xng_bars: list[CloseBar],
) -> TheilSenResult:
    selected = select_month_ends(current_bar, xti_bars, xng_bars)
    return TheilSenResult() if selected is None else classify_ratios(*selected)


def round_down(value: float, step: float = 0.01, minimum: float = 0.01) -> float:
    rounded = math.floor((value + 1e-12) / step) * step
    return rounded if rounded + 1e-12 >= minimum else 0.0


def equal_notional_half_risk_package(
    full_xti_lots: float,
    full_xng_lots: float,
    xti_notional_per_lot: float,
    xng_notional_per_lot: float,
) -> tuple[float, float, float, float]:
    xti = 0.5 * full_xti_lots
    xng = 0.5 * full_xng_lots
    if xti * xti_notional_per_lot > xng * xng_notional_per_lot:
        xti = xng * xng_notional_per_lot / xti_notional_per_lot
    else:
        xng = xti * xti_notional_per_lot / xng_notional_per_lot
    xti = round_down(xti)
    xng = round_down(xng)
    risk = xti / full_xti_lots + xng / full_xng_lots
    ratio = xti * xti_notional_per_lot / (xng * xng_notional_per_lot)
    return xti, xng, risk, ratio


class MonthlyTheilSenRatioReferenceTest(unittest.TestCase):
    def test_previous_month_keys_cross_year_without_gaps(self) -> None:
        self.assertEqual(previous_month_key(202601), 202512)
        self.assertEqual(previous_months(202608)[-1], 202507)
        self.assertEqual(previous_month_key(202600), 0)

    def test_latest_exact_pairs_are_selected_and_current_month_is_excluded(self) -> None:
        expected = [-0.06 + 0.01 * index for index in range(MONTH_COUNT)]
        current, xti, xng = make_fixture(expected)
        result = monthly_theilsen(current, xti, xng)
        self.assertTrue(result.valid)
        self.assertEqual(result.slope_count, 78)
        self.assertEqual((result.median_left_index, result.median_right_index), (38, 39))
        self.assertTrue(all(value < 1.0 for value in result.ratios))
        for actual, wanted in zip(result.ratios, expected):
            self.assertAlmostEqual(actual, wanted, places=12)
        self.assertTrue(all(value.day == 25 for value in result.selected_times))
        self.assertAlmostEqual(result.slope, 0.01, places=12)
        self.assertEqual(result.direction, -1)

    def test_missing_synchronized_month_and_stale_endpoint_fail_closed(self) -> None:
        ratios = [0.01 * index for index in range(MONTH_COUNT)]
        current, xti, xng = make_fixture(ratios, missing_month=202601)
        self.assertFalse(monthly_theilsen(current, xti, xng).valid)
        current, xti, xng = make_fixture(ratios)
        self.assertFalse(monthly_theilsen(current + timedelta(days=2), xti, xng).valid)

    def test_all_forward_slopes_and_strict_fade_direction(self) -> None:
        positive = classify_ratios([0.02 * index for index in range(MONTH_COUNT)])
        negative = classify_ratios([-0.02 * index for index in range(MONTH_COUNT)])
        flat = classify_ratios([0.0] * MONTH_COUNT)
        self.assertEqual((positive.slope_count, positive.direction), (78, -1))
        self.assertEqual((negative.slope_count, negative.direction), (78, 1))
        self.assertEqual((flat.slope, flat.direction), (0.0, 0))
        self.assertAlmostEqual(positive.center_low, 0.02, places=14)
        self.assertAlmostEqual(positive.center_high, 0.02, places=14)

    def test_endpoint_displacement_is_diagnostic_only(self) -> None:
        # Twelve endpoint-involving slopes are negative, while the other 66
        # forward slopes retain the positive robust path direction.
        ratios = [0.01 * index for index in range(12)] + [-1.0]
        result = classify_ratios(ratios)
        self.assertTrue(result.valid)
        self.assertLess(result.endpoint_displacement, 0.0)
        self.assertGreater(result.slope, 0.0)
        self.assertEqual(result.direction, -1)

    def test_governed_vectors_separate_existing_robust_estimators(self) -> None:
        # Existing QM5_41188 repeated median is -0.0045 on this vector.
        repeated_median_counterexample = [
            0.0, 0.01, 0.06, 0.11, 0.14, 0.13, 0.11,
            0.12, 0.09, 0.04, 0.02, 0.05, 0.10,
        ]
        theilsen = classify_ratios(repeated_median_counterexample)
        self.assertAlmostEqual(theilsen.slope, 0.0015555555555555557, places=15)
        self.assertEqual(theilsen.direction, -1)

        # Existing QM5_41189 LAD is -0.002 on this vector.
        lad_counterexample = [
            0.0, 0.02, 0.0, 0.0, -0.06, -0.09, -0.05,
            -0.05, 0.03, 0.06, -0.02, -0.03, 0.05,
        ]
        theilsen = classify_ratios(lad_counterexample)
        self.assertAlmostEqual(theilsen.slope, 0.00303030303030303, places=15)
        self.assertEqual(theilsen.direction, -1)

    def test_notional_balance_only_reduces_half_risk_legs(self) -> None:
        xti, xng, normalized_risk, ratio = equal_notional_half_risk_package(
            0.50, 8.00, 250_000.0, 5_000.0
        )
        self.assertLessEqual(xti, 0.25)
        self.assertLessEqual(xng, 4.00)
        self.assertLessEqual(normalized_risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0), 0.20)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41190_xtixng-mtheilsen-rv.mq5").read_text(encoding="utf-8")
        for marker in (
            "input int    qm_ea_id                    = 41190;",
            "input int    strategy_month_end_count         = 13;",
            "input int    strategy_history_bars_d1         = 900;",
            "expected_slope_count != 78",
            "for(int i = 0; i < strategy_month_end_count - 1; ++i)",
            "for(int j = i + 1; j < strategy_month_end_count; ++j)",
            "(chronological_ratios[j] - chronological_ratios[i]) /",
            "median_left_index != 38 || median_right_index != 39",
            "if(theilsen_slope < 0.0)",
            "else if(theilsen_slope > 0.0)",
            "normalized_stop_risk <= 1.0 + 1.0e-8",
            "request.tp = 0.0;",
        ):
            self.assertIn(marker, source)
        self.assertNotIn("Strategy_LoadMonthlyLad(", source)
        self.assertNotIn("Strategy_LoadMonthlyRepeatedMedian(", source)
        for banned in ("irsi(", "imacd(", "ibands(", "iichimoku(", "webrequest("):
            self.assertNotIn(banned, source.lower())
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState(g_signal_month_key)"),
            on_tick.index("Strategy_EntryWindowReady(g_signal_month_key"),
        )
        self.assertLess(
            on_tick.index("Strategy_EntryWindowReady(g_signal_month_key"),
            on_tick.index("Strategy_EntrySignal(request)"),
        )

        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        for setfile in setfiles:
            content = setfile.read_text(encoding="utf-8")
            for marker in (
                "; environment:  backtest",
                "; risk_mode:    FIXED",
                "qm_ea_id=41190",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "PORTFOLIO_WEIGHT=1",
                "strategy_month_end_count=13",
                "strategy_history_bars_d1=900",
                "strategy_atr_sl_mult=3.5",
                "strategy_notional_ratio=1.0",
                "strategy_max_notional_mismatch_fraction=0.20",
                "strategy_xng_max_spread_points=3000",
            ):
                self.assertIn(marker, content)

        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["logical_symbol"], "QM5_41190_XTI_XNG_MTHEILSEN_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XTIUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])

        approved = REPO_ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41190_xtixng-mtheilsen-rv_card.md"
        local = EA_DIR / "docs" / "strategy_card.md"
        self.assertEqual(approved.read_bytes(), local.read_bytes())
        magic_rows = (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(
            encoding="utf-8-sig"
        )
        self.assertIn("41190,xtixng-mtheilsen-rv,0,XTIUSD.DWX,411900000", magic_rows)
        self.assertIn("41190,xtixng-mtheilsen-rv,1,XNGUSD.DWX,411900001", magic_rows)
        resolver = (
            REPO_ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("411900000", resolver)
        self.assertIn("411900001", resolver)


if __name__ == "__main__":
    unittest.main()
