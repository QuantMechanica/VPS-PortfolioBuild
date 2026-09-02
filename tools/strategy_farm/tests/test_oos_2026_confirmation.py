from tools.strategy_farm import oos_2026_confirmation as subject
from tools.strategy_farm import q09_news_runner as q09


def test_campaign_scope_is_fixed_single_window_non_admission() -> None:
    assert len(subject.FRONTIER) == 31
    assert len(set(subject.FRONTIER)) == 31
    assert subject.FROM_UTC == "2026-01-01T00:00:00Z"
    assert subject.TO_UTC == "2026-04-06T23:59:59Z"
    assert subject.WINDOW_SOURCE == "oos_2026"
    assert subject.ALLOWED == ["T1", "T2", "T3", "T4", "T5"]
    assert subject.AVOID == ["T6", "T7", "T8", "T9", "T10"]


def test_single_window_timeout_is_supported() -> None:
    assert q09.required_factory_timeout_min(1, window_count=1) > 60
