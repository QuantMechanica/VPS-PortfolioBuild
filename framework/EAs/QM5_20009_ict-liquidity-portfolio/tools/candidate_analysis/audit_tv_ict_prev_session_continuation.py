#!/usr/bin/env python3
"""Fail-closed offline DEV auditor for TradingView ICT continuation source.

The exact Pine revision is unavailable.  The committed contract therefore
requires a deterministic source-admissibility preflight to stop before any
market/news input is opened.  This module also contains synthetic-testable
primitives for the timestamp fence, Darwinex wall-clock conversion, known
body-cross predicates, conservative execution, and exact commission.  Those
primitives are not used to manufacture an outcome while source semantics are
blocked.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP, localcontext
from pathlib import Path
from typing import Any, Mapping, Sequence
from zoneinfo import ZoneInfo


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
CONTRACT_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "tv_ict_prev_session_continuation_dev_contract.json"
)
MISMATCH_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "tv_ict_source_mismatch_qm5_9987.md"
)
TEST_PATH = (
    EA_ROOT
    / "tests"
    / "candidate_analysis"
    / "test_audit_tv_ict_prev_session_continuation.py"
)

ANALYSIS_ID = "QM5_20009_TV_ICT_PREV_SESSION_CONTINUATION_DEV_001"
FINALIZATION_MARKER = "EXPLICIT_PATHSPEC_PRE_OUTCOME"
EXPECTED_CONTRACT_SHA256 = "cb2b775eae86ff319cf94f0572b32ba5165d6325dfeb3e107b0e726a4f46820f"
EXPECTED_MISMATCH_SHA256 = "b253c789c959dd483f5d7d7f9bb064c2a09314e751ab59cb6e2a0fa7e43b3c4e"

DEFAULT_DATA_ROOT = Path(r"D:\QM\mt5\T_Export\MQL5\Files")
DEFAULT_NEWS_PATH = Path(r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv")
EXPECTED_NEWS_SHA256 = "8e898ca1c4aed5fbc4cbe43fc176e8d8595c2e6f5f05c2984c2468527d4f5b0d"

BROKER_FROM = datetime(2017, 10, 1)
BROKER_TO = datetime(2023, 1, 1)
TIMEFRAME_SECONDS = 300
POINT = Decimal("0.00001")
PIP = Decimal("0.00010")
SL_PIPS = Decimal("10")
TP_PIPS = Decimal("20")
RISK_USD = Decimal("1000")
CENT = Decimal("0.01")
ROME = ZoneInfo("Europe/Rome")
NEW_YORK = ZoneInfo("America/New_York")

EXPECTED_BLOCKERS = (
    "DAY_FLAT_EXACT_BOUNDARY_AND_ORDER",
    "REENTRY_TOLERANCE_PREDICATE",
    "RETEST_PREDICATE_AND_SAME_BAR_TRANSITIONS",
    "MIN_BARS_COUNTER_ORIGIN",
    "OPPOSITE_BREAK_RESET_PRECEDENCE",
    "PINE_ORDER_PROCESSING_MODE",
)

EXPECTED_EVIDENCE_SHA256 = {
    Path(r"D:\QM\strategy_farm\artifacts\source_notes\30591366-874b-5bee-b47c-da2fca20b728.md"):
        "c39a1dbe7b9df2a6c4ff2c760fe83201b6256f04cae6d424e9aa5a10414f6665",
    Path(r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_9987_tv-ict-session-break-reentry-retest.md"):
        "869c581c20f6d8516cd94c1633c4a02652ecf15a126a99c9bffb5f78e96e6e56",
    REPO_ROOT / "framework" / "EAs" / "QM5_9987_tv-ict-session-break-reentry-retest" / "SPEC.md":
        "234ce3b7952d67cbac08fd032cbfc620621c6f51c2dbca421c700c321f603bdd",
    REPO_ROOT / "framework" / "EAs" / "QM5_9987_tv-ict-session-break-reentry-retest" / "QM5_9987_tv-ict-session-break-reentry-retest.mq5":
        "15ae1ab6b862fd0d558c19f2e46285fc69201b283037583301053fef425c3631",
}


class AuditError(RuntimeError):
    """Fail-closed contract, provenance, or data-integrity error."""


@dataclass(frozen=True)
class Bar:
    timestamp: int
    broker_time: datetime
    utc_time: datetime
    rome_time: datetime
    new_york_time: datetime
    open: float
    high: float
    low: float
    close: float
    tick_volume: int


@dataclass(frozen=True)
class SliceIdentity:
    path: str
    selected_sha256: str
    selected_rows: int
    first_selected_broker_time: str
    last_selected_broker_time: str
    first_excluded_timestamp: str
    future_ohlc_parsed: bool


@dataclass(frozen=True)
class MarketSlice:
    symbol: str
    bars: tuple[Bar, ...]
    identity: SliceIdentity


@dataclass(frozen=True)
class Bracket:
    side: str
    entry: Decimal
    stop: Decimal
    target: Decimal


@dataclass(frozen=True)
class ExitEvent:
    reason: str
    price: Decimal
    same_bar_sl_tp_conflict: bool
    gap: bool


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def repo_label(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return str(resolved).replace("\\", "/")


def stamp(value: datetime) -> str:
    return value.isoformat(sep=" ", timespec="seconds")


def naive_epoch(value: datetime) -> int:
    return int((value - datetime(1970, 1, 1)).total_seconds())


def broker_wall_datetime(timestamp: int) -> datetime:
    return datetime(1970, 1, 1) + timedelta(seconds=timestamp)


def broker_wall_to_utc(value: datetime) -> datetime:
    """Map a Darwinex UTC+2/+3 wall clock to the represented UTC instant.

    Darwinex follows the US DST boundary.  Test the UTC+3 candidate in New
    York; if New York is on DST at that instant, it is the valid mapping.
    Otherwise use UTC+2.  This mirrors the repository's canonical vectorized
    converter without treating the wall-clock integer as Unix UTC.
    """

    if value.tzinfo is not None:
        raise AuditError("broker wall clock must be naive")
    daylight_candidate = (value - timedelta(hours=3)).replace(tzinfo=timezone.utc)
    if daylight_candidate.astimezone(NEW_YORK).dst() not in (None, timedelta(0)):
        return daylight_candidate
    return (value - timedelta(hours=2)).replace(tzinfo=timezone.utc)


def rome_session_date(utc_time: datetime) -> date:
    if utc_time.tzinfo is None:
        raise AuditError("UTC instant must be timezone-aware")
    local = utc_time.astimezone(ROME)
    if (local.hour, local.minute, local.second) < (6, 0, 0):
        return local.date() - timedelta(days=1)
    return local.date()


def new_york_date(utc_time: datetime) -> date:
    if utc_time.tzinfo is None:
        raise AuditError("UTC instant must be timezone-aware")
    return utc_time.astimezone(NEW_YORK).date()


def body_cross_side(
    open_price: Decimal,
    close_price: Decimal,
    previous_high: Decimal,
    previous_low: Decimal,
) -> str | None:
    """Return the continuation direction for the source-described body cross."""

    if previous_low >= previous_high:
        raise AuditError("previous session range is invalid")
    long_break = open_price < previous_high and close_price > previous_high
    short_break = open_price > previous_low and close_price < previous_low
    if long_break and short_break:
        raise AuditError("one body cannot cross both valid previous-session extremes")
    if long_break:
        return "LONG"
    if short_break:
        return "SHORT"
    return None


def reentry_level(side: str, previous_high: Decimal, previous_low: Decimal) -> Decimal:
    """Return only the source-described 5-pip-inside yellow level.

    This does not decide whether a bar has reentered: the missing Pine leaves
    that predicate blocked in the contract.
    """

    depth = Decimal("5") * PIP
    if side == "LONG":
        return previous_high - depth
    if side == "SHORT":
        return previous_low + depth
    raise AuditError(f"unsupported side: {side}")


def actual_fill(side: str, bid_open: Decimal, spread_points: int) -> Decimal:
    if spread_points < 0:
        raise AuditError("spread points must be non-negative")
    spread = Decimal(spread_points) * POINT
    if side == "LONG":
        return bid_open + spread
    if side == "SHORT":
        return bid_open
    raise AuditError(f"unsupported side: {side}")


def bracket_from_fill(side: str, fill: Decimal) -> Bracket:
    stop_distance = SL_PIPS * PIP
    target_distance = TP_PIPS * PIP
    if side == "LONG":
        return Bracket(side, fill, fill - stop_distance, fill + target_distance)
    if side == "SHORT":
        return Bracket(side, fill, fill + stop_distance, fill - target_distance)
    raise AuditError(f"unsupported side: {side}")


def resolve_bar_exit(
    bracket: Bracket,
    *,
    bid_open: Decimal,
    bid_high: Decimal,
    bid_low: Decimal,
    spread_points: int,
) -> ExitEvent | None:
    """Conservative M5 bracket resolution with adverse gap handling."""

    if spread_points < 0:
        raise AuditError("spread points must be non-negative")
    if bid_low > min(bid_open, bid_high) or bid_high < max(bid_open, bid_low):
        raise AuditError("invalid bar geometry")
    spread = Decimal(spread_points) * POINT
    if bracket.side == "LONG":
        if bid_open <= bracket.stop:
            return ExitEvent("SL_GAP", bid_open, False, True)
        if bid_open >= bracket.target:
            return ExitEvent("TP_GAP", bracket.target, False, True)
        stop_hit = bid_low <= bracket.stop
        target_hit = bid_high >= bracket.target
    elif bracket.side == "SHORT":
        ask_open = bid_open + spread
        if ask_open >= bracket.stop:
            return ExitEvent("SL_GAP", ask_open, False, True)
        if ask_open <= bracket.target:
            return ExitEvent("TP_GAP", bracket.target, False, True)
        stop_hit = bid_high + spread >= bracket.stop
        target_hit = bid_low + spread <= bracket.target
    else:
        raise AuditError(f"unsupported side: {bracket.side}")
    if stop_hit:
        return ExitEvent("SL", bracket.stop, target_hit, False)
    if target_hit:
        return ExitEvent("TP", bracket.target, False, False)
    return None


def commission_side(volume_lots: Decimal, deal_price: Decimal) -> Decimal:
    if volume_lots <= 0 or deal_price <= 0:
        raise AuditError("commission inputs must be positive")
    rate = max(Decimal("2.50"), Decimal("2.50") * deal_price)
    with localcontext() as context:
        context.prec = 50
        return (rate * volume_lots).quantize(CENT, rounding=ROUND_HALF_UP)


def parse_selected_market(path: Path, symbol: str) -> MarketSlice:
    """Parse the declared historical slice without parsing future OHLC.

    This function exists for synthetic fence verification and a future
    source-unblocked contract.  The current build_document deliberately never
    calls it.
    """

    if not path.is_file():
        raise AuditError(f"market file missing: {path}")
    lower = naive_epoch(BROKER_FROM)
    upper = naive_epoch(BROKER_TO)
    digest = hashlib.sha256()
    bars: list[Bar] = []
    previous_timestamp: int | None = None
    first_excluded: str | None = None
    with path.open("r", encoding="ascii", newline="") as handle:
        header = handle.readline().strip("\r\n")
        if header != "time,open,high,low,close,tickvol":
            raise AuditError(f"unexpected market header: {header!r}")
        for row_number, raw_line in enumerate(handle, start=2):
            raw_timestamp, separator, _unparsed_future_tail = raw_line.partition(",")
            if not separator:
                raise AuditError(f"row {row_number}: missing timestamp delimiter")
            try:
                timestamp = int(raw_timestamp)
            except ValueError as exc:
                raise AuditError(f"row {row_number}: invalid timestamp") from exc
            if previous_timestamp is not None and timestamp <= previous_timestamp:
                raise AuditError(f"row {row_number}: timestamps are not strictly increasing")
            previous_timestamp = timestamp
            broker_time = broker_wall_datetime(timestamp)
            if timestamp >= upper:
                first_excluded = stamp(broker_time)
                break
            if timestamp < lower:
                continue
            if timestamp % TIMEFRAME_SECONDS:
                raise AuditError(f"row {row_number}: selected timestamp is not M5-aligned")
            selected_line = raw_line.strip("\r\n")
            parts = selected_line.split(",")
            if len(parts) != 6:
                raise AuditError(f"row {row_number}: malformed selected row")
            try:
                open_, high, low, close = (float(value) for value in parts[1:5])
                tick_volume = int(parts[5])
            except ValueError as exc:
                raise AuditError(f"row {row_number}: non-numeric selected OHLC/tickvol") from exc
            values = (open_, high, low, close)
            if (
                not all(math.isfinite(value) and value > 0 for value in values)
                or high < max(values)
                or low > min(values)
                or tick_volume < 0
            ):
                raise AuditError(f"row {row_number}: invalid selected OHLC/tickvol")
            utc_time = broker_wall_to_utc(broker_time)
            bars.append(
                Bar(
                    timestamp=timestamp,
                    broker_time=broker_time,
                    utc_time=utc_time,
                    rome_time=utc_time.astimezone(ROME),
                    new_york_time=utc_time.astimezone(NEW_YORK),
                    open=open_,
                    high=high,
                    low=low,
                    close=close,
                    tick_volume=tick_volume,
                )
            )
            digest.update((selected_line + "\n").encode("ascii"))
    if not bars:
        raise AuditError("selected market slice is empty")
    if first_excluded is None:
        raise AuditError("cannot prove future fence: no >=2023 timestamp")
    return MarketSlice(
        symbol=symbol,
        bars=tuple(bars),
        identity=SliceIdentity(
            path=str(path.resolve()).replace("\\", "/"),
            selected_sha256=digest.hexdigest(),
            selected_rows=len(bars),
            first_selected_broker_time=stamp(bars[0].broker_time),
            last_selected_broker_time=stamp(bars[-1].broker_time),
            first_excluded_timestamp=first_excluded,
            future_ohlc_parsed=False,
        ),
    )


def read_contract() -> dict[str, Any]:
    observed_hash = sha256_file(CONTRACT_PATH)
    if observed_hash != EXPECTED_CONTRACT_SHA256:
        raise AuditError(
            f"contract hash drift: expected {EXPECTED_CONTRACT_SHA256}, observed {observed_hash}"
        )
    try:
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AuditError(f"cannot read contract: {exc}") from exc
    validate_contract(contract)
    return contract


def validate_contract(contract: Mapping[str, Any]) -> None:
    if contract.get("analysis_id") != ANALYSIS_ID:
        raise AuditError("analysis id drift")
    if contract.get("status") != "PREREGISTERED_BLOCKED_SOURCE_AMBIGUITY":
        raise AuditError("contract is not in the required blocked preregistration state")
    evidence = contract.get("source_evidence", {})
    if evidence.get("pine_source_available") is not False:
        raise AuditError("Pine availability drift requires a new contract/analysis id")
    blockers = tuple(
        item.get("id") for item in contract.get("source_semantics", {}).get("blocking_ambiguities", [])
    )
    if blockers != EXPECTED_BLOCKERS:
        raise AuditError("source blocker set/order drift")
    center = contract.get("frozen_center_if_source_unblocked", {})
    exact = {
        "symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
        "timeframe": "M5",
        "session_timezone": "Europe/Rome",
        "new_session_roll": "06:00:00 Europe/Rome",
        "reentry_level_pips_inside": 5,
        "entry_tolerance_pips": 5,
        "minimum_bars_after_break": 3,
        "entry_direction": "CONTINUATION",
        "stop_loss_pips_from_actual_fill": 10,
        "take_profit_pips_from_actual_fill": 20,
        "max_trades_per_new_york_day": 1,
        "pyramiding": 0,
    }
    for key, expected in exact.items():
        if center.get(key) != expected:
            raise AuditError(f"frozen center drift: {key}")
    spreads = contract.get("spread_scenarios", {})
    if spreads.get("points") != [0, 4, 8] or spreads.get("center_points") != 4:
        raise AuditError("spread scenario drift")
    if contract.get("news", {}).get("source_sha256") != EXPECTED_NEWS_SHA256:
        raise AuditError("news identity drift")


def committed_contract_identity() -> dict[str, str]:
    relative = CONTRACT_PATH.relative_to(REPO_ROOT).as_posix()
    command = ["git", "log", "-1", "--format=%H", "--", relative]
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    commit = completed.stdout.strip()
    if completed.returncode != 0 or not commit:
        raise AuditError("contract is not committed; outcome firewall remains closed")
    blob = subprocess.run(
        ["git", "show", f"{commit}:{relative}"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
    )
    if blob.returncode != 0 or blob.stdout != CONTRACT_PATH.read_bytes():
        raise AuditError("working contract does not byte-match its last committed blob")
    return {"commit": commit, "path": relative, "sha256": EXPECTED_CONTRACT_SHA256}


def verify_bound_evidence() -> dict[str, str]:
    if sha256_file(MISMATCH_PATH) != EXPECTED_MISMATCH_SHA256:
        raise AuditError("source-mismatch record hash drift")
    observed: dict[str, str] = {}
    for path, expected in EXPECTED_EVIDENCE_SHA256.items():
        if not path.is_file():
            raise AuditError(f"bound evidence missing: {path}")
        digest = sha256_file(path)
        if digest != expected:
            raise AuditError(f"bound evidence drift: {path}")
        observed[repo_label(path)] = digest
    return dict(sorted(observed.items()))


def build_document(
    data_root: Path = DEFAULT_DATA_ROOT,
    news_path: Path = DEFAULT_NEWS_PATH,
) -> dict[str, Any]:
    """Build a deterministic blocked result without opening outcome inputs."""

    contract = read_contract()
    contract_identity = committed_contract_identity()
    evidence = verify_bound_evidence()
    blockers = contract["source_semantics"]["blocking_ambiguities"]
    # Deliberately do not stat/hash/open data_root or news_path here.  Even a
    # missing input must not mask the earlier source-admissibility failure.
    return {
        "schema_version": 1,
        "analysis_id": ANALYSIS_ID,
        "status": "BLOCKED_SOURCE_AMBIGUITY",
        "decision": "NOT_ADJUDICATED",
        "admissibility": "NO_OUTCOME_RUN_NO_MT5_NO_PIPELINE_NO_FTMO",
        "identity": {
            "contract": contract_identity,
            "auditor_path": repo_label(TOOL_PATH),
            "auditor_sha256": sha256_file(TOOL_PATH),
            "test_path": repo_label(TEST_PATH),
            "test_sha256": sha256_file(TEST_PATH),
            "mismatch_path": repo_label(MISMATCH_PATH),
            "mismatch_sha256": EXPECTED_MISMATCH_SHA256,
            "bound_evidence": evidence,
        },
        "source_preflight": {
            "status": "BLOCKED",
            "pine_source_available": False,
            "direct_page_state": contract["source_evidence"]["direct_page_observed_2026_07_20"],
            "blocking_ambiguities": blockers,
            "unblock_requirement": contract["source_semantics"]["unblock_requirement"],
        },
        "outcome_input_access": {
            "market_paths_planned": [
                str((data_root / f"{symbol}_M5.csv")).replace("\\", "/")
                for symbol in ("EURUSD.DWX", "GBPUSD.DWX")
            ],
            "news_path_planned": str(news_path).replace("\\", "/"),
            "market_files_opened": 0,
            "market_rows_parsed": 0,
            "market_ohlc_rows_parsed": 0,
            "news_files_opened": 0,
            "news_rows_parsed": 0,
            "future_ohlc_parsed": False,
            "reason": "SOURCE_PREFLIGHT_BLOCK_PRECEDES_ALL_OUTCOME_INPUT_IO",
        },
        "frozen_center": contract["frozen_center_if_source_unblocked"],
        "predeclared_joint_merit_gate": contract["joint_merit_gate"],
        "performance": None,
        "merit": {
            "decision": "NOT_ADJUDICATED",
            "reason": "Exact source semantics are unavailable; no outcome was computed.",
            "failed_checks": [],
            "evaluated_checks": 0,
        },
        "required_next_action": [
            "Recover and hash the exact Pine revision named ICT_Session_Breakout_Published.pine.",
            "Resolve every blocker against executable Pine lines.",
            "Create and commit a new pre-outcome contract/analysis_id before any data read.",
        ],
        "prohibitions": contract["prohibitions"],
    }


def encode_document(document: Mapping[str, Any]) -> str:
    return json.dumps(document, indent=2, sort_keys=True, allow_nan=False) + "\n"


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT)
    parser.add_argument("--news", type=Path, default=DEFAULT_NEWS_PATH)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        document = build_document(args.data_root, args.news)
        payload = encode_document(document)
        if args.output is None:
            sys.stdout.write(payload)
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(payload, encoding="utf-8", newline="\n")
        return 3
    except (AuditError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"REJECT: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
