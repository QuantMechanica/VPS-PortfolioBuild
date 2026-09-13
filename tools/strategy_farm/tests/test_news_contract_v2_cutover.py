"""Consumer cutover onto ``qm.news_impact_mapping.v1`` behind one Default-OFF flag.

Three consumers are covered, in both modes:

* ``framework/scripts/p8_news_driver.py`` - impact rank and calendar validation;
* ``tools/strategy_farm/news_calendar_gate.py`` - the preflight self-report;
* ``tools/strategy_farm/q09_news_runner.py`` - the Q10_NEWS run self-report.

Every fixture is synthetic.  Nothing here reads ``D:\\QM\\data\\news_calendar``,
opens the farm database, or touches the live path (DL-080).
"""

import json
import os
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO / "framework" / "scripts"))

import news_calendar_gate as gate  # noqa: E402
import news_impact_mapping as nim  # noqa: E402
import p8_news_driver as p8  # noqa: E402
import q09_news_runner as runner  # noqa: E402

FLAG = nim.FLAG_ENV
HEADER = "Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,Actual,Forecast,Previous\n"


def _row(dt_utc: str, currency: str, impact: str, event: str) -> str:
    date = dt_utc.split(" ")[0]
    return f"{date},{dt_utc},{dt_utc},{currency},{impact},{event},1.0,,\n"


def _write_authoritative(directory: Path, rows) -> Path:
    path = directory / "forex_factory_calendar_clean.csv"
    path.write_text(HEADER + "".join(rows), encoding="utf-8")
    return path


def _p8_rows(rows) -> Path:
    """P8 reads its own column spelling; write a calendar in that dialect."""

    return rows


def _write_p8_calendar(directory: Path, rows) -> Path:
    path = directory / "p8_calendar.csv"
    header = "timestamp_utc,currency,impact,event,actual,forecast,previous\n"
    path.write_text(header + "".join(rows), encoding="utf-8")
    return path


def _p8_row(ts: str, currency: str, impact: str, event: str) -> str:
    return f"{ts},{currency},{impact},{event},1.0,1.0,1.0\n"


class FlagTests(unittest.TestCase):
    def test_flag_is_default_off_and_exact(self):
        for value, expected in (
            (None, False), ("", False), ("0", False), ("true", False),
            ("yes", False), ("2", False), (" 1 ", True), ("1", True),
        ):
            env = {} if value is None else {FLAG: value}
            self.assertIs(nim.v2_enabled(env), expected, value)

    def test_gate_flag_name_mirrors_the_mapping_module(self):
        self.assertEqual(gate.NEWS_IMPACT_MAPPING_V2_FLAG, nim.FLAG_ENV)

    def test_real_environment_is_off_in_this_repo(self):
        # A cutover that silently switched itself on would make every
        # "byte-identical when off" assertion below vacuous.
        self.assertFalse(nim.v2_enabled())


class ContractDeclarationTests(unittest.TestCase):
    def test_declaration_needs_an_opting_in_consumer(self):
        with self.assertRaises(nim.OptInRequired):
            nim.contract_declaration(require_source=False)
        with self.assertRaises(nim.OptInRequired):
            nim.contract_declaration(consumer="x", opt_in=False, require_source=False)

    def test_declaration_carries_the_section_7_triple(self):
        declaration = nim.contract_declaration(
            consumer="unit-test", opt_in=True, require_source=False
        )
        self.assertEqual(declaration["mapping_version"], nim.SCHEMA_VERSION)
        self.assertEqual(declaration["dst_rule_version"], nim.DST_RULE_VERSION)
        self.assertEqual(
            declaration["authoritative_source"], "forex_factory_calendar_clean.csv"
        )
        self.assertEqual(len(declaration["mapping_content_sha256"]), 64)
        self.assertTrue(declaration["live_path_forbidden"])
        self.assertNotIn("source_path", declaration)

    def test_declaration_hashes_the_source_when_asked(self):
        with TemporaryDirectory() as tmp:
            path = _write_authoritative(
                Path(tmp), [_row("2024.03.08 13:30", "USD", "High", "NFP")]
            )
            declaration = nim.contract_declaration(
                path, consumer="unit-test", opt_in=True
            )
        self.assertEqual(declaration["source_path"], str(path))
        self.assertEqual(len(declaration["content_sha256"]), 64)

    def test_non_authoritative_source_is_refused(self):
        with TemporaryDirectory() as tmp:
            other = Path(tmp) / "news_calendar_2015_2025.csv"
            other.write_text(HEADER, encoding="utf-8")
            with self.assertRaises(nim.SourceNotAuthoritative):
                nim.contract_declaration(other, consumer="unit-test", opt_in=True)


