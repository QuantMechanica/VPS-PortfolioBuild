from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path
import re
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41268_wti-mepps-shift-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41268_wti-mepps-shift-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41268_wti-mepps-shift-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
SOURCE_PACKET = (
    REPO_ROOT
    / "strategy-seeds"
    / "sources"
    / "AI-CODEX-WTI-MEPPS-SHIFT-20260901"
    / "source.md"
)
RETRIEVAL_RECORD = SOURCE_PACKET.with_name("retrieval_route_20260901.json")

CLOSE_COUNT = 51
RETURN_COUNT = 50
BLOCK_SIZE = 25
POINT_1 = 0.4
POINT_2 = 0.8
STATISTIC_GATE = 3.356693980033321
PIVOT_EPSILON = 1e-12
INVERSE_RESIDUAL_TOLERANCE = 1e-8
NEGATIVE_STAT_TOLERANCE = 1e-10
DIRECTION_EPSILON = 1e-12


@dataclass(frozen=True)
class Signal:
    direction: int
    qualifies: bool
    q25: float
    q75: float
    sigma: float
    t1: float
    t2: float
    inverse_residual: float
    statistic_w: float
    recent_return: float


def default_linear_quartiles(values: list[float]) -> tuple[float, float]:
    if len(values) != RETURN_COUNT:
        raise ValueError("fifty values required")
    if any(not math.isfinite(value) for value in values):
        raise ValueError("finite values required")
    ordered = sorted(values)
    q25 = ordered[12] + 0.25 * (ordered[13] - ordered[12])
    q75 = ordered[36] + 0.75 * (ordered[37] - ordered[36])
    return q25, q75


def ecf_features(value: float, t1: float, t2: float) -> tuple[float, ...]:
    features = (
        math.cos(t1 * value),
        math.cos(t2 * value),
        math.sin(t1 * value),
        math.sin(t2 * value),
    )
    if any(not math.isfinite(feature) for feature in features):
        raise ValueError("invalid feature")
    return features


def block_feature_moments(
    values: list[float], t1: float, t2: float
) -> tuple[tuple[float, ...], tuple[float, ...]]:
    if len(values) != BLOCK_SIZE:
        raise ValueError("twenty-five values required")
    rows = [ecf_features(value, t1, t2) for value in values]
    mean = tuple(
        sum(row[column] for row in rows) / BLOCK_SIZE
        for column in range(4)
    )
    covariance = tuple(
        sum(
            (row[left] - mean[left]) * (row[right] - mean[right])
            for row in rows
        )
        / BLOCK_SIZE
        for left in range(4)
        for right in range(4)
    )
    return mean, covariance


def scaled_partial_pivot_inverse(
    matrix: tuple[float, ...] | list[float],
) -> tuple[tuple[float, ...], float]:
    if len(matrix) != 16 or any(not math.isfinite(x) for x in matrix):
        raise ValueError("finite 4x4 matrix required")
    augmented = [
        list(matrix[row * 4 : (row + 1) * 4])
        + [1.0 if row == column else 0.0 for column in range(4)]
        for row in range(4)
    ]
    row_scale = [max(abs(value) for value in row[:4]) for row in augmented]
    matrix_max = max(row_scale)
    pivot_floor = PIVOT_EPSILON * max(1.0, matrix_max)

    for column in range(4):
        candidates = [
            (
                abs(augmented[row][column]) / row_scale[row]
                if row_scale[row] > pivot_floor
                else -1.0,
                -row,
                row,
            )
            for row in range(column, 4)
        ]
        pivot_row = max(candidates)[2]
        if abs(augmented[pivot_row][column]) <= pivot_floor:
            raise ValueError("rank-deficient covariance")
        if pivot_row != column:
            augmented[column], augmented[pivot_row] = (
                augmented[pivot_row],
                augmented[column],
            )
            row_scale[column], row_scale[pivot_row] = (
                row_scale[pivot_row],
                row_scale[column],
            )

        pivot = augmented[column][column]
        if not math.isfinite(pivot) or abs(pivot) <= pivot_floor:
            raise ValueError("rank-deficient covariance")
        augmented[column] = [value / pivot for value in augmented[column]]
        if any(not math.isfinite(value) for value in augmented[column]):
            raise ValueError("invalid inverse")
        for row in range(4):
            if row == column:
                continue
            factor = augmented[row][column]
            augmented[row] = [
                augmented[row][cell] - factor * augmented[column][cell]
                for cell in range(8)
            ]
            if any(not math.isfinite(value) for value in augmented[row]):
                raise ValueError("invalid inverse")

    inverse = tuple(
        augmented[row][column + 4]
        for row in range(4)
        for column in range(4)
    )
    residual = max(
        abs(
            sum(
                matrix[row * 4 + inner] * inverse[inner * 4 + column]
                for inner in range(4)
            )
            - (1.0 if row == column else 0.0)
        )
        for row in range(4)
        for column in range(4)
    )
    if not math.isfinite(residual) or residual > INVERSE_RESIDUAL_TOLERANCE:
        raise ValueError("inverse residual")
    return inverse, residual


