import csv
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class EaIdReservationTests(unittest.TestCase):
    def _repo(self) -> tempfile.TemporaryDirectory:
        return tempfile.TemporaryDirectory(ignore_cleanup_errors=True)

    def _write_registry(self, repo: Path) -> Path:
        registry = repo / "framework" / "registry" / "ea_id_registry.csv"
        registry.parent.mkdir(parents=True)
        registry.write_text(
            "\n".join(
                [
                    "ea_id,slug,strategy_id,status,owner,created_at",
                    "1001,alpha,SRC_A,active,Research,2026-05-01",
                    "1003,gamma,SRC_G,active,Research,2026-05-01",
                    "",
                ]
            ),
            encoding="utf-8",
            newline="\n",
        )
        return registry

    def _rows(self, registry: Path) -> list[dict[str, str]]:
        with registry.open(encoding="utf-8", newline="") as handle:
            return list(csv.DictReader(handle))

    def test_reserve_ea_ids_allocates_next_free_ids_atomically(self) -> None:
        with self._repo() as tmp:
            repo = Path(tmp)
            registry = self._write_registry(repo)
            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo
                result = farmctl.reserve_ea_ids(
                    Path(tmp) / "farm",
                    ["delta", "epsilon"],
                    strategy_id="SRC_NEW",
                    owner="Research",
                    created_at="2026-05-19",
                )
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertTrue(result["reserved"])
            self.assertEqual([row["ea_id"] for row in result["rows"]], ["1004", "1005"])
            rows = self._rows(registry)
            self.assertEqual([row["slug"] for row in rows[-2:]], ["delta", "epsilon"])
            self.assertFalse((registry.parent / ".ea_id_registry.lock").exists())

    def test_reserve_ea_ids_rejects_existing_slug_without_writing(self) -> None:
        with self._repo() as tmp:
            repo = Path(tmp)
            registry = self._write_registry(repo)
            before = registry.read_text(encoding="utf-8")
            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo
                result = farmctl.reserve_ea_ids(
                    Path(tmp) / "farm",
                    ["alpha"],
                    strategy_id="SRC_NEW",
                    created_at="2026-05-19",
                )
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertFalse(result["reserved"])
            self.assertEqual(result["reason"], "duplicate_slug")
            self.assertEqual(registry.read_text(encoding="utf-8"), before)

    def test_reserve_ea_ids_rejects_duplicate_slug_in_request(self) -> None:
        with self._repo() as tmp:
            repo = Path(tmp)
            registry = self._write_registry(repo)
            before = registry.read_text(encoding="utf-8")
            old_repo_root = farmctl.REPO_ROOT
            try:
                farmctl.REPO_ROOT = repo
                result = farmctl.reserve_ea_ids(
                    Path(tmp) / "farm",
                    ["delta", "delta"],
                    strategy_id="SRC_NEW",
                    created_at="2026-05-19",
                )
            finally:
                farmctl.REPO_ROOT = old_repo_root

            self.assertFalse(result["reserved"])
            self.assertEqual(result["reason"], "duplicate_slug_in_request")
            self.assertEqual(registry.read_text(encoding="utf-8"), before)


if __name__ == "__main__":
    unittest.main()
