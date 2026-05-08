from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from framework.scripts import research_dedup_check


class ResearchDedupCheckTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
