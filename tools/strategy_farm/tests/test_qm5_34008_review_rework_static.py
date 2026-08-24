from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
LABEL = "QM5_34008_multicurrency-basket-dispersion-hedger"
EA_DIR = REPO_ROOT / "framework" / "EAs" / LABEL
SOURCE_PATH = EA_DIR / f"{LABEL}.mq5"
ARTIFACT_PATH = REPO_ROOT / "artifacts" / "qm5_34008_build_result.json"


def _source() -> str:
    return SOURCE_PATH.read_text(encoding="utf-8")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_primary_host_owns_the_single_basket_signal() -> None:
    source = _source()
    no_trade = source[source.index("bool Strategy_NoTradeFilter()") : source.index("bool Strategy_EntrySignal(")]

    assert "#define STRATEGY_PRIMARY_SLOT 0" in source
    assert "_Symbol != g_basket_symbols[STRATEGY_PRIMARY_SLOT]" in no_trade
    assert "qm_magic_slot_offset != STRATEGY_PRIMARY_SLOT" in no_trade
    assert "_Period != PERIOD_H1" in no_trade

    manifest = json.loads((EA_DIR / "basket_manifest.json").read_text(encoding="utf-8"))
    assert manifest["host_symbol"] == "EURUSD.DWX"
    assert "sole package owner" in " ".join(manifest["notes"])


def test_extrema_package_and_combined_exits_remain_card_faithful() -> None:
    source = _source()

    assert "min_idx" in source and "max_idx" in source
    assert "min_delta > -threshold || max_delta < threshold" in source
    assert source.count("QM_BasketOpenPosition(") == 2
    assert "StrategyMaxDeviationPoints(sym_a)" in source
    assert "StrategyMaxDeviationPoints(sym_b)" in source
    assert "QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, deviation_a, req_a, ticket_a)" in source
    assert "QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, deviation_b, req_b, ticket_b)" in source
    assert "qm_news_mode_legacy, 20," not in source
    assert "CloseAllPackagePositions(QM_EXIT_STRATEGY);" in source
    assert "balance * (strategy_target_profit_pct / 100.0)" in source
    assert "balance * (strategy_hard_stop_loss_pct / 100.0)" in source
    assert "if(OpenPackageCount() == 1)" in source


def test_framework_loss_limits_magic_ownership_and_management_order() -> None:
    source = _source()

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_BrokerToUTC(t)" in source
    assert "QM_KillSwitchInit(qm_ea_id," in source
    assert "strategy_daily_hard_stop_pct," in source
    assert "strategy_total_dd_stop_pct," in source
    assert "QM_FrameworkRegisterMagicSymbol(qm_ea_id, slot, g_basket_symbols[slot])" in source
    assert "QM_FrameworkDeclareExecutionContract(" in source
    assert "PERIOD_H1," in source
    assert "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE," in source
    assert "QM_IsNewBar(_Symbol, PERIOD_H1)" in source

    on_tick = source[source.index("void OnTick()") : source.index("void OnTimer()")]
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index("Strategy_NoTradeFilter()")
    assert on_tick.index("Strategy_ExitSignal();") < on_tick.index("Strategy_NoTradeFilter()")
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index("QM_FrameworkHandleFridayClose()")
    assert on_tick.index("Strategy_ExitSignal();") < on_tick.index("QM_FrameworkHandleFridayClose()")

    raw_series_lines = [line for line in source.splitlines() if "iClose(" in line]
    assert raw_series_lines
    assert all("perf-allowed" in line for line in raw_series_lines)
    assert "CopyBuffer(" not in source
    assert not re.search(r"(?i)\b(tensorflow|torch|sklearn|keras|onnx)\b", source)


def test_every_declared_strategy_input_is_wired_and_sealed_in_sets() -> None:
    source = _source()
    strategy_inputs = re.findall(r"(?m)^input\s+\S+\s+(strategy_[A-Za-z0-9_]+)\s*=", source)

    assert strategy_inputs
    assert len(strategy_inputs) == len(set(strategy_inputs))
    for name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 7
    slots: dict[str, int] = {}
    for setfile in setfiles:
        text = setfile.read_text(encoding="utf-8")
        symbol = re.search(r"(?m)^; symbol:\s*(\S+)$", text)
        slot = re.search(r"(?m)^qm_magic_slot_offset=(\d+)$", text)
        assert symbol and slot
        slots[symbol.group(1)] = int(slot.group(1))
        assert "RISK_FIXED=1000" in text
        assert "RISK_PERCENT=0" in text
        assert f"; build_hash:   {_sha256(SOURCE_PATH)}" in text
        for name in strategy_inputs:
            assert re.search(rf"(?m)^{re.escape(name)}=", text), f"{setfile.name}: {name}"

    assert slots["EURUSD.DWX"] == 0
    assert sorted(slots.values()) == list(range(7))


def test_build_receipt_binds_current_source_and_binary() -> None:
    receipt = json.loads(ARTIFACT_PATH.read_text(encoding="utf-8"))
    binary = EA_DIR / f"{LABEL}.ex5"

    assert receipt["rework_task_id"] == "72b63c06-7749-4ac4-8276-fcf7bdc02dc4"
    assert receipt["mq5_sha256"] == _sha256(SOURCE_PATH)
    assert receipt["ex5_sha256"] == _sha256(binary)
    assert receipt["compile_succeeded"] is True
    assert receipt["compile_errors"] == 0
    assert receipt["compile_warnings"] == 0
    assert receipt["build_check_passed"] is False
    assert receipt["build_check_component_checks_passed"] is True
    assert receipt["build_check_blocked_reason"] == "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert receipt["blocked_reason"].startswith("CARD_DEFECT:")
    assert receipt["compile_log_path"]
