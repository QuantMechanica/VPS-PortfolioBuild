import datetime as dt
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio.commission import CommissionModel  # noqa: E402
from portfolio.portfolio_common import (  # noqa: E402
    FrozenStreamBundle,
    FrozenStreamValidationError,
    Trade,
    VerifiedStreamInfo,
    load_frozen_stream_bundle,
)
from portfolio.portfolio_freeze_gate import (  # noqa: E402
    FreezeGateError,
    sha256_file,
    validate_admission_resize_freeze_gate,
)
from portfolio.portfolio_resize import (  # noqa: E402
    AllocationError,
    SleeveMeta,
    allocate_hierarchical,
    build_resize_report_from_files,
    capped_proportional_allocation,
    closed_trade_portfolio_metrics,
    main as resize_main,
    normalized_daily_returns_per_risk_pct,
)


class CappedAllocationTests(unittest.TestCase):
    def test_sleeve_cap_redistributes_excess_and_preserves_exact_target(self) -> None:
        allocated = capped_proportional_allocation(
            {"heavy": 9.0, "light": 1.0}, target_total=1.5, caps=1.0
        )
        self.assertAlmostEqual(allocated["heavy"], 1.0)
        self.assertAlmostEqual(allocated["light"], 0.5)
        self.assertAlmostEqual(sum(allocated.values()), 1.5)

    def test_infeasible_sleeve_caps_fail_instead_of_returning_short_total(self) -> None:
        with self.assertRaisesRegex(AllocationError, "exceeds sleeve capacity"):
            capped_proportional_allocation(
                {"a": 9.0, "b": 1.0}, target_total=2.1, caps=1.0
            )

    def test_all_five_hierarchy_caps_hold_and_target_is_preserved(self) -> None:
        sleeves = [
            SleeveMeta("a", 1, "X", "m1", "fx"),
            SleeveMeta("b", 1, "Y", "m2", "fx"),
            SleeveMeta("c", 2, "X", "m2", "index"),
            SleeveMeta("d", 2, "Z", "m1", "index"),
        ]
        result = allocate_hierarchical(
            {"a": 10.0, "b": 1.0, "c": 1.0, "d": 1.0},
            sleeves,
            2.4,
            {
                "sleeve": 0.8,
                "ea": 1.2,
                "symbol": {"default": 0.8, "overrides": {"X": 1.0}},
                "mechanism": 1.3,
                "asset_class": 1.2,
            },
        )
        self.assertAlmostEqual(sum(result.weights.values()), 2.4, places=8)
        self.assertLessEqual(max(result.weights.values()), 0.8 + 1e-8)
        for dimension, groups in result.cap_usage.items():
            self.assertTrue(groups, dimension)
            for group in groups.values():
                self.assertLessEqual(
                    group["allocated_risk_pct"], group["cap_risk_pct"] + 1e-8
                )

    def test_crossing_ea_symbol_caps_find_feasible_solution_for_skewed_scores(self) -> None:
        # A greedy clip can strand capacity here after over-allocating the high-score
        # EA1/symbol-X intersection. The convex solver must still find the feasible cross.
        sleeves = [
            SleeveMeta("a", 1, "X", "m", "fx"),
            SleeveMeta("b", 1, "Y", "m", "fx"),
            SleeveMeta("c", 2, "X", "m", "fx"),
            SleeveMeta("d", 2, "Y", "m", "fx"),
        ]
        result = allocate_hierarchical(
            {"a": 100.0, "b": 1.0, "c": 1.0, "d": 1.0},
            sleeves,
            1.0,
            {"sleeve": 1.0, "ea": 0.5, "symbol": 0.5},
        )
        self.assertAlmostEqual(sum(result.weights.values()), 1.0, places=8)
        self.assertLessEqual(result.weights["a"] + result.weights["b"], 0.5 + 1e-8)
        self.assertLessEqual(result.weights["a"] + result.weights["c"], 0.5 + 1e-8)

    def test_dimension_capacity_is_fail_closed(self) -> None:
        sleeves = [
            SleeveMeta("a", 1, "X", "m", "fx"),
            SleeveMeta("b", 2, "Y", "m", "fx"),
        ]
        with self.assertRaisesRegex(AllocationError, "asset_class cap capacity"):
            allocate_hierarchical(
                {"a": 1.0, "b": 1.0},
                sleeves,
                1.0,
                {"sleeve": 1.0, "asset_class": 0.5},
            )


class FrozenStreamBundleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.frozen = self.root / "frozen_streams"
        self.frozen.mkdir()
        self.model_path = self.root / "commission.json"
        self.model_path.write_text(
            json.dumps(
                {
                    "classes": {"zero": {"pct_rate_rt": 0.0, "flat_per_lot_rt": 0.0}},
                    "symbol_class": {"EURUSD.DWX": "zero"},
                    "default_class": "zero",
                }
            ),
            encoding="utf-8",
        )
        self.model = CommissionModel(self.model_path)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _stream(self, name: str = "100_EURUSD_DWX.jsonl") -> Path:
        path = self.frozen / name
        path.write_text(
            json.dumps(
                {
                    "event": "TRADE_CLOSED",
                    "time": 1_704_153_600,
                    "net": 1000.0,
                    "volume": 1.0,
                    "notional": 10_000.0,
                }
            )
            + "\n",
            encoding="utf-8",
        )
        return path

    def _manifest(self, stream: Path, *, sha: str | None = None, frozen: bool = True) -> Path:
        manifest = self.root / "streams.json"
        manifest.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "frozen": frozen,
                    "frozen_root": str(self.frozen),
                    "risk_scale": {
                        "unit": "account_percent",
                        "source_starting_capital": 100_000,
                        "source_risk_pct": 2.0,
                    },
                    "streams": [
                        {
                            "ea_id": 100,
                            "symbol": "EURUSD.DWX",
                            "path": stream.name,
                            "sha256": sha or sha256_file(stream),
                            "trade_count": 1,
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        return manifest

    def test_loads_sha_verified_stream_and_explicit_source_scale(self) -> None:
        stream = self._stream()
        manifest = self._manifest(stream)
        bundle = load_frozen_stream_bundle(
            manifest, expected_keys=[(100, "EURUSD.DWX")], commission_model=self.model
        )
        info = bundle.info[(100, "EURUSD.DWX")]
        self.assertEqual(info.sha256, sha256_file(stream))
        self.assertEqual(info.trade_count, 1)
        self.assertEqual(info.source_starting_capital, 100_000)
        self.assertEqual(info.source_risk_pct, 2.0)

    def test_hash_mismatch_is_rejected(self) -> None:
        stream = self._stream()
        manifest = self._manifest(stream, sha="0" * 64)
        with self.assertRaisesRegex(FrozenStreamValidationError, "SHA256 mismatch"):
            load_frozen_stream_bundle(manifest, commission_model=self.model)

    def test_frozen_attestation_is_required(self) -> None:
        stream = self._stream()
        manifest = self._manifest(stream, frozen=False)
        with self.assertRaisesRegex(FrozenStreamValidationError, "frozen=true"):
            load_frozen_stream_bundle(manifest, commission_model=self.model)

    def test_stream_path_may_not_escape_frozen_root(self) -> None:
        stream = self._stream()
        outside = self.root / "outside.jsonl"
        outside.write_bytes(stream.read_bytes())
        manifest = self._manifest(stream)
        payload = json.loads(manifest.read_text(encoding="utf-8"))
        payload["streams"][0]["path"] = str(outside)
        payload["streams"][0]["sha256"] = sha256_file(outside)
        manifest.write_text(json.dumps(payload), encoding="utf-8")
        with self.assertRaisesRegex(FrozenStreamValidationError, "escapes frozen_root"):
            load_frozen_stream_bundle(manifest, commission_model=self.model)


class RiskScaleAndMetricTests(unittest.TestCase):
    def test_stream_dollars_use_explicit_source_risk_scale(self) -> None:
        key = (100, "EURUSD.DWX")
        day1 = int(dt.datetime(2024, 1, 2, tzinfo=dt.UTC).timestamp())
        day2 = int(dt.datetime(2024, 1, 3, tzinfo=dt.UTC).timestamp())
        trades = [
            Trade(100, key[1], day1, 2000.0, 1.0, None, 0.0, 2000.0),
            Trade(100, key[1], day2, 2000.0, 1.0, None, 0.0, 2000.0),
        ]
        info = VerifiedStreamInfo(
            key, Path("stream"), "a" * 64, 1, 2, day1, day2, 100_000.0, 2.0
        )
        bundle = FrozenStreamBundle(
            Path("manifest"), "b" * 64, Path("frozen"), {key: trades}, {key: info}
        )
        normalized = normalized_daily_returns_per_risk_pct(bundle)
        # $2k on $100k at source risk 2% = +1% return per allocated risk point.
        self.assertAlmostEqual(next(iter(normalized[key].values())), 0.01)
        metrics = closed_trade_portfolio_metrics(
            normalized, {key: 1.0}, starting_capital=100_000.0
        )
        self.assertAlmostEqual(metrics["final_equity"], 102_010.0)
        self.assertEqual(metrics["equity_basis"], "daily_compounded_realized_closes_only")

    def test_compounded_drawdown_uses_peak_equity(self) -> None:
        key = (100, "EURUSD.DWX")
        normalized = {
            key: {
                dt.date(2024, 1, 2): 0.10,
                dt.date(2024, 1, 3): -0.10,
            }
        }
        metrics = closed_trade_portfolio_metrics(
            normalized, {key: 1.0}, starting_capital=100.0
        )
        self.assertAlmostEqual(metrics["final_equity"], 99.0)
        self.assertAlmostEqual(metrics["max_drawdown_realized_close_only_pct"], 10.0)
        self.assertFalse(metrics["dxz_var_proxy"]["official_darwin_metric"])


class FreezeGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.truth = self.root / "truth.json"
        self.candidate_sha = "c" * 64
        self.adjudication_sha = "d" * 64
        self.requal_sha = "e" * 64
        self.truth.write_text(
            json.dumps(
                {
                    "verdict": "PASS",
                    "qualification_chain": {
                        "applicable": True,
                        "status": "PASS",
                        "candidate": {
                            "status": "BOUND_CANDIDATE_COMPLETE",
                            "sha256": self.candidate_sha,
                        },
                        "adjudication": {
                            "verdict": "PASS",
                            "sha256": self.adjudication_sha,
                        },
                        "requalification": {
                            "scope": "FULL",
                            "status": "PASS",
                            "sha256": self.requal_sha,
                        },
                    },
                }
            ),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _gate(
        self,
        *,
        truth_status: str = "PASS",
        truth_sha: str | None = None,
        input_sha: str = "a" * 64,
        stream_sha: str = "b" * 64,
    ) -> Path:
        gate = self.root / "gate.json"
        gate.write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "gate_type": "ADMISSION_RESIZE_FREEZE",
                    "allowed_purposes": ["admission", "resize"],
                    "truth_chain": {
                        "status": truth_status,
                        "artifact_path": self.truth.name,
                        "artifact_sha256": truth_sha or sha256_file(self.truth),
                        "candidate_manifest_sha256": self.candidate_sha,
                        "adjudication_sha256": self.adjudication_sha,
                        "requal_summary_sha256": self.requal_sha,
                    },
                    "inputs": {
                        "resize_config_sha256": input_sha,
                        "stream_manifest_sha256": input_sha,
                        "commission_registry_sha256": input_sha,
                        "streams": {"100:EURUSD.DWX": stream_sha},
                    },
                }
            ),
            encoding="utf-8",
        )
        return gate

    def test_pass_gate_supports_admission_and_resize_contract(self) -> None:
        gate = self._gate()
        evidence = validate_admission_resize_freeze_gate(
            gate,
            purpose="admission",
            actual_inputs={
                "resize_config_sha256": "a" * 64,
                "stream_manifest_sha256": "a" * 64,
                "commission_registry_sha256": "a" * 64,
            },
            actual_stream_sha256={"100:EURUSD.DWX": "b" * 64},
        )
        self.assertEqual(evidence.truth_chain_status, "PASS")
        self.assertEqual(evidence.gate_sha256, sha256_file(gate))

    def test_gate_flag_pass_is_not_enough_when_truth_artifact_is_not_pass(self) -> None:
        self.truth.write_text(json.dumps({"verdict": "FAIL"}), encoding="utf-8")
        gate = self._gate()
        with self.assertRaisesRegex(FreezeGateError, "artifact status"):
            validate_admission_resize_freeze_gate(
                gate,
                purpose="resize",
                actual_inputs={"resize_config_sha256": "a" * 64},
                actual_stream_sha256={"100:EURUSD.DWX": "b" * 64},
            )

    def test_any_input_sha_mismatch_fails(self) -> None:
        gate = self._gate()
        with self.assertRaisesRegex(FreezeGateError, "input SHA mismatch"):
            validate_admission_resize_freeze_gate(
                gate,
                purpose="resize",
                actual_inputs={"resize_config_sha256": "c" * 64},
                actual_stream_sha256={"100:EURUSD.DWX": "b" * 64},
            )

    def test_stream_sha_set_must_match_exactly(self) -> None:
        gate = self._gate()
        with self.assertRaisesRegex(FreezeGateError, "stream SHA key mismatch"):
            validate_admission_resize_freeze_gate(
                gate,
                purpose="resize",
                actual_inputs={"resize_config_sha256": "a" * 64},
                actual_stream_sha256={
                    "100:EURUSD.DWX": "b" * 64,
                    "200:GBPUSD.DWX": "c" * 64,
                },
            )


