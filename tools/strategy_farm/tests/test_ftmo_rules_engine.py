import copy
import datetime as dt
import hashlib
import json
import sys
from dataclasses import replace
from decimal import Decimal
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

import pytest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_rules_engine as engine  # noqa: E402


PRAGUE = ZoneInfo("Europe/Prague")
HOURLY = engine.EvaluationAssumptions(maximum_grid_seconds=3600)


def make_envelope(
    *,
    trace_id: str = "trace",
    start_date: dt.date = dt.date(2026, 1, 5),
    days: int = 2,
    grid_seconds: int = 3600,
    currency: str = "USD",
    initial_balance: str = "100000.00",
    events: dict[tuple[int, int, int], dict[str, Any]] | None = None,
    source_fingerprint_sha256: str | None = None,
) -> dict[str, Any]:
    start_local = dt.datetime.combine(start_date, dt.time(), tzinfo=PRAGUE)
    end_local = dt.datetime.combine(
        start_date + dt.timedelta(days=days), dt.time(), tzinfo=PRAGUE
    )
    timestamp = start_local.astimezone(dt.UTC)
    end_utc = end_local.astimezone(dt.UTC)
    state: dict[str, Any] = {
        "balance": initial_balance,
        "equity": initial_balance,
        "open_positions": 0,
    }
    previous_equity = initial_balance
    rows: list[dict[str, Any]] = []
    while timestamp <= end_utc:
        local = timestamp.astimezone(PRAGUE)
        key = ((local.date() - start_date).days, local.hour, local.minute)
        event = dict((events or {}).get(key, {}))
        opened_positions = event.pop("opened_positions", 0)
        explicit_interval_min = event.pop("interval_min_equity", None)
        old_balance = state["balance"]
        state.update(event)
        if (
            state["open_positions"] == 0
            and "equity" not in event
            and ("balance" in event or old_balance != state["balance"])
        ):
            state["equity"] = state["balance"]
        if state["open_positions"] == 0 and "open_positions" in event and "equity" not in event:
            state["equity"] = state["balance"]
        interval_min_equity = (
            explicit_interval_min
            if explicit_interval_min is not None
            else str(min(Decimal(str(previous_equity)), Decimal(str(state["equity"]))))
        )
        if not rows:
            interval_min_equity = state["equity"]
        rows.append(
            {
                "ts_utc": timestamp.isoformat().replace("+00:00", "Z"),
                "balance": state["balance"],
                "equity": state["equity"],
                "interval_min_equity": interval_min_equity,
                "open_positions": state["open_positions"],
                "opened_positions": opened_positions,
                "day_anchor": (
                    local.hour == local.minute == local.second == local.microsecond == 0
                ),
            }
        )
        previous_equity = state["equity"]
        timestamp += dt.timedelta(seconds=grid_seconds)
    if source_fingerprint_sha256 is None:
        fingerprint_payload = {
            "trace_id": trace_id,
            "currency": currency,
            "grid_seconds": grid_seconds,
            "rows": rows,
        }
        source_fingerprint_sha256 = hashlib.sha256(
            json.dumps(
                fingerprint_payload, sort_keys=True, separators=(",", ":")
            ).encode("utf-8")
        ).hexdigest()
    return {
        "schema_version": 1,
        "trace_id": trace_id,
        "currency": currency,
        "source_fingerprint_sha256": source_fingerprint_sha256,
        "money_decimals": 2,
        "grid_seconds": grid_seconds,
        "balance_basis": engine.BALANCE_BASIS_NET_TRADING,
        "equity_basis": engine.EQUITY_BASIS_MTM,
        "opened_positions_basis": engine.OPENED_POSITIONS_BASIS,
        "interval_min_equity_basis": engine.INTERVAL_MIN_EQUITY_BASIS,
        "rows": rows,
    }


def normalized(**kwargs: Any) -> engine.NormalizedTrace:
    return engine.normalize_trace(make_envelope(**kwargs))


