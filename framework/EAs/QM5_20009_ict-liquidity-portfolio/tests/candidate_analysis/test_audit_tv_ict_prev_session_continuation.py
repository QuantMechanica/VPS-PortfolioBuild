"""Synthetic guards for the fail-closed TradingView ICT continuation audit."""

from __future__ import annotations

import hashlib
import json
import sys
from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_TOOLS = EA_ROOT / "tools" / "candidate_analysis"
if str(CANDIDATE_TOOLS) not in sys.path:
    sys.path.insert(0, str(CANDIDATE_TOOLS))

import audit_tv_ict_prev_session_continuation as audit  # noqa: E402


def broker_epoch(value: datetime) -> int:
    return int((value - datetime(1970, 1, 1)).total_seconds())


def test_contract_hash_and_exact_blocker_set() -> None:
    assert audit.FINALIZATION_MARKER == "EXPLICIT_PATHSPEC_PRE_OUTCOME"
    assert hashlib.sha256(audit.CONTRACT_PATH.read_bytes()).hexdigest() == audit.EXPECTED_CONTRACT_SHA256
    contract = json.loads(audit.CONTRACT_PATH.read_text(encoding="utf-8"))
    audit.validate_contract(contract)
    blockers = tuple(item["id"] for item in contract["source_semantics"]["blocking_ambiguities"])
    assert blockers == audit.EXPECTED_BLOCKERS
    assert "DAY_FLAT_EXACT_BOUNDARY_AND_ORDER" in blockers
    assert contract["frozen_center_if_source_unblocked"]["day_flat"]["semantic_status"].startswith(
        "AMBIGUOUS_BLOCKED"
    )


def test_mismatch_record_hash_is_bound() -> None:
    assert hashlib.sha256(audit.MISMATCH_PATH.read_bytes()).hexdigest() == audit.EXPECTED_MISMATCH_SHA256


def test_preflight_block_never_opens_even_missing_outcome_inputs(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        audit,
        "committed_contract_identity",
        lambda: {
            "commit": "0" * 40,
            "path": audit.CONTRACT_PATH.relative_to(audit.REPO_ROOT).as_posix(),
            "sha256": audit.EXPECTED_CONTRACT_SHA256,
        },
    )
    monkeypatch.setattr(audit, "verify_bound_evidence", lambda: {"synthetic": "a" * 64})
    missing_root = Path("Z:/must-not-be-opened/market")
    missing_news = Path("Z:/must-not-be-opened/news.csv")
    first = audit.build_document(missing_root, missing_news)
    second = audit.build_document(missing_root, missing_news)
    assert audit.encode_document(first) == audit.encode_document(second)
    assert first["status"] == "BLOCKED_SOURCE_AMBIGUITY"
    assert first["decision"] == "NOT_ADJUDICATED"
    assert first["performance"] is None
    assert first["outcome_input_access"]["market_files_opened"] == 0
    assert first["outcome_input_access"]["market_ohlc_rows_parsed"] == 0
    assert first["outcome_input_access"]["news_files_opened"] == 0
    assert first["outcome_input_access"]["future_ohlc_parsed"] is False


def test_future_fence_does_not_parse_or_hash_2023_ohlc(tmp_path: Path) -> None:
    path = tmp_path / "EURUSD.DWX_M5.csv"
    selected = broker_epoch(datetime(2022, 12, 30, 23, 55))
    excluded = broker_epoch(datetime(2023, 1, 1, 0, 0))
    selected_line = f"{selected},1.10000,1.10100,1.09900,1.10050,12"
    path.write_text(
        "time,open,high,low,close,tickvol\n"
        f"{selected_line}\n"
        f"{excluded},FUTURE,OHLC,MUST,NOT_PARSE,NOPE\n",
        encoding="ascii",
    )
    market = audit.parse_selected_market(path, "EURUSD.DWX")
    assert len(market.bars) == 1
    assert market.identity.future_ohlc_parsed is False
    assert market.identity.first_excluded_timestamp == "2023-01-01 00:00:00"
    assert market.identity.selected_sha256 == hashlib.sha256(
        (selected_line + "\n").encode("ascii")
    ).hexdigest()


def test_selected_ohlc_is_validated_but_future_tail_is_not(tmp_path: Path) -> None:
    path = tmp_path / "GBPUSD.DWX_M5.csv"
    selected = broker_epoch(datetime(2022, 12, 30, 23, 55))
    excluded = broker_epoch(datetime(2023, 1, 1, 0, 0))
    path.write_text(
        "time,open,high,low,close,tickvol\n"
        f"{selected},1.10000,1.09900,1.10100,1.10050,12\n"
        f"{excluded},FUTURE,OHLC,MUST,NOT_PARSE,NOPE\n",
        encoding="ascii",
    )
    with pytest.raises(audit.AuditError, match="invalid selected OHLC"):
        audit.parse_selected_market(path, "GBPUSD.DWX")


