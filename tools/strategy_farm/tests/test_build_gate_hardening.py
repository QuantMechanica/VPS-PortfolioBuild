from __future__ import annotations

import subprocess
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as gate


REPO_ROOT = Path(__file__).resolve().parents[3]
BUILD_CHECK = REPO_ROOT / "framework" / "scripts" / "build_check.ps1"
LABEL = "QM5_99001_gate-fixture"


CARD = """
# Gate fixture

3. **Daily Loss Limit**: Account daily realized loss >= 2.0%.
* **Maximum Daily Drawdown Hard Stop**: 2.5% of starting balance.
* **Maximum Total Drawdown Stop**: 5.0% of initial equity.
* Rollover blackout: 23:55 to 00:05 GMT.
"""


PASSING_SOURCE = r"""
input double strategy_daily_loss_limit_pct = 2.0;
input double strategy_daily_hard_stop_pct = 2.5;
input double strategy_total_dd_stop_pct = 5.0;
input double strategy_sl_buffer_pips = 3.0;

bool Strategy_NoTradeFilter()
  {
   const double limits = strategy_daily_loss_limit_pct +
                         strategy_daily_hard_stop_pct +
                         strategy_total_dd_stop_pct;
   return limits <= 0.0;
  }

void Strategy_ManageOpenPosition() { }
bool Strategy_ExitSignal() { return false; }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal()) return;
   if(Strategy_NoTradeFilter()) return;
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime utc;
   TimeToStruct(utc_now, utc);
   if(utc.hour == 23) return;
   const double distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);
  }
"""


def write_fixture(
    tmp_path: Path,
    source: str,
    card: str = CARD,
    symbol: str = "EURUSD.DWX",
) -> tuple[Path, Path]:
    ea_dir = tmp_path / "framework" / "EAs" / LABEL
    card_dir = tmp_path / "strategy-seeds" / "cards"
    registry_dir = tmp_path / "framework" / "registry"
    sets_dir = ea_dir / "sets"
    tools_dir = tmp_path / "tools" / "strategy_farm"
    ea_dir.mkdir(parents=True)
    card_dir.mkdir(parents=True)
    registry_dir.mkdir(parents=True)
    sets_dir.mkdir(parents=True)
    tools_dir.mkdir(parents=True)
    source_path = ea_dir / f"{LABEL}.mq5"
    card_path = card_dir / f"{LABEL}.md"
    source_path.write_text(source, encoding="utf-8")
    card_path.write_text(card, encoding="utf-8")
    (registry_dir / "dwx_symbol_matrix.csv").write_text(
        "symbol,canonical_name_verified\nEURUSD.DWX,true\n",
        encoding="utf-8",
    )
    (registry_dir / "magic_numbers.csv").write_text(
        "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n"
        f"99001,gate-fixture,0,{symbol},990010000,2026-08-22,pytest,active\n",
        encoding="utf-8",
    )
    (sets_dir / f"{LABEL}_{symbol}_H1_backtest.set").write_text(
        f"; symbol: {symbol}\nRISK_FIXED=1000\nRISK_PERCENT=0\n",
        encoding="utf-8",
    )
    (tools_dir / "include_mirror.py").write_text(
        "#!/usr/bin/env python3\nraise SystemExit(0)\n",
        encoding="utf-8",
    )
    return source_path, card_path


def failure_codes(result: dict) -> str:
    return "\n".join(result["failures"])


def test_compile_worker_binding_uses_named_splatting() -> None:
    source = BUILD_CHECK.read_text(encoding="utf-8")

    assert "$compileParameters = @{" in source
    assert '$compileParameters["EALabel"] = $EALabel' in source
    assert '$compileParameters["CompileWorkItemId"] = $CompileWorkItemId' in source
    assert '$compileParameters["ClaimedTerminal"] = $ClaimedTerminal' in source
    assert "@compileParameters 2>&1" in source
    assert "$compileArguments = @(" not in source


