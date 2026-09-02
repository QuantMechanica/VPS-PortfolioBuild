from __future__ import annotations

import dataclasses
import json
import math
from pathlib import Path
import re
import unittest

import numpy as np


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41312_wti-mspectral-entropy-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41312_wti-mspectral-entropy-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41312_wti-mspectral-entropy-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
NULL_RECEIPT = (
    REPO_ROOT / "artifacts" / "qm5_wti_mspecent_tr_null_density_20260902.json"
)

RETURN_COUNT = 48
DFT_BINS = 24
TOTAL_POWER_FLOOR = 1e-24
PROBABILITY_TOLERANCE = 1e-10
ENTROPY_LOWER_TOLERANCE = 1e-12
ENTROPY_UPPER_TOLERANCE = 1e-10
ENTROPY_CEILING = 0.88
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class SpectralEntropy:
    return_mean: float
    powers: tuple[float, ...]
    total_power: float
    probability_sum: float
    value: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    spectral: SpectralEntropy
    entropy_qualified: bool
    momentum_12: float


def direct_spectral_entropy(values: list[float]) -> SpectralEntropy:
    if len(values) != RETURN_COUNT or any(not math.isfinite(v) for v in values):
        raise ValueError("forty-eight finite returns required")

    return_mean = sum(values) / RETURN_COUNT
    centered = [value - return_mean for value in values]
    powers: list[float] = []
    for bin_number in range(1, DFT_BINS + 1):
        real_part = 0.0
        imaginary_part = 0.0
        for index, value in enumerate(centered):
            angle = 2.0 * math.pi * bin_number * index / RETURN_COUNT
            real_part += value * math.cos(angle)
            imaginary_part -= value * math.sin(angle)
        raw_power = real_part * real_part + imaginary_part * imaginary_part
        powers.append(2.0 * raw_power if bin_number < DFT_BINS else raw_power)

    total_power = sum(powers)
    if not math.isfinite(total_power) or total_power <= TOTAL_POWER_FLOOR:
        raise ValueError("total spectral power at or below floor")
    probabilities = [power / total_power for power in powers]
    if any(
        not math.isfinite(probability)
        or probability < -PROBABILITY_TOLERANCE
        or probability > 1.0 + PROBABILITY_TOLERANCE
        for probability in probabilities
    ):
        raise ValueError("invalid normalized spectral power")
    probabilities = [min(1.0, max(0.0, probability)) for probability in probabilities]
    probability_sum = sum(probabilities)
    if abs(probability_sum - 1.0) > PROBABILITY_TOLERANCE:
        raise ValueError("spectral probabilities do not sum to one")
    value = -sum(
        probability * math.log(probability)
        for probability in probabilities
        if probability > 0.0
    ) / math.log(DFT_BINS)
    if (
        not math.isfinite(value)
        or value < -ENTROPY_LOWER_TOLERANCE
        or value > 1.0 + ENTROPY_UPPER_TOLERANCE
    ):
        raise ValueError("spectral entropy outside admitted range")
    return SpectralEntropy(
        return_mean=return_mean,
        powers=tuple(powers),
        total_power=total_power,
        probability_sum=probability_sum,
        value=min(1.0, max(0.0, value)),
    )


def numpy_one_sided_powers(values: list[float]) -> tuple[float, ...]:
    centered = np.asarray(values, dtype=np.float64) - np.mean(values)
    spectrum = np.fft.rfft(centered, n=RETURN_COUNT)
    return tuple(
        float(2.0 * abs(spectrum[k]) ** 2 if k < DFT_BINS else abs(spectrum[k]) ** 2)
        for k in range(1, DFT_BINS + 1)
    )


def classify(spectral_entropy: float, momentum_12: float) -> int:
    if not math.isfinite(spectral_entropy) or not math.isfinite(momentum_12):
        return 0
    if spectral_entropy > ENTROPY_CEILING:
        return 0
    if momentum_12 > DIRECTION_EPSILON:
        return 1
    if momentum_12 < -DIRECTION_EPSILON:
        return -1
    return 0


def signal_from_returns(values: list[float]) -> Signal:
    spectral = direct_spectral_entropy(values)
    momentum_12 = sum(values[36:48])
    entropy_qualified = spectral.value <= ENTROPY_CEILING
    return Signal(
        classify(spectral.value, momentum_12),
        spectral,
        entropy_qualified,
        momentum_12,
    )


def closes_from_returns(values: list[float], initial: float = 100.0) -> list[float]:
    closes = [initial]
    for value in values:
        closes.append(closes[-1] * math.exp(value))
    return closes


def signal_from_closes(closes: list[float]) -> Signal:
    if len(closes) != 49 or any(
        not math.isfinite(value) or value <= 0.0 for value in closes
    ):
        raise ValueError("forty-nine positive finite closes required")
    values = [math.log(right / left) for left, right in zip(closes, closes[1:])]
    return signal_from_returns(values)


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


