"""Independent deterministic fixtures for QM5_41164's repeated-median basket."""

from __future__ import annotations

import csv
import json
import math
import statistics
import unittest
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path


UTC = timezone.utc
EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
MONTH_COUNT = 13
HISTORY_BARS = 500
MAX_ENDPOINT_GAP_DAYS = 10


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class RepeatedMedianResult:
    valid: bool = False
    direction: int = 0
    grouped_slope_count: int = 0
    pivot_median_count: int = 0
    inner_median_min: float = 0.0
    inner_median_max: float = 0.0
    repeated_median: float = 0.0
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


def classify_ratios(
    ratios: list[float], times: list[datetime] | None = None
) -> RepeatedMedianResult:
    if len(ratios) != MONTH_COUNT or any(not math.isfinite(value) for value in ratios):
        return RepeatedMedianResult()

    grouped_count = 0
    pivot_medians: list[float] = []
    for pivot in range(MONTH_COUNT):
        slopes = []
        for other in range(MONTH_COUNT):
            if other == pivot:
                continue
            lower, upper = sorted((pivot, other))
            slopes.append((ratios[upper] - ratios[lower]) / (upper - lower))
            grouped_count += 1
        if len(slopes) != 12 or any(not math.isfinite(value) for value in slopes):
            return RepeatedMedianResult()
        ordered = sorted(slopes)
        pivot_medians.append(ordered[5] / 2.0 + ordered[6] / 2.0)

    if grouped_count != 156 or len(pivot_medians) != 13:
        return RepeatedMedianResult()
    repeated_median = sorted(pivot_medians)[6]
    if not math.isfinite(repeated_median):
        return RepeatedMedianResult()
    direction = 1 if repeated_median < 0.0 else -1 if repeated_median > 0.0 else 0
    return RepeatedMedianResult(
        valid=True,
        direction=direction,
        grouped_slope_count=grouped_count,
        pivot_median_count=len(pivot_medians),
        inner_median_min=min(pivot_medians),
        inner_median_max=max(pivot_medians),
        repeated_median=repeated_median,
        endpoint_displacement=ratios[-1] - ratios[0],
        ratios=tuple(ratios),
        selected_times=tuple(times or ()),
    )


def theil_sen_slope(ratios: list[float]) -> float:
    return statistics.median(
        (ratios[newer] - ratios[older]) / (newer - older)
        for older in range(MONTH_COUNT - 1)
        for newer in range(older + 1, MONTH_COUNT)
    )


def lad_slope(ratios: list[float]) -> float:
    candidates = [
        (ratios[newer] - ratios[older]) / (newer - older)
        for older in range(MONTH_COUNT - 1)
        for newer in range(older + 1, MONTH_COUNT)
    ]
    losses = []
    for slope in candidates:
        residuals = [ratios[index] - slope * index for index in range(MONTH_COUNT)]
        intercept = statistics.median(residuals)
        losses.append(
            sum(
                abs(ratios[index] - intercept - slope * index)
                for index in range(MONTH_COUNT)
            )
        )
    minimum = min(losses)
    return statistics.median(
        slope
        for slope, loss in zip(candidates, losses, strict=True)
        if abs(loss - minimum) <= 1.0e-12
    )


def _series_valid(bars: list[CloseBar]) -> bool:
    return (
        len(bars) == HISTORY_BARS
        and all(math.isfinite(bar.close) and bar.close > 0.0 for bar in bars)
        and all(
            bars[index - 1].opened > bars[index].opened
            for index in range(1, len(bars))
        )
    )


def make_fixture(
    chronological_ratios: list[float], *, missing_month: int = 0
) -> tuple[datetime, list[CloseBar], list[CloseBar]]:
    """Make newest-first series with unmatched days around each latest pair."""

    if len(chronological_ratios) != MONTH_COUNT:
        raise ValueError("exactly thirteen ratios are required")
    current_bar = datetime(2026, 8, 3, tzinfo=UTC)
    newest_first_keys = previous_months(month_key(current_bar))
    ratio_by_key = dict(zip(reversed(newest_first_keys), chronological_ratios))
    xau = [CloseBar(datetime(2026, 8, 1, tzinfo=UTC), math.exp(9.0))]
    xag = [CloseBar(datetime(2026, 8, 1, tzinfo=UTC), 1.0)]

    for key in newest_first_keys:
        year, month = divmod(key, 100)
        ratio = ratio_by_key[key]
        xau.extend(
            (
                CloseBar(datetime(year, month, 27, tzinfo=UTC), math.exp(ratio + 4.0)),
                CloseBar(datetime(year, month, 25, tzinfo=UTC), math.exp(ratio)),
                CloseBar(datetime(year, month, 20, tzinfo=UTC), math.exp(ratio - 0.5)),
            )
        )
        offset = timedelta(hours=1) if key == missing_month else timedelta(0)
        xag.extend(
            (
                CloseBar(datetime(year, month, 26, tzinfo=UTC), 1.0),
                CloseBar(datetime(year, month, 25, tzinfo=UTC) + offset, 1.0),
                CloseBar(datetime(year, month, 20, tzinfo=UTC) + offset, 1.0),
            )
        )

    filler_start = datetime(2025, 6, 30, tzinfo=UTC)
    while len(xau) < HISTORY_BARS:
        xau.append(CloseBar(filler_start - timedelta(days=len(xau)), math.exp(-0.25)))
    while len(xag) < HISTORY_BARS:
        xag.append(CloseBar(filler_start - timedelta(days=len(xag)), 1.0))
    return current_bar, sorted(xau, key=lambda bar: bar.opened, reverse=True), sorted(
        xag, key=lambda bar: bar.opened, reverse=True
    )


