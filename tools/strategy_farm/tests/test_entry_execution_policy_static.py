from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
QM_INCLUDE = REPO_ROOT / "framework" / "include" / "QM"
TRADE_CONTEXT = (QM_INCLUDE / "QM_TradeContext.mqh").read_text(encoding="utf-8")
RISK_SIZER = (QM_INCLUDE / "QM_RiskSizer.mqh").read_text(encoding="utf-8")
ENTRY = (QM_INCLUDE / "QM_Entry.mqh").read_text(encoding="utf-8")
TRADE_MANAGEMENT = (QM_INCLUDE / "QM_TradeManagement.mqh").read_text(encoding="utf-8")


def function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", source, re.S)
    if not match:
        raise AssertionError(f"function not found: {name}")
    start = match.end() - 1
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(source)):
        char = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]
    raise AssertionError(f"unbalanced function: {name}")


def test_send_once_policy_has_exactly_one_reachable_order_send() -> None:
    assert "enum QM_TradeSendPolicy" in TRADE_CONTEXT
    assert "QM_TRADE_SEND_RETRY_TRANSIENT = 0" in TRADE_CONTEXT
    assert "QM_TRADE_SEND_ONCE            = 1" in TRADE_CONTEXT
    assert re.search(
        r"QM_TradeContextSend\([^)]*send_policy\s*=\s*"
        r"QM_TRADE_SEND_RETRY_TRANSIENT\)",
        TRADE_CONTEXT,
        re.S,
    )

    body = function_body(TRADE_CONTEXT, "QM_TradeContextSend")
    sends = [match.start() for match in re.finditer(r"\bOrderSend\s*\(", body)]
    assert len(sends) == 3  # initial send plus the two historical transient branches
    retry_guard = body.index("send_policy == QM_TRADE_SEND_RETRY_TRANSIENT")
    assert sends[0] < retry_guard < sends[1] < sends[2]
    assert retry_guard < body.index("Sleep(200)")
    assert "send_policy == QM_TRADE_SEND_ONCE" not in body


def test_entry_and_trade_manager_thread_policy_with_retry_default() -> None:
    entry_internal = function_body(ENTRY, "QM_EntryInternal")
    assert "const QM_TradeSendPolicy send_policy" in ENTRY
    assert (
        "QM_TradeContextSend(trade_req, trade_res, broker_error_class, send_policy)"
        in entry_internal
    )
    assert ENTRY.count(
        "const QM_TradeSendPolicy send_policy = QM_TRADE_SEND_RETRY_TRANSIENT"
    ) == 2
    assert ENTRY.count("send_policy);") >= 2

    assert TRADE_MANAGEMENT.count(
        "const QM_TradeSendPolicy send_policy = QM_TRADE_SEND_RETRY_TRANSIENT"
    ) == 2
    assert TRADE_MANAGEMENT.count("send_policy);") >= 2

    legacy_tm = re.search(
        r"bool QM_TM_OpenPosition\([^)]*explicit_risk_percent[^)]*send_policy[^)]*\)"
        r"\s*\{(?P<body>.*?)\n\s*\}",
        TRADE_MANAGEMENT,
        re.S,
    )
    mode_tm = re.search(
        r"bool QM_TM_OpenPosition\([^)]*explicit_risk_mode[^)]*send_policy[^)]*\)"
        r"\s*\{(?P<body>.*?)\n\s*\}",
        TRADE_MANAGEMENT,
        re.S,
    )
    assert legacy_tm and "send_policy" in legacy_tm.group("body")
    assert mode_tm and "send_policy" in mode_tm.group("body")


def test_entry_margin_cap_uses_actual_side_and_resolved_price() -> None:
    marker = "// Entry-only exact margin rail."
    legacy, separator, entry_only = RISK_SIZER.partition(marker)
    assert separator
    assert legacy.count("double QM_LotsForRisk(") == 3
    assert "OrderCalcMargin" not in legacy

    cap = function_body(RISK_SIZER, "QM_RiskSizerCapLotsByOrderMargin")
    assert "QM_RISK_SIZER_MARGIN_HEADROOM = 0.90" in RISK_SIZER
    assert cap.count("OrderCalcMargin(order_type, symbol") == 3
    assert "requested_steps - 1" in cap
    assert "QM_RiskSizerQuantizeLots" in cap
    assert "return 0.0" in cap
    assert entry_only.count("double QM_LotsForRiskAtEntry(") == 3

    market_price = function_body(ENTRY, "QM_EntryMarketPrice")
    assert "SYMBOL_ASK" in market_price
    assert "SYMBOL_BID" in market_price

    entry_internal = function_body(ENTRY, "QM_EntryInternal")
    assert "const double entry_price = QM_EntryResolvePrice(req)" in entry_internal
    assert "QM_OrderTypeIsBuy(req.type)" in entry_internal
    assert "? ORDER_TYPE_BUY" in entry_internal
    assert ": ORDER_TYPE_SELL" in entry_internal
    assert entry_internal.count("QM_LotsForRiskAtEntry(_Symbol") == 3
    assert entry_internal.index("entry_price = QM_EntryResolvePrice") < entry_internal.index(
        "QM_LotsForRiskAtEntry(_Symbol"
    )

