import pytest

from tools.strategy_farm.portfolio import ftmo_conditional_deadline_policy as policy


def test_parse_and_serialize_policy_round_trip() -> None:
    raw = {
        "name": "two_step",
        "conditional_steps": [
            {
                "elapsed_calendar_days": 15,
                "minimum_profit": 0,
                "maximum_profit": 4000,
                "risk_multiplier": 28,
            },
            {
                "elapsed_calendar_days": 22,
                "minimum_profit": 0,
                "maximum_profit": 8500,
                "risk_multiplier": 35,
            },
        ],
    }
    parsed = policy.parse_policy(raw)
    assert parsed.steps == ((15, 0.0, 4000.0, 28.0), (22, 0.0, 8500.0, 35.0))
    assert policy.serialize_policy(parsed) == raw


def test_parse_rejects_non_increasing_days() -> None:
    raw = {
        "name": "bad",
        "conditional_steps": [
            {
                "elapsed_calendar_days": 20,
                "minimum_profit": 0,
                "maximum_profit": 4000,
                "risk_multiplier": 30,
            },
            {
                "elapsed_calendar_days": 20,
                "minimum_profit": 0,
                "maximum_profit": 8000,
                "risk_multiplier": 35,
            },
        ],
    }
    with pytest.raises(ValueError, match="increasing days"):
        policy.parse_policy(raw)


def test_rank_survivors_uses_worst_fill_delta() -> None:
    rows = [
        {
            "policy": {"name": "a", "conditional_steps": []},
            "stage_survivor": True,
            "pass_delta_pct_points": {"normal": 2.0, "adverse": 0.5},
        },
        {
            "policy": {"name": "b", "conditional_steps": []},
            "stage_survivor": True,
            "pass_delta_pct_points": {"normal": 1.0, "adverse": 1.0},
        },
    ]
    assert policy.rank_survivors(rows)[0]["policy"]["name"] == "b"


def test_dual_improvement_accepts_only_within_breach_budget() -> None:
    def row(pass_pct: float, daily: float, maximum: float) -> dict:
        return {
            "historical_rolling": {
                "pass_pct": pass_pct,
                "daily_breach_pct": daily,
                "max_breach_pct": maximum,
            }
        }

    control_normal = row(59.0, 0.0, 0.0)
    control_adverse = row(51.0, 21.0, 12.5)
    candidate_normal = row(59.5, 0.0, 0.0)
    candidate_adverse = row(51.5, 21.3, 12.5)
    assert not policy.dual_improvement_with_breach_budget(
        candidate_normal,
        candidate_adverse,
        control_normal,
        control_adverse,
        maximum_individual_breach_increase_pp=0.0,
    )
    assert policy.dual_improvement_with_breach_budget(
        candidate_normal,
        candidate_adverse,
        control_normal,
        control_adverse,
        maximum_individual_breach_increase_pp=0.5,
    )