class P8ResolverTests(unittest.TestCase):
    V1_ONLY = ["low", "medium", "high"]

    def test_flag_off_builds_the_frozen_v1_resolver(self):
        resolver = p8.build_impact_resolver({})
        self.assertIsInstance(resolver, p8.V1ImpactResolver)
        self.assertIsNone(resolver.declaration)
        self.assertEqual(p8.V1_IMPACT_RANK, {"low": 1, "medium": 2, "high": 3})
        for label in self.V1_ONLY:
            self.assertEqual(resolver.normalize(label.upper()), label)
        for unknown in ("red", "3", "holiday", "moderate", ""):
            self.assertIsNone(resolver.normalize(unknown))

    def test_flag_on_builds_the_v2_resolver(self):
        resolver = p8.build_impact_resolver({FLAG: "1"}, require_source=False)
        self.assertIsInstance(resolver, p8.V2ImpactResolver)
        self.assertEqual(resolver.mapping_version, nim.SCHEMA_VERSION)
        self.assertEqual(resolver.normalize("red"), "high")
        self.assertEqual(resolver.normalize("3"), "high")
        self.assertEqual(resolver.normalize("moderate"), "medium")
        self.assertEqual(resolver.normalize("Holiday"), "")  # known, non-gating
        self.assertEqual(resolver.rank("high"), 3)
        self.assertEqual(resolver.required_rank("high"), 3)
        self.assertEqual(resolver.required_rank("medium"), 2)

    def test_flag_on_still_fails_closed_on_an_undescribed_label(self):
        resolver = p8.build_impact_resolver({FLAG: "1"}, require_source=False)
        with self.assertRaises(nim.UnmappedImpactLabel):
            resolver.normalize("catastrophic")

    def test_v1_and_v2_rank_the_three_canonical_labels_identically(self):
        v1 = p8.V1ImpactResolver()
        v2 = p8.build_impact_resolver({FLAG: "1"}, require_source=False)
        for label in self.V1_ONLY:
            self.assertEqual(v1.rank(label), v2.rank(label), label)
            self.assertEqual(v1.required_rank(label), v2.required_rank(label), label)


class P8CalendarValidationTests(unittest.TestCase):
    ROWS = [
        _p8_row("2024-03-08T13:30:00", "USD", "high", "NFP"),
        _p8_row("2024-03-12T12:30:00", "USD", "medium", "CPI"),
        _p8_row("2024-03-13T09:00:00", "EUR", "low", "Trade Balance"),
    ]
    ALIAS_ROWS = ROWS + [
        _p8_row("2024-03-14T08:00:00", "GBP", "red", "BOE Rate"),
        _p8_row("2024-03-15T00:00:00", "JPY", "Holiday", "Bank Holiday"),
    ]

    def test_flag_off_output_is_unchanged(self):
        with TemporaryDirectory() as tmp:
            path = _write_p8_calendar(Path(tmp), self.ROWS)
            events, stats = p8.validate_calendar(path)
        self.assertEqual(len(events), 3)
        self.assertEqual(
            set(stats), {"rows", "usable_events", "duplicate_event_rows"}
        )
        self.assertEqual(stats["usable_events"], 3)

    def test_flag_off_rejects_an_alias_the_v1_dict_cannot_read(self):
        with TemporaryDirectory() as tmp:
            path = _write_p8_calendar(Path(tmp), self.ALIAS_ROWS)
            with self.assertRaises(ValueError) as caught:
                p8.validate_calendar(path)
        self.assertIn("invalid impact level", str(caught.exception))

    def test_flag_on_maps_aliases_and_drops_the_non_gating_label(self):
        resolver = p8.build_impact_resolver({FLAG: "1"}, require_source=False)
        with TemporaryDirectory() as tmp:
            path = _write_p8_calendar(Path(tmp), self.ALIAS_ROWS)
            events, stats = p8.validate_calendar(path, resolver)
        self.assertEqual([event.impact for event in events],
                         ["high", "medium", "low", "high"])
        self.assertEqual(stats["usable_events"], 4)
        self.assertEqual(stats["non_gating_event_rows"], 1)
        self.assertEqual(
            stats["news_contract_selfreport"]["mapping_version"], nim.SCHEMA_VERSION
        )
        self.assertEqual(
            stats["news_contract_selfreport"]["dst_rule_version"], nim.DST_RULE_VERSION
        )
        self.assertEqual(
            stats["news_contract_selfreport"]["authoritative_source"],
            "forex_factory_calendar_clean.csv",
        )

    def test_gating_decisions_are_identical_for_canonical_labels(self):
        from datetime import datetime, timezone

        trade = p8.Trade(
            symbol="EURUSD",
            entry_time_utc=datetime(2024, 3, 8, 13, 35, tzinfo=timezone.utc),
            exit_time_utc=None, side="buy", profit=1.0, volume=0.1,
            source_report="fixture",
        )
        with TemporaryDirectory() as tmp:
            path = _write_p8_calendar(Path(tmp), self.ROWS)
            v1_events, _ = p8.validate_calendar(path)
            resolver = p8.build_impact_resolver({FLAG: "1"}, require_source=False)
            v2_events, _ = p8.validate_calendar(path, resolver)
        for mode in ("PAUSE", "SKIP_DAY", "FTMO_PAUSE", "no_news", "news_only"):
            self.assertEqual(
                p8.trade_allowed(trade, v1_events, mode, 30, 30, "high"),
                p8.trade_allowed(trade, v2_events, mode, 30, 30, "high", resolver),
                mode,
            )