def test_normalize_accepts_complete_prague_days_across_dst() -> None:
    trace = normalized(start_date=dt.date(2026, 3, 28), days=3)

    anchors = [point for point in trace.points if point.day_anchor]

    assert len(anchors) == 4
    assert anchors[0].ts_utc.isoformat() == "2026-03-27T23:00:00+00:00"
    assert anchors[2].ts_utc.isoformat() == "2026-03-29T22:00:00+00:00"
    assert len(trace.points) == 72  # 71 elapsed DST-transition hours, inclusive endpoints


def test_normalize_accepts_autumn_dst_day_with_25_hours() -> None:
    trace = normalized(start_date=dt.date(2026, 10, 24), days=3)

    anchors = [point for point in trace.points if point.day_anchor]

    assert len(anchors) == 4
    assert anchors[0].ts_utc.isoformat() == "2026-10-23T22:00:00+00:00"
    assert anchors[2].ts_utc.isoformat() == "2026-10-25T23:00:00+00:00"
    assert len(trace.points) == 74  # 73 elapsed hours, inclusive endpoints


@pytest.mark.parametrize(
    ("field", "replacement", "reason"),
    [
        ("source_fingerprint_sha256", None, "source_fingerprint_sha256_invalid_or_missing"),
        ("source_fingerprint_sha256", "ABC", "source_fingerprint_sha256_invalid_or_missing"),
        ("opened_positions_basis", None, "opened_positions_basis_invalid_or_missing"),
        ("opened_positions_basis", "UNRECONCILED", "opened_positions_basis_invalid_or_missing"),
        (
            "interval_min_equity_basis",
            None,
            "interval_min_equity_basis_invalid_or_missing",
        ),
        (
            "interval_min_equity_basis",
            "BAR_LOW_PROXY",
            "interval_min_equity_basis_invalid_or_missing",
        ),
    ],
)
def test_normalize_requires_source_fingerprint_and_fixed_provenance_bases(
    field: str, replacement: str | None, reason: str
) -> None:
    envelope = make_envelope()
    if replacement is None:
        envelope.pop(field)
    else:
        envelope[field] = replacement

    with pytest.raises(engine.TraceValidationError, match=reason):
        engine.normalize_trace(envelope)


def test_normalize_requires_tick_complete_interval_minimum_and_zero_anchor_opens() -> None:
    missing = make_envelope()
    missing["rows"][5].pop("interval_min_equity")
    with pytest.raises(engine.TraceValidationError, match="interval_min_equity:5_invalid"):
        engine.normalize_trace(missing)

    above_endpoint = make_envelope()
    above_endpoint["rows"][5]["interval_min_equity"] = "100000.01"
    with pytest.raises(
        engine.TraceValidationError, match="interval_min_equity_exceeds_endpoint:5"
    ):
        engine.normalize_trace(above_endpoint)

    first_mismatch = make_envelope()
    first_mismatch["rows"][0]["interval_min_equity"] = "99999.99"
    with pytest.raises(
        engine.TraceValidationError, match="first_interval_min_equity_must_equal_equity"
    ):
        engine.normalize_trace(first_mismatch)

    anchor_open = make_envelope()
    anchor_open["rows"][24]["opened_positions"] = 1
    with pytest.raises(
        engine.TraceValidationError, match="opened_positions_at_day_anchor_forbidden:24"
    ):
        engine.normalize_trace(anchor_open)