def select_month_ends(
    current_bar: datetime, xau_bars: list[CloseBar], xag_bars: list[CloseBar]
) -> tuple[list[float], list[datetime]] | None:
    if not _series_valid(xau_bars) or not _series_valid(xag_bars):
        return None
    expected = previous_month_key(month_key(current_bar))
    xau_index = 0
    xag_index = 0
    newest_ratios: list[float] = []
    newest_times: list[datetime] = []
    while len(newest_ratios) < MONTH_COUNT:
        found = False
        while xau_index < len(xau_bars) and xag_index < len(xag_bars):
            xau = xau_bars[xau_index]
            xag = xag_bars[xag_index]
            if xau.opened > xag.opened:
                xau_index += 1
                continue
            if xag.opened > xau.opened:
                xag_index += 1
                continue
            matched_key = month_key(xau.opened)
            if xau.opened >= current_bar:
                return None
            if matched_key > expected:
                xau_index += 1
                xag_index += 1
                continue
            if matched_key < expected:
                return None
            ratio = math.log(xau.close) - math.log(xag.close)
            if not math.isfinite(ratio):
                return None
            newest_ratios.append(ratio)
            newest_times.append(xau.opened)
            xau_index += 1
            xag_index += 1
            found = True
            break
        if not found:
            return None
        expected = previous_month_key(expected)

    if current_bar - newest_times[0] > timedelta(days=MAX_ENDPOINT_GAP_DAYS):
        return None
    return list(reversed(newest_ratios)), list(reversed(newest_times))


def monthly_repeated_median(
    current_bar: datetime, xau_bars: list[CloseBar], xag_bars: list[CloseBar]
) -> RepeatedMedianResult:
    selected = select_month_ends(current_bar, xau_bars, xag_bars)
    return RepeatedMedianResult() if selected is None else classify_ratios(*selected)


def round_down(value: float, step: float = 0.01, minimum: float = 0.01) -> float:
    rounded = math.floor((value + 1.0e-12) / step) * step
    return rounded if rounded + 1.0e-12 >= minimum else 0.0


def equal_notional_half_risk_package(
    full_xau_lots: float,
    full_xag_lots: float,
    xau_notional_per_lot: float,
    xag_notional_per_lot: float,
) -> tuple[float, float, float, float]:
    xau = 0.5 * full_xau_lots
    xag = 0.5 * full_xag_lots
    if xau * xau_notional_per_lot > xag * xag_notional_per_lot:
        xau = xag * xag_notional_per_lot / xau_notional_per_lot
    else:
        xag = xau * xau_notional_per_lot / xag_notional_per_lot
    xau = round_down(xau)
    xag = round_down(xag)
    risk = xau / full_xau_lots + xag / full_xag_lots
    ratio = xau * xau_notional_per_lot / (xag * xag_notional_per_lot)
    return xau, xag, risk, ratio


