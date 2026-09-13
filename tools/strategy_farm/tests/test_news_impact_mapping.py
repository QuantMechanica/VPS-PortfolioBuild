"""Tests for qm.news_impact_mapping.v1 (contract sections 3/4/7/8)."""

import copy
import json
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from tempfile import TemporaryDirectory

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import news_impact_mapping as nim  # noqa: E402


HEADER = "Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,Actual,Forecast,Previous\n"


def _row(dt_utc: str, currency: str, impact: str, event: str, actual: str = "1.0") -> str:
    date = dt_utc.split(" ")[0]
    return f"{date},{dt_utc},{dt_utc},{currency},{impact},{event},{actual},,\n"


def _write_calendar(directory: Path, rows, name: str | None = None) -> Path:
    name = name or "forex_factory_calendar_clean.csv"
    path = directory / name
    path.write_text(HEADER + "".join(rows), encoding="utf-8")
    return path


class RulesArtifactTests(unittest.TestCase):
    def test_shipped_rules_load_and_encode_the_owner_decision(self):
        rules = nim.load_rules()
        self.assertEqual(rules["schema_version"], nim.SCHEMA_VERSION)
        self.assertEqual(rules["authoritative_source"], "forex_factory_calendar_clean.csv")
        self.assertEqual(rules["owner_decision"], "OWNER-DEC-NEWS-MAPPING")
        self.assertIn("news_calendar_2015_2025.csv", rules["audit_trail_sources"])
        self.assertFalse(rules["default_enabled"])
        self.assertTrue(rules["live_path_forbidden"])

    def test_missing_required_key_is_refused(self):
        rules = nim.load_rules()
        del rules["labels"]
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "rules.json"
            path.write_text(json.dumps(rules), encoding="utf-8")
            with self.assertRaises(nim.MappingError):
                nim.load_rules(path)

    def test_alias_claimed_by_two_labels_is_refused(self):
        rules = nim.load_rules()
        rules["labels"]["low"]["aliases"].append("high")
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "rules.json"
            path.write_text(json.dumps(rules), encoding="utf-8")
            with self.assertRaises(nim.MappingError):
                nim.load_rules(path)


class HashStabilityTests(unittest.TestCase):
    def test_hash_is_stable_across_calls_and_dict_order(self):
        rules = nim.load_rules()
        shuffled = dict(reversed(list(rules.items())))
        self.assertEqual(nim.mapping_version_hash(rules), nim.mapping_version_hash(rules))
        self.assertEqual(nim.mapping_version_hash(rules), nim.mapping_version_hash(shuffled))

    def test_hash_moves_when_a_rank_changes(self):
        rules = nim.load_rules()
        edited = copy.deepcopy(rules)
        edited["labels"]["medium"]["rank"] = 9
        self.assertNotEqual(nim.mapping_version_hash(rules), nim.mapping_version_hash(edited))

    def test_fingerprint_carries_rules_code_and_dst_versions(self):
        fingerprint = nim.mapping_fingerprint()
        self.assertEqual(fingerprint["mapping_version"], "qm.news_impact_mapping.v1")
        self.assertEqual(fingerprint["dst_rule_version"], "qm.dst_rule.us.v1")
        self.assertEqual(len(fingerprint["content_sha256"]), 64)
        self.assertNotEqual(fingerprint["rules_sha256"], fingerprint["code_sha256"])


class OptInTests(unittest.TestCase):
    def test_mapping_is_default_off(self):
        self.assertFalse(nim.DEFAULT_ENABLED)
        with self.assertRaises(nim.OptInRequired):
            nim.map_rows([], consumer="test")

    def test_opt_in_without_a_named_consumer_is_refused(self):
        with self.assertRaises(nim.OptInRequired):
            nim.map_rows([], opt_in=True, consumer="  ")

    def test_classification_and_hashing_need_no_opt_in(self):
        self.assertEqual(nim.classify("High").rank, 3)
        self.assertEqual(len(nim.mapping_version_hash()), 64)


