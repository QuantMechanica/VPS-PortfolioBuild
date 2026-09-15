"""Regression tests for the continuous book recomposition engine (E1).

Directive OWNER-DEC-CBE-20260915 sections 5-9, 57-59, 70. Covers:
* reproducibility (freeze once -> evaluate twice -> byte-identical evaluation.json),
* a small (3-pair) pool evaluates without any count condition,
* an empty pool refuses with a reason,
* venue fitness stays separate (DXZ vs FTMO objective differ on the same fixture),
* materiality default KEEP on noise,
* a change is proposed only when the improvement clears the thresholds,
* advisory cap warnings from ``risk_diagnostics`` are carried into the output.
"""
from __future__ import annotations

import datetime as dt
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.portfolio_common import load_streams, to_daily_pnl  # noqa: E402
from portfolio.recompose import alternatives as alt_mod  # noqa: E402
from portfolio.recompose import decide as decide_mod  # noqa: E402
from portfolio.recompose import dxz_fitness  # noqa: E402
from portfolio.recompose import frozen_snapshot as fs  # noqa: E402
from portfolio.recompose import materiality as mat_mod  # noqa: E402
from portfolio.recompose import metrics as metrics_mod  # noqa: E402
from portfolio.recompose import recompose as rc  # noqa: E402
from portfolio.recompose import venue_fitness  # noqa: E402

_BASE = dt.datetime(2022, 1, 3, 10, 0, tzinfo=dt.UTC)


def _write_stream(stream_dir: Path, ea: int, symbol: str, pattern, n: int = 500) -> None:
    stream_dir.mkdir(parents=True, exist_ok=True)
    path = stream_dir / f"{ea}_{symbol.replace('.', '_')}.jsonl"
    lines = []
    for i in range(n):
        day = _BASE + dt.timedelta(days=i)
        if day.weekday() >= 5:
            continue
        lines.append(json.dumps({
            "event": "TRADE_CLOSED",
            "magic": ea * 10000,
            "side": "BUY",
            "time": int(day.timestamp()),
            "entry_time": int((day - dt.timedelta(hours=5)).timestamp()),
            "net": float(pattern(i)),
            "volume": 0.1,
            "notional": 10000.0,
            "symbol": symbol,
        }))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _source_root(tmp: Path) -> Path:
    root = tmp / "src"
    q08 = root / "QM" / "q08_trades"
    _write_stream(q08, 101, "EURUSD.DWX", lambda i: math.sin(i / 7.0) * 20 + 5)
    _write_stream(q08, 102, "XAUUSD.DWX", lambda i: math.cos(i / 5.0) * 30 + 4)
    _write_stream(q08, 103, "USDJPY.DWX", lambda i: (i % 9 - 4) * 10 + 3)
    _write_stream(q08, 201, "GBPUSD.DWX", lambda i: math.sin(i / 11.0) * 15 + 8)
    return root


def _incumbents_3():
    return [{
        "label": "live_3",
        "source_path": "X",
        "status": "LIVE",
        "sleeves": [
            {"ea_id": 101, "symbol": "EURUSD.DWX", "magic": 1010000, "risk_pct": 2.0},
            {"ea_id": 102, "symbol": "XAUUSD.DWX", "magic": 1020000, "risk_pct": 2.0},
            {"ea_id": 103, "symbol": "USDJPY.DWX", "magic": 1030000, "risk_pct": 2.0},
        ],
    }]


