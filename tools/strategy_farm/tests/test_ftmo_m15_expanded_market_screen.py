from pathlib import Path

from tools.strategy_farm.portfolio import ftmo_m15_expanded_market_screen as screen


def test_expanded_instrument_contract() -> None:
    instruments = screen.expanded_instruments(Path("root"))
    assert [item.symbol for item in instruments] == [
        "UK100.DWX",
        "XAGUSD.DWX",
        "XTIUSD.DWX",
        "XNGUSD.DWX",
    ]
    assert [item.round_trip_cost_points for item in instruments] == [4.0, 0.03, 0.05, 0.02]


def test_configuration_count_and_family_names() -> None:
    definitions = screen._definitions()
    assert len(definitions) == 144
    assert {item[0] for item in definitions} == {
        "m15_orb_balanced",
        "m15_orb_convex",
        "m15_impulse_fade",
        "m15_impulse_cont",
        "m15_gap_fade",
        "m15_gap_cont",
    }