@pytest.mark.parametrize(
    ("mutator", "reason"),
    [
        (
            lambda env: env["rows"].__setitem__(10, copy.deepcopy(env["rows"][9])),
            "duplicate_timestamp",
        ),
        (
            lambda env: env["rows"][8].__setitem__(
                "ts_utc", "2026-01-05T05:30:00Z"
            ),
            "timestamps_not_strictly_increasing",
        ),
        (
            lambda env: env["rows"].pop(10),
            "grid_interval_mismatch",
        ),
        (
            lambda env: env["rows"][24].__setitem__("day_anchor", False),
            "day_anchor_missing",
        ),
        (
            lambda env: env["rows"][10].__setitem__("day_anchor", True),
            "day_anchor_not_midnight",
        ),
        (
            lambda env: env["rows"].pop(0),
            "trace_start_eod_anchor_missing",
        ),
        (
            lambda env: env["rows"].pop(),
            "trace_end_eod_anchor_missing",
        ),
    ],
)
def test_normalize_fails_closed_on_order_grid_and_anchor_attacks(mutator, reason) -> None:
    envelope = make_envelope()
    mutator(envelope)

    with pytest.raises(engine.TraceValidationError, match=reason):
        engine.normalize_trace(envelope)


def test_normalize_rejects_closed_pnl_only_equity_substitute() -> None:
    envelope = make_envelope()
    envelope["equity_basis"] = "CLOSED_PNL_ONLY"

    with pytest.raises(
        engine.TraceValidationError,
        match="closed_pnl_only_inadmissible_for_equity_gates",
    ):
        engine.normalize_trace(envelope)


def test_normalize_requires_explicit_no_external_cashflow_balance_basis() -> None:
    envelope = make_envelope()
    envelope.pop("balance_basis")

    with pytest.raises(engine.TraceValidationError, match="balance_basis_invalid_or_missing"):
        engine.normalize_trace(envelope)


def test_normalize_rejects_missing_equity_and_excess_money_precision() -> None:
    missing = make_envelope()
    missing["rows"][10].pop("equity")
    with pytest.raises(engine.TraceValidationError, match="equity:10_invalid"):
        engine.normalize_trace(missing)

    precision = make_envelope()
    precision["rows"][10]["balance"] = "100000.001"
    precision["rows"][10]["equity"] = "100000.001"
    with pytest.raises(
        engine.TraceValidationError,
        match="precision_exceeds_money_decimals",
    ):
        engine.normalize_trace(precision)


def test_normalize_rejects_row_metadata_and_flat_book_inconsistencies() -> None:
    currency = make_envelope()
    currency["rows"][5]["currency"] = "EUR"
    with pytest.raises(engine.TraceValidationError, match="row_currency_mismatch"):
        engine.normalize_trace(currency)

    grid = make_envelope()
    grid["rows"][5]["grid_seconds"] = 60
    with pytest.raises(engine.TraceValidationError, match="row_grid_mismatch"):
        engine.normalize_trace(grid)

    flat = make_envelope()
    flat["rows"][5]["equity"] = "99999.00"
    with pytest.raises(
        engine.TraceValidationError, match="flat_book_equity_balance_mismatch"
    ):
        engine.normalize_trace(flat)


def test_combine_rebases_and_scales_only_exact_common_grid() -> None:
    first = normalized(
        trace_id="first",
        initial_balance="100000.00",
        events={(0, 10, 0): {"balance": "100100.00", "opened_positions": 1}},
    )
    second = normalized(
        trace_id="second",
        initial_balance="200000.00",
        events={(0, 10, 0): {"balance": "199950.00", "opened_positions": 1}},
    )

    joint = engine.combine_synchronized_traces(
        {"a": first, "b": second},
        starting_balance="100000.00",
        minimum_overlap_days=2,
        scales={"a": "2.0", "b": "1.0"},
    )

    at_event = next(
        point
        for point in joint.points
        if point.ts_utc.astimezone(PRAGUE).hour == 10
    )
    assert at_event.balance == Decimal("100150.00")
    assert at_event.equity == Decimal("100150.00")
    assert at_event.opened_positions == 2


