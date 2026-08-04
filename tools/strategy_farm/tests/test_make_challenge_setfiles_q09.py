from __future__ import annotations

import pytest

from tools.strategy_farm.portfolio import make_challenge_setfiles as subject


def _admission(temporal: str = "SKIP_DAY") -> dict[str, object]:
    return {
        "admitted": True,
        "reason_code": "FTMO_Q09_ADMITTED",
        "q09_news_work_item_id": "q09-locked",
        "aggregate_sha256": "a" * 64,
        "chosen_temporal": temporal,
        "deployment_compliance": "FTMO",
    }


def test_locked_temporal_and_ftmo_compliance_flow_into_derived_set() -> None:
    source = (
        "; environment:  backtest\n"
        "; risk_mode:    FIXED\n"
        "RISK_FIXED=1000\n"
        "RISK_PERCENT=0\n"
        "qm_news_temporal=0\n"
        "qm_news_compliance=1\n"
        "qm_news_stale_max_hours=336\n"
        "strategy_period=20\n"
    )

    rendered = subject.patch(source, 3.0, _admission())
    values = subject._set_values(rendered)

    assert values["RISK_FIXED"] == "0"
    assert values["RISK_PERCENT"] == "3"
    assert values["qm_news_temporal"] == "5"
    assert values["qm_news_compliance"] == "2"
    assert values["strategy_period"] == "20"


def test_missing_q09_admission_refuses_before_rendering() -> None:
    with pytest.raises(ValueError, match="FTMO_Q09_EVIDENCE_MISSING"):
        subject.patch(
            "RISK_FIXED=1000\nRISK_PERCENT=0\n",
            3.0,
            {"admitted": False, "reason_code": "FTMO_Q09_EVIDENCE_MISSING"},
        )


def test_stale_news_limit_is_never_weakened() -> None:
    with pytest.raises(subject.ChallengeSetError, match="exceeds 336"):
        subject.patch(
            "RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours=337\n",
            3.0,
            _admission("PRE30"),
        )