def normalize_statistic(value: float) -> float:
    if not math.isfinite(value):
        raise ValueError("finite statistic required")
    if value < 0.0:
        if value >= -NEGATIVE_STAT_TOLERANCE:
            return 0.0
        raise ValueError("negative statistic")
    return value


def epps_singleton_signal(returns: list[float]) -> Signal:
    if len(returns) != RETURN_COUNT or any(
        not math.isfinite(value) for value in returns
    ):
        raise ValueError("locked finite fifty-return sample required")
    q25, q75 = default_linear_quartiles(returns)
    sigma = (q75 - q25) / 2.0
    if not math.isfinite(sigma) or sigma <= 0.0:
        raise ValueError("positive semi-IQR required")
    t1 = POINT_1 / sigma
    t2 = POINT_2 / sigma
    mean_old, covariance_old = block_feature_moments(
        returns[:BLOCK_SIZE], t1, t2
    )
    mean_recent, covariance_recent = block_feature_moments(
        returns[BLOCK_SIZE:], t1, t2
    )
    estimated_covariance = tuple(
        2.0 * covariance_old[index] + 2.0 * covariance_recent[index]
        for index in range(16)
    )
    inverse, residual = scaled_partial_pivot_inverse(estimated_covariance)
    delta = tuple(
        mean_old[index] - mean_recent[index] for index in range(4)
    )
    statistic_w = normalize_statistic(
        RETURN_COUNT
        * sum(
            delta[row] * inverse[row * 4 + column] * delta[column]
            for row in range(4)
            for column in range(4)
        )
    )
    recent_return = sum(returns[BLOCK_SIZE:])
    qualifies = statistic_w >= STATISTIC_GATE
    direction = 0
    if qualifies and recent_return > DIRECTION_EPSILON:
        direction = 1
    elif qualifies and recent_return < -DIRECTION_EPSILON:
        direction = -1
    return Signal(
        direction,
        qualifies,
        q25,
        q75,
        sigma,
        t1,
        t2,
        residual,
        statistic_w,
        recent_return,
    )


def fixture_old() -> list[float]:
    return [
        0.004 * math.sin((index + 1) * 1.13)
        + 0.002 * math.cos((index + 1) * 0.37)
        + 0.0002 * ((index % 5) - 2)
        for index in range(BLOCK_SIZE)
    ]


def fixture_recent_long() -> list[float]:
    return [
        0.012
        + 0.006 * math.sin((index + 1) * 0.79)
        + 0.003 * math.cos((index + 1) * 1.41)
        + 0.0003 * ((index % 4) - 1.5)
        for index in range(BLOCK_SIZE)
    ]


def fixture_recent_sell() -> list[float]:
    return [
        -0.011
        + 0.005 * math.sin((index + 1) * 0.83)
        + 0.003 * math.cos((index + 1) * 1.23)
        + 0.00025 * ((index % 6) - 2.5)
        for index in range(BLOCK_SIZE)
    ]


