"""C1 (2026-07-26) Q09 hard-gate — DL-083 stricter-of-two correlation rule.

Covers the ported gate criterion from decisions/2026-07-26_q09_hard_gate_dl083_port.md:
full-sample AND high-vol-regime correlation, corr_eff = stricter (max) of the two;
corr_eff >= 0.40 REJECT, corr_eff < 0.15 + positive marginal contribution ADMIT, gray zone
decided by delta-Sharpe >= 0.020. Regime = top-quartile book-composite rolling-vol days;
insufficient regime days => regime basis UNKNOWN and full-sample binds alone (reason carries
regime_unknown). Reason strings name the binding basis (corr_full / corr_regime / regime_unknown).

The zoned decision and its boundaries are tested against the pure classify_admission() function
(exact); the regime computation and its binding are tested end-to-end through evaluate_candidate()
with deterministic constructed streams.
"""
import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio import portfolio_admission as pa  # noqa: E402
from portfolio.portfolio_admission import (  # noqa: E402
    CORR_ADMIT_MAX,
    CORR_REJECT_MIN,
    SHARPE_DELTA_ADMIT,
    classify_admission,
    corr_eff_value,
    evaluate_candidate,
    _high_vol_regime_indices,
    _regime_correlation,
)


class ClassifyAdmissionZoneTests(unittest.TestCase):
    """Pure zoned-criterion logic — exact, deterministic."""

    def test_thresholds_are_the_dl083_numbers(self) -> None:
        self.assertEqual(CORR_REJECT_MIN, 0.40)
        self.assertEqual(CORR_ADMIT_MAX, 0.15)
        self.assertEqual(SHARPE_DELTA_ADMIT, 0.020)

    def test_corr_eff_value_is_stricter_of_two(self) -> None:
        self.assertEqual(corr_eff_value(0.30, 0.50, True), 0.50)
        self.assertEqual(corr_eff_value(0.30, 0.50, False), 0.30)   # regime unknown -> full binds
        self.assertEqual(corr_eff_value(None, 0.50, True), 0.50)
        self.assertEqual(corr_eff_value(0.20, None, True), 0.20)
        self.assertIsNone(corr_eff_value(None, None, False))

    def test_full_sample_binds_when_higher_than_regime(self) -> None:
        admit, base, basis, eff = classify_admission(0.30, 0.20, True, 0.5, True)
        self.assertEqual(basis, "corr_full")
        self.assertAlmostEqual(eff, 0.30)
        self.assertTrue(admit)          # gray zone, delta-Sharpe 0.5 >= 0.020
        self.assertEqual(base, "admitted")

    def test_regime_binds_when_higher_than_full_and_can_flip_the_verdict(self) -> None:
        # THE scenario the rule exists for: full-sample alone (0.20) would ADMIT, but the
        # high-vol regime correlation (0.45) is the stricter basis and REJECTS.
        admit_full_only, base_full, basis_full, eff_full = classify_admission(
            0.20, 0.45, False, 0.5, True  # regime UNKNOWN -> full binds alone
        )
        self.assertEqual(basis_full, "regime_unknown")
        self.assertAlmostEqual(eff_full, 0.20)
        self.assertTrue(admit_full_only)

        admit, base, basis, eff = classify_admission(0.20, 0.45, True, 0.5, True)
        self.assertEqual(basis, "corr_regime")
        self.assertAlmostEqual(eff, 0.45)
        self.assertFalse(admit)
        self.assertEqual(base, "correlation_above_max_corr")

    def test_regime_unknown_full_binds_alone_and_ignores_regime_value(self) -> None:
        admit, base, basis, eff = classify_admission(0.35, 0.99, False, 0.5, True)
        self.assertEqual(basis, "regime_unknown")     # named even though full bound
        self.assertAlmostEqual(eff, 0.35)             # regime 0.99 ignored (unknown)
        self.assertTrue(admit)                        # 0.35 gray, delta-Sharpe passes

    def test_zone_reject_at_or_above_reject_min(self) -> None:
        admit, base, basis, eff = classify_admission(0.45, 0.10, True, 5.0, True)
        self.assertFalse(admit)
        self.assertEqual(base, "correlation_above_max_corr")
        self.assertEqual(basis, "corr_full")

    def test_zone_strong_admit_below_admit_max_with_positive_marginal(self) -> None:
        admit, base, basis, eff = classify_admission(0.10, None, False, 0.0, True)
        self.assertTrue(admit)                        # strong zone: marginal_positive unlocks it
        self.assertEqual(base, "admitted")

    def test_zone_strong_admit_requires_positive_marginal(self) -> None:
        # corr < 0.15 but no positive marginal contribution AND delta-Sharpe below the gray band.
        admit, base, basis, eff = classify_admission(0.10, None, False, 0.0, False)
        self.assertFalse(admit)
        self.assertEqual(base, "no_diversification")

    def test_gray_zone_decided_by_delta_sharpe(self) -> None:
        self.assertTrue(classify_admission(0.30, None, False, 0.05, False)[0])
        self.assertFalse(classify_admission(0.30, None, False, 0.00, False)[0])
        self.assertEqual(classify_admission(0.30, None, False, 0.00, False)[1], "no_diversification")

    def test_insufficient_when_nothing_measurable(self) -> None:
        admit, base, basis, eff = classify_admission(None, None, False, 0.5, True)
        self.assertFalse(admit)
        self.assertEqual(base, "insufficient_overlap")
        self.assertEqual(basis, "regime_unknown")
        self.assertIsNone(eff)
        # regime known but no full-sample and no regime value -> still insufficient
        _, base2, basis2, _ = classify_admission(None, None, True, 0.5, True)
        self.assertEqual(base2, "insufficient_overlap")
        self.assertEqual(basis2, "corr_full")

    # --- boundary fixtures ------------------------------------------------- #
    def test_boundary_admit_max_0_15(self) -> None:
        # marginal_positive True, delta-Sharpe below gray band -> only the strong zone can admit.
        self.assertTrue(classify_admission(0.149, None, False, 0.0, True)[0])
        self.assertFalse(classify_admission(0.150, None, False, 0.0, True)[0])  # strict <
        self.assertFalse(classify_admission(0.151, None, False, 0.0, True)[0])
        self.assertEqual(classify_admission(0.150, None, False, 0.0, True)[1], "no_diversification")

    def test_boundary_reject_min_0_40(self) -> None:
        # delta-Sharpe high + marginal True so gray/strong would admit if not rejected.
        self.assertTrue(classify_admission(0.399, None, False, 0.5, True)[0])
        self.assertFalse(classify_admission(0.400, None, False, 0.5, True)[0])  # >= rejects
        self.assertFalse(classify_admission(0.401, None, False, 0.5, True)[0])
        self.assertEqual(
            classify_admission(0.400, None, False, 0.5, True)[1], "correlation_above_max_corr"
        )

    def test_boundary_sharpe_delta_0_020(self) -> None:
        # gray zone (corr_eff 0.30), no positive marginal -> delta-Sharpe alone decides.
        self.assertFalse(classify_admission(0.30, None, False, 0.0199, False)[0])
        self.assertTrue(classify_admission(0.30, None, False, 0.0200, False)[0])   # >= admits
        self.assertTrue(classify_admission(0.30, None, False, 0.0201, False)[0])


