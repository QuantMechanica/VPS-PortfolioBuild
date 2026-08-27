"""Deterministic reference checks for QM5_41188's repeated-median basket."""

from __future__ import annotations

import csv
import json
import math
import unittest
from pathlib import Path


EA_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[4]
MONTH_COUNT = 13


def repeated_median(ratios: list[float]) -> tuple[float, int, int]:
    if len(ratios) != MONTH_COUNT or any(not math.isfinite(x) for x in ratios):
        raise ValueError("exactly thirteen finite ratios are required")
    grouped = 0
    pivots: list[float] = []
    for pivot in range(MONTH_COUNT):
        slopes: list[float] = []
        for other in range(MONTH_COUNT):
            if other == pivot:
                continue
            lower, upper = sorted((pivot, other))
            slopes.append((ratios[upper] - ratios[lower]) / (upper - lower))
            grouped += 1
        ordered = sorted(slopes)
        if len(ordered) != 12:
            raise AssertionError("each pivot must own twelve slopes")
        pivots.append(ordered[5] / 2.0 + ordered[6] / 2.0)
    return sorted(pivots)[6], grouped, len(pivots)


def direction(ratios: list[float]) -> int:
    value, _, _ = repeated_median(ratios)
    return 1 if value < 0.0 else -1 if value > 0.0 else 0


class RepeatedMedianReferenceTests(unittest.TestCase):
    def test_exact_nested_median_counts_and_symmetric_fade(self) -> None:
        rising = [0.02 * index for index in range(MONTH_COUNT)]
        falling = [-value for value in rising]
        value, grouped, pivots = repeated_median(rising)
        self.assertEqual((grouped, pivots), (156, 13))
        self.assertAlmostEqual(value, 0.02, places=14)
        self.assertEqual((direction(rising), direction(falling)), (-1, 1))
        self.assertEqual(direction([0.0] * MONTH_COUNT), 0)

    def test_fixed_non_alias_counterexample(self) -> None:
        ratios = [
            0.0, 0.01, 0.06, 0.11, 0.14, 0.13, 0.11,
            0.12, 0.09, 0.04, 0.02, 0.05, 0.10,
        ]
        value, grouped, pivots = repeated_median(ratios)
        self.assertEqual((grouped, pivots), (156, 13))
        self.assertAlmostEqual(value, -0.0045, places=14)
        self.assertEqual(direction(ratios), 1)

    def test_static_source_and_backtest_contract(self) -> None:
        source = (EA_DIR / "QM5_41188_xtixng-mrepmedian-rv.mq5").read_text(
            encoding="utf-8"
        )
        for marker in (
            "input int    qm_ea_id                    = 41188;",
            "input int    strategy_month_end_count         = 13;",
            "const int slopes_per_pivot = strategy_month_end_count - 1;",
            "grouped_slope_count != 156",
            "center_low_index != 5 || center_high_index != 6",
            "outer_median_index != 6",
            "if(repeated_median < 0.0)",
            "else if(repeated_median > 0.0)",
            "normalized_stop_risk <= 1.0 + 1.0e-8",
            "request.tp = 0.0;",
        ):
            self.assertIn(marker, source)
        for prohibited in ("irsI(", "imacd(", "ibands(", "webrequest("):
            self.assertNotIn(prohibited.lower(), source.lower())

        setfiles = sorted((EA_DIR / "sets").glob("*.set"))
        self.assertEqual(len(setfiles), 3)
        for setfile in setfiles:
            content = setfile.read_text(encoding="utf-8")
            for marker in (
                "; environment:  backtest",
                "; risk_mode:    FIXED",
                "qm_ea_id=41188",
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "PORTFOLIO_WEIGHT=1",
                "strategy_month_end_count=13",
                "strategy_history_bars_d1=900",
            ):
                self.assertIn(marker, content)

        manifest = json.loads((EA_DIR / "basket_manifest.json").read_text())
        self.assertEqual(
            manifest["logical_symbol"], "QM5_41188_XTI_XNG_MREPMEDIAN_RV_D1"
        )
        self.assertEqual(
            manifest["traded_symbols"], ["XTIUSD.DWX", "XNGUSD.DWX"]
        )

    def test_identity_magic_and_local_card_binding(self) -> None:
        with (REPO_ROOT / "framework/registry/ea_id_registry.csv").open(
            newline="", encoding="utf-8-sig"
        ) as handle:
            identities = [
                row for row in csv.DictReader(handle)
                if row["ea_id"] == "41188" and row["status"] == "active"
            ]
        self.assertEqual(len(identities), 1)
        self.assertEqual(identities[0]["slug"], "xtixng-mrepmedian-rv")

        with (REPO_ROOT / "framework/registry/magic_numbers.csv").open(
            newline="", encoding="utf-8-sig"
        ) as handle:
            magics = [
                row for row in csv.DictReader(handle)
                if row["ea_id"] == "41188" and row["status"] == "active"
            ]
        self.assertEqual(
            [(row["symbol_slot"], row["symbol"], row["magic"]) for row in magics],
            [
                ("0", "XTIUSD.DWX", "411880000"),
                ("1", "XNGUSD.DWX", "411880001"),
            ],
        )

        approved = (
            REPO_ROOT
            / "strategy-seeds/cards/approved/QM5_41188_xtixng-mrepmedian-rv_card.md"
        )
        local = EA_DIR / "docs/strategy_card.md"
        self.assertEqual(approved.read_bytes(), local.read_bytes())


if __name__ == "__main__":
    unittest.main()
