from pathlib import Path

from tools.strategy_farm import compile_ea
from tools.strategy_farm.validate_build_guardrails import validate_path


def test_ea_id_registered_matches_id_not_qm5_prefix(tmp_path: Path, monkeypatch) -> None:
    # fail-closed compile gate: an EA may only compile if its ea_id is in the registry.
    csv = tmp_path / "magic_numbers.csv"
    csv.write_text("10590,elderimp,0,EURUSD.DWX,105900000,2026-06-03,X,active\n", encoding="utf-8")
    monkeypatch.setattr(compile_ea, "MAGIC_REGISTRY", csv)
    assert compile_ea.ea_id_registered("QM5_10590_mql5-elderimp") == (True, 10590)
    assert compile_ea.ea_id_registered("QM5_99999_x") == (False, 99999)
    assert compile_ea.ea_id_registered("QM5_5_x") == (False, 5)  # not the '5' in 'QM5'


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


def test_rejects_live_setfile_without_strategy_params_and_card_source(tmp_path: Path) -> None:
    sets = tmp_path / "sets"
    sets.mkdir()
    (sets / "QM5_9999_test_EURUSD.DWX_H1_live.set").write_text(
        "\n".join(
            [
                "; environment:  live",
                "RISK_FIXED=0",
                "RISK_PERCENT=0.25",
                "PORTFOLIO_WEIGHT=0.125",
                "; strategy-specific params from card must be appended below this line",
                "; card_defaults_source=not_found",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    result = validate_path(tmp_path)

    kinds = {finding["kind"] for finding in result["findings"]}
    assert result["verdict"] == "FAIL"
    assert "live_strategy_params_missing" in kinds
    assert "live_card_defaults_source_not_found" in kinds


def test_accepts_live_setfile_with_explicit_strategy_params(tmp_path: Path) -> None:
    sets = tmp_path / "sets"
    sets.mkdir()
    (sets / "QM5_9999_test_EURUSD.DWX_H1_live.set").write_text(
        "\n".join(
            [
                "; environment:  live",
                "RISK_FIXED=0",
                "RISK_PERCENT=0.25",
                "PORTFOLIO_WEIGHT=0.125",
                "; strategy-specific params from card must be appended below this line",
                "; card_defaults_source=C:\\QM\\repo\\artifacts\\cards_approved\\QM5_9999_test.md",
                "strategy_entry_threshold=30.0",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    result = validate_path(tmp_path)

    assert result["verdict"] == "PASS"
    assert result["findings"] == []


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


def test_rejects_time_sensitive_breakout_setfile_without_time_params(tmp_path: Path) -> None:
    ea = tmp_path / "QM5_9999_test-breakout"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    (ea / "QM5_9999_test-breakout.mq5").write_text(
        """
        input int strategy_range_start_hour_broker = 22;
        input int strategy_range_duration_minutes = 240;
        input int strategy_exit_hour_broker = 22;
        input int strategy_atr_period = 14;
        """,
        encoding="utf-8",
    )
    (ea / "SPEC.md").write_text("Range breakout from 03:00 to 06:00, EOD exit.", encoding="utf-8")
    (sets / "QM5_9999_test-breakout_USDJPY.DWX_M30_backtest.set").write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\n",
        encoding="utf-8",
    )

    result = validate_path(ea)

    assert result["verdict"] == "FAIL"
    assert any(f["kind"] == "time_sensitive_strategy_params_missing" for f in result["findings"])


def test_accepts_time_sensitive_breakout_setfile_with_explicit_time_params(tmp_path: Path) -> None:
    ea = tmp_path / "QM5_9999_test-breakout"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    (ea / "QM5_9999_test-breakout.mq5").write_text(
        """
        input int strategy_range_start_hour_broker = 22;
        input int strategy_range_duration_minutes = 240;
        input int strategy_exit_hour_broker = 22;
        input int strategy_atr_period = 14;
        """,
        encoding="utf-8",
    )
    (ea / "SPEC.md").write_text("Range breakout from 03:00 to 06:00, EOD exit.", encoding="utf-8")
    (sets / "QM5_9999_test-breakout_USDJPY.DWX_M30_backtest.set").write_text(
        "\n".join(
            [
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                "strategy_range_start_hour_broker=3",
                "strategy_range_duration_minutes=180",
                "strategy_exit_hour_broker=22",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    result = validate_path(ea)

    assert result["verdict"] == "PASS"
    assert result["findings"] == []


def test_exit_weight_is_not_misclassified_as_a_time_parameter(tmp_path: Path) -> None:
    ea = tmp_path / "QM5_9999_target-vol"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    (ea / "QM5_9999_target-vol.mq5").write_text(
        """
        input double strategy_exit_weight_threshold = 0.02;
        input int strategy_vol_lookback = 252;
        datetime g_last_refresh = 0;
        """,
        encoding="utf-8",
    )
    (ea / "SPEC.md").write_text("Weekly target volatility rebalance.", encoding="utf-8")
    (sets / "QM5_9999_target-vol_XAUUSD.DWX_D1_backtest.set").write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\n",
        encoding="utf-8",
    )

    result = validate_path(ea)

    assert result["verdict"] == "PASS"
    assert result["findings"] == []
