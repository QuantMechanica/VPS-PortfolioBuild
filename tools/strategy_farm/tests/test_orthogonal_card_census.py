from __future__ import annotations

import csv
from pathlib import Path

from tools.strategy_farm.orthogonal_card_census import (
    build_census,
    canonical_family,
    classify_mechanisms,
    parse_card,
)


def _card(path: Path, ea_id: str, body: str, symbols: str = "[EURUSD.DWX]") -> Path:
    path.write_text(
        "---\n"
        f"ea_id: {ea_id}\n"
        f"target_symbols: {symbols}\n"
        "timeframe: H1\n"
        "---\n\n"
        f"# {body}\n",
        encoding="utf-8",
    )
    return path


def test_explicit_mechanism_and_literal_timeframe_are_read(tmp_path: Path) -> None:
    path = tmp_path / "PENDING_A_card.md"
    path.write_text(
        "---\n"
        "ea_id: PENDING_A\n"
        "family: calendar_seasonality\n"
        "mechanism: fx_benchmark_fix_rebalancing\n"
        "target_symbols: [EURUSD.DWX, GBPUSD.DWX]\n"
        "timeframe: M15\n"
        "---\n\n"
        "# Month-end FX benchmark fix rebalancing at the London fix\n",
        encoding="utf-8",
    )
    card = parse_card(path)
    assert card.raw_family == "calendar_seasonality"
    assert card.raw_mechanism == "fx_benchmark_fix_rebalancing"
    assert card.symbols == ("EURUSD.DWX", "GBPUSD.DWX")
    assert "fx_benchmark_fix_rebalancing" in card.mechanisms


def test_mechanism_rules_require_the_relevant_carrier() -> None:
    text = "high-volatility reversal caused by evaporating liquidity"
    assert classify_mechanisms(text, ["EURUSD.DWX"]) == ()
    assert classify_mechanisms(text, ["SP500.DWX"]) == (
        "index_volatility_liquidity_reversal",
    )


def test_broad_family_priority_keeps_relative_value_out_of_momentum() -> None:
    assert canonical_family("market-neutral two-leg momentum spread") == "relative_value_stat_arb"


def test_build_census_joins_only_q08_or_higher(tmp_path: Path) -> None:
    approved = tmp_path / "approved"
    approved.mkdir()
    _card(
        approved / "QM5_1_fix.md",
        "QM5_1",
        "Month-end FX benchmark fix rebalancing at the London fix.",
    )
    _card(
        approved / "QM5_2_gap.md",
        "QM5_2",
        "Index gap fade reversal.",
        "[SP500.DWX]",
    )
    census = tmp_path / "census.csv"
    with census.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "symbol", "highest_contiguous_valid_gate"])
        writer.writeheader()
        writer.writerow({"ea_id": "QM5_1", "symbol": "EURUSD.DWX", "highest_contiguous_valid_gate": "Q08"})
        writer.writerow({"ea_id": "QM5_1", "symbol": "GBPUSD.DWX", "highest_contiguous_valid_gate": "Q10"})
        writer.writerow({"ea_id": "QM5_2", "symbol": "SP500.DWX", "highest_contiguous_valid_gate": "Q07"})

    result = build_census(approved, census)
    assert result["approved_card_count"] == 2
    assert result["q08_valid_pair_count"] == 2
    assert result["q08_valid_distinct_ea_count"] == 1
    assert result["q08_valid"]["mechanism"]["fx_benchmark_fix_rebalancing"] == 1
    assert result["q08_valid"]["mechanism"]["index_gap_response"] == 0
