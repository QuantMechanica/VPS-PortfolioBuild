"""Independent deterministic fixtures for QM5_41189's monthly LAD basket."""

from __future__ import annotations

import csv
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
LOSS_EPSILON = 1.0e-12


@dataclass(frozen=True)
class CloseBar:
    opened: datetime
    close: float


@dataclass(frozen=True)
class LadResult:
    valid: bool = False
    direction: int = 0
    candidate_count: int = 0
    objective_count: int = 0
    minimizer_count: int = 0
    intercept: float = 0.0
    minimum_loss: float = 0.0
    final_loss: float = 0.0
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


def ordinary_median(values: list[float]) -> float:
    if not values or any(not math.isfinite(value) for value in values):
        raise ValueError("finite nonempty values required")
    ordered = sorted(values)
    center = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[center]
    return ordered[center - 1] / 2.0 + ordered[center] / 2.0


def classify_ratios(ratios: list[float], times: list[datetime] | None = None) -> LadResult:
    if len(ratios) != MONTH_COUNT or any(not math.isfinite(value) for value in ratios):
        return LadResult()

    candidates = [
        (ratios[newer] - ratios[older]) / (newer - older)
        for older in range(MONTH_COUNT - 1)
        for newer in range(older + 1, MONTH_COUNT)
    ]
    if len(candidates) != 78 or any(not math.isfinite(value) for value in candidates):
        return LadResult()

    losses: list[float] = []
    for slope in candidates:
        residuals = [ratios[index] - slope * index for index in range(MONTH_COUNT)]
        intercept = sorted(residuals)[6]
        loss = sum(
            abs(ratios[index] - intercept - slope * index)
            for index in range(MONTH_COUNT)
        )
        if not math.isfinite(intercept) or not math.isfinite(loss) or loss < 0.0:
            return LadResult()
        losses.append(loss)

    minimum_loss = min(losses)
    minimizers = sorted(
        slope
        for slope, loss in zip(candidates, losses, strict=True)
        if abs(loss - minimum_loss) <= LOSS_EPSILON
    )
    if not minimizers:
        return LadResult()
    slope = ordinary_median(minimizers)
    final_residuals = [
        ratios[index] - slope * index for index in range(MONTH_COUNT)
    ]
    intercept = sorted(final_residuals)[6]
    final_loss = sum(
        abs(ratios[index] - intercept - slope * index)
        for index in range(MONTH_COUNT)
    )
    if abs(final_loss - minimum_loss) > LOSS_EPSILON:
        return LadResult()

    # The EA fades the ratio slope: positive means short XTI/long XNG.
    direction = 1 if slope < 0.0 else -1 if slope > 0.0 else 0
    return LadResult(
        valid=True,
        direction=direction,
        candidate_count=len(candidates),
        objective_count=len(losses),
        minimizer_count=len(minimizers),
        intercept=intercept,
        minimum_loss=minimum_loss,
        final_loss=final_loss,
        slope=slope,
        endpoint_displacement=ratios[-1] - ratios[0],
        ratios=tuple(ratios),
        selected_times=tuple(times or ()),
    )


def all_pair_median(ratios: list[float]) -> float:
    return ordinary_median(
        [
            (ratios[newer] - ratios[older]) / (newer - older)
            for older in range(MONTH_COUNT - 1)
            for newer in range(older + 1, MONTH_COUNT)
        ]
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
    chronological_ratios: list[float],
    *,
    missing_month: int = 0,
) -> tuple[datetime, list[CloseBar], list[CloseBar]]:
    """Make newest-first series with unmatched days around each latest pair."""

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
    while len(xti) < HISTORY_BARS:
        xti.append(CloseBar(filler_start - timedelta(days=len(xti)), math.exp(-0.25)))
    while len(xng) < HISTORY_BARS:
        xng.append(CloseBar(filler_start - timedelta(days=len(xng)), 1.0))
    return current_bar, sorted(xti, key=lambda bar: bar.opened, reverse=True), sorted(
        xng, key=lambda bar: bar.opened, reverse=True
    )