def test_combine_rejects_currency_grid_and_scale_key_mismatch() -> None:
    usd = normalized(trace_id="usd")
    eur = normalized(trace_id="eur", currency="EUR")
    with pytest.raises(engine.TraceValidationError, match="sleeve_currency_mismatch"):
        engine.combine_synchronized_traces(
            {"usd": usd, "eur": eur},
            starting_balance="100000.00",
            minimum_overlap_days=1,
        )

    half_hour = normalized(trace_id="half", grid_seconds=1800)
    with pytest.raises(engine.TraceValidationError, match="sleeve_grid_mismatch"):
        engine.combine_synchronized_traces(
            {"hour": usd, "half": half_hour},
            starting_balance="100000.00",
            minimum_overlap_days=1,
        )

    with pytest.raises(engine.TraceValidationError, match="sleeve_scale_keys_mismatch"):
        engine.combine_synchronized_traces(
            {"a": usd, "b": normalized(trace_id="b")},
            starting_balance="100000.00",
            minimum_overlap_days=1,
            scales={"a": 1},
        )


def test_combine_rejects_insufficient_overlap_and_open_seed_position() -> None:
    long_trace = normalized(trace_id="long", days=3)
    late_trace = normalized(
        trace_id="late", start_date=dt.date(2026, 1, 7), days=1
    )
    with pytest.raises(engine.TraceValidationError, match="insufficient_overlap_days:1<2"):
        engine.combine_synchronized_traces(
            {"long": long_trace, "late": late_trace},
            starting_balance="100000.00",
            minimum_overlap_days=2,
        )

    seeded = normalized(
        trace_id="seeded",
        events={(0, 0, 0): {"open_positions": 1, "equity": "99990.00"}},
    )
    with pytest.raises(engine.TraceValidationError, match="sleeve_not_flat_at_overlap_start"):
        engine.combine_synchronized_traces(
            {"flat": normalized(trace_id="flat"), "seeded": seeded},
            starting_balance="100000.00",
            minimum_overlap_days=1,
        )


def test_combine_rejects_duplicate_object_trace_id_and_source_fingerprint() -> None:
    same = normalized(trace_id="same")
    with pytest.raises(engine.TraceValidationError, match="duplicate_sleeve_object_identity"):
        engine.combine_synchronized_traces(
            {"a": same, "b": same},
            starting_balance="100000.00",
            minimum_overlap_days=1,
        )

    duplicate_id_a = normalized(
        trace_id="duplicate-id", source_fingerprint_sha256="1" * 64
    )
    duplicate_id_b = normalized(
        trace_id="duplicate-id", source_fingerprint_sha256="2" * 64
    )
    with pytest.raises(engine.TraceValidationError, match="duplicate_sleeve_trace_id"):
        engine.combine_synchronized_traces(
            {"a": duplicate_id_a, "b": duplicate_id_b},
            starting_balance="100000.00",
            minimum_overlap_days=1,
        )

    duplicate_source_a = normalized(
        trace_id="source-a", source_fingerprint_sha256="a" * 64
    )
    duplicate_source_b = normalized(
        trace_id="source-b", source_fingerprint_sha256="a" * 64
    )
    with pytest.raises(
        engine.TraceValidationError,
        match="duplicate_sleeve_source_fingerprint_sha256",
    ):
        engine.combine_synchronized_traces(
            {"a": duplicate_source_a, "b": duplicate_source_b},
            starting_balance="100000.00",
            minimum_overlap_days=1,
        )


def test_combine_rounds_scaled_money_down_at_target_boundary() -> None:
    sleeve = normalized(
        trace_id="round-down",
        days=4,
        events={
            (0, 10, 0): {"balance": "102499.99", "opened_positions": 1},
            (1, 10, 0): {"balance": "104999.99", "opened_positions": 1},
            (2, 10, 0): {"balance": "107499.99", "opened_positions": 1},
            (3, 10, 0): {"balance": "109999.99", "opened_positions": 1},
        },
    )

    joint = engine.combine_synchronized_traces(
        {"sleeve": sleeve},
        starting_balance="100000.00",
        minimum_overlap_days=4,
        scales={"sleeve": "1.0000006"},
    )
    result = engine.evaluate_two_step_phase(
        joint,
        phase="PHASE1",
        initial_balance="100000.00",
        assumptions=HOURLY,
    )

    assert joint.points[-1].balance == Decimal("109999.99")
    assert result["status"] == "NOT_PASSED"
    assert result["assumptions"]["scaled_money_rounding"] == "ROUND_FLOOR"
    assert len(joint.source_fingerprint_sha256) == 64


