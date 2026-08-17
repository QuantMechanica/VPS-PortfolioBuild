from __future__ import annotations

import csv
import json
from pathlib import Path
import sqlite3
import subprocess

from tools.strategy_farm import inventory_stranded_eas as inventory


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _ea(root: Path, name: str, *, source: bool, binary: bool, setfile: bool) -> None:
    directory = root / "framework" / "EAs" / name
    directory.mkdir(parents=True)
    if source:
        (directory / f"{name}.mq5").write_text("void OnTick(){}\n", encoding="utf-8")
    if binary:
        (directory / f"{name}.ex5").write_bytes(b"binary")
    if setfile:
        sets = directory / "sets"
        sets.mkdir()
        (sets / "x.set").write_text("RISK_FIXED=1\nRISK_PERCENT=0\n", encoding="utf-8")


def test_inventory_covers_four_classes_without_mutating(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    farm = tmp_path / "farm"
    (repo / "framework" / "include" / "QM").mkdir(parents=True)
    (farm / "artifacts" / "cards_approved").mkdir(parents=True)
    (farm / "state").mkdir(parents=True)
    _ea(repo, "QM5_1_authored", source=True, binary=False, setfile=False)
    _ea(repo, "QM5_2_built", source=True, binary=True, setfile=True)
    _ea(repo, "QM5_3_untracked", source=True, binary=True, setfile=False)

    _write_csv(
        repo / "framework" / "registry" / "ea_id_registry.csv",
        ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"],
        [{"ea_id": "QM5_4", "slug": "blocked", "strategy_id": "s", "status": "active", "owner": "x", "created_at": "x"}],
    )
    _write_csv(
        repo / "framework" / "registry" / "magic_numbers.csv",
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "reserved_at", "reserved_by", "status"],
        [],
    )
    (repo / "framework" / "include" / "QM" / "QM_MagicResolver.mqh").write_text(
        """
        static const int QM_MAGIC_REG_EA_ID[0]={};
        static const int QM_MAGIC_REG_SLOT[0]={};
        static const string QM_MAGIC_REG_SYMBOL[0]={};
        static const int QM_MAGIC_REG_MAGIC[0]={};
        """,
        encoding="utf-8",
    )
    (farm / "artifacts" / "cards_approved" / "QM5_4_blocked.md").write_text(
        "---\nea_id: QM5_4\nslug: blocked\ng0_status: APPROVED\ntarget_symbols: [EURUSD.DWX]\n---\n",
        encoding="utf-8",
    )
    with sqlite3.connect(farm / "state" / "farm_state.sqlite") as conn:
        conn.execute("CREATE TABLE work_items (ea_id TEXT)")

    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(
        ["git", "add", "framework/EAs/QM5_1_authored", "framework/EAs/QM5_2_built"],
        cwd=repo,
        check=True,
    )
    subprocess.run(
        [
            "git",
            "-c",
            "user.name=pytest",
            "-c",
            "user.email=pytest@example.invalid",
            "commit",
            "-qm",
            "fixture",
        ],
        cwd=repo,
        check=True,
    )
    result = inventory.build_inventory(repo, farm)
    by_key = {row["key"]: row for row in result["eas"]}
    assert "authored_not_built" in by_key["QM5_1_authored"]["classes"]
    assert "built_not_dispatched" in by_key["QM5_2_built"]["classes"]
    assert "untracked_in_git" in by_key["QM5_3_untracked"]["classes"]
    assert by_key["QM5_4_blocked"]["classes"] == ["blocked_on_registry"]
    assert result["counts"]["class_memberships"] == {
        "authored_not_built": 1,
        "blocked_on_registry": 1,
        "built_not_dispatched": 1,
        "untracked_in_git": 1,
    }
    assert inventory.render_inventory(result) == inventory.render_inventory(
        inventory.build_inventory(repo, farm)
    )
