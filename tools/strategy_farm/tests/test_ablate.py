from __future__ import annotations

import re
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from ablate import mutate_setfile, mutate_setfile_grid  # noqa: E402


def _fixture(tmp_path: Path) -> tuple[Path, Path]:
    ea_dir = tmp_path / "QM5_99998_ablation-fixture"
    ea_dir.mkdir()
    (ea_dir / f"{ea_dir.name}.mq5").write_text(
        "input int strategy_period = 10;\n"
        "input double strategy_threshold = 2.0;\n",
        encoding="utf-8",
    )
    parent = ea_dir / "sets" / "fixture.set"
    parent.parent.mkdir()
    parent.write_text(
        "; parent\n"
        "strategy_period=999\n"
        "Unrelated=42\n"
        "  strategy_period = 888\n",
        encoding="utf-8",
    )
    return ea_dir, parent


def _assert_replaced_once(content: str, marker: str) -> None:
    assert len(re.findall(r"(?m)^\s*strategy_period\s*=", content)) == 1
    assert len(re.findall(r"(?m)^\s*strategy_threshold\s*=", content)) == 1
    assert "strategy_period=999" not in content
    assert "strategy_period = 888" not in content
    assert "Unrelated=42" in content
    assert marker in content


def test_random_ablation_replaces_parent_assignments_without_duplicates(
    tmp_path: Path,
) -> None:
    ea_dir, parent = _fixture(tmp_path)

    children = mutate_setfile(
        parent,
        ea_dir,
        n_variants=1,
        perturb_pct=0.25,
        seed=7,
    )

    assert len(children) == 1
    _assert_replaced_once(
        children[0].read_text(encoding="utf-8"),
        "; --- ablation child 00",
    )


def test_grid_ablation_replaces_parent_assignments_without_duplicates(
    tmp_path: Path,
) -> None:
    ea_dir, parent = _fixture(tmp_path)

    children = mutate_setfile_grid(
        parent,
        ea_dir,
        n_target=1,
        perturb_pct=0.30,
    )

    assert len(children) == 1
    _assert_replaced_once(
        children[0].read_text(encoding="utf-8"),
        "; --- grid child 000/001",
    )
