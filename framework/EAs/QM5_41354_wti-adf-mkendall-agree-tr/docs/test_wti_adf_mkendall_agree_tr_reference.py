import math
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
EA_DIR = ROOT / "framework" / "EAs" / "QM5_41354_wti-adf-mkendall-agree-tr"
EA = EA_DIR / "QM5_41354_wti-adf-mkendall-agree-tr.mq5"
CARD = ROOT / "strategy-seeds" / "cards" / "approved" / "QM5_41354_wti-adf-mkendall-agree-tr_card.md"
SETFILE = EA_DIR / "sets" / "QM5_41354_wti-adf-mkendall-agree-tr_XTIUSD.DWX_D1_backtest.set"


def adf_t(closes):
    x = [math.log(value) for value in closes]
    rows = [(x[i] - x[i - 1], x[i - 1], x[i - 1] - x[i - 2]) for i in range(2, 60)]
    my, mz, mw = (sum(row[k] for row in rows) / 58 for k in range(3))
    szz = sum((z - mz) ** 2 for _, z, _ in rows)
    sww = sum((w - mw) ** 2 for _, _, w in rows)
    szw = sum((z - mz) * (w - mw) for _, z, w in rows)
    szy = sum((z - mz) * (y - my) for y, z, _ in rows)
    swy = sum((w - mw) * (y - my) for y, _, w in rows)
    det = szz * sww - szw * szw
    gamma = (szy * sww - swy * szw) / det
    phi = (swy * szz - szy * szw) / det
    alpha = my - gamma * mz - phi * mw
    sse = sum((y - alpha - gamma * z - phi * w) ** 2 for y, z, w in rows)
    return gamma / math.sqrt((sse / 55) * sww / det)


def rank_score(closes):
    tail = closes[-13:]
    if len(set(tail)) != 13:
        raise ValueError("ties fail closed")
    return sum(1 if tail[j] > tail[i] else -1 for i in range(12) for j in range(i + 1, 13))


class ReferenceContractTest(unittest.TestCase):
    def test_direction_and_state_fixtures(self):
        up = [math.exp(4 + .012*i + .025*math.sin(.73*i) + .009*math.cos(1.91*i)) for i in range(60)]
        down = [math.exp(5 - .010*i + .023*math.sin(.71*i) + .008*math.cos(1.83*i)) for i in range(60)]
        self.assertAlmostEqual(adf_t(up), -0.28754973622603336, places=10)
        self.assertAlmostEqual(adf_t(down), -0.34439061991466297, places=10)
        self.assertEqual(rank_score(up), 62)
        self.assertEqual(rank_score(down), -62)

    def test_rank_boundaries_and_ties(self):
        values = [13, 1, 4, 12, 5, 2, 3, 6, 7, 8, 9, 10, 11]
        prefix = list(range(100, 147))
        self.assertEqual(rank_score(prefix + values), 28)
        self.assertEqual(rank_score(prefix + [14-v for v in values]), -28)
        with self.assertRaises(ValueError):
            rank_score(list(range(47)) + values[:-1] + [values[-2]])

    def test_identity_and_fixed_risk(self):
        source = EA.read_text(encoding="utf-8")
        preset = SETFILE.read_text(encoding="utf-8")
        self.assertIn("QM_FrameworkMagic() != 413540000", source)
        registry = (ROOT / "framework" / "registry" / "magic_numbers.csv").read_text(encoding="utf-8")
        self.assertIn("41354,wti-adf-mkendall-agree-tr,0,XTIUSD.DWX,413540000", registry)
        self.assertIn("strategy_rank_points=13", preset)
        self.assertIn("strategy_min_abs_score=28", preset)
        self.assertIn("RISK_FIXED=1000", preset)
        self.assertIn("RISK_PERCENT=0", preset)

    def test_card_mirror(self):
        self.assertEqual(CARD.read_bytes(), (EA_DIR / "docs" / "strategy_card.md").read_bytes())


if __name__ == "__main__":
    unittest.main()