class V1V2ParityTests(unittest.TestCase):
    """The contract's measurable disagreement class, on a small fixture.

    Contract section 3 names a 41.7% impact-classification disagreement between
    the two shipped calendar files.  Under V2 exactly one file is consumed, so
    the disagreement does not vanish - it becomes *measurable and declared*
    instead of silent.  These tests measure it both ways.
    """

    #: (event, authoritative Impact, audit-trail Impact)
    COMMON_EVENTS = [
        ("NFP", "High", "High"),
        ("CPI", "High", "Medium"),
        ("Retail Sales", "Medium", "Medium"),
        ("Trade Balance", "Medium", "Low"),
        ("PPI", "Low", "Low"),
        ("Unemployment Claims", "High", "High"),
        ("ISM", "Medium", "High"),
        ("Housing Starts", "Low", "Low"),
        ("Consumer Confidence", "Medium", "Medium"),
        ("GDP", "High", "Medium"),
        ("Speech", "Low", "Low"),
        ("Bank Holiday", "Holiday", "Low"),
    ]

    def test_cross_source_disagreement_is_measured_and_resolved_to_one_source(self):
        rules = nim.load_rules()
        authoritative, audit = [], []
        for index, (event, impact_a, impact_b) in enumerate(self.COMMON_EVENTS):
            stamp = f"2024.05.{index + 1:02d} 12:30"
            authoritative.append(_row(stamp, "USD", impact_a, event))
            audit.append(_row(stamp, "USD", impact_b, event))
        with TemporaryDirectory() as tmp:
            path_a = _write_authoritative(Path(tmp), authoritative)
            path_b = Path(tmp) / "news_calendar_2015_2025.csv"
            path_b.write_text(HEADER + "".join(audit), encoding="utf-8")
            mapped_a = nim.map_rows(
                nim.read_calendar(path_a), consumer="parity", opt_in=True, rules=rules
            )
            mapped_b = nim.map_rows(
                nim.read_calendar(path_b), consumer="parity", opt_in=True, rules=rules
            )
            # section 3: only the authoritative file may be resolved for gating.
            self.assertEqual(nim.resolve_source(path_a, rules=rules).name,
                             rules["authoritative_source"])
            with self.assertRaises(nim.SourceNotAuthoritative):
                nim.resolve_source(path_b, rules=rules)

        by_event_a = {event.event: event.impact_label for event in mapped_a}
        by_event_b = {event.event: event.impact_label for event in mapped_b}
        common = sorted(set(by_event_a) & set(by_event_b))
        self.assertEqual(len(common), len(self.COMMON_EVENTS))
        disagreements = [key for key in common if by_event_a[key] != by_event_b[key]]
        rate = len(disagreements) / len(common)
        # The fixture is built to sit in the contract's observed neighbourhood.
        self.assertAlmostEqual(rate, 5 / 12, places=6)
        self.assertGreater(rate, 0.40)
        self.assertLess(rate, 0.45)
        # The consumed classification is single-valued: the authoritative file
        # alone decides, so the *consumed* disagreement rate is 0%.
        consumed = {key: by_event_a[key] for key in common}
        self.assertEqual(len(set(consumed) ^ set(by_event_a)), 0)
        for key in common:
            self.assertEqual(consumed[key], by_event_a[key])

    def test_v1_and_v2_label_disagreement_on_one_fixture_is_enumerable(self):
        v1 = p8.V1ImpactResolver()
        v2 = p8.build_impact_resolver({FLAG: "1"}, require_source=False)
        labels = ["high", "Medium", "LOW", "red", "3", "moderate", "hoch",
                  "Holiday", "none", "yellow"]
        differ = []
        for raw in labels:
            first = v1.normalize(raw)
            second = v2.normalize(raw)
            if first != second:
                differ.append((raw, first, second))
        # V1 reads exactly three spellings; every alias is a V1 hard error and
        # a V2 classification.  That gap is the cutover's whole point.
        self.assertEqual([item[0] for item in differ],
                         ["red", "3", "moderate", "hoch", "Holiday", "none", "yellow"])
        self.assertTrue(all(item[1] is None for item in differ))
        self.assertEqual(len(differ) / len(labels), 0.7)