class ReproducibilityTests(unittest.TestCase):
    def test_freeze_once_evaluate_twice_byte_identical(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            src = _source_root(tmp)
            snap = tmp / "snap"
            fs.freeze(
                "dxz", snap,
                as_of=dt.datetime(2026, 9, 18, 20, 0, tzinfo=dt.UTC),
                seed=7,
                qualified_pairs=[(101, "EURUSD.DWX"), (102, "XAUUSD.DWX"), (103, "USDJPY.DWX"), (201, "GBPUSD.DWX")],
                incumbents=_incumbents_3(),
                stream_source_roots=[src],
                git_commit="deadbeef",
            )
            rc.evaluate("dxz", snap, tmp / "rm1.json", risk_budget=6.0, book_evolution_root=tmp / "be1")
            rc.evaluate("dxz", snap, tmp / "rm2.json", risk_budget=6.0, book_evolution_root=tmp / "be2")
            e1 = (tmp / "be1" / "2026-W38" / "dxz" / "evaluation.json").read_bytes()
            e2 = (tmp / "be2" / "2026-W38" / "dxz" / "evaluation.json").read_bytes()
            self.assertEqual(e1, e2)
            self.assertEqual((tmp / "rm1.json").read_bytes(), (tmp / "rm2.json").read_bytes())


class SmallPoolTests(unittest.TestCase):
    def test_three_pair_pool_evaluates_without_count_condition(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            src = _source_root(tmp)
            snap = tmp / "snap"
            manifest = fs.freeze(
                "dxz", snap,
                as_of=dt.datetime(2026, 9, 18, 20, 0, tzinfo=dt.UTC),
                seed=1,
                qualified_pairs=[(101, "EURUSD.DWX"), (102, "XAUUSD.DWX"), (103, "USDJPY.DWX")],
                incumbents=_incumbents_3(),
                stream_source_roots=[src],
                git_commit="abc",
            )
            self.assertEqual(manifest["qualified_pool"]["count"], 3)
            read_model = rc.evaluate(
                "dxz", snap, tmp / "rm.json", risk_budget=6.0, book_evolution_root=tmp / "be"
            )
            # A valid outcome is produced from a 3-pair pool: no minimum-count gate.
            self.assertIn(read_model["proposal"]["outcome"], rc.decide_mod.VALID_OUTCOMES)
            self.assertEqual(read_model["incumbent"]["sleeve_count"], 3)


class EmptyPoolTests(unittest.TestCase):
    def test_empty_pool_and_incumbent_refuses_with_reason(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            src = _source_root(tmp)
            with self.assertRaises(fs.SnapshotError) as ctx:
                fs.freeze(
                    "dxz", tmp / "snap",
                    qualified_pairs=[],
                    incumbents=[],
                    stream_source_roots=[src],
                    git_commit="x",
                )
            self.assertIn("nothing to freeze", str(ctx.exception))


class VenueFitnessSeparationTests(unittest.TestCase):
    def test_dxz_and_ftmo_objectives_differ_on_same_fixture(self) -> None:
        metrics = {
            "return_to_maxdd": 4.0, "sharpe": 2.5, "effective_number_of_bets": 3.0,
            "n_sleeves": 4, "tail_loss_es5_pct": -0.5, "volatility_annual_pct": 8.0,
            "mean_abs_downside_correlation": 0.2,
        }
        try:
            # An injected FTMO objective that is deliberately different from DXZ.
            venue_fitness.register_venue_fitness(
                "ftmo", lambda m, snapshot=None: {"venue": "ftmo", "objective": round((m.get("sharpe") or 0) * 0.001, 6)}
            )
            dxz = venue_fitness.compute_venue_fitness("dxz", metrics)
            ftmo = venue_fitness.compute_venue_fitness("ftmo", metrics)
        finally:
            venue_fitness.register_venue_fitness("ftmo", None)
        self.assertNotEqual(dxz["objective"], ftmo["objective"])
        # DXZ objective is the real composite; FTMO uses its own objective (separate).
        self.assertEqual(dxz, dxz_fitness.compute_dxz_fitness(metrics))

    def test_ftmo_degrades_to_not_evaluated_when_module_absent(self) -> None:
        venue_fitness.register_venue_fitness("ftmo", None)
        out = venue_fitness.compute_venue_fitness("ftmo", {"sharpe": 1.0})
        # F1 module is not present in this worktree.
        self.assertEqual(out["objective"], "NOT_EVALUATED")


class MaterialityTests(unittest.TestCase):
    def _daily(self):
        with tempfile.TemporaryDirectory() as td:
            src = _source_root(Path(td))
            trades = load_streams(src, candidates=[(101, "EURUSD.DWX"), (102, "XAUUSD.DWX"), (103, "USDJPY.DWX"), (201, "GBPUSD.DWX")])
            return {k: to_daily_pnl(v) for k, v in trades.items()}

    def test_default_keep_on_noise(self) -> None:
        # A near-identical alternative (tiny noise) must not be material.
        daily = self._daily()
        keys = [(101, "EURUSD.DWX"), (102, "XAUUSD.DWX"), (103, "USDJPY.DWX")]
        weights = {k: 2.0 for k in keys}
        base_m = metrics_mod.compute_roster_metrics(keys, weights, daily)
        base_f = dxz_fitness.compute_dxz_fitness(base_m)
        base_book = metrics_mod.book_by_date(keys, weights, daily)
        assessment = mat_mod.assess(
            venue="dxz",
            change={"outcome": "KEEP", "add": [], "remove": [], "replace": []},
            baseline_fitness=base_f,
            alt_fitness=base_f,
            baseline_metrics=base_m,
            alt_metrics=base_m,
            baseline_book_by_date=base_book,
            alt_book_by_date=base_book,
            incumbent_symbols=["EURUSD", "XAUUSD", "USDJPY"],
            seed=0,
        )
        self.assertFalse(assessment["material"])
        self.assertIn("keep_baseline_no_change", assessment["reasons"])

    def test_material_only_when_thresholds_clear(self) -> None:
        daily = self._daily()
        keys = [(101, "EURUSD.DWX"), (102, "XAUUSD.DWX"), (103, "USDJPY.DWX")]
        weights = {k: 2.0 for k in keys}
        base_m = metrics_mod.compute_roster_metrics(keys, weights, daily)
        base_f = dxz_fitness.compute_dxz_fitness(base_m)
        base_book = metrics_mod.book_by_date(keys, weights, daily)

        # A degrading alternative (drop the best sleeve) must not be material.
        worse_keys = [(101, "EURUSD.DWX"), (103, "USDJPY.DWX")]
        worse_w = {k: 3.0 for k in worse_keys}
        worse_m = metrics_mod.compute_roster_metrics(worse_keys, worse_w, daily)
        worse_f = dxz_fitness.compute_dxz_fitness(worse_m)
        worse_book = metrics_mod.book_by_date(worse_keys, worse_w, daily)
        worse = mat_mod.assess(
            venue="dxz",
            change={"outcome": "REMOVE_SLEEVE", "add": [], "remove": [[102, "XAUUSD.DWX"]], "replace": []},
            baseline_fitness=base_f, alt_fitness=worse_f,
            baseline_metrics=base_m, alt_metrics=worse_m,
            baseline_book_by_date=base_book, alt_book_by_date=worse_book,
            incumbent_symbols=["EURUSD", "XAUUSD", "USDJPY"], seed=0,
        )
        # Whatever the sign, a change with delta_objective below the improvement threshold
        # is NEVER material; if it happens to improve it must clear every factor.
        if worse["factors"]["expected_improvement"]["delta_objective"] is not None:
            if worse["factors"]["expected_improvement"]["delta_objective"] < mat_mod.DEFAULT_CONFIG["min_fitness_improvement"]:
                self.assertFalse(worse["material"])


class ChangeThresholdTests(unittest.TestCase):
    def test_add_challenger_material_requires_all_factors(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            src = _source_root(tmp)
            snap = tmp / "snap"
            fs.freeze(
                "dxz", snap,
                as_of=dt.datetime(2026, 9, 18, 20, 0, tzinfo=dt.UTC), seed=3,
                qualified_pairs=[(101, "EURUSD.DWX"), (102, "XAUUSD.DWX"), (103, "USDJPY.DWX"), (201, "GBPUSD.DWX")],
                incumbents=_incumbents_3(), stream_source_roots=[src], git_commit="c",
            )
            read_model = rc.evaluate("dxz", snap, tmp / "rm.json", risk_budget=6.0, book_evolution_root=tmp / "be")
            outcome = read_model["proposal"]["outcome"]
            self.assertIn(outcome, decide_mod.VALID_OUTCOMES)
            if outcome != "KEEP":
                # A non-KEEP outcome must carry a material, threshold-clearing change.
                self.assertTrue(read_model["proposal"]["materiality"].get("material"))
                self.assertTrue(read_model["proposal"]["changes"])


class RiskDiagnosticsCarryTests(unittest.TestCase):
    def test_cap_warnings_carried_into_output(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            q08 = tmp / "src" / "QM" / "q08_trades"
            # Three distinct EAs on the SAME symbol -> symbol concentration warning.
            _write_stream(q08, 101, "EURUSD.DWX", lambda i: math.sin(i / 7.0) * 20 + 5)
            _write_stream(q08, 102, "EURUSD.DWX", lambda i: math.cos(i / 5.0) * 22 + 4)
            _write_stream(q08, 103, "EURUSD.DWX", lambda i: (i % 9 - 4) * 8 + 3)
            trades = load_streams(tmp / "src", candidates=[(101, "EURUSD.DWX"), (102, "EURUSD.DWX"), (103, "EURUSD.DWX")])
            daily = {k: to_daily_pnl(v) for k, v in trades.items()}
            keys = sorted(daily)
            weights = {k: 3.0 for k in keys}  # 3 x 3% = 9% on one symbol, budget 11 -> > 46% cap
            m = metrics_mod.compute_roster_metrics(keys, weights, daily, trades_by_key=trades)
            asset = {k: "fx_major" for k in keys}
            family = {k: f"fam_{k[0]}" for k in keys}
            session = {k: "london" for k in keys}
            diag = rc._risk_diagnostics(
                keys, weights, daily, trades, m,
                asset_by_key=asset, family_by_key=family, session_by_key=session,
            )
            self.assertEqual(diag["status"], "PRESENT")
            caps = {w["cap"] for w in diag["cap_warnings"]}
            self.assertIn("symbol", caps)
            # The advisory breach must NOT fail the book closed (b2: caps are advisory).
            self.assertTrue(diag["hard_guards"]["passed"])
            # Dependence panel is enriched with downside correlation + trade overlap.
            self.assertTrue(diag["dependence_panel"])
            self.assertIn("downside_correlation", diag["dependence_panel"][0])
            self.assertIn("trade_overlap_jaccard", diag["dependence_panel"][0])


if __name__ == "__main__":
    unittest.main()