def test_one_step_uses_mtm_equity_for_three_percent_daily_loss() -> None:
    trace = normalized(
        events={
            (0, 10, 0): {
                "balance": "100000.00",
                "equity": "96999.99",
                "open_positions": 1,
                "opened_positions": 1,
            }
        }
    )

    result = engine.evaluate_one_step(
        trace, initial_balance="100000.00", assumptions=HOURLY
    )

    assert result["status"] == "BREACH"
    assert result["breaches"] == ["MAXIMUM_DAILY_LOSS"]
    assert result["daily_loss_limit"] == "97000.00"


def test_interval_min_equity_catches_breach_recovered_before_endpoint() -> None:
    trace = normalized(
        events={(0, 10, 0): {"interval_min_equity": "96999.99"}}
    )

    result = engine.evaluate_one_step(
        trace, initial_balance="100000.00", assumptions=HOURLY
    )

    assert result["status"] == "BREACH"
    assert result["breaches"] == ["MAXIMUM_DAILY_LOSS"]
    assert result["breach_equity_observation"] == "INTERVAL_MIN_EQUITY"
    assert result["equity"] == "96999.99"
    assert result["sample_endpoint_equity"] == "100000.00"


def test_midnight_interval_uses_old_floor_then_endpoint_uses_new_ratchet() -> None:
    prior_day_interval_breach = normalized(
        events={(1, 0, 0): {"interval_min_equity": "96999.99"}}
    )
    prior_result = engine.evaluate_one_step(
        prior_day_interval_breach,
        initial_balance="100000.00",
        assumptions=HOURLY,
    )
    assert prior_result["status"] == "BREACH"
    assert (
        prior_result["breach_equity_observation"]
        == "INTERVAL_MIN_EQUITY_PRE_BOUNDARY_RESET"
    )
    assert prior_result["daily_loss_limit"] == "97000.00"
    assert prior_result["sample_endpoint_equity"] == "100000.00"

    post_ratchet_endpoint_breach = normalized(
        days=2,
        events={
            (0, 10, 0): {"balance": "110000.00", "opened_positions": 1},
            (0, 23, 0): {
                "equity": "110000.00",
                "open_positions": 1,
                "opened_positions": 1,
            },
            (1, 0, 0): {"equity": "99999.99"},
        },
    )
    post_result = engine.evaluate_one_step(
        post_ratchet_endpoint_breach,
        initial_balance="100000.00",
        assumptions=HOURLY,
    )
    assert post_result["status"] == "BREACH"
    assert post_result["breach_equity_observation"] == "ENDPOINT_EQUITY_POST_BOUNDARY_RESET"
    assert post_result["breaches"] == ["MAXIMUM_DAILY_LOSS", "MAXIMUM_LOSS"]
    assert post_result["maximum_loss_limit"] == "100000.00"


def test_exact_loss_limit_is_not_a_breach_under_published_below_wording() -> None:
    trace = normalized(
        events={
            (0, 10, 0): {
                "equity": "97000.00",
                "open_positions": 1,
                "opened_positions": 1,
            },
            (0, 11, 0): {"open_positions": 0},
        }
    )

    result = engine.evaluate_one_step(
        trace, initial_balance="100000.00", assumptions=HOURLY
    )

    assert result["status"] == "NOT_PASSED"
    assert result["assumptions"]["loss_limit_breach_operator"] == "equity < limit"


