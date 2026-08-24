from __future__ import annotations

import hashlib
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_DIR = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_41009_volume-profile-value-area-rejection"
)
EA_PATH = EA_DIR / "QM5_41009_volume-profile-value-area-rejection.mq5"
SET_PATHS = sorted((EA_DIR / "sets").glob("*_backtest.set"))


def source() -> str:
    return EA_PATH.read_text(encoding="utf-8-sig")


def function_body(code: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", code)
    assert match is not None, f"missing function {name}"
    start = match.end() - 1
    depth = 0
    for offset in range(start, len(code)):
        if code[offset] == "{":
            depth += 1
        elif code[offset] == "}":
            depth -= 1
            if depth == 0:
                return code[start + 1 : offset]
    raise AssertionError(f"unterminated function {name}")


def assignments(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


def test_rejected_card_drift_and_execution_contract_are_repaired() -> None:
    code = source()
    entry = function_body(code, "Strategy_EntrySignal")
    on_init = function_body(code, "OnInit")

    assert "RISK_PERCENT               = 0.0;" in code
    assert "QM_FrameworkDeclareExecutionContract(" in on_init
    assert "PERIOD_M5" in on_init
    assert "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE" in on_init
    assert "QM_BrokerToUTC(TimeCurrent())" in function_body(
        code, "Strategy_NoTradeFilter"
    )
    assert "g_prior_poc <= ask" in entry
    assert "g_prior_poc >= bid" in entry
    assert "req.tp = g_prior_poc;" in entry
    assert "1.8 *" not in entry


def test_all_three_loss_limits_and_three_tick_slippage_are_enforced() -> None:
    code = source()
    no_trade = function_body(code, "Strategy_NoTradeFilter")
    capital = function_body(code, "Strategy_CapitalPreservationCheck")
    on_init = function_body(code, "OnInit")

    assert "g_daily_realized_loss_pct >= InpDailyRealizedLossHaltPct" in no_trade
    assert "daily_drawdown_pct >= InpDailyHardStopPct" in capital
    assert "QM_KillSwitchTrip(KS_DAILY_LOSS" in capital
    assert "total_drawdown_pct >= InpTotalDrawdownStopPct" in capital
    assert 'QM_KillSwitchTrip("KS_TOTAL_DRAWDOWN"' in capital
    assert "InpSlippageTicks * tick_size / point" in function_body(
        code, "Strategy_SlippageDeviationPoints"
    )
    assert "QM_EntryConfigure" in on_init


def test_profile_capacity_is_bounded_without_the_rejected_500_bucket_cap() -> None:
    code = source()
    profile = function_body(code, "BuildPriorProfile")

    capacity = re.search(r"#define\s+STRATEGY_MAX_PROFILE_BUCKETS\s+(\d+)", code)
    assert capacity is not None
    assert int(capacity.group(1)) >= 1_000_000
    assert "n_buckets > 500" not in profile
    assert "raw_bucket_count >= STRATEGY_MAX_PROFILE_BUCKETS" in profile
    assert "ArrayResize(vol, n_buckets) != n_buckets" in profile
    assert "poc_idx >= ArraySize(vol)" in profile
    assert "hi_idx >= ArraySize(vol)" in profile
    assert "lo_idx >= ArraySize(vol)" in profile


def test_every_declared_input_is_wired_and_backtest_sets_are_complete() -> None:
    code = source()
    source_hash = hashlib.sha256(EA_PATH.read_bytes()).hexdigest()
    input_names = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    assert input_names
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ] == []

    assert len(SET_PATHS) == 2
    for set_path in SET_PATHS:
        text = set_path.read_text(encoding="utf-8-sig")
        values = assignments(set_path)
        assert f"; build_hash:   {source_hash}" in text
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["InpDailyRealizedLossHaltPct"] == "2.0"
        assert values["InpDailyHardStopPct"] == "2.5"
        assert values["InpTotalDrawdownStopPct"] == "5.0"
        assert values["InpSlippageTicks"] == "3.0"


def test_framework_chain_mae_magic_and_forbidden_surfaces() -> None:
    code = source()
    on_tick = function_body(code, "OnTick")

    assert "#include <QM/QM_Common.mqh>" in code
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "Strategy_NoTradeFilter()"
    )
    assert "QM_FrameworkMagic()" in code
    assert "QM_TM_OpenPosition(req, out_ticket);" in on_tick
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", code, re.IGNORECASE)
    assert "OrderSend(" not in code