def test_broker_wall_to_rome_handles_us_eu_dst_mismatch() -> None:
    # US DST is active on 2022-03-20 while EU DST is not: broker 09:00 is
    # UTC 06:00 and Rome 07:00, a two-hour wall-clock difference.
    mismatch_utc = audit.broker_wall_to_utc(datetime(2022, 3, 20, 9, 0))
    assert mismatch_utc == datetime(2022, 3, 20, 6, 0, tzinfo=timezone.utc)
    assert mismatch_utc.astimezone(audit.ROME).hour == 7

    # Once both regions are on DST, broker 09:00 maps to Rome 08:00.
    aligned_utc = audit.broker_wall_to_utc(datetime(2022, 4, 4, 9, 0))
    assert aligned_utc == datetime(2022, 4, 4, 6, 0, tzinfo=timezone.utc)
    assert aligned_utc.astimezone(audit.ROME).hour == 8


def test_rome_session_roll_is_exactly_six_local() -> None:
    before = datetime(2022, 7, 1, 3, 59, 59, tzinfo=timezone.utc)  # 05:59:59 Rome
    at_roll = datetime(2022, 7, 1, 4, 0, 0, tzinfo=timezone.utc)  # 06:00:00 Rome
    assert audit.rome_session_date(before) == date(2022, 6, 30)
    assert audit.rome_session_date(at_roll) == date(2022, 7, 1)


def test_body_cross_is_continuation_and_strict() -> None:
    high = Decimal("1.10500")
    low = Decimal("1.09500")
    assert audit.body_cross_side(Decimal("1.10400"), Decimal("1.10600"), high, low) == "LONG"
    assert audit.body_cross_side(Decimal("1.09600"), Decimal("1.09400"), high, low) == "SHORT"
    assert audit.body_cross_side(high, Decimal("1.10600"), high, low) is None
    assert audit.body_cross_side(Decimal("1.10400"), high, high, low) is None
    assert audit.body_cross_side(low, Decimal("1.09400"), high, low) is None
    assert audit.body_cross_side(Decimal("1.09600"), low, high, low) is None


def test_reentry_levels_are_five_pips_inside_previous_range() -> None:
    high = Decimal("1.10500")
    low = Decimal("1.09500")
    assert audit.reentry_level("LONG", high, low) == Decimal("1.10450")
    assert audit.reentry_level("SHORT", high, low) == Decimal("1.09550")


def test_actual_fill_and_brackets_use_execution_price() -> None:
    long_fill = audit.actual_fill("LONG", Decimal("1.10000"), 4)
    short_fill = audit.actual_fill("SHORT", Decimal("1.10000"), 4)
    assert long_fill == Decimal("1.10004")
    assert short_fill == Decimal("1.10000")
    long = audit.bracket_from_fill("LONG", long_fill)
    short = audit.bracket_from_fill("SHORT", short_fill)
    assert (long.stop, long.target) == (Decimal("1.09904"), Decimal("1.10204"))
    assert (short.stop, short.target) == (Decimal("1.10100"), Decimal("1.09800"))


def test_same_bar_stop_precedes_target_for_both_sides() -> None:
    long = audit.bracket_from_fill("LONG", Decimal("1.10000"))
    long_exit = audit.resolve_bar_exit(
        long,
        bid_open=Decimal("1.10000"),
        bid_high=Decimal("1.10300"),
        bid_low=Decimal("1.09800"),
        spread_points=4,
    )
    assert long_exit is not None
    assert long_exit.reason == "SL"
    assert long_exit.same_bar_sl_tp_conflict is True

    short = audit.bracket_from_fill("SHORT", Decimal("1.10000"))
    short_exit = audit.resolve_bar_exit(
        short,
        bid_open=Decimal("1.10000"),
        bid_high=Decimal("1.10200"),
        bid_low=Decimal("1.09700"),
        spread_points=4,
    )
    assert short_exit is not None
    assert short_exit.reason == "SL"
    assert short_exit.same_bar_sl_tp_conflict is True


def test_gap_policy_is_adverse_actual_open_and_no_favorable_improvement() -> None:
    long = audit.bracket_from_fill("LONG", Decimal("1.10000"))
    adverse = audit.resolve_bar_exit(
        long,
        bid_open=Decimal("1.09850"),
        bid_high=Decimal("1.09870"),
        bid_low=Decimal("1.09800"),
        spread_points=4,
    )
    assert adverse == audit.ExitEvent("SL_GAP", Decimal("1.09850"), False, True)
    favorable = audit.resolve_bar_exit(
        long,
        bid_open=Decimal("1.10300"),
        bid_high=Decimal("1.10350"),
        bid_low=Decimal("1.10250"),
        spread_points=4,
    )
    assert favorable == audit.ExitEvent("TP_GAP", long.target, False, True)


def test_external_commission_is_dealwise_half_up() -> None:
    assert audit.commission_side(Decimal("1"), Decimal("1.25")) == Decimal("3.13")
    assert audit.commission_side(Decimal("2"), Decimal("0.90")) == Decimal("5.00")
    # Frozen 10-lot center: each EURUSD side at 1.10 costs exactly $27.50.
    assert audit.commission_side(Decimal("10"), Decimal("1.10")) == Decimal("27.50")


def test_contract_commit_identity_is_real_after_preregistration() -> None:
    identity = audit.committed_contract_identity()
    assert len(identity["commit"]) == 40
    assert identity["sha256"] == audit.EXPECTED_CONTRACT_SHA256