class ClassificationTests(unittest.TestCase):
    def test_canonical_labels_and_ranks(self):
        self.assertEqual(nim.classify("High"), nim.ImpactClass("high", 3, True))
        self.assertEqual(nim.classify("medium"), nim.ImpactClass("medium", 2, True))
        self.assertEqual(nim.classify(" LOW "), nim.ImpactClass("low", 1, True))

    def test_holiday_is_ranked_but_not_gating(self):
        holiday = nim.classify("Holiday")
        self.assertEqual(holiday.rank, 0)
        self.assertFalse(holiday.gating)

    def test_unknown_label_fails_closed(self):
        with self.assertRaises(nim.UnmappedImpactLabel):
            nim.classify("catastrophic")
        with self.assertRaises(nim.UnmappedImpactLabel):
            nim.classify("")


class SingleSourceTests(unittest.TestCase):
    def test_non_authoritative_source_is_refused(self):
        with TemporaryDirectory() as tmp:
            path = _write_calendar(
                Path(tmp), [_row("2020.06.01 12:00", "USD", "High", "NFP")],
                name="news_calendar_2015_2025.csv",
            )
            with self.assertRaises(nim.SourceNotAuthoritative):
                nim.resolve_source(path)

    def test_audit_source_is_usable_only_with_an_explicit_override(self):
        with TemporaryDirectory() as tmp:
            path = _write_calendar(
                Path(tmp), [_row("2020.06.01 12:00", "USD", "High", "NFP")],
                name="news_calendar_2015_2025.csv",
            )
            self.assertEqual(
                nim.resolve_source(path, allow_non_authoritative=True).name,
                "news_calendar_2015_2025.csv",
            )

    def test_missing_source_fails_closed(self):
        with TemporaryDirectory() as tmp:
            with self.assertRaises(nim.MappingError):
                nim.resolve_source(Path(tmp) / "forex_factory_calendar_clean.csv")


class DeterminismTests(unittest.TestCase):
    def test_output_order_is_independent_of_input_order(self):
        rows = [
            {"DateTime_UTC": "2020.06.03 12:00", "Currency": "USD", "Impact": "High", "Event": "B"},
            {"DateTime_UTC": "2020.06.01 12:00", "Currency": "EUR", "Impact": "Low", "Event": "A"},
            {"DateTime_UTC": "2020.06.02 12:00", "Currency": "GBP", "Impact": "Medium", "Event": "C"},
        ]
        forward = nim.map_rows(rows, consumer="test", opt_in=True)
        backward = nim.map_rows(list(reversed(rows)), consumer="test", opt_in=True)
        self.assertEqual([e.as_dict() for e in forward], [e.as_dict() for e in backward])
        self.assertEqual([e.event for e in forward], ["A", "C", "B"])

    def test_schedule_view_never_exposes_lookahead_fields(self):
        rows = [{
            "DateTime_UTC": "2020.06.01 12:00", "Currency": "USD", "Impact": "High",
            "Event": "NFP", "Actual": "1", "Forecast": "2", "Previous": "3",
        }]
        view = nim.schedule_view(nim.map_rows(rows, consumer="test", opt_in=True))
        self.assertEqual(set(view[0]), {"timestamp_utc", "currency", "impact", "impact_rank", "event_id"})