def closes_from_returns(returns: list[float], start: float = 70.0) -> list[float]:
    closes = [start]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def parse_setfile(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    headers: dict[str, str] = {}
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith(";"):
            body = line[1:].strip()
            if ":" in body:
                key, value = body.split(":", 1)
                headers[key.strip()] = value.strip()
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class WtiEppsSingletonShiftTrendReferenceTests(unittest.TestCase):
    def test_chi_square_four_gate_is_exact_median_equation(self) -> None:
        survival = math.exp(-STATISTIC_GATE / 2.0) * (
            1.0 + STATISTIC_GATE / 2.0
        )
        self.assertAlmostEqual(survival, 0.5, places=15)

    def test_default_linear_quartile_indices_are_locked(self) -> None:
        q25, q75 = default_linear_quartiles([float(x) for x in range(50)])
        self.assertEqual((q25, q75, (q75 - q25) / 2.0), (12.25, 36.75, 12.25))

    def test_feature_order_is_cos_cos_sin_sin(self) -> None:
        value, t1, t2 = 0.017, 23.0, 47.0
        self.assertEqual(
            ecf_features(value, t1, t2),
            (
                math.cos(t1 * value),
                math.cos(t2 * value),
                math.sin(t1 * value),
                math.sin(t2 * value),
            ),
        )

    def test_fixed_long_fixture_matches_locked_arithmetic(self) -> None:
        signal = epps_singleton_signal(fixture_old() + fixture_recent_long())
        self.assertEqual((signal.qualifies, signal.direction), (True, 1))
        self.assertAlmostEqual(signal.q25, 3.7623678585846804e-06, places=17)
        self.assertAlmostEqual(signal.q75, 0.011011872802476959, places=16)
        self.assertAlmostEqual(signal.sigma, 0.005504055217309187, places=16)
        self.assertAlmostEqual(signal.t1, 72.67368952660168, places=11)
        self.assertAlmostEqual(signal.t2, 145.34737905320335, places=11)
        self.assertAlmostEqual(signal.statistic_w, 233.29397090701463, places=9)
        self.assertAlmostEqual(signal.recent_return, 0.30084610210438106, places=15)
        self.assertLess(signal.inverse_residual, INVERSE_RESIDUAL_TOLERANCE)

    def test_fixed_sell_fixture_matches_locked_arithmetic(self) -> None:
        signal = epps_singleton_signal(fixture_old() + fixture_recent_sell())
        self.assertEqual((signal.qualifies, signal.direction), (True, -1))
        self.assertAlmostEqual(signal.q25, -0.0110211577903532, places=16)
        self.assertAlmostEqual(signal.q75, -0.00018701455237788984, places=17)
        self.assertAlmostEqual(signal.sigma, 0.005417071618987655, places=16)
        self.assertAlmostEqual(signal.statistic_w, 219.58691223556315, places=9)
        self.assertAlmostEqual(signal.recent_return, -0.26738092414102177, places=15)

    def test_fixed_low_statistic_fixture_is_flat(self) -> None:
        returns = [
            0.004 * math.sin((index + 1) * 1.13)
            + 0.002 * math.cos((index + 1) * 0.37)
            + 0.0002 * ((index % 5) - 2)
            for index in range(RETURN_COUNT)
        ]
        signal = epps_singleton_signal(returns)
        self.assertFalse(signal.qualifies)
        self.assertEqual(signal.direction, 0)
        self.assertAlmostEqual(signal.statistic_w, 1.6438779252858395, places=11)

    def test_full_rank_inverse_and_singular_rejection(self) -> None:
        matrix = (
            4.0, 1.0, 0.5, 0.25,
            1.0, 3.0, 0.2, 0.1,
            0.5, 0.2, 2.5, 0.4,
            0.25, 0.1, 0.4, 1.75,
        )
        inverse, residual = scaled_partial_pivot_inverse(matrix)
        self.assertEqual(len(inverse), 16)
        self.assertLess(residual, 1e-14)
        with self.assertRaisesRegex(ValueError, "rank-deficient"):
            scaled_partial_pivot_inverse((1.0, 2.0, 3.0, 4.0) * 4)

    def test_degenerate_semi_iqr_and_negative_roundoff_guards(self) -> None:
        with self.assertRaisesRegex(ValueError, "semi-IQR"):
            epps_singleton_signal([0.01] * RETURN_COUNT)
        self.assertEqual(normalize_statistic(-0.5 * NEGATIVE_STAT_TOLERANCE), 0.0)
        with self.assertRaisesRegex(ValueError, "negative statistic"):
            normalize_statistic(-1.01 * NEGATIVE_STAT_TOLERANCE)

    def test_close_return_orientation_is_chronological(self) -> None:
        expected = fixture_old() + fixture_recent_long()
        closes = closes_from_returns(expected)
        self.assertEqual(len(closes), CLOSE_COUNT)
        recovered = [
            math.log(closes[index + 1] / closes[index])
            for index in range(RETURN_COUNT)
        ]
        for actual, target in zip(recovered, expected):
            self.assertAlmostEqual(actual, target, places=15)

    def test_source_contains_literal_formula_and_consumes_first(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        required = (
            "bool Strategy_EppsSingletonSignal",
            "metrics.q25 = sorted_returns[12] +",
            "metrics.q75 = sorted_returns[36] +",
            "metrics.sigma = (metrics.q75 - metrics.q25) / 2.0",
            "features[0] = MathCos(t1 * value)",
            "features[1] = MathCos(t2 * value)",
            "features[2] = MathSin(t1 * value)",
            "features[3] = MathSin(t2 * value)",
            "2.0 * cov_old[index] + 2.0 * cov_recent[index]",
            "Strategy_Invert4x4",
            "(double)strategy_return_count * quadratic_form",
            "metrics.statistic_w >= strategy_statistic_gate",
            "metrics.recent_return > strategy_direction_epsilon",
            "QM_FrameworkMagic() != 412680000",
            "RISK_FIXED != 1000.0",
            "qm_ea_id != 41268",
        )
        for literal in required:
            self.assertIn(literal, source)
        prepare = source[source.index("void Strategy_PrepareDecisionSignal") :]
        self.assertLess(
            prepare.index("Strategy_RecordMonthAttempt"),
            prepare.index("Strategy_LoadPreMonthCloses"),
        )
        self.assertEqual(source.count('input group "'), 6)
        for banned in (
            "iRSI",
            "iBands",
            "iMA(",
            "iMACD",
            "MathRand",
            "WebRequest",
            "FileOpen",
            "OnBookEvent",
        ):
            self.assertNotIn(banned, source)
        self.assertIsNone(re.search(r"\bp_?value\b", source, re.IGNORECASE))

    def test_setfile_is_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41268")
        self.assertEqual(headers["ea_slug"], "wti-mepps-shift-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertRegex(headers["build_hash"], r"^(pending|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41268",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_close_count": "51",
            "strategy_return_count": "50",
            "strategy_block_size": "25",
            "strategy_t1": "0.4",
            "strategy_t2": "0.8",
            "strategy_statistic_gate": "3.356693980033321",
            "strategy_inverse_pivot_epsilon": "0.000000000001",
            "strategy_inverse_residual_tolerance": "0.00000001",
            "strategy_negative_stat_tolerance": "0.0000000001",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars_d1": "80",
            "strategy_entry_grace_minutes": "180",
            "strategy_max_completed_bar_age_days": "4",
            "strategy_atr_period_d1": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_max_hold_days": "40",
            "strategy_max_spread_points": "1500",
            "strategy_deviation_points": "20",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

    def test_source_packet_pin_and_card_copy_are_preserved(self) -> None:
        packet = SOURCE_PACKET.read_text(encoding="utf-8-sig")
        retrieval = RETRIEVAL_RECORD.read_text(encoding="utf-8-sig")
        evidence = packet + retrieval
        self.assertIn("54ef5423f2e4376230ec3bfda6912a07a50958e3", evidence)
        self.assertIn("DD8520A88D5DC6D59DFCA0C8B077F068DDE674AF1917272C6E6B5356A63E9161", evidence)
        self.assertIn("4C60E5FFFAF2E96187036425F93B60980B7AA39DBF8A5E312ED0ED3883DC4CD2", evidence)
        self.assertEqual(EA_CARD.read_bytes(), CANONICAL_CARD.read_bytes())
        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(setfiles, [SETFILE])
        self.assertFalse(any("live" in path.name.lower() for path in setfiles))


if __name__ == "__main__":
    unittest.main()