class ResizeCliFailClosedTests(unittest.TestCase):
    def test_failed_truth_chain_does_not_create_output_or_parent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            frozen = root / "frozen"
            frozen.mkdir()
            stream = frozen / "100_EURUSD_DWX.jsonl"
            rows = []
            start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
            for offset in range(40):
                stamp = start + dt.timedelta(days=offset)
                if stamp.weekday() >= 5:
                    continue
                rows.append(
                    json.dumps(
                        {
                            "event": "TRADE_CLOSED",
                            "time": int(stamp.timestamp()),
                            "net": 100.0 if offset % 2 else -50.0,
                            "volume": 1.0,
                            "notional": 10_000.0,
                        }
                    )
                )
            stream.write_text("\n".join(rows) + "\n", encoding="utf-8")
            stream_manifest = root / "streams.json"
            stream_manifest.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "frozen": True,
                        "frozen_root": str(frozen),
                        "risk_scale": {
                            "unit": "account_percent",
                            "source_starting_capital": 100_000,
                            "source_risk_pct": 1.0,
                        },
                        "streams": [
                            {
                                "ea_id": 100,
                                "symbol": "EURUSD.DWX",
                                "path": stream.name,
                                "sha256": sha256_file(stream),
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            config = root / "config.json"
            config.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "target_total_risk_pct": 0.5,
                        "min_vol_sessions": 10,
                        "caps": {
                            "sleeve": 1.0,
                            "ea": 1.0,
                            "symbol": 1.0,
                            "mechanism": 1.0,
                            "asset_class": 1.0,
                        },
                        "sleeves": [
                            {
                                "ea_id": 100,
                                "symbol": "EURUSD.DWX",
                                "mechanism": "test",
                                "asset_class": "fx",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            truth = root / "truth.json"
            truth.write_text(json.dumps({"truth_chain_status": "FAIL"}), encoding="utf-8")
            gate = root / "gate.json"
            gate.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "gate_type": "ADMISSION_RESIZE_FREEZE",
                        "allowed_purposes": ["resize"],
                        "truth_chain": {
                            "status": "PASS",
                            "artifact_path": truth.name,
                            "artifact_sha256": sha256_file(truth),
                        },
                        "inputs": {
                            "resize_config_sha256": sha256_file(config),
                            "stream_manifest_sha256": sha256_file(stream_manifest),
                            "commission_registry_sha256": sha256_file(
                                REPO / "framework" / "registry" / "live_commission.json"
                            ),
                            "streams": {"100:EURUSD.DWX": sha256_file(stream)},
                        },
                    }
                ),
                encoding="utf-8",
            )
            out = root / "not_created" / "book.json"
            with self.assertRaisesRegex(FreezeGateError, "artifact status"):
                resize_main(
                    [
                        "--config",
                        str(config),
                        "--stream-manifest",
                        str(stream_manifest),
                        "--freeze-gate",
                        str(gate),
                        "--out",
                        str(out),
                    ]
                )
            self.assertFalse(out.exists())
            self.assertFalse(out.parent.exists())


if __name__ == "__main__":
    unittest.main()
