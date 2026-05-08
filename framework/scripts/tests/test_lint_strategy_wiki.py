from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from framework.scripts import lint_strategy_wiki


class LintStrategyWikiTests(unittest.TestCase):
    def test_empty_vault_tree_is_clean(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            vault = Path(tmp_dir)
            violations = lint_strategy_wiki.lint_vault(vault)
        self.assertEqual(violations, [])

    def test_detects_broken_xref_missing_frontmatter_and_index_drift(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            vault = Path(tmp_dir)
            (vault / "strategies").mkdir(parents=True, exist_ok=True)
            (vault / "_INDEX.md").write_text("[[ghost-node]]\n", encoding="utf-8")
            (vault / "strategies" / "node-a.md").write_text("[[missing-node]]\n", encoding="utf-8")
            violations = lint_strategy_wiki.lint_vault(vault)
        codes = {v.code for v in violations}
        self.assertIn("missing_frontmatter", codes)
        self.assertIn("broken_xref", codes)
        self.assertIn("index_stale_node", codes)
        self.assertIn("index_missing_node", codes)

    def test_detects_duplicate_ids_and_slugs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            vault = Path(tmp_dir)
            strategies = vault / "strategies"
            strategies.mkdir(parents=True, exist_ok=True)
            content = "---\nid: SRC01_S01\nslug: same-slug\ntitle: T\n---\n"
            (strategies / "one.md").write_text(content, encoding="utf-8")
            (strategies / "two.md").write_text(content, encoding="utf-8")
            violations = lint_strategy_wiki.lint_vault(vault)
        codes = {v.code for v in violations}
        self.assertIn("duplicate_id", codes)
        self.assertIn("duplicate_slug", codes)


if __name__ == "__main__":
    unittest.main()
