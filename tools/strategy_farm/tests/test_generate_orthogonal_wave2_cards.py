from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

import pytest

from tools.strategy_farm.generate_orthogonal_wave2_cards import card_specs, render_card, write_cards


def test_wave2_has_twenty_unique_cards_and_four_per_mechanism() -> None:
    specs = card_specs()
    assert len(specs) == 20
    assert len({spec.slug for spec in specs}) == 20
    assert len({spec.pending_id for spec in specs}) == 20
    assert set(Counter(spec.mechanism for spec in specs).values()) == {4}


def test_cards_are_schema_lintable_and_parameter_count_matches() -> None:
    for spec in card_specs():
        rendered = render_card(spec)
        lower = rendered.lower()
        assert "## hypothesis" in lower
        assert "## rules" in lower
        assert "## risk" in lower
        assert f"declared_parameter_count: {len(spec.parameters)}" in rendered
        assert f"target_symbols: [{spec.symbol}]" in rendered
        assert f"timeframe: {spec.timeframe}" in rendered
        assert "expected_pf:" not in lower
        assert "expected_dd" not in lower
        assert "g0_status: PENDING_REVIEW" in rendered


def test_all_targets_are_registered_dwx_symbols() -> None:
    matrix = Path("framework/registry/dwx_symbol_matrix.csv").read_text(encoding="utf-8-sig")
    registered = {line.split(",", 1)[0] for line in matrix.splitlines()[1:] if line.strip()}
    assert {spec.symbol for spec in card_specs()} <= registered


def test_writer_is_fail_closed_on_existing_file(tmp_path: Path) -> None:
    paths = write_cards(tmp_path)
    assert len(paths) == 20
    assert all(re.fullmatch(r"PENDING_[0-9A-F]{8}_.+\.md", path.name) for path in paths)
    with pytest.raises(FileExistsError, match="refusing to overwrite"):
        write_cards(tmp_path)
