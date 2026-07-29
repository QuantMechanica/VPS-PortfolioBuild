from __future__ import annotations

import datetime as dt
import json
import math
import unittest
from pathlib import Path

from framework.scripts.q08_v3_shadow.evidence_series import (
    BLOCK_BOOTSTRAP_SCHEMA_VERSION,
    RETURN_PANEL_SCHEMA_VERSION,
    CalendarBasis,
    DailyObservation,
    EvidenceSeriesError,
    ReferenceCapital,
    ReturnPanel,
    SleeveInput,
    SleeveReturnSeries,
    ValueKind,
    annualized_sharpe,
    build_return_panel,
    calendar_axis,
    moving_block_bootstrap,
)


SCHEMA_DIR = (
    Path(__file__).resolve().parents[1] / "q08_v3_shadow" / "schemas"
)
SOURCE_SHA = "a" * 64


def _capital(amount: float = 100_000.0) -> ReferenceCapital:
    return ReferenceCapital(
        amount=amount,
        currency="USD",
        source_id="ftmo-rulepack-v1",
        source_sha256=SOURCE_SHA,
    )


def _return_sleeve(
    sleeve_id: str,
    observations: list[tuple[str, float]],
) -> SleeveInput:
    return SleeveInput(
        sleeve_id=sleeve_id,
        value_kind=ValueKind.RETURN,
        observations=tuple(DailyObservation(day, value) for day, value in observations),
    )


