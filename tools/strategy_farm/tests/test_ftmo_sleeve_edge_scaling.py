from __future__ import annotations

import numpy as np

from tools.strategy_farm.portfolio import ftmo_bar_governor_sim as governor
from tools.strategy_farm.portfolio import ftmo_sleeve_edge_scaling as subject


def path(
    trade_id: str,
    *,
    key: str = "1:TEST",
    start: int,
    end: int,
    net: float,
) -> governor.GovernedTradePath:
    return governor.GovernedTradePath(
        trade_id=trade_id,
        key=key,
        start_idx=start,
        end_idx=end,
        entry_commission=10.0,
        exit_commission=10.0,
        exit_balance_delta=net + 10.0,
        adverse_pnl=np.array([-100.0]),
        close_pnl=np.array([net + 20.0]),
        nominal_risk=1000.0,
    )


def test_causal_score_uses_only_strictly_earlier_exits_per_sleeve() -> None:
    paths = [
        path("a", start=0, end=2, net=100.0),
        path("b", start=2, end=3, net=-50.0),
        path("c", start=4, end=5, net=25.0),
        path("other", key="2:TEST", start=4, end=5, net=999.0),
    ]
    scores = subject.causal_edge_scores(paths, 1)
    assert scores["a"] is None
    assert scores["b"] is None  # a exits in the same M15 bucket as b enters
    assert scores["c"] == -0.05
    assert scores["other"] is None


def test_scale_paths_multiplies_the_complete_trade_path() -> None:
    paths = [
        path("a", start=0, end=1, net=-100.0),
        path("b", start=2, end=3, net=200.0),
    ]
    policy = subject.EdgePolicy("soft", 1, 0.5, 1.25)
    scaled, counts = subject.scale_paths(paths, policy)
    assert scaled[0].nominal_risk == 1000.0
    assert scaled[1].nominal_risk == 500.0
    assert scaled[1].entry_commission == 5.0
    assert scaled[1].exit_balance_delta == 105.0
    assert scaled[1].adverse_pnl.tolist() == [-50.0]
    assert counts == {"nonpositive": 1, "warmup": 1}


def test_strict_dual_improvement_rejects_any_breach_increase() -> None:
    def evaluation(pass_pct: float, daily: float = 0.0, maximum: float = 0.0):
        return {
            "historical_rolling": {
                "pass_pct": pass_pct,
                "daily_breach_pct": daily,
                "max_breach_pct": maximum,
            }
        }

    control_normal = evaluation(50.0)
    control_adverse = evaluation(40.0, 10.0, 5.0)
    assert subject.strict_dual_improvement(
        evaluation(51.0), evaluation(41.0, 10.0, 5.0), control_normal, control_adverse
    )
    assert not subject.strict_dual_improvement(
        evaluation(51.0, 0.1),
        evaluation(41.0, 10.0, 5.0),
        control_normal,
        control_adverse,
    )