class DuplicateTests(unittest.TestCase):
    """Contract section 8 - duplicates must never silently double-count."""

    def test_identical_impact_duplicates_collapse_visibly(self):
        rows = [
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD", "Impact": "Low",
             "Event": "Personal Income m/m", "Actual": "-0.1"},
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD", "Impact": "Low",
             "Event": "Personal Income m/m", "Actual": "1.0"},
        ]
        events = nim.map_rows(rows, consumer="test", opt_in=True)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].occurrences, 2)

    @staticmethod
    def _reject_rules():
        rules = nim.load_rules()
        rules["duplicate_policy"] = nim.DUPLICATE_POLICY_REJECT
        return rules

    def test_conflicting_impact_duplicates_raise_under_the_reject_policy(self):
        rows = [
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD", "Impact": "Low", "Event": "X"},
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD", "Impact": "High", "Event": "X"},
        ]
        with self.assertRaises(nim.DuplicateEventConflict):
            nim.map_rows(rows, consumer="test", opt_in=True, rules=self._reject_rules())

    def test_shipped_policy_is_highest_rank_wins(self):
        rules = nim.load_rules()
        self.assertEqual(rules["duplicate_policy"], nim.DUPLICATE_POLICY_MAX_RANK)
        rule = rules["duplicate_conflict_rule"]
        self.assertEqual(
            rule["rule_id"], "qm.news_impact_mapping.duplicate_conflict.max_rank.v1"
        )
        self.assertTrue(rule["gate_semantics_unchanged"])
        self.assertEqual(
            set(rule["supported_policies"]), set(nim.SUPPORTED_DUPLICATE_POLICIES)
        )

    def test_unsupported_duplicate_policy_is_refused(self):
        rules = nim.load_rules()
        rules["duplicate_policy"] = "last_row_wins"
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "rules.json"
            path.write_text(json.dumps(rules), encoding="utf-8")
            with self.assertRaises(nim.MappingError):
                nim.load_rules(path)

    def test_conflicting_impact_escalates_to_the_higher_rank(self):
        for order in (("Low", "High"), ("High", "Low")):
            with self.subTest(order=order):
                rows = [
                    {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD",
                     "Impact": order[0], "Event": "X"},
                    {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD",
                     "Impact": order[1], "Event": "X"},
                ]
                events = nim.map_rows(rows, consumer="test", opt_in=True)
                self.assertEqual(len(events), 1)
                self.assertEqual(events[0].impact_label, "high")
                self.assertEqual(events[0].impact_rank, 3)
                self.assertTrue(events[0].gating)
                self.assertEqual(events[0].occurrences, 2)
                self.assertTrue(events[0].impact_conflict_resolved)
                self.assertEqual(events[0].superseded_impact_labels, ("low",))

    def test_escalation_never_downgrades_a_gating_row_to_holiday(self):
        rows = [
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD",
             "Impact": "Holiday", "Event": "X"},
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD",
             "Impact": "Medium", "Event": "X"},
        ]
        events = nim.map_rows(rows, consumer="test", opt_in=True)
        self.assertEqual(events[0].impact_label, "medium")
        self.assertTrue(events[0].gating)

    def test_three_way_conflict_keeps_every_superseded_label(self):
        rows = [
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD",
             "Impact": impact, "Event": "X"}
            for impact in ("Low", "Medium", "High")
        ]
        events = nim.map_rows(rows, consumer="test", opt_in=True)
        self.assertEqual(events[0].impact_label, "high")
        self.assertEqual(events[0].occurrences, 3)
        self.assertEqual(events[0].superseded_impact_labels, ("low", "medium"))

    def test_equal_rank_conflict_still_raises(self):
        rules = nim.load_rules()
        rules["labels"]["medium"]["rank"] = rules["labels"]["high"]["rank"]
        rows = [
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD",
             "Impact": "Medium", "Event": "X"},
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD",
             "Impact": "High", "Event": "X"},
        ]
        with self.assertRaises(nim.DuplicateEventConflict):
            nim.map_rows(rows, consumer="test", opt_in=True, rules=rules)

    def test_boe_bailey_2021_06_30_resolves_to_high(self):
        """The one conflicting identity in the canonical file (2026-09-13)."""
        rows = [
            {"DateTime_UTC": "2021.06.30 19:30", "Currency": "GBP",
             "Impact": "Medium", "Event": "BOE Gov Bailey Speaks"},
            {"DateTime_UTC": "2021.06.30 19:30", "Currency": "GBP",
             "Impact": "High", "Event": "BOE Gov Bailey Speaks"},
        ]
        events = nim.map_rows(rows, consumer="test", opt_in=True)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].impact_label, "high")
        self.assertEqual(events[0].superseded_impact_labels, ("medium",))
        known = nim.load_rules()["duplicate_conflict_rule"][
            "known_conflicts_at_decision_time"
        ]
        self.assertEqual(
            [
                (k["timestamp_utc"], k["currency"], k["event"], k["resolved_to"])
                for k in known
            ],
            [("2021-06-30T19:30:00Z", "GBP", "BOE Gov Bailey Speaks", "high")],
        )

    def test_self_report_records_the_resolved_conflict(self):
        rows = [
            _row("2021.06.30 19:30", "GBP", "Medium", "BOE Gov Bailey Speaks"),
            _row("2021.06.30 19:30", "GBP", "High", "BOE Gov Bailey Speaks"),
        ]
        with TemporaryDirectory() as tmp:
            path = _write_calendar(Path(tmp), rows)
            report = nim.run_self_report(path, consumer="test", opt_in=True)
        self.assertEqual(report["duplicate_conflicts_resolved"], 1)
        self.assertEqual(
            report["duplicate_conflict_rule_id"],
            "qm.news_impact_mapping.duplicate_conflict.max_rank.v1",
        )
        self.assertEqual(report["duplicate_conflicts"][0]["resolved_to"], "high")
        self.assertEqual(
            report["duplicate_conflicts"][0]["superseded_impact_labels"], ["medium"]
        )
        self.assertEqual(report["impact_counts"]["high"], 2)
        self.assertEqual(report["impact_counts"]["medium"], 0)

    @unittest.skipUnless(
        (nim.DEFAULT_CALENDAR_DIR / "forex_factory_calendar_clean.csv").is_file(),
        "canonical calendar not present on this host",
    )
    def test_canonical_source_is_no_longer_refused(self):
        report = nim.run_self_report(consumer="unit_test", opt_in=True)
        self.assertEqual(
            report["authoritative_source"], "forex_factory_calendar_clean.csv"
        )
        self.assertGreater(report["row_count"], 0)
        for entry in report["duplicate_conflicts"]:
            self.assertTrue(entry["superseded_impact_labels"])

    def test_same_event_different_currency_is_not_a_duplicate(self):
        rows = [
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "USD", "Impact": "Low", "Event": "CPI"},
            {"DateTime_UTC": "2019.02.28 20:30", "Currency": "EUR", "Impact": "Low", "Event": "CPI"},
        ]
        self.assertEqual(len(nim.map_rows(rows, consumer="test", opt_in=True)), 2)


