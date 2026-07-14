from tools.strategy_farm.portfolio import ftmo_ndx_gap_response_holdout_2025 as holdout


def test_holdout_gate_is_conjunctive() -> None:
    assert holdout.holdout_pass(
        {"trades": 40, "profit_factor": 1.10, "net_r": 0.01}
    )
    assert not holdout.holdout_pass(
        {"trades": 39, "profit_factor": 1.50, "net_r": 10.0}
    )
    assert not holdout.holdout_pass(
        {"trades": 50, "profit_factor": 1.09, "net_r": 10.0}
    )
    assert not holdout.holdout_pass(
        {"trades": 50, "profit_factor": 1.50, "net_r": 0.0}
    )
