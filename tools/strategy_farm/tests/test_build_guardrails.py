from pathlib import Path

from tools.strategy_farm.validate_build_guardrails import validate_path


def test_rejects_news_stale_bypass_in_mq5(tmp_path: Path) -> None:
    ea = tmp_path / "QM5_9999_test"
    ea.mkdir()
    (ea / "QM5_9999_test.mq5").write_text(
        "input int qm_news_stale_max_hours = 8760;\n",
        encoding="utf-8",
    )

    result = validate_path(ea)

    assert result["verdict"] == "FAIL"
    assert result["findings"][0]["kind"] == "news_stale_max_hours_too_high"


def test_rejects_percent_risk_in_backtest_setfile(tmp_path: Path) -> None:
    sets = tmp_path / "sets"
    sets.mkdir()
    (sets / "QM5_9999_test_EURUSD.DWX_H1_backtest.set").write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=1.0\n",
        encoding="utf-8",
    )

    result = validate_path(tmp_path)

    assert result["verdict"] == "FAIL"
    assert result["findings"][0]["kind"] == "backtest_risk_percent_invalid"


def test_accepts_fail_closed_news_and_fixed_backtest_risk(tmp_path: Path) -> None:
    ea = tmp_path / "QM5_9999_test"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    (ea / "QM5_9999_test.mq5").write_text(
        "input int qm_news_stale_max_hours = 336;\n",
        encoding="utf-8",
    )
    (sets / "QM5_9999_test_EURUSD.DWX_H1_backtest.set").write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours=336\n",
        encoding="utf-8",
    )

    result = validate_path(ea)

    assert result["verdict"] == "PASS"
    assert result["findings"] == []
