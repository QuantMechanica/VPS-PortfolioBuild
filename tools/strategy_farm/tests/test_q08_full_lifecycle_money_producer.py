from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[3]
COMMON = REPO_ROOT / "framework" / "include" / "QM" / "QM_Common.mqh"
MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
CENT = Decimal("0.01")


class LifecycleInvalid(RuntimeError):
    pass


@dataclass(frozen=True)
class Deal:
    deal_id: int
    position_id: int
    entry: str
    volume: Decimal
    commission: Decimal
    profit: Decimal = Decimal("0")
    swap: Decimal = Decimal("0")
    fee: Decimal = Decimal("0")
    magic: int = 99360000
    symbol: str = "USDJPY.DWX"
    time: int = 1
    side: str = "BUY"
    price: Decimal = Decimal("100")


def _money(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def _reference_emit(deals: list[Deal], sink: list[dict[str, object]]) -> None:
    """Small executable specification for the MQL history-walk contract.

    The sink is mutated only after every owned lifecycle has validated. This is
    intentionally independent Python reference logic, not a parser for MQL.
    """

    owned_positions = {
        deal.position_id
        for deal in deals
        if deal.entry == "IN" and deal.magic == 99360000
    }
    if any(
        deal.entry == "INOUT"
        and (deal.position_id in owned_positions or deal.magic == 99360000)
        for deal in deals
    ):
        raise LifecycleInvalid("INOUT_REVERSAL_UNSUPPORTED")

    prepared_by_deal: dict[int, dict[str, object]] = {}
    for position_id in sorted(owned_positions):
        lifecycle = [deal for deal in deals if deal.position_id == position_id]
        entries = [deal for deal in lifecycle if deal.entry == "IN"]
        exits = [deal for deal in lifecycle if deal.entry in {"OUT", "OUT_BY"}]
        if not entries or not exits:
            raise LifecycleInvalid("POSITION_LIFECYCLE_NOT_FULLY_CLOSED")

        magic = entries[0].magic
        symbol = entries[0].symbol
        if any(
            deal.magic != magic
            or deal.symbol != symbol
            or deal.side != entries[0].side
            or deal.volume <= 0
            or deal.price <= 0
            for deal in entries
        ):
            raise LifecycleInvalid("POSITION_ENTRY_IDENTITY_CHANGED")
        if any(
            any(value != _money(value) for value in (
                deal.profit, deal.swap, deal.fee, deal.commission
            ))
            or deal.fee != 0
            for deal in lifecycle
        ):
            raise LifecycleInvalid("MONEY_NOT_CENT_EXACT_OR_FEE_NONZERO")

        entry_volume = sum((deal.volume for deal in entries), Decimal("0"))
        entry_commission = _money(
            sum((deal.commission for deal in entries), Decimal("0"))
        )
        exit_volume = sum((deal.volume for deal in exits), Decimal("0"))
        if entry_volume <= 0 or exit_volume != entry_volume:
            raise LifecycleInvalid("POSITION_LIFECYCLE_NOT_FULLY_CLOSED")
        entry_price = sum(
            (deal.price * deal.volume for deal in entries), Decimal("0")
        ) / entry_volume

        # Validate chronology before preparing any output. Scale-ins are legal
        # while volume remains open; an exit may never exceed volume entered so far.
        observed_in = Decimal("0")
        observed_out = Decimal("0")
        for deal in lifecycle:
            if deal.entry == "IN":
                if observed_out and observed_in == observed_out:
                    raise LifecycleInvalid("POSITION_IDENTIFIER_REOPENED")
                observed_in += deal.volume
            elif deal.entry in {"OUT", "OUT_BY"}:
                observed_out += deal.volume
                if observed_out > observed_in:
                    raise LifecycleInvalid("EXIT_VOLUME_EXCEEDS_ENTRY_VOLUME")

        allocated_volume = Decimal("0")
        allocated_entry_commission = Decimal("0")
        for deal in exits:
            allocated_volume += deal.volume
            final_exit = allocated_volume == entry_volume
            target = (
                entry_commission
                if final_exit
                else _money(entry_commission * allocated_volume / entry_volume)
            )
            entry_cost = _money(target - allocated_entry_commission)
            allocated_entry_commission = target
            exit_cost = _money(deal.commission)
            commission = _money(entry_cost + exit_cost)
            profit = _money(deal.profit)
            swap = _money(deal.swap)
            prepared_by_deal[deal.deal_id] = {
                    "deal_id": deal.deal_id,
                    "entry": deal.entry,
                    "magic": magic,
                    "symbol": symbol,
                    "side": entries[0].side,
                    "entry_price": entry_price,
                    "exit_price": deal.price,
                    "entry_time": min(entry.time for entry in entries),
                    "money_basis": MONEY_BASIS,
                    "profit": profit,
                    "swap": swap,
                    "fee": _d("0.00"),
                    "entry_commission": entry_cost,
                    "exit_commission": exit_cost,
                    "commission": commission,
                    "net": _money(profit + swap + commission),
                }

        if allocated_entry_commission != entry_commission:
            raise LifecycleInvalid("ENTRY_COMMISSION_ALLOCATION_INCOMPLETE")

    sink.extend(
        prepared_by_deal[deal.deal_id]
        for deal in deals
        if deal.deal_id in prepared_by_deal
    )


def _d(value: str) -> Decimal:
    return Decimal(value)


def test_unequal_partial_exits_get_proportional_actual_entry_and_exit_costs() -> None:
    sink: list[dict[str, object]] = []
    _reference_emit(
        [
            Deal(1, 10, "IN", _d("3"), _d("-9"), time=100),
            Deal(2, 10, "OUT", _d("1"), _d("-1"), profit=_d("10"), time=200),
            Deal(3, 10, "OUT", _d("2"), _d("-4"), profit=_d("30"), time=300),
        ],
        sink,
    )

    assert [row["entry_commission"] for row in sink] == [_d("-3.00"), _d("-6.00")]
    assert [row["exit_commission"] for row in sink] == [_d("-1.00"), _d("-4.00")]
    assert [row["commission"] for row in sink] == [_d("-4.00"), _d("-10.00")]
    assert [row["net"] for row in sink] == [_d("6.00"), _d("20.00")]


def test_scale_ins_share_earliest_identity_and_all_actual_entry_commission() -> None:
    sink: list[dict[str, object]] = []
    _reference_emit(
        [
            Deal(1, 20, "IN", _d("1"), _d("-2"), time=100),
            Deal(2, 20, "IN", _d("2"), _d("-7"), time=110),
            Deal(3, 20, "OUT", _d("1"), _d("-1"), time=200),
            Deal(4, 20, "OUT", _d("2"), _d("-2"), time=210),
        ],
        sink,
    )

    assert [row["entry_time"] for row in sink] == [100, 100]
    assert [row["magic"] for row in sink] == [99360000, 99360000]
    assert sum((row["entry_commission"] for row in sink), _d("0")) == _d("-9.00")


def test_partial_exit_cents_use_cumulative_targets_and_final_remainder() -> None:
    sink: list[dict[str, object]] = []
    _reference_emit(
        [
            Deal(1, 30, "IN", _d("3"), _d("-0.10"), time=100),
            Deal(2, 30, "OUT", _d("1"), _d("0"), time=200),
            Deal(3, 30, "OUT", _d("1"), _d("0"), time=210),
            Deal(4, 30, "OUT", _d("1"), _d("0"), time=220),
        ],
        sink,
    )

    assert [row["entry_commission"] for row in sink] == [
        _d("-0.03"),
        _d("-0.04"),
        _d("-0.03"),
    ]
    assert sum((row["entry_commission"] for row in sink), _d("0")) == _d("-0.10")


def test_out_by_is_a_supported_exit_with_full_lifecycle_net() -> None:
    sink: list[dict[str, object]] = []
    _reference_emit(
        [
            Deal(1, 40, "IN", _d("1"), _d("-2"), time=100),
            Deal(2, 40, "OUT_BY", _d("1"), _d("-3"), profit=_d("20"), time=200),
        ],
        sink,
    )

    assert sink == [
        {
            "deal_id": 2,
            "entry": "OUT_BY",
            "magic": 99360000,
            "symbol": "USDJPY.DWX",
            "side": "BUY",
            "entry_price": _d("100"),
            "exit_price": _d("100"),
            "entry_time": 100,
            "money_basis": MONEY_BASIS,
            "profit": _d("20.00"),
            "swap": _d("0.00"),
            "fee": _d("0.00"),
            "entry_commission": _d("-2.00"),
            "exit_commission": _d("-3.00"),
            "commission": _d("-5.00"),
            "net": _d("15.00"),
        }
    ]


@pytest.mark.parametrize(
    "deals, reason",
    [
        (
            [
                Deal(1, 50, "IN", _d("1"), _d("-1"), time=100),
                Deal(2, 50, "INOUT", _d("1"), _d("-1"), time=200),
            ],
            "INOUT_REVERSAL_UNSUPPORTED",
        ),
        (
            [
                Deal(1, 60, "IN", _d("2"), _d("-2"), time=100),
                Deal(2, 60, "OUT", _d("1"), _d("-1"), time=200),
            ],
            "POSITION_LIFECYCLE_NOT_FULLY_CLOSED",
        ),
    ],
)
def test_invalid_lifecycle_fails_before_any_output(
    deals: list[Deal], reason: str
) -> None:
    sink: list[dict[str, object]] = []

    with pytest.raises(LifecycleInvalid, match=reason):
        _reference_emit(deals, sink)

    assert sink == []


@pytest.mark.parametrize(
    "deal",
    [
        Deal(2, 80, "OUT", _d("1"), _d("-1"), fee=_d("-0.01"), time=200),
        Deal(2, 80, "OUT", _d("1"), _d("-1.001"), time=200),
        Deal(2, 80, "OUT", _d("1"), _d("-1"), profit=_d("10.001"), time=200),
    ],
)
def test_fee_or_subcent_money_fails_before_any_output(deal: Deal) -> None:
    sink: list[dict[str, object]] = []
    with pytest.raises(LifecycleInvalid, match="MONEY_NOT_CENT_EXACT_OR_FEE_NONZERO"):
        _reference_emit(
            [Deal(1, 80, "IN", _d("1"), _d("-1"), time=100), deal],
            sink,
        )
    assert sink == []


def test_interleaved_positions_preserve_authoritative_deal_order() -> None:
    sink: list[dict[str, object]] = []
    _reference_emit(
        [
            Deal(1, 91, "IN", _d("1"), _d("-1"), time=100),
            Deal(2, 90, "IN", _d("1"), _d("-1"), time=101),
            Deal(3, 91, "OUT", _d("1"), _d("-1"), time=200),
            Deal(4, 90, "OUT", _d("1"), _d("-1"), time=201),
        ],
        sink,
    )
    assert [row["deal_id"] for row in sink] == [3, 4]


def test_reopened_position_identifier_fails_closed() -> None:
    sink: list[dict[str, object]] = []
    with pytest.raises(LifecycleInvalid, match="POSITION_IDENTIFIER_REOPENED"):
        _reference_emit(
            [
                Deal(1, 92, "IN", _d("1"), _d("-1"), time=100),
                Deal(2, 92, "OUT", _d("1"), _d("-1"), time=200),
                Deal(3, 92, "IN", _d("1"), _d("-1"), time=300),
                Deal(4, 92, "OUT", _d("1"), _d("-1"), time=400),
            ],
            sink,
        )
    assert sink == []


def test_mql_source_contract_is_full_lifecycle_actual_and_fail_closed() -> None:
    source = COMMON.read_text(encoding="utf-8")
    start = source.index("void QM_FrameworkQ08EmitFromHistory()")
    end = source.index("void QM_FrameworkQ08Flush()", start)
    emitter = source[start:end]
    compact = "".join(emitter.split())

    assert '\\"money_basis\\":\\"FULL_POSITION_LIFECYCLE_ACTUAL_V1\\"' in emitter
    assert "DEAL_FEE" in emitter
    assert '\\"fee\\":0.00' in emitter
    assert "QM_FrameworkQ08MoneyCentExact" in emitter
    for required_field in (
        "event",
        "magic",
        "side",
        "entry_price",
        "exit_price",
        "time",
        "entry_time",
        "mae_acct",
        "net",
        "profit",
        "swap",
        "commission",
        "entry_commission",
        "exit_commission",
        "volume",
        "notional",
        "symbol",
    ):
        assert f'\\"{required_field}\\"' in emitter

    assert "DEAL_POSITION_ID" in emitter
    assert "QM_FrameworkQ08CanonicalSide" in emitter
    assert "QM_FrameworkQ08StablePriceJson" in emitter
    assert "DoubleToString(value, 16)" in source
    assert "DEAL_ENTRY_OUT_BY" in emitter
    assert "INOUT_REVERSAL_UNSUPPORTED" in emitter
    assert "POSITION_LIFECYCLE_NOT_FULLY_CLOSED" in emitter
    assert "constboollifecycle_validated=!lifecycle_invalid;" in compact
    assert compact.index("constboollifecycle_validated") < compact.index(
        "g_qm_q08_trade_log+=StringFormat"
    )
    publication = emitter[emitter.index("// Pass 4:") :]
    assert "HistoryDealGet" not in publication
    assert "QM_FrameworkQ08WriteTempChunk" in publication
    assert "FileSize(q08_temp_fh)" in publication
    assert "FileMove(q08_temp_path" in publication
    assert "FILE_COMMON | FILE_REWRITE" in publication

    allocation_start = source.index("bool QM_FrameworkQ08AllocateEntryCommission")
    allocation_end = source.index("// Rebuild the entire Q08", allocation_start)
    allocation = "".join(source[allocation_start:allocation_end].split())
    assert "total_entry_commission*next_exit_volume/row.entry_volume" in allocation
    assert "target_allocated-row.allocated_entry_commission" in allocation
    assert "final_exit?total_entry_commission" in allocation
    assert "profit+swap+commission" in compact
