from pathlib import Path

from tools.strategy_farm import compile_ea
from tools.strategy_farm import validate_build_guardrails as guardrails
from tools.strategy_farm.validate_build_guardrails import validate_path


REPO_ROOT = Path(__file__).resolve().parents[3]


def _write_session_offset_registry(tmp_path: Path) -> Path:
    registry = tmp_path / "session_offset_minutes.csv"
    registry.write_text(
        "\n".join(
            [
                "symbol,asset_class,offset_minutes,offset_min_measured,offset_max_measured,offset_source,measurement_ref,measured_utc,notes",
                "XTIUSD.DWX,commodities,61.6,60.0,61.6,measured,test,2026-08-16,test",
                "XAUUSD.DWX,commodities,60.0,,,measured,test,2026-08-16,test",
                "EURUSD.DWX,forex,0.0,,,measured,test,2026-08-16,test",
                "CADJPY.DWX,forex,0.0,,,inferred_fx_continuous,test,2026-08-16,test",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return registry


def _write_entry_grace_ea(
    tmp_path: Path,
    *,
    symbol: str,
    grace: int,
    anchor_period: str = "D1",
    set_period: str = "D1",
    operational: bool = True,
    card_grace: int | None = None,
) -> Path:
    ea = tmp_path / f"QM5_9999_entry-grace-{symbol.replace('.', '-')}"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    use = ""
    if operational:
        use = f"""
        bool Strategy_EntryWindowReady()
          {{
           const datetime entry_bar_time = iTime(_Symbol, PERIOD_{anchor_period}, 0);
           const long opening_delay = (long)(TimeCurrent() - entry_bar_time);
           return (opening_delay >= 0 &&
                   opening_delay <= (long)strategy_entry_grace_minutes * 60);
          }}
        """
    (ea / f"{ea.name}.mq5").write_text(
        f"input int strategy_entry_grace_minutes = {grace};\n{use}\n",
        encoding="utf-8",
    )
    if card_grace is not None:
        (ea / "SPEC.md").write_text(
            f"Opening entry grace: {card_grace} minutes from the D1 bar open.\n",
            encoding="utf-8",
        )
    (sets / f"{ea.name}_{symbol}_{set_period}_backtest.set").write_text(
        "\n".join(
            [
                "RISK_FIXED=1000",
                "RISK_PERCENT=0",
                f"strategy_entry_grace_minutes={grace}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return ea


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


def test_rejects_five_minute_d1_grace_for_measured_xti_offset(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(tmp_path, symbol="XTIUSD.DWX", grace=5)

    result = validate_path(ea)

    finding = next(f for f in result["findings"] if f["kind"] == "entry_grace_below_session_offset")
    assert result["verdict"] == "FAIL"
    assert finding["symbol"] == "XTIUSD.DWX"
    assert finding["minimum_grace_minutes"] == 66.6
    compile_result = compile_ea.scoped_guardrails(
        ea,
        next(ea.glob("*.mq5")),
        ["XTIUSD.DWX"],
    )
    assert compile_result["verdict"] == "FAIL"
    assert any(
        item["kind"] == "entry_grace_below_session_offset"
        for item in compile_result["findings"]
    )


def test_rejects_five_minute_d1_grace_for_measured_xau_offset(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(tmp_path, symbol="XAUUSD.DWX", grace=5)

    result = validate_path(ea)

    finding = next(f for f in result["findings"] if f["kind"] == "entry_grace_below_session_offset")
    assert result["verdict"] == "FAIL"
    assert finding["minimum_grace_minutes"] == 65.0


def test_accepts_180_minute_d1_grace_for_measured_xti_offset(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(tmp_path, symbol="XTIUSD.DWX", grace=180)

    result = validate_path(ea)

    assert result["verdict"] == "PASS"
    assert result["findings"] == []


def test_accepts_five_minute_d1_grace_for_measured_zero_offset_eurusd(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(tmp_path, symbol="EURUSD.DWX", grace=5)

    result = validate_path(ea)

    assert result["verdict"] == "PASS"
    assert result["findings"] == []


def test_intraday_anchor_is_unaffected_even_on_d1_setfile(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(
        tmp_path,
        symbol="XAUUSD.DWX",
        grace=5,
        anchor_period="H1",
        set_period="D1",
    )

    result = validate_path(ea)

    assert guardrails._entry_grace_anchor_periods(next(ea.glob("*.mq5")).read_text()) == {"H1"}
    assert result["verdict"] == "PASS"
    assert result["findings"] == []


def test_missing_registry_symbol_is_a_named_fail_closed_result(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(tmp_path, symbol="MISSING.DWX", grace=180)

    result = validate_path(ea)

    finding = next(f for f in result["findings"] if f["kind"] == "session_offset_symbol_missing")
    assert result["verdict"] == "FAIL"
    assert finding["symbol"] == "MISSING.DWX"


def test_inferred_offset_is_non_authoritative_and_fails_closed(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(tmp_path, symbol="CADJPY.DWX", grace=180)

    result = validate_path(ea)

    finding = next(f for f in result["findings"] if f["kind"] == "session_offset_non_authoritative")
    assert result["verdict"] == "FAIL"
    assert finding["offset_source"] == "inferred_fx_continuous"


def test_declared_grace_without_bar_open_clock_is_unaffected(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(
        tmp_path,
        symbol="MISSING.DWX",
        grace=5,
        operational=False,
    )

    result = validate_path(ea)

    assert result["verdict"] == "PASS"
    assert result["findings"] == []


def test_card_declared_tighter_grace_cannot_be_widened_by_source_or_setfile(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setattr(
        guardrails, "SESSION_OFFSET_REGISTRY_PATH", _write_session_offset_registry(tmp_path)
    )
    ea = _write_entry_grace_ea(
        tmp_path,
        symbol="XTIUSD.DWX",
        grace=180,
        card_grace=5,
    )

    result = validate_path(ea)

    finding = next(f for f in result["findings"] if f["kind"] == "entry_grace_below_session_offset")
    assert result["verdict"] == "FAIL"
    assert finding["declared_grace_minutes"] == 5.0
    assert any(source.endswith("SPEC.md") for source in finding["declared_grace_sources"])


def test_current_metal_sources_classify_actual_h1_and_d1_anchors() -> None:
    qm20019 = (
        REPO_ROOT
        / "framework/EAs/QM5_20019_xauxag-wkend/QM5_20019_xauxag-wkend.mq5"
    ).read_text(encoding="utf-8")
    qm20095 = (
        REPO_ROOT
        / "framework/EAs/QM5_20095_auag-mon-diff/QM5_20095_auag-mon-diff.mq5"
    ).read_text(encoding="utf-8")

    assert guardrails._entry_grace_anchor_periods(qm20019) == {"H1"}
    assert "D1" in guardrails._entry_grace_anchor_periods(qm20095)


def test_compile_cache_cannot_bypass_current_build_guardrails(
    tmp_path: Path, monkeypatch
) -> None:
    label = "QM5_9999_cached-policy-fail"
    ea = tmp_path / "EAs" / label
    ea.mkdir(parents=True)
    mq5 = ea / f"{label}.mq5"
    ex5 = ea / f"{label}.ex5"
    mq5.write_text("void OnTick() {}\n", encoding="utf-8")
    ex5.write_bytes(b"cached")
    ex5.touch()
    monkeypatch.setattr(compile_ea, "EAS_DIR", tmp_path / "EAs")
    monkeypatch.setattr(compile_ea, "REPORT_ROOT", tmp_path / "reports")
    monkeypatch.setattr(
        compile_ea,
        "_validate_build_guardrails",
        lambda _path: {
            "verdict": "FAIL",
            "findings": [{"kind": "entry_grace_below_session_offset"}],
        },
    )

    result = compile_ea.compile_ea(label)

    assert result.verdict == "BUILD_GUARDRAILS_FAILED"
    assert result.cached is False
    assert result.symbol_scope_verdict == "NOT_RUN_GUARDRAIL_FAILURE"