def select_month_ends(
    current_bar: datetime,
    xti_bars: list[CloseBar],
    xng_bars: list[CloseBar],
) -> tuple[list[float], list[datetime]] | None:
    """Mirror exact-timestamp, latest-match, consecutive-month selection."""

    if not _series_valid(xti_bars) or not _series_valid(xng_bars):
        return None
    expected = previous_month_key(month_key(current_bar))
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


def monthly_lad(
    current_bar: datetime,
    xti_bars: list[CloseBar],
    xng_bars: list[CloseBar],
) -> LadResult:
    selected = select_month_ends(current_bar, xti_bars, xng_bars)
    return LadResult() if selected is None else classify_ratios(*selected)


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


class MonthlyLadRatioReferenceTests(unittest.TestCase):
    def test_year_rollover_and_exact_latest_synchronized_pairs(self) -> None:
        self.assertEqual(previous_month_key(202601), 202512)
        self.assertEqual(previous_months(202608)[-1], 202507)
        expected = [-0.06 + 0.01 * index for index in range(MONTH_COUNT)]
        current, xti, xng = make_fixture(expected)
        result = monthly_lad(current, xti, xng)
        self.assertTrue(result.valid)
        self.assertEqual((result.candidate_count, result.objective_count), (78, 78))
        self.assertTrue(all(value.day == 25 for value in result.selected_times))
        for actual, wanted in zip(result.ratios, expected, strict=True):
            self.assertAlmostEqual(actual, wanted, places=12)
        self.assertAlmostEqual(result.slope, 0.01, places=12)
        self.assertEqual(result.direction, -1)

    def test_missing_pair_and_stale_endpoint_fail_closed(self) -> None:
        ratios = [0.01 * index for index in range(MONTH_COUNT)]
        current, xti, xng = make_fixture(ratios, missing_month=202601)
        self.assertFalse(monthly_lad(current, xti, xng).valid)
        current, xti, xng = make_fixture(ratios)
        self.assertFalse(monthly_lad(current + timedelta(days=2), xti, xng).valid)

    def test_strict_fade_direction_and_zero_tie_face(self) -> None:
        positive = classify_ratios([0.02 * index for index in range(MONTH_COUNT)])
        negative = classify_ratios([-0.02 * index for index in range(MONTH_COUNT)])
        flat = classify_ratios([0.0] * MONTH_COUNT)
        self.assertEqual((positive.direction, negative.direction, flat.direction), (-1, 1, 0))
        self.assertAlmostEqual(positive.slope, 0.02, places=14)
        self.assertAlmostEqual(negative.slope, -0.02, places=14)
        self.assertEqual(flat.slope, 0.0)
        self.assertEqual(flat.minimizer_count, 78)
        self.assertAlmostEqual(flat.final_loss, flat.minimum_loss, places=14)

    def test_fixed_counterexample_is_opposite_existing_theil_sen_basket(self) -> None:
        ratios = [
            0.0, 0.02, 0.0, 0.0, -0.06, -0.09, -0.05,
            -0.05, 0.03, 0.06, -0.02, -0.03, 0.05,
        ]
        lad = classify_ratios(ratios)
        theil_sen = all_pair_median(ratios)
        self.assertTrue(lad.valid)
        self.assertAlmostEqual(lad.slope, -0.002, places=14)
        self.assertAlmostEqual(theil_sen, 0.00303030303030303, places=14)
        self.assertEqual(lad.direction, 1)
        self.assertEqual(-1 if theil_sen > 0.0 else 1, -1)

    def test_profiled_intercept_and_loss_counts(self) -> None:
        ratios = [0.003 * index + (0.02 if index == 4 else 0.0) for index in range(13)]
        result = classify_ratios(ratios)
        self.assertTrue(result.valid)
        self.assertEqual((result.candidate_count, result.objective_count), (78, 78))
        self.assertGreaterEqual(result.minimizer_count, 1)
        self.assertAlmostEqual(result.slope, 0.003, places=14)
        self.assertAlmostEqual(result.intercept, 0.0, places=14)
        self.assertAlmostEqual(result.final_loss, result.minimum_loss, places=12)

    def test_notional_balance_only_reduces_half_risk_legs(self) -> None:
        xti, xng, normalized_risk, ratio = equal_notional_half_risk_package(
            0.50, 8.00, 250_000.0, 5_000.0
        )
        self.assertLessEqual(xti, 0.25)
        self.assertLessEqual(xng, 4.00)
        self.assertLessEqual(normalized_risk, 1.0)
        self.assertLessEqual(abs(ratio - 1.0), 0.20)

    def test_static_build_contract_matches_approved_card(self) -> None:
        source = (EA_DIR / "QM5_41189_xtixng-mlad-rv.mq5").read_text(encoding="utf-8")
        required = (
            "input int    qm_ea_id                    = 41189;",
            "input int    strategy_month_end_count         = 13;",
            "input double strategy_loss_tie_epsilon         = 1.0e-12;",
            "expected_candidate_count != 78",
            "residuals[intercept_index]",
            "loss += term",
            "ArraySort(minimizers)",
            "if(lad_slope < 0.0)",
            "else if(lad_slope > 0.0)",
            "normalized_stop_risk <= 1.0 + 1.0e-8",
            "request.tp = 0.0;",
        )
        for marker in required:
            self.assertIn(marker, source)
        self.assertNotIn("Strategy_LoadMonthlyTheilSen(", source)
        for banned in ("irsi(", "imacd(", "ibands(", "iichimoku(", "webrequest("):
            self.assertNotIn(banned, source.lower())
        on_tick = source[source.index("void OnTick()") :]
        self.assertLess(
            on_tick.index("Strategy_RecordAttemptState(g_signal_month_key)"),
            on_tick.index("Strategy_EntryWindowReady(g_signal_month_key"),
        )
        self.assertLess(
            on_tick.index("Strategy_ManageOpenPosition()"),
            on_tick.index("Strategy_EntrySignal(request)"),
        )

        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        for setfile in setfiles:
            content = setfile.read_text(encoding="utf-8")
            for marker in (
                "; environment:  backtest",
                "; risk_mode:    FIXED",
                "qm_ea_id=41189",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "PORTFOLIO_WEIGHT=1",
                "strategy_month_end_count=13",
                "strategy_history_bars_d1=900",
                "strategy_loss_tie_epsilon=0.000000000001",
                "strategy_atr_sl_mult=3.5",
                "strategy_notional_ratio=1.0",
                "strategy_max_notional_mismatch_fraction=0.20",
            ):
                self.assertIn(marker, content)

        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["logical_symbol"], "QM5_41189_XTI_XNG_MLAD_RV_D1")
        self.assertEqual(manifest["host_symbol"], "XTIUSD.DWX")
        self.assertEqual(manifest["traded_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"])

    def test_identity_magic_and_approved_card_are_bound(self) -> None:
        with (REPO_ROOT / "framework/registry/ea_id_registry.csv").open(
            newline="", encoding="utf-8-sig"
        ) as handle:
            identities = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41189" and row["status"] == "active"
            ]
        self.assertEqual(len(identities), 1)
        self.assertEqual(identities[0]["slug"], "xtixng-mlad-rv")

        with (REPO_ROOT / "framework/registry/magic_numbers.csv").open(
            newline="", encoding="utf-8-sig"
        ) as handle:
            magics = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41189" and row["status"] == "active"
            ]
        self.assertEqual(
            [(row["symbol_slot"], row["symbol"], row["magic"]) for row in magics],
            [
                ("0", "XTIUSD.DWX", "411890000"),
                ("1", "XNGUSD.DWX", "411890001"),
            ],
        )

        approved = REPO_ROOT / "strategy-seeds/cards/approved/QM5_41189_xtixng-mlad-rv_card.md"
        local = EA_DIR / "docs/strategy_card.md"
        self.assertEqual(approved.read_bytes(), local.read_bytes())


if __name__ == "__main__":
    unittest.main()