def test_one_step_maximum_loss_trails_highest_midnight_balance_only_upward() -> None:
    trace = normalized(
        days=5,
        events={
            (0, 10, 0): {"balance": "104000.00", "opened_positions": 1},
            (1, 10, 0): {"balance": "101000.00", "opened_positions": 1},
            (2, 10, 0): {"balance": "98000.00", "opened_positions": 1},
            (3, 10, 0): {"balance": "95000.00", "opened_positions": 1},
            (4, 10, 0): {
                "equity": "93999.99",
                "open_positions": 1,
                "opened_positions": 1,
            },
        },
    )

    result = engine.evaluate_one_step(
        trace, initial_balance="100000.00", assumptions=HOURLY
    )

    assert result["status"] == "BREACH"
    assert result["breaches"] == ["MAXIMUM_LOSS"]
    assert result["maximum_loss_limit"] == "94000.00"
    assert result["daily_loss_limit"] == "92000.00"


def test_one_step_intraday_balance_peak_does_not_ratchet_maximum_loss() -> None:
    trace = normalized(
        days=4,
        events={
            (0, 10, 0): {"balance": "104000.00", "opened_positions": 1},
            (0, 20, 0): {"balance": "100000.00", "opened_positions": 1},
            (1, 10, 0): {"balance": "97000.00", "opened_positions": 1},
            (2, 10, 0): {"balance": "94000.00", "opened_positions": 1},
            (3, 10, 0): {
                "equity": "93000.00",
                "open_positions": 1,
                "opened_positions": 1,
            },
            (3, 11, 0): {"open_positions": 0},
        }
    )

    result = engine.evaluate_one_step(
        trace, initial_balance="100000.00", assumptions=HOURLY
    )

    assert result["status"] == "NOT_PASSED"
    assert result["maximum_loss_limit"] == "90000.00"


def test_one_step_target_waits_until_best_day_is_half_of_positive_days() -> None:
    trace = normalized(
        events={
            (0, 10, 0): {"balance": "110000.00", "opened_positions": 1},
            (1, 10, 0): {"balance": "120000.00", "opened_positions": 1},
        }
    )

    result = engine.evaluate_one_step(
        trace, initial_balance="100000.00", assumptions=HOURLY
    )

    assert result["status"] == "SCREEN_PASS"
    assert result["terminal_timestamp_utc"] == "2026-01-06T09:00:00Z"
    assert result["positive_days_profit"] == "20000.00"
    assert result["best_day_profit"] == "10000.00"
    assert result["best_day_fraction"] == "0.5"
    assert result["challenge_proof"] is False


def test_one_step_best_day_denominator_excludes_negative_days() -> None:
    trace = normalized(
        days=4,
        events={
            (0, 10, 0): {"balance": "106000.00", "opened_positions": 1},
            (1, 10, 0): {"balance": "104000.00", "opened_positions": 1},
            (2, 10, 0): {"balance": "108000.00", "opened_positions": 1},
            (3, 10, 0): {"balance": "110000.00", "opened_positions": 1},
        },
    )

    result = engine.evaluate_one_step(
        trace, initial_balance="100000.00", assumptions=HOURLY
    )

    assert result["status"] == "SCREEN_PASS"
    assert result["positive_days_profit"] == "12000.00"
    assert result["best_day_profit"] == "6000.00"
    assert result["best_day_fraction"] == "0.5"


def test_one_step_target_requires_flat_book_at_same_sample() -> None:
    trace = normalized(
        events={
            (0, 10, 0): {"balance": "105000.00", "opened_positions": 1},
            (1, 10, 0): {
                "balance": "110000.00",
                "equity": "110000.00",
                "open_positions": 1,
                "opened_positions": 1,
            },
            (1, 11, 0): {"open_positions": 0},
        }
    )

    result = engine.evaluate_one_step(
        trace, initial_balance="100000.00", assumptions=HOURLY
    )

    assert result["status"] == "SCREEN_PASS"
    assert result["terminal_timestamp_utc"] == "2026-01-06T10:00:00Z"


