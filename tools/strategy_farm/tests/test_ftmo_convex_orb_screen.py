from tools.strategy_farm.portfolio import ftmo_convex_orb_screen as screen
from tools.strategy_farm.portfolio.ftmo_intraday_candidate_screen import Trade


def test_target_grid_is_frozen() -> None:
    assert screen.TARGETS_R == (3.0, 5.0, 8.0)


def test_preholdout_score_ignores_holdout() -> None:
    row = {
        "metrics": {
            "dev_2018_2022": {"profit_factor": 1.25},
            "validation_2023": {"profit_factor": 1.10},
            "holdout_2024_2025": {"profit_factor": 99.0},
        }
    }
    assert screen.preholdout_score(row) == 1.10


def test_evidence_horizon_excludes_2026() -> None:
    def trade(year: int) -> Trade:
        return Trade("2025-01-01T00:00:00+00:00", "2025-01-01", year, 1, 1.0, "target")

    assert [row.year for row in screen.evidence_horizon([trade(2025), trade(2026)])] == [2025]