class NewsCalendarGateCutoverTests(unittest.TestCase):
    def _preflight(self, tmp: Path):
        source = tmp / "source"
        common = tmp / "common"
        source.mkdir()
        common.mkdir()
        for directory in (source, common):
            (directory / "news_calendar_2015_2025.csv").write_text(
                "datetime,currency,event_name,impact\n"
                "2024-03-08 13:30:00,USD,NFP,high\n",
                encoding="utf-8",
            )
            (directory / "forex_factory_calendar_clean.csv").write_text(
                HEADER + _row("2024.03.08 13:30", "USD", "High", "NFP"),
                encoding="utf-8",
            )
        return source, common

    def test_flag_off_payload_is_byte_identical(self):
        with TemporaryDirectory() as tmp:
            source, common = self._preflight(Path(tmp))
            gate.clear_preflight_cache()
            result = gate.preflight_news_calendar(source, common, use_cache=False)
            self.assertIsNone(result.news_contract_selfreport)
            self.assertNotIn("news_contract_selfreport", result.as_dict())
            self.assertEqual(result.status, gate.STATUS_OK)

    def test_flag_on_attaches_the_section_7_declaration(self):
        with TemporaryDirectory() as tmp:
            source, common = self._preflight(Path(tmp))
            gate.clear_preflight_cache()
            with mock.patch.dict(os.environ, {FLAG: "1"}):
                result = gate.preflight_news_calendar(source, common, use_cache=False)
        self.assertEqual(result.status, gate.STATUS_OK)
        declaration = result.as_dict()["news_contract_selfreport"]
        self.assertEqual(declaration["mapping_version"], nim.SCHEMA_VERSION)
        self.assertEqual(declaration["dst_rule_version"], nim.DST_RULE_VERSION)
        self.assertEqual(
            declaration["authoritative_source"], "forex_factory_calendar_clean.csv"
        )
        self.assertEqual(declaration["consumer"], "news_calendar_gate")
        self.assertTrue(json.dumps(result.as_dict()))

    def test_flag_on_fails_closed_when_the_authoritative_source_is_absent(self):
        with TemporaryDirectory() as tmp:
            source, common = self._preflight(Path(tmp))
            gate.clear_preflight_cache()
            result_off = gate.preflight_news_calendar(source, common, use_cache=False)
            self.assertEqual(result_off.status, gate.STATUS_OK)
            with mock.patch.dict(os.environ, {FLAG: "1"}), mock.patch.object(
                gate, "build_news_contract_declaration",
                side_effect=RuntimeError("source missing"),
            ):
                result = gate.preflight_news_calendar(source, common, use_cache=False)
        self.assertEqual(result.status, gate.STATUS_PARSE_INVALID)
        self.assertIn("news contract v2 declaration failed", result.detail)
        self.assertIsNone(result.news_contract_selfreport)


class RunnerSelfReportTests(unittest.TestCase):
    def test_flag_off_keeps_the_pre_v2_marker(self):
        self.assertIsNone(runner._news_contract_v2_declaration())

    def test_flag_on_declares_the_section_7_triple(self):
        with mock.patch.dict(os.environ, {FLAG: "1"}):
            declaration = runner._news_contract_v2_declaration()
        self.assertIsNotNone(declaration)
        self.assertEqual(declaration["mapping_version"], nim.SCHEMA_VERSION)
        self.assertEqual(declaration["dst_rule_version"], nim.DST_RULE_VERSION)
        self.assertEqual(declaration["consumer"], "q09_news_runner")

    def test_flag_on_failure_is_fatal_not_a_silent_pre_v2_downgrade(self):
        with mock.patch.dict(os.environ, {FLAG: "1"}), mock.patch.object(
            nim, "contract_declaration", side_effect=RuntimeError("rules gone")
        ):
            with self.assertRaises(runner.RunnerError):
                runner._news_contract_v2_declaration()


if __name__ == "__main__":
    unittest.main()
