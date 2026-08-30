from __future__ import annotations

import csv
from pathlib import Path

import pytest

from tools.strategy_farm import apply_q02_split_fix as split


def _csv(path: Path, causes: list[str]) -> Path:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=(
            "ea_id", "symbol", "primary_cause", "latest_work_item_id",
        ))
        writer.writeheader()
        for index, cause in enumerate(causes):
            writer.writerow({"ea_id": f"QM5_{1000 + index}", "symbol": f"S{index}.DWX",
                             "primary_cause": cause, "latest_work_item_id": f"source-{index}"})
    return path


def valid_causes() -> list[str]:
    return ["ACTIVE_TIMEOUT"] * 16 + ["TIMEOUT_METATESTER_HUNG"] * 2 + \
        ["NO_HISTORY_TRANSIENT"] * 2 + ["SETFILE_MISSING"] * 6 + \
        ["ONINIT_FAILED"] * 4 + ["SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE"] * 3 + \
        ["LOG_BOMB"]


def test_manifest_is_exact_20_14_and_four_batches(tmp_path: Path) -> None:
    manifest = split.derive_manifest(_csv(tmp_path / "classification.csv", valid_causes()))
    assert (manifest["row_count"], manifest["restart_count"], manifest["retire_count"]) == (34, 20, 14)
    assert [sum(row["batch"] == batch for row in manifest["rows"]) for batch in range(1, 5)] == [5, 5, 5, 5]
    assert all(row["batch"] is None for row in manifest["rows"] if row["action"] == "RETIRE")


def test_manifest_rejects_unknown_cause(tmp_path: Path) -> None:
    causes = valid_causes(); causes[0] = "JUDGMENT_CALL"
    with pytest.raises(split.SplitFixError, match="unmapped_primary_cause"):
        split.derive_manifest(_csv(tmp_path / "classification.csv", causes))


def test_manifest_rejects_count_drift(tmp_path: Path) -> None:
    with pytest.raises(split.SplitFixError, match="classification_count"):
        split.derive_manifest(_csv(tmp_path / "classification.csv", valid_causes()[:-1]))


def test_successor_ids_are_action_and_source_deterministic() -> None:
    assert split.deterministic_id("RESTART", "source") == split.deterministic_id("RESTART", "source")
    assert split.deterministic_id("RESTART", "source") != split.deterministic_id("RETIRE", "source")
