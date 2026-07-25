import datetime as dt
import hashlib
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_common import Trade  # noqa: E402
from portfolio import portfolio_q08_contribution  # noqa: E402
from portfolio.portfolio_q08_contribution import (  # noqa: E402
    equity_curve,
    evaluate_q08_soft_rescue,
    monthly_returns,
)


class PortfolioQ08ContributionTests(unittest.TestCase):
    def test_default_starting_capital_matches_canonical_tester_deposit(self) -> None:
        self.assertEqual(portfolio_q08_contribution.DEFAULT_STARTING_CAPITAL, 100_000.0)

    def test_monthly_returns_and_equity_curve_are_chronological(self) -> None:
        trades = [
            Trade(100, "EURUSD.DWX", self._ts(2024, 2, 1), 0.0, 1.0, 10000.0, 0.0, 3.25),
            Trade(100, "EURUSD.DWX", self._ts(2024, 1, 2), 0.0, 1.0, 10000.0, 0.0, 10.0),
            Trade(100, "EURUSD.DWX", self._ts(2024, 1, 5), 0.0, 1.0, 10000.0, 0.0, -4.5),
        ]

        self.assertEqual(monthly_returns(trades), {"2024-01": 5.5, "2024-02": 3.25})
        self.assertEqual(
            equity_curve(trades),
            [
                {"time": self._ts(2024, 1, 2), "equity": 10.0, "net_of_cost": 10.0},
                {"time": self._ts(2024, 1, 5), "equity": 5.5, "net_of_cost": -4.5},
                {"time": self._ts(2024, 2, 1), "equity": 8.75, "net_of_cost": 3.25},
            ],
        )

    def test_need_more_data_when_candidate_trade_count_below_minimum(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            common_dir = Path(tmp) / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 19)

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=Path(tmp) / "missing.sqlite",
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "portfolio_trade_count_below_min")
        self.assertEqual(verdict["trade_count"], 19)

    def test_short_stream_reexports_from_q08_evidence_and_gets_real_verdict(self) -> None:
        # WP-6 (gate-repair 2026-07-25): a Q08 passer whose durable stream export was
        # truncated (< floor) but whose backtest recorded >= floor is re-exported ONLY from a
        # provenance-bound Q08 source — the aggregate's own portfolio_stream record whose
        # persisted count matches the authoritative count AND whose file reads back exactly
        # that many volume-bearing rows — then judged for real. Here the aggregate recorded a
        # cross-key host_copy holding the full run (a legitimate basket-style recovery).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            # Admission stream (dst) is short; the aggregate-recorded recovery path is full.
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 12)
            recoverable = root / "durable_source_101_EURUSD_DWX.jsonl"
            self._write_stream(recoverable, [10.0] * 30)
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps(
                    {
                        "n_trades": 30,
                        "portfolio_stream": {"path": str(recoverable), "n": 30},
                    }
                ),
                encoding="utf-8",
            )
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX"), ("QM5_101", "EURUSD.DWX")])

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": True, "reason": "portfolio_contribution_pass"},
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                    q08_summary_path=summary,
                    q08_trade_count=30,
                )

        self.assertEqual(verdict["verdict"], "PASS_PORTFOLIO")
        self.assertEqual(verdict["trade_count"], 30)
        self.assertTrue(verdict["stream_reexport"]["repaired"])
        self.assertEqual(verdict["stream_reexport"]["reason"], "reexported_from_q08_evidence")
        self.assertEqual(verdict["stream_reexport"]["source_path"], str(recoverable))
        self.assertEqual(verdict["stream_reexport"]["source_trade_count"], 30)
        admission.assert_called_once()

    def test_short_stream_stays_need_more_data_when_no_recoverable_source(self) -> None:
        # No Q08 aggregate lineage at all (evidence purged): the sleeve stays NEED_MORE_DATA
        # even though the authoritative backtest cleared the floor. This is the real state of
        # the five stranded pairs — their Q08 aggregates are purged, so provenance is gone.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 12)

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=root / "missing.sqlite",
                q08_trade_count=30,
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "portfolio_trade_count_below_min")
        self.assertFalse(verdict["stream_reexport"]["repaired"])
        self.assertEqual(
            verdict["stream_reexport"]["reason"], "q08_aggregate_stream_lineage_unavailable"
        )

    def test_reexport_refuses_unrelated_source_with_wrong_count(self) -> None:
        # Codex-cited defect shape: authoritative=296, a short/foreign volume-bearing source.
        # The count gate refuses because the source does not read back exactly 296 rows — it
        # is NOT laundered into a real verdict (previously returned repaired=true).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 10)
            foreign = root / "durable_source_101_EURUSD_DWX.jsonl"
            self._write_stream(foreign, [10.0] * 40)  # 40 != authoritative 296
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({"n_trades": 296, "portfolio_stream": {"path": str(foreign), "n": 296}}),
                encoding="utf-8",
            )

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=root / "missing.sqlite",
                q08_summary_path=summary,
                q08_trade_count=296,
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertFalse(verdict["stream_reexport"]["repaired"])
        self.assertEqual(
            verdict["stream_reexport"]["reason"], "no_lineage_bound_source_matches_evidence_count"
        )

    def test_reexport_refuses_when_aggregate_records_wrong_persisted_count(self) -> None:
        # Lineage gate: the aggregate's own recorded persisted count must equal the
        # authoritative count. A run that graded 92 but recorded persisting 40 cannot be
        # trusted to have persisted the authoritative set — refuse.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 10)
            source = root / "durable_source_101_EURUSD_DWX.jsonl"
            self._write_stream(source, [10.0] * 92)
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({"n_trades": 92, "portfolio_stream": {"path": str(source), "n": 40}}),
                encoding="utf-8",
            )

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=root / "missing.sqlite",
                q08_summary_path=summary,
                q08_trade_count=92,
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertFalse(verdict["stream_reexport"]["repaired"])
        self.assertEqual(
            verdict["stream_reexport"]["reason"], "q08_aggregate_stream_count_mismatch"
        )

    def test_reexport_copy_failure_leaves_durable_stream_intact(self) -> None:
        # Atomicity (defect-3): if the copy fails mid-repair, the existing durable stream is
        # untouched (no truncated durable file) and no temp file is left behind.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            dst = stream_dir / "101_EURUSD_DWX.jsonl"
            self._write_stream(dst, [10.0] * 12)
            before = dst.read_bytes()
            source = root / "durable_source_101_EURUSD_DWX.jsonl"
            self._write_stream(source, [10.0] * 30)
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({"n_trades": 30, "portfolio_stream": {"path": str(source), "n": 30}}),
                encoding="utf-8",
            )

            with mock.patch(
                "portfolio.portfolio_q08_contribution.shutil.copyfile",
                side_effect=OSError("disk full"),
            ):
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                    q08_summary_path=summary,
                    q08_trade_count=30,
                )

            self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
            self.assertFalse(verdict["stream_reexport"]["repaired"])
            self.assertTrue(verdict["stream_reexport"]["reason"].startswith("reexport_copy_failed"))
            # Durable stream unchanged; no leftover temp sibling.
            self.assertEqual(dst.read_bytes(), before)
            self.assertEqual(list(stream_dir.glob("*.tmp")), [])

    def test_short_stream_not_repaired_when_backtest_below_floor(self) -> None:
        # No authoritative count >= floor => genuinely low-frequency, not a broken export.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 12)

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=root / "missing.sqlite",
                q08_trade_count=12,
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "portfolio_trade_count_below_min")
        self.assertFalse(verdict["stream_reexport"]["repaired"])
        self.assertEqual(
            verdict["stream_reexport"]["reason"], "q08_evidence_trade_count_below_min"
        )

    def test_regime_catastrophe_defers_to_portfolio_admission(self) -> None:
        # DL-078 (OWNER-ratified 2026-06-27): a standalone Q08 8.10 regime catastrophe no
        # longer hard-rejects. It is recorded for audit but the verdict defers to
        # portfolio_admission -- the anticorrelation book is meant to ABSORB regime
        # dependence (DL-075). A regime-fragile sleeve that improves the book is admitted.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            summary = root / "q08_summary.json"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX"), ("QM5_101", "EURUSD.DWX")])
            summary.write_text(
                json.dumps(
                    {
                        "sub_gates": [
                            {
                                "name": "8.10 Regime",
                                "detail": "unprofitable_regimes=London,NY",
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={
                    "admit": True,
                    "reason": "portfolio_contribution_pass",
                    "max_corr_to_book": 0.2,
                    "maxdd_with": 0.04,
                    "maxdd_without": 0.06,
                },
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                    q08_summary_path=summary,
                )

        self.assertEqual(verdict["verdict"], "PASS_PORTFOLIO")
        self.assertTrue(verdict["q08_regime_catastrophe"])
        self.assertTrue(verdict["regime_catastrophe_absorbed_by_book"])
        admission.assert_called_once()

    def test_regime_catastrophe_still_fails_when_book_not_improved(self) -> None:
        # The override is not a free pass: a regime-fragile sleeve that does NOT improve the
        # book still FAILs at the admission check (DL-078 defers, it does not waive).
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            summary = root / "q08_summary.json"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            summary.write_text(
                json.dumps({"sub_gates": [{"name": "8.10 Regime", "detail": "unprofitable_regimes=NY"}]}),
                encoding="utf-8",
            )
            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": False, "reason": "no_diversification"},
            ):
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                    q08_summary_path=summary,
                )

        self.assertEqual(verdict["verdict"], "FAIL_PORTFOLIO")
        self.assertEqual(verdict["reason"], "no_diversification")
        self.assertTrue(verdict["q08_regime_catastrophe"])

    def test_pass_portfolio_delegates_to_portfolio_admission(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX"), ("QM5_101", "EURUSD.DWX")])

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={
                    "admit": True,
                    "reason": "portfolio_contribution_pass",
                    "max_corr_to_book": 0.2,
                    "sharpe_with": 1.1,
                    "sharpe_without": 0.9,
                },
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                )

        self.assertEqual(verdict["verdict"], "PASS_PORTFOLIO")
        self.assertEqual(verdict["reason"], "portfolio_contribution_pass")
        admission.assert_called_once_with(
            (101, "EURUSD.DWX"),
            [(100, "EURUSD.DWX")],
            common_dir,
            max_corr=0.30,
            starting_capital=100_000.0,
        )

    def test_fail_portfolio_delegates_to_portfolio_admission(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": False, "reason": "correlation_above_max_corr"},
            ):
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                )

        self.assertEqual(verdict["verdict"], "FAIL_PORTFOLIO")
        self.assertEqual(verdict["reason"], "correlation_above_max_corr")

    def test_insufficient_overlap_is_need_more_data_not_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={
                    "admit": False,
                    "reason": "insufficient_overlap",
                    "diversifies": True,
                    "sharpe_with": 1.1,
                    "sharpe_without": 0.9,
                },
            ):
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "portfolio_correlation_overlap_below_min")
        self.assertEqual(verdict["previous_verdict"], "FAIL_PORTFOLIO")
        self.assertTrue(verdict["sparse_overlap_watchlist"])

    def test_missing_book_streams_are_need_more_data_not_runner_crash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX")])

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=candidates_db,
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "portfolio_admission_missing_streams")
        self.assertIn("missing q08 trade streams", verdict["admission_error"])

    def test_above_floor_count_mismatch_refuses_without_grading(self) -> None:
        # WP-6 defect-1 (round 2, 2026-07-25 Codex re-review): an ABOVE-FLOOR stream whose
        # count diverges from the authoritative Q08 count must NOT be graded. 40 loaded rows
        # against authoritative 296 with no recoverable lineage previously reached a real
        # PASS under a positive admission mock. It must now refuse (NEED_MORE_DATA) and never
        # call admission — a verdict on unproven data is exactly the laundering to prevent.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 40)

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": True, "reason": "portfolio_contribution_pass"},
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                    q08_trade_count=296,
                    min_portfolio_trades=20,
                )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "q08_stream_count_mismatch")
        self.assertEqual(verdict["trade_count"], 40)
        self.assertEqual(verdict["authoritative_q08_trade_count"], 296)
        admission.assert_not_called()

    def test_reexport_refuses_source_whose_sha_differs_from_content_sha256(self) -> None:
        # WP-6 defect-2 (round 2): a v2 aggregate binds the graded bytes via content_sha256.
        # A same-COUNT source whose bytes hash differently is foreign and must be refused —
        # previously it was accepted (repaired=true) on count equality alone.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 12)
            source = root / "durable_source_101_EURUSD_DWX.jsonl"
            self._write_stream(source, [10.0] * 30)
            wrong_sha = hashlib.sha256(b"not the source bytes").hexdigest()
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({
                    "n_trades": 30,
                    "portfolio_stream": {"path": str(source), "n": 30, "content_sha256": wrong_sha},
                }),
                encoding="utf-8",
            )

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=root / "missing.sqlite",
                q08_summary_path=summary,
                q08_trade_count=30,
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertFalse(verdict["stream_reexport"]["repaired"])
        self.assertEqual(verdict["stream_reexport"]["lineage_basis"], "sha256")
        self.assertEqual(
            verdict["stream_reexport"]["reason"],
            "no_lineage_bound_source_matches_evidence_sha256",
        )

    def test_reexport_repairs_when_source_sha_matches_content_sha256(self) -> None:
        # The v2 SHA gate is not refuse-everything: a source whose bytes DO hash to the
        # recorded content_sha256 repairs and reaches a real verdict, on lineage_basis=sha256.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 12)
            source = root / "durable_source_101_EURUSD_DWX.jsonl"
            self._write_stream(source, [10.0] * 30)
            good_sha = hashlib.sha256(source.read_bytes()).hexdigest()
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({
                    "n_trades": 30,
                    "portfolio_stream": {"path": str(source), "n": 30, "content_sha256": good_sha},
                }),
                encoding="utf-8",
            )
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX"), ("QM5_101", "EURUSD.DWX")])

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": True, "reason": "portfolio_contribution_pass"},
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                    q08_summary_path=summary,
                    q08_trade_count=30,
                )

        self.assertEqual(verdict["verdict"], "PASS_PORTFOLIO")
        self.assertEqual(verdict["trade_count"], 30)
        self.assertTrue(verdict["stream_reexport"]["repaired"])
        self.assertEqual(verdict["stream_reexport"]["lineage_basis"], "sha256")
        admission.assert_called_once()

    def test_v1_aggregate_repairs_on_count_only_fallback(self) -> None:
        # v1-fallback semantics: an aggregate WITHOUT content_sha256 can only be checked by
        # count. The re-export must still repair from a count-matched lineage source and
        # record lineage_basis=count_only so the evidence says which bar was applied.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 12)
            source = root / "durable_source_101_EURUSD_DWX.jsonl"
            self._write_stream(source, [10.0] * 30)
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({"n_trades": 30, "portfolio_stream": {"path": str(source), "n": 30}}),
                encoding="utf-8",
            )
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX"), ("QM5_101", "EURUSD.DWX")])

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": True, "reason": "portfolio_contribution_pass"},
            ):
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                    q08_summary_path=summary,
                    q08_trade_count=30,
                )

        self.assertEqual(verdict["verdict"], "PASS_PORTFOLIO")
        self.assertTrue(verdict["stream_reexport"]["repaired"])
        self.assertEqual(verdict["stream_reexport"]["lineage_basis"], "count_only")

    def test_null_volume_stream_is_need_more_data_not_crash(self) -> None:
        # WP-6 defect-4 (round 2): a durable admission stream carrying volume: null must NOT
        # crash the load path (float(None) TypeError deep in _load_one_stream). It fails
        # validation cleanly => NEED_MORE_DATA, never an exception, never a verdict.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            dst = stream_dir / "101_EURUSD_DWX.jsonl"
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            with dst.open("w", encoding="utf-8") as fh:
                for i in range(30):
                    fh.write(json.dumps({
                        "event": "TRADE_CLOSED",
                        "symbol": "EURUSD.DWX",
                        "time": int((start + dt.timedelta(days=i)).timestamp()),
                        "net": 10.0,
                        "volume": None,
                        "notional": 10000.0,
                    }) + "\n")

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=root / "missing.sqlite",
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "q08_stream_unloadable")
        self.assertTrue(verdict["stream_load_error"].startswith("q08_stream_unloadable:"))

    def test_null_volume_source_is_not_a_valid_reexport_source(self) -> None:
        # The volume-bearing count also rejects a null-volume file AS A SOURCE, so the
        # re-export never installs a stream that the load path would later choke on.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 12)
            source = root / "durable_source_101_EURUSD_DWX.jsonl"
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            with source.open("w", encoding="utf-8") as fh:
                for i in range(30):
                    fh.write(json.dumps({
                        "event": "TRADE_CLOSED",
                        "symbol": "EURUSD.DWX",
                        "time": int((start + dt.timedelta(days=i)).timestamp()),
                        "net": 10.0,
                        "volume": None,
                        "notional": 10000.0,
                    }) + "\n")
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({"n_trades": 30, "portfolio_stream": {"path": str(source), "n": 30}}),
                encoding="utf-8",
            )

            verdict = evaluate_q08_soft_rescue(
                (101, "EURUSD.DWX"),
                common_dir=common_dir,
                candidates_db=root / "missing.sqlite",
                q08_summary_path=summary,
                q08_trade_count=30,
            )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertFalse(verdict["stream_reexport"]["repaired"])
        self.assertEqual(
            verdict["stream_reexport"]["reason"],
            "no_lineage_bound_source_matches_evidence_count",
        )

    def test_same_count_destination_wrong_sha_is_never_graded(self) -> None:
        # WP-6 defect-1 (round 3, 2026-07-25 Codex re-check): a destination whose count
        # ALREADY equals the authoritative Q08 count previously skipped SHA verification
        # entirely (needs_repair was false) and was graded on foreign bytes. Now a v2
        # aggregate's content_sha256 is checked against the loaded destination BEFORE
        # grading; a mismatch that no re-export can reconcile refuses with
        # q08_stream_sha256_mismatch and NEVER calls admission.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            # Destination has the RIGHT count (30 == authoritative, above floor 20) but its
            # bytes will not match the aggregate's recorded content_sha256.
            self._write_stream(stream_dir / "101_EURUSD_DWX.jsonl", [10.0] * 30)
            # A same-count lineage source that ALSO does not hash to content_sha256, so the
            # re-export cannot reconcile the identity either.
            source = root / "durable_source_101_EURUSD_DWX.jsonl"
            self._write_stream(source, [7.5] * 30)
            wrong_sha = hashlib.sha256(b"authoritative bytes that exist nowhere").hexdigest()
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({
                    "n_trades": 30,
                    "portfolio_stream": {"path": str(source), "n": 30, "content_sha256": wrong_sha},
                }),
                encoding="utf-8",
            )

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": True, "reason": "portfolio_contribution_pass"},
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=root / "missing.sqlite",
                    q08_summary_path=summary,
                    q08_trade_count=30,
                    min_portfolio_trades=20,
                )

        self.assertEqual(verdict["verdict"], "NEED_MORE_DATA")
        self.assertEqual(verdict["reason"], "q08_stream_sha256_mismatch")
        self.assertEqual(verdict["lineage_basis"], "sha256")
        self.assertEqual(verdict["trade_count"], 30)
        self.assertEqual(verdict["evidence_content_sha256"], wrong_sha)
        # It entered the repair path (which re-hashes) and could not reconcile.
        self.assertFalse(verdict["stream_reexport"]["repaired"])
        # A verdict on unproven same-count bytes is exactly what must be prevented.
        admission.assert_not_called()

    def test_v2_destination_sha_match_is_graded(self) -> None:
        # v2 happy path: a destination whose count AND content hash both match the aggregate
        # is the freshly-exported authoritative set — it grades to a real verdict without any
        # re-export, on lineage_basis=sha256.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            common_dir = root / "common"
            stream_dir = self._stream_dir(common_dir)
            candidates_db = root / "candidates.sqlite"
            dst = stream_dir / "101_EURUSD_DWX.jsonl"
            self._write_stream(dst, [10.0] * 30)
            good_sha = hashlib.sha256(dst.read_bytes()).hexdigest()
            summary = root / "q08_summary.json"
            summary.write_text(
                json.dumps({
                    "n_trades": 30,
                    "portfolio_stream": {"path": str(dst), "n": 30, "content_sha256": good_sha},
                }),
                encoding="utf-8",
            )
            self._write_candidates(candidates_db, [("QM5_100", "EURUSD.DWX"), ("QM5_101", "EURUSD.DWX")])

            with mock.patch(
                "portfolio.portfolio_q08_contribution.portfolio_admission.evaluate_candidate",
                return_value={"admit": True, "reason": "portfolio_contribution_pass"},
            ) as admission:
                verdict = evaluate_q08_soft_rescue(
                    (101, "EURUSD.DWX"),
                    common_dir=common_dir,
                    candidates_db=candidates_db,
                    q08_summary_path=summary,
                    q08_trade_count=30,
                    min_portfolio_trades=20,
                )

        self.assertEqual(verdict["verdict"], "PASS_PORTFOLIO")
        self.assertEqual(verdict["trade_count"], 30)
        self.assertEqual(verdict["lineage_basis"], "sha256")
        self.assertEqual(verdict["destination_sha256"], good_sha)
        # No repair was needed: identity was proven directly on the loaded destination.
        self.assertNotIn("stream_reexport", verdict)
        admission.assert_called_once()

    def _ts(self, year: int, month: int, day: int) -> int:
        return int(dt.datetime(year, month, day, tzinfo=dt.UTC).timestamp())

    def _stream_dir(self, common_dir: Path) -> Path:
        stream_dir = common_dir / "QM" / "q08_trades"
        stream_dir.mkdir(parents=True)
        return stream_dir

    def _write_stream(self, path: Path, desired_net: list[float]) -> None:
        cost = CommissionModel(REPO / "framework" / "registry" / "live_commission.json").cost_round_trip(
            "EURUSD.DWX",
            1.0,
            10000.0,
        )
        start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
        with path.open("w", encoding="utf-8") as fh:
            for offset, net_of_cost in enumerate(desired_net):
                row = {
                    "event": "TRADE_CLOSED",
                    "symbol": "EURUSD.DWX",
                    "time": int((start + dt.timedelta(days=offset)).timestamp()),
                    "net": net_of_cost + cost,
                    "volume": 1.0,
                    "notional": 10000.0,
                }
                fh.write(json.dumps(row, sort_keys=True) + "\n")

    def _write_candidates(self, db_path: Path, rows: list[tuple[str, str]]) -> None:
        conn = sqlite3.connect(db_path)
        try:
            conn.execute("CREATE TABLE portfolio_candidates (ea_id TEXT, symbol TEXT, state TEXT)")
            conn.executemany(
                "INSERT INTO portfolio_candidates (ea_id, symbol, state) VALUES (?, ?, 'Q12_REVIEW_READY')",
                rows,
            )
            conn.commit()
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
