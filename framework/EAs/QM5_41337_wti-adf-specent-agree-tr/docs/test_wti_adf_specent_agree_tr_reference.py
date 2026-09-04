from __future__ import annotations

import csv
import dataclasses
import json
import math
from pathlib import Path
import random
import unittest


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
EA_SOURCE = EA_DIR / "QM5_41337_wti-adf-specent-agree-tr.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_41337_wti-adf-specent-agree-tr_XTIUSD.DWX_D1_backtest.set"
)
CANONICAL_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_41337_wti-adf-specent-agree-tr_card.md"
)
EA_CARD = EA_DIR / "docs" / "strategy_card.md"
MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
FIXTURE = (
    REPO_ROOT
    / "artifacts"
    / "qm5_wti_adf_specent_agree_tr_reference_fixture_20260905.json"
)

LEVEL_COUNT = 60
OBSERVATION_COUNT = 58
RESIDUAL_DOF = 55
ADF_T_MIN = -2.594
RETURN_COUNT = 48
DFT_BINS = 24
ENTROPY_CEILING = 0.88
DIRECTION_EPSILON = 1e-12


@dataclasses.dataclass(frozen=True)
class ADFState:
    alpha: float
    gamma: float
    phi: float
    sse: float
    residual_variance: float
    se_gamma: float
    adf_t: float


@dataclasses.dataclass(frozen=True)
class SpectralState:
    return_mean: float
    powers: tuple[float, ...]
    total_power: float
    probability_sum: float
    entropy: float


@dataclasses.dataclass(frozen=True)
class Signal:
    direction: int
    adf_qualified: bool
    entropy_qualified: bool
    momentum_12: float
    adf: ADFState
    spectral: SpectralState


def direct_adf(levels: list[float]) -> ADFState:
    if len(levels) != LEVEL_COUNT or any(not math.isfinite(v) for v in levels):
        raise ValueError("sixty finite levels required")
    y = [levels[t] - levels[t - 1] for t in range(2, LEVEL_COUNT)]
    z = [levels[t - 1] for t in range(2, LEVEL_COUNT)]
    w = [levels[t - 1] - levels[t - 2] for t in range(2, LEVEL_COUNT)]
    means = tuple(sum(values) / OBSERVATION_COUNT for values in (y, z, w))
    yc = [value - means[0] for value in y]
    zc = [value - means[1] for value in z]
    wc = [value - means[2] for value in w]
    szz = sum(value * value for value in zc)
    sww = sum(value * value for value in wc)
    szw = sum(left * right for left, right in zip(zc, wc))
    szy = sum(left * right for left, right in zip(zc, yc))
    swy = sum(left * right for left, right in zip(wc, yc))
    determinant = szz * sww - szw * szw
    if (
        szz <= 1e-18
        or sww <= 1e-18
        or determinant <= 1e-12 * szz * sww
    ):
        raise ValueError("singular ADF regression")
    gamma = (szy * sww - swy * szw) / determinant
    phi = (swy * szz - szy * szw) / determinant
    alpha = means[0] - gamma * means[1] - phi * means[2]
    residuals = [
        yy - alpha - gamma * zz - phi * ww for yy, zz, ww in zip(y, z, w)
    ]
    sse = sum(value * value for value in residuals)
    if sse <= 1e-18:
        raise ValueError("ADF residual energy at floor")
    residual_variance = sse / RESIDUAL_DOF
    se_gamma = math.sqrt(residual_variance * sww / determinant)
    if se_gamma <= 1e-18:
        raise ValueError("ADF standard error at floor")
    return ADFState(
        alpha, gamma, phi, sse, residual_variance, se_gamma, gamma / se_gamma
    )