class DstRuleTests(unittest.TestCase):
    """Contract section 8 - boundaries computed from the nth-weekday rule."""

    YEARS = (2023, 2024, 2025, 2026)  # spans a leap year and non-leap years

    def test_start_is_second_sunday_of_march_at_0700_utc(self):
        for year in self.YEARS:
            start = nim.us_dst_start_utc(year)
            self.assertEqual((start.month, start.hour, start.minute), (3, 7, 0))
            self.assertEqual(start.weekday(), 6)  # Sunday
            self.assertTrue(8 <= start.day <= 14)

    def test_end_is_first_sunday_of_november_at_0600_utc(self):
        for year in self.YEARS:
            end = nim.us_dst_end_utc(year)
            self.assertEqual((end.month, end.hour, end.minute), (11, 6, 0))
            self.assertEqual(end.weekday(), 6)
            self.assertTrue(1 <= end.day <= 7)

    def test_no_off_by_one_at_either_boundary(self):
        minute = timedelta(minutes=1)
        for year in self.YEARS:
            start = nim.us_dst_start_utc(year)
            end = nim.us_dst_end_utc(year)
            self.assertFalse(nim.is_us_dst_utc(start - minute))
            self.assertTrue(nim.is_us_dst_utc(start))
            self.assertTrue(nim.is_us_dst_utc(end - minute))
            self.assertFalse(nim.is_us_dst_utc(end))
            self.assertEqual(nim.broker_offset_hours(start - minute), 2)
            self.assertEqual(nim.broker_offset_hours(start), 3)
            self.assertEqual(nim.broker_offset_hours(end - minute), 3)
            self.assertEqual(nim.broker_offset_hours(end), 2)

    def test_dense_sweep_matches_the_interval_definition(self):
        for year in self.YEARS:
            start = nim.us_dst_start_utc(year)
            end = nim.us_dst_end_utc(year)
            for anchor in (start, end):
                moment = anchor - timedelta(days=3)
                stop = anchor + timedelta(days=3)
                while moment <= stop:
                    self.assertEqual(nim.is_us_dst_utc(moment), start <= moment < end)
                    self.assertEqual(
                        nim.utc_to_broker(moment) - moment,
                        timedelta(hours=3 if start <= moment < end else 2),
                    )
                    moment += timedelta(minutes=17)

    def test_november_fallback_ambiguity_prefers_standard_time(self):
        for year in self.YEARS:
            end = nim.us_dst_end_utc(year)
            ambiguous_broker = (end + timedelta(hours=2)).replace(tzinfo=None)
            resolved = nim.broker_to_utc(ambiguous_broker)
            self.assertFalse(nim.is_us_dst_utc(resolved))
            self.assertEqual(resolved, end.replace(tzinfo=timezone.utc))

    def test_mapped_row_carries_the_broker_projection(self):
        summer = [{"DateTime_UTC": "2024.07.01 12:00", "Currency": "USD",
                   "Impact": "High", "Event": "NFP"}]
        winter = [{"DateTime_UTC": "2024.12.02 12:00", "Currency": "USD",
                   "Impact": "High", "Event": "NFP"}]
        self.assertEqual(
            nim.map_rows(summer, consumer="test", opt_in=True)[0].broker_offset_hours, 3
        )
        self.assertEqual(
            nim.map_rows(winter, consumer="test", opt_in=True)[0].broker_offset_hours, 2
        )


