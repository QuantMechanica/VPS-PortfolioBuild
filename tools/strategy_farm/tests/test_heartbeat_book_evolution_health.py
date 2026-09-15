"""Heartbeat renders the Continuous Book Evolution health keys (D1 review follow-up).

OWNER-DEC-CBE-20260915. The 15-minute heartbeat must surface the four
``book_evolution_health`` keys in the vault Heartbeat page so book-evolution
readiness is visible at a glance; a missing read-model degrades to EVIDENCE_MISSING
without crashing the heartbeat.
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from tools.strategy_farm import heartbeat_snapshot as hb


class BookEvolutionHealthProbeTests(unittest.TestCase):
    def test_probe_reads_four_keys_and_renders(self) -> None:
        with TemporaryDirectory() as td:
            health = Path(td) / "book_evolution_health.json"
            health.write_text(json.dumps({
                "schema": "qm.book-evolution-health/v1",
                "generated_at_utc": "2026-09-15T14:45:48+00:00",
                "book_evolution_readmodels": "GREEN",
                "ftmo_readiness_recommendation": "NOT_READY",
                "research_state_freshness": "FRESH",
                "factory_bottleneck_top": "unwinnable_reservation_head_of_line_block",
            }), encoding="utf-8")
            out: dict = {"ts": "2026-09-15T15:00:00+00:00", "flags": []}
            with mock.patch.object(hb, "BOOK_EVOLUTION_HEALTH", health):
                hb.probe_book_evolution_health(out)
            beh = out["book_evolution_health"]
            self.assertEqual(beh["book_evolution_readmodels"], "GREEN")
            self.assertEqual(beh["ftmo_readiness_recommendation"], "NOT_READY")
            self.assertEqual(beh["research_state_freshness"], "FRESH")
            self.assertEqual(beh["factory_bottleneck_top"], "unwinnable_reservation_head_of_line_block")
            # No RED / STALE -> no flag raised.
            self.assertNotIn("BOOK_EVOLUTION_READMODELS_RED", out["flags"])
            md = hb.render_markdown(out)
            self.assertIn("## Buchentwicklungs-Gesundheit", md)
            self.assertIn("NOT_READY", md)
            self.assertIn("unwinnable_reservation_head_of_line_block", md)

    def test_missing_read_model_is_evidence_missing_no_crash(self) -> None:
        with TemporaryDirectory() as td:
            absent = Path(td) / "does_not_exist.json"
            out: dict = {"ts": "2026-09-15T15:00:00+00:00", "flags": []}
            with mock.patch.object(hb, "BOOK_EVOLUTION_HEALTH", absent):
                hb.probe_book_evolution_health(out)
            self.assertEqual(out["book_evolution_health"]["status"], "EVIDENCE_MISSING")
            md = hb.render_markdown(out)
            self.assertIn("EVIDENCE_MISSING", md)

    def test_red_and_stale_raise_flags(self) -> None:
        with TemporaryDirectory() as td:
            health = Path(td) / "book_evolution_health.json"
            health.write_text(json.dumps({
                "book_evolution_readmodels": "RED",
                "ftmo_readiness_recommendation": "NOT_READY",
                "research_state_freshness": "STALE",
                "factory_bottleneck_top": "none",
            }), encoding="utf-8")
            out: dict = {"ts": "t", "flags": []}
            with mock.patch.object(hb, "BOOK_EVOLUTION_HEALTH", health):
                hb.probe_book_evolution_health(out)
            self.assertIn("BOOK_EVOLUTION_READMODELS_RED", out["flags"])
            self.assertIn("RESEARCH_STATE_STALE", out["flags"])


if __name__ == "__main__":
    unittest.main()