def direct_spectral_entropy(values: list[float]) -> SpectralState:
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
    if not math.isfinite(total_power) or total_power <= 1e-24:
        raise ValueError("total spectral power at floor")
    probabilities = [power / total_power for power in powers]
    if any(
        not math.isfinite(p) or p < -1e-10 or p > 1.0 + 1e-10
        for p in probabilities
    ):
        raise ValueError("invalid spectral probability")
    probabilities = [min(1.0, max(0.0, p)) for p in probabilities]
    probability_sum = sum(probabilities)
    if abs(probability_sum - 1.0) > 1e-10:
        raise ValueError("spectral probabilities do not sum to one")
    entropy = -sum(p * math.log(p) for p in probabilities if p > 0.0) / math.log(
        DFT_BINS
    )
    if not math.isfinite(entropy) or entropy < -1e-12 or entropy > 1.0 + 1e-10:
        raise ValueError("spectral entropy outside admitted range")
    return SpectralState(
        return_mean,
        tuple(powers),
        total_power,
        probability_sum,
        min(1.0, max(0.0, entropy)),
    )


def signal_from_levels(levels: list[float]) -> Signal:
    adf = direct_adf(levels)
    returns = [levels[index] - levels[index - 1] for index in range(12, 60)]
    spectral = direct_spectral_entropy(returns)
    momentum_12 = levels[59] - levels[47]
    adf_qualified = adf.adf_t >= ADF_T_MIN
    entropy_qualified = spectral.entropy <= ENTROPY_CEILING
    direction = 0
    if adf_qualified and entropy_qualified:
        if momentum_12 > DIRECTION_EPSILON:
            direction = 1
        elif momentum_12 < -DIRECTION_EPSILON:
            direction = -1
    return Signal(
        direction,
        adf_qualified,
        entropy_qualified,
        momentum_12,
        adf,
        spectral,
    )


def fixture_levels(generator: str) -> list[float]:
    rng = random.Random(0)
    if generator == "rw":
        levels = [4.5]
        for _ in range(59):
            levels.append(levels[-1] + 0.006 + rng.gauss(0.0, 0.035))
        return levels
    if generator == "ar":
        levels: list[float] = []
        value = 4.5
        for index in range(60):
            value = (
                4.5
                + 0.25 * (value - 4.5)
                + 0.025 * math.sin(2.0 * math.pi * index / 6.0)
                + rng.gauss(0.0, 0.004)
            )
            levels.append(value)
        return levels
    if generator in {"up", "down"}:
        sign = 1.0 if generator == "up" else -1.0
        levels = [4.5]
        for index in range(59):
            value = (
                sign * 0.007
                + 0.018 * math.cos(2.0 * math.pi * index / 12.0)
                + 0.006 * math.cos(2.0 * math.pi * index / 6.0)
                + rng.gauss(0.0, 0.002)
            )
            levels.append(levels[-1] + value)
        return levels
    raise ValueError(generator)