class SelfReportTests(unittest.TestCase):
    """Contract section 7 - one consolidated object, not scattered fields."""

    REQUIRED = (
        "schema_version", "mapping_version", "dst_rule_version", "authoritative_source",
        "source_path", "content_sha256", "row_count", "max_event_date_utc",
        "generated_at_utc",
    )

    def _report(self, tmp: str):
        path = _write_calendar(Path(tmp), [
            _row("2020.03.10 12:00", "USD", "High", "NFP"),
            _row("2020.12.02 12:00", "EUR", "Medium", "CPI"),
            _row("2020.12.25 00:00", "GBP", "Holiday", "Christmas"),
            _row("2020.12.02 12:00", "EUR", "Medium", "CPI", actual="9.9"),
        ])
        return nim.run_self_report(
            path, consumer="unit_test", opt_in=True, generated_at_utc="2026-09-13T00:00:00Z"
        )

    def test_report_carries_every_required_section_7_field(self):
        with TemporaryDirectory() as tmp:
            report = self._report(tmp)
        for field in self.REQUIRED:
            self.assertIn(field, report)
            self.assertIsNotNone(report[field])
        self.assertEqual(report["mapping_version"], "qm.news_impact_mapping.v1")
        self.assertEqual(report["dst_rule_version"], "qm.dst_rule.us.v1")
        self.assertEqual(report["authoritative_source"], "forex_factory_calendar_clean.csv")
        self.assertEqual(report["authoritative_source_decision"], "OWNER-DEC-NEWS-MAPPING")
        self.assertTrue(report["live_path_forbidden"])

    def test_counts_duplicates_and_gating_rows(self):
        with TemporaryDirectory() as tmp:
            report = self._report(tmp)
        self.assertEqual(report["row_count"], 4)
        self.assertEqual(report["distinct_event_count"], 3)
        self.assertEqual(report["duplicate_groups"], 1)
        self.assertEqual(report["duplicate_collapsed_rows"], 1)
        self.assertEqual(report["impact_counts"], {"high": 1, "holiday": 1, "low": 0, "medium": 2})
        self.assertEqual(report["gating_row_count"], 3)
        self.assertEqual(report["max_event_date_utc"], "2020-12-25T00:00:00Z")

    def test_report_is_byte_reproducible(self):
        with TemporaryDirectory() as tmp:
            first = self._report(tmp)
            second = self._report(tmp)
        self.assertEqual(first["selfreport_sha256"], second["selfreport_sha256"])

    def test_report_needs_opt_in(self):
        with TemporaryDirectory() as tmp:
            path = _write_calendar(Path(tmp), [_row("2020.06.01 12:00", "USD", "High", "NFP")])
            with self.assertRaises(nim.OptInRequired):
                nim.run_self_report(path, consumer="unit_test")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
