from __future__ import annotations

import json
import math
import re
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
QM = ROOT / "framework" / "include" / "QM"
RESERVATION = (QM / "QM_AccountRiskReservation.mqh").read_text(encoding="utf-8")
TRADE_CONTEXT = (QM / "QM_TradeContext.mqh").read_text(encoding="utf-8")
RUNTIME = (QM / "QM_RuntimeExecutionContract.mqh").read_text(encoding="utf-8")
COMMON = (QM / "QM_Common.mqh").read_text(encoding="utf-8")
ENTRY = (QM / "QM_Entry.mqh").read_text(encoding="utf-8")
EVIDENCE = (
    ROOT
    / "docs"
    / "ops"
    / "evidence"
    / "2026-08-22_sp_c2_three_ea_reservation.jsonl"
)


def _function_body(source: str, name: str) -> str:
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


@dataclass(frozen=True)
class Exposure:
    owner: str
    magic: int
    risk_money: float | None
    kind: str


class AtomicRiskOracle:
    """Executable specification independent of the MQL implementation."""

    def __init__(self, cap_money: float, exposures: list[Exposure] | None = None):
        self.cap_money = cap_money
        self.exposures = list(exposures or [])
        self.events: list[dict[str, object]] = []
        self._lock = threading.Lock()
        self._sequence = 0

    def submit(
        self,
        ea: str,
        risk_money: float,
        *,
        magic: int,
        broker_accepts: bool = True,
    ) -> dict[str, object]:
        with self._lock:
            self._sequence += 1
            unknown = any(
                row.risk_money is None
                or not math.isfinite(row.risk_money)
                or row.risk_money <= 0
                for row in self.exposures
            )
            existing = sum(row.risk_money or 0.0 for row in self.exposures)
            projected = existing + risk_money
            event: dict[str, object] = {
                "evidence_kind": "DETERMINISTIC_UNIT_ORACLE_NOT_LIVE",
                "scenario": "SIMULTANEOUS_THREE_EA_ENTRY",
                "sequence": self._sequence,
                "ea": ea,
                "magic": magic,
                "existing_risk_money": round(existing, 2),
                "request_risk_money": round(risk_money, 2),
                "projected_risk_money": round(projected, 2),
                "cap_money": round(self.cap_money, 2),
            }
            if unknown or not math.isfinite(risk_money) or risk_money <= 0:
                event.update(
                    accepted=False,
                    event="ACCOUNT_RISK_ORDER_BLOCKED",
                    reason="ACCOUNT_RISK_INVENTORY_UNKNOWN",
                )
            elif projected > self.cap_money + 0.005:
                event.update(
                    accepted=False,
                    event="ACCOUNT_RISK_ORDER_BLOCKED",
                    reason="ACCOUNT_RISK_OVER_BUDGET",
                )
            elif not broker_accepts:
                event.update(
                    accepted=False,
                    event="ACCOUNT_RISK_RESERVATION_RELEASED",
                    reason="BROKER_REJECTED_NO_EXPOSURE_RETAINED",
                )
            else:
                event.update(
                    accepted=True,
                    event="ACCOUNT_RISK_ORDER_RESERVED",
                    reason="ACCOUNT_RISK_RESERVED",
                )
                self.exposures.append(
                    Exposure(ea, magic, round(risk_money, 2), "position")
                )
            self.events.append(event)
            return event


def test_three_simultaneous_eas_cannot_cross_account_cap() -> None:
    oracle = AtomicRiskOracle(2500.0)
    barrier = threading.Barrier(3)

    def attempt(index: int) -> dict[str, object]:
        barrier.wait()
        return oracle.submit(f"EA_{index}", 1000.0, magic=100_000 + index)

    with ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(attempt, (1, 2, 3)))

    assert sum(row["accepted"] is True for row in results) == 2
    assert sum(row["reason"] == "ACCOUNT_RISK_OVER_BUDGET" for row in results) == 1
    assert sum(row.risk_money or 0.0 for row in oracle.exposures) == 2000.0
    assert max(float(row["projected_risk_money"]) for row in oracle.events if row["accepted"]) <= 2500.0


def test_all_magics_and_pending_orders_accumulate_at_exact_boundary() -> None:
    oracle = AtomicRiskOracle(
        2500.0,
        [
            Exposure("manual", 0, 400.0, "position"),
            Exposure("foreign", 999, 300.0, "pending_order"),
        ],
    )
    accepted = oracle.submit("EA_A", 1800.0, magic=111_320_000)
    blocked = oracle.submit("EA_B", 0.01, magic=111_320_001)

    assert accepted["accepted"] is True
    assert accepted["projected_risk_money"] == 2500.0
    assert blocked["accepted"] is False
    assert blocked["reason"] == "ACCOUNT_RISK_OVER_BUDGET"


