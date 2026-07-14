from tools.strategy_farm.portfolio import ftmo_ndx_gap_response_validation_2024 as validation


def test_validation_gate_is_conjunctive() -> None:
    assert validation.validation_pass(
        {"trades": 40, "profit_factor": 1.10, "net_r": 0.01}
    )
    assert not validation.validation_pass(
        {"trades": 39, "profit_factor": 1.50, "net_r": 10.0}
    )
    assert not validation.validation_pass(
        {"trades": 50, "profit_factor": 1.09, "net_r": 10.0}
    )
    assert not validation.validation_pass(
        {"trades": 50, "profit_factor": 1.50, "net_r": 0.0}
    )
