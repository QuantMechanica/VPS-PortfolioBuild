from __future__ import annotations

from tools.strategy_farm.portfolio import ftmo_eurusd_tuesday_london_midday_nested as nested


def test_filter_accepts_fixed_causal_features() -> None:
    features = {
        "prior_day_return": 0.01,
        "prior_week_return": -0.02,
        "overnight_return": 0.001,
        "entry_price": 1.11,
        "sma20": 1.10,
    }
    assert nested.filter_accepts("none", features)
    assert nested.filter_accepts("prior_day_return_positive", features)
    assert not nested.filter_accepts("prior_day_return_nonpositive", features)
    assert nested.filter_accepts("prior_week_return_nonpositive", features)
    assert nested.filter_accepts("overnight_return_positive", features)
    assert nested.filter_accepts("above_20d_sma", features)


def test_filter_only_requires_its_own_causal_feature() -> None:
    features = {
        "prior_day_return": 0.01,
        "prior_week_return": float("nan"),
        "overnight_return": float("nan"),
        "entry_price": 1.11,
        "sma20": float("nan"),
    }
    assert nested.filter_accepts("prior_day_return_positive", features)
    assert not nested.filter_accepts("prior_week_return_positive", features)
    assert not nested.filter_accepts("above_20d_sma", features)


def test_control_arm_does_not_depend_on_feature_availability() -> None:
    trades = [object(), object()]
    assert nested.filtered_trades(trades, {}, "none") == trades


def test_research_gate_requires_strict_control_improvement() -> None:
    metrics = {
        "trades": 180,
        "profit_factor": 1.25,
        "net_r": 8.0,
        "positive_years": 5,
    }
    assert nested.research_pass(metrics, 1.24)
    assert not nested.research_pass(metrics, 1.25)
    assert not nested.research_pass({**metrics, "positive_years": 4}, 1.24)


def test_select_winner_is_deterministic_and_ignores_ineligible_rows() -> None:
    rows = [
        {
            "filter": "zeta",
            "metrics": {"profit_factor": 1.3, "trades": 160},
            "passes_research_gate": True,
        },
        {
            "filter": "alpha",
            "metrics": {"profit_factor": 1.3, "trades": 160},
            "passes_research_gate": True,
        },
        {
            "filter": "higher_but_failed",
            "metrics": {"profit_factor": 9.0, "trades": 999},
            "passes_research_gate": False,
        },
    ]
    assert nested.select_research_winner(rows)["filter"] == "alpha"


def test_year_gate_is_independent_of_research_metrics() -> None:
    assert nested.year_gate({"trades": 20, "profit_factor": 1.1, "net_r": 0.01})
    assert not nested.year_gate({"trades": 19, "profit_factor": 2.0, "net_r": 10.0})
    assert not nested.year_gate({"trades": 30, "profit_factor": 1.09, "net_r": 10.0})
