from __future__ import annotations

import math
import random
from pathlib import Path


EA_DIR = Path(__file__).parents[1]
EA = EA_DIR / "QM5_41349_wti-adf-sampen-agree-tr.mq5"
SETFILE = EA_DIR / "sets" / "QM5_41349_wti-adf-sampen-agree-tr_XTIUSD.DWX_D1_backtest.set"


def adf_t_from_returns(returns: list[float]) -> float:
    assert len(returns) == 60
    levels = [4.0]
    for value in returns:
        levels.append(levels[-1] + value)
    levels = levels[1:]  # newest sixty levels; first endpoint is SampEn-only
    ys = [levels[i] - levels[i - 1] for i in range(2, 60)]
    zs = [levels[i - 1] for i in range(2, 60)]
    ws = [levels[i - 1] - levels[i - 2] for i in range(2, 60)]
    mean_y, mean_z, mean_w = (sum(v) / 58 for v in (ys, zs, ws))
    yc = [v - mean_y for v in ys]
    zc = [v - mean_z for v in zs]
    wc = [v - mean_w for v in ws]
    szz = sum(v * v for v in zc)
    sww = sum(v * v for v in wc)
    szw = sum(a * b for a, b in zip(zc, wc))
    szy = sum(a * b for a, b in zip(zc, yc))
    swy = sum(a * b for a, b in zip(wc, yc))
    det = szz * sww - szw * szw
    gamma = (szy * sww - swy * szw) / det
    phi = (swy * szz - szy * szw) / det
    alpha = mean_y - gamma * mean_z - phi * mean_w
    sse = sum(
        (y - alpha - gamma * z - phi * w) ** 2
        for y, z, w in zip(ys, zs, ws)
    )
    return gamma / math.sqrt((sse / 55) * sww / det)


def sample_entropy(returns: list[float]) -> tuple[float, int, int]:
    assert len(returns) == 60
    mean = sum(returns) / 60
    sd = math.sqrt(sum((v - mean) ** 2 for v in returns) / 59)
    radius = 0.2 * sd

    def matches(dimension: int) -> int:
        count = 0
        template_count = 60 - (dimension - 1)
        for left in range(template_count):
            for right in range(left + 1, template_count):
                if max(
                    abs(returns[left + k] - returns[right + k])
                    for k in range(dimension)
                ) < radius:
                    count += 1
        return count

    b = matches(2)
    a = matches(3)
    if not (b >= a > 0):
        raise ValueError("invalid match counts")
    return math.log(b / a), b, a


def decision(returns: list[float]) -> tuple[int, float, float]:
    adf = adf_t_from_returns(returns)
    entropy, _, _ = sample_entropy(returns)
    momentum = sum(returns[48:60])
    direction = 0
    if adf >= -2.594 and entropy <= 2.5:
        direction = 1 if momentum > 1e-12 else -1 if momentum < -1e-12 else 0
    return direction, adf, entropy


def recurring_trend(seed: int = 7) -> list[float]:
    rng = random.Random(seed)
    return [
        0.004 + 0.006 * math.sin(index * 0.7) + rng.gauss(0.0, 0.001)
        for index in range(60)
    ]


def test_agreement_path_and_sample_entropy_counts() -> None:
    direction, adf, entropy = decision(recurring_trend())
    assert direction == 1
    assert abs(adf - (-0.6003018630081333)) < 1e-9
    assert abs(entropy - math.log(2.0)) < 1e-12
    assert sample_entropy(recurring_trend())[1:] == (44, 22)


def test_both_single_gate_disagreements_are_flat() -> None:
    high_entropy = [0.003 + random.Random(5).gauss(0.0, 0.01) for _ in range(60)]
    # Re-create a stateful sequence (not sixty repeats of the first RNG draw).
    rng = random.Random(5)
    high_entropy = [0.003 + rng.gauss(0.0, 0.01) for _ in range(60)]
    direction, adf, entropy = decision(high_entropy)
    assert adf >= -2.594 and entropy > 2.5 and direction == 0

    rng = random.Random(0)
    levels = [4.0] + [4.0 + 0.02 * rng.gauss(0.0, 1.0) for _ in range(60)]
    mean_reverting = [b - a for a, b in zip(levels, levels[1:])]
    direction, adf, entropy = decision(mean_reverting)
    assert adf < -2.594 and entropy <= 2.5 and direction == 0


def test_strict_template_boundary_and_locked_source_contract() -> None:
    source = EA.read_text(encoding="utf-8-sig")
    required = (
        "qm_ea_id                      = 41349",
        "QM_FrameworkMagic() != 413490000",
        "metrics.adf_qualified && metrics.entropy_qualified",
        "distance >= radius",
        "matches_m_plus_one > matches_m",
        "Strategy_RecordMonthAttempt(g_decision_month_key)",
        "RISK_FIXED                    = 1000.0",
    )
    for token in required:
        assert token in source
    assert source.index("Strategy_RecordMonthAttempt(g_decision_month_key)") < source.index(
        "Strategy_LoadMonthlyEndpoints", source.index("void Strategy_PrepareDecisionSignal")
    )


def test_only_one_fixed_risk_setfile() -> None:
    text = SETFILE.read_text(encoding="utf-8-sig")
    assert "; ea_id:        41349" in text
    assert "; environment:  backtest" in text
    assert "RISK_FIXED=1000" in text
    assert "RISK_PERCENT=0" in text
    assert "strategy_adf_t_min=-2.594" in text
    assert "strategy_entropy_ceiling=2.5" in text
    assert list((EA_DIR / "sets").glob("*.set")) == [SETFILE]