def four_day_profit_trace(
    *,
    verification: bool = False,
    start_date: dt.date | None = None,
    trace_id: str | None = None,
) -> engine.NormalizedTrace:
    increment = 1250 if verification else 2500
    if start_date is None:
        start_date = dt.date(2026, 1, 9) if verification else dt.date(2026, 1, 5)
    if trace_id is None:
        trace_id = "verification" if verification else "phase1"
    events = {
        (day, 10, 0): {
            "balance": f"{100000 + increment * (day + 1):.2f}",
            "opened_positions": 1,
        }
        for day in range(4)
    }
    return normalized(
        trace_id=trace_id,
        start_date=start_date,
        days=4,
        events=events,
    )


def test_two_step_phase1_and_verification_have_distinct_targets() -> None:
    phase1 = engine.evaluate_two_step_phase(
        four_day_profit_trace(),
        phase="PHASE1",
        initial_balance="100000.00",
        assumptions=HOURLY,
    )
    verification = engine.evaluate_two_step_phase(
        four_day_profit_trace(verification=True),
        phase="VERIFICATION",
        initial_balance="100000.00",
        assumptions=HOURLY,
    )

    assert phase1["status"] == "SCREEN_PASS"
    assert phase1["target_balance"] == "110000.00"
    assert phase1["trading_days"] == 4
    assert verification["status"] == "SCREEN_PASS"
    assert verification["target_balance"] == "105000.00"
    assert verification["trading_days"] == 4


def test_two_step_target_does_not_waive_four_trading_days() -> None:
    trace = normalized(
        days=4,
        events={(0, 10, 0): {"balance": "110000.00", "opened_positions": 1}},
    )

    result = engine.evaluate_two_step_phase(
        trace,
        phase="PHASE1",
        initial_balance="100000.00",
        assumptions=HOURLY,
    )

    assert result["status"] == "NOT_PASSED"
    assert result["missing_objectives"] == ["MINIMUM_TRADING_DAYS"]


def test_two_step_uses_five_percent_daily_and_static_ten_percent_limits() -> None:
    daily = normalized(
        events={
            (0, 10, 0): {
                "equity": "94999.99",
                "open_positions": 1,
                "opened_positions": 1,
            }
        }
    )
    daily_result = engine.evaluate_two_step_phase(
        daily,
        phase="PHASE1",
        initial_balance="100000.00",
        assumptions=HOURLY,
    )
    assert daily_result["breaches"] == ["MAXIMUM_DAILY_LOSS"]

    static = normalized(
        days=3,
        events={
            (0, 10, 0): {"balance": "95000.00", "opened_positions": 1},
            (1, 10, 0): {"balance": "90000.00", "opened_positions": 1},
            (2, 10, 0): {
                "equity": "89999.99",
                "open_positions": 1,
                "opened_positions": 1,
            },
        },
    )
    static_result = engine.evaluate_two_step_phase(
        static,
        phase="PHASE1",
        initial_balance="100000.00",
        assumptions=HOURLY,
    )
    assert static_result["breaches"] == ["MAXIMUM_LOSS"]
    assert static_result["maximum_loss_limit"] == "90000.00"


def test_two_step_has_no_engine_deadline() -> None:
    events = {
        (0, 10, 0): {"balance": "101250.00", "opened_positions": 1},
        (10, 10, 0): {"balance": "102500.00", "opened_positions": 1},
        (20, 10, 0): {"balance": "103750.00", "opened_positions": 1},
        (39, 10, 0): {"balance": "105000.00", "opened_positions": 1},
    }
    trace = normalized(days=40, events=events)

    result = engine.evaluate_two_step_phase(
        trace,
        phase="VERIFICATION",
        initial_balance="100000.00",
        assumptions=HOURLY,
    )

    assert result["status"] == "SCREEN_PASS"
    assert result["trading_days"] == 4
    assert result["assumptions"]["time_limit_days"] is None


