"""Pure, fail-closed FTMO Challenge rule evaluation on synchronized MTM traces.

This module is deliberately narrower than a challenge simulator.  It evaluates
the published numerical objectives against a caller-supplied, normalized
balance/equity path.  It does not infer intra-grid equity, execution, fills,
costs, or missing sleeve history and therefore never emits a claim that a real
or simulated FTMO Challenge is proven to pass.

Authoritative rule snapshot (retrieved 2026-07-21):
https://ftmo.com/en/trading-objectives/

Input contract
--------------
``normalize_trace`` accepts a mapping with these required fields::

    {
        "schema_version": 1,
        "trace_id": "portfolio-oos-2025",
        "currency": "USD",
        "source_fingerprint_sha256": "<64 lowercase hex characters>",
        "money_decimals": 2,
        "grid_seconds": 60,
        "balance_basis": "NET_CLOSED_TRADING_PNL_INCLUDING_COSTS_NO_EXTERNAL_CASHFLOWS",
        "equity_basis": "MARK_TO_MARKET_INCLUDING_OPEN_PNL_SWAP_COMMISSION",
        "opened_positions_basis": "RECONCILED_DEAL_OPEN_EVENTS_IN_INTERVAL_(PREVIOUS_TS,TS]",
        "interval_min_equity_basis": "TICK_EVENT_COMPLETE_INTERVAL_MIN_EQUITY_INCLUDING_ENDPOINTS",
        "rows": [{
            "ts_utc": "2026-01-04T23:00:00Z",
            "balance": "100000.00",
            "equity": "100000.00",
            "interval_min_equity": "100000.00",
            "open_positions": 0,
            "opened_positions": 0,
            "day_anchor": true
        }, ...]
    }

Rows are instantaneous observations on one regular UTC grid.  The trace starts
and ends at exact 00:00 Europe/Prague boundaries.  ``day_anchor`` is required
and must be true exactly at every such boundary, including CET/CEST changes.
The last row closes the preceding complete Prague day.  ``opened_positions``
counts reconciled deal-open events in ``(previous_ts, ts]``.  Such a count is
credited to the endpoint's Prague date; anchor rows must therefore carry zero
opens so an interval never ambiguously crosses a day boundary.  The first row
has no preceding interval and must also carry zero opens.

``interval_min_equity`` is the tick/event-complete minimum over the interval,
including both endpoints.  On the first row it must equal endpoint equity.  At
a Prague anchor, the interval minimum is tested against the preceding day's
floors before the reset/ratchet, then anchor endpoint equity is tested against
the newly established floors.  A trace whose equity is only reconstructed from
closed PnL is inadmissible for equity-loss objectives.

Boundary/operator assumptions follow the official wording literally:

* equity below (``<``), not equal to, a loss limit is a breach;
* target balance equal to or above the target passes that objective;
* 1-Step Maximum Loss trails the highest balance observed at a Prague midnight;
* Best Day uses net closed daily PnL inferred from balance changes, and includes
  the current partial day when testing an intraday target/flat-book point;
* 2-Step has no time limit; this engine imposes none.

The caller must explicitly state the largest acceptable observation interval by
passing ``EvaluationAssumptions``.  Interval minima close the between-sample
loss-gap only when their fixed tick/event-complete provenance contract is true.
Historical results still never prove a future or real Challenge: successful
screens return ``SCREEN_PASS`` and ``challenge_proof`` is always false.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation, ROUND_FLOOR
from enum import Enum
from typing import Any, Mapping, Sequence
from zoneinfo import ZoneInfo


TRACE_SCHEMA_VERSION = 1
RULES_AS_OF = "2026-07-21"
RULES_SOURCE_URL = "https://ftmo.com/en/trading-objectives/"
PRAGUE = ZoneInfo("Europe/Prague")
EQUITY_BASIS_MTM = "MARK_TO_MARKET_INCLUDING_OPEN_PNL_SWAP_COMMISSION"
BALANCE_BASIS_NET_TRADING = (
    "NET_CLOSED_TRADING_PNL_INCLUDING_COSTS_NO_EXTERNAL_CASHFLOWS"
)
OPENED_POSITIONS_BASIS = "RECONCILED_DEAL_OPEN_EVENTS_IN_INTERVAL_(PREVIOUS_TS,TS]"
INTERVAL_MIN_EQUITY_BASIS = (
    "TICK_EVENT_COMPLETE_INTERVAL_MIN_EQUITY_INCLUDING_ENDPOINTS"
)
_CURRENCY_RE = re.compile(r"^[A-Z]{3}$")
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class TraceValidationError(ValueError):
    """The evidence cannot safely be evaluated."""


class MaximumLossModel(str, Enum):
    EOD_TRAILING = "EOD_TRAILING"
    STATIC_INITIAL = "STATIC_INITIAL"


@dataclass(frozen=True)
class FtmoRuleSet:
    rule_set_id: str
    product: str
    phase: str
    profit_target_fraction: Decimal
    maximum_daily_loss_fraction: Decimal
    maximum_loss_fraction: Decimal
    maximum_loss_model: MaximumLossModel
    minimum_trading_days: int
    best_day_fraction: Decimal | None


ONE_STEP_CHALLENGE = FtmoRuleSet(
    rule_set_id="FTMO_1_STEP_CHALLENGE_2026_07_21",
    product="1_STEP",
    phase="CHALLENGE",
    profit_target_fraction=Decimal("0.10"),
    maximum_daily_loss_fraction=Decimal("0.03"),
    maximum_loss_fraction=Decimal("0.10"),
    maximum_loss_model=MaximumLossModel.EOD_TRAILING,
    minimum_trading_days=0,
    best_day_fraction=Decimal("0.50"),
)

TWO_STEP_PHASE1 = FtmoRuleSet(
    rule_set_id="FTMO_2_STEP_PHASE1_2026_07_21",
    product="2_STEP",
    phase="PHASE1",
    profit_target_fraction=Decimal("0.10"),
    maximum_daily_loss_fraction=Decimal("0.05"),
    maximum_loss_fraction=Decimal("0.10"),
    maximum_loss_model=MaximumLossModel.STATIC_INITIAL,
    minimum_trading_days=4,
    best_day_fraction=None,
)

TWO_STEP_VERIFICATION = FtmoRuleSet(
    rule_set_id="FTMO_2_STEP_VERIFICATION_2026_07_21",
    product="2_STEP",
    phase="VERIFICATION",
    profit_target_fraction=Decimal("0.05"),
    maximum_daily_loss_fraction=Decimal("0.05"),
    maximum_loss_fraction=Decimal("0.10"),
    maximum_loss_model=MaximumLossModel.STATIC_INITIAL,
    minimum_trading_days=4,
    best_day_fraction=None,
)

_FROZEN_OFFICIAL_RULE_SETS = (
    ONE_STEP_CHALLENGE,
    TWO_STEP_PHASE1,
    TWO_STEP_VERIFICATION,
)


@dataclass(frozen=True)
class EvaluationAssumptions:
    """Business assumptions which must be chosen by the caller.

    ``maximum_grid_seconds`` is an evidence-admissibility ceiling, not an FTMO
    rule.  A trace sampled more coarsely is rejected rather than silently used.
    """

    maximum_grid_seconds: int

    def __post_init__(self) -> None:
        if (
            isinstance(self.maximum_grid_seconds, bool)
            or not isinstance(self.maximum_grid_seconds, int)
            or self.maximum_grid_seconds <= 0
        ):
            raise TraceValidationError("maximum_grid_seconds_invalid")


@dataclass(frozen=True)
class TracePoint:
    ts_utc: dt.datetime
    balance: Decimal
    equity: Decimal
    interval_min_equity: Decimal
    open_positions: int
    opened_positions: int
    day_anchor: bool


@dataclass(frozen=True)
class NormalizedTrace:
    trace_id: str
    currency: str
    source_fingerprint_sha256: str
    money_decimals: int
    grid_seconds: int
    balance_basis: str
    equity_basis: str
    opened_positions_basis: str
    interval_min_equity_basis: str
    points: tuple[TracePoint, ...]

    @property
    def quantum(self) -> Decimal:
        return Decimal(1).scaleb(-self.money_decimals)


def _require_int(value: Any, label: str, *, minimum: int, maximum: int | None = None) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TraceValidationError(f"{label}_invalid")
    if value < minimum or (maximum is not None and value > maximum):
        raise TraceValidationError(f"{label}_out_of_range")
    return value


def _parse_timestamp(value: Any) -> dt.datetime:
    if isinstance(value, dt.datetime):
        parsed = value
    elif isinstance(value, str) and value.strip():
        raw = value.strip()
        if raw.endswith("Z"):
            raw = raw[:-1] + "+00:00"
        try:
            parsed = dt.datetime.fromisoformat(raw)
        except ValueError as exc:
            raise TraceValidationError(f"timestamp_invalid:{value}") from exc
    else:
        raise TraceValidationError("timestamp_invalid")
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise TraceValidationError("timestamp_timezone_missing")
    if parsed.utcoffset() != dt.timedelta(0):
        raise TraceValidationError("timestamp_not_utc")
    return parsed.astimezone(dt.UTC)


def _parse_decimal(value: Any, label: str) -> Decimal:
    if isinstance(value, bool) or value is None:
        raise TraceValidationError(f"{label}_invalid")
    try:
        parsed = Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise TraceValidationError(f"{label}_invalid") from exc
    if not parsed.is_finite():
        raise TraceValidationError(f"{label}_nonfinite")
    return parsed


def _parse_money(value: Any, label: str, quantum: Decimal) -> Decimal:
    parsed = _parse_decimal(value, label)
    try:
        quantized = parsed.quantize(quantum)
    except InvalidOperation as exc:
        raise TraceValidationError(f"{label}_outside_decimal_context") from exc
    if quantized != parsed:
        raise TraceValidationError(f"{label}_precision_exceeds_money_decimals")
    return parsed


def _is_prague_midnight(timestamp: dt.datetime) -> bool:
    local = timestamp.astimezone(PRAGUE)
    return local.hour == local.minute == local.second == local.microsecond == 0


def _validate_normalized(trace: NormalizedTrace, *, minimum_complete_days: int) -> None:
    if not isinstance(trace, NormalizedTrace):
        raise TraceValidationError("trace_not_normalized")
    _require_int(minimum_complete_days, "minimum_complete_days", minimum=1)
    if not isinstance(trace.trace_id, str) or not trace.trace_id:
        raise TraceValidationError("normalized_trace_id_invalid")
    if not isinstance(trace.currency, str) or not _CURRENCY_RE.fullmatch(trace.currency):
        raise TraceValidationError("normalized_currency_invalid")
    if (
        not isinstance(trace.source_fingerprint_sha256, str)
        or not _SHA256_RE.fullmatch(trace.source_fingerprint_sha256)
    ):
        raise TraceValidationError("normalized_source_fingerprint_sha256_invalid")
    _require_int(trace.money_decimals, "normalized_money_decimals", minimum=0, maximum=8)
    _require_int(trace.grid_seconds, "normalized_grid_seconds", minimum=1, maximum=3600)
    if 3600 % trace.grid_seconds != 0:
        raise TraceValidationError("normalized_grid_seconds_must_divide_one_hour")
    if trace.balance_basis != BALANCE_BASIS_NET_TRADING:
        raise TraceValidationError("normalized_balance_basis_invalid")
    if trace.equity_basis != EQUITY_BASIS_MTM:
        raise TraceValidationError("normalized_equity_basis_invalid")
    if trace.opened_positions_basis != OPENED_POSITIONS_BASIS:
        raise TraceValidationError("normalized_opened_positions_basis_invalid")
    if trace.interval_min_equity_basis != INTERVAL_MIN_EQUITY_BASIS:
        raise TraceValidationError("normalized_interval_min_equity_basis_invalid")
    if not trace.points:
        raise TraceValidationError("trace_empty")
    if len(trace.points) < 2:
        raise TraceValidationError("trace_has_no_complete_day")
    previous: dt.datetime | None = None
    previous_equity: Decimal | None = None
    seen: set[dt.datetime] = set()
    expected_delta = dt.timedelta(seconds=trace.grid_seconds)
    for index, point in enumerate(trace.points):
        if not isinstance(point, TracePoint):
            raise TraceValidationError(f"normalized_point_invalid:{index}")
        if (
            not isinstance(point.ts_utc, dt.datetime)
            or point.ts_utc.tzinfo is None
            or point.ts_utc.utcoffset() is None
            or point.ts_utc.utcoffset() != dt.timedelta(0)
        ):
            raise TraceValidationError(f"normalized_timestamp_not_utc:{index}")
        if point.ts_utc in seen:
            raise TraceValidationError(f"normalized_duplicate_timestamp:{index}")
        if previous is not None:
            if point.ts_utc <= previous:
                raise TraceValidationError(f"normalized_timestamps_not_increasing:{index}")
            if point.ts_utc - previous != expected_delta:
                raise TraceValidationError(f"normalized_grid_interval_mismatch:{index}")
        previous = point.ts_utc
        seen.add(point.ts_utc)
        if not isinstance(point.day_anchor, bool) or point.day_anchor != _is_prague_midnight(
            point.ts_utc
        ):
            raise TraceValidationError(f"normalized_day_anchor_invalid:{index}")
        if not isinstance(point.balance, Decimal) or not isinstance(point.equity, Decimal):
            raise TraceValidationError(f"normalized_money_type_invalid:{index}")
        if not isinstance(point.interval_min_equity, Decimal):
            raise TraceValidationError(f"normalized_interval_min_equity_type_invalid:{index}")
        _parse_money(point.balance, f"normalized_balance:{index}", trace.quantum)
        _parse_money(point.equity, f"normalized_equity:{index}", trace.quantum)
        _parse_money(
            point.interval_min_equity,
            f"normalized_interval_min_equity:{index}",
            trace.quantum,
        )
        _require_int(
            point.open_positions, f"normalized_open_positions:{index}", minimum=0
        )
        _require_int(
            point.opened_positions, f"normalized_opened_positions:{index}", minimum=0
        )
        if point.open_positions == 0 and point.balance != point.equity:
            raise TraceValidationError(f"normalized_flat_book_mismatch:{index}")
        if point.day_anchor and point.opened_positions != 0:
            raise TraceValidationError(
                f"normalized_opened_positions_at_day_anchor_forbidden:{index}"
            )
        if index == 0:
            if point.interval_min_equity != point.equity:
                raise TraceValidationError(
                    "normalized_first_interval_min_equity_must_equal_equity"
                )
        elif (
            point.interval_min_equity > point.equity
            or previous_equity is None
            or point.interval_min_equity > previous_equity
        ):
            raise TraceValidationError(
                f"normalized_interval_min_equity_exceeds_endpoint:{index}"
            )
        previous_equity = point.equity
    if not trace.points[0].day_anchor:
        raise TraceValidationError("trace_start_eod_anchor_missing")
    if not trace.points[-1].day_anchor:
        raise TraceValidationError("trace_end_eod_anchor_missing")
    start_local = trace.points[0].ts_utc.astimezone(PRAGUE)
    end_local = trace.points[-1].ts_utc.astimezone(PRAGUE)
    complete_days = (end_local.date() - start_local.date()).days
    if complete_days < minimum_complete_days:
        raise TraceValidationError(
            f"insufficient_complete_days:{complete_days}<{minimum_complete_days}"
        )


def _validate_rules(rules: FtmoRuleSet) -> None:
    if not isinstance(rules, FtmoRuleSet):
        raise TraceValidationError("rules_invalid")
    if not rules.rule_set_id or not rules.product or not rules.phase:
        raise TraceValidationError("rule_identity_invalid")
    for label, value in (
        ("profit_target_fraction", rules.profit_target_fraction),
        ("maximum_daily_loss_fraction", rules.maximum_daily_loss_fraction),
        ("maximum_loss_fraction", rules.maximum_loss_fraction),
    ):
        if not isinstance(value, Decimal) or not value.is_finite() or not 0 < value < 1:
            raise TraceValidationError(f"{label}_invalid")
    _require_int(rules.minimum_trading_days, "minimum_trading_days", minimum=0)
    if rules.best_day_fraction is not None and (
        not isinstance(rules.best_day_fraction, Decimal)
        or not rules.best_day_fraction.is_finite()
        or not 0 < rules.best_day_fraction <= 1
    ):
        raise TraceValidationError("best_day_fraction_invalid")
    if not isinstance(rules.maximum_loss_model, MaximumLossModel):
        raise TraceValidationError("maximum_loss_model_invalid")
    if rules not in _FROZEN_OFFICIAL_RULE_SETS:
        raise TraceValidationError("rules_not_frozen_official_profile")


def normalize_trace(
    envelope: Mapping[str, Any],
    *,
    minimum_complete_days: int = 1,
) -> NormalizedTrace:
    """Validate and normalize one absolute balance/equity trace.

    Validation errors are exceptions by design: an invalid trace cannot be
    mistaken for a failed or passed trading result.
    """

    if not isinstance(envelope, Mapping):
        raise TraceValidationError("trace_envelope_invalid")
    if envelope.get("schema_version") != TRACE_SCHEMA_VERSION:
        raise TraceValidationError("trace_schema_version_invalid")

    trace_id = envelope.get("trace_id")
    if not isinstance(trace_id, str) or not trace_id.strip():
        raise TraceValidationError("trace_id_invalid")
    trace_id = trace_id.strip()

    currency = envelope.get("currency")
    if not isinstance(currency, str) or not _CURRENCY_RE.fullmatch(currency):
        raise TraceValidationError("currency_invalid")
    source_fingerprint_sha256 = envelope.get("source_fingerprint_sha256")
    if (
        not isinstance(source_fingerprint_sha256, str)
        or not _SHA256_RE.fullmatch(source_fingerprint_sha256)
    ):
        raise TraceValidationError("source_fingerprint_sha256_invalid_or_missing")

    money_decimals = _require_int(
        envelope.get("money_decimals"), "money_decimals", minimum=0, maximum=8
    )
    quantum = Decimal(1).scaleb(-money_decimals)
    grid_seconds = _require_int(
        envelope.get("grid_seconds"), "grid_seconds", minimum=1, maximum=3600
    )
    if 3600 % grid_seconds != 0:
        raise TraceValidationError("grid_seconds_must_divide_one_hour")

    equity_basis = envelope.get("equity_basis")
    if equity_basis != EQUITY_BASIS_MTM:
        if equity_basis in {"CLOSED_PNL_ONLY", "BALANCE_ONLY"}:
            raise TraceValidationError("closed_pnl_only_inadmissible_for_equity_gates")
        raise TraceValidationError("equity_basis_invalid_or_missing")
    balance_basis = envelope.get("balance_basis")
    if balance_basis != BALANCE_BASIS_NET_TRADING:
        raise TraceValidationError("balance_basis_invalid_or_missing")
    opened_positions_basis = envelope.get("opened_positions_basis")
    if opened_positions_basis != OPENED_POSITIONS_BASIS:
        raise TraceValidationError("opened_positions_basis_invalid_or_missing")
    interval_min_equity_basis = envelope.get("interval_min_equity_basis")
    if interval_min_equity_basis != INTERVAL_MIN_EQUITY_BASIS:
        raise TraceValidationError("interval_min_equity_basis_invalid_or_missing")

    rows = envelope.get("rows")
    if not isinstance(rows, Sequence) or isinstance(rows, (str, bytes)):
        raise TraceValidationError("rows_invalid")

    points: list[TracePoint] = []
    seen: set[dt.datetime] = set()
    previous: dt.datetime | None = None
    expected_delta = dt.timedelta(seconds=grid_seconds)
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping):
            raise TraceValidationError(f"row_invalid:{index}")
        timestamp = _parse_timestamp(row.get("ts_utc"))
        if timestamp in seen:
            raise TraceValidationError(f"duplicate_timestamp:{timestamp.isoformat()}")
        if previous is not None:
            if timestamp < previous:
                raise TraceValidationError(f"timestamps_not_strictly_increasing:{index}")
            if timestamp - previous != expected_delta:
                raise TraceValidationError(
                    f"grid_interval_mismatch:{index}:"
                    f"{int((timestamp - previous).total_seconds())}!={grid_seconds}"
                )
        seen.add(timestamp)
        previous = timestamp

        if "currency" in row and row["currency"] != currency:
            raise TraceValidationError(f"row_currency_mismatch:{index}")
        if "grid_seconds" in row and row["grid_seconds"] != grid_seconds:
            raise TraceValidationError(f"row_grid_mismatch:{index}")
        if "equity_basis" in row and row["equity_basis"] != equity_basis:
            raise TraceValidationError(f"row_equity_basis_mismatch:{index}")
        if "balance_basis" in row and row["balance_basis"] != balance_basis:
            raise TraceValidationError(f"row_balance_basis_mismatch:{index}")
        if (
            "opened_positions_basis" in row
            and row["opened_positions_basis"] != opened_positions_basis
        ):
            raise TraceValidationError(f"row_opened_positions_basis_mismatch:{index}")
        if (
            "interval_min_equity_basis" in row
            and row["interval_min_equity_basis"] != interval_min_equity_basis
        ):
            raise TraceValidationError(
                f"row_interval_min_equity_basis_mismatch:{index}"
            )

        day_anchor = row.get("day_anchor")
        if not isinstance(day_anchor, bool):
            raise TraceValidationError(f"day_anchor_invalid:{index}")
        is_midnight = _is_prague_midnight(timestamp)
        if day_anchor != is_midnight:
            reason = "day_anchor_missing" if is_midnight else "day_anchor_not_midnight"
            raise TraceValidationError(f"{reason}:{index}:{timestamp.isoformat()}")

        balance = _parse_money(row.get("balance"), f"balance:{index}", quantum)
        equity = _parse_money(row.get("equity"), f"equity:{index}", quantum)
        interval_min_equity = _parse_money(
            row.get("interval_min_equity"), f"interval_min_equity:{index}", quantum
        )
        open_positions = _require_int(
            row.get("open_positions"), f"open_positions:{index}", minimum=0
        )
        opened_positions = _require_int(
            row.get("opened_positions"), f"opened_positions:{index}", minimum=0
        )
        if open_positions == 0 and equity != balance:
            raise TraceValidationError(f"flat_book_equity_balance_mismatch:{index}")
        if day_anchor and opened_positions != 0:
            raise TraceValidationError(
                f"opened_positions_at_day_anchor_forbidden:{index}"
            )
        if index == 0:
            if interval_min_equity != equity:
                raise TraceValidationError(
                    "first_interval_min_equity_must_equal_equity"
                )
        else:
            previous_equity = points[-1].equity
            if interval_min_equity > equity or interval_min_equity > previous_equity:
                raise TraceValidationError(
                    f"interval_min_equity_exceeds_endpoint:{index}"
                )
        points.append(
            TracePoint(
                ts_utc=timestamp,
                balance=balance,
                equity=equity,
                interval_min_equity=interval_min_equity,
                open_positions=open_positions,
                opened_positions=opened_positions,
                day_anchor=day_anchor,
            )
        )

    trace = NormalizedTrace(
        trace_id=trace_id,
        currency=currency,
        source_fingerprint_sha256=source_fingerprint_sha256,
        money_decimals=money_decimals,
        grid_seconds=grid_seconds,
        balance_basis=balance_basis,
        equity_basis=equity_basis,
        opened_positions_basis=opened_positions_basis,
        interval_min_equity_basis=interval_min_equity_basis,
        points=tuple(points),
    )
    _validate_normalized(trace, minimum_complete_days=minimum_complete_days)
    return trace


def _scale(value: Any, sleeve_id: str) -> Decimal:
    parsed = _parse_decimal(value, f"sleeve_scale:{sleeve_id}")
    if parsed < 0:
        raise TraceValidationError(f"sleeve_scale_negative:{sleeve_id}")
    return parsed


def combine_synchronized_traces(
    traces: Mapping[str, NormalizedTrace],
    *,
    starting_balance: Any,
    minimum_overlap_days: int,
    scales: Mapping[str, Any] | None = None,
    joint_trace_id: str = "FTMO_JOINT_TRACE",
) -> NormalizedTrace:
    """Combine absolute sleeve paths over their exact common grid.

    Every active sleeve is rebased to zero PnL at the first common Prague
    midnight.  It must be flat there.  No forward-fill is allowed.  Scaling is
    applied to each sleeve's balance/equity delta and rounded toward negative
    infinity to the common money precision.  Sleeve interval minima are summed;
    this is conservative even when individual minima occurred at different
    instants.
    """

    if not isinstance(traces, Mapping) or not traces:
        raise TraceValidationError("sleeve_traces_empty")
    _require_int(minimum_overlap_days, "minimum_overlap_days", minimum=1)
    if not isinstance(joint_trace_id, str) or not joint_trace_id.strip():
        raise TraceValidationError("joint_trace_id_invalid")

    raw_sleeve_ids = tuple(traces)
    for sleeve_id in raw_sleeve_ids:
        if not isinstance(sleeve_id, str) or not sleeve_id:
            raise TraceValidationError("sleeve_id_invalid")
    sleeve_ids = tuple(sorted(raw_sleeve_ids))
    for sleeve_id in sleeve_ids:
        _validate_normalized(traces[sleeve_id], minimum_complete_days=1)

    object_ids = [id(traces[sleeve_id]) for sleeve_id in sleeve_ids]
    if len(object_ids) != len(set(object_ids)):
        raise TraceValidationError("duplicate_sleeve_object_identity")
    trace_ids = [traces[sleeve_id].trace_id for sleeve_id in sleeve_ids]
    if len(trace_ids) != len(set(trace_ids)):
        raise TraceValidationError("duplicate_sleeve_trace_id")
    fingerprints = [
        traces[sleeve_id].source_fingerprint_sha256 for sleeve_id in sleeve_ids
    ]
    if len(fingerprints) != len(set(fingerprints)):
        raise TraceValidationError("duplicate_sleeve_source_fingerprint_sha256")

    reference = traces[sleeve_ids[0]]
    for sleeve_id in sleeve_ids[1:]:
        current = traces[sleeve_id]
        if current.currency != reference.currency:
            raise TraceValidationError(f"sleeve_currency_mismatch:{sleeve_id}")
        if current.money_decimals != reference.money_decimals:
            raise TraceValidationError(f"sleeve_money_decimals_mismatch:{sleeve_id}")
        if current.grid_seconds != reference.grid_seconds:
            raise TraceValidationError(f"sleeve_grid_mismatch:{sleeve_id}")
        if current.balance_basis != reference.balance_basis:
            raise TraceValidationError(f"sleeve_balance_basis_mismatch:{sleeve_id}")
        if current.equity_basis != reference.equity_basis:
            raise TraceValidationError(f"sleeve_equity_basis_mismatch:{sleeve_id}")
        if current.opened_positions_basis != reference.opened_positions_basis:
            raise TraceValidationError(
                f"sleeve_opened_positions_basis_mismatch:{sleeve_id}"
            )
        if current.interval_min_equity_basis != reference.interval_min_equity_basis:
            raise TraceValidationError(
                f"sleeve_interval_min_equity_basis_mismatch:{sleeve_id}"
            )

    if scales is not None:
        if not isinstance(scales, Mapping) or set(scales) != set(sleeve_ids):
            raise TraceValidationError("sleeve_scale_keys_mismatch")
        parsed_scales = {key: _scale(scales[key], key) for key in sleeve_ids}
    else:
        parsed_scales = {key: Decimal(1) for key in sleeve_ids}
    if not any(value > 0 for value in parsed_scales.values()):
        raise TraceValidationError("all_sleeve_scales_zero")

    overlap_start = max(trace.points[0].ts_utc for trace in traces.values())
    overlap_end = min(trace.points[-1].ts_utc for trace in traces.values())
    if overlap_end <= overlap_start:
        raise TraceValidationError("sleeve_overlap_empty")
    if not _is_prague_midnight(overlap_start) or not _is_prague_midnight(overlap_end):
        raise TraceValidationError("sleeve_overlap_eod_anchors_incomplete")
    overlap_days = (
        overlap_end.astimezone(PRAGUE).date()
        - overlap_start.astimezone(PRAGUE).date()
    ).days
    if overlap_days < minimum_overlap_days:
        raise TraceValidationError(
            f"insufficient_overlap_days:{overlap_days}<{minimum_overlap_days}"
        )

    sliced: dict[str, tuple[TracePoint, ...]] = {}
    reference_grid: tuple[dt.datetime, ...] | None = None
    for sleeve_id in sleeve_ids:
        points = tuple(
            point
            for point in traces[sleeve_id].points
            if overlap_start <= point.ts_utc <= overlap_end
        )
        grid = tuple(point.ts_utc for point in points)
        if reference_grid is None:
            reference_grid = grid
        elif grid != reference_grid:
            raise TraceValidationError(f"sleeve_timestamp_grid_mismatch:{sleeve_id}")
        sliced[sleeve_id] = points
    assert reference_grid is not None

    quantum = reference.quantum
    initial = _parse_money(starting_balance, "starting_balance", quantum)
    bases: dict[str, Decimal] = {}
    for sleeve_id, points in sliced.items():
        if not points:
            raise TraceValidationError(f"sleeve_overlap_empty:{sleeve_id}")
        first = points[0]
        if parsed_scales[sleeve_id] > 0 and (
            first.open_positions != 0 or first.equity != first.balance
        ):
            raise TraceValidationError(f"sleeve_not_flat_at_overlap_start:{sleeve_id}")
        bases[sleeve_id] = first.balance

    output: list[TracePoint] = []
    for index, timestamp in enumerate(reference_grid):
        balance = initial
        equity = initial
        interval_min_equity = initial
        open_positions = 0
        opened_positions = 0
        for sleeve_id in sleeve_ids:
            scale = parsed_scales[sleeve_id]
            if scale == 0:
                continue
            point = sliced[sleeve_id][index]
            balance += (point.balance - bases[sleeve_id]) * scale
            equity += (point.equity - bases[sleeve_id]) * scale
            interval_min_equity += (
                point.interval_min_equity - bases[sleeve_id]
            ) * scale
            open_positions += point.open_positions
            opened_positions += point.opened_positions
        try:
            balance = balance.quantize(quantum, rounding=ROUND_FLOOR)
            equity = equity.quantize(quantum, rounding=ROUND_FLOOR)
            interval_min_equity = interval_min_equity.quantize(
                quantum, rounding=ROUND_FLOOR
            )
        except InvalidOperation as exc:
            raise TraceValidationError(f"joint_money_outside_decimal_context:{index}") from exc
        if index == 0:
            # The rebased joint trace starts here; its first row has no preceding
            # interval even when the source sleeves have earlier history.
            interval_min_equity = equity
        if open_positions == 0 and balance != equity:
            raise TraceValidationError(f"joint_flat_book_equity_balance_mismatch:{index}")
        output.append(
            TracePoint(
                ts_utc=timestamp,
                balance=balance,
                equity=equity,
                interval_min_equity=interval_min_equity,
                open_positions=open_positions,
                opened_positions=opened_positions,
                day_anchor=_is_prague_midnight(timestamp),
            )
        )

    fingerprint_payload = {
        "schema": "FTMO_JOINT_TRACE_SOURCE_V1",
        "joint_trace_id": joint_trace_id.strip(),
        "starting_balance": format(initial, "f"),
        "overlap_start_utc": _timestamp(overlap_start),
        "overlap_end_utc": _timestamp(overlap_end),
        "sleeves": [
            {
                "sleeve_id": sleeve_id,
                "trace_id": traces[sleeve_id].trace_id,
                "source_fingerprint_sha256": traces[
                    sleeve_id
                ].source_fingerprint_sha256,
                "scale": format(parsed_scales[sleeve_id], "f"),
            }
            for sleeve_id in sleeve_ids
        ],
    }
    joint_source_fingerprint = hashlib.sha256(
        json.dumps(
            fingerprint_payload, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
    ).hexdigest()

    result = NormalizedTrace(
        trace_id=joint_trace_id.strip(),
        currency=reference.currency,
        source_fingerprint_sha256=joint_source_fingerprint,
        money_decimals=reference.money_decimals,
        grid_seconds=reference.grid_seconds,
        balance_basis=reference.balance_basis,
        equity_basis=reference.equity_basis,
        opened_positions_basis=reference.opened_positions_basis,
        interval_min_equity_basis=reference.interval_min_equity_basis,
        points=tuple(output),
    )
    _validate_normalized(result, minimum_complete_days=minimum_overlap_days)
    return result


def _money(value: Decimal, decimals: int) -> str:
    return format(value, f".{decimals}f")


def _timestamp(value: dt.datetime) -> str:
    return value.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def _base_result(
    trace: NormalizedTrace,
    rules: FtmoRuleSet,
    assumptions: EvaluationAssumptions,
    initial_balance: Decimal,
) -> dict[str, Any]:
    return {
        "rules_as_of": RULES_AS_OF,
        "rules_source_url": RULES_SOURCE_URL,
        "rule_set_id": rules.rule_set_id,
        "product": rules.product,
        "phase": rules.phase,
        "trace_id": trace.trace_id,
        "source_fingerprint_sha256": trace.source_fingerprint_sha256,
        "currency": trace.currency,
        "initial_balance": _money(initial_balance, trace.money_decimals),
        "trace_start_utc": _timestamp(trace.points[0].ts_utc),
        "trace_end_utc": _timestamp(trace.points[-1].ts_utc),
        "grid_seconds": trace.grid_seconds,
        "assumptions": {
            "day_boundary_timezone": "Europe/Prague",
            "day_boundary_local_time": "00:00:00",
            "equity_basis": EQUITY_BASIS_MTM,
            "balance_basis": BALANCE_BASIS_NET_TRADING,
            "opened_positions_basis": OPENED_POSITIONS_BASIS,
            "interval_min_equity_basis": INTERVAL_MIN_EQUITY_BASIS,
            "maximum_accepted_grid_seconds": assumptions.maximum_grid_seconds,
            "loss_limit_breach_operator": "equity < limit",
            "profit_target_operator": "balance >= target with flat book",
            "time_limit_days": None,
            "between_sample_equity_guard": "TICK_EVENT_COMPLETE_INTERVAL_MINIMUM",
            "scaled_money_rounding": "ROUND_FLOOR",
            "rule_threshold_arithmetic": "EXACT_DECIMAL_UNROUNDED",
        },
        "challenge_proof": False,
        "claim_boundary": "HISTORICAL_TICK_EVENT_COMPLETE_TRACE_RULE_SCREEN_ONLY",
    }


def _positive_day_metrics(
    completed_daily_pnl: Mapping[dt.date, Decimal],
    current_day: dt.date,
    current_day_pnl: Decimal,
) -> tuple[Decimal, Decimal, Decimal | None]:
    values = list(completed_daily_pnl.values())
    values.append(current_day_pnl)
    positive = [value for value in values if value > 0]
    if not positive:
        return Decimal(0), Decimal(0), None
    total = sum(positive, Decimal(0))
    best = max(positive)
    return total, best, best / total


def evaluate_trace(
    trace: NormalizedTrace,
    *,
    rules: FtmoRuleSet,
    initial_balance: Any,
    assumptions: EvaluationAssumptions,
) -> dict[str, Any]:
    """Evaluate one FTMO phase and return a JSON-safe deterministic artifact."""

    _validate_normalized(trace, minimum_complete_days=1)
    _validate_rules(rules)
    if not isinstance(assumptions, EvaluationAssumptions):
        raise TraceValidationError("evaluation_assumptions_required")
    if trace.grid_seconds > assumptions.maximum_grid_seconds:
        raise TraceValidationError(
            f"grid_too_coarse:{trace.grid_seconds}>{assumptions.maximum_grid_seconds}"
        )

    initial = _parse_money(initial_balance, "initial_balance", trace.quantum)
    if initial <= 0:
        raise TraceValidationError("initial_balance_not_positive")
    first = trace.points[0]
    if first.balance != initial:
        raise TraceValidationError(
            f"starting_balance_mismatch:{first.balance}!={initial}"
        )
    if first.equity != initial or first.open_positions != 0 or first.opened_positions != 0:
        raise TraceValidationError("challenge_start_not_flat_and_clean")

    daily_loss_amount = initial * rules.maximum_daily_loss_fraction
    maximum_loss_amount = initial * rules.maximum_loss_fraction
    target_balance = initial * (Decimal(1) + rules.profit_target_fraction)
    current_day = first.ts_utc.astimezone(PRAGUE).date()
    day_start_balance = initial
    completed_daily_pnl: dict[dt.date, Decimal] = {}
    trading_days: set[dt.date] = set()
    highest_midnight_balance = initial
    daily_floor = day_start_balance - daily_loss_amount
    maximum_floor = initial - maximum_loss_amount
    target_seen = False
    flat_target_seen = False
    last_best_total = Decimal(0)
    last_best_day = Decimal(0)
    last_best_ratio: Decimal | None = None

    def loss_breaches(
        observed_equity: Decimal,
        observed_daily_floor: Decimal,
        observed_maximum_floor: Decimal,
    ) -> list[str]:
        found: list[str] = []
        if observed_equity < observed_daily_floor:
            found.append("MAXIMUM_DAILY_LOSS")
        if observed_equity < observed_maximum_floor:
            found.append("MAXIMUM_LOSS")
        return found

    def terminal_breach(
        *,
        point: TracePoint,
        index: int,
        observed_equity: Decimal,
        observation: str,
        observed_daily_floor: Decimal,
        observed_maximum_floor: Decimal,
        breaches: list[str],
    ) -> dict[str, Any]:
        result = _base_result(trace, rules, assumptions, initial)
        result.update(
            {
                "status": "BREACH",
                "reason": "+".join(breaches),
                "breaches": breaches,
                "breach_equity_observation": observation,
                "terminal_sample_index": index,
                "terminal_timestamp_utc": _timestamp(point.ts_utc),
                "balance": _money(point.balance, trace.money_decimals),
                "equity": _money(observed_equity, trace.money_decimals),
                "sample_endpoint_equity": _money(
                    point.equity, trace.money_decimals
                ),
                "daily_loss_limit": _money(
                    observed_daily_floor, trace.money_decimals
                ),
                "maximum_loss_limit": _money(
                    observed_maximum_floor, trace.money_decimals
                ),
                "trading_days": len(trading_days),
            }
        )
        return result

    for index, point in enumerate(trace.points):
        local_day = point.ts_utc.astimezone(PRAGUE).date()
        if point.opened_positions > 0:
            trading_days.add(local_day)

        if index > 0:
            # This interval ends at the current point.  At a Prague boundary it
            # still belongs to the preceding risk day, so test it before reset
            # and before the 1-Step EOD ratchet.
            interval_breaches = loss_breaches(
                point.interval_min_equity, daily_floor, maximum_floor
            )
            if interval_breaches:
                return terminal_breach(
                    point=point,
                    index=index,
                    observed_equity=point.interval_min_equity,
                    observation=(
                        "INTERVAL_MIN_EQUITY_PRE_BOUNDARY_RESET"
                        if point.day_anchor
                        else "INTERVAL_MIN_EQUITY"
                    ),
                    observed_daily_floor=daily_floor,
                    observed_maximum_floor=maximum_floor,
                    breaches=interval_breaches,
                )

        if index > 0 and point.day_anchor:
            completed_daily_pnl[current_day] = point.balance - day_start_balance
            current_day = local_day
            day_start_balance = point.balance
            daily_floor = day_start_balance - daily_loss_amount
            if rules.maximum_loss_model is MaximumLossModel.EOD_TRAILING:
                highest_midnight_balance = max(highest_midnight_balance, point.balance)
                maximum_floor = highest_midnight_balance - maximum_loss_amount

        if index == 0 or point.day_anchor:
            # The first point has no interval.  Boundary endpoints must be
            # checked again after their new daily floor and EOD ratchet apply.
            endpoint_breaches = loss_breaches(
                point.equity, daily_floor, maximum_floor
            )
            if endpoint_breaches:
                return terminal_breach(
                    point=point,
                    index=index,
                    observed_equity=point.equity,
                    observation="ENDPOINT_EQUITY_POST_BOUNDARY_RESET",
                    observed_daily_floor=daily_floor,
                    observed_maximum_floor=maximum_floor,
                    breaches=endpoint_breaches,
                )

        current_day_pnl = point.balance - day_start_balance
        positive_total, best_day, best_ratio = _positive_day_metrics(
            completed_daily_pnl, current_day, current_day_pnl
        )
        last_best_total = positive_total
        last_best_day = best_day
        last_best_ratio = best_ratio

        at_target = point.balance >= target_balance
        flat_book = point.open_positions == 0 and point.equity == point.balance
        target_seen = target_seen or at_target
        flat_target_seen = flat_target_seen or (at_target and flat_book)
        best_day_satisfied = (
            rules.best_day_fraction is None
            or (
                best_ratio is not None
                and best_day <= rules.best_day_fraction * positive_total
            )
        )
        trading_days_satisfied = len(trading_days) >= rules.minimum_trading_days
        if at_target and flat_book and best_day_satisfied and trading_days_satisfied:
            result = _base_result(trace, rules, assumptions, initial)
            result.update(
                {
                    "status": "SCREEN_PASS",
                    "reason": "ALL_NUMERICAL_OBJECTIVES_SATISFIED_ON_HISTORICAL_TRACE",
                    "terminal_sample_index": index,
                    "terminal_timestamp_utc": _timestamp(point.ts_utc),
                    "balance": _money(point.balance, trace.money_decimals),
                    "equity": _money(point.equity, trace.money_decimals),
                    "target_balance": _money(target_balance, trace.money_decimals),
                    "daily_loss_limit": _money(daily_floor, trace.money_decimals),
                    "maximum_loss_limit": _money(maximum_floor, trace.money_decimals),
                    "trading_days": len(trading_days),
                    "minimum_trading_days": rules.minimum_trading_days,
                    "positive_days_profit": _money(positive_total, trace.money_decimals),
                    "best_day_profit": _money(best_day, trace.money_decimals),
                    "best_day_fraction": (
                        None if best_ratio is None else format(best_ratio, "f")
                    ),
                }
            )
            return result

    final = trace.points[-1]
    missing: list[str] = []
    if not target_seen:
        missing.append("PROFIT_TARGET")
    elif not flat_target_seen:
        missing.append("FLAT_BOOK_AT_TARGET")
    if len(trading_days) < rules.minimum_trading_days:
        missing.append("MINIMUM_TRADING_DAYS")
    if rules.best_day_fraction is not None and (
        last_best_ratio is None
        or last_best_day > rules.best_day_fraction * last_best_total
    ):
        missing.append("BEST_DAY_RULE")

    result = _base_result(trace, rules, assumptions, initial)
    result.update(
        {
            "status": "NOT_PASSED",
            "reason": "+".join(missing) if missing else "OBJECTIVES_NOT_SIMULTANEOUS",
            "missing_objectives": missing,
            "balance": _money(final.balance, trace.money_decimals),
            "equity": _money(final.equity, trace.money_decimals),
            "target_balance": _money(target_balance, trace.money_decimals),
            "daily_loss_limit": _money(daily_floor, trace.money_decimals),
            "maximum_loss_limit": _money(maximum_floor, trace.money_decimals),
            "trading_days": len(trading_days),
            "minimum_trading_days": rules.minimum_trading_days,
            "positive_days_profit": _money(last_best_total, trace.money_decimals),
            "best_day_profit": _money(last_best_day, trace.money_decimals),
            "best_day_fraction": (
                None if last_best_ratio is None else format(last_best_ratio, "f")
            ),
        }
    )
    return result


def evaluate_one_step(
    trace: NormalizedTrace,
    *,
    initial_balance: Any,
    assumptions: EvaluationAssumptions,
) -> dict[str, Any]:
    return evaluate_trace(
        trace,
        rules=ONE_STEP_CHALLENGE,
        initial_balance=initial_balance,
        assumptions=assumptions,
    )


def evaluate_two_step_phase(
    trace: NormalizedTrace,
    *,
    phase: str,
    initial_balance: Any,
    assumptions: EvaluationAssumptions,
) -> dict[str, Any]:
    normalized_phase = str(phase).strip().upper()
    if normalized_phase in {"PHASE1", "CHALLENGE"}:
        rules = TWO_STEP_PHASE1
    elif normalized_phase in {"VERIFICATION", "PHASE2"}:
        rules = TWO_STEP_VERIFICATION
    else:
        raise TraceValidationError(f"two_step_phase_invalid:{phase}")
    return evaluate_trace(
        trace,
        rules=rules,
        initial_balance=initial_balance,
        assumptions=assumptions,
    )


def evaluate_two_step(
    phase1_trace: NormalizedTrace,
    verification_trace: NormalizedTrace,
    *,
    initial_balance: Any,
    assumptions: EvaluationAssumptions,
) -> dict[str, Any]:
    """Evaluate chronological, non-overlapping fresh-start 2-Step traces."""

    _validate_normalized(phase1_trace, minimum_complete_days=1)
    _validate_normalized(verification_trace, minimum_complete_days=1)
    if phase1_trace.trace_id == verification_trace.trace_id:
        raise TraceValidationError("two_step_trace_ids_must_differ")
    if (
        phase1_trace.source_fingerprint_sha256
        == verification_trace.source_fingerprint_sha256
    ):
        raise TraceValidationError("two_step_source_fingerprints_must_differ")
    if phase1_trace.points[-1].ts_utc > verification_trace.points[0].ts_utc:
        raise TraceValidationError("two_step_phase_traces_overlap_or_reverse")

    phase1 = evaluate_two_step_phase(
        phase1_trace,
        phase="PHASE1",
        initial_balance=initial_balance,
        assumptions=assumptions,
    )
    verification = evaluate_two_step_phase(
        verification_trace,
        phase="VERIFICATION",
        initial_balance=initial_balance,
        assumptions=assumptions,
    )
    both_pass = phase1["status"] == verification["status"] == "SCREEN_PASS"
    return {
        "status": "SCREEN_PASS" if both_pass else "NOT_PASSED",
        "rules_as_of": RULES_AS_OF,
        "rules_source_url": RULES_SOURCE_URL,
        "challenge_proof": False,
        "claim_boundary": "TWO_CHRONOLOGICAL_HISTORICAL_TRACE_SCREENS_ONLY",
        "phase1": phase1,
        "verification": verification,
    }
