from __future__ import annotations

import csv
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from framework.scripts import research_dedup_check


class ResearchDedupCheckTests(unittest.TestCase):
    @staticmethod
    def _registry(path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=["ea_id", "slug", "strategy_id", "status", "owner"],
                lineterminator="\n",
            )
            writer.writeheader()
            writer.writerow(
                {
                    "ea_id": "1",
                    "slug": "existing-alpha",
                    "strategy_id": "EXISTING_S01",
                    "status": "active",
                    "owner": "test",
                }
            )

    @staticmethod
    def _card(path: Path, slug: str, strategy_id: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            f"---\nslug: {slug}\nstrategy_id: {strategy_id}\nauthor: Test\n"
            "mechanic: distinct-mechanic\n---\n",
            encoding="utf-8",
        )

    def _run_fixture_check(
        self,
        root: Path,
        *,
        cards_mode: str,
        vault_mode: str,
    ) -> tuple[int, dict, str]:
        registry = root / "ea_id_registry.csv"
        cards = root / "cards"
        vault = root / "vault"
        output = root / "evidence.json"
        self._registry(registry)
        cards.mkdir(parents=True, exist_ok=True)
        if cards_mode == "valid":
            self._card(cards / "existing-card.md", "card-alpha", "CARD_S01")
        elif cards_mode == "encoding_error":
            (cards / "broken.md").write_bytes(b"---\nslug: bad\n---\n\xff")
        if vault_mode == "valid":
            self._card(vault / "strategies" / "wiki-card.md", "wiki-alpha", "WIKI_S01")

        argv = [
            "check",
            "--slug",
            "novel-zulu",
            "--strategy-id",
            "NOVEL_S99",
            "--vault",
            str(vault),
            "--output",
            str(output),
        ]
        captured = io.StringIO()
        with patch.object(research_dedup_check, "EA_REG", registry), patch.object(
            research_dedup_check, "CARDS_DIR", cards
        ), redirect_stdout(captured):
            rc = research_dedup_check.main(argv)
        return rc, json.loads(output.read_text(encoding="utf-8")), captured.getvalue()

    def test_scan_wiki_strategies_reads_frontmatter(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            vault = Path(tmp_dir)
            strategies = vault / "strategies"
            strategies.mkdir(parents=True, exist_ok=True)
            node = strategies / "my-strategy.md"
            node.write_text(
                "---\nslug: my-strategy\nstrategy_id: SRC99_S01\nauthor: Jane\nmechanic: mean-reversion\n---\n",
                encoding="utf-8",
            )
            rows = research_dedup_check.scan_wiki_strategies(vault)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].slug, "my-strategy")
        self.assertEqual(rows[0].strategy_id, "SRC99_S01")
        self.assertEqual(rows[0].source, "wiki")

    def test_scan_cards_includes_approved_subdirectory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            cards = Path(tmp_dir) / "cards"
            self._card(
                cards / "approved" / "QM5_13108_xti-mtsm-s2_card.md",
                "xti-mtsm-s2",
                "LIU-MTSM-2021_XTI_S01",
            )
            with patch.object(research_dedup_check, "CARDS_DIR", cards):
                rows = research_dedup_check.scan_cards()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].slug, "xti-mtsm-s2")

    def test_check_detects_exact_duplicate_from_wiki_source(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            vault = Path(tmp_dir)
            strategies = vault / "strategies"
            strategies.mkdir(parents=True, exist_ok=True)
            (strategies / "dup.md").write_text(
                "---\nslug: dup-slug\nstrategy_id: SRC12_S03\n---\n",
                encoding="utf-8",
            )
            parser = research_dedup_check.argparse.ArgumentParser()
            args = parser.parse_args([])
            args.slug = "dup-slug"
            args.strategy_id = "SRC00_S00"
            args.author = ""
            args.mechanic = ""
            args.vault = vault
            with patch("framework.scripts.research_dedup_check.read_ea_registry", return_value=[]), patch(
                "framework.scripts.research_dedup_check.scan_cards", return_value=[]
            ):
                rc = research_dedup_check.cmd_check(args)
        self.assertEqual(rc, 2)

    def test_missing_root_fails_closed_never_clean(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            rc, report, stdout = self._run_fixture_check(
                Path(tmp_dir), cards_mode="valid", vault_mode="missing"
            )
        self.assertEqual(rc, 1)
        self.assertEqual(report["verdict"], "INPUT_ERROR_FAIL_CLOSED")
        failed = [source for source in report["sources"] if source["status"] != "OK"]
        self.assertEqual(failed[0]["status"], "MISSING_ROOT")
        self.assertIsNone(failed[0]["count"])
        self.assertNotIn("VERDICT: CLEAN", stdout)

    def test_empty_directory_fails_closed_never_clean(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            rc, report, stdout = self._run_fixture_check(
                Path(tmp_dir), cards_mode="empty", vault_mode="valid"
            )
        self.assertEqual(rc, 1)
        self.assertEqual(report["verdict"], "INPUT_ERROR_FAIL_CLOSED")
        failed = [source for source in report["sources"] if source["status"] != "OK"]
        self.assertEqual(failed[0]["status"], "EMPTY_ROOT")
        self.assertEqual(failed[0]["count"], 0)
        self.assertNotIn("VERDICT: CLEAN", stdout)

    def test_encoding_error_fails_closed_never_clean(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            rc, report, stdout = self._run_fixture_check(
                Path(tmp_dir), cards_mode="encoding_error", vault_mode="valid"
            )
        self.assertEqual(rc, 1)
        self.assertEqual(report["verdict"], "INPUT_ERROR_FAIL_CLOSED")
        failed = [source for source in report["sources"] if source["status"] != "OK"]
        self.assertEqual(failed[0]["status"], "ENCODING_ERROR")
        self.assertEqual(failed[0]["count"], 1)
        self.assertNotIn("VERDICT: CLEAN", stdout)

    def test_clean_evidence_binds_checked_roots_counts_and_tool_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            rc, report, stdout = self._run_fixture_check(
                Path(tmp_dir), cards_mode="valid", vault_mode="valid"
            )
        self.assertEqual(rc, 0)
        self.assertIn("VERDICT: CLEAN", stdout)
        self.assertEqual(report["verdict"], "CLEAN")
        self.assertEqual(report["tool_version"], research_dedup_check.TOOL_VERSION)
        self.assertEqual([source["count"] for source in report["sources"]], [1, 1, 1])
        self.assertTrue(all(Path(source["checked_root"]).is_absolute() for source in report["sources"]))
        self.assertTrue(all(source["status"] == "OK" for source in report["sources"]))


if __name__ == "__main__":
    unittest.main()