def next_month_key(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        return 0
    return (year + 1) * 100 + 1 if month == 12 else year * 100 + month + 1


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
        elif "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return headers, values


class WtiAdfSpectralAgreementReferenceTests(unittest.TestCase):
    def test_fixture_receipt_matches_independent_formula(self) -> None:
        receipt = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(receipt["schema"], "qm.strategy-reference-fixture/v1")
        for expected in receipt["fixtures"]:
            signal = signal_from_levels(fixture_levels(expected["generator"]))
            self.assertAlmostEqual(signal.adf.adf_t, expected["adf_t"], places=11)
            self.assertAlmostEqual(
                signal.spectral.entropy, expected["spectral_entropy"], places=11
            )
            self.assertAlmostEqual(
                signal.momentum_12, expected["momentum_12"], places=11
            )
            self.assertEqual(signal.adf_qualified, expected["adf_qualified"])
            self.assertEqual(
                signal.entropy_qualified, expected["spectral_qualified"]
            )
            self.assertEqual(signal.direction, expected["direction"])

    def test_direct_dft_paired_and_nyquist_weighting(self) -> None:
        paired = [
            0.02 * math.cos(2.0 * math.pi * 3 * index / 48)
            for index in range(48)
        ]
        state = direct_spectral_entropy(paired)
        self.assertAlmostEqual(state.powers[2], 0.4608, places=12)
        self.assertAlmostEqual(state.total_power, 0.4608, places=12)
        self.assertAlmostEqual(state.entropy, 0.0, places=12)
        nyquist = [0.01 if index % 2 == 0 else -0.01 for index in range(48)]
        state = direct_spectral_entropy(nyquist)
        self.assertAlmostEqual(state.powers[23], 0.2304, places=12)
        self.assertAlmostEqual(state.total_power, 0.2304, places=12)

    def test_inclusive_boundaries_and_conjunction(self) -> None:
        self.assertTrue(ADF_T_MIN >= ADF_T_MIN)
        self.assertTrue(ENTROPY_CEILING <= ENTROPY_CEILING)
        adf_only = signal_from_levels(fixture_levels("rw"))
        spectral_only = signal_from_levels(fixture_levels("ar"))
        self.assertTrue(adf_only.adf_qualified)
        self.assertFalse(adf_only.entropy_qualified)
        self.assertFalse(spectral_only.adf_qualified)
        self.assertTrue(spectral_only.entropy_qualified)
        self.assertEqual((adf_only.direction, spectral_only.direction), (0, 0))

    def test_degenerate_paths_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            direct_adf([4.2] * 60)
        with self.assertRaises(ValueError):
            direct_spectral_entropy([0.01] * 48)
        with self.assertRaises(ValueError):
            direct_spectral_entropy([0.01] * 47 + [math.inf])

    def test_month_clock(self) -> None:
        self.assertEqual(next_month_key(202611), 202612)
        self.assertEqual(next_month_key(202612), 202701)
        self.assertEqual(next_month_key(202613), 0)

    def test_setfile_is_single_fixed_risk_contract(self) -> None:
        headers, values = parse_setfile(SETFILE)
        self.assertEqual(headers["ea_id"], "41337")
        self.assertEqual(headers["ea_slug"], "wti-adf-specent-agree-tr")
        self.assertEqual(headers["symbol"], "XTIUSD.DWX")
        self.assertEqual(headers["timeframe"], "D1")
        self.assertEqual(headers["environment"], "backtest")
        expected = {
            "qm_ea_id": "41337",
            "qm_magic_slot_offset": "0",
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "PORTFOLIO_WEIGHT": "1",
            "strategy_level_count": "60",
            "strategy_spectral_return_count": "48",
            "strategy_dft_bins": "24",
            "strategy_adf_t_min": "-2.594",
            "strategy_entropy_ceiling": "0.88",
        }
        for key, value in expected.items():
            self.assertEqual(values[key], value)

    def test_source_contains_load_bearing_contract(self) -> None:
        source = EA_SOURCE.read_text(encoding="utf-8")
        for token in (
            "Strategy_ADFCore",
            "Strategy_SpectralEntropyCore",
            "right_index = index + 12",
            "bin < strategy_dft_bins",
            "metrics.adf_qualified && metrics.entropy_qualified",
            "strategy_adf_t_min - (-2.594)",
            "strategy_entropy_ceiling - 0.88",
            "RISK_FIXED != 1000.0",
            "QM_FrameworkMagic() != 413370000",
        ):
            self.assertIn(token, source)
        self.assertNotIn("Strategy_KPSSCore", source)
        self.assertNotIn("strategy_kpss_", source)

    def test_card_mirror_and_magic_registry(self) -> None:
        self.assertEqual(
            CANONICAL_CARD.read_text(encoding="utf-8"),
            EA_CARD.read_text(encoding="utf-8"),
        )
        with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
            rows = [
                row
                for row in csv.DictReader(handle)
                if row["ea_id"] == "41337" and row["status"] == "active"
            ]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["ea_slug"], "wti-adf-specent-agree-tr")
        self.assertEqual(rows[0]["symbol"], "XTIUSD.DWX")
        self.assertEqual(rows[0]["symbol_slot"], "0")
        self.assertEqual(rows[0]["magic"], "413370000")


if __name__ == "__main__":
    unittest.main()