class CalendarAndPanelContractTests(unittest.TestCase):
    def test_weekday_axis_is_complete_and_excludes_weekend(self) -> None:
        axis = calendar_axis(
            coverage_start="2026-07-24",
            coverage_end="2026-07-28",
            calendar_basis="WEEKDAY_252",
        )
        self.assertEqual(
            [day.isoformat() for day in axis],
            ["2026-07-24", "2026-07-27", "2026-07-28"],
        )

    def test_all_days_axis_includes_weekend(self) -> None:
        axis = calendar_axis(
            coverage_start="2026-07-24",
            coverage_end="2026-07-28",
            calendar_basis=CalendarBasis.ALL_DAYS_365,
        )
        self.assertEqual(len(axis), 5)
        self.assertEqual(axis[1].isoformat(), "2026-07-25")

    def test_missing_or_inverted_coverage_fails_closed(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "coverage_start"):
            calendar_axis(
                coverage_start=None,  # type: ignore[arg-type]
                coverage_end="2026-07-28",
                calendar_basis="ALL_DAYS_365",
            )
        with self.assertRaisesRegex(EvidenceSeriesError, "must not precede"):
            calendar_axis(
                coverage_start="2026-07-29",
                coverage_end="2026-07-28",
                calendar_basis="ALL_DAYS_365",
            )

    def test_noncanonical_date_and_weekend_only_weekday_coverage_fail(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "ISO date|canonical"):
            calendar_axis(
                coverage_start="2026-7-1",
                coverage_end="2026-07-02",
                calendar_basis="ALL_DAYS_365",
            )
        with self.assertRaisesRegex(EvidenceSeriesError, "contains no dates"):
            calendar_axis(
                coverage_start="2026-07-25",
                coverage_end="2026-07-26",
                calendar_basis="WEEKDAY_252",
            )

    def test_sparse_sleeves_share_one_zero_filled_axis(self) -> None:
        panel = build_return_panel(
            coverage_start="2026-07-20",
            coverage_end="2026-07-24",
            calendar_basis="WEEKDAY_252",
            sleeves=[
                _return_sleeve("B", [("2026-07-21", -0.02)]),
                _return_sleeve(
                    "A", [("2026-07-20", 0.01), ("2026-07-24", 0.03)]
                ),
            ],
        )
        self.assertEqual(len(panel.axis), 5)
        self.assertEqual([s.sleeve_id for s in panel.sleeves], ["A", "B"])
        self.assertEqual(panel.sleeves[0].returns, (0.01, 0.0, 0.0, 0.0, 0.03))
        self.assertEqual(panel.sleeves[1].returns, (0.0, -0.02, 0.0, 0.0, 0.0))
        self.assertEqual(panel.sleeves[0].zero_filled_day_count, 3)
        self.assertEqual(panel.sleeves[1].zero_filled_day_count, 4)
        self.assertRegex(panel.axis_sha256, r"^[0-9a-f]{64}$")
        self.assertRegex(panel.panel_sha256, r"^[0-9a-f]{64}$")

    def test_pnl_conversion_requires_and_binds_reference_capital(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "hash-bound"):
            SleeveInput(
                sleeve_id="no-capital",
                value_kind=ValueKind.PNL,
                observations=(DailyObservation("2026-07-20", 1000.0),),
            )

        capital = _capital()
        panel = build_return_panel(
            coverage_start="2026-07-20",
            coverage_end="2026-07-21",
            calendar_basis="WEEKDAY_252",
            sleeves=[
                SleeveInput(
                    sleeve_id="pnl",
                    value_kind=ValueKind.PNL,
                    observations=(DailyObservation("2026-07-20", 1000.0),),
                    reference_capital=capital,
                )
            ],
        )
        self.assertEqual(panel.sleeves[0].returns, (0.01, 0.0))
        encoded = panel.to_dict()["sleeves"][0]  # type: ignore[index]
        self.assertEqual(
            encoded["reference_capital"]["binding_sha256"],  # type: ignore[index]
            capital.binding_sha256,
        )

    def test_direct_returns_cannot_smuggle_a_capital_basis(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "must not carry"):
            SleeveInput(
                sleeve_id="direct",
                value_kind=ValueKind.RETURN,
                observations=(DailyObservation("2026-07-20", 0.01),),
                reference_capital=_capital(),
            )

    def test_duplicate_observation_day_fails_closed(self) -> None:
        sleeve = _return_sleeve(
            "duplicate",
            [("2026-07-20", 0.01), ("2026-07-20", 0.02)],
        )
        with self.assertRaisesRegex(EvidenceSeriesError, "duplicate day"):
            build_return_panel(
                coverage_start="2026-07-20",
                coverage_end="2026-07-24",
                calendar_basis="WEEKDAY_252",
                sleeves=[sleeve],
            )

    def test_duplicate_sleeve_id_fails_closed(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "duplicate sleeve_id"):
            build_return_panel(
                coverage_start="2026-07-20",
                coverage_end="2026-07-24",
                calendar_basis="WEEKDAY_252",
                sleeves=[_return_sleeve("same", []), _return_sleeve("same", [])],
            )

    def test_out_of_coverage_and_wrong_calendar_observations_fail(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "outside coverage"):
            build_return_panel(
                coverage_start="2026-07-20",
                coverage_end="2026-07-24",
                calendar_basis="WEEKDAY_252",
                sleeves=[_return_sleeve("late", [("2026-07-27", 0.01)])],
            )
        with self.assertRaisesRegex(EvidenceSeriesError, "outside the WEEKDAY_252 axis"):
            build_return_panel(
                coverage_start="2026-07-20",
                coverage_end="2026-07-26",
                calendar_basis="WEEKDAY_252",
                sleeves=[_return_sleeve("weekend", [("2026-07-25", 0.01)])],
            )

    def test_non_finite_observation_and_capital_fail_closed(self) -> None:
        for value in (math.nan, math.inf, -math.inf):
            with self.subTest(value=value):
                with self.assertRaisesRegex(EvidenceSeriesError, "finite"):
                    DailyObservation("2026-07-20", value)
        with self.assertRaisesRegex(EvidenceSeriesError, "finite"):
            _capital(math.nan)

    def test_reference_capital_requires_source_hash(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "lowercase SHA-256"):
            ReferenceCapital(
                amount=100_000,
                currency="USD",
                source_id="manifest",
                source_sha256="not-a-hash",
            )

    def test_sharpe_uses_full_series_and_correct_frequency(self) -> None:
        values = (0.01, 0.0, 0.0, -0.002, 0.0)
        weekday = annualized_sharpe(values, calendar_basis="WEEKDAY_252")
        all_days = annualized_sharpe(values, calendar_basis="ALL_DAYS_365")
        self.assertIsNotNone(weekday)
        self.assertIsNotNone(all_days)
        assert weekday is not None and all_days is not None
        self.assertAlmostEqual(all_days / weekday, math.sqrt(365 / 252), places=12)

        mean = sum(values) / len(values)
        sample_std = math.sqrt(
            sum((value - mean) ** 2 for value in values) / (len(values) - 1)
        )
        self.assertAlmostEqual(weekday, mean / sample_std * math.sqrt(252), places=12)

    def test_constant_or_short_series_has_no_invented_sharpe(self) -> None:
        self.assertIsNone(annualized_sharpe([0.0], calendar_basis="WEEKDAY_252"))
        self.assertIsNone(
            annualized_sharpe([0.01, 0.01], calendar_basis="WEEKDAY_252")
        )


class MovingBlockBootstrapTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel = build_return_panel(
            coverage_start="2026-07-20",
            coverage_end="2026-07-29",
            calendar_basis="WEEKDAY_252",
            sleeves=[
                _return_sleeve(
                    "A",
                    [
                        ("2026-07-20", 0.01),
                        ("2026-07-22", -0.02),
                        ("2026-07-27", 0.03),
                    ],
                ),
                _return_sleeve(
                    "B",
                    [
                        ("2026-07-20", 0.1),
                        ("2026-07-22", -0.2),
                        ("2026-07-27", 0.3),
                    ],
                ),
            ],
        )

    def test_bootstrap_is_deterministic_and_binds_parameters(self) -> None:
        first = moving_block_bootstrap(
            self.panel,
            seed=1729,
            block_length=3,
            replicate_count=4,
            sample_length=9,
        )
        second = moving_block_bootstrap(
            self.panel,
            seed=1729,
            block_length=3,
            replicate_count=4,
            sample_length=9,
        )
        self.assertEqual(first, second)
        payload = first.to_dict()
        self.assertEqual(payload["schema_version"], BLOCK_BOOTSTRAP_SCHEMA_VERSION)
        self.assertEqual(payload["method"], "MOVING_BLOCK")
        self.assertEqual(payload["source_axis_sha256"], self.panel.axis_sha256)
        self.assertEqual(payload["source_panel_sha256"], self.panel.panel_sha256)
        self.assertEqual(payload["source_axis_length"], len(self.panel.axis))
        self.assertEqual(payload["seed"], 1729)
        self.assertEqual(payload["block_length"], 3)

    def test_blocks_are_contiguous_and_applied_jointly_to_all_sleeves(self) -> None:
        result = moving_block_bootstrap(
            self.panel,
            seed=7,
            block_length=3,
            replicate_count=5,
            sample_length=8,
        )
        source = {sleeve.sleeve_id: sleeve.returns for sleeve in self.panel.sleeves}
        for path in result.paths:
            self.assertEqual(len(path.source_indices), 8)
            for block_start in range(0, 8, 3):
                block = path.source_indices[block_start : block_start + 3]
                self.assertEqual(
                    block,
                    tuple(range(block[0], block[0] + len(block))),
                )
            for sleeve in path.sleeves:
                self.assertEqual(
                    sleeve.returns,
                    tuple(source[sleeve.sleeve_id][i] for i in path.source_indices),
                )
            sampled = {sleeve.sleeve_id: sleeve.returns for sleeve in path.sleeves}
            self.assertEqual(
                sampled["B"],
                tuple(value * 10 for value in sampled["A"]),
            )

    def test_zero_days_are_not_filtered_before_sampling(self) -> None:
        result = moving_block_bootstrap(
            self.panel,
            seed=3,
            block_length=2,
            replicate_count=2,
        )
        self.assertEqual(result.sample_length, len(self.panel.axis))
        for path in result.paths:
            self.assertEqual(len(path.source_indices), len(self.panel.axis))
            sampled_a = path.sleeves[0].returns
            self.assertEqual(
                sampled_a,
                tuple(self.panel.sleeves[0].returns[i] for i in path.source_indices),
            )

    def test_iid_block_length_one_is_explicitly_rejected(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "IID"):
            moving_block_bootstrap(
                self.panel,
                seed=1,
                block_length=1,
                replicate_count=10,
            )

    def test_invalid_bootstrap_dimensions_fail_closed(self) -> None:
        with self.assertRaisesRegex(EvidenceSeriesError, "source axis"):
            moving_block_bootstrap(
                self.panel,
                seed=1,
                block_length=len(self.panel.axis) + 1,
                replicate_count=1,
            )
        with self.assertRaisesRegex(EvidenceSeriesError, "replicate_count"):
            moving_block_bootstrap(
                self.panel,
                seed=1,
                block_length=2,
                replicate_count=0,
            )
        with self.assertRaisesRegex(EvidenceSeriesError, "sample_length"):
            moving_block_bootstrap(
                self.panel,
                seed=1,
                block_length=2,
                replicate_count=1,
                sample_length=0,
            )

    def test_manually_misaligned_panel_is_rejected(self) -> None:
        bad_series = SleeveReturnSeries(
            sleeve_id="bad",
            source_value_kind=ValueKind.RETURN,
            reference_capital=None,
            observed_day_count=1,
            zero_filled_day_count=0,
            returns=(0.01,),
            sharpe_annualized=None,
        )
        with self.assertRaisesRegex(EvidenceSeriesError, "not aligned"):
            ReturnPanel(
                calendar_basis=self.panel.calendar_basis,
                coverage_start=self.panel.coverage_start,
                coverage_end=self.panel.coverage_end,
                axis=self.panel.axis,
                sleeves=(bad_series,),
            )


class EvidenceSchemaTests(unittest.TestCase):
    def test_schemas_are_parseable_strict_draft_2020_contracts(self) -> None:
        panel_schema = json.loads(
            (SCHEMA_DIR / "q08_evidence_return_panel_v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
        bootstrap_schema = json.loads(
            (SCHEMA_DIR / "q08_evidence_block_bootstrap_v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            panel_schema["properties"]["schema_version"]["const"],
            RETURN_PANEL_SCHEMA_VERSION,
        )
        self.assertFalse(panel_schema["additionalProperties"])
        self.assertEqual(
            bootstrap_schema["properties"]["schema_version"]["const"],
            BLOCK_BOOTSTRAP_SCHEMA_VERSION,
        )
        self.assertEqual(
            bootstrap_schema["properties"]["block_length"]["minimum"], 2
        )
        self.assertFalse(bootstrap_schema["additionalProperties"])

    def test_contract_payloads_are_strict_json_serializable(self) -> None:
        panel = build_return_panel(
            coverage_start="2026-07-20",
            coverage_end="2026-07-24",
            calendar_basis="WEEKDAY_252",
            sleeves=[_return_sleeve("A", [("2026-07-20", 0.01)])],
        )
        bootstrap = moving_block_bootstrap(
            panel,
            seed=42,
            block_length=2,
            replicate_count=2,
        )
        json.dumps(panel.to_dict(), allow_nan=False, sort_keys=True)
        json.dumps(bootstrap.to_dict(), allow_nan=False, sort_keys=True)


if __name__ == "__main__":
    unittest.main()
