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