def test_two_step_wrapper_requires_fresh_start_for_each_phase() -> None:
    result = engine.evaluate_two_step(
        four_day_profit_trace(),
        four_day_profit_trace(verification=True),
        initial_balance="100000.00",
        assumptions=HOURLY,
    )
    assert result["status"] == "SCREEN_PASS"
    assert result["challenge_proof"] is False

    wrong_start = normalized(
        trace_id="wrong-verification",
        start_date=dt.date(2026, 1, 9),
        initial_balance="110000.00",
        days=4,
    )
    with pytest.raises(engine.TraceValidationError, match="starting_balance_mismatch"):
        engine.evaluate_two_step(
            four_day_profit_trace(),
            wrong_start,
            initial_balance="100000.00",
            assumptions=HOURLY,
        )


def test_two_step_wrapper_rejects_duplicate_identity_and_overlapping_phases() -> None:
    phase1 = four_day_profit_trace()
    verification = four_day_profit_trace(verification=True)

    duplicate_id = replace(verification, trace_id=phase1.trace_id)
    with pytest.raises(engine.TraceValidationError, match="two_step_trace_ids_must_differ"):
        engine.evaluate_two_step(
            phase1,
            duplicate_id,
            initial_balance="100000.00",
            assumptions=HOURLY,
        )

    duplicate_fingerprint = replace(
        verification,
        source_fingerprint_sha256=phase1.source_fingerprint_sha256,
    )
    with pytest.raises(
        engine.TraceValidationError, match="two_step_source_fingerprints_must_differ"
    ):
        engine.evaluate_two_step(
            phase1,
            duplicate_fingerprint,
            initial_balance="100000.00",
            assumptions=HOURLY,
        )

    overlapping = four_day_profit_trace(
        verification=True,
        start_date=dt.date(2026, 1, 8),
        trace_id="overlapping-verification",
    )
    with pytest.raises(
        engine.TraceValidationError, match="two_step_phase_traces_overlap_or_reverse"
    ):
        engine.evaluate_two_step(
            phase1,
            overlapping,
            initial_balance="100000.00",
            assumptions=HOURLY,
        )


def test_evaluate_trace_rejects_non_frozen_custom_rules() -> None:
    weakened = engine.FtmoRuleSet(
        rule_set_id="FAKE_FTMO",
        product="1_STEP",
        phase="CHALLENGE",
        profit_target_fraction=Decimal("0.0001"),
        maximum_daily_loss_fraction=Decimal("0.90"),
        maximum_loss_fraction=Decimal("0.90"),
        maximum_loss_model=engine.MaximumLossModel.STATIC_INITIAL,
        minimum_trading_days=0,
        best_day_fraction=None,
    )
    trace = normalized(
        events={(0, 10, 0): {"balance": "100010.00", "opened_positions": 1}}
    )

    with pytest.raises(
        engine.TraceValidationError, match="rules_not_frozen_official_profile"
    ):
        engine.evaluate_trace(
            trace,
            rules=weakened,
            initial_balance="100000.00",
            assumptions=HOURLY,
        )


def test_evaluator_rejects_grid_coarser_than_explicit_business_assumption() -> None:
    trace = normalized()

    with pytest.raises(engine.TraceValidationError, match="grid_too_coarse:3600>60"):
        engine.evaluate_one_step(
            trace,
            initial_balance="100000.00",
            assumptions=engine.EvaluationAssumptions(maximum_grid_seconds=60),
        )


def test_evaluator_revalidates_manually_spoofed_normalized_trace() -> None:
    spoofed = replace(normalized(), equity_basis="CLOSED_PNL_ONLY")

    with pytest.raises(engine.TraceValidationError, match="normalized_equity_basis_invalid"):
        engine.evaluate_one_step(
            spoofed,
            initial_balance="100000.00",
            assumptions=HOURLY,
        )
