#!/usr/bin/env python3
"""Freeze the full Factory EA/symbol search universe for shadow null tests.

The census is read-only with respect to the Factory database.  It materializes
the exact sorted pair identities used by the canonical rebaseline frontier and
binds them with SHA-256.  The pair count is deliberately a *lower bound* on
selection multiplicity: phase evaluations, reruns, and parameter trials can
only make the true search world larger.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import rebaseline_census  # noqa: E402


SCHEMA = "qm.shadow-null-search-world-census/v1"
PRIMARY_UNIT = "EA_SYMBOL_PAIR_LOWER_BOUND"
DEFAULT_DB = Path(rebaseline_census.DEFAULT_DB)


class SearchWorldCensusError(ValueError):
    """The frozen search universe is incomplete, ambiguous, or tampered."""


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _normalise_pairs(rows: Iterable[Mapping[str, Any]]) -> list[dict[str, str]]:
    pairs = [
        {"ea_id": str(row.get("ea_id") or ""), "symbol": str(row.get("symbol") or "")}
        for row in rows
    ]
    if any(not row["ea_id"] or not row["symbol"] for row in pairs):
        raise SearchWorldCensusError("search-world pair has a blank EA or symbol")
    pairs.sort(key=lambda row: (row["ea_id"], row["symbol"]))
    identities = [(row["ea_id"], row["symbol"]) for row in pairs]
    if len(identities) != len(set(identities)):
        raise SearchWorldCensusError("search-world census contains duplicate pairs")
    return pairs


def build_payload(
    rows: Iterable[Mapping[str, Any]],
    *,
    generated_at_utc: str,
    database_path: str,
    database_observation: Mapping[str, Any],
) -> dict[str, Any]:
    pairs = _normalise_pairs(rows)
    pairs_sha256 = _sha256_bytes(_canonical_bytes(pairs))
    return {
        "schema": SCHEMA,
        "mode": "POST_HOC_SHADOW_ONLY_NON_GATE",
        "generated_at_utc": generated_at_utc,
        "primary_trial_unit": PRIMARY_UNIT,
        "definition": (
            "Every distinct (ea_id, symbol) pair in the canonical read-only "
            "rebaseline frontier at freeze time. This is a lower bound because "
            "phase, rerun, and parameter-selection hypotheses are not collapsed "
            "into fewer than one trial per pair."
        ),
        "pair_count": len(pairs),
        "pairs_sha256": pairs_sha256,
        "pairs": pairs,
        "database_observation": {
            "path": database_path,
            **dict(database_observation),
        },
        "census_code": {
            "path": str(Path(rebaseline_census.__file__).resolve()),
            "sha256": _file_sha256(Path(rebaseline_census.__file__).resolve()),
        },
        "authority": {
            "factory_write": False,
            "gate_change": False,
            "candidate_change": False,
            "book_or_live_use": False,
        },
    }


def validate_payload(payload: Mapping[str, Any]) -> dict[str, Any]:
    if payload.get("schema") != SCHEMA:
        raise SearchWorldCensusError("unsupported search-world census schema")
    if payload.get("mode") != "POST_HOC_SHADOW_ONLY_NON_GATE":
        raise SearchWorldCensusError("search-world census is not shadow-only")
    if payload.get("primary_trial_unit") != PRIMARY_UNIT:
        raise SearchWorldCensusError("unsupported search-world trial unit")
    generated_at = str(payload.get("generated_at_utc") or "")
    try:
        parsed_at = dt.datetime.fromisoformat(generated_at.replace("Z", "+00:00"))
    except ValueError as exc:
        raise SearchWorldCensusError("search-world freeze timestamp is invalid") from exc
    if parsed_at.tzinfo is None:
        raise SearchWorldCensusError("search-world freeze timestamp is not timezone-aware")
    if not str(payload.get("definition") or "").strip():
        raise SearchWorldCensusError("search-world definition is blank")
    raw_pairs = payload.get("pairs")
    if not isinstance(raw_pairs, list):
        raise SearchWorldCensusError("search-world pairs must be a list")
    pairs = _normalise_pairs(raw_pairs)
    if pairs != raw_pairs:
        raise SearchWorldCensusError("search-world pairs are not canonically sorted")
    if payload.get("pair_count") != len(pairs) or len(pairs) < 2:
        raise SearchWorldCensusError("search-world pair count is invalid")
    observed_hash = _sha256_bytes(_canonical_bytes(pairs))
    if payload.get("pairs_sha256") != observed_hash:
        raise SearchWorldCensusError("search-world pair hash mismatch")
    observation = payload.get("database_observation")
    if (
        not isinstance(observation, dict)
        or observation.get("query_only") is not True
        or observation.get("snapshot_transaction") is not True
    ):
        raise SearchWorldCensusError(
            "search-world database observation was not a read-only snapshot"
        )
    authority = payload.get("authority")
    if not isinstance(authority, dict) or any(authority.get(key) is not False for key in (
        "factory_write", "gate_change", "candidate_change", "book_or_live_use"
    )):
        raise SearchWorldCensusError("search-world census authority boundary is invalid")
    return dict(payload)


def load_census(path: str | Path) -> dict[str, Any]:
    source = Path(path).resolve()
    try:
        payload = json.loads(source.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SearchWorldCensusError(f"search-world census unreadable: {source}: {exc}") from exc
    if not isinstance(payload, dict):
        raise SearchWorldCensusError("search-world census must be an object")
    result = validate_payload(payload)
    result["census_path"] = str(source)
    result["census_sha256"] = _file_sha256(source)
    return result


def build_census(db_path: str | Path = DEFAULT_DB) -> dict[str, Any]:
    db = Path(db_path).resolve()
    con = rebaseline_census.open_ro(str(db))
    try:
        # Python's sqlite3 does not start a transaction for SELECT statements.
        # Pin one WAL snapshot explicitly so the concurrently running Factory
        # cannot make the identity list and multiplicity counts disagree.
        con.execute("BEGIN")
        census = rebaseline_census.compute(con, limit=None)
        observation = {
            "work_item_count": int(con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0]),
            "terminal_verdict_count": int(con.execute(
                "SELECT COUNT(*) FROM work_items WHERE status IN ('done','failed') "
                "AND verdict IS NOT NULL"
            ).fetchone()[0]),
            "distinct_ea_count": int(con.execute(
                "SELECT COUNT(DISTINCT ea_id) FROM work_items"
            ).fetchone()[0]),
            "distinct_pair_phase_count": int(con.execute(
                "SELECT COUNT(*) FROM (SELECT DISTINCT ea_id,symbol,phase FROM work_items)"
            ).fetchone()[0]),
            "max_work_item_updated_at": con.execute(
                "SELECT MAX(updated_at) FROM work_items"
            ).fetchone()[0],
            "query_only": True,
            "snapshot_transaction": True,
        }
    finally:
        if con.in_transaction:
            con.rollback()
        con.close()
    return build_payload(
        census["pair_rows"],
        generated_at_utc=_utc_now(),
        database_path=str(db),
        database_observation=observation,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        payload = build_census(args.db)
        validate_payload(payload)
    except (OSError, sqlite3.Error, SearchWorldCensusError, ValueError) as exc:
        print(f"SEARCH_WORLD_CENSUS_REFUSED: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2
    encoded = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(encoded, encoding="utf-8")
    print(json.dumps({
        "output": str(args.output.resolve()),
        "pair_count": payload["pair_count"],
        "pairs_sha256": payload["pairs_sha256"],
        "mode": payload["mode"],
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = [
    "PRIMARY_UNIT", "SCHEMA", "SearchWorldCensusError", "build_census",
    "build_payload", "load_census", "validate_payload",
]
