from __future__ import annotations

import math
from pathlib import Path


EA = Path(__file__).parents[1] / "QM5_41339_wti-adf-lz-agree-tr.mq5"


def lz76(word: str) -> tuple[int, str]:
    assert word and set(word) <= {"0", "1"}
    phrases: list[str] = []
    start = 0
    while start < len(word):
        remaining = len(word) - start
        chosen = 0
        for size in range(1, remaining + 1):
            phrase = word[start : start + size]
            if not any(
                word[candidate : candidate + size] == phrase
                for candidate in range(start)
            ):
                chosen = size
                break
        if chosen == 0:
            chosen = remaining
        phrases.append(word[start : start + chosen])
        start += chosen
    assert "".join(phrases) == word
    return len(phrases), "|".join(phrases)


def adf_t(levels: list[float]) -> float:
    ys = [levels[i] - levels[i - 1] for i in range(2, 60)]
    zs = [levels[i - 1] for i in range(2, 60)]
    ws = [levels[i - 1] - levels[i - 2] for i in range(2, 60)]
    means = tuple(sum(v) / 58 for v in (ys, zs, ws))
    yc = [v - means[0] for v in ys]
    zc = [v - means[1] for v in zs]
    wc = [v - means[2] for v in ws]
    szz = sum(v * v for v in zc)
    sww = sum(v * v for v in wc)
    szw = sum(a * b for a, b in zip(zc, wc))
    szy = sum(a * b for a, b in zip(zc, yc))
    swy = sum(a * b for a, b in zip(wc, yc))
    det = szz * sww - szw * szw
    gamma = (szy * sww - swy * szw) / det
    phi = (swy * szz - szy * szw) / det
    alpha = means[0] - gamma * means[1] - phi * means[2]
    sse = sum((y - alpha - gamma * z - phi * w) ** 2 for y, z, w in zip(ys, zs, ws))
    return gamma / math.sqrt((sse / 55) * sww / det)


def test_lz76_pinned_phrase_and_boundary_vectors() -> None:
    assert lz76("0011011101110110") == (5, "0|01|10|111|01110110")
    assert lz76("00000001101110100100")[0] == 6
    assert lz76("00000001101110101000")[0] == 7


def test_adf_reference_path_qualifies() -> None:
    levels = [
        4.0 + 0.012 * i + 0.025 * math.sin(0.73 * i) + 0.009 * math.cos(1.91 * i)
        for i in range(60)
    ]
    assert abs(adf_t(levels) - (-0.28754973622603336)) < 1e-9
    assert adf_t(levels) >= -2.594


def test_ea_locks_joint_gate_and_fixed_risk() -> None:
    text = EA.read_text(encoding="utf-8")
    required = (
        "qm_ea_id                      = 41339",
        "RISK_FIXED                    = 1000.0",
        "strategy_adf_t_min             = -2.594",
        "strategy_complexity_ceiling   = 6",
        "metrics.adf_qualified && metrics.lz_qualified",
        "QM_FrameworkMagic() != 413390000",
        "if(!Strategy_ADFLZReferenceSelfTest())",
    )
    for token in required:
        assert token in text