def test_uncovered_position_fails_closed_and_broker_failure_releases() -> None:
    unknown = AtomicRiskOracle(
        2500.0, [Exposure("manual", 0, None, "position")]
    )
    assert unknown.submit("EA_A", 100.0, magic=1)["reason"] == (
        "ACCOUNT_RISK_INVENTORY_UNKNOWN"
    )

    clean = AtomicRiskOracle(2500.0)
    failed = clean.submit("EA_A", 900.0, magic=1, broker_accepts=False)
    retried = clean.submit("EA_B", 2500.0, magic=2)
    assert failed["reason"] == "BROKER_REJECTED_NO_EXPOSURE_RETAINED"
    assert retried["accepted"] is True
    assert len(clean.exposures) == 1


def test_deterministic_three_ea_evidence_log_is_pinned() -> None:
    oracle = AtomicRiskOracle(2500.0)
    for index in (1, 2, 3):
        oracle.submit(f"EA_{index}", 1000.0, magic=100_000 + index)
    expected = [
        json.loads(line)
        for line in EVIDENCE.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    assert oracle.events == expected


def test_mql_scans_whole_account_and_prices_actual_stops() -> None:
    measure = _function_body(RESERVATION, "QM_AccountRiskMeasureInventory")
    assert "PositionsTotal()" in measure
    assert "PositionGetTicket(i)" in measure
    assert "OrdersTotal()" in measure
    assert "OrderGetTicket(i)" in measure
    assert "POSITION_MAGIC" not in RESERVATION
    assert "ORDER_MAGIC" not in RESERVATION
    assert "OrderCalcProfit(side, symbol, volume, from_price, stop_price" in RESERVATION
    assert "POSITION_SL" in RESERVATION
    assert "ORDER_SL" in RESERVATION
    assert "ACCOUNT_RISK_INVENTORY_COUNT_DRIFT" in measure


def test_cas_reservation_wraps_every_framework_order_send() -> None:
    send = _function_body(TRADE_CONTEXT, "QM_TradeContextSend")
    begin = send.index("QM_AccountRiskReservationBegin(request, account_risk)")
    sends = [match.start() for match in re.finditer(r"\bOrderSend\s*\(", send)]
    release = send.index("QM_AccountRiskReleaseLease(account_risk)")
    assert len(sends) == 3
    assert begin < min(sends) < max(sends) < release
    assert "GlobalVariableSetOnCondition" in RESERVATION
    assert "QM_ACCOUNT_RISK_LEASE_STALE_SECONDS = 120" in RESERVATION
    assert "ACCOUNT_RISK_ORDER_BLOCKED" in send
    assert "ACCOUNT_RISK_ORDER_RESERVED" in send


def test_position_ticket_deals_remain_unblocked_risk_reduction() -> None:
    begin = _function_body(RESERVATION, "QM_AccountRiskReservationBegin")
    assert "request.action == TRADE_ACTION_DEAL && request.position > 0" in begin
    assert begin.index("request.position > 0") < begin.index(
        "QM_AccountRiskAcquireLease(decision)"
    )


def test_activation_is_owner_bound_live_percent_only_and_defaults_off() -> None:
    configure = _function_body(
        RESERVATION, "QM_AccountRiskReservationConfigure"
    )
    assert "MQLInfoInteger(MQL_TESTER) != 0" in configure
    assert "!risk_percent_mode" in configure
    assert "!owner_ratified" in configure
    assert "cap_percent > QM_ACCOUNT_RISK_MAX_CAP_PERCENT" in configure
    assert "QM_ACCOUNT_RISK_MAX_CAP_PERCENT = 2.5" in RESERVATION
    assert "account_stop_risk_reservation_required = false" in RUNTIME
    assert "account_stop_risk_owner_ratified = false" in RUNTIME
    assert "account_stop_risk_cap_percent > 2.5" in RUNTIME

    init = _function_body(COMMON, "QM_FrameworkInitV3")
    assert init.index("QM_RuntimeExecutionBindRequired") < init.index(
        "QM_AccountRiskReservationConfigure"
    )
    assert "g_qm_risk_mode == QM_RISK_MODE_PERCENT" in init
    assert "ACCOUNT_RISK_RESERVATION_CONFIG_INVALID" in init


def test_account_risk_rejection_is_not_mislabeled_as_broker_failure() -> None:
    entry = _function_body(ENTRY, "QM_EntryInternal")
    assert "QM_ENTRY_REJECTED_ACCOUNT_RISK" in ENTRY
    assert 'StringFind(broker_error_class, "ACCOUNT_RISK_") == 0' in entry