class RegimeCorrelationUnitTests(unittest.TestCase):
    def test_insufficient_regime_days_returns_unknown(self) -> None:
        # Only a handful of rows -> fewer than MIN_REGIME_DAYS regime days -> UNKNOWN.
        aligned = [(100, "X"), (101, "X")]
        matrix = [[float(r % 3), float((r + 1) % 3)] for r in range(30)]
        corr_regime, regime_days, regime_known = _regime_correlation(
            (101, "X"), [(100, "X")], aligned, matrix, {(100, "X"): 1.0}
        )
        self.assertFalse(regime_known)
        self.assertIsNone(corr_regime)
        self.assertLess(regime_days, pa.MIN_REGIME_DAYS)

    def test_high_vol_regime_indices_selects_elevated_vol_block(self) -> None:
        # Calm ±1 for 120 days, then an elevated ±10 block -> the top quartile must sit in
        # the elevated block, never in the calm prefix.
        composite = [1.0 if i % 2 == 0 else -1.0 for i in range(120)]
        composite += [10.0 if i % 2 == 0 else -10.0 for i in range(120)]
        idx = _high_vol_regime_indices(composite, pa.REGIME_VOL_WINDOW, pa.REGIME_TOP_QUANTILE)
        self.assertTrue(idx)
        self.assertTrue(all(i >= 120 for i in idx))


