#!/usr/bin/env python3
"""Emit a census-bound ``qm.dual-book-roster/v1`` roster for the DXZ/FTMO builders.

Fixes defect D3 (docs/ops/evidence/2026-09-03_book_path_rehearsal_5pair_pool.md
lines 238-246): the book builders default to a hand-maintained roster FILE
(``build_book_dxz.py:47`` / ``build_book_ftmo.py:43`` ``DEFAULT_ROSTER``, the stale
July 24-sleeve live manifest) that is decoupled from the guard's qualified pool.

This tool reads the guard's census function
``book_build_guard._qualified_pair_rows`` (the exact function
``check_book_build_allowed`` uses, ``book_build_guard.py:72-84,191``) strictly
read-only, resolves every field a builder needs per sleeve from the repository
registries, and writes a roster JSON that the builders load through their own
loader ``book_builder_common.resolve_roster`` (``book_builder_common.py:91-160``,
schema ``book_builder_common.py:21``).

The tool never mutates the farm DB (it is opened ``mode=ro`` by
``rebaseline_census.open_ro``), a queue, a verdict, factory state, a deployment
tree, or AutoTrading state. It writes exactly one file: the caller-supplied
``--out`` roster (a scratch path). Application of any roster to a live book
remains a separate OWNER ceremony.
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import book_build_guard, gate_manifest
from tools.strategy_farm.portfolio import concentration_tail
from tools.strategy_farm.portfolio.book_builder_common import (
    SCHEMA,
    BookBuildError,
    file_binding,
    key_from_row,
    sleeve_bindings,
)

GENERATOR = "build_qualified_roster.py"
GENERATOR_CONTRACT = "qm.build-qualified-roster/v1"
Key = tuple[int, str]


class RosterBuildError(ValueError):
    """A qualified pair is missing a field a book builder requires."""

    def __init__(self, key: Key, reason: str):
        self.key = key
        self.reason = reason
        super().__init__(f"ROSTER_SLEEVE_REFUSED {key[0]}:{key[1]}: {reason}")


def _relpath(path: Path, repo_root: Path) -> str:
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(Path(repo_root).resolve())).replace("\\", "/")
    except ValueError:
        return str(resolved)


def _resolve_ea_dir(repo_root: Path, ea_id: int, key: Key) -> Path:
    matches = sorted(
        candidate
        for candidate in (repo_root / "framework" / "EAs").glob(f"QM5_{ea_id}_*")
        if candidate.is_dir()
    )
    if len(matches) != 1:
        raise RosterBuildError(
            key, f"expected exactly one EA directory QM5_{ea_id}_*, found {len(matches)}"
        )
    return matches[0]


def _resolve_family(repo_root: Path, key: Key) -> str:
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    kwargs: dict[str, Any] = {}
    if registry.is_file():
        kwargs["registry_path"] = registry
    try:
        return concentration_tail.family_fingerprints(repo_root, [key], **kwargs)[key]
    except concentration_tail.ConcentrationTailError as exc:
        raise RosterBuildError(key, f"family fingerprint unresolved: {exc}") from exc


def _resolve_timeframe(repo_root: Path, key: Key, setfile_rel: str) -> str:
    name = Path(setfile_rel).name
    match = re.search(
        rf"_{re.escape(key[1])}_([A-Za-z0-9]+)_backtest", name, re.IGNORECASE
    )
    if match:
        return match.group(1).upper()
    try:
        body = (repo_root / setfile_rel).read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError):
        body = ""
    header = re.search(r"(?mi)^;\s*(?:timeframe|period)\s*:\s*(\S+)\s*$", body)
    if header:
        return header.group(1).upper()
    raise RosterBuildError(key, f"timeframe token unresolved from setfile {name}")


def _resolve_sleeve(repo_root: Path, key: Key) -> dict[str, Any]:
    """Bind one qualified pair to every field a builder reads; refuse if any is absent."""
    ea_id, symbol = key
    ea_dir = _resolve_ea_dir(repo_root, ea_id, key)
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    try:
        ex5_binding = file_binding(ex5)
    except BookBuildError as exc:
        raise RosterBuildError(key, f"ex5 binary missing or unreadable: {exc}") from exc
    try:
        binding = sleeve_bindings(repo_root, [key])[0]
    except BookBuildError as exc:
        raise RosterBuildError(key, str(exc)) from exc
    family = _resolve_family(repo_root, key)
    timeframe = _resolve_timeframe(repo_root, key, str(binding["setfile"]))
    return {
        "ea_id": ea_id,
        "symbol": symbol,
        "q10_verdict": "PASS",
        "family": family,
        "timeframe": timeframe,
        "magic": binding["magic"],
        "ex5": _relpath(ex5, repo_root),
        "ex5_sha256": ex5_binding["sha256"],
        "ex5_size_bytes": ex5_binding["size_bytes"],
        "setfile": binding["setfile"],
        "setfile_sha256": binding["setfile_sha256"],
        "backtest_risk_fixed": binding["backtest_risk_fixed"],
        "backtest_risk_percent": binding["backtest_risk_percent"],
    }


def build_qualified_roster(
    *,
    venue: str,
    db_path: str | Path,
    order_dir: str | Path,
    repo_root: str | Path | None = None,
    qualified_rows: Iterable[Mapping[str, Any]] | None = None,
    terminal_gate: str | None = None,
    generated_at: str | None = None,
) -> dict[str, Any]:
    """Read the guard census read-only and return a census-bound roster dict.

    ``repo_root`` defaults to the guard's own ``REPO_ROOT`` so that the embedded
    guard status snapshot and the per-sleeve enrichment resolve against the same
    tree. Pass ``qualified_rows`` to bypass the DB read (tests / injection); those
    rows are still routed through the guard for the authoritative status snapshot.
    """
    venue_norm = book_build_guard._normalize_venue(venue)
    if repo_root is None:
        repo_root = book_build_guard.REPO_ROOT
    repo_root = Path(repo_root).resolve()
    if generated_at is None:
        generated_at = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    if qualified_rows is None:
        manifest = gate_manifest.load_gate_manifest()
        terminal_gate = manifest.terminal_requalification_gate
        raw_rows = book_build_guard._qualified_pair_rows(Path(db_path), terminal_gate)
    else:
        raw_rows = [dict(row) for row in qualified_rows]

    keys: list[Key] = sorted({key_from_row(row, "census row") for row in raw_rows})
    sleeves = [_resolve_sleeve(repo_root, key) for key in keys]

    guard_result = book_build_guard.check_book_build_allowed(
        venue_norm, db_path, order_dir, qualified_rows=raw_rows
    )

    return {
        "schema": SCHEMA,
        "generated_at": generated_at,
        "venue": venue_norm,
        "provenance": {
            "generator": GENERATOR,
            "generator_contract": GENERATOR_CONTRACT,
            "census_source": "book_build_guard._qualified_pair_rows",
            "db_path": str(db_path),
            "db_access_mode": "ro",
            "order_dir": str(order_dir),
            "repo_root": str(repo_root),
            "roster_loader": "book_builder_common.resolve_roster",
        },
        "census": {
            "guard_status": dataclasses.asdict(guard_result),
            "terminal_requalification_gate": terminal_gate,
            "qualified_pairs": len(keys),
            "qualified_ids": [{"ea_id": key[0], "symbol": key[1]} for key in keys],
        },
        "q10_pass": sleeves,
        "q16_outcomes": [],
    }


def parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--venue", required=True, choices=sorted(book_build_guard.SUPPORTED_VENUES))
    ap.add_argument("--out", type=Path, help="destination roster JSON (scratch path)")
    ap.add_argument("--dry-run", action="store_true", help="print the roster instead of writing it")
    ap.add_argument("--db-path", type=Path, default=book_build_guard.DEFAULT_DB_PATH)
    ap.add_argument("--order-dir", type=Path, default=book_build_guard.DEFAULT_ORDER_DIR)
    ap.add_argument("--generated-at", help="override the generated_at stamp (ISO-8601)")
    return ap


def main(argv: list[str] | None = None) -> int:
    ap = parser()
    args = ap.parse_args(argv)
    if not args.dry_run and args.out is None:
        ap.error("--out is required unless --dry-run is set")
    try:
        roster = build_qualified_roster(
            venue=args.venue,
            db_path=args.db_path,
            order_dir=args.order_dir,
            generated_at=args.generated_at,
        )
    except (RosterBuildError, BookBuildError, gate_manifest.GateManifestError) as exc:
        print(
            json.dumps({"status": "ROSTER_BUILD_REFUSED", "error": str(exc)}, indent=2),
            file=sys.stderr,
        )
        return 2
    text = json.dumps(roster, indent=2, sort_keys=True)
    if args.dry_run:
        print(text)
        return 0
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text + "\n", encoding="utf-8")
    print(json.dumps({
        "status": "ROSTER_WRITTEN",
        "out": str(out),
        "schema": SCHEMA,
        "venue": args.venue,
        "qualified_pairs": len(roster["q10_pass"]),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
