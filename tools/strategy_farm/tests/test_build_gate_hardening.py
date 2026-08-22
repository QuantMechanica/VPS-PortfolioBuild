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


def write_fixture(tmp_path: Path, source: str, card: str = CARD) -> tuple[Path, Path]:
    ea_dir = tmp_path / "framework" / "EAs" / LABEL
    card_dir = tmp_path / "strategy-seeds" / "cards"
    ea_dir.mkdir(parents=True)
    card_dir.mkdir(parents=True)
    source_path = ea_dir / f"{LABEL}.mq5"
    card_path = card_dir / f"{LABEL}.md"
    source_path.write_text(source, encoding="utf-8")
    card_path.write_text(card, encoding="utf-8")
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