def validate_month_keys(current_month: int, endpoints: list[int]) -> bool:
    if len(endpoints) != 49 or next_month_key(endpoints[-1]) != current_month:
        return False
    return all(
        next_month_key(left) == right for left, right in zip(endpoints, endpoints[1:])
    )


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


class WtiMonthlySpectralEntropyReferenceTests(unittest.TestCase):
    def test_paired_bin_dft_matches_numpy_and_parseval(self) -> None:
        values = [
            0.02 * math.cos(2.0 * math.pi * 3 * index / RETURN_COUNT)
            for index in range(RETURN_COUNT)
        ]
        result = direct_spectral_entropy(values)
        expected = numpy_one_sided_powers(values)
        np.testing.assert_allclose(result.powers, expected, rtol=1e-12, atol=1e-24)
        self.assertAlmostEqual(result.powers[2], 0.4608, places=12)
        self.assertAlmostEqual(result.total_power, 0.4608, places=12)
        self.assertAlmostEqual(result.value, 0.0, places=12)
        centered_energy = sum((value - result.return_mean) ** 2 for value in values)
        self.assertAlmostEqual(result.total_power, RETURN_COUNT * centered_energy, places=12)

    def test_nyquist_is_not_doubled(self) -> None:
        values = [0.01 if index % 2 == 0 else -0.01 for index in range(48)]
        result = direct_spectral_entropy(values)
        expected = numpy_one_sided_powers(values)
        np.testing.assert_allclose(result.powers, expected, rtol=1e-12, atol=1e-24)
        self.assertAlmostEqual(result.powers[23], 0.2304, places=12)
        self.assertAlmostEqual(result.total_power, 0.2304, places=12)
        self.assertAlmostEqual(result.value, 0.0, places=12)

    def test_two_equal_frequency_bins_have_normalized_log_two_entropy(self) -> None:
        values = [
            0.01 * math.cos(2.0 * math.pi * 3 * index / RETURN_COUNT)
            + 0.01 * math.cos(2.0 * math.pi * 5 * index / RETURN_COUNT)
            for index in range(RETURN_COUNT)
        ]
        result = direct_spectral_entropy(values)
        self.assertAlmostEqual(result.powers[2], result.powers[4], places=12)
        self.assertAlmostEqual(result.probability_sum, 1.0, places=15)
        self.assertAlmostEqual(result.value, math.log(2.0) / math.log(24.0), places=12)

    def test_constant_and_bad_paths_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "power"):
            direct_spectral_entropy([0.01] * 48)
        with self.assertRaises(ValueError):
            direct_spectral_entropy([0.01] * 47)
        with self.assertRaises(ValueError):
            direct_spectral_entropy([0.01] * 47 + [math.inf])
        with self.assertRaises(ValueError):
            signal_from_closes([100.0] * 48)
        with self.assertRaises(ValueError):
            signal_from_closes([100.0] * 48 + [0.0])

    def test_newest_twelve_month_direction_and_close_orientation(self) -> None:
        carrier = [
            0.01 * math.cos(2.0 * math.pi * 3 * index / RETURN_COUNT)
            for index in range(RETURN_COUNT)
        ]
        buy_values = [value + 0.02 for value in carrier]
        sell_values = [value - 0.02 for value in carrier]
        buy = signal_from_closes(closes_from_returns(buy_values))
        sell = signal_from_closes(closes_from_returns(sell_values))
        self.assertTrue(buy.entropy_qualified)
        self.assertTrue(sell.entropy_qualified)
        self.assertEqual((buy.direction, sell.direction), (1, -1))
        self.assertGreater(buy.momentum_12, DIRECTION_EPSILON)
        self.assertLess(sell.momentum_12, -DIRECTION_EPSILON)

    def test_entropy_boundary_is_inclusive_and_direction_band_is_symmetric(self) -> None:
        self.assertEqual(classify(ENTROPY_CEILING, 0.01), 1)
        self.assertEqual(classify(ENTROPY_CEILING, -0.01), -1)
        self.assertEqual(classify(math.nextafter(ENTROPY_CEILING, math.inf), 0.01), 0)
        self.assertEqual(classify(0.0, DIRECTION_EPSILON), 0)
        self.assertEqual(classify(0.0, -DIRECTION_EPSILON), 0)

    def test_forty_nine_consecutive_completed_months(self) -> None:
        endpoints: list[int] = []
        key = 202007
        for _ in range(49):
            endpoints.append(key)
            key = next_month_key(key)
        self.assertTrue(validate_month_keys(key, endpoints))
        self.assertFalse(validate_month_keys(key, endpoints[:-1]))
        broken = endpoints.copy()
        broken[24] = broken[23]
        self.assertFalse(validate_month_keys(key, broken))

    def test_market_free_density_receipt_is_formula_only(self) -> None:
        receipt = json.loads(NULL_RECEIPT.read_text(encoding="utf-8"))
        self.assertEqual(receipt["schema"], "qm.market-free-null-density/v1")
        self.assertEqual(receipt["generator"]["seed"], 20260902)
        self.assertEqual(receipt["generator"]["observations_per_draw"], 48)
        self.assertEqual(receipt["result"]["qualified"], 59_188)
        self.assertEqual(
            receipt["result"]["qualified"]
            + receipt["result"]["invalid_nonpositive_total_power"]
            + receipt["result"]["valid_above_boundary"],
            receipt["generator"]["draws"],
        )
        self.assertEqual(
            receipt["result"]["theoretical_qualified_attempts_per_12_clocks"],
            7.10256,
        )
        self.assertIn("not performance evidence", receipt["purpose"])

    def test_setfile_is_one_locked_fixed_risk_backtest(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41312")
        self.assertEqual(headers["ea_slug"], "wti-mspectral-entropy-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        self.assertEqual(headers["risk_mode"], "FIXED")
        self.assertRegex(headers["build_hash"], r"^(PENDING_COMPILE|[0-9a-f]{64})$")
        expected = {
            "qm_ea_id": "41312",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_month_returns": "48",
            "strategy_dft_bins": "24",
            "strategy_total_power_floor": "1e-24",
            "strategy_probability_tolerance": "0.0000000001",
            "strategy_entropy_lower_tolerance": "0.000000000001",
            "strategy_entropy_upper_tolerance": "0.0000000001",
            "strategy_entropy_ceiling": "0.88",
            "strategy_momentum_months": "12",
            "strategy_direction_epsilon": "0.000000000001",
            "strategy_history_bars": "1500",
            "strategy_entry_grace_minutes": "180",
            "strategy_endpoint_stale_days": "10",
            "strategy_atr_period": "20",
            "strategy_atr_sl_mult": "3.5",
            "strategy_stale_days": "40",
            "strategy_max_spread_points": "1500",
        }
        for key, value in expected.items():
            self.assertEqual(values.get(key), value, key)

        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        input_names = set(
            re.findall(r"(?m)^input\s+(?!group\b)(?:\w+\s+)+(\w+)\s*=", source)
        )
        self.assertTrue(set(values) <= input_names)
        self.assertTrue(
            {name for name in input_names if name.startswith("strategy_")} <= set(values)
        )
        self.assertEqual(sorted((EA_DIR / "sets").glob("*.set")), [SETFILE])

    def test_source_contract_attempt_order_and_spectral_guards(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8-sig")
        for required in (
            "bool Strategy_SpectralEntropyCore",
            "bool Strategy_SpectralEntropyReferenceSelfTest",
            "bool Strategy_SpectralEntropySignal",
            "imaginary_part -= centered[index] * MathSin(angle)",
            "(bin < strategy_dft_bins) ? 2.0 * raw_power : raw_power",
            "probability * MathLog(probability)",
            "MathLog((double)strategy_dft_bins)",
            "MathAbs(probability_sum - 1.0)",
            "metrics.spectral_entropy <= strategy_entropy_ceiling",
            "strategy_month_returns - strategy_momentum_months",
            "QM_FrameworkMagic() != 413120000",
            "Strategy_HasForeignSymbolPosition()",
        ):
            self.assertIn(required, source)

        prepare = source.index("void Strategy_PrepareDecisionSignal")
        consume = source.index("Strategy_RecordMonthAttempt(g_decision_month_key)", prepare)
        history = source.index("Strategy_LoadMonthlyEndpoints", consume)
        self.assertLess(consume, history)
        open_call = source.index("QM_TM_OpenPosition(req, out_ticket)")
        persist_entry = source.index("Strategy_RecordEntryMonth(g_decision_month_key)", open_call)
        self.assertLess(open_call, persist_entry)
        self.assertIn("Strategy_RecoverEntryMonthFromDeals", source)
        self.assertIn("HistorySelectByPosition(position_id)", source)

        for prohibited in (
            "iRSI(",
            "iMACD(",
            "iBands(",
            "iADX(",
            "iMA(",
            "MathRand(",
            "WebRequest(",
            "FileOpen(",
            "SampleEntropy",
            "LZ76",
        ):
            self.assertNotIn(prohibited, source)

    def test_magic_registry_and_card_copy_are_exact(self) -> None:
        registry = MAGIC_REGISTRY.read_text(encoding="utf-8-sig")
        self.assertIn(
            "41312,wti-mspectral-entropy-tr,0,XTIUSD.DWX,413120000", registry
        )
        self.assertEqual(
            EA_CARD.read_text(encoding="utf-8-sig"),
            CANONICAL_CARD.read_text(encoding="utf-8-sig"),
        )


if __name__ == "__main__":
    unittest.main()
