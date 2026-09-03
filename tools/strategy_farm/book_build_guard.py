#!/usr/bin/env python3
"""Fail-closed authorization guard for DXZ/FTMO book analysis and build entry.

The candidate census is read-only and delegates contiguous-gate validity to
``rebaseline_census``.  This module never mutates the farm DB, queues, verdicts,
factory state, deployment trees, or AutoTrading state.
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import gate_manifest, rebaseline_census
from tools.strategy_farm.portfolio import concentration_tail
from tools.strategy_farm.portfolio.portfolio_common import _coerce_ea_int


MIN_QUALIFIED_PAIRS = 25
SUPPORTED_VENUES = frozenset({"dxz", "ftmo", "both"})
DEFAULT_DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ORDER_DIR = REPO_ROOT / "decisions"
_ORDER_NAME = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})_owner_book_order_"
    r"(?P<venue>dxz|ftmo|both)\.md$"
)


@dataclass
class GuardResult:
    allowed: bool
    qualified_pairs: int
    distinct_eas: int
    strategy_families: int
    order_artifact: str | None
    reasons: list[str]


class BookBuildRefused(RuntimeError):
    """A book-analysis/build entry was attempted without both authorities."""

    def __init__(self, result: GuardResult):
        self.result = result
        detail = "; ".join(result.reasons) or "book-build guard refused"
        super().__init__(
            f"BOOK_BUILD_REFUSED: {detail} "
            f"(qualified_pairs={result.qualified_pairs}, "
            f"distinct_eas={result.distinct_eas}, "
            f"strategy_families={result.strategy_families})"
        )


REFUSAL_EXIT_CODE = 2


def emit_refusal(
    status: str,
    reason: str,
    fields: dict,
    *,
    stream=None,
) -> int:
    """Print ONE structured JSON refusal and return the fail-closed exit code.

    Mirrors the ``book_build_guard.py --status`` contract: the guard/freeze
    status ``fields`` plus a refusal ``reason``, rendered as JSON with exit
    code 2.  Book-path entrypoints call this from their ``main`` so a
    fail-closed refusal surfaces legibly instead of an uncaught traceback.  It
    changes only how a refusal is presented, never whether a path may proceed.
    """
    payload = {"status": status, "reason": reason, **fields}
    print(
        json.dumps(payload, indent=2, sort_keys=True),
        file=stream if stream is not None else sys.stdout,
    )
    return REFUSAL_EXIT_CODE


def emit_book_build_refusal(exc: "BookBuildRefused", *, stream=None) -> int:
    """Render a ``BookBuildRefused`` as the structured refusal (exit 2)."""
    return emit_refusal(
        "BOOK_BUILD_REFUSED",
        "; ".join(exc.result.reasons) or "book-build guard refused",
        dataclasses.asdict(exc.result),
        stream=stream,
    )


def _normalize_venue(venue: str) -> str:
    normalized = str(venue).strip().lower()
    if normalized not in SUPPORTED_VENUES:
        raise ValueError(
            f"venue must be one of {sorted(SUPPORTED_VENUES)}, got {venue!r}"
        )
    return normalized


def _qualified_pair_rows(db_path: Path, terminal_gate: str) -> list[dict]:
    """Use the census implementation to find exactly-terminal contiguous pairs."""
    connection = rebaseline_census.open_ro(str(Path(db_path)))
    try:
        pairs = rebaseline_census.build_pairs(connection, limit=None)
        rows: list[dict] = []
        for (ea_id, symbol), record in pairs.items():
            summary = rebaseline_census.summarise_pair(record)
            if summary["highest_contiguous_valid_gate"] == terminal_gate:
                rows.append({"ea_id": str(ea_id), "symbol": str(symbol)})
        return rows
    finally:
        connection.close()


def _count_strategy_families(rows: Iterable[dict]) -> int:
    keys: set[tuple[int, str]] = set()
    for row in rows:
        ea_int = _coerce_ea_int(row["ea_id"])
        if ea_int is None:
            raise ValueError(f"unparseable qualified ea_id: {row['ea_id']!r}")
        keys.add((ea_int, str(row["symbol"])))
    if not keys:
        return 0
    fingerprints = concentration_tail.family_fingerprints(REPO_ROOT, keys)
    return len(set(fingerprints.values()))


def _count_distinct_eas(rows: Iterable[dict]) -> int:
    ea_ids: set[int] = set()
    for row in rows:
        ea_int = _coerce_ea_int(row["ea_id"])
        if ea_int is None:
            raise ValueError(f"unparseable qualified ea_id: {row['ea_id']!r}")
        ea_ids.add(ea_int)
    return len(ea_ids)


def _compatible_order_venues(requested: str) -> frozenset[str]:
    if requested == "both":
        return frozenset({"both"})
    return frozenset({requested, "both"})


def _find_owner_order(
    venue: str,
    order_dir: Path,
    *,
    today: dt.date,
) -> tuple[str | None, list[str]]:
    compatible = _compatible_order_venues(venue)
    try:
        candidates = sorted(Path(order_dir).glob("*_owner_book_order_*.md"), reverse=True)
    except OSError as exc:
        return None, [f"owner_order_unreadable: {order_dir}: {exc}"]

    if not candidates:
        return None, [f"owner_order_missing: venue={venue} order_dir={order_dir}"]

    invalid: list[str] = []
    wrong_venues: set[str] = set()
    for path in candidates:
        match = _ORDER_NAME.fullmatch(path.name)
        if match is None:
            continue
        artifact_venue = match.group("venue")
        if artifact_venue not in compatible:
            wrong_venues.add(artifact_venue)
            continue
        raw_date = match.group("date")
        try:
            artifact_date = dt.date.fromisoformat(raw_date)
        except ValueError:
            invalid.append(f"owner_order_invalid_date: {path}")
            continue
        if artifact_date > today:
            invalid.append(f"owner_order_future_dated: {path} date={raw_date}")
            continue
        expected_line = f"OWNER-ORDER: BOOK_BUILD {artifact_venue} {raw_date}"
        try:
            lines = path.read_text(encoding="utf-8-sig").splitlines()
        except (OSError, UnicodeError) as exc:
            invalid.append(f"owner_order_unreadable: {path}: {exc}")
            continue
        if expected_line not in (line.strip() for line in lines):
            invalid.append(
                f"owner_order_invalid: {path} missing exact line {expected_line!r}"
            )
            continue
        return str(path.resolve()), []

    if invalid:
        return None, invalid
    if wrong_venues:
        return None, [
            f"owner_order_wrong_venue: requested={venue} "
            f"available={','.join(sorted(wrong_venues))}"
        ]
    return None, [f"owner_order_missing: venue={venue} order_dir={order_dir}"]


def check_book_build_allowed(
    venue: str,
    db_path: str | Path,
    order_dir: str | Path = "decisions",
    *,
    qualified_rows: Iterable[dict] | None = None,
) -> GuardResult:
    """Measure the two mandatory book-build conditions without changing state."""
    normalized_venue = _normalize_venue(venue)
    reasons: list[str] = []
    measured_rows: list[dict] = []
    distinct_eas = 0
    strategy_families = 0

    try:
        if qualified_rows is None:
            manifest = gate_manifest.load_gate_manifest()
            terminal_gate = manifest.terminal_requalification_gate
            measured_rows = _qualified_pair_rows(Path(db_path), terminal_gate)
        else:
            measured_rows = list(qualified_rows)
        distinct_eas = _count_distinct_eas(measured_rows)
        strategy_families = _count_strategy_families(measured_rows)
    except Exception as exc:
        reasons.append(f"qualified_pool_unavailable: {type(exc).__name__}: {exc}")

    qualified_pairs = len(measured_rows)
    if qualified_pairs < MIN_QUALIFIED_PAIRS:
        reasons.append(
            f"qualified_pairs_below_minimum: {qualified_pairs} < {MIN_QUALIFIED_PAIRS}"
        )

    artifact, artifact_reasons = _find_owner_order(
        normalized_venue,
        Path(order_dir),
        today=dt.date.today(),
    )
    reasons.extend(artifact_reasons)
    return GuardResult(
        allowed=not reasons,
        qualified_pairs=qualified_pairs,
        distinct_eas=distinct_eas,
        strategy_families=strategy_families,
        order_artifact=artifact,
        reasons=reasons,
    )


def require_book_build_allowed(
    venue: str,
    db_path: str | Path,
    order_dir: str | Path = "decisions",
) -> GuardResult:
    result = check_book_build_allowed(venue, db_path, order_dir)
    if not result.allowed:
        raise BookBuildRefused(result)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--status", action="store_true", help="print guard status as JSON")
    parser.add_argument("--venue", required=True, choices=sorted(SUPPORTED_VENUES))
    parser.add_argument("--db-path", type=Path, default=DEFAULT_DB_PATH)
    parser.add_argument("--order-dir", type=Path, default=DEFAULT_ORDER_DIR)
    args = parser.parse_args(argv)
    if not args.status:
        parser.error("--status is required (this CLI performs no build action)")
    result = check_book_build_allowed(args.venue, args.db_path, args.order_dir)
    print(json.dumps(dataclasses.asdict(result), indent=2, sort_keys=True))
    return 0 if result.allowed else 2


if __name__ == "__main__":
    raise SystemExit(main())
