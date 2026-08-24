from __future__ import annotations

import csv
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
LABEL = "QM5_35008_short-term-bollinger-reversion-system"
EA_DIR = REPO_ROOT / "framework" / "EAs" / LABEL
SOURCE_PATH = EA_DIR / f"{LABEL}.mq5"
CARD_PATH = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / "QM5_35008_short-term-bollinger-reversion-system.md"
)


def source_text() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8-sig")


def function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source)
    assert match, f"missing function {name}"
    depth = 1
    index = match.end()
    while index < len(source) and depth:
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
        index += 1
    assert depth == 0, f"unterminated function {name}"
    return source[match.end() : index - 1]


def test_approved_card_and_deterministic_registry_bindings() -> None:
    card = CARD_PATH.read_text(encoding="utf-8-sig")
    assert "ea_id: QM5_35008" in card
    assert "slug: short-term-bollinger-reversion-system" in card
    assert "g0_status: APPROVED" in card

    with (REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv").open(
        newline="", encoding="utf-8-sig"
    ) as handle:
        ea_rows = list(csv.DictReader(handle))
    row = next(row for row in ea_rows if row["ea_id"] == "35008")
    assert row["slug"] == "short-term-bollinger-reversion-system"
    assert row["status"] == "active"

    with (REPO_ROOT / "framework" / "registry" / "magic_numbers.csv").open(
        newline="", encoding="utf-8-sig"
    ) as handle:
        magic_rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "35008"]
    assert [
        (row["symbol_slot"], row["symbol"], row["magic"], row["status"])
        for row in magic_rows
    ] == [
        ("0", "EURUSD.DWX", "350080000", "active"),
        ("1", "USDCAD.DWX", "350080001", "active"),
        ("2", "EURCHF.DWX", "350080002", "active"),
    ]


def test_every_declared_input_has_a_runtime_use_site() -> None:
    source = source_text()
    declared = re.findall(
        r"^input\s+(?:\w+\s+)+(\w+)\s*=", source, flags=re.MULTILINE
    )
    assert declared
    unused = [name for name in declared if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2]
    assert unused == []


def test_realized_loss_halt_uses_closed_deals_and_balance_not_equity() -> None:
    source = source_text()
    ledger = function_body(source, "StrategyRealizedPnlToday")
    halt = function_body(source, "StrategyDailyEntryHalt")

    assert "QM_UTCToBroker(StrategyUtcDayStart(utc_now))" in ledger
    assert "HistorySelect(broker_day_start, broker_now)" in ledger
    for component in ("DEAL_PROFIT", "DEAL_SWAP", "DEAL_COMMISSION", "DEAL_FEE"):
        assert component in ledger
    assert "ACCOUNT_BALANCE" in ledger
    assert "ACCOUNT_EQUITY" not in ledger + halt
    assert "g_qm_ks_day_start_equity" not in ledger + halt
    assert "day_start_balance * strategy_daily_loss_halt_pct / 100.0" in halt
    assert "if(!StrategyRealizedPnlToday" in halt
    assert "return true;" in halt  # History failure is fail-closed for new entries.


def test_time_exit_remains_asserted_through_rollover_and_restart() -> None:
    source = source_text()
    exit_body = function_body(source, "Strategy_ExitSignal")
    prior_day_body = function_body(source, "StrategyHasPositionFromPriorUtcDay")

    assert "QM_BrokerToUTC(broker_now)" in exit_body
    assert "hhmm_utc >= strategy_exit_hhmm" in exit_body
    assert "hhmm_utc < strategy_entry_start_hhmm" in exit_body
    assert "hhmm_utc < 2355" not in exit_body
    assert "StrategyHasPositionFromPriorUtcDay(utc_now)" in exit_body
    assert "POSITION_TIME" in prior_day_body
    assert "POSITION_MAGIC" in prior_day_body
    assert "QM_BrokerToUTC(opened_broker)" in prior_day_body


def test_framework_risk_magic_mae_and_exit_ordering_contract() -> None:
    source = source_text()
    on_init = function_body(source, "OnInit")
    on_tick = function_body(source, "OnTick")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED" in on_init
    assert "QM_FrameworkMagic()" in source
    assert "350080000" not in source
    assert "StrategyParametersValid()" in on_init
    assert "strategy_max_slippage_ticks <= 3.0" in source
    assert "SYMBOL_TRADE_TICK_SIZE" in on_init
    assert "strategy_max_slippage_ticks * tick_size / point" in on_init
    assert "QM_EntryConfigure(qm_ea_id" in on_init
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_M15" in on_init
    assert "QM_FrameworkTrackOpenPositionMae();" in on_tick
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(Strategy_NoTradeFilter()) return;"
    )
    assert on_tick.index("if(Strategy_ExitSignal())") < on_tick.index(
        "if(Strategy_NoTradeFilter()) return;"
    )


def test_backtest_sets_use_fixed_risk_and_wire_all_strategy_inputs() -> None:
    source = source_text()
    strategy_inputs = re.findall(
        r"^input\s+(?:\w+\s+)+(strategy_\w+)\s*=", source, flags=re.MULTILINE
    )
    set_paths = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(set_paths) == 3

    for set_path in set_paths:
        values = {}
        for raw_line in set_path.read_text(encoding="utf-8-sig").splitlines():
            line = raw_line.strip()
            if line and not line.startswith(";") and "=" in line:
                key, value = line.split("=", 1)
                values[key] = value
        assert float(values["RISK_FIXED"]) > 0.0
        assert float(values["RISK_PERCENT"]) == 0.0
        assert values["qm_ea_id"] == "35008"
        assert set(strategy_inputs) <= values.keys()