class MonthlyRepeatedMedianRatioReferenceTests(unittest.TestCase):
    def test_year_rollover_and_exact_latest_synchronized_pairs(self) -> None:
        self.assertEqual(previous_month_key(202601), 202512)
        self.assertEqual(previous_months(202608)[-1], 202507)
        expected = [-0.06 + 0.01 * index for index in range(MONTH_COUNT)]
        current, xau, xag = make_fixture(expected)
        result = monthly_repeated_median(current, xau, xag)
        self.assertTrue(result.valid)
        self.assertEqual((result.grouped_slope_count, result.pivot_median_count), (156, 13))
        self.assertTrue(all(value.day == 25 for value in result.selected_times))
        self.assertAlmostEqual(result.repeated_median, 0.01, places=12)
        self.assertEqual(result.direction, -1)

    def test_missing_pair_and_stale_endpoint_fail_closed(self) -> None:
        ratios = [0.01 * index for index in range(MONTH_COUNT)]
        current, xau, xag = make_fixture(ratios, missing_month=202601)
        self.assertFalse(monthly_repeated_median(current, xau, xag).valid)
        current, xau, xag = make_fixture(ratios)
        self.assertFalse(monthly_repeated_median(current + timedelta(days=2), xau, xag).valid)

    def test_strict_fade_direction_and_zero(self) -> None:
        positive = classify_ratios([0.02 * index for index in range(MONTH_COUNT)])
        negative = classify_ratios([-0.02 * index for index in range(MONTH_COUNT)])
        flat = classify_ratios([0.0] * MONTH_COUNT)
        self.assertEqual((positive.direction, negative.direction, flat.direction), (-1, 1, 0))
        self.assertAlmostEqual(positive.repeated_median, 0.02, places=14)
        self.assertAlmostEqual(negative.repeated_median, -0.02, places=14)
        self.assertEqual(flat.repeated_median, 0.0)

    def test_fixed_counterexample_opposes_theilsen_and_lad_baskets(self) -> None:
        ratios = [0.0, 0.01, 0.06, 0.11, 0.14, 0.13, 0.11, 0.12, 0.09, 0.04, 0.02, 0.05, 0.10]
        repeated = classify_ratios(ratios)
        self.assertTrue(repeated.valid)
        self.assertAlmostEqual(theil_sen_slope(ratios), 0.00155555555555556, places=14)
        self.assertAlmostEqual(lad_slope(ratios), 0.00375, places=14)
        self.assertAlmostEqual(repeated.repeated_median, -0.0045, places=14)
        self.assertEqual(repeated.direction, 1)

    def test_notional_balance_only_reduces_half_risk_legs(self) -> None:
        xau, xag, normalized_risk, ratio = equal_notional_half_risk_package(
            0.50, 8.00, 250_000.0, 5_000.0
        )
        self.assertLessEqual(xau, 0.25)
        self.assertLessEqual(xag, 4.00)
        self.assertLessEqual(normalized_risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0), 0.20)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41164_xauxag-mrepmedian-rv.mq5").read_text(encoding="utf-8")
        required = (
            "input int    qm_ea_id                    = 41164;",
            "input int    strategy_month_end_count         = 13;",
            "const int slopes_per_pivot = strategy_month_end_count - 1;",
            "grouped_slope_count != 156",
            "center_low_index != 5 || center_high_index != 6",
            "outer_median_index != 6",
            "if(repeated_median < 0.0)",
            "else if(repeated_median > 0.0)",
            "normalized_stop_risk <= 1.0 + 1.0e-8",
            "request.tp = 0.0;",
        )
        for marker in required:
            self.assertIn(marker, source)
        for prohibited in ("Strategy_LoadMonthlyLad(", "strategy_loss_tie_epsilon", "iRSI(", "iMACD(", "iBands(", "WebRequest("):
            self.assertNotIn(prohibited.lower(), source.lower())
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState(g_signal_month_key)"),
            on_tick.index("Strategy_EntryWindowReady(g_signal_month_key"),
        )
        self.assertLess(on_tick.index("Strategy_ManageOpenPosition()"), on_tick.index("Strategy_EntrySignal(request)"))

        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        for setfile in setfiles:
            content = setfile.read_text(encoding="utf-8")
            for marker in (
                "; environment:  backtest",
                "; risk_mode:    FIXED",
                "qm_ea_id=41164",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "PORTFOLIO_WEIGHT=1",
                "strategy_month_end_count=13",
                "strategy_history_bars_d1=500",
                "strategy_atr_sl_mult=3.5",
                "strategy_notional_ratio=1.0",
                "strategy_max_notional_mismatch_fraction=0.20",
            ):
                self.assertIn(marker, content)
            self.assertNotIn("strategy_loss_tie_epsilon", content)

        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["logical_symbol"], "QM5_41164_XAU_XAG_MREPMEDIAN_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XAUUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XAUUSD.DWX", "XAGUSD.DWX"])

    def test_identity_magic_and_approved_card_are_bound(self) -> None:
        with (REPO_ROOT / "framework/registry/ea_id_registry.csv").open(newline="", encoding="utf-8-sig") as handle:
            identities = [row for row in csv.DictReader(handle) if row["ea_id"] == "41164" and row["status"] == "active"]
        self.assertEqual(len(identities), 1)
        self.assertEqual(identities[0]["slug"], "xauxag-mrepmedian-rv")

        with (REPO_ROOT / "framework/registry/magic_numbers.csv").open(newline="", encoding="utf-8-sig") as handle:
            magics = [row for row in csv.DictReader(handle) if row["ea_id"] == "41164" and row["status"] == "active"]
        self.assertEqual(
            [(row["symbol_slot"], row["symbol"], row["magic"]) for row in magics],
            [("0", "XAUUSD.DWX", "411640000"), ("1", "XAGUSD.DWX", "411640001")],
        )

        approved = REPO_ROOT / "strategy-seeds/cards/approved/QM5_41164_xauxag-mrepmedian-rv_card.md"
        local = EA_DIR / "docs/strategy_card.md"
        self.assertEqual(approved.read_bytes(), local.read_bytes())


if __name__ == "__main__":
    unittest.main()