def test_compile_worker_preserves_structured_failure_receipt() -> None:
    build_check = BUILD_CHECK.read_text(encoding="utf-8")
    compile_one = (
        REPO_ROOT / "framework" / "scripts" / "compile_one.ps1"
    ).read_text(encoding="utf-8")

    assert '$savedErrorActionPreference = $ErrorActionPreference' in build_check
    assert '$ErrorActionPreference = "Continue"' in build_check
    assert '$outputLines = @(& $ResolvedCompileScriptPath @compileParameters 2>&1)' in build_check
    assert '$ErrorActionPreference = $savedErrorActionPreference' in build_check
    assert "Write-Error $_ -ErrorAction Continue" in compile_one
    assert 'Write-Output "compile_one.reason_class=$reasonClass"' in compile_one
    assert 'Write-Output "compile_one.summary=$summaryCsvPath"' in compile_one


def test_d2_loss_limit_matching_and_mismatching_fixtures(tmp_path: Path) -> None:
    source, card = write_fixture(tmp_path, PASSING_SOURCE)
    passing = gate.analyze_file(source, card)
    assert "EA_CARD_LOSS_LIMIT" not in failure_codes(passing)

    source.write_text(
        PASSING_SOURCE.replace("strategy_daily_hard_stop_pct = 2.5", "strategy_daily_hard_stop_pct = 3.0"),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_CARD_LOSS_LIMIT_MISMATCH" in failure_codes(failing)


def test_d3_pip_helper_correct_and_double_conversion_fixtures(tmp_path: Path) -> None:
    source, card = write_fixture(tmp_path, PASSING_SOURCE)
    passing = gate.analyze_file(source, card)
    assert "EA_PIP_DOUBLE_CONVERSION" not in failure_codes(passing)

    source.write_text(
        PASSING_SOURCE.replace(
            "(int)strategy_sl_buffer_pips)",
            "(int)MathRound(strategy_sl_buffer_pips * 10.0))",
        ),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_PIP_DOUBLE_CONVERSION" in failure_codes(failing)


def test_d4_management_before_guard_passes_and_early_open_guard_fails(tmp_path: Path) -> None:
    source, card = write_fixture(tmp_path, PASSING_SOURCE)
    passing = gate.analyze_file(source, card)
    assert "EA_MANAGEMENT_UNREACHABLE_OPEN_GUARD" not in failure_codes(passing)

    failing_source = PASSING_SOURCE.replace(
        "return limits <= 0.0;",
        "return QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0;",
    ).replace(
        "Strategy_ManageOpenPosition();\n   if(Strategy_ExitSignal()) return;\n   if(Strategy_NoTradeFilter()) return;",
        "if(Strategy_NoTradeFilter()) return;\n   Strategy_ManageOpenPosition();\n   if(Strategy_ExitSignal()) return;",
    )
    source.write_text(failing_source, encoding="utf-8")
    failing = gate.analyze_file(source, card)
    assert "EA_MANAGEMENT_UNREACHABLE_OPEN_GUARD" in failure_codes(failing)


def test_d5_raw_broker_hour_fails_and_utc_conversion_passes(tmp_path: Path) -> None:
    source, card = write_fixture(tmp_path, PASSING_SOURCE)
    passing = gate.analyze_file(source, card)
    assert "EA_BROKER_TIME_USED_FOR_GMT_WINDOW" not in failure_codes(passing)

    source.write_text(
        PASSING_SOURCE.replace(
            "const datetime utc_now = QM_BrokerToUTC(TimeCurrent());",
            "const datetime utc_now = TimeCurrent();",
        ),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_BROKER_TIME_USED_FOR_GMT_WINDOW" in failure_codes(failing)


def test_d6_bars_calculated_first_fixture_fails_but_helper_and_decoys_pass(
    tmp_path: Path,
) -> None:
    source, card = write_fixture(tmp_path, PASSING_SOURCE)
    source.write_text(
        PASSING_SOURCE
        + r'''
// BarsCalculated(comment_only_handle) must not enter the cohort.
string documentary_example = "BarsCalculated(string_only_handle)";
bool IndicatorReady(const int handle)
  {
   return BarsCalculated(handle) >= 50;
  }
''',
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_BARSCALCULATED_FIRST" in failure_codes(failing)
    assert failure_codes(failing).count("EA_BARSCALCULATED_FIRST") == 1

    source.write_text(
        PASSING_SOURCE
        + r'''
// BarsCalculated(comment_only_handle) must not enter the cohort.
string documentary_example = "BarsCalculated(string_only_handle)";
bool IndicatorReady(const int handle)
  {
   return QM_IndicatorWarmupReady(handle, 0, 1, 50, "fixture");
  }
''',
        encoding="utf-8",
    )
    passing = gate.analyze_file(source, card)
    assert "EA_BARSCALCULATED_FIRST" not in failure_codes(passing)


def test_d6_canonical_eas_have_no_raw_bars_calculated_call_sites() -> None:
    rows = gate.analyze(REPO_ROOT)["rows"]
    failures = [
        failure
        for row in rows
        for failure in row["failures"]
        if failure.startswith("EA_BARSCALCULATED_FIRST:")
    ]
    assert failures == []


def test_d6_framework_helper_primes_before_readiness_and_bounds_retries() -> None:
    helper_path = REPO_ROOT / "framework" / "include" / "QM" / "QM_Indicators.mqh"
    helper = helper_path.read_text(encoding="utf-8")
    start = helper.index("bool QM_IndicatorWarmupProbe(")
    end = helper.index("bool QM_IndicatorWarmupReady(", start)
    probe = helper[start:end]
    assert probe.index("CopyBuffer(") < probe.index("BarsCalculated(")
    assert "last_probe_bar == probe_bar" in probe
    assert "persistent_error_candidate" in probe
    assert "calculated_out < 0" in probe
    assert "QM_INDICATOR_WARMUP_ERROR_AFTER_BARS" in probe
    assert "SETUP_DATA_MISSING" in probe
    assert "qm.indicator-first-tradable-bar/v1" in helper


def test_d7_framework_mae_hook_pass_and_fail_fixtures(tmp_path: Path) -> None:
    source, card = write_fixture(tmp_path, PASSING_SOURCE)
    passing = gate.analyze_file(source, card)
    assert "EA_Q08_MAE_HOOK_MISSING" not in failure_codes(passing)

    source.write_text(
        PASSING_SOURCE.replace("   QM_FrameworkTrackOpenPositionMae();\n", ""),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_Q08_MAE_HOOK_MISSING" in failure_codes(failing)


def test_d8_cached_new_bar_passes_and_second_same_key_gate_fails(tmp_path: Path) -> None:
    passing_source = r"""
void Strategy_Refresh() { }
bool Strategy_EntrySignal(QM_EntryRequest &req) { return false; }
void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const bool new_bar = QM_IsNewBar(_Symbol, _Period);
   if(new_bar) Strategy_Refresh();
   if(!new_bar) return;
   QM_EntryRequest req = {};
   Strategy_EntrySignal(req);
  }
"""
    source, card = write_fixture(tmp_path, passing_source)
    passing = gate.analyze_file(source, card)
    assert "EA_ENTRY_DOUBLE_NEW_BAR_GATE" not in failure_codes(passing)

    source.write_text(
        passing_source.replace(
            "const bool new_bar = QM_IsNewBar(_Symbol, _Period);\n"
            "   if(new_bar) Strategy_Refresh();\n"
            "   if(!new_bar) return;",
            "if(QM_IsNewBar(_Symbol, _Period)) Strategy_Refresh();\n"
            "   if(!QM_IsNewBar(_Symbol, _Period)) return;",
        ),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_ENTRY_DOUBLE_NEW_BAR_GATE" in failure_codes(failing)


def test_d9_trade_request_zero_init_pass_and_bare_request_fails(tmp_path: Path) -> None:
    passing_source = PASSING_SOURCE + r"""
bool SendRequest()
  {
   MqlTradeRequest request;
   ZeroMemory(request);
   MqlTradeResult result = {};
   return OrderSend(request, result);
  }
"""
    source, card = write_fixture(tmp_path, passing_source)
    passing = gate.analyze_file(source, card)
    assert "EA_TRADE_REQUEST_UNINITIALIZED" not in failure_codes(passing)

    source.write_text(
        passing_source.replace("   ZeroMemory(request);\n", ""),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_TRADE_REQUEST_UNINITIALIZED" in failure_codes(failing)
    assert "MqlTradeRequest request" in failure_codes(failing)

    source.write_text(
        PASSING_SOURCE.replace(
            "   Strategy_ManageOpenPosition();",
            "   QM_EntryRequest req;\n"
            "   if(Strategy_EntrySignal(req)) QM_TM_OpenPosition(req);\n"
            "   Strategy_ManageOpenPosition();",
        ),
        encoding="utf-8",
    )
    qm_entry_failing = gate.analyze_file(source, card)
    assert "QM_EntryRequest req" in failure_codes(qm_entry_failing)


def test_d10_indicator_buffer_bound_pass_and_fail_fixtures(tmp_path: Path) -> None:
    failing_source = r"""
double ComputeIndicator(const int period)
  {
   const int buffer_count = period + 4;
   double buffer[];
   ArrayResize(buffer, buffer_count);
   double total = 0.0;
   for(int i = 0; i < period + 6; ++i)
     {
      total += buffer[i];
     }
   return total;
  }
"""
    source, card = write_fixture(tmp_path, failing_source)
    failing = gate.analyze_file(source, card)
    assert "EA_INDICATOR_BUFFER_UNBOUNDED" in failure_codes(failing)

    source.write_text(
        failing_source.replace("i < period + 6", "i < ArraySize(buffer)"),
        encoding="utf-8",
    )
    passing = gate.analyze_file(source, card)
    assert "EA_INDICATOR_BUFFER_UNBOUNDED" not in failure_codes(passing)

    copybuffer_pass = r"""
bool ReadIndicator(const int handle)
  {
   double values[];
   const int copied = CopyBuffer(handle, 0, 0, 3, values);
   if(copied < 3) return false;
   return values[2] > 0.0;
  }
"""
    source.write_text(copybuffer_pass, encoding="utf-8")
    passing = gate.analyze_file(source, card)
    assert "EA_INDICATOR_BUFFER_UNBOUNDED" not in failure_codes(passing)

    source.write_text(
        copybuffer_pass.replace("   if(copied < 3) return false;\n", ""),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_INDICATOR_BUFFER_UNBOUNDED" in failure_codes(failing)


def test_d11_canonical_setfile_and_magic_symbol_pass(tmp_path: Path) -> None:
    write_fixture(tmp_path, PASSING_SOURCE)

    result = gate.analyze(tmp_path, LABEL)

    assert "EA_SYMBOL_NOT_IN_DWX_MATRIX" not in failure_codes(result)
    symbol_rows = result["build_symbol_checks"][0]["symbols"]
    assert symbol_rows == [
        {
            "symbol": "EURUSD.DWX",
            "matrix_exact_match": True,
            "canonical_case": "EURUSD.DWX",
            "origins": [
                "magic_registry:line=2:slot=0:status=active",
                f"setfile_content:framework/EAs/{LABEL}/sets/{LABEL}_EURUSD.DWX_H1_backtest.set:1",
                f"setfile_name:framework/EAs/{LABEL}/sets/{LABEL}_EURUSD.DWX_H1_backtest.set",
            ],
        }
    ]


def test_d11_phantom_setfile_and_magic_symbol_fail_closed(tmp_path: Path) -> None:
    write_fixture(tmp_path, PASSING_SOURCE, symbol="GER40.DWX")

    result = gate.analyze(tmp_path, LABEL)

    failures = failure_codes(result)
    assert "EA_SYMBOL_NOT_IN_DWX_MATRIX" in failures
    assert "GER40.DWX" in failures
    assert "GDAXI.DWX" in failures
    assert "setfile_name:" in failures
    assert "setfile_content:" in failures
    assert "magic_registry:" in failures


def test_d11_missing_matrix_fails_closed(tmp_path: Path) -> None:
    write_fixture(tmp_path, PASSING_SOURCE)
    (tmp_path / "framework" / "registry" / "dwx_symbol_matrix.csv").unlink()

    result = gate.analyze(tmp_path, LABEL)

    assert "EA_DWX_SYMBOL_MATRIX_MISSING" in failure_codes(result)


def test_d13_pending_order_type_pass_and_market_substitution_fail(
    tmp_path: Path,
) -> None:
    pending_card = CARD + """

### Entry
Place a BUY-STOP above structure and a SELL-STOP below structure.
"""
    pending_source = PASSING_SOURCE + r"""
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   if(req.price < 0.0)
      req.type = QM_SELL_STOP;
   return false;
  }
"""
    source, card = write_fixture(tmp_path, pending_source, pending_card)
    passing = gate.analyze_file(source, card)
    assert "EA_CARD_PENDING_ORDER_TYPE_MISMATCH" not in failure_codes(passing)
    assert passing["checks"]["D13_pending_entry_type"]["implemented"] == [
        "BUY_STOP",
        "SELL_STOP",
    ]

    source.write_text(
        pending_source.replace("QM_BUY_STOP", "QM_BUY").replace(
            "QM_SELL_STOP", "QM_SELL"
        ),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert failure_codes(failing).count("EA_CARD_PENDING_ORDER_TYPE_MISMATCH") == 2


def test_d14_copybuffer_direction_pass_and_inversion_fail(tmp_path: Path) -> None:
    direction_card = CARD + """

- Macro-bias gate: SMA(200,H4) must be rising for long and falling for short.
"""
    direction_source = PASSING_SOURCE + r"""
bool Strategy_MacroBias(const int direction)
  {
   double sma_values[2];
   if(CopyBuffer(g_sma, 0, 1, 2, sma_values) < 2) return false;
   if(direction > 0) return sma_values[1] >= sma_values[0];
   if(direction < 0) return sma_values[1] <= sma_values[0];
   return false;
  }
"""
    source, card = write_fixture(tmp_path, direction_source, direction_card)
    passing = gate.analyze_file(source, card)
    assert "EA_CARD_SMA_DIRECTION_INVERTED" not in failure_codes(passing)
    assert {
        item["direction"]
        for item in passing["checks"]["D14_directional_series_order"][
            "satisfied_evidence"
        ]
    } == {"RISING", "FALLING"}

    source.write_text(
        direction_source.replace("sma_values[1] >= sma_values[0]", "sma_values[0] >= sma_values[1]")
        .replace("sma_values[1] <= sma_values[0]", "sma_values[0] <= sma_values[1]"),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert failure_codes(failing).count("EA_CARD_SMA_DIRECTION_INVERTED") == 2


def test_d15_news_duration_and_entry_only_placement_fixtures(tmp_path: Path) -> None:
    news_card = CARD + """

- **News filter**: skip entry within ±3 H1 bars of high-impact news.
"""
    passing_source = r"""
input QM_NewsTemporalMode qm_news_temporal = QM_NEWS_TEMPORAL_OFF;
void Strategy_ManageOpenPosition() { }
bool Strategy_ExitSignal() { return false; }
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return !QM_NewsInWindow(TimeGMT(), _Symbol, 180, 180, "HIGH");
  }
void OnTick()
  {
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal()) return;
   QM_EntryRequest req = {};
   Strategy_EntrySignal(req);
  }
"""
    source, card = write_fixture(tmp_path, passing_source, news_card)
    passing = gate.analyze_file(source, card)
    assert "EA_CARD_NEWS_WINDOW_MISMATCH" not in failure_codes(passing)
    assert "EA_CARD_NEWS_BLOCKS_MANAGEMENT" not in failure_codes(passing)

    failing_source = r"""
input QM_NewsTemporalMode qm_news_temporal = QM_NEWS_TEMPORAL_PRE30_POST30;
void Strategy_ManageOpenPosition() { }
bool Strategy_ExitSignal() { return false; }
void OnTick()
  {
   bool news_allows = QM_NewsAllowsTrade2(_Symbol, TimeCurrent(), qm_news_temporal, QM_NEWS_COMPLIANCE_DXZ);
   if(!news_allows) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal()) return;
  }
"""
    source.write_text(failing_source, encoding="utf-8")
    failing = gate.analyze_file(source, card)
    assert "EA_CARD_NEWS_WINDOW_MISMATCH" in failure_codes(failing)
    assert "EA_CARD_NEWS_BLOCKS_MANAGEMENT" in failure_codes(failing)


def test_d17_explicit_card_universe_pass_and_extra_symbol_fail(tmp_path: Path) -> None:
    universe_card = CARD + "\n- Target symbols: EURUSD.DWX.\n"
    write_fixture(tmp_path, PASSING_SOURCE, universe_card)
    passing = gate.analyze(tmp_path, LABEL)
    assert "EA_SYMBOL_NOT_IN_CARD_UNIVERSE" not in failure_codes(passing)

    (tmp_path / "framework" / "registry" / "dwx_symbol_matrix.csv").write_text(
        "symbol,canonical_name_verified\nEURUSD.DWX,true\nUSDJPY.DWX,true\n",
        encoding="utf-8",
    )
    (tmp_path / "framework" / "registry" / "magic_numbers.csv").write_text(
        "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n"
        "99001,gate-fixture,0,USDJPY.DWX,990010000,2026-08-22,pytest,active\n",
        encoding="utf-8",
    )
    failing = gate.analyze(tmp_path, LABEL)
    assert "EA_SYMBOL_NOT_IN_CARD_UNIVERSE" in failure_codes(failing)
    assert "EA_SYMBOL_NOT_IN_DWX_MATRIX" not in failure_codes(failing)


def test_d18_descending_append_ordering_pass_and_impossible_guard_fail(
    tmp_path: Path,
) -> None:
    ordering_source = r"""
struct Pivot { int shift; };
void FillPivots(Pivot &low_pivots[])
  {
   for(int s = 20; s >= 1; --s)
     {
      const int size = ArraySize(low_pivots);
      ArrayResize(low_pivots, size + 1);
      low_pivots[size].shift = s;
     }
  }
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Pivot lows[];
   FillPivots(lows);
   const int count = ArraySize(lows);
   for(int i3 = 0; i3 < count - 1; ++i3)
     {
      const int s_t3 = lows[i3].shift;
      for(int i2 = i3 + 1; i2 < count; ++i2)
        {
         const int s_t2 = lows[i2].shift;
         if(s_t2 >= s_t3) continue;
         return true;
        }
     }
   return false;
  }
"""
    source, card = write_fixture(tmp_path, ordering_source)
    passing = gate.analyze_file(source, card)
    assert "EA_DETERMINISTIC_ZERO_TRADE_ORDERING" not in failure_codes(passing)

    source.write_text(
        ordering_source.replace("if(s_t2 >= s_t3)", "if(s_t2 <= s_t3)"),
        encoding="utf-8",
    )
    failing = gate.analyze_file(source, card)
    assert "EA_DETERMINISTIC_ZERO_TRADE_ORDERING" in failure_codes(failing)


def test_semantic_predicates_have_real_satisfying_sources() -> None:
    london_label = "QM5_20045_london-box"
    london_source = next((REPO_ROOT / "framework" / "EAs" / london_label).glob("*.mq5"))
    london_card = gate.find_card(REPO_ROOT, london_label)
    london = gate.analyze_file(london_source, london_card)
    assert london["failures"] == []
    assert london["checks"]["D13_pending_entry_type"]["implemented"] == [
        "BUY_STOP",
        "SELL_STOP",
    ]
    assert "EA_CARD_PENDING_ORDER_TYPE_MISMATCH" not in failure_codes(london)

    news_label = "QM5_10000_ff-tasayc-cci-breakout"
    news_source = next((REPO_ROOT / "framework" / "EAs" / news_label).glob("*.mq5"))
    news = gate.analyze_file(news_source, gate.find_card(REPO_ROOT, news_label))
    assert news["checks"]["D15_news_entry_contract"]["literal_windows"] == [
        {
            "source": "entry_call",
            "before_minutes": 120,
            "after_minutes": 120,
            "line": 71,
        }
    ]
    assert "EA_CARD_NEWS_WINDOW_MISMATCH" not in failure_codes(news)

    direction_label = "QM5_10418_et-sma5-trend"
    direction_source = next(
        (REPO_ROOT / "framework" / "EAs" / direction_label).glob("*.mq5")
    )
    direction = gate.analyze_file(
        direction_source, gate.find_card(REPO_ROOT, direction_label)
    )
    assert {
        item["direction"]
        for item in direction["checks"]["D14_directional_series_order"][
            "satisfied_evidence"
        ]
    } == {"RISING", "FALLING"}
    assert "EA_CARD_SMA_DIRECTION_INVERTED" not in failure_codes(direction)

    ordering_label = "QM5_1417_classical-pennant-continuation-h1"
    ordering_path = next(
        (REPO_ROOT / "framework" / "EAs" / ordering_label).glob("*.mq5")
    )
    raw = gate.read_text_compatible(ordering_path)
    ordering_source = gate.SourceFile(
        ordering_path.resolve(), raw, gate.strip_comments_preserve_lines(raw)
    )
    ordering_failures, ordering_detail = gate.check_deterministic_zero_trade_ordering(
        ordering_source
    )
    assert ordering_failures == []
    assert {row["array"] for row in ordering_detail["descending_shift_arrays"]} >= {
        "highs",
        "lows",
    }


def test_nonmechanizable_semantic_classes_name_required_card_declarations() -> None:
    scope = gate.SEMANTIC_AUTOMATION_SCOPE
    for key in (
        "D12_invented_inputs_or_proxies",
        "D16_restart_safe_management",
    ):
        assert scope[key]["mechanizable"] is False
        assert scope[key]["missing_card_declaration"]


def test_semantic_regression_catches_previously_invisible_1417_and_1425() -> None:
    expected = {
        "QM5_1417_classical-pennant-continuation-h1": {
            "EA_CARD_PENDING_ORDER_TYPE_MISMATCH",
            "EA_CARD_SMA_DIRECTION_INVERTED",
            "EA_CARD_NEWS_WINDOW_MISMATCH",
            "EA_CARD_NEWS_BLOCKS_MANAGEMENT",
        },
        "QM5_1425_classical-triple-bottom-reversal-h4": {
            "EA_CARD_PENDING_ORDER_TYPE_MISMATCH",
            "EA_CARD_SMA_DIRECTION_INVERTED",
            "EA_CARD_NEWS_WINDOW_MISMATCH",
            "EA_CARD_NEWS_BLOCKS_MANAGEMENT",
            "EA_DETERMINISTIC_ZERO_TRADE_ORDERING",
        },
    }
    for label, expected_codes in expected.items():
        source = next((REPO_ROOT / "framework" / "EAs" / label).glob("*.mq5"))
        result = gate.analyze_file(source, gate.find_card(REPO_ROOT, label))
        actual_codes = {failure.split(":", 1)[0] for failure in result["failures"]}
        assert expected_codes <= actual_codes


def test_d17_real_clean_card_and_build_universe_satisfy() -> None:
    label = "QM5_20045_london-box"
    matrix, matrix_failures, _ = gate.load_dwx_symbol_matrix(
        REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
    )
    magic, magic_failures, _ = gate.load_magic_build_symbols(
        REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
    )
    assert matrix_failures == []
    assert magic_failures == []
    result = gate.check_build_symbols(
        REPO_ROOT,
        REPO_ROOT / "framework" / "EAs" / label,
        matrix,
        True,
        magic,
        gate.find_card(REPO_ROOT, label),
    )
    assert result["card_target_symbols"] == ["EURGBP.DWX", "GBPUSD.DWX"]
    assert "EA_SYMBOL_NOT_IN_CARD_UNIVERSE" not in failure_codes(result)


def run_build_check(tmp_path: Path) -> subprocess.CompletedProcess[str]:
    report = tmp_path / "reports"
    command = [
        "pwsh",
        "-NoProfile",
        "-File",
        str(BUILD_CHECK),
        "-RepoRoot",
        str(tmp_path),
        "-EALabel",
        LABEL,
        "-ReportRoot",
        str(report),
        "-SkipCompile",
        "-SkipMagicCheck",
        "-SkipSetValidation",
        "-SkipLoggerSchema",
        "-SkipForbiddenScan",
        "-SkipInputGroupCheck",
        "-SkipPerfStaticCheck",
        "-SkipMaeHookCheck",
    ]
    return subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")


def test_build_check_applies_hardening_pass_and_fail_fixtures(tmp_path: Path) -> None:
    source, _ = write_fixture(tmp_path, PASSING_SOURCE)
    passing = run_build_check(tmp_path)
    assert passing.returncode == 0, passing.stdout + passing.stderr
    assert "build_check.result=PASS" in passing.stdout

    source.write_text(
        PASSING_SOURCE.replace(
            "(int)strategy_sl_buffer_pips)",
            "(int)MathRound(strategy_sl_buffer_pips * 10.0))",
        ),
        encoding="utf-8",
    )
    failing = run_build_check(tmp_path)
    assert failing.returncode == 1
    assert "EA_PIP_DOUBLE_CONVERSION" in failing.stdout + failing.stderr
    assert "build_check.result=FAIL" in failing.stdout


def test_build_check_rejects_d11_phantom_symbol(tmp_path: Path) -> None:
    write_fixture(tmp_path, PASSING_SOURCE, symbol="GER40.DWX")

    failing = run_build_check(tmp_path)

    assert failing.returncode == 1
    assert "EA_SYMBOL_NOT_IN_DWX_MATRIX" in failing.stdout + failing.stderr
    assert "build_check.result=FAIL" in failing.stdout