class Dl083GateIntegrationTests(unittest.TestCase):
    """End-to-end through evaluate_candidate with deterministic constructed streams."""

    N = 264
    CRISIS_LO, CRISIS_HI = 100, 166
    S = 10.0
    DRIFT = 4.0  # net-negative constant offset; Pearson is mean-centered so it leaves the
    #             correlations untouched but keeps the candidate from looking swap-superior.

    @staticmethod
    def _p1(i: int) -> float:
        return 1.0 if i % 2 == 0 else -1.0

    @staticmethod
    def _p2(i: int) -> float:
        return 1.0 if (i // 2) % 2 == 0 else -1.0

    def _cost(self) -> float:
        model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
        return model.cost_round_trip("EURUSD.DWX", 1.0, 10000.0)

    def _stream_dir(self, common_dir: Path) -> Path:
        stream_dir = common_dir / "QM" / "q08_trades"
        stream_dir.mkdir(parents=True)
        return stream_dir

    def _write_daily(self, path: Path, start: dt.datetime, pnl, cost: float) -> None:
        with path.open("w", encoding="utf-8") as fh:
            for offset, net_of_cost in enumerate(pnl):
                row = {
                    "event": "TRADE_CLOSED",
                    "time": int((start + dt.timedelta(days=offset)).timestamp()),
                    "net": net_of_cost + cost,
                    "profit": net_of_cost + cost,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 1.0,
                    "notional": 10000.0,
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")

    def _write_monthly(self, path: Path, start: dt.datetime, monthly_pnl, day: int, cost: float) -> None:
        with path.open("w", encoding="utf-8") as fh:
            for index, net_of_cost in enumerate(monthly_pnl):
                year = start.year + (start.month - 1 + index) // 12
                month = (start.month - 1 + index) % 12 + 1
                stamp = dt.datetime(year, month, day, tzinfo=dt.UTC)
                row = {
                    "event": "TRADE_CLOSED",
                    "time": int(stamp.timestamp()),
                    "net": net_of_cost + cost,
                    "profit": net_of_cost + cost,
                    "swap": 0.0,
                    "commission": 0.0,
                    "volume": 1.0,
                    "notional": 10000.0,
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")

    def _eval(self, book_pnl, cand_pnl):
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2020, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()
            self._write_daily(stream_dir / "100_EURUSD_DWX.jsonl", start, book_pnl, cost)
            self._write_daily(stream_dir / "101_EURUSD_DWX.jsonl", start, cand_pnl, cost)
            return evaluate_candidate((101, "EURUSD.DWX"), [(100, "EURUSD.DWX")], common_dir)

    def test_regime_binds_rejects_when_full_sample_alone_would_not(self) -> None:
        book, cand = [], []
        for i in range(self.N):
            if self.CRISIS_LO <= i < self.CRISIS_HI:
                book.append(2 * self.S * self._p1(i))
                cand.append(2 * self.S * (0.6 * self._p1(i) + 0.8 * self._p2(i)) - self.DRIFT)
            else:
                book.append(self.S * self._p1(i))
                cand.append(self.S * self._p2(i) - self.DRIFT)
        v = self._eval(book, cand)
        self.assertFalse(v["regime_unknown"])
        self.assertLess(v["corr_full"], CORR_REJECT_MIN)      # full alone would NOT reject
        self.assertGreaterEqual(v["corr_regime"], CORR_REJECT_MIN)
        self.assertEqual(v["corr_binding_basis"], "corr_regime")
        self.assertFalse(v["admit"])
        self.assertEqual(v["reason"].split(":")[0], "correlation_above_max_corr")
        self.assertEqual(v["reason"].split(":")[1], "corr_regime")

    def test_full_sample_binds_rejects_when_regime_alone_would_not(self) -> None:
        book, cand = [], []
        for i in range(self.N):
            if self.CRISIS_LO <= i < self.CRISIS_HI:
                book.append(2 * self.S * self._p1(i))
                cand.append(2 * self.S * (0.2 * self._p1(i) + 0.9797959 * self._p2(i)) - self.DRIFT)
            else:
                book.append(self.S * self._p1(i))
                cand.append(self.S * (0.7 * self._p1(i) + 0.7141428 * self._p2(i)) - self.DRIFT)
        v = self._eval(book, cand)
        self.assertFalse(v["regime_unknown"])
        self.assertGreaterEqual(v["corr_full"], CORR_REJECT_MIN)
        self.assertLess(v["corr_regime"], CORR_REJECT_MIN)     # regime alone would NOT reject
        self.assertEqual(v["corr_binding_basis"], "corr_full")
        self.assertFalse(v["admit"])
        self.assertEqual(v["reason"], "correlation_above_max_corr:corr_full")

    def test_strong_admit_low_correlation_diversifier(self) -> None:
        book = [self.S * self._p1(i) for i in range(self.N)]
        cand = [self.S * self._p2(i) + 2.0 for i in range(self.N)]  # uncorrelated, net positive
        v = self._eval(book, cand)
        self.assertLess(v["corr_eff"], CORR_ADMIT_MAX)
        self.assertTrue(v["diversifies"])
        self.assertTrue(v["admit"])
        self.assertEqual(v["reason"].split(":")[0], "admitted")

    def test_regime_unknown_on_monthly_fallback(self) -> None:
        # Sparse structural sleeves trading once a month on different days never share a daily
        # bar -> the full-sample correlation uses the monthly fallback and the DAILY high-vol
        # regime is not a meaningful construct -> regime basis UNKNOWN, reason carries it.
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp)
            stream_dir = self._stream_dir(common_dir)
            start = dt.datetime(2020, 1, 1, tzinfo=dt.UTC)
            cost = self._cost()
            self._write_monthly(stream_dir / "100_EURUSD_DWX.jsonl", start, [100.0, -40.0] * 18, 1, cost)
            self._write_monthly(stream_dir / "101_EURUSD_DWX.jsonl", start, [20.0, 120.0] * 18, 15, cost)
            v = evaluate_candidate((101, "EURUSD.DWX"), [(100, "EURUSD.DWX")], common_dir)
        self.assertEqual(v["corr_basis"], "monthly")
        self.assertTrue(v["regime_unknown"])
        self.assertEqual(v["corr_binding_basis"], "regime_unknown")
        self.assertIsNone(v["corr_regime"])
        self.assertEqual(v["reason"].split(":")[1], "regime_unknown")

    def test_new_schema_fields_and_reason_names_binding_basis(self) -> None:
        book = [self.S * self._p1(i) for i in range(self.N)]
        cand = [self.S * self._p2(i) + 2.0 for i in range(self.N)]
        v = self._eval(book, cand)
        for key in ("corr_full", "corr_regime", "corr_eff", "corr_binding_basis",
                    "regime_days", "regime_unknown"):
            self.assertIn(key, v)
        # reason of a correlation-gated verdict names the binding basis after a ':'
        self.assertIn(":", v["reason"])
        self.assertIn(v["reason"].split(":")[1], {"corr_full", "corr_regime", "regime_unknown"})


if __name__ == "__main__":
    unittest.main()
